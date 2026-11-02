import SwiftUI

struct FriendsView: View {
  @Environment(MainViewModel.self) private var model
  @State private var search = ""
  @State private var onlineOnly = false

  private var friends: [Friend] {
    model.friends.filter {
      (!onlineOnly || $0.isOnline) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))
    }
  }

  var body: some View {
    ActivityCard {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Text("친구 \(model.friends.count)명").font(.headline)
          Spacer()
          Toggle("온라인만", isOn: $onlineOnly).toggleStyle(.switch).controlSize(.small)
        }
        TextField("친구 이름 검색", text: $search).textFieldStyle(.roundedBorder)
          .accessibilityLabel("친구 이름 검색")
        if model.friends.isEmpty {
          ContentUnavailableView("아직 연결된 친구가 없어요", systemImage: "person.2",
                                 description: Text("친구 추가와 삭제는 서버 연동 후 사용할 수 있어요."))
        } else if friends.isEmpty {
          ContentUnavailableView("조건에 맞는 친구가 없어요", systemImage: "magnifyingglass",
                                 description: Text("검색어나 온라인 필터를 바꿔보세요."))
        } else {
          FriendStatusList(friends: friends)
        }
        Divider()
        Label("친구 추가·삭제 기능은 준비 중이에요.", systemImage: "person.badge.plus")
          .font(.callout).foregroundStyle(.secondary)
      }
    }
  }
}
