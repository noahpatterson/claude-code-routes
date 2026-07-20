# Claude Code Routes

> **Proof of concept / abandoned.** Shared as-is for reference. Not maintained.

macOS menu-bar app that launches a [claude-code-proxy](https://github.com/raine/claude-code-proxy) process and surfaces its status. Optionally resolves the Merge gateway API key via the [1Password CLI](https://developer.1password.com/docs/cli/) (`op read`), or from `MERGE_GATEWAY_API_KEY`.

## Requirements

- macOS 14+
- Swift 6 toolchain
- A built `claude-code-proxy` binary on disk
- Optional: [1Password CLI](https://developer.1password.com/docs/cli/) if you prefer not to put the API key in the environment

## Develop

```sh
swift test
swift build
swift run ClaudeCodeRoutes  # menu-bar app (accessory)
```

Quit from the menu bar item (**CCR**).

## Configuration

Settings live in `UserDefaults` (also editable in the Settings window):

| Setting | Purpose |
| --- | --- |
| `claudeCodeProxyPath` | Path to the proxy executable (default: `~/.local/bin/claude-code-proxy`) |
| `claudeCodeProxyURL` | Health-check URL (default: `http://127.0.0.1:18765/`) |
| `mergeGatewayOnePasswordItem` | Optional `op://Vault/Item/field` reference |
| `onePasswordExecutable` | Path to `op` (default: `/opt/homebrew/bin/op`) |

API key resolution:

```text
MERGE_GATEWAY_API_KEY environment variable
        │
        ├─ present → use it
        │
        └─ absent → read mergeGatewayOnePasswordItem via `op read`
```

The planner then starts the child with `CCP_MERGE_AUTH_TOKEN=<api key>`.

Never commit real `op://…` references, API keys, or `.env` files. Keep secrets in 1Password or your shell environment.

## Architecture (sketch)

```text
AppDelegate
  └─ ProxySession
       ├─ ProxyLaunchPlanner   (settings + env → launch plan)
       ├─ ProxyRuntime         (child process)
       └─ ProxyHealthChecker   (HTTP readiness)
```

Secret reading goes through a `SecretReader` seam (`OnePasswordSecretReader` in production; fakes in tests).

## License

MIT — see [LICENSE](LICENSE).
