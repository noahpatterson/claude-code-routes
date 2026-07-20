import Foundation

struct ProxyLaunchPlan: Equatable, Sendable {
  let executableProxyPath: URL
  let healthProxyURL: URL
  let apiKey: String
}

enum ProxyLaunchPlannerError: Error, Equatable, LocalizedError {
  case invalidHealthURL
  case proxyPathNotExecutable
  case missingOnePasswordReference

  var errorDescription: String? {
    switch self {
    case .invalidHealthURL:
      return "claudeCodeProxyURL is not a valid URL"
    case .proxyPathNotExecutable:
      return "Proxy path is not executable"
    case .missingOnePasswordReference:
      return "Set mergeGatewayOnePasswordItem (op://Vault/Item/field) or MERGE_GATEWAY_API_KEY"
    }
  }
}

struct ProxyLaunchPlanner {
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

  private func resolveApiKey(settings: AppSettings, environment: [String: String]) throws -> String
  {
    if let apiKey = environment["MERGE_GATEWAY_API_KEY"]?.trimmingCharacters(
      in: .whitespacesAndNewlines), !apiKey.isEmpty
    {
      return apiKey
    }

    let trimmedReference = settings.mergeGatewayOnePasswordItem.trimmingCharacters(
      in: .whitespacesAndNewlines)
    guard !trimmedReference.isEmpty else {
      throw ProxyLaunchPlannerError.missingOnePasswordReference
    }

    let apiKey = try secretReader.read(
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
