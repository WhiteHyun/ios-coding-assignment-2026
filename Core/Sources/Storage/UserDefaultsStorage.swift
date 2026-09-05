import Foundation

public final class UserDefaultsStorage: KeyValueStorage {
  private let defaults: UserDefaults

  public init(defaults: UserDefaults) {
    self.defaults = defaults
  }

  public func integer(forKey key: String) -> Int? {
    defaults.object(forKey: key) as? Int
  }

  public func bool(forKey key: String) -> Bool? {
    defaults.object(forKey: key) as? Bool
  }

  public func string(forKey key: String) -> String? {
    defaults.object(forKey: key) as? String
  }

  public func integerArray(forKey key: String) -> [Int]? {
    defaults.object(forKey: key) as? [Int]
  }

  public func set(_ value: Int, forKey key: String) {
    defaults.set(value, forKey: key)
  }

  public func set(_ value: Bool, forKey key: String) {
    defaults.set(value, forKey: key)
  }

  public func set(_ value: String, forKey key: String) {
    defaults.set(value, forKey: key)
  }

  public func set(_ value: [Int], forKey key: String) {
    defaults.set(value, forKey: key)
  }
}
