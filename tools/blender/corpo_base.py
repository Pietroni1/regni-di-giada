# Corpo base originale (uomo o donna) a partire dalla mesh e dalle forme di MakeHuman (tutte CC0), adattato allo
# scheletro delle animazioni del gioco (quello di Mixamo, preso da un FBX qualsiasi con lo scheletro in posa a T).
#
#   python3 tools/blender/corpo_base.py -- <makehuman/data> <scheletro.fbx> <parametri.json> <uscita.blend>
#   (oppure: blender -b --factory-startup --python tools/blender/corpo_base.py -- ...)
#
# Il file dei parametri (modelli/corpi/*.json) è il «disegno» del personaggio: sesso, muscoli, peso, altezza, proporzioni
# e un elenco di forme di dettaglio di MakeHuman con il loro peso (naso, occhi, mento, spalle, mani...).
# Cosa fa:
#   1. somma le forme alla mesh base (stessa matematica di MakeHuman: base + somma dei bersagli pesati);
#   2. calcola i giunti dallo scheletro predefinito di MakeHuman e li riporta sulle ossa di Mixamo;
#   3. porta braccia, mani, dita e gambe nella posa a T dello scheletro del gioco (le animazioni sono solo rotazioni:
#      la posa a riposo deve coincidere), con i pesi di MakeHuman riuniti sulle ossa di Mixamo;
#   4. salva un .blend con scheletro + corpo: `importa_mixamo.py` lo tratta come un personaggio «base_*».
import bpy, sys, os, json, math, re
import numpy as np
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
if len(argv) < 4:
    raise SystemExit('uso: corpo_base.py -- <makehuman/data> <scheletro.fbx> <parametri.json> <uscita.blend>')
DATI, SCHELETRO, PARAM, USCITA = argv[:4]
with open(PARAM, encoding='utf-8') as fh:
    P = json.load(fh)
SESSO = 'female' if P.get('sesso') == 'donna' else 'male'
TARGETS = os.path.join(DATI, 'targets')


# ------------------------------------------------------------------ mesh base e forme
def leggi_obj(path):
    v, vt, facce, gruppo = [], [], [], None
    for riga in open(path):
        if riga.startswith('v '):
            v.append([float(x) for x in riga.split()[1:4]])
        elif riga.startswith('vt '):
            vt.append([float(x) for x in riga.split()[1:3]])
        elif riga.startswith('g '):
            gruppo = riga.split()[1]
        elif riga.startswith('f '):
            idx = [p.split('/') for p in riga.split()[1:]]
            facce.append((gruppo, [int(p[0]) - 1 for p in idx], [int(p[1]) - 1 if len(p) > 1 and p[1] else 0 for p in idx]))
    return np.array(v), np.array(vt), facce


def somma_forma(V, nome, peso):
    if abs(peso) < 1e-4:
        return
    path = os.path.join(TARGETS, nome + '.target')
    if not os.path.exists(path):
        raise SystemExit('forma inesistente: ' + nome)
    for riga in open(path):
        if riga.startswith('#') or not riga.strip():
            continue
        a = riga.split()
        V[int(a[0])] += peso * np.array([float(a[1]), float(a[2]), float(a[3])])


def tre(v):
    """Valore 0..1 → pesi (min, medio, max) come i cursori di MakeHuman."""
    v = min(1.0, max(0.0, v))
    return (max(0.0, 1 - 2 * v), 1 - abs(2 * v - 1), max(0.0, 2 * v - 1))


V, VT, FACCE = leggi_obj(os.path.join(DATI, '3dobjs', 'base.obj'))
muscoli, peso = tre(P.get('muscoli', 0.5)), tre(P.get('peso', 0.5))
ETA = 'young'
for im, nm in enumerate(('minmuscle', 'averagemuscle', 'maxmuscle')):
    for ip, npeso in enumerate(('minweight', 'averageweight', 'maxweight')):
        w = muscoli[im] * peso[ip]
        somma_forma(V, f'macrodetails/universal-{SESSO}-{ETA}-{nm}-{npeso}', w)
        alt = P.get('altezza', 0.5) * 2 - 1
        if alt:
            somma_forma(V, f'macrodetails/height/{SESSO}-{ETA}-{nm}-{npeso}-{"max" if alt > 0 else "min"}height', w * abs(alt))
        prop = P.get('proporzioni', 0.5) * 2 - 1
        if prop:
            somma_forma(V, f'macrodetails/proportions/{SESSO}-{ETA}-{nm}-{npeso}-{"ideal" if prop > 0 else "uncommon"}proportions', w * abs(prop))
if SESSO == 'female':
    # seno: misura e tonicità (0..1, 0,5 = medio) come i cursori di MakeHuman
    coppa, tono = tre(P.get('seno', 0.5)), tre(P.get('tonicita', 0.5))
    for im, nm in enumerate(('minmuscle', 'averagemuscle', 'maxmuscle')):
        for ip, npeso in enumerate(('minweight', 'averageweight', 'maxweight')):
            for ic, nc in enumerate(('mincup', 'averagecup', 'maxcup')):
                for it, nt in enumerate(('minfirmness', 'averagefirmness', 'maxfirmness')):
                    w = muscoli[im] * peso[ip] * coppa[ic] * tono[it]
                    if (ic, it) != (1, 1) and w > 1e-4:
                        somma_forma(V, f'breast/female-{ETA}-{nm}-{npeso}-{nc}-{nt}', w)
for etnia, w in P.get('etnia', {'asian': 1.0}).items():
    somma_forma(V, f'macrodetails/{etnia}-{SESSO}-{ETA}', w)
for nome, w in P.get('forme', {}).items():
    if nome.startswith('#'):
        continue
    # «lr-…» vale per i due lati (l-… e r-…)
    for n in ([nome.replace('lr-', 'l-', 1), nome.replace('lr-', 'r-', 1)] if '/lr-' in nome else [nome]):
        somma_forma(V, n, w)

# MakeHuman: y in alto, guarda +z, decimetri → Blender: z in alto, guarda -y
V = np.stack([V[:, 0], -V[:, 2], V[:, 1]], axis=1) * 0.1

# ------------------------------------------------------------------ giunti e pesi di MakeHuman sulle ossa di Mixamo
with open(os.path.join(DATI, 'rigs', 'default.mhskel')) as fh:
    SK = json.load(fh)
with open(os.path.join(DATI, 'rigs', SK.get('weights_file', 'default_weights.mhw'))) as fh:
    PESI_MH = json.load(fh)['weights']


def giunto(osso, capo='head'):
    return V[SK['joints'][SK['bones'][osso][capo]]].mean(axis=0)


DITA = {'Thumb': 1, 'Index': 2, 'Middle': 3, 'Ring': 4, 'Pinky': 5}
GIUNTI = {  # osso di Mixamo → (osso di MakeHuman, capo)
    'Hips': ('spine05', 'head'), 'Spine': ('spine04', 'head'), 'Spine1': ('spine03', 'head'), 'Spine2': ('spine02', 'head'),
    'Neck': ('neck01', 'head'), 'Head': ('head', 'head'), 'HeadTop_End': ('head', 'tail'),
}
OSSO_DI = {'root': 'Hips', 'spine05': 'Hips', 'spine04': 'Spine', 'spine03': 'Spine1', 'spine02': 'Spine2', 'spine01': 'Spine2',
           'neck01': 'Neck', 'neck02': 'Neck', 'neck03': 'Neck'}
for lato, s in (('Left', 'L'), ('Right', 'R')):
    GIUNTI.update({
        f'{lato}Shoulder': (f'clavicle.{s}', 'head'), f'{lato}Arm': (f'upperarm01.{s}', 'head'),
        f'{lato}ForeArm': (f'lowerarm01.{s}', 'head'), f'{lato}Hand': (f'wrist.{s}', 'head'),
        f'{lato}UpLeg': (f'upperleg01.{s}', 'head'), f'{lato}Leg': (f'lowerleg01.{s}', 'head'),
        f'{lato}Foot': (f'foot.{s}', 'head'), f'{lato}ToeBase': (f'foot.{s}', 'tail'), f'{lato}Toe_End': (f'toe3-3.{s}', 'tail'),
    })
    OSSO_DI.update({f'pelvis.{s}': 'Hips', f'breast.{s}': 'Spine2', f'clavicle.{s}': f'{lato}Shoulder',
                    f'shoulder01.{s}': f'{lato}Shoulder', f'upperarm01.{s}': f'{lato}Arm', f'upperarm02.{s}': f'{lato}Arm',
                    f'lowerarm01.{s}': f'{lato}ForeArm', f'lowerarm02.{s}': f'{lato}ForeArm', f'wrist.{s}': f'{lato}Hand',
                    f'upperleg01.{s}': f'{lato}UpLeg', f'upperleg02.{s}': f'{lato}UpLeg', f'lowerleg01.{s}': f'{lato}Leg',
                    f'lowerleg02.{s}': f'{lato}Leg', f'foot.{s}': f'{lato}Foot'})
    for dito, n in DITA.items():
        for k in (1, 2, 3):
            GIUNTI[f'{lato}Hand{dito}{k}'] = (f'finger{n}-{k}.{s}', 'head')
            OSSO_DI[f'finger{n}-{k}.{s}'] = f'{lato}Hand{dito}{k}'
        GIUNTI[f'{lato}Hand{dito}4'] = (f'finger{n}-3.{s}', 'tail')
    for k in (1, 2, 3, 4):
        OSSO_DI[f'metacarpal{k}.{s}'] = f'{lato}Hand'


def osso_mixamo(osso_mh):
    if osso_mh in OSSO_DI:
        return OSSO_DI[osso_mh]
    m = re.match(r'^toe\d-\d\.(L|R)$', osso_mh)
    if m:
        return ('Left' if m.group(1) == 'L' else 'Right') + 'ToeBase'
    return 'Head'      # tutte le ossa del volto, occhi, lingua, mascella


POS = {b: giunto(*g) for b, g in GIUNTI.items()}
NOMI = sorted(GIUNTI)
IDX = {b: i for i, b in enumerate(NOMI)}
W = np.zeros((len(V), len(NOMI)))
for osso_mh, coppie in PESI_MH.items():
    j = IDX[osso_mixamo(osso_mh)]
    for i, w in coppie:
        W[i, j] += w
LABBRA = np.zeros(len(V))
for osso_mh, coppie in PESI_MH.items():
    if osso_mh.startswith('oris'):
        for i, w in coppie:
            LABBRA[i] += w
tot = W.sum(axis=1, keepdims=True)
W = np.where(tot > 1e-6, W / np.maximum(tot, 1e-6), 0)

# ------------------------------------------------------------------ scheletro del gioco
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=SCHELETRO, automatic_bone_orientation=False, ignore_leaf_bones=False, use_anim=False)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
vecchie = [o for o in bpy.data.objects if o.type == 'MESH']
bpy.context.view_layer.update()
MW = arm.matrix_world.copy()
PREF = next(b.name for b in arm.data.bones if b.name.endswith('Hips'))[:-4]      # «mixamorig:»
senza = lambda n: n[len(PREF):]
PADRE = {senza(b.name): (senza(b.parent.name) if b.parent else None) for b in arm.data.bones}
ORDINE = [senza(b.name) for b in arm.data.bones]                                  # i genitori vengono prima
RIPOSO = {senza(b.name): np.array(MW @ b.head_local) for b in arm.data.bones}     # posa a T di riferimento
# altezza del manichino di riferimento: il corpo nuovo prende la stessa
zs = [(o.matrix_world @ v.co).z for o in vecchie for v in o.data.vertices]
ALT_RIF = (max(zs) - min(zs)) if zs else 1.8
for o in vecchie:
    bpy.data.objects.remove(o, do_unlink=True)

mancanti = [b for b in ORDINE if b not in POS]
if mancanti:
    raise SystemExit('ossa dello scheletro senza giunto: ' + ', '.join(mancanti))

# ------------------------------------------------------------------ dalla posa di MakeHuman alla posa a T del gioco
# Busto, collo e testa restano come li ha modellati MakeHuman (portamento naturale): si allineano solo gli arti.
FIGLIO = {}
for lato in ('Left', 'Right'):
    FIGLIO.update({f'{lato}Arm': f'{lato}ForeArm', f'{lato}ForeArm': f'{lato}Hand',
                   f'{lato}Hand': f'{lato}HandMiddle1', f'{lato}UpLeg': f'{lato}Leg', f'{lato}Leg': f'{lato}Foot',
                   f'{lato}Foot': f'{lato}ToeBase', f'{lato}ToeBase': f'{lato}Toe_End'})
    for dito in DITA:
        for k in (1, 2, 3):
            FIGLIO[f'{lato}Hand{dito}{k}'] = f'{lato}Hand{dito}{k + 1}'


def unita(v):
    n = np.linalg.norm(v)
    return v / n if n > 1e-9 else v


def rot_fra(a, b):
    """Rotazione più breve che porta la direzione a sulla direzione b."""
    a, b = unita(a), unita(b)
    asse = np.cross(a, b)
    s, c = np.linalg.norm(asse), float(np.dot(a, b))
    if s < 1e-8:
        return np.eye(3)
    return rot_asse(asse / s, math.atan2(s, c))


def rot_asse(asse, ang):
    x, y, z = asse
    K = np.array([[0, -z, y], [z, 0, -x], [-y, x, 0]])
    return np.eye(3) + math.sin(ang) * K + (1 - math.cos(ang)) * (K @ K)


R = {None: np.eye(3)}       # rotazione accumulata di ogni osso
NUOVO = {}                  # posizione del giunto dopo la posa
ORIG = {None: np.zeros(3)}  # punto d'origine (posa MakeHuman) e punto d'arrivo di ogni osso
ARR = {None: np.zeros(3)}
for b in ORDINE:
    p = PADRE[b]
    testa = R[p] @ (POS[b] - ORIG[p]) + ARR[p]
    Rb = R[p]
    f = FIGLIO.get(b)
    if f and f in POS and f in RIPOSO:
        Rb = rot_fra(Rb @ (POS[f] - POS[b]), RIPOSO[f] - RIPOSO[b]) @ Rb
        if b.endswith('Hand'):
            # il palmo: la linea indice → mignolo deve stare come nel riferimento (gira attorno all'asse della mano)
            lato = b[:-4]
            asse = unita(RIPOSO[f] - RIPOSO[b])
            ora = Rb @ (POS[lato + 'HandPinky1'] - POS[lato + 'HandIndex1'])
            vuole = RIPOSO[lato + 'HandPinky1'] - RIPOSO[lato + 'HandIndex1']
            ora, vuole = unita(ora - asse * np.dot(ora, asse)), unita(vuole - asse * np.dot(vuole, asse))
            ang = math.atan2(float(np.dot(np.cross(ora, vuole), asse)), float(np.dot(ora, vuole)))
            Rb = rot_asse(asse, ang) @ Rb
    R[b], ORIG[b], ARR[b], NUOVO[b] = Rb, POS[b], testa, testa

Vn = np.zeros_like(V)
for b in ORDINE:
    w = W[:, IDX[b]:IDX[b] + 1]
    if w.max() > 0:
        Vn += w * ((V - ORIG[b]) @ R[b].T + ARR[b])
senza_peso = W.sum(axis=1) < 1e-6
Vn[senza_peso] = V[senza_peso]
V = Vn

# ------------------------------------------------------------------ solo il corpo (e gli occhi), altezza del riferimento
TENUTI = {'body': 0, 'helper-l-eye': 1, 'helper-r-eye': 1}
facce = [(TENUTI[g], vi, ti) for g, vi, ti in FACCE if g in TENUTI]
usati = sorted({i for _, vi, _ in facce for i in vi})
nuovo_i = {v: i for i, v in enumerate(usati)}
del_corpo = [i for mat_i, vi, _ in facce if mat_i == 0 for i in vi]
zmin, zmax = float(V[del_corpo, 2].min()), float(V[del_corpo, 2].max())
k = ALT_RIF / (zmax - zmin)
xc = float(np.mean([NUOVO['Hips'][0]]))
sposta = lambda p: (np.asarray(p) - np.array([xc, 0, zmin])) * k
V = (V - np.array([xc, 0, zmin])) * k
NUOVO = {b: sposta(p) for b, p in NUOVO.items()}

me = bpy.data.meshes.new('corpo')
me.from_pydata([tuple(V[i]) for i in usati], [], [[nuovo_i[i] for i in vi] for _, vi, _ in facce])
me.update()
uv = me.uv_layers.new(name='UVMap')
n = 0
for (mat_i, vi, ti), poly in zip(facce, me.polygons):
    poly.material_index = mat_i
    poly.use_smooth = True
    for t in ti:
        uv.data[n].uv = (VT[t][0], VT[t][1])
        n += 1
# seconda UV «Viso»: per la pelle (labbra, sopracciglia), per gli occhi le coordinate sul bulbo (iride disegnata dallo shader)
viso = me.uv_layers.new(name='Viso')
occhi = {}
for g in ('helper-l-eye', 'helper-r-eye'):
    ii = sorted({i for gg, vi, _ in FACCE if gg == g for i in vi})
    c = V[ii].mean(axis=0)
    occhi[g] = (c, float(np.linalg.norm(V[ii] - c, axis=1).mean()), set(ii))
alt_occhi = float(np.mean([o[0][2] for o in occhi.values()]))
r_occhio = float(np.mean([o[1] for o in occhi.values()]))


def uv_viso(i):
    p = V[i]
    for c, r, ii in occhi.values():
        if i in ii:
            return ((p[0] - c[0]) / r, (p[2] - c[2]) / r)
    labbra = float(LABBRA[i])
    sopra = 0.0
    for c, r, _ in occhi.values():
        # fascia arcuata sopra l'occhio, solo sul davanti del viso
        dx, dz = (p[0] - c[0]) / r, (p[2] - c[2]) / r
        fuori = dx * (1 if c[0] > 0 else -1)                # verso la tempia
        arco = 1.42 + 0.13 * fuori - 0.1 * dx * dx        # sopracciglio che sale verso l'esterno
        if p[1] < c[1] + r * 0.9 and p[0] * c[0] > 0 and abs(dx) < 1.9 and 0.8 < dz < 2.2:
            sopra = max(sopra, math.exp(-((dz - arco) / 0.2) ** 2) * (1.0 if abs(dx) < 1.3 else math.exp(-((abs(dx) - 1.3) / 0.25) ** 2)))
    return (labbra, sopra)


n = 0
for (mat_i, vi, ti), poly in zip(facce, me.polygons):
    for i in vi:
        q = uv_viso(i)
        viso.data[n].uv = (q[0], 1.0 - q[1])       # il glTF capovolge la v
        n += 1
# misure del cranio per i capelli del gioco: rispetto al giunto della testa, in metri (x a destra, y avanti = -y di Blender, z in alto)
cranio = [i for i in del_corpo if W[i, IDX['Head']] > 0.9 and V[i, 2] > alt_occhi + r_occhio * 1.2]
cr = V[cranio]
raggio = float(np.abs(cr[:, 0]).max())
cima = float(cr[:, 2].max())
testa_g = NUOVO['Head']
MISURE = {'raggio': raggio, 'su': cima - raggio - float(testa_g[2]), 'avanti': -float((cr[:, 1].min() + cr[:, 1].max()) / 2 - testa_g[1]),
          'profondo': float(cr[:, 1].max() - cr[:, 1].min()) / 2, 'alto': ALT_RIF}
for nome_mat, colore in (('pelle', (0.86, 0.66, 0.52, 1)), ('occhi', (0.95, 0.95, 0.95, 1))):
    m = bpy.data.materials.new(nome_mat)
    m.diffuse_color = colore
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    if bsdf:
        bsdf.inputs['Base Color'].default_value = colore
        bsdf.inputs['Roughness'].default_value = 0.75 if nome_mat == 'pelle' else 0.25
    me.materials.append(m)
ob = bpy.data.objects.new('corpo', me)
ob['testa'] = json.dumps(MISURE)
bpy.context.scene.collection.objects.link(ob)

# le ossa: stesse direzioni e stessi assi del riferimento, spostate sui giunti nuovi
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
MWi = MW.inverted()
for eb in arm.data.edit_bones:
    eb.use_connect = False
for eb in arm.data.edit_bones:
    dove = MWi @ Vector(NUOVO[senza(eb.name)])
    eb.translate(dove - eb.head)
bpy.ops.object.mode_set(mode='OBJECT')

# chioma: il cuoio capelluto del corpo, gonfiato verso l'esterno (segue il cranio; attaccatura alta davanti, bassa sulla nuca)
ymin, ymax = float(cr[:, 1].min()), float(cr[:, 1].max())
def nel_cuoio(i):
    p = V[i]
    if W[i, IDX['Head']] < 0.5:
        return False
    t = (p[1] - ymin) / (ymax - ymin)                       # 0 fronte → 1 nuca
    soglia = alt_occhi + r_occhio * (4.3 - 7.6 * min(1.0, max(0.0, t * 1.25)) ** 1.3)
    if abs(p[0]) > raggio * 0.8 and p[2] < alt_occhi + r_occhio * 1.1 and t < 0.75:
        return False                                        # tempie e orecchie restano libere
    return p[2] > soglia
cuoio = {i for i in del_corpo if nel_cuoio(i)}
f_cap = [vi for mat_i, vi, _ in facce if mat_i == 0 and sum(i in cuoio for i in vi) >= len(vi) - 1]
# solo il pezzo più grande: niente isolette di capelli sulla fronte
gruppo_di = {}
def radice(i):
    while gruppo_di.setdefault(i, i) != i:
        gruppo_di[i] = gruppo_di[gruppo_di[i]]
        i = gruppo_di[i]
    return i
for vi in f_cap:
    for i in vi[1:]:
        gruppo_di[radice(i)] = radice(vi[0])
conta = {}
for vi in f_cap:
    conta[radice(vi[0])] = conta.get(radice(vi[0]), 0) + 1
grande = max(conta, key=conta.get)
f_cap = [vi for vi in f_cap if radice(vi[0]) == grande]
v_cap = sorted({i for vi in f_cap for i in vi})
i_cap = {v: n for n, v in enumerate(v_cap)}
me.calc_loop_triangles()
norm = {i: np.array(me.vertices[nuovo_i[i]].normal) for i in v_cap}
centro_cr = np.array([0.0, (ymin + ymax) / 2, cima - raggio])
def gonfia(i):
    p = V[i]
    alto_ = max(0.0, (p[2] - alt_occhi) / (cima - alt_occhi))
    return p + norm[i] * (0.012 + 0.016 * alto_) * ALT_RIF / 1.8
mc = bpy.data.meshes.new('capo_capelli')
mc.from_pydata([tuple(gonfia(i)) for i in v_cap], [], [[i_cap[i] for i in vi] for vi in f_cap])
for poly in mc.polygons:
    poly.use_smooth = True
mc.update()
mcap = bpy.data.materials.new('capelli')
mcap.diffuse_color = (0.08, 0.06, 0.05, 1)
mc.materials.append(mcap)
oc = bpy.data.objects.new('capo_capelli', mc)
bpy.context.scene.collection.objects.link(oc)
gc = oc.vertex_groups.new(name=PREF + 'Head')
gc.add(list(range(len(v_cap))), 1.0, 'REPLACE')
sol = oc.modifiers.new('spessore', 'SOLIDIFY')
sol.thickness = 0.01
sol.offset = -1
mo = oc.modifiers.new('scheletro', 'ARMATURE')
mo.object = arm
oc.parent = arm
oc.matrix_parent_inverse = MW.inverted()

for b in ORDINE:
    g = ob.vertex_groups.new(name=PREF + b)
    col = W[:, IDX[b]]
    for i in usati:
        if col[i] > 1e-4:
            g.add([nuovo_i[i]], float(col[i]), 'REPLACE')
mod = ob.modifiers.new('scheletro', 'ARMATURE')
mod.object = arm
ob.parent = arm
ob.matrix_parent_inverse = MW.inverted()
me.validate()
os.makedirs(os.path.dirname(os.path.abspath(USCITA)), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(USCITA), compress=True)
print(f'corpo base {P.get("nome", "")}: {len(usati)} vertici, {len(facce)} facce, alto {ALT_RIF:.2f} m → {USCITA}')
