//
//  EndPoint.swift
//  Networker
//
//  Created by whitehyun on 9/4/26.
//

import Foundation

// MARK: - EndPoint

public protocol EndPoint {
  var url: EndpointURL { get }
  var method: HTTPMethod { get }
  var parameter: HTTPParameter { get }
  var headers: HTTPHeaders { get }
}
