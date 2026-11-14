import SwiftUI

struct ProfileView: View {
  @Environment(AppState.self) private var appState
  @State private var viewModel = ProfileViewModel()

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Button("로그아웃") {
        Task {
          if await viewModel.logout() { appState.clearAuthentication(notice: viewModel.errorMessage) }
        }
      }
      .disabled(viewModel.isLoading)
      if viewModel.isLoading { ProgressView().controlSize(.small) }
      if let error = viewModel.errorMessage {
        Text(error).font(.callout).foregroundStyle(.red)
      }
    }
  }
}

#Preview {
  ProfileView().environment(AppState())
}
