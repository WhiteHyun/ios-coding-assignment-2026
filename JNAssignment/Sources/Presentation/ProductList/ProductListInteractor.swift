import Observation

@MainActor
@Observable
final class ProductListInteractor: Interactor {
  enum Action {
    case task
    case retryButtonTapped
    case favoriteButtonTapped(productID: Int)
    case layoutChanged(ProductListLayout)
  }

  struct State: Equatable {
    var phase: ProductListPhase = .idle
    var retryCount = 0
    var layout: ProductListLayout = .list
  }

  enum ProductListPhase: Equatable {
    case idle
    case loading
    case loaded([Product])
    case failed
  }

  private(set) var state: State = .init()
  private let productListUseCase: ProductListUseCase
  private let favoriteUseCase: FavoriteUseCase
  private var isObservingProducts = false

  init(productListUseCase: ProductListUseCase, favoriteUseCase: FavoriteUseCase) {
    self.productListUseCase = productListUseCase
    self.favoriteUseCase = favoriteUseCase
  }

  func send(_ action: Action) async {
    switch action {
    case .task:
      if !isObservingProducts, state.phase != .failed {
        await observeProducts()
      }

    case .retryButtonTapped:
      if state.phase == .failed {
        state.phase = .idle
        state.retryCount += 1
      }

    case let .favoriteButtonTapped(productID):
      if case let .loaded(products) = state.phase, products.contains(where: { $0.id == productID }) {
        favoriteUseCase.toggle(productID: productID)
      }

    case let .layoutChanged(layout):
      state.layout = layout
    }
  }

  private func observeProducts() async {
    isObservingProducts = true
    defer { isObservingProducts = false }
    if state.phase == .idle {
      state.phase = .loading
    }
    do {
      let updates = try await productListUseCase.observeProducts()
      for await products in updates {
        if !Task.isCancelled {
          state.phase = .loaded(products)
        }
      }
      try Task.checkCancellation()
    } catch {
      if error is CancellationError || Task.isCancelled {
        if state.phase == .loading {
          state.phase = .idle
        }
      } else {
        state.phase = .failed
      }
    }
  }
}
