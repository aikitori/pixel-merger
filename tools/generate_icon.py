#!/usr/bin/env python3
"""Erzeugt das App-Icon: Ritter und Magier aus dem Spiel stürmen auf der schwebenden Insel vor dem
Dämmerhimmel aufeinander zu und verschmelzen in einem goldenen Merge-Blitz. Nur Standardbibliothek, nutzt Raster und Palette aus generate_sprites.py.

Aufruf (aus dem Projektordner):  python3 tools/generate_icon.py
Schreibt:
  icon.png                              Projekt-Icon (192 px, auch Fenster/Editor)
  assets/icon/icon_192.png              klassisches Android-Icon mit abgerundeten Ecken
  assets/icon/adaptive_foreground.png   Android 8+: Vordergrund (432 px, Motiv in der sicheren Mitte)
  assets/icon/adaptive_background.png   Android 8+: Hintergrund (432 px)
  assets/icon/adaptive_monochrome.png   Android 13+: einfarbige Silhouette für Designsymbole
"""
import random
import struct
import zlib
from pathlib import Path

import generate_sprites as gs

ROOT = Path(__file__).resolve().parent.parent

SKY_TOP = (23, 20, 70)
SKY_MID = (90, 45, 134)
SKY_LOW = (209, 105, 154)
GRASS = (79, 176, 74)
GRASS_DARK = (71, 163, 67)
GRASS_EDGE = (155, 227, 110)
CLIFF = (110, 75, 43)
CLIFF_LIP = (154, 116, 66)
CLIFF_DARK = (74, 48, 32)
GOLD = (255, 217, 31)
WHITE = (255, 255, 255)


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def canvas(n, fill=None):
    return [[fill for _ in range(n)] for _ in range(n)]


def put(img, x, y, color):
    if 0 <= y < len(img) and 0 <= x < len(img[0]):
        img[y][x] = color


def background(n, island_top):
    """Himmel mit Sternen, darunter die Grasinsel mit zackiger Felskante."""
    img = canvas(n)
    rng = random.Random(4)
    for y in range(n):
        t = y / (n - 1)
        c = lerp(SKY_TOP, SKY_MID, min(t * 1.6, 1.0)) if t < 0.62 else lerp(SKY_MID, SKY_LOW, (t - 0.62) / 0.38)
        for x in range(n):
            img[y][x] = c
    for _ in range(n // 3):
        put(img, rng.randrange(n), rng.randrange(island_top - 2), WHITE if rng.random() < 0.6 else (159, 232, 255))
    margin = n // 8
    bottom = island_top + n // 5
    for y in range(island_top, bottom):
        for x in range(margin, n - margin):
            checker = ((x // 3) + (y // 3)) % 2 == 0
            img[y][x] = GRASS_EDGE if y == island_top else (GRASS if checker else GRASS_DARK)
    for x in range(margin, n - margin):  # Felskante, unten zackig
        depth = 3 + (x * 7 % 5) + (2 if x % 4 == 0 else 0)
        for d in range(depth):
            put(img, x, bottom + d, CLIFF_LIP if d == 0 else (CLIFF if d < depth - 2 else CLIFF_DARK))
    return img


def merge_layer(n, feet_y, gap=3):
    """Merge-Motiv: Ritter (links, schaut nach rechts) und Magier (rechts, gespiegelt) laufen
    aufeinander zu, dazwischen ein goldener Merge-Blitz. Ritter + Magier ergibt im Spiel den Paladin."""
    img = canvas(n)
    knight = gs.parse(gs.KNIGHT)
    mage = [list(reversed(row)) for row in gs.parse(gs.MAGE)]
    size = len(knight)
    cx = n // 2
    burst_y = feet_y - size // 2 - 1
    # Leuchten hinter dem Blitz
    radius = size * 0.9
    for y in range(n):
        for x in range(n):
            d = ((x + 0.5 - cx) ** 2 + (y + 0.5 - burst_y) ** 2) ** 0.5
            if d < radius:
                img[y][x] = GOLD + (round(0.6 * (1 - d / radius) * 255),)
    # Bewegungslinien hinter den Figuren
    for side in (-1, 1):
        for k, (dy, length) in enumerate(((-4, 5), (0, 7), (4, 4))):
            start = cx + side * (gap + size + 2)
            for i in range(length):
                put(img, start + side * i, burst_y + dy, WHITE + (220 - 30 * i,))
    _paste(img, knight, cx - gap - size, feet_y - size)
    _paste(img, mage, cx + gap, feet_y - size)
    _burst(img, cx, burst_y, 5)
    for fx, fy, color in ((0.22, 0.2, WHITE), (0.78, 0.18, GOLD), (0.5, 0.12, WHITE)):
        x, y = round(n * fx), round(n * fy)
        for k in (-1, 0, 1):
            put(img, x + k, y, color + (255,))
            put(img, x, y + k, color + (255,))
    return img


def _paste(img, grid, left, top):
    for j, row in enumerate(grid):
        for i, ch in enumerate(row):
            if ch != '.':
                put(img, left + i, top + j, gs.hex_rgba(gs.PALETTE[ch]))


def _burst(img, cx, cy, r):
    """Achtzackiger Stern: lange Strahlen gerade, kurze diagonal, weißer Kern."""
    for k in range(-r, r + 1):
        put(img, cx + k, cy, GOLD + (255,))
        put(img, cx, cy + k, GOLD + (255,))
    for k in range(-(r - 2), r - 1):
        put(img, cx + k, cy + k, GOLD + (255,))
        put(img, cx + k, cy - k, GOLD + (255,))
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            put(img, cx + dx, cy + dy, WHITE + (255,))


def blend(base, layer):
    out = [row[:] for row in base]
    for y, row in enumerate(layer):
        for x, px in enumerate(row):
            if px is None:
                continue
            a = px[3] / 255
            b = out[y][x]
            out[y][x] = tuple(round(px[i] * a + b[i] * (1 - a)) for i in range(3))
    return out


def upscale(img, factor):
    out = []
    for row in img:
        wide = [px for px in row for _ in range(factor)]
        out.extend([wide[:] for _ in range(factor)])
    return out


def round_corners(img, radius):
    n = len(img)
    out = [list(row) for row in img]
    for y in range(n):
        for x in range(n):
            cx = radius if x < radius else (n - 1 - radius if x > n - 1 - radius else x)
            cy = radius if y < radius else (n - 1 - radius if y > n - 1 - radius else y)
            if (x - cx) ** 2 + (y - cy) ** 2 > radius ** 2:
                out[y][x] = None
    return out


def write_png(path, img):
    h, w = len(img), len(img[0])
    raw = bytearray()
    for row in img:
        raw.append(0)
        for px in row:
            if px is None:
                raw.extend((0, 0, 0, 0))
            elif len(px) == 4:
                raw.extend(px)
            else:
                raw.extend(px + (255,))

    def chunk(tag, data):
        body = tag + data
        return struct.pack('>I', len(data)) + body + struct.pack('>I', zlib.crc32(body) & 0xffffffff)

    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b'')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def flat_icon(n):
    island_top = round(n * 0.68)
    return blend(background(n, island_top), merge_layer(n, island_top + 1))


ADAPTIVE_SIZE = 72  # 6-fach = 432 px


def adaptive_island_top():
    return ADAPTIVE_SIZE // 2 + 8


def main():
    # Klassisches Icon: 48 Zeichen-Pixel, 4-fach = 192 px
    write_png(ROOT / 'assets/icon/icon_192.png', round_corners(upscale(flat_icon(48), 4), 28))
    # Projekt-Icon: dasselbe Bild
    write_png(ROOT / 'icon.png', round_corners(upscale(flat_icon(48), 4), 28))
    # Adaptiv: 72 Zeichen-Pixel, 6-fach = 432 px. Sichtbar ist je nach Launcher nur ein Kreis über
    # die mittleren 66 % (rund 47 Zeichen-Pixel), das Motiv steht deshalb mittig darin.
    n = ADAPTIVE_SIZE
    island_top = adaptive_island_top()
    write_png(ROOT / 'assets/icon/adaptive_background.png', upscale(background(n, island_top), 432 // n))
    write_png(ROOT / 'assets/icon/adaptive_foreground.png', upscale(merge_layer(n, island_top + 1), 432 // n))
    # Designsymbole (Android 13+): nur die Form zählt, der Launcher färbt sie selbst ein.
    shape = [[(255, 255, 255, 255) if px is not None and px[3] >= 200 else None for px in row]
             for row in merge_layer(n, island_top + 1)]
    write_png(ROOT / 'assets/icon/adaptive_monochrome.png', upscale(shape, 432 // n))
    print('App-Icons geschrieben.')


if __name__ == '__main__':
    main()
