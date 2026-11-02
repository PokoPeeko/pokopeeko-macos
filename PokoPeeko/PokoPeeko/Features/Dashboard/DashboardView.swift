import SwiftUI

struct DashboardView: View {
  @Environment(MainViewModel.self) private var model

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      HStack(spacing: 16) {
        metric("오늘의 사용 시간", value: UsageDuration.label(model.totalUsage), symbol: "clock")
        metric("사용한 앱", value: "\(model.appUsage.count)개", symbol: "square.stack.3d.up")
        metric("온라인 친구", value: "\(model.onlineFriends.count)명", symbol: "person.2")
      }

      ActivityCard {
        HStack(spacing: 16) {
          AppSymbol(symbol: model.isShowingSamples ? "hammer.fill" : "desktopcomputer")
          VStack(alignment: .leading, spacing: 6) {
            Text(model.isShowingSamples ? "Xcode와 함께하는 시간" : "나의 활동이 쌓일 공간")
              .font(.headline)
            Text(model.isShowingSamples ? "샘플 활동 · 누적 2시간 24분" : "앱 활동 추적 기능은 아직 연결되지 않았어요.")
              .foregroundStyle(.secondary)
          }
          Spacer()
          Image(systemName: "sparkles").font(.title2).foregroundStyle(.tint)
        }
      }

      ActivityCard {
        VStack(alignment: .leading, spacing: 20) {
          HStack {
            Text("오늘 많이 사용한 앱").font(.headline)
            Spacer()
            Button("전체 보기") { model.selection = .apps }.buttonStyle(.link)
          }
          if model.appUsage.isEmpty {
            ContentUnavailableView("아직 활동 기록이 없어요", systemImage: "chart.bar.xaxis",
                                   description: Text("기록이 생기면 앱별 사용 시간을 보여드릴게요."))
          } else {
            ForEach(model.appUsage) { app in
              AppUsageRow(app: app, maximum: model.appUsage.map(\.duration).max() ?? 1)
            }
          }
        }
      }

      ActivityCard {
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            Text("친구들의 지금").font(.headline)
            Spacer()
            Button("친구 보기") { model.selection = .friends }.buttonStyle(.link)
          }
          if model.friends.isEmpty {
            ContentUnavailableView("함께할 친구를 기다리고 있어요", systemImage: "person.2",
                                   description: Text("친구 연결 기능은 준비 중이에요."))
          } else {
            FriendStatusList(friends: model.onlineFriends)
          }
        }
      }
    }
  }

  private func metric(_ title: String, value: String, symbol: String) -> some View {
    ActivityCard {
      VStack(alignment: .leading, spacing: 16) {
        Label(title, systemImage: symbol).font(.callout).foregroundStyle(.secondary)
        Text(value).font(.system(size: 25, weight: .semibold, design: .rounded))
          .contentTransition(.numericText())
      }
    }
  }
}
