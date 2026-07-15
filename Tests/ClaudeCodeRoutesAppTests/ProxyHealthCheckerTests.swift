import Foundation
import ProxyRuntime
import Testing

@testable import ClaudeCodeRoutesApp

@Suite("ProxyHealthChecker")
@MainActor
struct ProxyHealthCheckerTests {
  @Test("wires probe and process into starting then running")
  func wiresProbeAndProcessIntoStartingThenRunning() async throws {
    let probe = FakeHTTPProbe(results: [false, true])
    let runner = HealthTestProcessRunner()
    let runtime = ProxyRuntime(
      executableURL: URL(fileURLWithPath: "/usr/bin/true"),
      runner: runner
    )
    try runtime.start()

    var messages: [String] = []
    let proxyURL = URL(string: "http://127.0.0.1:18765/")!
    let checker = ProxyHealthChecker(proxyURL: proxyURL, probe: probe) { _, message in
      messages.append(message)
    }

    checker.monitor(runtime: runtime, interval: .milliseconds(5))

    for _ in 0..<100 {
      if messages.count >= 2 { break }
      try await Task.sleep(for: .milliseconds(10))
    }
    checker.stop()

    #expect(messages.first == ProxyHealthReadinessMessage.starting.rawValue)
    #expect(messages.contains(ProxyHealthReadinessMessage.running.rawValue))
    #expect(probe.callCount >= 2)
    #expect(probe.lastURL == proxyURL)
  }
}

/// Second adapter for the `HTTPProbe` seam — scripted reachability results.
final class FakeHTTPProbe: HTTPProbe, @unchecked Sendable {
  private var results: [Bool]
  private(set) var callCount = 0
  private(set) var lastURL: URL?

  init(results: [Bool]) {
    precondition(!results.isEmpty, "FakeHTTPProbe needs at least one result")
    self.results = results
  }

  func isUp(url: URL) async -> Bool {
    callCount += 1
    lastURL = url
    if results.count == 1 {
      return results[0]
    }
    return results.removeFirst()
  }
}

final class HealthTestProcessRunner: ProcessRunning, @unchecked Sendable {
  func start(executableURL: URL, arguments: [String], environment: [String: String]) throws
    -> any RunningProcess
  {
    HealthTestRunningProcess()
  }
}

final class HealthTestRunningProcess: RunningProcess, @unchecked Sendable {
  var processIdentifier: Int32 { 1 }
  var isRunning: Bool { true }
  func terminate() {}
}
