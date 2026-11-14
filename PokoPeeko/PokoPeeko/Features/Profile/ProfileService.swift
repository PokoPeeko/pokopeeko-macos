import Foundation

final class ProfileService {
  private let client: SessionAPIClient
  init(client: SessionAPIClient? = nil) { self.client = client ?? SessionAPIClient() }

  func myProfile(sessionId: String) async throws -> UserProfile {
    let response: ProfileResponseDTO = try await client.send(path: "api/user/profile", sessionId: sessionId)
    return response.data.profile
  }

  func userProfile(id: UUID, sessionId: String) async throws -> UserProfile {
    let response: ProfileResponseDTO = try await client.send(path: "api/user/profile/\(id.uuidString.lowercased())", sessionId: sessionId)
    guard response.data.id == id else { throw SessionAPIError.invalidResponse }
    return response.data.profile
  }
}
