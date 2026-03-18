import Foundation

@MainActor
class LocalAttachmentService {
    private static var baseDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Brainbox/Attachments", isDirectory: true)
    }

    func save(attachment: PendingAttachment, conversationId: String) throws -> (localPath: String, attachmentId: String) {
        let id = UUID()
        let ext = fileExtension(for: attachment.mimeType)
        let dir = Self.baseDirectory.appendingPathComponent(conversationId, isDirectory: true)

        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let fileName = "\(id.uuidString).\(ext)"
        let fileURL = dir.appendingPathComponent(fileName)
        try attachment.data.write(to: fileURL)

        return (localPath: fileURL.path, attachmentId: id.uuidString)
    }

    func loadData(localPath: String) -> Data? {
        let url = URL(fileURLWithPath: localPath)
        return try? Data(contentsOf: url)
    }

    func fileURL(localPath: String) -> URL {
        URL(fileURLWithPath: localPath)
    }

    func deleteAttachments(conversationId: String) {
        let dir = Self.baseDirectory.appendingPathComponent(conversationId, isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
    }

    private func fileExtension(for mimeType: String) -> String {
        switch mimeType {
        case "image/jpeg": return "jpg"
        case "image/png": return "png"
        case "image/gif": return "gif"
        case "image/webp": return "webp"
        case "application/pdf": return "pdf"
        default: return "bin"
        }
    }
}
