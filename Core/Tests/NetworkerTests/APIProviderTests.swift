import Foundation
import Testing
@testable import Networker

// MARK: - APIProviderTests

struct APIProviderTests {
  @Test
  func `infers the response type and builds a relative request`() async throws {
    let session = makeSession()
    defer { session.invalidateAndCancel() }
    let provider: any Providable = APIProvider(session: session)
    let endpoint = TestEndpoint(parameter: .query(["search": "coffee & tea", "page": "2", "available": "true"]))

    let response: RequestEcho = try await provider.request(endpoint)

    #expect(response.host == "dummyjson.com")
    #expect(response.path == "/products")
    #expect(response.method == "GET")
    #expect(response.query == ["search": "coffee & tea", "page": "2", "available": "true"])
    #expect(response.accept == "application/json")
  }

  @Test
  func `encodes a JSON body and respects explicit content type`() async throws {
    let session = makeSession()
    defer { session.invalidateAndCancel() }
    let provider = APIProvider(session: session)
    var endpoint = TestEndpoint(method: .post, parameter: .body(SearchQuery(search: "coffee", page: 1, available: false)))

    let response: RequestEcho = try await provider.request(endpoint)
    #expect(response.method == "POST")
    #expect(response.contentType == "application/json")
    let decoded = try JSONDecoder().decode(SearchQuery.self, from: Data(response.body.utf8))
    #expect(decoded == SearchQuery(search: "coffee", page: 1, available: false))

    endpoint.headers = [.contentType("application/vnd.example+json")]
    let custom: RequestEcho = try await provider.request(endpoint)
    #expect(custom.contentType == "application/vnd.example+json")
  }

  @Test(arguments: ["status", "non-http", "offline", "cancelled", "malformed", "empty"])
  func `classifies response and transport failures`(path: String) async throws {
    let session = makeSession()
    defer { session.invalidateAndCancel() }
    let provider = APIProvider(session: session)
    do {
      let _: RequestEcho = try await provider.request(TestEndpoint(url: .base(path: path)))
      Issue.record("Expected an error for \(path)")
    } catch {
      switch (path, error) {
      case ("status", .failureResponse(statusCode: 503)), ("non-http", .invalidResponse), ("cancelled", .cancelled):
        break
      case let ("offline", .transport(underlying)):
        #expect((underlying as? URLError)?.code == .notConnectedToInternet)
      case let ("malformed", .decoding(underlying)), let ("empty", .decoding(underlying)):
        #expect(underlying is DecodingError)
      default:
        Issue.record("Unexpected error for \(path): \(error)")
      }
    }
  }

  @Test
  func `preserves body encoding errors`() async throws {
    let session = makeSession()
    defer { session.invalidateAndCancel() }
    let provider = APIProvider(session: session)
    let endpoint = TestEndpoint(parameter: .body(FailingPayload()))
    do {
      let _: RequestEcho = try await provider.request(endpoint)
      Issue.record("Expected an encoding error")
    } catch {
      guard case let .encoding(underlying) = error else {
        Issue.record("Unexpected error: \(error)")
        return
      }
      #expect(underlying is PayloadError)
    }
  }

  @Test(arguments: [
    ("products", "https://dummyjson.com/products"),
    ("/products", "https://dummyjson.com/products"),
    ("products/1", "https://dummyjson.com/products/1"),
    ("products/red apple", "https://dummyjson.com/products/red%20apple"),
    ("", "https://dummyjson.com/"),
  ])
  func `resolves paths against the fixed base URL`(path: String, expected: String) throws {
    let url = try #require(EndpointURL.base(path: path).url)
    #expect(url.absoluteString == expected)
  }

  private func makeSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    configuration.urlCache = nil
    return URLSession(configuration: configuration)
  }

  @Test
  func `plain parameters send neither query nor body`() async throws {
    let session = makeSession()
    defer { session.invalidateAndCancel() }
    let response: RequestEcho = try await APIProvider(session: session).request(TestEndpoint())
    #expect(response.query.isEmpty)
    #expect(response.body.isEmpty)
    #expect(response.contentType.isEmpty)
  }

  @Test(arguments: [
    [:],
    ["productName": "커피 & tea=100%+#", "available": "false", "page": "0", "empty": ""],
  ])
  func `preserves query strings without JSON conversion`(query: [String: String]) async throws {
    let session = makeSession()
    defer { session.invalidateAndCancel() }
    let provider = APIProvider(session: session)
    let endpoint = TestEndpoint(parameter: .query(query))
    let response: RequestEcho = try await provider.request(endpoint)
    #expect(response.query == query)
    #expect(response.body.isEmpty)
    #expect(response.contentType.isEmpty)
  }

  @Test
  func `uses DTO coding keys with the default network coders`() async throws {
    let session = makeSession()
    defer { session.invalidateAndCancel() }
    let provider = APIProvider(session: session)
    let response: CodingPayload = try await provider.request(TestEndpoint(url: .base(path: "snake-case")))
    #expect(response.productName == "coffee")
    #expect(response.createdAt == "2025-04-30T09:41:02.053Z")

    let echo: RequestEcho = try await provider.request(TestEndpoint(method: .post, parameter: .body(response)))
    let body = try #require(JSONSerialization.jsonObject(with: Data(echo.body.utf8)) as? [String: String])
    #expect(body == ["product_name": "coffee", "created_at": "2025-04-30T09:41:02.053Z"])
  }
}

// MARK: - CodingPayload

private struct CodingPayload: Codable, Sendable {
  let productName: String
  let createdAt: String

  /// API별 필드 이름 차이는 DTO에서 정의합니다.
  enum CodingKeys: String, CodingKey {
    case productName = "product_name"
    case createdAt = "created_at"
  }
}

// MARK: - TestEndpoint

private struct TestEndpoint: EndPoint {
  var url: EndpointURL = .base(path: "products")
  var method: HTTPMethod = .get
  var parameter: HTTPParameter = .plain
  var headers: HTTPHeaders = [.accept("application/json")]
}

// MARK: - SearchQuery

private struct SearchQuery: Codable, Equatable {
  let search: String
  let page: Int
  let available: Bool
}

// MARK: - RequestEcho

private struct RequestEcho: Decodable {
  let host: String
  let path: String
  let method: String
  let query: [String: String]
  let accept: String
  let contentType: String
  let body: String
}

// MARK: - PayloadError

private enum PayloadError: Error {
  case failed
}

// MARK: - FailingPayload

private struct FailingPayload: Encodable {
  func encode(to _: any Encoder) throws {
    throw PayloadError.failed
  }
}

// MARK: - StubURLProtocol

/// 공유 가변 상태 없이 요청 경로로 응답을 결정해 테스트 간 간섭을 방지합니다.
private final class StubURLProtocol: URLProtocol {
  override class func canInit(with _: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    guard let url = request.url else { return }
    switch url.lastPathComponent {
    case "offline":
      client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
      return

    case "cancelled":
      client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
      return

    default:
      break
    }

    let response: URLResponse
    if url.lastPathComponent == "non-http" {
      response = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
    } else {
      let status = url.lastPathComponent == "status" ? 503 : (url.lastPathComponent == "empty" ? 204 : 200)
      guard let http = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else { return }
      response = http
    }

    do {
      let data: Data
      switch url.lastPathComponent {
      case "empty": data = Data()
      case "malformed", "status": data = Data("not JSON".utf8)
      case "snake-case":
        data = Data(#"{"product_name":"coffee","created_at":"2025-04-30T09:41:02.053Z"}"#.utf8)
      default:
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let body = try readBody()
        data = try JSONSerialization.data(withJSONObject: [
          "host": url.host ?? "",
          "path": url.path,
          "method": request.httpMethod ?? "",
          "query": Dictionary(query.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { _, new in new }),
          "accept": request.value(forHTTPHeaderField: "Accept") ?? "",
          "contentType": request.value(forHTTPHeaderField: "Content-Type") ?? "",
          "body": String(decoding: body, as: UTF8.self),
        ])
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

  private func readBody() throws -> Data {
    if let body = request.httpBody {
      return body
    }
    guard let stream = request.httpBodyStream else { return Data() }
    stream.open()
    defer { stream.close() }
    var result = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)
    while true {
      let count = stream.read(&buffer, maxLength: buffer.count)
      if count < 0 {
        throw stream.streamError ?? URLError(.cannotDecodeRawData)
      }
      if count == 0 {
        return result
      }
      result.append(contentsOf: buffer.prefix(count))
    }
  }
}
