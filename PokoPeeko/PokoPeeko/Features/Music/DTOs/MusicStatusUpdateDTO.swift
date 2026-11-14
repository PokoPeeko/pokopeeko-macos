import Foundation

/// Socket.IO wire values are intentionally separate from the local player states.
nonisolated enum MusicStatusDTO: String, Codable {
  case playing = "PLAYING"
  case paused = "PAUSE"
}

nonisolated struct MusicStatusUpdateDTO {
  let artistName: String
  let trackTitle: String
  let status: MusicStatusDTO

  init?(playback: MusicPlayback) {
    guard playback.state != .closed,
          let title = playback.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty,
          let artist = playback.artist?.trimmingCharacters(in: .whitespacesAndNewlines), !artist.isEmpty else { return nil }
    trackTitle = String(title.prefix(200))
    artistName = String(artist.prefix(200))
    status = playback.state == .paused ? .paused : .playing
  }

  var payload: [String: String] {
    ["trackTitle": trackTitle, "artistName": artistName, "status": status.rawValue]
  }
}

nonisolated struct MusicStatusUpdatedDTO: Decodable {
  let userId: UUID
  let artistName: String
  let trackTitle: String
  let status: MusicStatusDTO
  let updatedAt: Double
}

nonisolated struct MusicStatusRemovedDTO: Decodable {
  let userId: UUID
}
