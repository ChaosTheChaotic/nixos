#!/usr/bin/env nix-shell
#!nix-shell -i bash -p git meson ninja cargo rust-bindgen clang "python3.withPackages (ps: with ps; [ pyyaml mutagen ])" pkg-config intltool unzip rustc "rustPlatform.bindgenHook" udev dbus pipewire sdl3 enet pcre2 wayland libunibreak libvorbis libxml2 luajit openal openblas physfs suitesparse libyaml cmark opus dav1d libgit2 libzip freetype glpk libpng

set -euo pipefail

NAEV_VERSION="0.13.5"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
TMP_DIR=$(mktemp -d)

echo "=> Fetching naev v${NAEV_VERSION}..."
git clone --recurse-submodules="assets" --depth 1 --branch "v${NAEV_VERSION}" https://codeberg.org/naev/naev.git "$TMP_DIR/naev"

pushd "$TMP_DIR/naev" >/dev/null

echo "=> Fetching assets..."
cd assets
git lfs fetch
git lfs checkout
cd ..

echo "=> Configuring and patching..."
find . -type f -name "*.sh" -exec chmod +x {} +
find . -type f -name "*.py" -exec chmod +x {} +
nix-shell -p stdenv --run "patchShebangs ."

echo "=> Running meson to generate Cargo.toml..."
# We only need to configure, not build, to generate the files
meson setup build .

echo "=> Generating workspace dependencies..."
ninja -C build colours.gen.h shaders.gen.h naevc || true

echo "=> Generating Cargo.lock..."
cd build
cargo generate-lockfile

popd >/dev/null

echo "=> Copying Cargo.lock to ${SCRIPT_DIR}..."
cp "$TMP_DIR/naev/build/Cargo.lock" "$SCRIPT_DIR/Cargo.lock"

echo "=> Cleaning up..."
rm -rf "$TMP_DIR"

echo "=> Done! Cargo.lock is ready to be used by Nix."
