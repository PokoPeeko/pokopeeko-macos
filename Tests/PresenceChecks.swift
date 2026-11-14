import Foundation

@main
struct PresenceChecks {
  struct Failure: Error { let message: String }
  @MainActor
  static func main() async throws {
    func check(_ condition: Bool, _ message: String) throws {
      if !condition { throw Failure(message: message) }
    }
    let id = UUID(uuidString: "9f02a61e-2adc-4e23-b0ae-c47a9bd8c788")!
    let friend = Friend(id: id, name: "Test User", isOnline: nil)
    let store = PresenceStore()
    let origin = Date(timeIntervalSince1970: 1000)
    func window(_ title: String, timestamp: Int = 2000) -> Data {
      Data("{\"userId\":\"\(id)\",\"appTitle\":\"\(title)\",\"taskDescription\":\"Using app\",\"updatedAt\":\(timestamp)}".utf8)
    }
    store.setConnected(true)
    try store.receive(event: "window_status:updated", data: window("Editor"), now: origin)
    try store.receive(event: "window_status:updated", data: window("Old", timestamp: 1000), now: origin)
    try check(store.applying(to: friend).currentAppName == "Editor", "Late older events must not overwrite current activity")
    try check(store.applying(to: friend).usageDuration == 0, "Update timestamp must not become fabricated usage time")
    func music(_ status: String, timestamp: Int = 2000) throws -> Data {
      try JSONSerialization.data(withJSONObject: ["userId": id.uuidString, "artistName": "Artist",
        "trackTitle": "Track", "status": status, "updatedAt": timestamp])
    }
    try store.receive(event: "music_status:updated", data: music("PLAYING"), now: origin)
    try check(store.applying(to: friend).songTitle == "Track" && !store.applying(to: friend).isMusicPaused, "Playing metadata")
    try store.receive(event: "music_status:updated", data: music("PAUSE", timestamp: 2100), now: origin)
    try store.receive(event: "music_status:updated", data: music("PLAYING", timestamp: 2000), now: origin)
    try check(store.applying(to: friend).isMusicPaused, "Older playing event must not replace paused metadata")
    do {
      try store.receive(event: "music_status:updated", data: music("UNKNOWN"), now: origin)
      throw Failure(message: "Unknown music state must be rejected")
    } catch is DecodingError { }
    let removedMusic = try JSONSerialization.data(withJSONObject: ["userId": id.uuidString])
    try store.receive(event: "music_status:removed", data: removedMusic, now: origin)
    try check(store.applying(to: friend).songTitle == nil && store.applying(to: friend).currentAppName == "Editor", "Music removal preserves app activity")
    try store.receive(event: "music_status:removed", data: removedMusic, now: origin)
    try store.receive(event: "music_status:updated", data: music("PAUSE", timestamp: 2200), now: origin)
    // Heartbeat keeps the original server updatedAt. Repeated snapshots renew local freshness.
    try store.receive(event: "window_status:updated", data: window("Editor"), now: origin.addingTimeInterval(60))
    store.expire(now: origin.addingTimeInterval(71))
    try check(store.applying(to: friend).currentAppName == "Editor" && store.applying(to: friend).songTitle == nil,
              "Expiry must use last snapshot receipt per activity type, not the server update timestamp")
    store.expire(now: origin.addingTimeInterval(131))
    try check(store.applying(to: friend).isOnline == false, "Missing state after grace must stop showing online")
    try store.receive(event: "window_status:updated", data: window("Editor"))
    try store.receive(event: "user_status:removed", data: Data("{\"userId\":\"\(id)\"}".utf8))
    try check(store.applying(to: friend).currentAppName == nil, "Removal must clear a user's activity")
    do {
      try store.receive(event: "window_status:updated", data: window(" "))
      throw Failure(message: "Whitespace activity must fail validation")
    } catch PresencePayloadError.invalid { }
    try store.receive(event: "window_status:updated", data: window("Editor"))
    store.retainUsers([])
    try check(store.applying(to: friend).currentAppName == nil, "Removed friends must lose cached activity")
    store.setConnected(false)
    try check(store.applying(to: friend).isOnline == nil, "Connection failure must show unknown instead of offline")

    guard let endpoint = ProcessInfo.processInfo.environment["PRESENCE_TEST_URL"] else {
      throw Failure(message: "The isolated local protocol test server must be supplied")
    }
    let service = PresenceService(baseURL: endpoint)
    service.updateCurrentApp(DetectedApp(id: "test.editor", name: "Test Editor"))
    let song = MusicPlayback(state: .playing, title: "Local song", artist: "Local artist")
    service.updateMusic(song)
    service.connect(sessionID: "00000000-0000-4000-8000-000000000000")
    for _ in 0..<100 {
      if service.store.applying(to: friend).currentAppName == "Remote Editor" && service.store.applying(to: friend).isMusicPaused { break }
      try await Task.sleep(for: .milliseconds(100))
    }
    try check(service.store.isConnected && service.store.applying(to: friend).currentAppName == "Remote Editor",
              "The real Socket.IO client must authenticate, join the namespace and receive friend events")
    try check(service.store.applying(to: friend).isMusicPaused, "Late-joining clients receive paused song from initial snapshot")
    service.updateMusic(song)
    service.setSharingEnabled(false)
    service.updateCurrentApp(DetectedApp(id: "test.other", name: "Other Editor"))
    // Exercise the real 20-second heartbeat, current-app resend and friend-state refresh.
    try await Task.sleep(for: .seconds(21))
    let (resultData, _) = try await URLSession.shared.data(from: URL(string: endpoint + "/test/results")!)
    let result = try JSONSerialization.jsonObject(with: resultData) as! [String: Any]
    try check(result["musicUpdates"] as? Int == 1 && result["validMusicPayload"] as? Bool == true,
              "Initial song must include status; unchanged polls and heartbeat must not duplicate it")
    try check(result["authenticated"] as? Bool == true, "Session ID must be in Socket.IO CONNECT auth payload")
    try check(result["validAppPayload"] as? Bool == true, "App emits must have exactly the documented fields")
    try check(result["receivedPrivateState"] as? Bool == true, "Hiding or leaving an app must replace previous shared app state")
    try check(result["lastAppTitle"] as? String == "활동 비공개", "Paused sharing must stay private through app switches and heartbeat")
    try check((result["heartbeats"] as? Int ?? 0) >= 1, "Connected clients must send heartbeat")
    try check((result["friendQueries"] as? Int ?? 0) >= 2, "Connected clients must refresh initial and ongoing friend state")
    service.updateMusic(MusicPlayback(state: .paused, title: "Local song", artist: "Local artist"))
    try await Task.sleep(for: .milliseconds(200))
    service.reconnect()
    for _ in 0..<100 {
      if service.store.isConnected && service.store.applying(to: friend).isMusicPaused { break }
      try await Task.sleep(for: .milliseconds(100))
    }
    try check(service.store.isConnected, "Reconnect must succeed")
    try await Task.sleep(for: .milliseconds(200))
    let (pauseData, _) = try await URLSession.shared.data(from: URL(string: endpoint + "/test/results")!)
    let pause = try JSONSerialization.jsonObject(with: pauseData) as! [String: Any]
    try check(pause["musicUpdates"] as? Int == 3 && pause["lastMusicStatus"] as? String == "PAUSE",
              "Pause is sent on change and republished on reconnect")
    service.updateMusic(.closed)
    service.updateMusic(.closed)
    service.setSharingEnabled(true)
    try await Task.sleep(for: .milliseconds(300))
    let (resumedData, _) = try await URLSession.shared.data(from: URL(string: endpoint + "/test/results")!)
    let resumed = try JSONSerialization.jsonObject(with: resumedData) as! [String: Any]
    try check(resumed["musicUpdates"] as? Int == 3 && resumed["musicRemovals"] as? Int == 1 && resumed["validMusicRemove"] as? Bool == true,
              "Closed sends one separate event without a payload")
    try check(service.store.applying(to: friend).songTitle == nil && service.store.applying(to: friend).currentAppName == "Remote Editor",
              "Removed listener clears music only")
    try check(resumed["lastAppTitle"] as? String == "Other Editor", "Resuming sharing must publish the current app")
    service.reconnect()
    for _ in 0..<100 {
      if service.store.isConnected { break }
      try await Task.sleep(for: .milliseconds(100))
    }
    try await Task.sleep(for: .milliseconds(300))
    let (closedData, _) = try await URLSession.shared.data(from: URL(string: endpoint + "/test/results")!)
    let closed = try JSONSerialization.jsonObject(with: closedData) as! [String: Any]
    try check(closed["musicRemovals"] as? Int == 2, "Reconnect while closed must clear previous server music")
    service.stop()
    try check(!service.store.isConnected && service.sessionID == nil && service.store.applying(to: friend).isOnline == nil,
              "Stopping must discard the authenticated transport and remote state")
    var expiredSession: String?
    service.onSessionExpired = { expiredSession = $0 }
    let invalidSession = "00000000-0000-4000-8000-000000000001"
    service.connect(sessionID: invalidSession)
    for _ in 0..<50 {
      if expiredSession != nil { break }
      try await Task.sleep(for: .milliseconds(100))
    }
    try check(expiredSession == invalidSession && service.sessionID == nil && !service.store.isConnected,
              "Namespace authentication errors must expire only the matching transport session")
    print("Presence checks passed: event ordering, independent expiry, privacy replacement, real Socket.IO handshake/auth, app send/receive, heartbeat, refresh and disconnect. Only an isolated localhost server was used.")
  }
}
