import Foundation
import Observation
import SocketIO
import OSLog

@MainActor
@Observable
final class PresenceService {
  let store = PresenceStore()
  private static let logger = Logger(subsystem: "com.peekopoko.pokopeeko", category: "Presence")
  private(set) var status = "로그인 후 실시간 공유를 시작해요" {
    didSet { if oldValue != status { Self.logger.info("\(self.status, privacy: .public)") } }
  }
  private(set) var errorMessage: String? {
    didSet { if oldValue != errorMessage, let errorMessage { Self.logger.error("\(errorMessage, privacy: .public)") } }
  }
  private(set) var isConnecting = false
  private(set) var sessionID: String?
  @ObservationIgnored var onSessionExpired: ((String) -> Void)?
  @ObservationIgnored private var manager: SocketManager?
  @ObservationIgnored private var socket: SocketIOClient?
  @ObservationIgnored private var heartbeat: Task<Void, Never>?
  private var generation = UUID()
  private var currentAppName: String?
  private var currentMusic: MusicPlayback = .closed
  private var isSharingEnabled = true
  private let baseURL: String

  init(baseURL: String? = nil) { self.baseURL = baseURL ?? APIConfig.socketBaseURL }

  func connect(sessionID: String) {
    guard self.sessionID != sessionID else { return }
    stop()
    guard UUID(uuidString: sessionID) != nil,
          let url = URL(string: baseURL), ["https", "http"].contains(url.scheme ?? ""), url.host != nil else {
      errorMessage = "실시간 서버 주소 설정을 확인해주세요."
      return
    }
    self.sessionID = sessionID
    Self.logger.info("Socket.IO 연결 시작 host=\(url.host ?? "", privacy: .public) port=\(url.port ?? (url.scheme == "https" ? 443 : 80)) namespace=/user-status")
    let token = generation
    let manager = SocketManager(socketURL: url, config: [
      .log(false), .path("/socket.io/"), .version(.three),
      .handleQueue(.main), .reconnects(true), .reconnectAttempts(5),
      .reconnectWait(3), .reconnectWaitMax(15)
    ])
    let socket = manager.socket(forNamespace: "/user-status")
    self.manager = manager
    self.socket = socket
    isConnecting = true
    status = "실시간 서버에 연결 중"
    socket.on(clientEvent: .connect) { [weak self] _, _ in
      MainActor.assumeIsolated {
        guard let self, self.generation == token else { return }
        self.isConnecting = false
        self.errorMessage = nil
        self.status = "실시간 연결됨"
        self.store.setConnected(true)
        self.publishCurrentApp()
        self.publishMusic()
        self.refreshFriends()
        self.startHeartbeat(token: token)
      }
    }
    socket.on(clientEvent: .disconnect) { [weak self] _, _ in
      MainActor.assumeIsolated {
        guard let self, self.generation == token else { return }
        self.heartbeat?.cancel()
        self.store.setConnected(false)
        self.isConnecting = false
        self.status = "실시간 연결 끊김"
      }
    }
    socket.on(clientEvent: .error) { [weak self] data, _ in
      MainActor.assumeIsolated { self?.handleError(data, token: token) }
    }
    socket.on("connect_error") { [weak self] data, _ in
      MainActor.assumeIsolated { self?.handleError(data, token: token) }
    }
    socket.on("exception") { [weak self] data, _ in
      MainActor.assumeIsolated { self?.handleError(data, token: token) }
    }
    for event in ["window_status:updated", "music_status:updated", "music_status:removed", "user_status:removed"] {
      socket.on(event) { [weak self] data, _ in
        MainActor.assumeIsolated {
          guard let self, self.generation == token, let payload = data.first,
                JSONSerialization.isValidJSONObject(payload) else { return }
          do {
            try self.store.receive(event: event, data: JSONSerialization.data(withJSONObject: payload))
          } catch { self.errorMessage = "친구 활동 응답 형식을 확인할 수 없어요." }
        }
      }
    }
    // Socket.IO v3/v4의 namespace CONNECT payload가 서버의 auth.sessionId에 대응한다.
    socket.connect(withPayload: ["sessionId": sessionID], timeoutAfter: 12) { [weak self] in
      MainActor.assumeIsolated {
        guard let self, self.generation == token else { return }
        self.isConnecting = false
        self.status = "실시간 연결 실패"
        self.errorMessage = "실시간 서버에 접속하지 못했어요. 소켓 서버 배포 주소와 /socket.io/ 경로를 확인해주세요."
      }
    }
  }

  func reconnect() {
    guard let id = sessionID else { return }
    stop()
    connect(sessionID: id)
  }

  func stop() {
    generation = UUID()
    heartbeat?.cancel()
    heartbeat = nil
    socket?.removeAllHandlers()
    socket?.disconnect()
    manager?.disconnect()
    socket = nil
    manager = nil
    sessionID = nil
    isConnecting = false
    store.setConnected(false)
    errorMessage = nil
    status = "로그인 후 실시간 공유를 시작해요"
  }

  func updateCurrentApp(_ app: DetectedApp?) {
    guard currentAppName != app?.name else { return }
    currentAppName = app?.name
    publishCurrentApp()
  }

  func updateMusic(_ playback: MusicPlayback) {
    guard currentMusic != playback else { return }
    currentMusic = playback
    publishMusic()
  }

  private func publishMusic() {
    guard store.isConnected else { return }
    if let update = MusicStatusUpdateDTO(playback: currentMusic) {
      socket?.emit("music_status:update", update.payload)
    } else {
      // Quit, stopped playback, disabled sharing or missing metadata clears only music.
      socket?.emit("music_status:remove")
    }
  }

  func setSharingEnabled(_ enabled: Bool) {
    guard isSharingEnabled != enabled else { return }
    isSharingEnabled = enabled
    Self.logger.info("앱 활동 공유 \(enabled ? "시작" : "일시 중지", privacy: .public)")
    publishCurrentApp()
  }

  func refreshFriends() {
    guard store.isConnected else { return }
    socket?.emit("friends_status:get")
  }

  private func publishCurrentApp() {
    guard store.isConnected else { return }
    // 삭제 이벤트가 없는 서버 계약에서는 이전 앱을 남기지 않도록 비공개 상태로 교체한다.
    // 창 제목·문서명은 수집하지 않는다.
    let sharedApp = isSharingEnabled ? currentAppName : nil
    let name = sharedApp.map { String($0.prefix(100)) } ?? "활동 비공개"
    socket?.emit("window_status:update", [
      "appTitle": name,
      "taskDescription": sharedApp == nil ? "공유 중인 앱이 없습니다" : "앱 사용 중"
    ])
  }

  private func startHeartbeat(token: UUID) {
    heartbeat?.cancel()
    heartbeat = Task { [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(20)) } catch { return }
        guard let self, self.generation == token, self.store.isConnected else { return }
        self.socket?.emit("user_status:heartbeat")
        // 슬립·일시적인 Redis TTL 만료 후에도 현재 상태가 복구되도록 재전송한다.
        self.publishCurrentApp()
        self.refreshFriends()
        self.store.expire()
      }
    }
  }

  private func handleError(_ data: [Any], token: UUID) {
    guard generation == token else { return }
    let message = (data.first as? [String: Any])?["message"] as? String ?? data.first as? String
    if message == "세션이 없습니다." || message == "유효하지 않은 세션입니다." {
      let id = sessionID
      stop()
      if let id { onSessionExpired?(id) }
      return
    }
    isConnecting = false
    status = store.isConnected ? "실시간 요청 오류" : "실시간 연결 실패"
    errorMessage = message == "An unexpected error occurred"
      ? "실시간 서버 처리 중 오류가 발생했어요."
      : "실시간 서버 연결 또는 요청을 확인해주세요. 친구 목록과 요청 기능은 별도로 사용할 수 있어요."
  }
}
