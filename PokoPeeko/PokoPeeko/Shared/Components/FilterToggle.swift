import SwiftUI

struct FilterToggle: View {
  let title: String
  @Binding var isOn: Bool

  init(_ title: String, isOn: Binding<Bool>) {
    self.title = title
    _isOn = isOn
  }

  var body: some View {
    Toggle(isOn: $isOn) {
      Text(title)
        .foregroundStyle(isOn ? Color(red: 0.80, green: 0.77, blue: 0.92) : Color.primary)
    }
    .toggleStyle(.button)
    .tint(.accentColor)
  }
}
