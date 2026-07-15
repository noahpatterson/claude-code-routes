import Foundation

struct AppSettings: Equatable, Sendable {
  var claudeCodeProxyPath: String
  var claudeCodeProxyURL: String
  var mergeGatewayOnePasswordItem: String

  static let `default` = AppSettings(
    claudeCodeProxyPath: "/Users/testuser/.local/bin/claude-code-proxy",
    claudeCodeProxyURL: "http://127.0.0.1:18765/",
    mergeGatewayOnePasswordItem: ""
  )
}

struct AppSettingsStore {
  private let defaults: UserDefaults

  private enum Key {
    static let claudeCodeProxyPath = "claudeCodeProxyPath"
    static let claudeCodeProxyURL = "claudeCodeProxyURL"
    static let mergeGatewayOnePasswordItem = "mergeGatewayOnePasswordItem"
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func load() -> AppSettings {
    AppSettings(
      claudeCodeProxyPath: string(forKey: Key.claudeCodeProxyPath)
        ?? AppSettings.default.claudeCodeProxyPath,
      claudeCodeProxyURL: string(forKey: Key.claudeCodeProxyURL)
        ?? AppSettings.default.claudeCodeProxyURL,
      mergeGatewayOnePasswordItem: string(forKey: Key.mergeGatewayOnePasswordItem)
        ?? AppSettings.default.mergeGatewayOnePasswordItem
    )
  }

  func save(_ settings: AppSettings) {
    defaults.set(settings.claudeCodeProxyPath, forKey: Key.claudeCodeProxyPath)
    defaults.set(settings.claudeCodeProxyURL, forKey: Key.claudeCodeProxyURL)
    defaults.set(
      settings.mergeGatewayOnePasswordItem, forKey: Key.mergeGatewayOnePasswordItem)
  }

  private func string(forKey key: String) -> String? {
    guard defaults.object(forKey: key) != nil else { return nil }
    return defaults.string(forKey: key)
  }
}
