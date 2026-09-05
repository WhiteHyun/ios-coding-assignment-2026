import Observation

@MainActor
@Observable
final class ProductDetailInteractor: Interactor {
  enum Action {
    case task
    case retryButtonTapped
    case favoriteButtonTapped
  }

  struct State: Equatable {
    var phase: ProductDetailPhase = .idle
    var retryCount = 0
  }

  enum ProductDetailPhase: Equatable {
    case idle
    case loading
    case loaded(ProductDetail)
    case failed
  }

  private(set) var state: State = .init()
  private let productID: Int
  private let productDetailUseCase: ProductDetailUseCase
  private let favoriteUseCase: FavoriteUseCase
  private var isObservingProduct = false

  init(productID: Int, productDetailUseCase: ProductDetailUseCase, favoriteUseCase: FavoriteUseCase) {
    self.productID = productID
    self.productDetailUseCase = productDetailUseCase
    self.favoriteUseCase = favoriteUseCase
  }

  func send(_ action: Action) async {
    switch action {
    case .task:
      if !isObservingProduct, state.phase != .failed {
        await observeProduct()
      }

    case .retryButtonTapped:
      if state.phase == .failed {
        state.phase = .idle
        state.retryCount += 1
      }

    case .favoriteButtonTapped:
      if case .loaded = state.phase {
        favoriteUseCase.toggle(productID: productID)
      }
    }
  }

  private func observeProduct() async {
    isObservingProduct = true
    defer { isObservingProduct = false }
    if state.phase == .idle {
      state.phase = .loading
    }
    do {
      let updates = try await productDetailUseCase.observeProduct(id: productID)
      for await product in updates {
        if !Task.isCancelled {
          state.phase = .loaded(product)
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
