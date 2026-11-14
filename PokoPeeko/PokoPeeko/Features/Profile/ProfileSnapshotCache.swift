import Foundation

/// 프로필 표시용 캐시. 로그인 판단에는 사용하지 않고, 조회한 사용자 계정별로 분리한다.
@MainActor
final class ProfileSnapshotCache {
  static let shared = ProfileSnapshotCache(directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
    .first?.appendingPathComponent("PokoPeeko/ProfileSnapshots", isDirectory: true))
  private let directory: URL?
  private var memory: [String: UserProfile] = [:]

  init(directory: URL?) { self.directory = directory }

  func profile(owner: UUID, id: UUID) -> UserProfile? {
    let key = "\(owner.uuidString)-\(id.uuidString)"
    if let saved = memory[key] { return saved }
    guard let file = directory?.appendingPathComponent(key + ".json"),
          let data = try? Data(contentsOf: file), data.count < 64_000,
          let saved = try? JSONDecoder().decode(UserProfile.self, from: data), saved.id == id else { return nil }
    memory[key] = saved
    return saved
  }

  func save(_ profile: UserProfile, owner: UUID) {
    guard let id = profile.id else { return }
    let key = "\(owner.uuidString)-\(id.uuidString)"
    if memory.count >= 256 { memory.removeAll() }
    memory[key] = profile
    guard let directory, let data = try? JSONEncoder().encode(profile) else { return }
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try? data.write(to: directory.appendingPathComponent(key + ".json"), options: .atomic)
    if let files = try? FileManager.default.contentsOfDirectory(at: directory,
       includingPropertiesForKeys: [.contentModificationDateKey]), files.count > 256 {
      let sorted = files.sorted {
        ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
          < ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
      }
      for file in sorted.prefix(files.count - 256) { try? FileManager.default.removeItem(at: file) }
    }
  }

  func remove(owner: UUID, id: UUID) {
    let key = "\(owner.uuidString)-\(id.uuidString)"
    memory[key] = nil
    if let file = directory?.appendingPathComponent(key + ".json") { try? FileManager.default.removeItem(at: file) }
  }
}
