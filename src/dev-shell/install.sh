#!/usr/bin/env bash
set -euo pipefail

# Runs as root at image build time. The workspace is not mounted yet, so anything that needs
# the workspace belongs in configure-environment.sh, which runs later as the remote user.

NUSHELL_VERSION="${NUSHELLVERSION:-"0.112.2"}"
OUCH_VERSION="${OUCHVERSION:-"0.5.1"}"
INSTALL_PACKAGES="${INSTALLPACKAGES:-"true"}"
INSTALL_CONFIG="${INSTALLCONFIG:-"true"}"

SHARE_DIR="/usr/local/share/dev-shell"
BIN_DIR="/usr/local/bin"

if [[ "$(id --user)" -ne 0 ]]; then
	echo "ERROR: this feature must install as root." >&2
	exit 1
fi

feature_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

check_packages() {
	if ! dpkg --status "$@" > /dev/null 2>&1; then
		apt-get update --yes
		apt-get install --yes --no-install-recommends "$@"
	fi
}

export DEBIAN_FRONTEND=noninteractive
check_packages ca-certificates curl

# Downloads a tar.gz release and installs the named binaries into BIN_DIR.
install_tarball() {
	local url="$1"
	shift
	local tmp_dir
	tmp_dir="$(mktemp --directory)"
	# Without pipefail a curl failure would be masked by tar succeeding on empty input.
	if ! curl --silent --show-error --location --fail "${url}" | tar --strip-components 1 --directory="${tmp_dir}" --extract --gzip --file -; then
		echo "ERROR: failed to download or extract '${url}'." >&2
		rm --recursive "${tmp_dir}"
		return 1
	fi
	local binary
	for binary in "$@"; do
		# nu ships plugin binaries as nu_plugin_*, so the caller passes a glob.
		local matches=("${tmp_dir}"/${binary})
		if [[ ! -e "${matches[0]}" ]]; then
			echo "ERROR: '${binary}' not found in '${url}'." >&2
			rm --recursive "${tmp_dir}"
			return 1
		fi
		install --mode 0755 "${matches[@]}" "${BIN_DIR}/"
	done
	rm --recursive "${tmp_dir}"
}

os="$(uname --kernel-name | tr '[:upper:]' '[:lower:]')"
arch="$(uname --machine)"

echo "(*) Installing Nushell ${NUSHELL_VERSION}..."
install_tarball \
	"https://github.com/nushell/nushell/releases/download/${NUSHELL_VERSION}/nu-${NUSHELL_VERSION}-${arch}-unknown-${os}-musl.tar.gz" \
	"nu" "nu_plugin_*"

echo "(*) Installing ouch ${OUCH_VERSION}..."
install_tarball \
	"https://github.com/ouch-org/ouch/releases/download/${OUCH_VERSION}/ouch-${arch}-unknown-${os}-musl.tar.gz" \
	"ouch"

echo "(*) Installing shared files to ${SHARE_DIR}..."
mkdir --parents "${SHARE_DIR}"
install --mode 0755 "${feature_dir}/get-package.nu" "${SHARE_DIR}/get-package.nu"
install --mode 0755 "${feature_dir}/configure-environment.sh" "${SHARE_DIR}/configure-environment.sh"
install --mode 0644 "${feature_dir}/packages.json" "${SHARE_DIR}/packages.json"
mkdir --parents "${SHARE_DIR}/config"
cp --recursive "${feature_dir}/config/." "${SHARE_DIR}/config/"
chmod 0644 "${SHARE_DIR}"/config/*

if [[ "${INSTALL_PACKAGES}" = "true" ]]; then
	echo "(*) Installing CLI tools from packages.json..."
	DEV_SHELL_PACKAGES_JSON="${SHARE_DIR}/packages.json" \
		DEV_SHELL_BIN_DIR="${BIN_DIR}" \
		"${BIN_DIR}/nu" "${SHARE_DIR}/get-package.nu" install-all
fi

# configure-environment.sh reads this to decide whether to lay down the shell config.
echo "DEV_SHELL_INSTALL_CONFIG=${INSTALL_CONFIG}" > "${SHARE_DIR}/feature.env"
chmod 0644 "${SHARE_DIR}/feature.env"

echo "Done!"
