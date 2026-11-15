# Regni di Giada — completi per classe e per grado, costruiti attorno al corpo base e legati al suo scheletro.
#
# Usato da importa_eroi.py. Per ogni classe (lama, ombra, monaco, mistico) si costruiscono:
#   capo_<classe>_base__<parte>   vesti di sotto, sempre indossate (pantaloni, veste, fasce...)
#   capo_<classe>_<g>__<parte>    sopravveste/armatura del grado g (0 = senza armatura, 1-4 = gradi degli oggetti)
# Parti (il client sceglie lo shader dalla parte, il colore dal modello o dal gioco):
#   stoffa (colore «robe» della classe), stoffa2 («pants»), fascia («trim»), regno (colore del regno),
#   cuoio, piastre (metallo liscio), lamelle (metallo: le file sovrapposte sono geometria, le giunture fra le piastre le
#   disegna lo shader metallo.gdshader), bordo (finiture d'oro o di bronzo), grani (legno, giada), gemma (luminosa),
#   carta (talismani). L'esportatore glTF non scrive le UV (nessuna texture): gli shader usano le coordinate del modello.
# Corpo femminile (donna=True): stessi completi; il Monaco aggiunge la fascia al petto (il busto resta scoperto ai lati).
# Geometria vera: superfici campionate attorno al corpo con raggi dall'interno (busto, arti), poi spessore e orli;
# piastre, spallacci, borchie, grani, lame e ornamenti sono solidi a parte. Pesi: quelli del punto del corpo più vicino
# (le vesti seguono la pelle), pesi rigidi per i pezzi duri (spallacci, ornamenti), pesi bacino → coscia per le falde.
# Convenzioni: Z in alto, personaggio rivolto verso -Y, sinistra del personaggio = +X, trasformazioni già applicate.
# Angoli attorno al busto in gradi: 0 = sinistra (+X), -90 = davanti, 90 = dietro, 180 = destra.
import bpy, bmesh, math
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
from mathutils.interpolate import poly_3d_calc

SU, AVANTI = Vector((0, 0, 1)), Vector((0, -1, 0))
CLASSI = ('lama', 'ombra', 'monaco', 'mistico')

# colori di partenza (lineari) delle parti che il gioco non tinge
CUOIO = (0.10, 0.055, 0.03)
CUOIO_CHIARO = (0.22, 0.12, 0.06)
ORO = (0.80, 0.52, 0.16)
BRONZO = (0.42, 0.25, 0.09)
ACCIAIO = (0.30, 0.32, 0.35)
ARGENTO = (0.62, 0.64, 0.68)


def _lim(x, a, b):
    return a if x < a else (b if x > b else x)


def _liscia(v, giri=1, chiusa=False):
    """Media mobile su una lista di numeri."""
    v = list(v)
    n = len(v)
    for _ in range(giri):
        w = v[:]
        for i in range(n):
            if chiusa:
                w[i] = (v[i - 1] + 2 * v[i] + v[(i + 1) % n]) / 4
            elif 0 < i < n - 1:
                w[i] = (v[i - 1] + 2 * v[i] + v[i + 1]) / 4
        v = w
    return v


class Sarto:
    """Strumenti per cucire capi attorno a un corpo (oggetto mesh con gruppi di vertici) e al suo scheletro."""

    def __init__(self, corpo, arm, H, donna=False):
        self.corpo, self.arm, self.donna = corpo, arm, donna
        self.u = H / 1.8
        self.B = arm.data.bones
        me = corpo.data
        gr = {g.index: g.name for g in corpo.vertex_groups}
        self.vpesi = [{gr[g.group]: g.weight for g in v.groups if g.group in gr and g.weight > 0.01} for v in me.vertices]
        self.bm = bmesh.new()
        self.bm.from_mesh(me)
        self.bm.faces.ensure_lookup_table()
        self.bvh = BVHTree.FromBMesh(self.bm)
        self.parti = {}            # (capo, parte) -> bmesh
        self.colori = {}           # (capo, parte) -> colore
        self.specifiche = []       # pesi: 0 = dal corpo, altrimenti indice + 1 in questa lista (dict o funzione)
        self._centri = {}
        u = self.u
        B = self.B
        self.z_vita = B['spine'].head_local.z
        self.z_collo = B['neck'].head_local.z
        self.z_spalla = B['upper_arm_L'].head_local.z
        self.z_ascella = self.z_spalla - 0.10 * u
        self.z_anca = B['thigh_L'].head_local.z
        self.z_ginocchio = B['shin_L'].head_local.z
        self.z_caviglia = B['foot_L'].head_local.z
        hit = self.bvh.ray_cast(Vector((0, B['hips'].head_local.y, 0.3)), SU, 3.0)[0]
        self.z_cavallo = hit.z if hit else self.z_anca - 0.1 * u

    # ------------------------------------------------------------------ misure
    def ossa(self, n):
        b = self.B[n]
        return b.head_local.copy(), b.tail_local.copy()

    def vicino(self, p):
        loc, nor, idx, d = self.bvh.find_nearest(p)
        return loc, idx

    def pesi_in(self, p):
        """Pesi delle ossa nel punto del corpo più vicino a p (al massimo 4, normalizzati)."""
        loc, idx = self.vicino(p)
        f = self.bm.faces[idx]
        w = poly_3d_calc([v.co for v in f.verts], loc)
        out = {}
        for v, k in zip(f.verts, w):
            for b, x in self.vpesi[v.index].items():
                out[b] = out.get(b, 0.0) + x * k
        out.pop('root', None)
        top = sorted(out.items(), key=lambda t: -t[1])[:4]
        s = sum(x for _, x in top) or 1.0
        return {b: x / s for b, x in top}

    def fuori(self, p):
        loc, idx = self.vicino(p)
        d = p - loc
        if d.length < 1e-6:
            return self.bm.faces[idx].normal.copy()
        return d.normalized()

    def raggio(self, o, d, rmin, rmax):
        """Distanza dal punto interno o alla pelle, lungo d (il primo punto in uscita)."""
        hit = self.bvh.ray_cast(o, d, rmax)[0]
        return _lim((hit - o).length if hit else rmax, rmin, rmax)

    def uscita(self, o, d, rmax):
        """Distanza dell'ultima superficie attraversata lungo d entro rmax (0 se nessuna)."""
        r, p = 0.0, o.copy()
        for _ in range(8):
            hit = self.bvh.ray_cast(p, d, rmax - (p - o).length)[0]
            if not hit:
                break
            r = (hit - o).length
            p = hit + d * 0.002
            if r >= rmax:
                break
        return r

    def centro(self, z):
        """Centro del busto alla quota z (a metà fra petto e schiena)."""
        k = round(z, 3)
        if k not in self._centri:
            y0 = self.B['hips'].head_local.y * 0.5
            o = Vector((0, y0, z))
            f = self.raggio(o, Vector((0, -1, 0)), 0.02, 0.6)
            b = self.raggio(o, Vector((0, 1, 0)), 0.02, 0.6)
            if (f > 0.55 or b > 0.55) and z < self.B['hips'].head_local.z:
                # fra le gambe: l'asse resta quello del bacino
                c = self.centro(z + 0.03)
                self._centri[k] = Vector((0, c.y, z))
            else:
                self._centri[k] = Vector((0, y0 + (b - f) / 2, z))
        return self._centri[k]

    @staticmethod
    def dir(a):
        a = math.radians(a)
        return Vector((math.cos(a), math.sin(a), 0))

    # ------------------------------------------------------------------ costruzione
    def _bm(self, capo, parte, colore):
        k = (capo, parte)
        if k not in self.parti:
            bm = bmesh.new()
            bm.verts.layers.int.new('spec')
            bm.loops.layers.uv.new('UVMap')
            self.parti[k] = bm
            self.colori[k] = colore
        return self.parti[k]

    def _spec(self, pesi):
        if pesi is None or pesi == 'corpo':
            return 0
        self.specifiche.append(pesi)
        return len(self.specifiche)

    def griglia(self, capo, parte, righe, colore=(1, 1, 1), chiusa=False, spessore=0.0, pesi='corpo', fuori=None,
                uv=None, chiudi_fondo=False):
        """Superficie da righe di punti (tutte lunghe uguali). spessore > 0: guscio solido verso l'interno.
        fuori(p) → verso esterno (di base: lontano dal corpo). uv: righe di (u, v); di base in metri lungo righe e colonne."""
        bm = self._bm(capo, parte, colore)
        spec = bm.verts.layers.int['spec']
        uvl = bm.loops.layers.uv['UVMap']
        s = self._spec(pesi)
        n = len(righe[0])
        if uv is None:
            uv = []
            vv = [0.0] * n
            for j, r in enumerate(righe):
                if j:
                    vv = [vv[i] + (r[i] - righe[j - 1][i]).length for i in range(n)]
                uu = [0.0]
                for i in range(1, n):
                    uu.append(uu[-1] + (r[i] - r[i - 1]).length)
                uv.append(list(zip(uu, vv)))
        vs = []
        for r in righe:
            riga = []
            for p in r:
                v = bm.verts.new(p)
                v[spec] = s
                riga.append(v)
            vs.append(riga)
        facce = []
        for j in range(len(righe) - 1):
            for i in range(n if chiusa else n - 1):
                i2 = (i + 1) % n
                q = (vs[j][i], vs[j][i2], vs[j + 1][i2], vs[j + 1][i])
                if len(set(q)) < 4:
                    continue
                try:
                    f = bm.faces.new(q)
                except ValueError:
                    continue
                cu = [uv[j][i], uv[j][i2] if i2 else (uv[j][i][0] + (righe[j][i2] - righe[j][i]).length, uv[j][i][1]),
                      uv[j + 1][i2] if i2 else (uv[j + 1][i][0] + (righe[j + 1][i2] - righe[j + 1][i]).length, uv[j + 1][i][1]), uv[j + 1][i]]
                for l, c in zip(f.loops, cu):
                    l[uvl].uv = c
                facce.append(f)
        if chiudi_fondo and chiusa:
            for riga in (vs[0], vs[-1]):
                try:
                    f = bm.faces.new(riga)
                    facce.append(f)
                except ValueError:
                    pass
        self._orienta(bm, facce, fuori)
        if spessore > 0 and facce:
            self._solido(bm, facce, spessore)
        return vs

    def _orienta(self, bm, facce, fuori):
        if not facce:
            return
        bm.normal_update()
        tot = 0.0
        for f in facce:
            c = f.calc_center_median()
            tot += f.normal.dot(fuori(c) if fuori else self.fuori(c))
        if tot < 0:
            bmesh.ops.reverse_faces(bm, faces=facce)

    def _solido(self, bm, facce, spessore):
        bm.normal_update()
        geom = list({v for f in facce for v in f.verts}) + list({e for f in facce for e in f.edges}) + facce
        bmesh.ops.solidify(bm, geom=geom, thickness=spessore)

    def mesh_primitiva(self, capo, parte, crea, colore, pesi, matrice=Matrix.Identity(4)):
        """Aggiunge una primitiva di bmesh.ops (crea(bm_tmp)) trasformata da matrice."""
        tmp = bmesh.new()
        crea(tmp)
        bmesh.ops.transform(tmp, matrix=matrice, verts=tmp.verts)
        me = bpy.data.meshes.new('tmp')
        tmp.to_mesh(me)
        tmp.free()
        bm = self._bm(capo, parte, colore)
        spec = bm.verts.layers.int['spec']
        prima = set(bm.verts)
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
        s = self._spec(pesi)
        for v in bm.verts:
            if v not in prima:
                v[spec] = s

    # ------------------------------------------------------------------ vesti aderenti: la pelle ritagliata
    def guscio(self, capo, parte, campo, stacco=0.012, colore=(1, 1, 1), spessore=0.0, liscia=6, seme=None, pesi='corpo', riduci=0.4,
               bordo=None):
        """Veste ricavata dalla pelle: si tiene la zona dove campo(co) > 0, tagliata esattamente sulla linea campo = 0
        (orli puliti), gonfiata di «stacco» (m o funzione co → m), lisciata (la stoffa non entra nei solchi dei muscoli).
        seme: punto; si tiene solo il pezzo connesso più vicino. bordo: (raggio, parte, colore) di un cordoncino sugli orli.
        Ritorna gli orli come liste di punti."""
        bm = self.bm.copy()
        for l in list(bm.verts.layers.deform):
            bm.verts.layers.deform.remove(l)
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)        # cuciture delle UV: la pelle diventa un pezzo solo
        f = {v: campo(v.co) for v in bm.verts}
        bmesh.ops.delete(bm, geom=[fa for fa in bm.faces if all(f[v] < 0 for v in fa.verts)
                                   and all(f[w] < 0 for v in fa.verts for e in v.link_edges for w in e.verts)], context='FACES')
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
        tagli = set()
        for e in list(bm.edges):
            a, b = e.verts
            fa, fb = f[a], f[b]
            if (fa > 0) != (fb > 0) and abs(fa - fb) > 1e-12:
                t = fa / (fa - fb)
                if t < 1e-4:
                    tagli.add(a)
                    f[a] = 0.0
                    continue
                if t > 1 - 1e-4:
                    tagli.add(b)
                    f[b] = 0.0
                    continue
                ne, nv = bmesh.utils.edge_split(e, a, t)
                nv.co = a.co.lerp(b.co, t)
                f[nv] = 0.0
                tagli.add(nv)
        for fa in list(bm.faces):
            cs = [v for v in fa.verts if v in tagli]
            if len(cs) == 2:
                a, b = cs
                if not any(a in e.verts and b in e.verts for e in fa.edges):
                    try:
                        bmesh.utils.face_split(fa, a, b)
                    except Exception:
                        pass
        bmesh.ops.delete(bm, geom=[fa for fa in bm.faces if any(f.get(v, -1) < -1e-9 for v in fa.verts)], context='FACES')
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
        if seme is not None and bm.faces:
            # pezzo connesso al seme
            bm.faces.ensure_lookup_table()
            iniz = min(bm.faces, key=lambda fa: (fa.calc_center_median() - Vector(seme)).length_squared)
            visti, coda = {iniz}, [iniz]
            while coda:
                fa = coda.pop()
                for e in fa.edges:
                    for g in e.link_faces:
                        if g not in visti:
                            visti.add(g)
                            coda.append(g)
            bmesh.ops.delete(bm, geom=[fa for fa in bm.faces if fa not in visti], context='FACES')
            bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
        if not bm.faces:
            bm.free()
            return []
        # gonfia, liscia, e riporta fuori quello che è rientrato
        st = stacco if callable(stacco) else (lambda co, s=stacco: s)
        bm.normal_update()
        for v in bm.verts:
            v.co += v.normal * st(v.co)
        bordo_v = [v for v in bm.verts if v.is_boundary]
        interni = [v for v in bm.verts if not v.is_boundary]
        for _ in range(liscia):
            bmesh.ops.smooth_vert(bm, verts=interni, factor=0.6, use_axis_x=True, use_axis_y=True, use_axis_z=True)
            nuove = {}
            for v in bordo_v:                      # gli orli si lisciano lungo se stessi
                vic = [e.other_vert(v) for e in v.link_edges if e.is_boundary]
                if len(vic) == 2:
                    nuove[v] = v.co * 0.5 + (vic[0].co + vic[1].co) * 0.25
            for v, co in nuove.items():
                v.co = co
            for v in bm.verts:
                loc, idx = self.vicino(v.co)
                d = v.co - loc
                minimo = st(v.co) * 0.8
                if d.length < minimo or d.dot(self.bm.faces[idx].normal) < 0:
                    n = self.bm.faces[idx].normal
                    v.co = loc + n * minimo
        bm.normal_update()
        if riduci < 1:
            # la pelle è fitta: la veste lisciata ne regge meno della metà (orli compresi)
            me = bpy.data.meshes.new('tmp')
            bm.to_mesh(me)
            bm.free()
            ob = bpy.data.objects.new('tmp', me)
            bpy.context.scene.collection.objects.link(ob)
            mod = ob.modifiers.new('riduci', 'DECIMATE')
            mod.ratio = riduci
            dg = bpy.context.evaluated_depsgraph_get()
            bm = bmesh.new()
            bm.from_object(ob, dg)
            bpy.data.objects.remove(ob, do_unlink=True)
            bpy.data.meshes.remove(me)
            bm.normal_update()
        orli = self._orli(bm)
        if spessore > 0:
            self._solido(bm, bm.faces[:], spessore)
        me = bpy.data.meshes.new('tmp')
        bm.to_mesh(me)
        bm.free()
        dest = self._bm(capo, parte, colore)
        spec = dest.verts.layers.int['spec']
        prima = set(dest.verts)
        dest.from_mesh(me)
        bpy.data.meshes.remove(me)
        s = self._spec(pesi)
        for v in dest.verts:
            if v not in prima:
                v[spec] = s
        if bordo:
            r, p2, c2 = bordo
            for o in orli:
                if len(o) > 3:
                    L = sum((b - a).length for a, b in zip(o, o[1:]))
                    chiuso = len(o) > 8 and (o[0] - o[-1]).length < 0.05 * self.u
                    self.tubo(capo, p2, o, r, c2, lati=6, chiuso=chiuso, n=max(8, int(L / (0.025 * self.u))))
        return orli

    @staticmethod
    def _orli(bm):
        """Orli di una superficie come liste ordinate di punti (anelli chiusi o tratti aperti)."""
        lati = [e for e in bm.edges if e.is_boundary]
        vic = {}
        for e in lati:
            a, b = e.verts
            vic.setdefault(a, []).append(b)
            vic.setdefault(b, []).append(a)
        visti, out = set(), []
        for v0 in vic:
            if v0 in visti:
                continue
            giro = [v0]
            visti.add(v0)
            cur, prec = v0, None
            while True:
                nx = [w for w in vic[cur] if w is not prec and w not in visti]
                if not nx:
                    break
                prec, cur = cur, nx[0]
                visti.add(cur)
                giro.append(cur)
            out.append([v.co.copy() for v in giro])
        return out

    # ------------------------------------------------------------------ rivestimenti
    def busto(self, capo, parte, zb, zt, a0, a1, na=24, livelli=None, nv=8, stacco=0.02, colore=(1, 1, 1), spessore=0.0,
              drappo=0.55, convesso=True, rmax=0.40, pesi='corpo', chiusa=None, ritorna_raggi=False):
        """Rivestimento del busto: per ogni angolo da a0 ad a1 (gradi) quote da zb(a) a zt(a) (numeri o funzioni).
        livelli: [(frazione 0=basso..1=alto, scostamento extra in m)] al posto di nv quote uniformi.
        stacco: m (o funzione (z, a) → m) dalla pelle. drappo: quanto la stoffa può rientrare scendendo (pendenza)."""
        u = self.u
        zb_f = zb if callable(zb) else (lambda a, z=zb: z)
        zt_f = zt if callable(zt) else (lambda a, z=zt: z)
        st_f = stacco if callable(stacco) else (lambda z, a, s=stacco: s)
        if chiusa is None:
            chiusa = abs(a1 - a0) >= 359.9
        nang = na if chiusa else na + 1
        angoli = [a0 + (a1 - a0) * i / na for i in range(nang)]
        if livelli is None:
            livelli = [(k / nv, 0.0) for k in range(nv + 1)]
        livelli = sorted(livelli, key=lambda t: -t[0])          # dall'alto in basso
        # raggio della pelle per ogni (livello, angolo), poi rientri riempiti come farebbe la stoffa
        R = []
        for f, _ in livelli:
            riga = []
            for a in angoli:
                z = zb_f(a) + (zt_f(a) - zb_f(a)) * f
                riga.append(self.raggio(self.centro(z), self.dir(a), 0.03 * u, rmax * u))
            med = sorted(riga)[len(riga) // 2]
            R.append([min(r, med * 1.45) for r in riga])      # raggi finiti dentro un braccio
        if convesso:
            for riga in R:
                for _ in range(3):
                    for i in range(len(riga)):
                        if chiusa or 0 < i < len(riga) - 1:
                            m = (riga[i - 1] + riga[(i + 1) % len(riga)]) / 2
                            riga[i] = max(riga[i], m - 0.004 * u)
        for j in range(1, len(R)):                 # scendendo la stoffa non rientra più di «drappo» per metro
            for i in range(len(angoli)):
                a = angoli[i]
                dz = abs((zt_f(a) - zb_f(a)) * (livelli[j - 1][0] - livelli[j][0]))
                R[j][i] = max(R[j][i], R[j - 1][i] - drappo * dz)
        righe = []
        for j, (f, extra) in enumerate(livelli):
            riga = []
            for i, a in enumerate(angoli):
                z = zb_f(a) + (zt_f(a) - zb_f(a)) * f
                riga.append(self.centro(z) + self.dir(a) * (R[j][i] + st_f(z, a) + extra))
            righe.append(riga)
        righe.reverse()                                       # dal basso in alto
        vs = self.griglia(capo, parte, righe, colore, chiusa=chiusa, spessore=spessore, pesi=pesi,
                          fuori=lambda p: Vector((p.x, p.y - self.centro(p.z).y, 0)))
        return righe

    def arto(self, capo, parte, percorso, t0, t1, nv=10, na=20, stacco=0.015, colore=(1, 1, 1), spessore=0.0, rmax=0.16,
             livelli=None, pesi='corpo', drappo=0.6, rif=None):
        """Tubo attorno a un arto: percorso = lista di punti (assi delle ossa), t0..t1 frazione della lunghezza.
        stacco: m o funzione (t, ang) → m."""
        u = self.u
        lung = [0.0]
        for a, b in zip(percorso, percorso[1:]):
            lung.append(lung[-1] + (b - a).length)
        L = lung[-1]

        def punto(t):
            s = t * L
            for k in range(len(percorso) - 1):
                if s <= lung[k + 1] or k == len(percorso) - 2:
                    seg = (s - lung[k]) / max(1e-6, lung[k + 1] - lung[k])
                    return percorso[k].lerp(percorso[k + 1], seg), (percorso[k + 1] - percorso[k]).normalized()
        st_f = stacco if callable(stacco) else (lambda t, a, s=stacco: s)
        if livelli is None:
            livelli = [(t0 + (t1 - t0) * k / nv, 0.0) for k in range(nv + 1)]
        R, assi = [], []
        for t, _ in livelli:
            c, d = punto(t)
            r0 = rif or (AVANTI if abs(d.dot(AVANTI)) < 0.8 else SU)
            x = r0 - d * r0.dot(d)
            x.normalize()
            y = d.cross(x)
            assi.append((c, x, y))
            riga = []
            for i in range(na):
                ang = 2 * math.pi * i / na
                dd = x * math.cos(ang) + y * math.sin(ang)
                riga.append(self.raggio(c, dd, 0.02 * u, rmax * u))
            for _ in range(3):
                for i in range(na):
                    riga[i] = max(riga[i], (riga[i - 1] + riga[(i + 1) % na]) / 2 - 0.003 * u)
            R.append(riga)
        for j in range(1, len(R)):
            dt = abs(livelli[j][0] - livelli[j - 1][0]) * L
            for i in range(na):
                R[j][i] = max(R[j][i], R[j - 1][i] - drappo * dt)
        righe = []
        for j, (t, extra) in enumerate(livelli):
            c, x, y = assi[j]
            riga = []
            for i in range(na):
                ang = 2 * math.pi * i / na
                dd = x * math.cos(ang) + y * math.sin(ang)
                riga.append(c + dd * (R[j][i] + st_f(t, math.degrees(ang)) + extra))
            righe.append(riga)
        self.griglia(capo, parte, righe, colore, chiusa=True, spessore=spessore, pesi=pesi)
        return righe

    def striscia(self, capo, parte, punti, largo, stacco=0.01, spessore=0.006, colore=(1, 1, 1), pesi='corpo',
                 proietta=True, n=None, arco=0.0, chiusa=False, normali=None):
        """Nastro lungo una linea: se proietta, i punti sono portati a «stacco» dalla pelle (cinghie, stole, fasce).
        largo: m o lista per punto. normali: verso esterno per punto (di base: dal corpo)."""
        P = self._ricampiona(punti, n, chiusa) if n else [Vector(p) for p in punti]
        N = []
        for i, p in enumerate(P):
            if normali is not None:
                N.append(Vector(normali[i]).normalized())
            else:
                N.append(self.fuori(p))
        for _ in range(3):
            N = [(N[i - 1] + N[i] * 2 + N[(i + 1) % len(N)]).normalized() if (chiusa or 0 < i < len(N) - 1) else N[i] for i in range(len(N))]
        if proietta:
            Q = []
            for p, nn in zip(P, N):
                loc, _ = self.vicino(p)
                Q.append(loc + nn * stacco)
            for _ in range(2):
                Q = [(Q[i - 1] + Q[i] * 2 + Q[(i + 1) % len(Q)]) / 4 if (chiusa or 0 < i < len(Q) - 1) else Q[i] for i in range(len(Q))]
            for i, q in enumerate(Q):           # mai dentro la pelle
                loc, _ = self.vicino(q)
                if (q - loc).dot(N[i]) < stacco * 0.8:
                    Q[i] = loc + N[i] * stacco
            P = Q
        m = len(P)
        L = largo if isinstance(largo, (list, tuple)) else [largo] * m
        sx, dx, mid = [], [], []
        for i in range(m):
            t = (P[(i + 1) % m] - P[i - 1]) if (chiusa or 0 < i < m - 1) else (P[min(i + 1, m - 1)] - P[max(i - 1, 0)])
            lato = t.cross(N[i])
            if lato.length < 1e-8:
                lato = Vector((1, 0, 0))
            lato.normalize()
            sx.append(P[i] - lato * L[i] / 2)
            dx.append(P[i] + lato * L[i] / 2)
            mid.append(P[i] + N[i] * arco)
        righe = [[a, b, c] for a, b, c in zip(sx, mid, dx)]
        nn = {id(r): N[i] for i, r in enumerate(righe)}
        self.griglia(capo, parte, righe, colore, chiusa=False, spessore=spessore, pesi=pesi)
        if chiusa:
            self.griglia(capo, parte, [righe[-1], righe[0]], colore, spessore=spessore, pesi=pesi)
        return P, N

    @staticmethod
    def _ricampiona(punti, n, chiusa=False):
        pts = [Vector(p) for p in punti] + ([Vector(punti[0])] if chiusa else [])
        lung = [0.0]
        for a, b in zip(pts, pts[1:]):
            lung.append(lung[-1] + (b - a).length)
        L = lung[-1]
        out = []
        k = 0
        cnt = n if chiusa else n - 1
        for i in range(n):
            s = L * i / max(1, cnt)
            while k < len(pts) - 2 and lung[k + 1] < s:
                k += 1
            seg = (s - lung[k]) / max(1e-6, lung[k + 1] - lung[k])
            out.append(pts[k].lerp(pts[k + 1], _lim(seg, 0, 1)))
        return out

    def tubo(self, capo, parte, punti, raggio, colore=(1, 1, 1), lati=8, pesi='corpo', chiuso=False, n=None, tappi=True):
        """Tubo tondo lungo una linea (corde, bordi arrotondati, anelli). raggio: m o lista."""
        P = self._ricampiona(punti, n, chiuso) if n else [Vector(p) for p in punti]
        m = len(P)
        Rr = raggio if isinstance(raggio, (list, tuple)) else [raggio] * m
        righe = []
        prec = None
        for i in range(m):
            t = (P[(i + 1) % m] - P[i - 1]) if (chiuso or 0 < i < m - 1) else (P[min(i + 1, m - 1)] - P[max(i - 1, 0)])
            t.normalize()
            ref = prec if prec is not None else (SU if abs(t.dot(SU)) < 0.9 else Vector((1, 0, 0)))
            x = (ref - t * ref.dot(t)).normalized()
            prec = x
            y = t.cross(x)
            righe.append([P[i] + (x * math.cos(2 * math.pi * k / lati) + y * math.sin(2 * math.pi * k / lati)) * Rr[i] for k in range(lati)])
        if chiuso:
            righe.append(righe[0])
        assi = P + ([P[0]] if chiuso else [])

        def fuori(p):
            best = min(assi, key=lambda c: (c - p).length_squared)
            return p - best
        bm = self._bm(capo, parte, colore)
        vs = self.griglia(capo, parte, [list(reversed(r)) for r in righe], colore, chiusa=True, pesi=pesi, fuori=fuori)
        if tappi and not chiuso:
            for riga in (vs[0], vs[-1]):
                try:
                    bm.faces.new(riga)
                except ValueError:
                    pass

    def sfera(self, capo, parte, c, r, colore=(1, 1, 1), pesi='corpo', seg=(10, 6), scala=(1, 1, 1), rot=None):
        M = Matrix.Translation(c) @ (rot.to_4x4() if rot else Matrix.Identity(4)) @ Matrix.Diagonal((scala[0] * r, scala[1] * r, scala[2] * r, 1))
        self.mesh_primitiva(capo, parte, lambda bm: bmesh.ops.create_uvsphere(bm, u_segments=seg[0], v_segments=seg[1], radius=1.0),
                            colore, self._rigido(c) if pesi == 'corpo' else pesi, M)

    def gemma(self, capo, parte, c, r, normale, colore=(1, 1, 1), pesi='corpo', lati=6, alto=0.6):
        """Gemma sfaccettata (bipiramide schiacciata lungo la normale)."""
        n = Vector(normale).normalized()
        x = (SU - n * SU.dot(n)) if abs(n.dot(SU)) < 0.9 else Vector((1, 0, 0))
        x.normalize()
        y = n.cross(x)
        anello = [c + (x * math.cos(2 * math.pi * k / lati) + y * math.sin(2 * math.pi * k / lati)) * r for k in range(lati)]
        sopra = c + n * r * alto
        sotto = c - n * r * 0.25
        bm = self._bm(capo, parte, colore)
        spec = bm.verts.layers.int['spec']
        s = self._spec(self._rigido(c) if pesi == 'corpo' else pesi)
        vs = [bm.verts.new(p) for p in anello]
        a, b = bm.verts.new(sopra), bm.verts.new(sotto)
        for v in vs + [a, b]:
            v[spec] = s
        for k in range(lati):
            bm.faces.new((vs[k], vs[(k + 1) % lati], a))
            bm.faces.new((vs[(k + 1) % lati], vs[k], b))

    def borchia(self, capo, parte, c, r, normale, alto=0.4, colore=(1, 1, 1), pesi='corpo', lati=8):
        """Borchia: cupoletta bassa appoggiata su un piano di normale data."""
        n = Vector(normale).normalized()
        x = (SU - n * SU.dot(n)) if abs(n.dot(SU)) < 0.9 else Vector((1, 0, 0))
        x.normalize()
        y = n.cross(x)
        righe = []
        for k, (rr, h) in enumerate(((1.0, 0.0), (0.92, 0.45), (0.6, 0.85), (0.05, 1.0))):
            righe.append([c + (x * math.cos(2 * math.pi * i / lati) + y * math.sin(2 * math.pi * i / lati)) * r * rr + n * r * alto * h for i in range(lati)])
        self.griglia(capo, parte, righe, colore, chiusa=True, pesi=self._rigido(c) if pesi == 'corpo' else pesi, fuori=lambda p: p - c + n * 0.001)

    def lama(self, capo, parte, base, punta, largo, normale, spessore=0.006, colore=(1, 1, 1), pesi='corpo', n=7, forma=None):
        """Lamina affusolata con costola (lame da lancio, corna, alette, penne). forma(t) → larghezza relativa."""
        base, punta = Vector(base), Vector(punta)
        d = punta - base
        nn = Vector(normale).normalized()
        lato = d.cross(nn).normalized()
        forma = forma or (lambda t: (1 - t) ** 0.8)
        righe = []
        for k in range(n):
            t = k / (n - 1)
            c = base + d * t
            w = largo * forma(t) / 2 + 0.0015
            righe.append([c - lato * w, c + nn * spessore, c + lato * w])
        P = self._rigido(base) if pesi == 'corpo' else pesi
        self.griglia(capo, parte, righe, colore, pesi=P, fuori=lambda p: nn)
        righe2 = [[r[0], r[1] - nn * spessore * 2, r[2]] for r in righe]
        self.griglia(capo, parte, righe2, colore, pesi=P, fuori=lambda p: -nn)

    def _rigido(self, c):
        return self.pesi_in(Vector(c))

    # ------------------------------------------------------------------ pannelli
    def falde(self, capo, parte, centri, largo, z_top, lungo, apri=0.06, cols=7, file=1, dente=0.0, gioco=0.025,
              colore=(1, 1, 1), spessore=0.004, coscia=0.8, stinco=0.0, curva=0.0, orlo=None, fondo=None):
        """Pannelli appesi in vita (scarselle, falde della veste). centri: angoli; largo: ampiezza in gradi.
        Raggio: inviluppo del bacino e delle gambe + gioco, che si apre di «apri» m in fondo.
        coscia/stinco: peso massimo sull'osso della gamba del lato del pannello. orlo: (alto, parte, colore) di un bordo."""
        u = self.u
        z_fondo = z_top - lungo
        out = []
        for cen in centri:
            angoli = [cen - largo / 2 + largo * i / (cols - 1) for i in range(cols)]
            nr = max(2, int(round(lungo / (0.06 * u))))
            if file > 1:
                livelli = []
                for j in range(file):
                    livelli += [(j / file, 0.004 * u * j), ((j + 1) / file - 1e-4, dente + 0.004 * u * j)]
            else:
                livelli = [(k / nr, 0.0) for k in range(nr + 1)]
            base = []
            for a in angoli:
                r = 0.0
                z_giu = self.z_cavallo + 0.08 * u        # più in basso l'asse è fra le gambe, fuori dal corpo
                for k in range(6):                      # inviluppo del bacino dalla vita all'anca
                    z = z_top - (z_top - z_giu) * k / 5
                    r = max(r, self.raggio(self.centro(z), self.dir(a), 0.05 * u, 0.36 * u))
                base.append(r)
            base = _liscia(base, 2)
            righe = []
            for t, extra in livelli:
                z = z_top - lungo * t
                riga = []
                for i, a in enumerate(angoli):
                    r = base[i] + gioco + apri * t ** 1.3 + extra
                    if z < self.z_cavallo + 0.05 * u:
                        o = self.centro(min(z, self.z_cavallo))
                        gamba = self.uscita(o, self.dir(a), 0.45 * u)
                        r = max(r, gamba + gioco * 1.2 + extra)
                    c = self.centro(_lim(z, self.z_cavallo, 3.0))
                    riga.append(Vector((c.x, c.y, z)) + self.dir(a) * r)
                righe.append(riga)
            # niente rientri scendendo
            for j in range(1, len(righe)):
                for i in range(cols):
                    p, q = righe[j - 1][i], righe[j][i]
                    c = Vector((0, self.centro(_lim(q.z, self.z_cavallo, 3.0)).y, 0))
                    rp = Vector((p.x, p.y - c.y, 0)).length
                    rq = Vector((q.x, q.y - c.y, 0)).length
                    if rq < rp - 0.02 * u * (abs(p.z - q.z) / (0.045 * u)) * 0.3:
                        dd = Vector((q.x, q.y - c.y, 0)).normalized()
                        righe[j][i] = Vector((c.x, c.y, q.z)) + dd * (rp - 0.002 * u)
            lato = 'L' if math.cos(math.radians(cen)) > 0 else 'R'
            z0, zg = z_top, self.z_ginocchio

            def pesi(co, lato=lato, z0=z0, zg=zg):
                t = _lim((z0 - co.z) / max(1e-3, z0 - self.z_cavallo + 0.15 * u), 0, 1)
                w = coscia * t
                s = stinco * _lim((zg - co.z) / (0.2 * u), 0, 1)
                return {'hips': max(0.0, 1 - w - s), 'thigh_' + lato: w, 'shin_' + lato: s} if s > 0 else {'hips': 1 - w, 'thigh_' + lato: w}
            righe.reverse()
            self.griglia(capo, parte, righe, colore, spessore=spessore, pesi=pesi,
                         fuori=lambda p: Vector((p.x, p.y - self.centro(_lim(p.z, self.z_cavallo, 3.0)).y, 0)))
            if orlo:
                alto, p2, col2 = orlo
                fondo_r = righe[0]
                su = [q + Vector((0, 0, alto)) for q in fondo_r]
                fuori = [Vector((q.x, q.y - self.centro(_lim(q.z, self.z_cavallo, 3.0)).y, 0)).normalized() * 0.004 * u for q in fondo_r]
                self.griglia(capo, p2, [[q + f for q, f in zip(fondo_r, fuori)], [q + f for q, f in zip(su, fuori)]], col2,
                             spessore=spessore * 1.5, pesi=pesi,
                             fuori=lambda p: Vector((p.x, p.y - self.centro(_lim(p.z, self.z_cavallo, 3.0)).y, 0)))
            out.append(righe)
        return out

    def spallaccio(self, capo, parte, lato, file=3, lungo=0.5, stacco=0.03, dente=0.014, apertura=170, colore=(1, 1, 1),
                   orlo=None, inizio=-0.18, gonfia=0.0, spessore=0.006, cols=13):
        """Spallaccio a file di piastre sopra il braccio (in posa a T il braccio è orizzontale).
        Ritorna (p0, d, su, lato, raggio, pesi) per aggiungere calotte, ali, borchie."""
        u = self.u
        s = lato
        ua = self.B['upper_arm_' + s]
        p0 = ua.head_local.copy()
        d = (ua.tail_local - ua.head_local).normalized()
        av = d.cross(SU).normalized()
        su = av.cross(d).normalized()
        if su.z < 0:
            su = -su
        hit = self.bvh.ray_cast(p0 + d * ua.length * 0.3 + su * 2, -su)[0]
        rad = _lim((hit - (p0 + d * ua.length * 0.3)).dot(su) if hit else 0.07 * u, 0.045 * u, 0.12 * u)
        a0 = inizio * ua.length
        passo = (lungo * ua.length - a0) / file

        def pesi(co, s=s, p0=p0, d=d, ua=ua):
            t = _lim((co - p0).dot(d) / (ua.length * 0.55), 0, 1)
            return {'upper_arm_' + s: 0.5 + 0.4 * t, 'shoulder_' + s: 0.5 - 0.4 * t}
        righe = []
        for j in range(file):
            for a, extra in ((a0 + j * passo, 0.0), (a0 + (j + 1) * passo, dente)):
                r = rad + stacco + 0.007 * u * j + extra + gonfia * (j / max(1, file - 1))
                riga = []
                for i in range(cols):
                    phi = math.radians(-apertura / 2 + apertura * i / (cols - 1))
                    riga.append(p0 + d * a + (su * math.cos(phi) + av * math.sin(phi)) * r)
                righe.append(riga)
        fuori = lambda p, p0=p0, d=d: p - (p0 + d * (p - p0).dot(d))
        self.griglia(capo, parte, righe, colore, spessore=spessore, pesi=pesi, fuori=fuori)
        if orlo:
            alto, p2, col2 = orlo
            ult = righe[-1]
            self.griglia(capo, p2, [[q + fuori(q).normalized() * 0.003 * u for q in ult],
                                    [q + d * alto + fuori(q).normalized() * 0.008 * u for q in ult]], col2, spessore=spessore,
                         pesi=pesi, fuori=fuori)
        return p0, d, su, av, rad, pesi, righe

    # ------------------------------------------------------------------ uscita
    def oggetti(self):
        """Un oggetto per (capo, parte): capo_<capo>__<parte>, legato allo scheletro, con i pesi e il materiale."""
        fatti = []
        for (capo, parte), bm in self.parti.items():
            nome = f'capo_{capo}__{parte}'
            spec = bm.verts.layers.int['spec']
            bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.0004)
            # lo spessore (solidify) su facce quasi piegate a metà può lanciare un vertice lontanissimo: lo si riporta fra i vicini
            lontani = {v for v in bm.verts if (v.co - self.vicino(v.co)[0]).length > 0.7 * self.u}
            for v in lontani:
                vic = [e.other_vert(v).co for e in v.link_edges if e.other_vert(v) not in lontani]
                if vic:
                    v.co = sum(vic, Vector()) / len(vic)
            bm.verts.ensure_lookup_table()
            specs = [v[spec] for v in bm.verts]
            me = bpy.data.meshes.new(nome)
            bm.to_mesh(me)
            ob = bpy.data.objects.new(nome, me)
            bpy.context.scene.collection.objects.link(ob)
            gruppi = {}
            for i, v in enumerate(me.vertices):
                s = specs[i]
                if s == 0:
                    w = self.pesi_in(v.co)
                else:
                    S = self.specifiche[s - 1]
                    w = S(v.co) if callable(S) else S
                for b, x in w.items():
                    if x <= 0.001:
                        continue
                    g = gruppi.get(b)
                    if g is None:
                        g = gruppi[b] = ob.vertex_groups.new(name=b)
                    g.add([i], x, 'REPLACE')
            ob.parent = self.arm
            ob.modifiers.new('Armature', 'ARMATURE').object = self.arm
            mat = bpy.data.materials.new(nome)
            mat.use_nodes = True
            bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
            col = self.colori[(capo, parte)]
            bsdf.inputs['Base Color'].default_value = (*col, 1)
            # lamelle: lacca su ferro (poco metallica, altrimenti il cielo le tinge di azzurro)
            bsdf.inputs['Metallic'].default_value = {'bordo': 0.75, 'piastre': 0.5, 'lamelle': 0.22}.get(parte, 0.0)
            bsdf.inputs['Roughness'].default_value = {'bordo': 0.3, 'piastre': 0.4, 'lamelle': 0.42, 'grani': 0.45, 'gemma': 0.15, 'cuoio': 0.7}.get(parte, 0.9)
            if parte == 'gemma':
                bsdf.inputs['Emission Color'].default_value = (*col, 1)
                bsdf.inputs['Emission Strength'].default_value = 2.0
            me.materials.append(mat)
            for p in me.polygons:
                p.use_smooth = True
            if parte in ('piastre', 'lamelle', 'bordo', 'gemma'):
                try:
                    me.set_sharp_from_angle(angle=math.radians(50))      # spigoli vivi solo sui pezzi duri
                except Exception:
                    pass
            bm.free()
            fatti.append(capo)
        self.bm.free()
        return sorted(set(fatti))


# ====================================================================== disegno delle classi
def _croce_v(a, fondo, centro=-90, largo=70):
    """Profilo dello scollo a V: 1 al centro davanti, 0 oltre «largo» gradi."""
    d = abs(((a - centro) + 180) % 360 - 180)
    t = max(0.0, 1 - d / largo)
    return fondo * t * t * (3 - 2 * t) ** 0.6


def _giromanica(a, fondo, esp=6):
    """Abbassamento dell'orlo superiore ai lati (giromanica), morbido."""
    return fondo * abs(math.cos(math.radians(a))) ** esp


# ---------------------------------------------------------------------- pezzi comuni
def _ang(S, co):
    c = S.centro(_lim(co.z, S.z_cavallo, S.z_collo))
    return math.degrees(math.atan2(co.y - c.y, co.x - c.x))


def veste_busto(S, C, parte, colore, z_orlo, scollo=0.18, scollo_c=-100, scollo_l=60, alto=0.0, spalla=0.80, stacco=0.018,
                maniche=None, bordo=None, collo=None, spessore=0.0, liscia=6):
    """Veste dal collo a z_orlo, senza maniche (giromanica a |x| < spalla × spalla del corpo) o con maniche fino a
    «maniche» (frazione dell'avambraccio, 0 = gomito). scollo: profondità della V (in u), collo: (largo, parte, colore) della fascia
    sullo scollo (colletto incrociato). Ritorna gli orli."""
    u = S.u
    xs = S.B['upper_arm_L'].head_local.x
    zc, za = S.z_collo, S.z_ascella

    def campo(co):
        a = _ang(S, co)
        f = min(co.z - z_orlo, (zc + alto * u - _croce_v(a, scollo * u, scollo_c, scollo_l)) - co.z)
        if maniche is None:
            f = min(f, max(spalla * xs - abs(co.x), (za - 0.03 * u) - co.z))
        else:
            fa = S.B['forearm_L']
            lim = fa.head_local.x + (fa.tail_local.x - fa.head_local.x) * maniche
            f = min(f, lim - abs(co.x))
        return f
    orli = S.guscio(C, parte, campo, stacco * u, colore, spessore=spessore, seme=(0, -0.3, (z_orlo + zc) / 2), bordo=bordo, liscia=liscia)
    if collo and orli:
        largo, p2, c2 = collo
        sc = max(orli, key=lambda o: sum(p.z for p in o) / len(o))
        # solo lo scollo (davanti e dietro il collo), non i giromanica: tratti con |x| piccolo
        dentro = [abs(p.x) < 0.6 * xs and p.z > za for p in sc]
        k0 = dentro.index(False) if False in dentro else 0
        giro = sc[k0:] + sc[:k0]
        dd = dentro[k0:] + dentro[:k0]
        tratti, cur = [], []
        for p, d in zip(giro, dd):
            if d:
                cur.append(p)
            elif cur:
                tratti.append(cur)
                cur = []
        if cur:
            tratti.append(cur)
        for t in tratti:
            if len(t) >= 4:
                L = sum((b - a).length for a, b in zip(t, t[1:]))
                S.striscia(C, p2, t, largo * u, stacco=(stacco + 0.008) * u, spessore=0.006 * u, colore=c2,
                           n=max(6, int(L / (0.02 * u))))
    return orli


def pantaloni(S, C, parte, colore, z_fondo, largo=0.02, stacco=0.008, liscia=5, z_su=None):
    """Pantaloni dalla vita a z_fondo; largo: quanto si gonfiano attorno a coscia e ginocchio (in u)."""
    u = S.u
    zt = z_su if z_su is not None else S.z_vita + 0.02 * u
    zk, zh = S.z_ginocchio, S.z_cavallo
    xg = S.B['thigh_L'].head_local.x

    def st(co):
        t = _lim((co.z - z_fondo) / max(1e-3, zh - z_fondo), 0, 1)
        dentro = _lim(abs(co.x) / xg, 0.15, 1.0) ** 1.5           # fra le gambe la stoffa non si gonfia
        return (stacco + largo * dentro * math.sin(math.pi * t) ** 0.7) * u if co.z < zh + 0.05 * u else stacco * u
    return S.guscio(C, parte, lambda co: min(zt - co.z, co.z - z_fondo), st, colore, seme=(0, 0, S.z_cavallo + 0.05 * u), liscia=liscia)


def fasce_gamba(S, C, parte, colore, t0, t1, giri=7, stacco=0.016):
    """Fasce avvolte attorno allo stinco (t: frazione dello stinco)."""
    u = S.u
    for s in 'LR':
        a, b = S.ossa('shin_' + s)
        S.arto(C, parte, [a, b], t0, t1, na=18, colore=colore, stacco=stacco * u,
               livelli=[(t0 + (t1 - t0) * k / (2 * giri), 0.005 * u * (k % 2)) for k in range(2 * giri + 1)])


def fasce_braccio(S, C, parte, colore, t0, t1, giri=5, stacco=0.012, dente=0.005):
    u = S.u
    for s in 'LR':
        a, b = S.ossa('forearm_' + s)
        S.arto(C, parte, [a, b], t0, t1, na=16, colore=colore, stacco=stacco * u,
               livelli=[(t0 + (t1 - t0) * k / (2 * giri), dente * u * (k % 2)) for k in range(2 * giri + 1)])


def bracciale(S, C, parte, colore, t0, t1, stacco=0.02, spessore=0.006, file=1, dente=0.006, bordo=None):
    """Bracciale rigido sull'avambraccio (file > 1: a piastre sovrapposte). bordo: (parte, colore) degli anelli alle estremità."""
    u = S.u
    for s in 'LR':
        a, b = S.ossa('forearm_' + s)
        if file > 1:
            liv = []
            for j in range(file):
                liv += [(t0 + (t1 - t0) * j / file, 0.0), (t0 + (t1 - t0) * (j + 1) / file - 1e-3, dente * u)]
        else:
            liv = [(t0 + (t1 - t0) * k / 6, 0.0) for k in range(7)]
        S.arto(C, parte, [a, b], t0, t1, na=18, colore=colore, stacco=stacco * u, spessore=spessore * u, livelli=liv,
               pesi={'forearm_' + s: 1.0})
        if bordo:
            for t in (t0, t1):
                S.arto(C, bordo[0], [a, b], t - 0.025, t + 0.025, nv=2, na=18, colore=bordo[1], stacco=(stacco + 0.006) * u,
                       spessore=spessore * u, pesi={'forearm_' + s: 1.0})


def schiniere(S, C, parte, colore, t0, t1, stacco=0.022, spessore=0.006, file=1, dente=0.007, ginocchiera=None, bordo=None):
    """Schiniere sullo stinco; ginocchiera: raggio della cupola sul ginocchio (in u)."""
    u = S.u
    for s in 'LR':
        a, b = S.ossa('shin_' + s)
        if file > 1:
            liv = []
            for j in range(file):
                liv += [(t0 + (t1 - t0) * j / file, 0.0), (t0 + (t1 - t0) * (j + 1) / file - 1e-3, dente * u)]
        else:
            liv = [(t0 + (t1 - t0) * k / 6, 0.0) for k in range(7)]
        S.arto(C, parte, [a, b], t0, t1, na=18, colore=colore, stacco=stacco * u, spessore=spessore * u, livelli=liv,
               pesi={'shin_' + s: 1.0})
        if bordo:
            S.arto(C, bordo[0], [a, b], t0 - 0.02, t0 + 0.02, nv=2, na=18, colore=bordo[1], stacco=(stacco + 0.006) * u,
                   spessore=spessore * u, pesi={'shin_' + s: 1.0})
        if ginocchiera:
            k = a.copy()
            hit = S.bvh.ray_cast(k + Vector((0, -0.5, 0)), Vector((0, 1, 0)), 1.0)[0]
            if hit:
                c = hit + Vector((0, -0.012 * u, 0))
                r = ginocchiera * u
                S.sfera(C, parte, c, r, colore, pesi={'shin_' + s: 0.6, 'thigh_' + s: 0.4}, seg=(12, 8), scala=(1.0, 0.55, 1.15))
                if bordo:
                    S.borchia(C, bordo[0], c + Vector((0, -0.55 * r, 0)), r * 0.35, (0, -1, 0), colore=bordo[1],
                              pesi={'shin_' + s: 0.6, 'thigh_' + s: 0.4})


def cintura(S, C, parte, colore, z, alto=0.06, stacco=0.03, spessore=0.006, fibbia=None, gemma=None):
    """Cinturone in vita; fibbia: (parte, colore, raggio u) davanti; gemma: colore della pietra sulla fibbia."""
    u = S.u
    S.busto(C, parte, z - alto * u / 2, z + alto * u / 2, 0, 360, na=40, nv=2, stacco=stacco * u, colore=colore,
            spessore=spessore * u, drappo=0.0)
    if fibbia:
        p2, c2, r = fibbia
        c = S.centro(z)
        dist = S.raggio(c, Vector((0, -1, 0)), 0.03 * u, 0.4 * u) + (stacco + 0.012) * u
        cen = c + Vector((0, -dist, 0))
        _disco(S, C, p2, cen, r * u, (0, -1, 0), c2, spessore=0.012 * u, pesi={'hips': 0.6, 'spine': 0.4})
        if gemma:
            S.gemma(C, 'gemma', cen + Vector((0, -0.012 * u, 0)), r * 0.45 * u, (0, -1, 0), gemma, pesi={'hips': 0.6, 'spine': 0.4})


def _disco(S, C, parte, c, r, n, colore, spessore=0.01, pesi='corpo', lati=20, cupola=0.25, anelli=(1.0, 0.82, 0.55, 0.0)):
    """Disco bombato con bordo rialzato (fibbie, specchi da petto, medaglioni)."""
    c = Vector(c)
    n = Vector(n).normalized()
    x = (SU - n * SU.dot(n)) if abs(n.dot(SU)) < 0.9 else Vector((1, 0, 0))
    x.normalize()
    y = n.cross(x)
    prof = [(1.0, 0.0), (1.0, spessore), (0.86, spessore * 1.2), (0.78, spessore * 0.8), (0.5, spessore * (1 + cupola * 2)), (0.02, spessore * (1 + cupola * 3))]
    righe = [[c + (x * math.cos(2 * math.pi * i / lati) + y * math.sin(2 * math.pi * i / lati)) * r * rr + n * h for i in range(lati)] for rr, h in prof]
    P = S._rigido(c) if pesi == 'corpo' else pesi
    S.griglia(C, parte, righe, colore, chiusa=True, pesi=P, fuori=lambda p: n)


def spallacci(S, C, parte, colore, file, lungo, stacco=0.03, dente=0.014, apertura=170, orlo=None, calotta=None,
              ala=None, borchie=None, gemma=None, spessore=0.006, gonfia=0.0, lati='LR', inizio=-0.18):
    """Coppia di spallacci; calotta: (scala, parte, colore) cupola sopra la spalla; ala: (scala, parte, colore) piastra
    che sale verso l'esterno; borchie: (parte, colore) una per fila; gemma: colore della pietra sulla calotta."""
    u = S.u
    for s in lati:
        p0, d, su, av, rad, pesi, righe = S.spallaccio(C, parte, s, file=file, lungo=lungo, stacco=stacco * u, dente=dente * u,
                                                       apertura=apertura, colore=colore, orlo=orlo, gonfia=gonfia * u,
                                                       spessore=spessore * u, inizio=inizio)
        if calotta:
            k, p2, c2 = calotta
            cen = p0 + d * 0.03 * u + su * (rad + stacco * u * 0.6)
            M = Matrix((d, av, su)).transposed().to_4x4()
            S.mesh_primitiva(C, p2, lambda bm: bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=1.0), c2,
                             {'shoulder_' + s: 0.55, 'upper_arm_' + s: 0.45},
                             Matrix.Translation(cen) @ M @ Matrix.Diagonal((0.13 * u * k, 0.12 * u * k, 0.075 * u * k, 1)))
            if gemma:
                S.gemma(C, 'gemma', cen + su * 0.075 * u * k, 0.03 * u * k, su, gemma, pesi={'shoulder_' + s: 0.55, 'upper_arm_' + s: 0.45})
        if ala:
            k, p2, c2 = ala
            base = p0 + su * (rad + 0.05 * u) + d * 0.02 * u
            for j, (al, an) in enumerate(((1.0, 0.0), (0.75, 0.6))):
                S.lama(C, p2, base - av * (0.03 - 0.06 * j) * u, base + (d * 0.22 * k + su * 0.26 * k * al - av * (0.06 - 0.12 * j) * k) * u,
                       0.12 * k * u * al, av if j == 0 else (av + d * 0.4), spessore=0.008 * u, colore=c2,
                       pesi={'shoulder_' + s: 0.6, 'upper_arm_' + s: 0.4}, forma=lambda t: (1 - t) ** 0.7 * (0.6 + 0.4 * math.sin(math.pi * min(1, t * 1.5))))
        if borchie:
            p2, c2 = borchie
            for j in range(file):
                riga = righe[2 * j]
                for i in (len(riga) // 2 - 3, len(riga) // 2, len(riga) // 2 + 3):
                    q = riga[i]
                    nn = (q - (p0 + d * (q - p0).dot(d))).normalized()
                    S.borchia(C, p2, q + nn * 0.004 * u + d * 0.03 * u, 0.012 * u, nn, colore=c2, pesi=pesi(q))


def corazza(S, C, parte, colore, z_fondo, z_cima=None, file=6, dente=0.016, stacco=0.035, scollo=0.10, giro=0.16, spessore=0.006,
            pesi='corpo', rmax=0.36):
    """Corazza del busto a file di lamelle (dente > 0) o liscia (file = 1), aperta sotto le ascelle."""
    u = S.u
    zt = z_cima if z_cima is not None else S.z_collo - 0.05 * u
    zb = z_fondo
    za = S.z_ascella

    def cima(a):
        return min(zt - _croce_v(a, scollo * u, -90, 70), zt - _giromanica(a, zt - za + giro * u * 0.5, 4))
    if file > 1:
        liv = []
        for j in range(file):
            liv += [(1 - j / file, 0.0), (1 - (j + 1) / file + 1e-3, dente * u)]
    else:
        liv = None
    return S.busto(C, parte, zb, cima, 0, 360, na=44, livelli=liv, nv=9, stacco=stacco * u, colore=colore, spessore=spessore * u,
                   pesi=pesi, rmax=rmax), cima


# ---------------------------------------------------------------------- classi
def lama(S, g):
    """Guerriero della spada: dalla tunica senza maniche alla corazza a piastre con spallacci enormi e mantello."""
    u = S.u
    C = f'lama_{g}'
    zv, zc, za = S.z_vita, S.z_collo, S.z_ascella
    if g == 'base':
        # veste corta senza maniche con colletto incrociato; pantaloni dritti con fasce di cuoio al polpaccio
        veste_busto(S, C, 'stoffa', (1, 1, 1), zv - 0.13 * u, scollo=0.17, collo=(0.045, 'fascia', (1, 1, 1)),
                    bordo=(0.006 * u, 'fascia', (1, 1, 1)))
        pantaloni(S, C, 'stoffa2', (1, 1, 1), S.z_caviglia + 0.10 * u, largo=0.018)
        fasce_gamba(S, C, 'cuoio', CUOIO, 0.55, 0.86, giri=6)
        return
    if g == 0:
        cintura(S, C, 'cuoio', CUOIO, zv - 0.07 * u, alto=0.07, stacco=0.03, fibbia=('bordo', BRONZO, 0.035))
        fasce_braccio(S, C, 'fascia', (1, 1, 1), 0.45, 0.92)
        return
    pal = {1: dict(cor=CUOIO_CHIARO, met=CUOIO_CHIARO, bor=BRONZO),
           2: dict(cor=(0.13, 0.025, 0.018), met=(0.16, 0.16, 0.17), bor=BRONZO),
           3: dict(cor=(0.11, 0.12, 0.14), met=(0.22, 0.23, 0.25), bor=ORO),
           4: dict(cor=(0.035, 0.035, 0.045), met=(0.07, 0.07, 0.085), bor=(0.95, 0.62, 0.18), gem=(1.0, 0.45, 0.08))}[g]
    pc = 'cuoio' if g == 1 else 'lamelle'
    pm = 'cuoio' if g == 1 else 'piastre'
    # corazza
    corazza(S, C, pc, pal['cor'], zv - 0.10 * u, file=1 if g == 1 else 3 + g, dente=0.010 + 0.002 * g, stacco=0.030 + 0.004 * g,
            scollo=0.12 if g < 3 else 0.06)
    # spallacci: crescono col grado
    spallacci(S, C, pc, pal['cor'], file=[0, 2, 3, 4, 5][g], lungo=[0, 0.38, 0.5, 0.62, 0.72][g], stacco=0.03 + 0.006 * g,
              dente=0.012 + 0.002 * g, apertura=150 + 8 * g, gonfia=0.01 * g,
              orlo=(0.024 * u, 'bordo', pal['bor']) if g >= 2 else None,
              calotta=(0.62 + 0.12 * (g - 3), 'piastre' if g < 4 else 'bordo', pal['met'] if g < 4 else pal['bor']) if g >= 3 else None,
              ala=(1.25, 'bordo', pal['bor']) if g >= 4 else None,
              borchie=('bordo', pal['bor']) if g in (1, 2) else None, gemma=pal.get('gem'))
    # cinturone e scarselle
    cintura(S, C, 'cuoio', CUOIO, zv - 0.08 * u, alto=0.07 + 0.01 * g, stacco=0.05 + 0.006 * g,
            fibbia=('bordo', pal['bor'], 0.04 + 0.01 * g), gemma=pal.get('gem'))
    S.falde(C, pc, [-90 + 360 / 6 * (k + 0.5) for k in range(6)] if g >= 2 else [-60, -120, 30, 150], 52 if g >= 2 else 50,
            zv - 0.09 * u, [0, 0.26, 0.32, 0.38, 0.44][g] * u, apri=0.03 * g * u, file=1 if g == 1 else 1 + g, dente=0.012 * u,
            gioco=0.05 * u, colore=pal['cor'], spessore=0.005 * u,
            orlo=(0.022 * u, 'bordo', pal['bor']) if g >= 3 else None)
    # braccia e gambe
    bracciale(S, C, pm, pal['met'], 0.35, 0.9, stacco=0.018, file=1 if g < 3 else 3, bordo=('bordo', pal['bor']) if g >= 2 else None)
    if g >= 2:
        schiniere(S, C, pm, pal['met'], 0.1, 0.62, stacco=0.034, file=1 if g < 3 else 3, ginocchiera=0.07 if g >= 3 else None,
                  bordo=('bordo', pal['bor']) if g >= 3 else None)
    # petto: specchio protettivo, gorgiera
    if g >= 3:
        zp = S.B['chest'].head_local.z + S.B['chest'].length * 0.42
        c = S.centro(zp)
        r = S.raggio(c, Vector((0, -1, 0)), 0.05 * u, 0.4 * u)
        cen = c + Vector((0, -(r + 0.065 * u), 0))
        _disco(S, C, 'piastre', cen, (0.055 + 0.008 * g) * u, (0, -1, 0.15), pal['met'], spessore=0.012 * u, pesi={'chest': 1.0})
        S.tubo(C, 'bordo', [cen + Vector((math.cos(2 * math.pi * i / 24), 0, math.sin(2 * math.pi * i / 24))) * (0.055 + 0.008 * g) * u for i in range(24)],
               0.011 * u, pal['bor'], chiuso=True, pesi={'chest': 1.0})
        if g >= 4:
            S.gemma(C, 'gemma', cen + Vector((0, -0.03 * u, 0.0)), 0.04 * u, (0, -1, 0.15), pal['gem'], pesi={'chest': 1.0})
        # gorgiera
        a, b = S.ossa('neck')
        S.arto(C, 'bordo' if g >= 4 else 'piastre', [a - (b - a) * 0.6, b], 0.0, 0.45, na=24, colore=pal['bor'] if g >= 4 else pal['met'],
               livelli=[(0.0, 0.0), (0.2, 0.004 * u), (0.45, 0.02 * u)], stacco=0.03 * u, spessore=0.006 * u, rmax=0.2,
               pesi={'chest': 0.6, 'neck': 0.4})
    # mantello corto alle spalle (leggendario)
    if g >= 4:
        mantello(S, C, 'regno', (1, 1, 1), S.z_cavallo + 0.02 * u, largo=110, stacco=0.075 * u, orlo=('bordo', pal['bor']))


def mantello(S, C, parte, colore, z_fondo, largo=100, stacco=0.06, orlo=None, cols=25):
    """Mantello appeso dietro le spalle fino a z_fondo; non rientra mai sotto il corpo che copre."""
    u = S.u
    zt = S.z_collo - 0.03 * u
    angoli = [90 - largo / 2 + largo * i / (cols - 1) for i in range(cols)]
    n = max(4, int((zt - z_fondo) / (0.05 * u)))
    inv = [0.0] * cols
    righe = []
    for k in range(n + 1):
        t = k / n
        z = zt - (zt - z_fondo) * t
        c = S.centro(_lim(z, S.z_cavallo, S.z_collo))
        riga = []
        for i, a in enumerate(angoli):
            r = S.raggio(c, S.dir(a), 0.04 * u, 0.32 * u)
            inv[i] = max(inv[i], r)
            rr = inv[i] + stacco + 0.05 * u * t ** 1.5 + 0.022 * u * t * (0.5 + 0.5 * math.cos(2 * math.pi * 4 * i / (cols - 1)))
            riga.append(Vector((c.x, c.y, z)) + S.dir(a) * rr)
        righe.append(riga)
    righe.reverse()
    pesi = lambda co: (lambda t: {'chest': 1 - t, 'spine_1': t * 0.6, 'spine': t * 0.4})(_lim((zt - co.z) / (zt - z_fondo), 0, 1))
    S.griglia(C, parte, righe, colore, spessore=0.006 * u, pesi=pesi)
    if orlo:
        f = righe[0]
        S.tubo(C, orlo[0], [q + Vector((0, 0.004 * u, 0)) for q in f], 0.009 * u, orlo[1], pesi=pesi)


def _sul_corpo(S, p, stacco):
    """Punto della pelle più vicino a p, spinto fuori di stacco."""
    loc, idx = S.vicino(Vector(p))
    return loc + S.bm.faces[idx].normal * stacco


def anello_collo(S, caduta, stacco, n=40, z0=None, dietro=0.0):
    """Linea attorno alla base del collo che scende davanti di «caduta» m (collane, sciarpe), già sulla pelle."""
    u = S.u
    zc = z0 if z0 is not None else S.z_collo - 0.01 * u
    a, b = S.ossa('neck')
    out = []
    for i in range(n):
        ang = -90 + 360 * i / n
        dav = max(0.0, -math.sin(math.radians(ang)))          # 1 davanti
        z = zc - caduta * dav ** 1.6 + dietro * max(0.0, math.sin(math.radians(ang)))
        guida = Vector((a.x, a.y, z)) + S.dir(ang) * (0.13 * u + 0.08 * u * dav)
        out.append(_sul_corpo(S, guida, stacco))
    return out


def collana(S, C, parte, colore, r, caduta, stacco=None, centro=None, alterna=None):
    """Grani lungo l'anello del collo. centro: (raggio, parte, colore) del grano grande davanti. alterna: (parte, colore) ogni 3."""
    u = S.u
    giro = anello_collo(S, caduta, stacco if stacco is not None else r * 1.1, n=80)
    L = sum((b - a).length for a, b in zip(giro, giro[1:] + giro[:1]))
    n = max(8, int(L / (2.15 * r)))
    pts = S._ricampiona(giro, n, chiusa=True)
    for i, p in enumerate(pts):
        if centro and i == 0:
            continue
        pp, cc = (alterna if alterna and i % 3 == 0 else (parte, colore))
        S.sfera(C, pp, p, r, cc, seg=(8, 6))
    if centro:
        R, p2, c2 = centro
        p = pts[0] + S.fuori(pts[0]) * (R - r) + Vector((0, 0, -R * 0.9))
        S.sfera(C, p2, p, R, c2, seg=(12, 8), scala=(1, 0.7, 1))
    return pts


def bandoliera(S, C, parte, colore, da_destra=True, largo=0.05, stacco=0.05, coltelli=None, n_col=3):
    """Cinghia a tracolla dalla spalla al fianco opposto, chiusa attorno al busto. coltelli: (parte, colore, gemma o None)."""
    u = S.u
    sg = -1 if da_destra else 1
    xs = S.B['upper_arm_L'].head_local.x
    zc, zv = S.z_collo, S.z_vita
    guida = [Vector((sg * 0.55 * xs, -0.3, zc - 0.03 * u)), Vector((sg * 0.1 * xs, -0.3, zc - 0.25 * u)),
             Vector((-sg * 0.45 * xs, -0.3, zv + 0.02 * u)), Vector((-sg * 0.8 * xs, 0.0, zv - 0.04 * u)),
             Vector((-sg * 0.45 * xs, 0.3, zv + 0.02 * u)), Vector((sg * 0.1 * xs, 0.3, zc - 0.25 * u)),
             Vector((sg * 0.55 * xs, 0.3, zc - 0.03 * u)), Vector((sg * 0.62 * xs, 0.0, zc + 0.02 * u))]
    pts = [_sul_corpo(S, g, stacco * u) for g in guida]
    P, N = S.striscia(C, parte, pts, largo * u, stacco=stacco * u, spessore=0.006 * u, colore=colore, n=48, chiusa=True)
    if coltelli:
        p2, c2, gem = coltelli
        for k in range(n_col):
            i = 4 + k * 3                                     # sul petto, scendendo verso il fianco
            p, nn = P[i], N[i]
            t = (P[i + 1] - P[i - 1]).normalized()
            lato = t.cross(nn).normalized()
            base = p + nn * 0.012 * u
            # lama di traverso sulla cinghia: impugnatura da un lato, punta dall'altro
            S.lama(C, p2, base, base + lato * 0.12 * u, 0.022 * u, nn, spessore=0.004 * u, colore=c2,
                   forma=lambda tt: (1 - tt) ** 0.6 if tt > 0.3 else 0.75)
            S.tubo(C, 'cuoio', [base - lato * 0.06 * u, base - lato * 0.005 * u], 0.009 * u, CUOIO, lati=6)
            if gem:
                S.gemma(C, 'gemma', base - lato * 0.065 * u + nn * 0.004 * u, 0.012 * u, nn, gem)
    return P, N


def nappa(S, C, parte, colore, attacco, lungo, r=0.02, cappuccio=None, pesi='corpo'):
    """Nappa appesa: cordino + fiocco a campana. cappuccio: (parte, colore) della ghiera."""
    u = S.u
    a = Vector(attacco)
    P = S._rigido(a) if pesi == 'corpo' else pesi
    S.tubo(C, parte, [a, a + Vector((0, 0, -lungo * 0.35))], r * 0.18, colore, lati=6, pesi=P)
    c = a + Vector((0, 0, -lungo * 0.35))
    righe = []
    for k, (rr, dz) in enumerate(((0.25, 0), (0.55, 0.12), (0.8, 0.45), (1.0, 1.0), (0.9, 1.04))):
        righe.append([c + Vector((math.cos(2 * math.pi * i / 10) * r * rr, math.sin(2 * math.pi * i / 10) * r * rr, -dz * lungo * 0.65)) for i in range(10)])
    S.griglia(C, parte, righe, colore, chiusa=True, pesi=P, fuori=lambda p: Vector((p.x - c.x, p.y - c.y, 0.01)))
    if cappuccio:
        S.sfera(C, cappuccio[0], c + Vector((0, 0, -0.01 * u)), r * 0.45, cappuccio[1], pesi=P, seg=(8, 5), scala=(1, 1, 0.8))


def aureola(S, C, parte, colore, R, dietro=0.14, z=None, spessore=0.012, raggi=0, gemme=None, grani=None, osso='chest'):
    """Anello sospeso dietro la schiena o la testa (pesato su un osso solo); raggi: lamine verso l'esterno; gemme: colore."""
    u = S.u
    zc = z if z is not None else S.z_collo + 0.03 * u
    hit = S.bvh.ray_cast(Vector((0, 3, zc - 0.15 * u)), Vector((0, -1, 0)))[0]
    yc = (hit.y if hit else 0.1 * u) + dietro * u
    P = {osso: 1.0}
    cen = Vector((0, yc, zc))
    giro = [cen + Vector((math.cos(2 * math.pi * i / 48), 0, math.sin(2 * math.pi * i / 48))) * R for i in range(48)]
    S.tubo(C, parte, giro, spessore * u, colore, chiuso=True, pesi=P)
    S.tubo(C, parte, [cen + (q - cen) * 0.82 for q in giro], spessore * 0.5 * u, colore, chiuso=True, pesi=P)
    for k in range(raggi):
        a = 2 * math.pi * (k + 0.5) / raggi
        d = Vector((math.cos(a), 0, math.sin(a)))
        S.lama(C, parte, cen + d * R * 0.98, cen + d * R * (1.32 if k % 2 == 0 else 1.18), 0.05 * u, (0, 1, 0), spessore=0.006 * u,
               colore=colore, pesi=P)
    if gemme:
        n = raggi or 8
        for k in range(n):
            a = 2 * math.pi * k / n
            S.gemma(C, 'gemma', cen + Vector((math.cos(a), 0, math.sin(a))) * R + Vector((0, -0.01 * u, 0)), 0.022 * u, (0, -1, 0), gemme, pesi=P)
    if grani:
        p2, c2, rg, n = grani
        for k in range(n):
            a = 2 * math.pi * (k + 0.25) / n
            S.sfera(C, p2, cen + Vector((math.cos(a), 0, math.sin(a))) * R * 0.91, rg * u, c2, pesi=P, seg=(10, 6))
    return cen


def ombra(S, g):
    """Assassino: stoffe scure aderenti, cuoio, una spalla sola corazzata, cinghie a croce con lame da lancio."""
    u = S.u
    C = f'ombra_{g}'
    zv, zc = S.z_vita, S.z_collo
    if g == 'base':
        veste_busto(S, C, 'stoffa', (1, 1, 1), zv - 0.17 * u, scollo=0.03, alto=0.03, spalla=0.74, collo=None,
                    bordo=(0.005 * u, 'fascia', (1, 1, 1)))
        pantaloni(S, C, 'stoffa2', (1, 1, 1), S.z_caviglia + 0.06 * u, largo=0.012)
        fasce_gamba(S, C, 'stoffa', (1, 1, 1), 0.5, 0.9, giri=7, stacco=0.012)
        fasce_braccio(S, C, 'stoffa2', (1, 1, 1), 0.3, 0.95, giri=7)
        return
    pal = {0: dict(cu=(0.05, 0.04, 0.045), me=ACCIAIO, bo=ARGENTO),
           1: dict(cu=(0.06, 0.045, 0.045), me=ACCIAIO, bo=ARGENTO),
           2: dict(cu=(0.055, 0.035, 0.04), me=(0.18, 0.19, 0.22), bo=ARGENTO),
           3: dict(cu=(0.045, 0.03, 0.035), me=(0.10, 0.10, 0.12), bo=(0.55, 0.55, 0.6)),
           4: dict(cu=(0.03, 0.022, 0.026), me=(0.05, 0.05, 0.06), bo=(0.75, 0.12, 0.12), gem=(1.0, 0.06, 0.12))}[g]
    gem = pal.get('gem')
    # sciarpa attorno al collo (il cappuccio abbassato)
    giro = anello_collo(S, 0.07 * u, 0.03 * u + 0.004 * u * g, n=40)
    S.striscia(C, 'fascia', giro, (0.075 + 0.008 * g) * u, proietta=False, spessore=0.006 * u, arco=0.018 * u, chiusa=True)
    S.tubo(C, 'fascia', [p + Vector((0, 0, 0.03 * u)) + S.fuori(p) * 0.012 * u for p in giro], 0.016 * u, (1, 1, 1), lati=8, chiuso=True)
    cintura(S, C, 'cuoio', pal['cu'], zv - 0.10 * u, alto=0.05, stacco=0.022)
    if g == 0:
        return
    # gilet di cuoio, a V profonda
    corazza(S, C, 'cuoio', pal['cu'], zv - 0.13 * u, file=1, stacco=0.026, scollo=0.20, giro=0.10, spessore=0.005)
    # uno spallaccio solo (sinistro), sempre più corazzato
    spallacci(S, C, 'cuoio' if g < 3 else 'piastre', pal['cu'] if g < 3 else pal['me'], file=1 + g, lungo=0.32 + 0.1 * g,
              stacco=0.03 + 0.004 * g, dente=0.014, apertura=150 + 6 * g, lati='L', gonfia=0.008 * g,
              orlo=(0.018 * u, 'bordo', pal['bo']) if g >= 3 else None,
              borchie=('bordo', pal['bo']) if g >= 2 else None,
              ala=(0.9, 'bordo', pal['bo']) if g >= 3 else None, gemma=gem,
              calotta=(0.7, 'piastre', pal['me']) if g >= 4 else None)
    bracciale(S, C, 'cuoio' if g < 3 else 'piastre', pal['cu'] if g < 3 else pal['me'], 0.35, 0.92, stacco=0.016,
              file=1 if g < 2 else 2, bordo=('bordo', pal['bo']) if g >= 2 else None)
    # cinghie con le lame da lancio
    bandoliera(S, C, 'cuoio', CUOIO_CHIARO if g < 3 else pal['cu'], da_destra=True, stacco=0.045,
               coltelli=('piastre', ARGENTO if g < 4 else pal['me'], gem), n_col=2 + min(g, 2))
    if g >= 2:
        bandoliera(S, C, 'cuoio', CUOIO_CHIARO if g < 3 else pal['cu'], da_destra=False, stacco=0.055,
                   coltelli=('piastre', ARGENTO if g < 4 else pal['me'], gem), n_col=2 + min(g - 1, 2))
        # falda di cuoio sul fianco sinistro e ginocchiere
        S.falde(C, 'cuoio', [10], 50, zv - 0.10 * u, 0.30 * u, apri=0.03 * u, file=2, dente=0.01 * u, gioco=0.04 * u,
                colore=pal['cu'], orlo=(0.016 * u, 'bordo', pal['bo']) if g >= 3 else None)
        schiniere(S, C, 'piastre', pal['me'], 0.02, 0.1, stacco=0.02, ginocchiera=0.042)
    if g >= 3:
        # coda della sciarpa che scende dietro
        a, b = S.ossa('neck')
        for k, sx in enumerate((-1, 1)):
            top = _sul_corpo(S, Vector((sx * 0.04 * u, a.y + 0.2, S.z_collo - 0.04 * u)), 0.07 * u)
            pts = [top + Vector((sx * 0.015 * u * t, 0.03 * u * t, -(0.45 + 0.12 * k + 0.12 * (g - 3)) * u * t)) for t in (i / 8 for i in range(9))]
            S.striscia(C, 'fascia', pts, 0.07 * u, proietta=False, spessore=0.004 * u, colore=(1, 1, 1),
                       normali=[Vector((0, 1, 0))] * 9,
                       pesi=lambda co, zt=top.z: (lambda t: {'chest': 1 - t, 'spine_1': t})(_lim((zt - co.z) / (0.4 * u), 0, 1)))
        # manica sinistra aderente sotto lo spallaccio, lame sugli avambracci
        a, b = S.ossa('upper_arm_L')
        S.arto(C, 'stoffa', [a, b], 0.12, 0.95, nv=8, na=16, stacco=0.012 * u, colore=(1, 1, 1))
        for s, sg in (('L', 1), ('R', -1)):
            a, b = S.ossa('forearm_' + s)
            d = (b - a).normalized()
            for k in range(2 if g == 3 else 3):
                base = a + d * (0.35 + 0.18 * k) * (b - a).length + Vector((0, 0.07 * u, 0.0))
                S.lama(C, 'piastre', base, base + d * 0.12 * u + Vector((0, 0.06 * u, 0)), 0.04 * u, Vector((0, 0, 1)), spessore=0.004 * u,
                       colore=ARGENTO if g < 4 else pal['bo'], pesi={'forearm_' + s: 1.0})
        # borse alla cintura
        for ang in (110, 135, 160):
            c = S.centro(zv - 0.14 * u)
            r = S.raggio(c, S.dir(ang), 0.05 * u, 0.4 * u)
            p = c + S.dir(ang) * (r + 0.05 * u)
            S.sfera(C, 'cuoio', p, 0.04 * u, pal['cu'], scala=(1.0, 0.7, 1.15), rot=Matrix.Rotation(math.radians(ang), 3, 'Z'))
    if g >= 4:
        # mezza maschera sul viso e ventaglio di lame dietro le spalle
        h0, h1 = S.ossa('head')
        zmax = h0.z + 0.10 * u
        S.guscio(C, 'stoffa2', lambda co: min(zmax - co.z, co.z - (S.z_collo + 0.0 * u), (h0.y + 0.03 * u) - co.y, 0.12 * u - abs(co.x)),
                 0.012 * u, (1, 1, 1), seme=(0, -0.5, zmax - 0.04 * u), bordo=(0.004 * u, 'fascia', (1, 1, 1)), liscia=4)
        hit = S.bvh.ray_cast(Vector((0, 3, S.z_ascella)), Vector((0, -1, 0)))[0]
        cen = Vector((0, (hit.y if hit else 0.15) + 0.07 * u, S.z_ascella + 0.02 * u))
        for k in range(5):
            a = math.radians(90 + (k - 2) * 24)
            d = Vector((math.cos(a), 0.15, math.sin(a))).normalized()
            S.lama(C, 'piastre', cen + d * 0.06 * u, cen + d * 0.30 * u, 0.075 * u, (0, 1, 0), spessore=0.006 * u, colore=pal['me'],
                   pesi={'chest': 1.0})
            S.lama(C, 'bordo', cen + d * 0.05 * u + Vector((0, 0.006 * u, 0)), cen + d * 0.2 * u + Vector((0, 0.006 * u, 0)), 0.03 * u, (0, 1, 0),
                   spessore=0.004 * u, colore=pal['bo'], pesi={'chest': 1.0})
        S.gemma(C, 'gemma', cen + Vector((0, 0.02 * u, 0)), 0.035 * u, (0, 1, 0), gem, pesi={'chest': 1.0})


def monaco(S, g):
    """Monaco guerriero: busto nudo, pantaloni larghi raccolti sotto il ginocchio, grani, fasce, oro e giada."""
    u = S.u
    C = f'monaco_{g}'
    zv, zc = S.z_vita, S.z_collo
    GIADA = (0.06, 0.40, 0.24)
    LEGNO = (0.16, 0.08, 0.035)
    if g == 'base':
        pantaloni(S, C, 'stoffa', (1, 1, 1), S.z_ginocchio - 0.13 * u, largo=0.055, stacco=0.012)
        fasce_gamba(S, C, 'fascia', (1, 1, 1), 0.26, 0.88, giri=6, stacco=0.016)
        if S.donna:
            # fascia di stoffa avvolta al petto (sarashi): copre il seno, lascia scoperti braccia, spalle e ventre
            zp = S.z_vita + 0.10 * u
            xs = S.B['upper_arm_L'].head_local.x
            S.guscio(C, 'stoffa2', lambda co: min(co.z - zp, (S.z_ascella + 0.05 * u) - co.z, 0.85 * xs - abs(co.x)), 0.02 * u,
                     (1, 1, 1), seme=(0, -0.5, zp + 0.08 * u), liscia=12, bordo=(0.006 * u, 'fascia', (1, 1, 1)))
        # fascia alta in vita con il nodo e i due lembi davanti
        S.busto(C, 'stoffa2', zv - 0.12 * u, zv + 0.02 * u, 0, 360, na=40, nv=4, stacco=0.035 * u, colore=(1, 1, 1),
                spessore=0.006 * u, drappo=0.0)
        c = S.centro(zv - 0.06 * u)
        ang = -60
        r = S.raggio(c, S.dir(ang), 0.05 * u, 0.4 * u) + 0.05 * u
        nodo = c + S.dir(ang) * r
        S.sfera(C, 'stoffa2', nodo, 0.035 * u, (1, 1, 1), scala=(1.2, 0.8, 1.0))
        for k, dx in enumerate((-0.03, 0.035)):
            pts = [nodo + Vector((dx * u * t * 2, -0.02 * u * t, -(0.02 + (0.30 + 0.06 * k) * t) * u)) for t in (i / 7 for i in range(8))]
            S.striscia(C, 'stoffa2', pts, 0.06 * u, proietta=False, spessore=0.004 * u, normali=[S.dir(ang)] * 8,
                       pesi=lambda co, ang=ang: (lambda t: {'hips': 1 - t * 0.6, 'thigh_L': t * 0.6})(_lim((S.z_vita - co.z) / (0.4 * u), 0, 1)))
        return
    bor = BRONZO if g < 3 else ORO
    gem = (0.25, 1.0, 0.55) if g >= 3 else None
    fasce_braccio(S, C, 'fascia', (1, 1, 1), 0.5 if g >= 2 else 0.35, 0.95, giri=5)
    if g == 0:
        collana(S, C, 'grani', LEGNO, 0.011 * u, 0.12 * u)
        return
    # collana di grani grossi
    collana(S, C, 'grani', LEGNO, (0.018 + 0.003 * g) * u, (0.16 + 0.02 * g) * u,
            centro=((0.03 + 0.005 * g) * u, 'piastre', GIADA) if g >= 2 else None,
            alterna=('bordo', ORO) if g >= 3 else None)
    if gem and g >= 4:
        giro = anello_collo(S, (0.16 + 0.02 * g) * u, 0.03 * u, n=80)
        S.gemma(C, 'gemma', giro[0] + S.fuori(giro[0]) * 0.03 * u + Vector((0, 0, -0.045 * u)), 0.022 * u, S.fuori(giro[0]), gem)
    # fascia a tracolla dalla spalla sinistra al fianco destro
    xs = S.B['upper_arm_L'].head_local.x
    guida = [Vector((0.6 * xs, -0.3, zc - 0.02 * u)), Vector((0.1 * xs, -0.3, zc - 0.3 * u)), Vector((-0.6 * xs, -0.3, zv - 0.02 * u)),
             Vector((-0.85 * xs, 0.0, zv - 0.05 * u)), Vector((-0.6 * xs, 0.3, zv - 0.02 * u)), Vector((0.1 * xs, 0.3, zc - 0.3 * u)),
             Vector((0.6 * xs, 0.3, zc - 0.02 * u)), Vector((0.7 * xs, 0.0, zc + 0.03 * u))]
    pts = [_sul_corpo(S, q, 0.02 * u) for q in guida]
    P, N = S.striscia(C, 'stoffa', pts, (0.08 + 0.01 * g) * u, stacco=0.02 * u, spessore=0.005 * u, n=60, chiusa=True, arco=0.01 * u)
    if g >= 3:
        for sgn in (-1, 1):
            orlo = []
            for i in range(len(P)):
                t = (P[(i + 1) % len(P)] - P[i - 1]).normalized()
                orlo.append(P[i] + t.cross(N[i]).normalized() * sgn * (0.04 + 0.005 * g) * u + N[i] * 0.004 * u)
            S.tubo(C, 'bordo', orlo, 0.006 * u, ORO, chiuso=True)
    # cordone sopra la fascia, con le nappe
    c0 = S.centro(zv - 0.05 * u)
    giro = []
    for i in range(48):
        a = 360 * i / 48
        giro.append(c0 + S.dir(a) * (S.raggio(c0, S.dir(a), 0.05 * u, 0.4 * u) + 0.06 * u))
    S.tubo(C, 'regno', giro, 0.012 * u, (1, 1, 1), chiuso=True, lati=6)
    for a in (-75, -105):
        c = S.centro(zv - 0.05 * u)
        p = c + S.dir(a) * (S.raggio(c, S.dir(a), 0.05 * u, 0.4 * u) + 0.075 * u)
        nappa(S, C, 'regno', (1, 1, 1), p, (0.22 + 0.03 * g) * u, r=(0.025 + 0.004 * g) * u, cappuccio=('bordo', bor) if g >= 2 else None,
              pesi={'hips': 1.0})
    if g >= 2:
        bracciale(S, C, 'bordo', bor, 0.42, 0.88, stacco=0.03, spessore=0.007, file=1 if g < 4 else 2,
                  bordo=('piastre', GIADA) if g >= 3 else None)
        schiniere(S, C, 'bordo', bor, 0.72, 0.9, stacco=0.035, ginocchiera=None)
        if gem:
            for s in 'LR':
                a, b = S.ossa('forearm_' + s)
                p = a.lerp(b, 0.65)
                hit = S.bvh.ray_cast(p + Vector((0, -0.4, 0)), Vector((0, 1, 0)), 1.0)[0]
                if hit:
                    S.gemma(C, 'gemma', hit + Vector((0, -0.04 * u, 0)), 0.02 * u, (0, -1, 0), gem, pesi={'forearm_' + s: 1.0})
    if g >= 3:
        # spallaccio d'oro sulla spalla sinistra, sopra la tracolla
        spallacci(S, C, 'bordo', ORO, file=2 if g == 3 else 3, lungo=0.40 + 0.08 * (g - 3), stacco=0.05, dente=0.012, apertura=140,
                  lati='L', orlo=(0.016 * u, 'piastre', GIADA), gemma=gem, calotta=(0.65, 'piastre', GIADA))
    if g >= 4:
        for s in 'LR':
            a, b = S.ossa('upper_arm_' + s)
            S.arto(C, 'bordo', [a, b], 0.58, 0.66, nv=2, na=18, colore=ORO, stacco=0.012 * u, spessore=0.005 * u, pesi={'upper_arm_' + s: 1.0})
        aureola(S, C, 'bordo', ORO, 0.32 * u, dietro=0.16, z=S.z_ascella + 0.05 * u, spessore=0.014, gemme=gem, grani=('piastre', GIADA, 0.026, 8))


def mistico(S, g):
    """Mago e guaritore: veste lunga a falde, maniche a campana, colletto alto, stola con talismani, ornamenti sospesi."""
    u = S.u
    C = f'mistico_{g}'
    zv, zc = S.z_vita, S.z_collo
    CARTA = (0.80, 0.70, 0.45)
    GIADA = (0.10, 0.45, 0.32)
    z_polp = S.z_caviglia + (S.z_ginocchio - S.z_caviglia) * 0.40
    if g == 'base':
        veste_busto(S, C, 'stoffa', (1, 1, 1), zv - 0.10 * u, scollo=0.15, maniche=0.15, collo=(0.05, 'fascia', (1, 1, 1)), stacco=0.016)
        for s in 'LR':
            a, b = S.ossa('forearm_' + s)
            S.arto(C, 'stoffa', [a, b], 0.05, 0.85, nv=9, na=20, colore=(1, 1, 1), spessore=0.004 * u,
                   stacco=lambda t, ang: (0.02 + 0.09 * _lim((t - 0.1) / 0.75, 0, 1) ** 1.5) * u, rmax=0.12, drappo=0.0)
            S.arto(C, 'fascia', [a, b], 0.80, 0.86, nv=2, na=20, colore=(1, 1, 1), spessore=0.004 * u, stacco=0.107 * u, rmax=0.12, drappo=0.0)
        pantaloni(S, C, 'stoffa2', (1, 1, 1), S.z_caviglia + 0.05 * u, largo=0.015)
        centri = [-112.5, -67.5, -22.5, 22.5, 67.5, 112.5, 157.5, -157.5]
        S.falde(C, 'stoffa', centri, 44, zv - 0.06 * u, zv - 0.06 * u - z_polp, apri=0.07 * u, cols=7, gioco=0.03 * u, colore=(1, 1, 1),
                spessore=0.004 * u, coscia=0.7, orlo=(0.03 * u, 'fascia', (1, 1, 1)))
        return
    bor = BRONZO if g < 3 else ORO
    gem = (0.35, 0.75, 1.0) if g >= 3 else None
    # fascia in vita
    cintura(S, C, 'fascia', (1, 1, 1), zv - 0.06 * u, alto=0.09, stacco=0.05, spessore=0.005)
    if g == 0:
        return
    # colletto alto
    a, b = S.ossa('neck')
    S.arto(C, 'fascia', [a - (b - a) * 0.5, b], 0.0, 0.5 + 0.05 * g, na=24, colore=(1, 1, 1),
           livelli=[(0.0, 0.0), (0.25, 0.006 * u), (0.5 + 0.05 * g, 0.008 * u * g)], stacco=0.02 * u, spessore=0.005 * u, rmax=0.2,
           pesi={'chest': 0.5, 'neck': 0.5})
    if g >= 3:
        S.arto(C, 'bordo', [a - (b - a) * 0.5, b], 0.5 + 0.05 * g, 0.52 + 0.05 * g, nv=1, na=24, colore=ORO,
               stacco=0.03 * u + 0.012 * u * g + 0.004 * u, spessore=0.006 * u, rmax=0.2, pesi={'chest': 0.5, 'neck': 0.5})
    # stola: dalla nuca sulle spalle, giù davanti fino alle ginocchia, con i talismani in fondo
    xs = S.B['upper_arm_L'].head_local.x
    lungo_stola = S.z_ginocchio + 0.05 * u - 0.06 * u * g
    for sx in (-1, 1):
        sup = [_sul_corpo(S, q, 0.05 * u) for q in (Vector((0, 0.3, zc - 0.03 * u)), Vector((sx * 0.25 * xs, 0.2, zc + 0.01 * u)),
                                                     Vector((sx * 0.38 * xs, 0.0, zc + 0.0 * u)), Vector((sx * 0.4 * xs, -0.3, zc - 0.12 * u)),
                                                     Vector((sx * 0.42 * xs, -0.3, zc - 0.32 * u)), Vector((sx * 0.42 * xs, -0.3, zv + 0.04 * u)))]
        ult = sup[-1]
        c = S.centro(zv - 0.1 * u)
        avanti = S.raggio(c, S.dir(-90 + sx * 25), 0.05 * u, 0.4 * u) + 0.10 * u
        giu = [Vector((ult.x, min(ult.y, c.y - avanti), z)) for z in (zv - 0.12 * u, zv - 0.3 * u, lungo_stola + 0.1 * u, lungo_stola)]
        pts = sup + giu
        N = [S.fuori(p) for p in sup] + [Vector((0, -1, 0))] * len(giu)
        pes = lambda co: S.pesi_in(co) if co.z > zv - 0.1 * u else {'hips': 0.6, 'thigh_L' if co.x > 0 else 'thigh_R': 0.4}
        S.striscia(C, 'fascia', pts, (0.07 + 0.008 * g) * u, proietta=False, spessore=0.005 * u, colore=(1, 1, 1),
                   normali=N, pesi=pes)
        fondo = Vector((ult.x, min(ult.y, c.y - avanti) - 0.008 * u, lungo_stola))
        # talismano di carta appeso
        t0 = fondo + Vector((0, 0, -0.01 * u))
        S.griglia(C, 'carta', [[t0 + Vector((-0.03 * u, 0, -z)), t0 + Vector((0.03 * u, 0, -z))] for z in (0, 0.07 * u, 0.14 * u)], CARTA,
                  pesi={'hips': 0.6, 'thigh_L' if sx > 0 else 'thigh_R': 0.4}, fuori=lambda p: Vector((0, -1, 0)))
        if g >= 3:
            S.gemma(C, 'gemma', fondo + Vector((0, -0.01 * u, 0.02 * u)), 0.02 * u, (0, -1, 0), gem,
                    pesi={'hips': 0.6, 'thigh_L' if sx > 0 else 'thigh_R': 0.4})
    if g >= 2:
        # mantellina sulle spalle con l'orlo d'oro
        za = S.z_ascella
        def orlo_m(co):
            dav = max(0.0, -math.sin(math.radians(_ang(S, co))))       # davanti resta sopra il petto
            return za + 0.01 * u + 0.12 * u * dav - 0.025 * u * g * (1 - dav)
        S.guscio(C, 'regno', lambda co: min(co.z - orlo_m(co), (xs * (1.15 + 0.08 * g)) - abs(co.x), (zc + 0.015 * u) - co.z),
                 lambda co: (0.05 + 0.008 * g) * u, (1, 1, 1), seme=(0, 0.5, za + 0.12 * u), liscia=16,
                 bordo=(0.008 * u, 'bordo', bor))
        # talismani alla cintura
        for a in (-20, 20, 160, 200) if g == 2 else (-20, 20, 45, 135, 160, 200):
            c = S.centro(zv - 0.06 * u)
            p = c + S.dir(a) * (S.raggio(c, S.dir(a), 0.05 * u, 0.4 * u) + 0.06 * u)
            d = S.dir(a)
            lat = Vector((-d.y, d.x, 0))
            S.griglia(C, 'carta', [[p + lat * -0.025 * u + Vector((0, 0, -z)), p + lat * 0.025 * u + Vector((0, 0, -z))] for z in (0.02 * u, 0.1 * u, 0.17 * u)],
                      CARTA, pesi={'hips': 0.7, 'thigh_L' if d.x > 0 else 'thigh_R': 0.3}, fuori=lambda q, d=d: d)
    if g >= 3:
        spallacci(S, C, 'piastre', GIADA, file=2, lungo=0.30 + 0.06 * (g - 3), stacco=0.085 + 0.01 * g, dente=0.01, apertura=130,
                  orlo=(0.014 * u, 'bordo', ORO), calotta=(0.55, 'bordo', ORO), gemma=gem)
        zp = S.B['chest'].head_local.z + S.B['chest'].length * 0.3
        c = S.centro(zp)
        cen = c + Vector((0, -(S.raggio(c, Vector((0, -1, 0)), 0.05 * u, 0.4 * u) + 0.03 * u), 0))
        _disco(S, C, 'bordo', cen, 0.045 * u, (0, -1, 0.1), ORO, spessore=0.01 * u, pesi={'chest': 1.0})
        S.gemma(C, 'gemma', cen + Vector((0, -0.022 * u, 0)), 0.026 * u, (0, -1, 0.1), gem, pesi={'chest': 1.0})
        for s in 'LR':
            a, b = S.ossa('forearm_' + s)
            S.arto(C, 'bordo', [a, b], 0.86, 0.9, nv=1, na=20, colore=ORO, spessore=0.004 * u, stacco=0.11 * u, rmax=0.12, drappo=0.0,
                   pesi={'forearm_' + s: 1.0})
    if g >= 4:
        # corona d'aureola dietro la testa e talismani sospesi attorno ai fianchi
        h0, h1 = S.ossa('head')
        aureola(S, C, 'bordo', ORO, 0.24 * u, dietro=0.10, z=h0.z + 0.13 * u, spessore=0.012, raggi=12, gemme=gem, osso='head')
        c = S.centro(zv - 0.15 * u)
        for k in range(8):
            a = 360 * (k + 0.5) / 8
            d = S.dir(a)
            p = c + d * (S.raggio(c, d, 0.05 * u, 0.4 * u) + 0.17 * u) + Vector((0, 0, 0.04 * u * math.sin(k * 1.7)))
            lat = Vector((-d.y, d.x, 0))
            S.griglia(C, 'carta', [[p + lat * -0.028 * u + Vector((0, 0, -z)), p + lat * 0.028 * u + Vector((0, 0, -z))] for z in (0, 0.08 * u, 0.16 * u)],
                      CARTA, pesi={'hips': 1.0}, fuori=lambda q, d=d: d)
            S.gemma(C, 'gemma', p + d * 0.004 * u + Vector((0, 0, 0.012 * u)), 0.016 * u, d, gem, pesi={'hips': 1.0})
        # seconda falda corta sopra la veste
        S.falde(C, 'regno', [-90, -30, 30, 90, 150, 210], 52, zv - 0.07 * u, 0.22 * u, apri=0.05 * u, cols=7, gioco=0.075 * u,
                colore=(1, 1, 1), spessore=0.004 * u, coscia=0.7, orlo=(0.022 * u, 'bordo', ORO))


DISEGNI = {'lama': lama, 'ombra': ombra, 'monaco': monaco, 'mistico': mistico}


def crea_completi(corpo, arm, H, classi=CLASSI, gradi=('base', 0, 1, 2, 3, 4), donna=False):
    """Costruisce tutti i completi sul corpo; ritorna i nomi dei capi (lama_base, lama_0 ... mistico_4)."""
    S = Sarto(corpo, arm, H, donna)
    for c in classi:
        if c not in DISEGNI:
            continue
        for g in gradi:
            DISEGNI[c](S, g)
    return S.oggetti()
