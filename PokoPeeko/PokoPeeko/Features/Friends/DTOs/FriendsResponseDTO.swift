import Foundation

struct FriendsResponseDTO: Decodable {
  let success: Bool
  let message: String
  let data: Payload
  struct Payload: Decodable { let friends: [FriendProfileDTO] }
}
