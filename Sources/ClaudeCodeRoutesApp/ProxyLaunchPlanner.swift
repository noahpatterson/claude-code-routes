import Foundation

struct ProxyLaunchPlan: Equatable, Sendable {
  let executableURL: URL
  let healthURL: URL
  let apiKey: String
}

enum ProxyLaunchPlannerError: Error, Equatable, LocalizedError {
  case invalidHealthURL

  var errorDescription: String? {
    switch self {
    case .invalidHealthURL:
      return "claudeCodeProxyURL is not a valid URL"
    }
  }
}

struct ProxyLaunchPlanner {
  let defaultOnePasswordExecutable: URL
  let secretReader: any SecretReader

  func plan(settings: AppSettings, environment: [String: String]) throws -> ProxyLaunchPlan {
    let configuration = try ProxyConfigurationResolver(
      settings: settings,
      defaultOnePasswordExecutable: defaultOnePasswordExecutable,
      secretReader: secretReader
    ).resolve(environment: environment)

    guard let healthURL = URL(string: settings.claudeCodeProxyURL),
      healthURL.scheme != nil,
      healthURL.host != nil
    else {
      throw ProxyLaunchPlannerError.invalidHealthURL
    }

    return ProxyLaunchPlan(
      executableURL: configuration.proxyPath,
      healthURL: healthURL,
      apiKey: configuration.apiKey
    )
  }
}
