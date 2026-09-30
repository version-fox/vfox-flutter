#!/usr/bin/env bash
# Assert on an installed SDK: `bash verify.sh <flavor> <version>`.
# Runs standalone (called as a subprocess by run.sh, like verify.ps1).
#
# NOTE: the drift-warning strings asserted here are part of the plugin's
# user-facing contract (see hooks/ / lib/). If the Lua side rewords them,
# update both this file and tests/e2e/windows/verify.Tests.ps1 together.
set -o errexit -o nounset -o pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$here/lib.sh"

# The official SDK must be pristine; the OpenHarmony SDK must be a git
# checkout with its engine pins tracked.
verify_sdk_layout() {
    local flavor="$1"
    local sdk="$2"
    if [[ "$flavor" == "official" ]]; then
        local subject
        subject="$(git -C "$sdk" log --max-count=1 --format=%s)"
        if printf '%s' "$subject" | grep --quiet --fixed-strings 'vfox install'; then
            die "the official SDK carries a vfox commit"
        fi
        pass "the official SDK carries no vfox commit"
    else
        [[ -d "$sdk/.git" ]] || die "the OpenHarmony SDK is not a git checkout"
        [[ -n "$(git -C "$sdk" ls-files bin/internal/engine.version)" ]] \
            || die "the OpenHarmony engine version pin is not tracked"
        pass "the OpenHarmony SDK is a git checkout with its engine pins tracked"
    fi
}

# Anchor the installed HEAD via .vfox-manifest, then prove `vfox use`
# reports drift exactly when the SDK moves (simulated `flutter upgrade`)
# and goes quiet again once restored.
verify_manifest_drift() {
    local version="$1"
    local sdk="$2"
    local manifest="$sdk/.vfox-manifest"
    [[ -f "$manifest" ]] \
        || die "the SDK has no .vfox-manifest, so its installed version cannot be anchored"
    pass "the SDK carries a .vfox-manifest"

    local installed_head anchor
    installed_head="$(git -C "$sdk" rev-parse HEAD)"
    if ! anchor="$(jq --raw-output '.expected_head // empty' "$manifest")"; then
        die "the .vfox-manifest is not valid JSON"
    fi
    [[ -n "$anchor" ]] || die "the .vfox-manifest has no expected_head"
    [[ "$anchor" == "$installed_head" ]] \
        || die "the .vfox-manifest anchor $anchor does not match the installed git HEAD $installed_head"
    pass "the .vfox-manifest anchor matches the installed git HEAD"

    local clean_output clean_code=0
    clean_output="$(vfox use --global flutter@"$version" 2>&1)" || clean_code=$?
    ((clean_code == 0)) || die "vfox use exited with code ${clean_code}"
    if printf '%s' "$clean_output" | grep --quiet --fixed-strings 'has drifted'; then
        {
            echo "FAIL a freshly installed SDK reports drift"
            echo "--- actual ---"
            echo "$clean_output"
        } >&2
        exit 1
    fi
    pass "a freshly installed SDK reports no drift"

    if ! GIT_AUTHOR_NAME=e2e GIT_AUTHOR_EMAIL=e2e@vfox.flutter \
        GIT_COMMITTER_NAME=e2e GIT_COMMITTER_EMAIL=e2e@vfox.flutter \
        git -C "$sdk" commit --allow-empty --quiet -m 'simulated flutter upgrade'; then
        die "failed to record a simulated flutter upgrade commit"
    fi
    local drifted_head drift_output drift_code=0
    drifted_head="$(git -C "$sdk" rev-parse HEAD)"

    drift_output="$(vfox use --global flutter@"$version" 2>&1)" || drift_code=$?
    ((drift_code == 0)) || die "vfox use exited with code ${drift_code}"
    assert_contains "$drift_output" 'has drifted from the version vfox installed' 'drift warning'
    assert_contains "$drift_output" "$anchor" 'drift warning expected head'
    assert_contains "$drift_output" "$drifted_head" 'drift warning current head'
    assert_contains "$drift_output" "vfox uninstall flutter@$version" 'drift warning restore command'
    assert_contains "$drift_output" "vfox install  flutter@$version" 'drift warning restore command'
    assert_contains "$drift_output" "vfox use      flutter@$version" 'drift warning restore command'
    assert_contains "$drift_output" 'vfox install flutter@<new-version>' 'drift warning upgrade command'

    git -C "$sdk" reset --quiet --hard "$anchor"
    local restored_output restored_code=0
    restored_output="$(vfox use --global flutter@"$version" 2>&1)" || restored_code=$?
    ((restored_code == 0)) || die "vfox use exited with code ${restored_code}"
    if printf '%s' "$restored_output" | grep --quiet --fixed-strings 'has drifted'; then
        {
            echo "FAIL a restored SDK still reports drift"
            echo "--- actual ---"
            echo "$restored_output"
        } >&2
        exit 1
    fi
    pass "a restored SDK reports no drift"
}

# The installed toolchain must bootstrap (pub.dev reachable) and the
# dart/flutter versions must agree with each other and the SDK checkout.
verify_toolchain() {
    local sdk="$1"
    if ! retry 'pub.dev' curl --fail --silent --show-error --location --max-time 20 --output /dev/null 'https://pub.dev/api/packages/args' >/dev/null; then
        die "pub.dev is unreachable, the Flutter tool cannot bootstrap"
    fi
    local dart flutter
    # dart --version reports on stderr, so merge streams like the old retry did.
    if ! dart="$(retry 'dart --version' dart --version 2>&1)"; then
        die "dart --version did not run"
    fi
    if ! flutter="$(retry 'flutter --version' flutter --version --no-version-check 2>&1)"; then
        die "flutter --version did not run"
    fi
    assert_contains "$flutter" "$(git -C "$sdk" rev-parse HEAD | cut --characters=1-10)" 'flutter --version revision'
    assert_contains "$dart" "$(printf '%s' "$flutter" | awk '/Tools/ { print $4 }')" 'dart --version'
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    flavor="${1:?usage: verify.sh <flavor> <version>}"
    version="${2:?usage: verify.sh <flavor> <version>}"
    activate_vfox
    sdk="$(sdk_dir)"
    verify_sdk_layout "$flavor" "$sdk"
    verify_manifest_drift "$version" "$sdk"
    verify_toolchain "$sdk"
fi
