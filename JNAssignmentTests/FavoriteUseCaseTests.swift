import Testing
@testable import JNAssignment

@MainActor
struct FavoriteUseCaseTests {
  @Test
  func `fetches saved favorites without writing`() {
    let repository = InMemoryFavoriteRepository(productIDs: [1, 2])
    let useCase = FavoriteUseCase(repository: repository)

    #expect(useCase.fetchProductIDs() == [1, 2])
    #expect(repository.saveCount == 0)
  }

  @Test
  func `forwards the repository observation without writing`() async {
    let repository = InMemoryFavoriteRepository(productIDs: [1, 2])
    let useCase = FavoriteUseCase(repository: repository)
    var iterator = useCase.observeProductIDs().makeAsyncIterator()

    #expect(await iterator.next() == [1, 2])
    #expect(await iterator.next() == nil)
    #expect(repository.saveCount == 0)
  }

  @Test
  func `adds and removes a favorite while preserving other IDs`() {
    let repository = InMemoryFavoriteRepository(productIDs: [2])
    let useCase = FavoriteUseCase(repository: repository)

    useCase.toggle(productID: 1)
    #expect(repository.productIDs == [1, 2])
    useCase.toggle(productID: 1)
    #expect(repository.productIDs == [2])
    #expect(repository.saveCount == 2)
    useCase.toggle(productID: 2)
    #expect(repository.productIDs.isEmpty)
  }

  @Test
  func `uses the latest persisted IDs on each toggle`() {
    let repository = InMemoryFavoriteRepository(productIDs: [1])
    let useCase = FavoriteUseCase(repository: repository)
    #expect(useCase.fetchProductIDs() == [1])
    repository.productIDs = [1, 2]

    useCase.toggle(productID: 3)
    #expect(repository.productIDs == [1, 2, 3])
  }
}
