import Foundation
import SwiftData

@MainActor
final class SwiftDataService: DataServiceProtocol {
    private var context: ModelContext {
        SharedModelContainer.shared.mainContext
    }

    // MARK: - Conversations

    func fetchConversations(profileId: String?) -> [Conversation] {
        let results: [SDConversation]
        if let profileId, let uuid = UUID(uuidString: profileId) {
            let descriptor = FetchDescriptor<SDConversation>(
                predicate: #Predicate { $0.profileId == uuid },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            results = (try? context.fetch(descriptor)) ?? []
        } else {
            let descriptor = FetchDescriptor<SDConversation>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            results = (try? context.fetch(descriptor)) ?? []
        }
        return results.map { Conversation(from: $0) }
    }

    func createConversation(title: String?, profileId: String?) -> Conversation {
        let sd = SDConversation(
            profileId: profileId.flatMap { UUID(uuidString: $0) },
            title: title ?? "New Chat"
        )
        context.insert(sd)
        try? context.save()
        return Conversation(from: sd)
    }

    func deleteConversation(id: String) {
        guard let sd = fetchSDConversation(id: id) else { return }
        LocalAttachmentService().deleteAttachments(conversationId: id)
        context.delete(sd)
        try? context.save()
    }

    func renameConversation(id: String, title: String) {
        guard let sd = fetchSDConversation(id: id) else { return }
        sd.title = title
        sd.updatedAt = Date()
        try? context.save()
    }

    func updateConversationModel(id: String, modelId: String, provider: String) {
        guard let sd = fetchSDConversation(id: id) else { return }
        sd.lastModelUsed = modelId
        sd.lastProviderUsed = provider
        sd.updatedAt = Date()
        try? context.save()
    }

    // MARK: - Messages

    func fetchMessages(conversationId: String) -> [Message] {
        guard let uuid = UUID(uuidString: conversationId) else { return [] }
        let descriptor = FetchDescriptor<SDMessage>(
            predicate: #Predicate { $0.conversation?.id == uuid },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let results = (try? context.fetch(descriptor)) ?? []
        return results.map { Message(from: $0) }
    }

    func createMessage(
        conversationId: String,
        role: String,
        content: String,
        modelIdentifier: String?,
        providerName: String?,
        isStreaming: Bool,
        attachmentIds: [String]
    ) -> Message {
        let conversation = fetchSDConversation(id: conversationId)

        let sd = SDMessage(
            conversation: conversation,
            role: role,
            content: content,
            modelIdentifier: modelIdentifier,
            providerName: providerName,
            isStreaming: isStreaming
        )
        context.insert(sd)

        // Link attachments
        for attachmentId in attachmentIds {
            if let att = fetchSDAttachment(id: attachmentId) {
                att.message = sd
                sd.attachments.append(att)
            }
        }

        // Update conversation timestamp
        conversation?.updatedAt = Date()

        try? context.save()
        return Message(from: sd)
    }

    func updateMessageContent(id: String, content: String) {
        guard let sd = fetchSDMessage(id: id) else { return }
        sd.content = content
        try? context.save()
    }

    func finishStreaming(id: String, content: String) {
        guard let sd = fetchSDMessage(id: id) else { return }
        sd.content = content
        sd.isStreaming = false
        try? context.save()
    }

    func deleteMessage(id: String) {
        guard let sd = fetchSDMessage(id: id) else { return }
        context.delete(sd)
        try? context.save()
    }

    // MARK: - Profiles

    func fetchProfiles() -> [Profile] {
        let descriptor = FetchDescriptor<SDProfile>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let results = (try? context.fetch(descriptor)) ?? []
        return results.map { Profile(from: $0) }
    }

    func createProfile(name: String, emoji: String) -> Profile {
        let sd = SDProfile(name: name, emoji: emoji)
        context.insert(sd)
        try? context.save()
        return Profile(from: sd)
    }

    func deleteProfile(id: String) {
        guard let uuid = UUID(uuidString: id) else { return }
        guard let sd = fetchSDProfile(id: id) else { return }

        // Unlink conversations from this profile
        let descriptor = FetchDescriptor<SDConversation>(
            predicate: #Predicate { $0.profileId == uuid }
        )
        if let conversations = try? context.fetch(descriptor) {
            for conv in conversations {
                conv.profileId = nil
            }
        }
        context.delete(sd)
        try? context.save()
    }

    func renameProfile(id: String, name: String) {
        guard let sd = fetchSDProfile(id: id) else { return }
        sd.name = name
        sd.updatedAt = Date()
        try? context.save()
    }

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
    ) -> MessageAttachment {
        let conversation = fetchSDConversation(id: conversationId)
        let message = messageId.flatMap { fetchSDMessage(id: $0) }

        let sd = SDAttachment(
            conversation: conversation,
            message: message,
            fileName: fileName,
            fileType: fileType,
            mimeType: mimeType,
            fileSize: fileSize,
            width: width,
            height: height,
            localPath: localPath
        )
        context.insert(sd)
        try? context.save()
        return MessageAttachment(from: sd)
    }

    func fetchAttachments(messageId: String) -> [MessageAttachment] {
        guard let uuid = UUID(uuidString: messageId) else { return [] }
        let descriptor = FetchDescriptor<SDAttachment>(
            predicate: #Predicate { $0.message?.id == uuid }
        )
        let results = (try? context.fetch(descriptor)) ?? []
        return results.map { MessageAttachment(from: $0) }
    }

    func deleteAttachments(conversationId: String) {
        guard let uuid = UUID(uuidString: conversationId) else { return }
        let descriptor = FetchDescriptor<SDAttachment>(
            predicate: #Predicate { $0.conversation?.id == uuid }
        )
        if let attachments = try? context.fetch(descriptor) {
            for att in attachments {
                context.delete(att)
            }
        }
        try? context.save()
    }

    // MARK: - Branch

    func branchConversation(fromMessageId: String, conversationId: String) -> String? {
        let messages = fetchMessages(conversationId: conversationId)
        guard let branchIndex = messages.firstIndex(where: { $0.id == fromMessageId }) else {
            return nil
        }

        let messagesToCopy = Array(messages[...branchIndex])
        let original = fetchSDConversation(id: conversationId)

        let newConv = SDConversation(
            profileId: original?.profileId,
            title: original?.title ?? "Branched Chat",
            lastModelUsed: original?.lastModelUsed,
            lastProviderUsed: original?.lastProviderUsed
        )
        context.insert(newConv)

        for msg in messagesToCopy {
            let newMsg = SDMessage(
                conversation: newConv,
                role: msg.role,
                content: msg.content,
                modelIdentifier: msg.modelIdentifier,
                providerName: msg.providerName,
                isStreaming: false,
                createdAt: Date(timeIntervalSince1970: msg.createdAt / 1000)
            )
            context.insert(newMsg)
        }

        try? context.save()
        return newConv.id.uuidString
    }

    // MARK: - Auto-title

    func autoTitleConversation(id: String, firstMessageContent: String) {
        guard let sd = fetchSDConversation(id: id) else { return }
        guard sd.title == "New Chat" else { return }
        let title = String(firstMessageContent.prefix(50))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            sd.title = title
            sd.updatedAt = Date()
            try? context.save()
        }
    }

    // MARK: - Fetch helpers

    private func fetchSDConversation(id: String) -> SDConversation? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        var descriptor = FetchDescriptor<SDConversation>(
            predicate: #Predicate { $0.id == uuid }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private func fetchSDMessage(id: String) -> SDMessage? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        var descriptor = FetchDescriptor<SDMessage>(
            predicate: #Predicate { $0.id == uuid }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private func fetchSDAttachment(id: String) -> SDAttachment? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        var descriptor = FetchDescriptor<SDAttachment>(
            predicate: #Predicate { $0.id == uuid }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private func fetchSDProfile(id: String) -> SDProfile? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        var descriptor = FetchDescriptor<SDProfile>(
            predicate: #Predicate { $0.id == uuid }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}

// MARK: - Shared Model Container

@MainActor
enum SharedModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            SDConversation.self,
            SDMessage.self,
            SDAttachment.self,
            SDProfile.self,
        ])
        let configuration = ModelConfiguration(
            "Brainbox",
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Schema migration failed — delete the old store and retry with a fresh database.
            // This loses existing data but prevents a hard crash on launch.
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let storeURL = appSupport.appendingPathComponent("Brainbox.store")
            for ext in ["", "-wal", "-shm"] {
                let fileURL = storeURL.appendingPathExtension("sqlite\(ext)")
                try? FileManager.default.removeItem(at: fileURL)
            }
            // Also try the default SwiftData naming convention
            let defaultURL = appSupport.appendingPathComponent("default.store")
            for ext in ["", "-wal", "-shm"] {
                let fileURL = defaultURL.appendingPathExtension("sqlite\(ext)")
                try? FileManager.default.removeItem(at: fileURL)
            }
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Failed to create ModelContainer after reset: \(error)")
            }
        }
    }()
}
