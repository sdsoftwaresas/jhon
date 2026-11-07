#!/bin/sh
# Jhon's installer:
#   curl -fsSL https://raw.githubusercontent.com/sdsoftwaresas/jhon/main/install.sh | sh
# A specific release:
#   curl -fsSL https://raw.githubusercontent.com/sdsoftwaresas/jhon/main/install.sh | JHON_VERSION=0.1.0 sh
#
# Linux only (amd64, arm64; WSL is Linux). Needs curl or wget, tar, gzip and
# sha256sum or shasum. It verifies the release's sha256 and, when cosign is
# installed, its signature, then hands the tarball to the release's own
# `jhon release install`, which checks the sha256 again, unpacks it under
# ~/.local/share/jhon/releases and links ~/.local/bin/jhon.
set -eu

REPO="sdsoftwaresas/jhon"
LATEST_URL="https://api.github.com/repos/${REPO}/releases/latest"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download"
# The signer, as engine/internal/update/verify.go (Issuer, IdentityPattern).
ISSUER="https://token.actions.githubusercontent.com"
IDENTITY='^https://github\.com/sdsoftwaresas/jhon/\.github/workflows/release\.yml@refs/tags/v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(-rc\.(0|[1-9]\d*))?$'

TMP=""
cleanup() {
    if [ -n "$TMP" ]; then rm -rf "$TMP"; fi
}
trap cleanup EXIT
trap 'exit 1' INT TERM HUP

say() { printf 'jhon: %s\n' "$*"; }
die() {
    printf 'jhon: %s\n' "$*" >&2
    exit 1
}
have() { command -v "$1" >/dev/null 2>&1; }

# fetch URL [FILE]: to FILE, or to stdout without one.
fetch() {
    if have curl; then
        if [ $# -eq 2 ]; then curl -fsSL --proto '=https' -o "$2" "$1"; else curl -fsSL --proto '=https' "$1"; fi
    elif have wget; then
        if [ $# -eq 2 ]; then wget -q --https-only -O "$2" "$1"; else wget -q --https-only -O - "$1"; fi
    else
        die "curl or wget is required"
    fi
}

# fetch_latest FILE: /releases/latest's JSON to FILE. GitHub answers 404
# while only pre-releases are published, which is said as such; any other
# failure (the network, a 5xx, a rate limit) shows the tool's own error.
fetch_latest() {
    err="$TMP/latest.err"
    if have curl; then
        code=$(curl -fsSL --proto '=https' -w '%{http_code}' -o "$1" "$LATEST_URL" 2>"$err") && return 0
    elif have wget; then
        wget -S --https-only -O "$1" "$LATEST_URL" 2>"$err" && return 0
        code=$(sed -n 's/.*HTTP\/[0-9.]* \([0-9][0-9][0-9]\).*/\1/p' "$err" | sed -n '$p')
    else
        die "curl or wget is required"
    fi
    [ "$code" != 404 ] ||
        die "no stable release is published yet (only pre-releases); pick one at https://github.com/${REPO}/releases and run: curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh | JHON_VERSION=<version> sh"
    cat "$err" >&2
    die "cannot read the latest release from $LATEST_URL"
}

# valid_version V: X.Y.Z or X.Y.Z-rc.N, no leading zeros. The case guard
# refuses a newline too, which grep, reading line by line, would let through.
valid_version() {
    case $1 in '' | *[!0-9.rc-]*) return 1 ;; esac
    printf '%s\n' "$1" | grep -Eq '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-rc\.(0|[1-9][0-9]*))?$'
}

os=$(uname -s)
[ "$os" = "Linux" ] || die "Jhon v0.1 runs on Linux only (this is $os); on Windows use WSL"
case $(uname -m) in
    x86_64 | amd64) arch=amd64 ;;
    aarch64 | arm64) arch=arm64 ;;
    *) die "unsupported architecture: $(uname -m) (Jhon ships amd64 and arm64)" ;;
esac

for tool in tar gzip; do
    have "$tool" || die "$tool is required"
done
if have sha256sum; then
    sha() { sha256sum "$1" | awk '{ print $1 }'; }
elif have shasum; then
    sha() { shasum -a 256 "$1" | awk '{ print $1 }'; }
else
    die "sha256sum or shasum is required"
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/jhon-install.XXXXXX")
if [ -n "${JHON_VERSION:-}" ]; then
    version=$JHON_VERSION
    valid_version "$version" || die "JHON_VERSION must be X.Y.Z or X.Y.Z-rc.N (no 'v', no leading zeros): $version"
else
    # /releases/latest never names a pre-release.
    fetch_latest "$TMP/latest.json"
    tag=$(sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$TMP/latest.json" | head -n 1)
    version=${tag#v}
    [ -n "$tag" ] && [ "$tag" = "v$version" ] || die "the latest release has no usable tag: '$tag'"
    valid_version "$version" || die "the latest release's tag is not vX.Y.Z: $tag"
    case $version in *-rc.*) die "the latest release is a pre-release ($tag); set JHON_VERSION to install one" ;; esac
fi

asset="jhon-${version}-linux-${arch}.tar.gz"
base="${DOWNLOAD_URL}/v${version}"

say "downloading $asset (v$version)"
for f in "$asset" "$asset.sha256" "$asset.sigstore.json"; do
    fetch "$base/$f" "$TMP/$f" || die "cannot download $base/$f; nothing was installed"
done

read -r want named <"$TMP/$asset.sha256" || true
named=${named#\*}
[ "$named" = "$asset" ] || die "$asset.sha256 names '$named', not $asset; nothing was installed"
got=$(sha "$TMP/$asset")
[ "$want" = "$got" ] || die "checksum mismatch for $asset; nothing was installed"
say "sha256 verified"

if have cosign; then
    cosign verify-blob \
        --bundle "$TMP/$asset.sigstore.json" \
        --certificate-identity-regexp "$IDENTITY" \
        --certificate-oidc-issuer "$ISSUER" \
        "$TMP/$asset" >/dev/null 2>&1 ||
        die "the signature of $asset does not verify as Jhon's release workflow; nothing was installed"
    say "signature verified (cosign)"
else
    say "signature not checked: cosign is not installed (jhon update verifies signatures itself)"
fi

mkdir "$TMP/unpacked"
tar -xzf "$TMP/$asset" -C "$TMP/unpacked" build/jhon 2>/dev/null ||
    die "$asset holds no build/jhon; nothing was installed"
"$TMP/unpacked/build/jhon" release install "$TMP/$asset" || die "jhon release install failed"

bin="$HOME/.local/bin"
path_hint() {
    case ":$PATH:" in
        *":$bin:"*) ;;
        *)
            cat <<EOF

$bin is not on your PATH. Add it:
  bash/zsh: echo 'export PATH="\$HOME/.local/bin:\$PATH"' >> ~/.bashrc   (or ~/.zshrc)
  fish:     fish_add_path ~/.local/bin
EOF
            ;;
    esac
}
if [ -t 1 ] && [ -r /dev/tty ] && (: </dev/tty) 2>/dev/null; then
    path_hint
    "$bin/jhon" setup </dev/tty
    exit 0
fi
cat <<EOF

Next steps:
  jhon setup      choose runtimes and integrations
  jhon start      start Jhon
  jhon start pi   start Jhon with pi
EOF
path_hint
