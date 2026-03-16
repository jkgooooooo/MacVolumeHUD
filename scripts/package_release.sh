#!/bin/zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PROJECT_PATH="$ROOT_DIR/MacVolumeHUD.xcodeproj"
SCHEME="MacVolumeHUD"
DERIVED_DATA_PATH="$ROOT_DIR/.codex-derived-data/release-build"
OUTPUT_DIR="$ROOT_DIR/dist"
APP_NAME="MacVolumeHUD.app"
ZIP_NAME="MacVolumeHUD.zip"
SIGNING_MODE="${SIGNING_MODE:-unsigned}"

mkdir -p "$OUTPUT_DIR"
rm -rf "$DERIVED_DATA_PATH"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED="$([[ "$SIGNING_MODE" == "signed" ]] && echo YES || echo NO)" \
  CODE_SIGNING_REQUIRED="$([[ "$SIGNING_MODE" == "signed" ]] && echo YES || echo NO)" \
  -quiet \
  build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/$APP_NAME"
ZIP_PATH="$OUTPUT_DIR/$ZIP_NAME"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded but $APP_PATH was not found." >&2
  exit 1
fi

rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

SHA256=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')

cat <<EOF
Created:
  $ZIP_PATH

SHA256:
  $SHA256

Upload the zip to:
  https://github.com/YOUR_GITHUB_USERNAME/MacVolumeHUD/releases/latest/download/MacVolumeHUD.zip

Then publish the cask from:
  $ROOT_DIR/Casks/macvolumehud.rb

Signing mode:
  $SIGNING_MODE
EOF
