"""Sprites aus den Dungeon-Crawl-Stone-Soup-Kacheln (CC0, siehe tools/dcss/README.md).

Jede Einheit bekommt eine Kachel aus dem Paket (Monster), eine aus Puppenteilen zusammengesetzte Figur
(Grundkörper, Rüstung, Helm, Waffe, Schild, Umhang) oder ein eigenes Bild im selben Stil (Pferd, Drachenei).
Kombinationen ohne eigene Kachel je Stufe werden mit Stufe 2 und 3 farbig umrandet.

Die Figuren schauen nach rechts (wie im Spiel), Kacheln mit Blick nach links werden gespiegelt.
Benötigte Kacheln kopiert tools/import_dcss.py nach tools/dcss/ (nur einmal, braucht Pillow).
"""
from pathlib import Path

import content
import pixel_image as pi
from pixel_image import Img

ROOT = Path(__file__).resolve().parent.parent
TILES = ROOT / 'tools/dcss'

# Wird von import_dcss.py ersetzt, um die Kacheln direkt aus dem Paket zu lesen.
loader = None
_cache = {}


def tile(rel):
    """Kachel `rel` (Pfad im Paket ohne .png), z.B. 'monster/troll'."""
    if rel not in _cache:
        _cache[rel] = loader(rel) if loader else pi.read_png(TILES / f'{rel}.png')
    return _cache[rel].copy()


def M(name, flip=False):
    img = tile(f'monster/{name}')
    return pi.flip(img) if flip else img


def doll(base, *parts, flip=False):
    """Figur aus Puppenteilen: Umhang hinter dem Körper, dann Teile in der angegebenen Reihenfolge."""
    capes = [tile(f'player/{p}') for p in parts if p.startswith('cloak/')]
    rest = [tile(f'player/{p}') for p in parts if not p.startswith('cloak/')]
    img = pi.layered(*(capes + [tile(f'player/base/{base}')] + rest)) if capes else \
        pi.layered(tile(f'player/base/{base}'), *rest)
    img = pi.shadow(pi.trim(img))
    return pi.flip(img) if flip else img


def draconian(color, job):
    return pi.layered(tile(f'monster/draconic/draconic_base-{color}'), tile(f'monster/draconic/draconic_job-{job}'))


def with_parts(img, *parts):
    """Puppenteile über eine fertige Kachel legen (z.B. Bogen für ein Skelett)."""
    return pi.layered(img, *(tile(f'player/{p}') for p in parts))


# --- Eigene Bilder im Kachelstil -------------------------------------------------------

HORSE = [
    "................................",
    "................................",
    ".....................k...k......",
    "....................k2k.k2k.....",
    "...................kmk2kk22k....",
    "..................kmnk112222k...",
    ".................kmn1112e2222k..",
    "................kmn11122222222k.",
    "...............kmn112222222222k.",
    "..............kmn112222222333k..",
    ".............kmn11222223kkkk....",
    "............kmn112222233k.......",
    ".....kkkkkkkmn1122222233k.......",
    "...kk1111111n11222222233k.......",
    "..kmk1122222222222222333k.......",
    ".kmnk1222222222222222333k.......",
    ".kmnk22222222222222223334k......",
    "kmn.k32222222222222233334k......",
    "kmn.k33222222222222333344k......",
    "kmn..k33332222223333334443k.....",
    ".kmn.k433k3333333k4334k443k.....",
    ".kmn.k443kk44444kk443k.k433k....",
    "..kmnk443k.kkkkk.k443k..k433k...",
    "..kmnk433k.......k433k...k43k...",
    "...kkk433k......k4433k...k33k...",
    ".....k3332k.....k433k...k333k...",
    ".....k3322k.....k433k...k332k...",
    ".....kkhhk......khhhk...khhk....",
    "....sskhhhkssssskhhhkssskhhhks..",
    "......sssssssssssssssssssssss...",
]
# Fellfarben (hell, mittel, Schatten, tief), Mähne (dunkel, hell), Hufe.
COATS = {
    'cream': ('#f2e2b8', '#d9c08a', '#b09464', '#806a44', '#c9a46a', '#e8d2a0', '#5a4a3a'),
    'brown': ('#ce9862', '#a46c3a', '#7a4c26', '#543218', '#281a12', '#4c3422', '#3a3430'),
    'bay': ('#9a5a32', '#74401f', '#522a12', '#36190a', '#140c08', '#2c1c12', '#2a2420'),
    'grey': ('#c8c8cc', '#9c9ca4', '#74747e', '#4e4e58', '#2a2a30', '#56565e', '#2c2c30'),
    'white': ('#ffffff', '#e4e8f0', '#b8c0d0', '#8a92a6', '#c8ccd8', '#f0f0f8', '#6a6a72'),
    'black': ('#5a5a66', '#3a3a44', '#26262e', '#16161c', '#0c0c10', '#2a2a32', '#1a1a1e'),
    'gold': ('#ffe9a0', '#f0c050', '#c08a28', '#8a5a14', '#fff4c0', '#ffd860', '#6a4a20'),
    'storm': ('#e8f6ff', '#b0d8f0', '#80a8c8', '#587898', '#5ff2ff', '#c8f8ff', '#3a4a5a'),
    'sea': ('#8ad8c8', '#58b0a0', '#3a8478', '#225a52', '#1a4a3a', '#2f7d5a', '#2a3a38'),
    'fire': ('#5a4a4a', '#3a2c2c', '#261c1c', '#140e0e', '#ff6a1a', '#ffc040', '#1a1414'),
}


def horse(coat='brown', eye='#0a0806'):
    hl, base, shade, deep, mane, mane_light, hoof = (pi.hex_color(c) for c in COATS[coat])
    pal = {'k': (26, 16, 10, 255), '1': hl, '2': base, '3': shade, '4': deep, 'm': mane, 'n': mane_light,
           'h': hoof, 'e': pi.hex_color(eye), 's': (0, 0, 0, 100)}
    img = Img(32, len(HORSE))
    for y, row in enumerate(HORSE):
        for x, ch in enumerate(row):
            if ch == '.':
                continue
            c = pal[ch]
            # Körnung wie in den Kacheln
            if ch in '1234mn' and (x * 7 + y * 13) % 9 == 0:
                c = tuple(min(255, int(v * 1.08)) for v in c[:3]) + (255,)
            elif ch in '1234mn' and (x * 5 + y * 11) % 11 == 0:
                c = tuple(int(v * 0.9) for v in c[:3]) + (255,)
            img.set(x, y, c)
    return img


def draw(img, rows, palette, x0=0, y0=0):
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != '.':
                img.set(x0 + x, y0 + y, pi.over(img.get(x0 + x, y0 + y), pi.hex_color(palette[ch])))
    return img


def barding(img, color, trim='#ffd91f'):
    """Schabracke (Decke) über dem Rücken."""
    rows = [
        "..ttttttttttttttt",
        ".tcccccccccccccct",
        ".tccccccccccccccdt",
        "tccccccccccccccddt",
        "tcccccccccccccdddt",
        ".tdddddddddddddddt",
        "..ttttttttttttttt",
    ]
    dark = pi.adjust(Img(1, 1, [pi.hex_color(color)]), 0.65).px[0]
    return draw(img, rows, {'t': trim, 'c': color, 'd': '#%02x%02x%02x' % dark[:3]}, 5, 13)


def chamfron(img):
    """Stirnpanzer aus Stahl."""
    rows = ["..gg", ".gWgg", "gWWgg.", "gggg", ".gg"]
    return draw(img, rows, {'g': '#8a92a6', 'W': '#dfe6f2'}, 21, 5)


def horn(img, color='#ffd91f'):
    return draw(img, ["....c", "...c.", "..cw.", ".cw.."], {'c': color, 'w': '#fff6c0'}, 25, 0)


def wings(img, color='#ffffff', shade='#b8c0d0'):
    rows = [
        "......kk.......",
        "....kkwwk......",
        "..kkwwwwwk.....",
        ".kwwwwwwssk....",
        "kwwwwwwsssk....",
        "kwwwwwsssk.....",
        ".kwwwssskk.....",
        "..kkkkkk.......",
    ]
    return draw(img, rows, {'k': '#3a3a48', 'w': color, 's': shade}, 4, 4)


def ride(mount, rider, seat_x, seat_y, cut=19):
    """Reiter (Puppe ohne Schatten) auf ein Reittier setzen: Oberkörper bis Zeile `cut`."""
    upper = pi.crop(rider, 0, 0, rider.w, cut)
    x0, _, w, _ = pi.bbox(upper)
    top = seat_y - cut
    out = pi.pad(mount, 0, max(0, -top), 0, 0)
    off = max(0, -top)
    # Bein seitlich am Bauch
    pi.paste(out, upper, seat_x - (x0 + w // 2), top + off)
    return out


def rider_doll(base, *parts):
    capes = [tile(f'player/{p}') for p in parts if p.startswith('cloak/')]
    rest = [tile(f'player/{p}') for p in parts if not p.startswith('cloak/')]
    return pi.layered(*(capes + [tile(f'player/base/{base}')] + rest))


def mounted(coat, base, *parts, extra=None):
    steed = horse(coat)
    if extra:
        steed = extra(steed)
    return ride(steed, rider_doll(base, *parts), 13, 16)


EGG = [
    "....kkkk....",
    "...k1122k...",
    "..k112g22k..",
    ".k1122ggg2k.",
    ".k1g222g23k.",
    "k112gg22223k",
    "k12ggg22g23k",
    "k1222g2ggg3k",
    "k2222222g33k",
    ".k2g2223g3k.",
    ".k22g22333k.",
    "..k223333k..",
    "...kkkkkk...",
    ".ssssssssss.",
]


def egg():
    img = Img(12, len(EGG))
    return draw(img, EGG, {'k': '#1e2a14', '1': '#f8f4e0', '2': '#dcd6b4', '3': '#a8a07c', 'g': '#4f9a3c',
                           's': '#00000064'})


# --- Stufen-Kennzeichnung und Wirkungen ------------------------------------------------

def glow(img, color, alpha=170, thickness=1):
    return pi.outline(img, color, alpha, thickness)


def tier(img, level, color):
    """Stufe 2: farbiger Rand, Stufe 3: breiter leuchtender Rand."""
    if level == 1:
        return img
    if level == 2:
        return glow(img, color, 150)
    return glow(img, color, 220, 2)


def themed(img, theme, strength=0.65):
    return pi.recolor(img, content.THEME_COLOR[theme], strength, 0.6, 0.12)


def tinted(img, color, strength=0.7):
    return pi.recolor(img, color, strength, 0.6, 0.12)


def big(img):
    return pi.scale(img, 2)


def crown(img, color='#ffd91f'):
    """Kleine Krone über dem Kopf (oberste Pixelzeile der Figur)."""
    x0, y0, w, _ = pi.bbox(img)
    top_row = [x for x in range(img.w) if img.get(x, y0)[3]]
    cx = (top_row[0] + top_row[-1]) // 2 if top_row else x0 + w // 2
    out = pi.pad(img, 0, 4, 0, 0)
    return draw(out, ["c.c.c", "ccccc", "dddddd"[:5]], {'c': color, 'd': '#b06a00'}, cx - 2, y0 + 1)


# --- Linien ----------------------------------------------------------------------------
# Jede Einheit: Funktion ohne Argumente, die ein Img liefert.

HUMAN = 'human_male'
HUMAN_F = 'human_female'

LINE = {
    # Nahkampf
    'peasant': lambda: doll(HUMAN, 'legs/pants_short_brown', 'boots/short_brown', 'body/shirt_vest',
                            'hair/brown_1', 'hand_right/pole_forked'),
    'squire': lambda: doll(HUMAN, 'legs/pants_brown', 'boots/middle_brown', 'body/leather_armor',
                           'hair/short_yellow', 'hand_right/short_sword', 'hand_left/buckler_round_2'),
    'knight': lambda: doll(HUMAN, 'legs/leg_armor_1', 'boots/middle_gray', 'body/plate', 'gloves/glove_gray',
                           'head/helm_plume', 'hand_right/long_sword', 'hand_left/shield_knight_blue'),
    'crusader': lambda: doll(HUMAN, 'cloak/white', 'legs/leg_armor_2', 'boots/mesh_white', 'body/plate_and_cloth',
                             'gloves/glove_white', 'head/fhelm_gray_3', 'hand_right/broadsword',
                             'hand_left/shield_long_cross'),
    'bodyguard': lambda: doll(HUMAN, 'cloak/black', 'legs/leg_armor_4', 'boots/mesh_black', 'body/plate_black',
                              'gloves/glove_black', 'head/full_black', 'hand_right/great_sword',
                              'hand_left/shield_large_dd_dk'),
    # Fernkampf
    'slinger': lambda: doll(HUMAN, 'legs/pants_short_darkbrown', 'boots/short_brown', 'body/leather_jacket',
                            'hair/brown_2', 'hand_right/sling'),
    'archer': lambda: doll(HUMAN, 'cloak/green', 'legs/pants_darkgreen', 'boots/middle_brown', 'body/leather_green',
                           'head/hood_green', 'hand_right/bow'),
    'hunter': lambda: doll(HUMAN, 'cloak/brown', 'legs/pants_brown', 'boots/middle_ybrown', 'body/leather_armor_3',
                           'head/feather_green', 'hand_right/great_bow'),
    'sharpshooter': lambda: doll(HUMAN, 'cloak/blue', 'legs/pants_blue', 'boots/middle_gray', 'body/leather_stud',
                                 'gloves/glove_blue', 'head/hood_gray', 'hand_right/crossbow_3'),
    'hawkeye': lambda: doll('elf_male', 'cloak/red', 'legs/pants_red', 'boots/long_red', 'body/legolas',
                            'hair/elf_yellow', 'head/feather_red', 'hand_right/great_bow'),
    # Magie
    'apprentice': lambda: doll(HUMAN, 'boots/short_brown', 'body/robe_brown', 'hair/brown_2',
                               'hand_right/quarterstaff'),
    'mage': lambda: M('wizard'),
    'archmage': lambda: doll(HUMAN, 'boots/middle_purple', 'body/robe_blue_white', 'beard/long_white',
                             'hair/long_white', 'head/wizard_blue', 'hand_right/staff_mage'),
    'grand_mage': lambda: doll(HUMAN, 'cloak/red', 'boots/long_red', 'body/robe_red_gold', 'beard/long_white',
                               'head/wizard_red', 'hand_right/staff_ruby'),
    'world_weaver': lambda: glow(doll(HUMAN, 'cloak/white', 'body/saruman', 'beard/long_white', 'hair/long_white',
                                      'head/wizard_white', 'hand_right/great_staff'), '#e8f0ff', 170, 2),
    # Reittiere
    'foal': lambda: horse('cream'),
    'horse': lambda: horse('brown'),
    'warhorse': lambda: barding(horse('bay'), '#a8153f'),
    'destrier': lambda: chamfron(barding(horse('grey'), '#4f5fb5', '#dfe6f2')),
    'stormsteed': lambda: glow(horse('storm', '#2f8cff'), '#8fe0ff', 170, 2),
    # Zwerge
    'miner': lambda: doll('dwarf_male', 'legs/pants_brown', 'boots/middle_brown', 'body/leather_heavy',
                          'beard/long_red', 'head/iron_1', 'hand_right/pick_axe'),
    'dwarf_warrior': lambda: M('dwarf_new'),
    'axe_master': lambda: doll('dwarf_male', 'legs/leg_armor_3', 'boots/middle_gray', 'body/chainmail',
                               'beard/long_black', 'head/viking_brown_1', 'hand_right/battleaxe'),
    'dwarf_lord': lambda: doll('dwarf_male', 'legs/leg_armor_1', 'boots/middle_gold', 'body/gimli',
                               'beard/long_yellow', 'head/helm_gimli', 'hand_right/gimli',
                               'hand_left/shield_kite_3'),
    'mountain_king': lambda: doll('dwarf_male', 'cloak/red', 'legs/leg_armor_1', 'boots/middle_gold',
                                  'body/dragon_armor_gold_new', 'beard/long_white', 'head/crown_gold_2',
                                  'hand_right/great_mace'),
    # Elfen
    'elf_scout': lambda: doll('elf_male', 'legs/pants_darkgreen', 'boots/short_brown', 'body/leather_green',
                              'hair/elf_yellow', 'hand_right/bow_blue'),
    'wood_elf': lambda: doll('elf_female', 'cloak/green', 'legs/trouser_green', 'boots/middle_green',
                             'body/legolas', 'hair/legolas', 'hand_right/legolas'),
    'high_elf': lambda: doll('elf_male', 'cloak/white', 'boots/mesh_white', 'body/robe_white_blue',
                             'hair/elf_white', 'hand_right/great_bow'),
    'elf_lord': lambda: doll('elf_male', 'cloak/yellow', 'legs/leg_armor_1', 'boots/blue_gold', 'body/gil-galad',
                             'hair/elf_yellow', 'hand_right/spear_2_new', 'hand_left/gil-galad'),
    'elf_king': lambda: doll('elf_male', 'cloak/magenta', 'boots/middle_purple', 'body/robe_purple',
                             'hair/elf_white', 'head/crown_gold_1', 'hand_right/scepter'),
    # Untote
    'skeleton': lambda: M('undead/skeletons/skeleton_humanoid_small'),
    'ghoul': lambda: M('undead/ghoul'),
    'revenant': lambda: M('undead/wight_new'),
    'death_knight': lambda: M('death_knight'),
    'lich_king': lambda: M('undead/ancient_lich_new'),
    # Drachen
    'dragon_egg': lambda: pi.scale(egg(), 2),
    'wyrmling': lambda: M('forest_drake', flip=True),
    'young_dragon': lambda: M('fire_drake'),
    'dragon': lambda: M('dragons/storm_dragon_new', flip=True),
    'elder_dragon': lambda: M('dragons/golden_dragon'),
    # Hexen
    'herbalist': lambda: doll(HUMAN_F, 'boots/short_brown', 'body/robe_brown_2', 'hair/fem_white',
                              'head/hood_ybrown', 'hand_right/sickle'),
    'witch': lambda: doll(HUMAN_F, 'boots/short_purple', 'body/robe_green', 'hair/fem_black', 'head/hat_black',
                          'hand_right/quarterstaff_2_new'),
    'sorceress': lambda: M('unique/erica_new'),
    'dark_witch': lambda: doll(HUMAN_F, 'cloak/black', 'boots/mesh_black', 'body/robe_of_night', 'hair/fem_black',
                               'head/hat_black', 'hand_right/staff_skull'),
    'witch_queen': lambda: doll(HUMAN_F, 'cloak/red', 'boots/long_red', 'body/robe_red_gold', 'hair/fem_black',
                                'head/crown_gold_3', 'hand_right/staff_ruby'),
    # Wölfe
    'wolf_pup': lambda: M('animals/jackal_new'),
    'wolf': lambda: M('animals/wolf', flip=True),
    'shadow_wolf': lambda: M('animals/warg', flip=True),
    'werewolf': lambda: M('gnoll_sergeant'),
    'fenrir': lambda: M('animals/raiju', flip=True),
    # Riesen
    'gnome': lambda: M('gnome'),
    'troll': lambda: M('troll'),
    'giant': lambda: M('hill_giant_new'),
    'cyclops': lambda: M('cyclops_new'),
    'titan': lambda: M('titan_new'),
    # Waldwesen
    'satyr': lambda: M('satyr'),
    'faun': lambda: M('faun'),
    'centaur': lambda: M('centaur', flip=True),
    'centaur_lord': lambda: M('centaur_warrior', flip=True),
    'chiron': lambda: M('unique/nessos_new', flip=True),
    # Feuer
    'spark': lambda: pi.scale(pi.trim(tile('effect/flame_0')), 2),
    'flame': lambda: M('nonliving/fire_vortex_2'),
    'fire_spirit': lambda: M('nonliving/orb_of_fire_new'),
    'fire_elemental': lambda: M('nonliving/fire_elemental_new'),
    'ifrit': lambda: M('demons/efreet'),
    # Wasser
    'droplet': lambda: M('nonliving/wellspring'),
    'wave': lambda: tinted(M('nonliving/maelstrom_2'), '#3f78d8', 0.85),
    'water_spirit': lambda: M('undead/drowned_soul'),
    'water_elemental': lambda: M('nonliving/water_elemental_new'),
    'leviathan': lambda: M('unique/jormungandr', flip=True),
    # Erde
    'pebble': lambda: M('animals/boulder_beetle'),
    'golem': lambda: M('nonliving/guardian_golem'),
    'earth_spirit': lambda: M('undead/bog_body'),
    'earth_elemental': lambda: M('nonliving/earth_elemental'),
    'gaia': lambda: M('nonliving/crystal_guardian'),
    # Wind
    'breath': lambda: M('nonliving/insubstantial_wisp'),
    'breeze': lambda: M('nonliving/twister_1'),
    'wind_spirit': lambda: M('harpy'),
    'air_elemental': lambda: M('nonliving/air_elemental_new'),
    'djinn': lambda: M('demons/rakshasa'),
    # Heiler
    'herb_healer': lambda: doll(HUMAN_F, 'boots/short_brown', 'body/dress_green', 'hair/fem_yellow',
                                'hand_right/staff_organic'),
    'healer': lambda: doll(HUMAN, 'boots/middle_brown', 'body/robe_white_red', 'hair/short_black', 'head/healer',
                           'hand_right/staff_plain'),
    'shaman': lambda: doll(HUMAN, 'legs/loincloth_red', 'boots/short_brown', 'body/animal_skin', 'head/bear',
                           'hand_right/staff_mage_2', 'hand_left/shield_shaman'),
    'doctor': lambda: doll(HUMAN, 'boots/middle_gray', 'body/robe_white_blue', 'hair/short_white',
                           'gloves/glove_white', 'hand_right/rod_blue_new'),
    'life_giver': lambda: M('daeva'),
}


# --- Kombinationen ---------------------------------------------------------------------
# Eintrag: Funktion für alle drei Stufen (dann Rand als Stufenzeichen) oder Liste mit drei Funktionen.

def knight_rider(*extra):
    return (HUMAN, 'legs/leg_armor_1', 'body/plate', 'gloves/glove_gray', 'head/helm_plume', 'hand_right/lance',
            *extra)


def archer_rider(*extra):
    return (HUMAN, 'cloak/green', 'body/leather_green', 'head/hood_green', 'hand_right/bow', *extra)


COMBO = {
    'mounted_knight': [lambda: mounted('brown', *knight_rider('hand_left/shield_knight_blue')),
                       lambda: mounted('bay', *knight_rider('hand_left/shield_knight_rw'), extra=chamfron),
                       lambda: mounted('black', *knight_rider('cloak/red', 'hand_left/shield_long_red'),
                                       extra=lambda h: chamfron(barding(h, '#a8153f')))],
    'mounted_archer': [lambda: mounted('brown', *archer_rider()),
                       lambda: mounted('bay', *archer_rider()),
                       lambda: mounted('cream', *archer_rider('head/feather_green'),
                                       extra=lambda h: barding(h, '#2f7d32', '#c97a2e'))],
    'paladin': [lambda: M('holy/paladin'), lambda: glow(M('holy/paladin'), '#fff4b0', 150),
                lambda: glow(M('holy/paladin'), '#ffd91f', 220, 2)],
    'holy_rider': lambda: mounted('white', HUMAN, 'cloak/white', 'body/armor_blue_gold', 'head/full_gold',
                                  'hand_right/lance', 'hand_left/shield_holy',
                                  extra=lambda h: barding(h, '#f4f4f4', '#ffd91f')),
    'legend': lambda: glow(mounted('gold', HUMAN, 'cloak/red', 'body/armor_blue_gold', 'head/crown_gold_1',
                                   'hand_right/blessed_blade', 'hand_left/shield_holy',
                                   extra=lambda h: barding(h, '#a8153f', '#ffd91f')), '#ff9a3c', 160),
    'fire_golem': lambda: themed(M('nonliving/stone_golem'), 'fire', 0.75),
    'water_golem': lambda: M('nonliving/crystal_golem'),
    'sand_golem': lambda: M('nonliving/clay_golem'),
    'fire_knight': lambda: M('hell_knight_new'),
    'pyromancer': lambda: doll(HUMAN, 'cloak/red', 'boots/long_red', 'body/robe_red', 'hair/short_red',
                               'head/wizard_blackred', 'hand_right/rod_ruby_new'),
    'hydromancer': lambda: M('merfolk_aquamancer'),
    'fire_wolf': lambda: M('animals/hell_hound_new', flip=True),
    'storm_archer': lambda: glow(doll('elf_male', 'cloak/cyan', 'legs/pants_blue', 'boots/mesh_blue',
                                      'body/leather_armor_2', 'hair/elf_white', 'head/feather_blue',
                                      'hand_right/bow_blue'), '#8fe0ff', 110),
    # Elemente untereinander
    'frost_spirit': [lambda: M('undead/freezing_wraith'), lambda: M('demons/ice_devil'),
                     lambda: M('demons/blizzard_demon')],
    'steam': [lambda: M('nonliving/vapour'), lambda: tinted(M('demons/smoke_demon_new'), '#c8ccd8', 0.4),
              lambda: M('dragons/steam_dragon', flip=True)],
    'lightning': [lambda: M('nonliving/ball_lightning'), lambda: M('nonliving/orb_of_electricity'),
                  lambda: M('nonliving/electric_golem')],
    'lava': [lambda: M('lava_worm', flip=True), lambda: M('nonliving/molten_gargoyle'), lambda: M('demons/balrug_new')],
    'sandstorm': [lambda: tinted(M('nonliving/twister_2'), '#c98a4b', 0.8),
                  lambda: tinted(M('nonliving/twister_3'), '#c98a4b', 0.8),
                  lambda: M('demons/sun_demon')],
    # Drachen und Mischwesen
    'fire_dragon': [lambda: M('salamander'), lambda: themed(M('dragons/dragon', flip=True), 'fire', 0.8),
                    lambda: M('unique/serpent_of_hell')],
    'ice_dragon': [lambda: M('ice_beast'), lambda: M('dragons/ice_dragon_new', flip=True),
                   lambda: glow(M('dragons/ice_dragon_new', flip=True), '#8fe0ff', 200, 2)],
    'dragon_rider': [lambda: draconian('red', 'knight'),
                     lambda: glow(draconian('red', 'knight'), '#f08a24', 150),
                     lambda: M('unique/tiamat_red')],
    'dragon_mage': [lambda: draconian('yellow', 'caller'), lambda: draconian('yellow', 'scorcher'),
                    lambda: M('unique/tiamat_yellow')],
    'bone_dragon': [lambda: M('undead/skeletons/skeleton_dragon', flip=True),
                    lambda: M('undead/bone_dragon_new', flip=True),
                    lambda: glow(M('undead/bone_dragon_new', flip=True), '#b060ff', 200, 2)],
    'hydra': [lambda: M('dragons/hydra_3_new', flip=True), lambda: M('dragons/hydra_5_new', flip=True),
              lambda: M('unique/lernaean_hydra')],
    'basilisk': lambda: M('animals/basilisk', flip=True),
    'chimera': lambda: M('manticore', flip=True),
    'phoenix': lambda: M('phoenix'),
    'thunderbird': lambda: glow(tinted(M('raven', flip=True), '#f5c935', 0.55), '#ffe14a', 140),
    # Untote
    'necromancer': [lambda: M('necromancer_new'), lambda: M('deep_elf_death_mage'),
                    lambda: M('undead/zonguldrok_lich_1')],
    'skeleton_knight': [lambda: M('undead/skeletal_warrior_new'), lambda: M('undead/skeletons/skeleton_humanoid_large'),
                        lambda: M('undead/wight_king')],
    'vampire': [lambda: M('undead/vampire_new'), lambda: M('undead/vampire_mage_new'),
                lambda: M('undead/vampire_knight_new')],
    'zombie_giant': [lambda: M('undead/zombies/zombie_ogre'), lambda: M('undead/rotting_hulk_new'),
                     lambda: glow(M('undead/rotting_hulk_new'), '#58b84e', 200, 2)],
    'mummy': [lambda: M('undead/mummy'), lambda: M('undead/greater_mummy'), lambda: M('unique/menkaure')],
    'ghost': [lambda: M('undead/ghost_new'), lambda: M('undead/hungry_ghost'), lambda: M('undead/silent_spectre')],
    'anubis': lambda: M('anubis_guard'),
    # Zwerge
    'rune_master': [lambda: M('deep_dwarf_artificer'), lambda: M('ironbrand_convoker'),
                    lambda: M('ironheart_preserver')],
    'stone_guard': [lambda: M('nonliving/gargoyle'), lambda: M('nonliving/metal_gargoyle'),
                    lambda: M('nonliving/iron_golem')],
    'fire_dwarf': lambda: glow(doll('dwarf_male', 'legs/leg_armor_0', 'boots/long_red', 'body/leather_red',
                                    'beard/long_red', 'head/iron_red', 'hand_right/hammer_3'), '#f08a24', 120),
    'dwarf_knight': lambda: doll('dwarf_male', 'legs/leg_armor_1', 'boots/middle_gold', 'body/plate_2',
                                 'beard/long_yellow', 'head/full_gold', 'hand_right/mace_new',
                                 'hand_left/shield_knight_rw'),
    'dwarf_gunner': lambda: doll('dwarf_male', 'legs/pants_brown', 'boots/middle_brown', 'body/leather_stud',
                                 'beard/short_yellow', 'head/brown_gold', 'hand_right/crossbow_4'),
    'thor': lambda: glow(doll(HUMAN, 'cloak/red', 'legs/leg_armor_2', 'boots/blue_gold', 'body/plate_and_cloth_2',
                              'beard/long_red', 'hair/long_red', 'head/viking_gold', 'hand_right/hammer_3'),
                         '#ffe14a', 130),
    # Elfen
    'fire_elf': lambda: glow(doll('elf_male', 'cloak/red', 'legs/pants_red', 'boots/long_red', 'body/robe_red_3',
                                  'hair/elf_red', 'hand_right/bow_3'), '#f08a24', 110),
    'treant': lambda: M('fungi_plants/treant'),
    'dark_elf': [lambda: M('deep_elf_fighter_new'), lambda: M('deep_elf_blademaster'),
                 lambda: M('deep_elf_annihilator')],
    'elf_mage': [lambda: M('deep_elf_mage'), lambda: M('deep_elf_conjurer'), lambda: M('deep_elf_summoner')],
    'beast_master': lambda: doll('elf_male', 'legs/pants_brown', 'boots/short_brown', 'body/animal_skin',
                                 'hair/elf_black', 'head/bear', 'hand_right/whip_new'),
    # Hexen und Märchen
    'red_hood': lambda: doll(HUMAN_F, 'cloak/red', 'boots/short_red', 'body/dress_white', 'hair/fem_yellow',
                             'head/hood_red', 'hand_right/dagger_new'),
    'broom_witch': lambda: doll(HUMAN_F, 'cloak/cyan', 'boots/short_purple', 'body/robe_cyan', 'hair/fem_red',
                                'head/hat_black', 'hand_right/quarterstaff_jester'),
    'snow_queen': lambda: glow(doll(HUMAN_F, 'cloak/white', 'boots/mesh_white', 'body/robe_white_blue',
                                    'hair/fem_white', 'head/crown_gold_3', 'hand_right/rod_moon_new'),
                               '#8fe0ff', 130),
    'medusa': [lambda: M('greater_naga'), lambda: M('naga_ritualist'), lambda: M('unique/vashnia')],
    'siren': [lambda: M('siren_new'), lambda: M('siren_water_new'), lambda: M('unique/ilsuiw_new')],
    'loki': lambda: M('unique/mara'),
    'gnome_rider': lambda: ride(M('animals/wolf', flip=True), tile('monster/gnome'), 16, 13, 18),
    # Riesen
    'fire_giant': lambda: M('fire_giant_new'),
    'ice_giant': lambda: M('frost_giant_new'),
    'stone_giant': lambda: M('stone_giant_new'),
    'minotaur': lambda: M('minotaur'),
    'hercules': lambda: doll(HUMAN, 'legs/loincloth_red', 'boots/short_brown', 'body/animal_skin', 'hair/brown_1',
                             'beard/short_black', 'hand_right/giant_club'),
    'achilles': lambda: doll(HUMAN, 'cloak/red', 'legs/leg_armor_0', 'boots/middle_gold', 'body/armor_blue_gold',
                             'head/helm_red', 'hand_right/spear', 'hand_left/shield_round_2'),
    # Pferde und Reittiere
    'pegasus': lambda: wings(horse('white')),
    'unicorn': lambda: horn(horse('white')),
    'nightmare': lambda: glow(horse('fire', '#ff3b1a'), '#ff6a1a', 120),
    'sleipnir': lambda: glow(barding(horse('grey'), '#264b94', '#c8ccd8'), '#c8ccd8', 110),
    'kelpie': lambda: horse('sea', '#5ff2ff'),
    'valkyrie': lambda: doll(HUMAN_F, 'cloak/white', 'legs/leg_armor_1', 'boots/mesh_white', 'body/half_plate',
                             'hair/fem_yellow', 'head/yellow_wing', 'hand_right/spear_2_new',
                             'hand_left/shield_round_3'),
    'wolf_knight': lambda: ride(M('animals/warg', flip=True),
                                rider_doll(HUMAN, 'body/plate_black', 'head/horned', 'hand_right/long_sword'),
                                16, 14),
    # Grundlinien untereinander
    'mercenary': lambda: doll(HUMAN, 'legs/pants_brown', 'boots/middle_brown', 'body/leather_stud',
                              'gloves/glove_brown', 'head/iron_2', 'hand_right/falchion_new',
                              'hand_left/shield_round_4'),
    'arcane_archer': lambda: glow(doll('elf_female', 'cloak/magenta', 'boots/middle_purple', 'body/robe_purple',
                                       'hair/elf_white', 'hand_right/bow_3'), '#c04cff', 110),
    'wild_hunter': lambda: doll(HUMAN, 'cloak/brown', 'legs/pants_brown', 'boots/middle_brown',
                                'body/leather_armor_3', 'head/horns_1', 'hand_right/spear_2_new'),
    'mage_rider': lambda: mounted('grey', HUMAN, 'cloak/blue', 'body/robe_blue', 'head/wizard_blue',
                                  'beard/long_white', 'hand_right/staff_mage'),
    # Heilkunst
    'field_medic': lambda: doll(HUMAN, 'legs/pants_l_white', 'boots/middle_brown', 'body/robe_white_red',
                                'head/band_red', 'hand_right/knife', 'hand_left/buckler_rb'),
    'fairy': [lambda: M('unique/psyche_new'), lambda: glow(M('unique/psyche_new'), '#fff4b0', 150),
              lambda: glow(M('unique/psyche_new'), '#ffd91f', 220, 2)],
    'priest': lambda: doll(HUMAN, 'boots/mesh_white', 'body/robe_white_2', 'hair/short_white', 'head/hood_white',
                           'hand_right/staff_mummy'),
    'druid': lambda: doll(HUMAN, 'boots/middle_green', 'body/robe_green_gold', 'beard/long_white',
                          'head/hood_green_2', 'hand_right/staff_organic'),
    'nymph': lambda: M('water_nymph'),
    'dryad': lambda: M('dryad'),
    'plague_doctor': lambda: doll(HUMAN, 'cloak/black', 'boots/mesh_black', 'body/robe_black', 'gloves/glove_black',
                                  'head/hat_black', 'hand_right/staff_plain'),
    'witch_doctor': lambda: M('gnoll_shaman'),
    'silver_unicorn': lambda: glow(horn(horse('white'), '#dfe6f2'), '#dfe6f2', 150),
    'angel': [lambda: M('angel'), lambda: M('holy/angel_mace'),
              lambda: pi.layered(*[pi.pad(M(f'holy/seraph_{part}'), 0, off, 0, 32 - off)
                                   for part, off in (('bottom', 32), ('top', 0))])],
    'asclepius': lambda: glow(doll(HUMAN, 'boots/blue_gold', 'body/robe_white_2', 'beard/long_white',
                                   'hair/long_white', 'hand_right/staff_organic'), '#ffd91f', 150),
    # Geheimrezepte
    'king_arthur': lambda: doll(HUMAN, 'cloak/red', 'legs/leg_armor_1', 'boots/blue_gold', 'body/armor_blue_gold',
                                'head/crown_gold_1', 'hair/short_yellow', 'hand_right/blessed_blade',
                                'hand_left/shield_knight_rw'),
    'merlin': lambda: doll(HUMAN, 'body/gandalf_g', 'beard/long_white', 'head/gandalf', 'hand_right/gandalf'),
    'baba_yaga': lambda: M('unique/agnes_new'),
    'kraken': lambda: M('aquatic/kraken_head_new'),
    'robin_hood': lambda: doll(HUMAN, 'cloak/green', 'legs/trouser_green', 'boots/middle_brown', 'body/aragorn',
                               'hair/brown_2', 'head/feather_green', 'hand_right/bow_2'),
}


# --- Gegner ----------------------------------------------------------------------------

ENEMIES = {
    'slime': lambda: M('amorphous/azure_jelly_new'),
    'goblin': lambda: M('goblin_new'),
    'bone_archer': lambda: with_parts(M('undead/skeletons/skeleton_humanoid_small'), 'hand_right/bow'),
    'orc': lambda: M('orc_warrior_new'),
    'ogre': lambda: M('ogre_new'),
    'boss_ogre': lambda: big(crown(M('two_headed_ogre_new'))),
    'boss_dragon': lambda: big(M('unique/xtahua_new')),
    'boss_bones': lambda: big(M('undead/eidolon')),
    'boss_golem': lambda: big(M('nonliving/stone_golem')),
}


def finish(img):
    return pi.trim(img)


def build():
    """Liefert (Einheiten, Gegner) als Dict Id -> Img."""
    units = {}
    for key, line in content.LINES.items():
        for uid in line['ids']:
            units[uid] = finish(LINE[uid]())
    for base, combo in content.COMBOS.items():
        spec = COMBO[base]
        color = combo['color']
        for level, uid in enumerate(content.combo_ids(base), 1):
            if isinstance(spec, list):
                img = spec[level - 1]()
            else:
                img = tier(spec(), level, color)
            units[uid] = finish(img)
    enemies = {uid: finish(fn()) for uid, fn in ENEMIES.items()}
    return units, enemies


# --- Animation -------------------------------------------------------------------------
# Wie bei 0x72: je 4 Bilder Stehen (Atmen) und Laufen (Wippen, Beine schwingen), nebeneinander in einem
# Streifen. Aus der Einzelkachel abgeleitet: der Oberkörper bewegt sich gegen die Beine.

ANIM_FRAMES = 8
IDLE = [(0, 0, 0), (1, 0, 0), (1, 0, 0), (0, 0, 0)]      # (Oberkörper tiefer, Beine schräg, ganze Figur höher)
RUN = [(0, 2, 0), (0, 0, 1), (0, -2, 0), (0, 0, 1)]
LEG_SHARE = 0.36


def _is_shadow(c):
    return c[3] <= 130 and max(c[:3]) < 24


def _frame(img, breathe, shear, lift):
    out = Img(img.w + 4, img.h + 1)
    split = img.h - round(img.h * LEG_SHARE)
    legs = max(1, img.h - split)
    for y in range(img.h):
        for x in range(img.w):
            c = img.px[y * img.w + x]
            if not c[3]:
                continue
            if _is_shadow(c):
                out.set(x + 2, y + 1, pi.over(out.get(x + 2, y + 1), c))
                continue
            dx, dy = 0, 1 - lift
            if y < split:
                dy += breathe
            else:
                dx = round(shear * (y - split + 1) / legs)
            out.set(x + 2 + dx, y + dy, pi.over(out.get(x + 2 + dx, y + dy), c))
    return out


def animate(img):
    frames = [_frame(img, *f) for f in IDLE + RUN]
    strip = Img(frames[0].w * len(frames), frames[0].h)
    for i, frame in enumerate(frames):
        pi.paste(strip, frame, i * frame.w, 0)
    return strip
