import SwiftUI

struct AppInfoView: View {
  private var version: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
  }

  var body: some View {
    ActivityCard {
      VStack(alignment: .leading, spacing: 24) {
        Image(systemName: "person.2.wave.2.fill")
          .font(.system(size: 52)).foregroundStyle(.tint)
        VStack(alignment: .leading, spacing: 8) {
          Text("PokoPeeko").font(.largeTitle.bold())
          Text("서로의 하루를 살짝, 더 가까이.").font(.title3).foregroundStyle(.secondary)
        }
        Text("친구들이 지금 어떤 앱을 사용하고 있는지 메뉴바에서 확인하고, 나의 앱 사용 시간을 돌아보는 macOS 앱입니다.")
          .lineSpacing(5)
        Divider()
        LabeledContent("버전", value: version)
        LabeledContent("현재 단계", value: "메인 앱 · 메뉴바 UI")
        Text("인증 완성, 앱 활동 측정과 실시간 공유는 이후 단계에서 연결합니다.")
          .font(.callout).foregroundStyle(.secondary)
      }
    }
  }
}
