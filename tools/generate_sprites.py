#!/usr/bin/env python3
"""Erzeugt die Pixel-Sprites (PNG) für Einheiten und Gegner.

Die Sprites sind als ASCII-Raster definiert, jedes Zeichen ist ein Palettenwert
('.' = transparent). Kombinierte Einheiten werden aus den Basis-Sprites zusammengesetzt
oder per Paletten-Tausch eingefärbt, damit alle Stufen zusammenpassen.

Standard sind Clonk-artige Grundfiguren (sprite_clonk) im Höllenshooter-Look (sprite_styles).
--classic erzeugt die früheren Sprites, --figures <name> und --style <name> wählen einzeln.

Aufruf (aus dem Projektordner):  python3 tools/generate_sprites.py
Nur Standardbibliothek, kein Pillow nötig. Mit --preview entsteht zusätzlich eine
vergrößerte Übersicht (preview.png, nicht im Repo).
"""
import struct
import sys
import zlib
from pathlib import Path

import content
import sprite_kits as kits
import sprite_clonk
import sprite_styles

ROOT = Path(__file__).resolve().parent.parent

PALETTE = {
    'k': '#24123a',  # Umriss (dunkles Violett statt Schwarz)
    'w': '#ffffff', 'W': '#b9d0ff',
    's': '#ffc79a', 'S': '#e8895e',  # Haut
    'g': '#dfe9ff', 'G': '#8aa4e8', 'd': '#4f5fb5',  # Stahl (bläulich)
    'r': '#ff3b4a', 'R': '#a8153f',
    'b': '#c97a2e', 'B': '#7a3f1a',  # Holz / Braun
    'y': '#ffd91f', 'Y': '#e08a00',
    'n': '#3fe05a', 'N': '#14953c',  # Grün
    'p': '#c04cff', 'P': '#6a1fb8',  # Violett
    'u': '#2f8cff', 'U': '#1b46c8',  # Blau
    'c': '#5ff2ff',
    'o': '#ff8a1f', 'O': '#d8480a',
    'h': '#e0954a', 'H': '#a65a24', 'm': '#5a2e1c',  # Pferd
    'l': '#8fe02e', 'L': '#4d9c14',  # Ork-Grün
    'e': '#fff0a8',
}
# Halbtransparente Leuchtfarben für Auren (Ziffern und 'a', siehe sprite_kits.GLOW)
for _char, _color in kits.GLOW.values():
    PALETTE[_char] = _color

KNIGHT = [
    "................",
    "......rr........",
    ".....krrk.......",
    "....kggggk......",
    "....kgGGgGk..w..",
    "....kgkkkkk..w..",
    "....kggggGk..w..",
    ".....kkggkk..w..",
    "..kkkgggggGkyyy.",
    ".kuuugggggGk.k..",
    ".kuyuggggGGk.k..",
    "..kkk.kGGGk.....",
    ".....kGgGGk.....",
    ".....kdk.kdk....",
    ".....kdk.kdk....",
    "....kkdk.kkdk...",
]

ARCHER = [
    "................",
    ".....kkkkk......",
    "....knnnnnk..b..",
    "...knnNNNnnk.wb.",
    "...knNssssNk.w.b",
    "...knNskskNk.w.b",
    "....kNsssSk..w.b",
    ".....kkssk...w.b",
    "...kkNnnnNkb.w.b",
    "..kBknnnnNnkbw.b",
    "..kBkNnnnNnkb..b",
    "...kk.kNNnk..wb.",
    ".....kNnNNk..b..",
    ".....kBk.kBk....",
    ".....kBk.kBk....",
    "....kkBk.kkBk...",
]

MAGE = [
    "................",
    "........p...ccc.",
    ".......pPp..ccc.",
    "......pPPPp..b..",
    ".....pPPyPPp.b..",
    "..kppppppppk.b..",
    "....kssssk...b..",
    "....kskSsk...b..",
    "....kwwwwk...b..",
    "...kppwwppk..b..",
    "...kpPpppPpk.b..",
    "...kppyyyppk.b..",
    "..kpPppppPpk.b..",
    "..kpPppppPpk.b..",
    "..kppppppppk.b..",
    "...kkkkkkkk..b..",
]

HEALER = [
    "............nnn.",
    ".....kkkk...nNn.",
    "....kwwwwk...b..",
    "...kwwwwwwk..b..",
    "...kwssssWk..b..",
    "...kwskskWk..b..",
    "....kssssk...b..",
    "...kkwwwwkk..b..",
    "..kwwwrrwwwk.b..",
    "..kwwrrrrwWk.b..",
    "..kwwwrrwwWk.b..",
    "..kwwwwwwwWk.b..",
    "..kwwwwwwwWk.b..",
    "..kWwwwwwWWk.b..",
    "...kkkkkkkk..b..",
    ".............b..",
]

HORSE = [
    "................kk....",
    "...............kHHk...",
    "..............kHHHHk..",
    "...kkkkkkkkk..kHhHHkk.",
    "..kmhhhhhhhhkkHhhhhhk.",
    ".kmmhhhhhhhhhhhhhkwhhk",
    ".kmhhhhhhhhhhhhhhhhhhk",
    "kmmhhhhhhhhhhhhhhhhhk.",
    "km.khhhhhhhhhhhhhhhk..",
    "k..kHHhhhhhhhhhhHHk...",
    "...kHkkHHHHHHkkHHk....",
    "...kHk.kHk..kHk.kHk...",
    "...kHk.kHk..kHk.kHk...",
    "...kkk.kkk..kkk.kkk...",
]

SLIME = [
    "............",
    "....kkkk....",
    "...knnnnk...",
    "..knnwnnnk..",
    "..knnnnnnk..",
    ".knnknnknnk.",
    ".knnnnnnnnk.",
    ".kNnnnnnnNk.",
    "..kNNNNNNk..",
    "...kkkkkk...",
]

GOBLIN = [
    "............",
    ".kk.kkkk.kk.",
    "kNNkNNNNkNNk",
    ".kNNNNNNNNk.",
    "..kNrNNrNk..",
    "..kNNkkNNk..",
    "...kkNNkk...",
    "..kbbbbbbk..",
    ".kNkbBBbkNk.",
    "..kkbbbbkk..",
    "...kbkkbk...",
    "...kNk.kNk..",
    "..kkNk.kNkk.",
    "............",
]

SKELETON = [
    "...kkkkkk...",
    "..kwwwwwwk..",
    "..kwkwwkwk..",
    "..kwwwwwwk..",
    "...kwkkwk...",
    "....kkkk..b.",
    "..kwwwwwk.bb",
    "..kwkkkkwkb.",
    "..kwwwwwwkb.",
    "...kkwwkk.b.",
    "...kwkkwk.b.",
    "...kwk.kwk..",
    "...kwk.kwk..",
    "...kwk.kwk..",
    "..kwwk.kwwk.",
    "..kkkk.kkkk.",
]

DWARF = [
    "................",
    "....kkkkkk......",
    "...kGGGGGGk.kk..",
    "...kGyyyyGk.kdk.",
    "...kssssssk.kdk.",
    "...kskssksk..b..",
    "..kRRsssRRk..b..",
    "..kRRRRRRRRk.b..",
    "..kRRRRRRRRk.b..",
    "..kkbbBBbbkk.b..",
    "..kbbbbbbbbk.b..",
    "..kkbbbbbbkk.b..",
    "...kBBkkBBk..b..",
    "...kBBk.kBBk.b..",
    "..kkBBk.kBBkk...",
    "..kkkkk.kkkkk...",
]

WOLF = [
    "............k.k.",
    "...........kGkGk",
    "..kkkkkkkkkGGGGk",
    ".kGGGGGGGGGGGrGk",
    "kGGGGGGGGGGGGGGk",
    "kGGGGGGGGGGGGkk.",
    ".kGGgggGGGGGk...",
    "..kGgggGGGGk....",
    "..kGkk.kGk.kGk..",
    "..kGk..kGk.kGk..",
    "..kdk..kdk.kdk..",
    "..kkk..kkk.kkk..",
]

DRAGON = [
    "....k..k........",
    "...kRk.kRk..kk..",
    "..kRRRkRRRk.kNk.",
    "..kRRRRRRRkkNNNk",
    ".kkNNNNNNNNNNyNk",
    "kNNNNNNNNNNNNNNk",
    "kNnnnnnnnNNNNkk.",
    ".kNnnnnnNNk.....",
    "..kNNNNNNNk.....",
    "..kNkkkkNk......",
    "..kNk..kNk......",
    "..kkk..kkk......",
]

FLAME = [
    ".....kk.....",
    "....kook....",
    "....koook...",
    "...kooook...",
    "..kooyook...",
    "..kooyyook..",
    ".kooyyyyook.",
    ".kooykyykok.",
    ".kooyyyyook.",
    ".krooyyoork.",
    "..krooooork.",
    "..kkroooorkk",
    "...kkrrrkk..",
    "....kkkk....",
]

DROP = [
    ".....kk.....",
    ".....kk.....",
    "....kuuk....",
    "....kuuk....",
    "...kuuuuk...",
    "..kuuuuuuk..",
    "..kuwcuuuk..",
    ".kuuwuuuuuk.",
    ".kuukuukuuk.",
    ".kuuuuuuuuk.",
    ".kUuuuuuuUk.",
    "..kUUuuuUUk.",
    "...kUUUUUk..",
    "....kkkkk...",
]

GOLEM = [
    "............",
    "...kkkkkk...",
    "..kggGGggk..",
    "..kgyGGygk..",
    "..kgGGGGgk..",
    ".kkkgGGgkkk.",
    "kggkGGGGkggk",
    "kgGkGggGkGgk",
    "kGGkGGGGkGGk",
    ".kkkGGGGkkk.",
    "...kGGGGGk..",
    "...kGGkGGk..",
    "...kdk.kdk..",
    "..kkdk.kdkk.",
]

SWIRL = [
    "..kkkkkkkk..",
    ".kwwwwwwwwk.",
    "kwwcwwwwcwwk",
    "kwwwkwwkwwwk",
    ".kcwwwwwwck.",
    "..kkkkkkkk..",
    "..kwwwwwwk..",
    "...kcwwwck..",
    "...kkkkkk...",
    "....kwwck...",
    "....kkkkk...",
    ".....kwck...",
    ".....kkk....",
]

EGG = [
    "....kk....",
    "...kwwk...",
    "..kwwwwk..",
    ".kwwnnwwk.",
    ".kwnwwnwk.",
    ".kwwwwwwk.",
    ".kwnnwwwk.",
    ".kwwwwwwk.",
    "..kwwwwk..",
    "...kkkk...",
]

ORC = [
    "................",
    "....kkkkkk......",
    "...kllllllk.....",
    "..kllllllllk....",
    "..klrllllrlk....",
    "..kllllllllk.k..",
    "..klwlkklwlk.kk.",
    "...kllllllk.kdk.",
    "..kkdddddkkkdgk.",
    ".klkdgddgdkbkk..",
    ".klkdddddd kbk..".replace(' ', 'd'),
    "..kkkdddddk.b...",
    ".....kdddk..b...",
    ".....klkklk.b...",
    ".....klk.klk....",
    "....kkLk.kLkk...",
]


PIXEL_SCALE = 2


def _rows(ch, x0, x1, y0, y1):
    return [(x, y, ch) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)]


def _wings(color, light):
    """Flügel links (2 Spalten) und rechts (1 Spalte) vom Körper, innen heller."""
    px = _rows(color, 0, 1, 5, 10) + _rows(color, 12, 12, 5, 10)
    return px + [(0, 4, color), (0, 11, color), (1, 6, light), (1, 7, light), (12, 7, light), (12, 8, light)]


HEAL_DECOR = {
    # Feldarzt: Stahlhelm und Schulterpanzer
    'field_medic': _rows('g', 4, 9, 2, 3) + [(3, 3, 'G'), (10, 3, 'G'), (4, 2, 'w'), (2, 8, 'g'), (11, 8, 'g'),
                                            (2, 9, 'G'), (11, 9, 'G'), (7, 1, 'r'), (7, 0, 'r')],
    'fairy': _wings('c', 'w') + [(1, 2, 'y'), (11, 1, 'w'), (2, 12, 'y'), (0, 13, 'w')],
    # Priester: goldene Mitra
    'priest': [(5, 0, 'k'), (6, 0, 'y'), (7, 0, 'y'), (8, 0, 'k'), (5, 1, 'Y'), (6, 1, 'y'), (7, 1, 'r'), (8, 1, 'Y'),
               (4, 1, 'k'), (9, 1, 'k')] + _rows('y', 4, 9, 7, 7),
    # Druide: Geweih mit Blättern
    'druid': [(3, 0, 'b'), (4, 1, 'b'), (3, 1, 'b'), (2, 0, 'n'), (10, 0, 'b'), (9, 1, 'b'), (10, 1, 'b'), (11, 0, 'n'),
              (3, 9, 'n'), (4, 10, 'n'), (3, 11, 'N')],
    # Quellnymphe: lange Wasserhaare und Tropfen
    'nymph': _rows('c', 2, 2, 3, 10) + _rows('c', 11, 11, 3, 10) + _rows('u', 1, 1, 6, 11) + _rows('u', 12, 12, 6, 11)
             + [(7, 0, 'c'), (7, 1, 'c'), (6, 1, 'w')],
    # Dryade: Blätterkrone und Ranken
    'dryad': [(4, 1, 'n'), (5, 0, 'n'), (6, 1, 'N'), (7, 0, 'n'), (8, 1, 'N'), (9, 0, 'n'), (10, 1, 'n'), (9, 11, 'n'),
              (10, 10, 'N'), (3, 8, 'n'), (2, 9, 'N'), (3, 10, 'n'), (6, 0, 'r')],
    # Pestdoktor: Schnabelmaske und breiter Hut
    'plague_doctor': _rows('k', 2, 11, 1, 1) + _rows('k', 4, 9, 2, 2) + _rows('e', 10, 12, 5, 5)
                     + [(11, 6, 'e'), (12, 6, 'e'), (12, 7, 'e'), (13, 5, 'k'), (13, 6, 'k'), (13, 7, 'k'), (6, 4, 'y'), (8, 4, 'y')],
    # Medizinmann: Federschmuck und Knochenkette
    'witch_doctor': [(3, 0, 'r'), (4, 0, 'r'), (5, 0, 'y'), (6, 0, 'y'), (7, 0, 'n'), (8, 0, 'n'), (9, 0, 'u'), (10, 0, 'u'),
                     (4, 1, 'r'), (6, 1, 'y'), (8, 1, 'n'), (9, 1, 'u'),
                     (4, 7, 'w'), (5, 8, 'w'), (6, 8, 'w'), (7, 8, 'w'), (8, 8, 'w'), (9, 7, 'w'), (7, 9, 'w')],
    # Engel: Halo und große Flügel
    'angel': _wings('w', 'W') + [(5, 0, 'y'), (6, 0, 'y'), (7, 0, 'y'), (8, 0, 'y'), (4, 1, 'Y'), (9, 1, 'Y')],
    # Silbereinhorn: goldenes Horn und rotes Kreuz an der Flanke, Mähne in Wasserblau
    'silver_unicorn': [(16, 0, 'y'), (17, 0, 'y'), (16, 1, 'Y'), (17, 1, 'y')] + [(1, 5, 'c'), (1, 6, 'c'), (2, 4, 'c'), (1, 7, 'u'), (0, 8, 'c')],
    # Asklepios: Bart und Schlangenstab
    'asclepius': [(5, 6, 'w'), (6, 6, 'w'), (7, 6, 'w'), (8, 6, 'w'), (6, 7, 'w'), (7, 7, 'w'),
                  (14, 3, 'n'), (12, 4, 'n'), (14, 5, 'n'), (12, 6, 'n'), (14, 7, 'N'), (12, 8, 'n'), (14, 9, 'N'), (12, 10, 'n'),
                  (14, 11, 'N'), (14, 2, 'n'), (13, 2, 'n')],
}


def hex_rgba(value):
    value = value.lstrip('#')
    alpha = int(value[6:8], 16) if len(value) == 8 else 255
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


def parse(rows, width=None):
    width = width or max(len(r) for r in rows)
    return [list(r.ljust(width, '.')) for r in rows]


def swap(grid, mapping):
    return [[mapping.get(c, c) for c in row] for row in grid]


def blank(w, h):
    return [['.'] * w for _ in range(h)]


def paste(canvas, grid, x, y, rows=None):
    """Legt grid auf canvas; rows begrenzt die Zeilenzahl (z.B. nur der Oberkörper)."""
    for j, row in enumerate(grid[:rows] if rows else grid):
        for i, c in enumerate(row):
            if c != '.' and 0 <= y + j < len(canvas) and 0 <= x + i < len(canvas[0]):
                canvas[y + j][x + i] = c


RIDER_Y = 0  # Höhe des Reiters über dem Pferd (je nach Grundfiguren, siehe use_figures)


# Sitzendes Bein über der Flanke (Seitenansicht), ab Zeile 11 des Reiters; P = Hosenfarbe des Reiters.
SEATED_LEG = ["....kPPPk", ".....kPPk", ".....kPk.", ".....kPk.", "....kBBk."]


def mounted(rider, horse, rider_rows=11, seated=True):
    canvas = blank(24, 24)
    paste(canvas, horse, 1, 10)
    paste(canvas, rider, 4, RIDER_Y, rider_rows)
    if RIDER_Y and seated:  # Clonk-Figuren: Oberkörper sitzt auf, das Bein hängt sichtbar über die Flanke
        legs = [c for row in rider[13:15] for c in row if c not in '.k']
        pants = max(set(legs), key=legs.count) if legs else 'B'
        leg = [[{'P': pants}.get(c, c) for c in row] for row in SEATED_LEG]
        paste(canvas, leg, 4, RIDER_Y + rider_rows)
    return canvas


def scale(grid, factor):
    out = []
    for row in grid:
        wide = [c for c in row for _ in range(factor)]
        out.extend([list(wide) for _ in range(factor)])
    return out


def to_rgba(grid):
    return [[(0, 0, 0, 0) if c == '.' else hex_rgba(PALETTE[c]) for c in row] for row in grid]


def write_png(path, grid, style=None, factor=1):
    """Schreibt das Zeichen-Raster; mit style (siehe sprite_styles) vorher umgewandelt."""
    if style:
        grid = sprite_styles.SHAPES[style](grid)
    rgba = to_rgba(grid)
    if style:
        rgba = sprite_styles.STYLES[style](rgba)
    if style:
        factor = sprite_styles.SCALE[style]
    if factor > 1:
        rgba = scale(rgba, factor)
    h, w = len(rgba), len(rgba[0])
    raw = bytearray()
    for row in rgba:
        raw.append(0)
        for px in row:
            raw.extend(px)

    def chunk(tag, data):
        body = tag + data
        return struct.pack('>I', len(data)) + body + struct.pack('>I', zlib.crc32(body) & 0xffffffff)

    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b'')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


# Paletten-Tausch pro Stufe (Stufe 1..5). Leeres Dict = Original-Sprite.
LINE_SPRITES = {
    'melee': (KNIGHT, [
        {'g': 'b', 'G': 'B', 'd': 'B', 'r': '.', 'w': 'b', 'u': 'B'},
        {'g': 'W', 'r': '.', 'u': 'B'},
        {},
        {'g': 'w', 'G': 'W', 'd': 'G', 'u': 'w', 'y': 'r'},
        {'g': 'd', 'G': 'U', 'd': 'k', 'r': 'y', 'u': 'U'},
    ]),
    'ranged': (ARCHER, [
        {'n': 'b', 'N': 'B', 'w': '.', 'b': '.'},
        {},
        {'n': 'l', 'N': 'L'},
        {'n': 'u', 'N': 'U'},
        {'n': 'r', 'N': 'R', 'b': 'y'},
    ]),
    'magic': (MAGE, [
        {'p': 'b', 'P': 'B', 'c': '.'},
        {},
        {'p': 'u', 'P': 'U', 'c': 'y'},
        {'p': 'r', 'P': 'R', 'c': 'o'},
        {'p': 'w', 'P': 'W', 'c': 'y', 'y': 'o'},
    ]),
    'cavalry': (HORSE, [
        {'h': 'e', 'H': 'h', 'm': 'h'},
        {},
        {'h': 'H', 'H': 'm', 'm': 'k'},
        {'h': 'W', 'H': 'G', 'm': 'd'},
        {'h': 'c', 'H': 'u', 'm': 'w'},
    ]),
}

# Linien mit wechselnden Grundformen: pro Stufe (Raster, Paletten-Tausch, Vergrößerung).
GRIDS = {
    'knight': KNIGHT, 'archer': ARCHER, 'mage': MAGE, 'horse': HORSE, 'dwarf': DWARF,
    'wolf': WOLF, 'dragon': DRAGON, 'flame': FLAME, 'drop': DROP, 'golem': GOLEM, 'swirl': SWIRL, 'egg': EGG, 'skeleton': SKELETON, 'healer': HEALER, 'goblin': GOBLIN, 'orc': ORC,
}
SKIN = {'n': 's', 'N': 'S'}
FREE_LINE_SPRITES = {
    'dwarf': [
        ('dwarf', {'G': 'B', 'd': 'B', 'y': 'Y', 'R': 'B'}, 1),
        ('dwarf', {'R': 'b'}, 1),
        ('dwarf', {}, 1),
        ('dwarf', {'G': 'y', 'y': 'w', 'R': 'W'}, 1),
        ('dwarf', {'G': 'y', 'd': 'Y', 'y': 'r', 'R': 'w'}, 1),
    ],
    'elf': [
        ('archer', {'n': 'L', 'N': 'N', 'w': '.'}, 1),
        ('archer', {'n': 'c', 'N': 'u'}, 1),
        ('archer', {'n': 'w', 'N': 'W', 'b': 'y'}, 1),
        ('archer', {'n': 'y', 'N': 'Y', 'b': 'y'}, 1),
        ('archer', {'n': 'p', 'N': 'P', 'b': 'y', 'w': 'y'}, 1),
    ],
    'undead': [
        ('skeleton', {}, 1),
        ('skeleton', {'w': 'n'}, 1),
        ('skeleton', {'w': 'W'}, 1),
        ('skeleton', {'w': 'u', 'k': 'k'}, 1),
        ('skeleton', {'w': 'p', 'b': 'y'}, 1),
    ],
    'dragon': [
        ('egg', {}, 1),
        ('dragon', {}, 1),
        ('dragon', {'N': 'r', 'n': 'o', 'R': 'O', 'y': 'y'}, 1),
        ('dragon', {'N': 'u', 'n': 'c', 'R': 'U'}, 1),
        ('dragon', {'N': 'y', 'n': 'w', 'R': 'o', 'y': 'r'}, 1),
    ],
    'witch': [
        ('mage', {'p': 'n', 'P': 'N', 'c': '.', 'y': '.'}, 1),
        ('mage', {'p': 'P', 'P': 'k', 's': 'n', 'S': 'N', 'c': 'n'}, 1),
        ('mage', {'p': 'p', 'P': 'k', 's': 'n', 'S': 'N', 'c': 'p'}, 1),
        ('mage', {'p': 'k', 'P': 'k', 's': 'n', 'S': 'N', 'c': 'r', 'y': 'r'}, 1),
        ('mage', {'p': 'r', 'P': 'R', 's': 'n', 'S': 'N', 'c': 'y', 'y': 'y'}, 1),
    ],
    'wolf': [
        ('wolf', {'G': 'W', 'g': 'w'}, 1),
        ('wolf', {}, 1),
        ('wolf', {'G': 'd', 'g': 'G'}, 1),
        ('wolf', {'G': 'B', 'g': 'b'}, 1),
        ('wolf', {'G': 'w', 'g': 'c', 'r': 'c'}, 2),
    ],
    'giant': [
        ('goblin', {'N': 'b', 'r': 'y'}, 1),
        ('orc', {'l': 'N', 'L': 'N'}, 1),
        ('orc', {'l': 's', 'L': 'S'}, 1),
        ('orc', {'l': 'S', 'L': 'B', 'r': 'y'}, 1),
        ('orc', {'l': 's', 'L': 'S', 'd': 'Y', 'g': 'y'}, 2),
    ],
    'fire': [
        ('flame', {'o': 'y', 'r': 'o'}, 1),
        ('flame', {}, 1),
        ('flame', {'o': 'r', 'r': 'R', 'y': 'o'}, 1),
        ('flame', {'o': 'u', 'r': 'U', 'y': 'c'}, 1),
        ('flame', {'o': 'y', 'r': 'o', 'y': 'w'}, 2),
    ],
    'water': [
        ('drop', {'u': 'c', 'U': 'u'}, 1),
        ('drop', {}, 1),
        ('drop', {'u': 'n', 'U': 'N'}, 1),
        ('drop', {'u': 'U', 'U': 'k', 'c': 'u'}, 1),
        ('drop', {'u': 'w', 'U': 'c', 'c': 'w'}, 2),
    ],
    'earth': [
        ('golem', {'G': 'b', 'g': 'h', 'd': 'B'}, 1),
        ('golem', {}, 1),
        ('golem', {'G': 'N', 'g': 'n', 'd': 'L'}, 1),
        ('golem', {'G': 'Y', 'g': 'y', 'd': 'O'}, 1),
        ('golem', {'G': 'c', 'g': 'w', 'd': 'u', 'y': 'r'}, 2),
    ],
    'air': [
        ('swirl', {}, 1),
        ('swirl', {'w': 'c', 'c': 'w'}, 1),
        ('swirl', {'w': 'G', 'c': 'g'}, 1),
        ('swirl', {'w': 'P', 'c': 'p'}, 1),
        ('swirl', {'w': 'y', 'c': 'w'}, 2),
    ],
    'healer': [
        ('healer', {'w': 'n', 'W': 'N', 'r': 'w', 'n': 'y', 'N': 'Y'}, 1),
        ('healer', {}, 1),
        ('healer', {'w': 'b', 'W': 'B', 'r': 'y', 'n': 'p', 'N': 'P'}, 1),
        ('healer', {'r': 'u', 'n': 'c', 'N': 'u'}, 1),
        ('healer', {'w': 'y', 'W': 'Y', 'r': 'w', 'n': 'w', 'N': 'e'}, 1),
    ],
    'centaur': [
        ('archer', {'n': 'B', 'N': 'B', 'w': '.', 'b': 'B'}, 1),
        ('archer', {'n': 'b', 'N': 'B', 'w': '.'}, 1),
        ('CENTAUR', {}, 1),
        ('CENTAUR', {'h': 'H', 'H': 'm', 'n': 'u'}, 1),
        ('CENTAUR', {'h': 'c', 'H': 'u', 'n': 'y'}, 1),
    ],
}


# Pferd-Tönung für höhere Stufen der Kombinationen.
COMBO_HORSE_TINT = [{}, {'h': 'H', 'H': 'm'}, {'h': 'm', 'H': 'k', 'm': 'y'}]


def build():
    """Alle Einheiten-Sprites: Grundform eingefärbt, dann Ausrüstung je Stufe (siehe sprite_kits)."""
    sprites = {}
    raw = {}      # Einheit -> Raster ohne Ausrüstung (Grundlage für Kombinationen)
    anchor = {}   # Einheit -> Ankerpunkte im rohen Raster
    factor_of = {}
    shape_of = {}  # Einheit -> Name der Grundform (für Anker und Umhang)
    line_of = {}
    for key, line in content.LINES.items():
        for uid in line['ids']:
            line_of[uid] = key

    for key, (base, swaps) in LINE_SPRITES.items():
        name = {'melee': 'knight', 'ranged': 'archer', 'magic': 'mage', 'cavalry': 'horse'}[key]
        grid = parse(base)
        for uid, mapping in zip(content.LINES[key]['ids'], swaps):
            raw[uid] = swap(grid, mapping)
            anchor[uid] = kits.anchor_for(name)
            factor_of[uid] = 1
            shape_of[uid] = name

    knight, archer, mage = parse(KNIGHT), parse(ARCHER), parse(MAGE)
    horse = parse(HORSE)
    centaur = mounted(swap(archer, SKIN), horse, seated=False)  # Zentaur: Oberkörper geht ins Pferd über
    for key, levels in FREE_LINE_SPRITES.items():
        for uid, (name, mapping, factor) in zip(content.LINES[key]['ids'], levels):
            grid = centaur if name == 'CENTAUR' else parse(GRIDS[name])
            raw[uid] = swap(grid, mapping)
            anchor[uid] = kits.anchor_for('archer', kits.MOUNTED_OFFSET) if name == 'CENTAUR' else kits.anchor_for(name)
            factor_of[uid] = factor
            shape_of[uid] = 'centaur' if name == 'CENTAUR' else name

    for key, line in content.LINES.items():
        for level, uid in enumerate(line['ids']):
            grid = kits.decorate(raw[uid], anchor[uid], kits.LINE_LEVEL_KITS[key][level])
            sprites[uid] = scale(grid, factor_of[uid]) if factor_of[uid] > 1 else grid

    white_horse = swap(horse, {'h': 'w', 'H': 'W', 'm': 'e'})
    gold = {'g': 'y', 'G': 'Y', 'd': 'Y', 'r': 'w', 'u': 'w'}
    paladin = swap(knight, gold)
    legend = swap(mounted(paladin, white_horse), {'y': 'o', 'Y': 'O', 'w': 'y', 'W': 'Y', 'e': 'o'})
    rider = kits.anchor_for('knight', kits.MOUNTED_OFFSET)
    hand = {
        'mounted_knight': (mounted(knight, horse), rider),
        'mounted_archer': (mounted(archer, horse), kits.anchor_for('archer', kits.MOUNTED_OFFSET)),
        'paladin': (paladin, kits.anchor_for('knight')),
        'holy_rider': (mounted(paladin, white_horse), rider),
        'legend': (legend, rider),
    }

    for base, combo in content.COMBOS.items():
        theme = combo.get('theme') or kits.HAND_THEME.get(base, 'gold')
        if base in hand:
            grid, combo_anchor = hand[base]
            factor = 1
            ingredient_kit = None
            cape = None
        else:
            source = combo['sprite_from']
            grid = swap(raw[source], combo['tint'])
            combo_anchor = anchor[source]
            factor = factor_of[source]
            other = combo['b'] if source == combo['a'] else combo['a']
            ingredient_kit = kits.LINE_KIT.get(line_of.get(other)) if other in line_of \
                else kits.THEME_KIT.get(content.COMBOS.get(other, {}).get('theme') or kits.HAND_THEME.get(other))
            # Umhang in der Hauptfarbe der zweiten Zutat, damit gleich eingefärbte Kombinationen auseinanderzuhalten sind
            cape = None
            if shape_of.get(source) in kits.HUMANOID and other in raw and ingredient_kit and not ingredient_kit.startswith('cape'):
                cape = 'cape:' + kits.dominant_color(raw[other], avoid=(kits.dominant_color(grid),))
        if base in HEAL_DECOR:  # eigene Merkmale der Heil-Kombinationen (Koordinaten im rohen Raster)
            grid = [row[:] for row in grid]
            for x, y, ch in HEAL_DECOR[base]:
                grid[y][x] = ch
        raw[base] = grid
        anchor[base] = combo_anchor
        factor_of[base] = factor
        shape_of[base] = shape_of.get(combo.get('sprite_from'), 'mounted')
        for level, uid in enumerate(content.combo_ids(base)):
            level_grid = swap(grid, COMBO_HORSE_TINT[level]) if base in ('mounted_knight', 'mounted_archer') else grid
            level_kits = kits.combo_level_kits(ingredient_kit, theme)[level]
            if cape and not any(k.startswith('cape') for k in level_kits):
                level_kits = [cape] + level_kits
            if base in content.SECRET_COMBOS and not any(k.startswith('sparkle') for k in level_kits):
                level_kits = level_kits + ['sparkle:gold']  # Geheimrezepte funkeln von Anfang an
            decorated = kits.decorate(level_grid, combo_anchor, level_kits)
            sprites[uid] = scale(decorated, factor) if factor > 1 else decorated

    ogre = swap(scale(parse(ORC), 2), {'l': 'b', 'L': 'B', 'k': 'k'})
    boss_tints = {
        'boss_ogre': (parse(ORC), {'l': 'h', 'L': 'H', 'r': 'y'}),
        'boss_dragon': (parse(DRAGON), {'N': 'r', 'n': 'o', 'R': 'O', 'y': 'y'}),
        'boss_bones': (parse(SKELETON), {'w': 'W', 'k': 'k', 'b': 'p'}),
        'boss_golem': (parse(GOLEM), {'G': 'u', 'g': 'c', 'd': 'U', 'y': 'r'}),
    }
    bosses = {}
    crown = ["y.y.y", "yyyyy", "YYYYY"]
    for uid, (grid, tint) in boss_tints.items():
        if uid in BOSS_GRIDS:
            bosses[uid] = scale(parse(BOSS_GRIDS[uid]), 2)
            continue
        art = [['.'] * len(grid[0]) for _ in range(len(crown))] + swap(grid, tint)
        top = next(y for y, row in enumerate(art) if y >= len(crown) and any(c != '.' for c in row))
        xs = [x for x, c in enumerate(art[top]) if c != '.']
        left = (xs[0] + xs[-1]) // 2 - len(crown[0]) // 2
        for j, row in enumerate(crown):
            for i, c in enumerate(row):
                if c != '.':
                    art[top - len(crown) + j][left + i] = c
        bosses[uid] = scale(art, 3)
    enemies = {
        'slime': parse(SLIME), 'goblin': parse(GOBLIN), 'bone_archer': parse(SKELETON),
        'orc': parse(ORC), 'ogre': ogre,
    }
    enemies.update(bosses)
    return sprites, enemies


BOSS_GRIDS = {}  # eigene Boss-Zeichnungen der gewählten Figuren (sonst Gegner mit Krone, 3-fach)


def use_figures(name):
    """Tauscht die Grundfiguren aus (siehe sprite_clonk). Die Listen werden an Ort und Stelle ersetzt,
    damit LINE_SPRITES und GRIDS, die auf dieselben Listen zeigen, die neuen Figuren sehen."""
    for var, grid in sprite_clonk.FIGURES[name].items():
        globals()[var][:] = grid
    BOSS_GRIDS.update(sprite_clonk.BOSS_FIGURES.get(name, {}))
    if name in sprite_clonk.RIDER_Y:
        global RIDER_Y
        RIDER_Y = sprite_clonk.RIDER_Y[name]
        kits.MOUNTED_OFFSET = (kits.MOUNTED_OFFSET[0], RIDER_Y)
    if name in sprite_clonk.DECOR:
        HEAL_DECOR.clear()
        HEAL_DECOR.update(sprite_clonk.DECOR[name])


# Stil des Spiels: Clonk-artige Figuren im Höllenshooter-Look (passend zu ArtStyle.DEFAULT).
# --classic erzeugt die früheren Sprites, --figures/--style wählen einzeln.
DEFAULT_FIGURES = 'clonk'
DEFAULT_STYLE = 'doom'


def option(name, default):
    if '--classic' in sys.argv:
        default = None
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def main():
    figures = option('--figures', DEFAULT_FIGURES)
    if figures:
        use_figures(figures)
    units, enemies = build()
    for old in (ROOT / 'assets/sprites/units').glob('*.png'):
        old.unlink()
    # Jedes Kunst-Pixel wird als PIXEL_SCALE x PIXEL_SCALE Block gespeichert (größere Pixel).
    style = option('--style', DEFAULT_STYLE)
    for name, grid in units.items():
        write_png(ROOT / 'assets/sprites/units' / f'{name}.png', grid, style, PIXEL_SCALE)
    for name, grid in enemies.items():
        write_png(ROOT / 'assets/sprites/enemies' / f'{name}.png', grid, style, PIXEL_SCALE)
    print(f'{len(units)} Einheiten und {len(enemies)} Gegner geschrieben.')

    if '--preview' in sys.argv:
        items = [scale(g, PIXEL_SCALE) for g in list(units.values()) + list(enemies.values())]
        per_row, cell_w, cell_h = 20, 70, 70
        rows = (len(items) + per_row - 1) // per_row
        sheet = blank(per_row * cell_w, rows * cell_h)
        for n, grid in enumerate(items):
            x = (n % per_row) * cell_w + 1
            y = (n // per_row) * cell_h + cell_h - 1 - len(grid)
            paste(sheet, grid, x, y)
        PALETTE['_'] = '#3b5a3a'
        bg = [['_' if c == '.' else c for c in row] for row in sheet]
        index = sys.argv.index('--preview') + 1
        target = Path(sys.argv[index]) if index < len(sys.argv) else ROOT / 'preview.png'
        write_png(target, scale(bg, 2))


if __name__ == '__main__':
    main()
