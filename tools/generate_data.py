#!/usr/bin/env python3
"""Schreibt die Einheiten- und Rezept-.tres aus tools/content.py nach data/.

Aufruf (aus dem Projektordner):  python3 tools/generate_data.py
Löscht dabei data/units und data/recipes und legt sie neu an. Gegner (data/enemies)
bleiben unberührt.
"""
from pathlib import Path

import content
import i18n_names

ROOT = Path(__file__).resolve().parent.parent


def color(hex_value):
    h = hex_value.lstrip('#')
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return f'Color({r:.3f}, {g:.3f}, {b:.3f}, 1)'


# Kampfanimation: Nahkampf (Schwert) bis Reichweite 30, darüber Pfeil oder Feuerball.
ARROW_LINES = {'ranged', 'elf', 'centaur'}
ARROW_COMBOS = {'robin_hood', 'mounted_archer', 'storm_archer', 'dwarf_gunner', 'mercenary', 'wild_hunter',
                'beast_master', 'dark_elf', 'red_hood', 'arcane_archer'}


HEAL_LINES = {'healer'}


def attack_style(rng, arrows, heals=False):
    if heals:
        return 'heal'
    if rng <= 30:
        return 'melee'
    return 'arrow' if arrows else 'magic'


def write_unit(uid, name, line_name, level, hex_color, stats, intel, shop_order=0, price=0, category='',
               unlock_round=1, upgrade=None, upgrade_cost=0, arrows=False, heals=False, ability=''):
    hp, atk, rng, cd, spd = stats
    exts = [('Script', 'res://scripts/data/unit_data.gd'),
            ('Texture2D', f'res://assets/sprites/units/{uid}.png')]
    if upgrade:
        exts.append(('Resource', f'res://data/units/{upgrade}.tres'))
    lines = [f'[gd_resource type="Resource" script_class="UnitData" load_steps={len(exts) + 1} format=3]', '']
    lines += [f'[ext_resource type="{t}" path="{p}" id="{i}"]' for i, (t, p) in enumerate(exts, 1)]
    props = [('script', 'ExtResource("1")'), ('sprite', 'ExtResource("2")'),
             ('id', f'&"{uid}"'), ('display_name', f'"{name}"'), ('line_name', f'"{line_name}"'),
             ('category', f'"{category}"'), ('color', color(hex_color)), ('level', level),
             ('shop_order', shop_order), ('price', price),
             ('unlock_round', unlock_round),
             ('max_health', float(hp)), ('attack', float(atk)), ('attack_range', float(rng)), ('attack_style', f'&"{attack_style(rng, arrows, heals)}"'),
             ('ability', f'&"{ability}"'), ('attack_cooldown', float(cd)), ('move_speed', float(spd)), ('intelligence', float(intel))]
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


# Bossgegner (Runde 5, 15, 25 ... reihum). Werte der Runde 1, sie werden mit der Runde skaliert.
BOSSES = [
    # id, Name, Farbe, Körpergröße, LP, Angriff, Reichweite, Stil, Abklingzeit, Tempo, Gold
    ('boss_ogre', 'Ogerkönig', '#8f5a2a', 36.0, 220, 9, 18, 'melee', 1.6, 20, 80),
    ('boss_dragon', 'Feuerdrache', '#d63c34', 36.0, 180, 11, 85, 'magic', 2.0, 18, 90),
    ('boss_bones', 'Knochenkönig', '#c8ccd8', 40.0, 190, 7, 100, 'arrow', 1.0, 22, 85),
    ('boss_golem', 'Steingigant', '#8795ad', 40.0, 300, 8, 18, 'melee', 2.0, 14, 95),
]


def write_bosses():
    for order, (uid, name, hex_color, body, hp, atk, rng, style, cd, spd, gold) in enumerate(BOSSES):
        lines = ['[gd_resource type="Resource" script_class="EnemyData" load_steps=3 format=3]', '',
                 '[ext_resource type="Script" path="res://scripts/data/enemy_data.gd" id="1"]',
                 f'[ext_resource type="Texture2D" path="res://assets/sprites/enemies/{uid}.png" id="2"]', '',
                 '[resource]', 'script = ExtResource("1")', 'sprite = ExtResource("2")',
                 f'id = &"{uid}"', f'display_name = "{name}"', f'color = {color(hex_color)}',
                 f'body_size = {body}', f'max_health = {float(hp)}', f'attack = {float(atk)}',
                 f'attack_range = {float(rng)}', f'attack_style = &"{style}"', f'attack_cooldown = {cd}',
                 f'move_speed = {float(spd)}', f'gold_reward = {gold}', f'min_round = {order}',
                 'weight = 0.0', 'intelligence = 20.0', 'is_boss = true']
        (ROOT / 'data/enemies' / f'{uid}.tres').write_text('\n'.join(lines) + '\n')


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
                unlock_round=content.LEVEL_UNLOCK_ROUND[i],
                arrows=key in ARROW_LINES, heals=key in HEAL_LINES, ability=content.UNIT_ABILITY[uid],
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
                category='Kombination', arrows=base in ARROW_COMBOS, heals=base in content.HEAL_COMBOS, ability=content.UNIT_ABILITY[uid],
                unlock_round=combo['unlock'] + content.COMBO_UNLOCK_STEP * level,
                upgrade=None if last else ids[level + 1],
                upgrade_cost=0 if last else round(combo['cost'] * content.COMBO_UPGRADE_MULT[level]))
        write_recipe(combo['a'], combo['b'], base, combo['cost'], combo['unlock'], base in content.SECRET_COMBOS)

    write_bosses()
    write_english_names()
    print('Einheiten, Rezepte und Bosse geschrieben.')


if __name__ == '__main__':
    main()
