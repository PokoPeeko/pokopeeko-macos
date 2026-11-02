import Foundation

enum UsageDuration {
  static func label(_ duration: TimeInterval) -> String {
    let minutes = max(0, Int(duration) / 60)
    return minutes >= 60 ? "\(minutes / 60)시간 \(minutes % 60)분" : "\(minutes)분"
  }
}
