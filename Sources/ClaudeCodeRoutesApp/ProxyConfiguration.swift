// Plan to split out ClaudeCodeRoutes to different seams
//
// - ClaudeCodeRoutesApp - calls the resolver, constructs ProxyRuntime, presents alerts.
// - ProxyConfiguration.swift: resolves environment precedence and returns configuration.
// - CommandRunning.swift: hides Process and output capture.
// - OnePasswordSecretReader.swift: knows how to invoke op.
// - ProxyRuntime: remains unaware of environment variables and 1Password.
import Foundation

struct ProxyConfiguration {
  let proxyPath: URL
  let apiKey: String
}

struct ProxyConfigurationResolver {
  let defaultProxyPath: URL
  let defaultOnePasswordExecutable: URL
  let onePasswordReference: String
  let secretReader: any SecretReader

  func checkPathIsExecutable(atPath: URL) -> Bool {
    return FileManager.default.isExecutableFile(atPath: atPath.path)
  }

  func resolve(environment: [String: String]) throws -> ProxyConfiguration {
    let proxyPath =
      environment["CLAUDE_CODE_PROXY_PATH"]
      .map(URL.init(fileURLWithPath:))
      ?? defaultProxyPath

    if !checkPathIsExecutable(atPath: proxyPath) {
      throw NSError(
        domain: "ProxyConfiguration", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Proxy path is not executable"])
    }

    let onePasswordExecutable =
      environment["ONE_PASSWORD_EXECUTABLE"]
      .map(URL.init(fileURLWithPath:))
      ?? defaultOnePasswordExecutable

    if !checkPathIsExecutable(atPath: onePasswordExecutable) {
      throw NSError(
        domain: "ProxyConfiguration", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "One password executable is not executable"])
    }

    let apiKey =
      try environment["MERGE_GATEWAY_API_KEY"]
      ?? secretReader.read(executable: onePasswordExecutable, reference: onePasswordReference)

    return ProxyConfiguration(proxyPath: proxyPath, apiKey: apiKey)
  }
}
