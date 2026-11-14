import Foundation

/// 세션 헤더로 인증하는 프로필·친구 API의 공통 전송 처리.
final class SessionAPIClient {
  private let session: URLSession
  private let baseURL: URL?

  init(session: URLSession = .shared, baseURL: URL? = nil) {
    self.session = session
    self.baseURL = baseURL ?? URL(string: APIConfig.baseURL)
  }

  func send<Response: Decodable>(path: String, method: String = "GET", sessionId: String, queryItems: [URLQueryItem] = []) async throws -> Response {
    guard UUID(uuidString: sessionId) != nil else { throw SessionAPIError.invalidRequest }
    guard let baseURL, ["http", "https"].contains(baseURL.scheme ?? ""), baseURL.host != nil else {
      throw SessionAPIError.invalidConfiguration
    }
    guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
      throw SessionAPIError.invalidConfiguration
    }
    if !queryItems.isEmpty {
      components.queryItems = queryItems
      components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
    }
    guard let url = components.url else { throw SessionAPIError.invalidConfiguration }
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
    request.httpMethod = method
    request.setValue(sessionId, forHTTPHeaderField: "x-session-id")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.timeoutInterval = 30
    let (data, response) = try await session.data(for: request)
    try Task.checkCancellation()
    guard let http = response as? HTTPURLResponse else { throw SessionAPIError.invalidResponse }
    guard (200...299).contains(http.statusCode) else {
      throw SessionAPIError.http(http.statusCode, (try? JSONDecoder().decode(ErrorResponseDTO.self, from: data))?.message)
    }
    do {
      let status = try JSONDecoder().decode(APIStatus.self, from: data)
      guard status.success else { throw SessionAPIError.rejected(status.message) }
      return try JSONDecoder().decode(Response.self, from: data)
    } catch let error as SessionAPIError {
      throw error
    } catch {
      throw SessionAPIError.invalidResponse
    }
  }

  private struct APIStatus: Decodable {
    let success: Bool
    let message: String
  }
}

enum SessionAPIError: LocalizedError {
  case invalidConfiguration, invalidRequest, invalidResponse
  case http(Int, String?)
  case rejected(String)

  var isUnauthorized: Bool { if case .http(401, _) = self { true } else { false } }
  var isNotFound: Bool { if case .http(404, _) = self { true } else { false } }
  var errorDescription: String? {
    switch self {
    case .invalidConfiguration: "서버 주소 설정을 확인해주세요."
    case .invalidRequest: "요청 정보를 확인해주세요."
    case .invalidResponse: "서버 응답을 확인할 수 없어요. 새로고침 후 다시 확인해주세요."
    case .http(401, _): "세션이 만료되었거나 유효하지 않아요. 다시 로그인해주세요."
    case .http(let code, let message): message ?? "요청에 실패했어요. 잠시 후 다시 시도해주세요. (\(code))"
    case .rejected(let message): message
    }
  }
}
