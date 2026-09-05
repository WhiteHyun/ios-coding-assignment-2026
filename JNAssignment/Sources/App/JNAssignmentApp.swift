//
//  JNAssignmentApp.swift
//  JNAssignment
//
//  Created by whitehyun on 9/4/26.
//

import Architecture
import Networker
import Storage
import SwiftUI

@main
struct JNAssignmentApp: App {
  private let productRepository: RemoteProductRepository = .init(provider: APIProvider(session: .shared))
  @State private var favoriteRepository: LocalFavoriteRepository = .init(
    storage: UserDefaultsStorage(defaults: .standard)
  )

  var body: some Scene {
    WindowGroup {
      // TODO: DIContainer를 도입해 Repository 생성과 주입 책임을 분리한다.
      ContentView(
        store: Store(reducer: ProductListReducer(
          productListUseCase: ProductListUseCase(
            productRepository: productRepository,
            favoriteRepository: favoriteRepository,
          ),
          favoriteUseCase: FavoriteUseCase(repository: favoriteRepository),
        )),
        makeDetailStore: { productID in
          Store(reducer: ProductDetailReducer(
            productID: productID,
            productDetailUseCase: ProductDetailUseCase(
              productRepository: productRepository,
              favoriteRepository: favoriteRepository,
            ),
            favoriteUseCase: FavoriteUseCase(repository: favoriteRepository),
          ))
        },
      )
    }
  }
}
