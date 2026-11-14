import SwiftUI

/// Scroll only overflowing text, retaining a static accessible label and respecting Reduce Motion.
struct MarqueeText: View {
  let text: String
  var size: CGFloat = 12
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var origin = Date()

  var body: some View {
    GeometryReader { geometry in
      let width = (text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size)]).width
      let overflow = width > geometry.size.width
      TimelineView(.animation(minimumInterval: 1 / 30, paused: !overflow || reduceMotion)) { timeline in
        let distance = width + 28
        let duration = distance / 24
        let elapsed = max(0, timeline.date.timeIntervalSince(origin))
        let phase = elapsed.truncatingRemainder(dividingBy: duration + 3)
        let offset = phase < 3 ? 0 : (phase - 3) * 24
        HStack(spacing: 28) {
          Text(text).fixedSize()
          if overflow && !reduceMotion { Text(text).fixedSize() }
        }
        .font(.system(size: size))
        .offset(x: overflow && !reduceMotion ? -offset : 0)
      }
      .onChange(of: text) { _, _ in origin = Date() }
      .onChange(of: geometry.size.width) { _, _ in origin = Date() }
    }
    .frame(height: size + 5)
    .clipped()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(text)
    .help(text)
  }
}
