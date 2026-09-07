#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
scratch_dir="$project_dir/.build"
app_dir="$project_dir/dist/YanXu.app"
widget_dir="$app_dir/Contents/PlugIns/YanXuWidgets.appex"
temporary_root="${TMPDIR:-/private/tmp}yanxu-build-cache"

mkdir -p "$temporary_root/clang" "$temporary_root/swiftpm"

CLANG_MODULE_CACHE_PATH="$temporary_root/clang" \
SWIFTPM_MODULECACHE_OVERRIDE="$temporary_root/swiftpm" \
swift build -c release --product YanXu --scratch-path "$scratch_dir"
CLANG_MODULE_CACHE_PATH="$temporary_root/clang" \
SWIFTPM_MODULECACHE_OVERRIDE="$temporary_root/swiftpm" \
swift build -c release --product YanXuWidgets --scratch-path "$scratch_dir"

mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources" "$widget_dir/Contents/MacOS"
install -m 755 "$scratch_dir/release/YanXu" "$app_dir/Contents/MacOS/YanXu"
install -m 644 "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
install -m 644 "$project_dir/Resources/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
install -m 755 "$scratch_dir/release/YanXuWidgets" "$widget_dir/Contents/MacOS/YanXuWidgets"
install -m 644 "$project_dir/Resources/YanXuWidgets-Info.plist" "$widget_dir/Contents/Info.plist"

codesign --force --sign - --entitlements "$project_dir/Resources/YanXuWidgets.entitlements" "$widget_dir"
codesign --force --sign - "$app_dir"

echo "$app_dir"
