import Foundation
import ProxyRuntime
import Testing

@Suite("ProxyRuntime")
struct ProxyRuntimeTests {
  @Test("start leaves the runtime healthy")
  func startLeavesRuntimeHealthy() throws {
    let runner = FakeProcessRunner()
    let runtime = ProxyRuntime(
      executableURL: URL(fileURLWithPath: "/usr/bin/true"),
      runner: runner
    )

    try runtime.start()

    #expect(runtime.isHealthy)
    #expect(runner.startCallCount == 1)
  }

  @Test("stop leaves the runtime not running")
  func stopLeavesRuntimeNotRunning() throws {
    let runner = FakeProcessRunner()
    let runtime = ProxyRuntime(
      executableURL: URL(fileURLWithPath: "/usr/bin/true"),
      runner: runner
    )

    try runtime.start()
    runtime.stop()

    #expect(!runtime.isHealthy)
    #expect(runner.lastProcess?.terminateCallCount == 1)
  }

  @Test("starting twice is a no-op when already healthy")
  func startingTwiceIsNoOpWhenHealthy() throws {
    let runner = FakeProcessRunner()
    let runtime = ProxyRuntime(
      executableURL: URL(fileURLWithPath: "/usr/bin/true"),
      runner: runner
    )

    try runtime.start()
    try runtime.start()

    #expect(runtime.isHealthy)
    #expect(runner.startCallCount == 1)
  }

  @Test("Foundation runner starts and stops a real process")
  func foundationRunnerStartsAndStopsRealProcess() throws {
    let runtime = ProxyRuntime(
      executableURL: URL(fileURLWithPath: "/bin/sleep"),
      arguments: ["30"],
      runner: FoundationProcessRunner()
    )

    try runtime.start()
    #expect(runtime.isHealthy)

    runtime.stop()
    #expect(!runtime.isHealthy)
  }

  @Test("concurrent start and stop do not race")
  func concurrentStartAndStopDoNotRace() async throws {
    let runtime = ProxyRuntime(
      executableURL: URL(fileURLWithPath: "/bin/sleep"),
      arguments: ["30"],
      runner: FoundationProcessRunner()
    )

    try await withThrowingTaskGroup(of: Void.self) { group in
      for _ in 0..<20 {
        group.addTask {
          try runtime.start()
          _ = runtime.isHealthy
          runtime.stop()
        }
      }
      try await group.waitForAll()
    }

    #expect(!runtime.isHealthy)
  }
}

final class FakeProcessRunner: ProcessRunning, @unchecked Sendable {
  private(set) var startCallCount = 0
  private(set) var lastProcess: FakeRunningProcess?
  private(set) var lastEnvironment: [String: String]?

  func start(executableURL: URL, arguments: [String], environment: [String: String]) throws
    -> any RunningProcess
  {
    startCallCount += 1
    lastEnvironment = environment
    let process = FakeRunningProcess()
    lastProcess = process
    return process
  }
}

final class FakeRunningProcess: RunningProcess, @unchecked Sendable {
  private(set) var terminateCallCount = 0
  private var running = true

  var processIdentifier: Int32 { 42 }
  var isRunning: Bool { running }

  func terminate() {
    terminateCallCount += 1
    running = false
  }
}
