import Foundation
import ProxyRuntime

@MainActor
final class ProxySession {
  private let makePlanner: (AppSettings, [String: String]) throws -> ProxyLaunchPlanner
  private let processRunner: any ProcessRunning
  private let probe: any HTTPProbe
  private let pollInterval: Duration
  private let onStatusChange: (ProxyStatus) -> Void
  private let makeHealthChecker:
    (URL, any HTTPProbe, @escaping (ProxyStatus) -> Void) -> any ProxyHealthChecking
  private var runtime: ProxyRuntime?
  private var healthChecker: (any ProxyHealthChecking)?

  init(
    makePlanner: @escaping (AppSettings, [String: String]) throws -> ProxyLaunchPlanner,
    processRunner: any ProcessRunning,
    makeHealthChecker: @escaping (
      URL, any HTTPProbe, @escaping (ProxyStatus) -> Void
    ) -> any ProxyHealthChecking,
    probe: any HTTPProbe,
    pollInterval: Duration,
    onStatusChange: @escaping (ProxyStatus) -> Void,
  ) {
    self.makePlanner = makePlanner
    self.processRunner = processRunner
    self.makeHealthChecker = makeHealthChecker
    self.probe = probe
    self.pollInterval = pollInterval
    self.onStatusChange = onStatusChange
  }

  func apply(
    settings: AppSettings,
    environment: [String: String]
  ) throws {
    // Plan first so invalid settings don't stop a healthy proxy.
    let planner = try makePlanner(settings, environment)
    let plan = try planner.plan(
      settings: settings,
      environment: environment
    )

    stop()
    try start(plan)
  }

  func stop() {
    healthChecker?.stop()
    healthChecker = nil
    runtime?.stop()
    runtime = nil

    onStatusChange(.stopped)
  }

  private func start(_ plan: ProxyLaunchPlan) throws {
    let runtime = makeRuntime(for: plan)
    try runtime.start()
    self.runtime = runtime

    startMonitoring(runtime: runtime, healthURL: plan.healthProxyURL)
  }

  private func makeRuntime(for plan: ProxyLaunchPlan) -> ProxyRuntime {
    ProxyRuntime(
      executableURL: plan.executableProxyPath,
      arguments: ["serve", "--no-monitor"],
      runner: processRunner,
      environment: ["CCP_MERGE_AUTH_TOKEN": plan.apiKey]
    )
  }

  private func startMonitoring(
    runtime: ProxyRuntime,
    healthURL: URL
  ) {
    // Construct and start the checker.
    let healthChecker = makeHealthChecker(healthURL, probe, onStatusChange)
    healthChecker.monitor(runtime: runtime, interval: pollInterval)
    self.healthChecker = healthChecker
    onStatusChange(.starting)
  }
}
