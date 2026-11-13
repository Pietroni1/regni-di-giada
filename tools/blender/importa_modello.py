# Regni di Giada — importa un modello umanoide ad alta definizione (per esempio generato con un
# servizio da immagine a 3D) e lo prepara per il gioco: scala, orientamento, poligoni, scheletro
# standard con pesi automatici e le 17 animazioni dei personaggi. Le texture originali restano.
#
# Uso:
#   blender -b --factory-startup --python tools/blender/importa_modello.py -- modelli/orco.glb client/assets/modelli/orco.glb \
#       [--altezza 2.6] [--triangoli 80000] [--ruota 0] [--texture 2048]
#
# Il modello va fatto in posa a T (o ad A), in piedi, visto di fronte. --ruota gira il modello
# (in gradi) se nel file guarda da un'altra parte: il gioco vuole il personaggio rivolto verso -Y di Blender.
import bpy, bmesh, math, sys, os
import numpy as np
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from forme import weights_for, select_only
from umanoide_anim import crea_animazioni

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
pos_args = [a for i, a in enumerate(argv) if not a.startswith('--') and (i == 0 or not argv[i - 1].startswith('--'))]
opt = {argv[i][2:]: argv[i + 1] for i in range(len(argv) - 1) if argv[i].startswith('--')}
SRC, OUT = os.path.abspath(pos_args[0]), os.path.abspath(pos_args[1])
H = float(opt.get('altezza', 2.35))
TRI = int(opt.get('triangoli', 80000))
ROT = float(opt.get('ruota', 0))
TEX = int(opt.get('texture', 2048))

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=SRC)

# ------------------------------------------------------------------ una sola mesh, senza vecchie armature
meshes = [o for o in scene.objects if o.type == 'MESH']
select_only(scene, meshes, meshes[0])
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
for o in meshes:
    for m in list(o.modifiers):
        o.modifiers.remove(m)
    o.shape_key_clear() if o.data.shape_keys else None
for o in [o for o in scene.objects if o.type != 'MESH']:
    bpy.data.objects.remove(o, do_unlink=True)
select_only(scene, meshes, meshes[0])
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
if len(meshes) > 1:
    bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
ob.name = 'personaggio'
me = ob.data
for vg in list(ob.vertex_groups):
    ob.vertex_groups.remove(vg)

# pulizia: vertici doppi (aiuta il calcolo dei pesi)
bm = bmesh.new()
bm.from_mesh(me)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
bm.to_mesh(me)
bm.free()

# ------------------------------------------------------------------ orientamento, scala, appoggio a terra
if ROT:
    me.transform(Matrix.Rotation(math.radians(ROT), 4, 'Z'))
V = np.array([v.co[:] for v in me.vertices])
lo, hi = V.min(0), V.max(0)
k = H / (hi[2] - lo[2])
me.transform(Matrix.Scale(k, 4) @ Matrix.Translation(Vector((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]))))
me.update()

# ------------------------------------------------------------------ riduzione dei poligoni (mantiene UV e texture)
tris = sum(len(p.vertices) - 2 for p in me.polygons)
if tris > TRI:
    mod = ob.modifiers.new('riduci', 'DECIMATE')
    mod.ratio = TRI / tris
    select_only(scene, [ob], ob)
    bpy.ops.object.modifier_apply(modifier='riduci')
tris2 = sum(len(p.vertices) - 2 for p in me.polygons)
print(f'triangoli: {tris} -> {tris2}')
for p in me.polygons:
    p.use_smooth = True

# texture troppo grandi: ridotte (il gioco gira nel browser)
for img in bpy.data.images:
    if img.size[0] > TEX or img.size[1] > TEX:
        img.scale(min(TEX, img.size[0]), min(TEX, img.size[1]))

# ------------------------------------------------------------------ stima delle articolazioni (posa a T o ad A)
V = np.array([v.co[:] for v in me.vertices])
X, Y, Z = V[:, 0], V[:, 1], V[:, 2]


def slice_center(z, band=0.03):
    m = np.abs(Z - z) < band * H
    m &= np.abs(X) < 0.12 * H
    return (float(np.median(Y[m])) if m.any() else 0.0)


upper = Z > 0.42 * H
# spalle: dove finisce il "busto" (colonna alta) e comincia il braccio (sottile in verticale)
bins = np.linspace(-0.6 * H, 0.6 * H, 121)
ext = np.zeros(len(bins) - 1)
for i in range(len(bins) - 1):
    m = upper & (X >= bins[i]) & (X < bins[i + 1])
    ext[i] = (Z[m].max() - Z[m].min()) if m.sum() > 3 else 0
mid = len(ext) // 2
torso_ext = max(ext[mid - 2:mid + 2])
shoulder = {}
for s, step in (('L', 1), ('R', -1)):
    i = mid
    while 0 < i < len(ext) - 1 and ext[i] > 0.45 * torso_ext:
        i += step
    sx = (bins[i] + bins[i + 1]) / 2 - step * 0.02 * H
    near = upper & (np.abs(X - (sx + step * 0.04 * H)) < 0.03 * H)
    sz = float(np.median(Z[near])) if near.any() else 0.8 * H
    shoulder[s] = Vector((sx, slice_center(sz), min(sz, 0.84 * H)))
# mani: punti più esterni delle braccia
hand = {}
for s, sgn in (('L', 1), ('R', -1)):
    cand = np.where(upper & (sgn * X > 0))[0] if s == 'L' else np.where(upper & (X < 0))[0]
    j = cand[np.argmax(sgn * X[cand])]
    hand[s] = Vector(V[j])
# piedi
low = Z < 0.07 * H
foot = {}
for s, sgn in (('L', 1), ('R', -1)):
    m = low & (sgn * X > 0.01 * H)
    c = V[m].mean(0) if m.any() else np.array([sgn * 0.08 * H, 0, 0.03 * H])
    toe_y = Y[m].min() if m.any() else c[1] - 0.06 * H
    foot[s] = (Vector(c), float(toe_y))
zs_avg = (shoulder['L'].z + shoulder['R'].z) / 2
zh = zs_avg * 0.61  # bacino: proporzione rispetto alle spalle (vale per figure realistiche e stilizzate)
J = {}
J['hips'] = Vector((0, slice_center(zh), zh))
J['spine'] = Vector((0, slice_center(zh + (zs_avg - zh) * 0.35), zh + (zs_avg - zh) * 0.35))
J['chest'] = Vector((0, slice_center(zh + (zs_avg - zh) * 0.7), zh + (zs_avg - zh) * 0.7))
J['neck'] = Vector((0, slice_center(zs_avg + 0.02 * H), zs_avg + 0.02 * H))
J['head'] = Vector((0, slice_center(zs_avg + (H - zs_avg) * 0.35), zs_avg + (H - zs_avg) * 0.35))
J['head_top'] = Vector((0, J['head'].y, H * 0.98))

BONES = [
    ('hips', J['hips'], J['spine'], None),
    ('spine', J['spine'], J['chest'], 'hips'),
    ('chest', J['chest'], J['neck'], 'spine'),
    ('neck', J['neck'], J['head'], 'chest'),
    ('head', J['head'], J['head_top'], 'neck'),
]
for s, sgn in (('L', 1), ('R', -1)):
    sh = shoulder[s]
    tip = hand[s]
    d = (tip - sh)
    wrist = tip - d.normalized() * 0.075 * H
    elbow = sh + (wrist - sh) * 0.5 + Vector((0, 0.01 * H, 0))
    clav = Vector((sgn * 0.03 * H, J['neck'].y, sh.z - 0.01 * H))
    fc, toe_y = foot[s]
    ankle = Vector((fc.x, fc.y + 0.02 * H, 0.055 * H))
    hipj = Vector((fc.x * 0.85, J['hips'].y, zh - 0.02 * H))
    knee = Vector(((hipj.x + ankle.x) / 2, (hipj.y + ankle.y) / 2 - 0.01 * H, (hipj.z + ankle.z) / 2 + 0.01 * H))
    toe = Vector((fc.x, toe_y + 0.02 * H, 0.02 * H))
    BONES += [
        (f'shoulder_{s}', clav, sh, 'chest'),
        (f'upper_arm_{s}', sh, elbow, f'shoulder_{s}'),
        (f'forearm_{s}', elbow, wrist, f'upper_arm_{s}'),
        (f'hand_{s}', wrist, tip, f'forearm_{s}'),
        (f'thigh_{s}', hipj, knee, 'hips'),
        (f'shin_{s}', knee, ankle, f'thigh_{s}'),
        (f'foot_{s}', ankle, toe, f'shin_{s}'),
    ]
for b in BONES:
    print(f'osso {b[0]:12s} {tuple(round(c, 3) for c in b[1])} -> {tuple(round(c, 3) for c in b[2])}')

arm_data = bpy.data.armatures.new('scheletro')
arm = bpy.data.objects.new('scheletro', arm_data)
scene.collection.objects.link(arm)
select_only(scene, [arm], arm)
bpy.ops.object.mode_set(mode='EDIT')
for name, h, t, parent in BONES:
    eb = arm_data.edit_bones.new(name)
    eb.head, eb.tail = h, t
    eb.roll = 0
    if parent:
        eb.parent = arm_data.edit_bones[parent]
        eb.use_connect = (h - arm_data.edit_bones[parent].tail).length < 1e-4
bpy.ops.object.mode_set(mode='OBJECT')

# ------------------------------------------------------------------ pesi: automatici (calore delle ossa), con riserva
select_only(scene, [ob, arm], arm)
try:
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
except Exception as e:
    print('pesi automatici non riusciti:', e)
if not ob.parent:
    ob.parent = arm
    ob.modifiers.new('scheletro', 'ARMATURE').object = arm
BH = {b[0]: b[1] for b in BONES}
BT = {b[0]: b[2] for b in BONES}
names = [b[0] for b in BONES]
for n in names:
    if n not in ob.vertex_groups:
        ob.vertex_groups.new(name=n)
groups = {g.index: g.name for g in ob.vertex_groups}
missing = 0
for v in me.vertices:
    tot = sum(g.weight for g in v.groups if groups.get(g.group) in BH)
    if tot > 0.05:
        continue
    missing += 1
    p = v.co
    side = 'L' if p.x > 0 else 'R'
    allowed = ['hips', 'spine', 'chest', 'neck', 'head'] + [f'{b}_{side}' for b in ('shoulder', 'upper_arm', 'forearm', 'hand', 'thigh', 'shin', 'foot')]
    for b, w in weights_for(p, allowed, BH, BT):
        ob.vertex_groups[b].add([v.index], w, 'REPLACE')
print(f'vertici senza pesi riparati: {missing} su {len(me.vertices)}')

# ------------------------------------------------------------------ animazioni e esportazione
ACTIONS = crea_animazioni(arm, scala=H / 2.35)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_animations=True, export_animation_mode='ACTIONS',
                          export_force_sampling=True, export_skins=True, export_def_bones=False, export_morph=False,
                          export_yup=True, export_texcoords=True, export_normals=True, export_materials='EXPORT', export_apply=False)
os.makedirs(os.path.join(HERE, 'modelli'), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, 'modelli', os.path.splitext(os.path.basename(OUT))[0] + '.blend'))
print('ESPORTATO', OUT, 'azioni:', len(ACTIONS))
