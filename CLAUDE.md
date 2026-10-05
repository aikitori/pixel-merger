# Pixel Merger

Pixel-2D-Merge- und Auto-Battle-Spiel in **Godot 4.7.2** (GDScript), 640x360. Ziele: Android (Debug-APK als Alpha-Release), Browser (GitHub Pages). Sprache im Code und in der Oberfläche: Deutsch, Englisch per Übersetzung. Lizenz: GPL v3.

Spielidee und Regeln: `docs/GAME_DESIGN.md`. Android-Build und Signierung: `docs/ANDROID.md`.

## Inhalte werden generiert

Einheiten, Sprites, Sounds und Namen kommen aus Python-Skripten (nur Standardbibliothek). **Nie die erzeugten Dateien von Hand ändern**, sondern die Quelle und neu erzeugen.

| Quelle | Erzeugt |
|---|---|
| `tools/content.py` | Linien, Kombinationen, Fähigkeiten (die inhaltliche Wahrheit) |
| `tools/generate_data.py` | `data/*.tres`, `scripts/i18n/names_en.gd` |
| `tools/generate_sprites.py`, `tools/sprite_kits.py` | PNG-Sprites (ASCII-Raster plus Ausrüstungsteile je Stufe) |
| `tools/sprite_clonk.py`, `tools/sprite_styles.py` | Grundfiguren im Clonk-Stil und Höllenshooter-Look, die `generate_sprites.py` standardmäßig nutzt (`--classic` für die früheren Sprites) |
| `tools/generate_logo.py` | Titel-Logo `assets/logo/logo_doom.png` |
| `tools/generate_icon.py` | App-Icons (mit denselben Grundfiguren) |
| `tools/generate_audio.py` | Sound-Effekte |
| `tools/i18n_names.py` | Deutsch-Englisch-Wörterbuch aller Namen (jeder Name muss drinstehen, sonst bricht der Generator ab) |

Nach Änderungen: `python3 tools/generate_data.py` und/oder `python3 tools/generate_sprites.py`, dann `godot --headless --path . --import`.

## Aufbau

- Autoloads (Reihenfolge): `Game`, `Registry`, `Loc`, `Sound`, `Achievements` (`scripts/autoload/`).
- Hauptszene ist das Menü (`scenes/menu.tscn`), das Spiel `scenes/main.tscn` (`scripts/main.gd`, y-sortiert).
- Kampf: `scripts/combatant.gd`. Fähigkeiten: `scripts/abilities.gd` (Daten) plus `_cast_ability` im Combatant.
- Oberfläche: `scripts/hud.gd`, `recipe_book.gd`, `shop.gd`, `village.gd`, `ui_theme.gd` (im Code gezeichnet, Farben aus `art_style.gd`).
- Bildstil: `scripts/art_style.gd` (Oberflächenfarben, Logo, Auswahl) plus `shaders/art_style.gdshader` (Nachbearbeitung über das ganze Bild, von `Game` eingehängt). Standard ist `ArtStyle.DEFAULT`, er muss zu den erzeugten Sprites passen.
- Spielfeld: `scripts/world.gd` (Kreuz aus zwei Armen, Hindernisse, Kollision).
- Texte: deutsche Strings stehen im Code in `tr()` (statisch: `TranslationServer.translate`). Die englische Übersetzung steht in `scripts/i18n/ui_en.gd`. **Jeder neue deutsche Text braucht dort einen Eintrag**, der Schlüssel muss exakt dem deutschen Text entsprechen.

## Fallstricke

- **Browser hat keine Systemschrift.** Nur Zeichen aus Latein-1 plus Gedankenstrich und Mittelpunkt verwenden. Keine Symbole wie ★, ✕, ▼, Pfeile oder Emoji (erscheinen dort als Kästchen). Auf Android und Desktop fällt es nicht auf.
- **Web-Export ohne Threads** (läuft auf GitHub Pages). Beenden-Knopf ist im Browser ausgeblendet, Vollbild nur außerhalb von Android.
- **Headless-Läufe** bleiben Deutsch und speichern keine Erfolge.
- Dev-Tests setzen oft Positionen und Gold selbst. Startfiguren und Gegner sind zufällig verteilt: Tests dürfen nicht von Zufall abhängen (die CI war deshalb schon zweimal rot).
- Beim Löschen von Einheiten `discard()` verwenden, ein freigegebenes Objekt gilt in Godot 4 nicht als `null`: `is_instance_valid` prüfen.
- Versionsnummer: `project.godot` (`config/version`) und `export_presets.cfg` (`version/name`, `version/code`) müssen übereinstimmen, der Events-Test prüft das.

## Tests (alle ohne Fenster)

```bash
godot --headless res://scenes/dev/smoke.tscn        # Runden durchspielen, Spiellogik
godot --headless res://scenes/dev/input_test.tscn   # Eingabe: Kaufen, Ziehen, Merge, Befehle, Karten
godot --headless res://scenes/dev/anim_test.tscn    # Angriffe, alle Fähigkeiten (dauert 2-3 Minuten)
godot --headless res://scenes/dev/events_test.tscn  # Boss-/Bonusrunden, Erfolge, Gelände, Version
```

Ausgabe prüfen auf `... OK`, keine Zeilen mit `FAIL`, `SCRIPT ERROR` oder `ERROR`. Die CI (`.github/workflows/android.yml`) führt alle vier aus. Screenshots: `scenes/dev/shot.tscn` (braucht ein Fenster oder Xvfb).

## Release

1. Version in `project.godot` und `export_presets.cfg` erhöhen (Code +1), `docs/ANDROID.md` anpassen.
2. Events-Test laufen lassen, APK bauen: `ANDROID_HOME=~/.local/opt/android-sdk JAVA_HOME=~/.local/opt/jdk-17 tools/build_android.sh`, mit `aapt2 dump badging` die Version prüfen.
3. Committen, pushen, Tag **`alpha-X.Y.Z`** setzen und als Prerelease mit der Debug-APK anlegen (`gh release create`).
4. **Kein `v*`-Tag verwenden**: Der löst in der CI den signierten Release-Job aus, der Geheimnisse braucht.
5. Die Web-Version baut `.github/workflows/pages.yml` bei jedem Push auf `main` selbst: https://aikitori.github.io/pixel-merger/

## Konventionen

- Commits von `aikitori <88290076+aikitori@users.noreply.github.com>`, Nachrichten auf Deutsch, Zusammenfassung in einer Zeile.
- Nie Keystores, Passwörter oder Geheimnisse einchecken (`.gitignore` schließt `build/`, `*.keystore`, `*.jks` aus).
- Keine Modellnamen in Code, Dokumenten oder Release-Texten.
- Code-Kommentare auf Deutsch, knapp, nur wo das Warum nicht offensichtlich ist.
- Neue Funktionen in `docs/GAME_DESIGN.md` festhalten.
