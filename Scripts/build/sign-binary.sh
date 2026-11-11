#!/bin/bash
# WHAT: Stable-sign one built binary so TCC grants survive rebuilds.
# PIN:  Ad-hoc identity IS the cdhash, which changes every build.
#
#   ./Scripts/build/sign-binary.sh /path/to/Crafted
#
BIN="$1"

if [ ! -f "$BIN" ]; then
    echo "sign-binary: nothing at $BIN — skipping"
    exit 0
fi

IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | awk -F'"' '/Apple Development/ {print $2; exit}')"

if [ -z "$IDENTITY" ]; then
    echo "sign-binary: no stable codesigning identity; leaving ad-hoc."
    exit 0
fi

codesign --force --sign "$IDENTITY" --preserve-metadata=entitlements "$BIN"
echo "sign-binary: signed $BIN with '$IDENTITY'"
