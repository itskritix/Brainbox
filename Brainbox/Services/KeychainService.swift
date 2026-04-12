import Foundation
import Security

@MainActor
@Observable
class KeychainService {
    static let providers = ["openai", "anthropic", "google", "mistral", "xai", "deepseek", "groq"]

    private static let servicePrefix = "com.brainbox.apikey."

    // Bumped on every save/delete to trigger SwiftUI updates
    private(set) var revision: Int = 0

    var configuredProviders: [String] {
        _ = revision // access to create observation dependency
        return Self.providers.filter { hasKey(for: $0) }
    }

    func apiKey(for provider: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.servicePrefix + provider,
            kSecAttrAccount as String: provider,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func setAPIKey(_ key: String, for provider: String) {
        guard let data = key.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.servicePrefix + provider,
            kSecAttrAccount as String: provider,
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
            SecItemAdd(addQuery as CFDictionary, nil)
        }

        revision += 1
    }

    func deleteAPIKey(for provider: String) {
        deleteAPIKeySilent(for: provider)
        revision += 1
    }

    func hasKey(for provider: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.servicePrefix + provider,
            kSecAttrAccount as String: provider,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    // Internal delete without bumping revision (used by setAPIKey to avoid double-bump)
    private func deleteAPIKeySilent(for provider: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.servicePrefix + provider,
            kSecAttrAccount as String: provider,
        ]
        SecItemDelete(query as CFDictionary)
    }

    nonisolated static func providerDisplayName(_ provider: String) -> String {
        switch provider {
        case "openai": return "OpenAI"
        case "anthropic": return "Anthropic"
        case "google": return "Google"
        case "mistral": return "Mistral"
        case "xai": return "xAI"
        case "deepseek": return "DeepSeek"
        case "groq": return "Groq"
        case "local": return "Local"
        default: return provider.capitalized
        }
    }

    static func providerKeyURL(_ provider: String) -> URL? {
        switch provider {
        case "openai": return URL(string: "https://platform.openai.com/api-keys")
        case "anthropic": return URL(string: "https://console.anthropic.com/settings/keys")
        case "google": return URL(string: "https://aistudio.google.com/apikey")
        case "mistral": return URL(string: "https://console.mistral.ai/api-keys")
        case "xai": return URL(string: "https://console.x.ai")
        case "deepseek": return URL(string: "https://platform.deepseek.com/api_keys")
        case "groq": return URL(string: "https://console.groq.com/keys")
        default: return nil
        }
    }
}
