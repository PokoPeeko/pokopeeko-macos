import Foundation
import Observation

@MainActor
@Observable
final class NicknameEditViewModel {
  struct Update { let sessionID: String; let profile: UserProfile }
  var nickname: String
  private(set) var isSaving = false
  var errorMessage: String?
  private var originalName: String
  private let service: AuthService
  private let sessions: any SessionStoring

  init(currentName: String?, service: AuthService? = nil, sessions: (any SessionStoring)? = nil) {
    nickname = currentName ?? ""
    originalName = currentName ?? ""
    self.service = service ?? AuthService()
    self.sessions = sessions ?? KeychainSessionStore()
  }

  var isValid: Bool { (1...10).contains(nickname.count) && !nickname.contains(where: \.isWhitespace) }
  var canSave: Bool { isValid && nickname != originalName && !isSaving }

  func synchronize(currentName: String?) {
    guard !isSaving else { return }
    let hasDraft = nickname != originalName
    originalName = currentName ?? ""
    if !hasDraft { nickname = originalName }
  }

  func acceptSavedName(_ name: String?) {
    originalName = name ?? ""
    nickname = originalName
    errorMessage = nil
  }

  func save(onSessionExpired: (String) -> Void) async -> Update? {
    guard canSave else { return nil }
    let submittedName = nickname
    isSaving = true
    errorMessage = nil
    defer { isSaving = false }
    var requestSessionID: String?
    do {
      guard let saved = try sessions.load(), !saved.needsProfileSetup else { throw AuthServiceError.sessionChanged }
      requestSessionID = saved.sessionId
      let response = try await service.setupProfile(
        requestDTO: ProfileSetupRequestDTO(displayName: submittedName, profileImage: nil), sessionId: saved.sessionId)
      try Task.checkCancellation()
      guard try sessions.load()?.sessionId == saved.sessionId else { throw AuthServiceError.sessionChanged }
      guard let name = response.data.displayName, (1...10).contains(name.count),
            !name.contains(where: \.isWhitespace) else { throw AuthServiceError.invalidResponse }
      return Update(sessionID: saved.sessionId, profile: UserProfile(id: saved.profile?.id, displayName: name,
        profileImageFileName: response.data.profileImage ?? saved.profile?.profileImageFileName))
    } catch is CancellationError {
    } catch {
      if let requestSessionID, (try? sessions.load())?.sessionId != requestSessionID { return nil }
      if (error as? AuthServiceError)?.isUnauthorized == true, let requestSessionID { onSessionExpired(requestSessionID) }
      errorMessage = error.localizedDescription
    }
    return nil
  }
}
