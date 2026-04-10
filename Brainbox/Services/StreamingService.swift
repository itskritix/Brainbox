import Foundation

final class StreamingService: Sendable {
    struct ProviderConfig {
        let baseURL: String
        let authHeader: String
        let authPrefix: String
        let parserType: SSEParserType
        let useQueryParam: Bool

        static func config(for provider: String) -> ProviderConfig {
            switch provider {
            case "openai":
                return ProviderConfig(
                    baseURL: "https://api.openai.com/v1/chat/completions",
                    authHeader: "Authorization", authPrefix: "Bearer ",
                    parserType: .openAI, useQueryParam: false
                )
            case "anthropic":
                return ProviderConfig(
                    baseURL: "https://api.anthropic.com/v1/messages",
                    authHeader: "x-api-key", authPrefix: "",
                    parserType: .anthropic, useQueryParam: false
                )
            case "google":
                return ProviderConfig(
                    baseURL: "https://generativelanguage.googleapis.com/v1beta/models/",
                    authHeader: "", authPrefix: "",
                    parserType: .google, useQueryParam: true
                )
            case "mistral":
                return ProviderConfig(
                    baseURL: "https://api.mistral.ai/v1/chat/completions",
                    authHeader: "Authorization", authPrefix: "Bearer ",
                    parserType: .openAI, useQueryParam: false
                )
            case "xai":
                return ProviderConfig(
                    baseURL: "https://api.x.ai/v1/chat/completions",
                    authHeader: "Authorization", authPrefix: "Bearer ",
                    parserType: .openAI, useQueryParam: false
                )
            case "deepseek":
                return ProviderConfig(
                    baseURL: "https://api.deepseek.com/v1/chat/completions",
                    authHeader: "Authorization", authPrefix: "Bearer ",
                    parserType: .openAI, useQueryParam: false
                )
            case "groq":
                return ProviderConfig(
                    baseURL: "https://api.groq.com/openai/v1/chat/completions",
                    authHeader: "Authorization", authPrefix: "Bearer ",
                    parserType: .openAI, useQueryParam: false
                )
            default:
                return ProviderConfig(
                    baseURL: "https://api.openai.com/v1/chat/completions",
                    authHeader: "Authorization", authPrefix: "Bearer ",
                    parserType: .openAI, useQueryParam: false
                )
            }
        }
    }

    func streamResponse(
        messages: [Message],
        attachments: [String: (data: Data, mimeType: String, fileType: String)],
        model: AIModel,
        apiKey: String
    ) -> AsyncThrowingStream<String, Error> {
        let capturedModel = model
        let capturedMessages = messages
        let capturedAttachments = attachments

        return AsyncThrowingStream { continuation in
            let task = Task.detached { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                do {
                    let config = ProviderConfig.config(for: capturedModel.provider)
                    let request = try self.buildRequest(
                        messages: capturedMessages,
                        attachments: capturedAttachments,
                        model: capturedModel,
                        apiKey: apiKey,
                        config: config
                    )

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: StreamingError.invalidResponse)
                        return
                    }

                    if httpResponse.statusCode != 200 {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                        }
                        continuation.finish(throwing: StreamingError.apiError(
                            statusCode: httpResponse.statusCode,
                            message: errorBody
                        ))
                        return
                    }

                    let parser = SSEParser(type: config.parserType)

                    for try await line in bytes.lines {
                        guard !Task.isCancelled else {
                            continuation.finish()
                            return
                        }

                        if let event = parser.parse(line: line) {
                            switch event {
                            case .text(let text):
                                continuation.yield(text)
                            case .done:
                                continuation.finish()
                                return
                            case .error(let message):
                                continuation.finish(throwing: StreamingError.apiError(
                                    statusCode: httpResponse.statusCode,
                                    message: message
                                ))
                                return
                            }
                        }
                    }

                    continuation.finish()
                } catch {
                    if !Task.isCancelled {
                        continuation.finish(throwing: error)
                    }
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Request Building

    private func buildRequest(
        messages: [Message],
        attachments: [String: (data: Data, mimeType: String, fileType: String)],
        model: AIModel,
        apiKey: String,
        config: ProviderConfig
    ) throws -> URLRequest {
        switch model.provider {
        case "anthropic":
            return try buildAnthropicRequest(
                messages: messages, attachments: attachments,
                modelId: model.id, apiKey: apiKey, config: config
            )
        case "google":
            return try buildGoogleRequest(
                messages: messages, attachments: attachments,
                modelId: model.id, apiKey: apiKey, config: config
            )
        default:
            return try buildOpenAIRequest(
                messages: messages, attachments: attachments,
                model: model, apiKey: apiKey, config: config
            )
        }
    }

    // MARK: - OpenAI-Compatible Request

    private func buildOpenAIRequest(
        messages: [Message],
        attachments: [String: (data: Data, mimeType: String, fileType: String)],
        model: AIModel,
        apiKey: String,
        config: ProviderConfig
    ) throws -> URLRequest {
        guard let url = URL(string: config.baseURL) else {
            throw StreamingError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.authPrefix + apiKey, forHTTPHeaderField: config.authHeader)

        var msgArray: [[String: Any]] = []
        for msg in messages {
            let content = buildOpenAIContent(
                message: msg, attachments: attachments, supportsVision: model.supportsVision
            )
            msgArray.append(["role": msg.role, "content": content])
        }

        let body: [String: Any] = [
            "model": model.id,
            "messages": msgArray,
            "stream": true,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func buildOpenAIContent(
        message: Message,
        attachments: [String: (data: Data, mimeType: String, fileType: String)],
        supportsVision: Bool
    ) -> Any {
        let msgAttachments = message.attachments ?? []
        guard !msgAttachments.isEmpty, supportsVision else {
            return message.content
        }

        var parts: [[String: Any]] = []

        for att in msgAttachments {
            if let attData = attachments[att.id] {
                if attData.fileType == "image" {
                    let base64 = attData.data.base64EncodedString()
                    parts.append([
                        "type": "image_url",
                        "image_url": ["url": "data:\(attData.mimeType);base64,\(base64)"],
                    ])
                }
            }
        }

        parts.append(["type": "text", "text": message.content.isEmpty ? "Describe this." : message.content])
        return parts
    }

    // MARK: - Anthropic Request

    private func buildAnthropicRequest(
        messages: [Message],
        attachments: [String: (data: Data, mimeType: String, fileType: String)],
        modelId: String,
        apiKey: String,
        config: ProviderConfig
    ) throws -> URLRequest {
        guard let url = URL(string: config.baseURL) else {
            throw StreamingError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        var msgArray: [[String: Any]] = []

        for msg in messages {
            if msg.role == "system" { continue }

            let msgAttachments = msg.attachments ?? []
            if msgAttachments.isEmpty {
                msgArray.append(["role": msg.role, "content": msg.content])
            } else {
                var content: [[String: Any]] = []

                for att in msgAttachments {
                    if let attData = attachments[att.id] {
                        if attData.fileType == "image" {
                            content.append([
                                "type": "image",
                                "source": [
                                    "type": "base64",
                                    "media_type": attData.mimeType,
                                    "data": attData.data.base64EncodedString(),
                                ] as [String: Any],
                            ])
                        } else if attData.fileType == "pdf" {
                            content.append([
                                "type": "document",
                                "source": [
                                    "type": "base64",
                                    "media_type": "application/pdf",
                                    "data": attData.data.base64EncodedString(),
                                ] as [String: Any],
                            ])
                        }
                    }
                }

                content.append(["type": "text", "text": msg.content.isEmpty ? "Describe this." : msg.content])
                msgArray.append(["role": msg.role, "content": content])
            }
        }

        // Extract system message
        let systemMessage = messages.first(where: { $0.role == "system" })?.content

        var body: [String: Any] = [
            "model": modelId,
            "messages": msgArray,
            "max_tokens": 8192,
            "stream": true,
        ]

        if let systemMessage {
            body["system"] = systemMessage
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: - Google Request

    private func buildGoogleRequest(
        messages: [Message],
        attachments: [String: (data: Data, mimeType: String, fileType: String)],
        modelId: String,
        apiKey: String,
        config: ProviderConfig
    ) throws -> URLRequest {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = "\(config.baseURL)\(modelId):streamGenerateContent?alt=sse&key=\(trimmedKey)"
        guard let url = URL(string: urlString) else {
            throw StreamingError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var contents: [[String: Any]] = []

        for msg in messages {
            if msg.role == "system" { continue }
            let role = msg.role == "assistant" ? "model" : "user"
            let msgAttachments = msg.attachments ?? []

            if msgAttachments.isEmpty {
                contents.append([
                    "role": role,
                    "parts": [["text": msg.content]],
                ])
            } else {
                var parts: [[String: Any]] = []

                for att in msgAttachments {
                    if let attData = attachments[att.id] {
                        parts.append([
                            "inlineData": [
                                "mimeType": attData.mimeType,
                                "data": attData.data.base64EncodedString(),
                            ],
                        ])
                    }
                }

                parts.append(["text": msg.content.isEmpty ? "Describe this." : msg.content])
                contents.append(["role": role, "parts": parts])
            }
        }

        // System instruction for Google
        var body: [String: Any] = ["contents": contents]

        if let systemMsg = messages.first(where: { $0.role == "system" }) {
            body["systemInstruction"] = [
                "parts": [["text": systemMsg.content]],
            ]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
}

// MARK: - Errors

enum StreamingError: LocalizedError {
    case noAPIKey(String)
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case localModelError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey(let provider):
            return "No API key configured for \(KeychainService.providerDisplayName(provider)). Add one in Settings > API Keys."
        case .invalidURL:
            return "Invalid API URL."
        case .invalidResponse:
            return "Invalid response from API."
        case .apiError(let code, let message):
            return "API error (\(code)): \(message)"
        case .localModelError(let message):
            return "Local model error: \(message)"
        }
    }

    /// Whether the error is potentially transient and retrying may succeed.
    var isRecoverable: Bool {
        switch self {
        case .noAPIKey:
            return false
        case .invalidURL:
            return false
        case .invalidResponse:
            return true
        case .apiError(let statusCode, _):
            // 429 = rate limit (recoverable), 5xx = server errors (recoverable)
            // 4xx (except 429) = client errors like auth/bad request (non-recoverable)
            return statusCode == 429 || statusCode >= 500
        case .localModelError:
            return false
        }
    }
}
