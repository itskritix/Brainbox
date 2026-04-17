import Foundation
import MLXLLM
import MLXLMCommon
import HuggingFace
import Tokenizers

// MARK: - Bridge Types for v3 API

struct HuggingFaceDownloader: Downloader {
    private let hubClient: HubClient

    init(hubClient: HubClient = .default) {
        self.hubClient = hubClient
    }

    func download(
        id: String,
        revision: String?,
        matching patterns: [String],
        useLatest: Bool,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> URL {
        guard let repoID = Repo.ID(rawValue: id) else {
            throw NSError(domain: "LocalModelService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid repository ID: \(id)"])
        }
        let revision = revision ?? "main"

        return try await hubClient.downloadSnapshot(
            of: repoID,
            revision: revision,
            matching: patterns,
            progressHandler: { @MainActor progress in
                progressHandler(progress)
            }
        )
    }
}

struct TransformersTokenizerLoader: TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        let upstream = try await AutoTokenizer.from(modelFolder: directory)
        return TransformersTokenizerBridge(upstream)
    }
}

struct TransformersTokenizerBridge: MLXLMCommon.Tokenizer {
    private let upstream: any Tokenizers.Tokenizer

    init(_ upstream: any Tokenizers.Tokenizer) {
        self.upstream = upstream
    }

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        upstream.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        upstream.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? {
        upstream.convertTokenToId(token)
    }

    func convertIdToToken(_ id: Int) -> String? {
        upstream.convertIdToToken(id)
    }

    var bosToken: String? { upstream.bosToken }
    var eosToken: String? { upstream.eosToken }
    var unknownToken: String? { upstream.unknownToken }

    func applyChatTemplate(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        do {
            return try upstream.applyChatTemplate(
                messages: messages, tools: tools, additionalContext: additionalContext)
        } catch Tokenizers.TokenizerError.missingChatTemplate {
            throw MLXLMCommon.TokenizerError.missingChatTemplate
        }
    }
}

// MARK: - Model Info

struct LocalModelInfo: Codable, Identifiable, Hashable {
    let id: String
    let displayName: String
    let downloadedAt: Date
    var sizeBytes: Int64
}

private struct LocalSessionKey: Hashable {
    let conversationId: String
    let modelId: String
}

private struct LocalMessageSnapshot: Equatable {
    let role: String
    let content: String
}

private struct LocalConversationSignature: Equatable {
    let messages: [LocalMessageSnapshot]
}

private final class LocalChatSessionState {
    let conversationId: String
    let modelId: String
    var signature: LocalConversationSignature
    let session: ChatSession
    var lastAccessed: UInt64

    init(conversationId: String, modelId: String, signature: LocalConversationSignature, session: ChatSession, lastAccessed: UInt64) {
        self.conversationId = conversationId
        self.modelId = modelId
        self.signature = signature
        self.session = session
        self.lastAccessed = lastAccessed
    }
}

// MARK: - Local Model Service

@MainActor
@Observable
class LocalModelService {

    // MARK: Published State

    private(set) var downloadedModels: [LocalModelInfo] = []
    private(set) var downloadProgress: [String: Double] = [:]
    private(set) var activeDownloads: Set<String> = []
    private(set) var loadedModelId: String?
    private(set) var errorMessage: String?

    var isModelLoaded: Bool { loadedModelId != nil }

    // MARK: Private

    private var modelContainer: ModelContainer?
    private var downloadTasks: [String: Task<Void, Never>] = [:]
    private var localSessions: [LocalSessionKey: LocalChatSessionState] = [:]
    private var sessionAccessCounter: UInt64 = 0
    private static let maxCachedSessions = 3

    private let registryURL: URL

    private let downloader = HuggingFaceDownloader()
    private let tokenizerLoader = TransformersTokenizerLoader()

    // MARK: Init

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelsDir = appSupport.appending(path: "Brainbox/Models")
        registryURL = modelsDir.appending(path: "registry.json")

        try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        loadRegistry()
    }

    // MARK: - Suggested Models

    static let suggestedModels: [(id: String, name: String, size: String)] = [
        ("mlx-community/gemma-4-e2b-it-4bit", "Gemma 4 E2B", "~3.6 GB"),
        ("mlx-community/gemma-4-e4b-it-4bit", "Gemma 4 E4B", "~5.2 GB"),
        ("mlx-community/Qwen3-4B-4bit", "Qwen3 4B", "~2.5 GB"),
        ("mlx-community/Llama-3.2-3B-Instruct-4bit", "Llama 3.2 3B", "~1.8 GB"),
        ("mlx-community/gemma-2-2b-it-4bit", "Gemma 2 2B", "~1.5 GB"),
        ("mlx-community/Mistral-7B-Instruct-v0.3-4bit", "Mistral 7B", "~4 GB"),
        ("mlx-community/Phi-4-mini-instruct-4bit", "Phi-4 Mini", "~2.4 GB"),
    ]

    private static let modelAliases: [String: String] = [
        "gema 4": "mlx-community/gemma-4-e2b-it-4bit",
        "gema-4": "mlx-community/gemma-4-e2b-it-4bit",
        "gemma 4": "mlx-community/gemma-4-e2b-it-4bit",
        "gemma-4": "mlx-community/gemma-4-e2b-it-4bit",
        "gemma 4 e2b": "mlx-community/gemma-4-e2b-it-4bit",
        "gemma-4-e2b": "mlx-community/gemma-4-e2b-it-4bit",
        "gemma 4 e4b": "mlx-community/gemma-4-e4b-it-4bit",
        "gemma-4-e4b": "mlx-community/gemma-4-e4b-it-4bit",
        "google/gemma-4-e2b-it": "mlx-community/gemma-4-e2b-it-4bit",
        "google/gemma-4-e4b-it": "mlx-community/gemma-4-e4b-it-4bit",
    ]

    nonisolated static func resolvedModelId(for input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()
        return modelAliases[normalized] ?? trimmed
    }

    private static func displayName(for modelId: String, fallback: String) -> String {
        suggestedModels.first(where: { $0.id == modelId })?.name ?? fallback
    }

    // MARK: - Download

    func downloadModel(id: String, displayName: String) {
        let id = Self.resolvedModelId(for: id)
        let displayName = Self.displayName(for: id, fallback: displayName)

        guard !activeDownloads.contains(id) else { return }
        guard !downloadedModels.contains(where: { $0.id == id }) else { return }

        activeDownloads.insert(id)
        downloadProgress[id] = 0

        let task = Task {
            defer {
                activeDownloads.remove(id)
                downloadProgress.removeValue(forKey: id)
                downloadTasks.removeValue(forKey: id)
            }

            do {
                let progressHandler: @Sendable (Progress) -> Void = { [weak self] progress in
                    Task { @MainActor in
                        self?.downloadProgress[id] = progress.fractionCompleted
                    }
                }

                let container = try await loadModelContainer(
                    from: downloader,
                    using: tokenizerLoader,
                    id: id,
                    progressHandler: progressHandler
                )

                try Task.checkCancellation()

                let size = diskUsage(for: id)
                let info = LocalModelInfo(
                    id: id,
                    displayName: displayName,
                    downloadedAt: Date(),
                    sizeBytes: size
                )
                downloadedModels.append(info)
                saveRegistry()

                modelContainer = container
                loadedModelId = id
                localSessions.removeAll()
            } catch is CancellationError {
            } catch {
                errorMessage = "Download failed: \(error.localizedDescription)"
            }
        }

        downloadTasks[id] = task
    }

    func cancelDownload(id: String) {
        downloadTasks[id]?.cancel()
        downloadTasks.removeValue(forKey: id)
        activeDownloads.remove(id)
        downloadProgress.removeValue(forKey: id)
    }

    // MARK: - Delete

    func deleteModel(id: String) {
        if loadedModelId == id {
            unloadModel()
        }

        let sanitized = id.replacingOccurrences(of: "/", with: "--")
        let fm = FileManager.default

        let homeDir = fm.homeDirectoryForCurrentUser
        let hfCacheDir = homeDir.appending(path: ".cache/huggingface/hub/models--\(sanitized)")
        try? fm.removeItem(at: hfCacheDir)

        if let cachesDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let sandboxHfDir = cachesDir.appending(path: "huggingface/hub/models--\(sanitized)")
            try? fm.removeItem(at: sandboxHfDir)
        }

        downloadedModels.removeAll { $0.id == id }
        saveRegistry()
    }

    // MARK: - Load / Unload

    func loadModel(id: String) async throws {
        if loadedModelId == id { return }

        unloadModel()

        let container = try await loadModelContainer(
            from: downloader,
            using: tokenizerLoader,
            id: id
        )

        modelContainer = container
        loadedModelId = id
    }

    func unloadModel() {
        modelContainer = nil
        loadedModelId = nil
        localSessions.removeAll()
    }

    // MARK: - Streaming

    func streamResponse(
        messages: [Message],
        conversationId: String,
        modelId: String
    ) -> AsyncThrowingStream<String, Error> {
        guard let container = modelContainer else {
            return AsyncThrowingStream { $0.finish(throwing: StreamingError.localModelError("No model loaded")) }
        }

        let promptMessages = Self.localPromptMessages(from: messages)
        guard let latestMessage = promptMessages.last(where: { $0.role == "user" }) else {
            return AsyncThrowingStream { $0.finish(throwing: StreamingError.localModelError("No user message to send")) }
        }

        let priorMessages = Array(promptMessages.dropLast())
        let priorSignature = Self.signature(for: priorMessages)
        let sessionKey = LocalSessionKey(conversationId: conversationId, modelId: modelId)

        sessionAccessCounter += 1
        let currentAccess = sessionAccessCounter

        let session: ChatSession
        if let cached = localSessions[sessionKey], cached.signature == priorSignature {
            cached.lastAccessed = currentAccess
            session = cached.session
        } else {
            session = ChatSession(
                container,
                instructions: "You are a helpful assistant.",
                history: Self.chatMessages(from: priorMessages)
            )
            localSessions[sessionKey] = LocalChatSessionState(
                conversationId: conversationId,
                modelId: modelId,
                signature: priorSignature,
                session: session,
                lastAccessed: currentAccess
            )
            evictSessionsIfNeeded()
        }

        return AsyncThrowingStream { continuation in
            let task = Task.detached {
                var fullContent = ""
                do {
                    let stream = session.streamResponse(to: latestMessage.content)
                    for try await chunk in stream {
                        try Task.checkCancellation()
                        fullContent += chunk
                        continuation.yield(chunk)
                    }
                    await MainActor.run { [weak self] in
                        self?.updateSessionSignature(
                            key: sessionKey,
                            session: session,
                            promptMessages: promptMessages,
                            assistantContent: fullContent
                        )
                    }
                    continuation.finish()
                } catch is CancellationError {
                    await MainActor.run { [weak self] in
                        self?.invalidateSession(key: sessionKey, session: session)
                    }
                    continuation.finish()
                } catch {
                    await MainActor.run { [weak self] in
                        self?.invalidateSession(key: sessionKey, session: session)
                    }
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    nonisolated static func localPromptMessages(
        from messages: [Message]
    ) -> [Message] {
        guard let latestUserIndex = messages.lastIndex(where: { $0.role == "user" }) else {
            return []
        }

        let latestUserMessage = messages[latestUserIndex]
        let priorMessages = messages[..<latestUserIndex].filter { message in
            (message.role == "user" || message.role == "assistant")
                && !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        return priorMessages + [latestUserMessage]
    }

    private nonisolated static func chatMessages(from messages: [Message]) -> [Chat.Message] {
        messages.compactMap { msg in
            switch msg.role {
            case "user": return .user(msg.content)
            case "assistant": return .assistant(msg.content)
            default: return nil
            }
        }
    }

    private nonisolated static func signature(for messages: [Message]) -> LocalConversationSignature {
        LocalConversationSignature(messages: messages.map { LocalMessageSnapshot(role: $0.role, content: $0.content) })
    }

    private nonisolated static func signature(
        for promptMessages: [Message],
        assistantContent: String
    ) -> LocalConversationSignature {
        var messages = promptMessages.map { LocalMessageSnapshot(role: $0.role, content: $0.content) }
        messages.append(LocalMessageSnapshot(role: "assistant", content: assistantContent))
        return LocalConversationSignature(messages: messages)
    }

    private func updateSessionSignature(
        key: LocalSessionKey,
        session: ChatSession,
        promptMessages: [Message],
        assistantContent: String
    ) {
        guard localSessions[key]?.session === session else { return }
        localSessions[key]?.signature = Self.signature(
            for: promptMessages,
            assistantContent: assistantContent
        )
    }

    private func evictSessionsIfNeeded() {
        while localSessions.count > Self.maxCachedSessions {
            guard let oldest = localSessions.min(by: { $0.value.lastAccessed < $1.value.lastAccessed }) else { break }
            localSessions.removeValue(forKey: oldest.key)
        }
    }

    private func invalidateSession(key: LocalSessionKey, session: ChatSession) {
        guard localSessions[key]?.session === session else { return }
        localSessions.removeValue(forKey: key)
    }

    // MARK: - Disk Usage

    func diskUsage(for modelId: String) -> Int64 {
        let sanitized = modelId.replacingOccurrences(of: "/", with: "--")
        let fm = FileManager.default

        let homeDir = fm.homeDirectoryForCurrentUser
        let hfDir = homeDir.appending(path: ".cache/huggingface/hub/models--\(sanitized)")
        let hfSize = directorySize(at: hfDir)
        if hfSize > 0 { return hfSize }

        if let cachesDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let sandboxDir = cachesDir.appending(path: "huggingface/hub/models--\(sanitized)")
            return directorySize(at: sandboxDir)
        }
        return 0
    }

    var totalDiskUsage: Int64 {
        downloadedModels.reduce(0) { $0 + $1.sizeBytes }
    }

    // MARK: - Registry Persistence

    private func loadRegistry() {
        guard let data = try? Data(contentsOf: registryURL) else { return }
        downloadedModels = (try? JSONDecoder().decode([LocalModelInfo].self, from: data)) ?? []
    }

    private func saveRegistry() {
        guard let data = try? JSONEncoder().encode(downloadedModels) else { return }
        try? data.write(to: registryURL, options: .atomic)
    }

    // MARK: - Helpers

    private func directorySize(at url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}
