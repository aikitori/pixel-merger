"""Arena, Dorf und Hindernisse aus Dungeon-Crawl-Kacheln (CC0), von oben gesehen wie die Figuren.

Erzeugt assets/sprites/tiles/: arena.png (ganzes Bild 640x360), village.png (Dorf 640x296) und
obstacle_<art>.png. Die Maße der Arena müssen zu scripts/world.gd passen (FIELD, CENTER, ARM_HALF_WIDTH),
die Häuser zu scripts/village.gd (HOUSES).
"""
import pixel_image as pi
from pixel_image import Img
from sprite_dcss import tile

W, H = 640, 360
FIELD_TOP, FIELD_BOTTOM = 24, 320
CENTER = (320, 172)
ARM = 70
PLAZA = (252, 106, 388, 240)  # CENTER_SQUARE plus 4 Pixel


def _hash(*v):
    h = 2166136261
    for x in v:
        h = ((h ^ (x & 0xffffffff)) * 16777619) & 0xffffffff
    return h


def floor_tile(name):
    img = tile(f'dungeon/floor/{name}')
    # Das Gras der Kacheln ist sehr dunkel, die Figuren heben sich auf hellerem Boden besser ab.
    return pi.adjust(img, 1.18, 1.05) if name.startswith('grass/grass_') and 'full' not in name else img


def _variant(names, gx, gy, salt=0):
    return names[_hash(gx, gy, salt) % len(names)]


def blit_clipped(dst, src, x0, y0, inside):
    for y in range(src.h):
        for x in range(src.w):
            c = src.px[y * src.w + x]
            if c[3] and inside(x0 + x, y0 + y):
                dst.set(x0 + x, y0 + y, pi.over(dst.get(x0 + x, y0 + y), c))


def darken(img, x, y, factor):
    c = img.get(x, y)
    img.set(x, y, (round(c[0] * factor), round(c[1] * factor), round(c[2] * factor), c[3]))


# --- Arena -----------------------------------------------------------------------------

def on_cross(x, y):
    in_h = CENTER[1] - ARM <= y < CENTER[1] + ARM
    in_v = CENTER[0] - ARM <= x < CENTER[0] + ARM and FIELD_TOP <= y < FIELD_BOTTOM
    return in_h or in_v


def on_plaza(x, y):
    return PLAZA[0] <= x < PLAZA[2] and PLAZA[1] <= y < PLAZA[3]


GRASS = ['grass/grass_0_new', 'grass/grass_1_new', 'grass/grass_2_new', 'grass/grass_0_new', 'grass/grass_1_new',
         'grass/grass_2_new', 'grass/grass_flowers_yellow_1_new', 'grass/grass_flowers_blue_2_new',
         'grass/grass_flowers_red_3_new']
PLAZA_FLOOR = ['limestone_0', 'limestone_1', 'limestone_2', 'limestone_3', 'limestone_5', 'limestone_8']
WALL = ['brick_gray_0', 'brick_gray_1', 'brick_gray_2', 'brick_gray_3', 'brick_gray_0', 'brick_gray_1',
        'wall_vines_1', 'wall_vines_3']


def arena():
    img = Img(W, H, [(20, 18, 16, 255)] * (W * H))
    ox, oy = CENTER[0] - 16, CENTER[1] - 16  # Raster so, dass ein Feld genau in der Mitte liegt
    for gy in range(-7, 7):
        for gx in range(-11, 11):
            x0, y0 = ox + gx * 32, oy + gy * 32
            blit_clipped(img, floor_tile(_variant(GRASS, gx, gy)), x0, y0, on_cross)
            blit_clipped(img, tile(f'dungeon/wall/{_variant(WALL, gx, gy, 3)}'), x0, y0,
                         lambda x, y: not on_cross(x, y))
            blit_clipped(img, floor_tile(_variant(PLAZA_FLOOR, gx, gy, 5)), x0, y0, on_plaza)
    _wall_edges(img)
    _rune_circle(img)
    # Fackeln an der Wand über und unter dem waagrechten Arm
    torch = tile('dungeon/wall/torches/torch_2')
    for x in (40, 136, 456, 552):
        pi.paste(img, torch, x, CENTER[1] - ARM - 30)
    for x in (88, 184, 424, 520):
        pi.paste(img, torch, x, CENTER[1] + ARM + 2)
    return img


def _wall_edges(img):
    """Dunkle Kante an der Wand und Schatten auf dem Boden unter und rechts von Wänden."""
    for y in range(FIELD_TOP, FIELD_BOTTOM):
        for x in range(W):
            if not on_cross(x, y):
                if on_cross(x, y + 1) or on_cross(x + 1, y) or on_cross(x - 1, y) or on_cross(x, y - 1):
                    img.set(x, y, (24, 20, 18, 255))
                continue
            for d in range(1, 9):  # Wand oberhalb wirft Schatten
                if not on_cross(x, y - d):
                    darken(img, x, y, 0.55 + 0.05 * d)
                    break
            for d in range(1, 5):
                if not on_cross(x - d, y):
                    darken(img, x, y, 0.7 + 0.06 * d)
                    break


def _rune_circle(img):
    import math
    for radius, color in ((56.0, (123, 230, 255, 255)), (48.0, (181, 131, 255, 255))):
        steps = int(math.tau * radius * 2)
        for i in range(steps):
            a = math.tau * i / steps
            if i % 9 < 6:
                img.set(int(CENTER[0] + math.cos(a) * radius), int(CENTER[1] + math.sin(a) * radius * 0.8), color)
    for i in range(8):
        a = math.tau * i / 8
        rx, ry = int(CENTER[0] + math.cos(a) * 52), int(CENTER[1] + math.sin(a) * 52 * 0.8)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                img.set(rx + dx, ry + dy, (255, 226, 122, 255))


# --- Hindernisse -----------------------------------------------------------------------

OBSTACLES = {
    'tree': lambda: tile('dungeon/trees/mangrove_1'),
    'crystal': lambda: tile('monster/statues/block_of_ice_2'),
    'ruin': lambda: tile('dungeon/statues/crumbled_column_1'),
    'rock': lambda: tile('dungeon/statues/granite_stump_new'),
}


# --- Dorf ------------------------------------------------------------------------------

VW, VH = 640, 296
# Wie village.gd HOUSES (dort halbe Koordinaten): Mitte x, Grundlinie y, Bauart.
HOUSES = [(110, 112, 'barracks'), (320, 112, 'guild'), (530, 112, 'fairy'),
          (130, 244, 'temple'), (510, 244, 'tower'), (320, 264, 'clinic')]
PATHS = [(98, 112, 24, 32), (308, 112, 24, 100), (308, 200, 24, 64), (518, 112, 24, 32),
         (98, 132, 432, 16), (118, 200, 384, 16), (118, 200, 24, 44), (498, 200, 24, 44)]
TREES = [(24, 48), (616, 48), (28, 192), (612, 192), (216, 60), (424, 60), (72, 280), (568, 280),
         (220, 272), (420, 272)]

BUILDINGS = {
    # Wand, Breite, Höhe (in Kacheln), Tür, Schmuck links/rechts der Tür, Wandschmuck
    'barracks': ('stone_brick_', 3, 2, 'dungeon/doors/closed_door', 'dungeon/statues/statue_sword', None,
                 'dungeon/wall/banners/banner_1'),
    'guild': ('brick_brown_', 3, 2, 'dungeon/shops/enter_shop', 'dungeon/chest', 'dungeon/large_box', None),
    'fairy': ('brick_brown-vines', 3, 2, 'dungeon/doors/runed_door', 'monster/fungi_plants/wandering_mushroom',
              'monster/fungi_plants/thorn_lotus', None),
    'temple': ('church_', 3, 2, 'dungeon/gateways/stone_arch', 'dungeon/statues/crumbled_column_3',
               'dungeon/altars/altar_shining_one', None),
    'tower': ('relief_', 2, 3, 'dungeon/doors/runed_door', 'dungeon/altars/altar_vehumet', None,
              'dungeon/wall/torches/torch_2'),
    'clinic': ('marble_wall_', 3, 2, 'dungeon/doors/closed_door', 'dungeon/altars/altar_elyvilon',
               'dungeon/sparkling_fountain', None),
}


def wall_tile(prefix, i):
    names = {'stone_brick_': [f'stone_brick_{n}' for n in (1, 2, 3, 4, 5)],
             'brick_brown_': [f'brick_brown_{n}' for n in (0, 1, 2, 3)],
             'brick_brown-vines': [f'brick_brown-vines_{n}' for n in (1, 2, 3, 4)],
             'church_': [f'church_{n}' for n in (0, 1, 2, 3)],
             'relief_': [f'relief_{n}' for n in (0, 1, 2, 3)],
             'marble_wall_': [f'marble_wall_{n}' for n in (1, 2, 3, 4)]}[prefix]
    return tile(f'dungeon/wall/{names[i % len(names)]}')


def village():
    img = Img(VW, VH)
    for gy in range(VH // 32 + 1):
        for gx in range(VW // 32):
            pi.paste(img, floor_tile(_variant(GRASS, gx, gy, 21)), gx * 32, gy * 32)
    dirt = floor_tile('grass/grass_full_new')
    for x0, y0, w, h in PATHS:
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                img.set(x, y, dirt.get(x % 32, y % 32))
    for x0, y0, w, h in PATHS:  # dunkle Wegkante
        for x in range(x0 - 1, x0 + w + 1):
            for y in (y0 - 1, y0 + h):
                if not any(px <= x < px + pw and py <= y < py + ph for px, py, pw, ph in PATHS):
                    darken(img, x, y, 0.6)
        for y in range(y0, y0 + h):
            for x in (x0 - 1, x0 + w):
                if not any(px <= x < px + pw and py <= y < py + ph for px, py, pw, ph in PATHS):
                    darken(img, x, y, 0.6)
    pi.paste(img, tile('dungeon/blue_fountain'), 304, 140)
    for x, y in TREES:
        pi.paste(img, tile(f'dungeon/trees/mangrove_{1 + (x + y) % 3}'), x - 16, y - 32)
    for cx, base, kind in HOUSES:
        _building(img, cx, base, kind)
    return img


def _building(img, cx, base, kind):
    prefix, tw, th, door, deco_left, deco_right, wall_deco = BUILDINGS[kind]
    x0, y0 = cx - tw * 16, base - th * 32
    # Schlagschatten rechts und unten
    for y in range(y0 + 4, base + 4):
        for x in range(x0 + 4, x0 + tw * 32 + 4):
            darken(img, x, y, 0.6)
    for j in range(th):
        for i in range(tw):
            pi.paste(img, wall_tile(prefix, i + j * 3 + cx), x0 + i * 32, y0 + j * 32)
    # Dachkante oben heller, Umriss
    for x in range(x0, x0 + tw * 32):
        img.set(x, y0, (220, 214, 200, 255))
        img.set(x, base - 1, (24, 20, 18, 255))
    for y in range(y0, base):
        img.set(x0, y, (24, 20, 18, 255))
        img.set(x0 + tw * 32 - 1, y, (24, 20, 18, 255))
    door_x = cx - 16
    pi.paste(img, tile(door), door_x, base - 32)
    if wall_deco:
        pi.paste(img, tile(wall_deco), x0, base - 32 - (32 if th > 2 else 0))
        if tw > 2:
            pi.paste(img, tile(wall_deco), x0 + (tw - 1) * 32, base - 32)
    if deco_left:
        pi.paste(img, tile(deco_left), x0 - 30, base - 30)
    if deco_right:
        pi.paste(img, tile(deco_right), x0 + tw * 32 - 2, base - 30)


# --- Oberfläche --------------------------------------------------------------------------
# 9-Patch-Bilder (Rand 4 Pixel) im Stil der Dungeon-Crawl-Reiter: Granit mit Gold- oder Stahlrand.

def _granite(brightness):
    fill = pi.crop(tile('gui/tabs/tab_selected'), 18, 3, 12, 12)
    # Wenig Kontrast, damit Schrift darauf lesbar bleibt
    mean = sum(sum(c[:3]) for c in fill.px) / (3 * len(fill.px))
    soft = pi.map_pixels(fill, lambda c: tuple(round(mean + (v - mean) * 0.4) for v in c[:3]) + (255,))
    return pi.adjust(soft, brightness, 0.6)


def ui_frame(rim, brightness, size=24):
    fill = _granite(brightness)
    rim_c = pi.hex_color(rim)
    light = tuple(min(255, int(v * 1.35)) for v in rim_c[:3]) + (255,)
    dark = tuple(int(v * 0.55) for v in rim_c[:3]) + (255,)
    ink = (10, 8, 6, 255)
    img = Img(size, size)
    last = size - 1
    for y in range(size):
        for x in range(size):
            edge = min(x, y, last - x, last - y)
            if edge == 0:
                c = ink
            elif edge == 1:
                c = light if (x == 1 or y == 1) and x < last - 1 and y < last - 1 else rim_c
            elif edge == 2:
                c = dark if (x == last - 2 or y == last - 2) else rim_c
            else:
                c = fill.get((x - 3) % fill.w, (y - 3) % fill.h)
                if y == 3:
                    c = tuple(min(255, int(v * 1.25)) for v in c[:3]) + (255,)
            img.set(x, y, c)
    for x, y in ((0, 0), (last, 0), (0, last), (last, last)):
        img.set(x, y, (0, 0, 0, 0))
    for x, y in ((1, 1), (last - 1, 1), (1, last - 1), (last - 1, last - 1)):
        img.set(x, y, ink)
    return img


def ui_bar():
    """Leiste oben und unten: Granitstreifen zum Kacheln."""
    fill = _granite(0.42)
    img = Img(48, 48)
    for y in range(48):
        for x in range(48):
            img.set(x, y, fill.get(x % fill.w, (y + (x // 12) * 5) % fill.h))
    return img


def ui():
    return {
        'ui_btn': ui_frame('#8a8f9a', 0.62),
        'ui_btn_hover': ui_frame('#e0b040', 0.75),
        'ui_btn_pressed': ui_frame('#c08a28', 0.45),
        'ui_btn_off': ui_frame('#4a4a50', 0.35),
        'ui_panel': ui_frame('#b8862e', 0.32),
        'ui_bar': ui_bar(),
        'ui_coin': pi.trim(tile('item/gold/gold_pile_3')),
    }


def build():
    out = {'arena': arena(), 'village': village(), **ui()}
    for kind, fn in OBSTACLES.items():
        out[f'obstacle_{kind}'] = pi.trim(fn())
    return out
