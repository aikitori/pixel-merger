#!/usr/bin/env python3
"""Schreibt die Einheiten- und Rezept-.tres aus tools/content.py nach data/.

Aufruf (aus dem Projektordner):  python3 tools/generate_data.py
Löscht dabei data/units, data/recipes und data/enemies und legt sie neu an.
"""
from pathlib import Path

import content
import i18n_names

ROOT = Path(__file__).resolve().parent.parent


def color(hex_value):
    h = hex_value.lstrip('#')
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return f'Color({r:.3f}, {g:.3f}, {b:.3f}, 1)'


def gd_keys(path):
    """Schlüssel der INFO-Tabelle eines GDScripts (z.B. scripts/traits.gd), um Ids zu prüfen."""
    import re
    text = (ROOT / path).read_text(encoding='utf-8')
    return set(re.findall(r'^\t&"(\w+)": \{', text, re.M))


def check_profiles():
    """Charakter der Einheiten: alles einzigartig (content.check_unique) und in den Skripten vorhanden."""
    traits = content.check_unique()
    for path, wanted in (('scripts/traits.gd', set(traits)),
                         ('scripts/behaviors.gd', {p['behavior'] for p in content.UNIT_PROFILE.values()}),
                         ('scripts/attack_kinds.gd', {p['attack'] for p in content.UNIT_PROFILE.values()}),
                         ('scripts/abilities.gd', set(content.UNIT_ABILITY.values()))):
        missing = sorted(wanted - gd_keys(path))
        assert not missing, f'In {path} fehlen: {missing}'


def write_unit(uid, name, line_name, level, hex_color, stats, intel, shop_order=0, price=0, category='',
               unlock_round=1, upgrade=None, upgrade_cost=0, ability='', house_level=0):
    hp, atk, rng, cd, spd = stats
    profile = content.UNIT_PROFILE[uid]
    traits = ', '.join(f'&"{t}"' for t in profile['traits'])
    exts = [('Script', 'res://scripts/data/unit_data.gd'),
            ('Texture2D', f'res://assets/sprites/units/{uid}.png')]
    if upgrade:
        exts.append(('Resource', f'res://data/units/{upgrade}.tres'))
    lines = [f'[gd_resource type="Resource" script_class="UnitData" load_steps={len(exts) + 1} format=3]', '']
    lines += [f'[ext_resource type="{t}" path="{p}" id="{i}"]' for i, (t, p) in enumerate(exts, 1)]
    props = [('script', 'ExtResource("1")'), ('sprite', 'ExtResource("2")'),
             ('id', f'&"{uid}"'), ('display_name', f'"{name}"'), ('line_name', f'"{line_name}"'),
             ('category', f'"{category}"'), ('color', color(hex_color)), ('level', level),
             ('shop_order', shop_order), ('price', price), ('house_level', house_level),
             ('unlock_round', unlock_round),
             ('max_health', float(hp)), ('attack', float(atk)), ('attack_range', float(rng)), ('attack_style', f'&"{content.attack_style(uid)}"'),
             ('ability', f'&"{ability}"'), ('behavior', f'&"{profile["behavior"]}"'),
             ('attack_kind', f'&"{profile["attack"]}"'), ('traits', f'Array[StringName]([{traits}])'), ('attack_cooldown', float(cd)), ('move_speed', float(spd)), ('intelligence', float(intel))]
    if upgrade:
        props += [('upgrade', 'ExtResource("3")'), ('upgrade_cost', upgrade_cost)]
    lines += ['', '[resource]'] + [f'{k} = {v}' for k, v in props]
    (ROOT / 'data/units' / f'{uid}.tres').write_text('\n'.join(lines) + '\n')


def write_recipe(a, b, result, cost, unlock, secret=False):
    lines = ['[gd_resource type="Resource" script_class="RecipeData" load_steps=5 format=3]', '',
             '[ext_resource type="Script" path="res://scripts/data/recipe_data.gd" id="1"]']
    lines += [f'[ext_resource type="Resource" path="res://data/units/{u}.tres" id="{i}"]'
              for i, u in enumerate((a, b, result), 2)]
    lines += ['', '[resource]', 'script = ExtResource("1")',
              'ingredient_a = ExtResource("2")', 'ingredient_b = ExtResource("3")',
              'result = ExtResource("4")', f'unlock_round = {unlock}', f'merge_cost = {cost}']
    if secret:
        lines.append('secret = true')
    (ROOT / 'data/recipes' / f'{a}_{b}.tres').write_text('\n'.join(lines) + '\n')


# Gegner. Werte der Runde 1, sie werden mit der Runde skaliert (Game.health_scale, damage_scale, gold_scale).
# Fähigkeit, Verhalten und Merkmale (fx) stammen aus denselben Bausteinen wie bei den Einheiten
# (scripts/abilities.gd, behaviors.gd, traits.gd); bei Gegnern wirken Verteidigung, Auren und Tod, die
# Wirkung von Treffern nicht. `minion`: Gegner, den die Fähigkeit "Beschwörung" ruft.
# Felder: Id, Name, Farbe, Körpergröße, LP, Angriff, Reichweite, Stil, Abklingzeit, Tempo, Gold, ab Runde, Gewicht, Zusatz
ENEMIES = [
    ('slime', 'Schleim', '#6fd36f', 10.0, 12, 2, 10, 'melee', 1.0, 25, 2, 1, 5.0, {'intelligence': 0.0}),
    ('goblin', 'Goblin', '#3f8f3f', 12.0, 18, 3.5, 10, 'melee', 1.0, 40, 3, 2, 4.0, {'intelligence': 15.0}),
    ('jackal', 'Schakal', '#b89a64', 12.0, 11, 3, 10, 'melee', 0.8, 58, 3, 3, 2.5,
     {'behavior': 'flanker', 'intelligence': 15.0}),
    ('bone_archer', 'Skelett-Bogenschütze', '#d8d8c8', 12.0, 14, 4, 80, 'arrow', 1.4, 30, 4, 3, 2.0,
     {'intelligence': 30.0}),
    ('spiny_frog', 'Stachelfrosch', '#b8a030', 12.0, 34, 3.5, 10, 'melee', 1.2, 26, 5, 5, 1.5,
     {'behavior': 'hopper', 'ability': 'thorns', 'power': 2.0, 'intelligence': 5.0}),
    ('orc', 'Ork', '#6b8f2a', 16.0, 55, 9, 12, 'melee', 1.2, 32, 8, 5, 2.0, {'intelligence': 10.0}),
    ('mushroom', 'Sprengpilz', '#e0702a', 14.0, 26, 5, 10, 'melee', 1.4, 22, 5, 6, 1.0,
     {'fx': {'death_blast': [1.5, 34.0]}, 'intelligence': 0.0}),
    ('gnoll_shaman', 'Gnoll-Schamane', '#a08850', 14.0, 30, 3.5, 70, 'magic', 1.8, 28, 9, 7, 1.0,
     {'behavior': 'skirmisher', 'ability': 'mass_heal', 'power': 1.0, 'intelligence': 30.0}),
    ('ghost', 'Geist', '#c8d0e0', 14.0, 30, 6, 10, 'melee', 1.1, 33, 7, 8, 1.2,
     {'behavior': 'floater', 'fx': {'dodge': 0.35}, 'intelligence': 15.0}),
    ('gnoll_sergeant', 'Gnoll-Hauptmann', '#8a6a30', 16.0, 62, 7, 12, 'melee', 1.1, 30, 11, 9, 1.0,
     {'ability': 'war_cry', 'power': 1.0, 'intelligence': 20.0}),
    ('warg', 'Warg', '#707078', 14.0, 70, 8.5, 12, 'melee', 1.0, 38, 11, 9, 1.2,
     {'ability': 'charge', 'power': 1.0, 'intelligence': 10.0}),
    ('ogre', 'Oger', '#8f5a2a', 22.0, 160, 20, 14, 'melee', 1.8, 22, 18, 8, 1.0, {'intelligence': 5.0}),
    ('gargoyle', 'Wasserspeier', '#9aa0b0', 20.0, 100, 9, 12, 'melee', 1.3, 21, 13, 10, 1.2,
     {'behavior': 'floater', 'fx': {'reduce': 0.3, 'block': 0.25}, 'intelligence': 10.0}),
    ('troll', 'Troll', '#4a8a3a', 22.0, 210, 15, 14, 'melee', 1.6, 24, 20, 11, 1.0,
     {'ability': 'regen', 'power': 2.0, 'intelligence': 5.0}),
    ('dark_mage', 'Dunkelmagier', '#3a8a5a', 16.0, 42, 7, 85, 'magic', 1.8, 26, 14, 12, 1.0,
     {'behavior': 'artillery', 'ability': 'meteor', 'power': 1.0, 'intelligence': 30.0}),
    ('vampire', 'Vampir', '#5a2a6a', 16.0, 115, 12, 12, 'melee', 0.9, 36, 17, 13, 1.0,
     {'behavior': 'assassin', 'ability': 'lifesteal', 'power': 2.0, 'intelligence': 25.0}),
    ('necromancer', 'Totenbeschwörer', '#4a4a50', 16.0, 60, 6, 80, 'magic', 2.0, 24, 18, 15, 0.8,
     {'behavior': 'skirmisher', 'ability': 'summon', 'power': 1.0, 'minion': 'skeleton', 'intelligence': 30.0}),
    # Helfer des Totenbeschwörers und des Knochenkönigs: erscheinen nie von selbst (Gewicht 0, keine Beute)
    ('skeleton', 'Skelett', '#d8d8c8', 12.0, 20, 4, 10, 'melee', 1.0, 32, 0, 99, 0.0, {'intelligence': 5.0}),
]

# Bossgegner (Runde 5, 15, 25 ... reihum), Stufe `ab Runde` ist die Reihenfolge.
BOSSES = [
    ('boss_ogre', 'Ogerkönig', '#8f5a2a', 36.0, 220, 9, 18, 'melee', 1.6, 20, 80, 0, 0.0,
     {'ability': 'war_cry', 'power': 1.0, 'intelligence': 20.0, 'is_boss': True}),
    ('boss_dragon', 'Feuerdrache', '#d63c34', 36.0, 180, 11, 85, 'magic', 2.0, 18, 90, 1, 0.0,
     {'ability': 'fire_breath', 'power': 1.0, 'intelligence': 20.0, 'is_boss': True}),
    ('boss_bones', 'Knochenkönig', '#c8ccd8', 40.0, 190, 7, 100, 'arrow', 1.0, 22, 85, 2, 0.0,
     {'ability': 'summon', 'power': 2.0, 'minion': 'skeleton', 'intelligence': 20.0, 'is_boss': True}),
    ('boss_golem', 'Steingigant', '#8795ad', 40.0, 300, 8, 18, 'melee', 2.0, 14, 95, 3, 0.0,
     {'ability': 'earthquake', 'power': 1.0, 'intelligence': 20.0, 'is_boss': True}),
]


def fx_literal(fx):
    """Dictionary im .tres-Format: {"dodge": 0.35, "death_blast": [3.0, 38.0]}"""
    def value(v):
        return '[' + ', '.join(value(x) for x in v) + ']' if isinstance(v, list) else str(float(v))
    return '{' + ', '.join(f'"{k}": {value(v)}' for k, v in fx.items()) + '}'


def write_enemy(uid, name, hex_color, body, hp, atk, rng, style, cd, spd, gold, min_round, weight, extra):
    lines = ['[gd_resource type="Resource" script_class="EnemyData" load_steps=3 format=3]', '',
             '[ext_resource type="Script" path="res://scripts/data/enemy_data.gd" id="1"]',
             f'[ext_resource type="Texture2D" path="res://assets/sprites/enemies/{uid}.png" id="2"]', '',
             '[resource]', 'script = ExtResource("1")', 'sprite = ExtResource("2")',
             f'id = &"{uid}"', f'display_name = "{name}"', f'color = {color(hex_color)}',
             f'body_size = {body}', f'max_health = {float(hp)}', f'attack = {float(atk)}',
             f'attack_range = {float(rng)}', f'attack_style = &"{style}"', f'attack_cooldown = {cd}',
             f'move_speed = {float(spd)}', f'gold_reward = {gold}', f'min_round = {min_round}',
             f'weight = {float(weight)}', f'intelligence = {float(extra.get("intelligence", 10.0))}']
    if extra.get('is_boss'):
        lines.append('is_boss = true')
    if extra.get('ability'):
        lines += [f'ability = &"{extra["ability"]}"', f'ability_power = {float(extra.get("power", 1.0))}']
    if extra.get('behavior'):
        lines.append(f'behavior = &"{extra["behavior"]}"')
    if extra.get('fx'):
        lines.append(f'fx = {fx_literal(extra["fx"])}')
    if extra.get('minion'):
        lines.append(f'minion = &"{extra["minion"]}"')
    (ROOT / 'data/enemies' / f'{uid}.tres').write_text('\n'.join(lines) + '\n')


def check_enemies():
    """Fähigkeit, Verhalten und Merkmale der Gegner müssen in den Skripten stehen, Helfer müssen existieren."""
    import re
    keys = re.search(r'const KEYS := \[(.*?)\]', (ROOT / 'scripts/traits.gd').read_text(encoding='utf-8'), re.S)
    trait_keys = set(re.findall(r'"(\w+)"', keys.group(1)))
    ids = {e[0] for e in ENEMIES + BOSSES}
    abilities, behaviors = gd_keys('scripts/abilities.gd'), gd_keys('scripts/behaviors.gd')
    for uid, *_rest, extra in ENEMIES + BOSSES:
        assert extra.get('ability', '') in abilities | {''}, f'{uid}: unbekannte Fähigkeit'
        assert extra.get('behavior', 'frontline') in behaviors, f'{uid}: unbekanntes Verhalten'
        assert set(extra.get('fx', {})) <= trait_keys, f'{uid}: unbekannter Baustein in fx'
        assert extra.get('minion', uid) in ids, f'{uid}: Helfer fehlt'
        assert (extra.get('ability') == 'summon') == bool(extra.get('minion')), f'{uid}: Helfer nur mit Beschwörung'
        assert extra.get('ability') not in ('revive',), f'{uid}: Wiederbeleben gilt nur für eigene Einheiten'


def write_enemies():
    check_enemies()
    path = ROOT / 'data/enemies'
    path.mkdir(parents=True, exist_ok=True)
    for old in path.glob('*.tres'):
        old.unlink()
    for entry in ENEMIES + BOSSES:
        write_enemy(*entry)


def write_english_names():
    """Prüft, dass jeder Name übersetzt ist, und schreibt scripts/i18n/names_en.gd (deutsch -> englisch)."""
    import re
    needed = set()
    for line in content.LINES.values():
        needed.update(line['names'])
        needed.add(line['name'])
        needed.add(line['category'])
    for combo in content.COMBOS.values():
        needed.update(combo['names'])
    needed.add('Kombination')
    for path in (ROOT / 'data/enemies').glob('*.tres'):
        needed.update(re.findall(r'^display_name = "(.*)"$', path.read_text(), re.M))
    needed.update(h for h in ('Kaserne', 'Gildenhaus', 'Märchenhütte', 'Tempel', 'Elementarturm', 'Lazarett'))
    missing = sorted(n for n in needed if n not in i18n_names.EN)
    assert not missing, f'Englische Namen fehlen: {missing}'
    lines = ['## Erzeugt von tools/generate_data.py aus tools/i18n_names.py. Nicht von Hand ändern.',
             'class_name NamesEn', 'extends RefCounted', '', 'const NAMES := {']
    for german in sorted(i18n_names.EN):
        english = i18n_names.EN[german].replace('"', '\\"')
        lines.append(f'\t"{german}": "{english}",')
    lines += ['}', '']
    (ROOT / 'scripts/i18n').mkdir(parents=True, exist_ok=True)
    (ROOT / 'scripts/i18n/names_en.gd').write_text('\n'.join(lines))


def main():
    check_profiles()
    for folder in ('units', 'recipes'):
        path = ROOT / 'data' / folder
        path.mkdir(parents=True, exist_ok=True)
        for old in path.glob('*'):
            old.unlink()

    for key, line in content.LINES.items():
        for i, uid in enumerate(line['ids']):
            last = i == len(line['ids']) - 1
            write_unit(
                uid, line['names'][i], line['name'], i + 1, line['colors'][i],
                (line['hp'][i], line['atk'][i], line['rng'][i], line['cd'][i], line['spd'][i]),
                line['int'][i],
                shop_order=line['order'] if i == 0 else 0,
                price=line['price'] if i == 0 else 0, category=line['category'],
                house_level=line['house_level'] if i == 0 else 0,
                unlock_round=content.LEVEL_UNLOCK_ROUND[i], ability=content.UNIT_ABILITY[uid],
                upgrade=None if last else line['ids'][i + 1],
                upgrade_cost=0 if last else content.UPGRADE_COST[i])

    for base, combo in content.COMBOS.items():
        ids = content.combo_ids(base)
        hp, atk, rng, cd, spd = combo['stats']
        for level, uid in enumerate(ids):
            mult = content.COMBO_STAT_MULT[level]
            last = level == len(ids) - 1
            write_unit(
                uid, combo['names'][level], 'Kombination', level + 1, combo['color'],
                (round(hp * mult), round(atk * mult, 1), rng, cd, spd),
                round(combo['int'] * content.COMBO_INT_MULT[level]),
                category='Kombination', ability=content.UNIT_ABILITY[uid],
                unlock_round=combo['unlock'] + content.COMBO_UNLOCK_STEP * level,
                upgrade=None if last else ids[level + 1],
                upgrade_cost=0 if last else round(combo['cost'] * content.COMBO_UPGRADE_MULT[level]))
        write_recipe(combo['a'], combo['b'], base, combo['cost'], combo['unlock'], base in content.SECRET_COMBOS)

    write_enemies()
    write_english_names()
    print('Einheiten, Rezepte und Gegner geschrieben.')


if __name__ == '__main__':
    main()
