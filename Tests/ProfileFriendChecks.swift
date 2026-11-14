import Foundation

private struct CheckFailure: Error { let message: String }
private nonisolated func check(_ value: Bool, _ message: String) throws {
  if !value { throw CheckFailure(message: message) }
}

private final class MockSessionProtocol: URLProtocol, @unchecked Sendable {
  nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Int, Data, Double))?
  private let lock = NSLock()
  nonisolated(unsafe) private var stopped = false
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    do {
      guard let handler = Self.handler else { throw CheckFailure(message: "Missing mock handler") }
      let (status, data, delay) = try handler(request)
      if delay > 0 {
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [self] in finish(status, data) }
      } else { finish(status, data) }
    } catch { client?.urlProtocol(self, didFailWithError: error) }
  }
  private nonisolated func finish(_ status: Int, _ data: Data) {
    lock.lock(); let cancelled = stopped; lock.unlock()
    guard !cancelled else { return }
    let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                                   headerFields: ["Content-Type": "application/json"])!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: data)
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() { lock.lock(); stopped = true; lock.unlock() }
}

private final class MockServer: @unchecked Sendable {
  private let lock = NSLock()
  nonisolated(unsafe) private var profileStatus = 200
  nonisolated(unsafe) private var profileDelay = 0.0
  nonisolated(unsafe) private var receivedFailure = false
  nonisolated(unsafe) private var pendingReceived = true
  nonisolated(unsafe) private var pendingSent = false
  nonisolated(unsafe) private var accepted = false
  nonisolated(unsafe) private var paths: [String] = []
  nonisolated(unsafe) private var mutationDelay = 0.0
  nonisolated(unsafe) private var deleteStatus = 200
  nonisolated(unsafe) private var searchedKeywords: [String] = []

  nonisolated func configure(profileStatus: Int = 200, profileDelay: Double = 0, receivedFailure: Bool = false,
                             received: Bool = true, sent: Bool = false, friend: Bool = false, mutationDelay: Double = 0, deleteStatus: Int = 200) {
    lock.lock(); defer { lock.unlock() }
    self.profileStatus = profileStatus; self.profileDelay = profileDelay; self.receivedFailure = receivedFailure
    pendingReceived = received; pendingSent = sent; accepted = friend; self.mutationDelay = mutationDelay
    paths = []
    searchedKeywords = []
    self.deleteStatus = deleteStatus
  }
  nonisolated func count(_ path: String) -> Int {
    lock.lock(); defer { lock.unlock() }
    return paths.filter { $0 == path }.count
  }
  nonisolated func lastKeyword() -> String? {
    lock.lock(); defer { lock.unlock() }
    return searchedKeywords.last
  }
  nonisolated func respond(_ request: URLRequest) throws -> (Int, Data, Double) {
    lock.lock(); defer { lock.unlock() }
    let path = request.url!.path
    let method = request.httpMethod ?? "GET"
    paths.append("\(method) \(path)")
    try check(request.value(forHTTPHeaderField: "x-session-id") != nil, "All requests must include session authentication")
    try check(request.httpBody == nil && request.httpBodyStream == nil, "These endpoints must be bodyless")
    try check(request.cachePolicy == .reloadIgnoringLocalCacheData, "Session checks must not use a cached profile response")
    let user = #"{"id":"9f02a61e-2adc-4e23-b0ae-c47a9bd8c788","displayName":"Other User","profileImage":"avatar.png"}"#
    if path == "/api/user/profile" {
      if profileStatus != 200 { return (profileStatus, Data(#"{"message":"profile failure"}"#.utf8), profileDelay) }
      let isNew = request.value(forHTTPHeaderField: "x-session-id") == "550e8400-e29b-41d4-a716-446655440002"
      let id = isNew ? "550e8400-e29b-41d4-a716-446655440012" : "550e8400-e29b-41d4-a716-446655440011"
      return (200, Data("{\"success\":true,\"message\":\"ok\",\"data\":{\"id\":\"\(id)\",\"displayName\":\"Owner\",\"profileImage\":null}}".utf8), profileDelay)
    }
    if path.hasPrefix("/api/user/profile/") {
      if profileStatus != 200 { return (profileStatus, Data(#"{"message":"profile failure"}"#.utf8), profileDelay) }
      return (200, Data("{\"success\":true,\"message\":\"ok\",\"data\":\(user)}".utf8), profileDelay)
    }
    if path == "/api/user/search" {
      try check(method == "GET", "User search uses GET")
      let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
      try check(query.queryItems?.count == 1 && query.queryItems?.first?.name == "keyword", "Exactly one keyword query must be sent")
      let keyword = query.queryItems!.first!.value!
      searchedKeywords.append(keyword)
      if keyword.contains("+") { try check(query.percentEncodedQuery!.contains("%2B"), "Literal plus must not turn into a query space") }
      if profileStatus != 200 { return (profileStatus, Data(#"{"message":"search failed"}"#.utf8), profileDelay) }
      let sameName = user.replacingOccurrences(of: "9f02a61e-2adc-4e23-b0ae-c47a9bd8c788", with: "9f02a61e-2adc-4e23-b0ae-c47a9bd8c789")
      return (200, Data("{\"success\":true,\"message\":\"ok\",\"data\":{\"users\":[\(user),\(sameName)]}}".utf8), profileDelay)
    }
    if path == "/api/friend/search" {
      return (200, Data("{\"success\":true,\"message\":\"ok\",\"data\":{\"friends\":[\(accepted ? user : "")]}}".utf8), 0)
    }
    if path == "/api/friend-request/requests/received" {
      if receivedFailure { return (500, Data(#"{"message":"received failed"}"#.utf8), 0) }
      let row = pendingReceived ? "{\"id\":\"9223372036854775808\",\"requester\":\(user)}" : ""
      return (200, Data("{\"success\":true,\"message\":\"ok\",\"data\":{\"friendRequests\":[\(row)]}}".utf8), 0)
    }
    if path == "/api/friend-request/requests/sent" {
      let row = pendingSent ? "{\"id\":\"9223372036854775809\",\"addressee\":\(user)}" : ""
      return (200, Data("{\"success\":true,\"message\":\"ok\",\"data\":{\"friendRequests\":[\(row)]}}".utf8), 0)
    }
    if method == "DELETE" && path == "/api/friend/9f02a61e-2adc-4e23-b0ae-c47a9bd8c788" {
      if deleteStatus != 200 { return (deleteStatus, Data(#"{"message":"delete failure"}"#.utf8), mutationDelay) }
      accepted = false
      return (200, Data(#"{"success":true,"message":"removed","data":null}"#.utf8), mutationDelay)
    }
    if method == "POST" && path == "/api/friend-request/9f02a61e-2adc-4e23-b0ae-c47a9bd8c788" {
      pendingSent = true
      return (201, Data(#"{"success":true,"message":"sent","data":{"friendRequestId":"9223372036854775809"}}"#.utf8), mutationDelay)
    }
    if path == "/api/friend-request/9223372036854775808/accept" {
      try check(method == "PATCH", "Accept must use PATCH")
      pendingReceived = false; accepted = true
    } else if path == "/api/friend-request/9223372036854775808/reject" {
      try check(method == "PATCH", "Reject must use PATCH")
      pendingReceived = false
    } else if path == "/api/friend-request/9223372036854775809/cancel" {
      try check(method == "DELETE", "Cancel must use DELETE")
      pendingSent = false
    } else { throw CheckFailure(message: "Unexpected mock route") }
    return (200, Data(#"{"success":true,"message":"done","data":null}"#.utf8), mutationDelay)
  }
}

@MainActor
private final class MemorySessions: SessionStoring {
  var value: SessionManager.StoredSession?
  var deletions = 0
  var failDelete = false
  init(_ value: SessionManager.StoredSession?) { self.value = value }
  func load() throws -> SessionManager.StoredSession? { value }
  func save(_ session: SessionManager.StoredSession) throws { value = session }
  func delete(ifMatching id: String) throws -> Bool {
    if failDelete { throw CheckFailure(message: "Simulated storage error") }
    guard value?.sessionId == id else { return false }
    value = nil; deletions += 1; return true
  }
}

@main
struct ProfileFriendChecks {
  @MainActor
  static func main() async throws {
    let id = "550e8400-e29b-41d4-a716-446655440001"
    let newID = "550e8400-e29b-41d4-a716-446655440002"
    let target = UUID(uuidString: "9f02a61e-2adc-4e23-b0ae-c47a9bd8c788")!
    func stored(_ sessionID: String = "550e8400-e29b-41d4-a716-446655440001", pending: Bool = false) -> SessionManager.StoredSession {
      SessionManager.StoredSession(sessionId: sessionID, needsProfileSetup: pending, profile: nil, routingVersion: 2)
    }
    let server = MockServer()
    MockSessionProtocol.handler = { try server.respond($0) }
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockSessionProtocol.self]
    let urlSession = URLSession(configuration: config)
    defer { urlSession.invalidateAndCancel(); MockSessionProtocol.handler = nil }
    let client = SessionAPIClient(session: urlSession, baseURL: URL(string: "https://profile.test.invalid")!)
    let profiles = ProfileService(client: client)
    let service = FriendService(client: client)

    let profileMemory = MemorySessions(stored())
    let friendProfile = FriendProfileViewModel(service: profiles, sessions: profileMemory)
    await friendProfile.load(id: target, onSessionExpired: { _ in })
    try check(friendProfile.profile?.id == target && friendProfile.errorMessage == nil,
              "Friend detail must retrieve the UUID-selected profile")
    server.configure(profileStatus: 500, profileDelay: 0.15)
    let backgroundRefresh = Task { await friendProfile.load(id: target, onSessionExpired: { _ in }) }
    try await Task.sleep(for: .milliseconds(30))
    try check(friendProfile.isLoading && friendProfile.profile?.id == target,
              "Refreshing an existing profile must keep its content visible")
    await backgroundRefresh.value
    try check(friendProfile.profile?.id == target && friendProfile.errorMessage != nil,
              "A transient refresh failure must retain the last profile instead of flashing empty content")
    server.configure(profileStatus: 401)
    var detailExpiredID: String?
    await friendProfile.load(id: target, onSessionExpired: { detailExpiredID = $0 })
    try check(detailExpiredID == id && friendProfile.profile == nil && friendProfile.errorMessage != nil,
              "Unauthorized profile detail must clear previous content and report only its request session")
    server.configure(profileDelay: 0.15)
    let detailTask = Task { await friendProfile.load(id: target, onSessionExpired: { _ in }) }
    try await Task.sleep(for: .milliseconds(30))
    profileMemory.value = stored(newID)
    await detailTask.value
    try check(friendProfile.profile == nil, "A late friend detail response must not cross an account change")
    server.configure()

    let memory = MemorySessions(stored())
    let state = AppState(profileService: profiles, sessions: memory)
    try check(!state.isLoggedIn && state.isRestoringSession, "Cached session must not show the main app before validation")
    await state.restoreSession()
    try check(state.isLoggedIn && state.profile?.id != nil && !state.isRestoringSession, "Valid session must load profile and enter the app")
    try check(memory.value?.profile?.id == state.profile?.id, "Retrieved profile UUID must be persisted")
    let count = server.count("GET /api/user/profile")
    await state.restoreSession()
    try check(server.count("GET /api/user/profile") == count, "Window updates must not repeatedly revalidate")
    server.configure(profileDelay: 0.15)
    let oldProfileRefresh = Task { await state.refreshProfile() }
    try await Task.sleep(for: .milliseconds(30))
    let editedProfile = UserProfile(id: state.profile?.id, displayName: "Updated", profileImageFileName: "updated.png")
    try state.applyProfileUpdate(editedProfile, imageData: Data([1, 2]), ifMatching: id)
    await oldProfileRefresh.value
    try check(state.profile == editedProfile && memory.value?.profile == editedProfile && state.profileImageData == Data([1, 2]),
              "An old refresh must not overwrite a committed photo update")
    let renamedProfile = UserProfile(id: editedProfile.id, displayName: "Renamed", profileImageFileName: editedProfile.profileImageFileName)
    try state.applyProfileUpdate(renamedProfile, imageData: nil, ifMatching: id)
    try check(state.profile?.displayName == "Renamed" && memory.value?.profile == renamedProfile
                && state.profileImageData == Data([1, 2]), "Nickname edits must retain the already displayed photo")
    do {
      try state.applyProfileUpdate(editedProfile, imageData: Data(), ifMatching: newID)
      throw CheckFailure(message: "A mismatched session must not accept profile edits")
    } catch SessionAPIError.rejected { }

    server.configure(profileStatus: 401)
    let expiredMemory = MemorySessions(stored())
    let expired = AppState(profileService: profiles, sessions: expiredMemory)
    await expired.restoreSession()
    try check(!expired.isLoggedIn && expiredMemory.value == nil && expiredMemory.deletions == 1,
              "401 must clear only the expired saved session")
    server.configure(profileStatus: 500)
    let offlineMemory = MemorySessions(stored())
    let offline = AppState(profileService: profiles, sessions: offlineMemory)
    await offline.restoreSession()
    try check(!offline.isLoggedIn && offline.startupError != nil && offlineMemory.value != nil,
              "Transient server failure must not erase the saved session or enter the app")
    let recoveryMemory = MemorySessions(stored())
    var signOutCount = 0
    let recovery = AppState(profileService: profiles, sessions: recoveryMemory, signOutFirebase: { signOutCount += 1 })
    await recovery.restoreSession()
    recovery.restartSignIn()
    try check(recoveryMemory.value == nil && signOutCount == 1 && recovery.startupError == nil
                && !recovery.isLoggedIn && !recovery.isRestoringSession && recovery.currentSessionId == nil,
              "Explicit recovery must clear the old local session and return to sign-in without bypassing authentication")
    recovery.restartSignIn()
    try check(signOutCount == 1, "Recovery must only run on the startup error screen")

    let failedDeleteMemory = MemorySessions(stored())
    failedDeleteMemory.failDelete = true
    let failedDelete = AppState(profileService: profiles, sessions: failedDeleteMemory)
    await failedDelete.restoreSession()
    failedDelete.restartSignIn()
    try check(failedDeleteMemory.value != nil && failedDelete.startupError != nil && !failedDelete.isLoggedIn,
              "Storage cleanup failure must retain the error screen")

    let replacementMemory = MemorySessions(stored())
    var replacementSignOuts = 0
    let replacement = AppState(profileService: profiles, sessions: replacementMemory,
                               signOutFirebase: { replacementSignOuts += 1 })
    await replacement.restoreSession()
    replacementMemory.value = stored(newID)
    replacement.restartSignIn()
    try check(replacementMemory.value?.sessionId == newID && replacementSignOuts == 0 && replacement.startupError != nil,
              "Recovery must not clear a replacement session")

    server.configure()
    await offline.restoreSession(force: true)
    try check(offline.isLoggedIn, "Retry should recover a transient profile failure")
    let pendingState = AppState(profileService: profiles, sessions: MemorySessions(stored(pending: true)))
    await pendingState.restoreSession()
    try check(!pendingState.isLoggedIn && !pendingState.isRestoringSession, "Validated but incomplete setup must remain in onboarding")

    server.configure(profileDelay: 0.15)
    let switchingMemory = MemorySessions(stored())
    let switching = AppState(profileService: profiles, sessions: switchingMemory)
    let oldLoad = Task { await switching.restoreSession() }
    for _ in 0..<100 where server.count("GET /api/user/profile") == 0 { try await Task.sleep(nanoseconds: 2_000_000) }
    switchingMemory.value = stored(newID)
    server.configure()
    switching.completeAuthentication(profile: nil, imageData: nil)
    await oldLoad.value
    for _ in 0..<100 where switching.profile?.id?.uuidString.lowercased() != "550e8400-e29b-41d4-a716-446655440012" {
      try await Task.sleep(nanoseconds: 2_000_000)
    }
    try check(switchingMemory.value?.sessionId == newID && switching.profile?.id?.uuidString.lowercased() == "550e8400-e29b-41d4-a716-446655440012",
              "An old account response must not overwrite a newer session/profile")

    server.configure()
    let friendMemory = MemorySessions(stored())
    var expiredIDs: [String] = []
    let model = FriendsViewModel(service: service, sessions: friendMemory,
                                onSessionExpired: { expiredIDs.append($0) })
    await model.refresh()
    try check(model.received.first?.id == "9223372036854775808", "Request IDs must survive beyond Int64 without conversion")
    let incoming = model.received[0]
    await model.act(on: incoming, action: .accept)
    try check(model.received.isEmpty && model.friends.first?.id == target && model.friends.first?.isOnline == nil,
              "Accept must remove the pending request and refresh friends without fabricating online state")

    var retainedIDs: Set<UUID> = [target]
    model.onFriendsLoaded = { retainedIDs = $0 }
    let removed = await model.removeFriend(id: target)
    try check(removed && model.friends.isEmpty && retainedIDs.isEmpty,
              "Delete must clear friend list and remote presence IDs immediately")
    try check(server.count("DELETE /api/friend/9f02a61e-2adc-4e23-b0ae-c47a9bd8c788") == 1,
              "Delete uses target UUID, with no request body")
    server.configure(friend: true, mutationDelay: 0.1)
    await model.refresh()
    let firstRemoval = Task { await model.removeFriend(id: target) }
    try await Task.sleep(for: .milliseconds(20))
    let duplicateRemoval = await model.removeFriend(id: target)
    _ = await firstRemoval.value
    try check(!duplicateRemoval && server.count("DELETE /api/friend/9f02a61e-2adc-4e23-b0ae-c47a9bd8c788") == 1,
              "Repeated delete clicks must not duplicate mutations")
    server.configure(friend: true, deleteStatus: 500)
    await model.refresh()
    let failedRemoval = await model.removeFriend(id: target)
    try check(!failedRemoval && model.friends.contains(where: { $0.id == target }) && model.actionError != nil,
              "Server failure must preserve the friend and expose a retryable error")
    server.configure(friend: true, mutationDelay: 0.1)
    await model.refresh()
    let previousRemoval = Task { await model.removeFriend(id: target) }
    try await Task.sleep(for: .milliseconds(20))
    friendMemory.value = stored(newID)
    // The new account has its own accepted relationship, independent of the old request.
    server.configure(friend: true)
    model.reset()
    await model.refresh()
    _ = await previousRemoval.value
    try check(model.friends.contains(where: { $0.id == target }), "Late deletion must not remove a new account's friend list")
    friendMemory.value = stored()
    model.reset()
    server.configure(received: false)
    model.reset()
    await model.refresh()
    model.searchQuery = "Other User"
    await model.searchUsers()
    try check(model.searchResults.first?.id == target && model.canSendRequest(to: target), "Name search must identify the selected UUID before sending")
    try check(model.searchResults.count == 2 && model.searchResults[0].displayName == model.searchResults[1].displayName
                && model.searchResults[0].id != model.searchResults[1].id, "Duplicate names must remain separate UUID-selected users")
    await model.sendRequest(to: UUID())
    try check(server.count("POST /api/friend-request/9f02a61e-2adc-4e23-b0ae-c47a9bd8c788") == 0,
              "A confirmation for a different recipient must not send")
    await model.sendRequest(to: target)
    try check(model.sent.count == 1 && model.notice != nil, "Sending must refresh outgoing requests")
    await model.act(on: model.sent[0], action: .cancel)
    try check(model.sent.isEmpty, "Cancel must remove the outgoing request")

    server.configure(mutationDelay: 0.1)
    model.reset()
    await model.refresh()
    let toReject = model.received[0]
    let firstReject = Task { await model.act(on: toReject, action: .reject) }
    for _ in 0..<100 where server.count("PATCH /api/friend-request/9223372036854775808/reject") == 0 { try await Task.sleep(nanoseconds: 2_000_000) }
    await model.act(on: toReject, action: .reject)
    await firstReject.value
    try check(server.count("PATCH /api/friend-request/9223372036854775808/reject") == 1 && model.received.isEmpty,
              "Repeated taps must not duplicate a request mutation")

    server.configure(receivedFailure: true, sent: true)
    model.reset()
    await model.refresh()
    try check(model.receivedError != nil && model.sentLoaded && model.sent.count == 1,
              "A failed incoming list must not discard a successful outgoing list")

    server.configure(profileDelay: 0.1)
    model.searchQuery = "Other User"
    let lookup = Task { await model.searchUsers() }
    try await Task.sleep(nanoseconds: 10_000_000)
    model.searchQuery = "different input"
    await lookup.value
    try check(model.searchResults.isEmpty, "A stale recipient lookup must not display the previous user's profile")

    server.configure(profileStatus: 401)
    model.searchQuery = "Other User"
    await model.searchUsers()
    try check(expiredIDs == [id] && model.friends.isEmpty && model.received.isEmpty && model.sent.isEmpty,
              "Expired requests must clear feature data and identify the affected session")
    server.configure()
    let users = try await service.searchUsers(keyword: "  수영 & + #  ", sessionId: id)
    try check(users.count == 2 && server.lastKeyword() == "수영 & + #", "Search must trim and safely encode one Unicode keyword")
    let searches = server.count("GET /api/user/search")
    do {
      _ = try await service.searchUsers(keyword: "   ", sessionId: id)
      throw CheckFailure(message: "Empty searches must not enumerate all users")
    } catch SessionAPIError.invalidRequest { }
    try check(server.count("GET /api/user/search") == searches, "Empty input must not make a network request")
    try check(APIConfig.profileImageURL(fileName: "avatar.png")?.path == "/static/profile/avatar.png", "Static profile path mismatch")
    try check(APIConfig.profileImageURL(fileName: "../private.png") == nil, "File names must not traverse the static path")
    do {
      _ = try await service.act(on: "../../other", action: .cancel, sessionId: id)
      throw CheckFailure(message: "Invalid request IDs must not be sent")
    } catch SessionAPIError.invalidRequest { }
    print("Profile/friend checks passed: session restoration, error policy, stale-response protection, name search, duplicate-name UUID identity, request actions, BigInt IDs, and static image URLs. No real users were contacted.")
  }
}
