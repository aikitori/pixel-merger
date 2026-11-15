# Pixel Merger

A 2D pixel-art merge and auto-battle game for Android and the browser, built with Godot 4.
Buy units, merge them into stronger combinations, then watch your army fight wave after wave of monsters.
Inspired by the Warcraft III custom map "Binders".

**[Play in the browser](https://aikitori.github.io/pixel-merger/)** (always the current state of `main`) ·
**[Download the Android alpha](https://github.com/aikitori/pixel-merger/releases)** (debug APK, tags `alpha-X.Y.Z`)

> Status: alpha. Expect rough edges and balance changes. The interface is German with an English translation.

## How it works

Every round has two phases:

1. **Build.** Spend gold on units and place them freely on the battlefield. Drag one unit onto another to merge
   them. A recipe always takes exactly two ingredients (order does not matter), and the result can itself be an
   ingredient, so combinations go several tiers deep: Knight + Horse = Mounted Rider, and so on.
2. **Battle.** The fight runs automatically within a fixed time window while monsters keep spawning. Survive until
   the timer ends to clear the round. Every kill earns gold for the next build phase.

You are not just a spectator, though: units can be given orders (hold, guard another unit, attack a target,
walk somewhere), and you can use their abilities.

### Features

- **23 unit lines and 100 combinations**, each with its own behavior, attack form, body type, ability and
  signature trait. The generators refuse to build two identical lines.
- **17 enemy types and 4 bosses** with their own abilities. Enemies scale with each round, and from round 8 some
  of them turn into elites.
- **Boss rounds with their own arenas**, and rewards (events) after them.
- **Secret recipes**, achievements and a high score that persist between runs; the current run is saved.
- **Strategy-game controls:** mouse (left select, right command, box select, control groups), keyboard
  shortcuts, and touch (tap, long press).
- **Fully animated** units: 16 frames each for idle, walk, attack and death.
- **Procedural audio** and CC0 sound effects.

The full rules and design notes live in [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) (German).

## Getting started

Requirements: [Godot 4.7](https://godotengine.org/download) (standard build, no .NET).

```bash
git clone https://github.com/aikitori/pixel-merger.git
cd pixel-merger
godot --path . --import   # first run only
godot --path .            # or open project.godot in the editor and press F5
```

Base resolution is 640x360 with nearest-neighbor filtering.

### Android

`tools/build_android.sh debug` produces `build/pixel-merger-debug.apk`. CI builds one on every push.
Setup, signing and release details: [docs/ANDROID.md](docs/ANDROID.md).

## Tests

All tests run headless:

```bash
godot --headless res://scenes/dev/smoke.tscn        # plays through rounds, game logic
godot --headless res://scenes/dev/input_test.tscn   # mouse, touch, keys, drag, merge, orders
godot --headless res://scenes/dev/anim_test.tscn    # attacks and all abilities (2-3 minutes)
godot --headless res://scenes/dev/units_test.tscn   # behaviors, attack forms, traits, strips
godot --headless res://scenes/dev/events_test.tscn  # bosses, bonus rounds, achievements, version
godot --headless res://scenes/dev/fuzz_test.tscn    # random input over many rounds
```

A passing run prints `... OK` and no `FAIL`, `SCRIPT ERROR` or `ERROR` lines.

## Project layout

```
assets/     sprites, audio, fonts (generated)
data/       units, recipes and enemies as .tres (generated)
docs/       game design, Android build
scenes/     scenes (.tscn), dev/ holds the tests
scripts/    GDScript (autoload/ singletons, data/ resource classes)
shaders/    full-screen post-processing
tools/      Python generators for all content
```

## Contributing

Units, sprites, sounds and names are **generated** by Python scripts (standard library only). Do not edit the
generated files by hand; change the source and regenerate:

| Source | Generates |
|---|---|
| `tools/content.py` | unit lines, combinations, abilities, traits |
| `tools/generate_data.py` | `data/*.tres`, English names |
| `tools/generate_sprites.py` | sprites, animation strips, arenas, village, UI images |
| `tools/generate_audio.py` | sound effects and music |

```bash
python3 tools/generate_data.py
python3 tools/generate_sprites.py
godot --headless --path . --import
```

Some art (arena textures, boss arenas, village, bosses, figures) was made with Stable Diffusion and is imported
once via `tools/import_sd.py`; that step needs ComfyUI and is not exactly reproducible.

Notes for contributors:

- Code comments and in-game text are German. Every new German string needs an English entry in
  `scripts/i18n/ui_en.gd`.
- The web build has no system font: use only Latin-1 characters (no emoji or symbols such as arrows or stars).
- Tests must not depend on randomness.
- Developer and architecture notes are in [CLAUDE.md](CLAUDE.md).

Issues and pull requests are welcome.

## License

Code, music and the self-made sounds: [GNU General Public License v3.0 or later](LICENSE),
Copyright (C) 2026 aikitori. Versions up to alpha 0.1.8 were released under the MIT license.

Third-party assets:

- Graphics are based on the [Dungeon Crawl Stone Soup tiles](https://opengameart.org/content/dungeon-crawl-32x32-tiles-supplemental)
  (CC0; thanks to the Crawl artists, see `tools/dcss/README.txt`). Arena textures, boss arenas, the village, the
  bosses and the other figures were drawn with Stable Diffusion, using the Crawl tiles as templates.
- Most sound effects come from [Kenney](https://kenney.nl) and the
  [512 Sound Effects (8-bit style)](https://opengameart.org/content/512-sound-effects-8-bit-style) pack by
  Juhani Junkala (both CC0, see `tools/sfx_cc0/README.txt`).
