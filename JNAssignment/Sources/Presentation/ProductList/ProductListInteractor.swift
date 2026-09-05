import Observation

@MainActor
@Observable
final class ProductListInteractor: Interactor {
  enum Action {
    case task
    case retryButtonTapped
  }

  enum State: Equatable {
    case idle
    case loading
    case loaded([Product])
    case failed
  }

  private(set) var state: State = .idle
  private let repository: any ProductRepository

  init(repository: any ProductRepository) {
    self.repository = repository
  }

  func send(_ action: Action) async {
    switch action {
    case .task:
      guard state == .idle else { return }

    case .retryButtonTapped:
      guard state == .failed else { return }
    }

    state = .loading
    do {
      let products = try await repository.fetchProducts()
      try Task.checkCancellation()
      state = .loaded(products)
    } catch is CancellationError {
      state = .idle
    } catch {
      state = Task.isCancelled ? .idle : .failed
    }
  }
}
