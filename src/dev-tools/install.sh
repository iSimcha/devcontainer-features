#!/usr/bin/env bash
set -euo pipefail

# Runs as root at image build time.

INSTALL_CSPELL="${INSTALLCSPELL:-"true"}"
INSTALL_CLAUDE_CODE="${INSTALLCLAUDECODE:-"true"}"

if [[ "$(id --user)" -ne 0 ]]; then
	echo "ERROR: this feature must install as root." >&2
	exit 1
fi

if [[ "${INSTALL_CSPELL}" != "true" && "${INSTALL_CLAUDE_CODE}" != "true" ]]; then
	echo "(*) dev-tools: nothing selected, skipping."
	exit 0
fi

# npm comes from the base image or the node feature, never from here. Failing loudly beats
# installing nothing and letting the missing CLI surface later as a broken check job.
if ! command -v npm > /dev/null 2>&1; then
	echo "ERROR: npm was not found. Add 'ghcr.io/devcontainers/features/node:1' to the features in devcontainer.json, or use a base image that ships Node." >&2
	exit 1
fi

if [[ "${INSTALL_CSPELL}" = "true" ]]; then
	echo "(*) Installing cspell..."
	npm install --global cspell@latest
fi

if [[ "${INSTALL_CLAUDE_CODE}" = "true" ]]; then
	echo "(*) Installing the Claude Code CLI..."
	npm install --global @anthropic-ai/claude-code
fi

echo "Done!"
