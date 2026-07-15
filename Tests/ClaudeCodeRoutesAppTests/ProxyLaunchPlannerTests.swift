import Foundation
import Testing

@testable import ClaudeCodeRoutesApp

@Suite("ProxyLaunchPlanner")
struct ProxyLaunchPlannerTests {

  @Test("plans executable, health URL, and api key from settings")
  func plansFromSettings() throws {
    let proxyPath = createEmptyExecutableFile(suffix: "launch-plan")
    let settings = AppSettings(
      claudeCodeProxyPath: proxyPath.path,
      claudeCodeProxyURL: "http://127.0.0.1:18765/",
      mergeGatewayOnePasswordItem: "op://Personal/ITEM/KEY"
    )
    let secretReader = FakeSecretReader()
    secretReader.apiKey = "planned-api-key"

    let plan = try ProxyLaunchPlanner(
      defaultOnePasswordExecutable: createEmptyExecutableFile(suffix: "op"),
      secretReader: secretReader
    ).plan(settings: settings, environment: [:])

    #expect(plan.executableURL == proxyPath)
    #expect(plan.healthURL == URL(string: "http://127.0.0.1:18765/")!)
    #expect(plan.apiKey == "planned-api-key")
  }

  @Test("invalid health URL throws")
  func invalidHealthURLThrows() throws {
    let settings = AppSettings(
      claudeCodeProxyPath: createEmptyExecutableFile().path,
      claudeCodeProxyURL: "",
      mergeGatewayOnePasswordItem: ""
    )

    let planner = ProxyLaunchPlanner(
      defaultOnePasswordExecutable: createEmptyExecutableFile(suffix: "op"),
      secretReader: FakeSecretReader()
    )

    #expect(throws: ProxyLaunchPlannerError.invalidHealthURL) {
      try planner.plan(
        settings: settings,
        environment: ["MERGE_GATEWAY_API_KEY": "env-key"]
      )
    }
  }
}
