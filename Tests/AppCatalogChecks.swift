import AppKit
import Foundation

/// 실행 방법은 README의 검증 항목을 참고한다.
@main
struct AppCatalogChecks {
  struct Failure: Error { let message: String }

  @MainActor
  static func main() throws {
    let suite = "PokoPeeko.AppCatalogChecks.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let catalog = AppCatalog(defaults: defaults)
    let app = DetectedApp(id: "test.editor", name: "Test Editor", applicationPath: "/Applications/Test Editor.app")

    func require(_ condition: Bool, _ message: String) throws {
      if !condition { throw Failure(message: message) }
    }

    catalog.recordDetection(app)
    catalog.recordDetection(app)
    try require(catalog.registeredApps.count == 1, "Repeated detection must not duplicate an app")

    catalog.updateApp(app.id, visible: false)
    try require(catalog.registeredApps.count == 1 && catalog.visibleApps.isEmpty,
                "Hiding must retain the app in its management list")
    catalog.recordDetection(app)
    try require(catalog.visibleApps.isEmpty, "Detection must preserve the visibility preference")

    catalog.updateApp(app.id, detection: false)
    catalog.recordDetection(app)
    catalog.removeApp(app.id)
    try require(catalog.registeredApps.isEmpty && catalog.blockedApps.count == 1,
                "Rediscovery and list deletion must not clear a block")
    try require(!catalog.addApp(app), "Manual addition must not bypass a block")

    let restored = AppCatalog(defaults: defaults)
    try require(restored.blockedApps.count == 1 && !restored.blockedApps[0].isVisible,
                "Restart must restore the block and visibility setting")
    restored.updateApp(app.id, detection: true)
    try require(restored.registeredApps.count == 1 && restored.visibleApps.isEmpty,
                "Unblocking must retain the visibility setting")
    restored.removeApp(app.id)
    try require(restored.allApps.isEmpty, "List deletion must remove an unblocked app")
    restored.recordDetection(app)
    try require(restored.registeredApps.count == 1, "Deleted apps may be rediscovered")

    let manual = DetectedApp(id: "test.manual", name: "Manual App")
    try require(restored.addApp(manual), "Manual addition must succeed")
    let reloaded = AppCatalog(defaults: defaults)
    try require(reloaded.registeredApps.contains { $0.id == manual.id && $0.isManuallyAdded },
                "Manual app metadata must survive restart")

    defaults.set(Data("invalid json".utf8), forKey: "appCatalog.v1")
    let corrupted = AppCatalog(defaults: defaults)
    corrupted.recordDetection(app)
    try require(corrupted.storageError != nil && defaults.data(forKey: "appCatalog.v1") == Data("invalid json".utf8),
                "A corrupt saved catalog must not be silently overwritten")
    defaults.removeObject(forKey: "appCatalog.v1")

    let live = AppCatalog(defaults: defaults)
    var publishedActivity: String?
    live.onActivityChange = { publishedActivity = $0?.id }
    live.start()
    try require(live.isMonitoring, "Workspace observation must start")
    try require(!live.registeredApps.isEmpty, "The desktop should expose running regular applications")
    let count = live.allApps.count
    live.start()
    try require(live.allApps.count == count, "Starting twice must not duplicate registrations")
    if let active = live.activeApp {
      try require(publishedActivity == active.id, "Workspace detection must notify the sharing service without a view observer")
      live.updateApp(active.id, visible: false)
      try require(publishedActivity == nil, "Hiding the active app must immediately stop publishing its identity")
      live.updateApp(active.id, visible: true)
      try require(publishedActivity == active.id, "Making an active app visible must publish its identity")
      live.updateApp(active.id, detection: false)
      try require(publishedActivity == nil, "Blocking the active app must immediately stop publishing its identity")
    }
    live.stop()
    try require(!live.isMonitoring && live.activeAppID == nil && publishedActivity == nil, "Stopping must clear active state")
    let finderIcon = AppIconResolver.icon(bundleIdentifier: "com.apple.finder", applicationPath: nil, appName: nil)
    try require(finderIcon != nil && finderIcon!.size.width > 0, "An installed app must provide a real icon")
    try require(AppIconResolver.icon(bundleIdentifier: "test.nonexistent.application", applicationPath: nil, appName: nil) == nil,
                "An unavailable app must use the fallback instead of an unrelated icon")
    print("App catalog checks passed, including live workspace discovery and real icon loading.")
  }
}
