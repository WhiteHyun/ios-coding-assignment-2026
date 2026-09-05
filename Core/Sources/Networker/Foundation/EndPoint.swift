//
//  EndPoint.swift
//  Networker
//
//  Created by whitehyun on 9/4/26.
//

import Foundation

// MARK: - EndPoint

public protocol EndPoint {
  var baseURL: String { get }
  var path: String { get }
  var method: HTTPMethod { get }
  var query: (any Encodable)? { get }
  var body: (any Encodable)? { get }
  var headers: HTTPHeaders { get }
}

extension EndPoint {
  public var baseURL: String {
    // request를 생성할 때 빈 문자열이면 invalidURL Error로 자연스레 들어갑니다.
    Bundle.main.infoDictionary?["BaseURL"] as? String ?? ""
  }
}

extension EndPoint {
  public func request() throws -> URLRequest {
    guard let targetURL = URL(string: baseURL)?.appendingPathComponent(path).appending(query: query)
    else {
      throw NetworkError.invalidURL
    }
    var request = URLRequest(url: targetURL)
    request.httpMethod = method.rawValue
    request.allHTTPHeaderFields = headers.dictionary
    request.httpBody = body?.data
    return request
  }
}

extension URL {
  fileprivate func appending(query: Encodable?) -> URL? {
    guard let query else {
      return self
    }
    var urlComponents = URLComponents(string: absoluteString)
    urlComponents?.queryItems = query.dictionary.map { (key: String, value: Any) in
      URLQueryItem(name: key, value: "\(value)")
    }
    return urlComponents?.url
  }
}

extension Encodable {
  fileprivate var data: Data? {
    try? JSONEncoder().encode(self)
  }

  fileprivate var dictionary: [String: Any] {
    guard
      let data = try? JSONEncoder().encode(self),
      let jsonData = try? JSONSerialization.jsonObject(with: data),
      let dictionaryTarget = jsonData as? [String: Any]
    else {
      return [:]
    }

    return dictionaryTarget
  }
}
