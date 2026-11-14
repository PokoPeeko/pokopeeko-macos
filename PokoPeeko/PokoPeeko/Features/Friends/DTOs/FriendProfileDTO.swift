import Foundation

struct FriendProfileDTO: Decodable {
  let id: UUID
  let displayName: String?
  let profileImage: String?

  var friend: Friend {
    Friend(id: id, name: displayName.flatMap { $0.isEmpty ? nil : $0 } ?? "닉네임 없음",
           profileImageURL: APIConfig.profileImageURL(fileName: profileImage),
           profileImageFileName: profileImage, currentAppName: nil)
  }
}
