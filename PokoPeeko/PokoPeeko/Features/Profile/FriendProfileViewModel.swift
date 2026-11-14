import Foundation
import Observation

@MainActor
@Observable
final class FriendProfileViewModel {
  private(set) var profile: UserProfile?
  private(set) var isLoading = false
  private(set) var errorMessage: String?
  private let service: ProfileService
  private let sessions: any SessionStoring
  private let cache: ProfileSnapshotCache
  private var generation = UUID()
  private var profileSessionID: String?

  init(service: ProfileService? = nil, sessions: (any SessionStoring)? = nil,
       cache: ProfileSnapshotCache? = nil, initialProfile: UserProfile? = nil) {
    self.service = service ?? ProfileService()
    self.sessions = sessions ?? KeychainSessionStore()
    self.cache = cache ?? .shared
    profile = initialProfile
  }

  func load(id: UUID, onSessionExpired: (String) -> Void) async {
    let token = UUID()
    generation = token
    errorMessage = nil
    isLoading = true
    defer { if generation == token { isLoading = false } }
    var requestSessionID: String?
    var ownerID: UUID?
    do {
      guard let saved = try sessions.load(), !saved.needsProfileSetup else {
        profile = nil
        errorMessage = "로그인 후 프로필을 확인해주세요."
        return
      }
      requestSessionID = saved.sessionId
      ownerID = saved.profile?.id
      if profile?.id != id || (profileSessionID != nil && profileSessionID != saved.sessionId) { profile = nil }
      if let ownerID, profile == nil { profile = cache.profile(owner: ownerID, id: id) }
      profileSessionID = saved.sessionId
      let result = try await service.userProfile(id: id, sessionId: saved.sessionId)
      try Task.checkCancellation()
      guard generation == token, try sessions.load()?.sessionId == saved.sessionId else { return }
      profile = result
      if let ownerID { cache.save(result, owner: ownerID) }
    } catch is CancellationError {
    } catch {
      guard generation == token, !Task.isCancelled else { return }
      guard let requestSessionID else { errorMessage = error.localizedDescription; return }
      guard (try? sessions.load())?.sessionId == requestSessionID else { return }
      if let apiError = error as? SessionAPIError, apiError.isUnauthorized || apiError.isNotFound {
        profile = nil
        if let ownerID { cache.remove(owner: ownerID, id: id) }
        if apiError.isUnauthorized { onSessionExpired(requestSessionID) }
      }
      errorMessage = error.localizedDescription
    }
  }
}
