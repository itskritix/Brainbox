import XCTest
@testable import Brainbox

final class BrainboxTests: XCTestCase {

    // MARK: - Message Model Tests

    func testMessageInitFromSwiftData() throws {
        let sd = SDMessage(
            role: "user",
            content: "Hello",
            modelIdentifier: "gpt-4o",
            providerName: "openai",
            isStreaming: false
        )
        let msg = Message(from: sd)

        XCTAssertEqual(msg.role, "user")
        XCTAssertEqual(msg.content, "Hello")
        XCTAssertEqual(msg.modelIdentifier, "gpt-4o")
        XCTAssertEqual(msg.providerName, "openai")
        XCTAssertFalse(msg.isStreaming)
        XCTAssertTrue(msg.isUser)
        XCTAssertFalse(msg.isAssistant)
    }

    func testMessageUpdated() throws {
        let msg = Message(
            _id: "test-1",
            conversationId: "conv-1",
            role: "assistant",
            content: "Hello",
            isStreaming: true,
            createdAt: 1000
        )

        let updated = msg.updated(content: "Hello world", isStreaming: false)

        XCTAssertEqual(updated.id, "test-1")
        XCTAssertEqual(updated.content, "Hello world")
        XCTAssertFalse(updated.isStreaming)
        XCTAssertEqual(updated.createdAt, 1000)
    }

    // MARK: - Conversation Model Tests

    func testConversationInitFromSwiftData() throws {
        let sd = SDConversation(title: "Test Chat")
        let conv = Conversation(from: sd)

        XCTAssertEqual(conv.title, "Test Chat")
        XCTAssertFalse(conv.id.isEmpty)
        XCTAssertNil(conv.profileId)
    }

    // MARK: - Profile Model Tests

    func testProfileInitFromSwiftData() throws {
        let sd = SDProfile(name: "Work", emoji: "briefcase.fill")
        let profile = Profile(from: sd)

        XCTAssertEqual(profile.name, "Work")
        XCTAssertEqual(profile.emoji, "briefcase.fill")
        XCTAssertFalse(profile.id.isEmpty)
    }

    // MARK: - Attachment Model Tests

    func testAttachmentInitFromSwiftData() throws {
        let sd = SDAttachment(
            fileName: "photo.jpg",
            fileType: "image",
            mimeType: "image/jpeg",
            fileSize: 1024,
            width: 800,
            height: 600,
            localPath: "/tmp/photo.jpg"
        )
        let att = MessageAttachment(from: sd)

        XCTAssertEqual(att.fileName, "photo.jpg")
        XCTAssertEqual(att.fileType, "image")
        XCTAssertEqual(att.mimeType, "image/jpeg")
        XCTAssertEqual(att.fileSize, 1024)
        XCTAssertEqual(att.width, 800)
        XCTAssertEqual(att.height, 600)
        XCTAssertEqual(att.url, "/tmp/photo.jpg")
        XCTAssertTrue(att.isImage)
        XCTAssertFalse(att.isPDF)
    }

    // MARK: - SSE Parser Tests

    func testSSEParserOpenAIText() throws {
        let parser = SSEParser(type: .openAI)
        let line = "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}"
        let event = parser.parse(line: line)

        if case .text(let text) = event {
            XCTAssertEqual(text, "Hello")
        } else {
            XCTFail("Expected .text event, got \(String(describing: event))")
        }
    }

    func testSSEParserOpenAIDone() throws {
        let parser = SSEParser(type: .openAI)
        let event = parser.parse(line: "data: [DONE]")

        if case .done = event {
            // pass
        } else {
            XCTFail("Expected .done event, got \(String(describing: event))")
        }
    }

    func testSSEParserOpenAIEmptyLine() throws {
        let parser = SSEParser(type: .openAI)
        XCTAssertNil(parser.parse(line: ""))
        XCTAssertNil(parser.parse(line: ": comment"))
    }

    func testSSEParserAnthropicText() throws {
        let parser = SSEParser(type: .anthropic)
        let line = "data: {\"type\":\"content_block_delta\",\"delta\":{\"text\":\"World\"}}"
        let event = parser.parse(line: line)

        if case .text(let text) = event {
            XCTAssertEqual(text, "World")
        } else {
            XCTFail("Expected .text event, got \(String(describing: event))")
        }
    }

    func testSSEParserAnthropicDone() throws {
        let parser = SSEParser(type: .anthropic)
        let line = "data: {\"type\":\"message_stop\"}"
        let event = parser.parse(line: line)

        if case .done = event {
            // pass
        } else {
            XCTFail("Expected .done event, got \(String(describing: event))")
        }
    }

    func testSSEParserGoogleText() throws {
        let parser = SSEParser(type: .google)
        let line = "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"Hi there\"}]}}]}"
        let event = parser.parse(line: line)

        if case .text(let text) = event {
            XCTAssertEqual(text, "Hi there")
        } else {
            XCTFail("Expected .text event, got \(String(describing: event))")
        }
    }

    func testSSEParserErrorResponse() throws {
        let parser = SSEParser(type: .openAI)
        let line = "data: {\"error\":{\"message\":\"Rate limit exceeded\"}}"
        let event = parser.parse(line: line)

        if case .error(let msg) = event {
            XCTAssertEqual(msg, "Rate limit exceeded")
        } else {
            XCTFail("Expected .error event, got \(String(describing: event))")
        }
    }

    // MARK: - AIModel Tests

    func testAIModelVisionSupport() throws {
        let openai = AIModel(id: "gpt-4o", name: "GPT-4o", provider: "openai", providerName: "OpenAI")
        XCTAssertTrue(openai.supportsVision)
        XCTAssertTrue(openai.supportsPDF)

        let deepseek = AIModel(id: "deepseek-chat", name: "DeepSeek V3", provider: "deepseek", providerName: "DeepSeek")
        XCTAssertFalse(deepseek.supportsVision)
        XCTAssertFalse(deepseek.supportsPDF)

        let mistral = AIModel(id: "mistral-large-latest", name: "Mistral Large", provider: "mistral", providerName: "Mistral")
        XCTAssertTrue(mistral.supportsVision)
        XCTAssertFalse(mistral.supportsPDF)
    }

    // MARK: - PendingAttachment SavedState Tests

    func testSavedStateIsSaved() throws {
        let saved = PendingAttachment.SavedState.saved(attachmentId: "abc", localPath: "/tmp/test.png")
        XCTAssertTrue(saved.isSaved)

        let pending = PendingAttachment.SavedState.pending
        XCTAssertFalse(pending.isSaved)

        let failed = PendingAttachment.SavedState.failed(error: "err")
        XCTAssertFalse(failed.isSaved)
    }

    // MARK: - Default Models Tests

    func testDefaultModelsNotEmpty() throws {
        XCTAssertFalse(defaultModels.isEmpty)
        XCTAssertTrue(defaultModels.count > 30)
    }

    func testDefaultModelsHaveAllProviders() throws {
        let providers = Set(defaultModels.map(\.provider))
        XCTAssertTrue(providers.contains("openai"))
        XCTAssertTrue(providers.contains("anthropic"))
        XCTAssertTrue(providers.contains("google"))
        XCTAssertTrue(providers.contains("mistral"))
        XCTAssertTrue(providers.contains("xai"))
        XCTAssertTrue(providers.contains("deepseek"))
        XCTAssertTrue(providers.contains("groq"))
    }

    // MARK: - Streaming Error Tests

    func testStreamingErrorDescriptions() throws {
        let noKey = StreamingError.noAPIKey("openai")
        XCTAssertTrue(noKey.localizedDescription.contains("OpenAI"))

        let apiErr = StreamingError.apiError(statusCode: 429, message: "Rate limited")
        XCTAssertTrue(apiErr.localizedDescription.contains("429"))
        XCTAssertTrue(apiErr.localizedDescription.contains("Rate limited"))
    }

    func testLocalPromptMessagesKeepsFullPriorHistory() throws {
        let messages = [
            testMessage(role: "user", content: "my name is Ganesh", offset: 0),
            testMessage(role: "assistant", content: "Nice to meet you.", offset: 1),
            testMessage(role: "user", content: "latest", offset: 2),
        ]

        let promptMessages = LocalModelService.localPromptMessages(from: messages)

        XCTAssertEqual(promptMessages.map(\.content), ["my name is Ganesh", "Nice to meet you.", "latest"])
    }

    func testLocalPromptMessagesIgnoresMessagesAfterLatestUser() throws {
        let messages = (0..<8).map {
            testMessage(role: $0.isMultiple(of: 2) ? "user" : "assistant", content: "message-\($0)", offset: $0)
        } + [
            testMessage(role: "user", content: "latest", offset: 8),
            testMessage(role: "assistant", content: "draft response", offset: 9),
        ]

        let promptMessages = LocalModelService.localPromptMessages(from: messages)

        XCTAssertEqual(promptMessages.last?.content, "latest")
        XCTAssertFalse(promptMessages.contains { $0.content == "draft response" })
    }

    @MainActor
    func testChatViewModelAutoDismissesErrorMessage() async throws {
        let viewModel = ChatViewModel(
            dataService: TestDataService(),
            keychainService: TestKeychainService(),
            localModelService: LocalModelService(),
            errorDismissalInterval: .milliseconds(50)
        )

        viewModel.errorMessage = "Temporary error"
        XCTAssertEqual(viewModel.errorMessage, "Temporary error")

        try await Task.sleep(for: .milliseconds(120))

        XCTAssertNil(viewModel.errorMessage)
    }

    private func testMessage(role: String, content: String, offset: Int) -> Message {
        Message(
            _id: "message-\(offset)",
            conversationId: "conversation-1",
            role: role,
            content: content,
            createdAt: Double(offset)
        )
    }
}

@MainActor
private final class TestDataService: DataServiceProtocol {
    func fetchConversations(profileId: String?) -> [Conversation] { [] }
    func fetchArchivedConversations(profileId: String?) -> [Conversation] { [] }
    func createConversation(title: String?, profileId: String?) -> Conversation {
        let now = Date().timeIntervalSince1970 * 1000
        return Conversation(_id: UUID().uuidString, profileId: profileId, title: title ?? "Test", createdAt: now, updatedAt: now)
    }
    func deleteConversation(id: String) {}
    func renameConversation(id: String, title: String) {}
    func archiveConversation(id: String) {}
    func unarchiveConversation(id: String) {}
    func updateConversationModel(id: String, modelId: String, provider: String) {}
    func fetchMessages(conversationId: String) -> [Message] { [] }
    func createMessage(
        conversationId: String,
        role: String,
        content: String,
        modelIdentifier: String?,
        providerName: String?,
        isStreaming: Bool,
        attachments: [AttachmentInfo]
    ) -> Message {
        Message(
            _id: UUID().uuidString,
            conversationId: conversationId,
            role: role,
            content: content,
            modelIdentifier: modelIdentifier,
            providerName: providerName,
            isStreaming: isStreaming,
            attachments: attachments.map {
                MessageAttachment(
                    _id: $0.attachmentId,
                    fileName: $0.fileName,
                    fileType: $0.fileType,
                    mimeType: $0.mimeType,
                    fileSize: Double($0.fileSize),
                    width: $0.width.map(Double.init),
                    height: $0.height.map(Double.init),
                    url: $0.localPath
                )
            },
            createdAt: Date().timeIntervalSince1970 * 1000
        )
    }
    func updateMessageContent(id: String, content: String) {}
    func finishStreaming(id: String, content: String) {}
    func deleteMessage(id: String) {}
    func fetchProfiles() -> [Profile] { [] }
    func createProfile(name: String, emoji: String) -> Profile {
        let now = Date().timeIntervalSince1970 * 1000
        return Profile(_id: UUID().uuidString, name: name, emoji: emoji, createdAt: now, updatedAt: now)
    }
    func deleteProfile(id: String) {}
    func renameProfile(id: String, name: String) {}
    func createAttachment(
        conversationId: String,
        messageId: String?,
        fileName: String,
        fileType: String,
        mimeType: String,
        fileSize: Int,
        width: Int?,
        height: Int?,
        localPath: String
    ) -> MessageAttachment {
        MessageAttachment(
            _id: UUID().uuidString,
            fileName: fileName,
            fileType: fileType,
            mimeType: mimeType,
            fileSize: Double(fileSize),
            width: width.map(Double.init),
            height: height.map(Double.init),
            url: localPath
        )
    }
    func fetchAttachments(messageId: String) -> [MessageAttachment] { [] }
    func deleteAttachments(conversationId: String) {}
    func branchConversation(fromMessageId: String, conversationId: String) -> String? { nil }
    func autoTitleConversation(id: String, firstMessageContent: String) {}
}

@MainActor
private final class TestKeychainService: KeychainService {
    override func apiKey(for provider: String) -> String? { nil }
    override var configuredProviders: [String] { [] }
}
