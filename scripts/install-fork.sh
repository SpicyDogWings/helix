#!/usr/bin/env sh
# Install the fork build of Helix: Rust side-panel explorer + Steel plugin system.
#
#   curl -fsSL https://raw.githubusercontent.com/SpicyDogWings/helix/feature/steel-on-personal/scripts/install-fork.sh | sh
#
# Options (or pass them after `sh -s --`):
#   --no-config        install the binary only, leave ~/.config/helix untouched
#   --prefix=DIR       install root (default: $HOME/.local/hx-fork)
#   --bin-dir=DIR      where to link `hx` (default: $HOME/.local/bin)
#
# Environment:
#   HX_FORK_TAG        release tag to install (default: latest fork release)
#   HX_FORK_REPO       owner/repo to pull from (default: SpicyDogWings/helix)
#   HX_FORK_PREFIX     same as --prefix
#   HX_FORK_BIN_DIR    same as --bin-dir
set -eu

REPO="${HX_FORK_REPO:-SpicyDogWings/helix}"
TAG="${HX_FORK_TAG:-latest}"
PREFIX="${HX_FORK_PREFIX:-$HOME/.local/hx-fork}"
BIN_DIR="${HX_FORK_BIN_DIR:-$HOME/.local/bin}"
WITH_CONFIG=1

for arg in "$@"; do
    case "$arg" in
        --no-config) WITH_CONFIG=0 ;;
        --prefix=*) PREFIX="${arg#*=}" ;;
        --bin-dir=*) BIN_DIR="${arg#*=}" ;;
        -h | --help)
            sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "install-fork: unknown option '$arg'" >&2
            exit 1
            ;;
    esac
done

case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) ARCH="x86_64-linux" ;;
    Linux-aarch64 | Linux-arm64)
        echo "install-fork: no prebuilt binary for $(uname -s)-$(uname -m)." >&2
        echo "Build it yourself: cargo build --release --features steel" >&2
        exit 1
        ;;
    *)
        echo "install-fork: no prebuilt binary for $(uname -s)-$(uname -m)." >&2
        echo "Build it yourself: cargo build --release --features steel" >&2
        exit 1
        ;;
esac

if command -v curl >/dev/null 2>&1; then
    fetch() { curl -fsSL "$1"; }
elif command -v wget >/dev/null 2>&1; then
    fetch() { wget -qO- "$1"; }
else
    echo "install-fork: curl or wget is required" >&2
    exit 1
fi

if [ "$TAG" = latest ]; then
    RELEASE_API="https://api.github.com/repos/$REPO/releases/latest"
else
    RELEASE_API="https://api.github.com/repos/$REPO/releases/tags/$TAG"
fi

echo "install-fork: resolving release ($TAG) from $REPO"
URL=$(fetch "$RELEASE_API" |
    grep -o "\"browser_download_url\"[[:space:]]*:[[:space:]]*\"[^\"]*-$ARCH\.tar\.gz\"" |
    head -n 1 |
    sed 's/.*"\(https[^"]*\)"/\1/')

if [ -z "${URL:-}" ]; then
    echo "install-fork: no $ARCH asset found for '$TAG' in $REPO" >&2
    echo "Check https://github.com/$REPO/releases" >&2
    exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM

echo "install-fork: downloading $(basename "$URL")"
if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$URL" -o "$TMP/hx-fork.tar.gz"
else
    wget -qO "$TMP/hx-fork.tar.gz" "$URL"
fi

tar -xzf "$TMP/hx-fork.tar.gz" -C "$TMP"

if [ ! -x "$TMP/hx-fork/hx" ]; then
    echo "install-fork: unexpected archive layout (missing hx-fork/hx)" >&2
    exit 1
fi

mkdir -p "$(dirname "$PREFIX")"
rm -rf "$PREFIX"
mv "$TMP/hx-fork" "$PREFIX"

mkdir -p "$BIN_DIR"
ln -sfn "$PREFIX/hx" "$BIN_DIR/hx"
echo "install-fork: installed $PREFIX/hx"
echo "install-fork: linked   $BIN_DIR/hx"

if [ "$WITH_CONFIG" = 1 ]; then
    CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/helix"
    mkdir -p "$CONFIG_DIR"

    # Plugin sources (never overwrite an existing copy).
    if [ -d "$CONFIG_DIR/file-explorer" ]; then
        echo "install-fork: keeping existing $CONFIG_DIR/file-explorer"
    else
        cp -R "$PREFIX/plugin/file-explorer" "$CONFIG_DIR/file-explorer"
        echo "install-fork: installed plugin $CONFIG_DIR/file-explorer"
    fi

    add_line() {
        _file="$1"
        _line="$2"
        [ -f "$_file" ] || : >"$_file"
        grep -qxF "$_line" "$_file" || printf '%s\n' "$_line" >>"$_file"
    }

    add_line "$CONFIG_DIR/init.scm" '(require "file-explorer/explorer.scm")'

    if [ ! -f "$CONFIG_DIR/helix.scm" ] || ! grep -q '^(provide' "$CONFIG_DIR/helix.scm"; then
        add_line "$CONFIG_DIR/helix.scm" '(require "file-explorer/explorer.scm")'
        add_line "$CONFIG_DIR/helix.scm" '(provide open-file-explorer)'
    else
        echo "install-fork: $CONFIG_DIR/helix.scm already has provides; add these lines yourself:"
        echo '    (require "file-explorer/explorer.scm")'
        echo '    (provide open-file-explorer)'
    fi

    KEYBINDING='P = ":open-file-explorer"'
    if grep -qF 'open-file-explorer' "$CONFIG_DIR/config.toml" 2>/dev/null; then
        :
    elif grep -q '^\[keys\.normal\.space\]' "$CONFIG_DIR/config.toml" 2>/dev/null; then
        echo "install-fork: $CONFIG_DIR/config.toml already defines [keys.normal.space]; add:"
        echo "    $KEYBINDING"
    else
        {
            printf '\n[keys.normal.space]\n'
            printf '%s\n' "$KEYBINDING"
        } >>"$CONFIG_DIR/config.toml"
        echo "install-fork: bound space P to the plugin explorer in $CONFIG_DIR/config.toml"
    fi
fi

echo

"$PREFIX/hx" --version || true

echo
echo "Usage:"
echo "  hx                     # this fork build (make sure $BIN_DIR is in PATH)"
echo "  space E                # Rust explorer panel (reveal current file)"
echo "  space P                # Steel plugin explorer (if the installer wired the config)"
echo "  space e                # classic file picker"
echo
echo "Docs: $PREFIX/README-FORK.md, changelog: $PREFIX/FORK_CHANGELOG.md"
