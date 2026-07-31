#!/usr/bin/env bash
set -eu

# This creates a build that is similar to a release build, but it is debuggable.
# There is no hot reloading and no separate game library.

OUT_DIR="build/debug"
HOMEBREW_PREFIX="$(brew --prefix)"
SDL3_MIXER_PREFIX="$(brew --prefix sdl3_mixer)"
SDL3_MIXER_LINKER_FLAGS="-L$SDL3_MIXER_PREFIX/lib -L$HOMEBREW_PREFIX/lib -Wl,-rpath,$SDL3_MIXER_PREFIX/lib -Wl,-rpath,$HOMEBREW_PREFIX/lib"
mkdir -p "$OUT_DIR"
odin build source/main_release -out:$OUT_DIR/game_debug.bin -strict-style -vet -debug \
	-extra-linker-flags:"$SDL3_MIXER_LINKER_FLAGS"
cp -R assets $OUT_DIR
echo "Debug build created in $OUT_DIR"
