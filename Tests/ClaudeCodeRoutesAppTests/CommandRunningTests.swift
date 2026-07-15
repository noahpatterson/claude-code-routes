import Foundation
import Testing

@testable import ClaudeCodeRoutesApp

@Suite("CommandRunning")
struct CommandRunningTests {
  @Test("fake runner returns canned output")
  func fakeRunnerReturnsCannedOutput() throws {
    let runner = FakeCommandRunner()
    runner.output = "hello, world"
    let result = try runner.runCapturingOutput(
      executable: URL(fileURLWithPath: "/usr/bin/echo"),
      arguments: ["hello, world"]
    )

    #expect(result == "hello, world")
    #expect(runner.callCount == 1)
    #expect(runner.lastExecutable == URL(fileURLWithPath: "/usr/bin/echo"))
    #expect(runner.lastArguments == ["hello, world"])
  }

  @Test("fake runner throws canned error")
  func fakeRunnerThrowsCannedError() throws {
    let runner = FakeCommandRunner()
    runner.error = NSError(
      domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])

    let error = #expect(throws: NSError.self) {
      try runner.runCapturingOutput(
        executable: URL(fileURLWithPath: "/usr/bin/echo"), arguments: ["hello, world"])
    }

    #expect(error?.domain == "TestError")
    #expect(error?.code == 1)
    #expect(error?.localizedDescription == "Test error")
  }

  @Test("Foundation runner returns trimmed stdout")
  func foundationRunnerReturnsTrimmedStdout() throws {
    let runner = FoundationCommandRunner()
    let result = try runner.runCapturingOutput(
      executable: URL(fileURLWithPath: "/bin/echo"),
      arguments: ["hello, world"]
    )

    #expect(result == "hello, world")
  }

  @Test("Foundation runner throws with stderr on non-zero exit")
  func foundationRunnerThrowsWithStderrOnNonZeroExit() throws {
    let runner = FoundationCommandRunner()

    let error = #expect(throws: NSError.self) {
      try runner.runCapturingOutput(
        executable: URL(fileURLWithPath: "/bin/sh"),
        arguments: ["-c", "echo fail >&2; exit 2"]
      )
    }

    #expect(error?.domain == "Shell")
    #expect(error?.code == 2)
    #expect(error?.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines) == "fail")
  }
}

/// Second adapter for the `CommandRunning` seam — record calls, return canned output.
final class FakeCommandRunner: CommandRunning, @unchecked Sendable {
  var output: String = ""
  var error: (any Error)?
  private(set) var lastExecutable: URL?
  private(set) var lastArguments: [String]?
  private(set) var callCount = 0

  func runCapturingOutput(executable: URL, arguments: [String]) throws -> String {
    callCount += 1
    lastExecutable = executable
    lastArguments = arguments
    if let error {
      throw error
    }
    return output
  }
}
