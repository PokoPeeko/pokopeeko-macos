import SwiftUI
import AppKit
import FirebaseCore
import FirebaseAuth

@main
struct PokoPeekoApp: App {
  init() {
    FirebaseApp.configure()
    let state = AppState(signOutFirebase: { try Auth.auth().signOut() })
    let friends = FriendsViewModel(onSessionExpired: { [weak state] id in
      _ = state?.invalidateSession(ifMatching: id)
    })
    let presence = PresenceService()
    presence.setSharingEnabled(UserDefaults.standard.object(forKey: "shareAppActivity") as? Bool ?? true)
    presence.onSessionExpired = { [weak state] id in _ = state?.invalidateSession(ifMatching: id) }
    state.onSessionChange = { [weak friends, weak presence] in
      friends?.reset()
      presence?.stop()
    }
    _appState = State(initialValue: state)
    _model = State(initialValue: MainViewModel(friendsModel: friends, presence: presence))
  }

  @State private var appState: AppState
  @State private var model: MainViewModel
  @AppStorage("appearance") private var appearance = AppAppearance.system
  @AppStorage("shareAppActivity") private var shareAppActivity = true

  var body: some Scene {
    Window("PokoPeeko", id: "main") {
      MainWindowContent()
        .task { model.appCatalog.start(); model.music.start() }
        .onAppear { appearance.apply() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
          model.loginItem.refresh()
        }
        .onChange(of: appearance) { _, value in value.apply() }
        .onChange(of: shareAppActivity) { _, value in model.presence.setSharingEnabled(value) }
        .onChange(of: appState.isLoggedIn, initial: true) { _, _ in syncPresence() }
        .onChange(of: appState.currentSessionId) { _, _ in syncPresence() }
        .environment(appState)
        .environment(model)
        .tint(.accentColor)
    }
    .defaultSize(width: 1_080, height: 760)

    MenuBarExtra {
      PresenceView()
        .onAppear { appearance.apply() }
        .environment(appState)
        .environment(model)
        .tint(.accentColor)
    } label: {
      Image(systemName: "person.2.fill")
    }
    .menuBarExtraStyle(.window)
  }

  private func syncPresence() {
    if appState.isLoggedIn, let id = appState.currentSessionId {
      model.presence.updateCurrentApp(model.appCatalog.activeApp)
      model.presence.connect(sessionID: id)
    } else {
      model.presence.stop()
    }
  }
}

private struct MainWindowContent: View {
  @Environment(AppState.self) private var appState

  var body: some View {
    Group {
      if appState.isRestoringSession {
        ProgressView("로그인 상태를 확인하고 있어요")
          .frame(minWidth: 440, minHeight: 300)
      } else if let error = appState.startupError {
        VStack(spacing: 18) {
          Image(systemName: "wifi.exclamationmark").font(.largeTitle).foregroundStyle(.secondary)
          Text("로그인 상태를 확인하지 못했어요").font(.headline)
          Text(error).foregroundStyle(.secondary).multilineTextAlignment(.center)
          HStack(spacing: 12) {
            Button("다시 시도") { Task { await appState.restoreSession(force: true) } }
            Button("다시 로그인") { appState.restartSignIn() }
          }
        }
        .padding(32).frame(width: 440).frame(minHeight: 300)
      } else if appState.isLoggedIn {
        MainView()
      } else {
        SignInView()
      }
    }
    .task { await appState.restoreSession() }
  }
}
