import SwiftUI
import FirebaseCore

@main
struct PokoPeekoApp: App {
  init() {
    FirebaseApp.configure()
  }

  @State private var appState = AppState()
  @State private var model = MainViewModel()
  @AppStorage("appearance") private var appearance = AppAppearance.system

  var body: some Scene {
    Window("PokoPeeko", id: "main") {
      MainWindowContent()
        .environment(appState)
        .environment(model)
        .tint(.teal)
        .preferredColorScheme(appearance.colorScheme)
    }
    .defaultSize(width: 1_080, height: 760)

    #if DEBUG
    Window("PokoPeeko · UI 미리보기", id: "ui-preview") {
      MainView()
        .environment(appState)
        .environment(model)
        .tint(.teal)
        .preferredColorScheme(appearance.colorScheme)
    }
    .defaultSize(width: 1_080, height: 760)
    .commands {
      CommandMenu("개발") {
        OpenPreviewButton()
      }
    }
    #endif

    MenuBarExtra {
      FriendStatusView()
        .environment(appState)
        .environment(model)
        .tint(.teal)
        .preferredColorScheme(appearance.colorScheme)
    } label: {
      Image(systemName: "person.2.fill")
    }
    .menuBarExtraStyle(.window)
  }
}

private struct MainWindowContent: View {
  @Environment(AppState.self) private var appState

  var body: some View {
    if appState.isLoggedIn {
      MainView()
    } else {
      VStack(spacing: 0) {
        SignInView()
        #if DEBUG
        OpenPreviewButton().padding(.bottom, 24)
        #endif
      }
    }
  }
}

#if DEBUG
private struct OpenPreviewButton: View {
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Button("UI 미리보기 열기") { openWindow(id: "ui-preview") }
  }
}
#endif
