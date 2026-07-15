import Foundation

enum ProxyHealthReadinessMessage: String {
  case running = "Claude Code Proxy: running"
  case starting = "Claude Code Proxy: starting…"
  case notReady = "Claude Code Proxy: not ready"
  case stopped = "Claude Code Proxy: stopped"
}

struct ProxyHealthReadinessStatus: Equatable {
  let healthy: Bool
  let message: ProxyHealthReadinessMessage
}

protocol ProxyHealthReadiness {
  func readiness(urlUp: Bool, processUp: Bool, sawReady: inout Bool) -> ProxyHealthReadinessStatus
}

struct FoundationProxyHealthReadiness: ProxyHealthReadiness {
  func readiness(urlUp: Bool, processUp: Bool, sawReady: inout Bool) -> ProxyHealthReadinessStatus {
    if urlUp {
      sawReady = true
      return ProxyHealthReadinessStatus(healthy: true, message: .running)
    } else if processUp {
      return ProxyHealthReadinessStatus(healthy: false, message: sawReady ? .notReady : .starting)
    } else {
      return ProxyHealthReadinessStatus(healthy: false, message: .stopped)
    }
  }
}
