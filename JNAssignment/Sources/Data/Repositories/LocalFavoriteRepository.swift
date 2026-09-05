import Foundation
import Storage

final class LocalFavoriteRepository: FavoriteRepository {
  private let storage: any KeyValueStorage
  private static let storageKey = "favoriteProductIDs"
  private var continuations: [UUID: AsyncStream<Set<Int>>.Continuation] = [:]

  init(storage: any KeyValueStorage) {
    self.storage = storage
  }

  func fetchProductIDs() -> Set<Int> {
    Set(storage.integerArray(forKey: Self.storageKey) ?? [])
  }

  func observeProductIDs() -> AsyncStream<Set<Int>> {
    let id = UUID()
    let (stream, continuation) = AsyncStream<Set<Int>>.makeStream(bufferingPolicy: .bufferingNewest(1))
    continuation.onTermination = { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.continuations.removeValue(forKey: id)
      }
    }
    continuations[id] = continuation
    continuation.yield(fetchProductIDs())
    return stream
  }

  func save(productIDs: Set<Int>) {
    storage.set(productIDs.sorted(), forKey: Self.storageKey)
    for continuation in continuations.values {
      continuation.yield(productIDs)
    }
  }

  deinit {
    for continuation in continuations.values {
      continuation.finish()
    }
  }
}
