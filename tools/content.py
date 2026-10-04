"""Inhalte (Einheiten, Entwicklungslinien, Kombinationen) als Zahlentabelle.

Wird von generate_data.py (.tres-Dateien) und generate_sprites.py (PNGs) benutzt.
Hier werden Namen, Werte und Kosten geändert, danach beide Skripte neu ausführen.
"""

# Selbst-Merge: Stufe n+1 entsteht aus zwei Einheiten der Stufe n.
UPGRADE_COST = [6, 14, 30, 70]      # Kosten für Stufe 1->2, 2->3, 3->4, 4->5
LEVEL_UNLOCK_ROUND = [1, 1, 2, 4, 7]  # ab dieser Runde darf Stufe n entstehen

# Jede Linie entspricht einer Bucht im Geister-Bereich (Stufe 1 = Ergebnis der Bucht).
LINES = {
    'melee': {
        'int': [5, 8, 12, 15, 20],
        'name': 'Nahkampf', 'order': 1,
        'ids': ['peasant', 'squire', 'knight', 'crusader', 'bodyguard'],
        'names': ['Bauer', 'Knappe', 'Ritter', 'Kreuzritter', 'Leibwächter'],
        'hp': [22, 30, 40, 80, 150], 'atk': [2.5, 3.5, 5, 10, 18],
        'rng': [12, 13, 14, 15, 16], 'cd': [1.0, 0.9, 0.8, 0.8, 0.7], 'spd': [38, 40, 40, 40, 42],
        'colors': ['#9a6732', '#c8ccd8', '#8795ad', '#f4f4f4', '#55607a'],
    },
    'ranged': {
        'int': [20, 25, 30, 40, 50],
        'name': 'Fernkampf', 'order': 2,
        'ids': ['slinger', 'archer', 'hunter', 'sharpshooter', 'hawkeye'],
        'names': ['Schleuderer', 'Bogenschütze', 'Jäger', 'Scharfschütze', 'Falkenauge'],
        'hp': [14, 20, 30, 48, 80], 'atk': [3, 5, 8, 14, 24],
        'rng': [70, 90, 100, 115, 130], 'cd': [1.1, 1.0, 1.0, 0.9, 0.8], 'spd': [35, 35, 35, 36, 38],
        'colors': ['#9a6732', '#58b84e', '#7ba333', '#3f78d8', '#d63c34'],
    },
    'magic': {
        'int': [40, 55, 70, 90, 110],
        'name': 'Magie', 'order': 3,
        'ids': ['apprentice', 'mage', 'archmage', 'grand_mage', 'world_weaver'],
        'names': ['Lehrling', 'Magier', 'Erzmagier', 'Großmeister', 'Weltenweber'],
        'hp': [12, 18, 32, 55, 90], 'atk': [5, 9, 16, 28, 46],
        'rng': [60, 70, 80, 90, 100], 'cd': [1.8, 1.6, 1.4, 1.2, 1.0], 'spd': [30, 30, 30, 30, 32],
        'colors': ['#9a6732', '#9b50c8', '#3f78d8', '#d63c34', '#f4f4f4'],
    },
    'cavalry': {
        'int': [3, 4, 5, 6, 8],
        'name': 'Reittiere', 'order': 4,
        'ids': ['foal', 'horse', 'warhorse', 'destrier', 'stormsteed'],
        'names': ['Fohlen', 'Pferd', 'Streitross', 'Schlachtross', 'Sturmross'],
        'hp': [18, 30, 55, 95, 160], 'atk': [1, 2, 4, 7, 11],
        'rng': [12, 12, 12, 12, 12], 'cd': [1.0, 1.0, 1.0, 1.0, 1.0], 'spd': [60, 70, 75, 80, 85],
        'colors': ['#f4e9a0', '#c98a4b', '#8f5d2c', '#8795ad', '#8fe0ff'],
    },
}

# Kombinationen aus zwei verschiedenen Einheiten. Jede hat selbst 3 Selbst-Merge-Stufen.
COMBO_STAT_MULT = [1.0, 1.8, 3.2]
COMBO_INT_MULT = [1.0, 1.3, 1.7]
COMBO_UPGRADE_MULT = [1.5, 3.0]
COMBO_UNLOCK_STEP = 3
COMBOS = {
    'mounted_knight': {
        'names': ['Berittener Reiter', 'Schwerer Reiter', 'Reiter-Champion'],
        'a': 'knight', 'b': 'horse', 'cost': 20, 'unlock': 3,
        'stats': (90, 9, 14, 0.8, 75), 'color': '#c7d2e8',
    },
    'mounted_archer': {
        'names': ['Berittener Schütze', 'Reitender Bogner', 'Steppenjäger'],
        'a': 'archer', 'b': 'horse', 'cost': 14, 'unlock': 2,
        'stats': (55, 7, 90, 0.9, 65), 'color': '#9bd68f',
    },
    'paladin': {
        'names': ['Paladin', 'Hochpaladin', 'Lichtbringer'],
        'a': 'knight', 'b': 'mage', 'cost': 25, 'unlock': 4,
        'stats': (80, 12, 30, 0.9, 40), 'color': '#f0d878',
    },
    'holy_rider': {
        'names': ['Heiliger Reiter', 'Erzheiliger Reiter', 'Himmelsreiter'],
        'a': 'mounted_knight', 'b': 'mage', 'cost': 60, 'unlock': 5,
        'stats': (170, 20, 35, 0.8, 70), 'color': '#fff4b0',
    },
    'legend': {
        'names': ['Legende', 'Mythos', 'Halbgott'],
        'a': 'holy_rider', 'b': 'archmage', 'cost': 150, 'unlock': 8,
        'stats': (300, 40, 80, 0.7, 70), 'color': '#ff9a3c',
    },
}


def combo_ids(base):
    return [base, f'{base}_2', f'{base}_3']


# --- Weitere Entwicklungslinien (Fantasy, Märchen, Mythologie) ---------------------
# Werte pro Stufe = Basiswerte der Stufe 1 mal Multiplikatoren.
_HP_MULT = [1, 1.6, 2.4, 4.2, 7.5]
_ATK_MULT = [1, 1.7, 2.8, 5.0, 9.0]


def _generated_line(name, order, ids, names, base, colors, hp_mult=None, atk_mult=None):
    hp, atk, rng, cd, spd = base
    hp_mult = hp_mult or _HP_MULT
    atk_mult = atk_mult or _ATK_MULT
    n = len(ids)
    return {
        'name': name, 'order': order, 'ids': ids, 'names': names,
        'hp': [round(hp * hp_mult[i]) for i in range(n)],
        'atk': [round(atk * atk_mult[i], 1) for i in range(n)],
        'rng': [rng] * n, 'cd': [cd] * n, 'spd': [spd] * n,
        'colors': colors,
    }


LINES['dwarf'] = _generated_line(
    'Zwerge', 5, ['miner', 'dwarf_warrior', 'axe_master', 'dwarf_lord', 'mountain_king'],
    ['Minenarbeiter', 'Zwergenkrieger', 'Axtmeister', 'Zwergenlord', 'Bergkönig'],
    (24, 2.5, 12, 1.0, 30), ['#5e3b1a', '#8795ad', '#c8ccd8', '#f5c935', '#f5c935'])
LINES['elf'] = _generated_line(
    'Elfen', 6, ['elf_scout', 'wood_elf', 'high_elf', 'elf_lord', 'elf_king'],
    ['Elfenspäher', 'Waldelf', 'Hochelf', 'Elfenfürst', 'Elfenkönig'],
    (12, 3.5, 95, 0.9, 42), ['#7ba333', '#8fe0ff', '#f4f4f4', '#f5c935', '#9b50c8'])
LINES['undead'] = _generated_line(
    'Untote', 7, ['skeleton', 'ghoul', 'revenant', 'death_knight', 'lich_king'],
    ['Skelett', 'Ghul', 'Wiedergänger', 'Todesritter', 'Lichkönig'],
    (16, 2.5, 12, 1.0, 34), ['#f4f4f4', '#58b84e', '#c8ccd8', '#3f78d8', '#9b50c8'])
LINES['dragon'] = _generated_line(
    'Drachen', 8, ['dragon_egg', 'wyrmling', 'young_dragon', 'dragon', 'elder_dragon'],
    ['Drachenei', 'Wyrmling', 'Junger Drache', 'Drache', 'Urdrache'],
    (10, 1.5, 40, 1.2, 25), ['#f4f4f4', '#58b84e', '#d63c34', '#3f78d8', '#f5c935'],
    hp_mult=[1, 2, 4, 8, 16], atk_mult=[1, 2.2, 5, 10, 20])
LINES['witch'] = _generated_line(
    'Hexen', 9, ['herbalist', 'witch', 'sorceress', 'dark_witch', 'witch_queen'],
    ['Kräuterfrau', 'Hexe', 'Zauberhexe', 'Schwarze Hexe', 'Hexenkönigin'],
    (11, 4, 65, 1.5, 30), ['#58b84e', '#2f7d32', '#9b50c8', '#1a1c2c', '#d63c34'])
LINES['wolf'] = _generated_line(
    'Wölfe', 10, ['wolf_pup', 'wolf', 'shadow_wolf', 'werewolf', 'fenrir'],
    ['Wolfswelpe', 'Wolf', 'Schattenwolf', 'Werwolf', 'Fenriswolf'],
    (14, 3, 10, 0.7, 60), ['#f4f4f4', '#8795ad', '#55607a', '#9a6732', '#8fe0ff'])
LINES['giant'] = _generated_line(
    'Riesen', 11, ['gnome', 'troll', 'giant', 'cyclops', 'titan'],
    ['Gnom', 'Troll', 'Riese', 'Zyklop', 'Titan'],
    (30, 4, 16, 1.6, 24), ['#9a6732', '#4b6a1c', '#efb78d', '#c98a65', '#f5c935'])
LINES['centaur'] = _generated_line(
    'Waldwesen', 12, ['satyr', 'faun', 'centaur', 'centaur_lord', 'chiron'],
    ['Satyr', 'Faun', 'Zentaur', 'Kentaurenfürst', 'Chiron'],
    (16, 3, 70, 1.0, 62), ['#5e3b1a', '#9a6732', '#c98a4b', '#8795ad', '#8fe0ff'])

# --- Elemente ---------------------------------------------------------------------
LINES['fire'] = _generated_line(
    'Feuer', 13, ['spark', 'flame', 'fire_spirit', 'fire_elemental', 'ifrit'],
    ['Funke', 'Flamme', 'Feuergeist', 'Feuerelementar', 'Ifrit'],
    (10, 5, 45, 0.9, 40), ['#f5c935', '#f08a24', '#d63c34', '#3f78d8', '#f4f4f4'])
LINES['water'] = _generated_line(
    'Wasser', 14, ['droplet', 'wave', 'water_spirit', 'water_elemental', 'leviathan'],
    ['Tropfen', 'Welle', 'Wassergeist', 'Wasserelementar', 'Leviathan'],
    (16, 3.5, 60, 1.1, 36), ['#8fe0ff', '#3f78d8', '#58b84e', '#264b94', '#f4f4f4'])
LINES['earth'] = _generated_line(
    'Erde', 15, ['pebble', 'golem', 'earth_spirit', 'earth_elemental', 'gaia'],
    ['Kiesel', 'Golem', 'Erdgeist', 'Erdelementar', 'Gaia'],
    (34, 3, 12, 1.4, 22), ['#9a6732', '#8795ad', '#4b6a1c', '#f5c935', '#8fe0ff'])
LINES['air'] = _generated_line(
    'Wind', 16, ['breath', 'breeze', 'wind_spirit', 'air_elemental', 'djinn'],
    ['Windhauch', 'Brise', 'Windgeist', 'Luftelementar', 'Dschinn'],
    (10, 3, 35, 0.6, 65), ['#f4f4f4', '#8fe0ff', '#8795ad', '#9b50c8', '#f5c935'])

# --- Heilkunst: Heiler heilen verletzte Verbündete, statt Gegner anzugreifen. 'atk' ist die
# Heilmenge pro Zauber, 'rng' die Heilreichweite.
LINES['healer'] = _generated_line(
    'Heiler', 17, ['herb_healer', 'healer', 'shaman', 'doctor', 'life_giver'],
    ['Kräuterkundiger', 'Heiler', 'Schamane', 'Arzt', 'Lebensspender'],
    (14, 3, 75, 1.4, 32), ['#58b84e', '#f4f4f4', '#9a6732', '#2f8cff', '#f5c935'],
    hp_mult=[1, 1.6, 2.6, 4.4, 7.5], atk_mult=[1, 1.8, 3.0, 5.2, 9.0])


# Intelligenz der generierten Linien: Basiswert mal Faktor pro Stufe.
_INT_MULT = [1, 1.4, 1.9, 2.6, 3.5]
_INT_BASE = {
    'dwarf': 15, 'elf': 40, 'undead': 8, 'dragon': 30, 'witch': 55, 'wolf': 12, 'giant': 4,
    'centaur': 30, 'healer': 35,
}


_INT_BASE.update({'fire': 30, 'water': 35, 'earth': 5, 'air': 25})
for _key, _base in _INT_BASE.items():
    LINES[_key]['int'] = [round(_base * m) for m in _INT_MULT]

# Shop: Kategorie (aufklappbarer Abschnitt) und Preis der Stufe-1-Einheit jeder Linie.
_SHOP = {
    'melee': ('Klassisch', 5), 'ranged': ('Klassisch', 6), 'magic': ('Klassisch', 8),
    'cavalry': ('Klassisch', 4),
    'dwarf': ('Fantasy', 6), 'elf': ('Fantasy', 7), 'undead': ('Fantasy', 5),
    'witch': ('Märchen', 7), 'wolf': ('Märchen', 6), 'giant': ('Märchen', 7),
    'dragon': ('Mythologie', 8), 'centaur': ('Mythologie', 7),
    'healer': ('Heilkunst', 7),
    'fire': ('Elemente', 7), 'water': ('Elemente', 7), 'earth': ('Elemente', 6), 'air': ('Elemente', 7),
}
for _key, (_category, _price) in _SHOP.items():
    LINES[_key]['category'] = _category
    LINES[_key]['price'] = _price

# Intelligenz der handgemachten Kombinationen (Stufe 1).
_HAND_COMBO_INT = {
    'mounted_knight': 14, 'mounted_archer': 30, 'paladin': 35, 'holy_rider': 55, 'legend': 90,
}


# --- Element-Kombinationen (Element + Einheit). 'sprite_from' + 'tint': Sprite der Zutat
# a wird per Paletten-Tausch eingefärbt.
COMBOS.update({
    'fire_golem': {
        'names': ['Feuergolem', 'Lavagolem', 'Magmakoloss'],
        'a': 'golem', 'b': 'flame', 'cost': 18, 'unlock': 2,
        'stats': (70, 8, 12, 1.2, 26), 'color': '#d63c34',
        'sprite_from': 'golem', 'tint': {'G': 'r', 'g': 'o', 'd': 'R'},
    },
    'water_golem': {
        'names': ['Wassergolem', 'Schlammgolem', 'Flutkoloss'],
        'a': 'golem', 'b': 'wave', 'cost': 18, 'unlock': 2,
        'stats': (75, 6, 12, 1.2, 26), 'color': '#3f78d8',
        'sprite_from': 'golem', 'tint': {'G': 'u', 'g': 'c', 'd': 'U'},
    },
    'sand_golem': {
        'names': ['Sandgolem', 'Sturmgolem', 'Wirbelkoloss'],
        'a': 'golem', 'b': 'breeze', 'cost': 18, 'unlock': 2,
        'stats': (60, 7, 14, 1.0, 34), 'color': '#c98a4b',
        'sprite_from': 'golem', 'tint': {'G': 'h', 'g': 'e', 'd': 'H'},
    },
    'fire_knight': {
        'names': ['Flammenritter', 'Glutritter', 'Inferno-Paladin'],
        'a': 'knight', 'b': 'flame', 'cost': 20, 'unlock': 3,
        'stats': (70, 10, 14, 0.8, 42), 'color': '#f08a24',
        'sprite_from': 'knight', 'tint': {'g': 'o', 'G': 'O', 'd': 'R', 'u': 'r'},
    },
    'pyromancer': {
        'names': ['Pyromant', 'Feuermagier', 'Flammenfürst'],
        'a': 'mage', 'b': 'flame', 'cost': 20, 'unlock': 3,
        'stats': (30, 16, 75, 1.3, 30), 'color': '#d63c34',
        'sprite_from': 'mage', 'tint': {'p': 'r', 'P': 'R', 'c': 'o'},
    },
    'hydromancer': {
        'names': ['Hydromant', 'Gezeitenmagier', 'Meeresherr'],
        'a': 'mage', 'b': 'wave', 'cost': 20, 'unlock': 3,
        'stats': (36, 13, 75, 1.2, 30), 'color': '#3f78d8',
        'sprite_from': 'mage', 'tint': {'p': 'u', 'P': 'U', 'c': 'c'},
    },
    'fire_wolf': {
        'names': ['Feuerwolf', 'Höllenhund', 'Zerberus'],
        'a': 'wolf', 'b': 'flame', 'cost': 16, 'unlock': 3,
        'stats': (45, 9, 10, 0.7, 62), 'color': '#f08a24',
        'sprite_from': 'wolf', 'tint': {'G': 'o', 'g': 'y', 'd': 'R'},
    },
    'storm_archer': {
        'names': ['Sturmschütze', 'Blitzjäger', 'Donnerfalke'],
        'a': 'archer', 'b': 'breeze', 'cost': 22, 'unlock': 4,
        'stats': (35, 10, 100, 0.8, 45), 'color': '#8fe0ff',
        'sprite_from': 'archer', 'tint': {'n': 'c', 'N': 'u'},
    },
})


_HAND_COMBO_INT.update({
    'fire_golem': 8, 'water_golem': 12, 'sand_golem': 8, 'fire_knight': 22,
    'pyromancer': 70, 'hydromancer': 75, 'fire_wolf': 18, 'storm_archer': 45,
})
for _key, _value in _HAND_COMBO_INT.items():
    COMBOS[_key]['int'] = _value


# --- Viele weitere Kombinationen, automatisch berechnet ----------------------------
# Eintrag: (id, Zutat a, Zutat b, Thema, Sprite-Quelle 'a'/'b', [3 Stufennamen])
# Werte = (Summe der Zutaten) * COMBO_POWER, Reichweite = max, Abklingzeit = min,
# Tempo = Mittel. Kosten und Freischaltung ergeben sich aus den Stufen der Zutaten.
# Zutaten, die selbst Kombinationen sind, müssen weiter oben in der Tabelle stehen.
COMBO_POWER = 1.3
COMBO_INT_POWER = 0.75
COMBO_COST_PER_LEVEL = 5
COMBO_COST_BASE = 10

THEME_COLOR = {
    'fire': '#f08a24', 'water': '#3f78d8', 'ice': '#8fe0ff', 'earth': '#9a6732', 'air': '#c8ccd8',
    'light': '#fff4b0', 'dark': '#5d2d88', 'nature': '#58b84e', 'thunder': '#f5c935',
    'gold': '#f5c935', 'blood': '#d63c34',
}

# Paletten-Tausch pro Thema (wirkt auf alle Sprite-Raster, Haut und Umriss bleiben).
THEME_TINT = {
    'fire': {'g': 'o', 'G': 'O', 'd': 'R', 'n': 'o', 'N': 'O', 'p': 'r', 'P': 'R', 'l': 'o', 'L': 'O',
             'u': 'r', 'U': 'R', 'h': 'o', 'H': 'O', 'w': 'y', 'W': 'o', 'c': 'y'},
    'water': {'g': 'c', 'G': 'u', 'd': 'U', 'n': 'c', 'N': 'u', 'p': 'u', 'P': 'U', 'l': 'c', 'L': 'u',
              'h': 'u', 'H': 'U', 'w': 'c', 'W': 'u', 'o': 'c', 'O': 'u'},
    'ice': {'g': 'w', 'G': 'c', 'd': 'u', 'n': 'c', 'N': 'u', 'p': 'c', 'P': 'u', 'l': 'w', 'L': 'c',
            'h': 'w', 'H': 'c', 'w': 'w', 'W': 'c', 'b': 'c', 'o': 'c', 'O': 'u'},
    'earth': {'g': 'h', 'G': 'H', 'd': 'B', 'n': 'L', 'N': 'B', 'p': 'b', 'P': 'B', 'l': 'h', 'L': 'H',
              'u': 'H', 'U': 'B', 'h': 'H', 'H': 'B', 'w': 'e', 'W': 'h', 'c': 'e'},
    'air': {'g': 'W', 'G': 'g', 'd': 'G', 'n': 'c', 'N': 'u', 'p': 'c', 'P': 'u', 'l': 'W', 'L': 'g',
            'h': 'W', 'H': 'g', 'w': 'w', 'W': 'c', 'o': 'c'},
    'light': {'g': 'y', 'G': 'Y', 'd': 'Y', 'n': 'e', 'N': 'y', 'p': 'w', 'P': 'W', 'l': 'e', 'L': 'y',
              'h': 'w', 'H': 'W', 'w': 'w', 'W': 'e', 'c': 'y', 'u': 'y', 'U': 'Y'},
    'dark': {'g': 'G', 'G': 'd', 'd': 'P', 'n': 'P', 'N': 'k', 'p': 'P', 'P': 'k', 'l': 'P', 'L': 'k',
             'h': 'd', 'H': 'k', 'w': 'G', 'W': 'd', 'c': 'p', 'u': 'P', 'U': 'k', 'y': 'p'},
    'nature': {'g': 'n', 'G': 'N', 'd': 'L', 'p': 'N', 'P': 'L', 'l': 'n', 'L': 'N', 'u': 'n', 'U': 'N',
               'h': 'L', 'H': 'N', 'w': 'n', 'W': 'l', 'c': 'n'},
    'thunder': {'g': 'y', 'G': 'Y', 'd': 'U', 'n': 'y', 'N': 'Y', 'p': 'u', 'P': 'U', 'l': 'y', 'L': 'Y',
                'h': 'y', 'H': 'Y', 'w': 'c', 'W': 'y', 'c': 'w', 'o': 'y'},
    'gold': {'g': 'y', 'G': 'Y', 'd': 'O', 'n': 'y', 'N': 'Y', 'p': 'y', 'P': 'Y', 'l': 'y', 'L': 'Y',
             'u': 'y', 'U': 'Y', 'h': 'y', 'H': 'Y', 'w': 'e', 'W': 'y'},
    'blood': {'g': 'r', 'G': 'R', 'd': 'k', 'n': 'r', 'N': 'R', 'p': 'R', 'P': 'k', 'l': 'r', 'L': 'R',
              'h': 'R', 'H': 'k', 'w': 'r', 'W': 'R', 'c': 'r'},
}

COMBO_TABLE = [
    # Elemente untereinander
    ('frost_spirit', 'wave', 'breeze', 'ice', 'a', ['Frostgeist', 'Eisgeist', 'Winterkönig']),
    ('steam', 'flame', 'wave', 'air', 'a', ['Dampfgeist', 'Dampfwolke', 'Geysir']),
    ('lightning', 'spark', 'breeze', 'thunder', 'b', ['Blitz', 'Gewitterwolke', 'Donnergott']),
    ('lava', 'flame', 'pebble', 'fire', 'b', ['Lavastein', 'Lavaelementar', 'Vulkan']),
    ('sandstorm', 'breeze', 'pebble', 'earth', 'a', ['Sandsturm', 'Wüstengeist', 'Sandkönig']),
    # Drachen und Mischwesen
    ('fire_dragon', 'wyrmling', 'flame', 'fire', 'a', ['Feuerwyrm', 'Feuerdrache', 'Höllendrache']),
    ('ice_dragon', 'wyrmling', 'frost_spirit', 'ice', 'a', ['Frostwyrm', 'Eisdrache', 'Frostkönig']),
    ('dragon_rider', 'young_dragon', 'knight', 'fire', 'a', ['Drachenreiter', 'Drachenritter', 'Drachenfürst']),
    ('dragon_mage', 'wyrmling', 'mage', 'thunder', 'a', ['Drachenmagier', 'Drachenweiser', 'Drachenlord']),
    ('bone_dragon', 'wyrmling', 'skeleton', 'dark', 'a', ['Knochenwyrm', 'Knochendrache', 'Todesdrache']),
    ('hydra', 'wyrmling', 'wave', 'water', 'a', ['Hydra', 'Mehrkopf-Hydra', 'Lernäische Hydra']),
    ('basilisk', 'wyrmling', 'herbalist', 'nature', 'a', ['Basilisk', 'Königsbasilisk', 'Versteinerer']),
    ('chimera', 'wolf', 'wyrmling', 'fire', 'a', ['Chimäre', 'Große Chimäre', 'Urchimäre']),
    ('phoenix', 'fire_spirit', 'wind_spirit', 'fire', 'a', ['Phönix', 'Feuerphönix', 'Sonnenvogel']),
    ('thunderbird', 'wind_spirit', 'spark', 'thunder', 'a', ['Donnervogel', 'Blitzvogel', 'Sturmvogel']),
    # Untote
    ('necromancer', 'mage', 'skeleton', 'dark', 'a', ['Nekromant', 'Totenbeschwörer', 'Todesmagier']),
    ('skeleton_knight', 'knight', 'skeleton', 'dark', 'a', ['Skelettritter', 'Knochenritter', 'Grabritter']),
    ('vampire', 'ghoul', 'wolf_pup', 'blood', 'a', ['Vampir', 'Blutgraf', 'Vampirfürst']),
    ('zombie_giant', 'giant', 'ghoul', 'nature', 'a', ['Zombieriese', 'Fäulnisriese', 'Seuchenfürst']),
    ('mummy', 'ghoul', 'breeze', 'earth', 'a', ['Mumie', 'Pharao', 'Wüstenkönig']),
    ('ghost', 'skeleton', 'breath', 'light', 'a', ['Geist', 'Poltergeist', 'Banshee']),
    ('anubis', 'ghoul', 'wolf', 'gold', 'a', ['Schakalwächter', 'Anubis', 'Totenrichter']),
    # Zwerge
    ('rune_master', 'dwarf_warrior', 'mage', 'thunder', 'a', ['Runenmeister', 'Runenschmied', 'Runenkönig']),
    ('stone_guard', 'axe_master', 'golem', 'earth', 'b', ['Steinwächter', 'Bergwächter', 'Titanenwächter']),
    ('fire_dwarf', 'dwarf_warrior', 'flame', 'fire', 'a', ['Feuerzwerg', 'Schmiedemeister', 'Essenkönig']),
    ('dwarf_knight', 'dwarf_warrior', 'knight', 'gold', 'a', ['Zwergenritter', 'Eisenwächter', 'Schildträger']),
    ('dwarf_gunner', 'miner', 'archer', 'gold', 'b', ['Zwergenschütze', 'Büchsenmeister', 'Meisterschütze']),
    ('thor', 'dwarf_lord', 'spark', 'thunder', 'a', ['Thor', 'Donnerer', 'Donnergott']),
    # Elfen
    ('fire_elf', 'wood_elf', 'flame', 'fire', 'a', ['Feuerelf', 'Glutelf', 'Sonnenelf']),
    ('treant', 'wood_elf', 'pebble', 'nature', 'b', ['Baumhüter', 'Ent', 'Uralter Ent']),
    ('dark_elf', 'elf_scout', 'skeleton', 'dark', 'a', ['Dunkelelf', 'Schattenelf', 'Nachtelf']),
    ('elf_mage', 'wood_elf', 'mage', 'light', 'a', ['Elfenmagier', 'Sternenmagier', 'Erzdruide']),
    ('beast_master', 'wood_elf', 'wolf', 'nature', 'b', ['Tierflüsterer', 'Wildhüter', 'Herr der Wälder']),
    # Hexen und Märchen
    ('red_hood', 'witch', 'wolf', 'blood', 'a', ['Rotkäppchen', 'Wolfsbändigerin', 'Waldhexe']),
    ('broom_witch', 'witch', 'breeze', 'air', 'a', ['Besenreiterin', 'Sturmhexe', 'Wetterhexe']),
    ('snow_queen', 'witch', 'frost_spirit', 'ice', 'a', ['Eishexe', 'Schneekönigin', 'Winterhexe']),
    ('medusa', 'witch', 'wave', 'nature', 'a', ['Medusa', 'Gorgone', 'Gorgonenkönigin']),
    ('siren', 'witch', 'droplet', 'water', 'a', ['Sirene', 'Meeressirene', 'Sirenenkönigin']),
    ('loki', 'dark_witch', 'flame', 'fire', 'a', ['Loki', 'Trickster', 'Feuerlist']),
    ('gnome_rider', 'gnome', 'wolf', 'nature', 'b', ['Koboldreiter', 'Wolfsgnom', 'Gnomenhäuptling']),
    # Riesen
    ('fire_giant', 'giant', 'flame', 'fire', 'a', ['Feuerriese', 'Muspel', 'Surtr']),
    ('ice_giant', 'giant', 'frost_spirit', 'ice', 'a', ['Frostriese', 'Eisriese', 'Ymir']),
    ('stone_giant', 'giant', 'golem', 'earth', 'a', ['Steinriese', 'Felsriese', 'Bergriese']),
    ('minotaur', 'troll', 'knight', 'earth', 'a', ['Minotaurus', 'Labyrinthwächter', 'Stierkrieger']),
    ('hercules', 'knight', 'giant', 'gold', 'a', ['Herkules', 'Halbgott-Held', 'Olymp-Held']),
    ('achilles', 'squire', 'spark', 'gold', 'a', ['Achilles', 'Held von Troja', 'Unverwundbarer']),
    # Pferde und Reittiere
    ('pegasus', 'horse', 'breeze', 'light', 'a', ['Pegasus', 'Sturmpegasus', 'Himmelspegasus']),
    ('unicorn', 'horse', 'spark', 'light', 'a', ['Einhorn', 'Sonnenhorn', 'Lichteinhorn']),
    ('nightmare', 'warhorse', 'flame', 'fire', 'a', ['Nachtmahr', 'Höllenross', 'Höllenhengst']),
    ('sleipnir', 'warhorse', 'wind_spirit', 'air', 'a', ['Sleipnir', 'Sturm-Sleipnir', 'Wotans Ross']),
    ('kelpie', 'horse', 'wave', 'water', 'a', ['Kelpie', 'Nöck', 'Meeresross']),
    ('valkyrie', 'knight', 'wind_spirit', 'light', 'a', ['Walküre', 'Schildmaid', 'Walküren-Fürstin']),
    ('wolf_knight', 'knight', 'wolf', 'dark', 'a', ['Wolfsritter', 'Wolfskrieger', 'Alpha-Ritter']),
    # Grundlinien untereinander
    ('mercenary', 'knight', 'archer', 'gold', 'a', ['Söldner', 'Veteran', 'Kriegsherr']),
    ('arcane_archer', 'archer', 'mage', 'light', 'a', ['Arkanschütze', 'Arkanjäger', 'Arkanmeister']),
    ('wild_hunter', 'archer', 'wolf', 'nature', 'a', ['Tierjäger', 'Wildjäger', 'Herr der Meute']),
    ('mage_rider', 'horse', 'mage', 'light', 'a', ['Magierreiter', 'Arkanreiter', 'Zauberreiter']),
    # Heil-Kombinationen: Jede Kombination mit einem Heiler heilt selbst (siehe HEAL_COMBOS).
    ('field_medic', 'knight', 'healer', 'nature', 'b', ['Feldarzt', 'Lazarettarzt', 'Generalarzt']),
    ('fairy', 'healer', 'breeze', 'light', 'a', ['Fee', 'Lichtfee', 'Feenkönigin']),
    ('priest', 'healer', 'mage', 'light', 'a', ['Priester', 'Hohepriester', 'Erzbischof']),
    ('druid', 'shaman', 'wood_elf', 'nature', 'a', ['Druide', 'Hochdruide', 'Waldweiser']),
    ('nymph', 'herb_healer', 'droplet', 'water', 'a', ['Quellnymphe', 'Undine', 'Meeresnymphe']),
    ('dryad', 'herb_healer', 'pebble', 'nature', 'a', ['Dryade', 'Baumnymphe', 'Waldmutter']),
    ('plague_doctor', 'healer', 'skeleton', 'dark', 'a', ['Pestdoktor', 'Seuchenarzt', 'Herr der Pest']),
    ('witch_doctor', 'shaman', 'troll', 'dark', 'a', ['Medizinmann', 'Voodoo-Priester', 'Stammesältester']),
    ('silver_unicorn', 'unicorn', 'herb_healer', 'light', 'a', ['Silbereinhorn', 'Heilendes Einhorn', 'Lebenseinhorn']),
    ('angel', 'doctor', 'wind_spirit', 'light', 'a', ['Engel', 'Erzengel', 'Seraph']),
    ('asclepius', 'doctor', 'spark', 'gold', 'a', ['Asklepios', 'Heilgott', 'Gott der Heilkunst']),
]

# Geheimrezepte: stehen erst im Rezeptbuch, wenn sie einmal durch Ausprobieren entdeckt wurden.
SECRET_TABLE = [
    ('king_arthur', 'knight', 'unicorn', 'gold', 'a', ['König Artus', 'Hochkönig Artus', 'Ewiger König']),
    ('merlin', 'archmage', 'wood_elf', 'light', 'a', ['Merlin', 'Merlin der Weise', 'Merlin der Ewige']),
    ('baba_yaga', 'witch', 'ghoul', 'dark', 'a', ['Baba Jaga', 'Knochenhexe', 'Hexe der Hühnerhütte']),
    ('kraken', 'hydra', 'wave', 'water', 'a', ['Krake', 'Riesenkrake', 'Kraken']),
    ('robin_hood', 'archer', 'wood_elf', 'nature', 'a', ['Robin Hood', 'König der Diebe', 'Held von Sherwood']),
]
SECRET_COMBOS = {row[0] for row in SECRET_TABLE}
COMBO_TABLE += SECRET_TABLE


def _register_table_combos():
    info = {}
    seen_pairs = {frozenset((c['a'], c['b'])) for c in COMBOS.values()}
    for line in LINES.values():
        for i, uid in enumerate(line['ids']):
            info[uid] = {
                'level': i + 1, 'unlock': LEVEL_UNLOCK_ROUND[i],
                'int': line['int'][i],
                'stats': (line['hp'][i], line['atk'][i], line['rng'][i], line['cd'][i], line['spd'][i])}
    for base, combo in COMBOS.items():
        info[base] = {'level': 3, 'unlock': combo['unlock'], 'stats': combo['stats'], 'int': combo['int']}
    for cid, a, b, theme, source, names in COMBO_TABLE:
        assert a in info and b in info, f'{cid}: unbekannte Zutat {a}/{b}'
        assert len(names) == 3, f'{cid}: drei Stufennamen nötig'
        assert cid not in info, f'{cid}: Id doppelt'
        pair = frozenset((a, b))
        assert pair not in seen_pairs, f'{cid}: Rezept {a}+{b} existiert schon'
        seen_pairs.add(pair)
        ia, ib = info[a], info[b]
        sa, sb = ia['stats'], ib['stats']
        stats = (round((sa[0] + sb[0]) * COMBO_POWER), round((sa[1] + sb[1]) * COMBO_POWER, 1),
                 max(sa[2], sb[2]), min(sa[3], sb[3]), round((sa[4] + sb[4]) / 2))
        intel = round((ia['int'] + ib['int']) * COMBO_INT_POWER)
        cost = COMBO_COST_PER_LEVEL * (ia['level'] + ib['level']) + COMBO_COST_BASE
        unlock = max(ia['unlock'], ib['unlock']) + 1
        COMBOS[cid] = {
            'names': names, 'a': a, 'b': b, 'cost': cost, 'unlock': unlock, 'stats': stats, 'int': intel,
            'color': THEME_COLOR[theme], 'sprite_from': a if source == 'a' else b,
            'tint': THEME_TINT[theme], 'theme': theme,
        }
        info[cid] = {'level': 3, 'unlock': unlock, 'stats': stats, 'int': intel}


_register_table_combos()


# Kombinationen mit mindestens einem heilenden Bestandteil heilen selbst statt anzugreifen.
HEAL_COMBOS = set()
_heal_ids = set(LINES['healer']['ids'])
for _base, _combo in COMBOS.items():
    if _combo['a'] in _heal_ids or _combo['b'] in _heal_ids:
        HEAL_COMBOS.add(_base)
        _heal_ids.update(combo_ids(_base))


# --- Fähigkeiten -------------------------------------------------------------------
# Jede Einheit hat genau eine Fähigkeit (Namen und Wirkung: scripts/abilities.gd). Aktive lösen im Kampf
# von selbst aus, sobald ihre Bedingung erfüllt und die Abklingzeit vorbei ist, passive wirken dauerhaft.
# Eine Linie hat eine Fähigkeit, einzelne Stufen können abweichen (Index = Stufe - 1).
LINE_ABILITY = {
    'melee': 'shield', 'ranged': 'arrow_rain', 'magic': 'frost_nova', 'cavalry': 'sprint',
    'dwarf': 'armor', 'elf': 'evasion', 'undead': 'lifesteal', 'dragon': 'meteor',
    'witch': 'slow_aura', 'wolf': 'war_cry', 'giant': 'taunt', 'centaur': 'war_aura',
    'fire': 'meteor', 'water': 'regen', 'earth': 'shield', 'air': 'evasion',
    'healer': ['mass_heal', 'mass_heal', 'mass_heal', 'revive', 'revive'],
}
# Handgemachte Kombinationen ohne Sprite-Tausch.
HAND_COMBO_ABILITY = {
    'mounted_knight': 'sprint', 'mounted_archer': 'arrow_rain', 'paladin': 'mass_heal',
    'holy_rider': 'revive', 'legend': 'war_aura',
}
# Einzelne Kombinationen, bei denen die Regel "Fähigkeit der anderen Zutat" nicht passt.
COMBO_ABILITY_OVERRIDE = {
    'phoenix': 'revive', 'valkyrie': 'revive', 'anubis': 'revive', 'necromancer': 'revive',
    'unicorn': 'regen', 'pegasus': 'sprint', 'hercules': 'taunt', 'achilles': 'shield', 'thor': 'war_aura',
    'king_arthur': 'war_aura', 'merlin': 'meteor', 'kraken': 'taunt', 'robin_hood': 'arrow_rain',
}
# Heilende Einheiten können mit diesen Fähigkeiten nichts anfangen (kein Gegnerziel / kein Schaden).
_NEEDS_ATTACKER = {'meteor', 'arrow_rain', 'lifesteal'}

UNIT_ABILITY = {}   # Einheiten-Id -> Fähigkeit (für alle Stufen, auch Kombinationen)
for _key, _line in LINES.items():
    _spec = LINE_ABILITY[_key]
    for _i, _uid in enumerate(_line['ids']):
        UNIT_ABILITY[_uid] = _spec[_i] if isinstance(_spec, list) else _spec

for _base, _combo in COMBOS.items():
    if _base in COMBO_ABILITY_OVERRIDE:
        _ability = COMBO_ABILITY_OVERRIDE[_base]
    elif _base in HAND_COMBO_ABILITY:
        _ability = HAND_COMBO_ABILITY[_base]
    elif 'sprite_from' in _combo:
        # Das Aussehen kommt von einer Zutat, die Fähigkeit von der anderen: Feuergolem = Golem + Flamme.
        _other = _combo['b'] if _combo['sprite_from'] == _combo['a'] else _combo['a']
        _ability = UNIT_ABILITY[_other]
    else:
        _ability = UNIT_ABILITY[_combo['a']]
    if _base in HEAL_COMBOS and _ability in _NEEDS_ATTACKER:
        _ability = 'mass_heal'
    for _uid in combo_ids(_base):
        UNIT_ABILITY[_uid] = _ability
