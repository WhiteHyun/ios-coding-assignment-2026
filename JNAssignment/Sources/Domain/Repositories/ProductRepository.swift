@MainActor
protocol ProductRepository {
  func fetchProducts() async throws -> [Product]
}
