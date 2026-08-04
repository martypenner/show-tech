#!/usr/bin/env bash
set -eu

. scripts/config.sh
kill "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null || true
rm -f "$PIDFILE"
rm -rf build
