import Foundation
import Observation

@MainActor
@Observable
final class ProfilePhotoViewModel {
  struct Update {
    let sessionID: String
    let profile: UserProfile
    let imageData: Data
  }
  private(set) var imageData: Data?
  private(set) var isSaving = false
  var errorMessage: String?
  private let service: AuthService
  private let sessions: any SessionStoring

  init(service: AuthService? = nil, sessions: (any SessionStoring)? = nil) {
    self.service = service ?? AuthService()
    self.sessions = sessions ?? KeychainSessionStore()
  }

  func selectImage(at url: URL) {
    guard !isSaving else { return }
    let accessed = url.startAccessingSecurityScopedResource()
    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
    do {
      imageData = try ProfileImageProcessor.pngData(from: Data(contentsOf: url, options: .mappedIfSafe))
      errorMessage = nil
    } catch { errorMessage = "사진을 읽지 못했어요. 다른 이미지 파일을 선택해주세요." }
  }

  func upload(onSessionExpired: (String) -> Void) async -> Update? {
    guard !isSaving, let imageData else { return nil }
    isSaving = true
    errorMessage = nil
    defer { isSaving = false }
    var requestSessionID: String?
    do {
      guard let saved = try sessions.load(), !saved.needsProfileSetup else {
        throw AuthServiceError.sessionChanged
      }
      requestSessionID = saved.sessionId
      let response = try await service.setupProfile(
        requestDTO: ProfileSetupRequestDTO(displayName: nil, profileImage: imageData), sessionId: saved.sessionId)
      try Task.checkCancellation()
      guard try sessions.load()?.sessionId == saved.sessionId else { throw AuthServiceError.sessionChanged }
      guard let filename = response.data.profileImage, APIConfig.profileImageURL(fileName: filename) != nil else {
        throw AuthServiceError.invalidResponse
      }
      return Update(sessionID: saved.sessionId,
        profile: UserProfile(id: saved.profile?.id, displayName: response.data.displayName ?? saved.profile?.displayName,
                             profileImageFileName: filename), imageData: imageData)
    } catch is CancellationError {
    } catch {
      if let requestSessionID, (try? sessions.load())?.sessionId != requestSessionID { return nil }
      if (error as? AuthServiceError)?.isUnauthorized == true, let requestSessionID {
        onSessionExpired(requestSessionID)
      }
      errorMessage = error.localizedDescription
    }
    return nil
  }
}
