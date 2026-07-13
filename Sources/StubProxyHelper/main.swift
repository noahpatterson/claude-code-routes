import Foundation

/// Long-lived stub that stands in for claude-code-proxy until a real binary is bundled.
@main
enum StubProxyHelper {
  static func main() {
    signal(SIGTERM) { _ in
      exit(0)
    }
    signal(SIGINT) { _ in
      exit(0)
    }

    while true {
      Thread.sleep(forTimeInterval: 3600)
    }
  }
}
