// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "ClaudeCodeRoutes",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "ProxyRuntime", targets: ["ProxyRuntime"]),
    .executable(name: "ClaudeCodeRoutes", targets: ["ClaudeCodeRoutesApp"]),
  ],
  targets: [
    .target(name: "ProxyRuntime"),
    .executableTarget(
      name: "ClaudeCodeRoutesApp",
      dependencies: ["ProxyRuntime"]
    ),
    .testTarget(
      name: "ProxyRuntimeTests",
      dependencies: ["ProxyRuntime"]
    ),
    .testTarget(
      name: "ClaudeCodeRoutesAppTests",
      dependencies: ["ClaudeCodeRoutesApp", "ProxyRuntime"]
    ),
  ]
)
