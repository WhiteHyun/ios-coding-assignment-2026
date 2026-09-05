import Foundation
import Observation

@MainActor
@Observable
public final class Store<R: Reducer> {
  public typealias State = R.State
  public typealias Action = R.Action

  public private(set) var state: State

  @ObservationIgnored private let reducer: R
  @ObservationIgnored private var tasks: [UUID: Task<Void, Never>] = [:]
  @ObservationIgnored private var cancellationIDs: [UUID: AnyHashable] = [:]
  @ObservationIgnored private var pendingActions: [Action] = []
  @ObservationIgnored private var isDispatching = false

  public init(reducer: R) {
    self.reducer = reducer
    state = reducer.initialState
  }

  deinit {
    for task in tasks.values {
      task.cancel()
    }
  }

  public func dispatch(_ action: Action) {
    pendingActions.append(action)
    if !isDispatching {
      isDispatching = true
      defer {
        pendingActions.removeAll(keepingCapacity: true)
        isDispatching = false
      }
      var index = 0
      while index < pendingActions.count {
        let action = pendingActions[index]
        index += 1
        let effect = reducer.reduce(state: &state, action: action)
        execute(effect)
      }
    }
  }

  public func cancelAll() {
    let tasks = tasks
    self.tasks.removeAll()
    cancellationIDs.removeAll()
    for task in tasks.values {
      task.cancel()
    }
  }

  private func execute(_ effect: EffectType<Action>) {
    switch effect {
    case .none:
      break

    case let .cancel(id):
      cancel(id: id)

    case let .task(id, operation):
      startTask(id: id) { send in
        let action = await operation()
        send(action)
      }

    case let .run(id, operation):
      startTask(id: id, operation: operation)
    }
  }

  private func startTask(
    id: AnyHashable?,
    operation: @escaping @MainActor @Sendable (EffectType<Action>.Send) async -> Void,
  ) {
    let token = prepare(id: id)
    tasks[token] = Task { @MainActor [weak self] in
      defer {
        self?.tasks.removeValue(forKey: token)
        self?.cancellationIDs.removeValue(forKey: token)
      }
      if !Task.isCancelled {
        await operation { [weak self] action in
          if !Task.isCancelled {
            self?.receive(action, token: token)
          }
        }
      }
    }
  }

  private func receive(_ action: Action, token: UUID) {
    if tasks[token] != nil {
      dispatch(action)
    }
  }

  private func prepare(id: AnyHashable?) -> UUID {
    if let id {
      cancel(id: id)
    }
    let token = UUID()
    cancellationIDs[token] = id
    return token
  }

  private func cancel(id: AnyHashable) {
    let tokens = cancellationIDs.filter { $0.value == id }.map(\.key)
    for token in tokens {
      cancellationIDs.removeValue(forKey: token)
      let task = tasks.removeValue(forKey: token)
      task?.cancel()
    }
  }
}
