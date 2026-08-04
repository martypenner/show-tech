#!/usr/bin/env bash
set -eu

# This creates a build that is similar to a release build, but it is debuggable.
# There is no hot reloading and no separate game library.

OUT_DIR="build/debug"
mkdir -p "$OUT_DIR"
. scripts/config.sh
odin build source/main_release -out:$OUT_DIR/game_debug.bin -strict-style -vet -debug \
	-extra-linker-flags:"$SDL3_MIXER_LINKER_FLAGS"
# Assets are huge, so link instead of copying (Windows .bat copies instead).
rm -f "$OUT_DIR/assets" "$OUT_DIR/settings.sjson"
ln -s ../../assets "$OUT_DIR/assets"
ln -s ../../settings.sjson "$OUT_DIR/settings.sjson"
echo "Debug build created in $OUT_DIR"
