//

import Foundation

enum APIConfig {
  static let baseURL = "https://port-0-pokopeeko-mvzcjohte9c33cc4.sel3.cloudtype.app"

  static let socketBaseURL = "http://port-0-pokopeeko-mvzcjohte9c33cc4.sel3.cloudtype.app:80"
  static func profileImageURL(fileName: String?) -> URL? {
    guard let fileName, !fileName.isEmpty, fileName != ".", fileName != "..",
          fileName.rangeOfCharacter(from: CharacterSet(charactersIn: "/\\?#")) == nil,
          let base = URL(string: baseURL) else { return nil }
    return base.appendingPathComponent("static/profile").appendingPathComponent(fileName)
  }
}
