import Foundation
import Networker
import Testing
@testable import JNAssignment

@MainActor
struct RemoteProductRepositoryTests {
  @Test
  func `requests the product list and unwraps the server response`() async throws {
    let session = makeSession(scenario: .products)
    defer { session.invalidateAndCancel() }
    let repository = RemoteProductRepository(provider: APIProvider(session: session))

    let products = try await repository.fetchProducts()

    #expect(products.count == 1)
    let product = try #require(products.first)
    #expect(product.id == 1)
    #expect(product.title == "Sample product")
    #expect(product.price == 9.99)
    #expect(product.thumbnail?.absoluteString == "https://example.com/image.png")
  }

  @Test
  func `keeps products without a thumbnail`() async throws {
    let session = makeSession(scenario: .productsWithoutThumbnail)
    defer { session.invalidateAndCancel() }
    let repository = RemoteProductRepository(provider: APIProvider(session: session))

    let products = try await repository.fetchProducts()

    #expect(products.count == 1)
    #expect(products.first?.thumbnail == nil)
  }

  @Test
  func `keeps the product when the raw thumbnail cannot become a URL`() async throws {
    let session = makeSession(scenario: .productsInvalidThumbnail)
    defer { session.invalidateAndCancel() }
    let repository = RemoteProductRepository(provider: APIProvider(session: session))

    let products = try await repository.fetchProducts()

    let product = try #require(products.first)
    #expect(product.id == 1)
    #expect(product.thumbnail == nil)
  }

  @Test
  func `translates URLSession cancellation for the feature layer`() async {
    let session = makeSession(scenario: .cancelled)
    defer { session.invalidateAndCancel() }
    let repository = RemoteProductRepository(provider: APIProvider(session: session))

    await #expect(throws: CancellationError.self) {
      try await repository.fetchProducts()
    }
  }

  @Test
  func `preserves an HTTP service unavailable response for the caller`() async {
    let session = makeSession(scenario: .serviceUnavailable)
    defer { session.invalidateAndCancel() }
    let repository = RemoteProductRepository(provider: APIProvider(session: session))

    await #expect {
      try await repository.fetchProducts()
    } throws: { error in
      if case .failureResponse(statusCode: 503) = error as? NetworkError {
        return true
      }
      return false
    }
  }

  private func makeSession(scenario: ProductURLProtocol.Scenario) -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [ProductURLProtocol.self]
    configuration.httpAdditionalHeaders = [ProductURLProtocol.scenarioHeader: scenario.rawValue]
    configuration.urlCache = nil
    return URLSession(configuration: configuration)
  }
}
