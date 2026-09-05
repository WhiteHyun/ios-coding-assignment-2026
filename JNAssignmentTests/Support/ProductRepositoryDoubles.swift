import Foundation
@testable import JNAssignment

// MARK: - StubProductRepository

@MainActor
final class StubProductRepository: ProductRepository {
  var result: Result<[Product], any Error>
  var detailResult: Result<ProductDetail, any Error>?
  private(set) var requestCount = 0
  private(set) var detailRequestIDs: [Int] = []

  init(result: Result<[Product], any Error>) {
    self.result = result
  }

  func fetchProduct(id: Int) async throws -> ProductDetail {
    detailRequestIDs.append(id)
    guard let detailResult else { throw URLError(.resourceUnavailable) }
    return try detailResult.get()
  }

  func fetchProducts() async throws -> [Product] {
    requestCount += 1
    return try result.get()
  }
}

// MARK: - ControlledProductRepository

@MainActor
final class ControlledProductRepository: ProductRepository {
  private(set) var requestCount = 0
  private(set) var detailRequestIDs: [Int] = []
  private let requests: (stream: AsyncStream<Void>, continuation: AsyncStream<Void>.Continuation) = AsyncStream.makeStream()
  private var continuation: CheckedContinuation<[Product], any Error>?
  private var detailContinuation: CheckedContinuation<ProductDetail, any Error>?

  func fetchProducts() async throws -> [Product] {
    requestCount += 1
    return try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation
      requests.continuation.yield(())
    }
  }

  func fetchProduct(id: Int) async throws -> ProductDetail {
    detailRequestIDs.append(id)
    return try await withCheckedThrowingContinuation { continuation in
      detailContinuation = continuation
      requests.continuation.yield(())
    }
  }

  func waitForRequest() async {
    var iterator = requests.stream.makeAsyncIterator()
    await iterator.next()
  }

  func completeDetail(with result: Result<ProductDetail, any Error>) {
    detailContinuation?.resume(with: result)
    detailContinuation = nil
  }

  func complete(with result: Result<[Product], any Error>) {
    continuation?.resume(with: result)
    continuation = nil
  }
}
