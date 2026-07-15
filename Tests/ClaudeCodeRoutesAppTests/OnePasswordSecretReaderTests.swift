import Foundation
import Testing

@testable import ClaudeCodeRoutesApp

@Suite("OnePasswordSecretReader")
struct OnePasswordSecretReaderTests {
  @Test("read invokes the runner with op read arguments")
  func readInvokesRunnerWithOpReadArguments() throws {
    let runner = FakeCommandRunner()
    runner.output = "secret-value"
    let executable = URL(fileURLWithPath: "/opt/homebrew/bin/op")
    let reference = "op://Personal/Merge/apikey"
    let reader = OnePasswordSecretReader(runner: runner)

    _ = try reader.read(executable: executable, reference: reference)

    #expect(runner.callCount == 1)
    #expect(runner.lastExecutable == executable)
    #expect(runner.lastArguments == ["read", reference])
  }

  @Test("read returns the runner output")
  func readReturnsRunnerOutput() throws {
    let runner = FakeCommandRunner()
    runner.output = "secret-from-op"
    let reader = OnePasswordSecretReader(runner: runner)

    let apiKey = try reader.read(
      executable: URL(fileURLWithPath: "/opt/homebrew/bin/op"),
      reference: "op://vault/item/field"
    )

    #expect(apiKey == "secret-from-op")
  }

  @Test("read propagates runner errors")
  func readPropagatesRunnerErrors() throws {
    let runner = FakeCommandRunner()
    let expectedError = NSError(
      domain: "Shell",
      code: 1,
      userInfo: [NSLocalizedDescriptionKey: "op not signed in"]
    )
    runner.error = expectedError
    let reader = OnePasswordSecretReader(runner: runner)

    let error = #expect(throws: NSError.self) {
      try reader.read(
        executable: URL(fileURLWithPath: "/opt/homebrew/bin/op"),
        reference: "op://vault/item/field"
      )
    }

    #expect(error?.domain == expectedError.domain)
    #expect(error?.code == expectedError.code)
    #expect(error?.localizedDescription == expectedError.localizedDescription)
    #expect(runner.callCount == 1)
  }
}
