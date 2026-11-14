//

import Foundation

struct Friend: Identifiable {
  let id: UUID
  var name: String
  var profileImageURL: URL?
  var profileImageFileName: String?
  var currentAppName: String?
  var isOnline: Bool?
  var currentAppBundleIdentifier: String?
  var usageDuration: TimeInterval = 0
  var songTitle: String?
  var artistName: String?
  var isMusicPaused = false
}
