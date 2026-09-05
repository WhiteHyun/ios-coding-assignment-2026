import Foundation

final class ProductURLProtocol: URLProtocol {
  enum Scenario: String {
    case products
    case productsWithoutThumbnail = "products-without-thumbnail"
    case productsInvalidThumbnail = "products-invalid-thumbnail"
    case cancelled
    case serviceUnavailable
  }

  static let scenarioHeader = "X-Test-Scenario"

  override class func canInit(with _: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    do {
      guard
        let url = request.url,
        url.absoluteString == "https://dummyjson.com/products",
        request.httpMethod == "GET",
        request.httpBody == nil,
        request.httpBodyStream == nil,
        let scenarioName = request.value(forHTTPHeaderField: Self.scenarioHeader),
        let scenario = Scenario(rawValue: scenarioName)
      else {
        throw URLError(.badURL)
      }

      if scenario == .cancelled {
        throw URLError(.cancelled)
      }

      let statusCode = scenario == .serviceUnavailable ? 503 : 200
      guard let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil) else {
        throw URLError(.badServerResponse)
      }

      let data: Data
      if scenario == .serviceUnavailable {
        data = Data()
      } else {
        guard let fixtureURL = Bundle(for: Self.self).url(forResource: scenario.rawValue, withExtension: "json") else {
          throw URLError(.fileDoesNotExist)
        }
        data = try Data(contentsOf: fixtureURL)
      }

      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {
  }
}
