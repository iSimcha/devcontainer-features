#!/usr/bin/env bash
set -euo pipefail

source dev-container-features-test-lib

check "cspell is on the path" cspell --version
check "claude code cli is on the path" claude --version

reportResults
