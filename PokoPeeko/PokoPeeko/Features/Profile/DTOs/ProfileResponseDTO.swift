import Foundation

struct ProfileResponseDTO: Decodable {
  let success: Bool
  let message: String
  let data: ProfileDataDTO
}

struct ProfileDataDTO: Decodable {
  let id: UUID
  let displayName: String?
  let profileImage: String?

  var profile: UserProfile {
    UserProfile(id: id, displayName: displayName, profileImageFileName: profileImage)
  }
}
