@MainActor
@propertyWrapper
public struct Dependency<Service> {
  public let wrappedValue: Service

  public init() {
    wrappedValue = DIContainer.shared.resolve(type: Service.self)
  }
}
