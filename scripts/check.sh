#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

python3 -c 'import pathlib, xml.etree.ElementTree as ET; root=pathlib.Path("'"$ROOT_DIR"'"); [ET.parse(p) for p in root.glob("CivVITrainer/**/*.xml")]; ET.parse(root / "CivVITrainer/CivVITrainer.modinfo"); print("XML and modinfo parse successfully")'

for required in CivVITrainer.modinfo UI/CivVITrainer.xml UI/CivVITrainer.lua UI/CivVITrainer_State.lua UI/CivVITrainer_Evaluator.lua; do
  test -f "$ROOT_DIR/CivVITrainer/$required"
done

test -f "$ROOT_DIR/Install-CivVITrainer.ps1"
test -f "$ROOT_DIR/install-windows.cmd"

echo "Required mod files are present"
