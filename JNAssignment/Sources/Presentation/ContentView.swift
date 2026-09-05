//
//  ContentView.swift
//  JNAssignment
//
//  Created by whitehyun on 9/4/26.
//

import Architecture
import SwiftUI

struct ContentView: View {
  @State var store: StoreOf<ProductListReducer>
  let makeDetailStore: (Int) -> StoreOf<ProductDetailReducer>

  var body: some View {
    NavigationStack {
      ProductListView(store: store)
        .navigationDestination(for: Int.self) { productID in
          ProductDetailView(store: makeDetailStore(productID))
        }
    }
  }
}
