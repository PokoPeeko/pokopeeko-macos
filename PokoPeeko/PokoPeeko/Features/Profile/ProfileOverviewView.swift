import SwiftUI
import AppKit

struct ProfileOverviewView: View {
  @Environment(AppState.self) private var appState
  @State private var isChangingPhoto = false
  @State private var nickname = NicknameEditViewModel(currentName: nil)

  var body: some View {
    @Bindable var editor = nickname
    ActivityCard {
      VStack(alignment: .leading, spacing: 24) {
        HStack {
          Label("나의 프로필", systemImage: "person.crop.circle").font(.headline)
          Spacer()
          if appState.isRefreshingProfile { ProgressView().controlSize(.small) }
          Button { Task { await appState.refreshProfile() } } label: {
            Image(systemName: "arrow.clockwise")
          }
          .disabled(appState.isRefreshingProfile || nickname.isSaving)
          .help("프로필 새로고침").accessibilityLabel("프로필 새로고침")
        }
        HStack(alignment: .center, spacing: 24) {
          Button { isChangingPhoto = true } label: {
            ProfileAvatarView(imageData: appState.profileImageData, imageURL: appState.profile?.profileImageURL, size: 88)
              .overlay(alignment: .bottomTrailing) {
                Image(systemName: "camera.fill")
                  .font(.system(size: 11)).padding(8)
                  .background(.background, in: Circle())
                  .overlay { Circle().strokeBorder(.primary.opacity(0.1)) }
              }
          }
          .buttonStyle(.plain).disabled(nickname.isSaving)
          .help("프로필 사진 변경").accessibilityLabel("프로필 사진 변경")

          VStack(alignment: .leading, spacing: 10) {
            Text("닉네임").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 10) {
              TextField("공백 없이 1~10자", text: $editor.nickname)
                .textFieldStyle(.roundedBorder)
                .disabled(nickname.isSaving)
                .accessibilityLabel("닉네임")
                .onSubmit { if nickname.canSave { Task { await saveNickname() } } }
              Button("변경하기") { Task { await saveNickname() } }
                .disabled(!nickname.canSave || appState.isRefreshingProfile)
              if nickname.isSaving { ProgressView().controlSize(.small) }
            }
            .frame(maxWidth: 480)

          }
          Spacer(minLength: 0)
        }
        if let error = nickname.errorMessage ?? appState.profileError {
          Text(error).font(.callout).foregroundStyle(.red)
        }
        Divider()
        Label("계정", systemImage: "person.badge.key").font(.headline)
        ProfileView().disabled(nickname.isSaving)
      }
    }
    .onAppear { nickname.synchronize(currentName: appState.profile?.displayName) }
    .onChange(of: appState.profile?.displayName) { _, name in nickname.synchronize(currentName: name) }
    .onChange(of: appState.currentSessionId) { _, _ in
      nickname = NicknameEditViewModel(currentName: appState.profile?.displayName)
    }
    .sheet(isPresented: $isChangingPhoto) { ProfilePhotoView() }
  }

  private func saveNickname() async {
    guard !appState.isRefreshingProfile else { return }
    // Capture the editor so a late save cannot update a replacement account's draft.
    let editor = nickname
    guard let update = await editor.save(onSessionExpired: { id in
      _ = appState.invalidateSession(ifMatching: id)
    }) else { return }
    do {
      try appState.applyProfileUpdate(update.profile, imageData: nil, ifMatching: update.sessionID)
      editor.acceptSavedName(update.profile.displayName)
    } catch { editor.errorMessage = error.localizedDescription }
  }
}
