import Foundation

enum SSEEvent {
    case text(String)
    case done
    case error(String)
}

enum SSEParserType {
    case openAI
    case anthropic
    case google
}

struct SSEParser {
    let type: SSEParserType

    func parse(line: String) -> SSEEvent? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // Skip empty lines and comments
        if trimmed.isEmpty || trimmed.hasPrefix(":") {
            return nil
        }

        // Handle "data: [DONE]" (OpenAI-compatible)
        if trimmed == "data: [DONE]" {
            return .done
        }

        // Extract data payload
        guard trimmed.hasPrefix("data: ") else {
            return nil
        }

        let jsonString = String(trimmed.dropFirst(6))

        switch type {
        case .openAI:
            return parseOpenAI(jsonString)
        case .anthropic:
            return parseAnthropic(jsonString)
        case .google:
            return parseGoogle(jsonString)
        }
    }

    private func parseOpenAI(_ json: String) -> SSEEvent? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let choices = obj["choices"] as? [[String: Any]],
           let delta = choices.first?["delta"] as? [String: Any] {
            if let content = delta["content"] as? String {
                return .text(content)
            }
            if let finishReason = choices.first?["finish_reason"] as? String, finishReason == "stop" {
                return .done
            }
            return nil
        }

        if let error = obj["error"] as? [String: Any],
           let message = error["message"] as? String {
            return .error(message)
        }

        return nil
    }

    private func parseAnthropic(_ json: String) -> SSEEvent? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let type = obj["type"] as? String

        switch type {
        case "content_block_delta":
            if let delta = obj["delta"] as? [String: Any],
               let text = delta["text"] as? String {
                return .text(text)
            }
        case "message_stop":
            return .done
        case "error":
            if let error = obj["error"] as? [String: Any],
               let message = error["message"] as? String {
                return .error(message)
            }
        default:
            break
        }

        return nil
    }

    private func parseGoogle(_ json: String) -> SSEEvent? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let candidates = obj["candidates"] as? [[String: Any]],
           let content = candidates.first?["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]] {
            var text = ""
            for part in parts {
                if let partText = part["text"] as? String {
                    text += partText
                }
            }
            if !text.isEmpty {
                return .text(text)
            }
            if let finishReason = candidates.first?["finishReason"] as? String,
               finishReason == "STOP" {
                return .done
            }
            return nil
        }

        if let error = obj["error"] as? [String: Any],
           let message = error["message"] as? String {
            return .error(message)
        }

        return nil
    }
}
