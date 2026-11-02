//

import Foundation
import FirebaseAuth

final class AuthService {

  func loginWithApple (
    firebaseIDToken: String,
    deviceID: String
  ) async throws -> AppleLoginResponseDTO {

    let url = URL(string: "\(APIConfig.baseURL)/api/auth/login/apple")!

    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(firebaseIDToken)", forHTTPHeaderField: "Authorization")
    request.setValue(deviceID, forHTTPHeaderField: "x-device-id")

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw URLError(.badServerResponse)
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      print("Status:", httpResponse.statusCode)
      print("Body:", String(data: data, encoding: .utf8) ?? "없음")

      throw URLError(.badServerResponse)
    }

    return try JSONDecoder().decode(
      AppleLoginResponseDTO.self,
      from: data
    )
  }

  func logout(sessionId: String) async throws {
    let url = URL(string: "\(APIConfig.baseURL)/api/auth/logout")!

    var request = URLRequest(url: url)
    request.httpMethod = "POST"


    request.setValue(
      sessionId,
      forHTTPHeaderField: "x-session-id"
    )

    let (_, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw URLError(.badServerResponse)
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw URLError(.badServerResponse)
    }
  }

  func setupProfile(
    requestDTO: ProfileSetupRequestDTO,
    sessionId: String
  ) async throws {

  }
}
