import Architecture
import DependencyInjection

@MainActor
struct ProductDetailReducer: Reducer {
  nonisolated enum Action: Sendable {
    case appeared
    case disappeared
    case retryButtonTapped
    case favoriteButtonTapped
    case productUpdated(ProductDetail)
    case observationFailed
    case observationEnded
    case observationCancelled
  }

  nonisolated struct State: Equatable, Sendable {
    var phase: ProductDetailPhase = .idle
    var isObserving = false
  }

  nonisolated enum ProductDetailPhase: Equatable, Sendable {
    case idle
    case loading
    case loaded(ProductDetail)
    case failed
  }

  private enum EffectID {
    case observation
  }

  let initialState: State = .init()
  private let productID: Int
  @Dependency private var productDetailUseCase: ProductDetailUseCase
  @Dependency private var favoriteUseCase: FavoriteUseCase

  init(productID: Int) {
    self.productID = productID
  }

  func reduce(state: inout State, action: Action) -> Effect {
    switch action {
    case .appeared:
      if !state.isObserving, state.phase != .failed {
        return observeProduct(state: &state)
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
        return observeProduct(state: &state)
      }
      return .none

    case .favoriteButtonTapped:
      if case .loaded = state.phase {
        return .run { _ in favoriteUseCase.toggle(productID: productID) }
      }
      return .none

    case let .productUpdated(product):
      state.phase = .loaded(product)
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
    }
  }

  private func observeProduct(state: inout State) -> Effect {
    state.isObserving = true
    if state.phase == .idle {
      state.phase = .loading
    }
    return .run(id: EffectID.observation) { send in
      do {
        let updates = try await productDetailUseCase.observeProduct(id: productID)
        for await product in updates {
          send(.productUpdated(product))
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
