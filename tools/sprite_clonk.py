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

FIGURES = {'clonk': {'KNIGHT': KNIGHT, 'ARCHER': ARCHER, 'MAGE': MAGE, 'HEALER': HEALER, 'DWARF': DWARF,
                     'HORSE': HORSE, 'WOLF': WOLF, 'DRAGON': DRAGON, 'GOBLIN': GOBLIN, 'ORC': ORC,
                     'SKELETON': SKELETON, 'GOLEM': GOLEM}}


for _set in FIGURES.values():
    for _name, _grid in _set.items():
        assert len({len(r) for r in _grid}) == 1, _name  # alle Zeilen gleich breit
