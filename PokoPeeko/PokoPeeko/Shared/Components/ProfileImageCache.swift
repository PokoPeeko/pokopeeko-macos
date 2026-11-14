import AppKit
import CryptoKit

/// 정적 아바타의 공통 메모리·디스크 캐시. 네트워크 요청에는 인증 정보를 넣지 않는다.
@MainActor
final class ProfileImageCache {
  static let shared = ProfileImageCache(directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
    .first?.appendingPathComponent("PokoPeeko/ProfileImages", isDirectory: true))
  private let directory: URL?
  private let session: URLSession
  private let memory = NSCache<NSURL, NSImage>()
  private var pending: [URL: Task<NSImage, Error>] = [:]

  init(directory: URL?, session: URLSession = .shared) {
    self.directory = directory
    self.session = session
    memory.countLimit = 100
    memory.totalCostLimit = 32 * 1024 * 1024
  }

  func cachedImage(for url: URL) -> NSImage? {
    if let image = memory.object(forKey: url as NSURL) { return image }
    guard let file = fileURL(url), let data = try? Data(contentsOf: file), data.count <= 8 * 1024 * 1024,
          let image = NSImage(data: data) else { return nil }
    memory.setObject(image, forKey: url as NSURL, cost: data.count)
    return image
  }

  func save(_ data: Data, for url: URL) {
    guard data.count <= 8 * 1024 * 1024, let image = NSImage(data: data) else { return }
    memory.setObject(image, forKey: url as NSURL, cost: data.count)
    guard let directory, let file = fileURL(url) else { return }
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try? data.write(to: file, options: .atomic)
    // 파일명은 URL의 SHA256. 100 MiB를 넘으면 오래된 캐시부터 정리한다.
    guard let files = try? FileManager.default.contentsOfDirectory(at: directory,
      includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) else { return }
    let entries = files.map { file -> (URL, Int, Date) in
      let values = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
      return (file, values?.fileSize ?? 0, values?.contentModificationDate ?? .distantPast)
    }.sorted { $0.2 < $1.2 }
    var total = entries.reduce(0) { $0 + $1.1 }
    for entry in entries where total > 100 * 1024 * 1024 {
      try? FileManager.default.removeItem(at: entry.0)
      total -= entry.1
    }
  }

  func image(for url: URL) async throws -> NSImage {
    if let image = cachedImage(for: url) { return image }
    if let task = pending[url] { return try await task.value }
    let task = Task { () throws -> NSImage in
      var request = URLRequest(url: url)
      request.timeoutInterval = 15
      let (data, response) = try await session.data(for: request)
      guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
            data.count <= 8 * 1024 * 1024, let image = NSImage(data: data) else {
        throw URLError(.badServerResponse)
      }
      if !(http.value(forHTTPHeaderField: "Cache-Control") ?? "").lowercased().contains("no-store") {
        save(data, for: url)
      }
      return image
    }
    pending[url] = task
    defer { pending[url] = nil }
    return try await task.value
  }

  private func fileURL(_ url: URL) -> URL? {
    let key = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
    return directory?.appendingPathComponent(key + ".image")
  }
}
