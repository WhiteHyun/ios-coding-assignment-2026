@MainActor
struct ProductDetailUseCase {
  private let productRepository: any ProductRepository
  private let favoriteRepository: any FavoriteRepository

  init(productRepository: any ProductRepository, favoriteRepository: any FavoriteRepository) {
    self.productRepository = productRepository
    self.favoriteRepository = favoriteRepository
  }

  func observeProduct(id: Int) async throws -> AsyncMapSequence<AsyncStream<Set<Int>>, Product> {
    let product = try await productRepository.fetchProduct(id: id)
    try Task.checkCancellation()
    return favoriteRepository.observeProductIDs().map { productIDs in
      var product = product
      product.isFavorite = productIDs.contains(product.id)
      return product
    }
  }
}
