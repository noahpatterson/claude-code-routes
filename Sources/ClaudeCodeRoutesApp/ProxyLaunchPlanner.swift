import Foundation

struct ProxyLaunchPlan: Equatable, Sendable {
  let executableProxyPath: URL
  let healthProxyURL: URL
  let apiKey: String
}

enum ProxyLaunchPlannerError: Error, Equatable, LocalizedError {
  case invalidHealthURL
  case proxyPathNotExecutable
  case onePasswordExecutableNotExecutable
  case missingOnePasswordReference

  var errorDescription: String? {
    switch self {
    case .invalidHealthURL:
      return "claudeCodeProxyURL is not a valid URL"
    case .proxyPathNotExecutable:
      return "Proxy path is not executable"
    case .onePasswordExecutableNotExecutable:
      return "One password executable is not executable"
    case .missingOnePasswordReference:
      return "Set mergeGatewayOnePasswordItem (op://Personal/ITEM/KEY) or MERGE_GATEWAY_API_KEY"
    }
  }
}

struct ProxyLaunchPlanner {
  let defaultOnePasswordExecutable: URL
  let secretReader: any SecretReader

  func plan(
    settings: AppSettings,
    environment: [String: String]
  ) throws -> ProxyLaunchPlan {

    let proxyPath = try resolveProxyPath(settings: settings, environment: environment)
    let apiKey = try resolveApiKey(settings: settings, environment: environment)
    let healthURL = try resolveHealthURL(settings: settings)

    return ProxyLaunchPlan(
      executableProxyPath: proxyPath,
      healthProxyURL: healthURL,
      apiKey: apiKey
    )
  }

  private func checkPathIsExecutable(atPath: URL) -> Bool {
    return FileManager.default.isExecutableFile(atPath: atPath.path)
  }

  private func resolveProxyPath(settings: AppSettings, environment: [String: String]) throws -> URL
  {
    let proxyPath =
      environment["CLAUDE_CODE_PROXY_PATH"]
      .map(URL.init(fileURLWithPath:)) ?? URL(fileURLWithPath: settings.claudeCodeProxyPath)

    if !checkPathIsExecutable(atPath: proxyPath) {
      throw ProxyLaunchPlannerError.proxyPathNotExecutable
    }

    return proxyPath
  }

  private func resolveOnePasswordExecutable(settings: AppSettings, environment: [String: String])
    throws -> URL
  {
    let onePasswordExecutable =
      environment["ONE_PASSWORD_EXECUTABLE"]
      .map(URL.init(fileURLWithPath:))
      ?? URL(fileURLWithPath: settings.onePasswordExecutable)

    if !checkPathIsExecutable(atPath: onePasswordExecutable) {
      throw ProxyLaunchPlannerError.onePasswordExecutableNotExecutable
    }

    return onePasswordExecutable
  }

  private func resolveApiKey(settings: AppSettings, environment: [String: String]) throws -> String
  {
    if let apiKey = environment["MERGE_GATEWAY_API_KEY"] {
      return apiKey
    }

    let trimmedReference = settings.mergeGatewayOnePasswordItem.trimmingCharacters(
      in: .whitespacesAndNewlines)
    guard !trimmedReference.isEmpty else {
      throw ProxyLaunchPlannerError.missingOnePasswordReference
    }

    let apiKey = try secretReader.read(
      executable: resolveOnePasswordExecutable(settings: settings, environment: environment),
      reference: trimmedReference)
    return apiKey
  }

  private func resolveHealthURL(settings: AppSettings) throws -> URL {
    guard let healthURL = URL(string: settings.claudeCodeProxyURL),
      healthURL.scheme != nil,
      healthURL.host != nil
    else {
      throw ProxyLaunchPlannerError.invalidHealthURL
    }

    return healthURL
  }
}
