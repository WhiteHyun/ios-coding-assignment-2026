import Networker

nonisolated struct ProductDetailEndpoint: EndPoint {
  let productID: Int

  var url: EndpointURL {
    .base(path: "products/\(productID)")
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
