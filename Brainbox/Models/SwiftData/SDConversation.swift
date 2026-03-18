import Foundation
import SwiftData

@Model
final class SDConversation {
    @Attribute(.unique) var id: UUID
    var profileId: UUID?
    var title: String
    var lastModelUsed: String?
    var lastProviderUsed: String?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \SDMessage.conversation)
    var messages: [SDMessage] = []

    @Relationship(deleteRule: .cascade, inverse: \SDAttachment.conversation)
    var attachments: [SDAttachment] = []

    init(
        id: UUID = UUID(),
        profileId: UUID? = nil,
        title: String = "New Chat",
        lastModelUsed: String? = nil,
        lastProviderUsed: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.profileId = profileId
        self.title = title
        self.lastModelUsed = lastModelUsed
        self.lastProviderUsed = lastProviderUsed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
