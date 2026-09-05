//
//  HTTPParameter.swift
//  Core
//
//  Created by whitehyun on 9/5/26.
//

import Foundation

// MARK: - HTTPParameter

/// 통신 요청 시 필요한 파라미터 데이터를 담습니다.
public enum HTTPParameter: Sendable {
  /// 쿼리와 본문 없이 요청합니다.
  case plain

  /// 문자열로 표현한 요청값을 URL 쿼리로 전달합니다.
  case query([String: String])

  /// JSON 본문으로 요청값을 전달합니다.
  case body(any Encodable & Sendable)
}
