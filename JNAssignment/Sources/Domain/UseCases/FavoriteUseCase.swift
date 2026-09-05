@MainActor
struct FavoriteUseCase {
  private let repository: any FavoriteRepository

  init(repository: any FavoriteRepository) {
    self.repository = repository
  }

  func fetchProductIDs() -> Set<Int> {
    repository.fetchProductIDs()
  }

  func observeProductIDs() -> AsyncStream<Set<Int>> {
    repository.observeProductIDs()
  }

  func toggle(productID: Int) {
    var productIDs = repository.fetchProductIDs()
    if !productIDs.insert(productID).inserted {
      productIDs.remove(productID)
    }
    repository.save(productIDs: productIDs)
  }
}
