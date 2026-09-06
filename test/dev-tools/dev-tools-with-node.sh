#!/usr/bin/env bash
set -euo pipefail

# The harness injects this library into the test container; it is absent at lint time.
# shellcheck source=/dev/null
source dev-container-features-test-lib

check "cspell is on the path" cspell --version
check "claude code cli is on the path" claude --version

reportResults
