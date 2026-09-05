import Architecture
import Observation
import Testing

// MARK: - StoreTests

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct StoreTests {
  @Test
  func `reduces state synchronously before executing effect`() async {
    let observed = AsyncStream<Int>.makeStream()
    let store = Store(reducer: TestReducer { state, action in
      state.append(action)
      let count = state.count
      return .run { _ in observed.continuation.yield(count) }
    })
    store.dispatch(1)
    #expect(store.state == [1])
    var iterator = observed.stream.makeAsyncIterator()
    #expect(await iterator.next() == 1)
  }

  @Test
  func `completed task sends response`() async {
    let gate = OperationGate()
    let store = Store(reducer: TestReducer { state, action in
      if action == 0 {
        return .task { await gate.value() }
      }
      state.append(action)
      return .none
    })
    store.dispatch(0)
    await gate.waitUntilStarted()
    gate.resume(1)
    await gate.waitUntilFinished()
    #expect(store.state == [1])
  }

  @Test
  func `cancel reaches operation and rejects its late response`() async {
    let gate = OperationGate()
    let store = Store(reducer: TestReducer { state, action in
      switch action {
      case 0: return .task(id: "load") { await gate.value() }
      case -1: return .cancel(id: "load")
      default: state.append(action); return .none
      }
    })
    store.dispatch(0)
    await gate.waitUntilStarted()
    store.dispatch(-1)
    gate.resume(1)
    await gate.waitUntilFinished()
    #expect(gate.wasCancelled)
    #expect(store.state.isEmpty)
  }

  @Test
  func `replacing same ID ignores old response without cancelling other IDs`() async {
    let first = OperationGate()
    let second = OperationGate()
    let independent = OperationGate()
    let store = Store(reducer: TestReducer { state, action in
      switch action {
      case 0: return .task(id: "load") { await first.value() }
      case -1: return .task(id: "load") { await second.value() }
      case -2: return .task(id: "other") { await independent.value() }
      default: state.append(action); return .none
      }
    })
    store.dispatch(0)
    await first.waitUntilStarted()
    store.dispatch(-2)
    await independent.waitUntilStarted()
    store.dispatch(-1)
    await second.waitUntilStarted()
    first.resume(1)
    await first.waitUntilFinished()
    #expect(first.wasCancelled)
    second.resume(2)
    await second.waitUntilFinished()
    independent.resume(3)
    await independent.waitUntilFinished()
    #expect(!second.wasCancelled)
    #expect(!independent.wasCancelled)
    #expect(store.state == [2, 3])
  }

  @Test
  func `store deinitialization cancels running operation without retaining store`() async {
    let gate = OperationGate()
    var store: Store<TestReducer>? = Store(reducer: TestReducer { _, _ in
      .task { await gate.value() }
    })
    weak var weakStore = store
    store?.dispatch(0)
    await gate.waitUntilStarted()
    store = nil
    #expect(weakStore == nil)
    gate.resume(1)
    await gate.waitUntilFinished()
    #expect(gate.wasCancelled)
  }

  @Test
  func `run consumes multiple stream values in order`() async {
    let completed = AsyncStream<Void>.makeStream()
    let values = AsyncStream<Int> { continuation in
      continuation.yield(1)
      continuation.yield(2)
      continuation.finish()
    }
    let store = Store(reducer: TestReducer { state, action in
      if action == 0 {
        return .run { send in
          for await value in values {
            send(value)
          }
          completed.continuation.yield(())
        }
      }
      state.append(action)
      return .none
    })
    store.dispatch(0)
    var iterator = completed.stream.makeAsyncIterator()
    await iterator.next()
    #expect(store.state == [1, 2])
  }

  @Test
  func `cancelAll cancels independent tasks and rejects their late responses`() async {
    let first = OperationGate()
    let second = OperationGate()
    let store = Store(reducer: TestReducer { state, action in
      switch action {
      case 0: return .task { await first.value() }
      case -1: return .task(id: "other") { await second.value() }
      default: state.append(action); return .none
      }
    })
    store.dispatch(0)
    store.dispatch(-1)
    await first.waitUntilStarted()
    await second.waitUntilStarted()
    store.cancelAll()
    first.resume(1)
    second.resume(2)
    await first.waitUntilFinished()
    await second.waitUntilFinished()
    #expect(first.wasCancelled)
    #expect(second.wasCancelled)
    #expect(store.state.isEmpty)
  }

  @Test
  func `reentrant action from observation waits for current state mutation`() {
    let store = Store(reducer: TestReducer { state, action in
      state.append(action)
      return .none
    })
    withObservationTracking {
      _ = store.state
    } onChange: {
      MainActor.assumeIsolated { store.dispatch(2) }
    }
    store.dispatch(1)
    #expect(store.state == [1, 2])
  }
}

// MARK: - TestReducer

@MainActor
private struct TestReducer: Reducer {
  typealias State = [Int]
  typealias Action = Int
  let initialState: [Int] = []
  let reduction: (inout [Int], Int) -> Effect

  init(_ reduction: @escaping (inout [Int], Int) -> Effect) {
    self.reduction = reduction
  }

  func reduce(state: inout [Int], action: Int) -> Effect {
    reduction(&state, action)
  }
}

// MARK: - OperationGate

@MainActor
private final class OperationGate {
  private let started: (stream: AsyncStream<Void>, continuation: AsyncStream<Void>.Continuation) = AsyncStream.makeStream()
  private let finished: (stream: AsyncStream<Void>, continuation: AsyncStream<Void>.Continuation) = AsyncStream.makeStream()
  private var continuation: CheckedContinuation<Int, Never>?
  private(set) var wasCancelled = false

  func value() async -> Int {
    let value = await withCheckedContinuation { continuation in
      self.continuation = continuation
      started.continuation.yield(())
    }
    wasCancelled = Task.isCancelled
    finished.continuation.yield(())
    return value
  }

  func resume(_ value: Int) {
    continuation?.resume(returning: value)
    continuation = nil
  }

  func waitUntilStarted() async {
    var iterator = started.stream.makeAsyncIterator()
    await iterator.next()
  }

  func waitUntilFinished() async {
    var iterator = finished.stream.makeAsyncIterator()
    await iterator.next()
  }
}
