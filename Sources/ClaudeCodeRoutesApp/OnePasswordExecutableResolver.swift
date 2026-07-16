import Foundation

enum OnePasswordExecutableError: Error, Equatable, LocalizedError {
  case notExecutable

  var errorDescription: String? {
    "One password executable is not executable"
  }
}

struct OnePasswordExecutableResolver {
  let defaultExecutable: URL

  func resolve(
    settings: AppSettings,
    environment: [String: String]
  ) throws -> URL {
    let configuredPath =
      environment["ONE_PASSWORD_EXECUTABLE"]
      ?? settings.onePasswordExecutable

    let executable = configuredPath.isEmpty
      ? defaultExecutable
      : URL(fileURLWithPath: configuredPath)

    guard checkPathIsExecutable(atPath: executable) else {
      throw OnePasswordExecutableError.notExecutable
    }

    return executable
  }
}
