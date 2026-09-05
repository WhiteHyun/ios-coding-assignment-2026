//
//  ContentView.swift
//  JNAssignment
//
//  Created by whitehyun on 9/4/26.
//

import SwiftUI

struct ContentView: View {
  @State var interactor: ProductListInteractor

  var body: some View {
    NavigationStack {
      ProductListView(interactor: interactor)
    }
  }
}
