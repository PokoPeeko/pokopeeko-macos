import Foundation
import Observation

/// Socket.IO 이벤트를 사용자 UUID에 연결한다. updatedAt은 사용 시간 시작 시각이 아니다.
@MainActor
@Observable
final class PresenceStore {
  private struct Entry<Value> {
    let value: Value
    let updatedAt: Double
    let receivedAt: Date
  }
  private struct WindowStatus: Decodable {
    let userId: UUID
    let appTitle: String
    let taskDescription: String
    let updatedAt: Double
  }
  private struct Removed: Decodable { let userId: UUID }
  private var windows: [UUID: Entry<WindowStatus>] = [:]
  private var music: [UUID: Entry<MusicStatusUpdatedDTO>] = [:]
  private(set) var isConnected = false

  func setConnected(_ connected: Bool) {
    isConnected = connected
    if !connected { windows.removeAll(); music.removeAll() }
  }

  func receive(event: String, data: Data, now: Date = Date()) throws {
    let decoder = JSONDecoder()
    switch event {
    case "window_status:updated":
      let value = try decoder.decode(WindowStatus.self, from: data)
      guard valid(value.appTitle, maximum: 100), valid(value.taskDescription, maximum: 500),
            value.updatedAt.isFinite, value.updatedAt > 0 else { throw PresencePayloadError.invalid }
      if let previous = windows[value.userId], previous.updatedAt > value.updatedAt { return }
      windows[value.userId] = Entry(value: value, updatedAt: value.updatedAt, receivedAt: now)
    case "music_status:updated":
      let value = try decoder.decode(MusicStatusUpdatedDTO.self, from: data)
      guard value.updatedAt.isFinite, value.updatedAt > 0 else { throw PresencePayloadError.invalid }
      guard valid(value.artistName, maximum: 200), valid(value.trackTitle, maximum: 200) else {
        throw PresencePayloadError.invalid
      }
      if let previous = music[value.userId], previous.updatedAt > value.updatedAt { return }
      music[value.userId] = Entry(value: value, updatedAt: value.updatedAt, receivedAt: now)
    case "music_status:removed":
      let value = try decoder.decode(MusicStatusRemovedDTO.self, from: data)
      music[value.userId] = nil
    case "user_status:removed":
      let value = try decoder.decode(Removed.self, from: data)
      windows[value.userId] = nil
      music[value.userId] = nil
    default: return
    }
  }

  func expire(now: Date = Date()) {
    // heartbeat는 updatedAt을 바꾸지 않는다. 20초 재조회에서 마지막으로 받은 시간을 사용한다.
    windows = windows.filter { now.timeIntervalSince($0.value.receivedAt) < 70 }
    music = music.filter { now.timeIntervalSince($0.value.receivedAt) < 70 }
  }

  func retainUsers(_ ids: Set<UUID>) {
    windows = windows.filter { ids.contains($0.key) }
    music = music.filter { ids.contains($0.key) }
  }

  func applying(to original: Friend) -> Friend {
    var friend = original
    friend.currentAppName = nil
    friend.currentAppBundleIdentifier = nil
    friend.songTitle = nil
    friend.artistName = nil
    friend.isMusicPaused = false
    friend.usageDuration = 0
    guard isConnected else { friend.isOnline = nil; return friend }
    let window = windows[friend.id]?.value
    let track = music[friend.id]?.value
    // 서버는 소켓 접속자 명단을 제공하지 않는다. 여기서 온라인은 공유 상태가 있음을 뜻한다.
    friend.isOnline = window != nil || track != nil
    friend.currentAppName = window?.appTitle
    friend.songTitle = track?.trackTitle
    friend.artistName = track?.artistName
    friend.isMusicPaused = track?.status == .paused
    return friend
  }

  private func valid(_ text: String, maximum: Int) -> Bool {
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.count <= maximum
  }
}

enum PresencePayloadError: Error { case invalid }
