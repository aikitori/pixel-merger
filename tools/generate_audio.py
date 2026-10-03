#!/usr/bin/env python3
"""Erzeugt Soundeffekte und Musik (WAV, mono, 22,05 kHz) per Synthese, nur Standardbibliothek.

Alles ist selbst erzeugt (Rechteck-, Dreieck-, Sägezahn-Wellen und Rauschen), es gibt keine
fremden Audiodateien und damit keine Lizenzfragen.

Aufruf (aus dem Projektordner):  python3 tools/generate_audio.py
Schreibt nach assets/audio/sfx/ und assets/audio/music/. Die Musik ist als nahtlose Schleife
gebaut: Noten, die über das Ende hinausklingen, laufen am Anfang weiter.
"""
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RATE = 22050
TAU = math.tau


# --- Bausteine ---------------------------------------------------------------------

def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def wave_fn(kind, duty=0.5):
    if kind == 'sine':
        return lambda p: math.sin(TAU * p)
    if kind == 'square':
        return lambda p: 1.0 if (p % 1.0) < duty else -1.0
    if kind == 'tri':
        return lambda p: 4.0 * abs((p % 1.0) - 0.5) - 1.0
    if kind == 'saw':
        return lambda p: 2.0 * (p % 1.0) - 1.0
    raise ValueError(kind)


def env(t, length, attack=0.005, release=0.05, curve=1.0):
    """Hüllkurve: kurzer Anstieg, Abfall mit `curve` (1 = linear, >1 = schneller)."""
    if t < attack:
        return t / attack
    left = length - t
    if left < release:
        return max(left / release, 0.0)
    return max(1.0 - (t - attack) / max(length - attack, 1e-6), 0.0) ** curve if curve != 0 else 1.0


def tone(freq, length, kind='square', duty=0.5, vol=0.5, attack=0.005, release=0.04, curve=1.5,
         vibrato=0.0, glide_to=None):
    """Ein Ton als Liste von Samples. glide_to = Zielfrequenz am Ende (Tonhöhenverlauf)."""
    fn = wave_fn(kind, duty)
    n = int(length * RATE)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = freq if glide_to is None else freq + (glide_to - freq) * (i / n)
        if vibrato:
            f *= 1.0 + 0.006 * math.sin(TAU * vibrato * t)
        phase += f / RATE
        out.append(fn(phase) * env(t, length, attack, release, curve) * vol)
    return out


def noise(length, vol=0.5, rng=None, lowpass=1.0, curve=2.0, attack=0.002):
    """Rauschen mit einfachem Tiefpass (lowpass 1 = ungefiltert, kleiner = dumpfer)."""
    rng = rng or random.Random(1)
    n = int(length * RATE)
    out = []
    y = 0.0
    for i in range(n):
        y += (rng.uniform(-1, 1) - y) * lowpass
        out.append(y * env(i / RATE, length, attack, 0.01, curve) * vol)
    return out


def sweep_noise(length, start_lp, end_lp, vol=0.5, seed=1, curve=1.0, attack=0.02):
    """Rauschen, dessen Filter sich öffnet oder schließt (Wusch/Zischen)."""
    rng = random.Random(seed)
    n = int(length * RATE)
    out = []
    y = 0.0
    for i in range(n):
        a = start_lp + (end_lp - start_lp) * (i / n)
        y += (rng.uniform(-1, 1) - y) * a
        out.append(y * env(i / RATE, length, attack, 0.04, curve) * vol)
    return out


def kick(vol=0.9):
    n = int(0.16 * RATE)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        phase += (50 + 110 * math.exp(-t * 40)) / RATE
        out.append(math.sin(TAU * phase) * math.exp(-t * 22) * vol)
    return out


def snare(vol=0.5, seed=3):
    body = tone(190, 0.1, 'tri', vol=vol * 0.6, curve=3)
    hiss = noise(0.14, vol * 0.8, random.Random(seed), lowpass=0.8, curve=3)
    return mix_lists([body, hiss])


def hat(vol=0.18, seed=5):
    return noise(0.04, vol, random.Random(seed), lowpass=1.0, curve=3)


def mix_lists(lists):
    n = max(len(x) for x in lists)
    out = [0.0] * n
    for x in lists:
        for i, v in enumerate(x):
            out[i] += v
    return out


def concat(parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def silence(length):
    return [0.0] * int(length * RATE)


def place(buf, start, samples, wrap=False):
    """Mischt `samples` ab Zeitpunkt `start` (Sekunden) in `buf`. wrap = über das Ende hinaus
    am Anfang weiterspielen (für nahtlose Schleifen)."""
    base = int(start * RATE)
    size = len(buf)
    for i, v in enumerate(samples):
        j = base + i
        if j >= size:
            if not wrap:
                break
            j %= size
        buf[j] += v


def normalize(buf, peak=0.9):
    top = max((abs(v) for v in buf), default=1.0) or 1.0
    return [v / top * peak for v in buf]


def write_wav(path, buf):
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1.0, min(1.0, v)) * 32767)) for v in buf))


# --- Soundeffekte -----------------------------------------------------------------

def sfx_swing():
    return normalize(sweep_noise(0.2, 0.08, 0.7, seed=11, curve=1.5, attack=0.06), 0.8)


def sfx_hit():
    thump = tone(170, 0.12, 'sine', vol=0.8, curve=3, glide_to=60)
    crack = noise(0.08, 0.7, random.Random(2), lowpass=0.7, curve=3)
    return normalize(mix_lists([thump, crack]), 0.9)


def sfx_arrow():
    twang = tone(1100, 0.16, 'saw', vol=0.35, curve=2.5, glide_to=420)
    air = sweep_noise(0.14, 0.6, 0.15, vol=0.5, seed=4, curve=2, attack=0.005)
    return normalize(mix_lists([twang, air]), 0.8)


def sfx_fireball():
    whoosh = sweep_noise(0.5, 0.05, 0.5, vol=0.9, seed=7, curve=0.8, attack=0.12)
    roar = tone(110, 0.5, 'saw', vol=0.35, curve=1, attack=0.1, glide_to=220)
    crackle = noise(0.5, 0.2, random.Random(9), lowpass=1.0, curve=1)
    return normalize(mix_lists([whoosh, roar, crackle]), 0.85)


def sfx_heal():
    notes = [76, 80, 83, 88]
    parts = [tone(hz(m), 0.08, 'sine', vol=0.6, curve=0.8, release=0.02) for m in notes[:-1]]
    parts.append(tone(hz(notes[-1]), 0.3, 'sine', vol=0.6, curve=2))
    return normalize(concat(parts), 0.7)


def sfx_page():
    return normalize(sweep_noise(0.2, 0.6, 0.12, vol=0.8, seed=3, curve=1.3, attack=0.03), 0.6)


def sfx_explode():
    boom = tone(120, 0.35, 'sine', vol=0.9, curve=2.5, glide_to=35)
    burst = noise(0.3, 0.9, random.Random(5), lowpass=0.35, curve=2.5)
    return normalize(mix_lists([boom, burst]), 0.9)


def sfx_death():
    return normalize(tone(420, 0.35, 'square', duty=0.25, vol=0.5, curve=1.2, glide_to=70), 0.75)


def sfx_coin():
    return normalize(concat([tone(hz(83), 0.06, 'square', duty=0.25, vol=0.5, curve=0.5, release=0.01),
                             tone(hz(88), 0.2, 'square', duty=0.25, vol=0.5, curve=2)]), 0.7)


def sfx_buy():
    return normalize(concat([tone(hz(72), 0.06, 'square', vol=0.5, curve=0.5, release=0.01),
                             tone(hz(79), 0.1, 'square', vol=0.5, curve=2)]), 0.7)


def sfx_merge():
    notes = [72, 76, 79, 84, 88]
    parts = [tone(hz(m), 0.09, 'square', duty=0.25, vol=0.45, curve=0.6, release=0.02) for m in notes[:-1]]
    parts.append(mix_lists([tone(hz(88), 0.4, 'square', duty=0.25, vol=0.4, curve=2, vibrato=7),
                            tone(hz(76), 0.4, 'tri', vol=0.4, curve=2)]))
    return normalize(concat(parts), 0.85)


def sfx_click():
    return normalize(tone(hz(84), 0.04, 'square', duty=0.25, vol=0.5, curve=1, release=0.01), 0.55)


def sfx_error():
    return normalize(concat([tone(hz(52), 0.1, 'square', vol=0.5, curve=0.5, release=0.01),
                             tone(hz(48), 0.16, 'square', vol=0.5, curve=1.5)]), 0.7)


def sfx_battle_start():
    horn = mix_lists([tone(hz(57), 0.7, 'saw', vol=0.3, attack=0.08, curve=0.6),
                      tone(hz(64), 0.7, 'saw', vol=0.3, attack=0.08, curve=0.6)])
    drums = [0.0] * len(horn)
    place(drums, 0.0, kick())
    place(drums, 0.18, kick(0.7))
    return normalize(mix_lists([horn, drums]), 0.85)


def sfx_round_win():
    notes = [(67, 0.12), (72, 0.12), (76, 0.12), (79, 0.5)]
    parts = [tone(hz(m), d, 'square', duty=0.25, vol=0.45, curve=0.8, release=0.03) for m, d in notes]
    chord = mix_lists([tone(hz(m), 0.5, 'tri', vol=0.35, curve=1.5) for m in (60, 64, 67)])
    out = concat(parts)
    place(out, 0.36, chord)
    return normalize(out, 0.85)


def sfx_game_over():
    notes = [(69, 0.25), (65, 0.25), (62, 0.25), (57, 0.8)]
    parts = [tone(hz(m), d, 'tri', vol=0.6, curve=1, vibrato=5, release=0.05) for m, d in notes]
    return normalize(concat(parts), 0.85)


SFX = {
    'swing': sfx_swing, 'hit': sfx_hit, 'arrow': sfx_arrow, 'fireball': sfx_fireball,
    'heal': sfx_heal, 'page': sfx_page,
    'explode': sfx_explode, 'death': sfx_death, 'coin': sfx_coin, 'buy': sfx_buy,
    'merge': sfx_merge, 'click': sfx_click, 'error': sfx_error, 'battle_start': sfx_battle_start,
    'round_win': sfx_round_win, 'game_over': sfx_game_over,
}


# --- Musik --------------------------------------------------------------------------

CHORDS = {  # Akkordtöne (MIDI), Grundton für den Bass steht in ROOTS
    'Am': [57, 60, 64, 69], 'F': [53, 57, 60, 65], 'C': [55, 60, 64, 67], 'G': [55, 59, 62, 67],
    'Em': [52, 55, 59, 64], 'Dm': [50, 53, 57, 62], 'E': [52, 56, 59, 64],
}
ROOTS = {'Am': 45, 'F': 41, 'C': 48, 'G': 43, 'Em': 40, 'Dm': 38, 'E': 40}
A_MINOR = [57, 59, 60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79, 81]
PENTATONIC = [57, 60, 62, 64, 67, 69, 72, 74, 76, 79, 81]


def nearest(scale, target):
    return min(scale, key=lambda m: abs(m - target))


def melody_for_bar(rng, chord, prev, scale, steps, high=False):
    """Eine Taktmelodie: Liste (Startschritt, Dauer in Schritten, MIDI)."""
    rhythms = [[(0, 4), (4, 2), (6, 2)], [(0, 2), (2, 2), (4, 4)], [(0, 3), (3, 1), (4, 4)],
               [(0, 2), (2, 1), (3, 1), (4, 2), (6, 2)], [(0, 8)], [(0, 4), (4, 4)],
               [(0, 1), (1, 1), (2, 2), (4, 4)]]
    pattern = rng.choice(rhythms)
    notes = []
    current = prev
    for k, (start, dur) in enumerate(pattern):
        if k == 0 or rng.random() < 0.3:  # starke Zählzeit: Akkordton
            candidates = [m + 12 * o for m in chord for o in (0, 1) if 64 <= m + 12 * o <= (84 if high else 79)]
            current = min(candidates, key=lambda m: abs(m - current) + rng.random() * 3)
        else:  # sonst Schritt in der Tonleiter
            index = scale.index(nearest(scale, current)) + rng.choice([-2, -1, -1, 1, 1, 2])
            current = scale[max(0, min(len(scale) - 1, index))]
            current = max(62, min(84 if high else 79, current))
        notes.append((start, dur, current))
    return notes


def build_music():
    """Ruhige Bauphasen-Musik: 90 BPM, a-Moll, Arpeggio + Flötenmelodie + Bass + Pad."""
    bpm = 90
    step = 60.0 / bpm / 2  # Achtelnote
    bars = ['Am', 'F', 'C', 'G', 'Am', 'F', 'G', 'Em',
            'Am', 'F', 'C', 'G', 'F', 'C', 'Dm', 'E']
    length = len(bars) * 8 * step
    buf = [0.0] * int(length * RATE)
    rng = random.Random(21)
    prev = 69
    for b, name in enumerate(bars):
        t0 = b * 8 * step
        chord = CHORDS[name]
        # Bass: Grundton auf 1 und 3, Quinte auf 4+
        for pos, offset in ((0, 0), (4, 0), (6, 7)):
            place(buf, t0 + pos * step, tone(hz(ROOTS[name] + offset), step * (4 if pos == 0 else 2), 'tri',
                                             vol=0.5, attack=0.01, release=0.06, curve=1.2), wrap=True)
        # Pad
        pad = mix_lists([tone(hz(m - 12), 8 * step, 'sine', vol=0.13, attack=0.4, release=0.5, curve=0.3)
                         for m in chord[:3]])
        place(buf, t0, pad, wrap=True)
        # Arpeggio
        order = [0, 1, 2, 3, 2, 1, 2, 3]
        for i, idx in enumerate(order):
            place(buf, t0 + i * step, tone(hz(chord[idx] + 12), step * 1.6, 'square', duty=0.25, vol=0.11,
                                           attack=0.003, release=0.05, curve=2.5), wrap=True)
        # Melodie (zweite Hälfte höher)
        for start, dur, midi in melody_for_bar(rng, chord, prev, A_MINOR, 8, high=b >= 8):
            prev = midi
            note = mix_lists([tone(hz(midi), dur * step * 0.95, 'tri', vol=0.34, attack=0.03, release=0.08,
                                   curve=0.7, vibrato=5.5),
                              tone(hz(midi), dur * step * 0.95, 'square', duty=0.5, vol=0.05, attack=0.03,
                                   release=0.08, curve=0.7)])
            place(buf, t0 + start * step, note, wrap=True)
    return normalize(buf, 0.85)


def build_battle():
    """Treibende Kampfmusik: 140 BPM, a-Moll, Schlagzeug, Bass, schnelles Arpeggio und Riff."""
    bpm = 140
    step = 60.0 / bpm / 4  # Sechzehntel
    bars = ['Am', 'Am', 'F', 'G', 'Am', 'Am', 'F', 'E',
            'Dm', 'Dm', 'Am', 'Am', 'F', 'G', 'Am', 'E']
    length = len(bars) * 16 * step
    buf = [0.0] * int(length * RATE)
    rng = random.Random(8)
    riffs = [
        [(0, 2, 0), (3, 1, 2), (4, 2, 3), (7, 1, 2), (8, 2, 0), (11, 1, 2), (12, 4, 4)],
        [(0, 1, 4), (2, 2, 3), (4, 2, 2), (6, 2, 3), (8, 4, 4), (12, 2, 3), (14, 2, 2)],
        [(0, 3, 3), (3, 1, 2), (4, 4, 0), (8, 2, 2), (10, 2, 3), (12, 4, 4)],
    ]
    for b, name in enumerate(bars):
        t0 = b * 16 * step
        chord = CHORDS[name]
        root = ROOTS[name]
        for i in range(16):
            t = t0 + i * step
            if i in (0, 8) or (i == 10 and b % 2 == 1):
                place(buf, t, kick(), wrap=True)
            if i in (4, 12):
                place(buf, t, snare(0.5, rng.randint(1, 99)), wrap=True)
            if i % 2 == 0:
                place(buf, t, hat(0.16 if i % 4 else 0.22, rng.randint(1, 99)), wrap=True)
            if i % 2 == 0:  # Achtel-Bass, Oktavsprung auf der Synkope
                midi = root + (12 if i in (6, 14) else 0)
                place(buf, t, tone(hz(midi), step * 1.8, 'square', duty=0.5, vol=0.3, attack=0.004,
                                   release=0.03, curve=1.6), wrap=True)
            place(buf, t, tone(hz(chord[(i * 3) % 4] + 12), step * 1.2, 'square', duty=0.125, vol=0.07,
                               attack=0.002, release=0.02, curve=2), wrap=True)
        # Riff auf Akkordtönen (zweite Hälfte eine Oktave höher)
        octave = 12 if b >= 8 else 0
        for start, dur, idx in rng.choice(riffs):
            midi = chord[idx % 4] + 12 + octave
            place(buf, t0 + start * step, tone(hz(midi), dur * step * 0.9, 'square', duty=0.25, vol=0.22,
                                               attack=0.004, release=0.04, curve=1.0, vibrato=6), wrap=True)
    return normalize(buf, 0.85)


MUSIC = {'build': build_music, 'battle': build_battle}


def main():
    for name, make in SFX.items():
        write_wav(ROOT / 'assets/audio/sfx' / f'{name}.wav', make())
    for name, make in MUSIC.items():
        write_wav(ROOT / 'assets/audio/music' / f'{name}.wav', make())
    print(f'{len(SFX)} Soundeffekte und {len(MUSIC)} Musikstücke geschrieben.')


if __name__ == '__main__':
    main()
