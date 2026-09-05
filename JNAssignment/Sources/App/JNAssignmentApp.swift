//
//  JNAssignmentApp.swift
//  JNAssignment
//
//  Created by whitehyun on 9/4/26.
//

import Networker
import Storage
import SwiftUI

@main
struct JNAssignmentApp: App {
  @State private var favoriteRepository: LocalFavoriteRepository = .init(
    storage: UserDefaultsStorage(defaults: .standard)
  )

  var body: some Scene {
    WindowGroup {
      // TODO: DIContainer를 도입해 Repository 생성과 주입 책임을 분리한다.
      ContentView(
        interactor: ProductListInteractor(
          productListUseCase: ProductListUseCase(
            productRepository: RemoteProductRepository(provider: APIProvider(session: .shared)),
            favoriteRepository: favoriteRepository,
          ),
          favoriteUseCase: FavoriteUseCase(repository: favoriteRepository),
        )
      )
    }
  }
}
