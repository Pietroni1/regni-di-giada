# Porta nel gioco i personaggi base «da eroe» di modelli/eroi/ (Quaternius, CC0: vedi modelli/eroi/LEGGIMI.md).
#
#   blender -b --factory-startup --python tools/blender/importa_eroi.py -- modelli/eroi client/assets/modelli
#   (oppure: python3 tools/blender/importa_eroi.py -- modelli/eroi client/assets/modelli   con il modulo bpy)
#
# Cosa fa:
#   - rinomina le ossa (scheletro in stile Unreal: pelvis, spine_01, upperarm_l...) con i nomi del gioco (hips, spine,
#     upper_arm_L...), così armi, capi, capelli e parte alta/bassa del corpo funzionano come con gli altri modelli;
#   - sceglie dalla Universal Animation Library le animazioni che servono (tabella ANIMAZIONI) → eroe_anim.glb;
#   - per ogni corpo: altezza del gioco, capigliature legate alla testa (capo_capelli_*), vesti/armature/elmi/calzari
#     ricostruiti attorno al corpo (le stesse funzioni di importa_mixamo.py) → base_uomo.glb, base_donna.glb;
#   - aggiorna indice.json (anim, capi, "dipinto": il corpo tiene le sue texture invece della pelle da shader).
import bpy, sys, os, re, json, math, tempfile
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
if len(argv) < 2:
    raise SystemExit('uso: importa_eroi.py -- modelli/eroi client/assets/modelli')
SRC, OUT = os.path.abspath(argv[0]), os.path.abspath(argv[1])
# le funzioni comuni stanno in importa_mixamo.py, che è uno script: lo si carica su una cartella vuota
sys.argv = sys.argv[:sys.argv.index('--') + 1] + [tempfile.mkdtemp(), OUT] + argv[2:]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importa_mixamo as M

ANIM_FILE = 'eroe_anim.glb'
# nome nel gioco → azione della libreria (la prima che esiste)
ANIMAZIONI = {
    'fermo': ['Idle_Loop'], 'guardia': ['Sword_Idle'], 'camminata': ['Walk_Loop'], 'corsa': ['Jog_Fwd_Loop', 'Sprint_Loop'],
    'spada_1': ['Sword_Regular_A', 'Sword_Attack'], 'spada_2': ['Sword_Regular_B'], 'spada_3': ['Sword_Regular_C'],
    'pugnali': ['Sword_Regular_B'], 'pugni': ['Punch_Jab'], 'pugni_2': ['Punch_Cross'], 'calcio': ['Melee_Hook'],
    'arco': ['Pistol_Shoot', 'OverhandThrow'], 'magia': ['Spell_Simple_Shoot'], 'bastone': ['Sword_Attack'],
    'colpito': ['Hit_Chest'], 'morte': ['Death01'], 'sella': ['Sitting_Idle_Loop', 'Driving_Loop'],
}
CENTRO = {'pelvis': 'hips', 'spine_01': 'spine', 'spine_02': 'spine_1', 'spine_03': 'chest', 'neck_01': 'neck', 'Head': 'head'}
LATO = {'clavicle': 'shoulder', 'upperarm': 'upper_arm', 'lowerarm': 'forearm', 'hand': 'hand', 'thigh': 'thigh',
        'calf': 'shin', 'foot': 'foot', 'ball': 'toe', 'ball_leaf': 'toe_end'}
CORPI = {'base_uomo': ('Superhero_Male_FullBody.gltf', ['Hair_SimpleParted', 'Hair_Buns', 'Hair_Long', 'Hair_Buzzed', 'Hair_Beard']),
         'base_donna': ('Superhero_Female_FullBody.gltf', ['Hair_SimpleParted', 'Hair_Buns', 'Hair_Long', 'Hair_BuzzedFemale'])}
CAPELLI = {'Hair_SimpleParted': 'capelli_corti', 'Hair_Buns': 'capelli_crocchia', 'Hair_Long': 'capelli_lunghi',
           'Hair_Buzzed': 'capelli_rasati', 'Hair_BuzzedFemale': 'capelli_rasati', 'Hair_Beard': 'barba'}


def nome_gioco(n):
    if n in CENTRO:
        return CENTRO[n]
    m = re.match(r'^(.+)_([lr])$', n)
    if not m:
        return n
    base, s = m.group(1), m.group(2).upper()
    if base in LATO:
        return f'{LATO[base]}_{s}'
    d = re.match(r'^(thumb|index|middle|ring|pinky)_0(\d)(_leaf)?$', base)
    if d:
        return f'hand_{s}_{d.group(1)}{d.group(2)}'
    return n


def rinomina(arm):
    for b in arm.data.bones:
        b.name = nome_gioco(b.name)


def importa(path):
    prima = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    nuovi = [o for o in bpy.data.objects if o not in prima]
    return next((o for o in nuovi if o.type == 'ARMATURE'), None), [o for o in nuovi if o.type == 'MESH'], nuovi


# ------------------------------------------------------------------ animazioni
def animazioni():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = 30
    princ = None
    for f in sorted(os.listdir(os.path.join(SRC, 'animazioni'))):
        if not f.lower().endswith('.glb'):
            continue
        arm, meshes, nuovi = importa(os.path.join(SRC, 'animazioni', f))
        for o in nuovi:
            if o is not arm and (princ is not None or o.type != 'ARMATURE'):
                bpy.data.objects.remove(o, do_unlink=True)
        if princ is None:
            princ = arm
        else:
            bpy.data.objects.remove(arm, do_unlink=True)
    presenti = {a.name: a for a in bpy.data.actions}
    scelte = []
    for nome, candidati in ANIMAZIONI.items():
        az = next((presenti[c] for c in candidati if c in presenti), None)
        if az is None:
            print('MANCA', nome, candidati)
            continue
        scelte.append((nome, az))
    # con l'azione assegnata Blender aggiorna i percorsi delle curve quando si rinominano le ossa: le si passa tutte
    ad = princ.animation_data or princ.animation_data_create()
    usate = {az for _, az in scelte}
    for az in usate:
        ad.action = az
        if hasattr(ad, 'action_slot') and len(az.slots):
            ad.action_slot = az.slots[0]
    vecchi = {b.name: nome_gioco(b.name) for b in princ.data.bones}
    rinomina(princ)
    for az in usate:           # sicurezza: i percorsi rimasti con i nomi vecchi
        curve = []
        if hasattr(az, 'layers'):
            for ly in az.layers:
                for st in ly.strips:
                    for cb in getattr(st, 'channelbags', []):
                        curve += list(cb.fcurves)
        else:
            curve = list(az.fcurves)
        for fc in curve:
            m = re.match(r'pose\.bones\["([^"]+)"\](.*)', fc.data_path)
            if m and m.group(1) in vecchi and vecchi[m.group(1)] != m.group(1):
                fc.data_path = f'pose.bones["{vecchi[m.group(1)]}"]{m.group(2)}'
    princ.name = 'scheletro'
    ad.action = None
    for tr in list(ad.nla_tracks):
        ad.nla_tracks.remove(tr)
    fine = 1
    fatte = []
    for nome, az in scelte:
        if az.name != nome and az in [a for n, a in scelte if n != nome and scelte.index((n, a)) < scelte.index((nome, az))]:
            az = az.copy()          # la stessa azione usata per due nomi
        tr = ad.nla_tracks.new()
        tr.name = nome
        st = tr.strips.new(nome, int(az.frame_range[0]), az)
        if hasattr(st, 'action_slot') and st.action_slot is None and len(az.slots):
            st.action_slot = az.slots[0]
        fine = max(fine, int(az.frame_range[1]))
        fatte.append(nome)
        print(f'animazione {nome:10s} ← {az.name:22s} fotogrammi {az.frame_range[0]:.0f}-{az.frame_range[1]:.0f}')
    scene.frame_end = fine
    M.esporta(os.path.join(OUT, ANIM_FILE), export_animations=True, export_animation_mode='NLA_TRACKS', export_force_sampling=True,
              export_optimize_animation_size=True, export_anim_slide_to_zero=True, export_materials='NONE')
    return fatte


# ------------------------------------------------------------------ corpi
def corpo(nome, file, capigliature):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    arm, meshes, nuovi = importa(os.path.join(SRC, 'corpi', file))
    if arm.animation_data:
        arm.animation_data_clear()
    pelle = max(meshes, key=lambda o: len(o.data.vertices))
    extra = []
    for o in meshes:
        if o is pelle:
            continue
        n = o.name.lower()
        if n.startswith('eye') and 'brow' not in n:
            o.name = o.data.name = 'occhi'
        elif 'brow' in n:
            o.name = o.data.name = 'sopracciglia'
        else:
            bpy.data.objects.remove(o, do_unlink=True)      # sfere d'aiuto e simili
    # capigliature: stesso spazio del corpo appena importato; si legano allo scheletro del corpo (osso della testa)
    for cap in capigliature:
        a2, m2, n2 = importa(os.path.join(SRC, 'capelli', cap + '.gltf'))
        for parte, o in enumerate(sorted(m2, key=lambda o: -len(o.data.vertices)), 1):
            mw = o.matrix_world.copy()
            for mod in list(o.modifiers):
                o.modifiers.remove(mod)
            o.parent = None
            o.matrix_world = mw
            o.vertex_groups.clear()
            g = o.vertex_groups.new(name='Head')
            g.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
            o.parent = arm
            o.matrix_parent_inverse = arm.matrix_world.inverted()
            mod = o.modifiers.new('scheletro', 'ARMATURE')
            mod.object = arm
            o.name = o.data.name = f'capo_{CAPELLI[cap]}__{parte}'
            extra.append(o)
        for o in n2:
            if o not in m2:
                bpy.data.objects.remove(o, do_unlink=True)
    rinomina(arm)
    arm.name = 'scheletro'
    arm.data.pose_position = 'REST'
    tutti = [o for o in bpy.data.objects if o.type == 'MESH']
    M.seleziona([arm] + tutti, arm)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    ob = pelle
    ob.name = 'personaggio'
    bpy.context.view_layer.update()
    zs = [(ob.matrix_world @ v.co).z for v in ob.data.vertices]
    lo, hi = min(zs), max(zs)
    k = M.H / (hi - lo)
    arm.matrix_world = Matrix.Translation((0, 0, -lo * k)) @ Matrix.Scale(k, 4) @ arm.matrix_world
    bpy.context.view_layer.update()
    M.seleziona([arm] + tutti, arm)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for img in bpy.data.images:
        if img.size[0] > M.TEX or img.size[1] > M.TEX:
            img.scale(min(M.TEX, img.size[0]), min(M.TEX, img.size[1]))
    capi = M.crea_capi(ob, arm) + M.crea_armature(ob, arm, M.H) + sorted({o.name[5:].split('__')[0] for o in extra})
    arm.data.pose_position = 'POSE'
    out = os.path.join(OUT, nome + '.glb')
    kw = dict(export_animations=False, export_materials='EXPORT')
    try:
        M.esporta(out, export_image_format='WEBP', **kw)
    except TypeError:
        M.esporta(out, **kw)
    print(f'corpo {nome}: {len(ob.data.vertices)} vertici, ossa {len(arm.data.bones)}, capi {capi}, {os.path.getsize(out) / 1e6:.1f} MB')
    return capi


fatte = animazioni()
idx_path = os.path.join(OUT, 'indice.json')
with open(idx_path, encoding='utf-8') as fh:
    idx = json.load(fh)
for nome, (file, capigliature) in CORPI.items():
    capi = corpo(nome, file, capigliature)
    d = idx['modelli'].setdefault(nome, {})
    d.update({'file': nome + '.glb', 'anim': ANIM_FILE, 'capi': capi, 'dipinto': True})
    d.pop('testa', None)
    d.pop('spalle', None)
with open(idx_path, 'w', encoding='utf-8') as fh:
    json.dump(idx, fh, indent=2, ensure_ascii=False)
    fh.write('\n')
print('FATTO — animazioni:', fatte, 'corpi:', list(CORPI))
