VFOX_VERSION="${VFOX_VERSION:-latest}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WORK="$(mktemp -d)"

if [ "$VFOX_VERSION" = main ]; then
    git clone --depth 1 https://github.com/version-fox/vfox "$WORK/src"
    (cd "$WORK/src" && CGO_ENABLED=0 go build -trimpath -o /usr/local/bin/vfox .)
else
    curl -sSL https://raw.githubusercontent.com/version-fox/vfox/main/install.sh | bash
fi

(cd "$REPO_ROOT" && zip -qr "$WORK/flutter.zip" metadata.lua hooks lib)
vfox add flutter --source "$WORK/flutter.zip"
