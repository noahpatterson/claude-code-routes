import Foundation
import Testing

@testable import ClaudeCodeRoutesApp

@Suite("SettingsWindowPresenter")
@MainActor
struct SettingsWindowPresenterTests {

  @Test("open shows a visible settings window")
  func openShowsVisibleWindow() {
    let suiteName = "SettingsWindowPresenterTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let presenter = SettingsWindowPresenter(
      model: SettingsModel(store: AppSettingsStore(defaults: defaults))
    )
    #expect(presenter.isVisible == false)

    presenter.open()

    #expect(presenter.isVisible == true)
    presenter.close()
    #expect(presenter.isVisible == false)
  }
}
