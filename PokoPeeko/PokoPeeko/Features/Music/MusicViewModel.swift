import AppKit
import Observation
import OSLog

@MainActor @Observable
final class MusicViewModel {
  var isEnabled: Bool {
    didSet { defaults.set(isEnabled, forKey: "musicSharingEnabled"); restart() }
  }
  var provider: MusicProvider {
    didSet { defaults.set(provider.rawValue, forKey: "musicProvider"); restart() }
  }
  private(set) var detectionStatus: MusicDetectionStatus = .disabled
  private(set) var artwork: MusicArtwork?
  private(set) var sampledAt = Date()
  private static let logger = Logger(subsystem: "com.peekopoko.pokopeeko", category: "Music")
  private(set) var playback: MusicPlayback = .closed
  private(set) var errorMessage: String?
  private(set) var permissionDenied = false
  private(set) var isRequestingPermission = false
  @ObservationIgnored var onChange: ((MusicPlayback) -> Void)?
  @ObservationIgnored private var task: Task<Void, Never>?
  @ObservationIgnored private var permissionTask: Task<Void, Never>?
  @ObservationIgnored private var artworkTask: Task<Void, Never>?
  @ObservationIgnored private var lastErrorCode: Int?
  @ObservationIgnored private var generation = UUID()
  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let processID: (MusicProvider) -> pid_t?
  @ObservationIgnored private let read: (pid_t, MusicProvider) async throws -> MusicPlayback
  @ObservationIgnored private let askPermission: (pid_t) async throws -> Void
  @ObservationIgnored private let readArtwork: (pid_t, MusicProvider, MusicPlayback) async -> MusicArtwork?

  init(defaults: UserDefaults = .standard,
       processID: @escaping (MusicProvider) -> pid_t? = { provider in
         NSRunningApplication.runningApplications(withBundleIdentifier: provider.bundleID).first?.processIdentifier
       },
       read: @escaping (pid_t, MusicProvider) async throws -> MusicPlayback = { try await MusicPlayerReader.read(processID: $0, provider: $1) },
       readArtwork: @escaping (pid_t, MusicProvider, MusicPlayback) async -> MusicArtwork? = { await MusicPlayerReader.artwork(processID: $0, provider: $1, expected: $2) },
       askPermission: @escaping (pid_t) async throws -> Void = { try await MusicPlayerReader.requestPermission(processID: $0) }) {
    self.defaults = defaults
    self.processID = processID
    self.read = read
    self.readArtwork = readArtwork
    self.askPermission = askPermission
    isEnabled = defaults.bool(forKey: "musicSharingEnabled")
    provider = MusicProvider(rawValue: defaults.string(forKey: "musicProvider") ?? "") ?? .appleMusic
  }

  func start() { if task == nil { restart() } }
  func retry() { restart() }

  func requestPermission() {
    guard isEnabled, !isRequestingPermission else { return }
    guard let pid = processID(provider) else { detectionStatus = .waitingForApp; return }
    let token = generation
    isRequestingPermission = true
    detectionStatus = .checking
    permissionTask = Task { [weak self] in
      guard let self else { return }
      do {
        try await self.askPermission(pid)
        guard token == self.generation, !Task.isCancelled else { return }
        self.isRequestingPermission = false
        self.restart()
      } catch {
        guard token == self.generation, !Task.isCancelled else { return }
        self.isRequestingPermission = false
        self.handleReadError(error)
      }
    }
  }

  private func restart() {
    generation = UUID()
    task?.cancel()
    task = nil
    permissionTask?.cancel()
    permissionTask = nil
    isRequestingPermission = false
    artworkTask?.cancel()
    artworkTask = nil
    artwork = nil
    detectionStatus = isEnabled ? .checking : .disabled
    errorMessage = nil
    lastErrorCode = nil
    permissionDenied = false
    update(.closed)
    guard isEnabled else { return }
    let token = generation
    task = Task { [weak self] in
      while !Task.isCancelled {
        guard let self, token == self.generation else { return }
        await self.poll(token: token)
        do { try await Task.sleep(for: .seconds(1)) } catch { return }
      }
    }
  }

  private func poll(token: UUID) async {
    guard !isRequestingPermission else { return }
    guard let pid = processID(provider) else {
      errorMessage = nil
      detectionStatus = .waitingForApp
      update(.closed)
      return
    }
    guard !permissionDenied else { return } // No repeated TCC prompts; explicit retry after changing permission.
    do {
      if detectionStatus == .waitingForApp { detectionStatus = .checking }
      let selectedProvider = provider
      let result = try await read(pid, selectedProvider)
      guard token == generation, !Task.isCancelled, !isRequestingPermission else { return }
      errorMessage = nil
      lastErrorCode = nil
      detectionStatus = .connected
      let changedTrack = !playback.hasSameTrack(as: result)
      update(result)
      if changedTrack && result.state != .closed {
        artworkTask?.cancel()
        artworkTask = Task { [weak self] in
          guard let self else { return }
          let image = await self.readArtwork(pid, selectedProvider, result)
          guard token == self.generation, !Task.isCancelled, self.playback.hasSameTrack(as: result) else { return }
          self.artwork = image
        }
      }
    } catch {
      guard token == generation, !Task.isCancelled, !isRequestingPermission else { return }
      if case MusicPlayerReader.ReaderError.changed = error { return }
      handleReadError(error)
    }
  }

  private func handleReadError(_ error: Error) {
    update(.closed)
    let code = (error as NSError).code
    if lastErrorCode != code { Self.logger.error("음악 감지 실패 code=\(code)") }
    lastErrorCode = code
    if [-1743, -1744].contains(code) {
      detectionStatus = code == -1744 ? .permissionRequired : .permissionDenied
      permissionDenied = true
      errorMessage = "음악 앱 접근 권한이 필요해요. 권한 요청 버튼을 눌러주세요."
    } else {
      detectionStatus = .failed
      errorMessage = code == -10004
        ? "음악 앱 접근이 앱의 보안 설정에 의해 거절됐어요. 최신 빌드로 다시 실행해주세요."
        : "음악 정보를 읽지 못했어요. 음악 앱에서 곡을 재생한 뒤 다시 시도해주세요."
    }
  }

  func displayedPosition(at date: Date) -> TimeInterval? {
    guard let position = playback.position, let duration = playback.duration else { return nil }
    let delta = playback.state == .playing ? max(0, date.timeIntervalSince(sampledAt)) : 0
    return min(duration, max(0, position + delta))
  }

  private func update(_ value: MusicPlayback) {
    let changed = !playback.hasSameSharedState(as: value)
    if !playback.hasSameTrack(as: value) { artwork = nil }
    playback = value
    sampledAt = Date()
    if changed { onChange?(value) }
  }
}
