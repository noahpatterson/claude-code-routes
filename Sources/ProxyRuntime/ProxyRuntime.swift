import Foundation

public protocol RunningProcess: AnyObject {
  var processIdentifier: Int32 { get }
  var isRunning: Bool { get }
  func terminate()
}

public protocol ProcessRunning: AnyObject {
  func start(executableURL: URL, arguments: [String], environment: [String: String]) throws
    -> any RunningProcess
}

/// Owns the lifecycle of the local proxy helper process.
///
/// All mutable state is guarded by `stateLock` so `start` / `stop` / `isHealthy`
/// are safe to call from concurrent contexts (e.g. main thread + signal path).
public final class ProxyRuntime: @unchecked Sendable {
  private let executableURL: URL
  private let arguments: [String]
  private let runner: any ProcessRunning
  private let stateLock = NSLock()
  private var process: (any RunningProcess)?
  private let environment: [String: String]

  public init(
    executableURL: URL,
    arguments: [String] = [],
    runner: any ProcessRunning,
    environment: [String: String] = [:]
  ) {
    self.executableURL = executableURL
    self.arguments = arguments
    self.runner = runner
    self.environment = environment
  }

  public var isHealthy: Bool {
    stateLock.lock()
    defer { stateLock.unlock() }
    return process?.isRunning == true
  }

  public func start() throws {
    stateLock.lock()
    defer { stateLock.unlock() }
    if process?.isRunning == true {
      return
    }
    process = try runner.start(
      executableURL: executableURL, arguments: arguments, environment: environment)
  }

  public func stop() {
    stateLock.lock()
    let current = process
    process = nil
    stateLock.unlock()
    current?.terminate()
  }
}

public final class FoundationProcessRunner: ProcessRunning {
  public init() {}

  public func start(executableURL: URL, arguments: [String], environment: [String: String])
    throws -> any RunningProcess
  {
    let process = Process()
    process.executableURL = executableURL
    process.arguments = arguments
    // Merge overlays into the current env; assigning only the overlay would
    // drop PATH/HOME and break most child processes.
    var merged = ProcessInfo.processInfo.environment
    for (key, value) in environment {
      merged[key] = value
    }
    process.environment = merged
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
