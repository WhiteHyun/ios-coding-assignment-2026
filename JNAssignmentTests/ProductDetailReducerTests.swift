import Architecture
import DependencyInjection
import Observation
import Testing
@testable import JNAssignment

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ProductDetailReducerTests {
  private let favorites: LocalFavoriteRepository = .init(storage: InMemoryStorage())
  private let product: ProductDetail = .init(
    id: 1,
    title: "Detail",
    price: 9.99,
    description: "Description",
    images: [],
    brand: nil,
    category: "beauty",
    rating: 4.5,
    stock: 10,
    isFavorite: false,
  )

  @Test
  func `detail unfavorite is reflected on returning to the list and changes flow both ways`() async {
    favorites.save(productIDs: [1])
    let listProduct = Product(id: 1, title: "List", price: 9.99, thumbnail: nil, isFavorite: false)
    let repository = StubProductRepository(result: .success([listProduct]))
    repository.detailResult = .success(product)
    var favoriteListProduct = listProduct
    favoriteListProduct.isFavorite = true
    registerDependencies(repository: repository)
    let list = Store(reducer: ProductListReducer())
    let detail = makeStore(repository: repository)
    var favoriteProduct = product
    favoriteProduct.isFavorite = true
    list.dispatch(.appeared)
    await waitForList([favoriteListProduct], in: list)
    list.dispatch(.disappeared)

    detail.dispatch(.appeared)
    defer { detail.dispatch(.disappeared) }
    await waitForDetail(favoriteProduct, in: detail)
    detail.dispatch(.favoriteButtonTapped)
    await waitForDetail(product, in: detail)
    #expect(list.state.phase == .loaded([favoriteListProduct]))

    list.dispatch(.appeared)
    defer { list.dispatch(.disappeared) }
    await waitForList([listProduct], in: list)
    list.dispatch(.favoriteButtonTapped(productID: 1))
    await waitForDetail(favoriteProduct, in: detail)
    await waitForList([favoriteListProduct], in: list)
    #expect(repository.requestCount == 1)
    #expect(repository.detailRequestIDs == [1])
  }

  @Test
  func `failed detail requests can be retried without changing favorites before loading`() async {
    let repository = StubProductRepository(result: .success([]))
    repository.detailResult = .failure(TestError.offline)
    let store = makeStore(repository: repository)
    store.dispatch(.favoriteButtonTapped)
    #expect(favorites.fetchProductIDs().isEmpty)
    store.dispatch(.appeared)
    await waitForPhase(.failed, in: store)
    #expect(store.state.phase == .failed)
    store.dispatch(.favoriteButtonTapped)
    #expect(favorites.fetchProductIDs().isEmpty)

    repository.detailResult = .success(product)
    store.dispatch(.retryButtonTapped)
    defer { store.dispatch(.disappeared) }
    await waitForDetail(product, in: store)
    #expect(repository.detailRequestIDs == [1, 1])
  }

  @Test
  func `cancelled late responses are discarded and a new appearance fetches detail again`() async {
    let repository = ControlledProductRepository()
    let store = makeStore(repository: repository)
    store.dispatch(.appeared)
    await repository.waitForRequest()
    #expect(store.state.phase == .loading)
    store.dispatch(.appeared)
    #expect(repository.detailRequestIDs == [1])
    store.dispatch(.disappeared)
    repository.completeDetail(with: .success(product))
    #expect(store.state.phase == .idle)

    store.dispatch(.appeared)
    defer { store.dispatch(.disappeared) }
    await repository.waitForRequest()
    favorites.save(productIDs: [1])
    repository.completeDetail(with: .success(product))
    var favoriteProduct = product
    favoriteProduct.isFavorite = true
    await waitForDetail(favoriteProduct, in: store)
    #expect(repository.detailRequestIDs == [1, 1])
  }

  @Test
  func `returning to a loaded detail fetches updated server information`() async {
    let repository = StubProductRepository(result: .success([]))
    repository.detailResult = .success(product)
    let store = makeStore(repository: repository)
    store.dispatch(.appeared)
    await waitForDetail(product, in: store)
    store.dispatch(.disappeared)

    let updated = ProductDetail(
      id: product.id,
      title: "Updated detail",
      price: product.price,
      description: product.description,
      images: product.images,
      brand: product.brand,
      category: product.category,
      rating: product.rating,
      stock: product.stock,
      isFavorite: false,
    )
    repository.detailResult = .success(updated)
    store.dispatch(.appeared)
    defer { store.dispatch(.disappeared) }
    await waitForDetail(updated, in: store)
    #expect(repository.detailRequestIDs == [product.id, product.id])
  }

  private func waitForPhase(_ phase: ProductDetailReducer.ProductDetailPhase, in store: StoreOf<ProductDetailReducer>) async {
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

  private func makeStore(repository: any ProductRepository) -> StoreOf<ProductDetailReducer> {
    registerDependencies(repository: repository)
    return Store(reducer: ProductDetailReducer(productID: product.id))
  }

  private func registerDependencies(repository: any ProductRepository) {
    let container = DIContainer.shared
    container.register(
      type: ProductListUseCase.self,
      ProductListUseCase(productRepository: repository, favoriteRepository: favorites),
    )
    container.register(
      type: ProductDetailUseCase.self,
      ProductDetailUseCase(productRepository: repository, favoriteRepository: favorites),
    )
    container.register(type: FavoriteUseCase.self, FavoriteUseCase(repository: favorites))
  }

  private func waitForDetail(_ product: ProductDetail, in store: StoreOf<ProductDetailReducer>) async {
    while store.state.phase != .loaded(product) {
      await withCheckedContinuation { continuation in
        withObservationTracking {
          _ = store.state.phase
        } onChange: {
          continuation.resume()
        }
      }
    }
  }

  private func waitForList(_ products: [Product], in store: StoreOf<ProductListReducer>) async {
    while store.state.phase != .loaded(products) {
      await withCheckedContinuation { continuation in
        withObservationTracking {
          _ = store.state.phase
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
