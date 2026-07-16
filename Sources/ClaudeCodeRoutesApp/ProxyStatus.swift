enum ProxyStatus: Equatable {
  case starting
  case running
  case notReady
  case stopped
  case failed(String)

  var isHealthy: Bool {
    switch self {
    case .running:
      return true
    case .starting, .notReady, .stopped, .failed:
      return false
    }
  }
  var displayMessage: String {
    switch self {
    case .starting:
      return "Claude Code Proxy: starting…"
    case .running:
      return "Claude Code Proxy: running"
    case .notReady:
      return "Claude Code Proxy: not ready"
    case .stopped:
      return "Claude Code Proxy: stopped"
    case .failed(let message):
      return "Claude Code Proxy: failed: \(message)"
    }
  }
}
