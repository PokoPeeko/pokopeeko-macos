import SwiftUI

struct ProfileOverviewView: View {
  @Environment(AppState.self) private var appState
  @Environment(MainViewModel.self) private var model

  var body: some View {
    ActivityCard {
      VStack(alignment: .leading, spacing: 24) {
        HStack(spacing: 18) {
          Image(systemName: "person.crop.circle.fill")
            .font(.system(size: 64)).foregroundStyle(.tint.opacity(0.65))
          VStack(alignment: .leading, spacing: 6) {
            Text(model.isShowingSamples ? "나의 프로필 · 샘플" : "나의 프로필").font(.title2.bold())
            Text("프로필 조회와 수정 기능은 준비 중이에요.").foregroundStyle(.secondary)
          }
        }
        Divider()
        Label("계정", systemImage: "person.badge.key").font(.headline)
        if appState.isLoggedIn && !model.isShowingSamples {
          ProfileView()
        } else {
          Text("UI 미리보기에서는 계정 정보를 조회하거나 변경하지 않아요.")
            .foregroundStyle(.secondary)
        }
      }
    }
  }
}
