import Networker

nonisolated struct ProductListEndpoint: EndPoint {
  var url: EndpointURL {
    .base(path: "products")
  }

  var method: HTTPMethod {
    .get
  }

  var parameter: HTTPParameter {
    .plain
  }

  var headers: HTTPHeaders {
    []
  }
}
