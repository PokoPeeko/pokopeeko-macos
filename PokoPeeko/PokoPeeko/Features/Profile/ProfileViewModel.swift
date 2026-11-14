import Foundation
import Observation
import FirebaseAuth

@MainActor
@Observable
final class ProfileViewModel {
  private let authService = AuthService()
  private(set) var isLoading = false
  private(set) var errorMessage: String?



  func logout() async -> Bool {
    guard !isLoading else { return false }
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
      if let saved = try SessionManager.load() {
        do {
          try await authService.logout(sessionId: saved.sessionId)
        } catch let error as AuthServiceError where error.isUnauthorized {
          // 이미 무효화된 서버 세션은 로컬에서도 정리한다.
        }
        guard try SessionManager.delete(ifMatching: saved.sessionId) else {
          errorMessage = "로그인 상태가 변경되었어요. 현재 상태를 확인해주세요."
          return false
        }
      }
      do {
        try Auth.auth().signOut()
      } catch {
        // 서버/앱 세션이 이미 정리되었으므로 화면은 로그아웃하고 남은 오류를 전달한다.
        errorMessage = "앱에서 로그아웃했지만 Firebase 인증 정리를 완료하지 못했어요. 다시 로그인해주세요."
      }
      return true
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }

}
