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

  @Test(arguments: [200, 299, 300, 400, 401, 500])
  func `accepts only successful HTTP status codes`(status: Int) async throws {
    let session = makeSession()
    defer { session.invalidateAndCancel() }
    let provider = APIProvider(session: session)
    do {
      let response: RequestEcho = try await provider.request(TestEndpoint(url: .base(path: "http/\(status)")))
      #expect(status == 200 || status == 299)
      #expect(response.path == "/http/\(status)")
    } catch {
      guard case let .failureResponse(code) = error else {
        Issue.record("예상하지 못한 오류: \(error)")
        return
      }
      #expect(status == 300 || status == 400 || status == 401 || status == 500)
      #expect(code == status)
    }
  }

  @Test(arguments: ["missing-field", "wrong-type"])
  func `preserves decoding errors for valid JSON that does not match the DTO`(path: String) async throws {
    let session = makeSession()
    defer { session.invalidateAndCancel() }
    do {
      let _: IDResponse = try await APIProvider(session: session).request(TestEndpoint(url: .base(path: path)))
      Issue.record("DTO와 맞지 않는 응답은 실패해야 합니다.")
    } catch {
      guard case let NetworkError.decoding(underlying) = error else {
        Issue.record("예상하지 못한 오류: \(error)")
        return
      }
      switch (path, underlying) {
      case let ("missing-field", DecodingError.keyNotFound(key, _)):
        #expect(key.stringValue == "id")

      case let ("wrong-type", DecodingError.typeMismatch(type, context)):
        #expect(ObjectIdentifier(type) == ObjectIdentifier(Int.self))
        #expect(context.codingPath.last?.stringValue == "id")

      default:
        Issue.record("원본 디코딩 오류가 보존되어야 합니다: \(underlying)")
      }
    }
  }

  @Test
  func `cancelling an in flight task cancels the request`() async throws {
    let (started, continuation) = AsyncStream.makeStream(of: Void.self)
    let observer = NotificationCenter.default.addObserver(forName: StubURLProtocol.requestStarted, object: nil, queue: nil) { _ in
      continuation.yield(())
    }
    defer {
      NotificationCenter.default.removeObserver(observer)
      continuation.finish()
    }
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    configuration.timeoutIntervalForRequest = 3
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    let task = Task { () throws -> RequestEcho in
      defer { continuation.finish() }
      return try await APIProvider(session: session).request(TestEndpoint(url: .base(path: "pending")))
    }
    defer { task.cancel() }

    // 응답 헤더가 도착한 뒤 본문을 기다리는 요청을 취소합니다.
    var responses = started.makeAsyncIterator()
    let received = await responses.next()
    try #require(received != nil)
    task.cancel()

    do {
      _ = try await task.value
      Issue.record("취소된 요청은 성공하면 안 됩니다.")
    } catch {
      guard case NetworkError.cancelled = error else {
        Issue.record("취소 오류로 전달되어야 합니다: \(error)")
        return
      }
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

// MARK: - IDResponse

private struct IDResponse: Decodable {
  let id: Int
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
  static let requestStarted = Notification.Name("NetworkerTests.pendingRequestStarted")

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
      let status = Int(url.lastPathComponent)
        ?? (url.lastPathComponent == "status" ? 503 : (url.lastPathComponent == "empty" ? 204 : 200))
      guard let http = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else { return }
      response = http
    }

    do {
      let data: Data
      switch url.lastPathComponent {
      case "empty": data = Data()
      case "malformed", "status": data = Data("not JSON".utf8)
      case "missing-field": data = Data("{}".utf8)
      case "wrong-type": data = Data(#"{"id":"one"}"#.utf8)
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
      // 취소 테스트에서는 헤더만 전달하고 본문과 완료 이벤트는 보내지 않습니다.
      if url.lastPathComponent == "pending" {
        NotificationCenter.default.post(name: Self.requestStarted, object: nil)
        return
      }
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
