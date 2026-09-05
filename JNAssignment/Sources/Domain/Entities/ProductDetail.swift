import Foundation

nonisolated struct ProductDetail: Identifiable, Equatable, Sendable {
  let id: Int
  let title: String
  let price: Double
  let description: String
  let images: [URL]
  let brand: String?
  let category: String
  let rating: Double
  let stock: Int
  var isFavorite: Bool
}
