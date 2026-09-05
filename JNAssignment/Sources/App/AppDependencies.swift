import DependencyInjection
import Foundation
import Networker
import Storage

@MainActor
enum AppDependencies {
  static func register(in container: DIContainer) {
    container.register(
      type: (any ProductRepository).self,
      RemoteProductRepository(provider: APIProvider(session: .shared)),
    )
    container.register(
      type: (any FavoriteRepository).self,
      LocalFavoriteRepository(storage: UserDefaultsStorage(defaults: .standard)),
    )
  }
}
