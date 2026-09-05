import Observation

@MainActor
protocol Interactor: AnyObject, Observable {
  associatedtype Action
  associatedtype State

  var state: State { get }

  func send(_ action: Action) async
}
