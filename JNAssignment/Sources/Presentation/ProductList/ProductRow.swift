import SwiftUI

struct ProductRow: View {
  let product: Product

  var body: some View {
    HStack(spacing: 16) {
      AsyncImage(url: product.thumbnail) { phase in
        switch phase {
        case let .success(image):
          image
            .resizable()
            .scaledToFit()

        case .empty, .failure:
          Image(systemName: "photo")
            .foregroundStyle(.secondary)

        @unknown default:
          Image(systemName: "photo")
            .foregroundStyle(.secondary)
        }
      }
      .frame(width: 80, height: 80)
      .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
      .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 8) {
        Text(product.title)
          .font(.headline)
        Text(product.price, format: .number.precision(.fractionLength(2)))
          .font(.subheadline)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, 8)
    .accessibilityElement(children: .combine)
  }
}
