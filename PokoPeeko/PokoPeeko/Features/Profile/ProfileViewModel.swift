//

import Foundation
import Observation
import FirebaseAuth

@Observable
final class ProfileViewModel {
  private let authService = AuthService()

  var isLoading: Bool = false
  var errorMessage: String?

  func logout() async -> Bool {
    guard let sessionId = SessionManager.sessionId else {
      return false
    }

    isLoading = true
    defer { isLoading = false }

    do {
      try await authService.logout(sessionId: sessionId)

      SessionManager.delete()

      try Auth.auth().signOut()

      return true

    } catch {
      errorMessage = error.localizedDescription
      print(errorMessage!)
      return false
    }
  }
}
