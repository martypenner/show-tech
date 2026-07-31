#!/usr/bin/env bash
set -eu

# This script creates an optimized release build.

OUT_DIR="build/release"
HOMEBREW_PREFIX="$(brew --prefix)"
SDL3_MIXER_PREFIX="$(brew --prefix sdl3_mixer)"
SDL3_MIXER_LINKER_FLAGS="-L$SDL3_MIXER_PREFIX/lib -L$HOMEBREW_PREFIX/lib -Wl,-rpath,$SDL3_MIXER_PREFIX/lib -Wl,-rpath,$HOMEBREW_PREFIX/lib"
mkdir -p "$OUT_DIR"
# Use -microarch:x86-64 for running on old laptops
odin build source/main_release -out:$OUT_DIR/showtime -strict-style -vet -no-bounds-check -o:speed \
	-extra-linker-flags:"$SDL3_MIXER_LINKER_FLAGS"
ln -s "$(pwd)/assets" $OUT_DIR
ln -s "$(pwd)/settings.sjson" $OUT_DIR
echo "Release build created in $OUT_DIR"
