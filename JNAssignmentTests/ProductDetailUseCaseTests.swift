import Testing
@testable import JNAssignment

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ProductDetailUseCaseTests {
  @Test
  func `fetches the requested detail and updates favorites without refetching`() async throws {
    let product = Product(id: 42, title: "Detail", price: 29.99, thumbnail: nil, description: "Description", isFavorite: false)
    let repository = StubProductRepository(result: .success([product]))
    let favorites = LocalFavoriteRepository(storage: InMemoryStorage())
    favorites.save(productIDs: [42])
    let useCase = ProductDetailUseCase(productRepository: repository, favoriteRepository: favorites)
    var iterator = try await useCase.observeProduct(id: 42).makeAsyncIterator()
    var favoriteProduct = product
    favoriteProduct.isFavorite = true

    #expect(await iterator.next() == favoriteProduct)
    favorites.save(productIDs: [])
    #expect(await iterator.next() == product)
    #expect(repository.detailRequestIDs == [42])
    #expect(repository.requestCount == 0)
  }
}
