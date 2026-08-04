#!/usr/bin/env bash
set -eu

# This script creates an optimized release build.

OUT_DIR="build/release"
mkdir -p "$OUT_DIR"
# Use -microarch:x86-64 for running on old laptops
odin build source/main_release -out:$OUT_DIR/showtime -strict-style -vet -no-bounds-check -o:speed
# Assets are huge, so link instead of copying (Windows .bat copies instead).
rm -f $OUT_DIR/assets $OUT_DIR/settings.sjson
ln -s ../../assets $OUT_DIR/assets
ln -s ../../settings.sjson $OUT_DIR/settings.sjson
echo "Release build created in $OUT_DIR"
