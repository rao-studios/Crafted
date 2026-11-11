#!/bin/bash
# WHAT: A Developer ID release of Crafted: the app → a signed .pkg → a notarized, stapled installer, with a manifest of
#       exactly what went in.
# IN:   Keychain identities "Developer ID Application" and "Developer ID Installer"; a notarytool profile
#       (NOTARY_PROFILE, default rao-notary):
#         xcrun notarytool store-credentials rao-notary --apple-id <id> --team-id TA6WK7F4P8
#       A clean, committed checkout. Every package by URL: Frigate and Granite come from Package.resolved, never a
#       sibling working tree.
# OUT:  build/Crafted-<version>.pkg — installs /Applications/Crafted.app (mlx.metallib beside the executable, the
#       templates in Contents/Resources/Templates), quitting a running Crafted first and opening the new one.
#       build/Crafted-<version>-manifest.txt — the commits it was built from; the same short commits ride in the app's
#       Info.plist (CraftedBuildCommit, CraftedDependencyCommits).
# PIN:  FORKED FROM CRAFT'S release.sh, WITHOUT THE HELPER AND THE UPLOAD: Crafted has no AIIServer and no update feed
#       yet. The pkg is the deliverable.
# PIN:  THE VERSION IS SET HERE. Given a version and build, they are written to Support/Info.plist and committed on
#       their own ("Crafted 0.1.0 (2)") before anything is built, so the build stamps a clean commit.
# PIN:  arm64 and macOS 27 only (MLX, and the app's floor). Nothing is built from a dirty tree, and nothing by path.
# PIN:  WRITTEN IN THE FIRST PASS, RUN IN THE FOLLOW-UP (with the real-model runs and the hardened-runtime check).
#
#   ./Scripts/release/release.sh                                  # this version and build again
#   ./Scripts/release/release.sh 0.1.0 2                          # set version 0.1.0, build 2, release it
#   SKIP_NOTARIZE=1 ./Scripts/release/release.sh                  # stop at the signed .pkg
#   ALLOW_DIRTY=1 SKIP_NOTARIZE=1 ./Scripts/release/release.sh    # a dry run from uncommitted work (no commit)
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="$REPO_ROOT/build"
APP="$BUILD/Crafted.app"
NOTARY_PROFILE="${NOTARY_PROFILE:-rao-notary}"
cd "$REPO_ROOT"

fail() { echo "error: $*" >&2; exit 1; }

NEW_VERSION=""
NEW_BUILD=""
while [ $# -gt 0 ]; do
    case "$1" in
        --version|--build)
            [ $# -ge 2 ] || fail "$1 needs a value"
            if [ "$1" = "--version" ]; then NEW_VERSION="$2"; else NEW_BUILD="$2"; fi
            shift 2 ;;
        -h|--help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
        -*) fail "unknown option $1 (see --help)" ;;
        *)
            if [ -z "$NEW_VERSION" ]; then NEW_VERSION="$1"
            elif [ -z "$NEW_BUILD" ]; then NEW_BUILD="$1"
            else fail "too many arguments: $1 (see --help)"
            fi
            shift ;;
    esac
done
[ -z "$NEW_VERSION" ] || [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "version $NEW_VERSION is not N.N.N"
[ -z "$NEW_BUILD" ] || [[ "$NEW_BUILD" =~ ^[1-9][0-9]*$ ]] || fail "build $NEW_BUILD is not a positive whole number"
command -v jq >/dev/null || fail "jq is required (brew install jq)"

identity() {
    security find-identity -v -p "$1" 2>/dev/null \
        | awk -F'"' -v kind="$2" 'index($2, kind) == 1 {print $2; exit}'
}

echo "▸ preflight: identities"
APP_IDENTITY="$(identity codesigning "Developer ID Application")"
[ -n "$APP_IDENTITY" ] || fail "no \"Developer ID Application\" identity in the keychain"
INSTALLER_IDENTITY="$(identity basic "Developer ID Installer")"
[ -n "$INSTALLER_IDENTITY" ] || fail "no \"Developer ID Installer\" identity — create one at developer.apple.com → Certificates"
if [ "${SKIP_NOTARIZE:-0}" != "1" ] \
    && ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    fail "no notarytool keychain profile '$NOTARY_PROFILE' (see the header)"
fi
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Support/Info.plist)"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Support/Info.plist)"
NEW_VERSION="${NEW_VERSION:-$VERSION}"
NEW_BUILD="${NEW_BUILD:-$BUILD_NUMBER}"
[ "$NEW_BUILD" -ge "$BUILD_NUMBER" ] || fail "build $NEW_BUILD is lower than Support/Info.plist's $BUILD_NUMBER"
if [ "$NEW_VERSION" != "$VERSION" ] && [ "$NEW_BUILD" = "$BUILD_NUMBER" ]; then
    fail "version $NEW_VERSION needs a build above $BUILD_NUMBER (e.g. $0 $NEW_VERSION $((BUILD_NUMBER + 1)))"
fi
echo "  Crafted $NEW_VERSION ($NEW_BUILD), signing as $APP_IDENTITY"

echo "▸ preflight: sources"
dirty="$(git -C "$REPO_ROOT" status --porcelain --untracked-files=normal)"
if [ -n "$dirty" ]; then
    if [ "${ALLOW_DIRTY:-0}" = "1" ]; then
        echo "  warning: the checkout is dirty (ALLOW_DIRTY=1)"
    else
        echo "$dirty" | head -20 >&2
        fail "uncommitted changes — commit them, or ALLOW_DIRTY=1 for a dry run"
    fi
fi
if grep -Eq '^[[:space:]]*\.package\(path:' "$REPO_ROOT/Package.swift"; then
    fail "Package.swift takes a package by path — restore the URL form before a release"
fi
[ ! -s "$REPO_ROOT/.swiftpm/configuration/mirrors.json" ] \
    || fail ".swiftpm/configuration/mirrors.json redirects a package — a release builds what its URLs name"
[ -d "$REPO_ROOT/Templates" ] || fail "no Templates/ — the app would ship without the agents' templates"

echo "▸ version"
if [ "$NEW_VERSION" != "$VERSION" ] || [ "$NEW_BUILD" != "$BUILD_NUMBER" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW_VERSION" -c "Set :CFBundleVersion $NEW_BUILD" Support/Info.plist
    echo "  Support/Info.plist: $VERSION ($BUILD_NUMBER) → $NEW_VERSION ($NEW_BUILD)"
    VERSION="$NEW_VERSION"
    BUILD_NUMBER="$NEW_BUILD"
    if [ "${ALLOW_DIRTY:-0}" = "1" ]; then
        echo "  not committed (ALLOW_DIRTY=1)"
    else
        git -C "$REPO_ROOT" commit -q -m "Crafted $VERSION ($BUILD_NUMBER)" -- Support/Info.plist
        echo "  committed $(git -C "$REPO_ROOT" rev-parse --short HEAD) “Crafted $VERSION ($BUILD_NUMBER)”"
    fi
else
    echo "  Crafted $VERSION ($BUILD_NUMBER) again — this run overwrites it"
fi
PKG="$BUILD/Crafted-$VERSION.pkg"
MANIFEST="$BUILD/Crafted-$VERSION-manifest.txt"

echo "▸ manifest"
pin() { jq -r --arg p "$1" '.pins[] | select(.identity == $p) | .state.revision' "$REPO_ROOT/Package.resolved" 2>/dev/null || true; }
FRIGATE_PINNED="$(pin frigate)"
GRANITE_PINNED="$(pin granite)"
[ -n "$FRIGATE_PINNED" ] && [ -n "$GRANITE_PINNED" ] || fail "Package.resolved pins no frigate or granite — resolve the package first"
mkdir -p "$BUILD"
{
    echo "Crafted $VERSION"
    echo "build $BUILD_NUMBER"
    echo "date $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "crafted $(git -C "$REPO_ROOT" rev-parse HEAD) $REPO_ROOT"
    echo "frigate $FRIGATE_PINNED (Package.resolved)"
    echo "granite $GRANITE_PINNED (Package.resolved)"
    echo "xcode   $(xcodebuild -version 2>/dev/null | tr '\n' ' ')"
    echo "dirty   ${ALLOW_DIRTY:-0}"
} > "$MANIFEST"
sed 's/^/  /' "$MANIFEST"

echo "▸ app"
DEVELOPER_ID=1 SIGN_IDENTITY="$APP_IDENTITY" CONFIG=release "$REPO_ROOT/Scripts/build/make-app.sh"

echo "▸ verify the app"
codesign --verify --deep --strict --verbose=2 "$APP"
signature="$(codesign -dv --verbose=2 "$APP" 2>&1)"
[[ "$signature" == *"(runtime)"* ]] || fail "$APP lacks the hardened runtime"
[[ "$signature" == *"TeamIdentifier=TA6WK7F4P8"* ]] || fail "$APP is not signed by team TA6WK7F4P8"
for key in CraftedBuildCommit CraftedDependencyCommits; do
    /usr/libexec/PlistBuddy -c "Print :$key" "$APP/Contents/Info.plist" >/dev/null 2>&1 || fail "the app's Info.plist has no $key"
done
[ -f "$APP/Contents/MacOS/mlx.metallib" ] || fail "no mlx.metallib beside the executable"
[ -d "$APP/Contents/Resources/Templates" ] || fail "no Templates in the app"
commit_stamp="$(/usr/libexec/PlistBuddy -c 'Print :CraftedBuildCommit' "$APP/Contents/Info.plist")"
if [[ "$commit_stamp" == *-dirty ]] && [ "${ALLOW_DIRTY:-0}" != "1" ]; then
    fail "the app is stamped $commit_stamp"
fi
echo "  CraftedBuildCommit $commit_stamp"

echo "▸ package"
rm -f "$BUILD/Crafted-component.pkg" "$PKG"
# From a staging root, with relocation off: a relocatable bundle would let the installer "upgrade" whatever copy of
# nyc.rao.crafted macOS last saw (build/Crafted.app on this Mac) instead of installing to /Applications. Version
# checking off too: with it on, Installer skips the app when the installed copy's version is higher.
STAGE="$BUILD/pkg-root"
rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Crafted.app"
pkgbuild --analyze --root "$STAGE" "$BUILD/components.plist"
plutil -replace 0.BundleIsRelocatable -bool NO "$BUILD/components.plist"
plutil -replace 0.BundleIsVersionChecked -bool NO "$BUILD/components.plist"
pkgbuild --root "$STAGE" \
    --component-plist "$BUILD/components.plist" \
    --install-location /Applications \
    --scripts "$REPO_ROOT/Support/Pkg/scripts" \
    --identifier nyc.rao.crafted.pkg \
    --version "$VERSION" \
    "$BUILD/Crafted-component.pkg"
rm -rf "$STAGE" "$BUILD/components.plist"
productbuild --distribution "$REPO_ROOT/Support/Pkg/Distribution.xml" \
    --package-path "$BUILD" \
    --sign "$INSTALLER_IDENTITY" --timestamp \
    "$PKG"
rm -f "$BUILD/Crafted-component.pkg"
pkgutil --check-signature "$PKG"
EXPANDED="$(mktemp -d)"
pkgutil --expand "$PKG" "$EXPANDED/pkg"
for script in preinstall postinstall; do
    [ -x "$EXPANDED/pkg/Crafted-component.pkg/Scripts/$script" ] || fail "$PKG carries no $script"
done
rm -rf "$EXPANDED"

if [ "${SKIP_NOTARIZE:-0}" = "1" ]; then
    echo "Skipped notarization. Signed, unnotarized: $PKG"
    echo "Manifest: $MANIFEST"
    exit 0
fi

echo "▸ notarize"
xcrun notarytool submit "$PKG" --keychain-profile "$NOTARY_PROFILE" --wait

echo "▸ staple"
xcrun stapler staple "$PKG"
xcrun stapler validate "$PKG"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "▸ assess"
codesign --verify --deep --strict "$APP"
spctl --assess --type install --verbose "$PKG"
spctl --assess --type exec --verbose "$APP"

echo "Done: $PKG"
echo "      $MANIFEST"
if git -C "$REPO_ROOT" rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null; then
    echo "Tag:  git tag -f -a v$VERSION -m 'Crafted $VERSION ($BUILD_NUMBER)' && git push origin -f v$VERSION"
else
    echo "Tag:  git tag -a v$VERSION -m 'Crafted $VERSION ($BUILD_NUMBER)' && git push origin v$VERSION"
fi
