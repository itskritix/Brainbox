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
        case saved(attachmentId: String, localPath: String)
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

/// Lightweight metadata passed through the send chain so SwiftData can create SDAttachment records.
struct AttachmentInfo: Equatable {
    let attachmentId: String
    let fileName: String
    let fileType: String
    let mimeType: String
    let fileSize: Int
    let width: Int?
    let height: Int?
    let localPath: String
}
