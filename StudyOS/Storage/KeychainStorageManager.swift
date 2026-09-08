import Foundation
#if canImport(Security)
import Security
#endif

/// Keychain 凭据存取协议
public protocol KeychainStorageManagerProtocol: Sendable {
    func saveSecret(_ secret: String, forKey key: String) async throws
    func getSecret(forKey key: String) async -> String?
    func deleteSecret(forKey key: String) async throws -> Bool
    func clearAll() async
}

/// 安全凭据管理器 (KeychainStorageManager)
/// 纯原生 Actor 隔离，使用 iOS/iPadOS Security Keychain 存储 API Key；
/// 提供非真机/模拟器/测试环境内存降级支持，确保零崩溃与 Strict Concurrency 安全
public actor KeychainStorageManager: KeychainStorageManagerProtocol {
    public static let shared = KeychainStorageManager()

    private let serviceName: String
    private var inMemoryFallback: [String: String] = [:]

    public init(serviceName: String = "com.studyos.app.credentials") {
        self.serviceName = serviceName
    }

    /// 存储凭据
    public func saveSecret(_ secret: String, forKey key: String) async throws {
        inMemoryFallback[key] = secret

        #if canImport(Security)
        guard let data = secret.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        // 尝试先删除旧条目
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status != errSecSuccess && status != errSecMissingEntitlement {
            // 在模拟器或无 entitlement 环境下静默走内存降级，不抛崩溃
        }
        #endif
    }

    /// 读取凭据
    public func getSecret(forKey key: String) async -> String? {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess, let data = item as? Data, let secret = String(data: data, encoding: .utf8) {
            inMemoryFallback[key] = secret
            return secret
        }
        #endif

        return inMemoryFallback[key]
    }

    /// 删除凭据
    public func deleteSecret(forKey key: String) async throws -> Bool {
        let hadInMemory = inMemoryFallback.removeValue(forKey: key) != nil

        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound || status == errSecMissingEntitlement || hadInMemory
        #else
        return true
        #endif
    }

    /// 清空所有内存缓存凭据
    public func clearAll() async {
        inMemoryFallback.removeAll()
    }
}
