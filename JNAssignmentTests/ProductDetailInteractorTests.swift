import Observation
import Testing
@testable import JNAssignment

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ProductDetailInteractorTests {
  private let favorites: LocalFavoriteRepository = .init(storage: InMemoryStorage())
  private let product: Product = .init(
    id: 1,
    title: "Detail",
    price: 9.99,
    thumbnail: nil,
    description: "Description",
    isFavorite: false,
  )

  @Test
  func `detail unfavorite is reflected on returning to the list and changes flow both ways`() async {
    favorites.save(productIDs: [1])
    let repository = StubProductRepository(result: .success([product]))
    let list = ProductListInteractor(
      productListUseCase: ProductListUseCase(productRepository: repository, favoriteRepository: favorites),
      favoriteUseCase: FavoriteUseCase(repository: favorites),
    )
    let detail = makeInteractor(repository: repository)
    var favoriteProduct = product
    favoriteProduct.isFavorite = true
    let listTask = Task { await list.send(.task) }
    await waitForList([favoriteProduct], in: list)
    listTask.cancel()
    await listTask.value

    let detailTask = Task { await detail.send(.task) }
    defer { detailTask.cancel() }
    await waitForDetail(favoriteProduct, in: detail)
    await detail.send(.favoriteButtonTapped)
    await waitForDetail(product, in: detail)
    #expect(list.state.phase == .loaded([favoriteProduct]))

    let resumedList = Task { await list.send(.task) }
    defer { resumedList.cancel() }
    await waitForList([product], in: list)
    await list.send(.favoriteButtonTapped(productID: 1))
    await waitForDetail(favoriteProduct, in: detail)
    await waitForList([favoriteProduct], in: list)
    #expect(repository.requestCount == 1)
    #expect(repository.detailRequestIDs == [1])
  }

  @Test
  func `failed detail requests can be retried without changing favorites before loading`() async {
    let repository = StubProductRepository(result: .failure(TestError.offline))
    let interactor = makeInteractor(repository: repository)
    await interactor.send(.favoriteButtonTapped)
    #expect(favorites.fetchProductIDs().isEmpty)
    await interactor.send(.task)
    #expect(interactor.state.phase == .failed)
    await interactor.send(.favoriteButtonTapped)
    #expect(favorites.fetchProductIDs().isEmpty)

    repository.result = .success([product])
    await interactor.send(.retryButtonTapped)
    #expect(interactor.state.retryCount == 1)
    let retry = Task { await interactor.send(.task) }
    defer { retry.cancel() }
    await waitForDetail(product, in: interactor)
    #expect(repository.detailRequestIDs == [1, 1])
  }

  @Test
  func `cancelled late responses are discarded and a new appearance fetches detail again`() async {
    let repository = ControlledProductRepository()
    let interactor = makeInteractor(repository: repository)
    let first = Task { await interactor.send(.task) }
    await repository.waitForRequest()
    #expect(interactor.state.phase == .loading)
    await interactor.send(.task)
    #expect(repository.detailRequestIDs == [1])
    first.cancel()
    repository.complete(with: .success([product]))
    await first.value
    #expect(interactor.state.phase == .idle)

    let next = Task { await interactor.send(.task) }
    defer { next.cancel() }
    await repository.waitForRequest()
    favorites.save(productIDs: [1])
    repository.complete(with: .success([product]))
    var favoriteProduct = product
    favoriteProduct.isFavorite = true
    await waitForDetail(favoriteProduct, in: interactor)
    #expect(repository.detailRequestIDs == [1, 1])
  }

  private func makeInteractor(repository: any ProductRepository) -> ProductDetailInteractor {
    ProductDetailInteractor(
      productID: product.id,
      productDetailUseCase: ProductDetailUseCase(productRepository: repository, favoriteRepository: favorites),
      favoriteUseCase: FavoriteUseCase(repository: favorites),
    )
  }

  private func waitForDetail(_ product: Product, in interactor: ProductDetailInteractor) async {
    while interactor.state.phase != .loaded(product) {
      await withCheckedContinuation { continuation in
        withObservationTracking {
          _ = interactor.state.phase
        } onChange: {
          continuation.resume()
        }
      }
    }
  }

  private func waitForList(_ products: [Product], in interactor: ProductListInteractor) async {
    while interactor.state.phase != .loaded(products) {
      await withCheckedContinuation { continuation in
        withObservationTracking {
          _ = interactor.state.phase
        } onChange: {
          continuation.resume()
        }
      }
    }
  }

  private enum TestError: Error {
    case offline
  }
}
