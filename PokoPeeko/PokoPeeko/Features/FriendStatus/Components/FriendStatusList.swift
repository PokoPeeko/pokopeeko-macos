import SwiftUI

struct FriendStatusList: View {
  let friends: [Friend]

  var body: some View {
    LazyVStack(spacing: 0) {
      ForEach(friends) { friend in
        FriendStatusRow(friend: friend)
        if friend.id != friends.last?.id { Divider().padding(.leading, 54) }
      }
    }
  }
}
