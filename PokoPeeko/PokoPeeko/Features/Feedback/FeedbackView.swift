import AppKit
import SwiftUI

struct FeedbackView: View {
  @State private var draft = ""
  @State private var copied = false

  var body: some View {
    ActivityCard {
      VStack(alignment: .leading, spacing: 16) {
        Label("어떤 이야기를 들려주실 건가요?", systemImage: "bubble.left.and.text.bubble.right")
          .font(.headline)
        Text("좋았던 점, 불편했던 점, 바라는 기능을 자유롭게 적어주세요.")
          .foregroundStyle(.secondary)
        TextEditor(text: $draft)
          .font(.body)
          .padding(8)
          .frame(minHeight: 200)
          .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
          .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(.primary.opacity(0.1)) }
          .accessibilityLabel("피드백 초안")
          .onChange(of: draft) { copied = false }
        HStack {
          Text("전송 기능은 준비 중입니다. 초안을 복사할 수 있어요.")
            .font(.caption).foregroundStyle(.secondary)
          Spacer()
          Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(draft, forType: .string)
            copied = true
          } label: {
            Label(copied ? "복사했어요" : "초안 복사", systemImage: copied ? "checkmark" : "doc.on.doc")
          }
          .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }
}
