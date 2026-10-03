# Pixel Merger

Pixel-2D-Handyspiel (Android/iOS) in Godot 4. Einheiten kaufen und zu stärkeren Kombinationen verbinden, inspiriert von der Warcraft-3-Map "Binders".

Spielidee und offene Fragen: [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md)

## Entwickeln

1. Godot 4.4 (Standard-Version, kein .NET) installieren.
2. `project.godot` im Godot-Projektmanager importieren und mit F5 starten.

Automatischer Test (spielt Runden durch, ohne Fenster):

```bash
godot --headless res://scenes/dev/smoke.tscn
```

## Struktur

```
assets/     Sprites, Audio, Fonts
scenes/     Szenen (.tscn)
scripts/    GDScript (autoload/ = globale Singletons, data/ = Resource-Klassen)
data/       Einheiten und Rezepte als .tres
docs/       Dokumentation
```

## Inhalte ändern

Namen, Werte, Kosten und Kombinationen stehen in `tools/content.py`. Danach neu erzeugen:

```bash
python3 tools/generate_data.py      # data/units und data/recipes
python3 tools/generate_sprites.py   # assets/sprites
python3 tools/generate_audio.py     # assets/audio (Effekte und Musik, ca. 15 s)
python3 tools/generate_icon.py      # App-Icon (icon.png, assets/icon)
```

## Sprites

Die Sprites werden aus ASCII-Rastern in `tools/generate_sprites.py` erzeugt (nur Python-Standardbibliothek):

```bash
python3 tools/generate_sprites.py            # schreibt assets/sprites/
python3 tools/generate_sprites.py --preview vorschau.png   # vergrößerte Übersicht
```

Sie sind nach rechts gezeichnet, Gegner werden im Spiel automatisch gespiegelt.

## Pixel-Art-Hinweise

- Sprites als PNG ablegen, Import-Preset "2D Pixel" ist bereits über die Projekteinstellungen (Nearest-Filter) abgedeckt.
- Basisauflösung 640x360; Sprites an ganzen Pixeln ausrichten.

## Android-APK

Pipeline und lokaler Build: siehe [docs/ANDROID.md](docs/ANDROID.md). Kurz: `tools/build_android.sh debug`
erzeugt `build/pixel-merger-debug.apk`; in GitHub Actions entsteht sie bei jedem Push, signierte
Release-APKs bei Tags `v*`.

## Export-Presets

`export_presets.cfg` (Android) liegt im Repo. Keystores und Passwörter gehören nie hinein: Sie kommen
über Umgebungsvariablen bzw. GitHub-Secrets (siehe [docs/ANDROID.md](docs/ANDROID.md)).

## Lizenz

GNU General Public License v3.0 (GPL-3.0-or-later), siehe [LICENSE](LICENSE).
Copyright (C) 2026 aikitori. Das gilt für Code und die erzeugten Sprites und Sounds.
Frühere Versionen (bis Alpha 0.1.8) wurden unter der MIT-Lizenz veröffentlicht.
