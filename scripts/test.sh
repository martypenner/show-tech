#!/usr/bin/env bash
set -eu

. scripts/config.sh

odin test source \
	-all-packages \
	-define:ODIN_TEST_THREADS=1 \
	-strict-style -vet \
	-extra-linker-flags:"$SDL3_MIXER_LINKER_FLAGS"
