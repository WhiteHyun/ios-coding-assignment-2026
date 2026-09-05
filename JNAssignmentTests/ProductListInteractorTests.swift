import Observation
import Testing
@testable import JNAssignment

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ProductListInteractorTests {
  private let favoriteRepository: LocalFavoriteRepository = .init(storage: InMemoryStorage())

  private var favoriteUseCase: FavoriteUseCase {
    FavoriteUseCase(repository: favoriteRepository)
  }

  @Test
  func `loads products on first appearance and preserves them on subsequent appearances`() async {
    let repository = StubProductRepository(result: .success([product]))
    let interactor = makeInteractor(repository: repository)

    #expect(interactor.state.phase == .idle)
    #expect(repository.requestCount == 0)

    let observation = Task { await interactor.send(.task) }
    defer { observation.cancel() }
    await waitForProducts([product], in: interactor)

    await interactor.send(.task)
    #expect(repository.requestCount == 1)
    #expect(interactor.state.phase == .loaded([product]))
  }

  @Test
  func `shows loading and ignores duplicate actions while a request is in flight`() async {
    let repository = ControlledProductRepository()
    let interactor = makeInteractor(repository: repository)
    let task = Task { await interactor.send(.task) }
    await repository.waitForRequest()

    #expect(interactor.state.phase == .loading)
    await interactor.send(.task)
    await interactor.send(.retryButtonTapped)
    #expect(repository.requestCount == 1)

    repository.complete(with: .success([product]))
    await waitForProducts([product], in: interactor)
    task.cancel()
    await task.value
  }

  @Test
  func `a late product response is combined with the latest saved favorites`() async {
    let repository = ControlledProductRepository()
    let interactor = makeInteractor(repository: repository)
    let loading = Task { await interactor.send(.task) }
    await repository.waitForRequest()

    favoriteRepository.save(productIDs: [product.id])
    repository.complete(with: .success([product]))
    await waitForProducts([favoriteProduct], in: interactor)
    loading.cancel()
    await loading.value
  }

  @Test
  func `an empty response is a successful load`() async {
    let interactor = makeInteractor(repository: StubProductRepository(result: .success([])))

    let observation = Task { await interactor.send(.task) }
    defer { observation.cancel() }
    await waitForProducts([], in: interactor)
  }

  @Test
  func `a failed request can be retried`() async {
    let repository = StubProductRepository(result: .failure(TestError.offline))
    let interactor = makeInteractor(repository: repository)

    await interactor.send(.task)
    #expect(interactor.state.phase == .failed)

    repository.result = .success([product])
    await interactor.send(.retryButtonTapped)
    #expect(interactor.state.retryCount == 1)
    #expect(interactor.state.phase == .idle)
    let retry = Task { await interactor.send(.task) }
    defer { retry.cancel() }
    await waitForProducts([product], in: interactor)
    #expect(repository.requestCount == 2)
    #expect(interactor.state.phase == .loaded([product]))
  }

  @Test
  func `cancellation discards a late response and allows a later appearance to load again`() async {
    let repository = ControlledProductRepository()
    let interactor = makeInteractor(repository: repository)
    let firstTask = Task { await interactor.send(.task) }
    await repository.waitForRequest()

    firstTask.cancel()
    repository.complete(with: .success([product]))
    await firstTask.value
    #expect(interactor.state.phase == .idle)

    let secondTask = Task { await interactor.send(.task) }
    await repository.waitForRequest()
    repository.complete(with: .success([product]))
    await waitForProducts([product], in: interactor)
    secondTask.cancel()
    await secondTask.value
    #expect(repository.requestCount == 2)
    #expect(interactor.state.phase == .loaded([product]))
  }

  @Test
  func `repository cancellation does not display an error`() async {
    let interactor = makeInteractor(repository: StubProductRepository(result: .failure(CancellationError())))

    await interactor.send(.task)

    #expect(interactor.state.phase == .idle)
  }

  @Test
  func `independent states receive favorite changes without reloading products`() async {
    favoriteRepository.save(productIDs: [2])
    let repository = StubProductRepository(result: .success([product]))
    let first = makeInteractor(repository: repository)
    let second = makeInteractor(repository: repository)
    let firstObservation = Task { await first.send(.task) }
    let secondObservation = Task { await second.send(.task) }
    defer {
      firstObservation.cancel()
      secondObservation.cancel()
    }
    await waitForProducts([product], in: first)
    await waitForProducts([product], in: second)

    await first.send(.favoriteButtonTapped(productID: product.id))
    await waitForProducts([favoriteProduct], in: first)
    await waitForProducts([favoriteProduct], in: second)
    await second.send(.favoriteButtonTapped(productID: product.id))
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
    let interactor = makeInteractor(repository: repository)
    let observation = Task { await interactor.send(.task) }
    await waitForProducts([favoriteProduct], in: interactor)
    observation.cancel()
    await observation.value

    favoriteUseCase.toggle(productID: 1)
    #expect(interactor.state.phase == .loaded([favoriteProduct]))
    let resumedObservation = Task { await interactor.send(.task) }
    defer { resumedObservation.cancel() }
    await waitForProducts([product], in: interactor)
    #expect(interactor.state.phase == .loaded([product]))
    #expect(repository.requestCount == 1)
  }

  private func makeInteractor(repository: any ProductRepository) -> ProductListInteractor {
    ProductListInteractor(
      productListUseCase: ProductListUseCase(productRepository: repository, favoriteRepository: favoriteRepository),
      favoriteUseCase: favoriteUseCase,
    )
  }

  private func waitForProducts(_ expected: [Product], in interactor: ProductListInteractor) async {
    while interactor.state.phase != .loaded(expected) {
      await withCheckedContinuation { continuation in
        withObservationTracking {
          _ = interactor.state.phase
        } onChange: {
          continuation.resume()
        }
      }
    }
  }

  @Test
  func `ignores favorite actions for products that are not displayed`() async {
    let interactor = makeInteractor(repository: StubProductRepository(result: .success([product])))
    await interactor.send(.favoriteButtonTapped(productID: product.id))
    #expect(favoriteRepository.fetchProductIDs().isEmpty)
    let observation = Task { await interactor.send(.task) }
    defer { observation.cancel() }
    await waitForProducts([product], in: interactor)
    await interactor.send(.favoriteButtonTapped(productID: 999))
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
