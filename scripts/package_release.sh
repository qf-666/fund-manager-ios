#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${1:-ZhihuFunds}"
DERIVED_DATA="${2:-build/DerivedData}"
ARTIFACT_BASENAME="${3:-$APP_NAME}"
OUTPUT_DIR="build/release"

APP_PATH="$(find "$DERIVED_DATA/Build/Products/Release-iphoneos" -type d -name "${APP_NAME}.app" | head -n 1)"
if [[ -z "$APP_PATH" ]]; then
  echo "Could not locate ${APP_NAME}.app in ${DERIVED_DATA}" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
PAYLOAD_DIR="$OUTPUT_DIR/Payload"
ARTIFACT_PATH="$OUTPUT_DIR/${ARTIFACT_BASENAME}.ipa"

rm -rf "$PAYLOAD_DIR"
mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_PATH" "$PAYLOAD_DIR/"
(cd "$OUTPUT_DIR" && /usr/bin/zip -qry "${ARTIFACT_BASENAME}.ipa" Payload)
rm -rf "$PAYLOAD_DIR"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "artifact=$ARTIFACT_PATH" >> "$GITHUB_OUTPUT"
fi

echo "$ARTIFACT_PATH"
