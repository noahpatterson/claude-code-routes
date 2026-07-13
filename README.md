# Claude Code Routes

macOS menu-bar app that runs a bundled [claude-code-proxy](https://github.com/raine/claude-code-proxy) fork and opens Claude Code in Warp.

## Status

Issue #2 scaffold: `ProxyRuntime` + stub helper + menu-bar app shell.

## Develop

```sh
swift test
swift build
swift run StubProxyHelper   # long-lived stub
swift run ClaudeCodeRoutes  # menu-bar app (accessory)
```

Quit from the menu bar item (**CCR**). The stub proxy process should terminate with the app.
