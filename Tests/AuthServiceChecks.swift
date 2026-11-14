import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

private struct CheckFailure: Error { let message: String }

@MainActor
private final class PhotoMemorySessions: SessionStoring {
  var value: SessionManager.StoredSession?
  init(_ value: SessionManager.StoredSession) { self.value = value }
  func load() throws -> SessionManager.StoredSession? { value }
  func save(_ session: SessionManager.StoredSession) throws { value = session }
  func delete(ifMatching id: String) throws -> Bool {
    guard value?.sessionId == id else { return false }; value = nil; return true
  }
}

private nonisolated func require(_ condition: Bool, _ message: String) throws {
  if !condition { throw CheckFailure(message: message) }
}

private final class MockAuthProtocol: URLProtocol, @unchecked Sendable {
  // 검증은 순차 실행하며 모든 요청을 이 프로토콜에서 종료한다. 외부 요청은 발생하지 않는다.
  nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Int, Data))?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    do {
      guard let handler = Self.handler, let url = request.url else { throw CheckFailure(message: "Missing mock handler") }
      let (status, data) = try handler(request)
      let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil,
                                     headerFields: ["Content-Type": "application/json"])!
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }
  override func stopLoading() { }
}

private nonisolated func body(of request: URLRequest) -> Data {
  if let body = request.httpBody { return body }
  guard let stream = request.httpBodyStream else { return Data() }
  stream.open()
  defer { stream.close() }
  var output = Data()
  var buffer = [UInt8](repeating: 0, count: 4096)
  while stream.hasBytesAvailable {
    let count = stream.read(&buffer, maxLength: buffer.count)
    if count <= 0 { break }
    output.append(contentsOf: buffer.prefix(count))
  }
  return output
}

@main
struct AuthServiceChecks {
  @MainActor
  static func main() async throws {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockAuthProtocol.self]
    let session = URLSession(configuration: config)
    defer { session.invalidateAndCancel(); MockAuthProtocol.handler = nil }
    let service = AuthService(session: session, baseURL: URL(string: "https://auth.test.invalid")!)
    let sessionId = "550e8400-e29b-41d4-a716-446655440000"
    let deviceId = "550e8400-e29b-41d4-a716-446655440001"

    MockAuthProtocol.handler = { request in
      try require(request.url?.path == "/api/auth/login/apple" && request.httpMethod == "POST", "Login route/method mismatch")
      try require(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token", "Missing Firebase authorization")
      try require(request.value(forHTTPHeaderField: "x-device-id") == deviceId, "Missing device ID")
      try require(body(of: request).isEmpty, "Authentication must not send a request body")
      try require(request.value(forHTTPHeaderField: "Content-Type") == nil, "Bodyless login should not set a JSON Content-Type")
      return (201, Data(#"{"success":true,"message":"ok","data":{"sessionId":"550e8400-e29b-41d4-a716-446655440000","needsProfileSetup":false}}"#.utf8))
    }
    let existing = try await service.loginWithApple(firebaseIDToken: "test-token", deviceID: deviceId)
    try require(!existing.data.needsProfileSetup, "Existing-account routing flag was changed")

    MockAuthProtocol.handler = { _ in
      (200, Data(#"{"success":true,"message":"ok","data":{"sessionId":"550e8400-e29b-41d4-a716-446655440000","needsProfileSetup":true}}"#.utf8))
    }
    let incomplete = try await service.loginWithApple(firebaseIDToken: "test-token", deviceID: deviceId)
    try require(incomplete.data.needsProfileSetup, "Profile-setup flag must be preserved")

    let fileBytes = Data([0, 255, 13, 10, 128, 1])
    MockAuthProtocol.handler = { request in
      try require(request.url?.path == "/api/user/profile" && request.httpMethod == "PATCH", "Profile route/method mismatch")
      try require(request.value(forHTTPHeaderField: "x-session-id") == sessionId, "Profile request must authenticate its session")
      guard let contentType = request.value(forHTTPHeaderField: "Content-Type"),
            let boundary = contentType.components(separatedBy: "boundary=").last,
            contentType.hasPrefix("multipart/form-data; boundary=") else {
        throw CheckFailure(message: "Missing multipart boundary")
      }
      let data = body(of: request)
      try require(data.range(of: Data("name=\"displayName\"\r\n\r\n권수영\r\n".utf8)) != nil, "Missing UTF-8 displayName field")
      try require(data.range(of: Data("name=\"profile_image\"; filename=\"profile.png\"".utf8)) != nil, "Incorrect binary field name")
      try require(data.range(of: fileBytes) != nil, "File must be binary bytes, not a string or base64")
      try require(data.suffix(Data("\r\n--\(boundary)--\r\n".utf8).count) == Data("\r\n--\(boundary)--\r\n".utf8), "Incorrect closing boundary")
      return (200, Data(#"{"success":true,"message":"프로필 수정에 성공했습니다.","data":{"displayName":"권수영","profileImage":"stored.png"}}"#.utf8))
    }
    let profile = try await service.setupProfile(requestDTO: ProfileSetupRequestDTO(displayName: "권수영", profileImage: fileBytes), sessionId: sessionId)
    try require(profile.data.displayName == "권수영" && profile.data.profileImage == "stored.png", "Profile response was not decoded")
    let nullable = try JSONDecoder().decode(ProfileSetupResponseDTO.self, from: Data(#"{"success":true,"message":"ok","data":{"displayName":null,"profileImage":null}}"#.utf8))
    try require(nullable.data.displayName == nil && nullable.data.profileImage == nil, "Nullable Swagger fields must decode")

    MockAuthProtocol.handler = { request in
      try require(body(of: request).range(of: Data("name=\"profile_image\"".utf8)) == nil,
                  "An omitted optional image must not send a fake empty file")
      return (200, Data(#"{"success":true,"message":"ok","data":{"displayName":"권수영","profileImage":null}}"#.utf8))
    }
    _ = try await service.setupProfile(requestDTO: ProfileSetupRequestDTO(displayName: "권수영", profileImage: nil), sessionId: sessionId)

    MockAuthProtocol.handler = { _ in (200, Data(#"{"success":false,"message":"rejected"}"#.utf8)) }
    do {
      _ = try await service.loginWithApple(firebaseIDToken: "test-token", deviceID: deviceId)
      throw CheckFailure(message: "A rejected response must not become a login success")
    } catch AuthServiceError.rejected { }

    MockAuthProtocol.handler = { _ in (401, Data(#"{"message":"expired"}"#.utf8)) }
    do {
      try await service.logout(sessionId: sessionId)
      throw CheckFailure(message: "Expired session should be reported")
    } catch let error as AuthServiceError {
      try require(error.isUnauthorized, "401 must be recognized as an invalid session")
    }
    MockAuthProtocol.handler = { request in
      try require(request.httpMethod == "POST" && request.url?.path == "/api/auth/logout", "Logout route mismatch")
      try require(request.value(forHTTPHeaderField: "x-session-id") == sessionId, "Missing logout session header")
      return (201, Data(#"{"success":true,"message":"ok","data":null}"#.utf8))
    }
    try await service.logout(sessionId: sessionId)
    MockAuthProtocol.handler = { _ in (200, Data("not json".utf8)) }
    do {
      _ = try await service.loginWithApple(firebaseIDToken: "test-token", deviceID: deviceId)
      throw CheckFailure(message: "Malformed responses must not log in")
    } catch AuthServiceError.invalidResponse { }

    let nonce = try AppleAuthHelper.randomNonceString()
    try require(nonce.count == 32 && Set(nonce).isSubset(of: Set("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")), "Invalid nonce")
    try require(AppleAuthHelper.sha256("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "Nonce hash mismatch")

    let pending = SessionManager.StoredSession(sessionId: sessionId, needsProfileSetup: true, profile: nil)
    let restored = try JSONDecoder().decode(SessionManager.StoredSession.self, from: JSONEncoder().encode(pending))
    try require(restored.needsProfileSetup, "Pending setup must survive session serialization")
    let withoutPhoto = SessionManager.StoredSession(sessionId: sessionId, needsProfileSetup: false,
      profile: UserProfile(displayName: "권수영", profileImageFileName: nil))
    let restoredProfile = try JSONDecoder().decode(SessionManager.StoredSession.self, from: JSONEncoder().encode(withoutPhoto))
    try require(!restoredProfile.needsProfileSetup && restoredProfile.profile?.displayName == "권수영" && restoredProfile.profile?.profileImageFileName == nil,
                "Completed setup without a photo must restore correctly")

    let context = CGContext(data: nil, width: 2000, height: 1000, bitsPerComponent: 8, bytesPerRow: 8000,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(CGColor(red: 0.1, green: 0.5, blue: 0.7, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 2000, height: 1000))
    let source = NSMutableData()
    let destination = CGImageDestinationCreateWithData(source, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    try require(CGImageDestinationFinalize(destination), "Image fixture generation failed")
    let normalized = try ProfileImageProcessor.pngData(from: source as Data)
    let normalizedSource = CGImageSourceCreateWithData(normalized as CFData, nil)!
    let normalizedImage = CGImageSourceCreateImageAtIndex(normalizedSource, 0, nil)!
    try require(normalizedImage.width == 1024 && normalizedImage.height == 512, "Profile image size normalization failed")
    let selectedFile = FileManager.default.temporaryDirectory.appendingPathComponent("photo-check-\(UUID()).png")
    try normalized.write(to: selectedFile)
    defer { try? FileManager.default.removeItem(at: selectedFile) }
    let owner = UserProfile(id: UUID(), displayName: "Keep Name", profileImageFileName: "old.png")
    let photoSessions = PhotoMemorySessions(SessionManager.StoredSession(sessionId: sessionId, needsProfileSetup: false,
                                                                        profile: owner, routingVersion: 2))
    let editor = ProfilePhotoViewModel(service: service, sessions: photoSessions)
    editor.selectImage(at: selectedFile)
    MockAuthProtocol.handler = { request in
      let data = body(of: request)
      try require(data.range(of: Data("name=\"displayName\"".utf8)) == nil,
                  "Photo-only changes must not overwrite the display name")
      try require(data.range(of: Data("name=\"profile_image\"".utf8)) != nil,
                  "Photo-only changes must send the binary file field")
      return (200, Data(#"{"success":true,"message":"ok","data":{"displayName":null,"profileImage":"new.png"}}"#.utf8))
    }
    let updatedPhoto = await editor.upload(onSessionExpired: { _ in })
    try require(updatedPhoto?.profile.profileImageFileName == "new.png" && updatedPhoto?.profile.displayName == owner.displayName,
                "Photo update must preserve profile identity and omitted name")
    try require(photoSessions.value?.profile == owner, "Uploading must leave local commit to the guarded app-state update")
    MockAuthProtocol.handler = { _ in (401, Data(#"{"message":"expired"}"#.utf8)) }
    var expiredPhotoSession: String?
    let rejectedPhoto = await editor.upload(onSessionExpired: { expiredPhotoSession = $0 })
    try require(rejectedPhoto == nil && expiredPhotoSession == sessionId, "Upload 401 must report only the request session")
    MockAuthProtocol.handler = { _ in
      Thread.sleep(forTimeInterval: 0.15)
      return (200, Data(#"{"success":true,"message":"ok","data":{"displayName":null,"profileImage":"late.png"}}"#.utf8))
    }
    let latePhoto = Task { await editor.upload(onSessionExpired: { _ in }) }
    try await Task.sleep(for: .milliseconds(30))
    photoSessions.value = SessionManager.StoredSession(sessionId: deviceId, needsProfileSetup: false, profile: nil, routingVersion: 2)
    let lateResult = await latePhoto.value
    try require(lateResult == nil, "A late photo upload must not be applied to a changed account")
    let nameSessions = PhotoMemorySessions(SessionManager.StoredSession(sessionId: sessionId, needsProfileSetup: false,
                                                                       profile: owner, routingVersion: 2))
    let nameEditor = NicknameEditViewModel(currentName: "기존이름", service: service, sessions: nameSessions)
    try require(!nameEditor.canSave, "Unchanged nicknames must not send a request")
    for invalid in ["", "이름 공백", "abcdefghijk", "이름\n"] {
      nameEditor.nickname = invalid
      try require(!nameEditor.canSave, "Invalid nickname accepted")
    }
    nameEditor.nickname = "새이름"
    MockAuthProtocol.handler = { request in
      let data = body(of: request)
      try require(data.range(of: Data("name=\"displayName\"\r\n\r\n새이름\r\n".utf8)) != nil,
                  "Nickname update must send the selected UTF-8 name")
      try require(data.range(of: Data("name=\"profile_image\"".utf8)) == nil,
                  "Nickname-only update must not upload or clear the image")
      return (200, Data(#"{"success":true,"message":"ok","data":{"displayName":"새이름","profileImage":null}}"#.utf8))
    }
    let renamed = await nameEditor.save(onSessionExpired: { _ in })
    try require(renamed?.profile.displayName == "새이름" && renamed?.profile.id == owner.id
                  && renamed?.profile.profileImageFileName == owner.profileImageFileName,
                "Nickname response must retain identity and existing image")
    MockAuthProtocol.handler = { _ in (401, Data(#"{"message":"expired"}"#.utf8)) }
    var expiredNameSession: String?
    let expiredName = await nameEditor.save(onSessionExpired: { expiredNameSession = $0 })
    try require(expiredName == nil && expiredNameSession == sessionId, "Nickname 401 must report only its session")
    MockAuthProtocol.handler = { _ in
      Thread.sleep(forTimeInterval: 0.15)
      return (200, Data(#"{"success":true,"message":"ok","data":{"displayName":"새이름","profileImage":null}}"#.utf8))
    }
    let lateName = Task { await nameEditor.save(onSessionExpired: { _ in }) }
    try await Task.sleep(for: .milliseconds(30))
    let duplicateName = await nameEditor.save(onSessionExpired: { _ in })
    try require(duplicateName == nil, "Saving a nickname must prevent duplicate requests")
    nameSessions.value = nil
    let staleName = await lateName.value
    try require(staleName == nil, "A late nickname response must not be applied after logout")
    let inline = NicknameEditViewModel(currentName: "기존이름", service: service, sessions: nameSessions)
    inline.nickname = "변경이름"
    try require(inline.canSave, "Inline button enables only for a valid changed nickname")
    inline.acceptSavedName("변경이름")
    try require(!inline.canSave, "Accepted nickname must disable inline save without reopening the editor")
    inline.synchronize(currentName: "서버이름")
    try require(inline.nickname == "서버이름" && !inline.canSave, "Untouched inline editor follows refreshed profile")
    inline.nickname = "작성중"
    inline.synchronize(currentName: "다른이름")
    try require(inline.nickname == "작성중" && inline.canSave, "Profile refresh preserves an unsaved draft")
    do {
      _ = try ProfileImageProcessor.pngData(from: Data("not an image".utf8))
      throw CheckFailure(message: "Non-image content must be rejected")
    } catch ProfileImageProcessor.ImageError.invalidImage { }
    print("Auth checks passed: mocked HTTP, multipart bytes, routing flags, session metadata, nonce, and image normalization. No real account requests were made.")
  }
}
