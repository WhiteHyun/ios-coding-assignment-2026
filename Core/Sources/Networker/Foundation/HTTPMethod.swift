//
//  HTTPMethod.swift
//  Networker
//
//  Created by whitehyun on 9/4/26.
//

/// HTTP Method를 나타냅니다.
public enum HTTPMethod: String, Sendable {
  /// The `GET` Method.
  case get = "GET"

  /// The `POST` Method.
  case post = "POST"

  /// The `DELETE` Method.
  case delete = "DELETE"

  /// The `PUT` Method.
  case put = "PUT"
}
