import Foundation

struct UserProfile: Codable, Equatable, Identifiable {
  var id: UUID? = nil
  let displayName: String?
  let profileImageFileName: String?

  var profileImageURL: URL? { APIConfig.profileImageURL(fileName: profileImageFileName) }
  var displayLabel: String { displayName.flatMap { $0.isEmpty ? nil : $0 } ?? "닉네임 없음" }
}
