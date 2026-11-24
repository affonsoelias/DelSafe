#!/usr/bin/env bash
set -euo pipefail

VERSION=""
OUT_DIR="dist"
SKIP_BUILD=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version=*) VERSION="${1#*=}" ;;
    --out-dir=*) OUT_DIR="${1#*=}" ;;
    --skip-build) SKIP_BUILD=1 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

if [[ -z "$VERSION" ]]; then
  VERSION="$(sed -n "s/.*AETHER_COMPILER_VERSION = '\([^']*\)'.*/\1/p" compiler/src/uAetherIncremental.pas | head -n 1)"
  VERSION="${VERSION:-0.5.0}"
fi

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  mkdir -p bin build
  fpc -MObjFPC -Sc -O2 -FEbin -FUbuild -Fucompiler/src compiler/aetherc.lpr
fi

if [[ ! -f "bin/aetherc" ]]; then
  echo "Error: bin/aetherc not found" >&2
  exit 1
fi

UNAME_S="$(uname -s)"
case "$UNAME_S" in
  Darwin*) OS_NAME="macos" ;;
  Linux*)  OS_NAME="linux" ;;
  *)       OS_NAME="$(echo "$UNAME_S" | tr '[:upper:]' '[:lower:]')" ;;
esac

UNAME_M="$(uname -m)"
case "$UNAME_M" in
  x86_64|amd64) ARCH_NAME="x86_64" ;;
  arm64|aarch64) ARCH_NAME="aarch64" ;;
  *) ARCH_NAME="$UNAME_M" ;;
esac

mkdir -p "$OUT_DIR"
ASSET_BASE="aether-v${VERSION}-${OS_NAME}-${ARCH_NAME}"
STAGE_DIR="$OUT_DIR/_stage_${ASSET_BASE}"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/bin" "$STAGE_DIR/std"

cp "bin/aetherc" "$STAGE_DIR/bin/aetherc"
chmod +x "$STAGE_DIR/bin/aetherc"
cp std/*.aeth "$STAGE_DIR/std/"
[[ -f README.md ]] && cp README.md "$STAGE_DIR/"
[[ -f LICENSE ]] && cp LICENSE "$STAGE_DIR/"

ARCHIVE_NAME="${ASSET_BASE}.tar.gz"
ARCHIVE_PATH="${OUT_DIR}/${ARCHIVE_NAME}"
tar -czf "$ARCHIVE_PATH" -C "$STAGE_DIR" .
rm -rf "$STAGE_DIR"

if command -v sha256sum >/dev/null 2>&1; then
  HASH="$(sha256sum "$ARCHIVE_PATH" | awk '{print $1}')"
else
  HASH="$(shasum -a 256 "$ARCHIVE_PATH" | awk '{print $1}')"
fi

echo "${HASH}  ${ARCHIVE_NAME}" > "${ARCHIVE_PATH}.sha256"
echo "${HASH}  ${ARCHIVE_NAME}" > "${OUT_DIR}/SHA256SUMS.txt"
echo "[OK] Packaged ${ARCHIVE_PATH} (SHA-256: ${HASH})"
