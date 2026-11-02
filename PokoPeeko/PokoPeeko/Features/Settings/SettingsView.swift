import SwiftUI

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
  var colorScheme: ColorScheme? {
    switch self {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }
}

struct SettingsView: View {
  @AppStorage("appearance") private var appearance = AppAppearance.system
  @Environment(MainViewModel.self) private var model

  var body: some View {
    @Bindable var model = model
    VStack(spacing: 20) {
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
          Label("미리보기", systemImage: "eye").font(.headline)
          Toggle("샘플 데이터 표시", isOn: $model.isShowingSamples)
          Text("친구와 앱 사용 기록의 예시입니다. 실제 계정이나 활동 데이터에 영향을 주지 않아요.")
            .font(.callout).foregroundStyle(.secondary)
        }
      }
      ActivityCard {
        VStack(alignment: .leading, spacing: 10) {
          Label("다음에 만날 기능", systemImage: "sparkles").font(.headline)
          Text("활동 추적, 실시간 공유, 로그인 시 자동 실행 설정은 이후 단계에서 제공할 예정이에요.")
            .foregroundStyle(.secondary)
        }
      }
    }
  }
}
