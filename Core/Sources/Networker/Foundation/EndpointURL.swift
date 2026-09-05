//
//  EndpointURL.swift
//  Networker
//
//  Created by whitehyun on 9/5/26.
//

import Foundation

public enum EndpointURL: Sendable {
  case base(path: String)

  var url: URL? {
    switch self {
    case let .base(path):
      URL(string: "https://dummyjson.com")?.appendingPathComponent(path)
    }
  }
}
