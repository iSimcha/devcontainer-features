# iSimcha Dev Tools (dev-tools)

Installs the shared npm-based developer CLIs.

```json
"features": {
  "ghcr.io/devcontainers/features/node:1": {},
  "ghcr.io/isimcha/devcontainer-features/dev-tools:1": {}
}
```

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `installCspell` | boolean | `true` | Install the cspell CLI, used by the spell-check job and the VS Code extension. |
| `installClaudeCode` | boolean | `true` | Install the Claude Code CLI, which the `Anthropic.claude-code` extension shells out to. |

## Requires npm

This feature does not install Node. If `npm` is absent the install **fails loudly** rather than skipping, because a
silently missing `cspell` surfaces later as a broken spell-check job with no explanation. Add
`ghcr.io/devcontainers/features/node:1`, or use a base image that ships Node.
