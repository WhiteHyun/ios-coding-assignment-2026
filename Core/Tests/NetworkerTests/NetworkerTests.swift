import Testing
@testable import Networker

@Test
func `exposes HTTP methods`() {
  #expect(HTTPMethod.get.rawValue == "GET")
}
