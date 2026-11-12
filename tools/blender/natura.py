# Regni di Giada — alberi, cespugli e rocce generati in Blender.
#
# Uso: blender -b --factory-startup --python tools/blender/natura.py -- client/assets/natura.glb
#
# Ogni specie ha due oggetti: "<specie>_tronco" (corteccia, UV su un atlante a 4 colonne) e
# "<specie>_chioma" (carte di foglie/fiori, UV su un atlante a 4 riquadri, normali sferiche per una
# luce morbida e "volumetrica"). Le rocce sono mesh lisce deformate dal rumore.
import bpy, bmesh, math, sys, os, random
from mathutils import Vector, Matrix, Euler, noise

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = os.path.abspath(argv[0] if argv else 'natura.glb')
HERE = os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# riquadri dell'atlante delle chiome (u0, v0, u1, v1 in coordinate glTF, origine in alto a sinistra)
LEAF = {'fiori': (0, 0, .5, .5), 'aghi': (.5, 0, 1, .5), 'acero': (0, .5, .5, 1), 'foglie': (.5, .5, 1, 1)}
# colonne dell'atlante della corteccia
BARK = {'pino': 0, 'ciliegio': 1, 'acero': 2, 'bambu': 3}


def catmull(pts, steps=4):
    """Curva morbida che passa per i punti di controllo."""
    pts = [Vector(p) for p in pts]
    out = []
    for i in range(len(pts) - 1):
        p0, p1, p2, p3 = pts[max(i - 1, 0)], pts[i], pts[i + 1], pts[min(i + 2, len(pts) - 1)]
        for k in range(steps):
            t = k / steps
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(pts[-1])
    return out


class Builder:
    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new('UVMap')
        self.normals = {}  # vertice -> normale personalizzata

    def tube(self, ctrl, r0, r1, col, n=8, steps=4, cap=True, bulge=None):
        """Ramo o tronco lungo una curva, raggio da r0 a r1; UV cilindriche nella colonna della corteccia."""
        path = catmull(ctrl, steps)
        rings, length = [], 0.0
        u0 = BARK[col] * 0.25
        for i, c in enumerate(path):
            if i:
                length += (c - path[i - 1]).length
            d = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
            ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
            u = ref.cross(d).normalized()
            w = d.cross(u).normalized()
            t = i / (len(path) - 1)
            r = r0 + (r1 - r0) * t
            if bulge:
                r *= bulge(length)
            ring = [self.bm.verts.new(c + u * (r * math.cos(2 * math.pi * k / n)) + w * (r * math.sin(2 * math.pi * k / n))) for k in range(n)]
            rings.append((ring, length))
        for i in range(len(rings) - 1):
            (ra, la), (rb, lb) = rings[i], rings[i + 1]
            for k in range(n):
                f = self.bm.faces.new((ra[k], ra[(k + 1) % n], rb[(k + 1) % n], rb[k]))
                f.smooth = True
                for lp, (kk, ll) in zip(f.loops, ((k, la), (k + 1, la), (k + 1, lb), (k, lb))):
                    lp[self.uv].uv = (u0 + 0.25 * kk / n * 0.98 + 0.002, 1 - ll * 0.35)
        if cap:
            f = self.bm.faces.new(list(reversed(rings[-1][0])))
            f.smooth = True
            for lp in f.loops:
                lp[self.uv].uv = (u0 + 0.12, 1 - rings[-1][1] * 0.35)
        return path

    def cards(self, center, radii, count, size, region, up_bias=1.0, tilt=1.0, seed=0, flat=False):
        """Ciuffo di carte (quad) dentro un ellissoide; normali che escono dal centro del ciuffo."""
        rnd = random.Random(seed)
        c = Vector(center)
        u0, v0, u1, v1 = LEAF[region]
        for _ in range(count):
            while True:
                p = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1)))
                if p.length <= 1:
                    break
            p = c + Vector((p.x * radii[0], p.y * radii[1], p.z * radii[2]))
            if flat:
                rot = Euler((rnd.uniform(-.5, .5) * tilt, rnd.uniform(-.5, .5) * tilt, rnd.uniform(0, math.tau))).to_matrix()
            else:
                rot = Euler((rnd.uniform(0, math.tau), rnd.uniform(0, math.tau), rnd.uniform(0, math.tau))).to_matrix()
            s = size * rnd.uniform(0.75, 1.25)
            corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
            vs = [self.bm.verts.new(p + rot @ Vector((a * s / 2, b * s / 2, 0)) if flat else p + rot @ Vector((a * s / 2, 0, b * s / 2))) for a, b in corners]
            nrm = (p - c)
            nrm = Vector((nrm.x / max(radii[0], .01), nrm.y / max(radii[1], .01), nrm.z / max(radii[2], .01) + up_bias * 0.6))
            if nrm.length < 1e-4:
                nrm = Vector((0, 0, 1))
            nrm.normalize()
            f = self.bm.faces.new(vs)
            f.smooth = True
            pad = 0.01
            for lp, (a, b) in zip(f.loops, corners):
                uu = u0 + pad + (a + 1) / 2 * (u1 - u0 - 2 * pad)
                vv = v0 + pad + (1 - (b + 1) / 2) * (v1 - v0 - 2 * pad)
                lp[self.uv].uv = (uu, 1 - vv)
            for v in vs:
                self.normals[v] = nrm

    def finish(self, name):
        me = bpy.data.meshes.new(name)
        self.bm.verts.index_update()
        nmap = {v.index: n for v, n in self.normals.items()}
        self.bm.to_mesh(me)
        self.bm.free()
        if nmap:
            if hasattr(me, 'use_auto_smooth'):
                me.use_auto_smooth = True
            vn = [nmap.get(i, Vector((0, 0, 1))) for i in range(len(me.vertices))]
            me.normals_split_custom_set_from_vertices(vn)
        ob = bpy.data.objects.new(name, me)
        scene.collection.objects.link(ob)
        mat = bpy.data.materials.get(name.split('_')[1]) or bpy.data.materials.new(name.split('_')[1])
        me.materials.append(mat)
        return ob


def branch_from(path, frac):
    i = min(len(path) - 1, max(0, int(frac * (len(path) - 1))))
    return path[i]


# ------------------------------------------------------------------ pino giapponese (nuvole di aghi a strati)
def pino(seed=1):
    rnd = random.Random(seed)
    t, f = Builder(), Builder()
    trunk = t.tube([(0, 0, -.3), (0, 0, .4), (.35, .1, 1.6), (-.25, .2, 3.0), (.35, -.1, 4.4), (.15, 0, 5.7)], .42, .1, 'pino', n=7, steps=3)
    pads = []
    for i, frac in enumerate((.38, .5, .62, .72, .84)):
        base = branch_from(trunk, frac)
        a = i * 2.3 + rnd.uniform(-.3, .3)
        L = 2.4 - frac * 1.4
        end = base + Vector((math.cos(a) * L, math.sin(a) * L, .5 + rnd.uniform(0, .4)))
        mid = base.lerp(end, .5) + Vector((0, 0, -.15))
        t.tube([base, mid, end], .13 - frac * .05, .05, 'pino', n=5, steps=2)
        pads.append((end + Vector((0, 0, .15)), 1.25 - frac * .3))
    pads.append((trunk[-1] + Vector((0, 0, .25)), 1.15))
    for k, (c, r) in enumerate(pads):
        f.cards(c, (r, r * .9, r * .38), 26, .95, 'aghi', up_bias=1.6, tilt=.9, seed=seed * 10 + k, flat=True)
    return t, f


# ------------------------------------------------------------------ ciliegio e acero (rami aperti, chioma a ciuffi)
def latifoglia(kind, seed=2):
    rnd = random.Random(seed)
    t, f = Builder(), Builder()
    col = 'ciliegio' if kind == 'ciliegio' else 'acero'
    tall = 1.0 if kind == 'ciliegio' else 1.25
    trunk = t.tube([(0, 0, -.3), (0, 0, .5), (.12, .05, 1.3 * tall), (.18, 0, 1.75 * tall)], .36, .22, col, n=8, steps=3, cap=False)
    top = trunk[-1]
    clusters = [(top + Vector((0, 0, 1.9 * tall)), 1.5)]
    for i in range(4):
        a = i * math.tau / 4 + rnd.uniform(-.4, .4)
        spread = rnd.uniform(1.5, 2.1) / tall
        end = top + Vector((math.cos(a) * spread, math.sin(a) * spread, rnd.uniform(1.3, 1.9) * tall))
        mid = top.lerp(end, .45) + Vector((math.cos(a) * .25, math.sin(a) * .25, -.2))
        t.tube([top, mid, end], .17, .06, col, n=6, steps=3)
        sub = end + Vector((math.cos(a + .8) * .6, math.sin(a + .8) * .6, .3))
        t.tube([mid, mid.lerp(sub, .5), sub], .07, .03, col, n=5, steps=2)
        clusters.append((end + Vector((0, 0, .35)), rnd.uniform(1.15, 1.45)))
    region = 'fiori' if kind == 'ciliegio' else 'acero'
    for k, (c, r) in enumerate(clusters):
        f.cards(c, (r, r, r * .78), 40, .9, region, up_bias=.8, seed=seed * 10 + k)
    return t, f


# ------------------------------------------------------------------ bambù (canne con nodi e ciuffi di foglie)
def bambu(seed=3):
    rnd = random.Random(seed)
    t, f = Builder(), Builder()
    for i in range(7):
        a, d = rnd.uniform(0, math.tau), rnd.uniform(0, .55)
        x, y = math.cos(a) * d, math.sin(a) * d
        h = rnd.uniform(6.0, 8.2)
        lean = Vector((x * .35 + rnd.uniform(-.25, .25), y * .35 + rnd.uniform(-.25, .25), 0))
        ctrl = [Vector((x, y, -.2)), Vector((x, y, h * .4)) + lean * .3, Vector((x, y, h)) + lean]
        nodes = lambda L: 1.0 + 0.18 * max(0.0, 1 - abs((L % 0.7) - 0.35) / 0.04 * 0.25) if (L % 0.7) > 0.66 else 1.0
        path = t.tube(ctrl, .075, .05, 'bambu', n=6, steps=8, bulge=nodes)
        for k in range(4):
            c = branch_from(path, .55 + k * .12)
            off = Vector((rnd.uniform(-.5, .5), rnd.uniform(-.5, .5), 0))
            f.cards(c + off, (.75, .75, .45), 9, .7, 'foglie', up_bias=.5, seed=seed * 100 + i * 10 + k)
    return t, f


def cespuglio(seed=4):
    t, f = Builder(), Builder()
    t.tube([(0, 0, -.1), (0, 0, .5)], .06, .03, 'acero', n=5, steps=1)
    f.cards((0, 0, .55), (1.05, .95, .6), 46, .75, 'foglie', up_bias=.9, seed=seed)
    return t, f


# ------------------------------------------------------------------ rocce lisce
def roccia(name, seed, scale):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
    off = Vector((seed * 7.1, seed * 3.3, seed * 1.7))
    for v in bm.verts:
        p = v.co
        n1 = noise.noise(p * 1.1 + off)
        n2 = noise.noise(p * 2.7 + off * 2) * .35
        v.co = p * (1 + .28 * n1 + .1 * n2)
        v.co.x *= scale[0]; v.co.y *= scale[1]; v.co.z *= scale[2]
        if v.co.z < -.25 * scale[2]:
            v.co.z = -.25 * scale[2] + (v.co.z + .25 * scale[2]) * .2
    for fc in bm.faces:
        fc.smooth = True
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    mat = bpy.data.materials.get('roccia') or bpy.data.materials.new('roccia')
    me.materials.append(mat)
    return ob


SPECIES = {
    'pino': pino(11), 'ciliegio': latifoglia('ciliegio', 21), 'acero': latifoglia('acero', 31),
    'bambu': bambu(41), 'cespuglio': cespuglio(51),
}
for name, (trunk, crown) in SPECIES.items():
    trunk.finish(f'{name}_tronco')
    crown.finish(f'{name}_chioma')
roccia('roccia_1', 1, (1.4, 1.1, .8))
roccia('roccia_2', 2, (1.0, .9, .9))
roccia('roccia_3', 3, (1.8, 1.0, .6))

for ob in scene.objects:
    print(f'{ob.name}: {len(ob.data.vertices)} vertici, {len(ob.data.polygons)} facce')

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_animations=False, export_skins=False, export_morph=False,
                          export_yup=True, export_texcoords=True, export_normals=True, export_materials='EXPORT', export_apply=False)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, 'natura.blend'))
print('ESPORTATO', OUT)
