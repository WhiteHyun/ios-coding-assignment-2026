import DependencyInjection
import Testing
@testable import JNAssignment

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct AppDependenciesTests {
  @Test
  func `registered use cases share repositories while keeping list caches separate`() async throws {
    let container = DIContainer()
    AppDependencies.register(in: container)
    let product = Product(id: 1, title: "Product", price: 9.99, thumbnail: nil, isFavorite: false)
    let repository = StubProductRepository(result: .success([product]))
    let favorites = LocalFavoriteRepository(storage: InMemoryStorage())
    container.register(type: (any ProductRepository).self, repository)
    container.register(type: (any FavoriteRepository).self, favorites)

    let first = container.resolve(type: ProductListUseCase.self)
    let second = container.resolve(type: ProductListUseCase.self)
    #expect(first !== second)
    var firstUpdates = try await first.observeProducts().makeAsyncIterator()
    var secondUpdates = try await second.observeProducts().makeAsyncIterator()
    #expect(await firstUpdates.next() == [product])
    #expect(await secondUpdates.next() == [product])
    #expect(repository.requestCount == 2)

    container.resolve(type: FavoriteUseCase.self).toggle(productID: product.id)
    var favoriteProduct = product
    favoriteProduct.isFavorite = true
    #expect(await firstUpdates.next() == [favoriteProduct])
    #expect(await secondUpdates.next() == [favoriteProduct])
    var resumedUpdates = try await first.observeProducts().makeAsyncIterator()
    #expect(await resumedUpdates.next() == [favoriteProduct])
    #expect(repository.requestCount == 2)
  }

  @Test
  func `registered detail use case resolves repositories from its own container`() async throws {
    let container = DIContainer()
    AppDependencies.register(in: container)
    let repository = StubProductRepository(result: .success([]))
    let product = ProductDetail(
      id: 7,
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
    repository.detailResult = .success(product)
    let favorites = LocalFavoriteRepository(storage: InMemoryStorage())
    favorites.save(productIDs: [product.id])
    container.register(type: (any ProductRepository).self, repository)
    container.register(type: (any FavoriteRepository).self, favorites)

    let useCase = container.resolve(type: ProductDetailUseCase.self)
    var updates = try await useCase.observeProduct(id: product.id).makeAsyncIterator()
    var expected = product
    expected.isFavorite = true
    #expect(await updates.next() == expected)
    #expect(repository.detailRequestIDs == [product.id])
  }
}
