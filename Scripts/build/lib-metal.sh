#!/bin/bash
# WHAT: Drop cached build descriptions that name a Metal toolchain mount other than the
#       current one, before `swift build`.
# PIN:  The Metal toolchain is a cryptex whose mount suffix
#       (…MetalToolchain-v27.1.266.1.<suffix>) changes on its own. Swift Build caches the
#       old path in .build/out/Intermediates.noindex/XCBuildData/<hash>.xcbuilddata and
#       fails with "unable to spawn process …/metal" until that description is
#       regenerated. Only the stale descriptions go, so nothing recompiles beyond a replan.
#       The native build system keeps no such cache; there this does nothing.
#
#   source Scripts/build/lib-metal.sh; refresh_metal_toolchain "$REPO_ROOT"

refresh_metal_toolchain() {
    local root="$1" metal current dir mounts
    metal="$(xcrun --find metal 2>/dev/null)" || return 0
    [[ "$metal" =~ (com\.apple\.MobileAsset\.MetalToolchain-v[^/]+) ]] || return 0
    current="${BASH_REMATCH[1]}"
    [ -d "$root/.build" ] || return 0
    while IFS= read -r dir; do
        [ -f "$dir/manifest.json" ] || continue
        mounts="$(grep -oE 'com\.apple\.MobileAsset\.MetalToolchain-v[^/"]+' "$dir/manifest.json" | sort -u || true)"
        if [ -n "$mounts" ] && grep -qvxF "$current" <<<"$mounts"; then
            echo "▸ Metal toolchain moved to ${current##*.}: dropping $(basename "$dir")" >&2
            rm -rf "$dir"
        fi
    done < <(find "$root/.build" -maxdepth 5 -type d -name '*.xcbuilddata' -path '*/XCBuildData/*' 2>/dev/null)
}
