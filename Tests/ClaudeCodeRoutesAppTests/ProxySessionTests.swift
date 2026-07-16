import Foundation
import ProxyRuntime
import Testing

@testable import ClaudeCodeRoutesApp

@Suite("ProxySession")
@MainActor
struct ProxySessionTests {

  @Test("apply starts runtime with plan; second apply restarts with new plan")
  func applyRestartsWithNewPlan() throws {
    let first = createEmptyExecutableFile(suffix: "first")
    let second = createEmptyExecutableFile(suffix: "second")
    let runner = RecordingProcessRunner()
    let session = ProxySession(
      planner: ProxyLaunchPlanner(
        defaultOnePasswordExecutable: first,
        secretReader: OnePasswordSecretReader(runner: FoundationCommandRunner())
      ),
      processRunner: runner,
      makeHealthChecker: { url, _, onChange in
        FakeHealthChecker(proxyURL: url, onStatusChange: onChange)
      },
      probe: URLSessionHTTPProbe(),
      pollInterval: .seconds(60),
      onStatusChange: { status in
        // onChange(status)
      }
    )

    try session.apply(
      settings: AppSettings(
        claudeCodeProxyPath: first.path,
        claudeCodeProxyURL: "http://127.0.0.1:1/",
        mergeGatewayOnePasswordItem: "key-1",
        onePasswordExecutable: second.path
      ),
      environment: ["MERGE_GATEWAY_API_KEY": "key-1"]
    )
    #expect(runner.startedExecutableURLs == [first])
    #expect(runner.startedEnvironments == [["CCP_MERGE_AUTH_TOKEN": "key-1"]])
    #expect(runner.terminatedCount == 0)

    try session.apply(
      settings: AppSettings(
        claudeCodeProxyPath: second.path,
        claudeCodeProxyURL: "http://127.0.0.1:2/",
        mergeGatewayOnePasswordItem: "key-2",
        onePasswordExecutable: first.path
      ),
      environment: ["MERGE_GATEWAY_API_KEY": "key-2"]
    )
    #expect(runner.startedExecutableURLs == [first, second])
    #expect(
      runner.startedEnvironments == [
        ["CCP_MERGE_AUTH_TOKEN": "key-1"],
        ["CCP_MERGE_AUTH_TOKEN": "key-2"],
      ]
    )
    #expect(runner.terminatedCount == 1)

    session.stop()
    #expect(runner.terminatedCount == 2)
  }
}

@MainActor
final class FakeHealthChecker: ProxyHealthChecking {
  let proxyURL: URL
  let onStatusChange: (ProxyStatus) -> Void
  private(set) var monitorCount = 0
  private(set) var stopCount = 0

  init(proxyURL: URL, onStatusChange: @escaping (ProxyStatus) -> Void) {
    self.proxyURL = proxyURL
    self.onStatusChange = onStatusChange
  }

  func monitor(runtime: ProxyRuntime, interval: Duration) {
    monitorCount += 1
  }

  func stop() {
    stopCount += 1
  }
}

final class RecordingProcessRunner: ProcessRunning, @unchecked Sendable {
  private(set) var startedExecutableURLs: [URL] = []
  private(set) var startedEnvironments: [[String: String]] = []
  private(set) var terminatedCount = 0

  func start(executableURL: URL, arguments: [String], environment: [String: String]) throws
    -> any RunningProcess
  {
    startedExecutableURLs.append(executableURL)
    startedEnvironments.append(environment)
    return RecordingRunningProcess { [weak self] in
      self?.terminatedCount += 1
    }
  }
}

final class RecordingRunningProcess: RunningProcess {
  private let onTerminate: () -> Void
  private(set) var isRunning = true
  let processIdentifier: Int32 = 1

  init(onTerminate: @escaping () -> Void) {
    self.onTerminate = onTerminate
  }

  func terminate() {
    guard isRunning else { return }
    isRunning = false
    onTerminate()
  }
}
