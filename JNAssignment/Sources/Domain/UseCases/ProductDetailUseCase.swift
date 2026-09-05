import DependencyInjection

@MainActor
struct ProductDetailUseCase {
  @Dependency private var productRepository: any ProductRepository
  @Dependency private var favoriteRepository: any FavoriteRepository

  init() {
  }

  init(productRepository: any ProductRepository, favoriteRepository: any FavoriteRepository) {
    _productRepository = Dependency(wrappedValue: productRepository)
    _favoriteRepository = Dependency(wrappedValue: favoriteRepository)
  }

  func observeProduct(id: Int) async throws -> AsyncMapSequence<AsyncStream<Set<Int>>, ProductDetail> {
    let product = try await productRepository.fetchProduct(id: id)
    try Task.checkCancellation()
    return favoriteRepository.observeProductIDs().map { productIDs in
      var product = product
      product.isFavorite = productIDs.contains(product.id)
      return product
    }
  }
}
