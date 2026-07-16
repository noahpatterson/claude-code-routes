import Testing

@testable import ClaudeCodeRoutesApp

@Suite("ProxyReadiness")
struct ProxyReadinessTests {

  @Test("URL up is running and records that readiness was reached")
  func urlUpIsRunning() {
    var readiness = ProxyReadiness()

    let status = readiness.observe(
      urlUp: true,
      processUp: false
    )

    #expect(status == .running)
    #expect(readiness.hasBeenReady)
  }

  @Test("process up before first ready is starting")
  func processUpBeforeReadyIsStarting() {
    var readiness = ProxyReadiness()

    let status = readiness.observe(
      urlUp: false,
      processUp: true
    )

    #expect(status == .starting)
    #expect(!readiness.hasBeenReady)
  }

  @Test("process up after readiness was lost is not ready")
  func processUpAfterReadyIsNotReady() {
    var readiness = ProxyReadiness()

    _ = readiness.observe(urlUp: true, processUp: true)

    let status = readiness.observe(
      urlUp: false,
      processUp: true
    )

    #expect(status == .notReady)
    #expect(readiness.hasBeenReady)
  }

  @Test("process and URL both down is stopped")
  func processAndURLDownIsStopped() {
    var readiness = ProxyReadiness()

    let status = readiness.observe(
      urlUp: false,
      processUp: false
    )

    #expect(status == .stopped)
  }

  @Test("stopped remains stopped after prior readiness")
  func stoppedIgnoresReadinessLatch() {
    var readiness = ProxyReadiness()

    _ = readiness.observe(urlUp: true, processUp: true)

    let status = readiness.observe(
      urlUp: false,
      processUp: false
    )

    #expect(status == .stopped)
  }
}
