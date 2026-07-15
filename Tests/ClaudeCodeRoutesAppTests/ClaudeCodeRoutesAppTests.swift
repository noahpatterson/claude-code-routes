import Foundation
import Testing

@testable import ClaudeCodeRoutesApp

/// App wiring lives in `AppDelegate` (resolver → runtime → health → menu bar).
/// Add coverage here once that surface accepts injectable collaborators.
@Suite("ClaudeCodeRoutesApp")
struct ClaudeCodeRoutesAppTests {}
