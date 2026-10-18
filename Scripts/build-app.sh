#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="${THUMBKEY_BUILD_DIR:-$project_dir/.build}"
cache_dir="${THUMBKEY_CACHE_DIR:-$project_dir/.swift-cache}"
app_dir="${THUMBKEY_APP_OUTPUT:-$project_dir/../ThumbKey.app}"
identity="${THUMBKEY_SIGN_IDENTITY:-}"
if [ -z "$identity" ]; then identity="$(security find-identity -v -p codesigning | awk '/Apple Development:/ {print $2;exit}')"; fi
if [ -z "$identity" ] || [ "$identity" = '-' ]; then echo 'A stable Apple Development signing identity is required for macOS input permission continuity.' >&2;exit 1;fi
swift build --package-path "$project_dir" --scratch-path "$build_dir" --cache-path "$cache_dir" -c release
if [ ! -e "$project_dir/Resources/AppIcon.icns" ]; then
 swift "$project_dir/Scripts/make-icon.swift" "$build_dir/ThumbKey.iconset"
 iconutil -c icns "$build_dir/ThumbKey.iconset" -o "$project_dir/Resources/AppIcon.icns"
fi
if [ -e "$app_dir" ]; then echo "Output already exists: $app_dir. Quit it and move it aside before rebuilding." >&2;exit 1;fi
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$build_dir/release/ThumbKey" "$app_dir/Contents/MacOS/"
cp "$project_dir/Info.plist" "$app_dir/Contents/"
cp "$project_dir/Resources/AppIcon.icns" "$app_dir/Contents/Resources/ThumbKeyMouse.icns"
codesign --force --timestamp=none --sign "$identity" "$app_dir"
codesign --verify --deep --strict "$app_dir"
echo "Built $app_dir"
