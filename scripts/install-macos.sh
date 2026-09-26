#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SOURCE_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../CivVITrainer" && pwd)
MODS_DIR="$HOME/Library/Application Support/Sid Meier's Civilization VI/Mods"
DESTINATION="$MODS_DIR/CivVITrainer"

mkdir -p "$MODS_DIR"
mkdir -p "$DESTINATION/UI"
cp "$SOURCE_DIR/CivVITrainer.modinfo" "$DESTINATION/CivVITrainer.modinfo"
cp "$SOURCE_DIR"/UI/* "$DESTINATION/UI/"

echo "Installed Civ VI Strategic Advisor at:"
echo "$DESTINATION"

