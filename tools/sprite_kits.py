"""Ausrüstung und Effekte für die Pixel-Sprites: Umhang, Schild, Köcher, Krone, Hörner, Heiligenschein,
Flügel, Leuchten und mehr. Damit unterscheiden sich die Stufen einer Linie und die Kombinationen
auch in der Form, nicht nur in der Farbe.

Jede Grundform hat Ankerpunkte (Kopfmitte, Kopfoberkante, Brust, linke/rechte Körperkante).
decorate() legt Rand um das Raster, zeichnet die Teile an den Ankern und schneidet leeren Rand ab.
Links ist hinten (die Figuren schauen nach rechts): Umhang, Köcher und Flügel sitzen links.
"""

# Grundform -> (Kopfmitte x, Kopf oben y, Brust y, Körper links x, Körper rechts x)
ANCHORS = {
    'knight': (7, 1, 9, 1, 11), 'archer': (7, 1, 9, 2, 12), 'mage': (7, 1, 10, 2, 11),
    'healer': (6, 1, 9, 2, 11), 'dwarf': (6, 1, 7, 2, 11), 'skeleton': (5, 0, 7, 2, 9),
    'goblin': (5, 1, 8, 1, 10), 'orc': (6, 1, 9, 1, 11), 'golem': (5, 1, 7, 0, 11),
    'wolf': (13, 0, 4, 0, 15), 'dragon': (13, 1, 5, 0, 15), 'horse': (17, 0, 6, 0, 21),
    'flame': (5, 0, 7, 1, 10), 'drop': (5, 0, 8, 1, 10), 'swirl': (5, 0, 3, 0, 11), 'egg': (4, 0, 5, 1, 8),
}
# Reiter auf Pferd (generate_sprites.mounted): Reiter liegt bei (4, 0).
MOUNTED_OFFSET = (4, 0)

# Leuchtfarben: halbtransparente Paletteneinträge (werden in generate_sprites.PALETTE ergänzt).
GLOW = {
    'fire': ('1', '#ff8a1f90'), 'water': ('2', '#5fb8ff90'), 'ice': ('3', '#c8f8ff99'),
    'earth': ('4', '#d8a96090'), 'air': ('5', '#eef6ff90'), 'light': ('6', '#fff4b0a0'),
    'dark': ('7', '#b060ff90'), 'nature': ('8', '#7dff7a90'), 'thunder': ('9', '#ffe14aa0'),
    'gold': ('0', '#ffd91fa0'), 'blood': ('a', '#ff3b4a90'),
}
# Volle Farbe je Thema (für Funken, Kugeln)
THEME_CHAR = {
    'fire': 'o', 'water': 'u', 'ice': 'c', 'earth': 'h', 'air': 'W', 'light': 'y', 'dark': 'p',
    'nature': 'n', 'thunder': 'y', 'gold': 'y', 'blood': 'r',
}

# Stufen der Linien: welche Teile die Stufe 1..5 trägt.
LINE_LEVEL_KITS = {
    'melee': [[], ['shield'], ['shield', 'cape:u'], ['shield', 'cape:r', 'plume:y'],
              ['shield', 'cape:R', 'crown', 'glow:gold']],
    'ranged': [[], ['quiver'], ['quiver', 'cape:N'], ['quiver', 'cape:U', 'plume:w'],
               ['quiver', 'cape:r', 'crown', 'glow:thunder']],
    'magic': [[], ['orbs:c'], ['orbs:y', 'cape:U'], ['orbs:o', 'cape:R', 'sparkle:fire'],
              ['orbs:c', 'cape:w', 'halo', 'glow:light']],
    'cavalry': [[], [], ['plume:r'], ['plume:y', 'sparkle:gold'], ['wings:w', 'glow:air']],
    'dwarf': [[], ['beard'], ['beard', 'shield'], ['beard', 'shield', 'cape:R'],
              ['beard', 'shield', 'cape:R', 'crown', 'glow:gold']],
    'elf': [[], ['ears'], ['ears', 'quiver'], ['ears', 'quiver', 'cape:N'],
            ['ears', 'quiver', 'cape:n', 'leaf', 'glow:nature']],
    'undead': [[], ['skull'], ['skull', 'cape:k'], ['skull', 'cape:P', 'horns'],
               ['skull', 'cape:k', 'horns', 'crown', 'glow:dark']],
    'dragon': [[], [], ['wings:R'], ['wings:U', 'horns'], ['wings:O', 'horns', 'crown', 'glow:fire']],
    'witch': [[], ['orbs:n'], ['orbs:p', 'cape:P'], ['orbs:r', 'cape:k', 'sparkle:dark'],
              ['orbs:y', 'cape:R', 'crown', 'glow:dark']],
    'wolf': [[], [], ['sparkle:dark', 'glow:dark'], ['horns'], ['crown', 'glow:ice']],
    'giant': [[], ['club'], ['club', 'cape:B'], ['club', 'horns', 'cape:R'], ['club', 'crown', 'glow:earth']],
    'centaur': [[], ['ears'], ['quiver'], ['quiver', 'plume:r'], ['quiver', 'leaf', 'glow:nature']],
    'fire': [[], [], ['sparkle:fire'], ['glow:fire', 'sparkle:fire'], ['glow:fire', 'crown']],
    'water': [[], ['bubbles'], ['bubbles', 'sparkle:ice'], ['bubbles', 'glow:water'], ['bubbles', 'glow:water', 'crown']],
    'earth': [[], [], ['rock'], ['rock', 'sparkle:gold'], ['rock', 'glow:earth', 'crown']],
    'air': [[], ['swirl'], ['swirl', 'sparkle:air'], ['swirl', 'glow:air'], ['swirl', 'glow:thunder', 'crown']],
    'healer': [[], [], ['cape:w'], ['cape:u', 'halo'], ['cape:y', 'halo', 'glow:light']],
}

# Menschenähnliche Grundformen: Sie tragen in Kombinationen einen Umhang in der Farbe der zweiten Zutat.
HUMANOID = {'knight', 'archer', 'mage', 'healer', 'dwarf', 'skeleton', 'goblin', 'orc', 'golem'}


def dominant_color(grid, avoid=()):
    """Häufigste Farbe eines Rasters (ohne Umriss, Haut, Weiß und Leuchten), nicht aus `avoid`."""
    counts = {}
    for row in grid:
        for c in row:
            if c not in '.ksSw0123456789a' and c not in avoid:
                counts[c] = counts.get(c, 0) + 1
    return max(counts, key=counts.get) if counts else 'R'


# Kombinationen: Merkmal der Zutat, die nicht fürs Aussehen steht (je Linie) bzw. des Themas.
LINE_KIT = {
    'melee': 'shield', 'ranged': 'quiver', 'magic': 'orbs:c', 'cavalry': 'plume:r', 'dwarf': 'beard',
    'elf': 'ears', 'undead': 'skull', 'dragon': 'wings:R', 'witch': 'orbs:p', 'wolf': 'cape:G',
    'giant': 'club', 'centaur': 'quiver', 'fire': 'flame', 'water': 'bubbles', 'earth': 'rock',
    'air': 'swirl', 'healer': 'cross',
}
THEME_KIT = {
    'fire': 'flame', 'water': 'bubbles', 'ice': 'ice', 'earth': 'rock', 'air': 'swirl', 'light': 'halo',
    'dark': 'horns', 'nature': 'leaf', 'thunder': 'bolt', 'gold': 'crown', 'blood': 'cape:R',
}
# Zweites Teil je Thema, falls das erste schon von der Zutat kommt
THEME_KIT2 = {
    'fire': 'horns', 'water': 'orbs:c', 'ice': 'crown', 'earth': 'club', 'air': 'wings:w', 'light': 'wings:w',
    'dark': 'wings:P', 'nature': 'orbs:n', 'thunder': 'orbs:y', 'gold': 'halo', 'blood': 'horns',
}
# Themen der Kombinationen, die nicht aus der Tabelle in content.py kommen
HAND_THEME = {
    'mounted_knight': 'earth', 'mounted_archer': 'nature', 'paladin': 'light', 'holy_rider': 'light',
    'legend': 'fire', 'fire_golem': 'fire', 'water_golem': 'water', 'sand_golem': 'earth',
    'fire_knight': 'fire', 'pyromancer': 'fire', 'hydromancer': 'water', 'fire_wolf': 'fire',
    'storm_archer': 'thunder',
}


def combo_level_kits(ingredient_kit, theme):
    """Stufe 1: Merkmal der Zutat; Stufe 2: dazu das Themen-Teil; Stufe 3: dazu Leuchten und Funken."""
    first = [ingredient_kit] if ingredient_kit else []
    theme_kit = THEME_KIT.get(theme)
    if theme_kit in first:  # gleiches Teil schon da: zweites Teil des Themas nehmen
        theme_kit = THEME_KIT2.get(theme)
    second = first + ([theme_kit] if theme_kit and theme_kit not in first else [])
    third = second + [f'sparkle:{theme}', f'glow:{theme}']
    if not first:  # ohne Zutaten-Merkmal trägt Stufe 1 schon das Thema
        extra = THEME_KIT2.get(theme)
        both = second + ([extra] if extra and extra not in second else [])
        return [second, both + [f'sparkle:{theme}'], both + [f'sparkle:{theme}', f'glow:{theme}']]
    return [first, second, third]


# --- Zeichnen ---------------------------------------------------------------------

PAD_TOP = 5
PAD_SIDE = 5


class Anchor:
    def __init__(self, hx, top, chest, left, right, bottom):
        self.hx, self.top, self.chest, self.left, self.right, self.bottom = hx, top, chest, left, right, bottom


def anchor_for(name, offset=(0, 0)):
    hx, top, chest, left, right = ANCHORS[name]
    dx, dy = offset
    return (hx + dx, top + dy, chest + dy, left + dx, right + dx)


def bbox_anchor(grid):
    ys = [y for y, row in enumerate(grid) if any(c != '.' for c in row)]
    xs = [x for row in grid for x, c in enumerate(row) if c != '.']
    x0, x1 = min(xs), max(xs)
    return ((x0 + x1) // 2, ys[0], (ys[0] + ys[-1]) // 2, x0, x1)


def decorate(grid, anchor, kits):
    """Zeichnet `kits` an die Anker und gibt ein neues, zugeschnittenes Raster zurück."""
    if not kits:
        return [row[:] for row in grid]
    width = len(grid[0]) + 2 * PAD_SIDE
    g = [['.'] * width for _ in range(PAD_TOP)]
    g += [['.'] * PAD_SIDE + row[:] + ['.'] * PAD_SIDE for row in grid]
    hx, top, chest, left, right = anchor
    a = Anchor(hx + PAD_SIDE, top + PAD_TOP, chest + PAD_TOP, left + PAD_SIDE, right + PAD_SIDE, len(g) - 1)
    ordered = [k for k in kits if not k.startswith('glow')] + [k for k in kits if k.startswith('glow')]
    for kit in ordered:
        name, _, arg = kit.partition(':')
        KITS[name](g, a, arg)
    return trim(g)


def trim(g):
    while g and all(c == '.' for c in g[0]):
        g = g[1:]
    while all(row[0] == '.' for row in g) and all(row[-1] == '.' for row in g) and len(g[0]) > 2:
        g = [row[1:-1] for row in g]
    return g


def put(g, x, y, c, over=False):
    if 0 <= y < len(g) and 0 <= x < len(g[0]) and (over or g[y][x] == '.'):
        g[y][x] = c


def row_edge(g, y, side):
    """Äußerster Körperpunkt einer Zeile (links oder rechts), oder None."""
    xs = [x for x, c in enumerate(g[y]) if c not in '.0123456789a'] if 0 <= y < len(g) else []
    if not xs:
        return None
    return xs[0] if side == 'left' else xs[-1]


def k_cape(g, a, color):
    color = color or 'R'
    start = a.chest - 2
    for y in range(start, a.bottom):
        edge = row_edge(g, y, 'left')
        if edge is None:
            continue
        width = min(1 + (y - start) // 3, 3)
        for i in range(1, width + 1):
            put(g, edge - i, y, color)
        put(g, edge - width - 1, y, 'k')
    edge = row_edge(g, a.bottom - 1, 'left')


def k_shield(g, a, _):
    shape = [".kkk.", "kuyuk", "kuuuk", ".kuk.", "..k.."]
    x0, y0 = a.left - 3, a.chest - 2
    for j, row in enumerate(shape):
        for i, c in enumerate(row):
            if c != '.':
                put(g, x0 + i, y0 + j, c, over=True)


def k_quiver(g, a, _):
    x = a.left - 1
    for y in range(a.top + 4, a.chest + 2):
        put(g, x, y, 'B')
        put(g, x - 1, y, 'k')
    put(g, x, a.top + 3, 'w')
    put(g, x - 1, a.top + 2, 'w')
    put(g, x + 1, a.top + 2, 'r')
    put(g, x, a.top + 2, 'k')


def k_plume(g, a, color):
    color = color or 'r'
    for dx, dy in ((0, -1), (-1, -2), (-2, -2), (-3, -1), (-1, -1), (-2, -3)):
        put(g, a.hx + dx, a.top + dy, color)


def k_crown(g, a, _):
    for j, row in enumerate(("y.y.y", "yyyyy", "YrYrY")):
        for i, c in enumerate(row):
            if c != '.':
                put(g, a.hx - 2 + i, a.top - 3 + j, c, over=True)


def k_halo(g, a, _):
    for i in range(-2, 3):
        put(g, a.hx + i, a.top - 2, 'y')
    for i in range(-1, 2):
        put(g, a.hx + i, a.top - 3, 'e')


def k_horns(g, a, _):
    for side in (-1, 1):
        for dx, dy, c in ((3, -1, 'e'), (4, -2, 'e'), (4, -3, 'w'), (3, -4, 'w')):
            put(g, a.hx + side * dx, a.top + dy, c)


def k_leaf(g, a, _):
    for i in range(-3, 4):
        put(g, a.hx + i, a.top - 1, 'n' if i % 2 == 0 else 'N')
    for i in (-2, 0, 2):
        put(g, a.hx + i, a.top - 2, 'n')
    put(g, a.hx, a.top - 3, 'r')


def k_flame(g, a, _):
    for i in range(-2, 3):
        put(g, a.hx + i, a.top - 1, 'o')
    for i in range(-1, 2):
        put(g, a.hx + i, a.top - 2, 'y')
    put(g, a.hx, a.top - 3, 'y')
    put(g, a.hx - 2, a.top - 2, 'r')
    put(g, a.hx + 2, a.top - 2, 'r')
    put(g, a.hx + 1, a.top - 3, 'o')


def k_ice(g, a, _):
    for edge, side in ((a.left, -1), (a.right, 1)):
        for dx, dy, c in ((0, -2, 'c'), (0, -3, 'c'), (side, -4, 'w'), (side, -2, 'c')):
            put(g, edge + dx, a.chest + dy, c)


def k_bolt(g, a, _):
    x = a.right + 2
    for dx, dy in ((1, 0), (0, 1), (-1, 2), (0, 2), (1, 2), (0, 3), (-1, 4), (-1, 5)):
        put(g, x + dx, a.top + dy, 'y')
    put(g, x + 2, a.top - 1, 'Y')


def k_bubbles(g, a, _):
    for x, y in ((a.left - 2, a.top + 2), (a.right + 2, a.top + 4), (a.left - 1, a.chest + 2), (a.right + 1, a.top)):
        put(g, x, y, 'c')
        put(g, x, y - 1, 'w')


def k_rock(g, a, _):
    for edge in (a.left, a.right):
        for dx in (-1, 0, 1):
            put(g, edge + dx, a.chest - 2, 'G', over=True)
            put(g, edge + dx, a.chest - 1, 'd', over=True)
        put(g, edge, a.chest - 3, 'k')


def k_swirl(g, a, _):
    for x, y in ((a.left - 2, a.chest - 2), (a.left - 3, a.chest - 1), (a.left - 3, a.chest), (a.left - 2, a.chest + 1),
                 (a.right + 2, a.chest - 3), (a.right + 3, a.chest - 2), (a.right + 3, a.chest - 1), (a.right + 2, a.chest)):
        put(g, x, y, 'W')


def k_cross(g, a, _):
    for dx, dy in ((0, -1), (0, 0), (0, 1), (-1, 0), (1, 0)):
        put(g, a.hx + dx, a.chest + dy, 'r', over=True)


def k_skull(g, a, _):
    for dx, dy, c in ((-1, -1, 'w'), (0, -1, 'w'), (1, -1, 'w'), (-1, 0, 'k'), (0, 0, 'w'), (1, 0, 'k'),
                      (-1, 1, 'w'), (1, 1, 'w')):
        put(g, a.hx + dx, a.chest + dy, c, over=True)


def k_beard(g, a, _):
    for dy, half in ((5, 2), (6, 2), (7, 1)):
        for dx in range(-half, half + 1):
            put(g, a.hx + dx, a.top + dy, 'w', over=True)


def k_ears(g, a, _):
    y = a.top + 3
    left, right = row_edge(g, y, 'left'), row_edge(g, y, 'right')
    if left is not None:
        put(g, left - 1, y, 's')
        put(g, left - 2, y - 1, 's')
    if right is not None:
        put(g, right + 1, y, 's')
        put(g, right + 2, y - 1, 's')


def k_wings(g, a, color):
    color = color or 'R'
    widths = [2, 3, 4, 4, 3, 1]
    start = a.top + 2
    for j, width in enumerate(widths):
        y = start + j
        edge = row_edge(g, y, 'left')
        if edge is None:
            edge = a.left
        for i in range(1, width + 1):
            put(g, edge - i, y, color)
        put(g, edge - width - 1, y, 'k')


def k_club(g, a, _):
    x = a.right + 4
    for y in range(a.chest - 2, a.chest + 4):
        put(g, x, y, 'b')
    for y in range(a.chest - 5, a.chest - 2):
        for dx in (-1, 0, 1):
            put(g, x + dx, y, 'B')
    for dx, dy in ((-2, -4), (2, -4), (0, -6)):
        put(g, x + dx, a.chest + dy, 'k')


def k_orbs(g, a, color):
    color = color or 'c'
    for x, y in ((a.left - 2, a.top + 2), (a.right + 2, a.top + 1), (a.right + 2, a.top + 7)):
        put(g, x, y, color)
        put(g, x, y - 1, 'w')


def k_sparkle(g, a, theme):
    c = THEME_CHAR.get(theme, 'y')
    for x, y in ((a.left - 3, a.top), (a.right + 3, a.chest - 1), (a.left - 2, a.bottom - 3), (a.right + 2, a.top - 2)):
        put(g, x, y, c)
        put(g, x + 1, y, 'w')


def k_glow(g, a, theme):
    char = GLOW.get(theme, GLOW['gold'])[0]
    height, width = len(g), len(g[0])
    body = [[c not in '.0123456789a' for c in row] for row in g]
    for y in range(height):
        for x in range(width):
            if g[y][x] != '.':
                continue
            if any(0 <= y + dy < height and 0 <= x + dx < width and body[y + dy][x + dx]
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                g[y][x] = char


KITS = {
    'cape': k_cape, 'shield': k_shield, 'quiver': k_quiver, 'plume': k_plume, 'crown': k_crown,
    'halo': k_halo, 'horns': k_horns, 'leaf': k_leaf, 'flame': k_flame, 'ice': k_ice, 'bolt': k_bolt,
    'bubbles': k_bubbles, 'rock': k_rock, 'swirl': k_swirl, 'cross': k_cross, 'skull': k_skull,
    'beard': k_beard, 'ears': k_ears, 'wings': k_wings, 'club': k_club, 'orbs': k_orbs,
    'sparkle': k_sparkle, 'glow': k_glow,
}
