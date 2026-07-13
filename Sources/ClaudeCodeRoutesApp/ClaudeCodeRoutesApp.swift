import AppKit
import ProxyRuntime
import SwiftUI

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

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    installSignalHandlers()

    let statusMessage: String
    let healthy: Bool

    if let helperURL = resolveStubHelperURL() {
      let runtime = ProxyRuntime(
        executableURL: helperURL,
        arguments: [],
        runner: FoundationProcessRunner()
      )
      self.runtime = runtime

      do {
        try runtime.start()
        healthy = runtime.isHealthy
        statusMessage = healthy ? "Proxy: running (stub)" : "Proxy: failed to start"
      } catch {
        healthy = false
        statusMessage = "Proxy: failed to start"
        NSLog("ClaudeCodeRoutes: failed to start stub proxy: \(error.localizedDescription)")
        presentAlert(
          title: "Couldn’t start stub proxy",
          message: error.localizedDescription
        )
      }
    } else {
      healthy = false
      statusMessage = "Proxy: stub helper missing"
      presentAlert(
        title: "Stub proxy helper not found",
        message: """
        StubProxyHelper was not found next to ClaudeCodeRoutes.

        Run `swift build` so both products land in `.build/.../debug/`, then launch the built ClaudeCodeRoutes binary again.
        """
      )
    }

    installStatusItem(healthy: healthy, statusMessage: statusMessage)
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    stopProxy()
    return .terminateNow
  }

  func applicationWillTerminate(_ notification: Notification) {
    stopProxy()
  }

  private func stopProxy() {
    runtime?.stop()
    runtime = nil
  }

  private func installStatusItem(healthy: Bool, statusMessage: String) {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = item.button {
      button.title = healthy ? "CCR ●" : "CCR ○"
      button.toolTip = "Claude Code Routes"
    }

    let menu = NSMenu()
    menu.addItem(NSMenuItem(title: statusMessage, action: nil, keyEquivalent: ""))
    menu.addItem(NSMenuItem.separator())
    menu.addItem(
      NSMenuItem(title: "Quit Claude Code Routes", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    )
    item.menu = menu
    statusItem = item
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
