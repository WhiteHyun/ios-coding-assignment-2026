//
//  JNAssignmentApp.swift
//  JNAssignment
//
//  Created by whitehyun on 9/4/26.
//

import Architecture
import DependencyInjection
import SwiftUI

@main
struct JNAssignmentApp: App {
  init() {
    AppDependencies.register(in: .shared)
  }

  var body: some Scene {
    WindowGroup {
      ContentView(
        store: Store(reducer: ProductListReducer()),
        makeDetailStore: { productID in
          Store(reducer: ProductDetailReducer(productID: productID))
        },
      )
    }
  }
}
