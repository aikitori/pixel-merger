#!/usr/bin/env python3
"""Kopiert die benötigten Kacheln aus Dungeon Crawl Stone Soup (CC0) nach tools/dcss/.

Nur nötig, wenn sprite_dcss.py oder tiles_dcss.py neue Kacheln verwenden. Braucht Pillow und das
entpackte Paket "Dungeon Crawl Stone Soup Full" von https://opengameart.org/content/dungeon-crawl-32x32-tiles-supplemental

Aufruf:  python3 tools/import_dcss.py "/pfad/Dungeon Crawl Stone Soup Full"

Die Kacheln werden als RGBA ohne Interlacing gespeichert, damit pixel_image.py sie ohne Pillow lesen kann.
Nicht mehr verwendete Kacheln in tools/dcss/ werden gelöscht.
"""
import shutil
import sys
from pathlib import Path

from PIL import Image

import pixel_image as pi
import sprite_dcss
import tiles_dcss

used = {}


def main():
    source = Path(sys.argv[1])
    target = sprite_dcss.TILES

    def load(rel):
        path = source / f'{rel}.png'
        if not path.exists():  # neuere Fassungen heißen oft *_new
            path = source / f'{rel}_new.png'
        if not path.exists():
            raise SystemExit(f'Kachel fehlt im Paket: {rel}')
        img = Image.open(path).convert('RGBA')
        used[rel] = img
        return pi.Img(img.width, img.height, list(img.getdata()))

    sprite_dcss.loader = load
    sprite_dcss.build()
    tiles_dcss.build()
    if target.exists():
        for old in target.rglob('*.png'):
            old.unlink()
    for rel, img in sorted(used.items()):
        path = target / f'{rel}.png'
        path.parent.mkdir(parents=True, exist_ok=True)
        img.save(path)
    for name in ('LICENSE.txt', 'README.txt'):
        shutil.copy(source / name, target / name)
    (target / '.gdignore').write_text('')
    print(f'{len(used)} Kacheln nach {target} kopiert.')


if __name__ == '__main__':
    main()
