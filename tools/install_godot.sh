#!/usr/bin/env bash
# Installiert Godot und die Android-Export-Templates (Prüfsumme wird kontrolliert).
# Nutzung: tools/install_godot.sh [Version]   (Standard: 4.4.1)
# Godot landet in ~/.local/opt/godot-<Version> mit Link ~/.local/bin/godot,
# die Templates in ~/.local/share/godot/export_templates/<Version>.stable.
set -euo pipefail

VERSION="${1:-4.4.1}"
BASE="https://github.com/godotengine/godot/releases/download/${VERSION}-stable"
BIN_DIR="$HOME/.local/opt/godot-${VERSION}"
TEMPLATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${VERSION}.stable"
ENGINE_ZIP="Godot_v${VERSION}-stable_linux.x86_64.zip"
TEMPLATE_ZIP="Godot_v${VERSION}-stable_export_templates.tpz"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

verify() {  # Datei gegen SHA512-SUMS.txt prüfen
  (cd "$WORK" && grep " $1\$" SHA512-SUMS.txt | sha512sum -c -)
}

curl -fsSL -o "$WORK/SHA512-SUMS.txt" "$BASE/SHA512-SUMS.txt"

if [ ! -x "$BIN_DIR/Godot_v${VERSION}-stable_linux.x86_64" ]; then
  curl -fsSL -o "$WORK/$ENGINE_ZIP" "$BASE/$ENGINE_ZIP"
  verify "$ENGINE_ZIP"
  mkdir -p "$BIN_DIR"
  unzip -q -o "$WORK/$ENGINE_ZIP" -d "$BIN_DIR"
fi
mkdir -p "$HOME/.local/bin"
ln -sf "$BIN_DIR/Godot_v${VERSION}-stable_linux.x86_64" "$HOME/.local/bin/godot"

# WITH_WEB=1: zusätzlich die Web-Templates (für den Browser-Export / GitHub Pages).
if [ ! -f "$TEMPLATE_DIR/android_release.apk" ] || { [ "${WITH_WEB:-0}" = 1 ] && [ ! -f "$TEMPLATE_DIR/web_nothreads_release.zip" ]; }; then
  curl -fsSL -o "$WORK/$TEMPLATE_ZIP" "$BASE/$TEMPLATE_ZIP"
  verify "$TEMPLATE_ZIP"
  # Nur die Android-Templates entpacken, der Rest (Windows, macOS, Web ...) wird nicht gebraucht.
  PATTERNS=('templates/android_*' 'templates/version.txt')
  [ "${WITH_WEB:-0}" = 1 ] && PATTERNS+=('templates/web_*')
  unzip -q -o "$WORK/$TEMPLATE_ZIP" "${PATTERNS[@]}" -d "$WORK"
  mkdir -p "$TEMPLATE_DIR"
  cp -f "$WORK"/templates/* "$TEMPLATE_DIR/"
fi

echo "Godot ${VERSION} installiert: $("$HOME/.local/bin/godot" --version)"
