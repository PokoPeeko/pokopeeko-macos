import SwiftUI

struct FriendPresenceList: View {
  let friends: [Friend]
  var onOpenProfile: ((Friend) -> Void)? = nil

  var body: some View {
    LazyVStack(spacing: 0) {
      ForEach(friends) { friend in
        FriendPresenceRow(friend: friend, onOpenProfile: onOpenProfile)
        if friend.id != friends.last?.id { Divider().padding(.leading, 54) }
      }
    }
  }
}
