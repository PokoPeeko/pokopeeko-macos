import SwiftUI

struct FriendStatusView: View {
  @Environment(AppState.self) private var appState
  @Environment(MainViewModel.self) private var model
  @Environment(\.openWindow) private var openWindow
  @State private var onlineOnly = false

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        Image(systemName: "person.2.wave.2.fill").foregroundStyle(.tint)
        Text("PokoPeeko").font(.headline)
        Spacer()
        Button { showMain(.settings) } label: {
          Image(systemName: "gearshape")
        }
        .buttonStyle(.plain)
        .help("설정 열기").accessibilityLabel("설정 열기")
      }
      .padding(18)
      Divider()
      HStack {
        Text("친구들의 지금").font(.subheadline.weight(.semibold))
        Text("\(model.onlineFriends.count)명 온라인").font(.caption).foregroundStyle(.secondary)
        Spacer()
        Toggle("온라인만", isOn: $onlineOnly)
          .toggleStyle(.button).font(.caption)
      }
      .padding(.horizontal, 18).padding(.vertical, 12)

      if model.isShowingSamples {
        Label("샘플 데이터", systemImage: "eye")
          .font(.caption).foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 18).padding(.bottom, 8)
      }

      ScrollView {
        if model.friends.isEmpty {
          ContentUnavailableView("아직 연결된 친구가 없어요", systemImage: "person.2",
                                 description: Text("친구 연결 기능을 준비하고 있어요."))
            .frame(minHeight: 230)
        } else if visibleFriends.isEmpty {
          ContentUnavailableView("온라인인 친구가 없어요", systemImage: "moon.zzz",
                                 description: Text("온라인 필터를 끄면 모든 친구를 볼 수 있어요."))
            .frame(minHeight: 230)
        } else {
          FriendStatusList(friends: visibleFriends).padding(.horizontal, 18)
        }
      }
      .frame(height: 300)
      Divider()
      HStack {
        Button { showMain(.friends) } label: {
          Label("친구 보기", systemImage: "person.2")
        }
        Spacer()
        Button { showMain(.dashboard) } label: {
          Label("메인 앱 열기", systemImage: "arrow.up.forward.app")
        }
      }
      .buttonStyle(.plain).font(.caption).padding(18)
    }
    .frame(width: 360)
  }

  private var visibleFriends: [Friend] {
    model.friends.filter { !onlineOnly || $0.isOnline }
  }

  private func showMain(_ section: MainSection) {
    model.selection = section
    #if DEBUG
    openWindow(id: appState.isLoggedIn ? "main" : "ui-preview")
    #else
    openWindow(id: "main")
    #endif
  }
}

#Preview {
  FriendStatusView().environment(MainViewModel()).environment(AppState())
}
