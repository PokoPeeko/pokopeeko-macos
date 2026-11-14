import Foundation

@main
struct MusicChecks {
  @MainActor static func main() async throws {
    func check(_ value: Bool, _ message: String) { precondition(value, message) }
    let suite = "MusicChecks.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    var running = true
    var reads = 0
    var artReads = 0
    var source = MusicPlayback(state: .playing, title: "곡, \"제목\"\n한글", artist: "Artist")
    var changes: [MusicPlayback] = []
    let model = MusicViewModel(defaults: defaults, processID: { _ in running ? 123 : nil }, read: { _, _ in
      reads += 1
      return source
    }, readArtwork: { _, _, _ in artReads += 1; return nil })
    model.onChange = { changes.append($0) }
    model.start()
    try await Task.sleep(for: .milliseconds(30))
    check(model.detectionStatus == .disabled && reads == 0, "Disabled by default; never request automation")
    model.isEnabled = true
    try await Task.sleep(for: .milliseconds(50))
    check(model.playback == source && reads == 1, "Publish initial track without mangling metadata")
    check(model.detectionStatus == .connected, "Successful read is distinct from waiting for an app")
    source.position = 20
    source.duration = 120
    try await Task.sleep(for: .milliseconds(1100))
    check(artReads == 1, "Artwork is read only once for the current track")
    check(model.displayedPosition(at: model.sampledAt.addingTimeInterval(3)) == 23, "Local progress interpolates while playing")
    check(changes.count == 1, "Unchanged local polls must not send network updates")
    source.state = .paused
    try await Task.sleep(for: .milliseconds(1100))
    check(model.playback.state == .paused && model.playback.title == source.title, "Pause retains metadata")
    check(model.displayedPosition(at: model.sampledAt.addingTimeInterval(3)) == 20, "Paused progress must freeze")
    check(artReads == 1, "Pause must retain artwork without re-fetching")
    source = .closed
    try await Task.sleep(for: .milliseconds(1100))
    check(model.detectionStatus == .connected && model.playback == .closed, "Connected player with no song is not a connection failure")
    running = false
    try await Task.sleep(for: .milliseconds(1100))
    check(model.detectionStatus == .waitingForApp && model.playback == .closed, "Quit clears music locally without querying a missing process")
    model.isEnabled = false
    let count = reads
    try await Task.sleep(for: .milliseconds(1100))
    check(reads == count, "Disabled monitor must stop polling")
    check(MusicStatusUpdateDTO(playback: MusicPlayback(state: .paused, title: "Track", artist: "Artist"))?.payload["status"] == "PAUSE", "Pause uses documented uppercase wire state")
    check(MusicStatusUpdateDTO(playback: .closed) == nil, "Closed uses a separate event without song fields")
    source = MusicPlayback(state: .playing, title: "Track", artist: "Artist")
    check(Set(MusicStatusUpdateDTO(playback: source)!.payload.keys) == ["trackTitle", "artistName", "status"], "Only documented fields are sent")
    check(MusicStatusUpdateDTO(playback: source)?.payload["status"] == "PLAYING", "Playing wire state")
    check(MusicStatusUpdateDTO(playback: MusicPlayback(state: .playing, title: " ", artist: "Artist")) == nil,
          "Invalid metadata must not leave a previous song displayed")
    let long = MusicPlayback(state: .playing, title: String(repeating: "가", count: 250), artist: " Artist ")
    check(MusicStatusUpdateDTO(playback: long)?.trackTitle.count == 200 && MusicStatusUpdateDTO(playback: long)?.artistName == "Artist",
          "Match server string limits and trim blank edges")

    // A result from the previous provider must not overwrite a newer selection or disabled monitor.
    let delayed = MusicViewModel(defaults: defaults, processID: { _ in 123 }, read: { _, _ in
      try? await Task.sleep(for: .milliseconds(150))
      return MusicPlayback(state: .playing, title: "Stale", artist: "Old")
    }, readArtwork: { _, _, _ in nil })
    delayed.isEnabled = true
    try await Task.sleep(for: .milliseconds(25))
    delayed.isEnabled = false
    try await Task.sleep(for: .milliseconds(220))
    check(delayed.playback == .closed, "Ignore stale reads after disabling")
    let denied = MusicViewModel(defaults: defaults, processID: { _ in 123 }, read: { _, _ in
      throw NSError(domain: NSOSStatusErrorDomain, code: -1743)
    }, readArtwork: { _, _, _ in nil })
    denied.isEnabled = true
    try await Task.sleep(for: .milliseconds(50))
    check(denied.detectionStatus == .permissionDenied && denied.permissionDenied && denied.playback == .closed, "Permission denial is actionable without false playback")
    denied.isEnabled = false
    var permissionRequests = 0
    var granted = false
    let permissionModel = MusicViewModel(defaults: defaults, processID: { _ in 123 }, read: { _, _ in
      if !granted { throw NSError(domain: NSOSStatusErrorDomain, code: -1744) }
      return MusicPlayback(state: .playing, title: "Granted song", artist: "Artist")
    }, readArtwork: { _, _, _ in nil }, askPermission: { _ in
      permissionRequests += 1
      granted = true
    })
    permissionModel.isEnabled = true
    try await Task.sleep(for: .milliseconds(50))
    check(permissionRequests == 0 && permissionModel.detectionStatus == .permissionRequired,
          "Turning on sharing must not prompt for permission")
    permissionModel.retry()
    try await Task.sleep(for: .milliseconds(50))
    check(permissionRequests == 0, "Retry must never prompt implicitly")
    permissionModel.requestPermission()
    permissionModel.requestPermission()
    try await Task.sleep(for: .milliseconds(100))
    check(permissionRequests == 1 && permissionModel.detectionStatus == .connected,
          "Only explicit button requests permission, with no duplicate prompt")
    permissionModel.isEnabled = false
    permissionModel.requestPermission()
    try await Task.sleep(for: .milliseconds(30))
    check(permissionRequests == 1, "Disabled card cannot request permission")
    let sandboxFailure = MusicViewModel(defaults: defaults, processID: { _ in 123 }, read: { _, _ in
      throw NSError(domain: NSOSStatusErrorDomain, code: -10004)
    }, readArtwork: { _, _, _ in nil })
    sandboxFailure.isEnabled = true
    try await Task.sleep(for: .milliseconds(50))
    check(sandboxFailure.detectionStatus == .failed && !sandboxFailure.permissionDenied,
          "Sandbox privilege errors must not tell users their TCC grant was denied")
    sandboxFailure.isEnabled = false
    print("Music checks passed: opt-in, polling deduplication, pause, quit, disable, stale reads, permission error and wire compatibility. No music apps queried.")
  }
}
