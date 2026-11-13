# Regni di Giada — animali con scheletro: lupo, cinghiale, orso, tigre, cavallo.
#
# Uso: blender -b --factory-startup --python tools/blender/animali.py -- client/assets/animali.glb
#
# Ogni specie ha la sua armatura (19 ossa, stessi nomi per tutte) e le sue animazioni, chiamate
# "<specie>:<azione>" (fermo, passo, corsa, attacco, colpito, morte). Colori da un atlante come per
# i personaggi; la seconda UV indica la parte (base, sella, bardatura) e la terza l'ombreggiatura dipinta.
import bpy, bmesh, math, sys, os
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from forme import lathe, sphere, cone, box, solidify, catmull, weights_for, make_obj, apply_subsurf, select_only, shade_vertices, make_action, stash_actions

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = os.path.abspath(argv[0] if argv else 'animali.glb')
HERE = os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 30

ATLAS = 256
SLOT = {'pelo': 0, 'pelo2': 1, 'scuro': 2, 'occhi': 3, 'zanne': 4, 'criniera': 5, 'interno': 6, 'sella': 7, 'oro': 8, 'stoffa': 9}
PART = {'base': 0, 'sella': 1, 'bardatura': 2}


def slot_uv(name):
    i = SLOT[name]
    return ((i * 16 + 8) / ATLAS, 1 - 8 / ATLAS)


SPECIES = {
    'lupo': dict(L=0.95, H=0.86, bodyR=0.2, hipR=0.155, neckLen=0.2, neckA=68, headR=0.195, snoutLen=0.3, snoutR=0.085, ears='punta', earS=0.15,
                 tail=('folta', 0.55), legR=0.06, sx=0.11, walk=(24, 30), run=(46, 16)),
    'cinghiale': dict(L=0.85, H=0.92, bodyR=0.27, hipR=0.24, neckLen=0.14, neckA=78, headR=0.23, snoutLen=0.3, snoutR=0.1, ears='punta', earS=0.1,
                      tail=('sottile', 0.22), legR=0.085, sx=0.15, tusks=True, bristles=True, walk=(20, 26), run=(38, 14)),
    'orso': dict(L=1.1, H=1.15, bodyR=0.42, hipR=0.38, neckLen=0.26, neckA=72, headR=0.22, snoutLen=0.2, snoutR=0.1, ears='tonde', earS=0.07,
                 tail=('mozza', 0.12), legR=0.11, sx=0.2, hump=True, walk=(20, 36), run=(34, 20)),
    'tigre': dict(L=1.2, H=0.92, bodyR=0.23, hipR=0.2, neckLen=0.24, neckA=58, headR=0.2, snoutLen=0.13, snoutR=0.1, ears='tonde', earS=0.065,
                  tail=('lunga', 1.0), legR=0.08, sx=0.13, walk=(22, 34), run=(44, 16)),
    'cavallo': dict(L=1.15, H=1.62, bodyR=0.38, hipR=0.36, neckLen=0.7, neckA=36, headR=0.21, snoutLen=0.46, snoutR=0.135, ears='punta', earS=0.11,
                    tail=('crini', 0.85), legR=0.09, sx=0.17, hooves=True, mane=True, saddle=True, walk=(22, 34), run=(40, 18)),
}


def build(name, P):
    L, H = P['L'], P['H']
    hipY, chestY = L / 2, -L / 2
    bR, hR = P['bodyR'], P['hipR']
    # ---------------------------------------------------------------- scheletro (posizioni)
    neck0 = Vector((0, chestY - 0.06, H - bR * 0.25))
    a = math.radians(P['neckA'])
    ndir = Vector((0, -math.sin(a), math.cos(a)))
    neck1 = neck0 + ndir * P['neckLen']
    hdir = Vector((0, -1, -0.3 if name != 'cavallo' else -0.75)).normalized()
    skull = neck1 + ndir * P['headR'] * 0.45 + hdir * P['headR'] * 0.3
    snout_end = skull + hdir * (P['headR'] * 0.7 + P['snoutLen'])
    sx = P['sx']
    legs = {}
    for s, k in (('L', 1), ('R', -1)):
        legs['f' + s] = [Vector((sx * k, chestY, H - bR * 0.7)), Vector((sx * k * 1.05, chestY + 0.03, H * 0.5)),
                         Vector((sx * k, chestY, H * 0.16)), Vector((sx * k, chestY - 0.07, 0.025))]
        legs['b' + s] = [Vector((sx * k, hipY, H - hR * 0.6)), Vector((sx * k * 1.05, hipY - 0.13, H * 0.55)),
                         Vector((sx * k, hipY + 0.12, H * 0.25)), Vector((sx * k, hipY + 0.05, 0.025))]
    tail0 = Vector((0, hipY + 0.12, H - 0.04))
    tl = P['tail'][1]
    tail_pts = [tail0, tail0 + Vector((0, tl * 0.4, -tl * 0.1)), tail0 + Vector((0, tl * 0.75, -tl * 0.35)), tail0 + Vector((0, tl * 0.95, -tl * 0.75))]
    if P['tail'][0] == 'lunga':
        tail_pts = [tail0, tail0 + Vector((0, tl * 0.4, -tl * 0.25)), tail0 + Vector((0, tl * 0.75, -tl * 0.35)), tail0 + Vector((0.1, tl, -tl * 0.1))]
    BONES = [
        ('hips', Vector((0, hipY, H - 0.08)), Vector((0, 0.0, H - 0.06)), None),
        ('spine', Vector((0, 0.0, H - 0.06)), Vector((0, chestY * 0.6, H - 0.04)), 'hips'),
        ('chest', Vector((0, chestY * 0.6, H - 0.04)), neck0, 'spine'),
        ('neck', neck0, neck1, 'chest'),
        ('head', neck1, snout_end, 'neck'),
        ('tail1', tail_pts[0], tail_pts[2], 'hips'),
        ('tail2', tail_pts[2], tail_pts[3], 'tail1'),
    ]
    for key in ('fL', 'fR', 'bL', 'bR'):
        j = legs[key]
        par = 'chest' if key[0] == 'f' else 'hips'
        n = key[0] + key[1]
        BONES += [(f'leg_{n}_up', j[0], j[1], par), (f'leg_{n}_low', j[1], j[2], f'leg_{n}_up'), (f'paw_{n}', j[2], j[3], f'leg_{n}_low')]
    BH = {b[0]: b[1] for b in BONES}
    BT = {b[0]: b[2] for b in BONES}
    names = [b[0] for b in BONES]

    # ---------------------------------------------------------------- forme
    PIECES = []

    def add(bm, slot, bones, part='base', smooth=True):
        PIECES.append(dict(bm=bm, slot=slot, bones=bones, part=PART[part], smooth=smooth))

    core = ['hips', 'spine', 'chest', 'neck']
    zc = lambda ry: H - ry * 0.8
    body = [((0, hipY + 0.2, zc(hR * 0.75) + 0.02), hR * 0.55, hR * 0.6), ((0, hipY, zc(hR * 1.1)), hR, hR * 1.1),
            ((0, 0, zc(bR * 0.92)), bR * 0.84, bR * 0.92), ((0, chestY, zc(bR * 1.32)), bR, bR * 1.32 * (1.12 if P.get('hump') else 1)),
            ((0, chestY - 0.16, zc(bR * 0.95)), bR * 0.72, bR * 0.95)]
    add(lathe(body, n=16), lambda c: 'pelo2' if c.z < H - bR * 1.35 else 'pelo', core)
    if P.get('hump'):
        add(sphere((0, chestY + 0.08, H - 0.02), bR * 0.75, (0.9, 1.1, 0.6)), 'pelo', ['spine', 'chest'])
    add(lathe([(neck0 - ndir * 0.08, bR * 0.72, bR * 0.85), (neck0 + ndir * P['neckLen'] * 0.5, P['headR'] * 0.95, P['headR'] * 1.05),
               (neck1, P['headR'] * 0.8, P['headR'] * 0.85)], n=14), 'pelo', ['chest', 'neck', 'head'])
    hr = P['headR']
    add(sphere(skull, hr, (0.95, 1.1, 0.9), seg=18, rings=12), 'pelo', ['head', 'neck'])
    sn0 = skull + hdir * hr * 0.55
    add(lathe([(sn0, P['snoutR'] * 1.25, P['snoutR'] * 1.15), (snout_end - hdir * 0.02, P['snoutR'], P['snoutR'] * 0.85)], n=12),
        'pelo2' if name in ('lupo', 'tigre', 'orso') else 'pelo', ['head'])
    nose = snout_end
    if name == 'cinghiale':
        add(lathe([(nose - hdir * 0.02, P['snoutR'] * 1.05, P['snoutR'] * 0.9), (nose + hdir * 0.02, P['snoutR'] * 1.05, P['snoutR'] * 0.9)], n=14), 'interno', ['head'])
    else:
        add(sphere(nose, P['snoutR'] * 0.45, (1.2, 1, 0.8)), 'scuro', ['head'])
    side = hdir.cross(Vector((0, 0, 1))).normalized()
    for k in (1, -1):
        add(sphere(skull + hdir * hr * 0.55 + side * k * hr * 0.55 + Vector((0, 0, hr * 0.25)), hr * 0.13, seg=10, rings=7), 'occhi', ['head'])
        ear = skull + side * k * hr * 0.55 + Vector((0, 0.02, hr * 0.85))
        if P['ears'] == 'punta':
            add(cone(ear, P['earS'] * 0.45, P['earS'], (0.25, -0.35 * k, 0), seg=6), 'pelo', ['head'])
        else:
            add(sphere(ear, P['earS'], (1, 0.5, 1)), 'pelo', ['head'])
        if P.get('tusks'):
            add(cone(snout_end - hdir * 0.08 + side * k * P['snoutR'] * 0.9, 0.025, 0.16, (-0.9, 0, 0), seg=6), 'zanne', ['head'])
    # zampe
    for key in ('fL', 'fR', 'bL', 'bR'):
        j = legs[key]
        n = key[0] + key[1]
        lr = P['legR'] * (1.0 if key[0] == 'f' else 1.15)
        bones = [f'leg_{n}_up', f'leg_{n}_low', f'paw_{n}', 'chest' if key[0] == 'f' else 'hips']
        top = j[0] + Vector((0, 0, 0.05))
        mid = j[0].lerp(j[1], 0.45)
        add(lathe([(top, lr * 2.2, lr * 2.7), (mid, lr * 1.9, lr * 2.2), (j[1], lr * 1.3, lr * 1.35), (j[2], lr * 0.9, lr * 0.9), (j[3] + Vector((0, 0, 0.06)), lr * 0.85, lr * 0.85)], n=12),
            'pelo', bones)
        if P.get('hooves'):
            add(lathe([(j[3] + Vector((0, -0.02, 0.09)), lr * 0.95, lr * 0.95), (j[3] + Vector((0, -0.03, 0.0)), lr * 1.15, lr * 1.2)], n=12), 'scuro', bones)
        else:
            add(sphere(j[3] + Vector((0, -0.04, 0.04)), lr * 1.3, (1, 1.35, 0.6)), 'scuro' if name == 'cinghiale' else 'pelo2', bones)
    # coda
    kind = P['tail'][0]
    tr = {'folta': (0.04, 0.075, 0.02), 'sottile': (0.02, 0.015, 0.008), 'mozza': (0.07, 0.06, 0.03), 'lunga': (0.045, 0.04, 0.03), 'crini': (0.07, 0.11, 0.05)}[kind]
    tp = catmull(tail_pts, 3)
    prof = [(p, max(0.008, tr[0] + (tr[1] - tr[0]) * math.sin(min(1, i / (len(tp) - 1) * 1.6) * math.pi / 2) - (tr[1] - tr[2]) * max(0, i / (len(tp) - 1) - 0.6) / 0.4),
             0) for i, p in enumerate(tp)]
    prof = [(p, r, r * (0.6 if kind == 'crini' else 1)) for p, r, _ in prof]
    add(lathe(prof, n=10), 'criniera' if kind == 'crini' else 'pelo', ['hips', 'tail1', 'tail2'])
    if P.get('mane'):
        mpts = [neck0 + ndir * (P['neckLen'] * t) + Vector((0, 0.06, P['headR'] * 0.75)) for t in (0.0, 0.35, 0.7, 1.05)]
        add(lathe([(p, 0.035, 0.11) for p in catmull(mpts, 2)], n=8), 'criniera', ['chest', 'neck', 'head'])
    if P.get('bristles'):
        for i in range(7):
            p = Vector((0, hipY - i * L / 6, H + 0.02))
            add(cone(p, 0.04, 0.12, (0, 0, 0), seg=4), 'scuro', core, smooth=False)
    if P.get('saddle'):
        add(lathe([((0, 0.18, H + 0.03), 0.28, 0.06), ((0, -0.08, H + 0.06), 0.3, 0.07), ((0, -0.3, H + 0.04), 0.26, 0.05)], n=14), 'sella', ['spine', 'hips', 'chest'], part='sella')
        add(lathe([((0, -0.12, H + 0.12), 0.06, 0.05), ((0, -0.2, H + 0.18), 0.05, 0.05)], n=8), 'sella', ['spine', 'chest'], part='sella')
        for k in (1, -1):
            add(box((k * (bR + 0.02), -0.05, H - 0.2), (0.025, 0.62, 0.42), (0, 0, 0)), 'stoffa', ['spine', 'hips', 'chest'], part='sella', smooth=False)
        add(box((0, chestY - 0.22, H - 0.05), (bR * 1.4, 0.06, 0.4), (0.2, 0, 0)), 'oro', ['chest', 'neck'], part='bardatura', smooth=False)
        add(box((0, chestY - 0.1, H - bR - 0.05), (bR * 2.2, 0.5, 0.08)), 'oro', ['chest'], part='bardatura', smooth=False)
        add(lathe([(skull + hdir * hr * 0.2 + Vector((0, 0, hr * 0.7)), hr * 0.5, 0.03), (skull + hdir * (hr + 0.2) + Vector((0, 0, hr * 0.4)), hr * 0.45, 0.03)], n=10),
            'oro', ['head'], part='bardatura')

    # ---------------------------------------------------------------- mesh per parte (liscia), ombre, unione
    objs = []
    for pid in sorted({pc['part'] for pc in PIECES}):
        bm = bmesh.new()
        uv0 = bm.loops.layers.uv.new('UVMap')
        uv1 = bm.loops.layers.uv.new('Part')
        dl = bm.verts.layers.deform.verify()
        BI = {n: i for i, n in enumerate(names)}
        for pc in [p for p in PIECES if p['part'] == pid]:
            src, vmap = pc['bm'], {}
            for v in src.verts:
                nv = bm.verts.new(v.co)
                for b, w in weights_for(v.co, pc['bones'], BH, BT):
                    nv[dl][BI[b]] = w
                vmap[v] = nv
            for f in src.faces:
                nf = bm.faces.new([vmap[v] for v in f.verts])
                nf.smooth = pc['smooth']
                slot = pc['slot'](f.calc_center_median()) if callable(pc['slot']) else pc['slot']
                for lp in nf.loops:
                    lp[uv0].uv = slot_uv(slot)
                    lp[uv1].uv = (pid, 0)
            src.free()
        ob = make_obj(scene, f'{name}_{pid}', bm, names)
        apply_subsurf(ob)
        shade_vertices(ob, reach=0.3 * max(1, H))
        objs.append(ob)
    if len(objs) > 1:
        select_only(scene, objs, objs[0])
        bpy.ops.object.join()
    body_ob = objs[0]
    body_ob.name = name
    me = body_ob.data
    me.materials.clear()
    mat = bpy.data.materials.get('animale') or bpy.data.materials.new('animale')
    me.materials.append(mat)
    me.uv_layers.active = me.uv_layers['UVMap']

    # ---------------------------------------------------------------- armatura
    arm_data = bpy.data.armatures.new(name + '_scheletro')
    arm = bpy.data.objects.new(name + '_scheletro', arm_data)
    scene.collection.objects.link(arm)
    select_only(scene, [arm], arm)
    bpy.ops.object.mode_set(mode='EDIT')
    for bn, h, t, parent in BONES:
        eb = arm_data.edit_bones.new(bn)
        eb.head, eb.tail = h, t
        eb.roll = 0
        if parent:
            eb.parent = arm_data.edit_bones[parent]
            eb.use_connect = (h - arm_data.edit_bones[parent].tail).length < 1e-4
    bpy.ops.object.mode_set(mode='OBJECT')
    body_ob.parent = arm
    body_ob.modifiers.new('scheletro', 'ARMATURE').object = arm

    # ---------------------------------------------------------------- animazioni
    TAU = math.pi * 2
    fwd = lambda d: ('X', -d)
    wa, wf = P['walk']
    ra, rf = P['run']
    tails = lambda p, amp=12: {'tail1': [('Z', amp * math.sin(TAU * p))], 'tail2': [('Z', amp * 1.3 * math.sin(TAU * p - 0.8))]}

    def legs_pose(ph, amp, bend):
        out = {}
        for n, off in ph.items():
            s, c = math.sin(TAU * off), math.cos(TAU * off)
            out[f'leg_{n}_up'] = [fwd(amp * s)]
            if n[0] == 'f':
                out[f'leg_{n}_low'] = [('X', bend * max(0, c) ** 1.5)]
                out[f'paw_{n}'] = [('X', bend * 0.6 * max(0, c))]
            else:
                out[f'leg_{n}_low'] = [('X', -bend * 0.7 * max(0, c) ** 1.5)]
                out[f'paw_{n}'] = [('X', bend * 0.5 * max(0, c))]
        return out

    def cycle(aname, frames, steps, fn):
        keys = [(round(frames * i / steps), fn(i / steps)) for i in range(steps)]
        keys.append((frames, fn(0.0)))
        return make_action(arm, f'{name}:{aname}', keys, loop=True)

    acts = []
    acts.append(cycle('fermo', 60, 6, lambda p: {**tails(p, 8), 'chest': [('X', 1.5 * math.sin(TAU * p))],
                                                  'neck': [('Z', 10 * math.sin(TAU * p * 0.5 + 1))], 'head': [('X', 3 * math.sin(TAU * p))]}))
    acts.append(cycle('passo', wf, 8, lambda p: {**legs_pose({'fL': p, 'bR': p + 0.02, 'fR': p + 0.5, 'bL': p + 0.52}, wa, 30), **tails(p, 10),
                                                  'neck': [('X', 3 * math.sin(TAU * p * 2))], 'loc': (0, 0, 0.018 * math.cos(2 * TAU * p))}))
    acts.append(cycle('corsa', rf, 8, lambda p: {**legs_pose({'fL': p, 'fR': p - 0.1, 'bL': p + 0.5, 'bR': p + 0.4}, ra, 55), **tails(p, 6),
                                                  'spine': [('X', 7 * math.sin(TAU * p))], 'chest': [('X', -5 * math.sin(TAU * p))],
                                                  'neck': [('X', -6 * math.sin(TAU * p))], 'loc': (0, 0, 0.05 * math.sin(TAU * p) + 0.02)}))
    crouch = {'leg_fL_up': [fwd(-12)], 'leg_fR_up': [fwd(-12)], 'leg_fL_low': [('X', 25)], 'leg_fR_low': [('X', 25)], 'loc': (0, 0.05, -0.06),
              'neck': [('X', 15)], 'head': [('X', -10)]}
    lunge = {'leg_fL_up': [fwd(35)], 'leg_fR_up': [fwd(30)], 'leg_bL_up': [fwd(-25)], 'leg_bR_up': [fwd(-25)], 'loc': (0, -0.22, 0.03),
             'neck': [('X', 22)], 'head': [('X', 18)], 'spine': [('X', -6)]}
    bite = {**lunge, 'head': [('X', -14)], 'neck': [('X', 12)]}
    acts.append(make_action(arm, f'{name}:attacco', [(0, {}), (5, crouch), (9, lunge), (11, bite), (18, {})]))
    acts.append(make_action(arm, f'{name}:colpito', [(0, {}), (3, {'neck': [('X', -18), ('Z', 10)], 'chest': [('X', -6)], 'loc': (0, 0.06, 0)}), (9, {})]))
    fall = {'hips': [('Y', 80)], 'loc': (0, 0, -(H - bR * 1.1) * 0.85)}
    for n in ('fL', 'fR', 'bL', 'bR'):
        fall[f'leg_{n}_up'] = [fwd(15 if n[0] == 'f' else -15)]
    acts.append(make_action(arm, f'{name}:morte', [(0, {}), (8, {'leg_fL_low': [('X', 50)], 'leg_fR_low': [('X', 50)], 'loc': (0, 0, -0.15), 'neck': [('X', 20)]}),
                                                     (20, fall), (30, {**fall, 'neck': [('X', -10), ('Y', 20)]})]))
    stash_actions(arm, acts)
    print(f'{name}: {len(me.vertices)} vertici, {len(acts)} azioni, altezza {H:.2f}')
    return arm


for nm, P in SPECIES.items():
    arm = build(nm, P)
    arm.location.x = list(SPECIES).index(nm) * 3.0  # in fila (solo per il file .blend); il gioco li usa separati

os.makedirs(os.path.dirname(OUT), exist_ok=True)
for o in scene.objects:
    if o.type == 'ARMATURE':
        o.location.x = 0
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_animations=True, export_animation_mode='ACTIONS',
                          export_force_sampling=True, export_skins=True, export_def_bones=False, export_morph=False,
                          export_yup=True, export_texcoords=True, export_normals=True, export_materials='EXPORT', export_apply=False)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, 'animali.blend'))
print('ESPORTATO', OUT)
