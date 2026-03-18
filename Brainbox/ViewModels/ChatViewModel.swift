import Foundation

@Observable
class ChatViewModel {
    var messages: [Message] = []
    var isLoading = false
    var errorMessage: String?
    var availableModels: [AIModel] = defaultModels
    var selectedModel: AIModel = defaultModels[0] {
        didSet {
            if oldValue.id != selectedModel.id {
                UserDefaults.standard.set(selectedModel.id, forKey: UDKey.selectedModelId)
            }
        }
    }

    private(set) var activeConversationId: String?
    private var streamingTask: Task<Void, Never>?
    private let dataService: DataServiceProtocol
    private let streamingService = StreamingService()
    private let keychainService: KeychainService
    private let localAttachmentService = LocalAttachmentService()

    init(dataService: DataServiceProtocol, keychainService: KeychainService) {
        self.dataService = dataService
        self.keychainService = keychainService
    }

    var isAssistantStreaming: Bool {
        messages.last?.isAssistant == true && messages.last?.isStreaming == true
    }

    func loadConversation(_ conversationId: String, initialMessages: [Message] = []) {
        if activeConversationId == conversationId {
            return
        }

        streamingTask?.cancel()
        streamingTask = nil
        activeConversationId = conversationId

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

    func send(content: String, conversationId: String, attachmentIds: [String] = []) {
        let userMsg = dataService.createMessage(
            conversationId: conversationId,
            role: "user",
            content: content,
            modelIdentifier: nil,
            providerName: nil,
            isStreaming: false,
            attachmentIds: attachmentIds
        )
        messages.append(userMsg)

        if messages.count == 1 {
            dataService.autoTitleConversation(id: conversationId, firstMessageContent: content)
        }

        let assistantMsg = dataService.createMessage(
            conversationId: conversationId,
            role: "assistant",
            content: "",
            modelIdentifier: selectedModel.id,
            providerName: selectedModel.provider,
            isStreaming: true,
            attachmentIds: []
        )
        messages.append(assistantMsg)

        dataService.updateConversationModel(
            id: conversationId,
            modelId: selectedModel.id,
            provider: selectedModel.provider
        )

        let assistantId = assistantMsg.id
        startStreaming(assistantMessageId: assistantId, conversationId: conversationId)
    }

    func regenerate(messageId: String, conversationId: String) {
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

        startStreaming(assistantMessageId: messageId, conversationId: conversationId)
    }

    func branch(fromMessageId messageId: String, conversationId: String) async -> String? {
        return dataService.branchConversation(fromMessageId: messageId, conversationId: conversationId)
    }

    func unsubscribeMessages() {
        streamingTask?.cancel()
        streamingTask = nil
        activeConversationId = nil
        messages = []
        isLoading = false
    }

    func refreshMessages() {
        guard let conversationId = activeConversationId else { return }
        messages = dataService.fetchMessages(conversationId: conversationId)
    }

    private func updateMessage(id: String, content: String, isStreaming: Bool) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index] = messages[index].updated(content: content, isStreaming: isStreaming)
    }

    private func startStreaming(assistantMessageId: String, conversationId: String) {
        streamingTask?.cancel()

        let model = selectedModel
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
                    self.errorMessage = StreamingError.noAPIKey(model.provider).localizedDescription
                    self.dataService.finishStreaming(id: assistantMessageId, content: "Error: No API key configured.")
                    self.refreshMessages()
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
            } catch {
                guard !Task.isCancelled else { return }

                let errorContent = "Error: \(error.localizedDescription)"
                self.dataService.finishStreaming(id: assistantMessageId, content: errorContent)
                self.errorMessage = error.localizedDescription
                self.updateMessage(id: assistantMessageId, content: errorContent, isStreaming: false)
            }
        }
    }
}
