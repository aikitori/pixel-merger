#!/usr/bin/env python3
"""Erzeugt das App-Icon: Ritter und Magier aus dem Spiel stehen sich auf dem Steinplatz der Arena gegenüber
und verschmelzen in einem goldenen Merge-Blitz (Ritter + Magier ergibt im Spiel den Paladin).
Nur Standardbibliothek, nutzt die Dungeon-Crawl-Figuren und -Kacheln (sprite_dcss, tiles_dcss).

Aufruf (aus dem Projektordner):  python3 tools/generate_icon.py
Schreibt:
  icon.png                              Projekt-Icon (192 px, auch Fenster/Editor)
  assets/icon/icon_192.png              klassisches Android-Icon mit abgerundeten Ecken
  assets/icon/adaptive_foreground.png   Android 8+: Vordergrund (432 px, Motiv in der sicheren Mitte)
  assets/icon/adaptive_background.png   Android 8+: Hintergrund (432 px)
  assets/icon/adaptive_monochrome.png   Android 13+: einfarbige Silhouette für Designsymbole
"""
from pathlib import Path

import pixel_image as pi
import sprite_dcss
import tiles_dcss
from pixel_image import Img

ROOT = Path(__file__).resolve().parent.parent
GOLD = (255, 217, 31)
WHITE = (255, 255, 255)


def background(n, wall_rows):
    """Steinplatz, oben eine Mauerreihe mit Fackel, Ränder dunkler."""
    img = Img(n, n)
    for gy in range(0, n, 32):
        for gx in range(0, n, 32):
            pi.paste(img, tiles_dcss.floor_tile(tiles_dcss.PLAZA_FLOOR[(gx // 32 + gy // 32) % 4]), gx, gy)
    for gx in range(0, n, 32):
        wall = sprite_dcss.tile(f'dungeon/wall/brick_gray_{(gx // 32) % 4}')
        pi.paste(img, pi.crop(wall, 0, 32 - wall_rows, 32, wall_rows), gx, 0)
    for x in range(n):
        img.set(x, wall_rows, (24, 20, 18, 255))
        for d in range(1, 6):
            tiles_dcss.darken(img, x, wall_rows + d, 0.6 + 0.07 * d)
    torch = sprite_dcss.tile('dungeon/wall/torches/torch_2')
    pi.paste(img, torch, n // 2 - 16, wall_rows - 30)
    for y in range(n):  # Vignette
        for x in range(n):
            dx, dy = (x + 0.5) / n - 0.5, (y + 0.5) / n - 0.5
            tiles_dcss.darken(img, x, y, 1.0 - min(0.55, (dx * dx + dy * dy) * 1.6))
    return img


def merge_layer(n, feet_y):
    """Ritter links, Magier rechts (gespiegelt), dazwischen der Merge-Blitz mit Leuchten."""
    img = Img(n, n)
    knight = sprite_dcss.LINE['knight']()
    mage = pi.flip(sprite_dcss.LINE['mage']())
    cx = n // 2
    burst_y = feet_y - 15
    radius = 20.0
    for y in range(n):
        for x in range(n):
            d = ((x + 0.5 - cx) ** 2 + (y + 0.5 - burst_y) ** 2) ** 0.5
            if d < radius:
                img.set(x, y, GOLD + (round(0.65 * (1 - d / radius) * 255),))
    pi.paste(img, knight, cx - 3 - knight.w, feet_y - knight.h)
    pi.paste(img, mage, cx + 3, feet_y - mage.h)
    _burst(img, cx, burst_y, 7)
    return img


def _burst(img, cx, cy, r):
    """Achtzackiger Stern: lange Strahlen gerade, kurze diagonal, weißer Kern."""
    gold = GOLD + (255,)
    for k in range(-r, r + 1):
        img.set(cx + k, cy, gold)
        img.set(cx, cy + k, gold)
    for k in range(-(r - 2), r - 1):
        img.set(cx + k, cy + k, gold)
        img.set(cx + k, cy - k, gold)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            img.set(cx + dx, cy + dy, WHITE + (255,))


def round_corners(img, radius):
    n = img.w
    out = img.copy()
    for y in range(n):
        for x in range(n):
            cx = radius if x < radius else (n - 1 - radius if x > n - 1 - radius else x)
            cy = radius if y < radius else (n - 1 - radius if y > n - 1 - radius else y)
            if (x - cx) ** 2 + (y - cy) ** 2 > radius ** 2:
                out.set(x, y, (0, 0, 0, 0))
    return out


def flat_icon(n):
    return pi.paste(background(n, 24), merge_layer(n, n - 4))


# Adaptiv: 72 Pixel, 6-fach = 432 px. Sichtbar ist je nach Launcher nur ein Kreis über die mittleren
# 66 % (rund 47 Pixel), das Motiv steht deshalb mittig darin.
ADAPTIVE_SIZE = 72


def main():
    # Klassisches Icon: 64 Pixel, 3-fach = 192 px
    icon = round_corners(pi.scale(flat_icon(64), 3), 28)
    pi.write_png(ROOT / 'assets/icon/icon_192.png', icon)
    pi.write_png(ROOT / 'icon.png', icon)
    n = ADAPTIVE_SIZE
    feet = n // 2 + 17
    pi.write_png(ROOT / 'assets/icon/adaptive_background.png', pi.scale(background(n, 20), 6))
    front = merge_layer(n, feet)
    pi.write_png(ROOT / 'assets/icon/adaptive_foreground.png', pi.scale(front, 6))
    # Designsymbole (Android 13+): nur die Form zählt, der Launcher färbt sie selbst ein.
    shape = pi.map_pixels(front, lambda c: (255, 255, 255, 255) if c[3] >= 200 else (0, 0, 0, 0))
    pi.write_png(ROOT / 'assets/icon/adaptive_monochrome.png', pi.scale(shape, 6))
    print('App-Icons geschrieben.')


if __name__ == '__main__':
    main()
