#!/usr/bin/env bash
set -eu

OUT_DIR="build/macos"

mkdir -p "$OUT_DIR"

if [[ "$(uname -s)" == "Darwin" ]]; then
	# Native build: brew SDL3/SDL3_mixer, dynamic link, rpath to brew libs.
	# No dylib bundling needed when building on the machine that runs it.
	. scripts/config.sh
	odin build source/main_release \
		-target:darwin_amd64 \
		-minimum-os-version:15.0 \
		-strict-style \
		-vet \
		-no-bounds-check \
		-o:speed \
		-out:"$OUT_DIR/showtime" \
		-extra-linker-flags:"$SDL3_MIXER_LINKER_FLAGS"
else
	# Cross-compile from Linux (docker image, macports SDL3_mixer at /opt/macos).
	SDL_PREFIX="/opt/macos"
	SDL_LINKER_FLAGS=("-L${SDL_PREFIX}/lib" "-Wl,-rpath,@executable_path")

	odin build source/main_release \
		-build-mode:obj \
		-target:darwin_amd64 \
		-minimum-os-version:15.0 \
		-out:"$OUT_DIR/showtime.obj" \
		-strict-style \
		-vet \
		-no-bounds-check \
		-o:speed

	o64-clang++ \
		"$OUT_DIR/showtime.obj" \
		vendor/odin-imgui/imgui_darwin_x64.a \
		"${SDL_LINKER_FLAGS[@]}" \
		-lSDL3_mixer \
		-lSDL3 \
		-mmacosx-version-min=15.0 \
		-o "$OUT_DIR/showtime"
	rm "$OUT_DIR/showtime.obj"

	binaries=("$OUT_DIR/showtime")
	for ((binary_index = 0; binary_index < ${#binaries[@]}; binary_index += 1)); do
		binary="${binaries[$binary_index]}"
		while read -r dependency _; do
			case "$dependency" in
			/opt/local/*)
				dependency_name="${dependency##*/}"
				dependency_target="$OUT_DIR/$dependency_name"
				if [[ ! -e "$dependency_target" ]]; then
					cp -L "$SDL_PREFIX/${dependency#/opt/local/}" "$dependency_target"
					architectures="$(x86_64-apple-darwin24.5-lipo -archs "$dependency_target")"
					if [[ "$architectures" == *" "* ]]; then
						x86_64-apple-darwin24.5-lipo "$dependency_target" \
							-thin x86_64 -output "$dependency_target.thin"
						mv "$dependency_target.thin" "$dependency_target"
					fi
					binaries+=("$dependency_target")
				fi
				x86_64-apple-darwin24.5-install_name_tool \
					-change "$dependency" "@rpath/$dependency_name" "$binary"
				;;
			esac
		done < <(x86_64-apple-darwin24.5-otool -L "$binary")
		if [[ "$binary" == *.dylib ]]; then
			x86_64-apple-darwin24.5-install_name_tool -id "@rpath/${binary##*/}" "$binary"
		fi
	done

fi
# Assets are huge, so link instead of copying (Windows .bat copies instead).
# Relative links so the build/macos folder works when copied to a Mac.
rm -f "$OUT_DIR/assets" "$OUT_DIR/settings.sjson"
ln -s ../../assets "$OUT_DIR/assets"
ln -s ../../settings.sjson "$OUT_DIR/settings.sjson"
echo "macOS release build created in $OUT_DIR"
