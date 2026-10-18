"""Arenen aus Dungeon-Crawl-Kacheln (CC0), schräg von oben gesehen: Mauern mit sichtbarer Vorderseite,
Tore an den Stellen, an denen Gegner erscheinen, erhöhter Steinplatz in der Mitte.

Die Grundrisse (LAYOUTS) sind die inhaltliche Wahrheit für Bild und Spiel: write_gd() schreibt daraus
scripts/arena_layouts.gd (begehbare Rechtecke, Spawn-Strecken, feste Hindernisse), World liest sie dort.

- Normale Runden: Kreuz, der Stil wechselt mit der Geländestufe (nach jedem Boss): CROSS_THEMES.
- Bossrunden (5, 15, 25, ...): reihum BOSS_LAYOUTS, keine Kreuzform.
"""
import math
from pathlib import Path

import pixel_image as pi
from pixel_image import Img
from sprite_dcss import tile

W, H = 640, 360
FIELD_TOP, FIELD_BOTTOM = 24, 320
CENTER = (320, 172)
PLAZA = (252, 106, 388, 240)  # Steinplatz: CENTER_SQUARE in world.gd plus 4 Pixel
WALL_FRONT = 30   # Höhe der sichtbaren Mauerfront über dem Boden
PARAPET = 7       # Zinnen am unteren Rand (Mauer zeigt vom Betrachter weg)
CLIFF = 34        # Felswand unter dem Boden beim Abgrund
PLAZA_STEP = 6    # Vorderkante des erhöhten Platzes

# Begehbare Fläche: Fußpunkte halten Abstand zu Mauern links/rechts (Köpfe) und oben (Front).
INSET_SIDE, INSET_TOP, INSET_FIELD_TOP = 6, 8, 14

# Arme in der Reihenfolge von World.Arm: WEST, NORTH, EAST, SOUTH. Spawn: Strecke (x0, y0, x1, y1).
LAYOUTS = {
    # Kreuz: zwei Arme, Gegner aus allen vier Richtungen
    'cross': {
        'floor': [(0, 102, 640, 140), (250, 24, 140, 296)],
        'spawn': [(2, 110, 2, 242), (256, 40, 384, 40), (638, 110, 638, 242), (256, 318, 384, 318)],
        'gates': {'west': 'side', 'east': 'side', 'north': 'arch_top', 'south': 'stairs'},
        'edge': 'wall',
    },
    # Thronsaal: eine große Halle, Säulenreihen, Tor in der Rückwand, Seitengänge
    'hall': {
        'floor': [(24, 58, 592, 262), (0, 146, 44, 52), (596, 146, 44, 52)],
        'spawn': [(2, 154, 2, 198), (296, 68, 344, 68), (638, 154, 638, 198), (260, 318, 380, 318)],
        'gates': {'west': 'side', 'east': 'side', 'north': 'arch_front', 'south': 'stairs'},
        'edge': 'wall',
        'carpet': True,
        'obstacles': [(96, 106, 'pillar'), (190, 106, 'pillar'), (450, 106, 'pillar'), (544, 106, 'pillar'),
                      (96, 284, 'pillar'), (190, 284, 'pillar'), (450, 284, 'pillar'), (544, 284, 'pillar')],
    },
    # Abgrund: schmale Brücke durch die Mitte, Plattform, Portale oben und unten auf der Plattform
    'chasm': {
        'floor': [(0, 140, 640, 64), (192, 46, 256, 254)],
        'spawn': [(2, 148, 2, 204), (296, 62, 344, 62), (638, 148, 638, 204), (296, 294, 344, 294)],
        'gates': {'west': 'side', 'east': 'side', 'north': 'portal', 'south': 'portal'},
        'edge': 'chasm',
        'obstacles': [(216, 84, 'ruin'), (424, 84, 'ruin'), (216, 284, 'ruin'), (424, 284, 'ruin')],
    },
    # Rundarena: Achteck aus drei Rechtecken, vier Tore
    'ring': {
        'floor': [(40, 112, 560, 120), (96, 64, 448, 216), (176, 24, 288, 296), (0, 146, 64, 52), (576, 146, 64, 52)],
        'spawn': [(2, 154, 2, 198), (256, 40, 384, 40), (638, 154, 638, 198), (256, 318, 384, 318)],
        'gates': {'west': 'side', 'east': 'side', 'north': 'arch_top', 'south': 'stairs'},
        'edge': 'wall',
        'obstacles': [(140, 90, 'pillar'), (500, 90, 'pillar'), (140, 258, 'pillar'), (500, 258, 'pillar')],
    },
}
BOSS_LAYOUTS = ['hall', 'chasm', 'ring']

# Stil: Mauerfront, Mauerkrone, Boden, Schmuck an der Front, Helligkeit des Bodens
THEMES = {
    'gray': {'face': [f'stone_brick_{n}' for n in (1, 2, 3, 4, 5)], 'crown': [f'brick_gray_{n}' for n in range(4)],
             'floor': 'grass', 'deco': ['torch', 'banner']},
    'brown': {'face': [f'brick_brown_{n}' for n in range(4)], 'crown': [f'brick_brown_{n}' for n in range(4)],
              'floor': 'grass', 'deco': ['torch']},
    'vines': {'face': [f'brick_brown-vines_{n}' for n in (1, 2, 3, 4)], 'crown': ['wall_vines_1', 'wall_vines_3'],
              'floor': 'flowers', 'deco': ['torch']},
    'marble': {'face': [f'marble_wall_{n}' for n in (1, 2, 3, 4)], 'crown': [f'marble_wall_{n}' for n in (1, 2, 3, 4)],
               'floor': 'grass', 'deco': ['banner', 'torch']},
    'relief': {'face': [f'relief_{n}' for n in range(4)], 'crown': [f'relief_{n}' for n in range(4)],
               'floor': 'dark', 'deco': ['torch']},
    'church': {'face': [f'church_{n}' for n in range(4)], 'crown': [f'church_{n}' for n in range(4)],
               'floor': 'stone', 'deco': ['banner', 'torch']},
    'cliff': {'face': [f'brick_gray_{n}' for n in range(4)], 'crown': [f'brick_gray_{n}' for n in range(4)],
              'floor': 'stone', 'deco': []},
    'arena': {'face': [f'stone_brick_{n}' for n in (1, 2, 3, 4, 5)], 'crown': [f'relief_{n}' for n in range(4)],
              'floor': 'dirt', 'deco': ['banner', 'torch']},
}
CROSS_THEMES = ['gray', 'brown', 'vines', 'marble', 'relief']
BOSS_THEMES = {'hall': 'church', 'chasm': 'cliff', 'ring': 'arena'}

GRASS = ['grass/grass_0_new', 'grass/grass_1_new', 'grass/grass_2_new', 'grass/grass_0_new', 'grass/grass_1_new',
         'grass/grass_2_new', 'grass/grass_flowers_yellow_1_new', 'grass/grass_flowers_blue_2_new',
         'grass/grass_flowers_red_3_new']
FLOWERS = ['grass/grass_flowers_yellow_1_new', 'grass/grass_flowers_blue_2_new', 'grass/grass_flowers_red_3_new',
           'grass/grass_0_new', 'grass/grass_1_new']
STONE = ['limestone_0', 'limestone_1', 'limestone_2', 'limestone_3', 'limestone_5', 'limestone_8']

INK = (24, 20, 18, 255)


def _hash(*v):
    h = 2166136261
    for x in v:
        h = ((h ^ (x & 0xffffffff)) * 16777619) & 0xffffffff
    return h


def _shade(c, f):
    return (max(0, min(255, round(c[0] * f))), max(0, min(255, round(c[1] * f))), max(0, min(255, round(c[2] * f))), 255)


class Tex:
    """Kacheln im 32er-Raster, Variante je Rasterfeld."""

    def __init__(self, names, prefix='dungeon/wall/', adjust=None, salt=0):
        self.tiles = []
        for n in names:
            img = tile(prefix + n)
            if adjust:
                img = pi.adjust(img, *adjust)
            self.tiles.append(img)
        self.salt = salt

    def get(self, x, y):
        t = self.tiles[_hash(x // 32, y // 32, self.salt) % len(self.tiles)]
        return t.get(x % 32, y % 32)


def floor_tex(kind):
    if kind == 'grass':
        return Tex(GRASS, 'dungeon/floor/', (1.18, 1.05), 1)
    if kind == 'flowers':
        return Tex(FLOWERS, 'dungeon/floor/', (1.18, 1.05), 1)
    if kind == 'dark':
        return Tex(GRASS[:3], 'dungeon/floor/', (0.95, 0.8), 1)
    if kind == 'dirt':
        return Tex(['grass/grass_full_new'], 'dungeon/floor/', (1.1, 0.9), 1)
    return Tex(STONE, 'dungeon/floor/', (0.9, 0.8), 2)


class Shape:
    def __init__(self, layout):
        self.rects = layout['floor']
        self.mask = bytearray(W * H)
        for x0, y0, w, h in self.rects:
            for y in range(max(0, y0), min(H, y0 + h)):
                for x in range(max(0, x0), min(W, x0 + w)):
                    self.mask[y * W + x] = 1

    def floor(self, x, y):
        return 0 <= x < W and 0 <= y < H and self.mask[y * W + x] == 1

    def wall(self, x, y):
        """Außerhalb des Bildes zählt links/rechts als Boden (Arme laufen hinaus), oben/unten als Mauer."""
        if x < 0 or x >= W:
            return not self.floor(min(max(x, 0), W - 1), y)
        return not self.floor(x, y)


def walk_rects(layout):
    out = []
    for x0, y0, w, h in layout['floor']:
        left = x0 + (INSET_SIDE if x0 > 0 else 0)
        right = x0 + w - (INSET_SIDE if x0 + w < W else 0)
        top = y0 + (INSET_FIELD_TOP if y0 <= FIELD_TOP else INSET_TOP)
        bottom = min(y0 + h, FIELD_BOTTOM)
        out.append((left, top, right - left, bottom - top))
    return out


# --- Zeichnen ----------------------------------------------------------------------------

def arena(name, theme_name):
    layout = LAYOUTS[name]
    theme = THEMES[theme_name]
    shape = Shape(layout)
    face = Tex(theme['face'], salt=7)
    crown = Tex(theme['crown'], salt=3)
    ground = floor_tex(theme['floor'])
    img = Img(W, H, [(14, 12, 18, 255)] * (W * H))
    chasm = layout['edge'] == 'chasm'
    for y in range(H):
        for x in range(W):
            if shape.floor(x, y):
                img.set(x, y, ground.get(x, y))
            elif chasm:
                img.set(x, y, _void(x, y))
            else:
                img.set(x, y, _shade(crown.get(x, y), 0.45))
    if chasm:
        _chasm_edges(img, shape, face)
    else:
        _floor_shadows(img, shape)
        _walls(img, shape, face)
    if layout.get('carpet'):
        _carpet(img, shape)
    _plaza(img, shape, theme)
    for arm, kind in layout['gates'].items():
        _gate(img, shape, layout, arm, kind, face)
    if not chasm:
        _decorate(img, shape, theme)
    return img


def _void(x, y):
    h = _hash(x, y, 99)
    if h % 397 == 0:
        return (120, 110, 160, 255)  # ferne Funken in der Tiefe
    d = 10 + (h >> 8) % 5
    return (d, d - 2, d + 8, 255)


def _floor_shadows(img, shape):
    """Schatten der Mauern auf dem Boden: Licht von oben links."""
    for y in range(H):
        for x in range(W):
            if not shape.floor(x, y):
                continue
            f = 1.0
            for d in range(1, 9):
                if shape.wall(x, y - d):
                    f *= 0.55 + 0.05 * d
                    break
            for d in range(1, 6):
                if shape.wall(x - d, y):
                    f *= 0.66 + 0.06 * d
                    break
            if f < 1.0:
                img.set(x, y, _shade(img.get(x, y), f))


def _walls(img, shape, face):
    fronts = []
    for x in range(W):
        for y in range(H - 1):
            # Mauer mit Boden darunter: sichtbare Vorderseite
            if shape.wall(x, y) and shape.floor(x, y + 1) and y + 1 < FIELD_BOTTOM:
                fronts.append((x, y))
    for x, y in fronts:
        for k in range(WALL_FRONT):
            yy = y - k
            if yy < 0 or shape.floor(x, yy):
                break
            f = 0.45 if k < 2 else 0.72 + 0.3 * k / WALL_FRONT
            img.set(x, yy, _shade(face.get(x, y - k), f))
        top = y - WALL_FRONT
        if top >= 0 and not shape.floor(x, top):
            img.set(x, top, (176, 172, 162, 255))
            if (x // 6) % 2 == 0:  # Zinnen
                for k in range(1, 5):
                    if top - k >= 0 and not shape.floor(x, top - k):
                        img.set(x, top - k, _shade(face.get(x, top - k), 1.05 if k < 4 else 1.25))
    for y in range(H):
        for x in range(W):
            if not shape.wall(x, y):
                continue
            # Zinnen am unteren Rand: Mauer mit Boden darüber
            if shape.floor(x, y - 1):
                for k in range(PARAPET):
                    if shape.wall(x, y + k):
                        solid = k >= 3 or (x // 6) % 2 == 0
                        if solid:
                            img.set(x, y + k, _shade(face.get(x, y + k), 1.2 if k == (0 if (x // 6) % 2 == 0 else 3) else 0.9))
                img.set(x, y + PARAPET, INK)
            # Seitenkanten: Mauer mit Boden links oder rechts (Krone von oben, helle Kante)
            elif shape.floor(x - 1, y) or shape.floor(x + 1, y):
                inward = 1 if shape.floor(x - 1, y) else -1
                for k in range(3):
                    if shape.wall(x + inward * k, y) and not _is_front(shape, x + inward * k, y):
                        on = k < 2 or (y // 6) % 2 == 0
                        if on:
                            img.set(x + inward * k, y, _shade(face.get(x + inward * k, y), 1.15 if k == 0 else 0.9))
                if not _is_front(shape, x + inward * 3, y):
                    img.set(x + inward * 3, y, INK)


def _is_front(shape, x, y):
    for k in range(WALL_FRONT + 1):
        if shape.floor(x, y + k + 1):
            return shape.wall(x, y + k)
        if not shape.wall(x, y + k):
            return False
    return False


def _chasm_edges(img, shape, face):
    for x in range(W):
        for y in range(H):
            if not shape.floor(x, y):
                continue
            # Felswand unter dem Boden
            if not shape.floor(x, y + 1):
                for k in range(CLIFF):
                    yy = y + 1 + k
                    if yy >= H or shape.floor(x, yy):
                        break
                    f = 0.85 - 0.7 * k / CLIFF
                    img.set(x, yy, _shade(face.get(x, yy), f))
                img.set(x, y, (196, 188, 170, 255))
            elif not shape.floor(x, y - 1):
                img.set(x, y, (210, 202, 186, 255))
            elif not shape.floor(x - 1, y) or not shape.floor(x + 1, y):
                if 0 < x < W - 1:
                    img.set(x, y, (170, 162, 146, 255))


def _plaza(img, shape, theme):
    x0, y0, x1, y1 = PLAZA
    stone = Tex(STONE if theme['floor'] != 'stone' else [f'marble_wall_{n}' for n in (1, 2, 3, 4)],
                'dungeon/floor/' if theme['floor'] != 'stone' else 'dungeon/wall/', salt=5)
    # Schatten rechts und vor der Stufe
    for y in range(y0 + 3, y1 + PLAZA_STEP + 3):
        for x in range(x0 + 3, x1 + 4):
            if (x >= x1 or y >= y1 + PLAZA_STEP) and shape.floor(x, y):
                img.set(x, y, _shade(img.get(x, y), 0.65))
    for y in range(y0, y1):
        for x in range(x0, x1):
            c = stone.get(x - x0 - 4, y - y0 - 6)
            if y == y0 or x == x0:
                c = _shade(c, 1.3)
            elif x == x1 - 1:
                c = _shade(c, 0.75)
            img.set(x, y, c)
    _rune_circle(img)
    # Vorderkante mit Treppe in der Mitte
    for k in range(PLAZA_STEP):
        y = y1 + k
        for x in range(x0, x1):
            if abs(x - CENTER[0]) < 20:
                c = _shade(stone.get(x, y + 40), 1.0 - 0.1 * (k // 2) if k % 2 == 0 else 0.55)
            else:
                c = _shade(stone.get(x, y + 40), 0.62 - 0.05 * k)
            img.set(x, y, c)
    for x in range(x0, x1):
        img.set(x, y1 + PLAZA_STEP, INK)


def _carpet(img, shape):
    """Roter Teppich vom Tor bis zur Treppe (Thronsaal)."""
    cx = CENTER[0]
    for y in range(H):
        for x in range(cx - 20, cx + 20):
            if not shape.floor(x, y):
                continue
            d = abs(x - cx + 0.5)
            if d > 18:
                c = INK
            elif d > 15:
                c = (214, 170, 72, 255) if (y // 3) % 2 == 0 or d < 17 else (150, 110, 40, 255)
            else:
                v = 1.0 if ((x - cx) // 4 + y // 4) % 2 == 0 else 0.86
                c = _shade((150, 34, 44, 255), v * (0.8 if (y + 2 * x) % 11 == 0 else 1.0))
            img.set(x, y, _shade(c, 0.75) if shape.wall(x, y - 1) or shape.wall(x, y - 4) else c)


def _rune_circle(img):
    cx, cy = CENTER
    for radius, color in ((56.0, (123, 230, 255, 255)), (48.0, (181, 131, 255, 255))):
        steps = int(math.tau * radius * 2)
        for i in range(steps):
            a = math.tau * i / steps
            if i % 9 < 6:
                img.set(int(cx + math.cos(a) * radius), int(cy + math.sin(a) * radius * 0.8), color)
    for i in range(8):
        a = math.tau * i / 8
        rx, ry = int(cx + math.cos(a) * 52), int(cy + math.sin(a) * 52 * 0.8)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                img.set(rx + dx, ry + dy, (255, 226, 122, 255))


def _gate(img, shape, layout, arm, kind, face):
    index = {'west': 0, 'north': 1, 'east': 2, 'south': 3}[arm]
    sx0, sy0, sx1, sy1 = layout['spawn'][index]
    if kind == 'side':
        # Dunkler Gang zum Bildrand, Pfeiler vorne
        left = arm == 'west'
        ys = [y for y in range(H) if shape.floor(0 if left else W - 1, y)]
        for y in ys:
            for d in range(48):
                x = d if left else W - 1 - d
                img.set(x, y, _shade(img.get(x, y), 0.12 + 0.88 * (d / 48) ** 0.8))
        post = range(0, 12) if left else range(W - 12, W)
        bottom = max(ys) + 1
        for x in post:
            for y in range(bottom, bottom + 12):
                img.set(x, y, _shade(face.get(x, y), 1.1 if y == bottom else 0.85))
            img.set(x, bottom + 12, INK)
    elif kind == 'stairs':
        # Treppe hinunter am unteren Rand
        x0, x1 = sx0 - 6, sx1 + 6
        stone = Tex(STONE, 'dungeon/floor/', salt=11)
        for y in range(FIELD_BOTTOM - 20, FIELD_BOTTOM):
            k = y - (FIELD_BOTTOM - 20)
            for x in range(x0, x1):
                if shape.floor(x, y):
                    f = 0.95 - 0.14 * (k // 4) if k % 4 else 0.35
                    img.set(x, y, _shade(stone.get(x, y), f))
    elif kind == 'arch_top':
        # Torbogen mit Fallgitter oben am Feldrand, Mauerfront um das Tor
        x0, x1 = sx0 - 6, sx1 + 6
        gx0, gx1, gy1 = CENTER[0] - 30, CENTER[0] + 30, FIELD_TOP + 18
        for y in range(FIELD_TOP - 4, gy1):
            for x in range(x0, x1):
                opening = gx0 + 4 <= x < gx1 - 4 and y > FIELD_TOP + 2 and \
                    (y > FIELD_TOP + 12 or (x - CENTER[0]) ** 2 + (y - FIELD_TOP - 12) ** 2 < 22 ** 2)
                if opening:
                    c = (95, 90, 85, 255) if (x - gx0) % 7 == 0 or (y - FIELD_TOP) % 7 == 0 else (12, 10, 10, 255)
                else:
                    c = _shade(face.get(x, y), 0.45 if y >= gy1 - 2 else 0.75 + 0.3 * (y - FIELD_TOP) / 18)
                img.set(x, y, c)
        for x in range(x0, x1):
            img.set(x, gy1, INK)
        _torch(img, gx0 - 26, FIELD_TOP - 6)
        _torch(img, gx1 - 6, FIELD_TOP - 6)
    elif kind == 'arch_front':
        # Tor in der Mauerfront über dem Boden
        edge = min(y for y in range(H) if shape.floor(CENTER[0], y))
        gx0, gx1 = CENTER[0] - 26, CENTER[0] + 26
        for y in range(edge - WALL_FRONT + 4, edge):
            for x in range(gx0, gx1):
                inside = y > edge - WALL_FRONT + 14 or (x - CENTER[0]) ** 2 + (y - (edge - WALL_FRONT + 14)) ** 2 < 26 ** 2
                if inside:
                    c = (95, 90, 85, 255) if (x - gx0) % 7 == 0 or (y - edge) % 7 == 0 else (12, 10, 10, 255)
                    img.set(x, y, c)
        for x in range(gx0 - 2, gx1 + 2):
            img.set(x, edge - 1, INK)
    elif kind == 'portal':
        cx, cy = (sx0 + sx1) // 2, sy0
        for ring, color in ((26, (90, 60, 160, 255)), (22, (170, 120, 255, 255)), (16, (60, 30, 110, 255))):
            for i in range(int(math.tau * ring * 2)):
                a = math.tau * i / (math.tau * ring * 2)
                img.set(int(cx + math.cos(a) * ring), int(cy + math.sin(a) * ring * 0.45), color)
        for y in range(cy - 8, cy + 8):
            for x in range(cx - 16, cx + 16):
                if ((x - cx) / 15.5) ** 2 + ((y - cy) / 7) ** 2 < 1:
                    img.set(x, y, _shade(img.get(x, y), 0.35))


def _torch(img, x, y):
    pi.paste(img, tile('dungeon/wall/torches/torch_2'), x, y)


def _decorate(img, shape, theme):
    """Fackeln und Banner auf geraden Stücken der Mauerfront."""
    deco = theme['deco']
    if not deco:
        return
    i = 0
    for x in range(36, W - 20, 72):
        for y in range(FIELD_TOP + WALL_FRONT - 2, FIELD_BOTTOM):
            if shape.wall(x, y) and shape.floor(x, y + 1):
                flat = all(shape.wall(xx, y) and shape.floor(xx, y + 1) and shape.wall(xx, y - WALL_FRONT)
                           for xx in range(x - 18, x + 18))
                if flat:
                    item = deco[i % len(deco)]
                    if item == 'torch':
                        _torch(img, x - 16, y - WALL_FRONT + 2)
                    else:
                        pi.paste(img, tile('dungeon/wall/banners/banner_1'), x - 16, y - WALL_FRONT + 1)
                    i += 1
                break


# --- Ausgabe -----------------------------------------------------------------------------

def images():
    """Alle Arenabilder: arena.png ist das erste Kreuz (auch Hintergrund im Menü)."""
    out = {}
    for i, theme in enumerate(CROSS_THEMES):
        out['arena' if i == 0 else f'arena_cross_{i}'] = arena('cross', theme)
    for name in BOSS_LAYOUTS:
        out[f'arena_{name}'] = arena(name, BOSS_THEMES[name])
    return out


def _rect(r):
    return 'Rect2(%d, %d, %d, %d)' % r


def write_gd(path):
    lines = [
        'class_name ArenaLayouts',
        '## Grundrisse der Arenen. Erzeugt von tools/arena_dcss.py, nicht von Hand ändern.',
        '## walk: begehbare Rechtecke (Fußpunkte). spawn: je Arm (WEST, NORTH, EAST, SOUTH) eine Strecke [von, bis].',
        '## obstacles: feste Hindernisse (nur Bossarenen), sonst verteilt World sie zufällig.',
        '',
        'const CROSS_TEXTURES: Array[String] = [',
    ]
    for i in range(len(CROSS_THEMES)):
        name = 'arena' if i == 0 else f'arena_cross_{i}'
        lines.append(f'\t"res://assets/sprites/tiles/{name}.png",')
    lines += [']', '', 'const BOSS_LAYOUTS: Array[StringName] = [%s]' % ', '.join(f'&"{n}"' for n in BOSS_LAYOUTS), '',
              'const LAYOUTS := {']
    for name, layout in LAYOUTS.items():
        lines.append(f'\t&"{name}": {{')
        lines.append('\t\t"walk": [%s],' % ', '.join(_rect(r) for r in walk_rects(layout)))
        lines.append('\t\t"spawn": [%s],' % ', '.join(
            f'[Vector2({s[0]}, {s[1]}), Vector2({s[2]}, {s[3]})]' for s in layout['spawn']))
        lines.append('\t\t"obstacles": [%s],' % ', '.join(
            f'{{"pos": Vector2({x}, {y}), "kind": "{k}"}}' for x, y, k in layout.get('obstacles', [])))
        texture = 'arena' if name == 'cross' else f'arena_{name}'
        lines.append(f'\t\t"texture": "res://assets/sprites/tiles/{texture}.png",')
        lines.append('\t},')
    lines.append('}')
    Path(path).write_text('\n'.join(lines) + '\n', encoding='utf-8')
