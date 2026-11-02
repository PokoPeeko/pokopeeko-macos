//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {
  @Environment(AppState.self) private var appState
  @State private var viewModel = ProfileViewModel()
  var body: some View {

#if DEBUG
    Button("인증 초기화") {
      SessionManager.delete()
      try? Auth.auth().signOut()
      appState.isLoggedIn = false
    }
#endif

    Button {
      Task {
        let success = await viewModel.logout()

        if success {
          appState.isLoggedIn = false
        }
      }
    } label: {
      Text("로그아웃")
    }
    .disabled(viewModel.isLoading)
  }
}

#Preview {
  ProfileView()
}
