# Texture dipinte del terreno per il client Godot: 8 materiali ripetibili in un solo atlante (4 x 2 riquadri da 512 px),
# colore in RGB e altezza nel canale alfa (serve per le transizioni «a incastro» e per il rilievo).
#   python3 tools/godot/texture_terreno.py            → godot/texture/terreno.png e godot/texture/variazione.png
# Tutto è generato da codice (numpy): nessuna immagine presa altrove. Ordine dei riquadri:
#   0 prato, 1 secco, 2 bosco, 3 sabbia, 4 terra, 5 roccia, 6 neve, 7 lastricato
import os, sys
import numpy as np
from PIL import Image

N = 512
rng = np.random.default_rng(7)


def rumore(celle, seme=None, liscio=True):
    """Rumore ripetibile: griglia casuale di `celle` x `celle` interpolata fino a N x N (avvolge ai bordi)."""
    r = np.random.default_rng(seme) if seme is not None else rng
    g = r.random((celle, celle))
    x = np.arange(N) * celle / N
    i0 = np.floor(x).astype(int)
    f = x - i0
    if liscio:
        f = f * f * (3 - 2 * f)
    i1 = (i0 + 1) % celle
    a = g[i0][:, i0] * (1 - f)[None, :] + g[i0][:, i1] * f[None, :]
    b = g[i1][:, i0] * (1 - f)[None, :] + g[i1][:, i1] * f[None, :]
    return a * (1 - f)[:, None] + b * f[:, None]


def frattale(base, ottave=4, seme=0):
    tot, amp, somma = np.zeros((N, N)), 1.0, 0.0
    for o in range(ottave):
        tot += rumore(base * 2 ** o, seme * 31 + o) * amp
        somma += amp
        amp *= 0.5
    return tot / somma


def pennellate(base_x, base_y, seme):
    """Tratti allungati: rumore con più celle in una direzione che nell'altra, poi contrasto."""
    r = np.random.default_rng(seme)
    g = r.random((base_y, base_x))
    yy, xx = np.arange(N) * base_y / N, np.arange(N) * base_x / N
    y0, x0 = np.floor(yy).astype(int), np.floor(xx).astype(int)
    fy, fx = yy - y0, xx - x0
    fy, fx = fy * fy * (3 - 2 * fy), fx * fx * (3 - 2 * fx)
    y1, x1 = (y0 + 1) % base_y, (x0 + 1) % base_x
    a = g[y0][:, x0] * (1 - fx) + g[y0][:, x1] * fx
    b = g[y1][:, x0] * (1 - fx) + g[y1][:, x1] * fx
    return a * (1 - fy)[:, None] + b * fy[:, None]


def scalino(v, a, b):
    t = np.clip((v - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def mescola(c1, c2, t):
    return np.asarray(c1)[None, None, :] * (1 - t[..., None]) + np.asarray(c2)[None, None, :] * t[..., None]


def celle_voronoi(quante, seme):
    """Distanze ripetibili dai due semi più vicini e identificativo della cella (per ciottoli e lastre)."""
    r = np.random.default_rng(seme)
    lato = int(np.sqrt(quante))
    pts = []
    for j in range(lato):
        for i in range(lato):
            pts.append(((i + 0.15 + 0.7 * r.random()) / lato, (j + 0.15 + 0.7 * r.random()) / lato, r.random()))
    y, x = np.mgrid[0:N, 0:N] / N
    d1 = np.full((N, N), 9.0); d2 = np.full((N, N), 9.0); ident = np.zeros((N, N))
    for px, py, pid in pts:
        dx = np.abs(x - px); dx = np.minimum(dx, 1 - dx)
        dy = np.abs(y - py); dy = np.minimum(dy, 1 - dy)
        d = np.sqrt(dx * dx + dy * dy)
        piu = d < d1
        d2 = np.where(piu, d1, np.minimum(d2, d))
        ident = np.where(piu, pid, ident)
        d1 = np.where(piu, d, d1)
    return d1 * lato, (d2 - d1) * lato, ident


def macchie(quante, raggio, seme):
    """Piccole macchie rotonde sparse (fiori, sassolini, foglie): maschera 0..1 e un numero per macchia."""
    r = np.random.default_rng(seme)
    y, x = np.mgrid[0:N, 0:N] / N
    m = np.zeros((N, N)); ident = np.zeros((N, N))
    for _ in range(quante):
        px, py, rr, pid = r.random(), r.random(), raggio * (0.6 + 0.8 * r.random()), r.random()
        dx = np.abs(x - px); dx = np.minimum(dx, 1 - dx)
        dy = np.abs(y - py); dy = np.minimum(dy, 1 - dy)
        t = 1 - scalino(np.sqrt(dx * dx + dy * dy), rr * 0.6, rr)
        ident = np.where(t > m, pid, ident)
        m = np.maximum(m, t)
    return m, ident


def erba(scuro, medio, chiaro, seme, fiori=True):
    grande, fine = frattale(3, 4, seme), frattale(24, 3, seme + 1)
    ciuffi = pennellate(96, 28, seme + 2) * 0.6 + pennellate(180, 48, seme + 3) * 0.4       # fili verticali
    ciuffi2 = pennellate(28, 96, seme + 4)
    t = scalino(grande, 0.3, 0.7)
    col = mescola(scuro, medio, t)
    col = mescola3(col, chiaro, scalino(ciuffi, 0.52, 0.8) * 0.75)
    col = mescola3(col, np.asarray(scuro) * 0.7, scalino(ciuffi2, 0.6, 0.85) * 0.5)
    col *= (0.86 + 0.28 * fine)[..., None]
    alt = 0.35 + 0.4 * ciuffi + 0.15 * fine
    if fiori:
        m, ident = macchie(26, 0.012, seme + 9)
        petalo = np.where((ident > 0.66)[..., None], np.array([0.96, 0.93, 0.86]), np.where((ident > 0.33)[..., None], np.array([0.96, 0.8, 0.3]), np.array([0.82, 0.55, 0.78])))
        col = col * (1 - m[..., None]) + petalo * m[..., None]
        alt = np.maximum(alt, m * 0.9)
    return col, alt


def mescola3(col, c2, t):
    return col * (1 - t[..., None]) + np.asarray(c2)[None, None, :] * t[..., None]


def fai():
    out = []
    # 0 prato
    out.append(erba((0.12, 0.22, 0.07), (0.21, 0.32, 0.1), (0.36, 0.44, 0.16), 10))
    # 1 secco: erba gialla con terra che affiora
    c, a = erba((0.42, 0.37, 0.15), (0.6, 0.53, 0.24), (0.76, 0.68, 0.34), 20, fiori=False)
    nudo = scalino(frattale(5, 4, 21), 0.55, 0.75)
    c = mescola3(c, (0.47, 0.38, 0.24), nudo * 0.7); a = a * (1 - nudo * 0.5)
    out.append((c, a))
    # 2 bosco: sottobosco scuro con foglie cadute
    c, a = erba((0.07, 0.15, 0.06), (0.13, 0.23, 0.08), (0.22, 0.31, 0.12), 30, fiori=False)
    m, ident = macchie(90, 0.016, 31)
    foglia = np.where((ident > 0.5)[..., None], np.array([0.45, 0.3, 0.12]), np.array([0.32, 0.22, 0.1]))
    c = c * (1 - m[..., None] * 0.85) + foglia * m[..., None] * 0.85
    out.append((c, np.maximum(a, m * 0.7)))
    # 3 sabbia: onde del vento e granelli
    onde = np.sin((np.mgrid[0:N, 0:N][0] / N * 14 + frattale(3, 3, 40) * 2.2) * 2 * np.pi) * 0.5 + 0.5
    grana = frattale(64, 2, 41)
    c = mescola((0.62, 0.53, 0.34), (0.86, 0.77, 0.55), onde * 0.6 + frattale(4, 3, 42) * 0.4)
    c *= (0.92 + 0.16 * grana)[..., None]
    m, _ = macchie(40, 0.006, 43)
    c = mescola3(c, (0.4, 0.36, 0.3), m * 0.8)
    out.append((c, 0.3 + 0.35 * onde + 0.1 * grana + m * 0.3))
    # 4 terra battuta: sentieri con sassolini e solchi
    grande = frattale(4, 4, 50); solchi = pennellate(20, 90, 51)
    c = mescola((0.3, 0.22, 0.14), (0.52, 0.4, 0.26), grande * 0.6 + solchi * 0.4)
    c *= (0.88 + 0.24 * frattale(40, 2, 52))[..., None]
    sasso, ident = macchie(70, 0.009, 53)
    c = mescola3(c, (0.5, 0.47, 0.41), sasso * (0.5 + 0.4 * ident))
    crepe = 1 - scalino(celle_voronoi(64, 54)[1], 0.0, 0.05)
    c = mescola3(c, (0.2, 0.15, 0.1), crepe * 0.35)
    out.append((c, 0.3 + 0.25 * solchi + sasso * 0.5))
    # 5 roccia: strati, crepe e licheni
    strati = pennellate(6, 40, 60) * 0.6 + frattale(8, 4, 61) * 0.4
    d1, bordo, ident = celle_voronoi(36, 62)
    crepa = 1 - scalino(bordo, 0.0, 0.07)
    c = mescola((0.24, 0.23, 0.22), (0.52, 0.5, 0.45), strati)
    c *= (0.85 + 0.2 * ident)[..., None]
    c = mescola3(c, (0.12, 0.11, 0.11), crepa * 0.85)
    lichene = scalino(frattale(10, 3, 63), 0.62, 0.78)
    c = mescola3(c, (0.36, 0.42, 0.24), lichene * 0.45)
    out.append((c, 0.25 + 0.6 * strati * (1 - crepa)))
    # 6 neve: cumuli morbidi con ombre azzurre e scintillii
    cumuli = frattale(4, 4, 70)
    c = mescola((0.74, 0.8, 0.9), (0.97, 0.98, 1.0), scalino(cumuli, 0.25, 0.7))
    m, _ = macchie(60, 0.004, 71)
    c = mescola3(c, (1.0, 1.0, 1.0), m)
    out.append((c, 0.3 + 0.6 * cumuli))
    # 7 lastricato: lastre irregolari con fughe scure e muschio
    d1, bordo, ident = celle_voronoi(49, 80)
    fuga = 1 - scalino(bordo, 0.03, 0.11)
    c = mescola((0.38, 0.35, 0.31), (0.6, 0.56, 0.48), ident)
    c *= (0.86 + 0.26 * frattale(28, 3, 81))[..., None]
    c *= (1.0 - 0.18 * scalino(d1, 0.2, 0.55))[..., None]                 # lastre bombate: più scure verso il bordo
    c = mescola3(c, (0.17, 0.16, 0.14), fuga * 0.9)
    muschio = fuga * scalino(frattale(5, 3, 82), 0.45, 0.7)
    c = mescola3(c, (0.2, 0.3, 0.12), muschio * 0.8)
    out.append((c, (1 - fuga) * (0.55 + 0.35 * ident)))
    return out


if __name__ == '__main__':
    qui = os.path.dirname(os.path.abspath(__file__))
    dest = os.path.join(qui, '..', '..', 'godot', 'texture')
    os.makedirs(dest, exist_ok=True)
    atlante = np.zeros((N * 2, N * 4, 4), dtype=np.uint8)
    for k, (col, alt) in enumerate(fai()):
        r, c = divmod(k, 4)
        rgba = np.concatenate([np.clip(col, 0, 1), np.clip(alt, 0, 1)[..., None]], axis=2)
        atlante[r * N:(r + 1) * N, c * N:(c + 1) * N] = (rgba * 255 + 0.5).astype(np.uint8)
    Image.fromarray(atlante, 'RGBA').save(os.path.join(dest, 'terreno.png'), optimize=True)
    # variazione lenta (toni che cambiano su decine di metri: rompe la ripetizione dei riquadri)
    var = np.stack([frattale(3, 5, 90), frattale(4, 5, 91), frattale(6, 4, 92)], axis=2)
    Image.fromarray((var * 255).astype(np.uint8), 'RGB').resize((256, 256), Image.LANCZOS).save(os.path.join(dest, 'variazione.png'), optimize=True)
    Image.fromarray(atlante[..., :3], 'RGB').save(os.path.join(dest, '..', '..', 'tools', 'godot', '_anteprima_terreno.png')) if '--anteprima' in sys.argv else None
    print('scritti', dest)
