//

import SwiftUI
import AuthenticationServices

struct SignInView: View {
  @Environment(AppState.self) private var appState
  @State private var viewModel = SignInViewModel()

  var body: some View {
    VStack(spacing: 24) {

      Text("PeekoPoko")
        .font(.largeTitle)
        .fontWeight(.bold)

      Text("친구들과 지금 무엇을 하고 있는지 공유해보세요.")
        .foregroundStyle(.secondary)

      if viewModel.needsProfileSetup {
        profileSetupView
      } else {
        appleSignInButton
      }

      if viewModel.isLoading {
        ProgressView()
      }

      if let errorMessage = viewModel.errorMessage {
        Text(errorMessage)
          .foregroundStyle(.red)
      }
    }
    .padding(40)
    .frame(width: 420, height: 300)
  }

  private var appleSignInButton: some View {
    SignInWithAppleButton(.continue) { request in
      let nonce = AppleAuthHelper.randomNonceString()

      viewModel.currentNonce = nonce
      request.nonce = AppleAuthHelper.sha256(nonce)
    } onCompletion: { result in
      switch result {
      case .success(let authorization):
        guard let credential =
                authorization.credential as? ASAuthorizationAppleIDCredential
        else {
          return
        }

        Task {
          await viewModel.signInWithApple(credential: credential)
        }

      case .failure(let error):
        viewModel.errorMessage = error.localizedDescription
      }
    }
//    .disabled(!viewModel.isValidDisplayName)
    .frame(height: 44)

  }

  private var profileSetupView: some View {
    VStack(spacing: 16) {
      Text("프로필 설정")
        .font(.headline)
      Text("친구들한테 보여질 프로필을 설정해보세요.")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Button {

      } label: {
        ZStack {
          Circle()
            .fill(.quaternary)
            .frame(width: 88, height: 88)

          Image(systemName: "person.fill")
            .font(.system(size: 36))
            .foregroundStyle(.secondary)

          Image(systemName: "camera.fill")
            .font(.system(size: 12))
            .padding(6)
            .background(.background)
            .clipShape(Circle())
            .offset(x: 32, y: 32)
        }
      }
      .buttonStyle(.plain)

      VStack(alignment: .leading, spacing: 6) {
        Text("닉네임")
          .font(.caption)
          .foregroundStyle(.secondary)

        TextField(
          "닉네임을 입력해주세요.",
          text: $viewModel.displayName
        )
        .textFieldStyle(.roundedBorder)

        Button("시작하기") {
          Task {
            await viewModel.setupProfile()
          }
        }
        .onChange(of: viewModel.isAuthenticated) { _, isAuthenticated in
          if isAuthenticated {
            appState.isLoggedIn = true
          }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .disabled(
          viewModel.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        )
      }
      .frame(maxWidth: 280)
    }
  }
}

#Preview {
  SignInView()
}
