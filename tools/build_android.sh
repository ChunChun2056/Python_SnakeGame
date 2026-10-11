#!/usr/bin/env bash
# Builds Android APKs with Godot 4.4 export templates (no Gradle needed).
#
#   tools/build_android.sh debug     -> build/AdventureQuest-debug.apk
#   tools/build_android.sh release   -> build/AdventureQuest-release.apk
#
# Requirements: Godot 4.4.x on PATH as `godot` (or set GODOT=...), matching
# export templates installed, a JDK 17+, and an Android SDK whose
# build-tools contain apksigner (Android Studio's SDK works).
# Configure the SDK/JDK paths once in Godot: Editor > Editor Settings >
# Export > Android, or pass ANDROID_SDK / JAVA_HOME below.
#
# Release signing uses Godot's environment variables:
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH, GODOT_ANDROID_KEYSTORE_RELEASE_USER,
#   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
MODE="${1:-debug}"
mkdir -p build

# regenerate data so the build always matches the generators
python3 tools/gen_levels.py >/dev/null

"$GODOT" --headless --import >/dev/null 2>&1 || true
if [ "$MODE" = "release" ]; then
  : "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:?set to your release keystore}"
  : "${GODOT_ANDROID_KEYSTORE_RELEASE_USER:?set to the key alias}"
  : "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:?set to the keystore password}"
  "$GODOT" --headless --export-release Android build/AdventureQuest-release.apk
  OUT=build/AdventureQuest-release.apk
else
  "$GODOT" --headless --export-debug Android build/AdventureQuest-debug.apk
  OUT=build/AdventureQuest-debug.apk
fi
test -s "$OUT"
if command -v apksigner >/dev/null; then apksigner verify --verbose "$OUT" | head -5; fi
ls -lh "$OUT"
