import Foundation

/// 네트워크의 기본 JSON 정책을 공유합니다.
enum NetworkCoders {
  static let encoder: JSONEncoder = .init()
  static let decoder: JSONDecoder = .init()
}
