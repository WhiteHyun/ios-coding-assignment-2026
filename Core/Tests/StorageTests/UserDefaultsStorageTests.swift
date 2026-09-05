import Foundation
import Storage
import Testing

struct UserDefaultsStorageTests {
  @Test
  func `restores all supported value types using the same suite`() throws {
    let suite = UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let storage = UserDefaultsStorage(defaults: defaults)

    storage.set(42, forKey: "integer")
    storage.set(true, forKey: "bool")
    storage.set("상품", forKey: "string")
    storage.set([3, 1, 3], forKey: "array")

    let restored = try UserDefaultsStorage(defaults: #require(UserDefaults(suiteName: suite)))
    #expect(restored.integer(forKey: "integer") == 42)
    #expect(restored.bool(forKey: "bool") == true)
    #expect(restored.string(forKey: "string") == "상품")
    #expect(restored.integerArray(forKey: "array") == [3, 1, 3])
  }

  @Test
  func `distinguishes missing values from zero false and empty values`() throws {
    let suite = UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let storage = UserDefaultsStorage(defaults: defaults)
    #expect(storage.integer(forKey: "integer") == nil)
    #expect(storage.bool(forKey: "bool") == nil)
    #expect(storage.string(forKey: "string") == nil)
    #expect(storage.integerArray(forKey: "array") == nil)

    storage.set(0, forKey: "integer")
    storage.set(false, forKey: "bool")
    storage.set("", forKey: "string")
    storage.set([Int](), forKey: "array")

    #expect(storage.integer(forKey: "integer") == 0)
    #expect(storage.bool(forKey: "bool") == false)
    #expect(storage.string(forKey: "string") == "")
    #expect(storage.integerArray(forKey: "array") == [])
  }

  @Test
  func `returns nil for incompatible values without changing stored data`() throws {
    let suite = UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let storage = UserDefaultsStorage(defaults: defaults)
    defaults.set("invalid", forKey: "value")

    #expect(storage.integer(forKey: "value") == nil)
    #expect(storage.bool(forKey: "value") == nil)
    #expect(storage.integerArray(forKey: "value") == nil)
    #expect(storage.string(forKey: "value") == "invalid")
  }
}
