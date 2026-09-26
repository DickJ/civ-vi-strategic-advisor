#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT INT TERM

PACKAGE_DIR="$TEMP_DIR/CivVI-Strategic-Advisor-Windows"
mkdir -p "$PACKAGE_DIR"
cp -R "$ROOT_DIR/CivVITrainer" "$PACKAGE_DIR/CivVITrainer"
cp "$ROOT_DIR/Install-CivVITrainer.ps1" "$PACKAGE_DIR/Install-CivVITrainer.ps1"
cp "$ROOT_DIR/install-windows.cmd" "$PACKAGE_DIR/install-windows.cmd"
cp "$ROOT_DIR/README.md" "$PACKAGE_DIR/README.md"

cd "$TEMP_DIR"
/usr/bin/zip -q -r -X "CivVI-Strategic-Advisor-Windows.zip" "CivVI-Strategic-Advisor-Windows"
mkdir -p "$ROOT_DIR/dist"
cp "CivVI-Strategic-Advisor-Windows.zip" "$ROOT_DIR/dist/CivVI-Strategic-Advisor-Windows.zip"

echo "Created: $ROOT_DIR/dist/CivVI-Strategic-Advisor-Windows.zip"

