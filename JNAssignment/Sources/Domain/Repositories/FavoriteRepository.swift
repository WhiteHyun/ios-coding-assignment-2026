@MainActor
protocol FavoriteRepository {
  func fetchProductIDs() -> Set<Int>
  func observeProductIDs() -> AsyncStream<Set<Int>>
  func save(productIDs: Set<Int>)
}
