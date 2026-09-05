//
//  HTTPHeaders.swift
//  Networker
//
//  Created by whitehyun on 9/4/26.
//

public struct HTTPHeaders: Sendable, Hashable {
  public let headers: [HTTPHeader]

  public init(_ headers: [HTTPHeader] = []) {
    self.headers = headers
  }

  var dictionary: [String: String] {
    Dictionary(uniqueKeysWithValues: headers.map { ($0.key, $0.value) })
  }
}
