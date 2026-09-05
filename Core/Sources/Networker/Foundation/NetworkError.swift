//
//  NetworkError.swift
//  Networker
//
//  Created by whitehyun on 9/5/26.
//

public enum NetworkError: Error {
  case invalidURL
  case invalidResponse
  case encoding(underlying: any Error)
  case transport(underlying: any Error)
  case decoding(underlying: any Error)
  case cancelled
  case internalServer
  case failureResponse(statusCode: Int)
  case emptyRequest
  case emptyResponse
  case unknown(raw: String)
}
