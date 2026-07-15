import Foundation

protocol HTTPProbe: Sendable {
  func isUp(url: URL) async -> Bool
}

struct URLSessionHTTPProbe: HTTPProbe {
  func isUp(url: URL) async -> Bool {
    do {
      let (_, response) = try await URLSession.shared.data(from: url)
      return response is HTTPURLResponse
    } catch {
      return false
    }
  }
}
