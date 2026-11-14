import SwiftUI

struct SectionHeading: View {
  let title: String
  let subtitle: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.largeTitle.bold())
      Text(subtitle).foregroundStyle(.secondary)
    }
  }
}

struct ActivityCard<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    content
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.background, in: RoundedRectangle(cornerRadius: 16))
      .overlay {
        RoundedRectangle(cornerRadius: 16)
          .strokeBorder(.primary.opacity(0.07))
      }
  }
}
