import AppKit
import Carbon

/// Reads the same scripting properties as AppleScript, without compiling scripts or launching a player.
/// Each descriptor stays on this worker; only value types cross back to the UI.
enum MusicPlayerReader {
  nonisolated static func read(processID: pid_t, provider: MusicProvider) async throws -> MusicPlayback {
    try await Task.detached(priority: .utility) {
      try autoreleasepool {
        let target = NSAppleEventDescriptor(processIdentifier: processID)
        let permission = AEDeterminePermissionToAutomateTarget(target.aeDesc, code("core"), code("getd"), false)
        guard permission == noErr else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(permission)) }
        let state = try get(property("pPlS"), target: target).enumCodeValue
        guard state == code("kPSP") || state == code("kPSp") || state == code("kPSF") || state == code("kPSR") else {
          return MusicPlayback.closed
        }
        // Resolve a single current-track object before reading metadata, avoiding mixed-track fields.
        let track = try get(property("pTrk"), target: target)
        let title = try get(property("pnam", container: track), target: target).stringValue ?? ""
        let artist = try get(property("pArt", container: track), target: target).stringValue ?? ""
        let position = try? get(property("pPos"), target: target).doubleValue
        let rawDuration = try? get(property("pDur", container: track), target: target).doubleValue
        let duration = rawDuration.map { provider == .spotify ? $0 / 1000 : $0 }
        // A switch during the read is retried next tick instead of publishing a mixed snapshot.
        let latestTrack = try get(property("pTrk"), target: target)
        guard latestTrack.data == track.data else { throw ReaderError.changed }
        let latestState = try get(property("pPlS"), target: target).enumCodeValue
        guard latestState == state else { throw ReaderError.changed }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .closed }
        return MusicPlayback(state: state == code("kPSp") ? .paused : .playing, title: title, artist: artist,
          position: position.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil },
          duration: duration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil })
      }
    }.value
  }

  /// Only the explicit permission button may invoke an interactive TCC request.
  nonisolated static func requestPermission(processID: pid_t) async throws {
    try await Task.detached(priority: .userInitiated) {
      let target = NSAppleEventDescriptor(processIdentifier: processID)
      let status = AEDeterminePermissionToAutomateTarget(target.aeDesc, code("core"), code("getd"), true)
      guard status == noErr else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }.value
  }

  /// Optional artwork is fetched once per track. Missing artwork never makes detection fail.
  nonisolated static func artwork(processID: pid_t, provider: MusicProvider, expected: MusicPlayback) async -> MusicArtwork? {
    await Task.detached(priority: .utility) {
      try? autoreleasepool {
        let target = NSAppleEventDescriptor(processIdentifier: processID)
        let track = try get(property("pTrk"), target: target)
        guard try get(property("pnam", container: track), target: target).stringValue == expected.title,
              try get(property("pArt", container: track), target: target).stringValue == expected.artist else { return nil }
        if provider == .spotify {
          guard let string = try get(property("aUrl", container: track), target: target).stringValue,
                let url = URL(string: string), url.scheme == "https", url.host != nil else { return nil }
          return MusicArtwork.url(url)
        }
        let item = NSAppleEventDescriptor.record()
        item.setDescriptor(NSAppleEventDescriptor(typeCode: code("cArt")), forKeyword: code("want"))
        item.setDescriptor(NSAppleEventDescriptor(enumCode: code("indx")), forKeyword: code("form"))
        item.setDescriptor(NSAppleEventDescriptor(int32: 1), forKeyword: code("seld"))
        item.setDescriptor(track, forKeyword: code("from"))
        guard let object = item.coerce(toDescriptorType: code("obj ")) else { return nil }
        let data = try get(property("pRaw", container: object), target: target).data
        guard !data.isEmpty && data.count <= 8 * 1024 * 1024 else { return nil }
        return MusicArtwork.data(data)
      }
    }.value
  }

  nonisolated private static func code(_ value: String) -> OSType {
    value.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
  }

  nonisolated private static func property(_ name: String, container: NSAppleEventDescriptor? = nil) -> NSAppleEventDescriptor {
    let record = NSAppleEventDescriptor.record()
    record.setDescriptor(NSAppleEventDescriptor(typeCode: code("prop")), forKeyword: code("want"))
    record.setDescriptor(NSAppleEventDescriptor(enumCode: code("prop")), forKeyword: code("form"))
    record.setDescriptor(NSAppleEventDescriptor(typeCode: code(name)), forKeyword: code("seld"))
    record.setDescriptor(container ?? NSAppleEventDescriptor.null(), forKeyword: code("from"))
    return record.coerce(toDescriptorType: code("obj "))!
  }

  nonisolated private static func get(_ object: NSAppleEventDescriptor, target: NSAppleEventDescriptor) throws -> NSAppleEventDescriptor {
    let event = NSAppleEventDescriptor(eventClass: code("core"), eventID: code("getd"),
      targetDescriptor: target, returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
    event.setParam(object, forKeyword: code("----"))
    let noPrompt = NSAppleEventDescriptor.SendOptions(rawValue: UInt(kAEDoNotPromptForUserConsent))
    let reply = try event.sendEvent(options: [.waitForReply, noPrompt], timeout: 2)
    let error = reply.paramDescriptor(forKeyword: code("errn"))?.int32Value ?? 0
    guard error == 0 else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(error)) }
    guard let result = reply.paramDescriptor(forKeyword: code("----")) else { throw ReaderError.invalid }
    return result
  }

  enum ReaderError: Error { case changed, invalid }
}
