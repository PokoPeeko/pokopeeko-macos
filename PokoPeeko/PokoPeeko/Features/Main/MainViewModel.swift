import Foundation
import Observation

@MainActor
@Observable
final class MainViewModel {
  var selection: MainSection? = .dashboard
  var friendsTab: FriendsTab = .list
  let appCatalog: AppCatalog

  let friendsModel: FriendsViewModel
  let presence: PresenceService
  let music = MusicViewModel()
  let loginItem = LaunchAtLoginController()
  var friends: [Friend] { friendsModel.friends.map { presence.store.applying(to: $0) } }
  var onlineFriends: [Friend] { friends.filter { $0.isOnline == true } }
  var apps: [DetectedApp] { appCatalog.registeredApps }
  var blockedApps: [DetectedApp] { appCatalog.blockedApps }

  init(appCatalog: AppCatalog? = nil, friendsModel: FriendsViewModel? = nil, presence: PresenceService? = nil) {
    self.appCatalog = appCatalog ?? AppCatalog()
    self.friendsModel = friendsModel ?? FriendsViewModel()
    self.presence = presence ?? PresenceService()
    let activityPresence = self.presence
    self.music.onChange = { [weak activityPresence] playback in
      activityPresence?.updateMusic(playback)
    }
    self.appCatalog.onActivityChange = { [weak activityPresence] app in
      activityPresence?.updateCurrentApp(app)
    }
    self.friendsModel.onFriendsLoaded = { [weak self] ids in
      self?.presence.store.retainUsers(ids)
      self?.presence.refreshFriends()
    }
  }
}
