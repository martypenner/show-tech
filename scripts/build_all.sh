#!/usr/bin/env bash
set -eu

# Builds the Linux release and the macOS release (via the osxcross docker
# image) in parallel. Builds the docker image first if needed.

echo "Building docker image..."
docker build . -t showtime-macos-crossbuild

mkdir -p build
./scripts/build_release.sh >build/linux.log 2>&1 &
linux_pid=$!

macos_status=0
docker run --rm -u "$(id -u):$(id -g)" -v "$(pwd):/workdir" \
	showtime-macos-crossbuild ./scripts/build_macos.sh >build/macos.log 2>&1 || macos_status=$?

linux_status=0
wait "$linux_pid" || linux_status=$?

if [ "$linux_status" -ne 0 ]; then
	echo "Linux build failed:"
	cat build/linux.log
fi
if [ "$macos_status" -ne 0 ]; then
	echo "macOS build failed:"
	cat build/macos.log
fi
exit $((linux_status || macos_status))
