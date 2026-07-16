import Foundation

protocol SecretReader {
  func read(reference: String) throws -> String
}

struct OnePasswordSecretReader: SecretReader {
  let runner: any CommandRunning
  let executable: URL

  func read(reference: String) throws -> String {
    try runner.runCapturingOutput(
      executable: executable,
      arguments: ["read", reference]
    )
  }
}
