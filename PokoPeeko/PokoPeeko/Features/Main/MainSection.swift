import Foundation

enum MainSection: String, CaseIterable, Identifiable {
  case dashboard, friends, apps, music, profile, settings, info, feedback
  var id: Self { self }

  var title: String {
    switch self {
    case .dashboard: "대시보드"
    case .friends: "친구"
    case .apps: "앱 목록"
    case .music: "음악 연동"
    case .profile: "프로필"
    case .settings: "설정"
    case .info: "정보"
    case .feedback: "피드백"
    }
  }

  var symbol: String {
    switch self {
    case .dashboard: "square.grid.2x2"
    case .friends: "person.2"
    case .apps: "square.stack.3d.up"
    case .music: "music.note"
    case .profile: "person.crop.circle"
    case .settings: "slider.horizontal.3"
    case .info: "info.circle"
    case .feedback: "bubble.left"
    }
  }

  var subtitle: String {
    switch self {
    case .dashboard: "나의 하루와 친구들의 지금을 한눈에."
    case .friends: "각자의 자리에서, 함께하는 친구들."
    case .apps: "감지한 앱과 차단·노출 설정을 관리하세요."
    case .music: "지금 듣는 음악도 함께."
    case .profile: "친구들에게 보여줄 나의 모습."
    case .settings: "PokoPeeko를 나에게 맞게."
    case .info: "작은 메뉴바에서 시작하는 연결."
    case .feedback: "더 나은 PokoPeeko를 함께 만들어요."
    }
  }
}
