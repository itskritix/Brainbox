import Foundation
import SwiftData

@Model
final class SDMessage {
    #Index<SDMessage>([\.createdAt])

    @Attribute(.unique) var id: UUID
    var conversation: SDConversation?
    var role: String
    var content: String
    var modelIdentifier: String?
    var providerName: String?
    var isStreaming: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \SDAttachment.message)
    var attachments: [SDAttachment] = []

    init(
        id: UUID = UUID(),
        conversation: SDConversation? = nil,
        role: String,
        content: String,
        modelIdentifier: String? = nil,
        providerName: String? = nil,
        isStreaming: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.conversation = conversation
        self.role = role
        self.content = content
        self.modelIdentifier = modelIdentifier
        self.providerName = providerName
        self.isStreaming = isStreaming
        self.createdAt = createdAt
    }
}
