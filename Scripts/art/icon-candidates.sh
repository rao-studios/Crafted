#!/bin/bash
# WHAT: Render every candidate glyph in Design/glyphs/ as the full icon, in both appearances, and lay them on one
#       contact sheet at 256, 64 and 32 px, Craft's own icon in the first row to compare against.
# IN:   Design/glyphs/*.svg (Scripts/art/build-glyphs.py writes them); $CRAFT for the reference row
#       (default ~/Documents/repositories/Craft; skipped when absent).
# OUT:  build/icon-candidates/<glyph>/icon_{light,dark}_1024.png and AppIcon-{light,dark}.png per candidate,
#       build/icon-candidates/sheet.png.
# PIN:  CPU only: CoreGraphics and AppKit's SVG renderer. Nothing here touches the app's icon; choosing one is
#       `cp Design/glyphs/<name>.svg Design/glyph.svg` and the steps in Scripts/art/README.md.
#
#   ./Scripts/art/icon-candidates.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/build/icon-candidates"
CRAFT="${CRAFT:-$HOME/Documents/repositories/Craft}"
REFERENCE="$CRAFT/Support/AppIcon/AppIcon.icon/Assets"

rm -rf "$OUT"
mkdir -p "$OUT/.tools"
# Compiled once, not interpreted per candidate.
xcrun --sdk macosx swiftc -O "$ROOT/Scripts/art/gen-app-icon.swift" -o "$OUT/.tools/gen-app-icon"
xcrun --sdk macosx swiftc -O "$ROOT/Scripts/art/contact-sheet.swift" -o "$OUT/.tools/contact-sheet"

shopt -s nullglob
glyphs=("$ROOT"/Design/glyphs/*.svg)
[[ ${#glyphs[@]} -gt 0 ]] || { echo "icon-candidates: no glyphs in Design/glyphs (run build-glyphs.py)" >&2; exit 1; }
for svg in "${glyphs[@]}"; do
    name="$(basename "$svg" .svg)"
    "$OUT/.tools/gen-app-icon" --glyph "$svg" --out "$OUT/$name"
done

if [[ -f "$REFERENCE/icon_light_1024.png" && -f "$REFERENCE/icon_dark_1024.png" ]]; then
    "$OUT/.tools/contact-sheet" "$OUT" "$OUT/sheet.png" --reference "$REFERENCE"
else
    "$OUT/.tools/contact-sheet" "$OUT" "$OUT/sheet.png"
fi
