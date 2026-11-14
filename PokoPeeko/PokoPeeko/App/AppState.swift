import Foundation
import Observation

@MainActor
@Observable
final class AppState {
  private(set) var isLoggedIn = false
  var authenticationNotice: String?
  private(set) var profile: UserProfile?
  private(set) var profileImageData: Data?
  private(set) var isRestoringSession = true
  private(set) var startupError: String?
  private(set) var profileError: String?
  private(set) var isRefreshingProfile = false
  private(set) var currentSessionId: String? {
    didSet { if oldValue != currentSessionId { onSessionChange?() } }
  }
  @ObservationIgnored var onSessionChange: (() -> Void)?

  private let profileService: ProfileService
  private let sessions: any SessionStoring
  private let signOutFirebase: () throws -> Void
  private var didRestore = false
  private var revision = UUID()
  @ObservationIgnored private var profileTask: Task<Void, Never>?

  init(profileService: ProfileService? = nil, sessions: (any SessionStoring)? = nil,
       signOutFirebase: @escaping () throws -> Void = {}) {
    self.profileService = profileService ?? ProfileService()
    self.sessions = sessions ?? KeychainSessionStore()
    self.signOutFirebase = signOutFirebase
  }

  func restoreSession(force: Bool = false) async {
    guard force || !didRestore else { return }
    didRestore = true
    profileTask?.cancel()
    isRefreshingProfile = false
    let token = UUID()
    revision = token
    isRestoringSession = true
    startupError = nil
    defer { if revision == token { isRestoringSession = false } }
    do {
      guard let saved = try sessions.load() else {
        clearAuthentication()
        return
      }
      currentSessionId = saved.sessionId
      let fetched = try await profileService.myProfile(sessionId: saved.sessionId)
      guard isCurrent(saved.sessionId, token: token) else { return }
      let updated = SessionManager.StoredSession(sessionId: saved.sessionId, needsProfileSetup: saved.needsProfileSetup,
                                             profile: fetched, routingVersion: saved.routingVersion)
      try sessions.save(updated)
      profile = fetched
      profileError = nil
      isLoggedIn = !saved.needsProfileSetup
    } catch is CancellationError {
      // 다음에 창을 열었을 때 다시 확인할 수 있도록 한다.
      if revision == token { didRestore = false }
    } catch {
      guard revision == token else { return }
      if let apiError = error as? SessionAPIError, apiError.isUnauthorized || apiError.isNotFound,
         let id = currentSessionId {
        invalidateSession(ifMatching: id)
      } else {
        startupError = error.localizedDescription
      }
    }
  }

  /// 시작 확인 실패 후 사용자가 명시적으로 선택한 로컬 재로그인 복구.
  func restartSignIn() {
    guard startupError != nil, !isRestoringSession else { return }
    do {
      if let saved = try sessions.load() {
        guard currentSessionId == nil || currentSessionId == saved.sessionId,
              try sessions.delete(ifMatching: saved.sessionId) else {
          startupError = "로그인 상태가 변경되었어요. 다시 시도로 현재 상태를 확인해주세요."
          return
        }
      }
      var notice: String?
      do { try signOutFirebase() } catch {
        notice = "앱 세션은 정리했지만 Firebase 인증 정리를 완료하지 못했어요. 다시 로그인해주세요."
      }
      clearAuthentication(notice: notice)
    } catch {
      // 저장소 정리에 실패하면 오류 화면을 유지하고 기존 세션을 자동 재사용하지 않는다.
      startupError = error.localizedDescription
    }
  }

  func completeAuthentication(profile: UserProfile?, imageData: Data?) {
    profileTask?.cancel()
    isRefreshingProfile = false
    revision = UUID()
    authenticationNotice = nil
    startupError = nil
    profileError = nil
    self.profile = profile
    profileImageData = imageData
    currentSessionId = (try? sessions.load())?.sessionId
    isLoggedIn = true
    isRestoringSession = false
    didRestore = true
    profileTask = Task { [weak self] in await self?.refreshProfile() }
  }

  func refreshProfile() async {
    guard isLoggedIn, !isRefreshingProfile else { return }
    let token = revision
    isRefreshingProfile = true
    profileError = nil
    defer { if revision == token { isRefreshingProfile = false } }
    do {
      guard let saved = try sessions.load() else { return }
      let fetched = try await profileService.myProfile(sessionId: saved.sessionId)
      guard isCurrent(saved.sessionId, token: token) else { return }
      if profile?.profileImageFileName != fetched.profileImageFileName { profileImageData = nil }
      try sessions.save(SessionManager.StoredSession(sessionId: saved.sessionId, needsProfileSetup: saved.needsProfileSetup,
                                                     profile: fetched, routingVersion: saved.routingVersion))
      profile = fetched
    } catch is CancellationError {
    } catch {
      guard revision == token else { return }
      if let apiError = error as? SessionAPIError, apiError.isUnauthorized || apiError.isNotFound,
         let id = currentSessionId {
        invalidateSession(ifMatching: id)
      } else {
        profileError = error.localizedDescription
      }
    }
  }

  func applyProfileUpdate(_ updated: UserProfile, imageData: Data?, ifMatching id: String) throws {
    guard isLoggedIn, currentSessionId == id, let saved = try sessions.load(), saved.sessionId == id else {
      throw SessionAPIError.rejected("로그인 상태가 변경되었어요. 다시 로그인한 뒤 프로필을 변경해주세요.")
    }
    // 업로드 이전에 시작한 조회가 새 이미지 파일명을 덮어쓰지 못하게 한다.
    profileTask?.cancel()
    revision = UUID()
    isRefreshingProfile = false
    try sessions.save(SessionManager.StoredSession(sessionId: id, needsProfileSetup: saved.needsProfileSetup,
      profile: updated, routingVersion: saved.routingVersion))
    let retainedImage = imageData ?? (profile?.profileImageFileName == updated.profileImageFileName ? profileImageData : nil)
    profile = updated
    profileImageData = retainedImage
    profileError = nil
  }

  @discardableResult
  func invalidateSession(ifMatching id: String) -> Bool {
    do {
      guard try sessions.delete(ifMatching: id) else { return false }
      var notice = "세션이 만료되었거나 유효하지 않아요. 다시 로그인해주세요."
      do { try signOutFirebase() } catch { notice += " Firebase 인증 정리를 완료하지 못했어요." }
      clearAuthentication(notice: notice)
      return true
    } catch {
      authenticationNotice = error.localizedDescription
      profileError = error.localizedDescription
      return false
    }
  }

  func clearAuthentication(notice: String? = nil) {
    profileTask?.cancel()
    revision = UUID()
    authenticationNotice = notice
    isLoggedIn = false
    isRestoringSession = false
    startupError = nil
    profileError = nil
    isRefreshingProfile = false
    currentSessionId = nil
    profile = nil
    profileImageData = nil
  }

  private func isCurrent(_ id: String, token: UUID) -> Bool {
    revision == token && (try? sessions.load())?.sessionId == id
  }
}
