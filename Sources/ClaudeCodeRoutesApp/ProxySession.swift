import Foundation
import ProxyRuntime

@MainActor
final class ProxySession {
  private let processRunner: any ProcessRunning
  private let makeHealthChecker:
    (URL, @escaping (Bool, String) -> Void) -> any ProxyHealthChecking
  private let onStatusChange: (Bool, String) -> Void
  private let pollInterval: Duration
  private let serveArguments: [String]

  private var runtime: ProxyRuntime?
  private var healthChecker: (any ProxyHealthChecking)?

  init(
    processRunner: any ProcessRunning,
    makeHealthChecker: @escaping (URL, @escaping (Bool, String) -> Void) -> any ProxyHealthChecking,
    onStatusChange: @escaping (Bool, String) -> Void,
    pollInterval: Duration,
    serveArguments: [String] = ["serve", "--no-monitor"]
  ) {
    self.processRunner = processRunner
    self.makeHealthChecker = makeHealthChecker
    self.onStatusChange = onStatusChange
    self.pollInterval = pollInterval
    self.serveArguments = serveArguments
  }

  func apply(_ plan: ProxyLaunchPlan) throws {
    stop()

    let runtime = ProxyRuntime(
      executableURL: plan.executableURL,
      arguments: serveArguments,
      runner: processRunner,
      environment: ["CCP_MERGE_AUTH_TOKEN": plan.apiKey]
    )
    try runtime.start()
    self.runtime = runtime

    let healthChecker = makeHealthChecker(plan.healthURL, onStatusChange)
    healthChecker.monitor(runtime: runtime, interval: pollInterval)
    self.healthChecker = healthChecker
  }

  func stop() {
    healthChecker?.stop()
    healthChecker = nil
    runtime?.stop()
    runtime = nil
  }
}
