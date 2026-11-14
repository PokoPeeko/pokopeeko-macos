import SwiftUI

struct NowPlayingView: View {
  let music: MusicViewModel
  var compact = false

  var body: some View {
    HStack(alignment: .center, spacing: compact ? 12 : 22) {
      artwork(music)
        .frame(width: compact ? 72 : 112, height: compact ? 72 : 112)
        .background(.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityLabel("현재 곡 앨범 표지")
      VStack(alignment: .leading, spacing: compact ? 6 : 10) {
        Label(music.playback.state == .paused ? "일시정지" : "지금 듣는 음악",
              systemImage: music.playback.state == .paused ? "pause.fill" : "waveform")
          .font(.caption.weight(.medium)).foregroundStyle(.secondary)
        MarqueeText(text: music.playback.title ?? "", size: compact ? 13 : 18)
        Text(music.playback.artist ?? "").font(.callout).foregroundStyle(.secondary)
          .lineLimit(1)
        if let duration = music.playback.duration, duration > 0, music.playback.position != nil {
          TimelineView(.periodic(from: .now, by: 1)) { context in
            let position = music.displayedPosition(at: context.date) ?? 0
            VStack(spacing: 5) {
              ProgressView(value: position, total: duration)
                .accessibilityLabel("재생 진행률")
              HStack {
                Text(time(position))
                Spacer()
                Text(time(duration))
              }
              .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
          }
        }
      }
      .opacity(music.playback.state == .paused ? 0.65 : 1)
    }
  }

  @ViewBuilder private func artwork(_ music: MusicViewModel) -> some View {
    switch music.artwork {
    case .data(let data):
      if let image = NSImage(data: data) {
        Image(nsImage: image).resizable().scaledToFill()
      } else { fallbackArtwork(music) }
    case .url(let url):
      AsyncImage(url: url) { image in image.resizable().scaledToFill() }
        placeholder: { fallbackArtwork(music) }
    case nil: fallbackArtwork(music)
    }
  }

  private func fallbackArtwork(_ music: MusicViewModel) -> some View {
    AppIconView(bundleIdentifier: music.provider.bundleID, appName: music.provider.name, size: compact ? 42 : 64)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func time(_ value: TimeInterval) -> String {
    let seconds = Int(min(86_400_000, max(0, value)))
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }

}
