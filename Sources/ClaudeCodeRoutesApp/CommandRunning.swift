import Foundation

protocol CommandRunning {
  func runCapturingOutput(executable: URL, arguments: [String]) throws -> String
}

struct FoundationCommandRunner: CommandRunning {
  func runCapturingOutput(
    executable: URL,
    arguments: [String]
  ) throws -> String {
    let process = Process()
    process.executableURL = executable
    process.arguments = arguments
    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr
    process.standardInput = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    let outData = stdout.fileHandleForReading.readDataToEndOfFile()
    let errData = stderr.fileHandleForReading.readDataToEndOfFile()
    guard process.terminationStatus == 0 else {
      let message = String(data: errData, encoding: .utf8) ?? "unknown error"
      throw NSError(
        domain: "Shell",
        code: Int(process.terminationStatus),
        userInfo: [NSLocalizedDescriptionKey: message]
      )
    }
    return String(data: outData, encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }
}
