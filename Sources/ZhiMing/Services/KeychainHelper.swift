import Foundation
import Security

/// API Key 只走 Keychain，禁止写入 UserDefaults/日志/持久层
enum KeychainHelper {
    static let service = "com.zhiming.apikeys"

    /// 保存成功返回 true；失败（如侧载缺 entitlement 的 -34018）返回 false，调用方须向用户呈现
    @discardableResult
    static func save(key: String, account: String) -> Bool {
        let data = Data(key.utf8)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        // 显式可达性：本设备 + 解锁后可读；同时阻止明文备份把密钥迁移到其他设备
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    static func load(account: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 删除成功（或条目本就不存在）返回 true；结果仅用于诊断，不阻断流程
    @discardableResult
    static func delete(account: String) -> Bool {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
