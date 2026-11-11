# Scripts/art

Crafted's art: the Lyon watercolours, the wash that paints them in, and the app icon. Every script runs on the CPU;
none draws with the GPU or launches the app. Run from the repository root.

## The watercolours

| Order | Script | Makes |
|---|---|---|
| 1 | `sync-watercolours.sh [site checkout]` | Copies the `gardens`, `fourviere` and `lyon` far / fog / near layers and the three blooms from craft.rao.nyc (`$SITE`, default `~/Documents/repositories/craft.rao.nyc`) into `Sources/CraftedApp/Resources/Watercolour/` under stable names (`gardens-far.webp`, `bloom-sky.webp`, …), and the Rao seal into `Resources/seal.png`. Reads the site's manifest (`app/(home)/_lib/home-art.ts`) for the current hashed names and records the site's commit in `Watercolour/SOURCE.txt`. |
| 2 | `swift gen-arrival-maps.swift [scene …]` | Bakes each `Design/washes/<scene>.json` into `Sources/CraftedApp/Resources/washes/<scene>-arrival.png` (480×270; red = when the wash arrives, green = slow wander). The JSON lists regions in the order they are laid, each with a shape, a sweep and a time band. |
| 3 | `../build/build-shaders.sh` | Compiles `Shaders/Watercolour.metal` into `Sources/CraftedApp/Resources/Watercolour.metallib` and writes the source's SHA-256 beside it. `--check` fails when the metallib is older than the source. |

Run step 1 when the site repaints, step 2 when a design in `Design/washes/` changes (or the paintings do), step 3
when the shader changes. Commit what they write: `swift build` has no step for any of it.

## The icon

| Order | Script | Makes |
|---|---|---|
| 1 | `python3 -I build-glyphs.py` | The candidate glyphs in `Design/glyphs/` (`needle-folder`, `hand-folder`, `stitched-patch`), drawn in Craft's embroidered hand: 320-unit box, stroke 1.7, round caps and joins, ticks across each seam. |
| 2 | `icon-candidates.sh` | Renders every candidate as the full icon in both appearances and lays them on one contact sheet at 256, 64 and 32 px, Craft's icon in the first row: `build/icon-candidates/sheet.png`. |
| 3 | `cp Design/glyphs/<name>.svg Design/glyph.svg && cp Design/glyph.svg Sources/CraftedApp/Resources/glyph.svg` | Chooses a glyph. `needle-folder` is installed as the placeholder until the owner picks. |
| 4 | `swift gen-app-icon.swift` | From `Design/glyph.svg`: the icon's layers `Support/AppIcon/AppIcon.icon/Assets/icon_{light,dark}_1024.png` (named in `AppIcon.icon/icon.json`, Craft's), the `.icns` fallback `Support/AppIcon/icon_1024.png`, and the bare binary's Dock tiles `Sources/CraftedApp/Resources/AppIcon-{light,dark}.png`. `--glyph <svg>` and `--out <dir>` render any other glyph elsewhere. |
| 5 | `make-iconset.sh Support/AppIcon/icon_1024.png build/AppIcon.iconset` | Craft's: the ten sizes for `iconutil -c icns`, used by the app packaging. |

`gen-app-icon.swift` is a fork of Craft's: same plate, ink, thread, knot ring and tile. Change the shared numbers in
both apps (and in the site's `scripts/lib/embroidery.mjs`) together. `contact-sheet.swift` is the sheet's composer,
called by `icon-candidates.sh`.
