#!/usr/bin/env bash
# Builds a universal (Apple Silicon + Intel) Release LocalOSXAi.app, sets its
# build number, signs it and packs it in a disk image,
# dist/LocalOSXAi-<version>.dmg: open it, drag the app onto Applications.
# Used by .github/workflows/release.yml; runs the same on a Mac.
#
# Usage: scripts/build-release.sh [build-number]
#
# Signing and notarization are optional and off by default, so this script
# runs unchanged for any contributor: without a Developer ID, it signs ad
# hoc, exactly as before (docs/code/releasing.md).
#
#   SIGNING_IDENTITY  A "Developer ID Application: …" identity (as
#                     `codesign --sign` takes it, e.g. the hash `security
#                     find-identity` prints). Default: "-" (ad hoc).
#   NOTARY_KEY_PATH   Path to an App Store Connect API key (.p8). Signing
#   NOTARY_KEY_ID     with a real identity but leaving these unset produces
#   NOTARY_ISSUER_ID  a signed, un-notarized build; all three together
#                     notarize and staple the disk image.
set -euo pipefail
cd "$(dirname "$0")/.."

build_number="${1:-1}"
signing_identity="${SIGNING_IDENTITY:--}"
version=$(scripts/app-version.sh)
derived=.build/Release
app="$derived/Build/Products/Release/LocalOSXAi.app"
image="dist/LocalOSXAi-$version.dmg"

xcodegen generate --quiet
rm -rf "$derived" dist
xcodebuild -project LocalOSXAi.xcodeproj -scheme LocalOSXAi -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "$derived" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO build -quiet

# The build number identifies this build in About (“Version 0.0.0.1 (42)”).
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$app/Contents/Info.plist"
# Changing Info.plist invalidates the signature: sign again. Hardened
# runtime is required for notarization, and harmless otherwise (ADR 0009:
# no App Sandbox, so it restricts nothing the app relies on).
codesign --force --deep --options runtime --sign "$signing_identity" "$app"
codesign --verify --deep --strict "$app"
if [[ "$signing_identity" != "-" ]]; then
  # An ad hoc signature has no identity for spctl to assess.
  codesign --display --verbose=2 "$app"
fi

# The image shows the app next to a link to /Applications, the usual
# drag-to-install window.
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/LocalOSXAi.app"
ln -s /Applications "$staging/Applications"

mkdir -p dist
# hdiutil sometimes fails with “Resource busy” on CI runners; retry.
for attempt in 1 2 3; do
  if hdiutil create -volname "LocalOSXAi $version" -srcfolder "$staging" -fs HFS+ -format UDZO -ov "$image"; then
    break
  fi
  [[ $attempt -eq 3 ]] && { echo "✘ hdiutil could not create $image" >&2; exit 1; }
  sleep 5
done
hdiutil verify "$image"

if [[ -n "${NOTARY_KEY_PATH:-}" ]]; then
  echo "→ Submitting $image for notarization…"
  xcrun notarytool submit "$image" \
    --key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID" \
    --wait --timeout 30m
  xcrun stapler staple "$image"
  xcrun stapler validate "$image"
  spctl --assess --verbose --type install "$image"
  echo "✔ $image (version $version, build $build_number, notarized)"
else
  echo "✔ $image (version $version, build $build_number)"
fi
