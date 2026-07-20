import Foundation
import Testing

@testable import ClaudeCodeRoutesApp

@Suite("ProxyLaunchPlanner")
struct ProxyLaunchPlannerTests {

  static let fakeExecutablePath = createEmptyExecutableFile()
  static let fakeNonExecutablePath = createNonExecutableFile()

  @Test("MERGE_GATEWAY_API_KEY wins over the secret reader")
  func mergeGatewayApiKeyWinsOverSecretReader() throws {
    let secretReader = FakeSecretReader()
    let environment = ["MERGE_GATEWAY_API_KEY": "fake-api-key"]

    let plan = try Self.makePlanner(secretReader: secretReader).plan(
      settings: Self.makeSettings(), environment: environment)

    #expect(plan.apiKey == "fake-api-key")
    #expect(secretReader.callCount == 0)
  }

  @Test("missing MERGE_GATEWAY_API_KEY falls back to the secret reader")
  func missingApiKeyFallsBackToSecretReader() throws {
    let secretReader = FakeSecretReader()

    let plan = try Self.makePlanner(secretReader: secretReader).plan(
      settings: Self.makeSettings(), environment: [:])

    #expect(plan.apiKey == "secret-reader-api-key")
    #expect(secretReader.callCount == 1)
  }

  @Test("blank MERGE_GATEWAY_API_KEY falls back to the secret reader")
  func blankApiKeyFallsBackToSecretReader() throws {
    let secretReader = FakeSecretReader()

    let plan = try Self.makePlanner(secretReader: secretReader).plan(
      settings: Self.makeSettings(),
      environment: ["MERGE_GATEWAY_API_KEY": "   "]
    )

    #expect(plan.apiKey == "secret-reader-api-key")
    #expect(secretReader.callCount == 1)
  }

  @Test("CLAUDE_CODE_PROXY_PATH overrides the settings proxy path")
  func claudeCodeProxyPathOverridesDefault() throws {
    let secretReader = FakeSecretReader()
    let claudeCodeProxyPath = createEmptyExecutableFile(suffix: "claude-code-proxy")
    let environment = [
      "CLAUDE_CODE_PROXY_PATH": claudeCodeProxyPath.path
    ]

    let plan = try Self.makePlanner(secretReader: secretReader).plan(
      settings: Self.makeSettings(), environment: environment)

    #expect(plan.executableProxyPath == claudeCodeProxyPath)
    #expect(plan.executableProxyPath != Self.fakeExecutablePath)
  }

  @Test("non-executable proxy path throws")
  func nonExecutableProxyPathThrows() throws {
    let environment = [
      "CLAUDE_CODE_PROXY_PATH": Self.fakeNonExecutablePath.path
    ]

    #expect(throws: ProxyLaunchPlannerError.proxyPathNotExecutable) {
      try Self.makePlanner(secretReader: FakeSecretReader())
        .plan(
          settings: Self.makeSettings(), environment: environment)
    }
  }

  @Test("empty onePassword reference without API key throws")
  func emptyOnePasswordReferenceWithoutApiKeyThrows() throws {
    let secretReader = FakeSecretReader()

    #expect(throws: ProxyLaunchPlannerError.missingOnePasswordReference) {
      try Self.makePlanner(secretReader: secretReader).plan(
        settings: Self.makeSettings(onePasswordReference: ""), environment: [:])
    }
    #expect(secretReader.callCount == 0)
  }

  @Test("AppSettings supply planner path and secret reference")
  func appSettingsSupplyPlannerDefaults() throws {
    let secretReader = FakeSecretReader()
    let proxyPath = createEmptyExecutableFile(suffix: "from-settings")
    let settings = Self.makeSettings(
      proxyPath: proxyPath,
      onePasswordReference: "op://Vault/Item/field"
    )

    let plan = try Self.makePlanner(secretReader: secretReader).plan(
      settings: settings, environment: [:])

    #expect(plan.executableProxyPath == proxyPath)
    #expect(secretReader.lastReference == "op://Vault/Item/field")
  }

  @Test("secret reader failure propagates")
  func secretReaderFailurePropagates() throws {
    let secretReader = FakeSecretReader()
    let expectedError = NSError(
      domain: "SecretReader",
      code: 42,
      userInfo: [NSLocalizedDescriptionKey: "failed to read secret"]
    )
    secretReader.error = expectedError

    let error = #expect(throws: NSError.self) {
      try Self.makePlanner(secretReader: secretReader).plan(
        settings: Self.makeSettings(), environment: [:])
    }

    #expect(error?.domain == expectedError.domain)
    #expect(error?.code == expectedError.code)
    #expect(error?.localizedDescription == expectedError.localizedDescription)
    #expect(secretReader.callCount == 1)
  }

  @Test("plans executable, health URL, and api key from settings")
  func plansFromSettings() throws {
    let proxyPath = createEmptyExecutableFile(suffix: "launch-plan")
    let settings = AppSettings(
      claudeCodeProxyPath: proxyPath.path,
      claudeCodeProxyURL: "http://127.0.0.1:18765/",
      mergeGatewayOnePasswordItem: "op://Vault/Item/field",
      onePasswordExecutable: createEmptyExecutableFile(suffix: "settings-op").path
    )
    let secretReader = FakeSecretReader()
    secretReader.apiKey = "planned-api-key"

    let plan = try ProxyLaunchPlanner(
      secretReader: secretReader
    ).plan(settings: settings, environment: [:])

    #expect(plan.executableProxyPath == proxyPath)
    #expect(plan.healthProxyURL == URL(string: "http://127.0.0.1:18765/")!)
    #expect(plan.apiKey == "planned-api-key")
  }

  @Test("invalid health URL throws")
  func invalidHealthURLThrows() throws {
    let settings = AppSettings(
      claudeCodeProxyPath: createEmptyExecutableFile().path,
      claudeCodeProxyURL: "",
      mergeGatewayOnePasswordItem: "",
      onePasswordExecutable: Self.fakeExecutablePath.path
    )

    let planner = ProxyLaunchPlanner(
      secretReader: FakeSecretReader()
    )

    #expect(throws: ProxyLaunchPlannerError.invalidHealthURL) {
      try planner.plan(
        settings: settings,
        environment: ["MERGE_GATEWAY_API_KEY": "env-key"]
      )
    }
  }

  private static func makeSettings(
    proxyPath: URL = fakeExecutablePath,
    proxyURL: String = "http://127.0.0.1:18765/",
    onePasswordReference: String = "fake-reference",
    onePasswordExecutable: URL = fakeExecutablePath
  ) -> AppSettings {
    AppSettings(
      claudeCodeProxyPath: proxyPath.path,
      claudeCodeProxyURL: proxyURL,
      mergeGatewayOnePasswordItem: onePasswordReference,
      onePasswordExecutable: onePasswordExecutable.path
    )
  }

  private static func makePlanner(secretReader: FakeSecretReader) -> ProxyLaunchPlanner {
    ProxyLaunchPlanner(
      secretReader: secretReader
    )
  }
}

/// Second adapter for the `SecretReader` seam — no real `op` process.
final class FakeSecretReader: SecretReader, @unchecked Sendable {
  var apiKey: String = "secret-reader-api-key"
  var error: (any Error)?
  private(set) var lastReference: String?
  private(set) var callCount = 0

  func read(reference: String) throws -> String {
    callCount += 1
    lastReference = reference
    if let error {
      throw error
    }
    return apiKey
  }
}

func createEmptyExecutableFile(suffix: String = "") -> URL {
  let fileManager = FileManager.default
  let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
  let randomSuffix = UUID().uuidString
  let filePath = tempDirectory.appendingPathComponent(
    "test_executable_\(suffix)_\(randomSuffix).sh")

  do {
    fileManager.createFile(atPath: filePath.path, contents: Data())
    try fileManager.setAttributes(
      [FileAttributeKey.posixPermissions: 0o755], ofItemAtPath: filePath.path)
    return filePath
  } catch {
    fatalError("Failed to create executable file at path: \(filePath.path)")
  }
}

func createNonExecutableFile(suffix: String = "") -> URL {
  let fileManager = FileManager.default
  let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
  let randomSuffix = UUID().uuidString
  let filePath = tempDirectory.appendingPathComponent(
    "test_non_executable_file_\(suffix)_\(randomSuffix).sh")
  fileManager.createFile(atPath: filePath.path, contents: Data())
  return filePath
}
