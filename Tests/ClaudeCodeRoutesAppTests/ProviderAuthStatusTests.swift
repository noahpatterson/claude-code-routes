import Foundation
import Testing

@testable import ClaudeCodeRoutesApp

@Suite("ProviderAuthStatus")
struct ProviderAuthStatusTests {
  private let proxyExecutable = URL(fileURLWithPath: "/usr/local/bin/claude-code-proxy")

  @Test("successful status command means Codex is connected")
  func successfulStatusCommandMeansCodexIsConnected() async {
    let runner = FakeProviderAuthCommandRunner(
      result: ProviderAuthCommandResult(
        exitStatus: 0,
        standardError: ""
      )
    )
    let checker = ProviderAuthStatusChecker(runner: runner)

    let status = await checker.codexStatus(executable: proxyExecutable)

    #expect(status == .connected)
    #expect(await runner.callCount == 1)
    #expect(await runner.lastExecutable == proxyExecutable)
    #expect(await runner.lastArguments == ["codex", "auth", "status"])
  }

  @Test("nonzero status command means Codex needs login")
  func nonzeroStatusCommandMeansCodexNeedsLogin() async {
    let runner = FakeProviderAuthCommandRunner(
      result: ProviderAuthCommandResult(
        exitStatus: 1,
        standardError: "No Codex credentials found"
      )
    )
    let checker = ProviderAuthStatusChecker(runner: runner)

    let status = await checker.codexStatus(executable: proxyExecutable)

    #expect(status == .needsLogin)
  }

  @Test("status command launch failure is visible as unavailable")
  func statusCommandLaunchFailureIsVisibleAsUnavailable() async {
    let runner = FakeProviderAuthCommandRunner(error: FakeProviderAuthCommandError.unavailable)
    let checker = ProviderAuthStatusChecker(runner: runner)

    let status = await checker.codexStatus(executable: proxyExecutable)

    #expect(status == .unavailable("Proxy command is unavailable"))
  }

  @Test("login starts the Codex browser auth command")
  func loginStartsTheCodexBrowserAuthCommand() async throws {
    let runner = FakeProviderAuthCommandRunner(
      result: ProviderAuthCommandResult(exitStatus: 0, standardError: "")
    )
    let checker = ProviderAuthStatusChecker(runner: runner)

    try await checker.loginToCodex(executable: proxyExecutable)

    #expect(await runner.lastExecutable == proxyExecutable)
    #expect(await runner.lastArguments == ["codex", "auth", "login"])
  }

  @Test("logout surfaces a failed Codex command")
  func logoutSurfacesAFailedCodexCommand() async {
    let runner = FakeProviderAuthCommandRunner(
      result: ProviderAuthCommandResult(exitStatus: 1, standardError: "Unable to clear credentials")
    )
    let checker = ProviderAuthStatusChecker(runner: runner)
    var didThrow = false

    do {
      try await checker.logoutOfCodex(executable: proxyExecutable)
    } catch {
      didThrow = true
      #expect(error.localizedDescription == "Unable to clear credentials")
    }

    #expect(didThrow)
    #expect(await runner.lastArguments == ["codex", "auth", "logout"])
  }
}

private actor FakeProviderAuthCommandRunner: ProviderAuthCommandRunning {
  private let outcome: FakeProviderAuthCommandOutcome
  private(set) var callCount = 0
  private(set) var lastExecutable: URL?
  private(set) var lastArguments: [String]?

  init(result: ProviderAuthCommandResult) {
    outcome = .result(result)
  }

  init(error: FakeProviderAuthCommandError) {
    outcome = .error(error)
  }

  func run(executable: URL, arguments: [String]) async throws -> ProviderAuthCommandResult {
    callCount += 1
    lastExecutable = executable
    lastArguments = arguments
    switch outcome {
    case .result(let result):
      return result
    case .error(let error):
      throw error
    }
  }
}

private enum FakeProviderAuthCommandOutcome: Sendable {
  case result(ProviderAuthCommandResult)
  case error(FakeProviderAuthCommandError)
}

private enum FakeProviderAuthCommandError: LocalizedError, Sendable {
  case unavailable

  var errorDescription: String? {
    "Proxy command is unavailable"
  }
}
