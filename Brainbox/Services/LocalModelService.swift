import Foundation
import MLXLLM
import MLXLMCommon

// MARK: - Model Info

struct LocalModelInfo: Codable, Identifiable, Hashable {
    let id: String          // HuggingFace model ID, e.g. "mlx-community/Qwen3-4B-4bit"
    let displayName: String
    let downloadedAt: Date
    var sizeBytes: Int64
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

    private let registryURL: URL

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
        ("mlx-community/gemma-4-e4b-it-4bit", "Gemma 4 4B", "~5 GB"),
        ("mlx-community/gemma-4-e2b-it-4bit", "Gemma 4 2B", "~3.5 GB"),
        ("mlx-community/Llama-3.2-3B-Instruct-4bit", "Llama 3.2 3B", "~1.8 GB"),
        ("mlx-community/Qwen3-4B-4bit", "Qwen3 4B", "~2.5 GB"),
        ("mlx-community/Mistral-7B-Instruct-v0.3-4bit", "Mistral 7B", "~4 GB"),
    ]

    // MARK: - Download

    func downloadModel(id: String, displayName: String) {
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
                let config = ModelConfiguration(id: id)

                let progressHandler: @Sendable (Progress) -> Void = { [weak self] progress in
                    Task { @MainActor in
                        self?.downloadProgress[id] = progress.fractionCompleted
                    }
                }

                // Downloads from HuggingFace on first use, then loads model
                let container = try await LLMModelFactory.shared.loadContainer(
                    configuration: config,
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

                // Keep the container loaded since we just downloaded it
                modelContainer = container
                loadedModelId = id
            } catch is CancellationError {
                // User cancelled — no error message needed
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

        // Remove HuggingFace cached files
        let sanitized = id.replacingOccurrences(of: "/", with: "--")
        let fm = FileManager.default

        // HuggingFace Swift caches to ~/.cache/huggingface/
        let homeDir = fm.homeDirectoryForCurrentUser
        let hfCacheDir = homeDir.appending(path: ".cache/huggingface/hub/models--\(sanitized)")
        try? fm.removeItem(at: hfCacheDir)

        // Also check app sandbox caches directory as a fallback
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

        let config = ModelConfiguration(id: id)
        let container = try await LLMModelFactory.shared.loadContainer(configuration: config)

        modelContainer = container
        loadedModelId = id
    }

    func unloadModel() {
        modelContainer = nil
        loadedModelId = nil
    }

    // MARK: - Streaming

    func streamResponse(messages: [Message]) -> AsyncThrowingStream<String, Error> {
        guard let container = modelContainer else {
            return AsyncThrowingStream { $0.finish(throwing: StreamingError.localModelError("No model loaded")) }
        }

        // Build Chat.Message history from all prior messages (excluding the latest user message)
        let lastUserMessage = messages.last(where: { $0.role == "user" })?.content ?? ""
        let priorMessages: [Chat.Message] = messages.dropLast().compactMap { msg in
            switch msg.role {
            case "user": return .user(msg.content)
            case "assistant": return .assistant(msg.content)
            default: return nil
            }
        }

        // Create a fresh ChatSession per request with full conversation history
        // This ensures conversation switching works correctly
        let session = ChatSession(
            container,
            instructions: "You are a helpful assistant.",
            history: priorMessages
        )

        return AsyncThrowingStream { continuation in
            let task = Task.detached {
                do {
                    let stream = session.streamResponse(to: lastUserMessage)
                    for try await chunk in stream {
                        try Task.checkCancellation()
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Disk Usage

    func diskUsage(for modelId: String) -> Int64 {
        let sanitized = modelId.replacingOccurrences(of: "/", with: "--")
        let fm = FileManager.default

        // Check ~/.cache/huggingface/ first (HuggingFace Swift default)
        let homeDir = fm.homeDirectoryForCurrentUser
        let hfDir = homeDir.appending(path: ".cache/huggingface/hub/models--\(sanitized)")
        let hfSize = directorySize(at: hfDir)
        if hfSize > 0 { return hfSize }

        // Fallback to app sandbox caches
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
