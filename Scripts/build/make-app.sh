#!/bin/bash
# WHAT: Assemble build/Crafted.app from a release build.
# OUT:  build/Crafted.app — Contents/MacOS/Crafted, Info.plist (stamped with CraftedBuildCommit, CraftedBuildDate and
#       CraftedDependencyCommits, which BuildInfo reads for Settings › About), the resource bundles, mlx.metallib beside
#       the executable, the app icon, and Templates/ in Contents/Resources/Templates (the forge's TemplateSource finds
#       them there).
#       build/app-metadata.json — version, build, commit, date and the MD5 of the signed executable.
# PIN:  FORKED FROM CRAFT'S make-app.sh, WITHOUT ITS HELPER: Crafted runs its models in process (CraftedMLX), so there
#       is no AIIServer, no Contents/Helpers and no Supabase stamp.
# PIN:  MLX finds its kernels as `mlx.metallib` NEXT TO THE RUNNING BINARY. The resource-bundle rung never matches
#       under Frigate (it emits Frigate_Cmlx.bundle, MLX probes for mlx-swift_Cmlx.bundle), so the metallib step runs
#       against the assembled app, before signing. Sign inside-out; never --deep.
#       Package.swift and Support/Info.plist must agree on the minimum OS.
#
#   ./Scripts/build/make-app.sh [--install]
#   CONFIG=debug ./Scripts/build/make-app.sh                      # a quick assembly from the debug build
#   SIGN_IDENTITY="…" DEVELOPER_ID=1 ./Scripts/build/make-app.sh  # what release.sh runs
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PKG="$REPO_ROOT"
APP_DIR="$REPO_ROOT/build/Crafted.app"
CONFIG="${CONFIG:-release}"
INSTALL=0

# PIN: BUILD SYSTEM. SwiftPM's default (`swiftbuild`) compiles Frigate's vendored .metal
#      sources, through Xcode's `metal` stub — which on this machine reports "missing
#      Metal Toolchain" even though `xcrun metal` compiles fine, so every build fails.
#      `native` has no Metal step at all; build-metallib.sh compiles the shaders with
#      xcrun and installs them. Flip back with CRAFTED_BUILD_SYSTEM=swiftbuild once the
#      toolchain is fixed.
BUILD_SYSTEM="${CRAFTED_BUILD_SYSTEM:-native}"

while [ $# -gt 0 ]; do
    case "$1" in
        --install) INSTALL=1; shift ;;
        *) echo "make-app: unknown argument '$1'" >&2; exit 2 ;;
    esac
done

# The plist and the manifest must agree on the OS floor.
PKG_OS="$(sed -nE 's/.*\.macOS\("([0-9.]+)"\).*/\1/p' "$PKG/Package.swift" | head -1)"
PLIST_OS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$PKG/Support/Info.plist")"
if [ "$PKG_OS" != "$PLIST_OS" ]; then
    echo "make-app: Package.swift says macOS $PKG_OS but Support/Info.plist says $PLIST_OS" >&2
    exit 1
fi

source "$REPO_ROOT/Scripts/build/lib-metal.sh"
refresh_metal_toolchain "$REPO_ROOT"
echo "▸ swift build -c $CONFIG ($BUILD_SYSTEM)"
swift build --build-system "$BUILD_SYSTEM" -c "$CONFIG" --product CraftedApp

echo "▸ assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$PKG/.build/$CONFIG/CraftedApp" "$APP_DIR/Contents/MacOS/Crafted"
cp "$PKG/Support/Info.plist" "$APP_DIR/Contents/Info.plist"

# What Settings › About reads (BuildInfo): the commit, the date, and the commits of the packages Package.resolved
# pinned. Only the bundle's copy is stamped; Support/Info.plist stays clean.
commit="$(git -C "$REPO_ROOT" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"
[ -z "$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null)" ] || commit="$commit-dirty"
built_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
dependencies="$(python3 -I - "$PKG/Package.resolved" <<'PY'
import json, sys
pins = {p["identity"]: p["state"].get("revision", "") for p in json.load(open(sys.argv[1]))["pins"]}
print(" ".join(f"{name}={pins[name][:12]}" for name in ("frigate", "granite") if pins.get(name)))
PY
)"
/usr/libexec/PlistBuddy -c "Add :CraftedBuildCommit string $commit" \
    -c "Add :CraftedBuildDate string $built_at" \
    -c "Add :CraftedDependencyCommits string $dependencies" "$APP_DIR/Contents/Info.plist"
echo "▸ stamped CraftedBuildCommit $commit, CraftedBuildDate $built_at, CraftedDependencyCommits $dependencies"

for bundle in "$PKG/.build/$CONFIG/"*.bundle; do
    [ -d "$bundle" ] && cp -R "$bundle" "$APP_DIR/Contents/Resources/"
done

# The templates the forge stamps packages from (TemplateSource looks in Contents/Resources/Templates first): their
# sources, never a build of them.
if [ -d "$PKG/Templates" ]; then
    echo "▸ Templates → Contents/Resources/Templates"
    mkdir -p "$APP_DIR/Contents/Resources/Templates"
    rsync -a --exclude '.build' --exclude '.swiftpm' --exclude '.DS_Store' "$PKG/Templates/" "$APP_DIR/Contents/Resources/Templates/"
else
    echo "▸ warning: no Templates/ to copy"
fi

echo "▸ mlx.metallib → Contents/MacOS"
"$REPO_ROOT/Scripts/build/build-metallib.sh" "$CONFIG" --app "$APP_DIR"

# Dock and Finder icon, before codesign: Resources is sealed. macOS 26+ reads the layered icon
# (Support/AppIcon/AppIcon.icon, compiled into Assets.car and named by CFBundleIconName); the .icns from the 1024 PNG
# is the fallback for anything reading CFBundleIconFile. Both are the art track's (Scripts/art).
ICON_SOURCE="$PKG/Support/AppIcon/AppIcon.icon"
if [ -d "$ICON_SOURCE" ]; then
    echo "▸ app icon"
    # ONE ICON COMPILE AT A TIME, across every Rao checkout: two actool runs in flight hand each other's renditions
    # (both catalogs are AppIcon.icon). mkdir is atomic; a lock left by a crash is `rmdir /tmp/rao-actool.lock`.
    ICON_LOCK="/tmp/rao-actool.lock"
    for _ in $(seq 1 150); do
        mkdir "$ICON_LOCK" 2>/dev/null && break
        echo "▸ waiting for another icon compile to finish ($ICON_LOCK)"; sleep 2
    done
    [ -d "$ICON_LOCK" ] || { echo "error: could not take $ICON_LOCK" >&2; exit 1; }
    trap 'rmdir "$ICON_LOCK" 2>/dev/null' EXIT
    ACTOOL_OUT="$(xcrun actool "$ICON_SOURCE" --compile "$APP_DIR/Contents/Resources" \
        --platform macosx --minimum-deployment-target "$PLIST_OS" --app-icon AppIcon \
        --include-all-app-icons --output-partial-info-plist "$REPO_ROOT/build/AppIcon-partial.plist" \
        --output-format human-readable-text 2>&1)"
    if echo "$ACTOOL_OUT" | grep -q -i "error" || [ ! -f "$APP_DIR/Contents/Resources/Assets.car" ]; then
        echo "make-app: actool failed to compile Support/AppIcon/AppIcon.icon" >&2
        echo "$ACTOOL_OUT" >&2
        exit 1
    fi
    rmdir "$ICON_LOCK"; trap - EXIT
else
    echo "▸ warning: no Support/AppIcon/AppIcon.icon yet; the app has no layered icon"
fi
ICON_PNG="$PKG/Support/AppIcon/icon_1024.png"
if [ -f "$ICON_PNG" ]; then
    ICONSET="$REPO_ROOT/build/AppIcon.iconset"
    rm -rf "$ICONSET"; mkdir -p "$ICONSET"
    for size in 16 32 128 256 512; do
        sips -z $size $size "$ICON_PNG" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
        double=$((size * 2))
        sips -z $double $double "$ICON_PNG" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
else
    echo "▸ warning: no Support/AppIcon/icon_1024.png yet; no AppIcon.icns"
fi

ENTITLEMENTS="$PKG/Support/Crafted.entitlements"
SIGN_FLAGS=()
if [ "${DEVELOPER_ID:-0}" = 1 ]; then
    IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Developer ID Application/ {print $2; exit}')}"
    SIGN_FLAGS=(--options runtime --timestamp)
else
    IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/ {print $2; exit}')}"
fi
if [ -n "$IDENTITY" ]; then
    echo "▸ codesign ($IDENTITY)"
else
    IDENTITY="-"
    echo "▸ codesign (ad-hoc)"
fi
# Metallibs under Contents/MacOS are nested code to codesign: sign them first.
find "$APP_DIR/Contents" \( -name mlx.metallib -o -name default.metallib \) -type f | while read -r lib; do
    xattr -c "$lib" 2>/dev/null || true
    codesign --force --sign "$IDENTITY" ${SIGN_FLAGS[@]+"${SIGN_FLAGS[@]}"} "$lib"
done
# SwiftPM resource bundles. PIN: codesign treats anything named *.bundle as nested code and refuses to sign the app
# while one is unsigned. Three layouts arrive here and each needs a different thing:
#   • deep (Contents/Info.plist): already signable, touch nothing.
#   • flat, loose files only: a root Info.plist is enough.
#   • flat with a Resources/ directory (`.copy("Resources")`, Crafted's own two): codesign reads Resources/ as the deep
#     layout and then cannot find Contents/. Normalise it to the deep layout. CraftedAssets, WatercolourResources and
#     ForgeResources all look in Contents/Resources as well as Resources/.
find "$APP_DIR/Contents" -maxdepth 3 -name '*.bundle' -type d | while read -r bundle; do
    name="$(basename "$bundle" .bundle)"
    plist="$bundle/Info.plist"
    if [ ! -f "$bundle/Contents/Info.plist" ]; then
        if [ -d "$bundle/Resources" ]; then
            mkdir -p "$bundle/Contents"
            rm -f "$bundle/Info.plist"
            for entry in "$bundle"/*; do
                case "$(basename "$entry")" in
                    Contents) ;;
                    Resources) mv "$entry" "$bundle/Contents/" ;;
                    *) mkdir -p "$bundle/Contents/Resources"; mv "$entry" "$bundle/Contents/Resources/" ;;
                esac
            done
            plist="$bundle/Contents/Info.plist"
        fi
        [ -f "$plist" ] || /usr/libexec/PlistBuddy \
            -c "Add :CFBundleIdentifier string nyc.rao.crafted.res.$(echo "$name" | tr '_' '-')" \
            -c "Add :CFBundleName string $name" \
            -c "Add :CFBundlePackageType string BNDL" \
            -c "Add :CFBundleInfoDictionaryVersion string 6.0" \
            "$plist" >/dev/null
    fi
    xattr -cr "$bundle" 2>/dev/null || true
    codesign --force --sign "$IDENTITY" ${SIGN_FLAGS[@]+"${SIGN_FLAGS[@]}"} "$bundle" || exit 1
done
xattr -cr "$APP_DIR/Contents/Resources/Templates" 2>/dev/null || true
codesign --force --sign "$IDENTITY" ${SIGN_FLAGS[@]+"${SIGN_FLAGS[@]}"} --entitlements "$ENTITLEMENTS" "$APP_DIR"

# What About shows at its foot. After codesign, which rewrites the executable; stapling (release.sh) and the pkg
# install leave it as it is.
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")"
build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_DIR/Contents/Info.plist")"
md5="$(md5 -q "$APP_DIR/Contents/MacOS/Crafted")"
METADATA="$REPO_ROOT/build/app-metadata.json"
cat > "$METADATA" <<JSON
{
  "version": "$version",
  "build": "$build_number",
  "commit": "$commit",
  "builtAt": "$built_at",
  "dependencies": "$dependencies",
  "signedBy": "$IDENTITY",
  "executable": "Crafted.app/Contents/MacOS/Crafted",
  "md5": "$md5"
}
JSON
echo "▸ wrote $METADATA (md5 $md5)"

if [ "$INSTALL" = 1 ]; then
    echo "▸ installing /Applications/Crafted.app"
    rm -rf /Applications/Crafted.app
    ditto "$APP_DIR" /Applications/Crafted.app
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Crafted.app
fi

echo "Done: $APP_DIR"
