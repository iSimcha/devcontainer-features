# iSimcha Dev Shell (dev-shell)

Installs Nushell, Starship and the shared CLI tool set, and lays down the iSimcha Nushell and Starship configuration.

```json
"features": {
  "ghcr.io/isimcha/devcontainer-features/dev-shell:1": {}
}
```

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `nushellVersion` | string | `0.112.2` | Nushell version to install. |
| `ouchVersion` | string | `0.5.1` | Version of ouch, used to unpack the other CLI tools. |
| `installPackages` | boolean | `true` | Install the CLI tools listed in `packages.json`. |
| `installConfig` | boolean | `true` | Lay down the Nushell and Starship configuration on container create. |

## What it does

At image build time, as root:

- Installs `nu` and its plugins, plus `ouch`, into `/usr/local/bin`.
- Installs every tool in `packages.json` into `/usr/local/bin` (just, ripgrep, fd, deno, caddy, xh, gomplate, yq, bun,
  starship, rage, watchexec).
- Stages `get-package.nu`, `packages.json` and the shell configuration under `/usr/local/share/dev-shell`.

On container create, as the remote user, via the feature's `postCreateCommand`:

- Creates `${PWD}/.cache/`, and points `~/.config/nushell` at `${PWD}/.cache/nushell` so shell state survives a rebuild.
- Copies `env.nu`, `config.nu`, `scripts/functions.nu` and `~/.config/starship.toml` into place, **only when absent**,
  so a developer's own edits are kept.
- Symlinks `~/.bash_history` into the workspace cache and appends the history-preserving `PROMPT_COMMAND` to `.bashrc`.

Add `.cache/` to the consuming repository's `.gitignore`.

## Notes

Binaries install to `/usr/local/bin` rather than `~/.local/bin`. The feature installs as root at build time, when the
remote user's home directory is not the installing user's home, so a user-scoped path would put the tools in `/root`.

`get-package.nu` can be run by hand inside the container. It reads `/usr/local/share/dev-shell/packages.json` by
default; `DEV_SHELL_PACKAGES_JSON` and `DEV_SHELL_BIN_DIR` override the locations.

```nu
nu /usr/local/share/dev-shell/get-package.nu search ripgrep
nu /usr/local/share/dev-shell/get-package.nu install-all
```
