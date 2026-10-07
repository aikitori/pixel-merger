"""Kleine RGBA-Bildbibliothek für die Sprite-Generatoren (nur Standardbibliothek).

Liest und schreibt PNG (8 Bit RGBA, ohne Interlacing, wie sie tools/import_dcss.py ablegt) und bietet
die Bausteine zum Zusammensetzen: übereinanderlegen, spiegeln, einfärben, Umriss, Leuchten, Schatten.
Ein Bild ist ein Img mit Breite, Höhe und einer flachen Liste von (r, g, b, a)-Tupeln.
"""
import colorsys
import struct
import zlib
from pathlib import Path


class Img:
    def __init__(self, w, h, px=None):
        self.w, self.h = w, h
        self.px = px if px is not None else [(0, 0, 0, 0)] * (w * h)

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y * self.w + x]
        return (0, 0, 0, 0)

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y * self.w + x] = c

    def copy(self):
        return Img(self.w, self.h, list(self.px))


def hex_color(value):
    value = value.lstrip('#')
    rgb = tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))
    return rgb + ((int(value[6:8], 16),) if len(value) == 8 else (255,))


# --- PNG -----------------------------------------------------------------------------

def read_png(path):
    data = Path(path).read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', path
    pos, idat, w = 8, b'', 0
    while pos < len(data):
        length, tag = struct.unpack('>I4s', data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        if tag == b'IHDR':
            w, h, depth, ctype, _, _, interlace = struct.unpack('>IIBBBBB', body)
            assert depth == 8 and ctype == 6 and interlace == 0, f'{path}: nur RGBA8 ohne Interlacing'
        elif tag == b'IDAT':
            idat += body
        pos += 12 + length
    raw = zlib.decompress(idat)
    stride = w * 4
    rows, prev, i = [], bytearray(stride), 0
    for _ in range(h):
        kind = raw[i]
        line = bytearray(raw[i + 1:i + 1 + stride])
        i += 1 + stride
        for x in range(stride):
            a = line[x - 4] if x >= 4 else 0
            b = prev[x]
            c = prev[x - 4] if x >= 4 else 0
            if kind == 1:
                line[x] = (line[x] + a) & 255
            elif kind == 2:
                line[x] = (line[x] + b) & 255
            elif kind == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif kind == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(line)
        prev = line
    px = [tuple(row[x:x + 4]) for row in rows for x in range(0, stride, 4)]
    return Img(w, h, px)


def write_png(path, img):
    raw = bytearray()
    for y in range(img.h):
        raw.append(0)
        for x in range(img.w):
            raw.extend(img.px[y * img.w + x])

    def chunk(tag, body):
        return struct.pack('>I', len(body)) + tag + body + struct.pack('>I', zlib.crc32(tag + body) & 0xffffffff)

    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', img.w, img.h, 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b'')
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


# --- Zusammensetzen ------------------------------------------------------------------

def over(dst, src):
    """src über dst (Alpha-Mischung)."""
    sa = src[3] / 255.0
    if sa >= 1.0 or dst[3] == 0:
        return src if sa > 0 else dst
    if sa <= 0.0:
        return dst
    da = dst[3] / 255.0
    oa = sa + da * (1 - sa)
    return tuple(round((src[i] * sa + dst[i] * da * (1 - sa)) / oa) for i in range(3)) + (round(oa * 255),)


def paste(dst, src, x0=0, y0=0):
    for y in range(src.h):
        for x in range(src.w):
            c = src.px[y * src.w + x]
            if c[3]:
                dst.set(x0 + x, y0 + y, over(dst.get(x0 + x, y0 + y), c))
    return dst


def layered(*imgs):
    """Legt gleich große Bilder übereinander (Puppenteile)."""
    out = imgs[0].copy()
    for img in imgs[1:]:
        paste(out, img)
    return out


def pad(img, left=0, top=0, right=0, bottom=0):
    out = Img(img.w + left + right, img.h + top + bottom)
    return paste(out, img, left, top)


def flip(img):
    return Img(img.w, img.h, [img.px[y * img.w + img.w - 1 - x] for y in range(img.h) for x in range(img.w)])


def crop(img, x0, y0, w, h):
    out = Img(w, h)
    for y in range(h):
        for x in range(w):
            out.px[y * w + x] = img.get(x0 + x, y0 + y)
    return out


def bbox(img):
    xs = [i % img.w for i, c in enumerate(img.px) if c[3]]
    ys = [i // img.w for i, c in enumerate(img.px) if c[3]]
    if not xs:
        return 0, 0, 1, 1
    return min(xs), min(ys), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1


def trim(img):
    return crop(img, *bbox(img))


def scale(img, factor):
    out = Img(img.w * factor, img.h * factor)
    for y in range(out.h):
        for x in range(out.w):
            out.px[y * out.w + x] = img.px[(y // factor) * img.w + x // factor]
    return out


def erase(img, keep):
    """Löscht Pixel, für die keep(x, y) falsch ist."""
    out = img.copy()
    for y in range(img.h):
        for x in range(img.w):
            if not keep(x, y):
                out.px[y * img.w + x] = (0, 0, 0, 0)
    return out


# --- Farbe ---------------------------------------------------------------------------

def map_pixels(img, fn):
    return Img(img.w, img.h, [fn(c) if c[3] else c for c in img.px])


def recolor(img, color, strength=1.0, min_saturation=0.0, skip_dark=0.0):
    """Färbt in Richtung `color` (Farbton), Helligkeit bleibt. Sehr dunkle Pixel (Umriss) bleiben."""
    target_h, target_s, _ = colorsys.rgb_to_hsv(*(v / 255 for v in hex_color(color)[:3]))

    def fn(c):
        h, s, v = colorsys.rgb_to_hsv(*(x / 255 for x in c[:3]))
        if v < skip_dark:
            return c
        s2 = max(s, min_saturation * target_s)
        r, g, b = colorsys.hsv_to_rgb(target_h, s2, v)
        mixed = [round(c[i] * (1 - strength) + (r, g, b)[i] * 255 * strength) for i in range(3)]
        return tuple(mixed) + (c[3],)
    return map_pixels(img, fn)


def hue_shift(img, degrees, saturation=1.0, value=1.0):
    def fn(c):
        h, s, v = colorsys.rgb_to_hsv(*(x / 255 for x in c[:3]))
        r, g, b = colorsys.hsv_to_rgb((h + degrees / 360.0) % 1.0, min(1.0, s * saturation), min(1.0, v * value))
        return (round(r * 255), round(g * 255), round(b * 255), c[3])
    return map_pixels(img, fn)


def adjust(img, brightness=1.0, saturation=1.0):
    return hue_shift(img, 0, saturation, brightness)


def outline(img, color, alpha=255, thickness=1):
    """Farbiger Rand um die Figur (außen)."""
    out = pad(img, thickness, thickness, thickness, thickness)
    rgb = hex_color(color)[:3]
    for step in range(thickness):
        base = out.copy()
        a = round(alpha * (1.0 - step / max(thickness, 1) * 0.55))
        for y in range(out.h):
            for x in range(out.w):
                if base.get(x, y)[3]:
                    continue
                if any(base.get(x + dx, y + dy)[3] > 40 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    out.set(x, y, rgb + (a,))
    return out


def shadow(img, alpha=110):
    """Dunkle Ellipse unter den Füßen (wie bei den Dungeon-Crawl-Monstern)."""
    x0, y0, w, h = bbox(img)
    out = pad(img, 0, 0, 0, 2)
    cx, cy = x0 + w / 2.0, y0 + h - 0.5
    rx, ry = max(4.0, w * 0.42), 2.2
    shade = Img(out.w, out.h)
    for y in range(out.h):
        for x in range(out.w):
            d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
            if d <= 1.0:
                shade.set(x, y, (0, 0, 0, alpha))
    return paste(shade, out)
