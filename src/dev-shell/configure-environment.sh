#!/usr/bin/env bash
set -euo pipefail

# Runs as the remote user on container create, with the workspace mounted at $PWD.
# Shell config and history live in the workspace .cache directory, which survives a rebuild.

SHARE_DIR="${DEV_SHELL_SHARE_DIR:-/usr/local/share/dev-shell}"
CACHE_DIR="${PWD}/.cache"
NUSHELL_DIR="${CACHE_DIR}/nushell"

if [[ -f "${SHARE_DIR}/feature.env" ]]; then
	# shellcheck source=/dev/null
	source "${SHARE_DIR}/feature.env"
fi

if [[ "${DEV_SHELL_INSTALL_CONFIG:-true}" != "true" ]]; then
	echo "(*) dev-shell: installConfig is false, leaving the shell configuration alone."
	exit 0
fi

if [[ ! -d "${SHARE_DIR}/config" ]]; then
	echo "ERROR: dev-shell config directory '${SHARE_DIR}/config' is missing; the feature did not install correctly." >&2
	exit 1
fi

mkdir --parents "${CACHE_DIR}" "${HOME}/bin" "${HOME}/.config" "${NUSHELL_DIR}/scripts"

# Preserve Bash history across rebuilds.
if [[ ! -f "${CACHE_DIR}/bash_history" ]]; then
	touch "${CACHE_DIR}/bash_history"
fi
if [[ ! -L "${HOME}/.bash_history" ]]; then
	if [[ -e "${HOME}/.bash_history" ]]; then
		# A real history file from the base image. Keep its contents rather than discarding them.
		cat "${HOME}/.bash_history" >> "${CACHE_DIR}/bash_history"
		rm "${HOME}/.bash_history"
	fi
	ln --symbolic "${CACHE_DIR}/bash_history" "${HOME}/.bash_history"
fi

# Starship config. A user edit in the container is kept.
if [[ ! -f "${HOME}/.config/starship.toml" ]]; then
	cp "${SHARE_DIR}/config/starship.toml" "${HOME}/.config/starship.toml"
fi

# Point Nushell at the workspace cache. Replace only a stale symlink, never a real directory,
# so a user's own ~/.config/nushell is not silently discarded.
if [[ -L "${HOME}/.config/nushell" ]]; then
	if [[ "$(readlink "${HOME}/.config/nushell")" != "${NUSHELL_DIR}" ]]; then
		rm "${HOME}/.config/nushell"
		ln --symbolic "${NUSHELL_DIR}" "${HOME}/.config/nushell"
	fi
elif [[ -e "${HOME}/.config/nushell" ]]; then
	echo "WARNING: '${HOME}/.config/nushell' exists and is not a symlink; leaving it alone." >&2
else
	ln --symbolic "${NUSHELL_DIR}" "${HOME}/.config/nushell"
fi

if [[ ! -f "${NUSHELL_DIR}/env.nu" ]]; then
	cp "${SHARE_DIR}/config/nushell_env.nu" "${NUSHELL_DIR}/env.nu"
fi
if [[ ! -f "${NUSHELL_DIR}/config.nu" ]]; then
	cp "${SHARE_DIR}/config/nushell_config.nu" "${NUSHELL_DIR}/config.nu"
fi
if [[ ! -f "${NUSHELL_DIR}/scripts/functions.nu" ]]; then
	cp "${SHARE_DIR}/config/nushell_functions.nu" "${NUSHELL_DIR}/scripts/functions.nu"
fi

# Disable the npm fund message.
if [[ ! -e "${HOME}/.npmrc" ]]; then
	touch "${HOME}/.npmrc"
fi
if ! grep --quiet "fund=false" "${HOME}/.npmrc"; then
	printf '\nfund=false\n' >> "${HOME}/.npmrc"
fi

# Write history after every command so it survives a rebuild.
if [[ -f "${HOME}/.bashrc" ]] && ! grep --quiet '^### CUSTOM: Preserve Bash History ###$' "${HOME}/.bashrc"; then
	cat >> "${HOME}/.bashrc" <<'EOT'

### CUSTOM: Preserve Bash History ###
PROMPT_COMMAND="history -a; ${PROMPT_COMMAND}"
EOT
fi

echo "(*) dev-shell: environment configured."
