import SwiftUI

struct MainView: View {
  @Environment(AppState.self) private var appState
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
          ForEach(MainSection.allCases.filter { $0 != .feedback }) { section in
            Label(section.title, systemImage: section.symbol).tag(section)
          }
        }
        .listStyle(.sidebar)

        Button {
          model.selection = .feedback
        } label: {
          Label("피드백", systemImage: "bubble.left")
            .font(.caption)
            .foregroundStyle(section == .feedback ? Color.accentColor : .secondary)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
      }
      .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
    } detail: {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          if section != .dashboard {
            SectionHeading(title: section.title, subtitle: section.subtitle)
          }
          switch section {
          case .dashboard: DashboardView()
          case .friends: FriendsView()
          case .apps: AppsView()
          case .music: MusicIntegrationView()
          case .profile: ProfileOverviewView()
          case .settings: SettingsView()
          case .info: AppInfoView()
          case .feedback: FeedbackView()
          }
        }
        .padding(section == .dashboard ? 16 : 32)
        .frame(maxWidth: 1_000, alignment: .leading)
        .frame(maxWidth: .infinity)
      }
      .background(.quaternary.opacity(0.25))
      .navigationTitle(section.title)

    }
    .frame(minWidth: 860, minHeight: 620)
    .task {
      model.appCatalog.start()
      if appState.isLoggedIn { await model.friendsModel.refresh() }
    }
  }

  private var section: MainSection { model.selection ?? .dashboard }
}

#Preview {
  MainView().environment(MainViewModel()).environment(AppState())
}
