import SwiftUI
import AppKit

enum AppAppearance: String, CaseIterable, Identifiable {
  case system, light, dark
  var id: Self { self }
  var title: String {
    switch self {
    case .system: "시스템 설정"
    case .light: "라이트"
    case .dark: "다크"
    }
  }
  @MainActor
  func apply() {
    let value: NSAppearance?
    switch self {
    case .system: value = nil
    case .light: value = NSAppearance(named: .aqua)
    case .dark: value = NSAppearance(named: .darkAqua)
    }
    NSApplication.shared.appearance = value
    // SwiftUI 창과 팝오버가 창별 강제 테마 대신 앱의 appearance를 상속하게 한다.
    for window in NSApplication.shared.windows {
      window.appearance = nil
      window.contentView?.appearance = nil
    }
  }
}

struct SettingsView: View {
  @Environment(MainViewModel.self) private var model
  @AppStorage("appearance") private var appearance = AppAppearance.system
  @AppStorage("shareAppActivity") private var shareAppActivity = true
  @AppStorage("showOfflineFriends") private var showOfflineFriends = false

  var body: some View {
    VStack(spacing: 20) {
      ActivityCard {
        VStack(alignment: .leading, spacing: 16) {
          Label("일반", systemImage: "gearshape").font(.headline)
          Toggle("로그인 시 자동 실행", isOn: Binding(
            get: { model.loginItem.isRegistered }, set: { model.loginItem.setEnabled($0) }
          ))
          .disabled(model.loginItem.isUpdating)
          Text("Mac에 로그인하면 PokoPeeko를 자동으로 실행합니다.")
            .font(.caption).foregroundStyle(.secondary)
          if model.loginItem.requiresApproval {
            Text("자동 실행을 완료하려면 시스템 설정에서 허용해주세요.")
              .font(.callout).foregroundStyle(.secondary)
            Button("로그인 항목 설정 열기") { model.loginItem.openSystemSettings() }
          }
          if let error = model.loginItem.errorMessage { Text(error).font(.callout).foregroundStyle(.red) }
        }
      }
      ActivityCard {
        VStack(alignment: .leading, spacing: 18) {
          Label("화면", systemImage: "paintbrush").font(.headline)
          HStack {
            Text("앱 테마")
            Spacer()
            Picker("앱 테마", selection: $appearance) {
              ForEach(AppAppearance.allCases) { value in
                Text(value.title).tag(value)
              }
            }
            .labelsHidden().frame(width: 160)
          }
          Text("메인 앱과 메뉴바 팝오버에 함께 적용됩니다.")
            .font(.caption).foregroundStyle(.secondary)
        }
      }
      ActivityCard {
        VStack(alignment: .leading, spacing: 16) {
          Label("활동 공유", systemImage: "person.2.wave.2").font(.headline)
          Toggle("사용 중인 앱 공유", isOn: $shareAppActivity)
          Text("끄면 친구들에게 현재 앱 이름 대신 비공개 상태를 표시합니다.")
            .font(.caption).foregroundStyle(.secondary)
          Button("앱별 차단·노출 설정") { model.selection = .apps }
        }
      }
      ActivityCard {
        VStack(alignment: .leading, spacing: 16) {
          Label("메뉴바", systemImage: "menubar.rectangle").font(.headline)
          Toggle("오프라인 친구도 표시", isOn: $showOfflineFriends)
          Text("기본적으로 활동 중인 친구만 표시합니다. 팝오버에서 바꾼 설정도 함께 저장됩니다.")
            .font(.caption).foregroundStyle(.secondary)
        }
      }
    }
    .toggleStyle(.switch)
    .task { model.loginItem.refresh() }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
      model.loginItem.refresh()
    }
  }
}
