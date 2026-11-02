//

import Foundation
import Security

enum SessionManager {
  private static let service = "com.peekopoko.pokopeeko"
  private static let account = "sessionId"

  static func save(sessionId: String) {
    let data = Data(sessionId.utf8)

    delete()

    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecValueData as String: data
    ]

    SecItemAdd(query as CFDictionary, nil)
  }

  static var sessionId: String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne
    ]

    var result: AnyObject?

    let status = SecItemCopyMatching(
      query as CFDictionary,
      &result
    )

    guard status == errSecSuccess,
          let data = result as? Data
    else {
      return nil
    }

    return String(data: data, encoding: .utf8)
  }

  static func delete() {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account
    ]

    SecItemDelete(query as CFDictionary)
  }
}
