#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Blockme.app"
SOURCE_APP="$ROOT_DIR/dist/$APP_NAME"
TARGET_DIR="${BLOCKME_INSTALL_DIR:-$HOME/Applications}"
TARGET_APP="$TARGET_DIR/$APP_NAME"

"$ROOT_DIR/Scripts/package-blockme-app.sh"

mkdir -p "$TARGET_DIR"
rm -rf "$TARGET_APP"
/usr/bin/ditto "$SOURCE_APP" "$TARGET_APP"
/usr/bin/xattr -dr com.apple.quarantine "$TARGET_APP" >/dev/null 2>&1 || true

echo
echo "Installed $APP_NAME to $TARGET_APP"
if [[ "${BLOCKME_NO_OPEN:-0}" != "1" ]]; then
  echo "Opening app..."
  /usr/bin/open "$TARGET_APP"
fi
echo
echo "Next step inside the app:"
echo "1. Click 'Install Protection'"
echo "2. Enter your macOS admin password"
echo "3. Add the domains you want to block"
