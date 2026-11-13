# Regni di Giada — armature per grado, costruite sul corpo base e legate al suo scheletro.
# Usato da importa_mixamo.py per i personaggi "base_*". Ogni grado produce fino a tre oggetti:
#   capo_<grado>__piastre  (lamelle: corazza, spallacci a pannello, scarselle, bracciali, schinieri)
#   capo_<grado>__bordo    (finiture: calotte delle spalle, collare, medaglione, aureola)
#   capo_<grado>__stoffa   (fascia in vita: il gioco la tinge con il colore del regno)
# Lo stile è quello delle armature lamellari orientali: file di piastre sovrapposte come tegole.
# Convenzioni: Z in alto, personaggio rivolto verso -Y, sinistra = +X, trasformazioni già applicate.
import bpy, bmesh, math
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

SU, AVANTI = Vector((0, 0, 1)), Vector((0, -1, 0))

# Disegno dei gradi. Misure in metri per un corpo alto 1,8 (vengono riscalate).
GRADI = {
    'tunica': dict(
        colori=dict(piastre=(1, 1, 1), stoffa=(1, 1, 1)),           # stoffa: tinta dal gioco
        scarselle=dict(pannelli=4, largo=82, file=1, lungo=0.30, dente=0.0, apri=0.05),
        fascia=dict(alto=0.10, spesso=0.022)),
    'lamellare': dict(
        colori=dict(piastre=(0.22, 0.045, 0.03), bordo=(0.45, 0.27, 0.09), stoffa=(1, 1, 1)),
        corazza=dict(fila=0.055, dente=0.017, base=0.022),
        spallacci=dict(file=4, lungo=0.55, stacco=0.030, dente=0.014, orlo=0.0, calotta=0.78),
        scarselle=dict(pannelli=6, largo=50, file=4, lungo=0.34, dente=0.012, apri=0.04),
        bracciali=dict(fila=0.055, dente=0.008, base=0.014),
        fascia=dict(alto=0.085, spesso=0.030)),
    'giada': dict(
        colori=dict(piastre=(0.05, 0.27, 0.16), bordo=(0.72, 0.42, 0.07), stoffa=(1, 1, 1)),
        corazza=dict(fila=0.062, dente=0.017, base=0.030),
        spallacci=dict(file=5, lungo=0.70, stacco=0.045, dente=0.016, orlo=0.015, calotta=1.0, ala=0.55),
        scarselle=dict(pannelli=6, largo=54, file=5, lungo=0.44, dente=0.015, apri=0.07),
        bracciali=dict(fila=0.06, dente=0.011, base=0.018), schinieri=True,
        collare=dict(alto=0.055, apri=0.03), medaglione=0.075,
        fascia=dict(alto=0.09, spesso=0.036)),
    'nubi': dict(
        colori=dict(piastre=(0.27, 0.31, 0.40), bordo=(0.80, 0.50, 0.08), stoffa=(1, 1, 1)),
        corazza=dict(fila=0.072, dente=0.021, base=0.036),
        spallacci=dict(file=6, lungo=0.82, stacco=0.060, dente=0.019, orlo=0.05, calotta=1.3, ala=1.0),
        scarselle=dict(pannelli=6, largo=56, file=6, lungo=0.54, dente=0.018, apri=0.11),
        bracciali=dict(fila=0.06, dente=0.013, base=0.022), schinieri=True,
        collare=dict(alto=0.095, apri=0.06), medaglione=0.095, aureola=0.37,
        fascia=dict(alto=0.095, spesso=0.042)),
}
# Elmi: i nomi sono gli id degli oggetti del gioco. calotta = distacco dalla testa, gronda = paranuca a lamelle.
ELMI = {
    'cappello_paglia': dict(stoffa=True, colori=dict(piastre=(0.50, 0.36, 0.13)), cono=dict(r=0.36, h=0.15)),
    'elmo_bronzo': dict(colori=dict(piastre=(0.26, 0.15, 0.06), bordo=(0.55, 0.36, 0.12)), calotta=0.022,
                        gronda=dict(file=3, passo=0.038, dente=0.012, apri=0.05, apertura=150), visiera=0.045),
    'elmo_cornuto': dict(colori=dict(piastre=(0.05, 0.20, 0.13), bordo=(0.72, 0.42, 0.07)), calotta=0.026,
                         gronda=dict(file=4, passo=0.040, dente=0.014, apri=0.085, apertura=140), visiera=0.055,
                         corna=dict(largo=0.17, alto=0.30, spesso=0.045)),
    'elmo_drago': dict(colori=dict(piastre=(0.23, 0.03, 0.03), bordo=(0.85, 0.52, 0.08)), calotta=0.030,
                       gronda=dict(file=5, passo=0.042, dente=0.016, apri=0.13, apertura=130), visiera=0.065,
                       corna=dict(largo=0.24, alto=0.40, spesso=0.055), cresta=dict(alto=0.34, largo=0.07)),
}
# Calzari: gambale = quanto sale sullo stinco (0-1), base = spessore, dente/fila = lamelle, anello = fascia in cima, ali = alette.
CALZARI = {
    'sandali': dict(stoffa=True, colori=dict(piastre=(0.42, 0.30, 0.12), bordo=(0.10, 0.06, 0.035)), suola=0.016),
    'stivali_cuoio': dict(stoffa=True, colori=dict(piastre=(0.10, 0.052, 0.025)), gambale=0.55, base=0.018, risvolto=0.012),
    'stivali_vento': dict(colori=dict(piastre=(0.035, 0.14, 0.12), bordo=(0.72, 0.42, 0.07)), gambale=0.68, base=0.020,
                          dente=0.008, fila=0.07, anello=0.035, ali=0.5),
    'stivali_nube': dict(colori=dict(piastre=(0.27, 0.31, 0.40), bordo=(0.80, 0.50, 0.08)), gambale=0.80, base=0.024,
                         dente=0.013, fila=0.065, anello=0.045, ali=0.8),
}
TORSO = ('spine', 'spine_1', 'chest', 'shoulder_L', 'shoulder_R')


def _seleziona(objs, attivo):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = attivo


def _griglia(bm, righe, chiusa=False):
    """Crea una superficie da una griglia di punti (righe di uguale lunghezza)."""
    vs = [[bm.verts.new(p) for p in r] for r in righe]
    n = len(righe[0])
    for a, b in zip(vs, vs[1:]):
        for i in range(n if chiusa else n - 1):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    return vs


def _lama(bm, centri, larghezze, verso):
    """Lamina affusolata (corna, ali, creste): una fila di punti centrali, allargata lungo `verso`."""
    return _griglia(bm, [[c - verso * w, c, c + verso * w] for c, w in zip(centri, larghezze)])


def _unisci(nome_capo, pezzi, colori, arm, stoffa=False):
    """Un oggetto per parte (capo_<nome>__<parte>), con il suo materiale."""
    for parte, lista in pezzi.items():
        if not lista:
            continue
        nome = f'capo_{nome_capo}__{parte}'
        dest = bpy.data.objects.new(nome, bpy.data.meshes.new(nome))
        bpy.context.scene.collection.objects.link(dest)
        _seleziona(lista + [dest], dest)
        bpy.ops.object.join()
        dest.parent = arm
        dest.modifiers.new('Armature', 'ARMATURE').object = arm
        mat = bpy.data.materials.new(nome)
        mat.use_nodes = True
        bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
        col = colori.get(parte, (1, 1, 1))
        opaco = parte == 'stoffa' or stoffa
        bsdf.inputs['Base Color'].default_value = (*col, 1)
        bsdf.inputs['Roughness'].default_value = 0.9 if opaco else (0.32 if parte == 'bordo' else 0.45)
        bsdf.inputs['Metallic'].default_value = 0.0 if opaco else 0.3
        dest.data.materials.clear()
        dest.data.materials.append(mat)
        for pol in dest.data.polygons:
            pol.material_index = 0
            pol.use_smooth = True


def _oggetto(nome, bm, pesi, fuori):
    """Mesh con normali verso l'esterno e pesi dati da pesi(co) -> {osso: peso}."""
    bm.normal_update()
    if sum(f.normal.dot(fuori(f.calc_center_median())) for f in bm.faces) < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    for v in me.vertices:
        for osso, w in pesi(v.co).items():
            if w > 0.001:
                (ob.vertex_groups.get(osso) or ob.vertex_groups.new(name=osso)).add([v.index], w, 'REPLACE')
    return ob


def _guscio(corpo, osso, scelta, sposta, riduci=0.5):
    """Copia le facce del corpo scelte (per osso dominante e posizione) e le gonfia: resta pesato come il corpo."""
    capo = corpo.copy()
    capo.data = corpo.data.copy()
    bpy.context.scene.collection.objects.link(capo)
    bm = bmesh.new()
    bm.from_mesh(capo.data)
    dentro = [scelta(osso[v.index], v.co) for v in bm.verts]
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if not all(dentro[v.index] for v in f.verts)], context='FACES')
    if len(bm.faces) < 20:
        bm.free()
        bpy.data.objects.remove(capo, do_unlink=True)
        return None
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * sposta(v.co)
    bm.to_mesh(capo.data)
    bm.free()
    if riduci < 1:
        mod = capo.modifiers.new('riduci', 'DECIMATE')
        mod.ratio = riduci
        _seleziona([capo], capo)
        bpy.ops.object.modifier_move_to_index(modifier='riduci', index=0)
        bpy.ops.object.modifier_apply(modifier='riduci')
    return capo


def crea_armature(corpo, arm, H):
    u = H / 1.8
    B = arm.data.bones
    me = corpo.data
    gruppi = {g.index: g.name for g in corpo.vertex_groups}
    osso = []
    for v in me.vertices:
        g = max(v.groups, key=lambda x: x.weight, default=None)
        osso.append(gruppi.get(g.group, '') if g else '')
    bm0 = bmesh.new()
    bm0.from_mesh(me)
    bvh = BVHTree.FromBMesh(bm0)
    asse = Vector((0, B['hips'].head_local.y, 0))

    def raggio(z, ang, minimo, massimo):
        d = Vector((math.cos(ang), math.sin(ang), 0))
        hit = bvh.ray_cast(Vector((asse.x, asse.y, z)) + d * 3, -d)[0]
        r = (Vector((hit.x - asse.x, hit.y - asse.y, 0)).length if hit else minimo)
        return max(minimo, min(massimo, r))

    def attorno(z, ang, r):
        return Vector((asse.x + math.cos(ang) * r, asse.y + math.sin(ang) * r, z))

    z_vita = B['hips'].head_local.z + 0.10 * u
    z_petto_su = B['neck'].head_local.z
    fatti = []

    for grado, D in GRADI.items():
        pezzi = {'piastre': [], 'bordo': [], 'stoffa': []}

        # ---------------------------------------------------------------- corazza: guscio del busto a file di lamelle
        if 'corazza' in D:
            c = D['corazza']
            g = _guscio(corpo, osso, lambda b, co: b in TORSO,
                        lambda co: (c['base'] + c['dente'] * (((z_petto_su - co.z) / (c['fila'] * u)) % 1.0)) * u)
            if g:
                pezzi['piastre'].append(g)
        if 'bracciali' in D:
            c = D['bracciali']
            for s in 'LR':
                fa = B['forearm_' + s]
                d = (fa.tail_local - fa.head_local).normalized()
                g = _guscio(corpo, osso, lambda b, co, s=s: b == 'forearm_' + s,
                            lambda co, fa=fa, d=d: (c['base'] + c['dente'] * ((((co - fa.head_local).dot(d)) / (c['fila'] * u)) % 1.0)) * u)
                if g:
                    pezzi['piastre'].append(g)
        if D.get('schinieri'):
            for s in 'LR':
                sh = B['shin_' + s]
                g = _guscio(corpo, osso, lambda b, co, s=s, sh=sh: b == 'shin_' + s and co.z > sh.tail_local.z + 0.05 * u,
                            lambda co, sh=sh: (0.018 + 0.012 * (((sh.head_local.z - co.z) / (0.07 * u)) % 1.0)) * u)
                if g:
                    pezzi['piastre'].append(g)

        # ---------------------------------------------------------------- spallacci: pannelli di lamelle sopra il braccio
        if 'spallacci' in D:
            c = D['spallacci']
            for s, sgn in (('L', 1), ('R', -1)):
                ua = B['upper_arm_' + s]
                p0 = ua.head_local.copy()
                d = (ua.tail_local - ua.head_local).normalized()
                lato = d.cross(SU).normalized()          # avanti/dietro rispetto al braccio
                su = lato.cross(d).normalized()
                if su.z < 0:
                    su = -su
                hit = bvh.ray_cast(p0 + d * ua.length * 0.45 + su * 2, -su)[0]
                rad = max(0.045 * u, min(0.11 * u, (hit - (p0 + d * ua.length * 0.45)).dot(su) if hit else 0.07 * u))
                a0 = -0.16 * ua.length
                passo = (c['lungo'] * ua.length - a0) / c['file']
                cols = 11
                bm = bmesh.new()
                righe = []
                for j in range(c['file']):
                    fine = j == c['file'] - 1
                    for a, extra in ((a0 + j * passo, 0.0), (a0 + (j + 1) * passo, c['dente'] * u + (c['orlo'] * u if fine else 0))):
                        r = rad + (c['stacco'] + 0.006 * j) * u + extra
                        riga = []
                        for i in range(cols):
                            phi = math.radians(-88 + 176 * i / (cols - 1))
                            alza = c['orlo'] * u * 1.2 if (fine and extra) else 0.0     # orlo rialzato verso l'esterno
                            riga.append(p0 + d * a + (su * math.cos(phi) + lato * math.sin(phi)) * r + su * alza)
                        righe.append(riga)
                _griglia(bm, righe)
                pesi = lambda co, s=s, p0=p0, d=d, ua=ua: (lambda t: {'upper_arm_' + s: 0.55 + 0.35 * t, 'shoulder_' + s: 0.45 - 0.35 * t})(
                    max(0.0, min(1.0, (co - p0).dot(d) / (ua.length * 0.5))))
                pezzi['piastre'].append(_oggetto('sp', bm, pesi, lambda p, p0=p0, d=d: p - (p0 + d * (p - p0).dot(d))))
                if 'bordo' in D['colori']:      # orlo in metallo chiaro lungo il fondo del pannello
                    bm = bmesh.new()
                    ult = righe[-1]
                    _griglia(bm, [[q + (q - (p0 + d * (q - p0).dot(d))).normalized() * 0.004 * u for q in ult],
                                  [q + d * 0.026 * u + (q - (p0 + d * (q - p0).dot(d))).normalized() * 0.010 * u for q in ult]])
                    pezzi['bordo'].append(_oggetto('spb', bm, pesi, lambda p, p0=p0, d=d: p - (p0 + d * (p - p0).dot(d))))
                if c.get('ala'):                # cresta ad ala che sale dalla spalla verso l'esterno
                    k = c['ala']
                    bm = bmesh.new()
                    base_ala = p0 + su * (rad + 0.07 * u)
                    n = 9
                    centri = [base_ala + d * (0.02 + 0.20 * k * t) * u + su * (0.26 * k * t ** 0.75) * u for t in (i / (n - 1) for i in range(n))]
                    larghezze = [(0.075 * k * (1 - t) ** 0.8 + 0.004) * u for t in (i / (n - 1) for i in range(n))]
                    _lama(bm, centri, larghezze, lato)
                    pezzi['bordo'].append(_oggetto('ala', bm, lambda co, s=s: {'shoulder_' + s: 0.6, 'upper_arm_' + s: 0.4}, lambda p: AVANTI))
                if c.get('calotta'):
                    k = c['calotta']
                    bm = bmesh.new()
                    M = Matrix.Translation(p0 + d * 0.02 * u + su * rad * 0.55) @ Matrix((
                        (d.x, lato.x, su.x, 0), (d.y, lato.y, su.y, 0), (d.z, lato.z, su.z, 0), (0, 0, 0, 1))) @ Matrix.Diagonal((0.125 * u * k, 0.115 * u * k, 0.085 * u * k, 1))
                    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=1.0, matrix=M)
                    centro = M.translation
                    bmesh.ops.delete(bm, geom=[v for v in bm.verts if (v.co - centro).dot(su) < -0.004 * u], context='VERTS')
                    pezzi['bordo'].append(_oggetto('cal', bm, lambda co, s=s: {'shoulder_' + s: 0.6, 'upper_arm_' + s: 0.4}, lambda p, centro=centro: p - centro))

        # ---------------------------------------------------------------- scarselle: pannelli appesi alla fascia
        if 'scarselle' in D:
            c = D['scarselle']
            n = c['pannelli']
            centri = [-90 + (360 / n) * (k + 0.5) for k in range(n)]      # nessun pannello al centro davanti
            cols = 7
            for cen in centri:
                bm = bmesh.new()
                righe = []
                angoli = [math.radians(cen - c['largo'] / 2 + c['largo'] * i / (cols - 1)) for i in range(cols)]
                base = [max(raggio(z_vita - k * 0.09 * u, a, 0.10 * u, 0.30 * u) for k in range(3)) + 0.030 * u for a in angoli]
                passo = c['lungo'] * u / c['file']
                for j in range(c['file']):
                    for z, extra in ((z_vita - j * passo, 0.0), (z_vita - (j + 1) * passo, c['dente'] * u)):
                        t = (z_vita - z) / (c['lungo'] * u)
                        righe.append([attorno(z, a, b + c['apri'] * u * t + 0.004 * u * j + extra) for a, b in zip(angoli, base)])
                _griglia(bm, righe)
                lato = 'L' if math.cos(math.radians(cen)) > 0 else 'R'
                pesi = lambda co, lato=lato: (lambda t: {'thigh_' + lato: 0.72 * t, 'hips': 1 - 0.72 * t})(
                    max(0.0, min(1.0, (z_vita - co.z) / (c['lungo'] * u) * 1.15)))
                pezzi['piastre'].append(_oggetto('sc', bm, pesi, lambda p: Vector((p.x - asse.x, p.y - asse.y, 0))))
                if 'bordo' in D['colori']:
                    bm = bmesh.new()
                    zf = z_vita - c['lungo'] * u
                    rf = [b + c['apri'] * u + 0.004 * u * (c['file'] - 1) + c['dente'] * u for b in base]
                    _griglia(bm, [[attorno(zf + 0.004 * u, a, r + 0.004 * u) for a, r in zip(angoli, rf)],
                                  [attorno(zf - 0.024 * u, a, r + 0.012 * u) for a, r in zip(angoli, rf)]])
                    pezzi['bordo'].append(_oggetto('scb', bm, lambda co, lato=lato: {'thigh_' + lato: 0.72, 'hips': 0.28}, lambda p: Vector((p.x - asse.x, p.y - asse.y, 0))))

        # ---------------------------------------------------------------- fascia in vita
        if 'fascia' in D:
            c = D['fascia']
            seg = 40
            ang = [2 * math.pi * i / seg for i in range(seg)]
            rr = [max(raggio(z_vita + k * 0.03 * u, a, 0.09 * u, 0.30 * u) for k in (-1, 0, 1)) for a in ang]
            h, t = c['alto'] * u, c['spesso'] * u
            profilo = [(-h / 2, 0.006 * u), (-h / 2, t), (-h * 0.15, t * 1.25), (h * 0.15, t * 1.25), (h / 2, t), (h / 2, 0.006 * u)]
            bm = bmesh.new()
            _griglia(bm, [[attorno(z_vita + dz, a, r + dr) for a, r in zip(ang, rr)] for dz, dr in profilo], chiusa=True)
            pezzi['stoffa'].append(_oggetto('fa', bm, lambda co: {'hips': 0.6, 'spine': 0.4}, lambda p: Vector((p.x - asse.x, p.y - asse.y, 0))))

        # ---------------------------------------------------------------- collare
        if 'collare' in D:
            c = D['collare']
            zc = B['neck'].head_local.z - 0.015 * u
            cy = B['neck'].head_local.y
            seg = 28
            bm = bmesh.new()
            righe = [[], [], []]
            for i in range(seg):
                a = 2 * math.pi * i / seg
                dietro = 0.5 + 0.5 * math.sin(a)                     # più alto dietro, basso sotto il mento
                r = 0.085 * u
                alto = c['alto'] * u * (0.45 + 0.55 * dietro)
                for k, (dz, dr) in enumerate(((0, 0), (alto, c['apri'] * u), (alto, c['apri'] * u - 0.012 * u))):
                    righe[k].append(Vector((math.cos(a) * (r + dr), cy + math.sin(a) * (r + dr) * 1.1, zc + dz)))
            _griglia(bm, righe, chiusa=True)
            pezzi['bordo'].append(_oggetto('co', bm, lambda co: {'chest': 0.7, 'neck': 0.3}, lambda p: Vector((p.x, p.y - cy, 0))))

        # ---------------------------------------------------------------- medaglione sul petto
        if 'medaglione' in D:
            r = D['medaglione'] * u
            zc = B['chest'].head_local.z + B['chest'].length * 0.45
            hit = bvh.ray_cast(Vector((0, -3, zc)), Vector((0, 1, 0)))[0]
            if hit:
                y0 = hit.y - D['corazza']['base'] * u - D['corazza']['dente'] * u
                bm = bmesh.new()
                seg = 20
                anelli = [(r, 0.0), (r, -0.012 * u), (r * 0.72, -0.020 * u), (r * 0.55, -0.012 * u), (r * 0.3, -0.026 * u)]
                righe = [[Vector((math.cos(2 * math.pi * i / seg) * rr, y0 + dy, zc + math.sin(2 * math.pi * i / seg) * rr)) for i in range(seg)] for rr, dy in anelli]
                vs = _griglia(bm, righe, chiusa=True)
                cv = bm.verts.new(Vector((0, y0 - 0.032 * u, zc)))
                for i in range(seg):
                    bm.faces.new((vs[-1][i], vs[-1][(i + 1) % seg], cv))
                pezzi['bordo'].append(_oggetto('me', bm, lambda co: {'chest': 1.0}, lambda p: Vector((0, -1, 0))))

        # ---------------------------------------------------------------- aureola dietro le spalle (grado più alto)
        if 'aureola' in D:
            R = D['aureola'] * u
            zc = B['neck'].head_local.z + 0.03 * u
            hit = bvh.ray_cast(Vector((0, 3, B['chest'].head_local.z + B['chest'].length * 0.5)), Vector((0, -1, 0)))[0]
            yc = (hit.y if hit else 0.1 * u) + 0.13 * u
            for RR, rr in ((R, 0.022 * u), (R * 0.80, 0.009 * u)):
                bm = bmesh.new()
                M, m = 48, 8
                righe = []
                for i in range(M):
                    a = 2 * math.pi * i / M
                    c0 = Vector((math.cos(a) * RR, yc, zc + math.sin(a) * RR))
                    rad = Vector((math.cos(a), 0, math.sin(a)))
                    righe.append([c0 + (rad * math.cos(2 * math.pi * k / m) + Vector((0, 1, 0)) * math.sin(2 * math.pi * k / m)) * rr for k in range(m)])
                righe.append(righe[0])
                _griglia(bm, righe, chiusa=True)
                pezzi['bordo'].append(_oggetto('au', bm, lambda co: {'chest': 1.0}, lambda p, RR=RR: p - (Vector((p.x, 0, p.z - zc)).normalized() * RR + Vector((0, yc, zc)))))

        _unisci(grado, pezzi, D['colori'], arm, stoffa=(grado == 'tunica'))
        fatti.append(grado)
    # ================================================================ elmi (tutti pesati sulla testa)
    testa = B['head']
    z_collo = testa.head_local.z
    z_cima = max(v.co.z for v in me.vertices)
    alt = z_cima - z_collo
    asse_t = Vector((0, testa.head_local.y, 0))

    def raggio_t(z, ang):
        dd = Vector((math.cos(ang), math.sin(ang), 0))
        hit = bvh.ray_cast(Vector((asse_t.x, asse_t.y, z)) + dd * 1.0, -dd)[0]
        return max(0.05 * u, min(0.16 * u, Vector((hit.x - asse_t.x, hit.y - asse_t.y, 0)).length if hit else 0.09 * u))

    zc = z_collo + alt * 0.52                                   # centro della calotta, all'altezza della fronte
    rx = max(raggio_t(zc, 0), raggio_t(zc, math.pi))
    ry_d, ry_f = raggio_t(zc, math.pi / 2), raggio_t(zc, -math.pi / 2)
    cy = asse_t.y + (ry_d - ry_f) / 2
    ry = (ry_d + ry_f) / 2
    rz = z_cima - zc
    PT = lambda co: {'head': 1.0}
    fuori_t = lambda p: p - Vector((0, cy, zc))

    def punto_t(ang, elev, gonfia):
        """Punto sull'ellissoide della testa, gonfiato di `gonfia` metri."""
        ce = math.cos(elev)
        return Vector((math.cos(ang) * ce * (rx + gonfia), cy + math.sin(ang) * ce * (ry + gonfia), zc + math.sin(elev) * (rz + gonfia)))

    for nome, E in ELMI.items():
        pezzi = {'piastre': [], 'bordo': [], 'stoffa': []}
        seg = 28
        if 'cono' in E:                                         # cappello largo di paglia
            c = E['cono']
            bm = bmesh.new()
            zt = z_cima + 0.05 * u
            righe = [[Vector((math.cos(2 * math.pi * i / seg) * r * u, cy + math.sin(2 * math.pi * i / seg) * r * u, zt - h * u)) for i in range(seg)]
                     for r, h in ((0.012, 0.0), (c['r'] * 0.35, c['h'] * 0.42), (c['r'] * 0.7, c['h'] * 0.78), (c['r'], c['h']), (c['r'] * 0.985, c['h'] + 0.012))]
            _griglia(bm, righe, chiusa=True)
            pezzi['piastre'].append(_oggetto('cono', bm, PT, lambda p: Vector((p.x, p.y - cy, 0.6))))
        if 'calotta' in E:
            g = E['calotta'] * u
            bm = bmesh.new()
            livelli = [math.radians(e) for e in (-14, 0, 18, 38, 58, 76)]
            righe = [[punto_t(2 * math.pi * i / seg, e, g) for i in range(seg)] for e in livelli]
            vs = _griglia(bm, righe, chiusa=True)
            cima = bm.verts.new(Vector((0, cy, zc + rz + g)))
            for i in range(seg):
                bm.faces.new((vs[-1][i], vs[-1][(i + 1) % seg], cima))
            pezzi['piastre'].append(_oggetto('cal', bm, PT, fuori_t))
            bm = bmesh.new()                                    # fascia attorno alla base della calotta
            _griglia(bm, [[punto_t(2 * math.pi * i / seg, math.radians(e), g + dr * u) for i in range(seg)] for e, dr in ((-16, 0.004), (-16, 0.016), (-4, 0.016), (-4, 0.004))], chiusa=True)
            pezzi['bordo'].append(_oggetto('fas', bm, PT, fuori_t))
            bm = bmesh.new()                                    # pomello in cima
            bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=0.022 * u, matrix=Matrix.Translation((0, cy, zc + rz + g + 0.012 * u)))
            pezzi['bordo'].append(_oggetto('pom', bm, PT, lambda p: p - Vector((0, cy, zc + rz + g))))
        if 'gronda' in E:                                       # paranuca a file di lamelle, aperto sul viso
            c = E['gronda']
            g = E['calotta'] * u
            cols = 21
            angoli = [math.radians(-90 + c['apertura'] / 2 + (360 - c['apertura']) * i / (cols - 1)) for i in range(cols)]
            bm = bmesh.new()
            righe = []
            z0 = zc + math.sin(math.radians(-14)) * (rz + g)
            for j in range(c['file']):
                for dz, extra in ((j * c['passo'], 0.0), ((j + 1) * c['passo'], c['dente'])):
                    t = dz / (c['file'] * c['passo'])
                    righe.append([Vector((math.cos(a) * (rx + g + (c['apri'] * t + 0.004 * j + extra) * u), cy + math.sin(a) * (ry + g + (c['apri'] * t + 0.004 * j + extra) * u), z0 - dz * u)) for a in angoli])
            _griglia(bm, righe)
            pezzi['piastre'].append(_oggetto('gro', bm, PT, lambda p: Vector((p.x, p.y - cy, 0))))
        if 'visiera' in E:
            g = E['calotta'] * u
            cols = 11
            angoli = [math.radians(-90 - 55 + 110 * i / (cols - 1)) for i in range(cols)]
            bm = bmesh.new()
            z0 = zc + math.sin(math.radians(-10)) * (rz + g)
            _griglia(bm, [[Vector((math.cos(a) * (rx + g + dr * u), cy + math.sin(a) * (ry + g + dr * u), z0 + dz * u)) for a in angoli] for dr, dz in ((0.0, 0.0), (E['visiera'], -0.018))])
            pezzi['bordo'].append(_oggetto('vis', bm, PT, lambda p: Vector((0, -0.3, 1))))
        if 'corna' in E:                                        # corna piatte che salgono dalla fronte
            c = E['corna']
            g = E['calotta'] * u
            fronte = Vector((0, cy - (ry + g) - 0.006 * u, zc + 0.02 * u))
            n = 10
            for sgn in (1, -1):
                bm = bmesh.new()
                ts = [i / (n - 1) for i in range(n)]
                centri = [fronte + Vector((sgn * (0.035 + c['largo'] * t ** 1.3), 0.03 * t, c['alto'] * t ** 0.8)) * u for t in ts]
                larghezze = [(c['spesso'] * (1 - t) ** 0.7 + 0.004) * u for t in ts]
                _lama(bm, centri, larghezze, Vector((sgn * 0.75, 0, -0.66)).normalized())
                pezzi['bordo'].append(_oggetto('cor', bm, PT, lambda p: AVANTI))
        if 'cresta' in E:                                       # fiamma centrale sopra la fronte
            c = E['cresta']
            g = E['calotta'] * u
            fronte = Vector((0, cy - (ry + g) - 0.010 * u, zc + 0.05 * u))
            n = 9
            ts = [i / (n - 1) for i in range(n)]
            bm = bmesh.new()
            centri = [fronte + Vector((0, 0.05 * t, c['alto'] * t)) * u for t in ts]
            larghezze = [(c['largo'] * math.sin(math.pi * (0.12 + 0.88 * t)) ** 0.8 * (1 - 0.55 * t) + 0.004) * u for t in ts]
            _lama(bm, centri, larghezze, Vector((1, 0, 0)))
            pezzi['bordo'].append(_oggetto('cre', bm, PT, lambda p: AVANTI))
        _unisci(nome, pezzi, E['colori'], arm, stoffa=E.get('stoffa', False))
        fatti.append(nome)

    # ================================================================ calzari
    for nome, K in CALZARI.items():
        pezzi = {'piastre': [], 'bordo': [], 'stoffa': []}
        for s, sgn in (('L', 1), ('R', -1)):
            piede, stinco = B['foot_' + s], B['shin_' + s]
            z_cav = piede.head_local.z
            z_gin = stinco.head_local.z
            z_su = z_cav + (z_gin - z_cav) * K.get('gambale', 0.0)
            dp = (piede.tail_local - piede.head_local)
            dp = Vector((dp.x, dp.y, 0)).normalized()
            if 'suola' in K:                                    # sandali: suola e due lacci
                g = _guscio(corpo, osso, lambda b, co, s=s: (b in ('foot_' + s, 'toe_' + s, 'toe_end_' + s)) and co.z < z_cav * 0.42, lambda co: K['suola'] * u, riduci=1)
                if g:
                    pezzi['piastre'].append(g)
                g = _guscio(corpo, osso, lambda b, co, s=s, piede=piede, dp=dp: (b in ('foot_' + s, 'toe_' + s)) and co.z >= z_cav * 0.30 and
                            (((co - piede.head_local).dot(dp) / (0.045 * u)) % 1.0) < 0.42, lambda co: 0.010 * u, riduci=1)
                if g:
                    pezzi['bordo'].append(g)
            else:
                dente, fila = K.get('dente', 0.0), K.get('fila', 0.06)
                g = _guscio(corpo, osso, lambda b, co, s=s: b in ('foot_' + s, 'toe_' + s, 'toe_end_' + s) or (b == 'shin_' + s and co.z < z_su),
                            lambda co: (K['base'] + (dente * (((z_su - co.z) / (fila * u)) % 1.0) if co.z > z_cav else 0.0)
                                        + (K.get('risvolto', 0.0) if co.z > z_su - 0.05 * u else 0.0)) * u)
                if g:
                    pezzi['piastre'].append(g)
            if 'anello' in K:                                   # fascia di metallo in cima al gambale
                t = (stinco.head_local.z - z_su) / max(1e-6, stinco.head_local.z - stinco.tail_local.z)
                cen = stinco.head_local.lerp(stinco.tail_local, t)
                seg = 20
                rr = []
                for i in range(seg):
                    a = 2 * math.pi * i / seg
                    dd = Vector((math.cos(a), math.sin(a), 0))
                    hit = bvh.ray_cast(cen + dd * 0.15 * u, -dd)[0]
                    rr.append(max(0.035 * u, min(0.10 * u, (hit - cen).length if hit else 0.06 * u)))
                rmax = sorted(rr)[seg // 4] * 1.12      # i raggi verso l'altra gamba la colpiscono: si usa il quartile basso
                bm = bmesh.new()
                h, sp = K['anello'] * u, (K['base'] + K.get('risvolto', 0) + K.get('dente', 0) + 0.008) * u
                _griglia(bm, [[cen + Vector((math.cos(2 * math.pi * i / seg) * (rmax + dr), math.sin(2 * math.pi * i / seg) * (rmax + dr), dz)) for i in range(seg)]
                              for dz, dr in ((-h / 2, sp - 0.004 * u), (-h / 2, sp + 0.008 * u), (h / 2, sp + 0.008 * u), (h / 2, sp - 0.004 * u))], chiusa=True)
                pezzi['bordo'].append(_oggetto('an', bm, lambda co, s=s: {'shin_' + s: 1.0}, lambda p, cen=cen: Vector((p.x - cen.x, p.y - cen.y, 0))))
            if 'ali' in K:                                      # alette alla caviglia, verso l'esterno e all'indietro
                k = K['ali']
                n = 8
                ts = [i / (n - 1) for i in range(n)]
                p_ala = piede.head_local + Vector((sgn * 0.055 * u, 0.01 * u, 0.02 * u))
                for alza in (1.0, 0.55):
                    bm = bmesh.new()
                    centri = [p_ala + Vector((sgn * 0.035 * t, 0.17 * k * t, 0.15 * k * alza * t ** 0.8)) * u for t in ts]
                    larghezze = [(0.042 * k * (1 - t) ** 0.8 + 0.003) * u for t in ts]
                    _lama(bm, centri, larghezze, Vector((0, -0.45, 0.89)).normalized())
                    pezzi['bordo'].append(_oggetto('alc', bm, lambda co, s=s: {'foot_' + s: 0.5, 'shin_' + s: 0.5}, lambda p, sgn=sgn: Vector((sgn, 0, 0))))
        _unisci(nome, pezzi, K['colori'], arm, stoffa=K.get('stoffa', False))
        fatti.append(nome)

    bm0.free()
    return fatti
