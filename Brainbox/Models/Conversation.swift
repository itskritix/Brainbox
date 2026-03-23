import Foundation

struct Conversation: Identifiable {
    let _id: String
    let profileId: String?
    let title: String
    let isArchived: Bool
    let createdAt: Double
    let updatedAt: Double

    var id: String { _id }

    init(
        _id: String,
        profileId: String? = nil,
        title: String,
        isArchived: Bool = false,
        createdAt: Double,
        updatedAt: Double
    ) {
        self._id = _id
        self.profileId = profileId
        self.title = title
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from sd: SDConversation) {
        self._id = sd.id.uuidString
        self.profileId = sd.profileId?.uuidString
        self.title = sd.title
        self.isArchived = sd.isArchived ?? false
        self.createdAt = sd.createdAt.timeIntervalSince1970 * 1000
        self.updatedAt = sd.updatedAt.timeIntervalSince1970 * 1000
    }
}
