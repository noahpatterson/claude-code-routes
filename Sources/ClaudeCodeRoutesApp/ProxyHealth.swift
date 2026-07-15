import Foundation
import ProxyRuntime

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
  private let proxyURL: URL
  private let onStatusChange: (Bool, String) -> Void
  private var healthPollTask: Task<Void, Never>?

  init(proxyURL: URL, onStatusChange: @escaping (Bool, String) -> Void) {
    self.proxyURL = proxyURL
    self.onStatusChange = onStatusChange
  }

  func monitor(runtime: ProxyRuntime, interval: Duration) {
    healthPollTask?.cancel()
    healthPollTask = Task { [weak self] in
      guard let self else { return }
      var lastMessage: String?
      var sawReady = false
      let readinessChecker = FoundationProxyHealthReadiness()

      while !Task.isCancelled {
        let processUp = runtime.isHealthy
        let urlUp = await self.isProxyRunningViaURL()

        let status = readinessChecker.readiness(
          urlUp: urlUp, processUp: processUp, sawReady: &sawReady)

        if lastMessage != status.message.rawValue {
          lastMessage = status.message.rawValue
          self.onStatusChange(status.healthy, status.message.rawValue)
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

  /// True when something is accepting HTTP on the proxy port.
  ///
  /// `GET /` returns 404 JSON from claude-code-proxy — that still means the
  /// server is up, so any `HTTPURLResponse` counts as ready (not only 200).
  private func isProxyRunningViaURL() async -> Bool {
    do {
      let (_, response) = try await URLSession.shared.data(from: proxyURL)
      return response is HTTPURLResponse
    } catch {
      return false
    }
  }
}
