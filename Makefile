.PHONY: all build build-web generate-enums run test format clean

PIDFILE=build/hot_reload/game.pid
HOMEBREW_PREFIX=$(shell brew --prefix)
SDL3_MIXER_PREFIX=$(shell brew --prefix sdl3_mixer)
SDL3_MIXER_LINKER_FLAGS=-L$(SDL3_MIXER_PREFIX)/lib -L$(HOMEBREW_PREFIX)/lib -Wl,-rpath,$(SDL3_MIXER_PREFIX)/lib -Wl,-rpath,$(HOMEBREW_PREFIX)/lib

all: build

build: clean
	./scripts/build_release.sh

build-web:
	./scripts/build_web.sh

generate-enums:
	@echo "Generating enums and hashes..."
	@odin run source/tools/generate_enums -extra-linker-flags:"$(SDL3_MIXER_LINKER_FLAGS)" >/dev/null

run: clean
	@./scripts/build_hot_reload.sh run
	@echo "Watching for changes (Ctrl-C or exit the game window to stop)..."
	@trap 'kill $$(cat $(PIDFILE) 2>/dev/null) 2>/dev/null; rm -f $(PIDFILE); echo; echo "Stopped game and watch."; exit 0' INT TERM; \
	while kill -0 $$(cat $(PIDFILE) 2>/dev/null) 2>/dev/null; do \
		if inotifywait -qr -t 1 -e modify,create,delete,move ./source ./assets >/dev/null 2>&1; then \
			./scripts/build_hot_reload.sh; \
		fi; \
	done; \
	echo "Game window closed, stopping watch."; \
	rm -f $(PIDFILE)

test:
	./scripts/test.sh

format:
	@odinfmt -w source >/dev/null

clean:
	@-kill $$(cat $(PIDFILE) 2>/dev/null) 2>/dev/null; rm -f $(PIDFILE)
	@rm -rf build
