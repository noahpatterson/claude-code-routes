import Foundation

protocol SecretReader {
  func read(executable: URL, reference: String) throws -> String
}

struct OnePasswordSecretReader: SecretReader {
  let runner: any CommandRunning

  func read(executable: URL, reference: String) throws -> String {
    try runner.runCapturingOutput(
      executable: executable,
      arguments: ["read", reference]
    )
  }
}
