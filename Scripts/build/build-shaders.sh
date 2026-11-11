#!/bin/bash
# WHAT: Compile the app's own Metal: Shaders/Watercolour.metal (the wash) into the metallib SwiftUI loads with
#       ShaderLibrary(url:), and record the source's SHA-256 beside it.
# OUT:  Sources/CraftedApp/Resources/Watercolour.metallib, Sources/CraftedApp/Resources/Watercolour.metallib.sha256.
#       Both are committed: `swift build` has no Metal step, and a checkout must run without this script.
# PIN:  CPU ONLY. `xcrun metal` and `metallib` compile; nothing here loads a device or draws.
# PIN:  --check compares the recorded hash with the source and fails when they differ, for CI and release: a shader
#       edited without a rebuild ships the old wash silently otherwise.
# PIN:  Not MLX's metallib: Scripts/build/build-metallib.sh installs Frigate's mlx.metallib. This is the app's own.
#
#   ./Scripts/build/build-shaders.sh            compile, write the metallib and the hash
#   ./Scripts/build/build-shaders.sh --check    exit 1 if the metallib is older than the source
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$ROOT/Shaders/Watercolour.metal"
OUT="$ROOT/Sources/CraftedApp/Resources/Watercolour.metallib"
HASH="$OUT.sha256"
WORK="$ROOT/build/shaders"

[[ -f "$SRC" ]] || { echo "build-shaders: no $SRC" >&2; exit 1; }
digest="$(shasum -a 256 "$SRC" | awk '{print $1}')"

if [[ "${1:-}" == "--check" ]]; then
    recorded="$(awk '{print $1}' "$HASH" 2>/dev/null || true)"
    if [[ -f "$OUT" && "$recorded" == "$digest" ]]; then
        echo "build-shaders: Watercolour.metallib matches Shaders/Watercolour.metal ($digest)"
        exit 0
    fi
    echo "build-shaders: Watercolour.metallib is stale; run Scripts/build/build-shaders.sh" >&2
    exit 1
fi

mkdir -p "$WORK"
# The package's floor (Package.swift: .macOS("27.0")), not the SDK's version, or an older 27.x refuses the library.
xcrun -sdk macosx metal -c "$SRC" -o "$WORK/Watercolour.air" -mmacosx-version-min=27.0 -Wall -Werror
xcrun -sdk macosx metallib "$WORK/Watercolour.air" -o "$OUT"
echo "$digest  Shaders/Watercolour.metal" > "$HASH"
echo "build-shaders: wrote ${OUT#"$ROOT"/} ($(wc -c < "$OUT" | tr -d ' ') bytes), source $digest"
