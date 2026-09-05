import Networker

struct RemoteProductRepository: ProductRepository {
  private let provider: any Providable

  init(provider: any Providable) {
    self.provider = provider
  }

  func fetchProducts() async throws -> [Product] {
    let response: ProductListResponse
    do {
      response = try await provider.request(ProductListEndpoint())
    } catch {
      if case .cancelled = error {
        throw CancellationError()
      }
      throw error
    }
    return response.products.map { $0.toDomain() }
  }
}
