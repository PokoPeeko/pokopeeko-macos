import Foundation
import Observation
import FirebaseAuth
import AuthenticationServices

@MainActor
@Observable
final class SignInViewModel {
  private let authService: AuthService
  private var currentNonce: String?

  private(set) var isLoading = false
  private(set) var errorMessage: String?
  var displayName = ""
  private(set) var needsProfileSetup = false
  private(set) var isAuthenticated = false
  private(set) var selectedImageData: Data?
  private(set) var profile: UserProfile?

  init(authService: AuthService? = nil) {
    self.authService = authService ?? AuthService()
    do {
      if let saved = try SessionManager.load(), saved.needsProfileSetup {
        needsProfileSetup = true
        displayName = saved.profile?.displayName ?? ""
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  var isValidDisplayName: Bool {
    (1...10).contains(displayName.count) && !displayName.contains { $0.isWhitespace }
  }

  var canSubmitProfile: Bool { isValidDisplayName && !isLoading }

  func beginAppleSignIn() -> String? {
    guard !isLoading else { return nil }
    isLoading = true
    errorMessage = nil
    do {
      let nonce = try AppleAuthHelper.randomNonceString()
      currentNonce = nonce
      return AppleAuthHelper.sha256(nonce)
    } catch {
      currentNonce = nil
      isLoading = false
      errorMessage = error.localizedDescription
      return nil
    }
  }

  func handleAuthorizationError(_ error: Error) {
    currentNonce = nil
    isLoading = false
    let nsError = error as NSError
    if nsError.domain == ASAuthorizationError.errorDomain,
       nsError.code == ASAuthorizationError.canceled.rawValue {
      errorMessage = nil
    } else {
      errorMessage = "Apple 로그인에 실패했어요. 다시 시도해주세요."
    }
  }

  func signInWithApple(credential: ASAuthorizationAppleIDCredential) async {
    defer { isLoading = false; currentNonce = nil }
    guard let nonce = currentNonce,
          let tokenData = credential.identityToken,
          let appleIDToken = String(data: tokenData, encoding: .utf8) else {
      errorMessage = "Apple 인증 정보를 확인할 수 없어요. 다시 시도해주세요."
      return
    }
    var stage = "Firebase 인증"
    do {
      let firebaseCredential = OAuthProvider.appleCredential(withIDToken: appleIDToken, rawNonce: nonce, fullName: nil)
      let result = try await Auth.auth().signIn(with: firebaseCredential)
      let firebaseIDToken = try await result.user.getIDToken()
      stage = "서버 로그인"
      let response = try await authService.loginWithApple(firebaseIDToken: firebaseIDToken, deviceID: DeviceIDManager.deviceID)
      try Task.checkCancellation()
      // 임시 진단: 사용자 요청에 따라 서버 플래그를 반대로 해석한다.
      // 백엔드 의미를 확인한 뒤 원복할 때 SessionManager의 routingVersion도 갱신한다.
      let requiresProfileSetup = !response.data.needsProfileSetup
      stage = "로그인 정보 저장"
      try SessionManager.save(sessionId: response.data.sessionId, needsProfileSetup: requiresProfileSetup)
      needsProfileSetup = requiresProfileSetup
      profile = nil
      isAuthenticated = !requiresProfileSetup
    } catch is CancellationError {
      errorMessage = nil
    } catch {
      errorMessage = "\(stage) 실패: \(error.localizedDescription)"
    }
  }

  func selectImage(at url: URL) {
    guard !isLoading else { return }
    let accessed = url.startAccessingSecurityScopedResource()
    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
    do {
      selectedImageData = try ProfileImageProcessor.pngData(from: Data(contentsOf: url, options: .mappedIfSafe))
      errorMessage = nil
    } catch {
      errorMessage = "이미지를 읽지 못했어요. 다른 이미지 파일을 선택해주세요."
    }
  }

  func removeSelectedImage() {
    guard !isLoading else { return }
    selectedImageData = nil
    errorMessage = nil
  }

  func imageSelectionFailed() {
    errorMessage = "이미지 파일을 선택하지 못했어요. 다시 시도해주세요."
  }

  func setupProfile() async {
    guard !isLoading else { return }
    guard isValidDisplayName else {
      errorMessage = "닉네임은 공백 없이 1~10자로 입력해주세요."
      return
    }
    let image = selectedImageData
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    var requestSessionId: String?
    do {
      guard let saved = try SessionManager.load(), saved.needsProfileSetup else {
        throw AuthServiceError.http(status: 401, message: nil)
      }
      requestSessionId = saved.sessionId
      let request = ProfileSetupRequestDTO(displayName: displayName, profileImage: image)
      let response = try await authService.setupProfile(requestDTO: request, sessionId: saved.sessionId)
      guard let name = response.data.displayName, !name.isEmpty else {
        throw AuthServiceError.invalidResponse
      }
      if image != nil, response.data.profileImage?.isEmpty != false {
        throw AuthServiceError.invalidResponse
      }
      guard try SessionManager.load()?.sessionId == saved.sessionId else {
        throw AuthServiceError.sessionChanged
      }
      let profile = UserProfile(id: saved.profile?.id, displayName: name, profileImageFileName: response.data.profileImage)
      try SessionManager.save(sessionId: saved.sessionId, needsProfileSetup: false, profile: profile)
      self.profile = profile
      needsProfileSetup = false
      isAuthenticated = true
    } catch is CancellationError {
      errorMessage = nil
    } catch {
      if let serviceError = error as? AuthServiceError, serviceError.isUnauthorized {
        do {
          let canReset: Bool
          if let requestSessionId {
            canReset = try SessionManager.delete(ifMatching: requestSessionId)
          } else {
            canReset = try SessionManager.load() == nil
          }
          if canReset {
            try Auth.auth().signOut()
            needsProfileSetup = false
            selectedImageData = nil
          }
        } catch {
          errorMessage = error.localizedDescription
          return
        }
      }
      errorMessage = error.localizedDescription
    }
  }
}
