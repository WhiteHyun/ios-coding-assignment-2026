@MainActor
final class ProductListUseCase {
  private let productRepository: any ProductRepository
  private let favoriteRepository: any FavoriteRepository
  private var cachedProducts: [Product]?

  init(productRepository: any ProductRepository, favoriteRepository: any FavoriteRepository) {
    self.productRepository = productRepository
    self.favoriteRepository = favoriteRepository
  }

  func observeProducts() async throws -> AsyncMapSequence<AsyncStream<Set<Int>>, [Product]> {
    let products: [Product]
    if let cachedProducts {
      products = cachedProducts
    } else {
      products = try await productRepository.fetchProducts()
      try Task.checkCancellation()
      cachedProducts = products
    }

    return favoriteRepository.observeProductIDs().map { productIDs in
      products.map { product in
        var product = product
        product.isFavorite = productIDs.contains(product.id)
        return product
      }
    }
  }
}
