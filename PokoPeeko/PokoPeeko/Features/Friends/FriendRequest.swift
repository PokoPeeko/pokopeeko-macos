import Foundation

struct FriendRequest: Identifiable {
  let id: String
  let user: Friend
}

enum FriendRequestAction: String {
  case accept, reject, cancel
  var method: String { self == .cancel ? "DELETE" : "PATCH" }
}
