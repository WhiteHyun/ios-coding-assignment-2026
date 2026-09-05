import SwiftUI

struct ProductImage: View {
  let url: URL?

  var body: some View {
    AsyncImage(url: url) { phase in
      switch phase {
      case let .success(image):
        image.resizable().scaledToFit()

      case .empty, .failure:
        Image(systemName: "photo")
          .font(.title2)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)

      @unknown default:
        Image(systemName: "photo")
          .foregroundStyle(.secondary)
      }
    }
  }
}
