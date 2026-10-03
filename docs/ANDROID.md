# Android-APK bauen

Das Spiel wird als APK exportiert (Godot 4.4.1, ohne Gradle, arm64-v8a). Die Pipeline läuft
als GitHub Action, dasselbe Skript funktioniert lokal.

## Pipeline (GitHub Actions)

Datei: `.github/workflows/android.yml`

| Auslöser | Was passiert |
|---|---|
| Push auf `main`, Pull Request, manuell | Import, Smoke-Test der Spiellogik, signierte **Debug-APK** als Artifact `pixel-merger-debug-apk` (14 Tage) |
| Tag `v*` (z.B. `v0.2.0`) | zusätzlich eine mit deinem Keystore signierte **Release-APK**, angehängt an ein GitHub-Release |

Versionsname und -code: Bei Tags kommt der Name aus dem Tag (`v0.2.0` -> `0.2.0`), der Code ist
immer die Nummer des Workflow-Laufs. Ohne Tag bleibt der Name aus `export_presets.cfg`.

### Einmalig: Release-Keystore und Secrets

Den Release-Keystore einmal erzeugen und **sicher aufbewahren**. Geht er verloren, lassen sich
bereits installierte Versionen nicht mehr aktualisieren.

```bash
keytool -genkeypair -v -keystore pixel-merger-release.keystore -alias pixelmerger \
  -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 pixel-merger-release.keystore    # Ausgabe in die Zwischenablage
```

Im Repo unter Settings > Secrets and variables > Actions anlegen:

| Secret | Inhalt |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Ausgabe von `base64 -w0` |
| `ANDROID_KEYSTORE_USER` | Alias, im Beispiel `pixelmerger` |
| `ANDROID_KEYSTORE_PASSWORD` | Passwort des Keystores (Store- und Key-Passwort müssen gleich sein) |

Den Keystore selbst nie ins Repo einchecken (`*.keystore` steht in `.gitignore`).

Release auslösen:

```bash
git tag v0.1.11 && git push origin v0.1.11
```

## Lokal bauen

```bash
tools/install_godot.sh                 # Godot 4.4.1 + Android-Templates (Prüfsumme wird geprüft)
export ANDROID_HOME=~/Android/Sdk      # SDK mit platform-tools, build-tools;35.0.1, platforms;android-35
export JAVA_HOME=/pfad/zu/jdk-17       # JDK (nicht nur JRE): javac muss existieren
tools/build_android.sh debug           # -> build/pixel-merger-debug.apk
```

Release lokal: `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_USER`, `ANDROID_KEYSTORE_PASSWORD`
setzen und `tools/build_android.sh release` ausführen. Optional `VERSION_NAME` und `VERSION_CODE`.

Aufs Handy: `adb install -r build/pixel-merger-debug.apk` (USB-Debugging am Gerät aktivieren)
oder die APK direkt aufs Gerät kopieren und öffnen.

## Wichtig zu wissen

- **Paketname:** `com.aikitori.pixelmerger` in `export_presets.cfg`. Vor der ersten
  Veröffentlichung nach Wunsch ändern, danach nicht mehr (er identifiziert die App).
- **Play Store:** Dafür braucht es ein AAB statt APK und ein aktuelles Target-SDK. Das geht nur
  mit Gradle-Build (`gradle_build/use_gradle_build`, Android-Build-Template, NDK) und ist hier
  **nicht** eingerichtet. Diese Pipeline erzeugt APKs zum Testen und Verteilen außerhalb des
  Stores.
- **Projekteinstellung `textures/vram_compression/import_etc2_astc=true`** in `project.godot`
  ist Pflicht für Mobile-Exporte. Ohne sie bricht der Export mit einer leeren Fehlermeldung ab.
- Nicht ins Spiel gepackt werden `tools/`, `docs/`, `scenes/dev/` und `scripts/dev/`
  (`exclude_filter` in `export_presets.cfg`).
- Das Android-Icon ist noch das Godot-Standard-Icon (`launcher_icons/*` leer).

## Fehlersuche

- *"Cannot export project ... due to configuration errors"* ohne Text: Projekteinstellung
  oben prüfen. Mit Text: meist fehlt JDK (`javac`), SDK-Paket oder Debug-Keystore.
- Godot beendet sich bei manchen Fehlern mit Exit-Code 0. Das Skript prüft deshalb, ob die APK
  wirklich entstanden ist.
