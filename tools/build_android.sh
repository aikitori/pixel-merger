#!/usr/bin/env bash
# Baut die Android-APK.
# Nutzung: tools/build_android.sh [debug|release]   (Standard: debug)
#
# Voraussetzungen: godot im PATH (tools/install_godot.sh), Java (JDK 17+), Android SDK
# mit platform-tools, build-tools;35.0.1 und platforms;android-35 (ANDROID_HOME).
#
# debug:   signiert mit einem automatisch erzeugten Debug-Keystore.
# release: braucht ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_USER, ANDROID_KEYSTORE_PASSWORD.
# Optional: VERSION_NAME und VERSION_CODE überschreiben die Version aus export_presets.cfg.
set -euo pipefail

MODE="${1:-debug}"
case "$MODE" in debug | release) ;; *) echo "Modus muss debug oder release sein" >&2; exit 2 ;; esac

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
: "${ANDROID_HOME:?ANDROID_HOME muss auf das Android SDK zeigen}"
if [ -z "${JAVA_HOME:-}" ]; then
  JAVAC="$(command -v javac || true)"
  [ -n "$JAVAC" ] || { echo "Kein JDK gefunden (javac fehlt). JDK 17 installieren oder JAVA_HOME setzen." >&2; exit 1; }
  JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$JAVAC")")")"
fi
[ -x "$JAVA_HOME/bin/javac" ] || { echo "JAVA_HOME ($JAVA_HOME) ist kein JDK: bin/javac fehlt." >&2; exit 1; }

GODOT_MINOR="$(godot --version | cut -d. -f1,2)"  # z.B. 4.7: Name der Editor-Einstellungen hängt davon ab
SETTINGS="${XDG_CONFIG_HOME:-$HOME/.config}/godot/editor_settings-${GODOT_MINOR}.tres"
mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' > "$SETTINGS"

set_setting() {  # Editor-Einstellung setzen oder anlegen
  if grep -q "^$1 = " "$SETTINGS"; then
    sed -i "s|^$1 = .*|$1 = \"$2\"|" "$SETTINGS"
  else
    sed -i "/^\[resource\]/a $1 = \"$2\"" "$SETTINGS"
  fi
}
set_setting export/android/android_sdk_path "$ANDROID_HOME"
set_setting export/android/java_sdk_path "$JAVA_HOME"

if [ "$MODE" = "debug" ]; then
  DEBUG_KEYSTORE="${DEBUG_KEYSTORE:-$HOME/.local/share/pixel-merger/debug.keystore}"
  if [ ! -f "$DEBUG_KEYSTORE" ]; then
    mkdir -p "$(dirname "$DEBUG_KEYSTORE")"
    keytool -genkeypair -keystore "$DEBUG_KEYSTORE" -alias androiddebugkey \
      -storepass android -keypass android -keyalg RSA -keysize 2048 -validity 10000 \
      -dname "CN=Android Debug,O=Android,C=US"
  fi
  # Godot prüft beim Export die Editor-Einstellung, eine Umgebungsvariable allein reicht nicht.
  set_setting export/android/debug_keystore "$DEBUG_KEYSTORE"
  set_setting export/android/debug_keystore_user androiddebugkey
  set_setting export/android/debug_keystore_pass android
  export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$DEBUG_KEYSTORE"
  export GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey
  export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android
else
  : "${ANDROID_KEYSTORE_PATH:?für release fehlt ANDROID_KEYSTORE_PATH}"
  : "${ANDROID_KEYSTORE_USER:?für release fehlt ANDROID_KEYSTORE_USER}"
  : "${ANDROID_KEYSTORE_PASSWORD:?für release fehlt ANDROID_KEYSTORE_PASSWORD}"
  export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$ANDROID_KEYSTORE_PATH"
  export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$ANDROID_KEYSTORE_USER"
  export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$ANDROID_KEYSTORE_PASSWORD"
fi

# Versionsüberschreibungen gelten nur für diesen Build, die Datei im Repo bleibt unverändert.
PRESETS_BACKUP="$(mktemp)"
cp export_presets.cfg "$PRESETS_BACKUP"
trap 'cp "$PRESETS_BACKUP" export_presets.cfg; rm -f "$PRESETS_BACKUP"' EXIT
[ -z "${VERSION_CODE:-}" ] || sed -i "s|^version/code=.*|version/code=${VERSION_CODE}|" export_presets.cfg
[ -z "${VERSION_NAME:-}" ] || sed -i "s|^version/name=.*|version/name=\"${VERSION_NAME}\"|" export_presets.cfg

# Erster Import legt den Klassen-Cache an, ein zweiter fängt Abhängigkeiten ab.
"$GODOT" --headless --import > /dev/null 2>&1 || true
"$GODOT" --headless --import > /dev/null 2>&1 || true

OUT="build/pixel-merger-${MODE}.apk"
mkdir -p build
rm -f "$OUT"
"$GODOT" --headless "--export-${MODE}" "Android" "$OUT"

# Godot beendet sich bei manchen Fehlern mit Code 0, deshalb die Datei prüfen.
if [ ! -s "$OUT" ]; then
  echo "Export fehlgeschlagen: $OUT wurde nicht erzeugt" >&2
  exit 1
fi
echo "Fertig: $OUT ($(du -h "$OUT" | cut -f1))"
