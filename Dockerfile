# syntax=docker/dockerfile:1

FROM crazymax/osxcross:15.5-debian@sha256:c38b73a6ec52f913c354c3931a472a8645337ca3545ad719af112a9c03b7df8a AS osxcross

FROM debian:trixie-slim@sha256:020c0d20b9880058cbe785a9db107156c3c75c2ac944a6aa7ab59f2add76a7bd

ARG ODIN_VERSION=dev-2026-07a

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
	&& apt-get install -y --no-install-recommends bzip2 ca-certificates clang curl file libarchive-tools libc6-dev lld make openssl xz-utils \
	&& rm -rf /var/lib/apt/lists/*

COPY --from=osxcross /osxcross /osxcross
ENV PATH="/odin:/osxcross/bin:${PATH}" \
	LD_LIBRARY_PATH="/osxcross/lib" \
	MACOSX_DEPLOYMENT_TARGET="15.0"

RUN mkdir /odin \
	&& curl -fsSL "https://github.com/odin-lang/Odin/releases/download/${ODIN_VERSION}/odin-linux-amd64-${ODIN_VERSION}.tar.gz" \
	| tar -xz --strip-components=1 -C /odin

RUN UNATTENDED=1 OSXCROSS_MACPORTS_MIRROR=https://packages.macports.org omp install SDL3_mixer \
	&& ln -s /osxcross/macports/pkgs/opt/local /opt/macos

WORKDIR /workdir
