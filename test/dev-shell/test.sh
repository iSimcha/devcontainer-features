#!/usr/bin/env bash
set -euo pipefail

# The harness injects this library into the test container; it is absent at lint time.
# shellcheck source=/dev/null
source dev-container-features-test-lib

check "nu is on the path" nu --version
check "ouch is installed" ouch --version
check "starship came from packages.json" starship --version
check "just came from packages.json" just --version
check "ripgrep came from packages.json" rg --version
check "bun came from packages.json" bun --version

check "shared files installed" test -f /usr/local/share/dev-shell/packages.json
check "get-package.nu installed" test -x /usr/local/share/dev-shell/get-package.nu
check "shell config staged" test -f /usr/local/share/dev-shell/config/starship.toml

# packages.json drives the installs, so a malformed entry must fail the build, not the container.
check "packages.json parses" nu --commands "open /usr/local/share/dev-shell/packages.json | length"
check "no package filename has stray whitespace" nu --commands \
	"if (open /usr/local/share/dev-shell/packages.json | any {|p| \$p.filename != (\$p.filename | str trim)}) { exit 1 }"

# Run the postCreate script directly rather than relying on the harness lifecycle. It is
# idempotent, so this is valid whether or not the harness already ran it.
check "configure-environment.sh succeeds" /usr/local/share/dev-shell/configure-environment.sh
check "configure-environment.sh is idempotent" /usr/local/share/dev-shell/configure-environment.sh

check "nushell config installed" test -f "${PWD}/.cache/nushell/config.nu"
check "nushell env installed" test -f "${PWD}/.cache/nushell/env.nu"
check "nushell functions installed" test -f "${PWD}/.cache/nushell/scripts/functions.nu"
check "starship config installed" test -f "${HOME}/.config/starship.toml"
check "nushell config dir is a symlink to the workspace cache" test -L "${HOME}/.config/nushell"
check "bash history is preserved in the workspace" test -L "${HOME}/.bash_history"

# The functions module is what a developer actually gets in an interactive shell.
check "nushell functions load" nu --commands "use ${PWD}/.cache/nushell/scripts/functions.nu *; l"

reportResults
