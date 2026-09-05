import DependencyInjection
import Testing

// MARK: - DependencyInjectionTests

@MainActor
struct DependencyInjectionTests {
  @Test
  func `protocol resolution shares the registered instance`() {
    let container = DIContainer()
    let service = SampleService()
    container.register(type: (any Service).self, service)
    let first = container.resolve(type: (any Service).self)
    let second = container.resolve(type: (any Service).self)
    #expect(first === service)
    #expect(second === service)
  }

  @Test
  func `factory resolves registered dependencies and creates a fresh object`() {
    let container = DIContainer()
    let service = SampleService()
    var creations = 0
    container.register(type: (any Service).self, service)
    container.register(type: FactoryConsumer.self) { resolver in
      creations += 1
      return FactoryConsumer(service: resolver.resolve(type: (any Service).self))
    }
    #expect(creations == 0)
    let first = container.resolve(type: FactoryConsumer.self)
    let second = container.resolve(type: FactoryConsumer.self)
    #expect(creations == 2)
    #expect(first !== second)
    #expect(first.service === service)
    #expect(second.service === service)
  }

  @Test
  func `each dependency wrapper keeps its own factory-created object`() {
    let container = DIContainer()
    container.register(type: (any Service).self, SampleService())
    container.register(type: FactoryConsumer.self) { resolver in
      FactoryConsumer(service: resolver.resolve(type: (any Service).self))
    }
    let first = Dependency<FactoryConsumer>(container: container)
    let second = Dependency<FactoryConsumer>(container: container)
    #expect(first.wrappedValue === first.wrappedValue)
    #expect(first.wrappedValue !== second.wrappedValue)
    #expect(first.wrappedValue.service === second.wrappedValue.service)
  }

  @Test
  func `identically named types do not collide`() {
    let container = DIContainer()
    container.register(type: FirstNamespace.Value.self, FirstNamespace.Value(number: 1))
    container.register(type: SecondNamespace.Value.self, SecondNamespace.Value(number: 2))
    #expect(container.resolve(type: FirstNamespace.Value.self).number == 1)
    #expect(container.resolve(type: SecondNamespace.Value.self).number == 2)
  }

  @Test
  func `containers keep their registrations independent`() {
    let first = DIContainer()
    let second = DIContainer()
    let firstService = SampleService()
    let secondService = SampleService()
    first.register(type: (any Service).self, firstService)
    second.register(type: (any Service).self, secondService)
    #expect(first.resolve(type: (any Service).self) === firstService)
    #expect(second.resolve(type: (any Service).self) === secondService)
  }

  @Test
  func `dependency resolves on first access and retains that instance`() {
    let container = DIContainer()
    let dependency = Dependency<any Service>(container: container)
    let first = SampleService()
    container.register(type: (any Service).self, first)
    #expect(dependency.wrappedValue === first)

    let second = SampleService()
    container.register(type: (any Service).self, second)
    #expect(container.resolve(type: (any Service).self) === second)
    #expect(dependency.wrappedValue === first)
    #expect(Dependency<any Service>(container: container).wrappedValue === second)
  }

  @Test
  func `explicit injection does not resolve an unregistered global dependency`() {
    let service = SampleService()
    let consumer = Consumer(service: service)
    #expect(consumer.service === service)
  }

  @Test
  func `default wrapper resolves from the shared container`() {
    let service = SharedService()
    DIContainer.shared.register(type: SharedService.self, service)
    let consumer = SharedConsumer()
    #expect(consumer.service === service)
  }
}

// MARK: - Service

@MainActor
private protocol Service: AnyObject {
}

// MARK: - SampleService

@MainActor
private final class SampleService: Service {
}

// MARK: - Consumer

@MainActor
private struct Consumer {
  @Dependency var service: any Service

  init(service: any Service) {
    _service = Dependency(wrappedValue: service)
  }
}

// MARK: - SharedService

@MainActor
private final class SharedService {
}

// MARK: - SharedConsumer

@MainActor
private struct SharedConsumer {
  @Dependency var service: SharedService
}

// MARK: - FirstNamespace

private enum FirstNamespace {
  struct Value {
    let number: Int
  }
}

// MARK: - SecondNamespace

private enum SecondNamespace {
  struct Value {
    let number: Int
  }
}

// MARK: - FactoryConsumer

@MainActor
private final class FactoryConsumer {
  let service: any Service

  init(service: any Service) {
    self.service = service
  }
}
