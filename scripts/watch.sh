#!/usr/bin/env bash
set -eu

# Hot-reload watcher. Monitors source/ continuously and rebuilds the game DLL
# on changes. Assets and settings.sjson are read from disk at runtime, so they
# don't trigger rebuilds. Uses inotifywait on Linux, fswatch on macOS.

. scripts/config.sh

stop_game() {
	kill "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null || true
	rm -f "$PIDFILE"
}

shutdown() {
	echo "Stopped game and watch."
	stop_game
	kill "${WATCH_PID:-}" 2>/dev/null || true
	exit 0
}

trap shutdown INT TERM

./scripts/build_hot_reload.sh run

if command -v inotifywait >/dev/null 2>&1; then
	echo "Watching source/ for changes (inotify)..."
	inotifywait -mqr -e modify,create,delete,move ./source |
		while IFS= read -r event; do
			while IFS= read -rt 0.2 next_event; do :; done
			./scripts/build_hot_reload.sh
		done &
elif command -v fswatch >/dev/null 2>&1; then
	echo "Watching source/ for changes (fswatch)..."
	fswatch -0r ./source |
		while IFS= read -r -d '' path; do
			while IFS= read -rt 0.2 -d '' next_path; do :; done
			./scripts/build_hot_reload.sh
		done &
else
	echo "Error: need inotifywait (inotify-tools) or fswatch to watch for changes." >&2
	stop_game
	exit 1
fi
WATCH_PID=$!

while kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; do
	sleep 1
done

echo "Game window closed, stopping watch."
kill "$WATCH_PID" 2>/dev/null || true
stop_game
