import Foundation

@MainActor
protocol DataServiceProtocol {
    // MARK: - Conversations
    func fetchConversations(profileId: String?) -> [Conversation]
    func fetchArchivedConversations(profileId: String?) -> [Conversation]
    func createConversation(title: String?, profileId: String?) -> Conversation
    func deleteConversation(id: String)
    func renameConversation(id: String, title: String)
    func archiveConversation(id: String)
    func unarchiveConversation(id: String)
    func updateConversationModel(id: String, modelId: String, provider: String)

    // MARK: - Messages
    func fetchMessages(conversationId: String) -> [Message]
    func createMessage(
        conversationId: String,
        role: String,
        content: String,
        modelIdentifier: String?,
        providerName: String?,
        isStreaming: Bool,
        attachments: [AttachmentInfo]
    ) -> Message
    func updateMessageContent(id: String, content: String)
    func finishStreaming(id: String, content: String)
    func deleteMessage(id: String)

    // MARK: - Profiles
    func fetchProfiles() -> [Profile]
    func createProfile(name: String, emoji: String) -> Profile
    func deleteProfile(id: String)
    func renameProfile(id: String, name: String)

    // MARK: - Attachments
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
    ) -> MessageAttachment
    func fetchAttachments(messageId: String) -> [MessageAttachment]
    func deleteAttachments(conversationId: String)

    // MARK: - Branch
    func branchConversation(fromMessageId: String, conversationId: String) -> String?

    // MARK: - Auto-title
    func autoTitleConversation(id: String, firstMessageContent: String)
}
