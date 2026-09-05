import Architecture
import SwiftUI

struct ProductDetailView: View {
  @State var store: StoreOf<ProductDetailReducer>

  var body: some View {
    content
      .navigationTitle("상품 상세")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear { store.dispatch(.appeared) }
      .onDisappear { store.dispatch(.disappeared) }
  }

  @ViewBuilder
  private var content: some View {
    switch store.state.phase {
    case .idle, .loading:
      ProgressView("상품을 불러오는 중이에요")
        .frame(maxWidth: .infinity, maxHeight: .infinity)

    case let .loaded(product):
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          ProductImageGallery(images: product.images)
          productInformation(product)
          if !product.description.isEmpty {
            Divider()
            VStack(alignment: .leading, spacing: 12) {
              Text("상품 설명")
                .font(.headline)
              Text(product.description)
                .font(.body)
                .foregroundStyle(.secondary)
            }
          }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .safeAreaInset(edge: .bottom) {
        Button {
          store.dispatch(.favoriteButtonTapped)
        } label: {
          Label(product.isFavorite ? "찜 해제" : "찜하기", systemImage: product.isFavorite ? "heart.fill" : "heart")
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(product.isFavorite ? .red : .accentColor)
        .accessibilityValue(product.isFavorite ? "선택됨" : "선택 안 됨")
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
      }

    case .failed:
      ContentUnavailableView {
        Label("상품을 불러오지 못했어요", systemImage: "wifi.exclamationmark")
      } description: {
        Text("잠시 후 다시 시도해 주세요.")
      } actions: {
        Button("다시 시도") {
          store.dispatch(.retryButtonTapped)
        }
        .buttonStyle(.borderedProminent)
      }
    }
  }

  private func productInformation(_ product: ProductDetail) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text([product.brand, product.category].compactMap(\.self).filter { !$0.isEmpty }.joined(separator: " · "))
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Text(product.title)
        .font(.title2.bold())
      Text(product.price, format: .number.precision(.fractionLength(2)))
        .font(.title.bold())
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 16) { productStatistics(product) }
        VStack(alignment: .leading, spacing: 8) { productStatistics(product) }
      }
      .font(.subheadline)
      .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private func productStatistics(_ product: ProductDetail) -> some View {
    Label {
      Text("평점 \(product.rating, format: .number.precision(.fractionLength(1))) / 5")
    } icon: {
      Image(systemName: "star.fill").foregroundStyle(.orange)
    }
    Label(product.stock > 0 ? "재고 \(product.stock)개" : "품절", systemImage: "shippingbox")
  }
}
