import AppKit
import Combine
import SwiftUI

@MainActor
final class SettingsModel: ObservableObject {
  @Published var settings: AppSettings
  private let store: AppSettingsStore
  var onSave: ((AppSettings) -> Void)?

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
      Button("Save & Restart Proxy") {
        model.save()
      }
      .keyboardShortcut(.defaultAction)
    }
    .padding()
    .frame(width: 520)
  }
}
