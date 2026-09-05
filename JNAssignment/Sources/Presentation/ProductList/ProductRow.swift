import SwiftUI

struct ProductRow: View {
  let product: Product
  let layout: ProductListLayout
  let favoriteButtonTapped: () -> Void

  var body: some View {
    let rowLayout = layout == .list
      ? AnyLayout(HStackLayout(alignment: .center, spacing: 8))
      : AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
    rowLayout {
      NavigationLink(value: product.id) {
        let contentLayout = layout == .list
          ? AnyLayout(HStackLayout(alignment: .center, spacing: 16))
          : AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
        contentLayout {
          ProductImage(url: product.thumbnail)
            .frame(width: layout == .list ? 88 : nil, height: layout == .list ? 88 : 150)
            .frame(maxWidth: layout == .grid ? .infinity : nil)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityHidden(true)
          VStack(alignment: .leading, spacing: 8) {
            Text(product.title)
              .font(.headline)
              .fixedSize(horizontal: false, vertical: true)
            Text(product.price, format: .number.precision(.fractionLength(2)))
              .font(.subheadline.weight(.semibold))
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      Button(action: favoriteButtonTapped) {
        Label("찜", systemImage: product.isFavorite ? "heart.fill" : "heart")
          .font(.subheadline)
          .foregroundStyle(product.isFavorite ? .red : .secondary)
          .frame(minWidth: 44, minHeight: 44)
      }
      .buttonStyle(.borderless)
      .frame(maxWidth: layout == .grid ? .infinity : nil, alignment: .trailing)
      .accessibilityLabel("\(product.title) 찜")
      .accessibilityValue(product.isFavorite ? "선택됨" : "선택 안 됨")
      .accessibilityHint(product.isFavorite ? "찜 해제" : "찜 추가")
    }
    .accessibilityElement(children: .contain)
  }
}
