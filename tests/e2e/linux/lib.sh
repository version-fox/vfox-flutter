#!/usr/bin/env bash
# Shared helpers for the Linux container E2E suite. Sourced, not executed:
#   source "$here/lib.sh"
#
# Layout (mirrors tests/e2e/windows):
#   lib.sh     - generic helpers (this file; no side effects when sourced)
#   config.sh  - default versions / flavours / mirrors
#   setup.sh   - install vfox and register the local flutter plugin
#   install.sh - install one Flutter version with retries
#   verify.sh  - assert on the installed SDK (layout, drift, toolchain)
#   run.sh     - thin in-container orchestrator: setup -> install -> verify
#   e2e.sh     - host-side matrix runner (builds the image, fans out containers)

if [[ -n "${VFOX_E2E_LIB_SH:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
VFOX_E2E_LIB_SH=1

die() {
    echo "FAIL $*" >&2
    exit 1
}

pass() {
    echo "PASS $*"
}

# assert_contains <actual> <expected> <label>
# Prints PASS and returns 0 on match, prints FAIL and returns 1 otherwise.
# Callers running under `set -o errexit` abort on failure; callers that need to
# continue must guard the call with `if` / `||`.
assert_contains() {
    local actual="$1"
    local expected="$2"
    local label="$3"
    if [[ -z "$expected" ]]; then
        echo "FAIL $label : the expected value is empty" >&2
        return 1
    fi
    if printf '%s' "$actual" | grep --quiet --fixed-strings -- "$expected"; then
        echo "PASS $label contains $expected"
        return 0
    fi
    {
        echo "FAIL $label is missing $expected"
        echo "--- actual ---"
        echo "$actual"
    } >&2
    return 1
}

# retry <label> <command...>
# Runs the command streaming its output (so `out=$(retry ...)` still
# captures it) and retries up to $E2E_RETRY_ATTEMPTS times with linear
# backoff. Progress notices go to stderr to stay out of captures.
retry() {
    local label="$1"
    shift
    local max="${E2E_RETRY_ATTEMPTS:-3}"
    local attempt=1
    local code=1
    while ((attempt <= max)); do
        if "$@"; then
            return 0
        else
            # NB: $code must be captured in the else branch. Reading $? after
            # the whole `if` would yield the if-statement's own status (0).
            code=$?
        fi
        if ((attempt < max)); then
            echo "retrying ${label}, attempt ${attempt} exited ${code}" >&2
            sleep $((10 * attempt))
        fi
        attempt=$((attempt + 1))
    done
    return "$code"
}

# require_env <NAME> prints the value or aborts; keeps "missing X" errors uniform.
require_env() {
    local name="$1"
    if [[ -z "${!name:-}" ]]; then
        die "$name is not set"
    fi
    printf '%s' "${!name}"
}

# normalize_arch <uname -m | $ARCH alias> prints amd64|arm64 or fails.
normalize_arch() {
    case "$1" in
        x86_64 | amd64) echo amd64 ;;
        aarch64 | arm64) echo arm64 ;;
        *)
            echo "FAIL unknown architecture $1" >&2
            return 1
            ;;
    esac
}

activate_vfox() {
    # SC1090 cannot be fixed: vfox prints shell code at runtime, so there
    # is no static file for shellcheck to follow.
    # shellcheck disable=SC1090
    eval "$(vfox activate bash)"
}

# sdk_dir prints the SDK root for the active flutter on PATH.
sdk_dir() {
    (cd "$(dirname "$(command -v flutter)")"/.. && pwd)
}
