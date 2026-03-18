import Foundation
import AppKit
import UniformTypeIdentifiers

class AttachmentService {
    static let allowedImageTypes: Set<String> = [
        "image/jpeg", "image/png", "image/gif", "image/webp"
    ]
    static let allowedPDFTypes: Set<String> = ["application/pdf"]
    static let maxImageSize = 10 * 1024 * 1024      // 10MB
    static let maxPDFSize = 20 * 1024 * 1024         // 20MB
    static let maxImageDimension: CGFloat = 2048
    static let compressionQuality: CGFloat = 0.85
    static let thumbnailSize: CGFloat = 120
    static let maxAttachmentsPerMessage = 5

    // MARK: - File Processing

    func processFile(url: URL) throws -> PendingAttachment {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        let fileName = url.lastPathComponent
        let fileMimeType = self.mimeType(for: url)
        let fileType = Self.allowedPDFTypes.contains(fileMimeType)
            ? AttachmentFileType.pdf
            : AttachmentFileType.image

        try validate(data: data, fileType: fileType, mimeType: fileMimeType)

        if fileType == .image {
            return processImageData(data, fileName: fileName, mimeType: fileMimeType)
        } else {
            return PendingAttachment(
                fileName: fileName,
                fileType: .pdf,
                mimeType: fileMimeType,
                data: data,
                thumbnail: nil,
                fileSize: data.count,
                width: nil,
                height: nil
            )
        }
    }

    func processImageFromPasteboard(_ image: NSImage) throws -> PendingAttachment {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: Self.compressionQuality]) else {
            throw AttachmentError.invalidImageData
        }

        return processImageData(jpegData, fileName: "Pasted Image.jpg", mimeType: "image/jpeg")
    }

    private func processImageData(_ data: Data, fileName: String, mimeType: String) -> PendingAttachment {
        let image = NSImage(data: data)
        let size = image?.size ?? .zero

        // Compress/resize if needed
        let processedData: Data
        let finalWidth: Int
        let finalHeight: Int

        if let img = image, max(size.width, size.height) > Self.maxImageDimension {
            let (resized, newSize) = resizeImage(img, maxDimension: Self.maxImageDimension)
            processedData = resized
            finalWidth = Int(newSize.width)
            finalHeight = Int(newSize.height)
        } else if mimeType == "image/jpeg" {
            processedData = data
            finalWidth = Int(size.width)
            finalHeight = Int(size.height)
        } else if let img = image {
            // Convert non-JPEG to JPEG for compression
            processedData = compressToJPEG(img) ?? data
            finalWidth = Int(size.width)
            finalHeight = Int(size.height)
        } else {
            processedData = data
            finalWidth = Int(size.width)
            finalHeight = Int(size.height)
        }

        // Generate thumbnail
        let thumbnail = image.flatMap { generateThumbnail($0) }

        return PendingAttachment(
            fileName: fileName,
            fileType: .image,
            mimeType: "image/jpeg",
            data: processedData,
            thumbnail: thumbnail,
            fileSize: processedData.count,
            width: finalWidth,
            height: finalHeight
        )
    }

    // MARK: - Validation

    private func validate(data: Data, fileType: AttachmentFileType, mimeType: String) throws {
        let allAllowed = Self.allowedImageTypes.union(Self.allowedPDFTypes)
        guard allAllowed.contains(mimeType) else {
            throw AttachmentError.unsupportedFileType(mimeType)
        }

        let maxSize = fileType == .image ? Self.maxImageSize : Self.maxPDFSize
        guard data.count <= maxSize else {
            throw AttachmentError.fileTooLarge(maxMB: maxSize / (1024 * 1024))
        }
    }

    // MARK: - Image Processing

    private func resizeImage(_ image: NSImage, maxDimension: CGFloat) -> (Data, NSSize) {
        let size = image.size
        let ratio = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        let newSize = NSSize(width: size.width * ratio, height: size.height * ratio)

        let resized = NSImage(size: newSize)
        resized.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )
        resized.unlockFocus()

        let data = compressToJPEG(resized) ?? Data()
        return (data, newSize)
    }

    private func compressToJPEG(_ image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: Self.compressionQuality]
        )
    }

    private func generateThumbnail(_ image: NSImage) -> NSImage {
        let size = image.size
        let ratio = min(Self.thumbnailSize / size.width, Self.thumbnailSize / size.height, 1.0)
        let thumbSize = NSSize(width: size.width * ratio, height: size.height * ratio)

        let thumb = NSImage(size: thumbSize)
        thumb.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: thumbSize),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )
        thumb.unlockFocus()
        return thumb
    }

    // MARK: - Helpers

    private func mimeType(for url: URL) -> String {
        if let utType = UTType(filenameExtension: url.pathExtension) {
            if utType.conforms(to: .jpeg) { return "image/jpeg" }
            if utType.conforms(to: .png) { return "image/png" }
            if utType.conforms(to: .gif) { return "image/gif" }
            if utType.conforms(to: .webP) { return "image/webp" }
            if utType.conforms(to: .pdf) { return "application/pdf" }
        }
        return "application/octet-stream"
    }
}

enum AttachmentError: LocalizedError {
    case unsupportedFileType(String)
    case fileTooLarge(maxMB: Int)
    case invalidImageData
    case tooManyAttachments

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType(let type):
            return "Unsupported file type: \(type). Use JPEG, PNG, GIF, WebP, or PDF."
        case .fileTooLarge(let maxMB):
            return "File too large. Maximum size is \(maxMB)MB."
        case .invalidImageData:
            return "Could not process image data."
        case .tooManyAttachments:
            return "Maximum \(AttachmentService.maxAttachmentsPerMessage) attachments per message."
        }
    }
}
