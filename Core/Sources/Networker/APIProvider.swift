import Foundation

public struct APIProvider: Providable {
  private let session: URLSession

  public init(session: URLSession = .shared) {
    self.session = session
  }

  public func request<Model: Decodable>(_ endpoint: any EndPoint) async throws(NetworkError) -> Model {
    let data = try await perform(endpoint)
    do {
      try Task.checkCancellation()
      return try NetworkCoders.decoder.decode(Model.self, from: data)
    } catch is CancellationError {
      throw .cancelled
    } catch {
      throw .decoding(underlying: error)
    }
  }

  private func perform(_ endpoint: any EndPoint) async throws(NetworkError) -> Data {
    if Task.isCancelled {
      throw .cancelled
    }
    let request = try makeURLRequest(from: endpoint)

    do {
      let (data, response) = try await session.data(for: request)
      try Task.checkCancellation()
      guard let response = response as? HTTPURLResponse else {
        throw NetworkError.invalidResponse
      }
      guard (200 ..< 300).contains(response.statusCode) else {
        throw NetworkError.failureResponse(statusCode: response.statusCode)
      }
      return data
    } catch let error as NetworkError {
      throw error
    } catch is CancellationError {
      throw .cancelled
    } catch let error as URLError where error.code == .cancelled {
      throw .cancelled
    } catch {
      throw .transport(underlying: error)
    }
  }

  private func makeURLRequest(from endpoint: any EndPoint) throws(NetworkError) -> URLRequest {
    guard let url = endpoint.url.url else {
      throw .invalidURL
    }
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      throw .invalidURL
    }

    let body: Data?
    do {
      switch endpoint.parameter {
      case .plain:
        body = nil

      case let .query(query):
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        body = nil

      case let .body(payload):
        body = try NetworkCoders.encoder.encode(payload)
      }
    } catch {
      throw .encoding(underlying: error)
    }

    guard let requestURL = components.url else {
      throw .invalidURL
    }
    var request = URLRequest(url: requestURL)
    request.httpMethod = endpoint.method.rawValue
    // 같은 이름의 헤더가 중복되면 마지막 값을 사용합니다.
    for header in endpoint.headers.headers {
      request.setValue(header.value, forHTTPHeaderField: header.key)
    }
    request.httpBody = body
    if body != nil, request.value(forHTTPHeaderField: "Content-Type") == nil {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    return request
  }
}
