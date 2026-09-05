import DependencyInjection

@MainActor
struct FavoriteUseCase {
  @Dependency private var repository: any FavoriteRepository

  init() {
  }

  init(repository: any FavoriteRepository) {
    _repository = Dependency(wrappedValue: repository)
  }

  func toggle(productID: Int) {
    var productIDs = repository.fetchProductIDs()
    if !productIDs.insert(productID).inserted {
      productIDs.remove(productID)
    }
    repository.save(productIDs: productIDs)
  }
}
