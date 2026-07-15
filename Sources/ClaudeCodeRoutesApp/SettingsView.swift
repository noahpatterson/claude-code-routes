import AppKit
import Combine
import SwiftUI

@MainActor
final class SettingsModel: ObservableObject {
  @Published var claudeCodeProxyPath: String
  @Published var claudeCodeProxyURL: String
  @Published var mergeGatewayOnePasswordItem: String

  private let store: AppSettingsStore
  var onSave: ((AppSettings) -> Void)?

  init(store: AppSettingsStore) {
    self.store = store
    let loaded = store.load()
    self.claudeCodeProxyPath = loaded.claudeCodeProxyPath
    self.claudeCodeProxyURL = loaded.claudeCodeProxyURL
    self.mergeGatewayOnePasswordItem = loaded.mergeGatewayOnePasswordItem
  }

  var current: AppSettings {
    AppSettings(
      claudeCodeProxyPath: claudeCodeProxyPath,
      claudeCodeProxyURL: claudeCodeProxyURL,
      mergeGatewayOnePasswordItem: mergeGatewayOnePasswordItem
    )
  }

  func reloadFromStore() {
    let loaded = store.load()
    claudeCodeProxyPath = loaded.claudeCodeProxyPath
    claudeCodeProxyURL = loaded.claudeCodeProxyURL
    mergeGatewayOnePasswordItem = loaded.mergeGatewayOnePasswordItem
  }

  func save() {
    let settings = current
    store.save(settings)
    onSave?(settings)
  }
}

struct SettingsView: View {
  @ObservedObject var model: SettingsModel

  var body: some View {
    Form {
      TextField("claudeCodeProxyPath", text: $model.claudeCodeProxyPath)
      TextField("claudeCodeProxyURL", text: $model.claudeCodeProxyURL)
      TextField(
        "mergeGatewayOnePasswordItem",
        text: $model.mergeGatewayOnePasswordItem,
        prompt: Text("op://Personal/ITEM/KEY")
      )
      Button("Save & Restart Proxy") {
        model.save()
      }
      .keyboardShortcut(.defaultAction)
    }
    .padding()
    .frame(width: 520)
  }
}
