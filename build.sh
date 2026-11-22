#!/usr/bin/env bash
set -e

echo "========================================================"
echo "  AetherLang Compiler (aetherc) - Linux/macOS Build"
echo "========================================================"

if ! command -v fpc &> /dev/null; then
    echo "[ERROR] Free Pascal Compiler (fpc) was not found in your PATH."
    echo "Please install Free Pascal (e.g. 'sudo apt install fpc' on Ubuntu/Debian, or via brew on macOS)."
    exit 1
fi

mkdir -p bin build

echo "[*] Compiling aetherc with optimizations (-O2)..."
fpc -MObjFPC -Sc -O2 -FEbin -FUbuild -Fucompiler/src compiler/aetherc.lpr

echo ""
echo "[SUCCESS] Native compiler generated at: bin/aetherc"
echo ""

echo "[*] Running diagnostic check..."
./bin/aetherc --version
./bin/aetherc test

echo ""
echo "========================================================"
echo "  Build complete! Run './bin/aetherc' to get started."
echo "========================================================"
