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
check "yt came from packages.json" yt --version
# fj has no --version flag; the subcommand is the only way to ask.
check "fj came from packages.json" fj version
check "uv came from packages.json" uv --version
check "uvx came from packages.json" uvx --version
check "biome came from packages.json" biome --version
check "d2 came from packages.json" d2 --version
check "kingfisher came from packages.json" kingfisher --version
check "trufflehog came from packages.json" trufflehog --version
check "noseyparker came from packages.json" noseyparker --version
# titus has no --version flag; the subcommand is the only way to ask.
check "titus came from packages.json" titus version

check "shared files installed" test -f /usr/local/share/dev-shell/packages.json
check "get-package.nu installed" test -x /usr/local/share/dev-shell/get-package.nu
check "shell config staged" test -f /usr/local/share/dev-shell/config/starship.toml

# packages.json drives the installs, so a malformed entry must fail the build, not the container.
check "packages.json parses" nu --commands "open /usr/local/share/dev-shell/packages.json | length"
check "no package filename has stray whitespace" nu --commands \
	"if (open /usr/local/share/dev-shell/packages.json | any {|p| \$p.filename != (\$p.filename | str trim)}) { exit 1 }"

# A wildcard glob such as "uv*" must install extracted binaries only, never the downloaded archive.
check "no download archive installed alongside the binaries" nu --commands \
	"if (ls /usr/local/bin | any {|f| \$f.name =~ '\\.(tar\\.[a-z0-9]+|tgz|zip)\$'}) { exit 1 }"

# deno and watchexec were dropped deliberately; fail the build if an entry for either comes back.
check "dropped tools stay out of packages.json" nu --commands \
	"if (open /usr/local/share/dev-shell/packages.json | any {|p| \$p.repo in ['denoland/deno', 'watchexec/watchexec']}) { exit 1 }"

# A missing checksum must never silently disable the integrity check for that entry.
check "every package has a 64-character hex sha256" nu --commands \
	"if (open /usr/local/share/dev-shell/packages.json | any {|p| not ((\$p.sha256? | default '') =~ '^[0-9a-f]{64}\$')}) { exit 1 }"

# A wrong sha256 must fail the install and must not install that entry's binary.
# shellcheck disable=SC2016
check "a wrong sha256 fails install-all and installs nothing for that entry" bash -c '
	set -euo pipefail
	tmp_json="$(mktemp --suffix=.json)"
	tmp_bin="$(mktemp -d)"
	trap "rm -rf \"${tmp_json}\" \"${tmp_bin}\"" EXIT
	nu --commands "open /usr/local/share/dev-shell/packages.json | update 0.sha256 \"0000000000000000000000000000000000000000000000000000000000000000\" | save --force \"${tmp_json}\""
	if DEV_SHELL_PACKAGES_JSON="${tmp_json}" DEV_SHELL_BIN_DIR="${tmp_bin}" nu /usr/local/share/dev-shell/get-package.nu install-all; then
		exit 1
	fi
	[ -z "$(ls -A "${tmp_bin}")" ]
'

# A removed sha256 key must fail the install the same way a wrong one does.
# shellcheck disable=SC2016
check "a missing sha256 fails install-all" bash -c '
	set -euo pipefail
	tmp_json="$(mktemp --suffix=.json)"
	tmp_bin="$(mktemp -d)"
	trap "rm -rf \"${tmp_json}\" \"${tmp_bin}\"" EXIT
	nu --commands "open /usr/local/share/dev-shell/packages.json | update 0 {|row| \$row | reject sha256} | save --force \"${tmp_json}\""
	if DEV_SHELL_PACKAGES_JSON="${tmp_json}" DEV_SHELL_BIN_DIR="${tmp_bin}" nu /usr/local/share/dev-shell/get-package.nu install-all; then
		exit 1
	fi
	[ -z "$(ls -A "${tmp_bin}")" ]
'

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

# Every helper ported from container-apps must be defined by the functions module.
for fn in l la ll lt lrt lrs rga fda get-hash dl url-filename git-log git-commit git-version backup restore os-release get-mountpoints find-dir-parent table-diff; do
	check "function ${fn} is defined" nu --commands \
		"use ${PWD}/.cache/nushell/scripts/functions.nu *; if (scope commands | where name == '${fn}' | is-empty) { exit 1 }"
done

# Side-effect-free calls that exercise a ported function end to end.
check "get-hash hashes a file" nu --commands \
	"use ${PWD}/.cache/nushell/scripts/functions.nu *; get-hash /usr/local/share/dev-shell/packages.json | get hash.0 | str length | if \$in != 64 { exit 1 }"
check "table-diff reports differing rows" nu --commands \
	"use ${PWD}/.cache/nushell/scripts/functions.nu *; table-diff [[a]; [1] [2]] [[a]; [2] [3]] --keys [a] | length | if \$in != 2 { exit 1 }"
check "os-release parses" nu --commands "use ${PWD}/.cache/nushell/scripts/functions.nu *; os-release | is-empty | if \$in { exit 1 }"
# shellcheck disable=SC2016
check "backup and restore round-trip" bash -c '
	set -euo pipefail
	tmp="$(mktemp -d)"
	trap "rm -rf \"${tmp}\"" EXIT
	cd "${tmp}"
	mkdir data && echo hello > data/file.txt
	nu --commands "use '"${PWD}"'/.cache/nushell/scripts/functions.nu *; backup data"
	rm -r data
	nu --commands "use '"${PWD}"'/.cache/nushell/scripts/functions.nu *; restore (glob data-*.tar.zst | first)"
	[ "$(cat data/file.txt)" = "hello" ]
'

reportResults
