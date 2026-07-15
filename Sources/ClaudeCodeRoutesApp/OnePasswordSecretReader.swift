// Plan to split out ClaudeCodeRoutes to different seams
//
// - ClaudeCodeRoutesApp - calls the resolver, constructs ProxyRuntime, presents alerts.
// - ProxyConfiguration.swift: resolves environment precedence and returns configuration.
// - CommandRunning.swift: hides Process and output capture.
// - OnePasswordSecretReader.swift: knows how to invoke op.
// - ProxyRuntime: remains unaware of environment variables and 1Password.

import Foundation

protocol SecretReader {
  func read(executable: URL, reference: String) throws -> String
}

struct OnePasswordSecretReader: SecretReader {
  let runner: any CommandRunning
  func read(executable: URL, reference: String) throws -> String {
    return try runner.runCapturingOutput(
      executable: executable,
      arguments: ["read", reference]
    )
  }
}
