// MARK: - Reducer

@MainActor
public protocol Reducer {
  associatedtype State: Sendable
  associatedtype Action: Sendable

  typealias Effect = EffectType<Action>

  var initialState: State { get }

  func reduce(state: inout State, action: Action) -> Effect
}

public typealias StoreOf<R: Reducer> = Store<R>
