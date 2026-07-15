import Foundation

struct ProxyConfiguration {
  let proxyPath: URL
  let apiKey: String
}

enum ProxyConfigurationError: Error, Equatable, LocalizedError {
  case proxyPathNotExecutable
  case onePasswordExecutableNotExecutable

  var errorDescription: String? {
    switch self {
    case .proxyPathNotExecutable:
      return "Proxy path is not executable"
    case .onePasswordExecutableNotExecutable:
      return "One password executable is not executable"
    }
  }
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
      throw ProxyConfigurationError.proxyPathNotExecutable
    }

    let onePasswordExecutable =
      environment["ONE_PASSWORD_EXECUTABLE"]
      .map(URL.init(fileURLWithPath:))
      ?? defaultOnePasswordExecutable

    if !checkPathIsExecutable(atPath: onePasswordExecutable) {
      throw ProxyConfigurationError.onePasswordExecutableNotExecutable
    }

    let apiKey =
      try environment["MERGE_GATEWAY_API_KEY"]
      ?? secretReader.read(executable: onePasswordExecutable, reference: onePasswordReference)

    return ProxyConfiguration(proxyPath: proxyPath, apiKey: apiKey)
  }
}
