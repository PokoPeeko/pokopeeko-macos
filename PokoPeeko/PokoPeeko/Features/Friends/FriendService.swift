import Foundation

final class FriendService {
  private let client: SessionAPIClient
  init(client: SessionAPIClient? = nil) { self.client = client ?? SessionAPIClient() }

  func friends(sessionId: String) async throws -> [Friend] {
    let response: FriendsResponseDTO = try await client.send(path: "api/friend/search", sessionId: sessionId)
    return response.data.friends.map(\.friend)
  }

  func searchUsers(keyword: String, sessionId: String) async throws -> [UserProfile] {
    let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !keyword.isEmpty else { throw SessionAPIError.invalidRequest }
    let response: UserSearchResponseDTO = try await client.send(path: "api/user/search", sessionId: sessionId,
      queryItems: [URLQueryItem(name: "keyword", value: keyword)])
    guard Set(response.data.users.map(\.id)).count == response.data.users.count else { throw SessionAPIError.invalidResponse }
    return response.data.users.map(\.profile)
  }

  func removeFriend(id: UUID, sessionId: String) async throws -> String {
    let response: FriendActionResponseDTO = try await client.send(path: "api/friend/\(id.uuidString.lowercased())", method: "DELETE", sessionId: sessionId)
    return response.message
  }

  func receivedRequests(sessionId: String) async throws -> [FriendRequest] {
    let response: ReceivedFriendRequestsResponseDTO = try await client.send(path: "api/friend-request/requests/received", sessionId: sessionId)
    guard response.data.friendRequests.allSatisfy({ Self.isValidRequestID($0.id) }) else { throw SessionAPIError.invalidResponse }
    return response.data.friendRequests.map { FriendRequest(id: $0.id, user: $0.requester.friend) }
  }

  func sentRequests(sessionId: String) async throws -> [FriendRequest] {
    let response: SentFriendRequestsResponseDTO = try await client.send(path: "api/friend-request/requests/sent", sessionId: sessionId)
    guard response.data.friendRequests.allSatisfy({ Self.isValidRequestID($0.id) }) else { throw SessionAPIError.invalidResponse }
    return response.data.friendRequests.map { FriendRequest(id: $0.id, user: $0.addressee.friend) }
  }

  func sendRequest(to id: UUID, sessionId: String) async throws -> (message: String, requestID: String) {
    let response: SendFriendRequestResponseDTO = try await client.send(path: "api/friend-request/\(id.uuidString.lowercased())", method: "POST", sessionId: sessionId)
    guard Self.isValidRequestID(response.data.friendRequestId) else { throw SessionAPIError.invalidResponse }
    return (response.message, response.data.friendRequestId)
  }

  func act(on requestId: String, action: FriendRequestAction, sessionId: String) async throws -> String {
    guard Self.isValidRequestID(requestId) else { throw SessionAPIError.invalidRequest }
    let response: FriendActionResponseDTO = try await client.send(path: "api/friend-request/\(requestId)/\(action.rawValue)", method: action.method, sessionId: sessionId)
    return response.message
  }

  private static func isValidRequestID(_ id: String) -> Bool {
    !id.isEmpty && id.utf8.allSatisfy { (48...57).contains($0) }
  }
}
