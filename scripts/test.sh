#!/usr/bin/env bash
set -eu

HOMEBREW_PREFIX="$(brew --prefix)"
SDL3_MIXER_PREFIX="$(brew --prefix sdl3_mixer)"
SDL3_MIXER_LINKER_FLAGS="-L$SDL3_MIXER_PREFIX/lib -L$HOMEBREW_PREFIX/lib -Wl,-rpath,$SDL3_MIXER_PREFIX/lib -Wl,-rpath,$HOMEBREW_PREFIX/lib"

odin test source \
	-all-packages \
	-define:ODIN_TEST_THREADS=1 \
	-strict-style -vet \
	-extra-linker-flags:"$SDL3_MIXER_LINKER_FLAGS"
