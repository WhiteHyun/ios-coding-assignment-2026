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
    container.register(type: ProductListUseCase.self) { resolver in
      ProductListUseCase(
        productRepository: resolver.resolve(type: (any ProductRepository).self),
        favoriteRepository: resolver.resolve(type: (any FavoriteRepository).self),
      )
    }
    container.register(type: ProductDetailUseCase.self) { resolver in
      ProductDetailUseCase(
        productRepository: resolver.resolve(type: (any ProductRepository).self),
        favoriteRepository: resolver.resolve(type: (any FavoriteRepository).self),
      )
    }
    container.register(type: FavoriteUseCase.self) { resolver in
      FavoriteUseCase(repository: resolver.resolve(type: (any FavoriteRepository).self))
    }
  }
}
