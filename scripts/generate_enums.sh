#!/usr/bin/env bash
set -eu

. scripts/config.sh
echo "Generating enums and hashes..."
odin run source/tools/generate_enums -extra-linker-flags:"$SDL3_MIXER_LINKER_FLAGS" >/dev/null
