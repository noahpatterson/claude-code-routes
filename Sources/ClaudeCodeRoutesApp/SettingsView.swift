import AppKit
import Combine
import SwiftUI

@MainActor
final class SettingsModel: ObservableObject {
  @Published var settings: AppSettings
  @Published private(set) var codexAuthStatus: ProviderAuthStatus = .checking
  @Published private(set) var isCodexAuthActionRunning = false
  private let store: AppSettingsStore
  private var providerAuthStatusChecker: ProviderAuthStatusChecker?
  var onSave: ((AppSettings) -> Void)?
  var onCodexAuthStatusChange: ((ProviderAuthStatus) -> Void)?
  var onCodexCredentialsChanged: (() -> Void)?

  init(store: AppSettingsStore) {
    self.store = store
    let loaded = store.load()
    self.settings = loaded
  }

  var current: AppSettings {
    settings
  }

  func reloadFromStore() {
    let loaded = store.load()
    settings = loaded
  }

  func save() {
    let settings = current
    store.save(settings)
    onSave?(settings)
  }

  func configureCodexAuth(_ providerAuthStatusChecker: ProviderAuthStatusChecker) {
    self.providerAuthStatusChecker = providerAuthStatusChecker
    refreshCodexAuthStatus()
  }

  func refreshCodexAuthStatus() {
    guard let providerAuthStatusChecker, !isCodexAuthActionRunning else { return }

    let executable = proxyExecutableURL()
    Task { [weak self] in
      let status = await providerAuthStatusChecker.codexStatus(executable: executable)
      guard let self, !self.isCodexAuthActionRunning else { return }
      self.updateCodexAuthStatus(status)
    }
  }

  func loginToCodex() {
    guard let providerAuthStatusChecker, !isCodexAuthActionRunning else { return }

    isCodexAuthActionRunning = true
    updateCodexAuthStatus(.checking)
    let executable = proxyExecutableURL()
    Task { [weak self] in
      do {
        try await providerAuthStatusChecker.loginToCodex(executable: executable)
        let status = await providerAuthStatusChecker.codexStatus(executable: executable)
        guard let self else { return }
        self.isCodexAuthActionRunning = false
        self.updateCodexAuthStatus(status)
        if status.isConnected {
          self.onCodexCredentialsChanged?()
        }
      } catch {
        guard let self else { return }
        self.isCodexAuthActionRunning = false
        self.updateCodexAuthStatus(.unavailable(error.localizedDescription))
      }
    }
  }

  func logoutOfCodex() {
    guard let providerAuthStatusChecker, !isCodexAuthActionRunning else { return }

    isCodexAuthActionRunning = true
    let executable = proxyExecutableURL()
    Task { [weak self] in
      do {
        try await providerAuthStatusChecker.logoutOfCodex(executable: executable)
        guard let self else { return }
        self.isCodexAuthActionRunning = false
        self.updateCodexAuthStatus(.needsLogin)
        self.onCodexCredentialsChanged?()
      } catch {
        guard let self else { return }
        self.isCodexAuthActionRunning = false
        self.updateCodexAuthStatus(.unavailable(error.localizedDescription))
      }
    }
  }

  private func proxyExecutableURL() -> URL {
    let path = ProcessInfo.processInfo.environment["CLAUDE_CODE_PROXY_PATH"]
      ?? settings.claudeCodeProxyPath
    return URL(fileURLWithPath: path)
  }

  private func updateCodexAuthStatus(_ status: ProviderAuthStatus) {
    codexAuthStatus = status
    onCodexAuthStatusChange?(status)
  }
}

struct SettingsView: View {
  @ObservedObject var model: SettingsModel

  var body: some View {
    Form {
      TextField("claudeCodeProxyPath", text: $model.settings.claudeCodeProxyPath)
      TextField("claudeCodeProxyURL", text: $model.settings.claudeCodeProxyURL)
      TextField(
        "mergeGatewayOnePasswordItem",
        text: $model.settings.mergeGatewayOnePasswordItem,
        prompt: Text("op://Personal/ITEM/KEY")
      )
      TextField(
        "onePasswordExecutable",
        text: $model.settings.onePasswordExecutable,
      )
      Section("Codex") {
        HStack {
          Text("ChatGPT subscription")
          Spacer()
          Text(model.codexAuthStatus.settingsMessage)
            .foregroundStyle(model.codexAuthStatus.isConnected ? .green : .secondary)
        }
        if model.isCodexAuthActionRunning {
          ProgressView("Waiting for browser sign-in…")
        } else {
          HStack {
            if model.codexAuthStatus.isConnected {
              Button("Log Out of Codex") {
                model.logoutOfCodex()
              }
            } else {
              Button("Log In to Codex") {
                model.loginToCodex()
              }
            }
            Button("Refresh Status") {
              model.refreshCodexAuthStatus()
            }
          }
        }
      }
      Button("Save & Restart Proxy") {
        model.save()
      }
      .keyboardShortcut(.defaultAction)
    }
    .padding()
    .frame(width: 520)
  }
}
