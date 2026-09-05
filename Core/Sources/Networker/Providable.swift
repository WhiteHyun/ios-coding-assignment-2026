public protocol Providable: Sendable {
  func request<Model: Decodable>(_ endpoint: any EndPoint) async throws(NetworkError) -> Model
}
