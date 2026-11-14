import SwiftUI

enum FriendsTab: String, CaseIterable, Identifiable {
  case list = "친구 목록"
  case add = "친구 추가"
  case requests = "친구 요청"
  var id: Self { self }
}

struct FriendsView: View {
  @Environment(MainViewModel.self) private var model
  @State private var search = ""
  @State private var onlineOnly = false
  @State private var outgoingRequests = false
  @State private var sendConfirmation = false
  @State private var recipientToConfirm: UserProfile?
  @State private var pendingAction: RequestConfirmation?

  private var requests: FriendsViewModel { model.friendsModel }
  private var friends: [Friend] {
    model.friends.filter {
      (!onlineOnly || $0.isOnline == true) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))
    }
  }

  var body: some View {
    @Bindable var model = model
    ActivityCard {
      VStack(alignment: .leading, spacing: 18) {
        HStack {
          Picker("친구 관리", selection: $model.friendsTab) {
            ForEach(FriendsTab.allCases) { tab in Text(tab.rawValue).tag(tab) }
          }
          .pickerStyle(.segmented).labelsHidden()
          Button { Task { await requests.refresh() } } label: {
            Image(systemName: "arrow.clockwise")
          }
          .disabled(requests.isRefreshing || requests.isMutating)
          .help("친구 및 요청 새로고침").accessibilityLabel("친구 및 요청 새로고침")
        }
        if requests.isRefreshing { ProgressView("목록을 불러오고 있어요").controlSize(.small) }
        if let error = requests.actionError { Text(error).font(.callout).foregroundStyle(.red) }
        if let notice = requests.notice { Label(notice, systemImage: "checkmark.circle").font(.callout).foregroundStyle(.green) }
        switch model.friendsTab {
        case .list: friendList
        case .add: addFriend
        case .requests: requestList
        }
      }
    }
    .alert("친구 요청을 보낼까요?", isPresented: $sendConfirmation) {
      Button("보내기") {
        if let id = recipientToConfirm?.id { Task { await requests.sendRequest(to: id) } }
      }
      Button("취소", role: .cancel) { }
    } message: {
      Text(recipientToConfirm?.displayLabel ?? "")
    }
    .alert(pendingAction?.title ?? "친구 요청", isPresented: Binding(
      get: { pendingAction != nil }, set: { if !$0 { pendingAction = nil } }
    ), presenting: pendingAction) { pending in
      Button(pending.buttonTitle, role: .destructive) {
        Task { await requests.act(on: pending.request, action: pending.action) }
      }
      Button("닫기", role: .cancel) { }
    } message: { pending in
      Text(pending.request.user.name)
    }
  }

  private var friendList: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("친구 \(model.friends.count)명").font(.headline)
        Spacer()
        FilterToggle("온라인만", isOn: $onlineOnly).controlSize(.small)
      }
      TextField("친구 이름 검색", text: $search).textFieldStyle(.roundedBorder)
      if let error = requests.friendsError { Text(error).foregroundStyle(.red).font(.callout) }
      if !requests.friendsLoaded {
        ContentUnavailableView("친구 목록 확인 중", systemImage: "person.2",
                               description: Text("불러오지 못했다면 새로고침해주세요."))
      } else if model.friends.isEmpty {
        ContentUnavailableView("아직 연결된 친구가 없어요", systemImage: "person.2",
                               description: Text("친구 추가 탭에서 이름으로 검색해보세요."))
      } else if friends.isEmpty {
        ContentUnavailableView("조건에 맞는 친구가 없어요", systemImage: "magnifyingglass",
                               description: Text("검색어나 온라인 필터를 바꿔보세요."))
      } else {
        ForEach(friends) { friend in
          HStack {
            FriendPresenceRow(friend: friend)
          }
          if friend.id != friends.last?.id { Divider() }
        }
      }
    }
  }

  private var addFriend: some View {
    @Bindable var requests = requests
    return VStack(alignment: .leading, spacing: 16) {
      Label("친구 찾기", systemImage: "person.badge.plus").font(.headline)
      HStack {
        TextField("사용자 이름 검색", text: $requests.searchQuery)
          .textFieldStyle(.roundedBorder).disabled(requests.isMutating)
          .accessibilityLabel("사용자 이름 검색")
          .onSubmit { Task { await requests.searchUsers() } }
        Button("검색") { Task { await requests.searchUsers() } }
          .disabled(!requests.canSearch)
      }
      if requests.isLookingUp { ProgressView("사용자를 찾고 있어요").controlSize(.small) }
      if requests.hasSearched && requests.searchResults.isEmpty {
        ContentUnavailableView("검색 결과가 없어요", systemImage: "magnifyingglass")
      }
      ForEach(requests.searchResults) { user in
        if let id = user.id {
          HStack(spacing: 12) {
            ProfileAvatarView(imageData: nil, imageURL: user.profileImageURL, size: 42)
            Text(user.displayLabel).fontWeight(.medium)
            Spacer()
            if let status = requests.requestStatus(for: id) {
              Text(status).font(.caption).foregroundStyle(.secondary)
            } else {
              Button("친구 추가") {
                recipientToConfirm = user
                sendConfirmation = true
              }
              .buttonStyle(.borderedProminent).disabled(!requests.canSendRequest(to: id))
            }
          }
          .padding(.vertical, 8)
          if user.id != requests.searchResults.last?.id { Divider() }
        }
      }
    }
    .padding(.vertical, 12)
  }

  private var requestList: some View {
    let rows = outgoingRequests ? requests.sent : requests.received
    let loaded = outgoingRequests ? requests.sentLoaded : requests.receivedLoaded
    let error = outgoingRequests ? requests.sentError : requests.receivedError
    return VStack(alignment: .leading, spacing: 16) {
      Picker("요청 종류", selection: $outgoingRequests) {
        Text("받은 요청 (\(requests.received.count))").tag(false)
        Text("보낸 요청 (\(requests.sent.count))").tag(true)
      }
      .pickerStyle(.segmented).labelsHidden()
      if let error { Text(error).font(.callout).foregroundStyle(.red) }
      if !loaded {
        ContentUnavailableView("요청 목록 확인 중", systemImage: "envelope",
                               description: Text("불러오지 못했다면 새로고침해주세요."))
      } else if rows.isEmpty {
        ContentUnavailableView(outgoingRequests ? "보낸 요청이 없어요" : "받은 요청이 없어요", systemImage: "envelope")
      } else {
        ForEach(rows) { request in
          HStack(spacing: 12) {
            ProfileAvatarView(imageData: nil, imageURL: request.user.profileImageURL, size: 40)
            VStack(alignment: .leading, spacing: 4) {
              Text(request.user.name).fontWeight(.medium)
            }
            Spacer()
            if outgoingRequests {
              Button("요청 취소") { pendingAction = RequestConfirmation(request: request, action: .cancel) }
            } else {
              Button("거절") { pendingAction = RequestConfirmation(request: request, action: .reject) }
              Button("수락") { Task { await requests.act(on: request, action: .accept) } }
                .buttonStyle(.borderedProminent)
            }
          }
          .disabled(requests.isMutating)
          .padding(.vertical, 8)
          if request.id != rows.last?.id { Divider() }
        }
      }
      if requests.isMutating { ProgressView("처리하고 있어요").controlSize(.small) }
    }
  }

  private struct RequestConfirmation {
    let request: FriendRequest
    let action: FriendRequestAction
    var title: String { action == .cancel ? "보낸 요청을 취소할까요?" : "받은 요청을 거절할까요?" }
    var buttonTitle: String { action == .cancel ? "요청 취소" : "거절" }
  }
}
