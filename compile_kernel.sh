#!/bin/bash
set -e

if [ $# -lt 1 ]; then
    echo "usage: $0 path/to/kernel.metal"
    exit 1
fi

METAL_FILE="$1"
BASENAME=$(basename "$METAL_FILE" .metal)
DIRNAME=$(dirname "$METAL_FILE")
AIR_FILE="$DIRNAME/$BASENAME.air"
LIB_FILE="$DIRNAME/$BASENAME.metallib"

echo "compiling $METAL_FILE -> $AIR_FILE"
xcrun -sdk macosx metal -c "$METAL_FILE" -o "$AIR_FILE"

echo "linking $AIR_FILE -> $LIB_FILE"
xcrun -sdk macosx metallib "$AIR_FILE" -o "$LIB_FILE"

rm -f "$AIR_FILE"

echo "done: $LIB_FILE"
