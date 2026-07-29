#!/usr/bin/env bash
set -eu

odin test source \
	-all-packages \
	-define:ODIN_TEST_THREADS=1 \
	-strict-style -vet
