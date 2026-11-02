import SwiftUI

struct FriendStatusRow: View {
  let friend: Friend

  var body: some View {
    HStack(spacing: 12) {
      Text(String(friend.name.prefix(1)))
        .font(.system(size: 17, weight: .semibold, design: .rounded))
        .foregroundStyle(friend.isOnline ? Color.accentColor : .secondary)
        .frame(width: 42, height: 42)
        .background(friend.isOnline ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.10), in: Circle())
        .overlay(alignment: .bottomTrailing) {
          Circle().fill(friend.isOnline ? Color.green : Color.secondary)
            .frame(width: 10, height: 10)
            .overlay { Circle().stroke(.background, lineWidth: 2) }
        }
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 6) {
          Text(friend.name).font(.system(size: 13, weight: .semibold))
          if friend.isOnline {
            Text("온라인").font(.system(size: 10)).foregroundStyle(.secondary)
          }
        }
        if friend.isOnline, let app = friend.currentAppName {
          Label(app, systemImage: friend.appSymbol).font(.caption).foregroundStyle(.secondary)
        } else {
          Text(friend.isOnline ? "활동 정보 없음" : "오프라인").font(.caption).foregroundStyle(.secondary)
        }
      }
      .lineLimit(1)
      Spacer(minLength: 4)
      if friend.isOnline, friend.currentAppName != nil {
        Text(UsageDuration.label(friend.usageDuration))
          .font(.caption).monospacedDigit().foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 10)
    .accessibilityElement(children: .combine)
  }
}
