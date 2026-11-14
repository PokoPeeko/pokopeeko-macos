import Foundation

struct UserSearchResponseDTO: Decodable {
  let success: Bool
  let message: String
  let data: Payload
  struct Payload: Decodable { let users: [ProfileDataDTO] }
}
