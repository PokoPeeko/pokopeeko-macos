import AppKit
import SwiftUI

struct ProfileAvatarView: View {
  let imageData: Data?
  var imageURL: URL? = nil
  var size: CGFloat = 72
  @State private var loadedImage: NSImage?
  @State private var loadedURL: URL?

  var body: some View {
    Group {
      if let imageData, let image = NSImage(data: imageData) {
        Image(nsImage: image).resizable().scaledToFill()
      } else if let imageURL {
        if let image = ProfileImageCache.shared.cachedImage(for: imageURL)
          ?? (loadedURL == imageURL ? loadedImage : nil) {
          Image(nsImage: image).resizable().scaledToFill()
        } else { placeholder }
      } else {
        placeholder
      }
    }
    .frame(width: size, height: size)
    .clipShape(Circle())
    .accessibilityHidden(true)
    .task(id: imageURL) {
      guard let imageURL else { loadedImage = nil; loadedURL = nil; return }
      if let imageData { ProfileImageCache.shared.save(imageData, for: imageURL); return }
      do {
        let image = try await ProfileImageCache.shared.image(for: imageURL)
        try Task.checkCancellation()
        loadedURL = imageURL
        loadedImage = image
      } catch { }
    }
  }

  private var placeholder: some View {
    Image(systemName: "person.crop.circle.fill")
      .resizable().scaledToFit().foregroundStyle(.secondary.opacity(0.6))
  }
}
