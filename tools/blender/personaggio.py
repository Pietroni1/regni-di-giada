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
        'armatura': 7, 'frangia': 8, 'mantello': 9, 'colletto': 10}
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
for s in 'LR':
    k = side(s)
    add(sphere((.245 * k, .01, 1.93), .05, (.45, .75, 1), seg=8, rings=6), 'pelle', bones=('head',))
    # spalla, braccio, avambraccio, mano
    add(sphere((.185 * k, 0, 1.515), .085), 'veste', bones=('chest', f'shoulder_{s}', f'upper_arm_{s}'))
    add(lathe([((.19 * k, 0, 1.53), .075, .075), ((.27 * k, 0, 1.42), .07, .07), ((.355 * k, 0, 1.30), .06, .06)], n=10), 'maniche',
        bones=(f'shoulder_{s}', f'upper_arm_{s}', f'forearm_{s}'))
    add(lathe([((.355 * k, 0, 1.30), .058, .058), ((.42 * k, 0, 1.20), .052, .052), ((.49 * k, 0, 1.09), .042, .042)], n=10), 'pelle',
        bones=(f'upper_arm_{s}', f'forearm_{s}', f'hand_{s}'))
    add(sphere((.515 * k, -.01, 1.035), .062, (.75, .95, 1.25), seg=10, rings=7), 'pelle', bones=(f'forearm_{s}', f'hand_{s}'))
    # manica larga a campana con orlo
    add(solidify(lathe([((.30 * k, 0, 1.385), .082, .085), ((.38 * k, 0, 1.255), .115, .13), ((.465 * k, 0, 1.12), .145, .165)], n=12,
                       cap0=False, cap1=False), .016), 'maniche', bones=(f'upper_arm_{s}', f'forearm_{s}'))
    add(solidify(lathe([((.458 * k, 0, 1.131), .147, .167), ((.47 * k, 0, 1.112), .149, .169)], n=12, cap0=False, cap1=False), .018),
        'bordo', bones=(f'upper_arm_{s}', f'forearm_{s}'))
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
for i in range(7):
    a = -math.pi * 0.75 + i * (math.pi * 1.5 / 6)  # davanti e ai lati
    x, y = math.sin(a) * .235, -math.cos(a) * .19
    s = 'L' if x > .05 else 'R' if x < -.05 else None
    add(box((x, y, .93), (.15, .03, .22), (-.18, 0, a)), 'armatura', 'armatura',
        bones=('hips', f'thigh_{s}') if s else ('hips',), smooth=False)
# mantello
add(box((0, .2, 1.0), (.5, .025, 1.15), (-.08, 0, 0)), 'mantello', 'mantello', bones=('spine', 'chest', 'hips'), smooth=False)

# ------------------------------------------------------------------ unione in una sola mesh
master = bmesh.new()
uv0 = master.loops.layers.uv.new('UVMap')
uv1 = master.loops.layers.uv.new('Part')
dl = master.verts.layers.deform.verify()
BI = {n: i for i, n in enumerate(BONE_NAMES)}
for pc in PIECES:
    bm = pc['bm']
    vmap = {}
    for v in bm.verts:
        nv = master.verts.new(v.co)
        for b, w in weights_for(v.co, pc['bones']):
            nv[dl][BI[b]] = w
        vmap[v] = nv
    for f in bm.faces:
        nf = master.faces.new([vmap[v] for v in f.verts])
        nf.smooth = pc['smooth']
        for lp in nf.loops:
            lp[uv0].uv = face_uv(lp.vert.co) if pc['slot'] == 'face' else slot_uv(pc['slot'])
            lp[uv1].uv = (pc['part'], 0)
    bm.free()

me = bpy.data.meshes.new('personaggio')
master.to_mesh(me)
master.free()
body = bpy.data.objects.new('personaggio', me)
scene.collection.objects.link(body)
for n in BONE_NAMES:
    body.vertex_groups.new(name=n)
mat = bpy.data.materials.new('personaggio')
mat.use_nodes = True
me.materials.append(mat)
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

# ------------------------------------------------------------------ animazioni
# Le rotazioni si scrivono negli assi dell'armatura a riposo (X = beccheggio, Y = laterale, Z = torsione):
#   gambe e braccia: X negativo = in avanti;  busto/testa: X positivo = si piega in avanti;
#   Z positivo = ruota verso sinistra;  braccio sinistro: Y positivo = si abbassa verso il fianco (destro: Y negativo).
REST = {b.name: b.matrix_local.to_3x3() for b in arm_data.bones}
AX = {'X': Vector((1, 0, 0)), 'Y': Vector((0, 1, 0)), 'Z': Vector((0, 0, 1))}


def local_quat(bone, rots):
    q = Quaternion()
    for ax, deg in rots:
        q = Quaternion(AX[ax], math.radians(deg)) @ q
    M = REST[bone]
    return (M.inverted() @ q.to_matrix() @ M).to_quaternion()


def fwd(d): return ('X', -d)


def lean(d): return ('X', d)


def turn(d): return ('Z', d)


def down(s, d): return ('Y', d if s == 'L' else -d)


def mir(s): return 'R' if s == 'L' else 'L'


def merge(*poses):
    out = {}
    for p in poses:
        for k, v in p.items():
            if k == 'loc':
                out['loc'] = tuple(a + b for a, b in zip(out.get('loc', (0, 0, 0)), v))
            elif k.startswith(('blade', 'staff', 'bow')):
                out[k] = v
            else:
                out[k] = out.get(k, []) + list(v)
    return out


def relaxed_arms(d=24, f=4, bend=12):
    p = {}
    for s in 'LR':
        p[f'upper_arm_{s}'] = [down(s, d), fwd(f)]
        p[f'forearm_{s}'] = [fwd(bend)]
    return p


def stance():
    """Guardia di combattimento: gambe piegate, busto in avanti."""
    return {'thigh_L': [fwd(14)], 'shin_L': [('X', 16)], 'thigh_R': [fwd(-8)], 'shin_R': [('X', 12)], 'foot_L': [('X', -4)],
            'spine': [lean(6)], 'head': [lean(-4)], 'loc': (0, 0, -.03),
            'upper_arm_L': [down('L', 28), fwd(28)], 'forearm_L': [fwd(55)],
            'upper_arm_R': [down('R', 22), fwd(14)], 'forearm_R': [fwd(35)]}


ACTIONS = {}

# Direzione delle armi rispetto alla mano a riposo (stessa convenzione dell'impugnatura nel gioco):
# Y dell'impugnatura = verso il gomito, Z = davanti. Lama: -0.22 Y + 0.976 Z; asta del bastone: +Y.
def grip_axes(s):
    k = 1 if s == 'L' else -1
    y = -Vector((0.05 * k, -0.01, -0.10)).normalized()
    z = Vector((0, -1, 0))
    z = (z - y * z.dot(y)).normalized()
    return y, z


def weapon_dir(s, kind):
    y, z = grip_axes(s)
    return (y * -0.22 + z * 0.976).normalized() if kind == 'blade' else y


def aim_hand2(s, t_axis, t_front):
    """Orienta l'impugnatura su due assi: Y dell'impugnatura verso t_axis, Z verso t_front (per l'arco)."""
    bpy.context.view_layer.update()
    pb = arm.pose.bones[f'hand_{s}']
    P = pb.matrix.to_3x3().normalized()
    y, z = grip_axes(s)
    Rinv = REST[f'hand_{s}'].inverted()
    cy, cz = P @ (Rinv @ y), P @ (Rinv @ z)
    a = Vector(t_axis).normalized()
    Q1 = cy.rotation_difference(a)
    cz = Q1 @ cz
    f = Vector(t_front)
    f = (f - a * f.dot(a)).normalized()
    cz = (cz - a * cz.dot(a)).normalized()
    Q = cz.rotation_difference(f) @ Q1
    pb.rotation_quaternion = pb.rotation_quaternion @ (P.inverted() @ Q.to_matrix() @ P).to_quaternion()


def aim_hand(s, kind, target):
    """Ruota il polso perché l'arma punti verso target (assi dell'armatura)."""
    bpy.context.view_layer.update()
    pb = arm.pose.bones[f'hand_{s}']
    P = pb.matrix.to_3x3().normalized()
    local = REST[f'hand_{s}'].inverted() @ weapon_dir(s, kind)
    cur = P @ local
    Q = cur.rotation_difference(Vector(target).normalized())
    pb.rotation_quaternion = pb.rotation_quaternion @ (P.inverted() @ Q.to_matrix() @ P).to_quaternion()


def make_action(name, keys, loop=False):
    """keys: lista di (frame, posa). Ogni posa: {osso: [(asse, gradi)...], 'loc': (x, y, z)}."""
    act = bpy.data.actions.new(name)
    arm.animation_data_create()
    arm.animation_data.action = act
    for frame, pose in keys:
        for pb in arm.pose.bones:
            pb.rotation_mode = 'QUATERNION'
            pb.rotation_quaternion = local_quat(pb.name, pose.get(pb.name, []))
            if pb.name == 'hips':
                pb.location = REST['hips'].inverted() @ Vector(pose.get('loc', (0, 0, 0)))
        for key, (s, kind) in (('blade_R', ('R', 'blade')), ('blade_L', ('L', 'blade')), ('staff_R', ('R', 'staff'))):
            if key in pose:
                aim_hand(s, kind, pose[key])
        if 'bow_L' in pose:
            aim_hand2('L', *pose['bow_L'])
        for pb in arm.pose.bones:
            pb.keyframe_insert('rotation_quaternion', frame=frame, group=pb.name)
            if pb.name == 'hips':
                pb.keyframe_insert('location', frame=frame, group=pb.name)
    act.use_frame_range = True
    act.frame_start, act.frame_end = keys[0][0], keys[-1][0]
    act.use_cyclic = loop
    act.use_fake_user = True
    ACTIONS[name] = act
    arm.animation_data.action = None
    return act


def cycle(name, frames, steps, fn):
    keys = [(round(frames * i / steps), fn(i / steps)) for i in range(steps)]
    keys.append((frames, fn(0.0)))
    make_action(name, keys, loop=True)


TAU = math.pi * 2

# fermo: respiro lento
cycle('fermo', 60, 6, lambda p: merge(relaxed_arms(f=4 + math.sin(TAU * p)), {
    'spine': [lean(2)], 'chest': [lean(1 + 1.2 * math.sin(TAU * p))], 'neck': [lean(-2)],
    'head': [lean(-1 - .8 * math.sin(TAU * p))], 'shin_L': [('X', 3)], 'shin_R': [('X', 3)],
    'loc': (0, 0, -.004 + .004 * math.sin(TAU * p))}))


def walk(p, amp=26, knee=42, arm=22, lean_=4, bob=.022, elbow=14, twist=6):
    s, c = math.sin(TAU * p), math.cos(TAU * p)
    return {
        'thigh_L': [fwd(amp * s)], 'thigh_R': [fwd(-amp * s)],
        'shin_L': [('X', 6 + knee * max(0, c) ** 2)], 'shin_R': [('X', 6 + knee * max(0, -c) ** 2)],
        'foot_L': [('X', -8 * s)], 'foot_R': [('X', 8 * s)],
        'hips': [turn(-twist * s)], 'chest': [turn(twist * 1.2 * s)], 'spine': [lean(lean_)],
        'head': [lean(-lean_ * .6), turn(-2 * s)],
        'upper_arm_L': [down('L', 20), fwd(-arm * s)], 'upper_arm_R': [down('R', 20), fwd(arm * s)],
        'forearm_L': [fwd(elbow + 12 * max(0, -s))], 'forearm_R': [fwd(elbow + 12 * max(0, s))],
        'loc': (0, 0, bob * math.cos(2 * TAU * p) - bob * .6),
    }


cycle('camminata', 30, 10, lambda p: walk(p))
cycle('corsa', 18, 9, lambda p: walk(p, amp=44, knee=80, arm=40, lean_=13, bob=.04, elbow=70, twist=9))

# in sella: gambe aperte e piegate, mani alle redini
cycle('sella', 30, 6, lambda p: {
    'thigh_L': [down('R', 28), fwd(78)], 'thigh_R': [down('L', 28), fwd(78)],
    'shin_L': [('X', 85)], 'shin_R': [('X', 85)], 'foot_L': [('X', -15)], 'foot_R': [('X', -15)],
    'spine': [lean(6 + 2 * math.sin(TAU * p))], 'head': [lean(-6)],
    'upper_arm_L': [down('L', 22), fwd(38)], 'upper_arm_R': [down('R', 22), fwd(38)],
    'forearm_L': [fwd(60)], 'forearm_R': [fwd(60)], 'loc': (0, 0, .01 * math.sin(TAU * p))})


def strike(name, wind, hit, follow=None, total=15, w=4, h=8):
    keys = [(0, stance()), (w, merge(stance(), wind)), (h, merge(stance(), hit))]
    if follow:
        keys.append((h + 3, merge(stance(), follow)))
    keys.append((total, stance()))
    make_action(name, keys)


# spada: fendente orizzontale, colpo dall'alto, affondo
strike('spada_1',
       {'chest': [turn(-38)], 'spine': [turn(-10)], 'upper_arm_R': [down('R', -55), fwd(-15)], 'forearm_R': [fwd(65)], 'blade_R': (-0.75, 0.35, 0.55)},
       {'chest': [turn(36)], 'spine': [turn(12)], 'upper_arm_R': [down('R', -58), fwd(78)], 'forearm_R': [fwd(10)], 'blade_R': (0.2, -1, 0.05)},
       {'chest': [turn(48)], 'spine': [turn(14)], 'upper_arm_R': [down('R', -35), fwd(88)], 'forearm_R': [fwd(15)], 'blade_R': (0.9, -0.35, -0.1)})
strike('spada_2',
       {'chest': [lean(-10), turn(-14)], 'upper_arm_R': [down('R', -18), fwd(165)], 'forearm_R': [fwd(70)], 'blade_R': (-0.2, 0.75, 0.55)},
       {'chest': [lean(20), turn(14)], 'spine': [lean(10)], 'upper_arm_R': [down('R', -8), fwd(48)], 'forearm_R': [fwd(5)], 'blade_R': (0.15, -0.8, -0.55),
        'thigh_L': [fwd(30)], 'shin_L': [('X', 38)], 'loc': (0, 0, -.06)})
strike('spada_3',
       {'chest': [turn(-26)], 'upper_arm_R': [down('R', 8), fwd(-35)], 'forearm_R': [fwd(105)], 'blade_R': (0.05, -1, 0.1)},
       {'chest': [turn(24), lean(10)], 'upper_arm_R': [down('R', -6), fwd(86)], 'forearm_R': [fwd(4)], 'blade_R': (0.05, -1, 0.02),
        'thigh_L': [fwd(36)], 'shin_L': [('X', 30)], 'thigh_R': [fwd(-22)], 'loc': (0, -.10, -.05)}, h=7)


def stab(name, s, kick=False):
    o = mir(s)
    tw = 1 if s == 'R' else -1
    if kick:
        strike(name, {'thigh_' + s: [fwd(40)], 'shin_' + s: [('X', 90)], 'spine': [lean(-8)]},
               {'thigh_' + s: [fwd(85)], 'shin_' + s: [('X', 8)], 'foot_' + s: [('X', 20)], 'spine': [lean(-14)],
                'upper_arm_' + o: [down(o, 10), fwd(20)]}, total=12, w=4, h=7)
        return
    blade = {'blade_' + s: (0, -1, 0.15)} if name.startswith('pugnali') else {}
    strike(name, merge({f'upper_arm_{s}': [down(s, 12), fwd(-25)], f'forearm_{s}': [fwd(115)], 'chest': [turn(-14 * tw)]}, blade),
           merge({f'upper_arm_{s}': [down(s, -8), fwd(75)], f'forearm_{s}': [fwd(18)], 'chest': [turn(26 * tw)], 'spine': [lean(6)]},
                 {'blade_' + s: (0, -1, -0.05)} if blade else {}),
           total=10, w=3, h=6)


stab('pugnali_1', 'R'); stab('pugnali_2', 'L')
stab('pugni_1', 'R'); stab('pugni_2', 'L'); stab('pugni_3', 'R', kick=True)

# arco: braccio sinistro teso, la destra tende la corda fino al mento e rilascia
bow_hold = {'upper_arm_L': [down('L', -8), fwd(84)], 'forearm_L': [fwd(4)], 'chest': [turn(-12)], 'head': [turn(12)],
            'bow_L': ((0, 0.05, 1), (0, -1, 0))}
make_action('arco', [
    (0, stance()),
    (5, merge(stance(), bow_hold, {'upper_arm_R': [down('R', -6), fwd(82)], 'forearm_R': [fwd(40)]})),
    (11, merge(stance(), bow_hold, {'upper_arm_R': [down('R', -18), fwd(78)], 'forearm_R': [fwd(150)]})),
    (13, merge(stance(), bow_hold, {'upper_arm_R': [down('R', -30), fwd(60)], 'forearm_R': [fwd(165)]})),
    (20, stance())])

# magia: le mani si alzano e poi spingono in avanti
make_action('magia', [
    (0, stance()),
    (6, merge(stance(), {s: [down(s[-1], 6), fwd(130)] for s in ('upper_arm_L', 'upper_arm_R')},
              {'forearm_L': [fwd(30)], 'forearm_R': [fwd(30)], 'chest': [lean(-8)], 'head': [lean(-8)], 'staff_R': (0, 0.1, 1)})),
    (11, merge(stance(), {s: [down(s[-1], 8), fwd(82)] for s in ('upper_arm_L', 'upper_arm_R')},
               {'forearm_L': [fwd(8)], 'forearm_R': [fwd(8)], 'chest': [lean(10)], 'staff_R': (0, -0.3, 1)})),
    (18, stance())])
# bastone: colpo in avanti con l'asta
strike('bastone',
       {'upper_arm_R': [down('R', 4), fwd(-20)], 'forearm_R': [fwd(95)], 'chest': [turn(-20)], 'staff_R': (0, 0.4, 1)},
       {'upper_arm_R': [down('R', -2), fwd(70)], 'forearm_R': [fwd(30)], 'chest': [turn(18), lean(8)], 'staff_R': (0, -1, 0.35)},
       {'upper_arm_R': [down('R', 10), fwd(40)], 'forearm_R': [fwd(45)], 'chest': [turn(8)], 'staff_R': (0, -0.45, 0.9)}, total=15, w=4, h=8)

# colpito e morte
make_action('colpito', [(0, merge(relaxed_arms(), {})),
                        (3, merge(relaxed_arms(d=10, f=-10, bend=30), {'chest': [lean(-14), turn(8)], 'head': [lean(-12)], 'loc': (0, .04, 0)})),
                        (9, merge(relaxed_arms(), {}))])
make_action('morte', [
    (0, merge(relaxed_arms(), {})),
    (8, merge(relaxed_arms(d=10, f=20, bend=40), {'thigh_L': [fwd(55)], 'thigh_R': [fwd(50)], 'shin_L': [('X', 75)], 'shin_R': [('X', 70)],
                                                  'spine': [lean(22)], 'head': [lean(15)], 'loc': (0, 0, -.32)})),
    (18, merge(relaxed_arms(d=-20, f=-30, bend=20), {'hips': [lean(-70)], 'thigh_L': [fwd(30)], 'thigh_R': [fwd(20)],
                                                     'shin_L': [('X', 30)], 'shin_R': [('X', 20)], 'head': [lean(-10)],
                                                     'loc': (0, .45, -.62)})),
    (30, merge(relaxed_arms(d=-55, f=-10, bend=10), {'hips': [lean(-90)], 'thigh_L': [fwd(4)], 'thigh_R': [fwd(-4)],
                                                     'shin_L': [('X', 6)], 'shin_R': [('X', 4)], 'head': [turn(20)],
                                                     'loc': (0, .82, -.78)}))])

# tutte le azioni nelle tracce NLA, così l'esportatore glTF le include
arm.animation_data_create()
for name, act in ACTIONS.items():
    tr = arm.animation_data.nla_tracks.new()
    tr.name = name
    tr.strips.new(name, int(act.frame_range[0]), act)
    tr.mute = True
arm.animation_data.action = None
for pb in arm.pose.bones:
    pb.rotation_quaternion = Quaternion()
    pb.location = Vector()

# ------------------------------------------------------------------ esportazione
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format='GLB', export_animations=True, export_animation_mode='ACTIONS',
    export_force_sampling=True, export_skins=True, export_def_bones=False, export_morph=False,
    export_yup=True, export_texcoords=True, export_normals=True, export_materials='EXPORT', export_apply=False)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, 'personaggio.blend'))
print('ESPORTATO', OUT, 'azioni:', ', '.join(ACTIONS))
