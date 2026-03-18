import Foundation
import AppKit

struct PendingAttachment: Identifiable {
    let id = UUID()
    let fileName: String
    let fileType: AttachmentFileType
    let mimeType: String
    let data: Data
    let thumbnail: NSImage?
    let fileSize: Int
    let width: Int?
    let height: Int?

    var savedState: SavedState = .pending

    enum SavedState: Equatable {
        case pending
        case saved(attachmentId: String)
        case failed(error: String)

        var isSaved: Bool {
            if case .saved = self { return true }
            return false
        }
    }
}

enum AttachmentFileType: String {
    case image
    case pdf
}
