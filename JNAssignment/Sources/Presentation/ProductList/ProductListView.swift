import SwiftUI

struct ProductListView: View {
  let interactor: ProductListInteractor

  var body: some View {
    content
      .navigationTitle("상품")
      .task {
        await interactor.send(.task)
      }
  }

  @ViewBuilder
  private var content: some View {
    switch interactor.state {
    case .idle, .loading:
      ProgressView("상품을 불러오는 중이에요")
        .frame(maxWidth: .infinity, maxHeight: .infinity)

    case let .loaded(products):
      if products.isEmpty {
        ContentUnavailableView("상품이 없어요", systemImage: "shippingbox")
      } else {
        List(products) { product in
          ProductRow(product: product)
        }
        .listStyle(.plain)
      }

    case .failed:
      ContentUnavailableView {
        Label("상품을 불러오지 못했어요", systemImage: "wifi.exclamationmark")
      } description: {
        Text("잠시 후 다시 시도해 주세요.")
      } actions: {
        Button("다시 시도") {
          Task {
            await interactor.send(.retryButtonTapped)
          }
        }
        .buttonStyle(.borderedProminent)
      }
    }
  }
}
