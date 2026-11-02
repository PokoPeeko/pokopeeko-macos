import SwiftUI

struct AppsView: View {
  @Environment(MainViewModel.self) private var model
  @State private var search = ""
  @State private var sortByName = false

  private var apps: [AppUsage] {
    let filtered = model.appUsage.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
    return sortByName ? filtered.sorted { $0.name < $1.name } : filtered.sorted { $0.duration > $1.duration }
  }

  var body: some View {
    ActivityCard {
      VStack(alignment: .leading, spacing: 20) {
        HStack {
          Label("오늘", systemImage: "calendar").font(.headline)
          Spacer()
          Picker("정렬", selection: $sortByName) {
            Text("사용 시간순").tag(false)
            Text("이름순").tag(true)
          }
          .labelsHidden().frame(width: 150)
        }
        TextField("앱 검색", text: $search).textFieldStyle(.roundedBorder)
          .accessibilityLabel("앱 이름 검색")
        if model.appUsage.isEmpty {
          ContentUnavailableView("아직 사용 기록이 없어요", systemImage: "square.stack.3d.up",
                                 description: Text("활동 추적 기능이 연결되면 이곳에 기록이 쌓여요."))
        } else if apps.isEmpty {
          ContentUnavailableView.search(text: search)
        } else {
          ForEach(apps) { app in
            AppUsageRow(app: app, maximum: model.appUsage.map(\.duration).max() ?? 1)
          }
          Divider()
          HStack {
            Text("총 사용 시간").foregroundStyle(.secondary)
            Spacer()
            Text(UsageDuration.label(model.totalUsage)).fontWeight(.semibold)
          }
        }
      }
    }
  }
}

struct AppUsageRow: View {
  let app: AppUsage
  let maximum: TimeInterval

  var body: some View {
    HStack(spacing: 14) {
      AppSymbol(symbol: app.symbol)
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text(app.name).fontWeight(.medium)
          Spacer()
          Text(UsageDuration.label(app.duration)).foregroundStyle(.secondary).monospacedDigit()
        }
        GeometryReader { geometry in
          Capsule().fill(.tint.opacity(0.10))
            .overlay(alignment: .leading) {
              Capsule().fill(.tint.opacity(0.65))
                .frame(width: geometry.size.width * min(1, max(0, app.duration / max(1, maximum))))
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
      }
    }
  }
}
