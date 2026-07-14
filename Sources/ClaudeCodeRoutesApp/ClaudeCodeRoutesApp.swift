import AppKit
import Foundation
import ProxyRuntime
import SwiftUI

private enum Constants {
  static let claudeCodeProxyPath = "/Users/testuser/.local/bin/claude-code-proxy"
  static let claudeCodeProxyURL = "http://127.0.0.1:18765/"
  static let mergeGatewayOnePasswordItem = "op://Personal/Merge/apikey"
  static let proxyReadyPollInterval: Duration = .seconds(1)
}

private func runCommandCapturingOutput(
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

@main
struct ClaudeCodeRoutesApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    // Settings scene keeps the SwiftUI app lifecycle alive for a menu-bar-only app.
    Settings {
      EmptyView()
    }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem?
  private var runtime: ProxyRuntime?
  private var signalSources: [DispatchSourceSignal] = []
  private var healthPollTask: Task<Void, Never>?

  private var getClaudeCodeProxyPathFromEnvironment: URL? {
    if let path = ProcessInfo.processInfo.environment["CLAUDE_CODE_PROXY_PATH"] {
      return URL(fileURLWithPath: path)
    }
    return nil
  }

  private var getMergeGatewayAPIKeyFromEnvironment: String? {
    if let key = ProcessInfo.processInfo.environment["MERGE_GATEWAY_API_KEY"] {
      return key
    }
    return nil
  }

  private var getMergeGatewayAPIKeyFromOnePassword: String? {
    do {
      let key = try runCommandCapturingOutput(
        executable: URL(fileURLWithPath: "/opt/homebrew/bin/op"),  // or resolve via `which`
        arguments: ["read", Constants.mergeGatewayOnePasswordItem]
      )
      return key
    } catch {
      NSLog(
        "ClaudeCodeRoutes: failed to get merge gateway API key from one password: \(error.localizedDescription)"
      )
      presentAlert(
        title: "Failed to get merge gateway API key from one password",
        message: error.localizedDescription
      )
      return nil
    }
  }

  // TODO: can this be hoisted so it's viewable by SwiftUI?
  private var claudeCodeProxyPath: URL {
    if let path = getClaudeCodeProxyPathFromEnvironment {
      return path
    }
    return URL(fileURLWithPath: Constants.claudeCodeProxyPath)
  }

  /// True when something is accepting HTTP on the proxy port.
  ///
  /// `GET /` returns 404 JSON from claude-code-proxy — that still means the
  /// server is up, so any `HTTPURLResponse` counts as ready (not only 200).
  private func isProxyRunningViaURL() async -> Bool {
    guard let url = URL(string: Constants.claudeCodeProxyURL) else {
      return false
    }

    do {
      let (_, response) = try await URLSession.shared.data(from: url)
      return response is HTTPURLResponse
    } catch {
      return false
    }
  }

  /// Keeps polling the ready URL until quit, updating the menu when readiness
  /// flips. URL reachability is the source of truth for ●/○; process liveness
  /// only distinguishes "starting/not ready" vs "stopped" when the URL is down.
  private func monitorProxyHealth(interval: Duration = Constants.proxyReadyPollInterval) {
    healthPollTask?.cancel()
    healthPollTask = Task { @MainActor [weak self] in
      guard let self else { return }
      var lastMessage: String?
      var sawReady = false

      while !Task.isCancelled {
        let processUp = self.runtime?.isHealthy == true
        let urlUp = await self.isProxyRunningViaURL()

        let healthy: Bool
        let message: String
        if urlUp {
          healthy = true
          sawReady = true
          message = "Claude Code Proxy: running"
        } else if processUp {
          healthy = false
          message =
            sawReady
            ? "Claude Code Proxy: not ready"
            : "Claude Code Proxy: starting…"
        } else {
          healthy = false
          message = "Claude Code Proxy: stopped"
        }

        if lastMessage != message {
          lastMessage = message
          self.updateStatusItem(healthy: healthy, statusMessage: message)
          if !processUp && urlUp {
            NSLog(
              "ClaudeCodeRoutes: proxy URL is up but the managed process is not running (another instance may own the port)"
            )
          }
        }

        try? await Task.sleep(for: interval)
      }
    }
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    installSignalHandlers()

    // check if the claude code proxy binary is executable
    if !FileManager.default.isExecutableFile(atPath: claudeCodeProxyPath.path) {
      installStatusItem(healthy: false, statusMessage: "Proxy: claude-code-proxy not found")
      presentAlert(
        title: "Claude Code Proxy not found",
        message:
          "Claude Code Proxy was not found at \(claudeCodeProxyPath.path). Set the CLAUDE_CODE_PROXY_PATH environment variable to the path to the claude-code-proxy binary or use the default path of \(Constants.claudeCodeProxyPath)."
      )
      return
    }

    // try to get the merge gateway API key from the environment or one password
    guard
      let mergeGatewayAPIKey =
        getMergeGatewayAPIKeyFromEnvironment ?? getMergeGatewayAPIKeyFromOnePassword
    else {
      installStatusItem(healthy: false, statusMessage: "Merge Gateway: API key not found")
      presentAlert(
        title: "Merge Gateway API key not found",
        message:
          "Merge Gateway API key was not found. Set the MERGE_GATEWAY_API_KEY environment variable or use the default path of \(Constants.mergeGatewayOnePasswordItem)."
      )
      return
    }

    let proxyURL = claudeCodeProxyPath
    let arguments = [
      "serve",
      "--no-monitor",
    ]
    let runtime = ProxyRuntime(
      executableURL: proxyURL,
      arguments: arguments,
      runner: FoundationProcessRunner(),
      environment: [
        "CCP_MERGE_AUTH_TOKEN": mergeGatewayAPIKey
      ]
    )
    self.runtime = runtime

    do {
      try runtime.start()
    } catch {
      installStatusItem(healthy: false, statusMessage: "Claude Code Proxy: failed to start")
      presentAlert(
        title: "Claude Code Proxy failed to start",
        message: """
          Claude Code Proxy failed to start: \(error.localizedDescription).
          """
      )
      return
    }

    installStatusItem(healthy: false, statusMessage: "Claude Code Proxy: starting…")
    monitorProxyHealth()
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    stopProxy()
    return .terminateNow
  }

  func applicationWillTerminate(_ notification: Notification) {
    stopProxy()
  }

  private func stopProxy() {
    healthPollTask?.cancel()
    healthPollTask = nil
    runtime?.stop()
    runtime = nil
  }

  private func installStatusItem(healthy: Bool, statusMessage: String) {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    item.button?.toolTip = "Claude Code Routes"
    statusItem = item
    updateStatusItem(healthy: healthy, statusMessage: statusMessage)
  }

  private func updateStatusItem(healthy: Bool, statusMessage: String) {
    guard let item = statusItem else { return }
    item.button?.title = healthy ? "CCR ●" : "CCR ○"

    let menu = NSMenu()
    menu.addItem(NSMenuItem(title: statusMessage, action: nil, keyEquivalent: ""))
    menu.addItem(NSMenuItem.separator())
    menu.addItem(
      NSMenuItem(
        title: "Quit Claude Code Routes", action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q")
    )
    item.menu = menu
  }

  private func presentAlert(title: String, message: String) {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = title
    alert.informativeText = message
    alert.addButton(withTitle: "OK")
    alert.runModal()
  }

  /// `kill <pid>` delivers SIGTERM; wire it through AppKit terminate so the stub is reaped.
  private func installSignalHandlers() {
    for sig in [SIGTERM, SIGINT] {
      signal(sig, SIG_IGN)
      let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
      source.setEventHandler {
        NSApp.terminate(nil)
      }
      source.resume()
      signalSources.append(source)
    }
  }

  /// SPM places `ClaudeCodeRoutes` and `StubProxyHelper` in the same build output directory.
  private func resolveStubHelperURL() -> URL? {
    let fm = FileManager.default
    var candidates: [URL] = []

    if let executableURL = Bundle.main.executableURL {
      candidates.append(
        executableURL.deletingLastPathComponent().appendingPathComponent("StubProxyHelper")
      )
    }

    let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
    candidates.append(contentsOf: [
      cwd.appendingPathComponent(".build/debug/StubProxyHelper"),
      cwd.appendingPathComponent(".build/release/StubProxyHelper"),
      cwd.appendingPathComponent(".build/arm64-apple-macosx/debug/StubProxyHelper"),
      cwd.appendingPathComponent(".build/arm64-apple-macosx/release/StubProxyHelper"),
    ])

    return candidates.first { fm.isExecutableFile(atPath: $0.path) }
  }
}
