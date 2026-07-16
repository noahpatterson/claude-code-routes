import AppKit
import Foundation
import ProxyRuntime
import SwiftUI

private enum Constants {
  static let defaultOnePasswordExecutable = "/opt/homebrew/bin/op"
  static let proxyReadyPollInterval: Duration = .seconds(1)
}

@main
struct ClaudeCodeRoutesApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    // Keeps the SwiftUI app lifecycle alive for a menu-bar-only app.
    // Settings UI is an owned NSPanel (SwiftUI Settings never materializes here).
    Settings {
      EmptyView()
    }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem?
  private var signalSources: [DispatchSourceSignal] = []
  private var session: ProxySession?
  private var settingsPresenter: SettingsWindowPresenter?
  private var proxyIsHealthy = false
  private var proxyStatusMessage = "Claude Code Proxy: starting…"
  private var codexAuthStatus: ProviderAuthStatus = .checking
  private let settingsStore = AppSettingsStore()
  private(set) lazy var settingsModel = SettingsModel(store: settingsStore)

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    installSignalHandlers()

    settingsModel.onSave = { [weak self] saved in
      self?.applySettings(saved, presentErrors: true)
    }
    settingsModel.onCodexAuthStatusChange = { [weak self] status in
      self?.updateCodexAuthStatus(status)
    }
    settingsModel.onCodexCredentialsChanged = { [weak self] in
      self?.restartProxyForChangedCodexCredentials()
    }
    settingsPresenter = SettingsWindowPresenter(model: settingsModel)

    let executableResolver = OnePasswordExecutableResolver(
      defaultExecutable: URL(fileURLWithPath: Constants.defaultOnePasswordExecutable)
    )
    let commandRunner = FoundationCommandRunner()

    let session = ProxySession(
      makePlanner: { settings, environment in
        let executable = try executableResolver.resolve(
          settings: settings,
          environment: environment
        )
        return ProxyLaunchPlanner(
          secretReader: OnePasswordSecretReader(
            runner: commandRunner,
            executable: executable
          )
        )
      },
      processRunner: FoundationProcessRunner(),

      makeHealthChecker: { url, probe, onChange in
        ProxyHealthChecker(
          proxyURL: url,
          probe: probe,
          onStatusChange: { status in
            onChange(status)
          })
      },
      probe: URLSessionHTTPProbe(),
      pollInterval: Constants.proxyReadyPollInterval,
      onStatusChange: { [weak self] status in
        self?.updateStatusItem(healthy: status.isHealthy, statusMessage: status.displayMessage)
      }
    )
    self.session = session

    settingsModel.configureCodexAuth(
      ProviderAuthStatusChecker(runner: FoundationProviderAuthCommandRunner())
    )
    installStatusItem(healthy: false, statusMessage: "Claude Code Proxy: starting…")
    applySettings(settingsStore.load(), presentErrors: true)
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    session?.stop()
    return .terminateNow
  }

  func applicationWillTerminate(_ notification: Notification) {
    session?.stop()
  }

  private func applySettings(
    _ settings: AppSettings,
    presentErrors: Bool
  ) {
    do {
      try session?.apply(
        settings: settings,
        environment: ProcessInfo.processInfo.environment
      )
    } catch {
      updateStatusItem(healthy: false, statusMessage: error.localizedDescription)
      if presentErrors {
        presentAlert(
          title: "Failed to apply proxy settings",
          message: error.localizedDescription
        )
      }
    }
  }

  private func installStatusItem(healthy: Bool, statusMessage: String) {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    item.button?.toolTip = "Claude Code Routes"
    statusItem = item
    updateStatusItem(healthy: healthy, statusMessage: statusMessage)
  }

  private func updateStatusItem(healthy: Bool, statusMessage: String) {
    proxyIsHealthy = healthy
    proxyStatusMessage = statusMessage
    guard let item = statusItem else { return }
    item.button?.title = healthy ? "CCR ●" : "CCR ○"

    let menu = NSMenu()
    menu.addItem(NSMenuItem(title: statusMessage, action: nil, keyEquivalent: ""))
    menu.addItem(NSMenuItem(title: codexAuthStatus.menuBarTitle, action: nil, keyEquivalent: ""))
    menu.addItem(NSMenuItem.separator())
    let settingsItem = NSMenuItem(
      title: "Settings…",
      action: #selector(openSettings),
      keyEquivalent: ","
    )
    settingsItem.target = self
    menu.addItem(settingsItem)
    menu.addItem(NSMenuItem.separator())
    menu.addItem(
      NSMenuItem(
        title: "Quit Claude Code Routes", action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q")
    )
    item.menu = menu
  }

  private func updateCodexAuthStatus(_ status: ProviderAuthStatus) {
    codexAuthStatus = status
    updateStatusItem(healthy: proxyIsHealthy, statusMessage: proxyStatusMessage)
  }

  private func restartProxyForChangedCodexCredentials() {
    session?.stop()
    applySettings(settingsModel.current, presentErrors: false)
  }

  @objc private func openSettings() {
    settingsPresenter?.open()
  }

  private func presentAlert(title: String, message: String) {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = title
    alert.informativeText = message
    alert.addButton(withTitle: "OK")
    alert.runModal()
  }

  /// `kill <pid>` delivers SIGTERM.
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
