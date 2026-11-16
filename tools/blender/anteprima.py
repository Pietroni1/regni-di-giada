# Regni di Giada — anteprima veloce di una mesh senza GPU: proiezione ortografica con z-buffer (numpy + PIL).
# Serve agli script che generano modelli per guardare la sagoma subito, prima di passare da Godot.
#   from anteprima import disegna
#   disegna('file.png', vertici (N,3), triangoli (M,3), colori (M,3) 0..1, viste=['lato', 'fronte', 'tre_quarti'])
# Assi di Blender: z in alto, il modello guarda verso -y.
import numpy as np
from PIL import Image

VISTE = {
    # (destra, alto) nello spazio del modello; la profondità è destra × alto
    'lato': ((0, -1, 0), (0, 0, 1)),            # visto dal fianco sinistro (+x), muso a destra
    'lato_d': ((0, 1, 0), (0, 0, 1)),
    'fronte': ((1, 0, 0), (0, 0, 1)),
    'dietro': ((-1, 0, 0), (0, 0, 1)),
    'alto': ((0, -1, 0), (-1, 0, 0)),
    'tre_quarti': ((0.62, -0.78, 0), (0, 0, 1)),
    'tre_quarti_d': ((-0.62, 0.78, 0), (0, 0, 1)),
}


def _vista(V, T, C, destra, alto, px, margine, sfondo, luce):
    d = np.array(destra, float)
    d /= np.linalg.norm(d)
    a = np.array(alto, float)
    a /= np.linalg.norm(a)
    f = np.cross(d, a)                       # verso chi guarda
    P = np.stack([V @ d, V @ a, V @ f], 1)
    lo, hi = P[:, :2].min(0), P[:, :2].max(0)
    W = int((hi[0] - lo[0]) * px) + 2 * margine
    H = int((hi[1] - lo[1]) * px) + 2 * margine
    img = np.empty((H, W, 3), float)
    img[:] = sfondo
    zb = np.full((H, W), -1e9)
    X = (P[:, 0] - lo[0]) * px + margine
    Y = H - ((P[:, 1] - lo[1]) * px + margine)
    Z = P[:, 2]
    p0, p1, p2 = V[T[:, 0]], V[T[:, 1]], V[T[:, 2]]
    N = np.cross(p1 - p0, p2 - p0)
    N /= np.maximum(1e-12, np.linalg.norm(N, axis=1))[:, None]
    L = np.array(luce, float)
    L /= np.linalg.norm(L)
    Lv = L[0] * d + L[1] * a + L[2] * f      # luce data nello spazio della vista
    sh = 0.42 + 0.58 * np.clip(N @ Lv, 0, 1) + 0.12 * np.clip(N @ a, -1, 1)
    davanti = (N @ f) > 0
    for i in np.nonzero(davanti)[0]:
        t = T[i]
        xs, ys, zs = X[t], Y[t], Z[t]
        x0, x1 = max(int(xs.min()), 0), min(int(xs.max()) + 1, W - 1)
        y0, y1 = max(int(ys.min()), 0), min(int(ys.max()) + 1, H - 1)
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        den = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
        if abs(den) < 1e-9:
            continue
        w0 = ((ys[1] - ys[2]) * (gx - xs[2]) + (xs[2] - xs[1]) * (gy - ys[2])) / den
        w1 = ((ys[2] - ys[0]) * (gx - xs[2]) + (xs[0] - xs[2]) * (gy - ys[2])) / den
        w2 = 1 - w0 - w1
        dentro = (w0 >= -0.01) & (w1 >= -0.01) & (w2 >= -0.01)
        z = w0 * zs[0] + w1 * zs[1] + w2 * zs[2]
        sub = zb[y0:y1 + 1, x0:x1 + 1]
        m = dentro & (z > sub)
        sub[m] = z[m]
        img[y0:y1 + 1, x0:x1 + 1][m] = np.clip(C[i] * sh[i], 0, 1)
    return img


def disegna(file, V, T, C=None, viste=('lato', 'fronte', 'tre_quarti'), px=260, margine=14, sfondo=(0.62, 0.68, 0.74), luce=(0.45, 0.6, 0.65)):
    V = np.asarray(V, float)
    T = np.asarray(T, int)
    C = np.full((len(T), 3), 0.7) if C is None else np.asarray(C, float)
    parti = [_vista(V, T, C, *VISTE[v], px, margine, sfondo, luce) for v in viste]
    H = max(p.shape[0] for p in parti)
    riga = []
    for p in parti:
        if p.shape[0] < H:
            pad = np.empty((H - p.shape[0], p.shape[1], 3))
            pad[:] = sfondo
            p = np.concatenate([pad, p], 0)
        riga.append(p)
    Image.fromarray((np.concatenate(riga, 1) * 255).astype(np.uint8)).save(file)


def da_oggetti(oggetti, colore_di=None):
    """Vertici, triangoli e colori da una lista di oggetti mesh di Blender (posa di riposo, trasformazioni applicate)."""
    Vs, Ts, Cs, base = [], [], [], 0
    for ob in oggetti:
        me = ob.data
        me.calc_loop_triangles()
        mw = np.array(ob.matrix_world)
        v = np.array([x.co[:] for x in me.vertices], float)
        v = v @ mw[:3, :3].T + mw[:3, 3]
        t = np.array([lt.vertices[:] for lt in me.loop_triangles], int)
        if len(t) == 0:
            continue
        Vs.append(v)
        Ts.append(t + base)
        base += len(v)
        if colore_di is None:
            Cs.append(np.full((len(t), 3), 0.7))
        else:
            Cs.append(np.array([colore_di(ob, lt) for lt in me.loop_triangles], float))
    return np.concatenate(Vs), np.concatenate(Ts), np.concatenate(Cs)
