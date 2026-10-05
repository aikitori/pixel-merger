"""Alternative Sprite-Stile (Entwurf): wandeln fertige Sprites pixelgenau um.

Jede Funktion bekommt ein Raster aus RGBA-Tupeln (r, g, b, a mit 0..255) in Kunst-Pixeln und gibt ein
Raster gleicher Größe zurück. Aufruf über generate_sprites.py --style <name>.
"""
import colorsys

OUTLINE = (0x24, 0x12, 0x3a)  # Umrissfarbe der Basis-Sprites


def _luma(c):
    return (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255.0


def _hsv(c):
    return colorsys.rgb_to_hsv(c[0] / 255.0, c[1] / 255.0, c[2] / 255.0)


def _rgb(h, s, v, a=255):
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, max(0.0, min(1.0, s)), max(0.0, min(1.0, v)))
    return (round(r * 255), round(g * 255), round(b * 255), a)


def _mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (a[3] if len(a) > 3 else 255,)


def _solid(p):
    return p[3] > 128


def _at(g, x, y):
    if 0 <= y < len(g) and 0 <= x < len(g[0]):
        return g[y][x]
    return (0, 0, 0, 0)


def _is_outline(p):
    return _solid(p) and p[:3] == OUTLINE


def _fill_neighbor(g, x, y):
    """Mittlere Farbe der Füllpixel (nicht Umriss) in der Nachbarschaft, sonst None."""
    sel = [_at(g, x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1))]
    sel = [p for p in sel if _solid(p) and not _is_outline(p)]
    if not sel:
        return None
    return tuple(round(sum(p[i] for p in sel) / len(sel)) for i in range(3)) + (255,)


def _edge(g, x, y):
    return any(not _solid(_at(g, x + dx, y + dy)) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))


def _map(g, fn):
    return [[fn(g, x, y, p) if p[3] else p for x, p in enumerate(row)] for y, row in enumerate(g)]


BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


# 1 Taschenkonsole: vier Grüntöne, geordnetes Dithering, Umriss = dunkelster Ton
def handheld(g):
    pal = [(0x0f, 0x38, 0x0f), (0x30, 0x62, 0x30), (0x8b, 0xac, 0x0f), (0x9b, 0xbc, 0x0f)]

    def f(g, x, y, p):
        if _is_outline(p):
            return pal[0] + (255,)
        lv = max(0.0, min(1.0, (_luma(p) - 0.08) * 1.25))
        q = int(max(0, min(3, lv * 3 + (BAYER[y % 4][x % 4] + 0.5) / 16 * 0.5 - 0.25 + 0.5)))
        return pal[q] + (p[3],)
    return _map(g, f)


# 2 Tusche & Pergament: verwaschene Farbe, braune Tusche, Schraffur in den Schatten
def ink(g):
    ink_c = (0x2a, 0x1d, 0x14)

    def f(g, x, y, p):
        if _is_outline(p):
            return ink_c + (255,)
        l = _luma(p)
        lq = round(l * 4) / 4
        wash = tuple(0.3 * p[i] + 0.7 * lq * 255 for i in range(3))
        o = (min(255, wash[0] * 1.02 + 20), min(255, wash[1] * 0.95 + 14), min(255, wash[2] * 0.78 + 4), 255)
        o = tuple(round(v) for v in o)
        if l < 0.40 and (x + y) % 3 == 0:
            o = _mix(o, ink_c + (255,), 0.75)
        if l < 0.22 and (x - y) % 3 == 0:
            o = _mix(o, ink_c + (255,), 0.85)
        return o[:3] + (p[3],)
    return _map(g, f)


# 3 Neon: Umriss und Detailkanten leuchten in der Farbe der Figur, Füllung fast schwarz, Schein ringsum
def neon(g):
    h, w = len(g), len(g[0])

    def neon_of(c, v=1.0):
        hh, ss, _ = _hsv(c)
        return _rgb(hh, max(ss, 0.8), v)

    def f(g, x, y, p):
        if _is_outline(p):
            n = _fill_neighbor(g, x, y)
            return neon_of(n if n else (255, 60, 240, 255)) if n else (255, 61, 240, 255)
        l = _luma(p)
        detail = max(abs(l - _luma(q)) for q in (_at(g, x + 1, y), _at(g, x - 1, y), _at(g, x, y + 1), _at(g, x, y - 1)) if _solid(q)) \
            if any(_solid(q) for q in (_at(g, x + 1, y), _at(g, x - 1, y), _at(g, x, y + 1), _at(g, x, y - 1))) else 0
        if _edge(g, x, y) or detail > 0.28:
            return neon_of(p, 0.95)
        hh, ss, _ = _hsv(p)
        return _rgb(hh, 0.9, 0.10 + 0.22 * l, p[3])
    out = _map(g, f)
    # Schein: durchsichtige Pixel neben einer leuchtenden Kante
    for y in range(h):
        for x in range(w):
            if g[y][x][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    q = _at(out, x + dx, y + dy)
                    if _solid(q) and _edge(g, x + dx, y + dy):
                        out[y][x] = q[:3] + (70,)
                        break
    return out


# 4 Zuckerwatte: helle, weiche Farben, flache Töne, farbiger Umriss, weißer Glanzpunkt
def pastel(g):
    def f(g, x, y, p):
        if _is_outline(p):
            n = _fill_neighbor(g, x, y)
            if n is None:
                return (0x7a, 0x5a, 0x8e, 255)
            hh, ss, vv = _hsv(n)
            return _rgb(hh + 0.04, 0.45, 0.50, 255)
        hh, ss, vv = _hsv(p)
        if 0.2 < hh < 0.45:
            hh += 0.07
        vv = round(vv * 3) / 3
        o = _rgb(hh, ss * 0.55, 0.62 + 0.38 * vv)
        up, left = _at(g, x, y - 1), _at(g, x - 1, y)
        if _luma(p) > 0.55 and (_is_outline(up) or not _solid(up)) and (_is_outline(left) or not _solid(left)):
            return (255, 255, 255, 255)
        return o[:3] + (p[3],)
    return _map(g, f)


# 5 Düsterwald: fast farblos, nur Rot bleibt, kaltes Streiflicht an Licht-Kanten, Nebel nach unten
def gothic(g):
    h = len(g)

    def f(g, x, y, p):
        if _is_outline(p):
            return (8, 8, 10, 255)
        hh, ss, vv = _hsv(p)
        l = _luma(p)
        red = (hh < 0.04 or hh > 0.93) and ss > 0.45 and vv > 0.3
        o = [l * 0.82, l * 0.92, l * 1.06]
        if red:
            o = [0.8 * (0.5 + vv * 0.6), 0.08, 0.06]
        o = [max(0.0, min(1.0, v)) ** 1.6 * 1.15 for v in o]
        fog = 1.0 - 0.35 * (y / max(1, h - 1))
        o = [v * fog for v in o]
        if _is_outline(_at(g, x, y - 1)) or _is_outline(_at(g, x - 1, y)) or not _solid(_at(g, x, y - 1)):
            o = [o[0] * 0.8 + 0.10, o[1] * 0.85 + 0.14, o[2] * 0.9 + 0.20]
        return tuple(round(max(0.0, min(1.0, v)) * 255) for v in o) + (p[3],)
    return _map(g, f)


# 6 Höllenshooter (wie Ego-Shooter der frühen 90er): keine schwarze Umrisslinie, Figuren wirken plastisch
# (hell in der Mitte, dunkel zum Rand, Licht von oben links), Originalfarben leicht warm, Körnung.
def doom(g):
    h, w = len(g), len(g[0])
    # Abstand zum Rand der Figur (Volumen), Umriss gilt als Rand; Reichweite wächst mit der Figur
    reach = max(3, min(h, w) // 5)
    inf = 99
    dist = [[0 if not _solid(g[y][x]) or _is_outline(g[y][x]) else inf for x in range(w)] for y in range(h)]
    for _ in range(reach):
        for y in range(h):
            for x in range(w):
                if dist[y][x]:
                    n = min(dist[y + dy][x + dx] if 0 <= y + dy < h and 0 <= x + dx < w else 0
                            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                    dist[y][x] = min(dist[y][x], n + 1)
    d = lambda x, y: min(dist[y][x], reach) if 0 <= y < h and 0 <= x < w else 0
    out = []
    for y in range(h):
        row = []
        for x in range(w):
            p = g[y][x]
            if not p[3]:
                row.append(p)
                continue
            if _is_outline(p):
                n = _fill_neighbor(g, x, y)
                row.append(tuple(round(v * 0.28) for v in (n[:3] if n else (90, 60, 40))) + (255,))
                continue
            vol = d(x, y) / reach                                   # 0 am Rand, 1 innen
            # Fläche zeigt nach oben links, wenn der Rand dort näher ist: dann heller
            facing = (d(x + 1, y + 1) - d(x - 1, y - 1)) / reach
            grain = (((x * 73856093) ^ (y * 19349663)) % 1000 / 1000.0 - 0.5) * 0.10
            shade = 0.62 + 0.28 * vol ** 0.7 + 0.30 * facing + grain
            # Originalfarbe, leicht entsättigt und warm, nur heller oder dunkler schattiert
            l = _luma(p) * 255
            base = [p[i] * 0.85 + l * 0.15 for i in range(3)]
            warm = (1.04, 0.98, 0.90)
            row.append(tuple(max(0, min(255, round(base[i] * warm[i] * shade))) for i in range(3)) + (p[3],))
        out.append(row)
    return out


STYLES = {'handheld': handheld, 'ink': ink, 'neon': neon, 'pastel': pastel, 'gothic': gothic, 'doom': doom}


# ---- Formen: wirken auf das Zeichen-Raster (vor der Färbung) und ändern die Proportionen ----

def _bands(grid, bands):
    """Setzt das Raster aus waagerechten Bändern neu zusammen.

    bands = [(Anteil der Quellhöhe, Zielhöhe-Faktor, Breiten-Faktor)], Nachbarwert-Abtastung.
    Die Breite jedes Bandes wird um die Mitte skaliert, das Ergebnis auf die breiteste Zeile gepolstert.
    """
    h, w = len(grid), len(grid[0])
    total = sum(b[0] for b in bands)
    rows, y0 = [], 0.0
    for share, hf, wf in bands:
        y1 = y0 + share / total * h
        src_h = y1 - y0
        out_h = max(1, round(src_h * hf))
        out_w = max(1, round(w * wf))
        for j in range(out_h):
            sy = min(h - 1, int(y0 + (j + 0.5) / out_h * src_h))
            src = grid[sy]
            rows.append([src[min(w - 1, int((i + 0.5) / out_w * w))] for i in range(out_w)])
        y0 = y1
    width = max(len(r) for r in rows)
    return [['.'] * ((width - len(r)) // 2) + r + ['.'] * (width - len(r) - (width - len(r)) // 2) for r in rows]


def _trim(grid):
    ys = [y for y, r in enumerate(grid) if any(c != '.' for c in r)]
    xs = [x for r in grid for x, c in enumerate(r) if c != '.']
    if not ys:
        return grid
    return [r[min(xs):max(xs) + 1] for r in grid[ys[0]:ys[-1] + 1]]


GLOW_CHARS = set('0123456789a')


def _coarse(grid, f):
    """Rechnet auf ein f-mal gröberes Raster herunter; Umriss gewinnt bei Gleichstand, Leuchtzeichen nie."""
    g = _trim(grid)
    h, w = len(g), len(g[0])
    out = []
    for y in range(0, h, f):
        row = []
        for x in range(0, w, f):
            block = [g[j][i] for j in range(y, min(y + f, h)) for i in range(x, min(x + f, w)) if g[j][i] != '.']
            if len(block) * 2 < f * f:
                row.append('.')
                continue
            row.append(max(set(block), key=lambda c: (block.count(c) + (0.5 if c == 'k' else 0), c)))
        out.append(row)
    return out


def _clean(grid):
    """Einzelne Streupixel entfernen, dann um die Figur einen sauberen 1-Pixel-Umriss legen."""
    h, w = len(grid), len(grid[0])
    g = [['.'] * (w + 2)] + [['.'] + list(r) + ['.'] for r in grid] + [['.'] * (w + 2)]
    for y in range(1, h + 1):
        for x in range(1, w + 1):
            if g[y][x] != '.' and not any(g[y + dy][x + dx] != '.' for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                g[y][x] = '.'
    solid = lambda c: c != '.' and c not in GLOW_CHARS
    out = [r[:] for r in g]
    for y in range(h + 2):
        for x in range(w + 2):
            if g[y][x] == '.' and any(0 <= y + dy < h + 2 and 0 <= x + dx < w + 2 and solid(g[y + dy][x + dx])
                                      and g[y + dy][x + dx] != 'k' for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out[y][x] = 'k'
    return out


def _epx(grid):
    """Scale2x: doppelte Auflösung, Diagonalen werden glatter statt treppenförmig."""
    h, w = len(grid), len(grid[0])
    at = lambda x, y: grid[y][x] if 0 <= x < w and 0 <= y < h else '.'
    out = []
    for y in range(h):
        top, bottom = [], []
        for x in range(w):
            p, a, b, c, d = grid[y][x], at(x, y - 1), at(x + 1, y), at(x - 1, y), at(x, y + 1)
            t1 = a if c == a and c != d and a != b else p
            t2 = b if a == b and a != c and b != d else p
            b1 = c if d == c and d != b and c != a else p
            b2 = d if b == d and b != a and d != c else p
            top += [t1, t2]
            bottom += [b1, b2]
        out += [top, bottom]
    return out


def _shape(grid, factor, bands, hires=False):
    """Optional gröberes Raster oder Scale2x, neue Proportionen (siehe _bands), sauberer Umriss."""
    g = _coarse(grid, factor) if factor > 1 else _trim(grid)
    if hires:
        g = _epx(g)
    if bands:
        g = _bands(g, bands)
    return _clean(g)


# Endgültige Vergrößerung beim Speichern: Taschenkonsole grob (2), die anderen auf Scale2x-Raster fein (1)
SCALE = {'handheld': 2, 'ink': 1, 'neon': 1, 'pastel': 1, 'gothic': 1, 'doom': 1}


def lowres(grid):
    """Taschenkonsole: gedrungene Figuren mit großem Kopf, grobes Raster (Originalauflösung)."""
    return _shape(grid, 1, [(0.42, 1.0, 1.15), (0.58, 0.85, 1.1)])


def slender(grid):
    """Tusche: hochgewachsene Figuren, kleiner Kopf, lange Beine."""
    return _shape(grid, 1, [(0.28, 0.9, 0.85), (0.32, 1.2, 0.8), (0.40, 1.5, 0.8)], hires=True)


def chibi(grid):
    """Zuckerwatte: Kopf fast so groß wie der Körper, Stummelbeine."""
    return _shape(grid, 1, [(0.42, 1.3, 1.4), (0.40, 0.8, 0.9), (0.18, 0.7, 0.9)], hires=True)


def runner(grid):
    """Neon: kleiner Kopf, schmale Taille, sehr lange Beine."""
    return _shape(grid, 1, [(0.28, 0.85, 0.9), (0.27, 0.9, 1.1), (0.45, 1.7, 0.75)], hires=True)


def hulk(grid):
    """Düsterwald: breite Schultern und Brust, schmale Hüfte."""
    return _shape(grid, 1, [(0.22, 0.9, 1.0), (0.43, 1.2, 1.4), (0.35, 1.0, 0.85)], hires=True)


def brute(grid):
    """Höllenshooter: feines Raster, wuchtige Figuren, Pixel leicht hochgezogen wie bei 320x200."""
    return _shape(grid, 1, [(0.25, 1.15, 1.05), (0.40, 1.25, 1.25), (0.35, 1.2, 1.0)], hires=True)


SHAPES = {'handheld': lowres, 'ink': slender, 'neon': runner, 'pastel': chibi, 'gothic': hulk, 'doom': brute}
