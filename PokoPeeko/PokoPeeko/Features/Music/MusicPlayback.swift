import Foundation

nonisolated enum MusicProvider: String, CaseIterable, Identifiable, Sendable {
  case appleMusic, spotify
  var id: String { rawValue }
  var name: String { self == .appleMusic ? "Apple Music" : "Spotify" }
  var bundleID: String { self == .appleMusic ? "com.apple.Music" : "com.spotify.client" }
}

nonisolated enum MusicPlaybackState: String, Codable, Sendable {
  case playing, paused, closed
}

nonisolated struct MusicPlayback: Equatable, Sendable {
  var state: MusicPlaybackState
  var title: String?
  var artist: String?
  var position: TimeInterval?
  var duration: TimeInterval?

  func hasSameSharedState(as other: MusicPlayback) -> Bool {
    state == other.state && title == other.title && artist == other.artist
  }
  func hasSameTrack(as other: MusicPlayback) -> Bool {
    title == other.title && artist == other.artist && state != .closed && other.state != .closed
  }
  static let closed = MusicPlayback(state: .closed)
  var description: String { [title, artist].compactMap { $0 }.joined(separator: " — ") }
}


nonisolated enum MusicArtwork: Sendable {
  case data(Data)
  case url(URL)
}

nonisolated enum MusicDetectionStatus {
  case disabled, waitingForApp, checking, connected, permissionRequired, permissionDenied, failed
}
