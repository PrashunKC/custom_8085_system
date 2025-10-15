#!/usr/bin/env bash
set -euo pipefail

ASL=${ASL:-asl}
P2BIN=${P2BIN:-p2bin}
P2HEX=${P2HEX:-p2hex}
SRC=${1:-src/bios.asm}
BUILD=build
BASENAME=$(basename "$SRC" .asm)
OBJ="$BUILD/$BASENAME.p"
BIN="$BUILD/$BASENAME.bin"
HEX="$BUILD/$BASENAME.hex"
LST="$BUILD/$BASENAME.lst"

mkdir -p "$BUILD"

$ASL -L -i -o "$OBJ" "$SRC"
$P2BIN "$OBJ" "$BIN"
$P2HEX "$OBJ" "$HEX"

echo "Built: $BIN $HEX"
