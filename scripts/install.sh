#!/usr/bin/env bash
set -euo pipefail

REPO="${AETHER_UPGRADE_REPO:-affonsoelias/aether}"
INSTALL_ROOT="${AETHER_HOME:-$HOME/.aether}"
VERSION=""
NIGHTLY=0
ALLOW_UNSIGNED=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version=*) VERSION="${1#*=}" ;;
    --nightly) NIGHTLY=1 ;;
    --allow-unsigned) ALLOW_UNSIGNED=1 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

UNAME_S="$(uname -s)"
case "$UNAME_S" in
  Darwin*) OS_NAME="macos" ;;
  Linux*)  OS_NAME="linux" ;;
  *)       echo "Unsupported OS: $UNAME_S" >&2; exit 1 ;;
esac

UNAME_M="$(uname -m)"
case "$UNAME_M" in
  x86_64|amd64) ARCH_NAME="x86_64" ;;
  arm64|aarch64) ARCH_NAME="aarch64" ;;
  *) echo "Unsupported architecture: $UNAME_M" >&2; exit 1 ;;
esac

if [[ -n "$VERSION" ]]; then
  API_URL="https://api.github.com/repos/${REPO}/releases/tags/${VERSION}"
elif [[ "$NIGHTLY" -eq 1 ]]; then
  API_URL="https://api.github.com/repos/${REPO}/releases?per_page=10"
else
  API_URL="https://api.github.com/repos/${REPO}/releases/latest"
fi

echo "[1/4] Fetching release metadata (${OS_NAME}-${ARCH_NAME})..."
META_JSON="$(curl -fsSL -H 'User-Agent: Aether-Installer' -H 'Accept: application/vnd.github.v3+json' "$API_URL")"

ASSET_URL="$(printf '%s' "$META_JSON" | grep -oE '"browser_download_url"\s*:\s*"[^"]*"' | cut -d'"' -f4 | grep -E "${OS_NAME}.*(${ARCH_NAME}|amd64|arm64)" | grep -vE '\.(sha256|sig|asc)$' | head -n 1)"
if [[ -z "$ASSET_URL" ]]; then
  echo "Error: No compatible asset found for ${OS_NAME}-${ARCH_NAME}." >&2
  exit 1
fi
ASSET_NAME="$(basename "$ASSET_URL")"
SUM_URL="$(printf '%s' "$META_JSON" | grep -oE '"browser_download_url"\s*:\s*"[^"]*"' | cut -d'"' -f4 | grep -E "${ASSET_NAME}\.sha256|SHA256SUMS\.txt" | head -n 1 || true)"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "[2/4] Downloading ${ASSET_NAME}..."
curl -fsSL -H 'User-Agent: Aether-Installer' -o "$TMP_DIR/$ASSET_NAME" "$ASSET_URL"

if command -v sha256sum >/dev/null 2>&1; then
  CALC_HASH="$(sha256sum "$TMP_DIR/$ASSET_NAME" | awk '{print $1}')"
else
  CALC_HASH="$(shasum -a 256 "$TMP_DIR/$ASSET_NAME" | awk '{print $1}')"
fi

if [[ -n "$SUM_URL" ]]; then
  SUM_CONTENT="$(curl -fsSL "$SUM_URL")"
  if ! echo "$SUM_CONTENT" | tr '[:upper:]' '[:lower:]' | grep -q "$CALC_HASH"; then
    echo "Security Error: SHA-256 verification failed for ${ASSET_NAME}!" >&2
    exit 1
  fi
  echo "      [OK] SHA-256 verified: ${CALC_HASH}"
elif [[ "$ALLOW_UNSIGNED" -eq 0 ]]; then
  echo "Security Error: No checksum asset found. Pass --allow-unsigned to override." >&2
  exit 1
fi

echo "[3/4] Extracting into ${INSTALL_ROOT}..."
mkdir -p "$TMP_DIR/extracted" "$INSTALL_ROOT/bin" "$INSTALL_ROOT/std"
tar -xzf "$TMP_DIR/$ASSET_NAME" -C "$TMP_DIR/extracted"
EXE_SRC="$(find "$TMP_DIR/extracted" -type f -name aetherc | head -n 1)"
if [[ -z "$EXE_SRC" ]]; then
  echo "Error: aetherc binary missing from archive." >&2
  exit 1
fi
cp "$EXE_SRC" "$INSTALL_ROOT/bin/aetherc"
chmod +x "$INSTALL_ROOT/bin/aetherc"

STD_SRC="$(find "$TMP_DIR/extracted" -type d -name std | head -n 1 || true)"
if [[ -n "$STD_SRC" ]]; then
  rm -rf "$INSTALL_ROOT/std"
  cp -R "$STD_SRC" "$INSTALL_ROOT/std"
fi

echo "[4/4] Installed!"
"$INSTALL_ROOT/bin/aetherc" --version
echo "Add to PATH: export PATH=\"$INSTALL_ROOT/bin:\$PATH\""
