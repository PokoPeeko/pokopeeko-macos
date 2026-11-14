import Foundation
import Observation

@MainActor
@Observable
final class FriendsViewModel {
  @ObservationIgnored var onFriendsLoaded: ((Set<UUID>) -> Void)?
  private(set) var friends: [Friend] = []
  private(set) var received: [FriendRequest] = []
  private(set) var sent: [FriendRequest] = []
  private(set) var searchResults: [UserProfile] = []
  private(set) var hasSearched = false
  private(set) var isRefreshing = false
  private(set) var isMutating = false
  private(set) var isLookingUp = false
  private(set) var receivedLoaded = false
  private(set) var sentLoaded = false
  private(set) var friendsLoaded = false
  private(set) var receivedError: String?
  private(set) var sentError: String?
  private(set) var friendsError: String?
  private(set) var actionError: String?
  private(set) var notice: String?

  var searchQuery = "" {
    didSet {
      searchResults = []
      hasSearched = false
      lookupToken = UUID()
      isLookingUp = false
      actionError = nil
      notice = nil
    }
  }
  var canSearch: Bool { !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isMutating && !isLookingUp }

  func requestStatus(for id: UUID) -> String? {
    if friends.contains(where: { $0.id == id }) { return "친구" }
    if sent.contains(where: { $0.user.id == id }) { return "요청 보냄" }
    if received.contains(where: { $0.user.id == id }) { return "받은 요청 있음" }
    return nil
  }

  func canSendRequest(to id: UUID) -> Bool {
    searchResults.contains(where: { $0.id == id }) && !isMutating && !isLookingUp && requestStatus(for: id) == nil
  }

  private let service: FriendService
  private let sessions: any SessionStoring
  private let onSessionExpired: (String) -> Void
  private var sessionId: String?
  private var sessionGeneration = UUID()
  private var refreshToken = UUID()
  private var lookupToken = UUID()

  init(service: FriendService? = nil,
       sessions: (any SessionStoring)? = nil, onSessionExpired: @escaping (String) -> Void = { _ in }) {
    self.service = service ?? FriendService()
    self.sessions = sessions ?? KeychainSessionStore()
    self.onSessionExpired = onSessionExpired
  }

  func reset() {
    sessionGeneration = UUID()
    refreshToken = UUID()
    lookupToken = UUID()
    sessionId = nil
    friends = []; received = []; sent = []
    searchQuery = ""
    isRefreshing = false; isMutating = false; isLookingUp = false
    receivedLoaded = false; sentLoaded = false; friendsLoaded = false
    receivedError = nil; sentError = nil; friendsError = nil
    actionError = nil; notice = nil
  }

  func refresh() async {
    guard let context = captureSession(), !isRefreshing else { return }
    let token = UUID()
    refreshToken = token
    isRefreshing = true
    defer { if refreshToken == token { isRefreshing = false } }
    async let incoming: Void = loadReceived(context, token: token)
    async let outgoing: Void = loadSent(context, token: token)
    async let accepted: Void = loadFriends(context, token: token)
    _ = await (incoming, outgoing, accepted)
  }

  func searchUsers() async {
    guard canSearch, let context = captureSession(), canSearch else { return }
    let keyword = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    let token = UUID()
    lookupToken = token
    isLookingUp = true
    actionError = nil
    notice = nil
    defer { if lookupToken == token { isLookingUp = false } }
    do {
      let users = try await service.searchUsers(keyword: keyword, sessionId: context.id)
      guard isCurrent(context), lookupToken == token,
            searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == keyword else { return }
      let ownID = try sessions.load()?.profile?.id
      searchResults = users.filter { $0.id != ownID }
      hasSearched = true
    } catch {
      guard isCurrent(context), lookupToken == token else { return }
      report(error, context: context)
    }
  }

  func sendRequest(to id: UUID) async {
    guard let context = captureSession(), canSendRequest(to: id),
          let user = searchResults.first(where: { $0.id == id }) else { return }
    beginMutation()
    defer { if isCurrent(context) { isMutating = false } }
    do {
      let result = try await service.sendRequest(to: id, sessionId: context.id)
      guard isCurrent(context) else { return }
      sent.append(FriendRequest(id: result.requestID, user: Friend(id: id, name: user.displayLabel,
        profileImageURL: user.profileImageURL, profileImageFileName: user.profileImageFileName)))
      notice = result.message
      await refreshAfterMutation()
    } catch {
      guard isCurrent(context) else { return }
      report(error, context: context)
    }
  }

  func act(on request: FriendRequest, action: FriendRequestAction) async {
    guard !isMutating, let context = captureSession() else { return }
    let list = action == .cancel ? sent : received
    guard list.contains(where: { $0.id == request.id }) else { return }
    beginMutation()
    defer { if isCurrent(context) { isMutating = false } }
    do {
      let message = try await service.act(on: request.id, action: action, sessionId: context.id)
      guard isCurrent(context) else { return }
      if action == .cancel { sent.removeAll { $0.id == request.id } }
      else { received.removeAll { $0.id == request.id } }
      notice = message
      await refreshAfterMutation()
    } catch {
      guard isCurrent(context) else { return }
      report(error, context: context)
      // 다른 기기에서 처리되었을 수 있으므로 목록만 새로 읽고 동작을 자동 재전송하지 않는다.
      if !((error as? SessionAPIError)?.isUnauthorized ?? false) { await refreshAfterMutation() }
    }
  }

  @discardableResult
  func removeFriend(id: UUID) async -> Bool {
    guard !isMutating, let context = captureSession(), friends.contains(where: { $0.id == id }) else { return false }
    beginMutation()
    defer { if isCurrent(context) { isMutating = false } }
    do {
      let message = try await service.removeFriend(id: id, sessionId: context.id)
      guard isCurrent(context) else { return false }
      friends.removeAll { $0.id == id }
      onFriendsLoaded?(Set(friends.map(\.id)))
      notice = message
      await refreshAfterMutation()
      return true
    } catch {
      guard isCurrent(context) else { return false }
      report(error, context: context)
      return false
    }
  }

  private func refreshAfterMutation() async {
    refreshToken = UUID()
    isRefreshing = false
    await refresh()
  }

  private func beginMutation() {
    refreshToken = UUID() // 이전 목록 응답이 처리된 요청을 다시 표시하지 못하게 한다.
    isRefreshing = false
    isMutating = true
    actionError = nil
    notice = nil
  }

  private func loadReceived(_ context: Context, token: UUID) async {
    do {
      let result = try await service.receivedRequests(sessionId: context.id)
      guard isCurrent(context), refreshToken == token else { return }
      received = result; receivedLoaded = true; receivedError = nil
    } catch {
      guard isCurrent(context), refreshToken == token else { return }
      if handleUnauthorized(error, context: context) { return }
      if !isCancellation(error) { receivedError = error.localizedDescription }
    }
  }

  private func loadSent(_ context: Context, token: UUID) async {
    do {
      let result = try await service.sentRequests(sessionId: context.id)
      guard isCurrent(context), refreshToken == token else { return }
      sent = result; sentLoaded = true; sentError = nil
    } catch {
      guard isCurrent(context), refreshToken == token else { return }
      if handleUnauthorized(error, context: context) { return }
      if !isCancellation(error) { sentError = error.localizedDescription }
    }
  }

  private func loadFriends(_ context: Context, token: UUID) async {
    do {
      let result = try await service.friends(sessionId: context.id)
      guard isCurrent(context), refreshToken == token else { return }
      let previous = Dictionary(friends.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
      friends = result.map { item in
        var friend = previous[item.id] ?? item
        friend.name = item.name
        friend.profileImageFileName = item.profileImageFileName
        friend.profileImageURL = item.profileImageURL
        return friend
      }
      friendsLoaded = true; friendsError = nil
      onFriendsLoaded?(Set(friends.map(\.id)))
    } catch {
      guard isCurrent(context), refreshToken == token else { return }
      if handleUnauthorized(error, context: context) { return }
      if !isCancellation(error) { friendsError = error.localizedDescription }
    }
  }

  private struct Context { let id: String; let generation: UUID }
  private func captureSession() -> Context? {
    do {
      guard let saved = try sessions.load(), !saved.needsProfileSetup else {
        reset()
        actionError = "로그인과 프로필 설정을 완료해주세요."
        return nil
      }
      if sessionId != saved.sessionId {
        // 최초 진입의 입력은 유지하고, 다른 세션으로 바뀔 때 데이터를 초기화한다.
        if sessionId != nil { reset() }
        sessionId = saved.sessionId
      }
      return Context(id: saved.sessionId, generation: sessionGeneration)
    } catch {
      actionError = error.localizedDescription
      return nil
    }
  }

  private func isCurrent(_ context: Context) -> Bool {
    sessionId == context.id && sessionGeneration == context.generation
      && (try? sessions.load())?.sessionId == context.id
  }

  private func handleUnauthorized(_ error: Error, context: Context) -> Bool {
    guard (error as? SessionAPIError)?.isUnauthorized == true else { return false }
    reset()
    onSessionExpired(context.id)
    return true
  }

  private func report(_ error: Error, context: Context) {
    if handleUnauthorized(error, context: context) || isCancellation(error) { return }
    actionError = error.localizedDescription
  }

  private func isCancellation(_ error: Error) -> Bool {
    error is CancellationError || (error as? URLError)?.code == .cancelled
  }
}
