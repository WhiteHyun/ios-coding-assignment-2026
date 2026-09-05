public protocol KeyValueStorage: AnyObject {
  func integer(forKey key: String) -> Int?
  func bool(forKey key: String) -> Bool?
  func string(forKey key: String) -> String?
  func integerArray(forKey key: String) -> [Int]?

  func set(_ value: Int, forKey key: String)
  func set(_ value: Bool, forKey key: String)
  func set(_ value: String, forKey key: String)
  func set(_ value: [Int], forKey key: String)
}
