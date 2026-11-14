import AppKit
import Foundation

private final class CachedImageProtocol: URLProtocol, @unchecked Sendable {
  nonisolated(unsafe) static var imageData = Data()
  nonisolated(unsafe) static var requests = 0
  private static let lock = NSLock()
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    Self.lock.lock(); Self.requests += 1; Self.lock.unlock()
    guard request.value(forHTTPHeaderField: "Authorization") == nil,
          request.value(forHTTPHeaderField: "x-session-id") == nil else {
      client?.urlProtocol(self, didFailWithError: URLError(.userAuthenticationRequired)); return
    }
    let missing = request.url!.lastPathComponent == "missing.png"
    let noStore = request.url!.lastPathComponent == "no-store.png"
    let response = HTTPURLResponse(url: request.url!, statusCode: missing ? 404 : 200,
      httpVersion: nil, headerFields: ["Content-Type": "image/png", "Cache-Control": noStore ? "no-store" : "public"])!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: missing ? Data("missing".utf8) : Self.imageData)
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() { }
}

@main
struct ProfileCacheChecks {
  struct Failure: Error { let message: String }
  @MainActor
  static func main() async throws {
    func check(_ value: Bool, _ message: String) throws { if !value { throw Failure(message: message) } }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("PokoPeeko.CacheChecks.\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let owner = UUID(), otherOwner = UUID(), user = UUID()
    let profile = UserProfile(id: user, displayName: "Cached name", profileImageFileName: "a.png")
    let snapshots = ProfileSnapshotCache(directory: root.appendingPathComponent("profiles"))
    snapshots.save(profile, owner: owner)
    let reopened = ProfileSnapshotCache(directory: root.appendingPathComponent("profiles"))
    try check(reopened.profile(owner: owner, id: user) == profile, "Profile metadata must survive a cache instance restart")
    try check(reopened.profile(owner: otherOwner, id: user) == nil, "Profiles must remain scoped to the viewer account")
    reopened.remove(owner: owner, id: user)
    try check(reopened.profile(owner: owner, id: user) == nil, "Deleted or unauthorized profiles must be removable")

    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8,
      samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    bitmap.bitmapData?.initialize(repeating: 255, count: bitmap.bytesPerRow * 2)
    CachedImageProtocol.imageData = bitmap.representation(using: .png, properties: [:])!
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [CachedImageProtocol.self]
    let session = URLSession(configuration: config)
    defer { session.invalidateAndCancel() }
    let images = root.appendingPathComponent("images")
    let cache = ProfileImageCache(directory: images, session: session)
    let url = URL(string: "https://images.test.invalid/static/profile/a.png")!
    async let first = cache.image(for: url)
    async let duplicate = cache.image(for: url)
    _ = try await (first, duplicate)
    try check(CachedImageProtocol.requests == 1, "Simultaneous avatar loads must share one request")
    let reloaded = ProfileImageCache(directory: images, session: session)
    try check(reloaded.cachedImage(for: url) != nil, "Avatars must load synchronously from disk after restart")
    _ = try await reloaded.image(for: url)
    try check(CachedImageProtocol.requests == 1, "Cached avatars must not repeat a download")
    _ = try await reloaded.image(for: URL(string: "https://images.test.invalid/static/profile/b.png")!)
    try check(CachedImageProtocol.requests == 2, "A changed image filename must download new content")
    let missing = URL(string: "https://images.test.invalid/static/profile/missing.png")!
    do { _ = try await cache.image(for: missing); throw Failure(message: "404 must not become an image") }
    catch let error as URLError { try check(error.code == .badServerResponse, "Wrong error for missing image") }
    try check(cache.cachedImage(for: missing) == nil, "Failed downloads must never become persistent cache entries")
    let noStore = URL(string: "https://images.test.invalid/static/profile/no-store.png")!
    _ = try await cache.image(for: noStore)
    try check(cache.cachedImage(for: noStore) == nil, "Server no-store must be respected")
    print("Profile cache checks passed: account isolation, disk persistence, request coalescing, changed filenames, 404 rejection and no-store. No external requests were made.")
  }
}
