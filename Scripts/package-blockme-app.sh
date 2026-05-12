#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Blockme.app"
APP_BINARY_NAME="Blockme"
ICONSET_DIR="$ROOT_DIR/dist/AppIcon.iconset"
ICON_THUMBNAIL_DIR="$ROOT_DIR/dist/icon-preview"
ICON_RENDERER="$ROOT_DIR/Scripts/render-icon.swift"
ICON_PREVIEW="$ICON_THUMBNAIL_DIR/BlockmeIcon.png"
BUILD_DIR="$ROOT_DIR/.build"
RELEASE_BINARY="$BUILD_DIR/release/blockme"
DIST_APP="$ROOT_DIR/dist/$APP_NAME"
CONTENTS_DIR="$DIST_APP/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
INFO_PLIST="$CONTENTS_DIR/Info.plist"

cd "$ROOT_DIR"

echo "Rendering app icon..."
rm -rf "$ICONSET_DIR" "$ICON_THUMBNAIL_DIR"
mkdir -p "$ICONSET_DIR" "$ICON_THUMBNAIL_DIR"

/usr/bin/swift "$ICON_RENDERER" "$ICON_PREVIEW"

make_icon() {
  local size="$1"
  local output="$2"
  /usr/bin/sips -s format png -z "$size" "$size" "$ICON_PREVIEW" --out "$output" >/dev/null
}

make_icon 16 "$ICONSET_DIR/icon_16x16.png"
make_icon 32 "$ICONSET_DIR/icon_16x16@2x.png"
make_icon 32 "$ICONSET_DIR/icon_32x32.png"
make_icon 64 "$ICONSET_DIR/icon_32x32@2x.png"
make_icon 128 "$ICONSET_DIR/icon_128x128.png"
make_icon 256 "$ICONSET_DIR/icon_128x128@2x.png"
make_icon 256 "$ICONSET_DIR/icon_256x256.png"
make_icon 512 "$ICONSET_DIR/icon_256x256@2x.png"
make_icon 512 "$ICONSET_DIR/icon_512x512.png"
cp "$ICON_PREVIEW" "$ICONSET_DIR/icon_512x512@2x.png"

/usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$ROOT_DIR/AppResources/AppIcon.icns"

echo "Building release app binary..."
swift build -c release --product blockme

if [[ ! -x "$RELEASE_BINARY" ]]; then
  echo "Expected release binary at $RELEASE_BINARY but it was not built."
  exit 1
fi

echo "Assembling app bundle..."
rm -rf "$DIST_APP"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
/bin/cp "$RELEASE_BINARY" "$MACOS_DIR/$APP_BINARY_NAME"
/bin/chmod 755 "$MACOS_DIR/$APP_BINARY_NAME"
/bin/cp "$ROOT_DIR/AppResources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

cat > "$INFO_PLIST" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Blockme</string>
    <key>CFBundleExecutable</key>
    <string>Blockme</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>local.steadfast.blockme</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Blockme</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

/usr/bin/codesign --force --deep --sign - "$DIST_APP" >/dev/null

echo "Packaged $DIST_APP"
