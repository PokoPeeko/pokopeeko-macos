import SwiftUI

struct FriendProfileView: View {
  let userID: UUID
  private let width: CGFloat
  private let onClose: (() -> Void)?
  @Environment(AppState.self) private var appState
  @Environment(MainViewModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var confirmRemoval = false
  @State private var removalError: String?
  @State private var viewModel = FriendProfileViewModel()

  init(userID: UUID, initialProfile: UserProfile? = nil, width: CGFloat = 420, onClose: (() -> Void)? = nil) {
    self.userID = userID
    self.width = width
    self.onClose = onClose
    _viewModel = State(initialValue: FriendProfileViewModel(initialProfile: initialProfile))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 22) {
      HStack {
        Text("친구 프로필").font(.title2.bold())
        Spacer()
        if onClose == nil {
          Button("닫기") { close() }.keyboardShortcut(.cancelAction)
        } else {
          Button("닫기") { close() }
        }
      }
      if viewModel.isLoading && viewModel.profile == nil {
        ProgressView("프로필을 불러오는 중").frame(maxWidth: .infinity, minHeight: 200)
      } else if let profile = viewModel.profile {
        VStack(spacing: 14) {
          ProfileAvatarView(imageData: nil, imageURL: profile.profileImageURL, size: 88)
          Text(profile.displayLabel).font(.title2.bold())
          if let friend = model.friends.first(where: { $0.id == userID }) {
            Divider()
            FriendPresenceRow(friend: friend, opensProfile: false)
          }
        }
        .frame(maxWidth: .infinity)
      }
      if let error = viewModel.errorMessage {
        Text(error).font(.callout).foregroundStyle(.red)
      }
      if onClose != nil && confirmRemoval {
        VStack(alignment: .leading, spacing: 12) {
          Text("친구를 삭제할까요?").font(.headline)
          Text("\(viewModel.profile?.displayLabel ?? "이 친구")님과 친구 연결을 해제합니다.")
            .font(.callout).foregroundStyle(.secondary)
          HStack {
            Button("취소") { confirmRemoval = false }
            Spacer()
            Button("삭제", role: .destructive) { removeFriend() }
          }
          .disabled(model.friendsModel.isMutating)
        }
        .padding(14)
        .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
      }
      if let removalError { Text(removalError).font(.callout).foregroundStyle(.red) }
      HStack {
        if model.friendsModel.friends.contains(where: { $0.id == userID }) {
          Button("친구 삭제", role: .destructive) { confirmRemoval = true }
            .disabled(model.friendsModel.isMutating)
        }
        if model.friendsModel.isMutating { ProgressView().controlSize(.small) }
        if viewModel.isLoading && viewModel.profile != nil { ProgressView().controlSize(.small) }
        Spacer()
        Button("새로고침") { Task { await load() } }.disabled(viewModel.isLoading)
      }
    }
    .padding(28).frame(width: width).frame(minHeight: 300)
    .background {
      if onClose == nil { Rectangle().fill(.background) }
    }
    .alert("친구를 삭제할까요?", isPresented: Binding(
      get: { confirmRemoval && onClose == nil }, set: { confirmRemoval = $0 }
    )) {
      Button("삭제", role: .destructive) { removeFriend() }
      Button("취소", role: .cancel) { }
    } message: {
      Text("\(viewModel.profile?.displayLabel ?? "이 친구")님과 친구 연결을 해제합니다.")
    }
    .task { await load() }
    .onChange(of: appState.currentSessionId) { _, _ in close() }
  }

  private func close() {
    if let onClose { onClose() }
    else { dismiss() }
  }

  private func removeFriend() {
    removalError = nil
    Task {
      if await model.friendsModel.removeFriend(id: userID) { close() }
      else { removalError = model.friendsModel.actionError }
    }
  }

  private func load() async {
    await viewModel.load(id: userID) { id in _ = appState.invalidateSession(ifMatching: id) }
  }
}
