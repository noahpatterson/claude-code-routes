import Foundation
import Testing

@testable import ClaudeCodeRoutesApp

@Suite("AppSettingsStore")
struct AppSettingsStoreTests {

  @Test("empty store returns documented defaults")
  func emptyStoreReturnsDocumentedDefaults() {
    let suiteName = "AppSettingsStoreTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = AppSettingsStore(defaults: defaults)
    let settings = store.load()

    let expectedProxyPath = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".local/bin/claude-code-proxy").path
    #expect(settings.claudeCodeProxyPath == expectedProxyPath)
    #expect(settings.claudeCodeProxyURL == "http://127.0.0.1:18765/")
    #expect(settings.mergeGatewayOnePasswordItem == "")
    #expect(settings.onePasswordExecutable == "/opt/homebrew/bin/op")
  }

  @Test("save then load round-trips values across store instances")
  func saveThenLoadRoundTripsAcrossStoreInstances() {
    let suiteName = "AppSettingsStoreTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let saved = AppSettings(
      claudeCodeProxyPath: "/custom/bin/claude-code-proxy",
      claudeCodeProxyURL: "http://127.0.0.1:9999/",
      mergeGatewayOnePasswordItem: "op://Vault/Item/field",
      onePasswordExecutable: "/custom/bin/op"
    )
    AppSettingsStore(defaults: defaults).save(saved)

    let loaded = AppSettingsStore(defaults: defaults).load()
    #expect(loaded == saved)
  }
}
