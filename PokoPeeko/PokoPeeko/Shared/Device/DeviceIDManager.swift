//

import Foundation

enum DeviceIDManager {
  private static let key = "deviceID"

  static var deviceID: String {
    if let deviceID = UserDefaults.standard.string(forKey: key) {
      return deviceID
    }

    let deviceID = UUID().uuidString
    UserDefaults.standard.set(deviceID, forKey: key)

    return deviceID
  }
}
