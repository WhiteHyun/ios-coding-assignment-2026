import DependencyInjection

@MainActor
final class ProductListUseCase {
  @Dependency private var productRepository: any ProductRepository
  @Dependency private var favoriteRepository: any FavoriteRepository
  private var cachedProducts: [Product]?

  init() {
  }

  init(productRepository: any ProductRepository, favoriteRepository: any FavoriteRepository) {
    _productRepository = Dependency(wrappedValue: productRepository)
    _favoriteRepository = Dependency(wrappedValue: favoriteRepository)
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
