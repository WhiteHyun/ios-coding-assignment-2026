//
//  ContentView.swift
//  JNAssignment
//
//  Created by whitehyun on 9/4/26.
//

import SwiftUI

struct ContentView: View {
  @State var interactor: ProductListInteractor
  let makeDetailInteractor: (Int) -> ProductDetailInteractor

  var body: some View {
    NavigationStack {
      ProductListView(interactor: interactor)
        .navigationDestination(for: Int.self) { productID in
          ProductDetailView(interactor: makeDetailInteractor(productID))
        }
    }
  }
}
