import Foundation

struct AIModel: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let provider: String
    let providerName: String

    var supportsVision: Bool {
        switch provider {
        case "openai", "anthropic", "google", "xai": return true
        case "mistral":
            // All Mistral 3 family models have native vision
            return true
        case "groq":
            // Only Llama 4 Scout is multimodal on Groq
            return id.contains("llama-4")
        case "deepseek": return false
        default: return false
        }
    }

    var supportsPDF: Bool {
        switch provider {
        case "openai", "anthropic", "google": return true
        default: return false
        }
    }

}

let defaultModels: [AIModel] = [
    // OpenAI
    AIModel(id: "gpt-4o", name: "GPT-4o", provider: "openai", providerName: "OpenAI"),
    AIModel(id: "gpt-4o-mini", name: "GPT-4o Mini", provider: "openai", providerName: "OpenAI"),
    AIModel(id: "gpt-4.1", name: "GPT-4.1", provider: "openai", providerName: "OpenAI"),
    AIModel(id: "gpt-4.1-mini", name: "GPT-4.1 Mini", provider: "openai", providerName: "OpenAI"),
    AIModel(id: "gpt-4.1-nano", name: "GPT-4.1 Nano", provider: "openai", providerName: "OpenAI"),
    AIModel(id: "gpt-5", name: "GPT-5", provider: "openai", providerName: "OpenAI"),
    AIModel(id: "gpt-5-mini", name: "GPT-5 Mini", provider: "openai", providerName: "OpenAI"),
    AIModel(id: "gpt-5-nano", name: "GPT-5 Nano", provider: "openai", providerName: "OpenAI"),
    AIModel(id: "gpt-5-codex", name: "GPT-5 Codex", provider: "openai", providerName: "OpenAI"),
    AIModel(id: "gpt-5.1", name: "GPT-5.1", provider: "openai", providerName: "OpenAI"),
    AIModel(id: "gpt-5.1-codex", name: "GPT-5.1 Codex", provider: "openai", providerName: "OpenAI"),
    AIModel(id: "gpt-5.1-codex-mini", name: "GPT-5.1 Codex Mini", provider: "openai", providerName: "OpenAI"),
    AIModel(id: "gpt-5.1-codex-max", name: "GPT-5.1 Codex Max", provider: "openai", providerName: "OpenAI"),
    AIModel(id: "gpt-5.2", name: "GPT-5.2", provider: "openai", providerName: "OpenAI"),
    AIModel(id: "gpt-5.2-codex", name: "GPT-5.2 Codex", provider: "openai", providerName: "OpenAI"),
    AIModel(id: "gpt-5.3-codex", name: "GPT-5.3 Codex", provider: "openai", providerName: "OpenAI"),
    AIModel(id: "gpt-5.4", name: "GPT-5.4", provider: "openai", providerName: "OpenAI"),

    // Anthropic
    AIModel(id: "claude-sonnet-4-20250514", name: "Claude Sonnet 4", provider: "anthropic", providerName: "Anthropic"),
    AIModel(id: "claude-3-5-haiku-20241022", name: "Claude 3.5 Haiku", provider: "anthropic", providerName: "Anthropic"),
    AIModel(id: "claude-haiku-4-5", name: "Claude Haiku 4.5", provider: "anthropic", providerName: "Anthropic"),
    AIModel(id: "claude-sonnet-4-5", name: "Claude Sonnet 4.5", provider: "anthropic", providerName: "Anthropic"),
    AIModel(id: "claude-sonnet-4-6", name: "Claude Sonnet 4.6", provider: "anthropic", providerName: "Anthropic"),
    AIModel(id: "claude-opus-4-1", name: "Claude Opus 4.1", provider: "anthropic", providerName: "Anthropic"),
    AIModel(id: "claude-opus-4-5", name: "Claude Opus 4.5", provider: "anthropic", providerName: "Anthropic"),
    AIModel(id: "claude-opus-4-6", name: "Claude Opus 4.6", provider: "anthropic", providerName: "Anthropic"),

    // Google
    AIModel(id: "gemini-2.5-flash", name: "Gemini 2.5 Flash", provider: "google", providerName: "Google"),
    AIModel(id: "gemini-2.5-pro", name: "Gemini 2.5 Pro", provider: "google", providerName: "Google"),
    AIModel(id: "gemini-2.5-flash-lite", name: "Gemini 2.5 Flash-Lite", provider: "google", providerName: "Google"),
    AIModel(id: "gemini-3-pro-preview", name: "Gemini 3 Pro Preview", provider: "google", providerName: "Google"),
    AIModel(id: "gemini-3-flash-preview", name: "Gemini 3 Flash Preview", provider: "google", providerName: "Google"),
    AIModel(id: "gemini-3.1-pro-preview", name: "Gemini 3.1 Pro Preview", provider: "google", providerName: "Google"),

    // Mistral
    AIModel(id: "mistral-large-latest", name: "Mistral Large", provider: "mistral", providerName: "Mistral"),
    AIModel(id: "mistral-small-latest", name: "Mistral Small", provider: "mistral", providerName: "Mistral"),
    AIModel(id: "mistral-medium-latest", name: "Mistral Medium", provider: "mistral", providerName: "Mistral"),
    AIModel(id: "magistral-medium-latest", name: "Magistral Medium", provider: "mistral", providerName: "Mistral"),
    AIModel(id: "magistral-small-latest", name: "Magistral Small", provider: "mistral", providerName: "Mistral"),
    AIModel(id: "ministral-8b-latest", name: "Ministral 8B", provider: "mistral", providerName: "Mistral"),
    AIModel(id: "ministral-3b-latest", name: "Ministral 3B", provider: "mistral", providerName: "Mistral"),

    // xAI
    AIModel(id: "grok-3", name: "Grok 3", provider: "xai", providerName: "xAI"),
    AIModel(id: "grok-3-mini", name: "Grok 3 Mini", provider: "xai", providerName: "xAI"),
    AIModel(id: "grok-4", name: "Grok 4", provider: "xai", providerName: "xAI"),
    AIModel(id: "grok-4-1", name: "Grok 4.1", provider: "xai", providerName: "xAI"),
    AIModel(id: "grok-4-1-fast-reasoning", name: "Grok 4.1 Fast Reasoning", provider: "xai", providerName: "xAI"),
    AIModel(id: "grok-4-1-fast-non-reasoning", name: "Grok 4.1 Fast", provider: "xai", providerName: "xAI"),

    // DeepSeek
    AIModel(id: "deepseek-chat", name: "DeepSeek V3", provider: "deepseek", providerName: "DeepSeek"),
    AIModel(id: "deepseek-reasoner", name: "DeepSeek R1", provider: "deepseek", providerName: "DeepSeek"),

    // Groq
    AIModel(id: "llama-3.3-70b-versatile", name: "Llama 3.3 70B", provider: "groq", providerName: "Groq"),
    AIModel(id: "llama-3.1-8b-instant", name: "Llama 3.1 8B", provider: "groq", providerName: "Groq"),
    AIModel(id: "meta-llama/llama-4-scout-17b-16e-instruct", name: "Llama 4 Scout", provider: "groq", providerName: "Groq"),
    AIModel(id: "qwen/qwen3-32b", name: "Qwen3 32B", provider: "groq", providerName: "Groq"),
    AIModel(id: "openai/gpt-oss-120b", name: "GPT-OSS 120B", provider: "groq", providerName: "Groq"),
    AIModel(id: "moonshotai/kimi-k2-instruct-0905", name: "Kimi K2", provider: "groq", providerName: "Groq"),
]
