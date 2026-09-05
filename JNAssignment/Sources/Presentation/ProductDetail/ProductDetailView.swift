import SwiftUI

struct ProductDetailView: View {
  @State var interactor: ProductDetailInteractor

  var body: some View {
    content
      .navigationTitle("상품 상세")
      .navigationBarTitleDisplayMode(.inline)
      .task(id: interactor.state.retryCount) {
        await interactor.send(.task)
      }
  }

  @ViewBuilder
  private var content: some View {
    switch interactor.state.phase {
    case .idle, .loading:
      ProgressView("상품을 불러오는 중이에요")
        .frame(maxWidth: .infinity, maxHeight: .infinity)

    case let .loaded(product):
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          AsyncImage(url: product.thumbnail) { image in
            image.resizable().scaledToFit()
          } placeholder: {
            Image(systemName: "photo")
              .font(.largeTitle)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity)
          .frame(height: 260)
          .accessibilityHidden(true)

          Text(product.title)
            .font(.title2.bold())
          Text(product.price, format: .number.precision(.fractionLength(2)))
            .font(.title3)
          if let description = product.description, !description.isEmpty {
            Text(description)
          }

          Button {
            Task { await interactor.send(.favoriteButtonTapped) }
          } label: {
            Label(product.isFavorite ? "찜 해제" : "찜하기", systemImage: product.isFavorite ? "heart.fill" : "heart")
              .frame(maxWidth: .infinity, minHeight: 44)
          }
          .buttonStyle(.borderedProminent)
          .tint(product.isFavorite ? .red : .accentColor)
          .accessibilityValue(product.isFavorite ? "선택됨" : "선택 안 됨")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
      }

    case .failed:
      ContentUnavailableView {
        Label("상품을 불러오지 못했어요", systemImage: "wifi.exclamationmark")
      } description: {
        Text("잠시 후 다시 시도해 주세요.")
      } actions: {
        Button("다시 시도") {
          Task { await interactor.send(.retryButtonTapped) }
        }
        .buttonStyle(.borderedProminent)
      }
    }
  }
}
