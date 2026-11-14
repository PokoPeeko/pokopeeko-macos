import Foundation

struct DetectedApp: Identifiable, Codable, Equatable {
  let id: String
  var name: String
  var applicationPath: String?
  var isDetectionEnabled = true
  var isVisible = true
  var isManuallyAdded = false
}
