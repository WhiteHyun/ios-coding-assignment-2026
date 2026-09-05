import Testing
@testable import JNAssignment

@MainActor
struct ProductListInteractorTests {
  @Test
  func `loads products on first appearance and preserves them on subsequent appearances`() async {
    let repository = StubRepository(result: .success([product]))
    let interactor = ProductListInteractor(repository: repository)

    #expect(interactor.state == .idle)
    #expect(repository.requestCount == 0)

    await interactor.send(.task)
    #expect(interactor.state == .loaded([product]))

    await interactor.send(.task)
    #expect(repository.requestCount == 1)
    #expect(interactor.state == .loaded([product]))
  }

  @Test
  func `shows loading and ignores duplicate actions while a request is in flight`() async {
    let repository = ControlledRepository()
    let interactor = ProductListInteractor(repository: repository)
    let task = Task { await interactor.send(.task) }
    await repository.waitForRequest()

    #expect(interactor.state == .loading)
    await interactor.send(.task)
    await interactor.send(.retryButtonTapped)
    #expect(repository.requestCount == 1)

    repository.complete(with: .success([product]))
    await task.value
    #expect(interactor.state == .loaded([product]))
  }

  @Test
  func `an empty response is a successful load`() async {
    let interactor = ProductListInteractor(repository: StubRepository(result: .success([])))

    await interactor.send(.task)

    #expect(interactor.state == .loaded([]))
  }

  @Test
  func `a failed request can be retried`() async {
    let repository = StubRepository(result: .failure(TestError.offline))
    let interactor = ProductListInteractor(repository: repository)

    await interactor.send(.task)
    #expect(interactor.state == .failed)

    repository.result = .success([product])
    await interactor.send(.retryButtonTapped)
    #expect(repository.requestCount == 2)
    #expect(interactor.state == .loaded([product]))
  }

  @Test
  func `cancellation discards a late response and allows a later appearance to load again`() async {
    let repository = ControlledRepository()
    let interactor = ProductListInteractor(repository: repository)
    let firstTask = Task { await interactor.send(.task) }
    await repository.waitForRequest()

    firstTask.cancel()
    repository.complete(with: .success([product]))
    await firstTask.value
    #expect(interactor.state == .idle)

    let secondTask = Task { await interactor.send(.task) }
    await repository.waitForRequest()
    repository.complete(with: .success([product]))
    await secondTask.value
    #expect(repository.requestCount == 2)
    #expect(interactor.state == .loaded([product]))
  }

  @Test
  func `repository cancellation does not display an error`() async {
    let interactor = ProductListInteractor(repository: StubRepository(result: .failure(CancellationError())))

    await interactor.send(.task)

    #expect(interactor.state == .idle)
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
