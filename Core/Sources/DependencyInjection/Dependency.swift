@MainActor
@propertyWrapper
public final class Dependency<Service> {
  private let container: DIContainer
  private var value: Service?

  public init() {
    container = .shared
  }

  public init(container: DIContainer) {
    self.container = container
  }

  public init(wrappedValue: Service) {
    container = .shared
    value = wrappedValue
  }

  public var wrappedValue: Service {
    if let value {
      return value
    }
    let resolved = container.resolve(type: Service.self)
    value = resolved
    return resolved
  }
}
