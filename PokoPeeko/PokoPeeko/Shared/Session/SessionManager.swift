import Foundation
import Security

/// 세션과 프로필 설정 진행 상태를 같은 Keychain 항목에 저장한다.
enum SessionManager {
  struct StoredSession: Codable, Equatable {
    let sessionId: String
    let needsProfileSetup: Bool
    let profile: UserProfile?
    var routingVersion: Int? = nil
  }

  // 로그인 응답 해석이 바뀌면 이전 판정으로 저장한 세션을 재사용하지 않는다.
  private static let routingVersion = 2

  private static var query: [String: Any] {
    [kSecClass as String: kSecClassGenericPassword,
     kSecAttrService as String: "com.peekopoko.pokopeeko",
     kSecAttrAccount as String: "sessionId"]
  }

  static var sessionId: String? { (try? load())?.sessionId }

  static func load() throws -> StoredSession? {
    var request = query
    request[kSecReturnData as String] = true
    request[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: AnyObject?
    let status = SecItemCopyMatching(request as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess else { throw KeychainError.status(status) }
    guard let data = result as? Data else { throw KeychainError.invalidData }
    // 이전 구현의 세션 문자열에는 설정 완료 여부가 없어 다시 로그인하도록 한다.
    if let legacy = String(data: data, encoding: .utf8), UUID(uuidString: legacy) != nil { return nil }
    guard let stored = try? JSONDecoder().decode(StoredSession.self, from: data),
          UUID(uuidString: stored.sessionId) != nil else { throw KeychainError.invalidData }
    guard stored.routingVersion == routingVersion else { return nil }
    return stored
  }

  static func save(sessionId: String, needsProfileSetup: Bool, profile: UserProfile? = nil) throws {
    guard UUID(uuidString: sessionId) != nil else { throw KeychainError.invalidData }
    let stored = StoredSession(sessionId: sessionId, needsProfileSetup: needsProfileSetup, profile: profile, routingVersion: routingVersion)
    let attributes: [String: Any] = [
      kSecValueData as String: try JSONEncoder().encode(stored),
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ]
    let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      let item = query.merging(attributes) { _, new in new }
      let addStatus = SecItemAdd(item as CFDictionary, nil)
      guard addStatus == errSecSuccess else { throw KeychainError.status(addStatus) }
    } else if status != errSecSuccess {
      throw KeychainError.status(status)
    }
  }

  @discardableResult
  static func delete(ifMatching sessionId: String? = nil) throws -> Bool {
    if let sessionId, try load()?.sessionId != sessionId { return false }
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.status(status) }
    return true
  }

  enum KeychainError: LocalizedError {
    case status(OSStatus)
    case invalidData

    var errorDescription: String? {
      switch self {
      case .status: "로그인 정보를 Keychain에서 처리하지 못했어요. 잠금 상태와 앱 권한을 확인해주세요."
      case .invalidData: "저장된 로그인 정보를 읽지 못했어요. 다시 로그인해주세요."
      }
    }
  }
}
