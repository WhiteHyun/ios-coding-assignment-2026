@MainActor
public enum EffectType<Action: Sendable> {
  public typealias Send = @MainActor @Sendable (Action) -> Void

  case none
  case task(id: AnyHashable? = nil, operation: @MainActor @Sendable () async -> Action)
  case run(id: AnyHashable? = nil, operation: @MainActor @Sendable (Send) async -> Void)
  case cancel(id: AnyHashable)
}
