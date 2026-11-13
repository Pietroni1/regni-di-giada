# Regni di Giada — importa i personaggi riggati su Mixamo e le loro animazioni.
#
# Uso (una cartella intera):
#   blender -b --factory-startup --python tools/blender/importa_mixamo.py -- modelli/mixamo client/assets/modelli \
#       [--altezza 2.35] [--triangoli 60000] [--texture 2048] [--ruota 0] [--draco 1] [--solo base_uomo]
#
# I personaggi il cui nome comincia con "base_" sono corpi base: ricevono i capi (crea_capi) e le armature per grado
# (armature.py), che il gioco accende in base all'equipaggiamento.
#
# Nella cartella di origine:
#   - i file .fbx con un nome di animazione (fermo, camminata, corsa, spada_1..3, pugnali, pugni, calcio, arco,
#     magia, colpito, morte, sella...) sono animazioni "Without Skin": finiscono tutte in mixamo_anim.glb,
#     una volta sola per tutti i personaggi;
#   - tutti gli altri .fbx sono personaggi "With Skin" in posa a T: ognuno diventa NOME.glb (senza animazioni).
# Le ossa "mixamorig:*" prendono i nomi del gioco (hips, spine, chest, hand_R...), così armi, cappelli e
# divisione parte alta / parte bassa funzionano come per gli altri personaggi.
# Alla fine i personaggi vengono aggiunti a indice.json (sezione "modelli"); l'assegnazione a classi, PNG e
# mostri resta da scrivere a mano.
import bpy, bmesh, sys, os, re, json, math
from mathutils import Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from armature import crea_armature

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
pos_args = [a for i, a in enumerate(argv) if not a.startswith('--') and (i == 0 or not argv[i - 1].startswith('--'))]
opt = {argv[i][2:]: argv[i + 1] for i in range(len(argv) - 1) if argv[i].startswith('--')}
SRC, OUT = os.path.abspath(pos_args[0]), os.path.abspath(pos_args[1])
H = float(opt.get('altezza', 2.35))
TRI = int(opt.get('triangoli', 60000))
TEX = int(opt.get('texture', 2048))
ROT = float(opt.get('ruota', 0))
DRACO = opt.get('draco', '1') != '0'
SOLO = opt.get('solo')          # --solo base_uomo: rifà solo quel personaggio, senza toccare le animazioni
ANIM_FILE = 'mixamo_anim.glb'

ANIMAZIONI = {'fermo', 'camminata', 'corsa', 'sella', 'spada_1', 'spada_2', 'spada_3', 'pugnali', 'pugnali_1', 'pugnali_2',
              'pugni', 'pugni_1', 'pugni_2', 'pugni_3', 'calcio', 'arco', 'bastone', 'magia', 'colpito', 'morte'}

# ------------------------------------------------------------------ nomi delle ossa
CENTRO = {'Hips': 'hips', 'Spine': 'spine', 'Spine1': 'spine_1', 'Spine2': 'chest', 'Neck': 'neck', 'Head': 'head',
          'HeadTop_End': 'head_end'}
LATO = {'Shoulder': 'shoulder', 'Arm': 'upper_arm', 'ForeArm': 'forearm', 'Hand': 'hand', 'UpLeg': 'thigh', 'Leg': 'shin',
        'Foot': 'foot', 'ToeBase': 'toe', 'Toe_End': 'toe_end'}


def nome_gioco(nome):
    n = re.sub(r'^mixamorig\d*[:_]?', '', nome)
    if n in CENTRO:
        return CENTRO[n]
    m = re.match(r'^(Left|Right)(.+)$', n)
    if not m:
        return n.lower()
    s, resto = m.group(1)[0], m.group(2)
    if resto in LATO:
        return f'{LATO[resto]}_{s}'
    d = re.match(r'^Hand(Thumb|Index|Middle|Ring|Pinky)(\d)$', resto)   # dita: restano nella "parte alta" (hand_*)
    if d:
        return f'hand_{s}_{d.group(1).lower()}{d.group(2)}'
    return f'{resto.lower()}_{s}'


def rinomina_ossa(arm):
    for b in arm.data.bones:
        nuovo = nome_gioco(b.name)
        if nuovo != b.name:
            b.name = nuovo


def seleziona(objs, attivo):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = attivo


def importa_fbx(path):
    prima = set(bpy.data.objects)
    try:
        bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=False, ignore_leaf_bones=False,use_anim=True)
    except AttributeError:
        bpy.ops.wm.fbx_import(filepath=path)
    nuovi = [o for o in bpy.data.objects if o not in prima]
    arm = next((o for o in nuovi if o.type == 'ARMATURE'), None)
    return arm, [o for o in nuovi if o.type == 'MESH'], nuovi


def esporta(path, **kw):
    base = dict(filepath=path, export_format='GLB', export_skins=True, export_def_bones=False, export_morph=False,
                export_yup=True, export_texcoords=True, export_normals=True, export_apply=False)
    base.update(kw)
    bpy.ops.export_scene.gltf(**base)


# ------------------------------------------------------------------ animazioni: un solo scheletro, una traccia per azione
def importa_animazioni(files):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = 30
    princ, azioni = None, []
    for nome, path in files:
        arm, meshes, nuovi = importa_fbx(path)
        if not arm or not arm.animation_data or not arm.animation_data.action:
            print('SALTATA (nessuna animazione):', path)
            for o in nuovi:
                bpy.data.objects.remove(o, do_unlink=True)
            continue
        rinomina_ossa(arm)           # con l'azione assegnata: Blender aggiorna anche i percorsi delle curve
        az = arm.animation_data.action
        az.name = nome
        az.use_fake_user = True
        azioni.append(az)
        for o in meshes:             # se per sbaglio è "With Skin" la pelle non serve
            bpy.data.objects.remove(o, do_unlink=True)
        if princ is None:
            princ = arm
        else:
            for o in nuovi:
                if o.type != 'MESH' and o is not arm:
                    bpy.data.objects.remove(o, do_unlink=True)
            bpy.data.objects.remove(arm, do_unlink=True)
    if not princ:
        return []
    princ.name = 'scheletro'
    for o in [o for o in scene.objects if o is not princ]:
        bpy.data.objects.remove(o, do_unlink=True)
    # solo la rotazione: la scala resta (i movimenti del bacino sono nelle unità del file, il gioco li riscala)
    seleziona([princ], princ)
    if ROT:
        princ.rotation_euler.z += math.radians(ROT)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    ad = princ.animation_data
    ad.action = None
    fine = 1
    for az in azioni:
        tr = ad.nla_tracks.new()
        tr.name = az.name
        st = tr.strips.new(az.name, int(az.frame_range[0]), az)
        if hasattr(st, 'action_slot') and st.action_slot is None and len(az.slots):
            st.action_slot = az.slots[0]
        fine = max(fine, int(az.frame_range[1]))
        print(f'animazione {az.name:12s} fotogrammi {az.frame_range[0]:.0f}-{az.frame_range[1]:.0f}')
    scene.frame_end = fine
    esporta(os.path.join(OUT, ANIM_FILE), export_animations=True, export_animation_mode='NLA_TRACKS', export_force_sampling=True,
            export_optimize_animation_size=True, export_anim_slide_to_zero=True, export_materials='NONE')
    return [a.name for a in azioni]


# ------------------------------------------------------------------ capi: gusci ricavati dal corpo, già pesati sulle ossa
# Ogni capo copia le facce di una zona del corpo (scelta dall'osso che pesa di più su ogni vertice) e le gonfia
# lungo le normali: calza per forza e segue le animazioni. Il gioco li accende in base all'equipaggiamento e li tinge.
TORSO = ('spine', 'spine_1', 'chest', 'shoulder_L', 'shoulder_R')
CAPI_DEF = [  # nome, spessore (m per un corpo alto 1,8), metallo
    ('pantaloni', 0.010, 0.0),
    ('veste', 0.017, 0.0),
]
CAPI = {}


def crea_capi(ob, arm):
    me = ob.data
    gruppi = {g.index: g.name for g in ob.vertex_groups}
    osso = []
    for v in me.vertices:
        g = max(v.groups, key=lambda x: x.weight, default=None)
        osso.append(gruppi.get(g.group, '') if g else '')
    B = arm.data.bones
    ginocchio = B['shin_L'].head_local.z
    def nel_capo(nome, i):
        b, co = osso[i], me.vertices[i].co
        if nome == 'pantaloni':
            return b == 'hips' or b.startswith(('thigh_', 'shin_'))
        if nome == 'veste':
            return b in TORSO or b == 'hips' or b.startswith('upper_arm_')
        if nome == 'stivali':
            return b.startswith(('foot_', 'toe_')) or (b.startswith('shin_') and co.z < ginocchio * 0.62)
        if nome == 'bracciali':
            return b.startswith('forearm_')
        if nome == 'armatura':
            if b in ('chest', 'spine_1', 'shoulder_L', 'shoulder_R'):
                return True
            if b.startswith('upper_arm_'):
                ua = B[b]
                return (co - ua.head_local).length < ua.length * 0.5
        return False
    fatti = []
    for nome, spessore, metallo in CAPI_DEF:
        dentro = [nel_capo(nome, i) for i in range(len(me.vertices))]
        capo = ob.copy()
        capo.data = me.copy()
        capo.name = capo.data.name = 'capo_' + nome
        bpy.context.scene.collection.objects.link(capo)
        bm = bmesh.new()
        bm.from_mesh(capo.data)
        via = [f for f in bm.faces if not all(dentro[v.index] for v in f.verts)]
        bmesh.ops.delete(bm, geom=via, context='FACES')
        if len(bm.faces) < 20:
            bm.free()
            bpy.data.objects.remove(capo, do_unlink=True)
            continue
        bm.normal_update()
        d = spessore * H / 1.8
        for v in bm.verts:
            v.co += v.normal * d
        bm.to_mesh(capo.data)
        bm.free()
        mat = bpy.data.materials.new('capo_' + nome)
        mat.use_nodes = True
        bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
        bsdf.inputs['Base Color'].default_value = (1, 1, 1, 1)
        bsdf.inputs['Roughness'].default_value = 0.55 if metallo else 0.85
        bsdf.inputs['Metallic'].default_value = metallo
        capo.data.materials.clear()
        capo.data.materials.append(mat)
        for p in capo.data.polygons:
            p.material_index = 0
            p.use_smooth = True
        mod = capo.modifiers.new('riduci', 'DECIMATE')
        mod.ratio = 0.5
        seleziona([capo], capo)
        bpy.ops.object.modifier_move_to_index(modifier='riduci', index=0)
        bpy.ops.object.modifier_apply(modifier='riduci')
        fatti.append(nome)
    return fatti


# ------------------------------------------------------------------ personaggio: scala, poligoni, texture
def importa_personaggio(nome, path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    arm, meshes, nuovi = importa_fbx(path)
    if not arm or not meshes:
        print('SALTATO (serve un FBX "With Skin"):', path)
        return False
    if arm.animation_data:
        arm.animation_data_clear()
    for o in nuovi:
        if o is not arm and o not in meshes:
            bpy.data.objects.remove(o, do_unlink=True)
    rinomina_ossa(arm)
    arm.name = 'scheletro'
    arm.data.pose_position = 'REST'
    if ROT:
        arm.rotation_euler.z += math.radians(ROT)
    seleziona([arm] + meshes, arm)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(meshes) > 1:
        seleziona(meshes, meshes[0])
        bpy.ops.object.join()
    ob = meshes[0]
    ob.name = 'personaggio'
    me = ob.data
    if me.shape_keys:
        ob.shape_key_clear()
    # altezza del gioco e piedi a terra
    bpy.context.view_layer.update()
    zs = [(ob.matrix_world @ v.co).z for v in me.vertices]
    lo, hi = min(zs), max(zs)
    k = H / (hi - lo)
    arm.matrix_world = Matrix.Translation((0, 0, -lo * k)) @ Matrix.Scale(k, 4) @ arm.matrix_world
    bpy.context.view_layer.update()
    seleziona([arm, ob], arm)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # riduzione dei poligoni (mantiene UV, pesi e texture)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    if tris > TRI:
        mod = ob.modifiers.new('riduci', 'DECIMATE')
        mod.ratio = TRI / tris
        seleziona([ob], ob)
        bpy.ops.object.modifier_move_to_index(modifier='riduci', index=0)
        bpy.ops.object.modifier_apply(modifier='riduci')
    tris2 = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    for img in bpy.data.images:
        if img.size[0] > TEX or img.size[1] > TEX:
            img.scale(min(TEX, img.size[0]), min(TEX, img.size[1]))
    capi = crea_capi(ob, arm) + crea_armature(ob, arm, H) if nome.startswith('base_') else []
    arm.data.pose_position = 'POSE'
    out = os.path.join(OUT, nome + '.glb')
    kw = dict(export_animations=False, export_materials='EXPORT')
    if DRACO:
        kw.update(export_draco_mesh_compression_enable=True, export_draco_mesh_compression_level=6)
    try:
        esporta(out, export_image_format='WEBP', **kw)
    except TypeError:
        esporta(out, **kw)
    print(f'personaggio {nome}: triangoli {tris} -> {tris2}, ossa {len(arm.data.bones)}, capi {capi}, {os.path.getsize(out) / 1e6:.1f} MB')
    CAPI[nome] = capi
    return True


# ------------------------------------------------------------------ cartella
os.makedirs(OUT, exist_ok=True)
anim, pers = [], []
for f in sorted(os.listdir(SRC)):
    if not f.lower().endswith('.fbx'):
        continue
    nome = re.sub(r'[^a-z0-9]+', '_', os.path.splitext(f)[0].lower()).strip('_')
    (anim if nome in ANIMAZIONI else pers).append((nome, os.path.join(SRC, f)))
print(f'animazioni: {[n for n, _ in anim]}\npersonaggi: {[n for n, _ in pers]}')

if SOLO:
    pers = [(n, p) for n, p in pers if n == SOLO]
fatte = importa_animazioni(anim) if anim and not SOLO else []
ha_anim = bool(fatte) or os.path.exists(os.path.join(OUT, ANIM_FILE))
fatti = [n for n, p in pers if importa_personaggio(n, p)]

idx_path = os.path.join(OUT, 'indice.json')
idx = {'modelli': {}, 'classi': {}, 'mostri': {}, 'png': {}}
if os.path.exists(idx_path):
    with open(idx_path, encoding='utf-8') as fh:
        idx.update(json.load(fh))
for n in fatti:
    d = idx['modelli'].setdefault(n, {})
    d['file'] = n + '.glb'
    if ha_anim:
        d['anim'] = ANIM_FILE
    if CAPI.get(n):
        d['capi'] = CAPI[n]
with open(idx_path, 'w', encoding='utf-8') as fh:
    json.dump(idx, fh, indent=2, ensure_ascii=False)
    fh.write('\n')
print('FATTO — animazioni:', fatte, 'personaggi:', fatti)
