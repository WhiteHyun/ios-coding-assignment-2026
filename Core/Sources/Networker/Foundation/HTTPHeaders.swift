//
//  HTTPHeaders.swift
//  Networker
//
//  Created by whitehyun on 9/4/26.
//

// MARK: - HTTPHeaders

public struct HTTPHeaders: Sendable, Hashable {
  public let headers: [HTTPHeader]

  public init(headers: [HTTPHeader]) {
    self.headers = headers
  }

  var dictionary: [String: String] {
    let headersTuple = headers.map { ($0.key, $0.value) }
    return Dictionary(uniqueKeysWithValues: headersTuple)
  }
}

// MARK: ExpressibleByArrayLiteral

extension HTTPHeaders: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: HTTPHeader...) {
    self.init(headers: elements)
  }
}
