import Foundation

struct ProfileSetupResponseDTO: Decodable {
  let success: Bool
  let message: String
  let data: Data

  struct Data: Decodable {
    // Swagger에서 nullable로 정의되어 있다.
    let displayName: String?
    let profileImage: String?
  }
}
