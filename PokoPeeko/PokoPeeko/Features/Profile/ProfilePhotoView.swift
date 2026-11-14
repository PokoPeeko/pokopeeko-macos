import SwiftUI
import UniformTypeIdentifiers

struct ProfilePhotoView: View {
  @Environment(AppState.self) private var appState
  @Environment(\.dismiss) private var dismiss
  @State private var viewModel = ProfilePhotoViewModel()
  @State private var isChoosingImage = false

  var body: some View {
    VStack(spacing: 20) {
      Text("프로필 사진 변경").font(.title2.bold())
      ProfileAvatarView(imageData: viewModel.imageData ?? appState.profileImageData,
        imageURL: viewModel.imageData == nil ? appState.profile?.profileImageURL : nil, size: 110)
      Button("사진 선택") { isChoosingImage = true }.disabled(viewModel.isSaving)
      Text("사진을 선택한 뒤 저장하면 친구들에게도 새 사진이 표시됩니다.")
        .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
      if let error = viewModel.errorMessage {
        Text(error).font(.callout).foregroundStyle(.red).multilineTextAlignment(.center)
      }
      if viewModel.isSaving { ProgressView("사진을 저장하고 있어요").controlSize(.small) }
      HStack {
        Spacer()
        Button("취소") { dismiss() }.keyboardShortcut(.cancelAction).disabled(viewModel.isSaving)
        Button("저장") {
          Task {
            guard let update = await viewModel.upload(onSessionExpired: { id in
              _ = appState.invalidateSession(ifMatching: id)
            }) else { return }
            do {
              try appState.applyProfileUpdate(update.profile, imageData: update.imageData, ifMatching: update.sessionID)
              dismiss()
            } catch { viewModel.errorMessage = error.localizedDescription }
          }
        }
        .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
        .disabled(viewModel.imageData == nil || viewModel.isSaving)
      }
    }
    .padding(28).frame(width: 420)
    .onChange(of: appState.currentSessionId) { _, _ in dismiss() }
    .fileImporter(isPresented: $isChoosingImage, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
      switch result {
      case .success(let urls): if let url = urls.first { viewModel.selectImage(at: url) }
      case .failure(let error):
        if (error as NSError).code != NSUserCancelledError { viewModel.errorMessage = "사진을 선택하지 못했어요." }
      }
    }
  }
}
