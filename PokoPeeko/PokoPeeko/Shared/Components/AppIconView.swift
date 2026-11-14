import AppKit
import SwiftUI

struct AppIconView: View {
  var bundleIdentifier: String?
  var applicationPath: String?
  var appName: String?
  var size: CGFloat = 32

  var body: some View {
    Group {
      if let icon = AppIconResolver.icon(bundleIdentifier: bundleIdentifier,
                                         applicationPath: applicationPath, appName: appName) {
        Image(nsImage: icon).resizable().interpolation(.high).scaledToFit()
      } else {
        Image(systemName: "app.fill").resizable().scaledToFit()
          .padding(size * 0.12).foregroundStyle(.secondary)
      }
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

@MainActor
enum AppIconResolver {
  private static let cache = NSCache<NSString, NSImage>()

  static func icon(bundleIdentifier: String?, applicationPath: String?, appName: String?) -> NSImage? {
    let workspace = NSWorkspace.shared
    let url: URL?
    if let id = bundleIdentifier, let installed = workspace.urlForApplication(withBundleIdentifier: id) {
      url = installed
    } else if let path = applicationPath, FileManager.default.fileExists(atPath: path) {
      url = URL(fileURLWithPath: path)
    } else if let name = appName {
      // 번들 ID가 없는 기존 표시 데이터는 실행 중인 앱의 이름이 정확히 일치할 때만 사용한다.
      url = workspace.runningApplications.first { $0.localizedName == name }?.bundleURL
    } else {
      url = nil
    }
    guard let url else { return nil }
    if let cached = cache.object(forKey: url.path as NSString) { return cached }
    let icon = workspace.icon(forFile: url.path)
    cache.setObject(icon, forKey: url.path as NSString)
    return icon
  }
}
