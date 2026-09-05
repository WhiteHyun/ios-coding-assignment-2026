import Testing
@testable import JNAssignment

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct LocalFavoriteRepositoryTests {
  @Test
  func `each subscriber receives current IDs and every saved snapshot`() async {
    let storage = InMemoryStorage()
    let repository = LocalFavoriteRepository(storage: storage)
    repository.save(productIDs: [2])
    var first = repository.observeProductIDs().makeAsyncIterator()
    var second = repository.observeProductIDs().makeAsyncIterator()
    #expect(await first.next() == [2])
    #expect(await second.next() == [2])

    repository.save(productIDs: [1, 2])
    #expect(await first.next() == [1, 2])
    #expect(await second.next() == [1, 2])
    #expect(storage.integerArray(forKey: "favoriteProductIDs") == [1, 2])
    repository.save(productIDs: [])
    #expect(await first.next() == [])
    #expect(await second.next() == [])
  }

  @Test
  func `slow and new subscribers receive the latest snapshot`() async {
    let repository = LocalFavoriteRepository(storage: InMemoryStorage())
    var slow = repository.observeProductIDs().makeAsyncIterator()
    repository.save(productIDs: [1])
    repository.save(productIDs: [2])
    #expect(await slow.next() == [2])
    var latest = repository.observeProductIDs().makeAsyncIterator()
    #expect(await latest.next() == [2])
  }

  @Test
  func `cancelling one subscriber leaves other subscribers active`() async {
    let repository = LocalFavoriteRepository(storage: InMemoryStorage())
    let stream = repository.observeProductIDs()
    var first = stream.makeAsyncIterator()
    var second = repository.observeProductIDs().makeAsyncIterator()
    #expect(await first.next() == [])
    #expect(await second.next() == [])
    let observation = Task {
      var iterator = stream.makeAsyncIterator()
      return await iterator.next()
    }
    observation.cancel()
    #expect(await observation.value == nil)

    repository.save(productIDs: [1])
    #expect(await first.next() == nil)
    #expect(await second.next() == [1])
  }

  @Test
  func `releasing the repository finishes its observations`() async throws {
    var repository: LocalFavoriteRepository? = LocalFavoriteRepository(storage: InMemoryStorage())
    var iterator = try #require(repository?.observeProductIDs().makeAsyncIterator())
    #expect(await iterator.next() == [])

    repository = nil
    #expect(await iterator.next() == nil)
  }

  @Test
  func `reads and saves favorite IDs through storage`() {
    let storage = InMemoryStorage()
    storage.set([2, 2], forKey: "favoriteProductIDs")
    let repository = LocalFavoriteRepository(storage: storage)
    #expect(repository.fetchProductIDs() == [2])

    repository.save(productIDs: [1, 2])
    #expect(storage.integerArray(forKey: "favoriteProductIDs") == [1, 2])
    #expect(LocalFavoriteRepository(storage: storage).fetchProductIDs() == [1, 2])
    repository.save(productIDs: [])
    #expect(repository.fetchProductIDs().isEmpty)
    #expect(storage.integerArray(forKey: "favoriteProductIDs") == [])
  }

  @Test
  func `missing or incompatible stored data returns an empty set`() {
    let storage = InMemoryStorage()
    let repository = LocalFavoriteRepository(storage: storage)
    #expect(repository.fetchProductIDs().isEmpty)
    storage.set("invalid", forKey: "favoriteProductIDs")
    #expect(repository.fetchProductIDs().isEmpty)
    #expect(storage.string(forKey: "favoriteProductIDs") == "invalid")
  }
}
