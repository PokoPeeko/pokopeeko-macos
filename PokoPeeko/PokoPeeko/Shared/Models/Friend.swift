//

import Foundation

struct Friend: Identifiable {
  let id: UUID
  var name: String
  var profileImageURL: URL?
  var currentAppName: String?
  var isOnline = false
  var appSymbol = "app"
  var usageDuration: TimeInterval = 0
}
