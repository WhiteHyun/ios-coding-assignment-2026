//
//  HTTPHeader.swift
//  Networker
//
//  Created by whitehyun on 9/5/26.
//

// MARK: - HTTPHeader

/// HTTP 헤더를 나타냅니다
public struct HTTPHeader: Sendable, Hashable {
  /// header 이름
  let key: String

  /// header에 대응되는 값
  let value: String

  public init(key: String, value: String) {
    self.key = key
    self.value = value
  }
}

extension HTTPHeader {
  public static func accept(_ value: String) -> Self {
    HTTPHeader(key: "Accept", value: value)
  }

  public static func contentType(_ value: String) -> Self {
    HTTPHeader(key: "Content-Type", value: value)
  }

  public static func authorization(bearer token: String) -> Self {
    HTTPHeader(key: "Authorization", value: "Bearer \(token)")
  }
}

// MARK: CustomStringConvertible

extension HTTPHeader: CustomStringConvertible {
  public var description: String {
    "\(key): \(value)"
  }
}
