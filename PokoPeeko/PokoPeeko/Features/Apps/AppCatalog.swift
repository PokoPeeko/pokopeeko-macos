import AppKit
import Combine
import Observation

/// 로컬 앱 목록과 차단 정책을 관리한다. 사용 시간 계산이나 서버 전송은 수행하지 않는다.
@MainActor
@Observable
final class AppCatalog {
  private(set) var allApps: [DetectedApp] = [] {
    didSet { onActivityChange?(activeApp) }
  }
  private(set) var activeAppID: String? {
    didSet { onActivityChange?(activeApp) }
  }
  @ObservationIgnored var onActivityChange: ((DetectedApp?) -> Void)?
  private(set) var isMonitoring = false
  private(set) var storageError: String?

  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let workspace: NSWorkspace
  @ObservationIgnored private var subscriptions: Set<AnyCancellable> = []
  private static let storageKey = "appCatalog.v1"

  var registeredApps: [DetectedApp] { allApps.filter(\.isDetectionEnabled) }
  var blockedApps: [DetectedApp] { allApps.filter { !$0.isDetectionEnabled } }
  var visibleApps: [DetectedApp] { registeredApps.filter(\.isVisible) }
  var activeApp: DetectedApp? {
    visibleApps.first { $0.id == activeAppID }
  }

  init(defaults: UserDefaults = .standard, workspace: NSWorkspace = .shared) {
    self.defaults = defaults
    self.workspace = workspace
    restore()
  }

  func start() {
    guard !isMonitoring else { return }
    isMonitoring = true
    let center = workspace.notificationCenter
    for notification in [NSWorkspace.didLaunchApplicationNotification,
                         NSWorkspace.didActivateApplicationNotification,
                         NSWorkspace.didTerminateApplicationNotification] {
      center.publisher(for: notification)
        .receive(on: RunLoop.main)
        .sink { [weak self] event in
          MainActor.assumeIsolated { self?.handle(event) }
        }
        .store(in: &subscriptions)
    }
    center.publisher(for: NSWorkspace.willSleepNotification)
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in
        MainActor.assumeIsolated { self?.activeAppID = nil }
      }
      .store(in: &subscriptions)
    center.publisher(for: NSWorkspace.didWakeNotification)
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in
        MainActor.assumeIsolated { self?.scanRunningApps() }
      }
      .store(in: &subscriptions)
    scanRunningApps()
  }

  func stop() {
    subscriptions.removeAll()
    isMonitoring = false
    activeAppID = nil
  }

  /// 자동 감지의 단일 진입점. 기존 차단·노출 설정은 덮어쓰지 않는다.
  func recordDetection(_ app: DetectedApp) {
    guard !app.id.isEmpty, app.id != Bundle.main.bundleIdentifier else { return }
    if let index = allApps.firstIndex(where: { $0.id == app.id }) {
      guard allApps[index].isDetectionEnabled else { return }
      var updated = allApps[index]
      updated.name = app.name
      if let path = app.applicationPath { updated.applicationPath = path }
      guard updated != allApps[index] else { return }
      allApps[index] = updated
    } else {
      allApps.append(app)
    }
    persist()
  }

  @discardableResult
  func addApp(_ app: DetectedApp) -> Bool {
    guard !app.id.isEmpty, !app.name.isEmpty,
          !allApps.contains(where: { $0.id == app.id }) else { return false }
    var added = app
    added.isManuallyAdded = true
    allApps.append(added)
    persist()
    return true
  }

  func updateApp(_ id: String, detection: Bool? = nil, visible: Bool? = nil) {
    guard let index = allApps.firstIndex(where: { $0.id == id }) else { return }
    if let detection { allApps[index].isDetectionEnabled = detection }
    if let visible { allApps[index].isVisible = visible }
    persist()
  }

  func removeApp(_ id: String) {
    // 차단 정보는 일반 목록 삭제로 지우지 않는다.
    guard let index = allApps.firstIndex(where: { $0.id == id }),
          allApps[index].isDetectionEnabled else { return }
    allApps.remove(at: index)
    persist()
  }

  private func scanRunningApps() {
    for application in workspace.runningApplications {
      if let app = descriptor(for: application) { recordDetection(app) }
    }
    updateActiveApp(workspace.frontmostApplication)
  }

  private func handle(_ event: Notification) {
    guard let application = event.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
    if event.name == NSWorkspace.didTerminateApplicationNotification {
      if activeAppID == application.bundleIdentifier { activeAppID = nil }
    } else {
      if let app = descriptor(for: application) { recordDetection(app) }
      if event.name == NSWorkspace.didActivateApplicationNotification {
        updateActiveApp(application)
      }
    }
  }

  private func updateActiveApp(_ application: NSRunningApplication?) {
    activeAppID = application.flatMap { descriptor(for: $0)?.id }
  }

  private func descriptor(for application: NSRunningApplication) -> DetectedApp? {
    guard application.activationPolicy == .regular,
          let id = application.bundleIdentifier,
          id != Bundle.main.bundleIdentifier,
          let url = application.bundleURL else { return nil }
    return DetectedApp(id: id, name: application.localizedName ?? url.deletingPathExtension().lastPathComponent,
                       applicationPath: url.path)
  }

  private func restore() {
    guard let data = defaults.data(forKey: Self.storageKey) else { return }
    do {
      let decoded = try JSONDecoder().decode([DetectedApp].self, from: data)
      guard decoded.allSatisfy({ !$0.id.isEmpty && !$0.name.isEmpty }),
            Set(decoded.map(\.id)).count == decoded.count else {
        throw CocoaError(.coderReadCorrupt)
      }
      allApps = decoded
    } catch {
      storageError = "저장된 앱 목록을 읽지 못했어요. 기존 저장 데이터는 보존됩니다."
    }
  }

  private func persist() {
    // 읽기 실패한 기존 데이터를 빈 목록으로 덮어쓰지 않는다.
    guard storageError == nil else { return }
    do {
      defaults.set(try JSONEncoder().encode(allApps), forKey: Self.storageKey)
    } catch {
      storageError = "앱 목록 변경을 저장하지 못했어요."
    }
  }
}
