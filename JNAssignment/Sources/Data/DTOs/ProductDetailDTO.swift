import Foundation

nonisolated struct ProductDetailDTO: Decodable, Sendable {
  let id: Int
  let title: String
  let price: Double
  let description: String
  let images: [String]
  let thumbnail: String?
  let brand: String?
  let category: String
  let rating: Double
  let stock: Int

  func toDomain() -> ProductDetail {
    let imageURLs = images.compactMap(URL.init(string:))
    let fallback = thumbnail.flatMap(URL.init(string:))
    return ProductDetail(
      id: id,
      title: title,
      price: price,
      description: description,
      images: imageURLs.isEmpty ? [fallback].compactMap(\.self) : imageURLs,
      brand: brand,
      category: category,
      rating: rating,
      stock: stock,
      isFavorite: false,
    )
  }
}
