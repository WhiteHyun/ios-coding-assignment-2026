import SwiftUI

struct ProductRow: View {
  let product: Product
  let isFavorite: Bool
  let favoriteButtonTapped: () -> Void

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

      Button(action: favoriteButtonTapped) {
        Image(systemName: isFavorite ? "heart.fill" : "heart")
          .foregroundStyle(isFavorite ? .red : .secondary)
          .frame(width: 44, height: 44)
      }
      .buttonStyle(.borderless)
      .accessibilityLabel("\(product.title) 찜")
      .accessibilityValue(isFavorite ? "선택됨" : "선택 안 됨")
      .accessibilityHint(isFavorite ? "찜 해제" : "찜 추가")
    }
    .padding(.vertical, 8)
    .accessibilityElement(children: .contain)
  }
}
