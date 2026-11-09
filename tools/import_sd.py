#!/usr/bin/env python3
"""Erzeugt Grafiken mit Stable Diffusion über ComfyUI und legt sie unter tools/sd/ ab.

- textures: nahtlose Texturen für Boden und Mauern (tools/sd/textures/). Farbe und Helligkeit werden an die
  Dungeon-Crawl-Kacheln angeglichen, die sie ersetzen. arena_dcss.py baut die Arenen daraus wie bisher.
- bosses: die Bossarenen, mit ControlNet aus dem Generatorbild neu gezeichnet (tools/sd/arenas/). ControlNet
  hält Kanten und Flächen fest, der Grundriss bleibt. Vorher müssen die Texturen da sein.
- village: das Dorf genauso neu gezeichnet (tools/sd/village.png), Häuser und Wege bleiben, wo village.gd sie erwartet.
- sprites: die Bosse als Pixel-Art (Pixel-Art-LoRA, Hintergrund per BiRefNet entfernt), auf die
  Größe der bisherigen Bilder gebracht (tools/sd/sprites/). sprite_dcss.py und tiles_dcss.py nehmen sie statt der
  Kacheln. Unter etwa 40 Pixeln wird SD matschig, kleine Figuren, Hindernisse und die Münze bleiben deshalb Kacheln.

Nur nötig, wenn sich Texturen, Prompts oder Grundrisse ändern. Braucht Pillow und eine ComfyUI-
Instanz mit den Checkpoints und ControlNet-Modellen aus den Tabellen unten. Ergebnisse schwanken je nach GPU
etwas, deshalb liegen die PNGs im Repo. arena_dcss.py liest sie ohne Pillow.

Aufruf:  COMFYUI=http://rechner:8188 python3 tools/import_sd.py textures|bosses|village|sprites [name ...] [--seeds 1,2,3]
Mit --seeds landen Varianten zum Aussuchen in tools/sd/candidates/ (nicht im Repo). Die passende Seed in die
Tabelle eintragen und ohne --seeds neu laufen lassen.
"""
import argparse
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
import pixel_image as pi
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
    src_stat, ref_stat = ImageStat.Stat(img), ImageStat.Stat(ref)
    lut = []
    for c in range(3):
        ms, ss = src_stat.mean[c], src_stat.stddev[c] or 1.0
        mr, sr = ref_stat.mean[c], ref_stat.stddev[c]
        for v in range(256):
            target = (v - ms) / ss * sr + mr
            lut.append(max(0, min(255, round(v + (target - v) * COLOR_MATCH))))
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
    prompt, (bw, bh), default_seed = SPRITES[name]
    wf = _base(SPRITE_CKPT, f'pixel art, {prompt}, full body, single object, centered, plain white background, '
               'game sprite, dark fantasy', SPRITE_NEGATIVE)
    wf['lo'] = {'class_type': 'LoraLoader', 'inputs': {'model': ['ck', 0], 'clip': ['ck', 1], 'lora_name': PIXEL_LORA,
                                                       'strength_model': 1.0, 'strength_clip': 1.0}}
    for node in ('p', 'n'):
        wf[node]['inputs']['clip'] = ['lo', 1]
    wf['l'] = {'class_type': 'EmptyLatentImage', 'inputs': {'width': 1024, 'height': 1024, 'batch_size': 1}}
    wf['ks'] = {'class_type': 'KSampler', 'inputs': {
        'model': ['lo', 0], 'positive': ['p', 0], 'negative': ['n', 0], 'latent_image': ['l', 0],
        'seed': default_seed if seed is None else seed, 'steps': 6, 'cfg': 2.0, 'sampler_name': 'dpmpp_sde',
        'scheduler': 'karras', 'denoise': 1.0}}
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
    small = small.quantize(32, method=Image.Quantize.MAXCOVERAGE, dither=Image.Dither.NONE).convert('RGBA')
    small.putalpha(alpha)
    # Dunkler Umriss wie bei den Kacheln, damit sich die Figur vom Boden abhebt
    framed = Image.new('RGBA', (w + 2, h + 2), (0, 0, 0, 0))
    framed.paste(small, (1, 1))
    shape = framed.getchannel('A')
    ring = ImageChops.subtract(shape.filter(ImageFilter.MaxFilter(3)), shape)
    framed.paste(Image.new('RGBA', framed.size, OUTLINE), mask=ring)
    return framed.crop(framed.getbbox())


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
}


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('kind', choices=list(KINDS))
    ap.add_argument('names', nargs='*')
    ap.add_argument('--seeds', help='Varianten zum Aussuchen, z.B. 1,2,3')
    a = ap.parse_args()
    table, make, folder, filename = KINDS[a.kind]
    names = a.names or list(table)
    for name in names:
        if name not in table:
            raise SystemExit(f'Unbekannt: {name} (bekannt: {", ".join(table)})')
        if a.seeds:
            for seed in (int(s) for s in a.seeds.split(',')):
                _save(make(name, seed), OUT / 'candidates' / folder / f'{name}_s{seed}.png')
        else:
            _save(make(name), OUT / folder / filename.format(name))


if __name__ == '__main__':
    main()
