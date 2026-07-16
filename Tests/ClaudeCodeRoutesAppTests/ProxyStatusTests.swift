import Testing

@testable import ClaudeCodeRoutesApp

@Suite("ProxyStatus")
struct ProxyStatusTests {
  @Test("starting is not healthy until the proxy is ready")
  func startingIsNotHealthy() {
    #expect(!ProxyStatus.starting.isHealthy)
  }

  @Test("not ready status is displayed distinctly from starting")
  func notReadyStatusHasDistinctDisplayMessage() {
    #expect(ProxyStatus.notReady.displayMessage == "Claude Code Proxy: not ready")
  }
}
