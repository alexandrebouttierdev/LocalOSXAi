#!/usr/bin/env bash
# Builds a universal (Apple Silicon + Intel) Release LocalOSXAi.app, sets its
# build number, signs it ad hoc and zips it to dist/LocalOSXAi-<version>.zip.
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
archive="dist/LocalOSXAi-$version.zip"

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

mkdir -p dist
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
echo "✔ $archive (version $version, build $build_number)"
