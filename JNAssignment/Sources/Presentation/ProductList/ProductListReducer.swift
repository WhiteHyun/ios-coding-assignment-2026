import Architecture
import DependencyInjection

@MainActor
struct ProductListReducer: Reducer {
  nonisolated enum Action: Sendable {
    case appeared
    case disappeared
    case retryButtonTapped
    case favoriteButtonTapped(productID: Int)
    case productsUpdated([Product])
    case observationFailed
    case observationEnded
    case observationCancelled
    case layoutChanged(ProductListLayout)
  }

  nonisolated struct State: Equatable, Sendable {
    var phase: ProductListPhase = .idle
    var isObserving = false
    var layout: ProductListLayout = .list
  }

  nonisolated enum ProductListPhase: Equatable, Sendable {
    case idle
    case loading
    case loaded([Product])
    case failed
  }

  private enum EffectID {
    case observation
  }

  let initialState: State = .init()
  @Dependency private var productListUseCase: ProductListUseCase
  @Dependency private var favoriteUseCase: FavoriteUseCase

  init() {
  }

  func reduce(state: inout State, action: Action) -> Effect {
    switch action {
    case .appeared:
      if !state.isObserving, state.phase != .failed {
        return observeProducts(state: &state)
      }
      return .none

    case .disappeared:
      state.isObserving = false
      if state.phase == .loading {
        state.phase = .idle
      }
      return .cancel(id: EffectID.observation)

    case .retryButtonTapped:
      if state.phase == .failed {
        state.phase = .idle
        return observeProducts(state: &state)
      }
      return .none

    case let .favoriteButtonTapped(productID):
      if case let .loaded(products) = state.phase, products.contains(where: { $0.id == productID }) {
        return .run { _ in favoriteUseCase.toggle(productID: productID) }
      }
      return .none

    case let .productsUpdated(products):
      state.phase = .loaded(products)
      return .none

    case .observationFailed:
      state.isObserving = false
      state.phase = .failed
      return .none

    case .observationEnded, .observationCancelled:
      state.isObserving = false
      if state.phase == .loading {
        state.phase = .idle
      }
      return .none

    case let .layoutChanged(layout):
      state.layout = layout
      return .none
    }
  }

  private func observeProducts(state: inout State) -> Effect {
    state.isObserving = true
    if state.phase == .idle {
      state.phase = .loading
    }
    return .run(id: EffectID.observation) { send in
      do {
        let updates = try await productListUseCase.observeProducts()
        for await products in updates {
          send(.productsUpdated(products))
        }
        send(.observationEnded)
      } catch is CancellationError {
        send(.observationCancelled)
      } catch {
        send(.observationFailed)
      }
    }
  }
}
