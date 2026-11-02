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

struct AppSymbol: View {
  let symbol: String

  var body: some View {
    Image(systemName: symbol)
      .font(.system(size: 20, weight: .medium))
      .foregroundStyle(.tint)
      .frame(width: 44, height: 44)
      .background(.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
      .accessibilityHidden(true)
  }
}

struct SampleNotice: View {
  var body: some View {
    Label("샘플 데이터 미리보기 · 실제 활동 정보가 아닙니다", systemImage: "eye")
      .font(.callout)
      .foregroundStyle(.secondary)
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
  }
}
