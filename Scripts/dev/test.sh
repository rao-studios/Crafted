#!/bin/bash
# WHAT: Build the tests, install mlx.metallib beside every test bundle, run them. No test loads a model.
# PIN:  MLX-touching tests run out of .xctest bundles, each of which needs its own mlx.metallib beside its executable;
#       `swift test` alone would abort on the first GPU op. Live-model tests stay gated behind CRAFTED_MLX_LIVE=1
#       (the follow-up).
# PIN:  A TEMPORARY HOME. Generations, the cache and the shelf go to a fresh CRAFTED_HOME; the preferences to a store
#       of the suite's own, never the person's.
#
#   ./Scripts/dev/test.sh                            # everything
#   ./Scripts/dev/test.sh --filter CraftedCoreTests
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

BUILD_SYSTEM="${CRAFTED_BUILD_SYSTEM:-native}"

export CRAFTED_HOME="${CRAFTED_HOME:-$(mktemp -d)}"
export CRAFTED_PREFERENCES_KEY="${CRAFTED_PREFERENCES_KEY:-crafted.persistence.preferences.test}"
export CRAFTED_MODELS="${CRAFTED_MODELS:-scripted}"

source "$REPO_ROOT/Scripts/build/lib-metal.sh"
refresh_metal_toolchain "$REPO_ROOT"
echo "▸ swift build --build-tests ($BUILD_SYSTEM)"
swift build --build-system "$BUILD_SYSTEM" --build-tests
"$REPO_ROOT/Scripts/build/build-metallib.sh" debug
echo "▸ swift test $*"
exec swift test --build-system "$BUILD_SYSTEM" --skip-build "$@"
