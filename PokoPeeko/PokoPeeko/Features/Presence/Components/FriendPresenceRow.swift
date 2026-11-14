import SwiftUI

struct FriendPresenceRow: View {
  let friend: Friend
  var opensProfile = true
  var onOpenProfile: ((Friend) -> Void)? = nil
  @State private var isShowingProfile = false

  var body: some View {
    Group {
      if opensProfile {
        Button {
          if let onOpenProfile { onOpenProfile(friend) }
          else { isShowingProfile = true }
        } label: { row }
          .buttonStyle(.plain)
          .help("\(friend.name) 프로필 보기")
          .accessibilityLabel("\(friend.name) 프로필 보기")
      } else { row }
    }
    .sheet(isPresented: $isShowingProfile) {
      FriendProfileView(userID: friend.id, initialProfile: UserProfile(id: friend.id,
        displayName: friend.name, profileImageFileName: friend.profileImageFileName))
    }
  }

  private var row: some View {
    HStack(spacing: 12) {
      ProfileAvatarView(imageData: nil, imageURL: friend.profileImageURL, size: 42)
        .overlay(alignment: .bottomTrailing) {
          Circle().fill(friend.isOnline == true ? Color.green : Color.secondary)
            .frame(width: 10, height: 10)
            .overlay { Circle().stroke(.background, lineWidth: 2) }
        }
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 6) {
          Text(friend.name).font(.system(size: 13, weight: .semibold)).layoutPriority(1)
          if friend.isOnline == true, let song = friend.songTitle {
            Text("·").foregroundStyle(.tertiary)
            Image(systemName: friend.isMusicPaused ? "pause.fill" : "music.note")
              .font(.system(size: 9)).foregroundStyle(.secondary)
            MarqueeText(text: [song, friend.artistName].compactMap { $0 }.joined(separator: " — "), size: 10)
              .foregroundStyle(.secondary)
              .opacity(friend.isMusicPaused ? 0.65 : 1)
          }
        }
        if friend.isOnline == true, let app = friend.currentAppName {
          HStack(spacing: 5) {
            AppIconView(bundleIdentifier: friend.currentAppBundleIdentifier, appName: app, size: 16)
            Text(app).font(.caption).foregroundStyle(.secondary)
          }
        } else {
          Text(friend.isOnline.map { $0 ? "활동 정보 없음" : "오프라인 또는 공유 활동 없음" } ?? "활동 상태 확인 불가").font(.caption).foregroundStyle(.secondary)
        }
      }
      .lineLimit(1)
      Spacer(minLength: 4)
    }
    .padding(.vertical, 10)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }
}
