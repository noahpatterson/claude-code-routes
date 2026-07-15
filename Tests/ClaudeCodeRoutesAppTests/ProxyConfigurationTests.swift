import Foundation
import Testing

@testable import ClaudeCodeRoutesApp

@Suite("ProxyConfiguration")
struct ProxyConfigurationTests {

  static let fakeExecutablePath = createEmptyExecutableFile()
  static let fakeNonExecutablePath = createNonExecutableFile()

  @Test("MERGE_GATEWAY_API_KEY wins over the secret reader")
  func mergeGatewayApiKeyWinsOverSecretReader() throws {
    let secretReader = FakeSecretReader()
    let environment = ["MERGE_GATEWAY_API_KEY": "fake-api-key"]

    let proxyConfiguration = try ProxyConfigurationResolver(
      defaultProxyPath: Self.fakeExecutablePath,
      defaultOnePasswordExecutable: Self.fakeExecutablePath,
      onePasswordReference: "fake-reference",
      secretReader: secretReader
    ).resolve(environment: environment)

    #expect(proxyConfiguration.apiKey == "fake-api-key")
    #expect(secretReader.callCount == 0)
  }

  @Test("missing MERGE_GATEWAY_API_KEY falls back to the secret reader")
  func missingApiKeyFallsBackToSecretReader() throws {
    let secretReader = FakeSecretReader()

    let proxyConfiguration = try ProxyConfigurationResolver(
      defaultProxyPath: Self.fakeExecutablePath,
      defaultOnePasswordExecutable: Self.fakeExecutablePath,
      onePasswordReference: "fake-reference",
      secretReader: secretReader
    ).resolve(environment: [:])

    #expect(proxyConfiguration.apiKey == "secret-reader-api-key")
    #expect(secretReader.callCount == 1)
  }

  @Test("CLAUDE_CODE_PROXY_PATH overrides the default proxy path")
  func claudeCodeProxyPathOverridesDefault() throws {
    let secretReader = FakeSecretReader()
    let claudeCodeProxyPath = createEmptyExecutableFile(suffix: "claude-code-proxy")
    let environment = [
      "CLAUDE_CODE_PROXY_PATH": claudeCodeProxyPath.path
    ]

    let proxyConfiguration = try ProxyConfigurationResolver(
      defaultProxyPath: Self.fakeExecutablePath,
      defaultOnePasswordExecutable: Self.fakeExecutablePath,
      onePasswordReference: "fake-reference",
      secretReader: secretReader
    ).resolve(environment: environment)

    #expect(proxyConfiguration.proxyPath == claudeCodeProxyPath)
    #expect(proxyConfiguration.proxyPath != Self.fakeExecutablePath)
  }

  @Test("ONE_PASSWORD_EXECUTABLE overrides the default op path")
  func onePasswordExecutableOverridesDefault() throws {
    let secretReader = FakeSecretReader()
    let onePasswordExecutable = createEmptyExecutableFile(suffix: "op")
    let environment = [
      "ONE_PASSWORD_EXECUTABLE": onePasswordExecutable.path
    ]

    let resolver = ProxyConfigurationResolver(
      defaultProxyPath: Self.fakeExecutablePath,
      defaultOnePasswordExecutable: Self.fakeExecutablePath,
      onePasswordReference: "fake-reference",
      secretReader: secretReader
    )
    let _ = try resolver.resolve(environment: environment)

    #expect(secretReader.callCount == 1)
    #expect(secretReader.lastExecutable == onePasswordExecutable)
    #expect(secretReader.lastExecutable != Self.fakeExecutablePath)
  }

  @Test("non-executable proxy path throws")
  func nonExecutableProxyPathThrows() throws {
    let secretReader = FakeSecretReader()
    let environment = [
      "CLAUDE_CODE_PROXY_PATH": Self.fakeNonExecutablePath.path
    ]

    let resolver = ProxyConfigurationResolver(
      defaultProxyPath: Self.fakeExecutablePath,
      defaultOnePasswordExecutable: Self.fakeExecutablePath,
      onePasswordReference: "fake-reference",
      secretReader: secretReader
    )

    #expect(throws: ProxyConfigurationError.proxyPathNotExecutable) {
      try resolver.resolve(environment: environment)
    }
  }

  @Test("non-executable one password path throws")
  func nonExecutableOnePasswordPathThrows() throws {
    let secretReader = FakeSecretReader()
    let environment = [
      "ONE_PASSWORD_EXECUTABLE": Self.fakeNonExecutablePath.path
    ]

    let resolver = ProxyConfigurationResolver(
      defaultProxyPath: Self.fakeExecutablePath,
      defaultOnePasswordExecutable: Self.fakeExecutablePath,
      onePasswordReference: "fake-reference",
      secretReader: secretReader
    )

    #expect(throws: ProxyConfigurationError.onePasswordExecutableNotExecutable) {
      try resolver.resolve(environment: environment)
    }
  }

  @Test("empty onePassword reference without API key throws")
  func emptyOnePasswordReferenceWithoutApiKeyThrows() throws {
    let secretReader = FakeSecretReader()

    let resolver = ProxyConfigurationResolver(
      defaultProxyPath: Self.fakeExecutablePath,
      defaultOnePasswordExecutable: Self.fakeExecutablePath,
      onePasswordReference: "",
      secretReader: secretReader
    )

    #expect(throws: ProxyConfigurationError.missingOnePasswordReference) {
      try resolver.resolve(environment: [:])
    }
    #expect(secretReader.callCount == 0)
  }

  @Test("AppSettings supply resolver path and onePassword defaults")
  func appSettingsSupplyResolverDefaults() throws {
    let secretReader = FakeSecretReader()
    let proxyPath = createEmptyExecutableFile(suffix: "from-settings")
    let settings = AppSettings(
      claudeCodeProxyPath: proxyPath.path,
      claudeCodeProxyURL: "http://127.0.0.1:18765/",
      mergeGatewayOnePasswordItem: "op://Personal/ITEM/KEY"
    )

    let proxyConfiguration = try ProxyConfigurationResolver(
      settings: settings,
      defaultOnePasswordExecutable: Self.fakeExecutablePath,
      secretReader: secretReader
    ).resolve(environment: [:])

    #expect(proxyConfiguration.proxyPath == proxyPath)
    #expect(secretReader.lastReference == "op://Personal/ITEM/KEY")
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

    let resolver = ProxyConfigurationResolver(
      defaultProxyPath: Self.fakeExecutablePath,
      defaultOnePasswordExecutable: Self.fakeExecutablePath,
      onePasswordReference: "fake-reference",
      secretReader: secretReader
    )

    let error = #expect(throws: NSError.self) {
      try resolver.resolve(environment: [:])
    }

    #expect(error?.domain == expectedError.domain)
    #expect(error?.code == expectedError.code)
    #expect(error?.localizedDescription == expectedError.localizedDescription)
    #expect(secretReader.callCount == 1)
  }
}

/// Second adapter for the `SecretReader` seam — no real `op` process.
final class FakeSecretReader: SecretReader, @unchecked Sendable {
  var apiKey: String = "secret-reader-api-key"
  var error: (any Error)?
  private(set) var lastExecutable: URL?
  private(set) var lastReference: String?
  private(set) var callCount = 0

  func read(executable: URL, reference: String) throws -> String {
    callCount += 1
    lastExecutable = executable
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
