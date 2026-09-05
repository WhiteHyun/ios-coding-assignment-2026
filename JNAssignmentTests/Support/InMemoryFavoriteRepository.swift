@testable import JNAssignment

@MainActor
final class InMemoryFavoriteRepository: FavoriteRepository {
  var productIDs: Set<Int>
  private(set) var saveCount = 0

  init(productIDs: Set<Int>) {
    self.productIDs = productIDs
  }

  func fetchProductIDs() -> Set<Int> {
    productIDs
  }

  func observeProductIDs() -> AsyncStream<Set<Int>> {
    AsyncStream { continuation in
      continuation.yield(productIDs)
      continuation.finish()
    }
  }

  func save(productIDs: Set<Int>) {
    self.productIDs = productIDs
    saveCount += 1
  }
}
