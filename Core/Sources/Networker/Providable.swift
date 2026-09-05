public protocol Providable {
  func request<Model: Decodable>(_ endpoint: any EndPoint) async throws(NetworkError) -> Model
}
