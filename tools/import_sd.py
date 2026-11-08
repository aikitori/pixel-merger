#!/usr/bin/env python3
"""Erzeugt Arena-Texturen und Bossarenen mit Stable Diffusion über ComfyUI und legt sie unter tools/sd/ ab.

- textures: nahtlose Texturen für Boden und Mauern (tools/sd/textures/). Farbe und Helligkeit werden an die
  Dungeon-Crawl-Kacheln angeglichen, die sie ersetzen. arena_dcss.py baut die Arenen daraus wie bisher.
- bosses: die Bossarenen, mit ControlNet aus dem Generatorbild neu gezeichnet (tools/sd/arenas/). ControlNet
  hält Kanten und Flächen fest, der Grundriss bleibt. Vorher müssen die Texturen da sein.

Nur nötig, wenn sich Texturen, Prompts oder Grundrisse der Bossarenen ändern. Braucht Pillow und eine ComfyUI-
Instanz mit den Checkpoints und ControlNet-Modellen aus den Tabellen unten. Ergebnisse schwanken je nach GPU
etwas, deshalb liegen die PNGs im Repo. arena_dcss.py liest sie ohne Pillow.

Aufruf:  COMFYUI=http://rechner:8188 python3 tools/import_sd.py textures|bosses [name ...] [--seeds 1,2,3]
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


def _run(workflow):
    """Workflow abschicken, auf das Ergebnis warten, das Bild des Knotens 'save' zurückgeben."""
    pid = json.loads(_req('/prompt', json.dumps({'prompt': workflow}).encode()))['prompt_id']
    while True:
        time.sleep(2)
        history = json.loads(_req('/history/' + pid))
        if pid in history:
            break
    status = history[pid]['status']
    if status['status_str'] != 'success':
        raise SystemExit(f'ComfyUI-Fehler: {status["messages"][-1]}')
    name = history[pid]['outputs']['save']['images'][0]['filename']
    return Image.open(io.BytesIO(_req(f'/view?filename={name}&type=output'))).convert('RGB')


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
    base = arena_dcss.arena(name, arena_dcss.BOSS_THEMES[name])
    src = Image.new('RGBA', (base.w, base.h))
    src.putdata(base.px)
    big = src.convert('RGB').resize((1024, 576), Image.NEAREST).filter(ImageFilter.GaussianBlur(0.8))
    wf = _base(BOSS_CKPT, f'{prompt}, {BOSS_SUFFIX}', BOSS_NEGATIVE)
    wf['li'] = {'class_type': 'LoadImage', 'inputs': {'image': _upload(big)}}
    wf['ve'] = {'class_type': 'VAEEncode', 'inputs': {'pixels': ['li', 0], 'vae': ['ck', 2]}}
    wf['cl'] = {'class_type': 'ControlNetLoader', 'inputs': {'control_net_name': CONTROLNET}}
    wf['ca'] = {'class_type': 'ControlNetApplyAdvanced', 'inputs': {
        'positive': ['p', 0], 'negative': ['n', 0], 'control_net': ['cl', 0], 'image': ['li', 0],
        'strength': CONTROL, 'start_percent': 0.0, 'end_percent': 1.0}}
    wf['ks'] = _sampler(default_seed if seed is None else seed, 've', DENOISE, ('ca', 0), ('ca', 1))
    img = _run(wf).resize((base.w, base.h), Image.BOX)
    return img.quantize(96, method=Image.Quantize.MAXCOVERAGE, dither=Image.Dither.NONE).convert('RGBA')


def _save(img, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.convert('RGBA').save(path)  # RGBA ohne Interlacing, wie pixel_image.py es erwartet
    print(path.relative_to(ROOT))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('kind', choices=['textures', 'bosses'])
    ap.add_argument('names', nargs='*')
    ap.add_argument('--seeds', help='Varianten zum Aussuchen, z.B. 1,2,3')
    a = ap.parse_args()
    table, make, folder = (TEXTURES, texture, 'textures') if a.kind == 'textures' else (BOSSES, boss, 'arenas')
    names = a.names or list(table)
    for name in names:
        if name not in table:
            raise SystemExit(f'Unbekannt: {name} (bekannt: {", ".join(table)})')
        if a.seeds:
            for seed in (int(s) for s in a.seeds.split(',')):
                _save(make(name, seed), OUT / 'candidates' / folder / f'{name}_s{seed}.png')
        else:
            _save(make(name), OUT / folder / (f'arena_{name}.png' if a.kind == 'bosses' else f'{name}.png'))


if __name__ == '__main__':
    main()
