# Regni di Giada — bestie dei mostri con scheletro: lupi (comune, capobranco, sciacallo), cinghiali, orso, tigre, scimmie.
#
# Uso: python3 tools/blender/mostri.py -- client/assets/modelli/mostri.glb      (modulo bpy)
#      blender -b --factory-startup --python tools/blender/mostri.py -- client/assets/modelli/mostri.glb
#
# Stessa costruzione di animali.py (19 ossa con gli stessi nomi, azioni "<specie>:<azione>": fermo, passo, corsa,
# attacco, colpito, morte), con forme più ricche e più riconoscibili per i mostri. Il file animali.glb resta al cavallo
# e al client nel browser.
# Dati per lo shader del gioco (godot/shader/bestia.gdshader), niente texture:
#   - UV0: x = casella della parte (pelo, ventre, scuro, occhi, zanne, criniera, interno, faccia, cristallo, metallo,
#     artigli), y = curvatura (0,5 = piatto; il glTF capovolge la v: si scrive 1 - v);
#   - UV1 («Part»): y = occlusione dipinta (1 = in piena luce, scritta come 1 - v).
import bpy, bmesh, math, sys, os
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from forme import lathe, sphere, cone, box, catmull, weights_for, make_obj, apply_subsurf, select_only, shade_vertices, make_action, stash_actions

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = os.path.abspath(argv[0] if argv else 'mostri.glb')
HERE = os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 30

ATLAS = 256
SLOT = {'pelo': 0, 'pelo2': 1, 'scuro': 2, 'occhi': 3, 'zanne': 4, 'criniera': 5, 'interno': 6, 'faccia': 7,
        'cristallo': 8, 'metallo': 9, 'artigli': 10}

# L lunghezza del busto, H altezza del bacino, Hf (facoltativo) altezza delle spalle in rapporto ad H.
SPECIES = {
    'lupo': dict(L=0.95, H=0.84, bodyR=0.2, hipR=0.15, neckLen=0.2, neckA=66, headR=0.19, snoutLen=0.31, snoutR=0.08, ears='punta', earS=0.16,
                 tail=('folta', 0.6), legR=0.058, sx=0.11, ruff=0.6, claws=True, walk=(24, 30), run=(46, 16)),
    # capobranco (alfa e anziano): petto più grande, criniera folta sul collo e sulle spalle, muso lungo
    'lupo_capo': dict(L=1.0, H=0.9, Hf=1.06, bodyR=0.24, hipR=0.16, neckLen=0.2, neckA=60, headR=0.205, snoutLen=0.33, snoutR=0.088, ears='punta', earS=0.17,
                      tail=('folta', 0.66), legR=0.064, sx=0.12, ruff=1.3, claws=True, walk=(24, 32), run=(46, 16)),
    # sciacallo: snello, zampe lunghe, orecchie enormi, coda sottile e folta in punta
    'sciacallo': dict(L=0.85, H=0.86, bodyR=0.16, hipR=0.13, neckLen=0.22, neckA=62, headR=0.16, snoutLen=0.3, snoutR=0.065, ears='grandi', earS=0.26,
                      tail=('folta', 0.48), legR=0.045, sx=0.095, claws=True, walk=(26, 28), run=(48, 15)),
    'cinghiale': dict(L=0.85, H=0.9, Hf=1.08, bodyR=0.28, hipR=0.23, neckLen=0.12, neckA=80, headR=0.23, snoutLen=0.32, snoutR=0.1, ears='punta', earS=0.11,
                      tail=('sottile', 0.22), legR=0.08, sx=0.15, tusks=0.2, crest=True, walk=(20, 26), run=(38, 14)),
    # cinghiale dalle zanne di ferro: zanne enormi rivestite, piastra sul muso, cresta irta
    'cinghiale_ferro': dict(L=0.9, H=0.95, Hf=1.12, bodyR=0.31, hipR=0.25, neckLen=0.12, neckA=80, headR=0.25, snoutLen=0.32, snoutR=0.11, ears='punta', earS=0.11,
                            tail=('sottile', 0.22), legR=0.088, sx=0.16, tusks=0.36, ironTusks=True, plate=True, crest=True, walk=(20, 28), run=(38, 14)),
    'orso': dict(L=1.1, H=1.1, Hf=1.06, bodyR=0.44, hipR=0.38, neckLen=0.24, neckA=74, headR=0.23, snoutLen=0.2, snoutR=0.1, ears='tonde', earS=0.075,
                 tail=('mozza', 0.12), legR=0.115, sx=0.21, hump=True, claws=True, ruff=0.5, walk=(20, 36), run=(34, 20)),
    'tigre': dict(L=1.2, H=0.9, bodyR=0.23, hipR=0.2, neckLen=0.24, neckA=58, headR=0.2, snoutLen=0.13, snoutR=0.1, ears='tonde', earS=0.065,
                  tail=('lunga', 1.05), legR=0.08, sx=0.13, cheeks=True, claws=True, walk=(22, 34), run=(44, 16)),
    # scimmie: spalle alte e braccia lunghe (si appoggiano sulle nocche), faccia piatta, coda arricciata
    'scimmia': dict(L=0.42, H=0.52, Hf=1.75, bodyR=0.19, hipR=0.15, neckLen=0.08, neckA=40, headR=0.15, snoutLen=0.05, snoutR=0.075, ears='scimmia', earS=0.05,
                    tail=('ricciolo', 0.75), legR=0.05, sx=0.12, armR=0.055, monkey=True, walk=(22, 30), run=(40, 16)),
    # scimmia urlatrice: più grossa, mantello di pelo sulle spalle, barba sotto il mento, braccia possenti
    'scimmia_urlatrice': dict(L=0.48, H=0.58, Hf=1.85, bodyR=0.24, hipR=0.17, neckLen=0.08, neckA=40, headR=0.165, snoutLen=0.07, snoutR=0.085, ears='scimmia', earS=0.05,
                              tail=('ricciolo', 0.85), legR=0.058, sx=0.14, armR=0.07, monkey=True, cape=True, beard=True, walk=(22, 32), run=(40, 16)),
}


def slot_uv(name, curv=0.0):
    i = SLOT[name]
    return ((i * 16 + 8) / ATLAS, 1 - (0.5 + 0.5 * curv))


def build(name, P):
    L, H = P['L'], P['H']
    Hc = H * P.get('Hf', 1.0)          # altezza delle spalle
    hipY, chestY = L / 2, -L / 2
    bR, hR = P['bodyR'], P['hipR']
    monkey = P.get('monkey', False)

    def zline(y):
        # quota della schiena lungo il busto: dal bacino (H) alle spalle (Hc)
        t = max(0.0, min(1.0, (hipY - y) / (hipY - chestY)))
        return H + (Hc - H) * t

    # ---------------------------------------------------------------- scheletro (posizioni)
    neck0 = Vector((0, chestY - 0.06, Hc - bR * 0.25))
    a = math.radians(P['neckA'])
    ndir = Vector((0, -math.sin(a), math.cos(a)))
    neck1 = neck0 + ndir * P['neckLen']
    hdir = Vector((0, -1, -0.3)).normalized() if not monkey else Vector((0, -1, -0.05)).normalized()
    skull = neck1 + ndir * P['headR'] * 0.45 + hdir * P['headR'] * 0.3
    snout_end = skull + hdir * (P['headR'] * 0.7 + P['snoutLen'])
    sx = P['sx']
    legs = {}
    for s, k in (('L', 1), ('R', -1)):
        if monkey:
            # braccia lunghe dalle spalle alte fino a terra, un po' in avanti; gambe corte e piegate
            legs['f' + s] = [Vector((sx * k * 1.25, chestY, Hc - bR * 0.45)), Vector((sx * k * 1.45, chestY - 0.02, Hc * 0.52)),
                             Vector((sx * k * 1.3, chestY - 0.1, 0.16)), Vector((sx * k * 1.3, chestY - 0.16, 0.03))]
            legs['b' + s] = [Vector((sx * k, hipY, H - hR * 0.5)), Vector((sx * k * 1.2, hipY - 0.2, H * 0.55)),
                             Vector((sx * k * 1.1, hipY + 0.02, H * 0.2)), Vector((sx * k * 1.1, hipY - 0.1, 0.025))]
        else:
            legs['f' + s] = [Vector((sx * k, chestY, Hc - bR * 0.7)), Vector((sx * k * 1.05, chestY + 0.03, Hc * 0.5)),
                             Vector((sx * k, chestY, Hc * 0.16)), Vector((sx * k, chestY - 0.07, 0.025))]
            legs['b' + s] = [Vector((sx * k, hipY, H - hR * 0.6)), Vector((sx * k * 1.05, hipY - 0.13, H * 0.55)),
                             Vector((sx * k, hipY + 0.12, H * 0.25)), Vector((sx * k, hipY + 0.05, 0.025))]
    tail0 = Vector((0, hipY + 0.12, H - 0.04))
    tl = P['tail'][1]
    tail_pts = [tail0, tail0 + Vector((0, tl * 0.4, -tl * 0.1)), tail0 + Vector((0, tl * 0.75, -tl * 0.35)), tail0 + Vector((0, tl * 0.95, -tl * 0.75))]
    if P['tail'][0] == 'lunga':
        tail_pts = [tail0, tail0 + Vector((0, tl * 0.4, -tl * 0.25)), tail0 + Vector((0, tl * 0.75, -tl * 0.35)), tail0 + Vector((0.1, tl, -tl * 0.1))]
    elif P['tail'][0] == 'ricciolo':
        # coda che sale ad arco e si arriccia in cima
        tail0 = Vector((0, hipY + 0.06, H - 0.02))
        tail_pts = [tail0, tail0 + Vector((0, tl * 0.35, tl * 0.15)), tail0 + Vector((0, tl * 0.5, tl * 0.6)), tail0 + Vector((0, tl * 0.25, tl * 0.85))]
    BONES = [
        ('hips', Vector((0, hipY, H - 0.08)), Vector((0, 0.0, zline(0.0) - 0.06)), None),
        ('spine', Vector((0, 0.0, zline(0.0) - 0.06)), Vector((0, chestY * 0.6, zline(chestY * 0.6) - 0.04)), 'hips'),
        ('chest', Vector((0, chestY * 0.6, zline(chestY * 0.6) - 0.04)), neck0, 'spine'),
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

    def add(bm, slot, bones, smooth=True, netto=False):
        # netto: pezzo a punta (orecchie, artigli, zanne, ciuffi) che non passa dalla suddivisione e resta affilato
        PIECES.append(dict(bm=bm, slot=slot, bones=bones, smooth=smooth, netto=netto))

    core = ['hips', 'spine', 'chest', 'neck']
    hr = P['headR']

    def zc(y, ry):
        return zline(y) - ry * 0.8

    body = [((0, hipY + 0.2, zc(hipY, hR * 0.75) + 0.02), hR * 0.55, hR * 0.6), ((0, hipY, zc(hipY, hR * 1.1)), hR, hR * 1.1),
            ((0, 0, zc(0, bR * 0.92)), bR * 0.84, bR * 0.92), ((0, chestY, zc(chestY, bR * 1.32)), bR, bR * 1.32 * (1.12 if P.get('hump') else 1)),
            ((0, chestY - 0.16, zc(chestY, bR * 0.95)), bR * 0.72, bR * 0.95)]
    if monkey:
        # busto corto e tozzo, inclinato verso l'alto
        body = [((0, hipY + 0.08, zc(hipY, hR) + 0.02), hR * 0.7, hR * 0.8), ((0, hipY - 0.02, zc(hipY, hR * 1.1)), hR * 1.05, hR * 1.15),
                ((0, 0, zc(0, bR)), bR * 0.95, bR), ((0, chestY, zc(chestY, bR * 1.1)), bR * 1.08, bR * 1.15),
                ((0, chestY - 0.08, zc(chestY, bR * 0.6) + 0.06), bR * 0.75, bR * 0.7)]
    belly = (lambda c: 'pelo2' if c.z < zline(c.y) - bR * 1.35 else 'pelo') if not monkey else (lambda c: 'pelo2' if (c.y < chestY + 0.05 and c.z < Hc - bR * 0.3) else 'pelo')
    add(lathe(body, n=16), belly, core)
    if P.get('hump'):
        add(sphere((0, chestY + 0.08, Hc - 0.02), bR * 0.75, (0.9, 1.1, 0.6)), 'pelo', ['spine', 'chest'])
    add(lathe([(neck0 - ndir * 0.08, bR * 0.72, bR * 0.85), (neck0 + ndir * P['neckLen'] * 0.5, hr * 0.95, hr * 1.05),
               (neck1, hr * 0.8, hr * 0.85)], n=14), 'pelo', ['chest', 'neck', 'head'])
    side = hdir.cross(Vector((0, 0, 1))).normalized()
    up = side.cross(hdir).normalized()
    if monkey:
        # testa tonda, arcata sopraccigliare, muso corto con la faccia nuda, basette di pelo
        add(sphere(skull, hr, (1.0, 1.0, 1.0), seg=18, rings=12), 'pelo', ['head', 'neck'])
        face_c = skull + hdir * hr * 0.62 - up * hr * 0.12
        add(sphere(face_c, hr * 0.72, (1.0, 0.55, 0.95), seg=16, rings=10), 'faccia', ['head'])
        add(sphere(skull + hdir * hr * 0.75 + up * hr * 0.32, hr * 0.62, (1.25, 0.4, 0.32)), 'scuro', ['head'])
        add(sphere(snout_end - hdir * 0.03 - up * hr * 0.25, P['snoutR'], (1.15, 0.8, 0.75)), 'faccia', ['head'])
        add(sphere(snout_end - hdir * 0.0 - up * hr * 0.22, P['snoutR'] * 0.35, (1.4, 0.5, 0.6)), 'interno', ['head'])
        for k in (1, -1):
            add(sphere(skull + side * k * hr * 0.78 - up * hr * 0.15 + hdir * hr * 0.1, hr * 0.45, (0.55, 0.8, 1.1)), 'criniera', ['head'])
        if P.get('beard'):
            add(cone(skull + hdir * hr * 0.5 - up * hr * 1.0, hr * 0.5, hr * 0.9, (math.pi, 0, 0), seg=8, r2=hr * 0.1), 'criniera', ['head', 'neck'])
    else:
        add(sphere(skull, hr, (0.95, 1.1, 0.9), seg=18, rings=12), 'pelo', ['head', 'neck'])
        sn0 = skull + hdir * hr * 0.45
        sr = P['snoutR']
        mid = sn0.lerp(snout_end, 0.55) - up * sr * 0.08
        # muso che si assottiglia; sotto (mascella) più chiaro
        add(lathe([(sn0 + up * sr * 0.2, sr * 1.45, sr * 1.35), (mid, sr * 1.05, sr * 0.95), (snout_end - hdir * 0.02, sr * 0.7, sr * 0.62)], n=12),
            lambda c: 'pelo2' if (c - snout_end).dot(up) < -sr * 0.35 else 'pelo', ['head'])
        if name.startswith('cinghiale'):
            add(lathe([(snout_end - hdir * 0.02, P['snoutR'] * 1.05, P['snoutR'] * 0.9), (snout_end + hdir * 0.02, P['snoutR'] * 1.05, P['snoutR'] * 0.9)], n=14), 'interno', ['head'])
        else:
            add(sphere(snout_end, P['snoutR'] * 0.45, (1.2, 1, 0.8)), 'scuro', ['head'])
        # arcata delle sopracciglia: sguardo cattivo
        add(sphere(skull + hdir * hr * 0.5 + up * hr * 0.42, hr * 0.5, (1.35, 0.55, 0.3)), 'pelo', ['head'])
        if P.get('cheeks'):
            for k in (1, -1):
                add(cone(skull + side * k * hr * 0.75 - up * hr * 0.2, hr * 0.35, hr * 0.6, (0, math.pi / 2 * k * 0.9, 0), seg=6), 'pelo2', ['head'])
    for k in (1, -1):
        eye = skull + hdir * hr * (0.72 if monkey else 0.55) + side * k * hr * (0.33 if monkey else 0.52) + up * hr * (0.12 if monkey else 0.25)
        add(sphere(eye, hr * (0.12 if monkey else 0.13), (1.0, 0.7, 0.8) if not monkey else (1, 1, 1), seg=10, rings=7), 'occhi', ['head'])
        ear = skull + side * k * hr * 0.55 + Vector((0, 0.02, hr * 0.85))
        if P['ears'] == 'punta':
            e = cone(ear, P['earS'] * 0.42, P['earS'], (0.25, -0.3 * k, 0), seg=4)
            bmesh.ops.scale(e, vec=(1.0, 0.55, 1.0), space=__import__('mathutils').Matrix.Translation(-ear), verts=e.verts)
            add(e, 'pelo', ['head'], netto=True)
        elif P['ears'] == 'grandi':
            e = cone(ear + Vector((0, 0.02, P['earS'] * 0.3)), P['earS'] * 0.42, P['earS'], (0.15, -0.25 * k, 0), seg=4)
            add(e, 'pelo', ['head'], netto=True)
        elif P['ears'] == 'scimmia':
            add(sphere(skull + side * k * hr * 0.98 + up * hr * 0.05, P['earS'], (0.35, 0.9, 1.1)), 'faccia', ['head'])
        else:
            add(sphere(ear, P['earS'], (1, 0.5, 1)), 'pelo', ['head'])
        t = P.get('tusks')
        if t:
            # zanne che escono dal muso e piegano all'insù
            base = snout_end - hdir * 0.1 + side * k * P['snoutR'] * 0.85 - up * 0.02
            pts = [base, base + hdir * t * 0.35 + side * k * t * 0.15, base + hdir * t * 0.55 + side * k * t * 0.25 + up * t * 0.45,
                   base + hdir * t * 0.5 + side * k * t * 0.2 + up * t * 0.85]
            rr = 0.022 + t * 0.06
            cp = catmull(pts, 3)
            add(lathe([(p, rr * (1 - i / len(cp)) + 0.003, rr * (1 - i / len(cp)) + 0.003) for i, p in enumerate(cp)], n=8),
                'metallo' if P.get('ironTusks') else 'zanne', ['head'], netto=True)
            if P.get('ironTusks'):
                add(lathe([(base + hdir * t * 0.12 + side * k * 0.05, rr * 1.5, rr * 1.5), (base + hdir * t * 0.22 + side * k * 0.07, rr * 1.5, rr * 1.5)], n=10), 'metallo', ['head'])
    if P.get('plate'):
        # piastra di ferro borchiata sulla fronte
        add(sphere(skull + hdir * hr * 0.45 + up * hr * 0.45, hr * 0.62, (1.1, 0.45, 0.85), seg=12, rings=8), 'metallo', ['head'])
        for k in (1, 0, -1):
            add(cone(skull + hdir * hr * 0.6 + up * hr * 0.75 + side * k * hr * 0.35, 0.03, 0.08, (-0.6, 0, 0), seg=6), 'artigli', ['head'], netto=True)
    # criniera sul collo e sulle spalle: file di ciuffi a punta che scendono all'indietro, più una gorgiera sul petto
    ruff = P.get('ruff')
    if ruff:
        for fila in range(3):
            t = 0.0 + fila * 0.42
            cen = neck0.lerp(neck1, t)
            n_t = 7
            for i in range(n_t):
                ang = -math.pi * 0.15 + math.pi * 1.3 * (i + 0.5 * (fila % 2)) / n_t       # dai fianchi al dorso (niente sotto la gola)
                dirv = (side * math.cos(ang) + up * math.sin(ang)).normalized()
                p0 = cen + dirv * hr * (0.75 + 0.1 * fila)
                ln = hr * (0.55 + 0.2 * fila) * ruff
                q = (Vector((0, 0.9, -0.25)) + dirv * 0.35).normalized()
                # ciocca: ellissoide allungato verso la coda, schiacciato sul collo
                bm = sphere((0, 0, 0), hr * 0.3 * (0.75 + 0.25 * ruff), (1.0, 0.6, 1.0 + 1.3 * ruff), seg=8, rings=6)
                bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Vector((0, 0, 1)).rotation_difference(q).to_matrix())
                bmesh.ops.translate(bm, vec=p0 + q * ln * 0.45, verts=bm.verts)
                add(bm, 'criniera', ['neck', 'chest'])
        # gorgiera folta sotto il collo e sul petto
        add(sphere(neck0 - up * hr * 0.35 + ndir * 0.02, hr * (0.75 + 0.2 * ruff), (0.9, 1.0, 1.15)), 'criniera', ['chest', 'neck'])
    if P.get('crest'):
        # cresta irta lungo la schiena: ciuffi a punta inclinati all'indietro
        for i in range(9):
            y = hipY - 0.05 - i * (L * 0.95) / 8
            hgt = 0.09 + 0.07 * math.sin(math.pi * (i + 1) / 10)
            add(cone((0, y + 0.03, zline(y) + 0.02 + hgt * 0.3), 0.04, hgt * 1.5, (-0.6, 0, 0), seg=4), 'criniera', core, netto=True)
    if P.get('cape'):
        # mantello di pelo lungo sulle spalle della scimmia urlatrice
        add(lathe([((0, chestY - 0.04, Hc + 0.04), bR * 1.0, bR * 0.6), ((0, chestY + 0.1, Hc - 0.02), bR * 1.35, bR * 1.0),
                   ((0, chestY + 0.26, Hc - 0.18), bR * 1.25, bR * 0.85)], n=14), 'criniera', ['chest', 'spine', 'neck'])
    # zampe
    for key in ('fL', 'fR', 'bL', 'bR'):
        j = legs[key]
        n = key[0] + key[1]
        lr = P['legR'] * (1.0 if key[0] == 'f' else 1.15)
        if monkey and key[0] == 'f':
            lr = P.get('armR', lr)
        bones = [f'leg_{n}_up', f'leg_{n}_low', f'paw_{n}', 'chest' if key[0] == 'f' else 'hips']
        top = j[0] + Vector((0, 0, 0.05))
        mid = j[0].lerp(j[1], 0.45)
        add(lathe([(top, lr * 2.2, lr * 2.7), (mid, lr * 1.9, lr * 2.2), (j[1], lr * 1.3, lr * 1.35), (j[2], lr * 0.9, lr * 0.9), (j[3] + Vector((0, 0, 0.06)), lr * 0.85, lr * 0.85)], n=12),
            'pelo', bones)
        if monkey:
            add(sphere(j[3] + Vector((0, -0.03, 0.04)), lr * 1.5, (1.1, 1.3, 0.75)), 'faccia', bones)
        else:
            add(sphere(j[3] + Vector((0, -0.04, 0.04)), lr * 1.3, (1, 1.35, 0.6)), 'scuro' if name.startswith('cinghiale') else 'pelo', bones)
        if P.get('claws'):
            for c in (-1, 0, 1):
                add(cone(j[3] + Vector((c * lr * 0.6, -0.04 - lr * 1.2, 0.03)), lr * 0.25, lr * 0.9, (1.75, 0, 0), seg=4), 'artigli', bones, netto=True)
    # coda
    kind = P['tail'][0]
    tr = {'folta': (0.04, 0.075, 0.02), 'sottile': (0.02, 0.015, 0.008), 'mozza': (0.07, 0.06, 0.03), 'lunga': (0.045, 0.04, 0.03), 'ricciolo': (0.035, 0.03, 0.02)}[kind]
    tp = catmull(tail_pts, 3)
    prof = [(p, max(0.008, tr[0] + (tr[1] - tr[0]) * math.sin(min(1, i / (len(tp) - 1) * 1.6) * math.pi / 2) - (tr[1] - tr[2]) * max(0, i / (len(tp) - 1) - 0.6) / 0.4),
             0) for i, p in enumerate(tp)]
    prof = [(p, r, r) for p, r, _ in prof]
    add(lathe(prof, n=10), lambda c: ('pelo2' if (kind == 'folta' and (c - tail_pts[-1]).length < tl * 0.25) else 'pelo'), ['hips', 'tail1', 'tail2'])

    # ---------------------------------------------------------------- mesh liscia, ombre, unione
    BI = {n: i for i, n in enumerate(names)}

    def assembla(pezzi, nome):
        bm = bmesh.new()
        uv0 = bm.loops.layers.uv.new('UVMap')
        uv1 = bm.loops.layers.uv.new('Part')
        dl = bm.verts.layers.deform.verify()
        for pc in pezzi:
            src, vmap = pc['bm'], {}
            for v in src.verts:
                nv = bm.verts.new(v.co)
                for b, w in weights_for(v.co, pc['bones'], BH, BT):
                    nv[dl][BI[b]] = w
                vmap[v] = nv
            for f in src.faces:
                try:
                    nf = bm.faces.new([vmap[v] for v in f.verts])
                except ValueError:
                    continue
                nf.smooth = pc['smooth']
                slot = pc['slot'](f.calc_center_median()) if callable(pc['slot']) else pc['slot']
                for lp in nf.loops:
                    lp[uv0].uv = slot_uv(slot)
                    lp[uv1].uv = (0, 0)
            src.free()
        return make_obj(scene, nome, bm, names)

    ob = assembla([p for p in PIECES if not p['netto']], name)
    apply_subsurf(ob)
    netti = [p for p in PIECES if p['netto']]
    ob2 = assembla(netti, name + '_netto') if netti else None
    n2 = sum(len(p.vertices) - 2 for p in ob2.data.polygons) if ob2 else 0
    # leggerezza: dopo la suddivisione (forme morbide) si riduce il corpo, i pezzi a punta restano interi
    tri = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    dec = ob.modifiers.new('leggero', 'DECIMATE')
    dec.ratio = min(1.0, max(800, P.get('tri', 3400) - n2) / tri)
    dec.delimit = {'UV'}
    select_only(scene, [ob], ob)
    bpy.ops.object.modifier_apply(modifier=dec.name)
    if ob2:
        select_only(scene, [ob, ob2], ob)
        bpy.ops.object.join()
    ob.data.validate()
    for poly in ob.data.polygons:
        poly.use_smooth = True
    shade_vertices(ob, reach=0.3 * max(1, H))
    me = ob.data
    # occlusione e curvatura dalla terza UV («Ombra») alle prime due, che il glTF porta in Godot
    om = me.uv_layers['Ombra']
    for lp in me.loops:
        ao, cv = om.data[lp.index].uv
        cv = (1 - cv) - 1.0            # shade_vertices scrive 1 - (1 + 0.22·c)
        u0 = me.uv_layers['UVMap'].data[lp.index].uv
        me.uv_layers['UVMap'].data[lp.index].uv = (u0[0], 1 - (0.5 + 0.5 * max(-1, min(1, cv / 0.22))))
        me.uv_layers['Part'].data[lp.index].uv = (0, 1 - ao)
    me.uv_layers.remove(om)
    me.materials.clear()
    mat = bpy.data.materials.get('bestia') or bpy.data.materials.new('bestia')
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
    ob.parent = arm
    ob.modifiers.new('scheletro', 'ARMATURE').object = arm

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
    # da fermo: respiro, coda e testa che si guardano attorno (le scimmie si grattano la testa con un braccio)
    if monkey:
        acts.append(cycle('fermo', 72, 8, lambda p: {**tails(p, 6), 'chest': [('X', 2.5 * math.sin(TAU * p))],
                                                      'neck': [('Z', 18 * math.sin(TAU * p * 0.5 + 1))], 'head': [('X', 5 * math.sin(TAU * p * 2))],
                                                      'leg_fR_up': [fwd(10 + 25 * max(0, math.sin(TAU * p)))], 'leg_fR_low': [('X', 40 * max(0, math.sin(TAU * p)))]}))
    else:
        acts.append(cycle('fermo', 60, 6, lambda p: {**tails(p, 8), 'chest': [('X', 1.5 * math.sin(TAU * p))],
                                                      'neck': [('Z', 10 * math.sin(TAU * p * 0.5 + 1))], 'head': [('X', 3 * math.sin(TAU * p))]}))
    acts.append(cycle('passo', wf, 8, lambda p: {**legs_pose({'fL': p, 'bR': p + 0.02, 'fR': p + 0.5, 'bL': p + 0.52}, wa, 30), **tails(p, 10),
                                                  'neck': [('X', 3 * math.sin(TAU * p * 2))], 'loc': (0, 0, 0.018 * math.cos(2 * TAU * p))}))
    acts.append(cycle('corsa', rf, 8, lambda p: {**legs_pose({'fL': p, 'fR': p - 0.1, 'bL': p + 0.5, 'bR': p + 0.4}, ra, 55), **tails(p, 6),
                                                  'spine': [('X', 7 * math.sin(TAU * p))], 'chest': [('X', -5 * math.sin(TAU * p))],
                                                  'neck': [('X', -6 * math.sin(TAU * p))], 'loc': (0, 0, 0.05 * math.sin(TAU * p) + 0.02)}))
    if monkey:
        # si alza sulle gambe e schiaccia a due braccia
        su = {'spine': [('X', -28)], 'chest': [('X', -18)], 'neck': [('X', 20)], 'leg_fL_up': [fwd(150)], 'leg_fR_up': [fwd(150)],
              'leg_fL_low': [('X', 30)], 'leg_fR_low': [('X', 30)], 'leg_bL_up': [fwd(-20)], 'leg_bR_up': [fwd(-20)], 'loc': (0, 0.05, 0.12),
              'head': [('X', -15)]}
        giu = {'spine': [('X', 6)], 'chest': [('X', 8)], 'neck': [('X', -5)], 'leg_fL_up': [fwd(40)], 'leg_fR_up': [fwd(40)],
               'leg_fL_low': [('X', 5)], 'leg_fR_low': [('X', 5)], 'loc': (0, -0.15, -0.05), 'head': [('X', 10)]}
        acts.append(make_action(arm, f'{name}:attacco', [(0, {}), (7, su), (10, su), (13, giu), (22, {})]))
    else:
        crouch = {'leg_fL_up': [fwd(-12)], 'leg_fR_up': [fwd(-12)], 'leg_fL_low': [('X', 25)], 'leg_fR_low': [('X', 25)], 'loc': (0, 0.05, -0.06),
                  'neck': [('X', 15)], 'head': [('X', -10)]}
        lunge = {'leg_fL_up': [fwd(35)], 'leg_fR_up': [fwd(30)], 'leg_bL_up': [fwd(-25)], 'leg_bR_up': [fwd(-25)], 'loc': (0, -0.22, 0.03),
                 'neck': [('X', 22)], 'head': [('X', 18)], 'spine': [('X', -6)]}
        if name.startswith('cinghiale'):
            # carica a testa bassa con un colpo di zanne verso l'alto
            lunge = {**lunge, 'neck': [('X', 28)], 'head': [('X', 10)], 'loc': (0, -0.3, 0.0)}
            bite = {**lunge, 'neck': [('X', -12)], 'head': [('X', -20)]}
        elif name in ('orso', 'tigre'):
            # zampata: si alza sul davanti e cala la zampa destra
            lunge = {'spine': [('X', -18)], 'chest': [('X', -10)], 'leg_fR_up': [fwd(95)], 'leg_fR_low': [('X', 40)], 'leg_fL_up': [fwd(30)],
                     'neck': [('X', 10)], 'loc': (0, -0.05, 0.1)}
            bite = {'spine': [('X', 4)], 'leg_fR_up': [fwd(30)], 'leg_fR_low': [('X', 5)], 'neck': [('X', 18)], 'head': [('X', 12)], 'loc': (0, -0.2, -0.03)}
        else:
            bite = {**lunge, 'head': [('X', -14)], 'neck': [('X', 12)]}
        acts.append(make_action(arm, f'{name}:attacco', [(0, {}), (5, crouch), (9, lunge), (11, bite), (18, {})]))
    acts.append(make_action(arm, f'{name}:colpito', [(0, {}), (3, {'neck': [('X', -18), ('Z', 10)], 'chest': [('X', -6)], 'loc': (0, 0.06, 0)}), (9, {})]))
    fall = {'hips': [('Y', 80)], 'loc': (0, 0, -(H - bR * 1.1) * 0.85)}
    for n in ('fL', 'fR', 'bL', 'bR'):
        fall[f'leg_{n}_up'] = [fwd(15 if n[0] == 'f' else -15)]
    acts.append(make_action(arm, f'{name}:morte', [(0, {}), (8, {'leg_fL_low': [('X', 50)], 'leg_fR_low': [('X', 50)], 'loc': (0, 0, -0.15), 'neck': [('X', 20)]}),
                                                     (20, fall), (30, {**fall, 'neck': [('X', -10), ('Y', 20)]})]))
    stash_actions(arm, acts)
    print(f'{name}: {len(me.vertices)} vertici, {sum(len(p.vertices) - 2 for p in me.polygons)} triangoli, {len(acts)} azioni')
    return arm


for nm, P in SPECIES.items():
    build(nm, P)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_animations=True, export_animation_mode='ACTIONS',
                          export_force_sampling=True, export_skins=True, export_def_bones=False, export_morph=False,
                          export_yup=True, export_texcoords=True, export_normals=True, export_materials='EXPORT', export_apply=False)
print('ESPORTATO', OUT)
