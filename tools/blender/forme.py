# Regni di Giada — strumenti comuni per gli script di Blender: primitive (bmesh), pesi delle ossa
# calcolati dalla distanza, suddivisione, ombreggiatura dipinta per vertice, animazioni in assi semplici.
import bpy, bmesh, math
from mathutils import Vector, Quaternion, Euler
from mathutils.bvhtree import BVHTree


# ------------------------------------------------------------------ primitive
def lathe(path, n=12, cap0=True, cap1=True):
    """Tubo lungo un percorso: path = [(centro, rx, ry)]."""
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
        ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((0, -1, 0))
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


def sphere(c, r, scale=(1, 1, 1), seg=16, rings=10, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Euler(rot).to_matrix())
    bmesh.ops.translate(bm, vec=Vector(c), verts=bm.verts)
    return bm


def box(c, size, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Euler(rot).to_matrix())
    bmesh.ops.translate(bm, vec=Vector(c), verts=bm.verts)
    return bm


def cone(c, r, h, rot=(0, 0, 0), seg=8, r2=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r2, depth=h)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Euler(rot).to_matrix())
    bmesh.ops.translate(bm, vec=Vector(c), verts=bm.verts)
    return bm


def cut(bm, fn):
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if fn(v.co)], context='VERTS')
    return bm


def solidify(bm, t):
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


def catmull(pts, steps=4):
    pts = [Vector(p) for p in pts]
    out = []
    for i in range(len(pts) - 1):
        p0, p1, p2, p3 = pts[max(i - 1, 0)], pts[i], pts[i + 1], pts[min(i + 2, len(pts) - 1)]
        for k in range(steps):
            t = k / steps
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t))
    out.append(pts[-1])
    return out


# ------------------------------------------------------------------ pesi delle ossa
def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (a + ab * t - p).length


def weights_for(p, allowed, BH, BT, power=4):
    ds = sorted((seg_dist(p, BH[b], BT[b]), b) for b in allowed)[:3]
    ws = [(1.0 / (d + 0.025) ** power, b) for d, b in ds]
    tot = sum(w for w, _ in ws)
    out = [(b, w / tot) for w, b in ws if w / tot > 0.03]
    tot = sum(w for _, w in out)
    return [(b, w / tot) for b, w in out]


# ------------------------------------------------------------------ oggetti
def make_obj(scene, name, bm, groups):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    for n in groups:
        ob.vertex_groups.new(name=n)
    return ob


def apply_subsurf(ob, levels=1):
    mod = ob.modifiers.new('liscio', 'SUBSURF')
    mod.levels = mod.render_levels = levels
    mod.uv_smooth = 'NONE'
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    ob.modifiers.remove(mod)
    old = ob.data
    ob.data = me
    bpy.data.meshes.remove(old)
    for poly in me.polygons:
        poly.use_smooth = True


def select_only(scene, obs, active):
    for o in scene.objects:
        o.select_set(False)
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active


# ------------------------------------------------------------------ ombreggiatura dipinta per vertice
def _hemi(n=20):
    out, ga = [], math.pi * (3 - math.sqrt(5))
    for i in range(n):
        z = 1 - (i + 0.5) / n
        r = math.sqrt(max(0.0, 1 - z * z))
        out.append(Vector((math.cos(ga * i) * r, math.sin(ga * i) * r, z)))
    return out


HEMI = _hemi(20)


def shade_vertices(ob, reach=0.26, uv_name='Ombra'):
    """Occlusione ambientale (solo contro l'oggetto stesso) e curvatura -> terza UV (v già capovolta per glTF)."""
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.normal_update()
    tree = BVHTree.FromBMesh(bm)
    ao, curv = {}, {}
    wsum = sum(h.z for h in HEMI)
    for v in bm.verts:
        n = v.normal
        t = n.orthogonal().normalized()
        b = n.cross(t)
        o = v.co + n * 0.004
        occ = 0.0
        for d in HEMI:
            hit = tree.ray_cast(o, (t * d.x + b * d.y + n * d.z).normalized(), reach)
            if hit[0] is not None:
                occ += d.z * (1 - hit[3] / reach)
        ao[v.index] = 1 - min(1.0, occ / wsum * 1.6)
        c, k = 0.0, 0
        for e in v.link_edges:
            u = e.other_vert(v)
            dv = v.co - u.co
            if dv.length_squared > 1e-10:
                c += (v.normal - u.normal).dot(dv) / dv.length_squared
                k += 1
        curv[v.index] = c / max(1, k)
    bm.free()
    vals = sorted(abs(x) for x in curv.values())
    scale = vals[int(len(vals) * 0.92)] or 1.0
    lay = me.uv_layers.new(name=uv_name)
    for lp in me.loops:
        i = lp.vertex_index
        cv = max(-1.0, min(1.0, curv[i] / scale))
        lay.data[lp.index].uv = (0.4 + 0.6 * ao[i], 1 - (1.0 + 0.22 * cv))


# ------------------------------------------------------------------ animazioni (rotazioni negli assi dell'armatura a riposo)
AX = {'X': Vector((1, 0, 0)), 'Y': Vector((0, 1, 0)), 'Z': Vector((0, 0, 1))}


def local_quat(rest3, rots):
    q = Quaternion()
    for ax, deg in rots:
        q = Quaternion(AX[ax], math.radians(deg)) @ q
    return (rest3.inverted() @ q.to_matrix() @ rest3).to_quaternion()


def make_action(arm, name, keys, loop=False, root='hips'):
    rest = {b.name: b.matrix_local.to_3x3() for b in arm.data.bones}
    act = bpy.data.actions.new(name)
    arm.animation_data_create()
    arm.animation_data.action = act
    for frame, pose in keys:
        for pb in arm.pose.bones:
            pb.rotation_mode = 'QUATERNION'
            pb.rotation_quaternion = local_quat(rest[pb.name], pose.get(pb.name, []))
            pb.keyframe_insert('rotation_quaternion', frame=frame, group=pb.name)
            if pb.name == root:
                pb.location = rest[root].inverted() @ Vector(pose.get('loc', (0, 0, 0)))
                pb.keyframe_insert('location', frame=frame, group=pb.name)
    act.use_frame_range = True
    act.frame_start, act.frame_end = keys[0][0], keys[-1][0]
    act.use_cyclic = loop
    act.use_fake_user = True
    arm.animation_data.action = None
    return act


def stash_actions(arm, actions):
    arm.animation_data_create()
    for act in actions:
        tr = arm.animation_data.nla_tracks.new()
        tr.name = act.name
        tr.strips.new(act.name, int(act.frame_range[0]), act)
        tr.mute = True
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
