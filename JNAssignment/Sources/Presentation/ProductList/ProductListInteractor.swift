import Observation

@MainActor
@Observable
final class ProductListInteractor: Interactor {
  enum Action {
    case task
    case observeFavorites
    case retryButtonTapped
    case favoriteButtonTapped(productID: Int)
  }

  struct State: Equatable {
    var phase: ProductListPhase = .idle
    var favoriteIDs: Set<Int> = []
  }

  enum ProductListPhase: Equatable {
    case idle
    case loading
    case loaded([Product])
    case failed
  }

  private(set) var state: State = .init()
  private let repository: any ProductRepository
  private let favoriteUseCase: FavoriteUseCase

  init(repository: any ProductRepository, favoriteUseCase: FavoriteUseCase) {
    self.repository = repository
    self.favoriteUseCase = favoriteUseCase
  }

  func send(_ action: Action) async {
    switch action {
    case .task:
      if state.phase == .idle {
        await loadProducts()
      }

    case .observeFavorites:
      for await productIDs in favoriteUseCase.observeProductIDs() {
        if !Task.isCancelled {
          state.favoriteIDs = productIDs
        }
      }

    case .retryButtonTapped:
      if state.phase == .failed {
        await loadProducts()
      }

    case let .favoriteButtonTapped(productID):
      if case let .loaded(products) = state.phase, products.contains(where: { $0.id == productID }) {
        favoriteUseCase.toggle(productID: productID)
      }
    }
  }

  private func loadProducts() async {
    state.phase = .loading
    do {
      let products = try await repository.fetchProducts()
      try Task.checkCancellation()
      state.phase = .loaded(products)
    } catch is CancellationError {
      state.phase = .idle
    } catch {
      state.phase = Task.isCancelled ? .idle : .failed
    }
  }
}
