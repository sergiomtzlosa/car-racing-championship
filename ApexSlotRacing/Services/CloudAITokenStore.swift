import Foundation
import Security

/// Abstraction over secure token persistence so tests never need the login
/// keychain and so an unsigned local build can still keep the token in memory.
protocol CloudAITokenStoring: AnyObject {
    func loadToken() -> String
    @discardableResult func saveToken(_ token: String) -> Bool
    func deleteToken()
}

/// Stores the optional cloud-AI API token as a generic password item in the
/// macOS Keychain. Tokens are intentionally excluded from `AppSettings`'
/// `Codable` representation and therefore never reach `UserDefaults`.
final class KeychainCloudAITokenStore: CloudAITokenStoring {
    private let service: String
    private let account: String

    init(service: String = "com.sid.ApexSlotRacing.cloud-ai",
         account: String = "api-token") {
        self.service = service
        self.account = account
    }

    func loadToken() -> String {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return ""
        }
        return token
    }

    @discardableResult
    func saveToken(_ token: String) -> Bool {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            deleteToken()
            return true
        }

        deleteToken()
        var query = baseQuery
        query[kSecValueData as String] = Data(trimmed.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    func deleteToken() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

/// Used by the test suite and as an in-memory fallback when Keychain access is
/// unavailable in an unsigned sandboxed build.
final class InMemoryCloudAITokenStore: CloudAITokenStoring {
    private(set) var token: String

    init(token: String = "") {
        self.token = token
    }

    func loadToken() -> String { token }

    @discardableResult
    func saveToken(_ token: String) -> Bool {
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return true
    }

    func deleteToken() {
        token = ""
    }
}
