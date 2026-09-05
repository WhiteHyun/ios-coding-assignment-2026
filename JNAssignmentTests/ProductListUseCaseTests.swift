import Testing
@testable import JNAssignment

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ProductListUseCaseTests {
  @Test
  func `emits complete products and updates favorites without fetching again`() async throws {
    let first = Product(id: 1, title: "First", price: 9.99, thumbnail: nil, isFavorite: false)
    let second = Product(id: 2, title: "Second", price: 19.99, thumbnail: nil, isFavorite: true)
    let repository = StubProductRepository(result: .success([first, second]))
    let favorites = LocalFavoriteRepository(storage: InMemoryStorage())
    favorites.save(productIDs: [1, 99])
    let useCase = ProductListUseCase(productRepository: repository, favoriteRepository: favorites)
    var iterator = try await useCase.observeProducts().makeAsyncIterator()
    var expectedFirst = first
    expectedFirst.isFavorite = true
    var expectedSecond = second
    expectedSecond.isFavorite = false

    #expect(await iterator.next() == [expectedFirst, expectedSecond])
    favorites.save(productIDs: [])
    #expect(await iterator.next() == [first, expectedSecond])
    #expect(repository.requestCount == 1)
    #expect(!first.isFavorite)
    #expect(second.isFavorite)
  }

  @Test
  func `resubscription reuses fetched products with the current favorites`() async throws {
    let product = Product(id: 1, title: "Sample", price: 9.99, thumbnail: nil, isFavorite: false)
    let repository = StubProductRepository(result: .success([product]))
    let favorites = LocalFavoriteRepository(storage: InMemoryStorage())
    let useCase = ProductListUseCase(productRepository: repository, favoriteRepository: favorites)
    let updates = try await useCase.observeProducts()
    var first = updates.makeAsyncIterator()
    #expect(await first.next() == [product])
    let observation = Task {
      var iterator = updates.makeAsyncIterator()
      return await iterator.next()
    }
    observation.cancel()
    #expect(await observation.value == nil)

    favorites.save(productIDs: [1])
    var resumed = try await useCase.observeProducts().makeAsyncIterator()
    var favoriteProduct = product
    favoriteProduct.isFavorite = true
    #expect(await resumed.next() == [favoriteProduct])
    #expect(repository.requestCount == 1)
  }
}
