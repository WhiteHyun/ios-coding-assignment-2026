@MainActor
public final class DIContainer {
  public static let shared: DIContainer = .init()

  private var storage: [ObjectIdentifier: Any] = [:]

  public init() {
  }

  public func register<Service>(type: Service.Type, _ object: Service) {
    storage[ObjectIdentifier(type)] = object
  }

  public func resolve<Service>(type: Service.Type) -> Service {
    guard let object = storage[ObjectIdentifier(type)] as? Service else {
      preconditionFailure("등록되지 않은 의존성: \(String(reflecting: type))")
    }
    return object
  }
}
