#!/usr/bin/env python3
"""Erzeugt das Titel-Logo (Entwurf) für den Bildstil Höllenshooter: blockige Pixel-Buchstaben mit
3D-Kante, „PIXEL“ in Stahl, „MERGER“ in Feuerfarben. Die Wörter verschmelzen: Der Fuß des L geht in
das Bein des M über, die Farbe läuft über die Fuge von Stahl zu Feuer, an der Naht leuchtet es.

Aufruf (aus dem Projektordner):  python3 tools/generate_logo.py
Nur Standardbibliothek. Ausgabe: assets/logo/logo_doom.png
"""
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CELL = 5      # Kantenlänge eines Schrift-Pixels
EXTRUDE = 4   # Tiefe der 3D-Kante nach rechts unten

FONT = {
    'P': ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    'I': ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
    'X': ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
    'E': ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    'L': ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    'M': ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    'R': ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    'G': ["01111", "10000", "10000", "10111", "10001", "10001", "01111"],
}

STEEL = [(0xe8, 0xf0, 0xff), (0xb8, 0xc6, 0xd8), (0x8a, 0x98, 0xae), (0x5e, 0x6a, 0x80), (0x3c, 0x44, 0x56)]
FIRE = [(0xff, 0xf0, 0x7a), (0xff, 0xc0, 0x30), (0xf0, 0x7a, 0x18), (0xc8, 0x30, 0x10), (0x80, 0x12, 0x08)]
OUTLINE = (0x10, 0x08, 0x06)


def word_mask(text):
    """Pixelmaske eines Wortes (True = Buchstabe)."""
    w = len(text) * 6 * CELL - CELL
    h = 7 * CELL
    mask = [[False] * w for _ in range(h)]
    for n, ch in enumerate(text):
        for row, bits in enumerate(FONT[ch]):
            for col, bit in enumerate(bits):
                if bit == '1':
                    for y in range(CELL):
                        for x in range(CELL):
                            mask[row * CELL + y][n * 6 * CELL + col * CELL + x] = True
    return mask


def grain(x, y):
    return (((x * 73856093) ^ (y * 19349663)) % 1000) / 1000.0 - 0.5


def shade(color, f):
    return tuple(max(0, min(255, round(c * f))) for c in color)


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def draw(canvas, mask, ox, oy, blend_at):
    """Zeichnet die Maske; blend_at(x) gibt 0 (Stahl) bis 1 (Feuer) je Spalte."""
    h, w = len(mask), len(mask[0])
    for d in range(EXTRUDE, 0, -1):  # 3D-Kante: Maske versetzt nach rechts unten, dunkel
        for y in range(h):
            for x in range(w):
                if mask[y][x]:
                    deep = mix(STEEL[-1], FIRE[-1], blend_at(x))
                    canvas[oy + y + d][ox + x + d] = shade(deep, 0.55 - d * 0.04)
    for y in range(h):
        for x in range(w):
            if not mask[y][x]:
                continue
            band = min(len(STEEL) - 1, y * len(STEEL) // h)
            c = mix(STEEL[band], FIRE[band], blend_at(x))
            cx, cy = x % CELL, y % CELL
            f = 1.18 if cx == 0 or cy == 0 else 0.78 if cx == CELL - 1 or cy == CELL - 1 else 1.0
            canvas[oy + y][ox + x] = shade(c, f + grain(ox + x, oy + y) * 0.16)


def seam(canvas, mask, ox, oy, sx):
    """Leuchtende Naht an Spalte sx: helle Linie in der Schrift, weicher Schein daneben, Funken."""
    h = len(mask)
    for y in range(-6, h + EXTRUDE + 4):
        for dx in range(-6, 7):
            x = sx + dx
            if not (0 <= x < len(mask[0])):
                continue
            inside = 0 <= y < h and mask[y][x]
            px, py = ox + x, oy + y
            if inside and abs(dx) <= 1:
                canvas[py][px] = (0xff, 0xfa, 0xe0) if dx == 0 else (0xff, 0xe6, 0x9a)
            elif inside and abs(dx) <= 3:
                canvas[py][px] = mix(canvas[py][px], (0xff, 0xd8, 0x70), 0.5 - abs(dx) * 0.1)
            elif canvas[py][px] is None and -4 <= y < h + 3:
                alpha = round(100 * (1 - abs(dx) / 7) * (1 - max(0, -y, y - h) / 5))
                if alpha > 0:
                    canvas[py][px] = (0xff, 0xc8, 0x50, alpha)
    for fx, fy in ((-5, -5), (4, -8), (7, -3), (-8, h + 2), (5, h + 4), (0, -10)):
        x, y = ox + sx + fx, oy + fy
        for ddx, ddy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            canvas[y + ddy][x + ddx] = (0xff, 0xff, 0xe0)


def outline(canvas):
    h, w = len(canvas), len(canvas[0])
    out = [row[:] for row in canvas]
    for y in range(h):
        for x in range(w):
            if canvas[y][x] is None and any(
                    0 <= y + dy < h and 0 <= x + dx < w and canvas[y + dy][x + dx] is not None
                    and len(canvas[y + dy][x + dx]) == 3
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out[y][x] = OUTLINE
    return out


def write_png(path, canvas):
    raw = bytearray()
    for row in canvas:
        raw.append(0)
        for p in row:
            raw.extend((0, 0, 0, 0) if p is None else (p + (255,) if len(p) == 3 else p))

    def chunk(tag, data):
        body = tag + data
        return struct.pack('>I', len(data)) + body + struct.pack('>I', zlib.crc32(body) & 0xffffffff)

    h, w = len(canvas), len(canvas[0])
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b'')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def main():
    pixel, merger = word_mask('PIXEL'), word_mask('MERGER')
    # MERGER beginnt eine Schrift-Spalte vor dem Ende von PIXEL: Fuß des L und Bein des M teilen sich einen Block
    shift = len(pixel[0]) - CELL
    width = shift + len(merger[0])
    mask = [[(x < len(pixel[0]) and pixel[y][x]) or (x >= shift and merger[y][x - shift]) for x in range(width)]
            for y in range(len(pixel))]
    seam_x = shift + CELL // 2
    zone = 6 * CELL  # Breite des Farbübergangs zu jeder Seite der Naht

    def blend_at(x):
        t = max(0.0, min(1.0, (x - seam_x + zone) / (2 * zone)))
        return t * t * (3 - 2 * t)

    pad, top = 10, 12
    w = pad + width + EXTRUDE + pad
    h = top + 7 * CELL + EXTRUDE + 10
    canvas = [[None] * w for _ in range(h)]
    draw(canvas, mask, pad, top, blend_at)
    seam(canvas, mask, pad, top, seam_x)
    write_png(ROOT / 'assets/logo/logo_doom.png', outline(canvas))
    print(f'Logo {w}x{h} geschrieben.')


if __name__ == '__main__':
    main()
