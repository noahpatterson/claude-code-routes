import AppKit
import SwiftUI

@MainActor
final class SettingsWindowPresenter {
  private let model: SettingsModel
  private var window: NSWindow?

  init(model: SettingsModel) {
    self.model = model
  }

  var isVisible: Bool {
    window?.isVisible == true
  }

  func open() {
    model.reloadFromStore()

    if let window {
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    let hostingController = NSHostingController(rootView: SettingsView(model: model))
    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 560, height: 240),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    panel.title = "Claude Code Routes Settings"
    panel.contentViewController = hostingController
    panel.isReleasedWhenClosed = false
    panel.level = .floating
    panel.center()
    panel.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    window = panel
  }

  func close() {
    window?.orderOut(nil)
  }
}
