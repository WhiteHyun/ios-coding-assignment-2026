import Storage

final nonisolated class InMemoryStorage: KeyValueStorage {
  private var values: [String: Any] = [:]

  func integer(forKey key: String) -> Int? {
    values[key] as? Int
  }

  func bool(forKey key: String) -> Bool? {
    values[key] as? Bool
  }

  func string(forKey key: String) -> String? {
    values[key] as? String
  }

  func integerArray(forKey key: String) -> [Int]? {
    values[key] as? [Int]
  }

  func set(_ value: Int, forKey key: String) {
    values[key] = value
  }

  func set(_ value: Bool, forKey key: String) {
    values[key] = value
  }

  func set(_ value: String, forKey key: String) {
    values[key] = value
  }

  func set(_ value: [Int], forKey key: String) {
    values[key] = value
  }
}
