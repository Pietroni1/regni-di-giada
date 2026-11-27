# Regni di Giada — destrieri: un cavallo vero per ogni classe, con finimenti che crescono col livello.
#
# Uso: python3 tools/blender/destrieri.py -- client/assets/modelli/destrieri.glb [--solo lama] [--anteprima cartella]
#      (modulo bpy, oppure blender -b --factory-startup --python tools/blender/destrieri.py -- ...)
#
# Per ogni classe (lama, ombra, monaco, mistico) un'armatura «<classe>_scheletro» con:
#   - «<classe>»            corpo, zoccoli, occhi, criniera e coda (sempre visibili)
#   - «<classe>_tAB»        finimenti visibili dal passo A al passo B (1..4: livelli 1-5, 6-12, 13-19, 20)
# e le azioni «<classe>:fermo|passo|corsa|impennata» (corsa = galoppo a tre tempi con sospensione).
# Il corpo nasce da sezioni anatomiche (tronco, collo, testa, zampe, masse muscolari) fuse in una pelle sola con il
# Remesh a voxel, lisciata e poi ridotta; le normali restano quelle della pelle fitta.
# Dati per lo shader del gioco (godot/shader/destriero.gdshader), niente texture:
#   - UV0: x = casella della parte (vedi SLOT), y = curvatura per il corpo (0,5 = piatto) o coordinata trasversale
#     dei finimenti (in metri / 0,5); il glTF capovolge la v: si scrive 1 - v;
#   - UV1: x = coordinata lungo il pezzo (metri / 4), y = occlusione dipinta (1 = in piena luce);
#   - colore dei vertici: posizione a riposo (x, quota, y) in un cubo noto → macchie, balzane e stella restano ferme
#     sul mantello quando lo scheletro si muove; alfa = quanto il crine è libero (0 radice, 1 punta).
import bpy, bmesh, math, sys, os
from mathutils import Vector, Matrix, Euler, Quaternion
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from forme import sphere, cone, catmull, select_only, shade_vertices, make_action, stash_actions, seg_dist

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = os.path.abspath(argv[0] if argv and not argv[0].startswith('--') else 'destrieri.glb')
SOLO = argv[argv.index('--solo') + 1].split(',') if '--solo' in argv else None
ANTEPRIMA = argv[argv.index('--anteprima') + 1] if '--anteprima' in argv else None
NIENTE_GLB = '--niente-glb' in argv
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 30

SLOT = {'pelo': 0, 'criniera': 1, 'zoccoli': 2, 'occhi': 3, 'scuro': 4, 'cuoio': 5, 'metallo': 6, 'oro': 7, 'stoffa': 8,
        'regno': 9, 'lacca': 10, 'giada': 11, 'corda': 12, 'grani': 13, 'lamelle': 14, 'carta': 15}
# cubo della posizione a riposo scritta nel colore dei vertici (metri)
CUBO = ((-1.0, 1.0), (0.0, 2.6), (-1.8, 1.4))        # x, quota (z), y


# ====================================================================== sezioni e tubi
def S(y, z, w, a, b, na=2.0, nb=2.0, x=0.0):
    """Sezione di un tubo: centro (y, z) nel piano sagittale, mezza larghezza w, estensione a dal lato della normale
    (dorso, cresta, fronte) e b dal lato opposto, esponenti della superellisse sopra e sotto, scostamento laterale x."""
    return dict(y=y, z=z, w=w, a=a, b=b, na=na, nb=nb, x=x)


def _interpola(sez, passi):
    if passi <= 1:
        return [dict(s) for s in sez]
    chiavi = list(sez[0].keys())
    out = []
    for i in range(len(sez) - 1):
        p0, p1, p2, p3 = sez[max(i - 1, 0)], sez[i], sez[i + 1], sez[min(i + 2, len(sez) - 1)]
        for k in range(passi):
            t = k / passi
            d = {}
            for c in chiavi:
                a0, a1, a2, a3 = p0[c], p1[c], p2[c], p3[c]
                v = 0.5 * ((2 * a1) + (-a0 + a2) * t + (2 * a0 - 5 * a1 + 4 * a2 - a3) * t * t + (-a0 + 3 * a1 - 3 * a2 + a3) * t * t * t)
                if c in ('w', 'a', 'b'):
                    v = max(v, min(a1, a2) * 0.9)      # niente strozzature da sovraelongazione
                d[c] = v
            out.append(d)
    out.append(dict(sez[-1]))
    return out


def tubo(sez, n=18, passi=3, specchio=1, fisso=None):
    """Pelle chiusa lungo le sezioni. La normale di ogni anello è la tangente del percorso ruotata di 90° nel piano
    sagittale: per un percorso che va verso il muso (−y) punta in alto, per uno che scende punta in avanti."""
    sez = _interpola(sez, passi)
    bm = bmesh.new()
    anelli, m = [], len(sez)
    for i, s in enumerate(sez):
        c = Vector((s['x'] * specchio, s['y'], s['z']))
        if fisso is not None:
            d = Vector((0, fisso[0], fisso[1]))
        else:
            q0, q1 = sez[max(i - 1, 0)], sez[min(i + 1, m - 1)]
            d = Vector((0, q1['y'] - q0['y'], q1['z'] - q0['z']))
        d.normalize()
        nrm = Vector((0, d.z, -d.y))
        lat = Vector((1, 0, 0))
        ring = []
        for k in range(n):
            t = 2 * math.pi * k / n
            cs, sn = math.cos(t), math.sin(t)
            e = s['na'] if sn >= 0 else s['nb']
            px = s['w'] * math.copysign(abs(cs) ** (2 / e), cs)
            ph = (s['a'] if sn >= 0 else s['b']) * math.copysign(abs(sn) ** (2 / e), sn)
            ring.append(bm.verts.new(c + lat * px + nrm * ph))
        anelli.append(ring)
    for i in range(m - 1):
        for k in range(n):
            bm.faces.new((anelli[i][k], anelli[i][(k + 1) % n], anelli[i + 1][(k + 1) % n], anelli[i + 1][k]))
    bm.faces.new(list(reversed(anelli[0])))
    bm.faces.new(anelli[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def massa(c, raggi, ang=0.0, seg=14, rings=9):
    """Ellissoide (massa muscolare); ang = rotazione attorno all'asse laterale, in gradi."""
    return sphere(c, 1.0, raggi, seg=seg, rings=rings, rot=(math.radians(ang), 0, 0))


def unisci(bms):
    bm = bmesh.new()
    for src in bms:
        vm = {v: bm.verts.new(v.co) for v in src.verts}
        for f in src.faces:
            try:
                bm.faces.new([vm[v] for v in f.verts])
            except ValueError:
                pass
        src.free()
    return bm


def oggetto(nome, bm):
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(nome, me)
    scene.collection.objects.link(ob)
    return ob


def applica(ob, mod):
    select_only(scene, [ob], ob)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def triangoli(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


# ====================================================================== anatomia
# Cavallo di riferimento: 1,62 m al garrese, lungo quanto è alto, muso verso −y. Ogni classe lo deforma con i suoi
# parametri: tronco (larghezza), fondo (profondità del torace), zampe (spessore), collo (spessore), collo_l (lunghezza
# e portamento), testa (taglia), muscoli (masse di spalla e groppa), taglia (scala finale).
BASE = dict(tronco=1.0, fondo=1.0, zampe=1.0, collo=1.0, collo_alto=0.0, testa=1.0, muscoli=1.0, taglia=1.0, ventre=1.0)


def anatomia(P):
    """Punti di riferimento (y, z) e misure derivate, usati da corpo, scheletro e finimenti."""
    A = {}
    tr, fo, za, co, ms = P['tronco'], P['fondo'], P['zampe'], P['collo'], P['muscoli']
    A['sx_a'], A['sx_p'] = 0.155 * (0.6 + 0.4 * tr), 0.17 * (0.6 + 0.4 * tr)       # scostamento laterale delle zampe
    ca = P['collo_alto']
    # collo: centri dal petto alla nuca (arcuato: ripido alla base, più piatto verso la nuca)
    A['collo'] = [(-0.50, 1.34), (-0.62, 1.54 + 0.02 * ca), (-0.76 + 0.02 * ca, 1.74 + 0.05 * ca), (-0.91 + 0.05 * ca, 1.90 + 0.09 * ca),
                  (-1.04 + 0.08 * ca, 2.00 + 0.12 * ca), (-1.10 + 0.09 * ca, 2.045 + 0.13 * ca)]
    A['nuca'] = Vector((0, A['collo'][-1][0] + 0.02, A['collo'][-1][1] + 0.005))
    ang = math.radians(53 + 6 * ca)                 # più il collo è alto e arcuato, più il muso scende a piombo
    A['hdir'] = Vector((0, -math.cos(ang), -math.sin(ang)))
    A['hup'] = Vector((0, A['hdir'].z, -A['hdir'].y))        # lato della fronte
    A['testa_l'] = 0.6 * P['testa']
    A['muso'] = A['nuca'] + A['hdir'] * A['testa_l'] * 1.04
    A['gomito'] = (-0.49, 0.98)
    A['ginocchio'] = (-0.55, 0.50)
    A['nodello_a'] = (-0.535, 0.155)
    A['anca'] = (0.50, 1.30)
    A['grassella'] = (0.34, 0.99)
    A['garretto'] = (0.775, 0.61)
    A['nodello_p'] = (0.793, 0.165)
    return A


def corpo_pezzi(P, A):
    tr, fo, za, co, ms, te = P['tronco'], P['fondo'], P['zampe'], P['collo'], P['muscoli'], P['testa']
    pezzi = []

    def T(y, alto, basso, w, k=0.55, na=2.0, nb=2.0):
        basso = 1.55 - (1.55 - basso) * fo * (P['ventre'] if -0.35 < y < 0.45 else 1.0)
        zc = basso + (alto - basso) * k
        return S(y, zc, w * tr, alto - zc, zc - basso, na, nb)

    # ------------------------------------------------ tronco: dalla punta della natica al petto
    pezzi.append(tubo([
        T(0.90, 1.40, 1.22, 0.07), T(0.84, 1.475, 1.08, 0.17, na=2.2), T(0.70, 1.55, 0.99, 0.255, na=2.4),
        T(0.52, 1.60, 0.95, 0.285, na=2.5), T(0.32, 1.585, 0.925, 0.275, 0.5, na=2.2), T(0.12, 1.545, 0.875, 0.29, 0.5),
        T(-0.10, 1.51, 0.835, 0.305, 0.5), T(-0.30, 1.535, 0.82, 0.29, 0.52, na=1.9), T(-0.45, 1.615, 0.83, 0.25, 0.5, na=1.5),
        T(-0.58, 1.60, 0.90, 0.215, 0.5, na=1.7), T(-0.69, 1.50, 1.00, 0.17), T(-0.75, 1.40, 1.10, 0.11), T(-0.78, 1.32, 1.18, 0.05)], n=24))
    # ------------------------------------------------ collo
    cl = A['collo']
    spess = [(0.20, 0.26, 0.26), (0.15, 0.225, 0.215), (0.108, 0.19, 0.168), (0.084, 0.152, 0.125), (0.07, 0.115, 0.092), (0.058, 0.07, 0.07)]
    pezzi.append(tubo([S(c[0], c[1], s[0] * (0.5 + 0.5 * co) * (0.7 + 0.3 * tr if i < 2 else 1), s[1] * co, s[2] * co, 1.6, 2.0)
                       for i, (c, s) in enumerate(zip(cl, spess))], n=20))
    # ------------------------------------------------ testa: dalla nuca al muso
    nuca, hd, hu = A['nuca'], A['hdir'], A['hup']
    L = A['testa_l']

    def H(t, w, a, b, na=2.6, nb=1.8):
        c = nuca + hd * (t * L / 0.6)
        return S(c.y, c.z, w * te, a * te, b * te, na, nb)

    pezzi.append(tubo([H(-0.03, 0.06, 0.05, 0.07), H(0.05, 0.10, 0.085, 0.135), H(0.14, 0.114, 0.092, 0.185), H(0.25, 0.096, 0.082, 0.165),
                       H(0.37, 0.07, 0.07, 0.105), H(0.48, 0.06, 0.062, 0.08), H(0.56, 0.067, 0.06, 0.08, 2.4, 2.2),
                       H(0.615, 0.06, 0.05, 0.07, 2.2, 2.2), H(0.645, 0.036, 0.03, 0.045)], n=18))

    def nella_testa(t, dors, lato):
        return nuca + hd * (t * L / 0.6) + hu * dors * te + Vector((lato * te, 0, 0))

    ang_t = math.degrees(math.atan2(-hd.y, -hd.z))        # rotazione che porta l'asse z lungo la testa
    for k in (1, -1):
        pezzi.append(massa(nella_testa(0.16, -0.085, 0.066 * k), (0.05 * te, 0.105 * te, 0.11 * te), ang_t))        # ganascia
        pezzi.append(massa(nella_testa(0.125, 0.05, 0.088 * k), (0.034 * te, 0.04 * te, 0.05 * te), ang_t, 10, 7))  # arcata dell'occhio
        pezzi.append(massa(nella_testa(0.585, 0.022, 0.05 * k), (0.026 * te, 0.03 * te, 0.04 * te), ang_t, 10, 7))  # froge
    pezzi.append(massa(nella_testa(0.57, -0.07, 0), (0.04 * te, 0.035 * te, 0.045 * te), ang_t, 10, 7))             # mento
    # ------------------------------------------------ masse di spalla, petto e groppa
    pezzi.append(massa((0, -0.67, 1.20), (0.16 * tr, 0.115, 0.20), -12))                             # petto
    for k in (1, -1):
        pezzi.append(massa((0.10 * tr * k, -0.56, 1.24), (0.135 * ms, 0.17, 0.27), -24))            # scapola
        pezzi.append(massa((0.11 * tr * k, -0.41, 1.08), (0.135 * ms, 0.15, 0.19), 10))             # tricipite
        pezzi.append(massa((0.12 * tr * k, -0.70, 1.17), (0.105 * ms, 0.085, 0.10)))                # punta della spalla
        pezzi.append(massa((0.07 * tr * k, -0.655, 1.06), (0.075 * ms, 0.06, 0.10)))                # pettorale
        pezzi.append(massa((0.13 * tr * k, 0.52, 1.27), (0.17 * ms, 0.32, 0.31), 8))                # groppa e coscia
        pezzi.append(massa((0.11 * tr * k, 0.745, 1.2), (0.12 * ms, 0.10, 0.2), -10))               # natica
        pezzi.append(massa((0.15 * tr * k, 0.35, 1.0), (0.085, 0.08, 0.085), 0, 10, 7))             # grassella
    # ------------------------------------------------ zampe
    sa, sp = A['sx_a'], A['sx_p']
    for k in (1, -1):
        def Z(y, z, w, a, b, x):
            return S(y, z, w * za, a * za, b * za, 2.0, 2.0, x)
        m = (0.7 + 0.3 * ms)
        pezzi.append(tubo([S(-0.47, 1.14, 0.09 * m, 0.13 * m, 0.14 * m, x=sa * 1.04), S(-0.49, 0.99, 0.088 * m, 0.118 * m, 0.128 * m, x=sa * 1.03),
                           Z(-0.512, 0.85, 0.074, 0.098, 0.09, sa), Z(-0.532, 0.69, 0.056, 0.068, 0.062, sa), Z(-0.545, 0.57, 0.046, 0.05, 0.048, sa),
                           Z(-0.552, 0.505, 0.055, 0.062, 0.05, sa), Z(-0.548, 0.455, 0.051, 0.055, 0.049, sa), Z(-0.542, 0.40, 0.04, 0.042, 0.046, sa),
                           Z(-0.54, 0.29, 0.035, 0.038, 0.046, sa * 0.99), Z(-0.538, 0.205, 0.037, 0.039, 0.05, sa * 0.98),
                           Z(-0.535, 0.155, 0.048, 0.05, 0.064, sa * 0.97), Z(-0.56, 0.108, 0.041, 0.044, 0.046, sa * 0.96),
                           Z(-0.582, 0.078, 0.052, 0.054, 0.054, sa * 0.95), Z(-0.587, 0.05, 0.04, 0.04, 0.04, sa * 0.95)], n=14, passi=2, specchio=k))
        pezzi.append(tubo([S(0.50, 1.22, 0.115 * m, 0.22 * m, 0.25 * m, x=sp), S(0.51, 1.05, 0.105 * m, 0.19 * m, 0.255 * m, x=sp),
                           S(0.555, 0.92, 0.086 * m, 0.145 * m, 0.19 * m, x=sp), Z(0.635, 0.80, 0.076, 0.105, 0.115, sp), Z(0.715, 0.69, 0.056, 0.072, 0.07, sp),
                           Z(0.775, 0.61, 0.054, 0.066, 0.074, sp), Z(0.79, 0.545, 0.047, 0.054, 0.058, sp), Z(0.795, 0.46, 0.04, 0.044, 0.049, sp * 0.99),
                           Z(0.797, 0.33, 0.036, 0.04, 0.047, sp * 0.98), Z(0.797, 0.22, 0.039, 0.043, 0.052, sp * 0.97),
                           Z(0.793, 0.165, 0.05, 0.054, 0.066, sp * 0.96), Z(0.77, 0.112, 0.043, 0.046, 0.048, sp * 0.95),
                           Z(0.752, 0.08, 0.054, 0.056, 0.056, sp * 0.94), Z(0.747, 0.05, 0.04, 0.04, 0.04, sp * 0.94)], n=14, passi=2, specchio=k))
        pezzi.append(massa((sp * k, 0.835, 0.64), (0.032 * za, 0.042 * za, 0.05 * za), 0, 8, 6))     # punta del garretto
    # ------------------------------------------------ moncone della coda
    pezzi.append(tubo([S(0.80, 1.44, 0.05, 0.045, 0.045), S(0.90, 1.38, 0.04, 0.036, 0.036), S(0.955, 1.27, 0.028, 0.026, 0.026)], n=10))
    return pezzi


def zoccolo(y_alto, y_basso, x, za, dietro=False):
    """Zoccolo: tronco di cono con la parete davanti inclinata e i talloni più corti."""
    return tubo([S(y_alto, 0.092, 0.047 * za, 0.05 * za, 0.05 * za, 2.2, 2.2, x), S(y_alto - 0.004, 0.075, 0.052 * za, 0.055 * za, 0.052 * za, 2.2, 2.2, x),
                 S(y_basso, 0.0, 0.062 * za, 0.074 * za, 0.058 * za, 2.3, 2.3, x)], n=10, passi=1, fisso=(0, -1))


def costruisci_corpo(nome, P, A):
    """Pelle fitta (riferimento per normali e finimenti) e pelle leggera del corpo."""
    alta = oggetto(nome + '_alta', unisci(corpo_pezzi(P, A)))
    r = alta.modifiers.new('pelle', 'REMESH')
    r.mode = 'VOXEL'
    r.voxel_size = 0.011
    r.adaptivity = 0.0
    r.use_smooth_shade = True
    applica(alta, r)
    # lisciatura: poca ovunque, molta sul tronco (fonde le masse muscolari), quasi nulla su zampe sottili e muso
    g = alta.vertex_groups.new(name='tronco')
    sm = lambda a, b, x: max(0.0, min(1.0, (x - a) / (b - a))) ** 2 * (3 - 2 * max(0.0, min(1.0, (x - a) / (b - a))))
    for v in alta.data.vertices:
        w = sm(0.62, 1.0, v.co.z) * (1.0 - 0.5 * sm(-0.7, -0.9, v.co.y)) * (1.0 - 0.6 * sm(-0.95, -1.12, v.co.y))
        g.add([v.index], w, 'REPLACE')
    s = alta.modifiers.new('liscia', 'SMOOTH')
    s.factor = 0.5
    s.iterations = 5
    applica(alta, s)
    s = alta.modifiers.new('liscia2', 'SMOOTH')
    s.factor = 0.5
    s.iterations = 70
    s.vertex_group = 'tronco'
    applica(alta, s)
    bassa = oggetto(nome, bmesh.new())
    bassa.data = alta.data.copy()
    d = bassa.modifiers.new('leggero', 'DECIMATE')
    d.ratio = min(1.0, P.get('tri', 2700) / max(1, triangoli(alta)))
    applica(bassa, d)
    return alta, bassa


# ====================================================================== pelle di riferimento
class Pelle:
    """Pelle fitta del corpo a riposo: raggi e punto più vicino (per posare crini e finimenti sulla superficie)."""

    def __init__(self, ob):
        self.bm = bmesh.new()
        self.bm.from_mesh(ob.data)
        self.bm.normal_update()
        self.albero = BVHTree.FromBMesh(self.bm)

    def raggio(self, o, d, dist=3.0):
        loc, nrm, _, _ = self.albero.ray_cast(Vector(o), Vector(d).normalized(), dist)
        return (loc, nrm) if loc is not None else None

    def vicino(self, p):
        loc, nrm, _, dist = self.albero.find_nearest(Vector(p))
        return loc, nrm, dist

    def fuori(self, p, off):
        """Il punto p, spinto fuori dalla pelle di almeno off."""
        p = Vector(p)
        loc, nrm, dist = self.vicino(p)
        dentro = (p - loc).dot(nrm) < 0
        if dentro or dist < off:
            return loc + nrm * off
        return p

    def mezza(self, y, z):
        """Mezza larghezza del corpo alla quota z della sezione y (0 se il raggio non tocca)."""
        r = self.raggio((1.5, y, z), (-1, 0, 0), 1.5)
        return max(0.0, r[0].x) if r else 0.0

    def dorso(self, y, x=0.0):
        r = self.raggio((x, y, 3.0), (0, 0, -1), 3.0)
        return r[0].z if r else 0.0


# ====================================================================== pezzi con attributi per vertice
class Pezzo:
    """Parte di mesh con i suoi dati per vertice: u = metri lungo il pezzo, d = metri dal bordo (finimenti) o
    curvatura (corpo), lib = quanto il crine è libero, rad = radice del crine (per i pesi)."""

    def __init__(self, slot, ossa=('corpo', None)):
        self.slot, self.ossa = slot, ossa
        self.v, self.f, self.u, self.d, self.lib, self.rad = [], [], [], [], [], []
        self.pesi = None
        self.nrm = None
        self.aperto = False          # foglio aperto (drappi, gusci, cinghie): il verso delle facce si decide contro la pelle

    def punto(self, co, u=0.0, d=0.25, lib=0.0, rad=None):
        self.v.append(Vector(co))
        self.u.append(u)
        self.d.append(d)
        self.lib.append(lib)
        self.rad.append(rad)
        return len(self.v) - 1

    def griglia(self, righe, chiusa=False):
        for i in range(len(righe) - 1):
            a, b = righe[i], righe[i + 1]
            m = len(a)
            for k in range(m if chiusa else m - 1):
                self.f.append((a[k], a[(k + 1) % m], b[(k + 1) % m], b[k]))

    def specchio(self):
        q = Pezzo(self.slot, self.ossa)
        q.v = [Vector((-v.x, v.y, v.z)) for v in self.v]
        q.f = [tuple(reversed(f)) for f in self.f]
        q.u, q.d, q.lib = list(self.u), list(self.d), list(self.lib)
        q.rad = [None if r is None else Vector((-r.x, r.y, r.z)) for r in self.rad]
        return q

    def tri(self):
        return sum(len(f) - 2 for f in self.f)


def p_da_bm(bm, slot, ossa=('corpo', None), d=0.25):
    p = Pezzo(slot, ossa)
    idx = {v: p.punto(v.co, 0.0, d) for v in bm.verts}
    for f in bm.faces:
        p.f.append(tuple(idx[v] for v in f.verts))
    bm.free()
    return p


def p_sfera(c, r, slot, ossa=('corpo', None), scala=(1, 1, 1), seg=8, rings=5, rot=(0, 0, 0)):
    return p_da_bm(sphere(c, r, scala, seg=seg, rings=rings, rot=rot), slot, ossa)


def p_cono(base, punta, r, slot, ossa=('corpo', None), seg=5, r2=0.0, schiaccia=1.0):
    """Cono dalla base alla punta (schiaccia < 1: appiattito lungo x locale)."""
    base, punta = Vector(base), Vector(punta)
    d = punta - base
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r2, depth=d.length)
    bmesh.ops.scale(bm, vec=(1.0, schiaccia, 1.0), verts=bm.verts)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix())
    bmesh.ops.translate(bm, vec=(base + punta) / 2, verts=bm.verts)
    return p_da_bm(bm, slot, ossa)


def _ricampiona(punti, n):
    """n+1 punti a passo costante lungo la spezzata lisciata."""
    fitti = catmull(punti, 8)
    lung = [0.0]
    for i in range(1, len(fitti)):
        lung.append(lung[-1] + (fitti[i] - fitti[i - 1]).length)
    out, j = [], 0
    for k in range(n + 1):
        s = lung[-1] * k / n
        while j < len(lung) - 2 and lung[j + 1] < s:
            j += 1
        t = (s - lung[j]) / max(1e-9, lung[j + 1] - lung[j])
        out.append(fitti[j].lerp(fitti[j + 1], min(1.0, max(0.0, t))))
    return out, lung[-1]


def p_tubo3d(punti, r, slot, ossa=('corpo', None), lati=5, n=None, d=0.25):
    """Tubo lungo un percorso qualsiasi (corde, redini, cordoni). r = raggio o funzione di t (0..1)."""
    n = n or max(2, len(punti) * 2)
    pts, lung = _ricampiona(punti, n)
    p = Pezzo(slot, ossa)
    righe = []
    rif = Vector((1, 0, 0))
    for i, c in enumerate(pts):
        t = (pts[min(i + 1, n)] - pts[max(i - 1, 0)]).normalized()
        if abs(t.dot(rif)) > 0.95:
            rif = Vector((0, 0, 1))
        a = t.cross(rif).normalized()
        b = t.cross(a).normalized()
        rif = b.cross(t)                 # trasporto del riferimento: niente torsioni
        rr = r(i / n) if callable(r) else r
        righe.append([p.punto(c + (a * math.cos(2 * math.pi * k / lati) + b * math.sin(2 * math.pi * k / lati)) * rr, lung * i / n, d) for k in range(lati)])
    p.griglia(righe, chiusa=True)
    p.f.append(tuple(reversed(righe[0])))
    p.f.append(tuple(righe[-1]))
    return p


def _orli(p, righe, bordo_u=True, bordo_v=True):
    """Distanza in metri di ogni vertice della griglia dal bordo più vicino → p.d."""
    nu, nv = len(righe), len(righe[0])
    lu = [[0.0] * nv for _ in range(nu)]
    lv = [[0.0] * nv for _ in range(nu)]
    for i in range(nu):
        for k in range(nv):
            if i:
                lu[i][k] = lu[i - 1][k] + (p.v[righe[i][k]] - p.v[righe[i - 1][k]]).length
            if k:
                lv[i][k] = lv[i][k - 1] + (p.v[righe[i][k]] - p.v[righe[i][k - 1]]).length
    for i in range(nu):
        for k in range(nv):
            d = 9.0
            if bordo_u:
                d = min(d, lu[i][k], lu[-1][k] - lu[i][k])
            if bordo_v:
                d = min(d, lv[i][k], lv[i][-1] - lv[i][k])
            p.d[righe[i][k]] = min(d, 0.5)


def _asse(punti, n):
    """Stazioni lungo un asse nel piano sagittale: (centro, tangente, normale) e lunghezza."""
    pts, lung = _ricampiona([Vector((0, q[0], q[1])) if len(q) == 2 else Vector(q) for q in punti], n)
    out = []
    for i, c in enumerate(pts):
        t = (pts[min(i + 1, n)] - pts[max(i - 1, 0)]).normalized()
        out.append((c, t, Vector((0, t.z, -t.y))))
    return out, lung


def p_avvolgi(K, asse, ang0, ang1, nu, nv, off=0.02, slot='cuoio', ossa=('corpo', None), R=0.9, file=0, gradino=0.02, bordo_u=True, minimo=0.03):
    """Guscio che avvolge il corpo attorno a un asse (tronco, collo, testa...): per ogni stazione e ogni angolo (gradi,
    0 = lato della normale dell'asse, positivo verso +x) un raggio dall'esterno cerca la pelle. off = distanza dalla
    pelle (numero o funzione di s, a in 0..1). file > 0: file di lamelle a gradino lungo l'asse."""
    staz, lung = _asse(asse, nu)
    p = Pezzo(slot, ossa)
    p.aperto = True
    chiuso = abs(abs(ang1 - ang0) - 360) < 1e-3
    ultimo = [None]
    X = Vector((1, 0, 0))

    def vertice(i, k, extra=0.0):
        c, t, nrm = staz[i]
        a = k / nv
        th = math.radians(ang0 + (ang1 - ang0) * a)
        d = nrm * math.cos(th) + X * math.sin(th)
        o = (off(i / nu, a) if callable(off) else off) + extra
        h = K.pelle.raggio(c + d * R, -d, R)
        if h:
            ultimo[0] = (h[0] - c).length
        # raggio a vuoto (oltre il bordo del corpo): stessa distanza dall'asse dell'ultimo punto trovato
        q = (h[0] + d * o) if h else (c + d * ((ultimo[0] if ultimo[0] is not None else minimo) + o))
        return p.punto(q, lung * i / nu, 0.25)

    cols = nv if chiuso else nv + 1
    if file <= 0:
        righe = [[vertice(i, k) for k in range(cols)] for i in range(nu + 1)]
        p.griglia(righe, chiusa=chiuso)
        _orli(p, righe, bordo_u, not chiuso)
    else:
        per = max(1, nu // file)
        for fi in range(file):
            i0, i1 = fi * per, min(nu, (fi + 1) * per)
            righe = [[vertice(i, k, gradino * (i - i0) / max(1, i1 - i0)) for k in range(cols)] for i in range(i0, i1 + 1)]
            p.griglia(righe, chiusa=chiuso)
            _orli(p, righe, True, not chiuso)
    return p


def p_cinghia(K, punti, larg, slot='cuoio', ossa=('corpo', None), off=0.008, n=None, libera=False):
    """Cinghia posata sulla pelle lungo i punti dati (tre file di vertici: i bordi e una costa leggermente rialzata)."""
    n = n or max(2, len(punti) * 2)
    pts, lung = _ricampiona(punti, n)
    p = Pezzo(slot, ossa)
    p.aperto = True
    righe = []
    for i, c in enumerate(pts):
        t = (pts[min(i + 1, n)] - pts[max(i - 1, 0)]).normalized()
        loc, nrm, _ = K.pelle.vicino(c)
        if libera:
            nrm = (c - loc).normalized() if (c - loc).length > 1e-5 else nrm
            loc = c
        b = nrm.cross(t).normalized()
        riga = []
        for lato, su, dd in ((-0.5, 0.0, 0.0), (0.0, 0.004, larg * 0.5), (0.5, 0.0, 0.0)):
            q = loc + b * (larg * lato)
            if not libera:
                q2, n2, _ = K.pelle.vicino(q)
                q = q2 + n2 * (off + su)
            else:
                q = q + nrm * su
            riga.append(p.punto(q, lung * i / n, dd))
        righe.append(riga)
    p.griglia(righe)
    return p


def p_drappo(K, y0, y1, fondo, ny, nz, off=0.02, slot='stoffa', ossa=('corpo', {'hips', 'spine', 'chest'}), svaso=0.0, cima=None):
    """Drappo posato sul dorso che pende a piombo sui fianchi fino alla quota fondo (numero o funzione di y):
    segue il corpo dove si allarga, cade dritto dove rientra. svaso = quanto si apre verso il basso (metri)."""
    p = Pezzo(slot, ossa)
    p.aperto = True
    righe = []
    for i in range(ny + 1):
        y = y0 + (y1 - y0) * i / ny
        top = (cima(y) if cima else K.pelle.dorso(y)) + off
        zf = fondo(y) if callable(fondo) else fondo
        meta = []
        mx = 0.0
        for k in range(nz + 1):
            f = (k / nz) ** 1.25              # la cima è più fitta: lì il dorso curva
            z = top - (top - zf) * f
            if k == 0:
                meta.append(Vector((0, y, top)))
                continue
            mx = max(mx, K.pelle.mezza(y, z) + off)        # la larghezza non rientra mai: la stoffa pende
            meta.append(Vector((mx + svaso * f * f, y, z)))
        riga = [p.punto(Vector((-q.x, q.y, q.z)), abs(y - y0), 0.25) for q in reversed(meta[1:])] + [p.punto(q, abs(y - y0), 0.25) for q in meta]
        righe.append(riga)
    p.griglia(righe)
    # dove la maglia larga taglia una gobba del corpo (groppa, spalle) i vertici della faccia escono di quanto serve
    for _ in range(3):
        spinte = {}
        for f in p.f:
            c = sum((p.v[i] for i in f), Vector()) / len(f)
            loc, nrm, dist = K.pelle.vicino(c)
            sotto = (c - loc).dot(nrm)
            if sotto < off * 0.6:
                for i in f:
                    spinte[i] = max(spinte.get(i, 0.0), off * 0.8 - sotto)
        if not spinte:
            break
        for i, quanto in spinte.items():
            v = p.v[i]
            fuori = Vector((math.copysign(1.0, v.x) if abs(v.x) > 0.04 else 0.0, 0, 0.35 if abs(v.x) > 0.04 else 1.0)).normalized()
            p.v[i] = v + fuori * min(quanto, 0.06)
    _orli(p, righe, True, True)
    return p


def p_ciocca(K, punti, w0, w1, sp, slot='criniera', ossa=('crini', None), n=4, rad=None, lib0=0.0, lib1=1.0, piatto=None):
    """Ciocca di crine: sezione a rombo schiacciato che si assottiglia; il lato piatto guarda fuori dalla pelle."""
    pts, lung = _ricampiona(punti, n)
    p = Pezzo(slot, ossa)
    rad = Vector(rad if rad is not None else pts[0])
    righe = []
    for i, c in enumerate(pts):
        f = i / n
        t = (pts[min(i + 1, n)] - pts[max(i - 1, 0)]).normalized()
        if piatto is not None:
            nrm = Vector(piatto)
        else:
            loc, nrm, _ = K.pelle.vicino(c)
            if (c - loc).length > 0.01:
                nrm = (c - loc).normalized()
        b = t.cross(nrm)
        if b.length < 1e-4:
            b = t.cross(Vector((1, 0, 0)))
        b.normalize()
        nrm = b.cross(t).normalized()
        w = (w0 + (w1 - w0) * f) * (0.55 + 0.45 * math.sin(math.pi * min(1.0, f * 1.6 + 0.2)))     # radice stretta, pancia, punta
        s = sp * (1.0 - 0.6 * f)
        lib = lib0 + (lib1 - lib0) * f
        riga = [p.punto(c + b * w, lung * f, 0.0, lib, rad), p.punto(c + nrm * s, lung * f, 1.0, lib, rad),
                p.punto(c - b * w, lung * f, 0.0, lib, rad), p.punto(c - nrm * s * 0.4, lung * f, 1.0, lib, rad)]
        righe.append(riga)
    p.griglia(righe, chiusa=True)
    p.f.append(tuple(righe[-1]))
    return p


# ====================================================================== contesto di una classe
class Contesto:
    pass


def punto_testa(K, t, dors=0.0, lato=0.0):
    """Punto nella testa: t = metri dalla nuca lungo il muso (testa di riferimento lunga 0,6), dors verso la fronte."""
    te = K.P['testa']
    return K.A['nuca'] + K.A['hdir'] * (t * K.A['testa_l'] / 0.6) + K.A['hup'] * dors * te + Vector((lato * te, 0, 0))


def asse_collo(K, s0=0.0, s1=1.0):
    pts, _ = _ricampiona([Vector((0, c[0], c[1])) for c in K.A['collo'][:-1]], 24)
    i0, i1 = int(round(s0 * 24)), int(round(s1 * 24))
    return pts[i0:i1 + 1]


def cresta(K, s):
    """Punto sulla cresta del collo (s = 0 al garrese, 1 alla nuca), con normale e tangente."""
    staz, _ = _asse([Vector((0, c[0], c[1])) for c in K.A['collo'][:-1]], 24)
    c, t, nrm = staz[max(0, min(24, int(round(s * 24))))]
    h = K.pelle.raggio(c + nrm * 0.8, -nrm, 0.8)
    return (h[0] if h else c + nrm * 0.1), nrm, t


# ====================================================================== occhi, orecchie, zoccoli, crini
def dettagli(K):
    P, A = K.P, K.A
    te, za = P['testa'], P['zampe']
    out = []
    for k in (1, -1):
        lato = 'L' if k > 0 else 'R'
        # occhio: globo scuro incassato sotto l'arcata
        out.append(p_sfera(punto_testa(K, 0.148, 0.022, 0.1 * k), 0.026 * te, 'occhi', 'head', seg=8, rings=6))
        # narice
        c = punto_testa(K, 0.6, 0.012, 0.052 * k)
        out.append(p_sfera(K.pelle.vicino(c)[0], 0.02 * te, 'scuro', 'head', scala=(0.5, 0.9, 1.2), seg=6, rings=4))
        # orecchio: foglia appuntita, cava davanti
        base = punto_testa(K, 0.015, 0.045, 0.058 * k)
        punta = base + Vector((0.045 * k, -0.035, 0.165)) * te
        out.append(p_cono(base - (punta - base) * 0.15, punta, 0.047 * te, 'pelo', 'ear_' + lato, seg=6, schiaccia=0.7))
        out.append(p_cono(base + (punta - base) * 0.12 + Vector((0, -0.021, 0)), base + (punta - base) * 0.78 + Vector((0, -0.014, 0)), 0.02 * te,
                          'scuro', 'ear_' + lato, seg=4, schiaccia=0.5))
        # zoccoli
        out.append(p_da_bm(zoccolo(-0.582, -0.604, A['sx_a'] * 0.95 * k, za), 'zoccoli', 'piede_a' + lato))
        out.append(p_da_bm(zoccolo(0.752, 0.73, A['sx_p'] * 0.94 * k, za), 'zoccoli', 'piede_p' + lato))
    return out


def crini(K):
    """Criniera, ciuffo e coda secondo lo stile della classe."""
    C = K.P['crini']
    out = []
    X = Vector((1, 0, 0))
    stile = C['stile']
    n = C.get('n', 12)
    lung = C.get('lung', 0.3)
    if stile == 'cresta':
        # criniera rasata a cresta: ciuffi corti e dritti, inclinati all'indietro
        for i in range(n):
            s = 0.14 + 0.83 * i / (n - 1)
            c, nrm, t = cresta(K, s)
            h = lung * (0.75 + 0.35 * math.sin(math.pi * i / (n - 1))) * (1.15 if i % 2 else 0.9)
            d = (nrm * 0.9 - t * 0.45).normalized()
            p = p_cono(c - d * 0.02, c + d * h, 0.055, 'criniera', ('crini', None), seg=4, schiaccia=0.38)
            for j, v in enumerate(p.v):
                f = max(0.0, min(1.0, (v - c).dot(d) / h))
                p.lib[j], p.rad[j], p.u[j], p.d[j] = f * 0.35, c, f * h, 0.5
            out.append(p)
    else:
        # ciocche larghe che si sovrappongono come tegole e scendono lungo il collo; lati = 2: su entrambi i fianchi
        lati = C.get('lati', 2)
        giu = Vector((0, 0.25, -1)).normalized()
        for k in ((1, -1) if lati == 2 else (1,)):
            for i in range(n):
                s = 0.08 + 0.9 * (i + (0.5 if k < 0 else 0.0)) / n
                c, nrm, t = cresta(K, s)
                ll = lung * (0.82 + 0.28 * math.sin(i * 2.4 + k) ** 2) * (0.7 + 0.45 * math.sin(math.pi * min(1.0, s * 1.25)))
                # la ciocca scende sul fianco del collo seguendone la larghezza; sotto il collo pende libera
                pts = [c - nrm * 0.015 + X * k * 0.004]
                mx = 0.03
                for fz in (0.25, 0.62, 1.0):
                    y, z = c.y + 0.25 * ll * fz, c.z - ll * fz
                    mx = max(mx * 0.9, K.pelle.mezza(y, z) + 0.024 + 0.008 * fz)
                    pts.append(Vector((k * mx, y, z)))
                out.append(p_ciocca(K, pts, C.get('larg', 0.075), 0.035, C.get('spess', 0.012), n=3, rad=c, piatto=Vector((k, 0, 0.2)).normalized()))
        if lati == 1:
            # dall'altra parte solo una frangia corta lungo la cresta
            for i in range(n // 2):
                s = 0.12 + 0.82 * i / (n // 2 - 1)
                c, nrm, t = cresta(K, s)
                ll = lung * 0.3
                p0 = c - nrm * 0.015
                p1 = K.pelle.fuori(c - X * 0.05 + giu * ll * 0.4, 0.02)
                p2 = K.pelle.fuori(c - X * 0.06 + giu * ll, 0.024)
                out.append(p_ciocca(K, [p0, p1, p2], 0.07, 0.03, 0.018, n=2, rad=c))
    # ciuffo sulla fronte
    cf = C.get('ciuffo', 0.16)
    if cf > 0:
        for k in (-1, 0, 1):
            base = punto_testa(K, 0.0, 0.07, 0.022 * k)
            p1 = punto_testa(K, 0.05, 0.115, 0.03 * k)
            p2 = K.pelle.fuori(punto_testa(K, 0.05 + cf * 0.6, 0.1, 0.045 * k), 0.022)
            p3 = K.pelle.fuori(punto_testa(K, 0.05 + cf, 0.09, 0.05 * k), 0.02)
            out.append(p_ciocca(K, [base, p1, p2, p3], 0.04, 0.015, 0.018, ossa='head', n=3))
    # coda: fascio di ciocche dal moncone
    tl, tn, tw = C.get('coda', (0.95, 7, 0.06))
    for i in range(tn):
        a = 2 * math.pi * i / tn + 0.3
        lx, ly = math.cos(a), math.sin(a)
        r0 = 0.022
        l = tl * (0.85 + 0.15 * math.sin(i * 1.7) ** 2) * (1.0 if ly > -0.5 else 0.85)
        p0 = Vector((lx * r0, 0.86 + ly * 0.01, 1.41 + ly * r0))
        p1 = Vector((lx * 0.05, 0.99 + ly * 0.03, 1.33 + ly * 0.03))
        p2 = Vector((lx * 0.075, 1.07 + ly * 0.045, 1.33 - l * 0.33))
        p3 = Vector((lx * 0.085, 1.08 + ly * 0.05, 1.33 - l * 0.7))
        p4 = Vector((lx * 0.05, 1.05 + ly * 0.035, 1.33 - l))
        out.append(p_ciocca(K, [p0, p1, p2, p3, p4], tw, 0.02, 0.03, ossa='coda', n=5, piatto=Vector((lx, ly * 0.8 + 0.2, 0.15)).normalized()))
    # ciuffi ai nodelli (cavalli pesanti)
    if C.get('barbette', 0) > 0:
        b = C['barbette']
        for k in (1, -1):
            lato = 'L' if k > 0 else 'R'
            for (y, z, x, osso) in ((-0.5, 0.2, K.A['sx_a'] * 0.97 * k, 'stinco_a'), (0.835, 0.21, K.A['sx_p'] * 0.96 * k, 'stinco_p')):
                for j in (-1, 1):
                    base = Vector((x + j * 0.02, y - 0.015, z + 0.03))
                    out.append(p_cono(base, base + Vector((j * 0.012, 0.05, -0.15 * b)), 0.042, 'criniera', osso + lato, seg=5, schiaccia=0.55))
    return out


# ====================================================================== scheletro
def ossa_di(K):
    A, P = K.A, K.P
    V = lambda y, z, x=0.0: Vector((x, y, z))
    cl = A['collo']
    nuca, muso = A['nuca'], A['muso']
    te = P['testa']
    c_mid, c_nrm, _ = cresta(K, 0.5)
    ys = -0.14
    B = [('hips', V(0.62, 1.38), V(0.20, 1.40), None),
         ('spine', V(0.20, 1.40), V(-0.22, 1.38), 'hips'),
         ('chest', V(-0.22, 1.38), V(-0.56, 1.42), 'spine'),
         ('neck1', V(-0.56, 1.42), V(cl[2][0], cl[2][1]), 'chest'),
         ('neck2', V(cl[2][0], cl[2][1]), nuca.copy(), 'neck1'),
         ('head', nuca.copy(), muso.copy(), 'neck2'),
         ('muso', muso.copy(), muso + A['hdir'] * 0.05, 'head'),
         ('crini', c_mid - c_nrm * 0.06, c_mid + c_nrm * 0.1, 'neck1'),
         ('sella', V(ys, K.pelle.dorso(ys) + 0.05), V(ys, K.pelle.dorso(ys) + 0.25), 'spine'),
         ('tail1', V(0.84, 1.43), V(0.99, 1.26), 'hips'),
         ('tail2', V(0.99, 1.26), V(1.07, 0.92), 'tail1'),
         ('tail3', V(1.07, 0.92), V(1.05, 0.5), 'tail2')]
    for s, k in (('L', 1), ('R', -1)):
        eb = punto_testa(K, 0.015, 0.045, 0.058 * k)
        B.append(('ear_' + s, eb, eb + Vector((0.04 * k, -0.03, 0.15)) * te, 'head'))
        xa, xp = A['sx_a'] * k, A['sx_p'] * k
        B += [('spalla_' + s, V(-0.46, 1.38, xa), V(*A['gomito'], xa), 'chest'),
              ('avambraccio_' + s, V(*A['gomito'], xa), V(*A['ginocchio'], xa), 'spalla_' + s),
              ('stinco_a' + s, V(*A['ginocchio'], xa), V(*A['nodello_a'], xa * 0.97), 'avambraccio_' + s),
              ('piede_a' + s, V(*A['nodello_a'], xa * 0.97), V(-0.63, 0.02, xa * 0.95), 'stinco_a' + s),
              ('coscia_' + s, V(*A['anca'], xp), V(*A['grassella'], xp), 'hips'),
              ('gamba_' + s, V(*A['grassella'], xp), V(*A['garretto'], xp), 'coscia_' + s),
              ('stinco_p' + s, V(*A['garretto'], xp), V(*A['nodello_p'], xp * 0.96), 'gamba_' + s),
              ('piede_p' + s, V(*A['nodello_p'], xp * 0.96), V(0.70, 0.02, xp * 0.94), 'stinco_p' + s)]
    return B


NON_DEFORMA = ('crini', 'sella', 'muso', 'ear_L', 'ear_R')


def crea_scheletro(nome, B):
    arm_data = bpy.data.armatures.new(nome + '_scheletro')
    arm = bpy.data.objects.new(nome + '_scheletro', arm_data)
    scene.collection.objects.link(arm)
    select_only(scene, [arm], arm)
    bpy.ops.object.mode_set(mode='EDIT')
    for bn, h, t, parent in B:
        eb = arm_data.edit_bones.new(bn)
        eb.head, eb.tail = h, t
        eb.roll = 0
        if parent:
            eb.parent = arm_data.edit_bones[parent]
            eb.use_connect = (h - arm_data.edit_bones[parent].tail).length < 1e-4
    bpy.ops.object.mode_set(mode='OBJECT')
    return arm


def _pesi_dist(p, permesse, K, potenza=4):
    ds = sorted((seg_dist(p, K.BH[b], K.BT[b]), b) for b in permesse)[:3]
    ws = [(1.0 / (d + 0.02) ** potenza, b) for d, b in ds]
    tot = sum(w for w, _ in ws)
    out = {b: w / tot for w, b in ws if w / tot > 0.04}
    tot = sum(out.values())
    return {b: w / tot for b, w in out.items()}


def pesi_corpo(K, bassa, arm):
    """Pesi della pelle: calore delle ossa di Blender; se fallisce, distanza dalle ossa."""
    bassa.vertex_groups.clear()
    for b in arm.data.bones:
        b.use_deform = b.name not in NON_DEFORMA
    select_only(scene, [bassa, arm], arm)
    ok = True
    try:
        bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    except Exception as e:
        print('pesi automatici non riusciti:', e)
        ok = False
    for b in arm.data.bones:
        b.use_deform = True
    nomi = {g.index: g.name for g in bassa.vertex_groups}
    pesi = []
    vuoti = 0
    for v in bassa.data.vertices:
        w = {nomi[g.group]: g.weight for g in v.groups if g.weight > 0.02}
        tot = sum(w.values())
        if tot < 1e-6:
            vuoti += 1
            w = None
        else:
            w = {b: x / tot for b, x in w.items()}
        pesi.append(w)
    deform = [b for b in K.BH if b not in NON_DEFORMA]
    if not ok or vuoti > len(pesi) * 0.2:
        print('  ripiego: pesi dalla distanza (%d vertici senza peso)' % vuoti)
        pesi = [_pesi_dist(v.co, deform, K) for v in bassa.data.vertices]
    elif vuoti:
        pesi = [w if w is not None else _pesi_dist(bassa.data.vertices[i].co, deform, K) for i, w in enumerate(pesi)]
    return pesi


# ====================================================================== montaggio di un oggetto
def _emisfero(n=12):
    out, ga = [], math.pi * (3 - math.sqrt(5))
    for i in range(n):
        z = 1 - (i + 0.5) / n
        r = math.sqrt(max(0.0, 1 - z * z))
        out.append(Vector((math.cos(ga * i) * r, math.sin(ga * i) * r, z)))
    return out


EMI = _emisfero(12)


def _orienta(K, p):
    """Facce rivolte all'esterno: i pezzi chiusi con il ricalcolo di Blender, i fogli aperti guardando via dalla pelle."""
    if p.nrm is not None or not p.f:
        return
    if p.aperto:
        voto = 0.0
        for f in p.f:
            a, b, c = p.v[f[0]], p.v[f[1]], p.v[f[2]]
            n = (b - a).cross(c - a)
            centro = (a + b + c) / 3
            loc, _, _ = K.pelle.vicino(centro)
            voto += n.normalized().dot((centro - loc).normalized()) if (centro - loc).length > 1e-5 and n.length > 1e-9 else 0.0
        if voto < 0:
            p.f = [tuple(reversed(f)) for f in p.f]
        return
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in p.v]
    facce = []
    for f in p.f:
        try:
            facce.append(bm.faces.new([vs[i] for i in f]))
        except ValueError:
            facce.append(None)
    bmesh.ops.recalc_face_normals(bm, faces=[f for f in facce if f is not None])
    bm.verts.index_update()
    p.f = [tuple(v.index for v in f.verts) for f in facce if f is not None]
    bm.free()


def monta(K, nome, pezzi, arm, alberi_extra=(), portata=0.22):
    """Unisce i pezzi in un oggetto con UV, colore dei vertici, pesi, normali e occlusione dipinta."""
    V, F, slot, U, D, LIB, W, NRM = [], [], [], [], [], [], [], []
    for p in pezzi:
        _orienta(K, p)
        base = len(V)
        V += p.v
        F += [tuple(i + base for i in f) for f in p.f]
        slot += [SLOT[p.slot]] * len(p.v)
        U += p.u
        D += p.d
        LIB += p.lib
        NRM += (p.nrm if p.nrm is not None else [None] * len(p.v))
        for i, co in enumerate(p.v):
            if p.pesi is not None:
                w = p.pesi[i]
            elif isinstance(p.ossa, str) and p.ossa == 'coda':
                w = _pesi_dist(co, ['hips', 'tail1', 'tail2', 'tail3'], K, 3)
            elif isinstance(p.ossa, str):
                w = {p.ossa: 1.0}
            elif p.ossa[0] == 'crini':
                w = dict(K.pesi_vicino(p.rad[i] if p.rad[i] is not None else co, {'neck1', 'neck2', 'head', 'chest'}))
                wc = 0.85 * p.lib[i] ** 1.2
                w = {b: x * (1 - wc) for b, x in w.items()}
                w['crini'] = w.get('crini', 0.0) + wc
            else:
                w = K.pesi_vicino(co, p.ossa[1])
            W.append(w)
    me = bpy.data.meshes.new(nome)
    me.from_pydata([v[:] for v in V], [], F)
    me.update()
    for poly in me.polygons:
        poly.use_smooth = True
    ob = bpy.data.objects.new(nome, me)
    scene.collection.objects.link(ob)
    # normali: quelle date (pelle fitta) oppure quelle lisce della mesh
    vn = [NRM[i] if NRM[i] is not None else Vector(me.vertex_normals[i].vector) for i in range(len(V))]
    # occlusione: raggi contro l'oggetto stesso e contro gli alberi dati (corpo)
    bm = bmesh.new()
    bm.from_mesh(me)
    alberi = [BVHTree.FromBMesh(bm)] + list(alberi_extra)
    ao = []
    wsum = sum(h.z for h in EMI)
    for i, co in enumerate(V):
        n = vn[i]
        if n.length < 1e-6:
            n = Vector((0, 0, 1))
        t = n.orthogonal().normalized()
        b = n.cross(t)
        o = co + n * 0.006
        occ = 0.0
        for d in EMI:
            dv = (t * d.x + b * d.y + n * d.z)
            best = None
            for al in alberi:
                hit = al.ray_cast(o, dv, portata)
                if hit[0] is not None and (best is None or hit[3] < best):
                    best = hit[3]
            if best is not None:
                occ += d.z * (1 - best / portata)
        ao.append(1 - min(1.0, occ / wsum * 1.5))
    bm.free()
    uv0 = me.uv_layers.new(name='UVMap')
    uv1 = me.uv_layers.new(name='Part')
    col = me.color_attributes.new('Riposo', 'FLOAT_COLOR', 'POINT')
    for lp in me.loops:
        i = lp.vertex_index
        dd = D[i] if slot[i] in (SLOT['pelo'], SLOT['criniera']) else D[i] * 2.0
        uv0.data[lp.index].uv = ((slot[i] + 0.5) / 16.0, 1 - max(0.0, min(1.0, dd)))
        uv1.data[lp.index].uv = (max(0.0, min(1.0, U[i] / 4.0)), 1 - ao[i])
    for i, co in enumerate(V):
        col.data[i].color = ((co.x - CUBO[0][0]) / (CUBO[0][1] - CUBO[0][0]), (co.z - CUBO[1][0]) / (CUBO[1][1] - CUBO[1][0]),
                             (co.y - CUBO[2][0]) / (CUBO[2][1] - CUBO[2][0]), LIB[i])
    me.color_attributes.active_color = col
    me.color_attributes.render_color_index = 0
    me.uv_layers.active = uv0
    gruppi = {b: ob.vertex_groups.new(name=b) for b in K.BH}
    for i, w in enumerate(W):
        for b, x in w.items():
            gruppi[b].add([i], x, 'REPLACE')
    me.normals_split_custom_set_from_vertices([n[:] for n in vn])
    mat = bpy.data.materials.get('destriero') or bpy.data.materials.new('destriero')
    me.materials.append(mat)
    ob.parent = arm
    ob.modifiers.new('scheletro', 'ARMATURE').object = arm
    return ob


def pezzo_corpo(K, bassa):
    """La pelle leggera come Pezzo: normali dalla pelle fitta, curvatura nel canale d."""
    me = bassa.data
    p = Pezzo('pelo')
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.normal_update()
    curv = []
    for v in bm.verts:
        c, k = 0.0, 0
        for e in v.link_edges:
            u = e.other_vert(v)
            dv = v.co - u.co
            if dv.length_squared > 1e-10:
                c += (v.normal - u.normal).dot(dv) / dv.length_squared
                k += 1
        curv.append(c / max(1, k))
    vals = sorted(abs(x) for x in curv)
    scala = vals[int(len(vals) * 0.92)] or 1.0
    p.nrm = []
    for v in bm.verts:
        p.punto(v.co, 0.0, 0.5 + 0.5 * max(-1.0, min(1.0, curv[v.index] / scala)))
        loc, nrm, _ = K.pelle.vicino(v.co)
        p.nrm.append(nrm.copy())
    for f in bm.faces:
        p.f.append(tuple(v.index for v in f.verts))
    bm.free()
    p.pesi = K.pesi_bassa
    return p


# ====================================================================== animazioni
def _rot(v, gradi):
    c, s = math.cos(math.radians(gradi)), math.sin(math.radians(gradi))
    return (v[0] * c - v[1] * s, v[0] * s + v[1] * c)


def _ang(v):
    return math.degrees(math.atan2(v[1], v[0]))


def _som(a, b):
    return (a[0] + b[0], a[1] + b[1])


def _dif(a, b):
    return (a[0] - b[0], a[1] - b[1])


def _lun(a):
    return math.hypot(a[0], a[1])


def _liscio(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def _chiavi(tab, t):
    """Valore al tempo t di una tabella [(t, v)] con raccordo morbido fra le chiavi."""
    if t <= tab[0][0]:
        return tab[0][1]
    for (t0, v0), (t1, v1) in zip(tab, tab[1:]):
        if t <= t1:
            return v0 + (v1 - v0) * _liscio((t - t0) / (t1 - t0))
    return tab[-1][1]


class Andatura:
    """Pose dello scheletro nel piano sagittale: il corpo si muove come deciso (beccheggio, quota, schiena), le zampe
    raggiungono con la cinematica inversa il nodello voluto (zoccoli fermi a terra in appoggio)."""

    def __init__(self, K):
        self.K = K
        H = lambda b: (K.BH[b].y, K.BH[b].z)
        T = lambda b: (K.BT[b].y, K.BT[b].z)
        self.H = H
        self.a = dict(v1=_dif(T('spalla_L'), H('spalla_L')), v2=_dif(T('avambraccio_L'), H('avambraccio_L')), v3=_dif(T('stinco_aL'), H('stinco_aL')),
                      riposo=T('stinco_aL'))
        self.p = dict(v1=_dif(T('coscia_L'), H('coscia_L')), v2=_dif(T('gamba_L'), H('gamba_L')), v3=_dif(T('stinco_pL'), H('stinco_pL')),
                      riposo=T('stinco_pL'))

    def _u(self, davanti, f):
        g = self.a if davanti else self.p
        if davanti:
            return _som(_som(g['v1'], _rot(g['v2'], -0.55 * f)), _rot(g['v3'], 0.45 * f))
        return _som(_som(g['v1'], _rot(g['v2'], f)), g['v3'])

    def _piega(self, davanti, dist):
        lo, hi = (-6.0, 150.0) if davanti else (-38.0, 120.0)
        if dist >= _lun(self._u(davanti, lo)):
            return lo
        if dist <= _lun(self._u(davanti, hi)):
            return hi
        for _ in range(28):
            mid = (lo + hi) / 2
            if _lun(self._u(davanti, mid)) > dist:
                lo = mid
            else:
                hi = mid
        return (lo + hi) / 2

    def posa(self, c):
        """c: beccheggio, dy, dz, spine, chest, neck1, neck2, head, tail1..3, crini, ear (gradi attorno a x),
        zampe = {'aL': dict(nodello=(y, z), aria=(angolo, piega), peso_aria, terra=0..1, flesso=gradi), ...},
        extra = {osso: [('Z', gradi)]}."""
        H = self.H
        be = c.get('beccheggio', 0.0)
        hips = _som(H('hips'), (c.get('dy', 0.0), c.get('dz', 0.0)))
        a_spine = be + c.get('spine', 0.0)
        p_spine = _som(hips, _rot(_dif(H('spine'), H('hips')), be))
        a_chest = a_spine + c.get('chest', 0.0)
        p_chest = _som(p_spine, _rot(_dif(H('chest'), H('spine')), a_spine))
        out = {'hips': [('X', be)], 'loc': (0, c.get('dy', 0.0), c.get('dz', 0.0)), 'spine': [('X', c.get('spine', 0.0))], 'chest': [('X', c.get('chest', 0.0))]}
        for b in ('neck1', 'neck2', 'head', 'tail1', 'tail2', 'tail3', 'crini'):
            out[b] = [('X', c.get(b, 0.0))]
        for b in ('ear_L', 'ear_R'):
            out[b] = [('X', c.get(b, c.get('ear', 0.0)))]
        for b, r in c.get('extra', {}).items():
            out[b] = out.get(b, []) + r
        for nome_z, z in c['zampe'].items():
            davanti = nome_z[0] == 'a'
            lato = nome_z[1]
            if davanti:
                piv = _som(p_chest, _rot(_dif(H('spalla_L'), H('chest')), a_chest))
                a_gen = a_chest
            else:
                piv = _som(hips, _rot(_dif(H('coscia_L'), H('hips')), be))
                a_gen = be
            sol = None
            if 'nodello' in z:
                d = _dif(z['nodello'], piv)
                f = self._piega(davanti, _lun(d))
                a1 = _ang(d) - _ang(self._u(davanti, f))
                a1 = (a1 + 180) % 360 - 180
                sol = (a1 - a_gen, f)
            if 'aria' in z:
                w = z.get('peso_aria', 1.0)
                sol = z['aria'] if sol is None else (sol[0] + (z['aria'][0] - sol[0]) * w, sol[1] + (z['aria'][1] - sol[1]) * w)
            rel1, f = sol
            a1 = a_gen + rel1
            terra, flesso = z.get('terra', 1.0), z.get('flesso', 0.0)
            if davanti:
                a_st = a1 + 0.45 * f
                out['spalla_' + lato] = [('X', rel1)]
                out['avambraccio_' + lato] = [('X', -0.55 * f)]
                out['stinco_a' + lato] = [('X', f)]
                out['piede_a' + lato] = [('X', terra * (-a_st) + (1 - terra) * flesso)]
            else:
                out['coscia_' + lato] = [('X', rel1)]
                out['gamba_' + lato] = [('X', f)]
                out['stinco_p' + lato] = [('X', -f)]
                out['piede_p' + lato] = [('X', terra * (-a1) + (1 - terra) * flesso)]
        return out

    def passo_zampa(self, davanti, phi, st, avanti, dietro, alto, affonda=0.03, flesso=50.0):
        """Nodello di una zampa nel suo ciclo (phi = 0 all'appoggio): in appoggio scorre indietro col terreno."""
        yr, zr = (self.a if davanti else self.p)['riposo']
        if phi < st:
            t = phi / st
            return dict(nodello=(yr - avanti + (avanti + dietro) * t, zr - affonda * math.sin(math.pi * t)), terra=1.0)
        s = (phi - st) / (1 - st)
        e = 0.5 - 0.5 * math.cos(math.pi * s)
        y = yr + dietro - (avanti + dietro) * e
        z = zr + alto * math.sin(math.pi * s ** 0.8) ** 1.3
        terra = max(0.0, 1 - s / 0.14) + max(0.0, (s - 0.9) / 0.1)
        return dict(nodello=(y, z), terra=min(1.0, terra), flesso=flesso * math.sin(math.pi * s ** 0.7) ** 1.2)


def anima(nome, arm, K):
    G = Andatura(K)
    TAU = 2 * math.pi
    sn, cs = math.sin, math.cos
    az = []

    def ciclo(az_nome, fotogrammi, fn):
        chiavi = [(i, G.posa(fn(i / fotogrammi))) for i in range(fotogrammi)]
        chiavi.append((fotogrammi, G.posa(fn(0.0))))
        return make_action(arm, f'{nome}:{az_nome}', chiavi, loop=True)

    def riposo():
        return {z: dict(nodello=(G.a if z[0] == 'a' else G.p)['riposo'], terra=1.0) for z in ('aL', 'aR', 'pL', 'pR')}

    # ------------------------------------------------ fermo: respiro, coda che scaccia, orecchie, testa che si muove
    def fermo(p):
        scatto = lambda c, l=0.05: math.exp(-((p - c) / l) ** 2)
        coda = 16 * sn(TAU * p * 3) * (scatto(0.22, 0.1) + scatto(0.7, 0.08))
        return dict(chest=0.9 * sn(TAU * p * 2), spine=0.5 * sn(TAU * p * 2 + 0.6), neck1=2.5 * sn(TAU * p) + 1.0 * sn(TAU * p * 2), neck2=1.5 * sn(TAU * p + 0.8),
                    head=2.5 * sn(TAU * p - 0.5), tail1=2 * sn(TAU * p), tail2=3 * sn(TAU * p - 0.6), tail3=4 * sn(TAU * p - 1.2), crini=2.5 * sn(TAU * p * 2 + 1),
                    ear_L=-22 * scatto(0.3, 0.035) + 10 * scatto(0.62, 0.05), ear_R=-22 * scatto(0.78, 0.035) + 8 * scatto(0.12, 0.05),
                    dz=0.004 * sn(TAU * p * 2), zampe=riposo(),
                    extra={'tail1': [('Z', coda)], 'tail2': [('Z', coda * 0.8)], 'tail3': [('Z', coda * 0.6)], 'head': [('Z', 5 * sn(TAU * p + 2))],
                           'neck2': [('Z', 4 * sn(TAU * p + 1.4))]})

    az.append(ciclo('fermo', 120, fermo))

    # ------------------------------------------------ passo: quattro tempi (posteriore, anteriore dello stesso lato...)
    def passo(p):
        td = {'pL': 0.0, 'aL': 0.25, 'pR': 0.5, 'aR': 0.75}
        z = {k: G.passo_zampa(k[0] == 'a', (p - v) % 1.0, 0.62, 0.3, 0.3, 0.15 if k[0] == 'a' else 0.11, 0.015, 35.0) for k, v in td.items()}
        return dict(dz=-0.012 + 0.01 * cs(2 * TAU * p), neck1=3.5 * sn(2 * TAU * p + 0.5), neck2=1.5 * sn(2 * TAU * p), head=-2 * sn(2 * TAU * p + 0.5),
                    spine=0.8 * sn(2 * TAU * p), tail1=3 + 3 * sn(TAU * p), tail2=4 * sn(TAU * p - 0.7), tail3=6 * sn(TAU * p - 1.4), crini=3 + 3 * sn(2 * TAU * p),
                    zampe=z, extra={'tail1': [('Z', 5 * sn(TAU * p))], 'tail2': [('Z', 6 * sn(TAU * p - 0.8))]})

    az.append(ciclo('passo', 30, passo))

    # ------------------------------------------------ corsa: galoppo a tre tempi con sospensione raccolta
    def galoppo(p):
        st = 0.25
        td = {'pL': 0.0, 'pR': 0.09, 'aL': 0.36, 'aR': 0.47}
        z = {}
        for k, v in td.items():
            dav = k[0] == 'a'
            z[k] = G.passo_zampa(dav, (p - v) % 1.0, st, 0.40 if dav else 0.56, 0.50 if dav else 0.36, 0.52 if dav else 0.36, 0.035, 60.0)
        be = -5.5 * cs(TAU * (p - 0.03))
        return dict(beccheggio=be, dz=0.035 * cs(TAU * (p - 0.86)) - 0.035, spine=4.0 * cs(TAU * (p - 0.85)), chest=3.0 * cs(TAU * (p - 0.85)),
                    neck1=14 - 0.5 * be + 5 * sn(TAU * (p - 0.3)), neck2=7 + 3 * sn(TAU * (p - 0.4)), head=-14 + 4 * sn(TAU * (p - 0.5)),
                    tail1=44 + 7 * sn(TAU * p), tail2=4 + 11 * sn(TAU * (p - 0.2)), tail3=-10 + 15 * sn(TAU * (p - 0.4)),
                    crini=24 + 9 * sn(2 * TAU * p), ear=-26, zampe=z)

    az.append(ciclo('corsa', 14, galoppo))

    # ------------------------------------------------ impennata: si raccoglie, si alza sui posteriori, scalcia l'aria, ricade
    N = 40
    chiavi = []
    for i in range(N + 1):
        su = _chiavi([(0, 0.0), (5, -0.08), (15, 0.95), (19, 1.0), (24, 0.95), (33, 0.0), (36, -0.05), (40, 0.0)], i)
        aria = _chiavi([(6, 0.0), (11, 1.0), (27, 1.0), (32, 0.0)], i)
        z = riposo()
        for k, fase in (('aL', 0.0), ('aR', 1.9)):
            z[k]['aria'] = (-28 + 14 * sn(i * 0.55 + fase), 100 + 22 * sn(i * 0.55 + fase + 1.2))
            z[k]['peso_aria'] = aria
            z[k]['terra'] = 1 - aria
            z[k]['flesso'] = 35.0
        be = -46 * su
        alto = max(0.0, su)
        chiavi.append((i, G.posa(dict(beccheggio=be, dz=-0.11 * alto - 0.4 * max(0.0, -su), dy=0.1 * alto, spine=-5 * alto, chest=-4 * alto,
                                      neck1=16 * su, neck2=10 * su, head=12 * su, tail1=-0.8 * be, tail2=6 * su, tail3=8 * su, crini=-0.45 * be, ear=-18 * alto,
                                      zampe=z))))
    az.append(make_action(arm, f'{nome}:impennata', chiavi))
    stash_actions(arm, az)
    return az


# ====================================================================== finimenti
TRONCO = {'hips', 'spine', 'chest'}
X = Vector((1, 0, 0))
Z = Vector((0, 0, 1))


def asse_tronco(y0, y1, z=1.2):
    return [(y0, z), (y1, z)]


def asse_testa(K, t0, t1):
    return [punto_testa(K, t0), punto_testa(K, t1)]


def asse_petto(z0, z1, y=-0.5):
    """Asse verticale dentro il petto: angolo 0 = davanti, positivo verso il fianco sinistro."""
    return [(y, z0), (y, z1)]


def attorno(K, centro, tang, angoli, off=0.02, R=0.7):
    """Punti sulla pelle attorno a un asse (centro, tangente nel piano sagittale): [(punto, direzione verso fuori)]."""
    c = Vector((0, centro[0], centro[1])) if len(centro) == 2 else Vector(centro)
    t = Vector((0, tang[0], tang[1])).normalized() if len(tang) == 2 else Vector(tang).normalized()
    nrm = Vector((0, t.z, -t.y))
    out = []
    for a in angoli:
        th = math.radians(a)
        d = nrm * math.cos(th) + X * math.sin(th)
        h = K.pelle.raggio(c + d * R, -d, R)
        out.append(((h[0] + d * off) if h else c + d * off, d))
    return out


def libero(p, quanto=1.0):
    """Il pezzo dondola un poco (nappe, pendenti, talismani)."""
    p.lib = [quanto] * len(p.v)
    return p


def p_arcione(K, y, alto, spess, slot, ang=60.0, inclina=0.0, n=8, tondo=0.7):
    """Arco della sella (arcione davanti, paletta dietro): tavola curva posata sul dorso, più alta al centro."""
    p = Pezzo(slot, ('corpo', TRONCO))
    linee = [[], [], [], []]
    for j in range(n + 1):
        a = -ang + 2 * ang * j / n
        th = math.radians(a)
        d = Z * math.cos(th) + X * math.sin(th)
        h = alto * max(0.0, math.cos(math.radians(a / ang * 90.0))) ** tondo + 0.012
        basi = []
        for yy in (y - spess / 2, y + spess / 2):
            c = Vector((0, yy, 1.2))
            hit = K.pelle.raggio(c + d * 0.9, -d, 0.9)
            basi.append((hit[0] if hit else c + d * 0.3) + d * 0.012)
        su = d * h + Vector((0, inclina * h, 0))
        linee[0].append(p.punto(basi[0], 0.0, h))
        linee[1].append(p.punto(basi[0] + su, 0.0, 0.0))
        linee[2].append(p.punto(basi[1] + su, 0.0, 0.0))
        linee[3].append(p.punto(basi[1], 0.0, h))
    p.griglia(linee)
    p.aperto = True
    return p


def p_nappa(c, lung, r, ossa, slot='regno', slot_nodo='oro'):
    c = Vector(c)
    return [libero(p_sfera(c, r * 0.8, slot_nodo, ossa, seg=5, rings=3), 0.5),
            libero(p_cono(c - Z * lung, c - Z * r * 0.3, r * 1.35, slot, ossa, seg=5, r2=r * 0.5))]


def p_anello(c, asse, r, rt, slot, ossa, n=8, lati=3):
    c, asse = Vector(c), Vector(asse).normalized()
    a = asse.orthogonal().normalized()
    b = asse.cross(a)
    pts = [c + (a * math.cos(2 * math.pi * j / n) + b * math.sin(2 * math.pi * j / n)) * r for j in range(n + 1)]
    return p_tubo3d(pts, rt, slot, ossa, lati=lati, n=n)


def p_placca(c, d, r, slot, ossa, spess=0.35, seg=6):
    """Placca tonda piatta (giada, specchio, disco) appoggiata con la faccia verso d."""
    bm = sphere((0, 0, 0), r, (1.0, 1.0, spess), seg=seg, rings=3)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Z.rotation_difference(Vector(d).normalized()).to_matrix())
    bmesh.ops.translate(bm, vec=Vector(c), verts=bm.verts)
    return p_da_bm(bm, slot, ossa)


def base_finimenti(K, stile):
    """Seggio, quartieri, sottopancia, staffe, testiera e redini: ciò che ogni destriero porta a tutti i livelli."""
    out = []
    s_cuoio, s_metallo = stile.get('cuoio', 'cuoio'), stile.get('metallo', 'metallo')
    s_cinghie = stile.get('cinghie_slot', s_cuoio)
    out.append(p_avvolgi(K, asse_tronco(0.15, -0.37), -56, 56, 5, 6, lambda s, a: 0.03 + 0.014 * math.sin(math.pi * a), s_cuoio, ('corpo', TRONCO)))
    for k in (1, -1):
        out.append(p_avvolgi(K, asse_tronco(0.02, -0.3), 52 * k, 108 * k, 2, 3, 0.03, s_cuoio, ('corpo', TRONCO)))
    out.append(p_avvolgi(K, asse_tronco(-0.27, -0.335), 0, 360, 1, 14, 0.016, s_cinghie, ('corpo', {'spine', 'chest'}), bordo_u=False))
    for k in (1, -1):
        x = K.pelle.mezza(-0.2, 1.2) + 0.025
        st = ('corpo', {'spine', 'chest'})
        out.append(p_tubo3d([Vector((k * (x - 0.02), -0.2, 1.28)), Vector((k * x, -0.21, 1.05)), Vector((k * (x + 0.005), -0.22, 0.86))], 0.011, s_cinghie, st, lati=3, n=3))
        arco = [Vector((k * (x + 0.005), -0.22 + dy, 0.86 - dz)) for dy, dz in ((0, 0), (0.05, 0.03), (0.062, 0.1), (0.055, 0.135), (-0.055, 0.135), (-0.062, 0.1), (-0.05, 0.03), (0, 0))]
        out.append(p_tubo3d(arco, 0.011, s_metallo, st, lati=3, n=8))
        out.append(p_da_bm(sphere((k * (x + 0.005), -0.22, 0.722), 1.0, (0.035, 0.062, 0.01), seg=5, rings=2), s_metallo, st))
    # testiera
    larg = stile.get('cinghie', 0.022)
    corda = stile.get('testiera') == 'corda'
    if corda:
        # cavezza di corda: giri grossi attorno al muso e dietro le orecchie
        for t, n_p, r in ((0.43, 8, 0.011), (0.0, 8, 0.011)):
            pts = [q for q, _ in attorno(K, punto_testa(K, t), K.A['hdir'], [360.0 * j / n_p for j in range(n_p + 1)], 0.008, R=0.4)]
            out.append(p_tubo3d(pts, r, 'corda', 'head', lati=4, n=n_p))
        for k in (1, -1):
            out.append(p_tubo3d([K.pelle.fuori(punto_testa(K, t, dd, ll * k), 0.008) for t, dd, ll in ((0.0, 0.0, 0.085), (0.2, -0.03, 0.11), (0.43, -0.03, 0.08))], 0.01, 'corda', 'head', lati=4, n=4))
    else:
        out.append(p_avvolgi(K, asse_testa(K, 0.42, 0.42 + larg * 1.3), 0, 360, 1, 10, 0.007, s_cinghie, 'head', R=0.4, bordo_u=False))          # capezzina
        out.append(p_avvolgi(K, asse_testa(K, 0.075, 0.075 + larg * 1.2), -78, 78, 1, 5, 0.008, s_cinghie, 'head', R=0.4, bordo_u=False))      # frontalino
        out.append(p_avvolgi(K, asse_testa(K, -0.015, -0.015 + larg * 1.2), -175, 175, 1, 8, 0.008, s_cinghie, ('corpo', {'head', 'neck2'}), R=0.4, bordo_u=False))
    for k in (1, -1):
        if not corda:
            out.append(p_cinghia(K, [punto_testa(K, 0.07, 0.02, 0.105 * k), punto_testa(K, 0.25, -0.03, 0.1 * k), punto_testa(K, 0.43, -0.03, 0.075 * k)], larg, s_cinghie, 'head', n=4))
        c = punto_testa(K, 0.5, -0.045, 0.062 * k)
        c = K.pelle.vicino(c)[0] + Vector((0.012 * k, 0, 0))
        if not corda:
            out.append(p_anello(c, X, 0.026, 0.006, s_metallo, 'head', n=6, lati=3))
            out.append(p_cinghia(K, [punto_testa(K, 0.43, -0.03, 0.075 * k), c], larg * 0.8, s_cinghie, 'head', n=2))
        else:
            c = K.pelle.fuori(punto_testa(K, 0.43, -0.05, 0.075 * k), 0.012)
        # redine: dal morso all'arcione, con un po' di pancia
        fine = Vector((0.05 * k, -0.37, K.pelle.dorso(-0.37) + 0.1))
        medio = c.lerp(fine, 0.5) + Vector((0.11 * k, 0.0, -0.12))
        red = p_tubo3d([c, c.lerp(medio, 0.5) + Vector((0.05 * k, 0, -0.03)), medio, fine], 0.008 if not corda else 0.01, stile.get('redini', s_cinghie), None, lati=3, n=6)
        red.pesi = []
        for v in red.v:
            f = _liscio((v - c).length / max(1e-6, (fine - c).length))
            red.pesi.append({'head': (1 - f) * 0.8, 'neck2': (1 - f) * 0.2, 'chest': f} if f < 0.999 else {'chest': 1.0})
        out.append(red)
    return out


def pettorale(K, slot, larg=0.06, z=1.23, ang=112, off=0.012):
    return p_avvolgi(K, asse_petto(z + larg / 2, z - larg / 2), -ang, ang, 1, 12, off, slot, ('corpo', {'chest', 'spine'}))


def sul_petto(K, angoli, z=1.2, off=0.02):
    return attorno(K, (-0.5, z), (0, -1), angoli, off)


def groppiera_cinghie(K, slot, larg=0.035):
    """Cinghie della groppa: lungo la schiena fino alla coda e giù sui fianchi."""
    out = [p_cinghia(K, [Vector((0, y, K.pelle.dorso(y))) for y in (0.16, 0.4, 0.62, 0.8)], larg, slot, ('corpo', {'hips', 'spine'}), n=5)]
    for k in (1, -1):
        out.append(p_cinghia(K, [Vector((0, 0.55, K.pelle.dorso(0.55))), Vector((k * 0.2, 0.57, 1.5)), Vector((k * 0.3, 0.6, 1.28)), Vector((k * 0.27, 0.62, 1.12))], larg, slot, ('corpo', {'hips'}), n=5))
    return out


# ---------------------------------------------------------------------- Lama: barda da guerra a lamelle laccate
def finimenti_lama(K):
    stile = dict(cuoio='cuoio', metallo='metallo')
    out = [(1, 4, base_finimenti(K, stile))]
    # 1: coperta corta nel colore del regno, arcioni bassi di cuoio
    out.append((1, 1, [p_drappo(K, -0.44, 0.24, 1.14, 5, 4, 0.014, 'regno'),
                       p_arcione(K, -0.38, 0.07, 0.05, 'cuoio', inclina=-0.3), p_arcione(K, 0.16, 0.08, 0.05, 'cuoio', inclina=0.4)]))
    # 2+: sella laccata con arcioni alti, pettorale borchiato con lo specchio, groppiera di cinghie
    p2 = [p_arcione(K, -0.39, 0.13, 0.05, 'lacca', inclina=-0.25), p_arcione(K, 0.17, 0.15, 0.05, 'lacca', inclina=0.45, ang=66),
          pettorale(K, 'cuoio', 0.07)]
    for q, d in sul_petto(K, [-90, -60, -30, 30, 60, 90], 1.23, 0.022):
        p2.append(p_sfera(q, 0.016, 'oro', 'chest', seg=4, rings=2))
    q, d = sul_petto(K, [0], 1.22, 0.022)[0]
    p2.append(p_placca(q, d, 0.075, 'metallo', 'chest'))
    p2.append(p_placca(q + d * 0.012, d, 0.04, 'oro', 'chest'))
    p2 += groppiera_cinghie(K, 'cuoio')
    out.append((2, 4, p2))
    out.append((2, 2, [p_drappo(K, -0.45, 0.3, 1.04, 5, 4, 0.014, 'regno')]))
    # 3+: gualdrappa del regno, pettiera a lamelle, frontale di ferro, nappa rossa sotto la gola
    p3 = [p_drappo(K, -0.46, 0.5, lambda y: 0.9 + 0.5 * (y - 0.02) ** 2, 8, 5, 0.014, 'regno', svaso=0.03),
          p_avvolgi(K, asse_petto(1.36, 0.99, -0.46), -98, 98, 6, 10, 0.022, 'lamelle', ('corpo', {'chest', 'neck1'}), file=3, gradino=0.028),
          p_avvolgi(K, asse_testa(K, 0.035, 0.5), -72, 72, 4, 6, lambda s, a: 0.012 + 0.014 * math.exp(-((a - 0.5) / 0.12) ** 2), 'metallo', 'head', R=0.4)]
    q = punto_testa(K, 0.2, 0.11, 0)
    p3.append(p_placca(K.pelle.fuori(q, 0.03), K.A['hup'], 0.035, 'oro', 'head'))
    q = K.pelle.fuori(punto_testa(K, 0.1, -0.24, 0), 0.03)
    p3 += p_nappa(q, 0.2, 0.035, 'head', 'stoffa')
    out.append((3, 4, p3))
    out.append((3, 3, [p_avvolgi(K, asse_tronco(0.3, 0.62, 1.25), 85, 275, 4, 10, 0.022, 'lamelle', ('corpo', {'hips', 'spine'}), file=2, gradino=0.025)]))
    # 4: groppa e gola coperte di lamelle, frontale con la lama e i guanciali, pennacchio, anello d'oro alla coda
    p4 = [p_avvolgi(K, asse_tronco(0.28, 0.84, 1.25), 78, 282, 8, 12, 0.022, 'lamelle', ('corpo', {'hips', 'spine'}), file=4, gradino=0.025),
          p_avvolgi(K, asse_collo(K, 0.06, 0.74), 92, 268, 8, 8, 0.02, 'lamelle', ('corpo', {'neck1', 'neck2', 'chest'}), file=4, gradino=0.022)]
    # lama sulla fronte: cresta d'acciaio a mezzaluna lungo il naso (non un corno)
    fr = [punto_testa(K, t, dd, 0) for t, dd in ((0.02, 0.12), (0.1, 0.2), (0.22, 0.2), (0.33, 0.125))]
    lama = Pezzo('metallo', 'head')
    base = [punto_testa(K, t, 0.1, 0) for t in (0.02, 0.1, 0.22, 0.33)]
    for k in (1, -1):
        r0 = [lama.punto(b + X * 0.012 * k, 0.0, 0.05) for b in base]
        r1 = [lama.punto(f, 0.0, 0.0) for f in fr]
        lama.griglia([r0, r1] if k > 0 else [r1, r0])
    lama.aperto = True
    p4.append(lama)
    for k in (1, -1):
        # guanciali e corna di ferro ai lati della fronte
        p4.append(p_avvolgi(K, asse_testa(K, 0.08, 0.3), 75 * k, 150 * k, 2, 3, 0.012, 'metallo', 'head', R=0.4))
        b = K.pelle.fuori(punto_testa(K, 0.04, 0.07, 0.085 * k), 0.01)
        p4.append(p_cono(b, b + Vector((0.1 * k, 0.03, 0.2)), 0.03, 'oro', 'head', seg=4, schiaccia=0.5))
    # pennacchio rosso sulla nuca
    nuca = punto_testa(K, -0.01, 0.07, 0)
    for j, (dy, dz, ll) in enumerate(((0.05, 0.3, 1.0), (0.14, 0.24, 0.85), (-0.02, 0.26, 0.8))):
        p4.append(p_ciocca(K, [nuca, nuca + Vector((0, dy * 0.4, dz * 0.6)), nuca + Vector((0, dy * 1.4 + 0.08, dz)) * ll], 0.045, 0.012, 0.02, 'stoffa', 'head', n=3,
                           piatto=Vector((1, 0, 0))))
    p4.append(p_anello((0, 0.93, 1.35), (0, 0.6, -0.8), 0.055, 0.013, 'oro', 'tail1'))
    # stendardi del regno ai lati della paletta
    for k in (1, -1):
        b = Vector((0.2 * k, 0.2, K.pelle.dorso(0.2, 0.2 * k) + 0.02))
        cima = b + Vector((0.015 * k, 0.07, 0.6))
        p4.append(p_tubo3d([b, cima], 0.009, 'oro', ('corpo', {'hips', 'spine'}), lati=3, n=2))
        p4.append(p_sfera(cima, 0.02, 'oro', ('corpo', {'hips', 'spine'}), seg=4, rings=2))
        band = Pezzo('regno', ('corpo', {'hips', 'spine'}))
        alto0, alto1 = cima - Vector((0, 0, 0.03)), cima - Vector((0, 0, 0.2))
        righe = []
        for i in range(4):
            f = i / 3
            centro = alto0.lerp(alto1, 0.5) + Vector((0, 0.3 * f, -0.05 * f * f))
            mezzo = 0.085 * (1 - f) + 0.004
            righe.append([band.punto(centro + Vector((0, 0, mezzo)), 0.3 * f, 0.0, f), band.punto(centro, 0.3 * f, mezzo, f), band.punto(centro - Vector((0, 0, mezzo)), 0.3 * f, 0.0, f)])
        band.griglia(righe)
        band.aperto = True
        p4.append(band)
    out.append((4, 4, p4))
    return out


# ---------------------------------------------------------------------- Ombra: cuoio scuro, borchie, maschera e lame
def finimenti_ombra(K):
    stile = dict(cuoio='cuoio', metallo='metallo', redini='corda', cinghie=0.018)
    out = [(1, 4, base_finimenti(K, stile))]
    out.append((1, 1, [p_drappo(K, -0.42, 0.2, 1.16, 5, 4, 0.014, 'stoffa')]))
    # 2+: pettorale con le punte, bisacce, coperta dall'orlo a denti
    p2 = [pettorale(K, 'cuoio', 0.055), p_arcione(K, -0.38, 0.06, 0.04, 'cuoio', inclina=-0.3), p_arcione(K, 0.16, 0.07, 0.04, 'cuoio', inclina=0.4)]
    for q, d in sul_petto(K, [-80, -53, -27, 0, 27, 53, 80], 1.23, 0.014):
        p2.append(p_cono(q, q + d * 0.06, 0.016, 'metallo', 'chest', seg=4))
    for k in (1, -1):
        x = K.pelle.mezza(0.24, 1.3)
        p2.append(p_sfera((k * (x + 0.05), 0.26, 1.28), 1.0, 'cuoio', ('corpo', {'hips', 'spine'}), scala=(0.06, 0.13, 0.11), seg=6, rings=4))
        p2.append(p_cinghia(K, [Vector((k * 0.05, 0.25, 1.6)), Vector((k * 0.2, 0.26, 1.5)), Vector((k * x, 0.26, 1.36))], 0.03, 'cuoio', ('corpo', {'hips', 'spine'}), n=3))
    out.append((2, 4, p2))
    dente = lambda y: 1.06 + 0.07 * abs(((y + 0.42) / 0.16) % 2.0 - 1.0)
    out.append((2, 3, [p_drappo(K, -0.42, 0.38, dente, 10, 4, 0.014, 'stoffa')]))
    # 3+: maschera di cuoio con le lame, collare con le punte e la sciarpa del regno
    p3 = [p_avvolgi(K, asse_testa(K, 0.03, 0.4), -98, 98, 3, 8, 0.011, 'metallo', 'head', R=0.4)]
    for k in (1, -1):
        b = K.pelle.fuori(punto_testa(K, 0.09, 0.075, 0.07 * k), 0.008)
        p3.append(p_cono(b, b + Vector((0.07 * k, 0.16, 0.2)), 0.032, 'metallo', 'head', seg=4, schiaccia=0.3))
        for t in (0.2, 0.3):
            q = K.pelle.fuori(punto_testa(K, t, 0.08, 0.035 * k), 0.016)
            p3.append(p_sfera(q, 0.011, 'oro', 'head', seg=4, rings=2))
    staz, _ = _asse([Vector((0, c[0], c[1])) for c in K.A['collo'][:-1]], 24)
    c, t, nrm = staz[4]
    p3.append(p_avvolgi(K, [staz[3][0], staz[5][0]], 0, 360, 1, 10, 0.014, 'cuoio', ('corpo', {'neck1', 'chest'}), R=0.6, bordo_u=False))
    for q, d in attorno(K, c, t, [-140, -100, -60, 60, 100, 140, 180], 0.016, R=0.6):
        p3.append(p_cono(q, q + d * 0.075, 0.018, 'metallo', ('corpo', {'neck1', 'chest'}), seg=4))
    q, d = attorno(K, c, t, [152], 0.02, R=0.6)[0]
    sc = p_cinghia(K, [q, q + Vector((0.03, 0.03, -0.2)), q + Vector((0.05, 0.08, -0.42))], 0.07, 'regno', ('corpo', {'neck1', 'chest'}), n=3, libera=True)
    for i, v in enumerate(sc.v):
        sc.lib[i] = min(1.0, (q.z - v.z) / 0.4)
    p3.append(sc)
    out.append((3, 4, p3))
    # 4: mantello lacero sulla groppa, lame lungo la cresta del collo, pugnali alla sella, catene
    strappi = lambda y: 0.86 + 0.16 * abs(((y - 0.1) / 0.11) % 2.0 - 1.0) * (0.6 + 0.4 * math.sin(y * 23.0))
    p4 = [p_drappo(K, 0.1, 0.86, strappi, 14, 5, 0.022, 'stoffa', ('corpo', {'hips', 'spine'}), svaso=0.05)]
    for i in range(5):
        c, nrm, t = cresta(K, 0.2 + 0.16 * i)
        d = (nrm - t * 0.7).normalized()
        p4.append(p_cono(c - d * 0.02, c + d * (0.24 + 0.04 * math.sin(i * 1.9)), 0.05, 'metallo', ('corpo', {'neck1', 'neck2'}), seg=4, schiaccia=0.22))
    for k in (1, -1):
        x = K.pelle.mezza(-0.34, 1.3) + 0.045
        b = Vector((k * x, -0.36, 1.36))
        p4.append(p_cono(b + Vector((0, 0.03, -0.3)), b, 0.022, 'cuoio', ('corpo', {'chest', 'spine'}), seg=4, r2=0.03, schiaccia=0.5))          # fodero
        p4.append(p_cono(b, b + Vector((0, -0.02, 0.12)), 0.014, 'metallo', ('corpo', {'chest', 'spine'}), seg=4, r2=0.012))                   # elsa
        p4.append(p_sfera(b + Vector((0, -0.022, 0.13)), 0.02, 'oro', ('corpo', {'chest', 'spine'}), seg=4, rings=2))
    out.append((4, 4, p4))
    return out


# ---------------------------------------------------------------------- Monaco: corde, grani, nappe, sonagli, oro
def finimenti_monaco(K):
    stile = dict(cuoio='cuoio', metallo='oro', cinghie_slot='corda', testiera='corda', redini='corda')
    out = [(1, 4, base_finimenti(K, stile))]
    out.append((1, 1, [p_drappo(K, -0.44, 0.24, 1.14, 5, 4, 0.014, 'stoffa')]))
    # 2+: coperta grande arancio, arcioni di legno, corda sul petto con i grani e la nappa
    p2 = [p_drappo(K, -0.46, 0.34, 1.0, 5, 5, 0.014, 'stoffa', svaso=0.02),
          p_arcione(K, -0.38, 0.1, 0.06, 'grani', inclina=-0.25, tondo=0.45), p_arcione(K, 0.16, 0.1, 0.06, 'grani', inclina=0.35, tondo=0.45)]
    giro = sul_petto(K, [-112 + 224 * j / 12 for j in range(13)], 1.22, 0.02)
    p2.append(p_tubo3d([q for q, _ in giro], 0.014, 'corda', ('corpo', {'chest', 'spine'}), lati=4, n=12))
    for q, d in sul_petto(K, [-66, -44, -22, 0, 22, 44, 66], 1.215, 0.035):
        p2.append(p_sfera(q, 0.034, 'grani', 'chest', seg=5, rings=3))
    q, d = sul_petto(K, [0], 1.17, 0.04)[0]
    p2 += p_nappa(q, 0.2, 0.04, 'chest', 'regno')
    out.append((2, 4, p2))
    # 3+: collana di grani grossi alla base del collo, sonagli, nappe alla cavezza, stuoia arrotolata dietro la sella
    staz, _ = _asse([Vector((0, c[0], c[1])) for c in K.A['collo'][:-1]], 24)
    c, t, nrm = staz[3]
    p3 = []
    for q, d in attorno(K, c, t, [360.0 * j / 13 + 14 for j in range(13)], 0.05, R=0.7):
        p3.append(p_sfera(q, 0.047, 'grani', ('corpo', {'neck1', 'chest'}), seg=5, rings=3))
    for q, d in sul_petto(K, [-30, 30], 1.1, 0.03):
        p3.append(libero(p_sfera(q, 0.036, 'oro', 'chest', seg=5, rings=3), 0.5))
        p3.append(p_tubo3d([q, q + Vector((0, 0, 0.1))], 0.006, 'corda', 'chest', lati=3, n=1))
    for k in (1, -1):
        q = K.pelle.fuori(punto_testa(K, 0.2, -0.05, 0.11 * k), 0.02)
        p3 += p_nappa(q, 0.16, 0.03, 'head', 'regno')
    yd = 0.26
    zd = K.pelle.dorso(yd) + 0.075
    p3.append(p_tubo3d([Vector((-0.3, yd, zd - 0.07)), Vector((-0.15, yd, zd)), Vector((0.15, yd, zd)), Vector((0.3, yd, zd - 0.07))], 0.07, 'stoffa', ('corpo', {'hips', 'spine'}), lati=6, n=5))
    for xx in (-0.2, 0.2):
        p3.append(p_anello((xx, yd, zd - 0.02), X, 0.075, 0.01, 'corda', ('corpo', {'hips', 'spine'}), n=6))
    out.append((3, 4, p3))
    # 4: anelli d'oro alle zampe, disco del sole sulla fronte, corde con le nappe sulla groppa, anello alla coda, fiamma d'oro sull'arcione
    p4 = []
    za = K.P['zampe']
    for k in (1, -1):
        lato = 'L' if k > 0 else 'R'
        for (y, x, osso) in ((-0.54, K.A['sx_a'] * 0.985 * k, 'stinco_a'), (0.797, K.A['sx_p'] * 0.975 * k, 'stinco_p')):
            for zz in (0.3, 0.345):
                p4.append(p_anello((x, y + 0.003, zz), Z, 0.05 * za, 0.014, 'oro', osso + lato, n=6))
    q = K.pelle.fuori(punto_testa(K, 0.13, 0.1, 0), 0.02)
    p4.append(p_placca(q, K.A['hup'], 0.06, 'oro', 'head', seg=8))
    for j in range(8):
        a = 2 * math.pi * j / 8
        d = (X * math.cos(a) + K.A['hdir'] * math.sin(a))
        p4.append(p_cono(q + d * 0.05, q + d * 0.1, 0.014, 'oro', 'head', seg=3))
    p4 += groppiera_cinghie(K, 'corda', 0.03)
    for k in (1, -1):
        for (xx, yy, zz) in ((0.27, 0.62, 1.1), (0.2, 0.57, 1.47)):
            q = K.pelle.fuori(Vector((k * xx, yy, zz)), 0.03)
            p4 += p_nappa(q, 0.2, 0.036, 'hips', 'regno')
    p4.append(p_anello((0, 0.93, 1.35), (0, 0.6, -0.8), 0.055, 0.016, 'oro', 'tail1'))
    p4 += p_nappa((0, 0.99, 1.26), 0.16, 0.035, 'tail1', 'regno')
    b = Vector((0, -0.4, K.pelle.dorso(-0.4) + 0.1))
    for (dx, hh) in ((0, 0.2), (-0.05, 0.13), (0.05, 0.13)):
        p4.append(p_cono(b + Vector((dx, 0, 0)), b + Vector((dx * 1.6, -0.03, hh)), 0.035, 'oro', ('corpo', {'chest', 'spine'}), seg=4, schiaccia=0.45))
    out.append((4, 4, p4))
    return out


# ---------------------------------------------------------------------- Mistico: gualdrappa ricamata, giada, talismani
def finimenti_mistico(K):
    stile = dict(cuoio='cuoio', metallo='oro', cinghie=0.016)
    out = [(1, 4, base_finimenti(K, stile))]
    out.append((1, 1, [p_drappo(K, -0.44, 0.24, 1.14, 5, 4, 0.014, 'stoffa')]))
    # 2+: gualdrappa lunga ricamata con le nappe agli angoli, arcioni laccati
    p2 = [p_drappo(K, -0.46, 0.44, lambda y: 0.86 + 0.6 * (y + 0.01) ** 2, 8, 6, 0.014, 'stoffa', svaso=0.03),
          p_arcione(K, -0.39, 0.11, 0.045, 'lacca', inclina=-0.25), p_arcione(K, 0.17, 0.12, 0.045, 'lacca', inclina=0.4)]
    for k in (1, -1):
        for yy in (-0.46, 0.44):
            x = K.pelle.mezza(yy, 0.95)
            xm = max(K.pelle.mezza(yy, 0.9 + 0.1 * j) for j in range(7)) + 0.05
            p2 += p_nappa((k * xm, yy, 0.9), 0.16, 0.03, ('corpo', TRONCO), 'regno')
    out.append((2, 4, p2))
    # 3+: pettorale del regno con i pendenti di giada, disco di giada sulla fronte, talismani al collo
    p3 = [pettorale(K, 'regno', 0.07)]
    for q, d in sul_petto(K, [-70, -35, 0, 35, 70], 1.15, 0.024):
        p3.append(libero(p_placca(q, d, 0.042, 'giada', 'chest'), 0.4))
        p3.append(p_tubo3d([q + Z * 0.035, q + Z * 0.07], 0.005, 'oro', 'chest', lati=3, n=1))
    q = K.pelle.fuori(punto_testa(K, 0.13, 0.1, 0), 0.018)
    p3.append(p_placca(q, K.A['hup'], 0.052, 'oro', 'head', seg=8))
    p3.append(p_placca(q + K.A['hup'] * 0.012, K.A['hup'], 0.036, 'giada', 'head', seg=6))
    staz, _ = _asse([Vector((0, c[0], c[1])) for c in K.A['collo'][:-1]], 24)
    c, t, nrm = staz[5]
    giro = attorno(K, c, t, [360.0 * j / 10 for j in range(11)], 0.012, R=0.6)
    p3.append(p_tubo3d([q for q, _ in giro], 0.009, 'oro', ('corpo', {'neck1', 'chest'}), lati=3, n=10))
    for q, d in attorno(K, c, t, [-150, -110, 110, 150], 0.02, R=0.6):
        tl = p_cinghia(K, [q, q - Z * 0.11, q - Z * 0.22], 0.07, 'carta', ('corpo', {'neck1', 'chest'}), n=2, libera=True)
        for i, v in enumerate(tl.v):
            tl.lib[i] = min(1.0, (q.z - v.z) / 0.2)
            tl.d[i] = min(tl.d[i], (q.z - v.z), 0.22 - (q.z - v.z))
        p3.append(tl)
    out.append((3, 4, p3))
    # 4: drappo del regno sulla groppa, diadema di giada con la mezzaluna, nastri, anelli di giada alla coda
    p4 = [p_drappo(K, 0.2, 0.86, 0.8, 5, 5, 0.03, 'regno', ('corpo', {'hips', 'spine'}), svaso=0.07)]
    nuca = punto_testa(K, 0.03, 0.085, 0)
    for j, a in enumerate((-55, -28, 0, 28, 55)):
        th = math.radians(a)
        b = K.pelle.fuori(punto_testa(K, 0.035, 0.085 * math.cos(th), 0.1 * math.sin(th)), 0.008)
        alt = (0.17, 0.11, 0.08, 0.11, 0.17)[j]
        p4.append(p_cono(b, b + (K.A['hup'] * 0.8 + Z * 0.5 + X * 0.35 * math.sin(th)).normalized() * alt, 0.022, 'giada' if j % 2 == 0 else 'oro', 'head', seg=4, schiaccia=0.5))
    # mezzaluna d'oro sopra il disco
    q = K.pelle.fuori(punto_testa(K, 0.13, 0.1, 0), 0.02)
    luna = [q + K.A['hup'] * 0.02 + (X * math.sin(a) * 0.085 - K.A['hdir'] * (math.cos(a) * 0.085 - 0.02)) for a in [math.radians(v) for v in (-115, -75, -35, 0, 35, 75, 115)]]
    p4.append(p_tubo3d(luna, lambda f: 0.004 + 0.012 * math.sin(math.pi * f), 'oro', 'head', lati=3, n=8))
    for k in (1, -1):
        b = Vector((0.16 * k, 0.2, K.pelle.dorso(0.2, 0.16 * k) + 0.05))
        xm = K.pelle.mezza(0.3, 1.2) + 0.09
        n_ = p_cinghia(K, [b, Vector((k * xm, 0.3, 1.25)), Vector((k * (xm + 0.03), 0.36, 0.95)), Vector((k * (xm + 0.02), 0.42, 0.66))], 0.06, 'stoffa', ('corpo', {'hips', 'spine'}), n=5, libera=True)
        for i, v in enumerate(n_.v):
            n_.lib[i] = max(0.0, min(1.0, (1.3 - v.z) / 0.6))
        p4.append(n_)
        p4.append(libero(p_placca(Vector((k * (xm + 0.02), 0.42, 0.63)), X * k, 0.04, 'giada', ('corpo', {'hips'}))))
    for (yy, zz, r) in ((0.93, 1.35, 0.055), (1.0, 1.2, 0.05)):
        p4.append(p_anello((0, yy, zz), (0, 0.5, -0.85), r, 0.013, 'giada', 'tail1'))
    for q, d in sul_petto(K, [-52, -17, 17, 52], 1.1, 0.024):
        p4.append(libero(p_placca(q, d, 0.03, 'oro', 'chest'), 0.4))
    out.append((4, 4, p4))
    return out


def finimenti(K):
    """Finimenti della classe per passo: lista di (da, a, [Pezzi])."""
    return {'lama': finimenti_lama, 'ombra': finimenti_ombra, 'monaco': finimenti_monaco, 'mistico': finimenti_mistico}[K.nome](K)


# ====================================================================== classi
CRINI_BASE = dict(stile='folta', n=8, lung=0.32, lati=2, ciuffo=0.16, coda=(0.95, 7, 0.06))
CLASSI = {
    # destriero da guerra: massiccio, collo potente, zampe forti con le barbette
    'lama': dict(BASE, tronco=1.12, fondo=1.06, zampe=1.22, collo=1.2, collo_alto=0.0, testa=1.04, muscoli=1.2,
                 crini=dict(CRINI_BASE, n=10, lung=0.36, larg=0.09, barbette=1.0, coda=(1.0, 7, 0.075))),
    # corsiero d'ombra: asciutto, zampe lunghe e sottili, ventre retratto, criniera rasata a cresta
    'ombra': dict(BASE, tronco=0.9, fondo=0.95, zampe=0.92, collo=0.88, collo_alto=0.35, testa=0.95, muscoli=0.9, ventre=0.93,
                  crini=dict(CRINI_BASE, stile='cresta', n=15, lung=0.13, ciuffo=0.0, coda=(1.05, 6, 0.05))),
    # sauro robusto: compatto, collo forte portato più basso
    'monaco': dict(BASE, tronco=1.08, fondo=1.04, zampe=1.12, collo=1.12, collo_alto=-0.5, testa=1.06, muscoli=1.1,
                   crini=dict(CRINI_BASE, lung=0.26, larg=0.085, spess=0.016, n=9, ciuffo=0.12, coda=(0.85, 7, 0.07))),
    # bianco slanciato: collo alto e arcuato, crini lunghissimi
    'mistico': dict(BASE, tronco=0.95, fondo=0.97, zampe=0.95, collo=0.92, collo_alto=0.8, testa=0.93, muscoli=0.95,
                    crini=dict(CRINI_BASE, lung=0.62, larg=0.09, n=10, lati=2, ciuffo=0.26, coda=(1.3, 8, 0.07))),
}

COLORI_ANTEPRIMA = {0: (0.55, 0.36, 0.22), 1: (0.12, 0.1, 0.1), 2: (0.2, 0.18, 0.16), 3: (0.05, 0.05, 0.05), 4: (0.15, 0.1, 0.1), 5: (0.35, 0.2, 0.12),
                    6: (0.6, 0.62, 0.66), 7: (0.9, 0.72, 0.3), 8: (0.6, 0.15, 0.12), 9: (0.2, 0.35, 0.75), 10: (0.5, 0.05, 0.05), 11: (0.4, 0.75, 0.55),
                    12: (0.75, 0.65, 0.45), 13: (0.45, 0.25, 0.12), 14: (0.4, 0.1, 0.1), 15: (0.9, 0.85, 0.7)}

if ANTEPRIMA:
    from anteprima import disegna, da_oggetti
    os.makedirs(ANTEPRIMA, exist_ok=True)

    def _colore(ob, lt):
        uv = ob.data.uv_layers['UVMap'].data[lt.loops[0]].uv
        return COLORI_ANTEPRIMA.get(int(uv[0] * 16), (0.7, 0.7, 0.7))


def _passi(nome_oggetto):
    return int(nome_oggetto[-2]), int(nome_oggetto[-1])


for nome, P in CLASSI.items():
    if SOLO and nome not in SOLO:
        continue
    K = Contesto()
    K.nome = nome
    K.P = P
    K.A = anatomia(P)
    alta, bassa = costruisci_corpo(nome + '_pelle', P, K.A)
    K.pelle = Pelle(alta)
    B = ossa_di(K)
    K.BH = {b[0]: b[1] for b in B}
    K.BT = {b[0]: b[2] for b in B}
    arm = crea_scheletro(nome, B)
    K.pesi_bassa = pesi_corpo(K, bassa, arm)
    kd = KDTree(len(bassa.data.vertices))
    for v in bassa.data.vertices:
        kd.insert(v.co, v.index)
    kd.balance()

    def pesi_vicino(co, permesse=None, kd=kd, K=K):
        _, i, _ = kd.find(co)
        w = K.pesi_bassa[i]
        if permesse:
            w = {b: x for b, x in w.items() if b in permesse}
            tot = sum(w.values())
            if tot < 0.05:
                return _pesi_dist(co, sorted(permesse), K)
            w = {b: x / tot for b, x in w.items()}
        return w

    K.pesi_vicino = pesi_vicino
    pezzi = [pezzo_corpo(K, bassa)] + dettagli(K) + crini(K)
    bm_b = bmesh.new()
    bm_b.from_mesh(bassa.data)
    albero_bassa = BVHTree.FromBMesh(bm_b)
    corpo = monta(K, nome, pezzi, arm)
    tri = {'corpo': triangoli(corpo)}
    oggetti = [corpo]
    per_passi = {}
    for da, a, lista in finimenti(K):
        per_passi.setdefault((da, a), []).extend(lista)
    for (da, a), lista in sorted(per_passi.items()):
        if not lista:
            continue
        ob = monta(K, f'{nome}_t{da}{a}', lista, arm, alberi_extra=[albero_bassa], portata=0.12)
        tri[f't{da}{a}'] = triangoli(ob)
        oggetti.append(ob)
    for ob in (alta, bassa):
        bpy.data.objects.remove(ob)
    anima(nome, arm, K)
    per_passo = {p: tri['corpo'] + sum(v for k, v in tri.items() if k != 'corpo' and int(k[1]) <= p <= int(k[2])) for p in (1, 2, 3, 4)}
    print(f'{nome}: corpo {tri["corpo"]} triangoli; con i finimenti per passo {per_passo}')
    if ANTEPRIMA:
        fatti = set()
        for p in (1, 2, 3, 4):
            vis = [o for o in oggetti if o is corpo or _passi(o.name)[0] <= p <= _passi(o.name)[1]]
            chiave = tuple(o.name for o in vis)
            if chiave in fatti:
                continue
            fatti.add(chiave)
            Vv, Tt, Cc = da_oggetti(vis, _colore)
            disegna(os.path.join(ANTEPRIMA, f'{nome}_{p}.png'), Vv, Tt, Cc, viste=('lato', 'fronte', 'tre_quarti', 'dietro'), px=300)

if not NIENTE_GLB:
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_animations=True, export_animation_mode='ACTIONS',
                              export_force_sampling=True, export_skins=True, export_def_bones=False, export_morph=False,
                              export_yup=True, export_texcoords=True, export_normals=True, export_materials='EXPORT', export_apply=False,
                              export_vertex_color='ACTIVE', export_all_vertex_colors=True, export_active_vertex_color_when_no_material=True)
    print('ESPORTATO', OUT, os.path.getsize(OUT) // 1024, 'kB')
