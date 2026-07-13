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

    let runtime = makeRuntime()
    self.runtime = runtime

    do {
      try runtime.start()
    } catch {
      NSLog("ClaudeCodeRoutes: failed to start stub proxy: \(error.localizedDescription)")
    }

    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = item.button {
      button.title = runtime.isHealthy ? "CCR ●" : "CCR ○"
      button.toolTip = "Claude Code Routes"
    }

    let menu = NSMenu()
    let statusTitle = runtime.isHealthy ? "Proxy: running (stub)" : "Proxy: stopped"
    menu.addItem(NSMenuItem(title: statusTitle, action: nil, keyEquivalent: ""))
    menu.addItem(NSMenuItem.separator())
    menu.addItem(
      NSMenuItem(title: "Quit Claude Code Routes", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    )
    item.menu = menu
    statusItem = item
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

  private func makeRuntime() -> ProxyRuntime {
    guard let helperURL = resolveStubHelperURL() else {
      preconditionFailure(
        "StubProxyHelper not found next to ClaudeCodeRoutes. Run `swift build` so both products land in .build/.../debug/."
      )
    }

    return ProxyRuntime(
      executableURL: helperURL,
      arguments: [],
      runner: FoundationProcessRunner()
    )
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
