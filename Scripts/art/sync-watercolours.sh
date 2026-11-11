#!/bin/bash
# WHAT: Copy the Lyon watercolours from the site (craft.rao.nyc) into the app's resources, under stable names:
#       per scene its far (opaque), fog and near (transparent) layers; the three pigment blooms; the Rao seal.
# IN:   $SITE, the site's checkout (default ~/Documents/repositories/craft.rao.nyc). Its public/home/ names every
#       file <name>.<hash>.webp; app/(home)/_lib/home-art.ts is the manifest that says which hash is current.
# OUT:  Sources/CraftedApp/Resources/Watercolour/{gardens,fourviere,lyon}-{far,fog,near}.webp,
#       Sources/CraftedApp/Resources/Watercolour/bloom-{sky,brass,clay}.webp,
#       Sources/CraftedApp/Resources/seal.png,
#       Sources/CraftedApp/Resources/Watercolour/SOURCE.txt (the site's commit, and each file's source).
# PIN:  The manifest is read for the hashed names, not a glob: the site keeps an old hash on disk for a while after
#       a repaint, and a glob would pick either. A name the manifest does not give fails the sync.
#
#   ./Scripts/art/sync-watercolours.sh [site checkout]
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SITE="${1:-${SITE:-$HOME/Documents/repositories/craft.rao.nyc}}"
MANIFEST="$SITE/app/(home)/_lib/home-art.ts"
OUT="$ROOT/Sources/CraftedApp/Resources/Watercolour"
SCENES=(gardens fourviere lyon)
BLOOMS=(sky brass clay)

[[ -f "$MANIFEST" ]] || { echo "sync-watercolours: no manifest at $MANIFEST" >&2; exit 1; }
mkdir -p "$OUT"

# The site path the manifest gives for a key such as "gardens-far" or "bloom-sky": the first /home/<key>.<hash>.webp.
source_of() {
    local key="$1"
    local path
    path="$(grep -oE "/home/${key}\.[0-9a-f]+\.webp" "$MANIFEST" | head -n 1)"
    [[ -n "$path" ]] || { echo "sync-watercolours: the manifest names no $key" >&2; exit 1; }
    echo "$SITE/public$path"
}

commit="$(git -C "$SITE" rev-parse HEAD 2>/dev/null || echo unknown)"
dirty="$(git -C "$SITE" status --porcelain -- public/home public/rao 2>/dev/null | head -n 1)"
{
    echo "Copied from craft.rao.nyc by Scripts/art/sync-watercolours.sh. Do not edit these files by hand."
    echo "site commit: $commit${dirty:+ (with uncommitted changes under public/)}"
    echo "synced: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo
} > "$OUT/SOURCE.txt"

copy() {
    local from="$1" to="$2"
    [[ -f "$from" ]] || { echo "sync-watercolours: missing $from" >&2; exit 1; }
    cp "$from" "$to"
    echo "${to#"$ROOT"/}  <-  ${from#"$SITE"/}" | tee -a "$OUT/SOURCE.txt"
}

for scene in "${SCENES[@]}"; do
    for layer in far fog near; do
        copy "$(source_of "$scene-$layer")" "$OUT/$scene-$layer.webp"
    done
done
for tone in "${BLOOMS[@]}"; do
    copy "$(source_of "bloom-$tone")" "$OUT/bloom-$tone.webp"
done
copy "$SITE/public/rao/seal-512.png" "$ROOT/Sources/CraftedApp/Resources/seal.png"

echo "sync-watercolours: site $commit"
