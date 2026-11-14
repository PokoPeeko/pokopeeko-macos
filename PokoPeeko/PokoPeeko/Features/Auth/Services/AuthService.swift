import Foundation

final class AuthService {
  private let session: URLSession
  private let baseURL: URL?

  init(session: URLSession = .shared, baseURL: URL? = nil) {
    self.session = session
    self.baseURL = baseURL ?? URL(string: APIConfig.baseURL)
  }

  func loginWithApple(firebaseIDToken: String, deviceID: String) async throws -> AppleLoginResponseDTO {
    guard !firebaseIDToken.isEmpty, UUID(uuidString: deviceID) != nil else {
      throw AuthServiceError.invalidRequest
    }
    var request = try makeRequest(path: "api/auth/login/apple", method: "POST")
    request.setValue("Bearer \(firebaseIDToken)", forHTTPHeaderField: "Authorization")
    request.setValue(deviceID, forHTTPHeaderField: "x-device-id")
    let response: AppleLoginResponseDTO = try await send(request)
    guard UUID(uuidString: response.data.sessionId) != nil else { throw AuthServiceError.invalidResponse }
    return response
  }

  func setupProfile(requestDTO: ProfileSetupRequestDTO, sessionId: String) async throws -> ProfileSetupResponseDTO {
    guard !sessionId.isEmpty, requestDTO.profileImage?.isEmpty != true else { throw AuthServiceError.invalidRequest }
    var request = try makeRequest(path: "api/user/profile", method: "PATCH")
    let boundary = "PokoPeeko-\(UUID().uuidString)"
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    request.setValue(sessionId, forHTTPHeaderField: "x-session-id")
    request.httpBody = requestDTO.multipartBody(boundary: boundary)
    return try await send(request)
  }

  func logout(sessionId: String) async throws {
    var request = try makeRequest(path: "api/auth/logout", method: "POST")
    request.setValue(sessionId, forHTTPHeaderField: "x-session-id")
    let _: LogoutResponseDTO = try await send(request)
  }

  private func makeRequest(path: String, method: String) throws -> URLRequest {
    guard let baseURL, ["http", "https"].contains(baseURL.scheme ?? ""), baseURL.host != nil else {
      throw AuthServiceError.invalidConfiguration
    }
    var request = URLRequest(url: baseURL.appendingPathComponent(path))
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.timeoutInterval = 30
    return request
  }

  private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
    let (data, response) = try await session.data(for: request)
    try Task.checkCancellation()
    guard let http = response as? HTTPURLResponse else { throw AuthServiceError.invalidResponse }
    guard (200...299).contains(http.statusCode) else {
      let message = (try? JSONDecoder().decode(ErrorResponseDTO.self, from: data))?.message
      throw AuthServiceError.http(status: http.statusCode, message: message)
    }
    do {
      let result = try JSONDecoder().decode(ResultStatus.self, from: data)
      guard result.success else { throw AuthServiceError.rejected(result.message) }
      return try JSONDecoder().decode(Response.self, from: data)
    } catch let error as AuthServiceError {
      throw error
    } catch {
      throw AuthServiceError.invalidResponse
    }
  }

  private struct ResultStatus: Decodable {
    let success: Bool
    let message: String
  }
}

enum AuthServiceError: LocalizedError {
  case invalidConfiguration
  case invalidRequest
  case invalidResponse
  case sessionChanged
  case rejected(String)
  case http(status: Int, message: String?)

  var isUnauthorized: Bool {
    if case .http(status: 401, message: _) = self { return true }
    return false
  }

  var errorDescription: String? {
    switch self {
    case .invalidConfiguration: "서버 주소 설정을 확인해주세요."
    case .invalidRequest: "인증 요청 정보를 확인해주세요."
    case .invalidResponse: "서버 응답을 확인할 수 없어요. 다시 시도해주세요."
    case .sessionChanged: "로그인 상태가 변경되었어요. 창을 다시 열어 현재 상태를 확인해주세요."
    case .rejected(let message): message
    case .http(let status, let message):
      status == 401 ? "인증이 만료되었거나 유효하지 않아요. 다시 로그인해주세요."
        : "\(message ?? "요청에 실패했어요. 잠시 후 다시 시도해주세요.") (HTTP \(status))"
    }
  }
}
