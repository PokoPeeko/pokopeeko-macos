import Foundation

/// 비동기 요청 중 세션 교체 여부 확인과 저장소 독립 검증에 사용한다.
@MainActor
protocol SessionStoring {
  func load() throws -> SessionManager.StoredSession?
  func save(_ session: SessionManager.StoredSession) throws
  @discardableResult func delete(ifMatching id: String) throws -> Bool
}

struct KeychainSessionStore: SessionStoring {
  func load() throws -> SessionManager.StoredSession? { try SessionManager.load() }
  func save(_ session: SessionManager.StoredSession) throws {
    try SessionManager.save(sessionId: session.sessionId, needsProfileSetup: session.needsProfileSetup, profile: session.profile)
  }
  func delete(ifMatching id: String) throws -> Bool { try SessionManager.delete(ifMatching: id) }
}
