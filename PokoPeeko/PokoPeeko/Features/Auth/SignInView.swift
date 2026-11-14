import SwiftUI
import AppKit
import AuthenticationServices
import UniformTypeIdentifiers

struct SignInView: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(AppState.self) private var appState
  @State private var viewModel = SignInViewModel()
  @State private var isChoosingImage = false

  var body: some View {
    VStack(spacing: 24) {
      Text("PokoPeeko").font(.largeTitle.bold())
      Text("친구들과 지금 무엇을 하고 있는지 공유해보세요.")
        .foregroundStyle(.secondary).multilineTextAlignment(.center)

      if viewModel.needsProfileSetup {
        profileSetupView
      } else {
        appleSignInButton
      }

      if viewModel.isLoading {
        ProgressView(viewModel.needsProfileSetup ? "프로필을 저장하고 있어요" : "로그인하고 있어요")
          .controlSize(.small)
      }
      if let error = viewModel.errorMessage ?? appState.authenticationNotice {
        Text(error).font(.callout).foregroundStyle(.red)
          .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
          .accessibilityLabel("오류: \(error)")
      }

    }
    .padding(32)
    .frame(width: 440)
    .frame(minHeight: viewModel.needsProfileSetup ? 520 : 300)
    .background {
      RoundedRectangle(cornerRadius: 20)
        .fill(Color(nsColor: .windowBackgroundColor))
        .overlay {
          RoundedRectangle(cornerRadius: 20)
            .fill(LinearGradient(colors: [
              Color.accentColor.opacity(colorScheme == .dark ? 0.18 : 0.14),
              Color.accentColor.opacity(colorScheme == .dark ? 0.07 : 0.05)
            ], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay {
          RoundedRectangle(cornerRadius: 20).strokeBorder(Color.accentColor.opacity(0.14))
        }
    }
    .shadow(color: Color.accentColor.opacity(0.08), radius: 24, y: 10)
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background {
      ZStack {
        Color(nsColor: .windowBackgroundColor)
        LinearGradient(colors: [
          Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.18),
          Color.accentColor.opacity(0.08),
          Color.accentColor.opacity(0.03)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
      }
      .ignoresSafeArea()
    }
    .onChange(of: viewModel.isLoading) { _, loading in
      if loading { appState.authenticationNotice = nil }
    }
    .onChange(of: viewModel.isAuthenticated) { _, authenticated in
      if authenticated {
        appState.completeAuthentication(profile: viewModel.profile, imageData: viewModel.selectedImageData)
      }
    }
    .fileImporter(isPresented: $isChoosingImage, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
      switch result {
      case .success(let urls):
        if let url = urls.first { viewModel.selectImage(at: url) }
      case .failure:
        viewModel.imageSelectionFailed()
      }
    }
  }

  private var appleSignInButton: some View {
    SignInWithAppleButton(.continue) { request in
      request.nonce = viewModel.beginAppleSignIn()
    } onCompletion: { result in
      switch result {
      case .success(let authorization):
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
          viewModel.handleAuthorizationError(AuthServiceError.invalidResponse)
          return
        }
        Task { await viewModel.signInWithApple(credential: credential) }
      case .failure(let error):
        viewModel.handleAuthorizationError(error)
      }
    }
    .frame(height: 44)
    .disabled(viewModel.isLoading)
  }

  private var profileSetupView: some View {
    VStack(spacing: 18) {
      Text("프로필 설정").font(.headline)
      Text("친구들에게 보여줄 닉네임을 정해주세요. 사진은 선택이에요.")
        .font(.callout).foregroundStyle(.secondary)
      Button { isChoosingImage = true } label: {
        ProfileAvatarView(imageData: viewModel.selectedImageData, size: 88)
          .overlay(alignment: .bottomTrailing) {
            Image(systemName: "camera.fill")
              .font(.caption).padding(7)
              .background(.background, in: Circle())
          }
      }
      .buttonStyle(.plain).disabled(viewModel.isLoading)
      .accessibilityLabel("프로필 이미지 선택")
      Text(viewModel.selectedImageData == nil ? "프로필 사진 (선택)" : "사진을 눌러 변경")
        .font(.caption).foregroundStyle(.secondary)
      if viewModel.selectedImageData != nil {
        Button("사진 선택 취소") { viewModel.removeSelectedImage() }
          .buttonStyle(.link).font(.caption).disabled(viewModel.isLoading)
      }
      VStack(alignment: .leading, spacing: 8) {
        Text("닉네임").font(.caption).foregroundStyle(.secondary)
        TextField("공백 없이 1~10자", text: $viewModel.displayName)
          .textFieldStyle(.roundedBorder).disabled(viewModel.isLoading)
          .accessibilityLabel("닉네임")
        Button("시작하기") { Task { await viewModel.setupProfile() } }
          .buttonStyle(.borderedProminent).controlSize(.large)
          .frame(maxWidth: .infinity)
          .disabled(!viewModel.canSubmitProfile)
      }
    }
  }
}

#Preview {
  SignInView().environment(AppState())
}
