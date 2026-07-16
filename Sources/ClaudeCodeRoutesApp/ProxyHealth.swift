import Foundation
import ProxyRuntime

struct ProxyReadiness {
  private(set) var hasBeenReady = false

  mutating func observe(urlUp: Bool, processUp: Bool) -> ProxyStatus {
    if urlUp {
      hasBeenReady = true
      return .running
    } else if processUp {
      return hasBeenReady ? .notReady : .starting
    } else {
      return .stopped
    }
  }
}

@MainActor
protocol ProxyHealthChecking: AnyObject {
  func monitor(runtime: ProxyRuntime, interval: Duration)
  func stop()
}

/// Keeps polling the ready URL until quit, reporting readiness changes.
///
/// URL reachability is the source of truth for ●/○; process liveness only
/// distinguishes "starting/not ready" vs "stopped" when the URL is down.
@MainActor
final class ProxyHealthChecker: ProxyHealthChecking {
  private let probe: HTTPProbe
  private let proxyURL: URL
  private let onStatusChange: (ProxyStatus) -> Void
  private var healthPollTask: Task<Void, Never>?

  init(
    proxyURL: URL,
    probe: HTTPProbe = URLSessionHTTPProbe(),
    onStatusChange: @escaping (ProxyStatus) -> Void
  ) {
    self.proxyURL = proxyURL
    self.probe = probe
    self.onStatusChange = onStatusChange
  }

  func monitor(runtime: ProxyRuntime, interval: Duration) {
    healthPollTask?.cancel()
    healthPollTask = Task { [weak self] in
      guard let self else { return }
      let probe = self.probe
      let proxyURL = self.proxyURL
      var lastMessage: String?
      var readinessChecker = ProxyReadiness()

      while !Task.isCancelled {
        let processUp = runtime.isHealthy
        let urlUp = await probe.isUp(url: proxyURL)
        guard !Task.isCancelled else { break }

        let status = readinessChecker.observe(
          urlUp: urlUp, processUp: processUp)

        if lastMessage != status.displayMessage {
          lastMessage = status.displayMessage
          self.onStatusChange(status)
          if !processUp && urlUp {
            NSLog(
              "ClaudeCodeRoutes: proxy URL is up but the managed process is not running (another instance may own the port)"
            )
          }
        }

        try? await Task.sleep(for: interval)
      }
    }
  }

  func stop() {
    healthPollTask?.cancel()
    healthPollTask = nil
  }
}
