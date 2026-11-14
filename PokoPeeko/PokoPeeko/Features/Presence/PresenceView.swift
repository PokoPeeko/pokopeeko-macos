import AppKit
import SwiftUI

struct PresenceView: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(AppState.self) private var appState
  @Environment(MainViewModel.self) private var model
  @Environment(\.openWindow) private var openWindow
  @Environment(\.dismiss) private var dismiss
  @State private var profileToShow: Friend?
  @AppStorage("shareAppActivity") private var shareAppActivity = true
  @AppStorage("showOfflineFriends") private var showOffline = false

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
        Text(!model.friends.isEmpty && model.friends.allSatisfy { $0.isOnline == nil }
             ? "상태 확인 불가" : "\(model.onlineFriends.count)명 온라인")
          .font(.caption).foregroundStyle(.secondary)
        Spacer()
        FilterToggle("오프라인 포함", isOn: $showOffline).font(.caption)
      }
      .padding(.horizontal, 18).padding(.vertical, 12)

      ScrollView {
        if !appState.isLoggedIn {
          ContentUnavailableView("로그인이 필요해요", systemImage: "person.crop.circle",
                                 description: Text("메인 앱에서 로그인해주세요."))
            .frame(minHeight: 230)
        } else {
          LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            Section {
              friendRows
            } header: {
              VStack(spacing: 0) {
                Button { showMain(.profile) } label: { ownActivity }
                  .buttonStyle(.plain)
                  .help("내 프로필 보기").accessibilityLabel("내 활동과 프로필 보기")
                  .padding(.horizontal, 18).padding(.vertical, 10)
                Divider().padding(.leading, 72).padding(.trailing, 18)
              }
              .background(.background)
            }
          }
        }
      }
      .frame(height: 300)
      Divider()
      HStack {
        Button {
          model.friendsTab = .add
          showMain(.friends)
        } label: {
          Label("친구 추가", systemImage: "person.badge.plus")
        }
        Spacer()
        Button { showMain(.dashboard) } label: {
          Label("앱 열기", systemImage: "arrow.up.forward.app")
        }
      }
      .buttonStyle(.plain).font(.caption).padding(18)
    }
    .frame(width: 360)
    .allowsHitTesting(profileToShow == nil)
    .accessibilityHidden(profileToShow != nil)
    .overlay {
      if let friend = profileToShow {
        ZStack {
          Color.clear
            .contentShape(Rectangle())
            .onTapGesture { profileToShow = nil }
          FriendProfileView(userID: friend.id,
            initialProfile: UserProfile(id: friend.id, displayName: friend.name, profileImageFileName: friend.profileImageFileName),
            width: 300, onClose: { profileToShow = nil })
          .fixedSize(horizontal: false, vertical: true)
          .padding(.bottom, 12)
          .frame(width: 300)
          .frame(minHeight: 380)
          .background(Color(white: colorScheme == .dark ? 0.20 : 0.92))
          .clipShape(RoundedRectangle(cornerRadius: 16))
          .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.12)) }
          .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
          .id(friend.id)
        }
      }
    }
    .onExitCommand {
      if profileToShow != nil { profileToShow = nil }
      else { dismiss() }
    }
    .onChange(of: appState.currentSessionId) { _, _ in profileToShow = nil }
    .task { if appState.isLoggedIn { await model.friendsModel.refresh() } }
  }

  @ViewBuilder private var friendRows: some View {
    if let error = model.friendsModel.friendsError, model.friends.isEmpty {
      ContentUnavailableView("친구 목록을 불러오지 못했어요", systemImage: "wifi.exclamationmark",
                             description: Text(error)).frame(minHeight: 200)
    } else if model.friends.isEmpty {
      ContentUnavailableView("아직 연결된 친구가 없어요", systemImage: "person.2",
                             description: Text("친구 추가에서 이름으로 검색해보세요."))
        .frame(minHeight: 200)
    } else if visibleFriends.isEmpty {
      ContentUnavailableView("온라인인 친구가 없어요", systemImage: "moon.zzz",
                             description: Text("오프라인 포함을 켜면 전체 친구를 볼 수 있어요."))
        .frame(minHeight: 200)
    } else {
      FriendPresenceList(friends: visibleFriends, onOpenProfile: { profileToShow = $0 }).padding(.horizontal, 18)
    }
  }

  private var ownActivity: some View {
    HStack(alignment: .center, spacing: 12) {
      ProfileAvatarView(imageData: appState.profileImageData, imageURL: appState.profile?.profileImageURL, size: 42)
      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 6) {
          Text(appState.profile?.displayLabel ?? "내 프로필")
            .font(.system(size: 13, weight: .semibold)).lineLimit(1).layoutPriority(1)
          if model.music.isEnabled, model.music.playback.state != .closed {
            Text("·").foregroundStyle(.tertiary)
            HStack(spacing: 5) {
              Image(systemName: model.music.playback.state == .paused ? "pause.fill" : "music.note")
                .font(.system(size: 9))
              MarqueeText(text: model.music.playback.description, size: 10)
            }
            .foregroundStyle(.secondary)
            .opacity(model.music.playback.state == .paused ? 0.65 : 1)
          }
        }
        HStack(spacing: 5) {
          if shareAppActivity, let app = model.appCatalog.activeApp {
            AppIconView(bundleIdentifier: app.id, appName: app.name, size: 16)
            Text(app.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
          } else {
            Text(shareAppActivity ? "공유 중인 앱 없음" : "앱 활동 공유 꺼짐")
              .font(.caption).foregroundStyle(.secondary)
          }
        }
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
  }

  private var visibleFriends: [Friend] {
    model.friends.filter { showOffline || $0.isOnline == true }
  }

  private func showMain(_ section: MainSection) {
    model.selection = section
    let windowID = "main"
    dismiss()
    openWindow(id: windowID)
    NSApp.activate()
    DispatchQueue.main.async {
      if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == windowID }) {
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
      }
    }
  }
}

#Preview {
  PresenceView().environment(MainViewModel()).environment(AppState())
}
