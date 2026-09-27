#!/usr/bin/env bash
# Builds a universal (Apple Silicon + Intel) Release LocalOSXAi.app, sets its
# build number, signs it ad hoc and packs it in a disk image,
# dist/LocalOSXAi-<version>.dmg: open it, drag the app onto Applications.
# Used by .github/workflows/release.yml; runs the same on a Mac.
#
# Usage: scripts/build-release.sh [build-number]
#
# The app is signed ad hoc, not with a Developer ID, and not notarized:
# macOS asks users to confirm the first launch (docs/code/releasing.md).
set -euo pipefail
cd "$(dirname "$0")/.."

build_number="${1:-1}"
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
# Changing Info.plist invalidates the signature: sign again, ad hoc.
codesign --force --deep --options runtime --sign - "$app"
codesign --verify --deep --strict "$app"

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
echo "✔ $image (version $version, build $build_number)"
