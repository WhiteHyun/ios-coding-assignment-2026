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
    let repository = StubRepository(result: .success([product]))
    let interactor = ProductListInteractor(repository: repository, favoriteUseCase: favoriteUseCase)

    #expect(interactor.state.phase == .idle)
    #expect(repository.requestCount == 0)

    await interactor.send(.task)
    #expect(interactor.state.phase == .loaded([product]))

    await interactor.send(.task)
    #expect(repository.requestCount == 1)
    #expect(interactor.state.phase == .loaded([product]))
  }

  @Test
  func `shows loading and ignores duplicate actions while a request is in flight`() async {
    let repository = ControlledRepository()
    let interactor = ProductListInteractor(repository: repository, favoriteUseCase: favoriteUseCase)
    let task = Task { await interactor.send(.task) }
    await repository.waitForRequest()

    #expect(interactor.state.phase == .loading)
    await interactor.send(.task)
    await interactor.send(.retryButtonTapped)
    #expect(repository.requestCount == 1)

    repository.complete(with: .success([product]))
    await task.value
    #expect(interactor.state.phase == .loaded([product]))
  }

  @Test
  func `an empty response is a successful load`() async {
    let interactor = ProductListInteractor(repository: StubRepository(result: .success([])), favoriteUseCase: favoriteUseCase)

    await interactor.send(.task)

    #expect(interactor.state.phase == .loaded([]))
  }

  @Test
  func `a failed request can be retried`() async {
    let repository = StubRepository(result: .failure(TestError.offline))
    let interactor = ProductListInteractor(repository: repository, favoriteUseCase: favoriteUseCase)

    await interactor.send(.task)
    #expect(interactor.state.phase == .failed)

    repository.result = .success([product])
    await interactor.send(.retryButtonTapped)
    #expect(repository.requestCount == 2)
    #expect(interactor.state.phase == .loaded([product]))
  }

  @Test
  func `cancellation discards a late response and allows a later appearance to load again`() async {
    let repository = ControlledRepository()
    let interactor = ProductListInteractor(repository: repository, favoriteUseCase: favoriteUseCase)
    let firstTask = Task { await interactor.send(.task) }
    await repository.waitForRequest()

    firstTask.cancel()
    repository.complete(with: .success([product]))
    await firstTask.value
    #expect(interactor.state.phase == .idle)

    let secondTask = Task { await interactor.send(.task) }
    await repository.waitForRequest()
    repository.complete(with: .success([product]))
    await secondTask.value
    #expect(repository.requestCount == 2)
    #expect(interactor.state.phase == .loaded([product]))
  }

  @Test
  func `repository cancellation does not display an error`() async {
    let interactor = ProductListInteractor(
      repository: StubRepository(result: .failure(CancellationError())),
      favoriteUseCase: favoriteUseCase,
    )

    await interactor.send(.task)

    #expect(interactor.state.phase == .idle)
  }

  @Test
  func `independent states receive favorite changes without reloading products`() async {
    favoriteRepository.save(productIDs: [2])
    let repository = StubRepository(result: .success([product]))
    let first = ProductListInteractor(repository: repository, favoriteUseCase: favoriteUseCase)
    let second = ProductListInteractor(repository: repository, favoriteUseCase: favoriteUseCase)
    await first.send(.task)
    await second.send(.task)
    let firstObservation = Task { await first.send(.observeFavorites) }
    let secondObservation = Task { await second.send(.observeFavorites) }
    defer {
      firstObservation.cancel()
      secondObservation.cancel()
    }
    await waitForFavorites([2], in: first)
    await waitForFavorites([2], in: second)

    await first.send(.favoriteButtonTapped(productID: product.id))
    await waitForFavorites([1, 2], in: first)
    await waitForFavorites([1, 2], in: second)
    await second.send(.favoriteButtonTapped(productID: product.id))
    await waitForFavorites([2], in: first)
    await waitForFavorites([2], in: second)
    #expect(first.state.phase == .loaded([product]))
    #expect(second.state.phase == .loaded([product]))
    #expect(repository.requestCount == 2)
  }

  @Test
  func `resubscribing restores changes made while observation was cancelled`() async {
    favoriteRepository.save(productIDs: [1])
    let repository = StubRepository(result: .success([product]))
    let interactor = ProductListInteractor(repository: repository, favoriteUseCase: favoriteUseCase)
    await interactor.send(.task)
    let observation = Task { await interactor.send(.observeFavorites) }
    await waitForFavorites([1], in: interactor)
    observation.cancel()
    await observation.value

    favoriteUseCase.toggle(productID: 1)
    #expect(interactor.state.favoriteIDs == [1])
    let resumedObservation = Task { await interactor.send(.observeFavorites) }
    defer { resumedObservation.cancel() }
    await waitForFavorites([], in: interactor)
    #expect(interactor.state.phase == .loaded([product]))
    #expect(repository.requestCount == 1)
  }

  private func waitForFavorites(_ expected: Set<Int>, in interactor: ProductListInteractor) async {
    while interactor.state.favoriteIDs != expected {
      await withCheckedContinuation { continuation in
        withObservationTracking {
          _ = interactor.state.favoriteIDs
        } onChange: {
          continuation.resume()
        }
      }
    }
  }

  @Test
  func `ignores favorite actions for products that are not displayed`() async {
    let interactor = ProductListInteractor(
      repository: StubRepository(result: .success([product])),
      favoriteUseCase: favoriteUseCase,
    )
    await interactor.send(.favoriteButtonTapped(productID: product.id))
    #expect(favoriteRepository.fetchProductIDs().isEmpty)
    await interactor.send(.task)
    await interactor.send(.favoriteButtonTapped(productID: 999))
    #expect(favoriteRepository.fetchProductIDs().isEmpty)
  }

  private var product: Product {
    Product(id: 1, title: "Sample product", price: 9.99, thumbnail: nil)
  }

  private enum TestError: Error {
    case offline
  }

  private final class StubRepository: ProductRepository {
    var result: Result<[Product], any Error>
    private(set) var requestCount = 0

    init(result: Result<[Product], any Error>) {
      self.result = result
    }

    func fetchProducts() async throws -> [Product] {
      requestCount += 1
      return try result.get()
    }
  }

  private final class ControlledRepository: ProductRepository {
    private(set) var requestCount = 0
    private let requests: (stream: AsyncStream<Void>, continuation: AsyncStream<Void>.Continuation) = AsyncStream.makeStream()
    private var continuation: CheckedContinuation<[Product], any Error>?

    func fetchProducts() async throws -> [Product] {
      requestCount += 1
      return try await withCheckedThrowingContinuation { continuation in
        self.continuation = continuation
        requests.continuation.yield(())
      }
    }

    func waitForRequest() async {
      var iterator = requests.stream.makeAsyncIterator()
      await iterator.next()
    }

    func complete(with result: Result<[Product], any Error>) {
      continuation?.resume(with: result)
      continuation = nil
    }
  }
}
