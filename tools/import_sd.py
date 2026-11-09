#!/usr/bin/env python3
"""Erzeugt Grafiken mit Stable Diffusion über ComfyUI und legt sie unter tools/sd/ ab.

- textures: nahtlose Texturen für Boden und Mauern (tools/sd/textures/). Farbe und Helligkeit werden an die
  Dungeon-Crawl-Kacheln angeglichen, die sie ersetzen. arena_dcss.py baut die Arenen daraus wie bisher.
- bosses: die Bossarenen, mit ControlNet aus dem Generatorbild neu gezeichnet (tools/sd/arenas/). ControlNet
  hält Kanten und Flächen fest, der Grundriss bleibt. Vorher müssen die Texturen da sein.
- village: das Dorf genauso neu gezeichnet (tools/sd/village.png), Häuser und Wege bleiben, wo village.gd sie erwartet.
- sprites: die Bosse als Pixel-Art (Pixel-Art-LoRA, Hintergrund per BiRefNet entfernt), auf die
  Größe der bisherigen Bilder gebracht (tools/sd/sprites/). sprite_dcss.py und tiles_dcss.py nehmen sie statt der
  Kacheln. Hindernisse und die Münze bleiben Kacheln, frei gezeichnet wird SD unter etwa 40 Pixeln matschig.
- figures: Einheiten und Gegner, mit der bisherigen Kachelfigur als Vorlage neu gezeichnet (img2img), so bleiben
  Pose, Blickrichtung, Farben und Ausrüstung (tools/sd/sprites/units/, enemies/). Übernommen sind die Figuren in
  FIGURES, bei den übrigen ging Wesentliches verloren (Skelett, Flügel, Reittier), sie bleiben Kacheln.

Nur nötig, wenn sich Texturen, Prompts oder Grundrisse ändern. Braucht Pillow und eine ComfyUI-
Instanz mit den Checkpoints und ControlNet-Modellen aus den Tabellen unten. Ergebnisse schwanken je nach GPU
etwas, deshalb liegen die PNGs im Repo. arena_dcss.py liest sie ohne Pillow.

Aufruf:  COMFYUI=http://rechner:8188 python3 tools/import_sd.py textures|bosses|village|sprites|figures [name ...] [--seeds 1,2,3]
Mit --seeds landen Varianten zum Aussuchen in tools/sd/candidates/ (nicht im Repo). Die passende Seed in die
Tabelle eintragen und ohne --seeds neu laufen lassen.
"""
import argparse
import functools
import glob
import io
import json
import os
import time
import urllib.request
import uuid
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageStat

import arena_dcss
import content
import pixel_image as pi
import sprite_dcss
import tiles_dcss

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'tools/sd'
DCSS = ROOT / 'tools/dcss/dungeon'
URL = os.environ.get('COMFYUI', 'http://127.0.0.1:8188')

PIXEL_CKPT = 'dreamshaper-8.safetensors'
PHOTO_CKPT = 'realistic-vision-6.safetensors'
NEGATIVE = 'perspective, vignette, shadow gradient, border, frame, text, watermark, blurry, people, objects'
PHOTO_NEGATIVE = 'isometric, 3d blocks, buildings, ' + NEGATIVE  # sonst zeichnet SD bei Mauern ganze Gebäude

# Name: Prompt, Größe (b, h), Seed, Fotostil (gegen isometrische Blöcke bei Mauern), Vorbild für die Farben
TEXTURES = {
    'grass': ('dense short green grass, top view, natural, tiny wildflowers', (128, 128), 4, False,
              'floor/grass/grass_[012]_new'),
    'flowers': ('green meadow full of small yellow blue and red flowers', (128, 128), 1, False,
                'floor/grass/grass_flowers_*'),
    'limestone': ('worn beige limestone floor slabs, cracks', (128, 128), 1, False, 'floor/limestone_*'),
    'plaza': ('old square sandstone flagstones floor, worn, cracks, top view', (128, 128), 11, True,
              'floor/limestone_*'),
    'gray': ('gray stone brick wall, rectangular blocks, moss in the mortar', (128, 64), 2, True,
             'wall/stone_brick_*'),
    'brown': ('brown sandstone brick wall, many small bricks, rough', (128, 64), 2, True, 'wall/brick_brown_?'),
    'vines': ('old brown brick wall with natural climbing ivy leaves, many small bricks', (128, 64), 5, True,
              'wall/brick_brown-vines_*'),
    'marble': ('white marble block wall, small polished blocks, subtle gray veins', (128, 64), 5, True,
               'wall/marble_wall_*'),
    'relief': ('ancient carved sandstone wall frieze, small figures bas-relief, egyptian', (128, 64), 5, True,
               'wall/relief_*'),
    'church': ('gothic cathedral stone wall, pointed arch windows', (128, 64), 1, False, 'wall/church_*'),
}
COLOR_MATCH = 0.85  # 1 = Farben ganz wie die Kacheln, 0 = wie von SD

# Bossarena: Prompt, Seed. Neu gezeichnet mit Stärke DENOISE, ControlNet "tile" mit Stärke CONTROL.
BOSSES = {
    'hall': ('gothic throne hall, stone walls with banners and torches, sandstone floor tiles, red carpet, '
             'flat empty stone platform in the center', 2),
    'chasm': ('stone bridge and platform over a dark bottomless chasm, ruined gray brick walls, glowing embers '
              'deep below', 2),
    'ring': ('round gladiator arena, stone brick walls with banners and torches, sandy dirt floor, '
             'flat empty stone platform in the center', 4),
}
BOSS_CKPT = PIXEL_CKPT
CONTROLNET = 'control_v11f1e_sd15_tile_fp16.safetensors'
DENOISE, CONTROL = 0.75, 0.8
VILLAGE = ('peaceful medieval village seen from above, small stone houses with doors, dirt paths, green meadow, '
           'trees, blue fountain in the middle', 3)

# Sprite: Prompt, größte Breite und Höhe (wie das bisherige Bild, damit Kollision und Platz passen), Seed
SPRITES = {
    'boss_ogre': ('ogre king boss, huge muscular ogre with a small golden crown, leather loincloth, big wooden club',
                  (58, 70), 1),
    'boss_dragon': ('fire dragon boss, red scales, purple wings spread, horns, standing', (64, 64), 2),
    'boss_bones': ('skeleton king boss, giant floating skeleton lich with a golden crown, tattered dark robe, '
                   'glowing eyes', (58, 60), 1),
    'boss_golem': ('stone giant boss, huge stone golem, glowing red eyes, cracked granite body, moss', (62, 62), 3),
}
SPRITE_CKPT = 'dreamshaper-xl-lightning.safetensors'
PIXEL_LORA = 'pixel-art-xl.safetensors'
BG_MODEL = 'birefnet.safetensors'
OUTLINE = (24, 16, 30, 255)
SPRITE_NEGATIVE = 'blurry, 3d render, photo, text, watermark, multiple characters, cropped, frame, scenery, ground'

BOSS_SUFFIX = 'top-down view of a dungeon arena, 16-bit pixel art game background, detailed textures, dark fantasy, rich shading'
BOSS_NEGATIVE = ('tower, well, fountain, statue, building in the center, letters, blurry, photo, text, watermark, '
                 'characters, people, monsters, perspective change, frame')


# --- ComfyUI -----------------------------------------------------------------------------

def _req(path, data=None, headers=None):
    request = urllib.request.Request(URL + path, data=data, headers=headers or {'Content-Type': 'application/json'})
    return urllib.request.urlopen(request, timeout=60).read()


def _upload(img):
    buf = io.BytesIO()
    img.save(buf, 'PNG')
    boundary = uuid.uuid4().hex
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="pm_{uuid.uuid4().hex[:8]}.png"\r\n'
            'Content-Type: image/png\r\n\r\n').encode() + buf.getvalue() + f'\r\n--{boundary}--\r\n'.encode()
    return json.loads(_req('/upload/image', body, {'Content-Type': f'multipart/form-data; boundary={boundary}'}))['name']


def _retry(make, *args, tries=4):
    """ComfyUI stürzt bei langen Läufen ab und startet neu: warten und noch einmal versuchen."""
    for attempt in range(tries):
        try:
            return make(*args)
        except OSError as err:
            if attempt == tries - 1:
                raise
            print(f'ComfyUI nicht erreichbar ({err}), warte auf Neustart')
            while True:
                time.sleep(10)
                try:
                    _req('/system_stats')
                    break
                except OSError:
                    pass


def _run(workflow, extra=None):
    """Workflow abschicken, auf das Ergebnis warten, das Bild des Knotens 'save' zurückgeben (mit extra auch dessen)."""
    pid = json.loads(_req('/prompt', json.dumps({'prompt': workflow}).encode()))['prompt_id']
    while True:
        time.sleep(2)
        history = json.loads(_req('/history/' + pid))
        if pid in history:
            break
    status = history[pid]['status']
    if status['status_str'] != 'success':
        raise SystemExit(f'ComfyUI-Fehler: {status["messages"][-1]}')
    def image(node):
        name = history[pid]['outputs'][node]['images'][0]['filename']
        return Image.open(io.BytesIO(_req(f'/view?filename={name}&type=output'))).convert('RGB')
    return (image('save'), image(extra)) if extra else image('save')


def _base(ckpt, prompt, negative):
    return {'ck': {'class_type': 'CheckpointLoaderSimple', 'inputs': {'ckpt_name': ckpt}},
            'p': {'class_type': 'CLIPTextEncode', 'inputs': {'clip': ['ck', 1], 'text': prompt}},
            'n': {'class_type': 'CLIPTextEncode', 'inputs': {'clip': ['ck', 1], 'text': negative}},
            'vd': {'class_type': 'VAEDecodeTiled', 'inputs': {'samples': ['ks', 0], 'vae': ['ck', 2], 'tile_size': 512,
                                                              'overlap': 64, 'temporal_size': 64, 'temporal_overlap': 8}},
            'save': {'class_type': 'SaveImage', 'inputs': {'images': ['vd', 0], 'filename_prefix': 'pixel_merger'}}}


def _sampler(seed, latent, denoise, positive=('p', 0), negative=('n', 0)):
    return {'class_type': 'KSampler', 'inputs': {
        'model': ['ck', 0], 'positive': list(positive), 'negative': list(negative), 'latent_image': [latent, 0],
        'seed': seed, 'steps': 25, 'cfg': 7, 'sampler_name': 'dpmpp_2m', 'scheduler': 'karras', 'denoise': denoise}}


# --- Texturen ----------------------------------------------------------------------------

def _seamless(img):
    """Kachelbar machen: Mitte vom Original, Ränder von der um eine halbe Größe verschobenen Kopie."""
    shifted = ImageChops.offset(img, img.width // 2, img.height // 2)
    mask = Image.new('L', img.size, 0)
    bw, bh = img.width // 6, img.height // 6
    ImageDraw.Draw(mask).rectangle((bw, bh, img.width - bw, img.height - bh), fill=255)
    return Image.composite(img, shifted, mask.filter(ImageFilter.GaussianBlur(min(bw, bh) * 0.6)))


def _match_colors(img, pattern):
    """Mittelwert und Streuung je Farbkanal an die Vorbild-Kacheln angleichen."""
    tiles = [Image.open(f).convert('RGB') for f in sorted(glob.glob(str(DCSS / f'{pattern}.png')))]
    if not tiles:
        raise SystemExit(f'Keine Vorbild-Kacheln für {pattern}')
    ref = Image.new('RGB', (32 * len(tiles), 32))
    for i, t in enumerate(tiles):
        ref.paste(t.resize((32, 32)), (32 * i, 0))
    return _match_to(img, ref, COLOR_MATCH)


def _match_to(img, ref, strength, mask=None, ref_mask=None):
    src_stat, ref_stat = ImageStat.Stat(img, mask), ImageStat.Stat(ref, ref_mask)
    lut = []
    for c in range(3):
        ms, ss = src_stat.mean[c], src_stat.stddev[c] or 1.0
        mr, sr = ref_stat.mean[c], ref_stat.stddev[c]
        for v in range(256):
            target = (v - ms) / ss * sr + mr
            lut.append(max(0, min(255, round(v + (target - v) * strength))))
    return img.point(lut)


def texture(name, seed=None):
    prompt, (w, h), default_seed, photo, ref = TEXTURES[name]
    if photo:
        prompt += ', seamless texture, frontal photo, orthographic, flat even lighting, high detail'
    else:
        prompt += ', seamless tileable texture, flat orthographic top-down, even lighting, 16-bit pixel art game texture, crisp detail'
    gw, gh = (512 * w // h, 512) if w >= h else (512, 512 * h // w)
    wf = _base(PHOTO_CKPT if photo else PIXEL_CKPT, prompt, PHOTO_NEGATIVE if photo else NEGATIVE)
    wf['l'] = {'class_type': 'EmptyLatentImage', 'inputs': {'width': gw // 8 * 8, 'height': gh // 8 * 8, 'batch_size': 1}}
    wf['ks'] = _sampler(default_seed if seed is None else seed, 'l', 1.0)
    img = _seamless(_run(wf)).resize((w, h), Image.BOX)
    img = img.quantize(24, method=Image.Quantize.MAXCOVERAGE, dither=Image.Dither.NONE).convert('RGB')
    return _match_colors(img, ref).convert('RGBA')


# --- Bossarenen --------------------------------------------------------------------------

def boss(name, seed=None):
    prompt, default_seed = BOSSES[name]
    return _redraw(arena_dcss.arena(name, arena_dcss.BOSS_THEMES[name]), prompt, default_seed if seed is None else seed)


def village(name, seed=None):
    prompt, default_seed = VILLAGE
    return _redraw(tiles_dcss.village(), prompt, default_seed if seed is None else seed)


def _redraw(base, prompt, seed):
    """Generatorbild mit ControlNet neu zeichnen lassen, Kanten und Flächen bleiben."""
    src = Image.new('RGBA', (base.w, base.h))
    src.putdata(base.px)
    gw = 1024
    gh = round(gw * base.h / base.w / 8) * 8
    big = src.convert('RGB').resize((gw, gh), Image.NEAREST).filter(ImageFilter.GaussianBlur(0.8))
    wf = _base(BOSS_CKPT, f'{prompt}, {BOSS_SUFFIX}', BOSS_NEGATIVE)
    wf['li'] = {'class_type': 'LoadImage', 'inputs': {'image': _upload(big)}}
    wf['ve'] = {'class_type': 'VAEEncode', 'inputs': {'pixels': ['li', 0], 'vae': ['ck', 2]}}
    wf['cl'] = {'class_type': 'ControlNetLoader', 'inputs': {'control_net_name': CONTROLNET}}
    wf['ca'] = {'class_type': 'ControlNetApplyAdvanced', 'inputs': {
        'positive': ['p', 0], 'negative': ['n', 0], 'control_net': ['cl', 0], 'image': ['li', 0],
        'strength': CONTROL, 'start_percent': 0.0, 'end_percent': 1.0}}
    wf['ks'] = _sampler(seed, 've', DENOISE, ('ca', 0), ('ca', 1))
    img = _run(wf).resize((base.w, base.h), Image.BOX)
    return img.quantize(96, method=Image.Quantize.MAXCOVERAGE, dither=Image.Dither.NONE).convert('RGBA')


# --- Sprites -----------------------------------------------------------------------------

def sprite(name, seed=None):
    prompt, size, default_seed = SPRITES[name]
    return sprite_image(prompt, size, default_seed if seed is None else seed)


def sprite_image(prompt, size, seed, negative=SPRITE_NEGATIVE, template=None, original=None, denoise=1.0):
    """Mit Vorlage (PIL-Bild 1024x1024) img2img: Pose, Farben und Ausrüstung bleiben, SD zeichnet neu.
    Die Farben werden zum Teil an das Original (klein, RGBA) angeglichen, SD bleicht sie sonst aus."""
    bw, bh = size
    wf = _base(SPRITE_CKPT, f'pixel art, {prompt}, full body, single object, centered, plain white background, '
               'game sprite, dark fantasy', negative)
    wf['lo'] = {'class_type': 'LoraLoader', 'inputs': {'model': ['ck', 0], 'clip': ['ck', 1], 'lora_name': PIXEL_LORA,
                                                       'strength_model': 1.0, 'strength_clip': 1.0}}
    for node in ('p', 'n'):
        wf[node]['inputs']['clip'] = ['lo', 1]
    if template is None:
        wf['l'] = {'class_type': 'EmptyLatentImage', 'inputs': {'width': 1024, 'height': 1024, 'batch_size': 1}}
    else:
        wf['li'] = {'class_type': 'LoadImage', 'inputs': {'image': _upload(template)}}
        wf['l'] = {'class_type': 'VAEEncode', 'inputs': {'pixels': ['li', 0], 'vae': ['ck', 2]}}
    wf['ks'] = {'class_type': 'KSampler', 'inputs': {
        'model': ['lo', 0], 'positive': ['p', 0], 'negative': ['n', 0], 'latent_image': ['l', 0],
        'seed': seed, 'steps': 6, 'cfg': 2.0, 'sampler_name': 'dpmpp_sde',
        'scheduler': 'karras', 'denoise': denoise}}
    # Maske als zweites Bild: Hintergrund per BiRefNet
    wf['bg'] = {'class_type': 'LoadBackgroundRemovalModel', 'inputs': {'bg_removal_name': BG_MODEL}}
    wf['rb'] = {'class_type': 'RemoveBackground', 'inputs': {'bg_removal_model': ['bg', 0], 'image': ['vd', 0]}}
    wf['mi'] = {'class_type': 'MaskToImage', 'inputs': {'mask': ['rb', 0]}}
    wf['save_mask'] = {'class_type': 'SaveImage', 'inputs': {'images': ['mi', 0], 'filename_prefix': 'pixel_merger_mask'}}
    img, mask = _run(wf, extra='save_mask')
    rgba = img.copy()
    rgba.putalpha(mask.convert('L').point(lambda v: 255 if v > 110 else 0))
    rgba = rgba.crop(rgba.getbbox())
    scale = min((bw - 2) / rgba.width, (bh - 2) / rgba.height)  # 1 Pixel Umriss je Seite
    w, h = max(1, round(rgba.width * scale)), max(1, round(rgba.height * scale))
    alpha = rgba.getchannel('A').resize((w, h), Image.BOX).point(lambda v: 255 if v > 120 else 0)
    small = rgba.convert('RGB').resize((w, h), Image.BOX)
    if original is not None:
        small = _match_to(small, original.convert('RGB'), FIGURE_COLOR_MATCH, alpha, original.getchannel('A'))
    small = small.quantize(32, method=Image.Quantize.MAXCOVERAGE, dither=Image.Dither.NONE).convert('RGBA')
    small.putalpha(alpha)
    # Dunkler Umriss wie bei den Kacheln, damit sich die Figur vom Boden abhebt
    framed = Image.new('RGBA', (w + 2, h + 2), (0, 0, 0, 0))
    framed.paste(small, (1, 1))
    shape = framed.getchannel('A')
    ring = ImageChops.subtract(shape.filter(ImageFilter.MaxFilter(3)), shape)
    framed.paste(Image.new('RGBA', framed.size, OUTLINE), mask=ring)
    return framed.crop(framed.getbbox())


# --- Figuren (Einheiten und Gegner) -------------------------------------------------------
# Der Prompt kommt aus der bisherigen Kachelfigur: welche Kacheln sie lädt (Körper, Rüstung, Waffe, Umhang),
# dazu Name, Farbe und Körperbau. Kombinationen bekommen ein Bild für alle Stufen (sprite_dcss setzt den Rand).

FIGURE_SKIP = ('legs', 'boots', 'gloves')  # bei 32 Pixeln nicht zu sehen
FIGURE_BODY = {'quadruped': 'four-legged animal', 'rider': 'riding a horse', 'serpent': 'serpent', 'flyer': 'flying',
               'floater': 'floating', 'hopper': 'small creature', 'colossus': 'huge creature', 'blob': 'blob'}
FIGURE_DENOISE = float(os.environ.get('FIGURE_DENOISE', 0.75))  # wie weit SD von der Vorlage abweicht
FIGURE_COLOR_MATCH = 0.5
# Übernommene Figuren: Denoise und Seed. Nicht aufgeführte bleiben Kacheln (SD hat dort Wesentliches verloren).
FIGURES = {
    'enemies/dark_mage': (0.75, 1), 'enemies/gargoyle': (0.75, 1), 'enemies/ghost': (0.75, 1),
    'enemies/gnoll_sergeant': (0.75, 1), 'enemies/gnoll_shaman': (0.75, 1), 'enemies/goblin': (0.75, 1),
    'enemies/jackal': (0.75, 1), 'enemies/mushroom': (0.75, 1), 'enemies/necromancer': (0.75, 1),
    'enemies/ogre': (0.75, 1), 'enemies/orc': (0.75, 1), 'enemies/slime': (0.75, 1), 'enemies/spiny_frog': (0.75, 1),
    'enemies/troll': (0.75, 1), 'enemies/vampire': (0.75, 1), 'enemies/warg': (0.75, 1), 'units/abbot': (0.75, 1),
    'units/achilles': (0.75, 1), 'units/angel': (0.75, 1), 'units/anubis': (0.75, 1), 'units/apis': (0.75, 1),
    'units/apprentice': (0.75, 1), 'units/arcane_archer': (0.75, 1), 'units/archer': (0.75, 1),
    'units/archmage': (0.75, 1), 'units/asclepius': (0.75, 1), 'units/axe_master': (0.75, 1),
    'units/baba_yaga': (0.75, 1), 'units/basilisk': (0.75, 1), 'units/beast_master': (0.75, 1),
    'units/bodyguard': (0.75, 1), 'units/bone_dragon': (0.6, 1), 'units/breeze': (0.75, 1),
    'units/broom_witch': (0.75, 1), 'units/centaur': (0.75, 1), 'units/centaur_lord': (0.75, 1),
    'units/chimera': (0.75, 1), 'units/crusader': (0.75, 1), 'units/cyclops': (0.6, 1), 'units/dark_elf': (0.75, 1),
    'units/dark_witch': (0.75, 1), 'units/destrier': (0.6, 1), 'units/djinn': (0.75, 1), 'units/doctor': (0.75, 1),
    'units/dragon': (0.75, 1), 'units/dragon_mage': (0.75, 1), 'units/dragon_rider': (0.75, 1),
    'units/droplet': (0.75, 1), 'units/druid': (0.75, 1), 'units/dryad': (0.75, 1), 'units/dwarf_gunner': (0.75, 1),
    'units/dwarf_knight': (0.75, 1), 'units/dwarf_lord': (0.75, 1), 'units/dwarf_warrior': (0.75, 1),
    'units/earth_elemental': (0.75, 1), 'units/earth_spirit': (0.75, 1), 'units/elder_dragon': (0.75, 1),
    'units/elf_king': (0.75, 1), 'units/elf_lord': (0.75, 1), 'units/elf_mage': (0.75, 1),
    'units/elf_scout': (0.75, 1), 'units/exorcist': (0.75, 1), 'units/fairy': (0.75, 1), 'units/faun': (0.75, 1),
    'units/fenrir': (0.6, 1), 'units/field_medic': (0.75, 1), 'units/fire_dragon': (0.75, 1),
    'units/fire_dwarf': (0.75, 1), 'units/fire_elemental': (0.75, 1), 'units/fire_elf': (0.75, 1),
    'units/fire_giant': (0.75, 1), 'units/fire_golem': (0.75, 1), 'units/fire_knight': (0.75, 1),
    'units/fire_spirit': (0.75, 1), 'units/fire_wolf': (0.6, 1), 'units/flame': (0.75, 1), 'units/foal': (0.75, 1),
    'units/frog': (0.75, 1), 'units/frog_king': (0.75, 1), 'units/frog_prince': (0.75, 1),
    'units/frost_demon': (0.75, 1), 'units/frost_imp': (0.6, 1), 'units/frost_knight': (0.75, 1),
    'units/frost_lord': (0.75, 1), 'units/frost_spirit': (0.75, 1), 'units/gaia': (0.75, 1), 'units/ghost': (0.75, 1),
    'units/ghoul': (0.6, 1), 'units/giant': (0.75, 1), 'units/giant_toad': (0.75, 1), 'units/gnome': (0.75, 1),
    'units/gnome_rider': (0.75, 1), 'units/golem': (0.75, 1), 'units/grand_mage': (0.75, 1),
    'units/griffin': (0.75, 1), 'units/griffin_rider': (0.75, 1), 'units/guardsman': (0.75, 1),
    'units/halberdier': (0.75, 1), 'units/hawkeye': (0.6, 1), 'units/healer': (0.75, 1),
    'units/herb_healer': (0.75, 1), 'units/herbalist': (0.75, 1), 'units/hercules': (0.75, 1),
    'units/high_elf': (0.75, 1), 'units/hippogriff': (0.75, 1), 'units/holy_rider': (0.75, 1),
    'units/horse': (0.75, 1), 'units/hunter': (0.75, 1), 'units/hydra': (0.6, 1), 'units/hydromancer': (0.75, 1),
    'units/ice_dragon': (0.75, 1), 'units/ice_giant': (0.75, 1), 'units/ice_griffin': (0.75, 1),
    'units/ice_mage': (0.75, 1), 'units/ifrit': (0.75, 1), 'units/kelpie': (0.75, 1), 'units/king_arthur': (0.75, 1),
    'units/knight': (0.75, 1), 'units/kraken': (0.75, 1), 'units/lamassu': (0.75, 1), 'units/lamia': (0.75, 1),
    'units/lancer': (0.75, 1), 'units/lava': (0.75, 1), 'units/legend': (0.75, 1), 'units/leviathan': (0.75, 1),
    'units/lich_king': (0.75, 1), 'units/lightning': (0.6, 1), 'units/loki': (0.75, 1), 'units/mage': (0.75, 1),
    'units/mage_rider': (0.75, 1), 'units/marshal': (0.75, 1), 'units/medusa': (0.75, 1),
    'units/mercenary': (0.75, 1), 'units/merlin': (0.75, 1), 'units/miner': (0.75, 1), 'units/minotaur': (0.75, 1),
    'units/monk': (0.75, 1), 'units/mountain_king': (0.75, 1), 'units/mounted_archer': (0.75, 1),
    'units/mounted_knight': (0.75, 1), 'units/mummy': (0.75, 1), 'units/naga': (0.75, 1),
    'units/naga_archer': (0.75, 1), 'units/naga_guard': (0.75, 1), 'units/naga_mage': (0.75, 1),
    'units/naga_queen': (0.75, 1), 'units/necromancer': (0.75, 1), 'units/newt': (0.75, 1),
    'units/nightmare': (0.75, 1), 'units/novice': (0.75, 1), 'units/nymph': (0.75, 1), 'units/paladin': (0.75, 1),
    'units/peasant': (0.75, 1), 'units/pebble': (0.75, 1), 'units/pegasus': (0.75, 1), 'units/phoenix': (0.75, 1),
    'units/pikeman': (0.75, 1), 'units/plague_doctor': (0.75, 1), 'units/polar_bear': (0.75, 1),
    'units/priest': (0.75, 1), 'units/prior': (0.75, 1), 'units/pyromancer': (0.75, 1), 'units/red_hood': (0.75, 1),
    'units/revenant': (0.75, 1), 'units/robin_hood': (0.75, 1), 'units/rune_master': (0.75, 1),
    'units/saint': (0.75, 1), 'units/sand_golem': (0.75, 1), 'units/sandstorm': (0.75, 1), 'units/satyr': (0.75, 1),
    'units/shadow_wolf': (0.75, 1), 'units/shaman': (0.75, 1), 'units/sharpshooter': (0.75, 1),
    'units/shock_serpent': (0.75, 1), 'units/silver_unicorn': (0.75, 1), 'units/siren': (0.75, 1),
    'units/skeleton': (0.75, 1), 'units/sky_griffin': (0.75, 1), 'units/sleipnir': (0.75, 1),
    'units/slinger': (0.75, 1), 'units/snow_queen': (0.75, 1), 'units/snowflake': (0.75, 1),
    'units/sorceress': (0.75, 1), 'units/spark': (0.75, 1), 'units/spearman': (0.75, 1), 'units/sphinx': (0.75, 1),
    'units/spiny_frog': (0.75, 1), 'units/squire': (0.75, 1), 'units/st_george': (0.75, 1), 'units/steam': (0.75, 1),
    'units/stone_giant': (0.75, 1), 'units/stone_guard': (0.75, 1), 'units/storm_archer': (0.75, 1),
    'units/stormsteed': (0.75, 1), 'units/templar': (0.75, 1), 'units/thor': (0.75, 1),
    'units/thunderbird': (0.75, 1), 'units/titan': (0.75, 1), 'units/treant': (0.75, 1), 'units/tree_frog': (0.75, 1),
    'units/triton': (0.75, 1), 'units/troll': (0.75, 1), 'units/unicorn': (0.75, 1), 'units/valkyrie': (0.75, 1),
    'units/vampire': (0.75, 1), 'units/warhorse': (0.6, 1), 'units/water_elemental': (0.75, 1),
    'units/water_golem': (0.75, 1), 'units/water_spirit': (0.75, 1), 'units/wave': (0.75, 1),
    'units/werewolf': (0.75, 1), 'units/wild_hunter': (0.75, 1), 'units/wind_spirit': (0.75, 1),
    'units/witch': (0.75, 1), 'units/witch_doctor': (0.75, 1), 'units/witch_queen': (0.75, 1),
    'units/wolf': (0.75, 1), 'units/wolf_pup': (0.75, 1), 'units/wood_elf': (0.75, 1),
    'units/world_weaver': (0.75, 1), 'units/wyrmling': (0.75, 1), 'units/young_dragon': (0.75, 1),
    'units/zombie_giant': (0.75, 1),
}


def _color_name(hex_color):
    r, g, b = (int(hex_color[i:i + 2], 16) / 255 for i in (1, 3, 5))
    hi, lo = max(r, g, b), min(r, g, b)
    if hi - lo < 0.12:
        return 'white' if hi > 0.8 else 'black' if hi < 0.25 else 'gray'
    if hi == r:
        hue = ((g - b) / (hi - lo)) % 6
    elif hi == g:
        hue = (b - r) / (hi - lo) + 2
    else:
        hue = (r - g) / (hi - lo) + 4
    names = ['red', 'orange', 'yellow', 'yellow', 'green', 'green', 'cyan', 'blue', 'blue', 'purple', 'magenta', 'red']
    name = names[int(hue * 2) % 12]
    return ('dark ' if hi < 0.45 else '') + ('brown' if name in ('orange', 'yellow') and hi < 0.65 else name)


def _tile_words(rel):
    parts = rel.split('/')
    word = parts[-1].replace('_new', '').replace('-', ' ').replace('_', ' ').rstrip('0123456789 ')
    if parts[0] == 'player':
        slot = parts[1]
        if slot in FIGURE_SKIP:
            return None
        if slot == 'base':
            return word.replace('male', '').replace('fe', '').strip() or 'human'
        if slot in ('hair', 'beard'):
            return f'{word} {slot}'
        if slot == 'hand_right':
            return f'holding {word}'
        if slot == 'hand_left':
            return f'with {word}'
        return word if slot != 'cloak' else f'{word} cloak'
    return word.replace('monster ', '')


def _describe(make):
    """Kacheln und Pferde, die der Erzeuger der bisherigen Figur benutzt, als Stichworte."""
    words = []
    tile, horse = sprite_dcss.tile, sprite_dcss.horse
    def rec_tile(rel):
        words.append(_tile_words(rel))
        return tile(rel)
    def rec_horse(coat='brown', eye='#0a0806'):
        words.append(f'{coat} horse')
        return horse(coat, eye)
    sprite_dcss.tile, sprite_dcss.horse = rec_tile, rec_horse
    try:
        img = make()
    finally:
        sprite_dcss.tile, sprite_dcss.horse = tile, horse
    return img, words


@functools.cache
def figures():
    """units/<Id> und enemies/<Id> -> (Prompt, bisherige Figur). Kombinationen einmal unter ihrer Basis-Id."""
    from i18n_names import EN
    table = {}
    def add(key, make, name, color, body):
        img, words = _describe(make)
        img = pi.trim(img)
        parts = [name.lower(), *words, FIGURE_BODY.get(body), color and f'{_color_name(color)} colors']
        table[key] = (', '.join(dict.fromkeys(p for p in parts if p)), img)
    for line in content.LINES.values():
        for uid, name, color in zip(line['ids'], line['names'], line['colors']):
            add(f'units/{uid}', sprite_dcss.LINE[uid], EN[name], color, content.UNIT_PROFILE[uid]['body'])
    for base, combo in content.COMBOS.items():
        spec = sprite_dcss.COMBO[base]
        add(f'units/{base}', spec[0] if isinstance(spec, list) else spec, EN[combo['names'][0]], combo['color'],
            content.UNIT_PROFILE[base]['body'])
    for uid, make in sprite_dcss.ENEMIES.items():
        if not uid.startswith('boss_'):
            add(f'enemies/{uid}', make, uid.replace('_', ' '), None, sprite_dcss.ENEMY_BODY.get(uid, 'biped'))
    return table


def _template(img):
    """Bisherige Figur groß auf Weiß als Vorlage für img2img (Schatten am Boden weggelassen), dazu klein."""
    small = Image.frombytes('RGBA', (img.w, img.h), bytes(v for c in img.px for v in (c if c[3] > 200 else (0, 0, 0, 0))))
    factor = 800 // max(img.w, img.h)
    big = small.resize((img.w * factor, img.h * factor), Image.NEAREST)
    canvas = Image.new('RGB', (1024, 1024), 'white')
    canvas.paste(big, ((1024 - big.width) // 2, (1024 - big.height) // 2), big)
    return canvas, small


def figure(name, seed=None):
    prompt, img = figures()[name]
    denoise, picked = FIGURES.get(name, (FIGURE_DENOISE, 1))
    return sprite_image(prompt, (img.w, img.h), picked if seed is None else seed, SPRITE_NEGATIVE, *_template(img),
                        denoise=denoise)


def _save(img, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.convert('RGBA').save(path)  # RGBA ohne Interlacing, wie pixel_image.py es erwartet
    print(path.relative_to(ROOT))


# Art: Tabelle, Erzeuger, Ordner unter tools/sd/, Dateiname
KINDS = {
    'textures': (TEXTURES, texture, 'textures', '{}.png'),
    'bosses': (BOSSES, boss, 'arenas', 'arena_{}.png'),
    'village': ({'village': VILLAGE}, village, '.', '{}.png'),
    'sprites': (SPRITES, sprite, 'sprites', '{}.png'),
    'figures': (None, figure, 'sprites', '{}.png'),
}


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('kind', choices=list(KINDS))
    ap.add_argument('names', nargs='*')
    ap.add_argument('--seeds', help='Varianten zum Aussuchen, z.B. 1,2,3')
    a = ap.parse_args()
    table, make, folder, filename = KINDS[a.kind]
    if table is None:  # figures: ohne Namen nur die übernommenen neu erzeugen
        table = figures()
        names = a.names or list(FIGURES)
    else:
        names = a.names or list(table)
    for name in names:
        if name not in table:
            raise SystemExit(f'Unbekannt: {name} (bekannt: {", ".join(table)})')
        if a.seeds:
            for seed in (int(s) for s in a.seeds.split(',')):
                path = OUT / 'candidates' / folder / f'{name}_s{seed}.png'
                if not path.exists():  # nach Abbruch weitermachen; zum Neuerzeugen den Ordner leeren
                    _save(_retry(make, name, seed), path)
        else:
            _save(_retry(make, name), OUT / folder / filename.format(name))


if __name__ == '__main__':
    main()
