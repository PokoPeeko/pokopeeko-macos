import SwiftUI

struct DashboardView: View {
  @Environment(AppState.self) private var appState
  @Environment(MainViewModel.self) private var model
  @AppStorage("appearance") private var appearance = AppAppearance.system
  @State private var friendSearch = ""
  @State private var onlineOnly = false
  @State private var profileToShow: Friend?

  private var friends: [Friend] {
    model.friends.filter {
      (!onlineOnly || $0.isOnline == true) &&
      (friendSearch.isEmpty || $0.name.localizedCaseInsensitiveContains(friendSearch))
    }
  }

  var body: some View {
    VStack(spacing: 12) {
      profilePanel
      HStack(alignment: .top, spacing: 12) {
        friendsPanel
        appsPanel
      }
      HStack(alignment: .top, spacing: 12) {
        musicPanel
        settingsPanel
      }
      infoPanel
    }
    .sheet(item: $profileToShow) { friend in
      FriendProfileView(userID: friend.id, initialProfile: UserProfile(id: friend.id,
        displayName: friend.name, profileImageFileName: friend.profileImageFileName))
    }
  }

  private var profilePanel: some View {
    DashboardPanel(title: "프로필", destination: .profile) {
      HStack(spacing: 22) {
        ProfileAvatarView(imageData: appState.profileImageData, imageURL: appState.profile?.profileImageURL, size: 72)
        VStack(alignment: .leading, spacing: 10) {
          Text("계정").font(.caption).foregroundStyle(.secondary)
          Text("로그인됨")
            .fontWeight(.medium)
          VStack(alignment: .leading, spacing: 5) {
            Text("닉네임").font(.caption).foregroundStyle(.secondary)
            Text(appState.profile?.displayName ?? (appState.isRefreshingProfile ? "프로필을 불러오는 중" : "닉네임 미설정"))
              .foregroundStyle(.secondary)
              .frame(maxWidth: 260, alignment: .leading)
              .padding(.horizontal, 10).padding(.vertical, 6)
              .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
              .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(.primary.opacity(0.12)) }
          }
        }
        Spacer(minLength: 0)
      }
      .padding(.vertical, 4)
    }
  }

  private var friendsPanel: some View {
    DashboardPanel(title: "친구 목록", destination: .friends) {
      VStack(spacing: 10) {
        HStack {
          Picker("친구 표시", selection: $onlineOnly) {
            Text("전체").tag(false)
            Text("온라인").tag(true)
          }
          .pickerStyle(.segmented)
          Button {
            model.friendsTab = .add
            model.selection = .friends
          } label: {
            Image(systemName: "person.badge.plus")
          }
          .buttonStyle(.borderless).help("친구 추가")
          .accessibilityLabel("친구 추가")
        }
        TextField("친구 이름 검색", text: $friendSearch)
          .textFieldStyle(.roundedBorder)
        if model.friends.isEmpty {
          emptyState("연결된 친구가 없어요", symbol: "person.2", detail: "친구 추가에서 새로운 친구를 연결해보세요.")
        } else if friends.isEmpty {
          emptyState("조건에 맞는 친구가 없어요", symbol: "magnifyingglass", detail: "검색어나 필터를 바꿔보세요.")
        } else {
          VStack(spacing: 12) {
            ForEach(Array(friends.prefix(4))) { friend in
              Button { profileToShow = friend } label: {
                HStack(spacing: 10) {
                ProfileAvatarView(imageData: nil, imageURL: friend.profileImageURL, size: 28)
                Text(friend.name).lineLimit(1)
                Spacer()
                Circle().fill(friend.isOnline == true ? Color.green : .secondary)
                  .frame(width: 7, height: 7)
                Text(friend.currentAppName ?? (friend.isOnline.map { $0 ? "온라인" : "공유 활동 없음" } ?? "연결 확인 필요"))
                  .font(.caption).foregroundStyle(.secondary)
                }
              }
              .buttonStyle(.plain).help("\(friend.name) 프로필 보기")
              .accessibilityLabel("\(friend.name) 프로필 보기")
            }
          }
          .padding(.vertical, 4)
        }
        Spacer(minLength: 0)
        panelFooter("친구 관리", destination: .friends)
      }
      .frame(minHeight: 244)
    }
  }

  private var appsPanel: some View {
    DashboardPanel(title: "앱 목록", destination: .apps) {
      VStack(spacing: 12) {
        if model.appCatalog.visibleApps.isEmpty {
          emptyState("아직 앱 기록이 없어요", symbol: "app.dashed", detail: "앱을 실행하거나 전환하면 이곳에 표시됩니다.")
        } else {
          ForEach(Array(model.appCatalog.visibleApps.prefix(5))) { app in
            HStack(spacing: 10) {
              AppIconView(bundleIdentifier: app.id, applicationPath: app.applicationPath, size: 30)
              Text(app.name).lineLimit(1)
              Spacer(minLength: 4)
              if model.appCatalog.activeApp?.id == app.id {
                Text("사용 중").font(.caption).foregroundStyle(.green)
              }
            }
          }
        }
        Spacer(minLength: 0)
        panelFooter("앱 목록 관리", destination: .apps)
      }
      .frame(minHeight: 244)
    }
  }

  private var musicPanel: some View {
    DashboardPanel(title: "음악 연동", destination: .music) {
      VStack(spacing: 8) {
        Label(model.music.provider.name, systemImage: model.music.playback.state == .paused ? "pause.fill" : "music.note")
          .frame(maxWidth: .infinity, alignment: .leading)
        if model.music.isEnabled, model.music.playback.state != .closed {
          NowPlayingView(music: model.music, compact: true)
        } else {
          Text(model.music.isEnabled ? "음악 앱에서 곡을 재생해보세요" : "음악 공유 꺼짐")
            .font(.caption).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .frame(minHeight: 122)
    }
  }

  private var settingsPanel: some View {
    DashboardPanel(title: "앱 설정", destination: .settings) {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text("화면 모드")
          Spacer()
          Picker("화면 모드", selection: $appearance) {
            ForEach(AppAppearance.allCases) { value in Text(value.title).tag(value) }
          }
          .labelsHidden().frame(width: 125)
        }
        Toggle("로그인 시 자동 실행", isOn: Binding(
          get: { model.loginItem.isRegistered }, set: { model.loginItem.setEnabled($0) }
        ))
        .disabled(model.loginItem.isUpdating)
        Button("모든 설정 보기") { model.selection = .settings }.font(.caption)
        if model.loginItem.requiresApproval {
          Button("시스템 설정에서 허용") { model.loginItem.openSystemSettings() }.font(.caption)
        }
        if let error = model.loginItem.errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
      }
      .toggleStyle(.switch).controlSize(.small)
      .frame(minHeight: 122)
    }
  }

  private var infoPanel: some View {
    DashboardPanel(title: "앱 정보", destination: .info) {
      HStack(spacing: 14) {
        Image(systemName: "person.2.wave.2.fill")
          .font(.system(size: 28)).foregroundStyle(.tint)
          .frame(width: 52, height: 52)
          .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        VStack(alignment: .leading, spacing: 4) {
          Text("PokoPeeko").fontWeight(.semibold)
          Text("버전 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
            .font(.caption).foregroundStyle(.secondary)
          Text("서로의 하루를 살짝, 더 가까이.")
            .font(.caption).foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
        Button("자세히 보기") { model.selection = .info }
          .controlSize(.small)
      }
    }
  }

  private func emptyState(_ title: String, symbol: String, detail: String) -> some View {
    VStack(spacing: 8) {
      Image(systemName: symbol).font(.title2).foregroundStyle(.tertiary)
      Text(title).font(.callout)
      Text(detail).font(.caption).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, minHeight: 140)
  }

  private func panelFooter(_ title: String, destination: MainSection) -> some View {
    VStack(spacing: 8) {
      Divider()
      HStack {
        Spacer()
        Button { model.selection = destination } label: {
          HStack(spacing: 5) {
            Text(title)
            Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
          }
        }
        .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
      }
    }
  }
}

private struct DashboardPanel<Content: View>: View {
  @Environment(MainViewModel.self) private var model
  let title: String
  let destination: MainSection
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button { model.selection = destination } label: {
        HStack {
          Text(title).font(.headline)
          Spacer()
          Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("\(destination.title) 열기")
      content
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.09))
    }
  }
}

#Preview {
  DashboardView().environment(MainViewModel()).environment(AppState()).padding(20).frame(width: 820)
}
