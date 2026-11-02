import Foundation
import Observation

/// UI 단계의 표시 데이터. 서버 연결 및 실제 활동 측정은 후속 단계에서 구현한다.
@Observable
final class MainViewModel {
  var selection: MainSection? = .dashboard
  var isShowingSamples = false

  var friends: [Friend] { isShowingSamples ? Self.sampleFriends : [] }
  var appUsage: [AppUsage] { isShowingSamples ? Self.sampleApps : [] }
  var onlineFriends: [Friend] { friends.filter(\.isOnline) }
  var totalUsage: TimeInterval { appUsage.reduce(0) { $0 + $1.duration } }

  private static let sampleFriends = [
    Friend(id: UUID(), name: "서연", currentAppName: "Xcode", isOnline: true,
           appSymbol: "hammer.fill", usageDuration: 5_280),
    Friend(id: UUID(), name: "민준", currentAppName: "Figma", isOnline: true,
           appSymbol: "square.on.circle.fill", usageDuration: 3_540),
    Friend(id: UUID(), name: "지우", currentAppName: "Safari", isOnline: true,
           appSymbol: "safari.fill", usageDuration: 1_260),
    Friend(id: UUID(), name: "하린", currentAppName: nil, isOnline: false),
    Friend(id: UUID(), name: "도윤", currentAppName: nil, isOnline: false)
  ]

  private static let sampleApps = [
    AppUsage(id: "com.apple.dt.Xcode", name: "Xcode", symbol: "hammer.fill", duration: 8_640),
    AppUsage(id: "com.apple.Safari", name: "Safari", symbol: "safari.fill", duration: 3_780),
    AppUsage(id: "com.figma.Desktop", name: "Figma", symbol: "square.on.circle.fill", duration: 2_700),
    AppUsage(id: "com.apple.Notes", name: "메모", symbol: "note.text", duration: 1_080)
  ]
}
