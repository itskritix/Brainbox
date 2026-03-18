import Foundation

struct Profile: Identifiable {
    let _id: String
    let name: String
    let emoji: String
    let createdAt: Double
    let updatedAt: Double

    var id: String { _id }

    init(
        _id: String,
        name: String,
        emoji: String,
        createdAt: Double,
        updatedAt: Double
    ) {
        self._id = _id
        self.name = name
        self.emoji = emoji
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from sd: SDProfile) {
        self._id = sd.id.uuidString
        self.name = sd.name
        self.emoji = sd.emoji
        self.createdAt = sd.createdAt.timeIntervalSince1970 * 1000
        self.updatedAt = sd.updatedAt.timeIntervalSince1970 * 1000
    }
}
