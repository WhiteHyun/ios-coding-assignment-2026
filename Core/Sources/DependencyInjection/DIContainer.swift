@MainActor
public final class DIContainer {
  public static let shared: DIContainer = .init()

  private var factories: [ObjectIdentifier: @MainActor (DIContainer) -> Any] = [:]
  private var resolvingTypes: Set<ObjectIdentifier> = []

  public init() {
  }

  public func register<Service>(type: Service.Type, _ object: Service) {
    factories[ObjectIdentifier(type)] = { _ in object }
  }

  public func register<Service>(type: Service.Type, factory: @escaping @MainActor (DIContainer) -> Service) {
    factories[ObjectIdentifier(type)] = { container in factory(container) }
  }

  public func resolve<Service>(type: Service.Type) -> Service {
    let key = ObjectIdentifier(type)
    guard let factory = factories[key] else {
      preconditionFailure("등록되지 않은 의존성: \(String(reflecting: type))")
    }
    guard resolvingTypes.insert(key).inserted else {
      preconditionFailure("순환 의존성: \(String(reflecting: type))")
    }
    defer { resolvingTypes.remove(key) }
    guard let object = factory(self) as? Service else {
      preconditionFailure("등록 타입과 생성된 객체 타입이 일치하지 않음: \(String(reflecting: type))")
    }
    return object
  }
}
