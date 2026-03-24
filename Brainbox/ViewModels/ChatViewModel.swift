import Foundation

@MainActor
@Observable
class ChatViewModel {
    struct QueuedMessage: Identifiable, Equatable {
        let id = UUID()
        let content: String
        let conversationId: String
        let attachments: [AttachmentInfo]
        let model: AIModel

        var previewText: String {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
            let count = attachments.count
            return count == 1 ? "1 attachment" : "\(count) attachments"
        }
    }

    private struct ActiveStream {
        let assistantMessageId: String
        let conversationId: String
        var content: String
    }

    var messages: [Message] = []
    var isLoading = false
    var errorMessage: String? {
        didSet {
            scheduleErrorDismissal(for: errorMessage)
        }
    }
    var availableModels: [AIModel] = defaultModels
    var queuedMessages: [QueuedMessage] = []
    var selectedModel: AIModel = defaultModels[0] {
        didSet {
            if oldValue.id != selectedModel.id {
                UserDefaults.standard.set(selectedModel.id, forKey: UDKey.selectedModelId)
            }
        }
    }

    private(set) var activeConversationId: String?
    private var streamingTask: Task<Void, Never>?
    private var activeStream: ActiveStream?
    private var errorDismissTask: Task<Void, Never>?
    private let dataService: DataServiceProtocol
    private let streamingService = StreamingService()
    private let keychainService: KeychainService
    private let localAttachmentService = LocalAttachmentService()
    private let errorDismissalInterval: Duration

    init(
        dataService: DataServiceProtocol,
        keychainService: KeychainService,
        errorDismissalInterval: Duration = .seconds(15)
    ) {
        self.dataService = dataService
        self.keychainService = keychainService
        self.errorDismissalInterval = errorDismissalInterval
    }

    /// Whether the assistant is currently streaming a response.
    /// Uses both the derived message state and the active task as a safety check.
    var isAssistantStreaming: Bool {
        streamingTask != nil || (messages.last?.isAssistant == true && messages.last?.isStreaming == true)
    }

    /// Whether there are messages waiting to be sent after the current stream finishes.
    var hasQueuedMessages: Bool {
        !queuedMessages.isEmpty
    }

    var queuedMessagePreviews: [QueuedMessagesPillView.QueuedPreview] {
        queuedMessages.map { QueuedMessagesPillView.QueuedPreview(id: $0.id, text: $0.previewText) }
    }

    func loadConversation(_ conversationId: String, initialMessages: [Message] = []) {
        if activeConversationId == conversationId {
            return
        }

        cancelStreaming(finalizeCurrentMessage: true, continueQueue: false)
        activeConversationId = conversationId
        queuedMessages = []

        if !initialMessages.isEmpty {
            messages = initialMessages
        } else {
            messages = dataService.fetchMessages(conversationId: conversationId)
        }
        isLoading = false
    }

    func loadModels() {
        let configured = keychainService.configuredProviders
        if configured.isEmpty {
            availableModels = defaultModels
        } else {
            availableModels = defaultModels.filter { configured.contains($0.provider) }
            if availableModels.isEmpty {
                availableModels = defaultModels
            }
        }

        if let savedId = UserDefaults.standard.string(forKey: UDKey.selectedModelId),
           let model = availableModels.first(where: { $0.id == savedId }) {
            selectedModel = model
        } else if let first = availableModels.first {
            selectedModel = first
        }
    }

    func send(content: String, conversationId: String, attachments: [AttachmentInfo] = []) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !attachments.isEmpty else {
            return
        }

        // Only allow queuing for the currently active conversation
        guard conversationId == activeConversationId else {
            return
        }

        let queuedMessage = QueuedMessage(
            content: trimmed,
            conversationId: conversationId,
            attachments: attachments,
            model: selectedModel
        )

        if isAssistantStreaming {
            queuedMessages.append(queuedMessage)
            return
        }

        sendNow(queuedMessage)
    }

    func stopStreaming() {
        cancelStreaming(finalizeCurrentMessage: true, continueQueue: true)
    }

    func removeQueuedMessage(id: QueuedMessage.ID) {
        queuedMessages.removeAll { $0.id == id }
    }

    func popLastQueuedMessage() -> String? {
        guard let lastMessage = queuedMessages.last,
              !lastMessage.content.isEmpty else {
            return nil
        }

        queuedMessages.removeLast()
        return lastMessage.content
    }

    func regenerate(messageId: String, conversationId: String) {
        cancelStreaming(finalizeCurrentMessage: true, continueQueue: false)

        guard let index = messages.firstIndex(where: { $0.id == messageId && $0.isAssistant }) else {
            return
        }

        dataService.updateMessageContent(id: messageId, content: "")
        messages[index] = messages[index].updated(
            content: "",
            isStreaming: true,
            modelIdentifier: selectedModel.id,
            providerName: selectedModel.provider
        )

        startStreaming(
            assistantMessageId: messageId,
            conversationId: conversationId,
            model: selectedModel
        )
    }

    func branch(fromMessageId messageId: String, conversationId: String) async -> String? {
        return dataService.branchConversation(fromMessageId: messageId, conversationId: conversationId)
    }

    func unsubscribeMessages() {
        cancelStreaming(finalizeCurrentMessage: true, continueQueue: false)
        activeConversationId = nil
        queuedMessages = []
        messages = []
        isLoading = false
    }

    func refreshMessages() {
        guard let conversationId = activeConversationId else { return }
        messages = dataService.fetchMessages(conversationId: conversationId)
    }

    private func sendNow(_ queuedMessage: QueuedMessage) {
        let userMsg = dataService.createMessage(
            conversationId: queuedMessage.conversationId,
            role: "user",
            content: queuedMessage.content,
            modelIdentifier: nil,
            providerName: nil,
            isStreaming: false,
            attachments: queuedMessage.attachments
        )
        messages.append(userMsg)

        if messages.count == 1 {
            dataService.autoTitleConversation(
                id: queuedMessage.conversationId,
                firstMessageContent: queuedMessage.previewText
            )
        }

        let assistantMsg = dataService.createMessage(
            conversationId: queuedMessage.conversationId,
            role: "assistant",
            content: "",
            modelIdentifier: queuedMessage.model.id,
            providerName: queuedMessage.model.provider,
            isStreaming: true,
            attachments: []
        )
        messages.append(assistantMsg)

        dataService.updateConversationModel(
            id: queuedMessage.conversationId,
            modelId: queuedMessage.model.id,
            provider: queuedMessage.model.provider
        )

        let assistantId = assistantMsg.id
        startStreaming(
            assistantMessageId: assistantId,
            conversationId: queuedMessage.conversationId,
            model: queuedMessage.model
        )
    }

    private func updateMessage(id: String, content: String, isStreaming: Bool) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index] = messages[index].updated(content: content, isStreaming: isStreaming)
    }

    private func startStreaming(assistantMessageId: String, conversationId: String, model: AIModel) {
        streamingTask?.cancel()
        streamingTask = nil

        // Single source of truth: activeStream is always set here
        activeStream = ActiveStream(
            assistantMessageId: assistantMessageId,
            conversationId: conversationId,
            content: ""
        )

        let currentMessages = messages.filter { $0.id != assistantMessageId }

        var attachmentMap: [String: (data: Data, mimeType: String, fileType: String)] = [:]
        for msg in currentMessages {
            for att in msg.attachments ?? [] {
                if let url = att.url, let data = localAttachmentService.loadData(localPath: url) {
                    attachmentMap[att.id] = (data: data, mimeType: att.mimeType, fileType: att.fileType)
                }
            }
        }

        streamingTask = Task {
            do {
                guard let apiKey = keychainService.apiKey(for: model.provider)?.trimmingCharacters(in: .whitespacesAndNewlines), !apiKey.isEmpty else {
                    let errorContent = "Error: No API key configured for \(model.provider)."
                    self.errorMessage = StreamingError.noAPIKey(model.provider).localizedDescription
                    self.dataService.finishStreaming(id: assistantMessageId, content: errorContent)
                    self.updateMessage(id: assistantMessageId, content: errorContent, isStreaming: false)
                    self.cleanupStreamState()
                    // Non-recoverable: clear the entire queue
                    self.queuedMessages.removeAll()
                    return
                }

                let stream = streamingService.streamResponse(
                    messages: currentMessages,
                    attachments: attachmentMap,
                    model: model,
                    apiKey: apiKey
                )

                var fullContent = ""
                var lastPersistTime = Date()

                for try await chunk in stream {
                    guard !Task.isCancelled else { return }

                    fullContent += chunk
                    self.activeStream?.content = fullContent
                    self.updateMessage(id: assistantMessageId, content: fullContent, isStreaming: true)

                    let now = Date()
                    if now.timeIntervalSince(lastPersistTime) >= 0.5 {
                        self.dataService.updateMessageContent(id: assistantMessageId, content: fullContent)
                        lastPersistTime = now
                    }
                }

                guard !Task.isCancelled else { return }

                self.dataService.finishStreaming(id: assistantMessageId, content: fullContent)
                self.updateMessage(id: assistantMessageId, content: fullContent, isStreaming: false)
                self.errorMessage = nil
                self.cleanupStreamState()
                self.processNextQueuedMessage()
            } catch {
                guard !Task.isCancelled else { return }

                let errorContent = "Error: \(error.localizedDescription)"
                self.dataService.finishStreaming(id: assistantMessageId, content: errorContent)
                self.errorMessage = error.localizedDescription
                self.updateMessage(id: assistantMessageId, content: errorContent, isStreaming: false)
                self.cleanupStreamState()

                // Only continue queue for recoverable errors; clear queue on auth/config failures
                if let streamingError = error as? StreamingError, !streamingError.isRecoverable {
                    self.queuedMessages.removeAll()
                } else {
                    self.processNextQueuedMessage()
                }
            }
        }
    }

    /// Clears the streaming task and active stream state. Call after streaming ends
    /// (success, error, or cancellation) to prevent stale state.
    private func cleanupStreamState() {
        streamingTask = nil
        activeStream = nil
    }

    private func cancelStreaming(finalizeCurrentMessage: Bool, continueQueue: Bool) {
        if finalizeCurrentMessage, let activeStream {
            dataService.finishStreaming(id: activeStream.assistantMessageId, content: activeStream.content)
            updateMessage(
                id: activeStream.assistantMessageId,
                content: activeStream.content,
                isStreaming: false
            )
        }

        streamingTask?.cancel()
        cleanupStreamState()

        if continueQueue {
            processNextQueuedMessage()
        }
    }

    private func processNextQueuedMessage() {
        // Guard: don't start a new stream if one is already running
        guard streamingTask == nil, !queuedMessages.isEmpty else {
            return
        }

        // Only process messages for the currently active conversation.
        // If the user navigated away, discard stale queued messages silently.
        while let next = queuedMessages.first {
            queuedMessages.removeFirst()
            if next.conversationId == activeConversationId {
                sendNow(next)
                return
            }
        }
    }

    private func scheduleErrorDismissal(for message: String?) {
        errorDismissTask?.cancel()
        errorDismissTask = nil

        guard let message else { return }

        errorDismissTask = Task { [weak self] in
            do {
                try await Task.sleep(for: errorDismissalInterval)
            } catch {
                return
            }

            guard !Task.isCancelled, self?.errorMessage == message else {
                return
            }

            self?.errorMessage = nil
        }
    }
}
