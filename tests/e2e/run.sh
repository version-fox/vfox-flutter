#!/usr/bin/env bash
set -eu

VFOX_VERSION="${VFOX_VERSION:-latest}"
FLUTTER_VERSION=3.44.0
[ "$(uname -m)" = x86_64 ] || { echo "x86_64 only, got $(uname -m)" >&2; exit 1; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d)"
export PATH="$WORK:$PATH"

ensure_go() {
    command -v go >/dev/null 2>&1 && return
    local ver
    ver="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -n1)"
    curl -fsSL "https://go.dev/dl/${ver}.linux-amd64.tar.gz" -o "$WORK/go.tgz"
    tar -C "$WORK" -xzf "$WORK/go.tgz"
    export PATH="$WORK/go/bin:$PATH"
}

if [ "$VFOX_VERSION" = main ]; then
    ensure_go
    git clone --depth 1 https://github.com/version-fox/vfox "$WORK/src"
    (cd "$WORK/src" && go build -trimpath -o "$WORK/vfox" .)
else
    curl -sSL https://raw.githubusercontent.com/version-fox/vfox/main/install.sh | bash
fi

(cd "$REPO_ROOT" && zip -qr "$WORK/flutter.zip" metadata.lua hooks lib)

eval "$(vfox activate bash)"
vfox add flutter --source "$WORK/flutter.zip"
vfox install "flutter@${FLUTTER_VERSION}"
vfox use --global "flutter@${FLUTTER_VERSION}"

bash -c '
    set -e
    eval "$(vfox activate bash)"
    dart --version
    flutter --version --no-version-check
'
