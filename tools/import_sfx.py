#!/usr/bin/env python3
"""Holt die verwendeten CC0-Soundeffekte aus den heruntergeladenen Paketen nach tools/sfx_cc0/ (einmalig, braucht ffmpeg).

Aufruf: python3 tools/import_sfx.py <Paketordner> [<Paketordner> ...]
Pakete: Kenney "RPG Audio", "Impact Sounds", "Interface Sounds", "Music Jingles" (kenney.nl) und
"The Essential Retro Video Game Sound Effects Collection [512 sounds]" von Juhani Junkala (opengameart.org).
Welche Dateien gebraucht werden, steht in CC0_SFX in tools/generate_audio.py. Die Dateien werden in WAV
(mono, 22,05 kHz, 16 Bit) umgewandelt, damit generate_audio.py sie mit der Standardbibliothek lesen kann.
"""
import subprocess
import sys
from pathlib import Path

from generate_audio import CC0_DIR, CC0_SFX, RATE


def main():
    folders = [Path(p) for p in sys.argv[1:]]
    if not folders:
        sys.exit(__doc__)
    CC0_DIR.mkdir(exist_ok=True)
    for effect, (source, name) in CC0_SFX.items():
        matches = [f for d in folders for f in d.rglob(f'{name}.*') if f.suffix in ('.ogg', '.wav')]
        if not matches:
            sys.exit(f'{name} ({effect}) in keinem Paket gefunden')
        target = CC0_DIR / f'{name}.wav'
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(matches[0]), '-ac', '1', '-ar', str(RATE),
                        '-sample_fmt', 's16', str(target)], check=True)
        print(f'{effect}: {source} / {name}')


if __name__ == '__main__':
    main()
