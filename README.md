# Claude Code Routes

macOS menu-bar app that runs a bundled [claude-code-proxy](https://github.com/raine/claude-code-proxy) fork and opens Claude Code in Warp.

## Status

Issue #4 bundle claude code proxy.

## Develop

```sh
swift test
swift build
swift run ClaudeCodeRoutes  # menu-bar app (accessory)
```

Quit from the menu bar item (**CCR**).

## how it works

Think of the app as having two jobs:

1. Decide how to launch the proxy.
2. Keep the proxy running and report its status.

`ProxySession` is becoming the module that owns both jobs.

```text
AppDelegate
  ├─ reads settings
  ├─ tells ProxySession to apply them
  └─ displays status/errors

ProxySession
  ├─ ProxyLaunchPlanner
  ├─ ProxyRuntime
  └─ ProxyHealthChecker
```

## What happens when the app starts?

### 1. `AppDelegate` assembles the collaborators

In [ClaudeCodeRoutesApp.swift](/Users/testuser/Developer/claude-code-routes/Sources/ClaudeCodeRoutesApp/ClaudeCodeRoutesApp.swift), the app creates:

- A `ProxyLaunchPlanner`
- A real `FoundationProcessRunner`
- A real `URLSessionHTTPProbe`
- A `ProxySession`

The test versions of those dependencies can be substituted later.

### 2. The app loads settings

`AppSettingsStore` reads values from `UserDefaults`:

```swift
AppSettings(
  claudeCodeProxyPath: ...,
  claudeCodeProxyURL: ...,
  mergeGatewayOnePasswordItem: ...,
  onePasswordExecutable: ...
)
```

These settings describe what the user wants, but they are not yet ready to launch a process.

### 3. `AppDelegate` calls `ProxySession`

```swift
try session?.apply(
  settings: settings,
  environment: ProcessInfo.processInfo.environment
)
```

This is the important new interface. The caller supplies settings and the environment. It does not construct a `ProxyLaunchPlan` or manually start a runtime.

## What does `ProxySession.apply` do?

In [ProxySession.swift](/Users/testuser/Developer/claude-code-routes/Sources/ClaudeCodeRoutesApp/ProxySession.swift), it performs this sequence:

```text
settings + environment
        │
        ▼
ProxyLaunchPlanner.plan(...)
        │
        ▼
ProxyLaunchPlan
        │
        ▼
stop old proxy
        │
        ▼
start new ProxyRuntime
        │
        ▼
start ProxyHealthChecker
```

The order matters:

```swift
let plan = try planner.plan(...)
stop()
try start(plan)
```

The session plans first. If the new settings are invalid, the existing proxy remains alive instead of being stopped prematurely.

## What does the planner do?

[ProxyLaunchPlanner.swift](/Users/testuser/Developer/claude-code-routes/Sources/ClaudeCodeRoutesApp/ProxyLaunchPlanner.swift) converts user-facing settings into a valid launch plan.

It resolves:

- Proxy executable path.
- API key.
- Health-check URL.

The API-key flow is:

```text
MERGE_GATEWAY_API_KEY environment variable
        │
        ├─ present → use it
        │
        └─ absent → read settings reference through 1Password
```

These two environment names have different purposes:

- `MERGE_GATEWAY_API_KEY`: input to the planner.
- `CCP_MERGE_AUTH_TOKEN`: output passed to the child proxy process.

That is why the test needed `MERGE_GATEWAY_API_KEY`.

The result is:

```swift
ProxyLaunchPlan(
  executableProxyPath: ...,
  healthProxyURL: ...,
  apiKey: ...
)
```

## What does `ProxyRuntime` do?

`ProxyRuntime` owns the child process.

It starts the proxy approximately like this:

```text
claude-code-proxy serve --no-monitor
```

with:

```text
CCP_MERGE_AUTH_TOKEN=<api key>
```

It also owns stopping the process and checking whether the process is still running.

`ProcessRunning` is the seam:

- Production adapter: `FoundationProcessRunner`
- Test adapter: `RecordingProcessRunner` or `FakeProcessRunner`

The session does not need to know how `Process` works internally.

## What does `ProxyHealthChecker` do?

Starting the process does not prove the proxy is ready. The health checker periodically probes the configured URL.

It considers two facts:

```text
Is the process running?
Is the proxy URL responding?
```

It then emits a `ProxyStatus`:

```swift
.starting
.running
.notReady
.stopped
.failed(...)
```

The status travels back up:

```text
ProxyHealthChecker
        │
        ▼
ProxySession onStatusChange
        │
        ▼
AppDelegate
        │
        ▼
menu bar icon and message
```

## Why use private functions inside `ProxySession`?

The private functions organize the implementation:

```swift
private func start(_ plan: ProxyLaunchPlan)
private func makeRuntime(for plan: ProxyLaunchPlan)
private func startMonitoring(...)
```

They are not new application-facing primitives. They are implementation details that help `ProxySession` keep one clear interface:

```swift
apply(settings:environment:)
stop()
status reporting
```

So yes: this is a combination of orchestration responsibilities, implemented by expanding `ProxySession` and adding private functions. It does not mean deleting every collaborator.

## Where are the tests?

Tests replace the real side effects:

```text
Real app                         Tests
─────────────────────────────    ─────────────────────────
FoundationProcessRunner       →  RecordingProcessRunner
URLSessionHTTPProbe            →  FakeHTTPProbe
OnePasswordSecretReader        →  FakeSecretReader
ProxyHealthChecker              →  FakeHealthChecker
```

The `ProxySession` test now checks the important behavior:

1. Settings become a launch plan.
2. The first proxy starts.
3. Applying new settings stops the first proxy.
4. The second proxy starts.
5. Stopping the session terminates the current proxy.

The current implementation is an intermediate step: `ProxySession` owns the workflow, but `AppDelegate` still helps construct its planner and health-checker factory. That is acceptable for dependency injection. If you later want an even smaller `AppDelegate`, add a production factory or convenience initializer for `ProxySession`; keep the injection-heavy initializer for tests.