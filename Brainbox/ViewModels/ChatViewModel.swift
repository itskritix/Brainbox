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
                // Auto-unload local model when switching to a different model
                if oldValue.isLocal && !selectedModel.isLocal {
                    localModelService.unloadModel()
                }
            }
        }
    }

    private(set) var activeConversationId: String?
    private var streamingTasks: [String: Task<Void, Never>] = [:]
    private var activeStreams: [String: ActiveStream] = [:]
    private var errorDismissTask: Task<Void, Never>?
    var isLocalModelLoading = false

    private let dataService: DataServiceProtocol
    private let streamingService = StreamingService()
    private let keychainService: KeychainService
    private let localModelService: LocalModelService
    private let localAttachmentService = LocalAttachmentService()
    private let errorDismissalInterval: Duration
    private static let streamingUIUpdateInterval: TimeInterval = 1.0 / 15.0

    init(
        dataService: DataServiceProtocol,
        keychainService: KeychainService,
        localModelService: LocalModelService,
        errorDismissalInterval: Duration = .seconds(15)
    ) {
        self.dataService = dataService
        self.keychainService = keychainService
        self.localModelService = localModelService
        self.errorDismissalInterval = errorDismissalInterval
    }

    /// Whether the assistant is currently streaming a response for the active conversation.
    var isAssistantStreaming: Bool {
        guard let id = activeConversationId else { return false }
        return streamingTasks[id] != nil || (messages.last?.isAssistant == true && messages.last?.isStreaming == true)
    }

    /// Conversation IDs that currently have an active streaming task (for sidebar indicators).
    var streamingConversationIds: Set<String> {
        Set(streamingTasks.keys)
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

        // Don't cancel background streams — let them continue running.
        // Just discard queued messages for the old conversation.
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

        // Always append downloaded local models regardless of API key configuration
        let localModels = localModelService.downloadedModels.map {
            AIModel.localModel(id: $0.id, name: $0.displayName)
        }
        availableModels.append(contentsOf: localModels)

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
        guard let id = activeConversationId else { return }
        cancelStreaming(conversationId: id, finalizeCurrentMessage: true, continueQueue: true)
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
        cancelStreaming(conversationId: conversationId, finalizeCurrentMessage: true, continueQueue: false)

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

    /// Edits a user message in place: truncates everything after it, updates content, and re-sends.
    func editAndResend(messageId: String, newContent: String, conversationId: String) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }),
              messages[index].isUser else { return }
        cancelStreaming(conversationId: conversationId, finalizeCurrentMessage: false, continueQueue: false)

        // Delete all messages after the edited one
        let afterIndex = messages.index(after: index)
        if afterIndex < messages.endIndex {
            let removed = messages[afterIndex...]
            messages.removeSubrange(afterIndex...)
            for msg in removed {
                dataService.deleteMessage(id: msg.id)
            }
        }

        // Update the user message content
        dataService.updateMessageContent(id: messageId, content: newContent)
        messages[index] = messages[index].updated(content: newContent, isStreaming: false)

        // Create a new assistant message and stream the response
        let assistantMsg = dataService.createMessage(
            conversationId: conversationId,
            role: "assistant",
            content: "",
            modelIdentifier: selectedModel.id,
            providerName: selectedModel.provider,
            isStreaming: true,
            attachments: []
        )
        messages.append(assistantMsg)

        startStreaming(
            assistantMessageId: assistantMsg.id,
            conversationId: conversationId,
            model: selectedModel
        )
    }

    func branch(fromMessageId messageId: String, conversationId: String) async -> String? {
        return dataService.branchConversation(fromMessageId: messageId, conversationId: conversationId)
    }

    func unsubscribeMessages() {
        // Don't cancel background streams — only clear active conversation state
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
        // Cancel any existing stream for this specific conversation
        streamingTasks[conversationId]?.cancel()
        streamingTasks[conversationId] = nil

        activeStreams[conversationId] = ActiveStream(
            assistantMessageId: assistantMessageId,
            conversationId: conversationId,
            content: ""
        )

        let currentMessages = messages.filter { $0.id != assistantMessageId }

        streamingTasks[conversationId] = Task {
            do {
                let stream: AsyncThrowingStream<String, Error>

                if model.isLocal {
                    if localModelService.loadedModelId != model.id {
                        self.isLocalModelLoading = true
                        defer { self.isLocalModelLoading = false }
                        try await localModelService.loadModel(id: model.id)
                    }
                    stream = localModelService.streamResponse(
                        messages: currentMessages,
                        conversationId: conversationId,
                        modelId: model.id
                    )
                } else {
                    guard let apiKey = keychainService.apiKey(for: model.provider)?.trimmingCharacters(in: .whitespacesAndNewlines), !apiKey.isEmpty else {
                        let errorContent = "Error: No API key configured for \(model.provider)."
                        self.errorMessage = StreamingError.noAPIKey(model.provider).localizedDescription
                        self.dataService.finishStreaming(id: assistantMessageId, content: errorContent)
                        self.updateMessage(id: assistantMessageId, content: errorContent, isStreaming: false)
                        self.cleanupStreamState(for: conversationId)
                        self.queuedMessages.removeAll()
                        return
                    }

                    let attachmentMap = self.attachmentMap(for: currentMessages)
                    stream = streamingService.streamResponse(
                        messages: currentMessages,
                        attachments: attachmentMap,
                        model: model,
                        apiKey: apiKey
                    )
                }

                var fullContent = ""
                var lastUIUpdateTime = Date.distantPast
                var lastPersistTime = Date()

                for try await chunk in stream {
                    guard !Task.isCancelled else { return }

                    fullContent += chunk
                    self.activeStreams[conversationId]?.content = fullContent

                    // Only update in-memory messages if this is the active conversation
                    let now = Date()
                    if conversationId == self.activeConversationId,
                       now.timeIntervalSince(lastUIUpdateTime) >= Self.streamingUIUpdateInterval {
                        self.updateMessage(id: assistantMessageId, content: fullContent, isStreaming: true)
                        lastUIUpdateTime = now
                    }

                    // Always persist to DB so background streams save their progress
                    if now.timeIntervalSince(lastPersistTime) >= 0.5 {
                        self.dataService.updateMessageContent(id: assistantMessageId, content: fullContent)
                        lastPersistTime = now
                    }
                }

                guard !Task.isCancelled else { return }

                self.dataService.finishStreaming(id: assistantMessageId, content: fullContent)
                if conversationId == self.activeConversationId {
                    self.updateMessage(id: assistantMessageId, content: fullContent, isStreaming: false)
                    self.errorMessage = nil
                }
                self.cleanupStreamState(for: conversationId)
                self.processNextQueuedMessage()
            } catch {
                guard !Task.isCancelled else { return }

                let errorContent = "Error: \(error.localizedDescription)"
                self.dataService.finishStreaming(id: assistantMessageId, content: errorContent)
                if conversationId == self.activeConversationId {
                    self.errorMessage = error.localizedDescription
                    self.updateMessage(id: assistantMessageId, content: errorContent, isStreaming: false)
                }
                self.cleanupStreamState(for: conversationId)

                if let streamingError = error as? StreamingError, !streamingError.isRecoverable {
                    self.queuedMessages.removeAll()
                } else {
                    self.processNextQueuedMessage()
                }
            }
        }
    }

    private func attachmentMap(
        for messages: [Message]
    ) -> [String: (data: Data, mimeType: String, fileType: String)] {
        var attachmentMap: [String: (data: Data, mimeType: String, fileType: String)] = [:]
        for msg in messages {
            for att in msg.attachments ?? [] {
                if let url = att.url, let data = localAttachmentService.loadData(localPath: url) {
                    attachmentMap[att.id] = (data: data, mimeType: att.mimeType, fileType: att.fileType)
                }
            }
        }
        return attachmentMap
    }

    /// Clears the streaming task and active stream state for a specific conversation.
    private func cleanupStreamState(for conversationId: String) {
        streamingTasks[conversationId] = nil
        activeStreams[conversationId] = nil
    }

    /// Cancels streaming for a specific conversation.
    private func cancelStreaming(conversationId: String, finalizeCurrentMessage: Bool, continueQueue: Bool) {
        if finalizeCurrentMessage, let stream = activeStreams[conversationId] {
            dataService.finishStreaming(id: stream.assistantMessageId, content: stream.content)
            if conversationId == activeConversationId {
                updateMessage(
                    id: stream.assistantMessageId,
                    content: stream.content,
                    isStreaming: false
                )
            }
        }

        streamingTasks[conversationId]?.cancel()
        cleanupStreamState(for: conversationId)

        if continueQueue {
            processNextQueuedMessage()
        }
    }

    /// Cancels streaming for a given conversation (used when deleting/archiving).
    func cancelBackgroundStream(for conversationId: String) {
        cancelStreaming(conversationId: conversationId, finalizeCurrentMessage: true, continueQueue: false)
    }

    private func processNextQueuedMessage() {
        // Guard: don't start a new stream if the active conversation already has one running
        guard let activeId = activeConversationId,
              streamingTasks[activeId] == nil,
              !queuedMessages.isEmpty else {
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
