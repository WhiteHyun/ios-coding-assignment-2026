//
//  HTTPHeader.swift
//  Networker
//
//  Created by whitehyun on 9/5/26.
//

public struct HTTPHeader: Sendable, Hashable {
  public let key: String
  public let value: String

  public init(key: String, value: String) {
    self.key = key
    self.value = value
  }
}
