import Foundation
import Networker
import Testing
@testable import JNAssignment

@MainActor
struct RemoteProductRepositoryTests {
  @Test
  func `requests a specific product and decodes detail images and information`() async throws {
    let session = makeSession(scenario: .productDetail)
    defer { session.invalidateAndCancel() }
    let repository = RemoteProductRepository(provider: APIProvider(session: session))

    let product = try await repository.fetchProduct(id: 42)

    #expect(product.id == 42)
    #expect(product.title == "Detail product")
    #expect(product.description == "Product description from the detail API.")
    #expect(product.price == 29.99)
    #expect(product.images.map(\.absoluteString) == ["https://example.com/detail-1.png", "https://example.com/detail-2.png"])
    #expect(product.brand == "Example")
    #expect(product.category == "beauty")
    #expect(product.rating == 4.25)
    #expect(product.stock == 12)
    #expect(!product.isFavorite)
  }

  @Test
  func `invalid detail images fall back to the thumbnail and a missing brand is allowed`() async throws {
    let session = makeSession(scenario: .productDetailWithoutImages)
    defer { session.invalidateAndCancel() }
    let repository = RemoteProductRepository(provider: APIProvider(session: session))

    let product = try await repository.fetchProduct(id: 42)

    #expect(product.images.map(\.absoluteString) == ["https://example.com/detail.png"])
    #expect(product.brand == nil)
    #expect(product.title == "Detail product")
  }

  @Test
  func `detail cancellation is translated and not found errors are preserved`() async {
    let cancelled = makeSession(scenario: .detailCancelled)
    let notFound = makeSession(scenario: .detailNotFound)
    defer {
      cancelled.invalidateAndCancel()
      notFound.invalidateAndCancel()
    }
    await #expect(throws: CancellationError.self) {
      try await RemoteProductRepository(provider: APIProvider(session: cancelled)).fetchProduct(id: 42)
    }
    await #expect {
      try await RemoteProductRepository(provider: APIProvider(session: notFound)).fetchProduct(id: 42)
    } throws: { error in
      if case .failureResponse(statusCode: 404) = error as? NetworkError {
        return true
      }
      return false
    }
  }

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
