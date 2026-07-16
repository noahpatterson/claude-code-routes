enum ProxyStatus: Equatable {
  case starting
  case running
  case notReady
  case stopped
  case failed(String)

  var isHealthy: Bool {
    switch self {
    case .starting, .running:
      return true
    case .notReady, .stopped, .failed:
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
      return "Claude Code Proxy: starting…"
    case .stopped:
      return "Claude Code Proxy: stopped"
    case .failed(let message):
      return "Claude Code Proxy: failed: \(message)"
    }
  }
}
