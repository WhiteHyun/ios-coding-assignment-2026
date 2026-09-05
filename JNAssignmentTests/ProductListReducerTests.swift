import Architecture
import Observation
import Testing
@testable import JNAssignment

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ProductListReducerTests {
  private let favoriteRepository: LocalFavoriteRepository = .init(storage: InMemoryStorage())

  private var favoriteUseCase: FavoriteUseCase {
    FavoriteUseCase(repository: favoriteRepository)
  }

  @Test
  func `loads products on first appearance and preserves them on subsequent appearances`() async {
    let repository = StubProductRepository(result: .success([product]))
    let store = makeStore(repository: repository)

    #expect(store.state.phase == .idle)
    #expect(repository.requestCount == 0)

    store.dispatch(.appeared)
    defer { store.dispatch(.disappeared) }
    await waitForProducts([product], in: store)

    store.dispatch(.appeared)
    #expect(repository.requestCount == 1)
    #expect(store.state.phase == .loaded([product]))
  }

  @Test
  func `shows loading and ignores duplicate actions while a request is in flight`() async {
    let repository = ControlledProductRepository()
    let store = makeStore(repository: repository)
    store.dispatch(.appeared)
    await repository.waitForRequest()

    #expect(store.state.phase == .loading)
    store.dispatch(.appeared)
    store.dispatch(.retryButtonTapped)
    #expect(repository.requestCount == 1)

    repository.complete(with: .success([product]))
    await waitForProducts([product], in: store)
    store.dispatch(.disappeared)
  }

  @Test
  func `a late product response is combined with the latest saved favorites`() async {
    let repository = ControlledProductRepository()
    let store = makeStore(repository: repository)
    store.dispatch(.appeared)
    await repository.waitForRequest()

    favoriteRepository.save(productIDs: [product.id])
    repository.complete(with: .success([product]))
    await waitForProducts([favoriteProduct], in: store)
    store.dispatch(.disappeared)
  }

  @Test
  func `an empty response is a successful load`() async {
    let store = makeStore(repository: StubProductRepository(result: .success([])))

    store.dispatch(.appeared)
    defer { store.dispatch(.disappeared) }
    await waitForProducts([], in: store)
  }

  @Test
  func `a failed request can be retried`() async {
    let repository = StubProductRepository(result: .failure(TestError.offline))
    let store = makeStore(repository: repository)

    store.dispatch(.appeared)
    await waitForPhase(.failed, in: store)
    #expect(store.state.phase == .failed)

    repository.result = .success([product])
    store.dispatch(.retryButtonTapped)
    #expect(store.state.phase == .loading)
    defer { store.dispatch(.disappeared) }
    await waitForProducts([product], in: store)
    #expect(repository.requestCount == 2)
    #expect(store.state.phase == .loaded([product]))
  }

  @Test
  func `cancellation discards a late response and allows a later appearance to load again`() async {
    let repository = ControlledProductRepository()
    let store = makeStore(repository: repository)
    store.dispatch(.appeared)
    await repository.waitForRequest()

    store.dispatch(.disappeared)
    repository.complete(with: .success([product]))
    #expect(store.state.phase == .idle)

    store.dispatch(.appeared)
    await repository.waitForRequest()
    repository.complete(with: .success([product]))
    await waitForProducts([product], in: store)
    store.dispatch(.disappeared)
    #expect(repository.requestCount == 2)
    #expect(store.state.phase == .loaded([product]))
  }

  @Test
  func `repository cancellation does not display an error`() async {
    let store = makeStore(repository: StubProductRepository(result: .failure(CancellationError())))

    store.dispatch(.appeared)
    await waitForPhase(.idle, in: store)

    #expect(store.state.phase == .idle)
  }

  @Test
  func `independent states receive favorite changes without reloading products`() async {
    favoriteRepository.save(productIDs: [2])
    let repository = StubProductRepository(result: .success([product]))
    let first = makeStore(repository: repository)
    let second = makeStore(repository: repository)
    first.dispatch(.appeared)
    second.dispatch(.appeared)
    defer {
      first.dispatch(.disappeared)
      second.dispatch(.disappeared)
    }
    await waitForProducts([product], in: first)
    await waitForProducts([product], in: second)

    first.dispatch(.favoriteButtonTapped(productID: product.id))
    await waitForProducts([favoriteProduct], in: first)
    await waitForProducts([favoriteProduct], in: second)
    second.dispatch(.favoriteButtonTapped(productID: product.id))
    await waitForProducts([product], in: first)
    await waitForProducts([product], in: second)
    #expect(first.state.phase == .loaded([product]))
    #expect(second.state.phase == .loaded([product]))
    #expect(repository.requestCount == 2)
  }

  @Test
  func `resubscribing restores changes made while observation was cancelled`() async {
    favoriteRepository.save(productIDs: [1])
    let repository = StubProductRepository(result: .success([product]))
    let store = makeStore(repository: repository)
    store.dispatch(.appeared)
    await waitForProducts([favoriteProduct], in: store)
    store.dispatch(.disappeared)

    favoriteUseCase.toggle(productID: 1)
    #expect(store.state.phase == .loaded([favoriteProduct]))
    store.dispatch(.appeared)
    defer { store.dispatch(.disappeared) }
    await waitForProducts([product], in: store)
    #expect(store.state.phase == .loaded([product]))
    #expect(repository.requestCount == 1)
  }

  @Test
  func `switching layouts preserves products and favorites without refetching`() async {
    let repository = StubProductRepository(result: .success([product]))
    let store = makeStore(repository: repository)
    #expect(store.state.layout == .list)
    store.dispatch(.appeared)
    await waitForProducts([product], in: store)

    store.dispatch(.layoutChanged(.grid))
    #expect(store.state.layout == .grid)
    #expect(store.state.phase == .loaded([product]))
    store.dispatch(.favoriteButtonTapped(productID: product.id))
    await waitForProducts([favoriteProduct], in: store)
    store.dispatch(.layoutChanged(.list))
    #expect(store.state.layout == .list)
    #expect(store.state.phase == .loaded([favoriteProduct]))

    store.dispatch(.layoutChanged(.grid))
    store.dispatch(.disappeared)
    store.dispatch(.appeared)
    defer { store.dispatch(.disappeared) }
    await waitForProducts([favoriteProduct], in: store)
    #expect(store.state.layout == .grid)
    #expect(repository.requestCount == 1)
  }

  @Test
  func `layout selection survives loading and retry`() async {
    let repository = StubProductRepository(result: .failure(TestError.offline))
    let store = makeStore(repository: repository)
    store.dispatch(.layoutChanged(.grid))
    store.dispatch(.appeared)
    await waitForPhase(.failed, in: store)
    #expect(store.state.phase == .failed)
    repository.result = .success([product])
    store.dispatch(.retryButtonTapped)
    defer { store.dispatch(.disappeared) }
    await waitForProducts([product], in: store)
    #expect(store.state.layout == .grid)
  }

  @Test
  func `reducer changes state without executing network or storage work`() {
    let repository = StubProductRepository(result: .success([product]))
    let reducer = ProductListReducer(
      productListUseCase: ProductListUseCase(productRepository: repository, favoriteRepository: favoriteRepository),
      favoriteUseCase: favoriteUseCase,
    )
    var state = reducer.initialState
    _ = reducer.reduce(state: &state, action: .appeared)
    #expect(state.phase == .loading)
    #expect(state.isObserving)
    #expect(repository.requestCount == 0)

    _ = reducer.reduce(state: &state, action: .productsUpdated([product]))
    _ = reducer.reduce(state: &state, action: .favoriteButtonTapped(productID: product.id))
    #expect(state.phase == .loaded([product]))
    #expect(favoriteRepository.fetchProductIDs().isEmpty)

    _ = reducer.reduce(state: &state, action: .disappeared)
    #expect(!state.isObserving)
    #expect(state.phase == .loaded([product]))
  }

  private func waitForPhase(_ phase: ProductListReducer.ProductListPhase, in store: StoreOf<ProductListReducer>) async {
    while store.state.phase != phase {
      await withCheckedContinuation { continuation in
        withObservationTracking {
          _ = store.state.phase
        } onChange: {
          continuation.resume()
        }
      }
    }
  }

  private func makeStore(repository: any ProductRepository) -> StoreOf<ProductListReducer> {
    Store(reducer: ProductListReducer(
      productListUseCase: ProductListUseCase(productRepository: repository, favoriteRepository: favoriteRepository),
      favoriteUseCase: favoriteUseCase,
    ))
  }

  private func waitForProducts(_ expected: [Product], in store: StoreOf<ProductListReducer>) async {
    while store.state.phase != .loaded(expected) {
      await withCheckedContinuation { continuation in
        withObservationTracking {
          _ = store.state.phase
        } onChange: {
          continuation.resume()
        }
      }
    }
  }

  @Test
  func `ignores favorite actions for products that are not displayed`() async {
    let store = makeStore(repository: StubProductRepository(result: .success([product])))
    store.dispatch(.favoriteButtonTapped(productID: product.id))
    #expect(favoriteRepository.fetchProductIDs().isEmpty)
    store.dispatch(.appeared)
    defer { store.dispatch(.disappeared) }
    await waitForProducts([product], in: store)
    store.dispatch(.favoriteButtonTapped(productID: 999))
    #expect(favoriteRepository.fetchProductIDs().isEmpty)
  }

  private var product: Product {
    Product(id: 1, title: "Sample product", price: 9.99, thumbnail: nil, isFavorite: false)
  }

  private var favoriteProduct: Product {
    var product = product
    product.isFavorite = true
    return product
  }

  private enum TestError: Error {
    case offline
  }
}
