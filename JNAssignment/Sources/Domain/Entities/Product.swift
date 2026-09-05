import Foundation

nonisolated struct Product: Identifiable, Equatable, Sendable {
  let id: Int
  let title: String
  let price: Double
  let thumbnail: URL?
}
