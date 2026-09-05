import Foundation

// MARK: - ProductListResponse

nonisolated struct ProductListResponse: Decodable, Sendable {
  let products: [ProductDTO]
}

// MARK: - ProductDTO

nonisolated struct ProductDTO: Decodable, Sendable {
  let id: Int
  let title: String
  let price: Double
  let thumbnail: String?

  func toDomain() -> Product {
    Product(id: id, title: title, price: price, thumbnail: thumbnail.flatMap(URL.init(string:)))
  }
}
