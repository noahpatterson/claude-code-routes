import Foundation

public protocol RunningProcess: AnyObject {
  var processIdentifier: Int32 { get }
  var isRunning: Bool { get }
  func terminate()
}

public protocol ProcessRunning: AnyObject {
  func start(executableURL: URL, arguments: [String]) throws -> any RunningProcess
}

public final class ProxyRuntime: @unchecked Sendable {
  private let executableURL: URL
  private let arguments: [String]
  private let runner: any ProcessRunning
  private var process: (any RunningProcess)?

  public init(
    executableURL: URL,
    arguments: [String] = [],
    runner: any ProcessRunning
  ) {
    self.executableURL = executableURL
    self.arguments = arguments
    self.runner = runner
  }

  public var isHealthy: Bool {
    process?.isRunning == true
  }

  public func start() throws {
    if isHealthy {
      return
    }
    process = try runner.start(executableURL: executableURL, arguments: arguments)
  }

  public func stop() {
    process?.terminate()
    process = nil
  }
}

public final class FoundationProcessRunner: ProcessRunning {
  public init() {}

  public func start(executableURL: URL, arguments: [String]) throws -> any RunningProcess {
    let process = Process()
    process.executableURL = executableURL
    process.arguments = arguments
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    return FoundationRunningProcess(process: process)
  }
}

final class FoundationRunningProcess: RunningProcess {
  private let process: Process

  init(process: Process) {
    self.process = process
  }

  var processIdentifier: Int32 {
    process.processIdentifier
  }

  var isRunning: Bool {
    process.isRunning
  }

  func terminate() {
    guard process.isRunning else { return }
    process.terminate()
    process.waitUntilExit()
  }
}
