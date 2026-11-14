import SwiftUI

struct MusicIntegrationView: View {
  @Environment(MainViewModel.self) private var model

  var body: some View {
    @Bindable var music = model.music
    ActivityCard {
      VStack(alignment: .leading, spacing: 20) {
        Toggle(isOn: $music.isEnabled) {
          Label("이 Mac의 음악", systemImage: "headphones").font(.headline)
        }
        .toggleStyle(.switch)
        .accessibilityLabel("이 Mac의 음악 감지 및 공유")

        VStack(alignment: .leading, spacing: 18) {
          Text("Apple Music 또는 Spotify 앱에서 듣는 곡과 가수를 친구에게 공유해요.")
            .foregroundStyle(.secondary)
          Picker("음악 앱", selection: $music.provider) {
            ForEach(MusicProvider.allCases) { Text($0.name).tag($0) }
          }
          .pickerStyle(.segmented)
          Divider()
          connectionPanel(music)
        }
        .disabled(!music.isEnabled)
        .opacity(music.isEnabled ? 1 : 0.45)
      }
      .padding(4)
    }
  }

  private func connectionPanel(_ music: MusicViewModel) -> some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(spacing: 8) {
        if music.detectionStatus == .checking {
          ProgressView().controlSize(.small)
        } else {
          Image(systemName: statusSymbol(music))
            .foregroundStyle(music.detectionStatus == .connected ? Color.green : Color.secondary)
        }
        Text(statusTitle(music)).font(.headline)
        Spacer()
        Text(music.provider.name).font(.caption).foregroundStyle(.secondary)
      }
      if music.detectionStatus == .connected {
        if music.playback.state != .closed {
          NowPlayingView(music: music)
        } else {
          Label("음악 앱과 연결됐어요. 곡을 재생하면 여기에 표시돼요.", systemImage: "music.note")
            .foregroundStyle(.secondary)
        }
      } else {
        Text(statusDetail(music)).foregroundStyle(.secondary)
        if music.isEnabled && music.detectionStatus != .checking {
          HStack {
            if music.detectionStatus == .waitingForApp {
              Button("\(music.provider.name) 열기") {
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: music.provider.bundleID) {
                  NSWorkspace.shared.open(url)
                }
              }
            }
            if music.permissionDenied {
              Button("권한 요청") { music.requestPermission() }
                .disabled(music.isRequestingPermission)
              Button("자동화 설정 열기") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
              }
            }
            Button("다시 확인") { music.retry() }
          }
        }
      }
    }
  }

  private func statusSymbol(_ music: MusicViewModel) -> String {
    switch music.detectionStatus {
    case .connected: return "checkmark.circle.fill"
    case .permissionRequired, .permissionDenied: return "lock.shield"
    case .failed: return "exclamationmark.triangle"
    default: return "music.note"
    }
  }

  private func statusTitle(_ music: MusicViewModel) -> String {
    switch music.detectionStatus {
    case .disabled: return "음악 공유 꺼짐"
    case .waitingForApp: return "음악 앱 실행 대기"
    case .checking: return "음악 앱 접근 확인 중"
    case .connected: return "음악 앱 연결됨"
    case .permissionRequired: return "음악 앱 접근 권한 필요"
    case .permissionDenied: return "자동화 권한 거부됨"
    case .failed: return "음악 앱 연결 확인 필요"
    }
  }

  private func statusDetail(_ music: MusicViewModel) -> String {
    switch music.detectionStatus {
    case .disabled: return "감지 및 공유를 켜면 선택한 음악 앱에 연결해요."
    case .waitingForApp: return "\(music.provider.name) 앱을 실행해주세요. 실행되면 자동으로 연결을 확인해요."
    case .checking: return music.isRequestingPermission ? "macOS 허용 창에서 접근을 허용해주세요." : "음악 앱의 접근 권한과 현재 상태를 확인하고 있어요."
    case .permissionRequired: return "‘권한 요청’을 누르면 macOS 접근 허용 창이 나타나요. 공유 스위치만 켜면 권한 창은 뜨지 않아요."
    case .permissionDenied: return "시스템 설정 → 개인정보 보호 및 보안 → 자동화에서 PokoPeeko 아래의 음악 앱을 허용해주세요. 항목이 없다면 음악 앱을 실행한 뒤 ‘권한 요청’을 눌러주세요."
    case .failed: return music.errorMessage ?? "음악 앱의 응답을 확인하지 못했어요."
    case .connected: return ""
    }
  }
}
