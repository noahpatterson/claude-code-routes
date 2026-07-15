import Testing

@testable import ClaudeCodeRoutesApp

@Suite("ProxyHealth readiness")
struct ProxyHealthReadinessTests {

  @Test("url up is healthy and running even when process is down and latch is clear")
  func urlUpIsRunning() {
    var sawReady = false
    let status = FoundationProxyHealthReadiness().readiness(
      urlUp: true, processUp: false, sawReady: &sawReady)
    #expect(status.healthy == true)
    #expect(status.message == .running)
    #expect(sawReady == true)
  }

  @Test("process up before first ready is starting")
  func processUpBeforeReadyIsStarting() {
    var sawReady = false
    let status = FoundationProxyHealthReadiness().readiness(
      urlUp: false, processUp: true, sawReady: &sawReady)
    #expect(status.healthy == false)
    #expect(status.message == .starting)
  }

  @Test("process up after having been ready is not ready")
  func processUpAfterReadyIsNotReady() {
    var sawReady = true
    let status = FoundationProxyHealthReadiness().readiness(
      urlUp: false, processUp: true, sawReady: &sawReady)
    #expect(status.healthy == false)
    #expect(status.message == .notReady)
  }

  @Test("process and url both down is stopped")
  func processAndUrlDownIsStopped() {
    var sawReady = false
    let status = FoundationProxyHealthReadiness().readiness(
      urlUp: false, processUp: false, sawReady: &sawReady)
    #expect(status.healthy == false)
    #expect(status.message == .stopped)
  }

  @Test("stopped ignores the sawReady latch")
  func stoppedIgnoresSawReadyLatch() {
    var sawReady = true
    let status = FoundationProxyHealthReadiness().readiness(
      urlUp: false, processUp: false, sawReady: &sawReady)
    #expect(status.healthy == false)
    #expect(status.message == .stopped)
  }
}
