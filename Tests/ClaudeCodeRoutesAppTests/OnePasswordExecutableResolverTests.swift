import Foundation
import Testing

@testable import ClaudeCodeRoutesApp

@Suite("OnePasswordExecutableResolver")
struct OnePasswordExecutableResolverTests {

  @Test("environment executable overrides the settings executable")
  func environmentExecutableOverridesSettings() throws {
    let settingsExecutable = createEmptyExecutableFile(suffix: "settings-op")
    let environmentExecutable = createEmptyExecutableFile(suffix: "environment-op")
    let settings = makeSettings(executable: settingsExecutable)
    let resolver = OnePasswordExecutableResolver(
      defaultExecutable: createEmptyExecutableFile(suffix: "default-op")
    )

    let executable = try resolver.resolve(
      settings: settings,
      environment: ["ONE_PASSWORD_EXECUTABLE": environmentExecutable.path]
    )

    #expect(executable == environmentExecutable)
  }

  @Test("settings executable is used without an environment override")
  func settingsExecutableIsUsed() throws {
    let settingsExecutable = createEmptyExecutableFile(suffix: "settings-op")
    let settings = makeSettings(executable: settingsExecutable)
    let resolver = OnePasswordExecutableResolver(
      defaultExecutable: createEmptyExecutableFile(suffix: "default-op")
    )

    let executable = try resolver.resolve(settings: settings, environment: [:])

    #expect(executable == settingsExecutable)
  }

  @Test("empty settings executable falls back to the default")
  func emptySettingsExecutableUsesDefault() throws {
    let defaultExecutable = createEmptyExecutableFile(suffix: "default-op")
    let resolver = OnePasswordExecutableResolver(defaultExecutable: defaultExecutable)
    let settings = AppSettings(
      claudeCodeProxyPath: "/bin/true",
      claudeCodeProxyURL: "http://127.0.0.1:18765/",
      mergeGatewayOnePasswordItem: "op://Personal/ITEM/KEY",
      onePasswordExecutable: ""
    )

    let executable = try resolver.resolve(
      settings: settings,
      environment: [:]
    )

    #expect(executable == defaultExecutable)
  }

  @Test("non-executable selected path throws")
  func nonExecutablePathThrows() throws {
    let resolver = OnePasswordExecutableResolver(
      defaultExecutable: createEmptyExecutableFile(suffix: "default-op")
    )
    let nonExecutable = createNonExecutableFile(suffix: "op")

    #expect(throws: OnePasswordExecutableError.notExecutable) {
      try resolver.resolve(
        settings: makeSettings(executable: nonExecutable),
        environment: [:]
      )
    }
  }

  private func makeSettings(executable: URL) -> AppSettings {
    AppSettings(
      claudeCodeProxyPath: "/bin/true",
      claudeCodeProxyURL: "http://127.0.0.1:18765/",
      mergeGatewayOnePasswordItem: "op://Personal/ITEM/KEY",
      onePasswordExecutable: executable.path
    )
  }
}
