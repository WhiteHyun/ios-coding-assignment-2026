import Architecture
import SwiftUI

struct ProductListView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let store: StoreOf<ProductListReducer>

  var body: some View {
    content
      .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: store.state.layout)
      .navigationTitle("상품")
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          layoutButton(.list, title: "1열 목록", systemImage: "list.bullet")
          layoutButton(.grid, title: "2열 격자", systemImage: "square.grid.2x2")
        }
      }
      .onAppear { store.dispatch(.appeared) }
      .onDisappear { store.dispatch(.disappeared) }
  }

  private func layoutButton(_ layout: ProductListLayout, title: String, systemImage: String) -> some View {
    Button {
      store.dispatch(.layoutChanged(layout))
    } label: {
      Label(title, systemImage: systemImage)
        .labelStyle(.iconOnly)
        .foregroundStyle(store.state.layout == layout ? Color.accentColor : .secondary)
        .frame(minWidth: 44, minHeight: 44)
        .background(
          store.state.layout == layout ? Color.primary.opacity(0.1) : .clear,
          in: RoundedRectangle(cornerRadius: 12),
        )
    }
    .accessibilityAddTraits(store.state.layout == layout ? .isSelected : [])
  }

  @ViewBuilder
  private var content: some View {
    switch store.state.phase {
    case .idle, .loading:
      ProgressView("상품을 불러오는 중이에요")
        .frame(maxWidth: .infinity, maxHeight: .infinity)

    case let .loaded(products):
      if products.isEmpty {
        ContentUnavailableView("상품이 없어요", systemImage: "shippingbox")
      } else {
        ScrollView {
          LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: store.state.layout == .list ? 1 : 2),
            alignment: .leading,
            spacing: 20,
          ) {
            ForEach(products) { product in
              ProductRow(product: product, layout: store.state.layout) {
                store.dispatch(.favoriteButtonTapped(productID: product.id))
              }
            }
          }
          .padding()
        }
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
}
