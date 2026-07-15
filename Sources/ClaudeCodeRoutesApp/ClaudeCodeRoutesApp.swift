// Plan to split out ClaudeCodeRoutes to different seams
//
// - ClaudeCodeRoutesApp - calls the resolver, constructs ProxyRuntime, presents alerts.
// - ProxyConfiguration.swift: resolves environment precedence and returns configuration.
// - CommandRunning.swift: hides Process and output capture.
// - OnePasswordSecretReader.swift: knows how to invoke op.
// - ProxyRuntime: remains unaware of environment variables and 1Password.

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
  private var proxyConfigurationResolver: ProxyConfigurationResolver?
  private var healthChecker: ProxyHealthChecker?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    installSignalHandlers()

    let resolver = ProxyConfigurationResolver(
      defaultProxyPath: URL(fileURLWithPath: Constants.claudeCodeProxyPath),
      defaultOnePasswordExecutable: URL(fileURLWithPath: "/opt/homebrew/bin/op"),
      onePasswordReference: Constants.mergeGatewayOnePasswordItem,
      secretReader: OnePasswordSecretReader(runner: FoundationCommandRunner())
    )
    proxyConfigurationResolver = resolver

    let proxyConfiguration: ProxyConfiguration
    do {
      proxyConfiguration = try resolver.resolve(
        environment: ProcessInfo.processInfo.environment
      )
    } catch {
      installStatusItem(healthy: false, statusMessage: error.localizedDescription)
      presentAlert(
        title: "Failed to resolve proxy configuration",
        message: error.localizedDescription
      )
      return
    }

    let proxyURL = proxyConfiguration.proxyPath
    let arguments = [
      "serve",
      "--no-monitor",
    ]
    let runtime = ProxyRuntime(
      executableURL: proxyURL,
      arguments: arguments,
      runner: FoundationProcessRunner(),
      environment: [
        "CCP_MERGE_AUTH_TOKEN": proxyConfiguration.apiKey
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

    guard let proxyHealthURL = URL(string: Constants.claudeCodeProxyURL) else {
      return
    }
    let healthChecker = ProxyHealthChecker(proxyURL: proxyHealthURL) {
      [weak self] healthy, message in
      self?.updateStatusItem(healthy: healthy, statusMessage: message)
    }
    self.healthChecker = healthChecker
    healthChecker.monitor(runtime: runtime, interval: Constants.proxyReadyPollInterval)
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    stopProxy()
    return .terminateNow
  }

  func applicationWillTerminate(_ notification: Notification) {
    stopProxy()
  }

  private func stopProxy() {
    healthChecker?.stop()
    healthChecker = nil
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

  /// `kill <pid>` delivers SIGTERM;.
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
}
