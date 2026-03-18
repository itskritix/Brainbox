import Foundation
import SwiftData

@Model
final class SDAttachment {
    @Attribute(.unique) var id: UUID
    var conversation: SDConversation?
    var message: SDMessage?
    var fileName: String
    var fileType: String
    var mimeType: String
    var fileSize: Int
    var width: Int?
    var height: Int?
    var localPath: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        conversation: SDConversation? = nil,
        message: SDMessage? = nil,
        fileName: String,
        fileType: String,
        mimeType: String,
        fileSize: Int,
        width: Int? = nil,
        height: Int? = nil,
        localPath: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.conversation = conversation
        self.message = message
        self.fileName = fileName
        self.fileType = fileType
        self.mimeType = mimeType
        self.fileSize = fileSize
        self.width = width
        self.height = height
        self.localPath = localPath
        self.createdAt = createdAt
    }
}
