#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="${BLOCKME_INSTALL_DIR:-$HOME/Applications}/Blockme.app"

echo "Building and installing Blockme.app..."
BLOCKME_NO_OPEN=1 "$ROOT_DIR/Scripts/install-blockme-app.sh"

INSTALL_COMMAND="'$APP_PATH/Contents/MacOS/Blockme' install"
ESCAPED_INSTALL_COMMAND="${INSTALL_COMMAND//\\/\\\\}"
ESCAPED_INSTALL_COMMAND="${ESCAPED_INSTALL_COMMAND//\"/\\\"}"

echo
echo "Installing the privileged backend. macOS will ask for your admin password."
/usr/bin/osascript <<APPLESCRIPT
do shell script "$ESCAPED_INSTALL_COMMAND" with administrator privileges
APPLESCRIPT

echo
echo "Opening Blockme.app..."
/usr/bin/open "$APP_PATH"

echo
echo "Install complete."
echo "You can now:"
echo "  - open Blockme.app from ~/Applications"
echo "  - use 'blockme status' in Terminal"
echo "  - use 'sudo blockme add instagram.com' to add a blocked domain from the CLI"
