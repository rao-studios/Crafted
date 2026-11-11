#!/bin/bash
# WHAT: Build + metallib + stable-sign + run the Mac app (the bare binary, with Support/Info.plist embedded).
#
#   ./Scripts/dev/dev.sh
#   CONFIG=release ./Scripts/dev/dev.sh
#   CRAFTED_MODELS=scripted CRAFTED_HOME="$(mktemp -d)" ./Scripts/dev/dev.sh      # no model loads: the fixtures' scripts
#   CRAFTED_SELFTEST=Fixtures/projects/py-unit-converter CRAFTED_MODELS=scripted CRAFTED_HOME="$(mktemp -d)" ./Scripts/dev/dev.sh
#
# PIN:  THE WORKING DIRECTORY IS THE REPOSITORY. ScriptedModel finds Fixtures/scripts and the forge finds Templates/
#       upward from it (or from the binary), so the dev binary runs from here.
set -e

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CONFIG="${CONFIG:-debug}"
cd "$REPO_ROOT"

# PIN: BUILD SYSTEM. SwiftPM's default (`swiftbuild`) compiles Frigate's vendored .metal
#      sources, through Xcode's `metal` stub — which on this machine reports "missing
#      Metal Toolchain" even though `xcrun metal` compiles fine, so every build fails.
#      `native` has no Metal step at all; build-metallib.sh compiles the shaders with
#      xcrun and installs them. Flip back with CRAFTED_BUILD_SYSTEM=swiftbuild once the
#      toolchain is fixed (then `swift test` also regains one .xctest per target).
BUILD_SYSTEM="${CRAFTED_BUILD_SYSTEM:-native}"

source "$REPO_ROOT/Scripts/build/lib-metal.sh"
refresh_metal_toolchain "$REPO_ROOT"
echo "▸ swift build ($CONFIG)"
swift build --build-system "$BUILD_SYSTEM" -c "$CONFIG" --product CraftedApp

"$REPO_ROOT/Scripts/build/build-metallib.sh" "$CONFIG"

BIN="$REPO_ROOT/.build/$CONFIG/CraftedApp"
"$REPO_ROOT/Scripts/build/sign-binary.sh" "$BIN"

exec "$BIN" "$@"
