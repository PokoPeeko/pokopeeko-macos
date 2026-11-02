//

import Foundation
import Observation
import FirebaseAuth
import AuthenticationServices

@Observable
final class SignInViewModel {
  private let authService = AuthService()

  var isLoading: Bool = false
  var errorMessage: String?
  var displayName: String = ""
  var needsProfileSetup: Bool = false
  var isAuthenticated: Bool = false
  var currentNonce: String?

  var isValidDisplayName: Bool {
    let count = displayName.count
    let hasWhiteSpace = displayName.contains { $0.isWhitespace }

    return (1...10).contains(count) && !hasWhiteSpace
  }

  func signInWithApple(credential: ASAuthorizationAppleIDCredential) async {
    guard let nonce = currentNonce else { return }

    guard let tokenData = credential.identityToken,
          let appleIDToken = String(data: tokenData, encoding: .utf8)
    else {
      return
    }

    do {

      let firebaseCredential = OAuthProvider.appleCredential(
        withIDToken: appleIDToken,
        rawNonce: nonce,
        fullName: nil
      )

      let result = try await Auth.auth().signIn(
        with: firebaseCredential
      )

      let firebaseIDToken = try await result.user.getIDToken()

      let response = try await authService.loginWithApple(
        firebaseIDToken: firebaseIDToken,
        deviceID: DeviceIDManager.deviceID
      )

      SessionManager.save(sessionId: response.data.sessionId)

      needsProfileSetup = true

    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func setupProfile() async {
    guard !isLoading else { return }

    guard isValidDisplayName else {
      errorMessage = "닉네임은 공백 없이 1~10자로 입력해주세요."
      return
    }

    guard let sessionId = SessionManager.sessionId else {
      errorMessage = "로그인 세션이 없습니다."
      return
    }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let requestDTO = ProfileSetupRequestDTO(displayName: displayName)

      try await authService.setupProfile(
        requestDTO: requestDTO,
        sessionId: sessionId
      )

      needsProfileSetup = false
      isAuthenticated = true

    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
