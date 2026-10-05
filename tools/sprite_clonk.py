"""Alternative Grundfiguren (Entwurf) nach Art klassischer Clonk-Männchen, dazu passende Tiere und Gegner: Seitenansicht nach rechts,
runder Kopf mit Nase und einem Auge, schmaler Körper, Schrittstellung. Eigene Zeichnungen.

Die Raster nutzen dieselben Palettenzeichen wie die Originale (damit die Stufen-Färbungen greifen) und
halten Kopf, Brust und Hand ungefähr an den Ankerpunkten aus sprite_kits.ANCHORS.
Aufruf über generate_sprites.py --figures clonk.
"""

KNIGHT = [
    "......r.........",
    ".....krkk.......",
    "....kgggGk......",
    "...kgggggGk...w.",
    "...kggggggGk..w.",
    "...kGkssksSk..w.",
    "...kGssssssSk.w.",
    "....kGsssSkk..w.",
    ".....kkkkk...kyk",
    "..kkkgggggk.ksk.",
    ".kuuukgggGkkk...",
    ".kuyukgggGk.....",
    ".kuuukGGGGk.....",
    "..kkk.kdkkdk....",
    ".....kdk..kdk...",
    "....kkk....kkk..",
]

ARCHER = [
    "................",
    ".....kkkk.......",
    "....knnnnk...b..",
    "...knnnnnNk..wb.",
    "..knnNsssssk.w.b",
    "..kNnsssksSk.w.b",
    "...kNssssssskw.b",
    "....kSssssk..w.b",
    ".....kkkkk...w.b",
    "....knnnnNk..w.b",
    "...knnnnnNkkkssb",
    "..kBknnnnNk..w.b",
    "..kBkNNNNNk..wb.",
    "...k.kBkkBk..b..",
    ".....kBk.kBk....",
    "....kkk...kkk...",
]

MAGE = [
    "......p......ccc",
    ".....pPp.....ccc",
    "....pPPPp.....b.",
    "...pPPyPPp....b.",
    "..kppppppppk..b.",
    "...kssssksSk..b.",
    "...kssssssssk.b.",
    "....kwwwwwk...b.",
    "....kwwwwwwk..b.",
    "...kpPwwwppk..b.",
    "...kpPpppppkkssk",
    "..kpPppyyyppk.b.",
    "..kpPpppppppk.b.",
    "..kpPpppppppk.b.",
    "..kppppppppppkb.",
    "...kkkkkkkkkk.b.",
]

HEALER = [
    "..............nn",
    ".....kkkk....nNn",
    "....kwwwwk....b.",
    "...kwwwwwWk...b.",
    "..kwwwsssssk..b.",
    "..kWwsssksSk..b.",
    "...kWssssssssk..",
    "....kSssssk...b.",
    ".....kkkkk....b.",
    "....kwwwwwk...b.",
    "...kwwrwwWkkkssk",
    "...kwrrrwWk...b.",
    "...kwwrwwWk...b.",
    "...kwwwwwWk...b.",
    "...kWwwwwWWk..b.",
    "....kkkkkkkk..b.",
]

DWARF = [
    "................",
    "................",
    ".....kkkkk......",
    "....kGGGGGk..kk.",
    "...kGGGGGGGk.kdk",
    "...kyyyyyyyk.kdk",
    "...ksssksSssk.b.",
    "...kRsssssSsk.b.",
    "..kRRRRRssk...b.",
    "..kRRRRRRRk..kb.",
    "..kkRRRRRkkkksk.",
    "..kbbbBBbbk...b.",
    "..kbbbbbbbbk..b.",
    "...kBBkkBBk...b.",
    "..kBBk..kBBk....",
    "..kkkk..kkkk....",
]


HORSE = [
    "...............kk.....",
    "..............kmmk....",
    ".............kmhhhkk..",
    "............kmhhhkhhk.",
    "............kmhhhhhhhk",
    "....kkkkkkkkkmhhhhHHk.",
    "..kkhhhhhhhhhhhhkkkk..",
    ".kmkhhhhhhhhhhhhk.....",
    "kmmkhhhhhhhhhhhHk.....",
    "km.kHhhhhhhhhhHHk.....",
    "k...kHHHHHHHHHHk......",
    "....kHk.kHk.kHk.kHk...",
    "...kHk..kHk..kHk.kHk..",
    "...kkk..kkk..kkk.kkk..",
]

WOLF = [
    "..........k.k...",
    ".........kGkGk..",
    "..kkkkkkkGGGGGk.",
    ".kGGGGGGGGGkGGGk",
    "kGGGGGGGGGGGGGGk",
    "kGGGGGGGGGGGGrk.",
    ".kGgggggGGGGkk..",
    "..kgggggGGGk....",
    "..kGk.kGk.kGk...",
    ".kGk..kGk..kGk..",
    ".kdk...kdk.kdk..",
    ".kkk...kkk.kkk..",
]

DRAGON = [
    "....kk..........",
    "...kRRk.....kkk.",
    "..kRRRRk...kNNNk",
    "..kRRRRRk.kNNyNk",
    "...kRRRRkkNNNNNk",
    ".kkkNNNNNNNNNkk.",
    "kNNNNNNNNNNNNk..",
    "kNkNnnnnnnNNk...",
    ".k.kNnnnnNNNk...",
    "...kNNNNNNNk....",
    "...kNk..kNk.....",
    "...kkk..kkk.....",
]

GOBLIN = [
    "............",
    "....kkkk....",
    "..kkNNNNk...",
    ".kNNNNNNNk..",
    "kNNkNNNrNNk.",
    ".kkNNNNNNNNk",
    "...kNNNNkk..",
    "...kbbbbk...",
    "..kbbBBbbk..",
    "..kNbbbbkNk.",
    "...kbbbbk...",
    "...kNk.kNk..",
    "..kNk...kNk.",
    "..kkk...kkk.",
]

ORC = [
    "................",
    "....kkkkk.......",
    "...klllllk......",
    "..klllllllk.kk..",
    "..kllllrllk.kdk.",
    "..klllllllllkdgk",
    "..kllllwlllk.bk.",
    "...kkllllkk..b..",
    "..kdddddddk..b..",
    ".kdddgddddkkkb..",
    ".kldddddddkllk..",
    "..kddddddk..b...",
    "..kkdddddk..b...",
    "...klk.klk......",
    "..klk...klk.....",
    "..kkk...kLkk....",
]

SKELETON = [
    "....kkkk....",
    "...kwwwwk...",
    "..kwwwwwwk..",
    "..kwwwkwwk..",
    "..kwwwwwwwk.",
    "...kwkwkwk..",
    "....kkkk..b.",
    "...kwwwk..bb",
    "..kwkwkwk.b.",
    "..kwwwwwkkb.",
    "...kwkwk..b.",
    "....kwwk..b.",
    "...kwk.kwk..",
    "..kwk...kwk.",
    "..kwk...kwk.",
    ".kkkk..kkkk.",
]

GOLEM = [
    "............",
    "....kkkk....",
    "...kgGGgk...",
    "...kGGGyk...",
    "..kkGGGGkk..",
    ".kggGGGGGGk.",
    "kgGGGGGGGGGk",
    "kGGkGGGGGkGk",
    "kGkkGgGGGkkk",
    ".k.kGGGGGk..",
    "...kGGGGGGk.",
    "...kGGkkGGk.",
    "..kdk...kdk.",
    "..kkk...kkk.",
]

FLAME = [
    "..k.........",
    ".kok..k.....",
    ".kook.kok...",
    "..kookoook..",
    "..koooooook.",
    ".kooyyyyook.",
    ".kooyyykyok.",
    "kooyyyyyyyok",
    "kooyyyyyyok.",
    "krooyyyyook.",
    ".krooyyoork.",
    ".kkroooorkk.",
    "..kkrrrrkk..",
    "....kkkk....",
]

DROP = [
    "..kk........",
    "..kuk.......",
    "...kuk......",
    "...kuuk.....",
    "..kuuuuk....",
    "..kuuuuuk...",
    ".kuwcuuuuk..",
    ".kuwuuukuuk.",
    ".kuuuuuuuuuk",
    ".kuuuuuuuuk.",
    ".kUuuuuuuUk.",
    "..kUUuuuUUk.",
    "...kUUUUUk..",
    "....kkkkk...",
]

SWIRL = [
    "..kkkkkkk...",
    ".kwwwwwwwk..",
    "kwwcwwwkwwk.",
    "kwwwwwwwwwwk",
    ".kcwwwwwwck.",
    "..kkwwwwkk..",
    "...kwwwwk...",
    "..kcwwwck...",
    "..kkkkkk....",
    "...kwwck....",
    "...kkkkk....",
    "....kwck....",
    "....kkk.....",
]

EGG = [
    "....kk....",
    "...kwwk...",
    "..kwwwwk..",
    ".kwwnnwwk.",
    ".kwkwwknk.",
    ".kwwkkwwk.",
    ".kwnwwwwk.",
    ".kwwwnnwk.",
    "..kwwwwk..",
    "...kkkk...",
]

SLIME = [
    "............",
    "...kkkkk....",
    "..knnnnnk...",
    ".knnwnnnnk..",
    ".knnnnnknnk.",
    "knnnnnnnnnnk",
    "knNnnnnnnnnk",
    "kNNnnnnnnnNk",
    ".kNNNNNNNNk.",
    "..kkkkkkkk..",
]

# Bosse: eigene, doppelt so feine Zeichnungen (generate_sprites vergrößert sie 2-fach statt 3-fach),
# Farben und Krone schon fertig, kein Paletten-Tausch mehr.
BOSSES = {
    'boss_ogre': [
        "......y.y.y.............",
        "......yyyyy.............",
        "......YYYYY.............",
        ".....kkkkkkk............",
        "....khhhhhhhk...........",
        "...khhhhhhhhhk..........",
        "...khhhhhkrhhhk.........",
        "...khhhhhhhhhhhk........",
        "...khhhhhhhhhhhhk.......",
        "....khhhhwhhhhkk........",
        ".....kkhhhhhkk.......kk.",
        "....kBBBBBBBBBk.....kbbk",
        "...kBBhhhhhhBBBk...kbbbk",
        "..khBhhhhhhhhhBBk.kbbbk.",
        "..khhhhhhhhhhhhhBkkbbk..",
        "..khhhhhhhhhhhhhhkhbk...",
        "...khhhhhhhhhhhhkhhk....",
        "...kBBBBBBBBBBBBkkk.....",
        "...kBBBBBBBBBBBBk.......",
        "....kBBBBBkBBBBk........",
        ".....kHHk...kHHk........",
        "....kHHk.....kHHk.......",
        "....kHHk.....kHHk.......",
        "...kHHHk....kHHHk.......",
        "...kkkkk....kkkkk.......",
    ],
    'boss_dragon': [
        "................y.y.y...",
        "................yyyyy...",
        "....kk..........YYYYY...",
        "...kOOk........kkkkkk...",
        "..kOOOOk......krrrrrrk..",
        "..kOOOOOk....krrrrkyrrk.",
        "..kOOOOOOk..krrrrrrrrrrk",
        "...kOOOOOOkkrrrrrrrrkkk.",
        "...kOOOOOOOkrrrrrrrk....",
        "....kOOOOOOkrrrrrrk.....",
        "..kkkrrrrrrrrrrrrk......",
        ".krrrrrrrrrrrrrrrk......",
        "krrkrrooooooorrrrk......",
        "krk.kroooooooorrrk......",
        ".k..kroooooooorrk.......",
        "....krrooooorrrrk.......",
        ".....krrrrrrrrrk........",
        ".....krrk...krrk........",
        "....krrk....krrk........",
        "....krrk...krrrk........",
        "...kkkkk...kkkkk........",
    ],
    'boss_bones': [
        "......y.y.y.............",
        "......yyyyy.............",
        "......YYYYY.............",
        ".....kkkkkkk............",
        "....kWWWWWWWk...........",
        "...kWWWWWWWWWk......p...",
        "...kWWWWWkkWWk.....ppp..",
        "...kWWWWWkkWWWk.....p...",
        "...kWWWWWWWWWWk.....p...",
        "....kWkWkWkWk.......p...",
        ".....kkkkkkk........p...",
        "......kWWk.........kp...",
        "....kpWWWWWpk.....kWk...",
        "...kpWkkkkkWpk...kWk....",
        "...kpWWWWWWWpk.kkWk.....",
        "...kpWkkkkkWpkkWWk......",
        "...kpWWWWWWWpk..........",
        "....kpWkkkWpk...........",
        "....kppWWWppk...........",
        ".....kWk.kWk............",
        "....kWk...kWk...........",
        "....kWk...kWk...........",
        "...kWWk...kWWk..........",
        "...kkkk...kkkk..........",
    ],
    'boss_golem': [
        "........y.y.y...........",
        "........yyyyy...........",
        "........YYYYY...........",
        ".......kkkkkkk..........",
        "......kcuuuuuuk.........",
        "......kuuuuurrk.........",
        "......kuuuuuuuuk........",
        "...kkkkkuuuuuukkkk......",
        "..kcuuuukkkkkkuuuuk.....",
        ".kcuuuuuuuuuuuuuuuuk....",
        ".kuuuuuuuuuuuuuukuuk....",
        "kuuuukuuuuuuuuukkuuuk...",
        "kuuuukUuuuuuuuuk.kuuuk..",
        "kuuuk.kUuuuuuuUk.kuuuk..",
        ".kkk..kUuuuuuuUk..kkk...",
        "......kUUuuuuUUk........",
        ".....kUUUkkkUUUk........",
        ".....kUUk...kUUk........",
        "....kUUUk...kUUUk.......",
        "....kkkkk...kkkkk.......",
    ],
}

def _rows(ch, x0, x1, y0, y1):
    return [(x, y, ch) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)]


# Merkmale der Heil-Kombinationen (wie generate_sprites.HEAL_DECOR), passend zu HEALER und HORSE oben:
# Kopf in Zeile 1-8 (Gesicht rechts, Hinterkopf links), Körper Zeile 9-15, Stab in Spalte 14, Rücken links.
HEAL_DECOR = {
    # Feldarzt: Stahlhelm mit Federbusch und Schulterpanzer
    'field_medic': [(5, 0, 'k'), (6, 0, 'r'), (7, 0, 'r'), (8, 0, 'k')] + _rows('g', 5, 8, 1, 1) + _rows('g', 4, 9, 2, 2)
                   + [(3, 3, 'G'), (4, 3, 'g'), (9, 3, 'g'), (10, 3, 'G'), (3, 9, 'g'), (4, 9, 'G'), (10, 9, 'g'), (11, 9, 'G')],
    # Fee: Flügel am Rücken, Funken
    'fairy': _rows('c', 0, 2, 8, 11) + [(1, 7, 'c'), (2, 7, 'c'), (0, 12, 'c'), (1, 9, 'w'), (1, 10, 'w'), (2, 9, 'w'),
                                        (1, 3, 'y'), (11, 0, 'w'), (0, 14, 'y')],
    # Priester: goldene Mitra und Gürtel
    'priest': [(5, 0, 'k'), (6, 0, 'y'), (7, 0, 'y'), (8, 0, 'k'), (4, 1, 'k'), (5, 1, 'Y'), (6, 1, 'y'), (7, 1, 'r'),
               (8, 1, 'Y'), (9, 1, 'k')] + _rows('y', 4, 9, 13, 13),
    # Druide: Geweih mit Blättern, Ranke am Gewand
    'druid': [(3, 0, 'b'), (3, 1, 'b'), (4, 1, 'b'), (2, 0, 'n'), (10, 0, 'b'), (9, 1, 'b'), (10, 1, 'b'), (11, 0, 'n'),
              (4, 11, 'n'), (5, 12, 'N'), (4, 13, 'n')],
    # Quellnymphe: lange Wasserhaare den Rücken hinunter
    'nymph': _rows('c', 1, 2, 4, 11) + _rows('u', 0, 0, 6, 12) + [(6, 0, 'c'), (7, 0, 'c')],
    # Dryade: Blätterkrone mit Blüte und Ranken
    'dryad': [(4, 1, 'n'), (5, 0, 'n'), (6, 0, 'N'), (7, 0, 'r'), (8, 0, 'N'), (9, 1, 'n'), (3, 2, 'n'), (10, 2, 'N'),
              (4, 11, 'n'), (4, 12, 'N'), (5, 13, 'n')],
    # Pestdoktor: breiter Hut und Schnabelmaske nach vorn
    'plague_doctor': _rows('k', 5, 8, 0, 1) + _rows('k', 2, 11, 2, 2)
                     + [(11, 6, 'e'), (12, 6, 'e'), (13, 6, 'e'), (11, 7, 'e'), (12, 7, 'e'), (14, 6, 'k'), (13, 7, 'k'),
                        (8, 5, 'y')],
    # Medizinmann: Federschmuck und Knochenkette
    'witch_doctor': [(4, 0, 'r'), (5, 0, 'r'), (6, 0, 'y'), (7, 0, 'n'), (8, 0, 'u'), (9, 0, 'u'), (4, 1, 'r'), (9, 1, 'u'),
                     (5, 9, 'w'), (6, 9, 'w'), (7, 9, 'w'), (8, 9, 'w'), (7, 10, 'w')],
    # Engel: Heiligenschein und große weiße Flügel am Rücken
    'angel': _rows('w', 0, 2, 7, 12) + [(1, 6, 'w'), (2, 6, 'w'), (0, 13, 'w'), (1, 9, 'W'), (1, 10, 'W'), (2, 10, 'W'),
                                        (5, 0, 'y'), (6, 0, 'y'), (7, 0, 'y'), (8, 0, 'y')],
    # Silbereinhorn: goldenes Horn auf der Stirn, Mähne in Wasserblau
    'silver_unicorn': [(17, 1, 'y'), (18, 0, 'y'), (18, 1, 'Y'), (14, 1, 'c'), (15, 1, 'c'), (14, 2, 'c'), (13, 3, 'c'),
                       (13, 4, 'c'), (13, 5, 'u')],
    # Asklepios: weißer Bart und Schlange um den Stab
    'asclepius': _rows('w', 6, 10, 7, 7) + [(7, 8, 'w'), (8, 8, 'w'),
                  (15, 3, 'n'), (13, 4, 'n'), (15, 5, 'n'), (13, 7, 'N'), (15, 8, 'n'), (13, 9, 'N'), (15, 11, 'N'),
                  (14, 2, 'n'), (15, 2, 'n')],
}

FIGURES = {'clonk': {'KNIGHT': KNIGHT, 'ARCHER': ARCHER, 'MAGE': MAGE, 'HEALER': HEALER, 'DWARF': DWARF,
                     'HORSE': HORSE, 'WOLF': WOLF, 'DRAGON': DRAGON, 'GOBLIN': GOBLIN, 'ORC': ORC,
                     'SKELETON': SKELETON, 'GOLEM': GOLEM, 'FLAME': FLAME, 'DROP': DROP, 'SWIRL': SWIRL,
                     'EGG': EGG, 'SLIME': SLIME}}
BOSS_FIGURES = {'clonk': BOSSES}
DECOR = {'clonk': HEAL_DECOR}


for _set in list(FIGURES.values()) + list(BOSS_FIGURES.values()):
    for _name, _grid in _set.items():
        assert len({len(r) for r in _grid}) == 1, _name  # alle Zeilen gleich breit
