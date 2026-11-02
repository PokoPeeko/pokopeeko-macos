import SwiftUI

struct MainView: View {
  @Environment(MainViewModel.self) private var model

  var body: some View {
    @Bindable var model = model

    NavigationSplitView {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 10) {
          Image(systemName: "person.2.wave.2.fill")
            .font(.title2).foregroundStyle(.tint)
          Text("PokoPeeko").font(.title3.bold())
        }
        .padding(20)

        List(selection: $model.selection) {
          Section("내 공간") {
            ForEach([MainSection.dashboard, .friends, .apps]) { section in
              Label(section.title, systemImage: section.symbol).tag(section)
            }
          }
          Section("앱 관리") {
            ForEach([MainSection.profile, .settings, .info, .feedback]) { section in
              Label(section.title, systemImage: section.symbol).tag(section)
            }
          }
        }
        .listStyle(.sidebar)

        VStack(alignment: .leading, spacing: 6) {
          Label("UI 미리보기", systemImage: "paintpalette")
            .font(.callout.weight(.medium))
          Text("활동 측정과 서버 연결은 준비 중이에요.")
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
      }
      .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
    } detail: {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          SectionHeading(title: section.title, subtitle: section.subtitle)
          if model.isShowingSamples { SampleNotice() }
          switch section {
          case .dashboard: DashboardView()
          case .friends: FriendsView()
          case .apps: AppsView()
          case .profile: ProfileOverviewView()
          case .settings: SettingsView()
          case .info: AppInfoView()
          case .feedback: FeedbackView()
          }
        }
        .padding(32)
        .frame(maxWidth: 1_000, alignment: .leading)
        .frame(maxWidth: .infinity)
      }
      .background(.quaternary.opacity(0.25))
      .navigationTitle(section.title)
      .toolbar {
        ToolbarItem {
          Toggle(isOn: $model.isShowingSamples) {
            Label("샘플 데이터", systemImage: "eye")
          }
          .toggleStyle(.button)
          .help("샘플 데이터와 빈 화면 전환")
        }
      }
    }
    .frame(minWidth: 860, minHeight: 620)
  }

  private var section: MainSection { model.selection ?? .dashboard }
}

#Preview {
  MainView().environment(MainViewModel()).environment(AppState())
}
