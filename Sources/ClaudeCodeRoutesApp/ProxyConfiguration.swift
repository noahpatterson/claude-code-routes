import Foundation

struct ProxyConfiguration {
  let proxyPath: URL
  let apiKey: String
}

enum ProxyConfigurationError: Error, Equatable, LocalizedError {
  case proxyPathNotExecutable
  case onePasswordExecutableNotExecutable
  case missingOnePasswordReference

  var errorDescription: String? {
    switch self {
    case .proxyPathNotExecutable:
      return "Proxy path is not executable"
    case .onePasswordExecutableNotExecutable:
      return "One password executable is not executable"
    case .missingOnePasswordReference:
      return "Set mergeGatewayOnePasswordItem (op://Personal/ITEM/KEY) or MERGE_GATEWAY_API_KEY"
    }
  }
}

struct ProxyConfigurationResolver {
  let defaultProxyPath: URL
  let defaultOnePasswordExecutable: URL
  let onePasswordReference: String
  let secretReader: any SecretReader

  init(
    defaultProxyPath: URL,
    defaultOnePasswordExecutable: URL,
    onePasswordReference: String,
    secretReader: any SecretReader
  ) {
    self.defaultProxyPath = defaultProxyPath
    self.defaultOnePasswordExecutable = defaultOnePasswordExecutable
    self.onePasswordReference = onePasswordReference
    self.secretReader = secretReader
  }

  init(
    settings: AppSettings,
    defaultOnePasswordExecutable: URL,
    secretReader: any SecretReader
  ) {
    self.init(
      defaultProxyPath: URL(fileURLWithPath: settings.claudeCodeProxyPath),
      defaultOnePasswordExecutable: defaultOnePasswordExecutable,
      onePasswordReference: settings.mergeGatewayOnePasswordItem,
      secretReader: secretReader
    )
  }

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

    if let apiKey = environment["MERGE_GATEWAY_API_KEY"] {
      return ProxyConfiguration(proxyPath: proxyPath, apiKey: apiKey)
    }

    let trimmedReference = onePasswordReference.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedReference.isEmpty else {
      throw ProxyConfigurationError.missingOnePasswordReference
    }

    let apiKey = try secretReader.read(
      executable: onePasswordExecutable, reference: trimmedReference)
    return ProxyConfiguration(proxyPath: proxyPath, apiKey: apiKey)
  }
}
