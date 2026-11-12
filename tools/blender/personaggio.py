# Regni di Giada — personaggio umanoide generato in Blender (modello, scheletro, pesi, animazioni).
#
# Uso (dalla cartella del progetto):
#   blender -b --factory-startup --python tools/blender/personaggio.py -- client/assets/personaggio.glb
#
# Produce un unico modello con scheletro a 21 ossa. Tutte le parti (capelli, hakama, armatura...)
# stanno nella stessa mesh: il gioco mostra o nasconde le parti in base alla seconda coordinata UV
# ("Part") e colora il modello con un piccolo atlante (tavolozza + viso) generato per ogni aspetto.
# Salva anche il file .blend accanto a questo script, da aprire e modificare in Blender.
import bpy, bmesh, math, sys, os
from mathutils import Vector, Matrix, Quaternion, Euler

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = os.path.abspath(argv[0] if argv else 'personaggio.glb')
HERE = os.path.dirname(os.path.abspath(__file__))

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 30

# ------------------------------------------------------------------ atlante e parti
# Atlante 256x256 (origine in alto a sinistra, come in glTF): riga 0-16 = tavolozza a celle 16x16,
# quadrato 32..224 x 40..232 = viso visto di fronte. Il resto è color pelle.
ATLAS = 256
SLOT = {'pelle': 0, 'veste': 1, 'bordo': 2, 'pantaloni': 3, 'fascia': 4, 'scarpe': 5, 'capelli': 6, 'armatura': 7,
        'calze': 8, 'sottoveste': 9, 'oro': 10, 'maniche': 11, 'barba': 12, 'mantello': 13}
PART = {'base': 0, 'hakama': 1, 'codino': 2, 'lunghi': 3, 'crocchia': 4, 'cappuccio': 5, 'barba': 6,
        'armatura': 7, 'frangia': 8, 'mantello': 9, 'colletto': 10, 'maniche': 11}
FACE = (32, 40, 192)  # x, y, lato in pixel
HEAD_C, HEAD_R, HEAD_RZ = Vector((0, 0, 1.95)), 0.25, 0.25 * 1.05


def slot_uv(name):
    i = SLOT[name]
    return ((i * 16 + 8) / ATLAS, 1 - 8 / ATLAS)  # v di Blender = 1 - v di glTF


def face_uv(co):
    u = (FACE[0] + (co.x / HEAD_R + 1) / 2 * FACE[2]) / ATLAS
    v = (FACE[1] + (HEAD_C.z + HEAD_RZ - co.z) / (2 * HEAD_RZ) * FACE[2]) / ATLAS
    if co.y > 0.0:
        v += 1.0  # dietro la testa: fuori dall'atlante, si legge il bordo (pelle)
    return (u, 1 - v)


# ------------------------------------------------------------------ scheletro
# Il personaggio guarda verso -Y (in glTF diventa +Z), Z è l'alto. Sinistra del personaggio = +X.
BONES = [
    ('hips', (0, 0, 0.92), (0, 0, 1.08), None),
    ('spine', (0, 0, 1.08), (0, 0, 1.30), 'hips'),
    ('chest', (0, 0, 1.30), (0, 0, 1.58), 'spine'),
    ('neck', (0, 0, 1.58), (0, 0, 1.74), 'chest'),
    ('head', (0, 0, 1.74), (0, 0, 2.12), 'neck'),
]
for s, k in (('L', 1), ('R', -1)):
    BONES += [
        (f'shoulder_{s}', (0.04 * k, 0, 1.52), (0.19 * k, 0, 1.53), 'chest'),
        (f'upper_arm_{s}', (0.19 * k, 0, 1.53), (0.355 * k, 0, 1.30), f'shoulder_{s}'),
        (f'forearm_{s}', (0.355 * k, 0, 1.30), (0.49 * k, 0, 1.09), f'upper_arm_{s}'),
        (f'hand_{s}', (0.49 * k, 0, 1.09), (0.54 * k, -0.01, 0.99), f'forearm_{s}'),
        (f'thigh_{s}', (0.10 * k, 0, 0.95), (0.115 * k, 0, 0.52), 'hips'),
        (f'shin_{s}', (0.115 * k, 0, 0.52), (0.12 * k, 0, 0.11), f'thigh_{s}'),
        (f'foot_{s}', (0.12 * k, 0, 0.11), (0.12 * k, -0.14, 0.04), f'shin_{s}'),
    ]
BONE_NAMES = [b[0] for b in BONES]
BH = {b[0]: Vector(b[1]) for b in BONES}
BT = {b[0]: Vector(b[2]) for b in BONES}


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (a + ab * t - p).length


def weights_for(p, allowed):
    ds = sorted((seg_dist(p, BH[b], BT[b]), b) for b in allowed)[:3]
    ws = [(1.0 / (d + 0.025) ** 4, b) for d, b in ds]
    tot = sum(w for w, _ in ws)
    out = [(b, w / tot) for w, b in ws if w / tot > 0.03]
    tot = sum(w for _, w in out)
    return [(b, w / tot) for b, w in out]


# ------------------------------------------------------------------ primitive (bmesh)
def lathe(path, n=12, cap0=True, cap1=True):
    """Tubo lungo un percorso: path = [(centro, rx, ry)], rx sul lato, ry davanti-dietro."""
    bm = bmesh.new()
    rings, m = [], len(path)
    for i, (c, rx, ry) in enumerate(path):
        c = Vector(c)
        if i == 0:
            d = Vector(path[1][0]) - c
        elif i == m - 1:
            d = c - Vector(path[i - 1][0])
        else:
            d = Vector(path[i + 1][0]) - Vector(path[i - 1][0])
        d.normalize()
        ref = Vector((0, -1, 0)) if abs(d.y) < 0.9 else Vector((0, 0, 1))
        u = ref.cross(d).normalized()
        w = d.cross(u).normalized()
        rings.append([bm.verts.new(c + u * (rx * math.cos(2 * math.pi * k / n)) + w * (ry * math.sin(2 * math.pi * k / n))) for k in range(n)])
    for i in range(m - 1):
        for k in range(n):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % n], rings[i + 1][(k + 1) % n], rings[i + 1][k]))
    if cap0:
        bm.faces.new(list(reversed(rings[0])))
    if cap1:
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def sphere(c, r, scale=(1, 1, 1), seg=14, rings=9):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(c), verts=bm.verts)
    return bm


def box(c, size, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Euler(rot).to_matrix())
    bmesh.ops.translate(bm, vec=Vector(c), verts=bm.verts)
    return bm


def cone(c, r, h, rot=(0, 0, 0), seg=6):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=0.0, depth=h)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Euler(rot).to_matrix())
    bmesh.ops.translate(bm, vec=Vector(c), verts=bm.verts)
    return bm


def cut(bm, fn):
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if fn(v.co)], context='VERTS')
    return bm


def solidify(bm, t):
    """Dà spessore a una superficie aperta (guscio interno + bordo)."""
    bm.normal_update()
    boundary = [e for e in bm.edges if e.is_boundary]
    verts, faces = list(bm.verts), list(bm.faces)
    inner = {v: bm.verts.new(v.co - v.normal * t) for v in verts}
    for f in faces:
        bm.faces.new([inner[v] for v in reversed(f.verts)])
    for e in boundary:
        f = e.link_faces[0]
        for lp in f.loops:
            if lp.edge == e:
                a, b = lp.vert, lp.link_loop_next.vert
                break
        bm.faces.new((b, a, inner[a], inner[b]))
    return bm


def mirror_x(bm):
    bmesh.ops.scale(bm, vec=(-1, 1, 1), verts=bm.verts)
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    return bm


# ------------------------------------------------------------------ pezzi del personaggio
PIECES = []


def add(bm, slot, part='base', bones=('chest',), smooth=True):
    PIECES.append(dict(bm=bm, slot=slot, part=PART[part], bones=list(bones), smooth=smooth))


def side(s):
    return 1 if s == 'L' else -1


# busto (kimono), collo, testa
add(lathe([((0, 0, 0.90), .165, .125), ((0, 0, 1.02), .155, .118), ((0, 0, 1.20), .16, .12), ((0, 0, 1.38), .195, .135),
           ((0, 0, 1.50), .19, .13), ((0, 0, 1.57), .13, .095), ((0, 0, 1.61), .075, .07)], n=16), 'veste',
    bones=('hips', 'spine', 'chest', 'neck', 'shoulder_L', 'shoulder_R'))
add(lathe([((0, 0, 1.56), .062, .062), ((0, 0, 1.80), .058, .058)], n=10), 'pelle', bones=('chest', 'neck', 'head'))
add(sphere(HEAD_C, HEAD_R, (1, .95, 1.05), seg=24, rings=16), 'face', bones=('head',))
add(cone((0, -.232, 1.888), .021, .045, (math.radians(-100), 0, 0), seg=8), 'pelle', bones=('head',))
for s in 'LR':
    k = side(s)
    add(sphere((.245 * k, .01, 1.93), .05, (.45, .75, 1), seg=8, rings=6), 'pelle', bones=('head',))
    # spalla, braccio, avambraccio, mano
    add(sphere((.185 * k, 0, 1.515), .085), 'veste', bones=('chest', f'shoulder_{s}', f'upper_arm_{s}'))
    add(lathe([((.19 * k, 0, 1.53), .075, .075), ((.27 * k, 0, 1.42), .07, .07), ((.355 * k, 0, 1.30), .06, .06)], n=10), 'maniche',
        bones=(f'shoulder_{s}', f'upper_arm_{s}', f'forearm_{s}'))
    add(lathe([((.355 * k, 0, 1.30), .058, .058), ((.42 * k, 0, 1.20), .052, .052), ((.49 * k, 0, 1.09), .042, .042)], n=10), 'pelle',
        bones=(f'upper_arm_{s}', f'forearm_{s}', f'hand_{s}'))
    add(sphere((.52 * k, -.012, 1.03), .074, (.78, .95, 1.22), seg=12, rings=8), 'pelle', bones=(f'forearm_{s}', f'hand_{s}'))
    # manica larga a campana con orlo
    add(solidify(lathe([((.30 * k, 0, 1.385), .082, .085), ((.38 * k, 0, 1.255), .115, .13), ((.465 * k, 0, 1.12), .145, .165)], n=12,
                       cap0=False, cap1=False), .016), 'maniche', 'maniche', bones=(f'upper_arm_{s}', f'forearm_{s}'))
    add(solidify(lathe([((.458 * k, 0, 1.131), .147, .167), ((.47 * k, 0, 1.112), .149, .169)], n=12, cap0=False, cap1=False), .018),
        'bordo', 'maniche', bones=(f'upper_arm_{s}', f'forearm_{s}'))
    # gamba (pantaloni aderenti), calza, sandalo
    add(lathe([((.10 * k, 0, .97), .092, .088), ((.11 * k, 0, .74), .08, .078), ((.115 * k, 0, .52), .066, .066)], n=10), 'pantaloni',
        bones=('hips', f'thigh_{s}', f'shin_{s}'))
    add(lathe([((.115 * k, 0, .52), .066, .066), ((.118 * k, 0, .30), .058, .058), ((.12 * k, 0, .16), .05, .05)], n=10), 'pantaloni',
        bones=(f'thigh_{s}', f'shin_{s}', f'foot_{s}'))
    add(lathe([((.12 * k, 0, .21), .054, .054), ((.12 * k, 0, .06), .052, .052)], n=10), 'calze', bones=(f'shin_{s}', f'foot_{s}'))
    add(lathe([((.12 * k, .05, .045), .052, .042), ((.12 * k, -.04, .045), .058, .044), ((.12 * k, -.15, .035), .045, .03)], n=10), 'scarpe',
        bones=(f'shin_{s}', f'foot_{s}'))
    # hakama: gamba ampia che si allarga verso il basso
    add(solidify(lathe([((.095 * k, 0, 1.03), .14, .13), ((.12 * k, 0, .78), .165, .15), ((.15 * k, 0, .42), .19, .17),
                        ((.165 * k, 0, .11), .21, .19)], n=14, cap0=False, cap1=False), .015), 'pantaloni', 'hakama',
        bones=('hips', f'thigh_{s}', f'shin_{s}'))
add(sphere((0, 0, .93), .165, (1, .78, .7)), 'pantaloni', bones=('hips', 'thigh_L', 'thigh_R', 'spine'))
add(solidify(lathe([((0, 0, 1.12), .19, .15), ((0, 0, .98), .24, .19), ((0, 0, .86), .27, .21)], n=16, cap0=False, cap1=False), .015),
    'pantaloni', 'hakama', bones=('hips', 'spine', 'thigh_L', 'thigh_R'))

# obi con cordino e nodo sulla schiena, colletto incrociato
add(lathe([((0, 0, 1.02), .178, .138), ((0, 0, 1.21), .178, .138)], n=16), 'fascia', bones=('hips', 'spine'))
add(lathe([((0, 0, 1.105), .183, .143), ((0, 0, 1.125), .183, .143)], n=16), 'bordo', bones=('hips', 'spine'))
add(box((0, .165, 1.13), (.26, .07, .14)), 'fascia', bones=('hips', 'spine'), smooth=False)
for k in (1, -1):
    add(box((.07 * k, .178, .98), (.08, .03, .28), (0, .2 * k, 0)), 'fascia', bones=('hips', 'spine'), smooth=False)
    add(box((.05 * k, -.143, 1.40), (.065, .02, .40), (0, math.radians(14) * k, 0)), 'bordo', 'colletto', bones=('spine', 'chest'), smooth=False)
    add(box((.024 * k, -.147, 1.42), (.026, .02, .34), (0, math.radians(14) * k, 0)), 'sottoveste', 'colletto', bones=('spine', 'chest'), smooth=False)

# capelli: calotta + frangia + ciocche laterali (parte comune), poi le acconciature
cap = sphere((0, .012, 1.965), .268, (1, .97, 1.04), seg=24, rings=14)
cut(cap, lambda c: c.z < 1.78 or (c.y < -.02 and c.z < 2.05))
add(solidify(cap, .015), 'capelli', 'frangia', bones=('head',))
for i, x in enumerate((-.14, -.07, 0, .07, .14)):
    z = 2.075 - abs(x) * .35
    y = -math.sqrt(max(0.0, .268 ** 2 - (z - 1.965) ** 2 / 1.04 ** 2 - x ** 2)) * .97 - .005
    add(cone((x, y, z), .055, .17, (math.pi - .3, 0, x * -1.5), seg=4), 'capelli', 'frangia', bones=('head',), smooth=False)
for k in (1, -1):
    add(lathe([((.236 * k, -.05, 2.0), .03, .045), ((.243 * k, -.065, 1.78), .018, .028)], n=6), 'capelli', 'frangia', bones=('head',))
# codino alto
add(lathe([((0, .214, 2.13), .055, .05), ((0, .226, 2.16), .055, .05)], n=10), 'bordo', 'codino', bones=('head',))
add(lathe([((0, .235, 2.15), .06, .05), ((0, .31, 2.0), .07, .055), ((0, .32, 1.80), .055, .045), ((0, .29, 1.58), .02, .02)], n=10),
    'capelli', 'codino', bones=('head',))
# capelli lunghi sciolti
add(lathe([((0, .13, 2.08), .23, .12), ((0, .2, 1.85), .22, .08), ((0, .21, 1.55), .19, .05), ((0, .19, 1.40), .14, .03)], n=14),
    'capelli', 'lunghi', bones=('head',))
# crocchia con spillone
add(sphere((0, .2, 2.14), .105), 'capelli', 'crocchia', bones=('head',))
add(box((0, .24, 2.16), (.34, .018, .018), (0, .5, 0)), 'oro', 'crocchia', bones=('head',), smooth=False)
# cappuccio
hood = sphere((0, .02, 1.97), .30, (1, 1, 1.06), seg=20, rings=12)
cut(hood, lambda c: c.z < 1.68 or (c.y < -.05 and 1.70 < c.z < 2.12))
add(solidify(hood, .02), 'veste', 'cappuccio', bones=('head',))
# barba
add(cone((0, -.17, 1.70), .11, .40, (math.pi - .35, 0, 0), seg=8), 'barba', 'barba', bones=('head',))
# armatura: pettorale e schienale con lacci, spallacci a lamelle, falde
# corazza (dō) che avvolge il busto, a fasce orizzontali con lacci
add(lathe([((0, 0, 1.20), .19, .145), ((0, 0, 1.30), .205, .152), ((0, 0, 1.42), .222, .158), ((0, 0, 1.53), .2, .145), ((0, 0, 1.57), .16, .12)], n=16),
    'armatura', 'armatura', bones=('spine', 'chest'))
for z in (1.27, 1.36, 1.45):
    add(lathe([((0, 0, z - .008), .214 + (z - 1.27) * .08, .156), ((0, 0, z + .008), .214 + (z - 1.27) * .08, .156)], n=16), 'bordo', 'armatura',
        bones=('spine', 'chest'))
add(box((0, -.165, 1.47), (.07, .02, .07), (0, 0, math.pi / 4)), 'oro', 'armatura', bones=('chest',), smooth=False)
for k in (1, -1):
    s = 'L' if k > 0 else 'R'
    for i in range(3):
        add(box(((.29 + .03 * i) * k, 0, 1.47 - .085 * i), (.035, .26, .26 - .02 * i), (0, -(.30 + .08 * i) * k, 0)), 'armatura', 'armatura',
            bones=(f'shoulder_{s}', f'upper_arm_{s}'), smooth=False)
        add(box(((.305 + .03 * i) * k, 0, 1.40 - .085 * i), (.036, .265, .016), (0, -(.30 + .08 * i) * k, 0)), 'bordo', 'armatura',
            bones=(f'shoulder_{s}', f'upper_arm_{s}'), smooth=False)
for k in (1, -1):
    s = 'L' if k > 0 else 'R'
    sb = (f'shoulder_{s}', f'upper_arm_{s}')
    dome = sphere((.285 * k, 0, 1.50), .175, (1.1, 1.0, .9), seg=20, rings=12)
    cut(dome, lambda c: c.z < 1.47)
    add(solidify(dome, .025), 'armatura', 'armatura', bones=sb)
    add(solidify(lathe([((.285 * k, 0, 1.474), .19, .174), ((.285 * k, 0, 1.494), .192, .176)], n=20, cap0=False, cap1=False), .03),
        'oro', 'armatura', bones=sb)
    for j in range(4):
        a = -0.9 + j * 0.6
        add(sphere((.285 * k + math.sin(a) * .1 * k, math.cos(a) * -.13, 1.58), .022, seg=8, rings=5), 'oro', 'armatura', bones=sb)
    # bracciale di metallo con bordi dorati
    fb = (f'upper_arm_{s}', f'forearm_{s}', f'hand_{s}')
    add(lathe([((.37 * k, 0, 1.275), .072, .072), ((.43 * k, 0, 1.18), .07, .07), ((.475 * k, 0, 1.115), .064, .064)], n=14), 'armatura', 'armatura', bones=fb)
    for t0 in (.36, .47):
        z = 1.30 - (t0 - .355) / .135 * .21
        add(lathe([((t0 * k, 0, z + .012), .078, .078), ((t0 * k, 0, z - .012), .078, .078)], n=14), 'oro', 'armatura', bones=fb)
# cinturone di cuoio con medaglione
add(lathe([((0, 0, .985), .205, .162), ((0, 0, 1.045), .205, .162)], n=20), 'scarpe', 'armatura', bones=('hips', 'spine'))
add(lathe([((0, -.162, 1.015), .07, .07), ((0, -.19, 1.015), .07, .07)], n=16), 'oro', 'armatura', bones=('hips',))
add(lathe([((0, -.19, 1.015), .045, .045), ((0, -.198, 1.015), .045, .045)], n=16), 'armatura', 'armatura', bones=('hips',))
for i in range(7):
    a = -math.pi * 0.75 + i * (math.pi * 1.5 / 6)  # davanti e ai lati
    x, y = math.sin(a) * .235, -math.cos(a) * .19
    s = 'L' if x > .05 else 'R' if x < -.05 else None
    add(box((x, y, .93), (.15, .03, .22), (-.18, 0, a)), 'armatura', 'armatura',
        bones=('hips', f'thigh_{s}') if s else ('hips',), smooth=False)
# mantello
add(box((0, .2, 1.0), (.5, .025, 1.15), (-.08, 0, 0)), 'mantello', 'mantello', bones=('spine', 'chest', 'hips'), smooth=False)

# ------------------------------------------------------------------ una mesh per parte: forme lisce suddivise + pezzi duri
BI = {n: i for i, n in enumerate(BONE_NAMES)}
PART_NAMES = {v: k for k, v in PART.items()}
SHADE_OUT = os.path.join(os.path.dirname(OUT), 'personaggio_ombre.png')


def to_bmesh(pieces):
    bm = bmesh.new()
    uv0 = bm.loops.layers.uv.new('UVMap')
    uv1 = bm.loops.layers.uv.new('Part')
    dl = bm.verts.layers.deform.verify()
    for pc in pieces:
        src, vmap = pc['bm'], {}
        for v in src.verts:
            nv = bm.verts.new(v.co)
            for b, w in weights_for(v.co, pc['bones']):
                nv[dl][BI[b]] = w
            vmap[v] = nv
        for f in src.faces:
            nf = bm.faces.new([vmap[v] for v in f.verts])
            nf.smooth = pc['smooth']
            for lp in nf.loops:
                lp[uv0].uv = face_uv(lp.vert.co) if pc['slot'] == 'face' else slot_uv(pc['slot'])
                lp[uv1].uv = (pc['part'], 0)
    return bm


def make_obj(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    for n in BONE_NAMES:
        ob.vertex_groups.new(name=n)
    return ob


def apply_subsurf(ob, levels=1):
    """Suddivisione (Catmull-Clark): forme organiche lisce, UV e pesi conservati."""
    mod = ob.modifiers.new('liscio', 'SUBSURF')
    mod.levels = mod.render_levels = levels
    mod.uv_smooth = 'NONE'
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    ob.modifiers.remove(mod)
    old = ob.data
    ob.data = me
    bpy.data.meshes.remove(old)
    for poly in me.polygons:
        poly.use_smooth = True


def select_only(obs, active):
    for o in scene.objects:
        o.select_set(False)
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active


part_objs = []
for pid in sorted({pc['part'] for pc in PIECES}):
    softp = [pc for pc in PIECES if pc['part'] == pid and pc['smooth']]
    hardp = [pc for pc in PIECES if pc['part'] == pid and not pc['smooth']]
    name = 'parte_' + PART_NAMES[pid]
    obs = []
    if softp:
        so = make_obj(name, to_bmesh(softp))
        apply_subsurf(so)
        obs.append(so)
    if hardp:
        obs.append(make_obj(name + '_duro', to_bmesh(hardp)))
    if len(obs) > 1:
        select_only(obs, obs[0])
        bpy.ops.object.join()
    part_objs.append(obs[0])
for pc in PIECES:
    pc['bm'].free()

# ------------------------------------------------------------------ ombre dipinte, calcolate per vertice
# Occlusione ambientale (raggi verso l'emisfero, solo contro la parte stessa: nascondere hakama o
# capelli non lascia macchie scure) e curvatura (bordi convessi più chiari, cavità più scure).
# I due valori finiscono nella terza UV ("Ombra"): il gioco li usa come ombreggiatura dipinta.
from mathutils.bvhtree import BVHTree

def hemisphere(n=20):
    out, ga = [], math.pi * (3 - math.sqrt(5))
    for i in range(n):
        z = 1 - (i + 0.5) / n
        r = math.sqrt(max(0.0, 1 - z * z))
        out.append(Vector((math.cos(ga * i) * r, math.sin(ga * i) * r, z)))
    return out

HEMI = hemisphere(20)

def shade_part(ob):
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.normal_update()
    tree = BVHTree.FromBMesh(bm)
    ao, curv = {}, {}
    for v in bm.verts:
        n = v.normal
        t = n.orthogonal().normalized()
        b = n.cross(t)
        o = v.co + n * 0.004
        occ = 0.0
        for d in HEMI:
            w = d.z
            dirv = (t * d.x + b * d.y + n * d.z).normalized()
            hit = tree.ray_cast(o, dirv, 0.26)
            if hit[0] is not None:
                occ += w * (1 - hit[3] / 0.26)
        ao[v.index] = 1 - min(1.0, occ / sum(h.z for h in HEMI) * 1.6)
        c, k = 0.0, 0
        for e in v.link_edges:
            u = e.other_vert(v)
            dv = v.co - u.co
            l2 = dv.length_squared
            if l2 > 1e-10:
                c += (v.normal - u.normal).dot(dv) / l2
                k += 1
        curv[v.index] = c / max(1, k)
    bm.free()
    vals = sorted(abs(x) for x in curv.values())
    scale = vals[int(len(vals) * 0.92)] or 1.0
    lay = me.uv_layers.new(name='Ombra')
    for lp in me.loops:
        i = lp.vertex_index
        cv = max(-1.0, min(1.0, curv[i] / scale))
        lay.data[lp.index].uv = (0.4 + 0.6 * ao[i], 1 - (1.0 + 0.22 * cv))  # glTF capovolge v

for ob in part_objs:
    shade_part(ob)
print('ombre calcolate')

# ------------------------------------------------------------------ unione finale
select_only(part_objs, part_objs[0])
bpy.ops.object.join()
body = part_objs[0]
body.name = 'personaggio'
me = body.data
me.name = 'personaggio'
me.materials.clear()
mat = bpy.data.materials.new('personaggio')
mat.use_nodes = True
me.materials.append(mat)
for poly in me.polygons:
    poly.material_index = 0
me.uv_layers.active = me.uv_layers['UVMap']
for ln in [l.name for l in me.uv_layers]:
    print('UV', ln)
print('vertici:', len(me.vertices), 'facce:', len(me.polygons))

# ------------------------------------------------------------------ armatura
arm_data = bpy.data.armatures.new('scheletro')
arm = bpy.data.objects.new('scheletro', arm_data)
scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT')
for name, h, t, parent in BONES:
    eb = arm_data.edit_bones.new(name)
    eb.head, eb.tail = h, t
    eb.roll = 0
    if parent:
        eb.parent = arm_data.edit_bones[parent]
        eb.use_connect = (Vector(h) - Vector(arm_data.edit_bones[parent].tail)).length < 1e-4
bpy.ops.object.mode_set(mode='OBJECT')
body.parent = arm
mod = body.modifiers.new('scheletro', 'ARMATURE')
mod.object = arm

# ------------------------------------------------------------------ animazioni (modulo condiviso)
sys.path.insert(0, HERE)
from umanoide_anim import crea_animazioni
ACTIONS = crea_animazioni(arm)

# ------------------------------------------------------------------ esportazione
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format='GLB', export_animations=True, export_animation_mode='ACTIONS',
    export_force_sampling=True, export_skins=True, export_def_bones=False, export_morph=False,
    export_yup=True, export_texcoords=True, export_normals=True, export_materials='EXPORT', export_apply=False)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, 'personaggio.blend'))
print('ESPORTATO', OUT, 'azioni:', ', '.join(ACTIONS))
