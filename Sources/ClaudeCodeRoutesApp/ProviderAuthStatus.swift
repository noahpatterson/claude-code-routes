import Foundation

enum ProviderAuthStatus: Equatable, Sendable {
  case checking
  case connected
  case needsLogin
  case unavailable(String)

  var menuBarTitle: String {
    switch self {
    case .checking:
      return "Codex: checking…"
    case .connected:
      return "Codex: connected"
    case .needsLogin:
      return "Codex: needs login"
    case .unavailable:
      return "Codex: unavailable"
    }
  }

  var settingsMessage: String {
    switch self {
    case .checking:
      return "Checking…"
    case .connected:
      return "Connected"
    case .needsLogin:
      return "Needs login"
    case .unavailable(let message):
      return message
    }
  }

  var isConnected: Bool {
    self == .connected
  }
}

struct ProviderAuthCommandResult: Equatable, Sendable {
  let exitStatus: Int32
  let standardError: String
}

protocol ProviderAuthCommandRunning: Sendable {
  func run(executable: URL, arguments: [String]) async throws -> ProviderAuthCommandResult
}

struct FoundationProviderAuthCommandRunner: ProviderAuthCommandRunning {
  func run(executable: URL, arguments: [String]) async throws -> ProviderAuthCommandResult {
    try await Task.detached(priority: .userInitiated) {
      let process = Process()
      process.executableURL = executable
      process.arguments = arguments
      let standardError = Pipe()
      process.standardOutput = FileHandle.nullDevice
      process.standardError = standardError
      process.standardInput = FileHandle.nullDevice
      try process.run()
      process.waitUntilExit()

      return ProviderAuthCommandResult(
        exitStatus: process.terminationStatus,
        standardError: String(
          data: standardError.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8
        ) ?? ""
      )
    }.value
  }
}

struct ProviderAuthStatusChecker: Sendable {
  private let runner: any ProviderAuthCommandRunning

  init(runner: any ProviderAuthCommandRunning) {
    self.runner = runner
  }

  func codexStatus(executable: URL) async -> ProviderAuthStatus {
    do {
      let result = try await runner.run(
        executable: executable,
        arguments: ["codex", "auth", "status"]
      )
      return result.exitStatus == 0 ? .connected : .needsLogin
    } catch {
      return .unavailable(error.localizedDescription)
    }
  }

  func loginToCodex(executable: URL) async throws {
    try await runSuccessful(
      executable: executable,
      arguments: ["codex", "auth", "login"]
    )
  }

  func logoutOfCodex(executable: URL) async throws {
    try await runSuccessful(
      executable: executable,
      arguments: ["codex", "auth", "logout"]
    )
  }

  private func runSuccessful(executable: URL, arguments: [String]) async throws {
    let result = try await runner.run(executable: executable, arguments: arguments)
    guard result.exitStatus == 0 else {
      throw ProviderAuthCommandError(result: result)
    }
  }
}

private struct ProviderAuthCommandError: LocalizedError {
  let result: ProviderAuthCommandResult

  var errorDescription: String? {
    let message = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
    return message.isEmpty ? "Codex authentication command failed" : message
  }
}
