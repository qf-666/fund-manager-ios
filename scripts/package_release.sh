#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${1:-ZhihuFunds}"
DERIVED_DATA="${2:-build/DerivedData}"
OUTPUT_DIR="build/release"

APP_PATH="$(find "$DERIVED_DATA/Build/Products" -type d -name "${APP_NAME}.app" | head -n 1)"
if [[ -z "$APP_PATH" ]]; then
  echo "Could not locate ${APP_NAME}.app in ${DERIVED_DATA}" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
ARTIFACT_PATH="$OUTPUT_DIR/${APP_NAME}.app.zip"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ARTIFACT_PATH"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "artifact=$ARTIFACT_PATH" >> "$GITHUB_OUTPUT"
fi

echo "$ARTIFACT_PATH"
