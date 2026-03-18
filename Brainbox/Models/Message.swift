import Foundation

struct MessageAttachment: Identifiable, Equatable {
    let _id: String
    let fileName: String
    let fileType: String
    let mimeType: String
    let fileSize: Double?
    let width: Double?
    let height: Double?
    let url: String?

    var id: String { _id }
    var isImage: Bool { fileType == "image" }
    var isPDF: Bool { fileType == "pdf" }

    init(
        _id: String,
        fileName: String,
        fileType: String,
        mimeType: String,
        fileSize: Double? = nil,
        width: Double? = nil,
        height: Double? = nil,
        url: String? = nil
    ) {
        self._id = _id
        self.fileName = fileName
        self.fileType = fileType
        self.mimeType = mimeType
        self.fileSize = fileSize
        self.width = width
        self.height = height
        self.url = url
    }

    init(from sd: SDAttachment) {
        self._id = sd.id.uuidString
        self.fileName = sd.fileName
        self.fileType = sd.fileType
        self.mimeType = sd.mimeType
        self.fileSize = Double(sd.fileSize)
        self.width = sd.width.map { Double($0) }
        self.height = sd.height.map { Double($0) }
        self.url = sd.localPath
    }
}

struct Message: Identifiable, Equatable {
    let _id: String
    let conversationId: String
    let role: String
    let content: String
    let modelIdentifier: String?
    let providerName: String?
    let isStreaming: Bool
    let attachments: [MessageAttachment]?
    let createdAt: Double

    var id: String { _id }
    var isUser: Bool { role == "user" }
    var isAssistant: Bool { role == "assistant" }
    var hasAttachments: Bool { !(attachments ?? []).isEmpty }

    func updated(content: String, isStreaming: Bool, modelIdentifier: String? = nil, providerName: String? = nil) -> Message {
        Message(
            _id: _id,
            conversationId: conversationId,
            role: role,
            content: content,
            modelIdentifier: modelIdentifier ?? self.modelIdentifier,
            providerName: providerName ?? self.providerName,
            isStreaming: isStreaming,
            attachments: attachments,
            createdAt: createdAt
        )
    }

    init(
        _id: String,
        conversationId: String,
        role: String,
        content: String,
        modelIdentifier: String? = nil,
        providerName: String? = nil,
        isStreaming: Bool = false,
        attachments: [MessageAttachment]? = nil,
        createdAt: Double
    ) {
        self._id = _id
        self.conversationId = conversationId
        self.role = role
        self.content = content
        self.modelIdentifier = modelIdentifier
        self.providerName = providerName
        self.isStreaming = isStreaming
        self.attachments = attachments
        self.createdAt = createdAt
    }

    init(from sd: SDMessage) {
        self._id = sd.id.uuidString
        self.conversationId = sd.conversation?.id.uuidString ?? ""
        self.role = sd.role
        self.content = sd.content
        self.modelIdentifier = sd.modelIdentifier
        self.providerName = sd.providerName
        self.isStreaming = sd.isStreaming
        self.attachments = sd.attachments.isEmpty ? nil : sd.attachments.map { MessageAttachment(from: $0) }
        self.createdAt = sd.createdAt.timeIntervalSince1970 * 1000
    }
}
