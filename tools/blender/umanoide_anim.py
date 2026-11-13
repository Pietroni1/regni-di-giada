# Regni di Giada — animazioni dell'umanoide (17 azioni), applicabili a qualunque armatura con le ossa
# standard del gioco: le rotazioni sono scritte negli assi dell'armatura e convertite per ogni osso,
# quindi funzionano anche su modelli importati con proporzioni diverse.
import bpy, math
from mathutils import Vector, Quaternion


def crea_animazioni(arm, scala=1.0):
    """scala: altezza del modello / 2.35 (gli spostamenti del bacino seguono la taglia)."""
    arm_data = arm.data
    # Le rotazioni si scrivono negli assi dell'armatura a riposo (X = beccheggio, Y = laterale, Z = torsione):
    #   gambe e braccia: X negativo = in avanti;  busto/testa: X positivo = si piega in avanti;
    #   Z positivo = ruota verso sinistra;  braccio sinistro: Y positivo = si abbassa verso il fianco (destro: Y negativo).
    REST = {b.name: b.matrix_local.to_3x3() for b in arm_data.bones}
    AX = {'X': Vector((1, 0, 0)), 'Y': Vector((0, 1, 0)), 'Z': Vector((0, 0, 1))}


    def local_quat(bone, rots):
        q = Quaternion()
        for ax, deg in rots:
            q = Quaternion(AX[ax], math.radians(deg)) @ q
        M = REST[bone]
        return (M.inverted() @ q.to_matrix() @ M).to_quaternion()


    def fwd(d): return ('X', -d)


    def lean(d): return ('X', d)


    def turn(d): return ('Z', d)


    def down(s, d): return ('Y', d if s == 'L' else -d)


    def mir(s): return 'R' if s == 'L' else 'L'


    def merge(*poses):
        out = {}
        for p in poses:
            for k, v in p.items():
                if k == 'loc':
                    out['loc'] = tuple(a + b for a, b in zip(out.get('loc', (0, 0, 0)), v))
                elif k.startswith(('blade', 'staff', 'bow')):
                    out[k] = v
                else:
                    out[k] = out.get(k, []) + list(v)
        return out


    def relaxed_arms(d=24, f=4, bend=12):
        p = {}
        for s in 'LR':
            p[f'upper_arm_{s}'] = [down(s, d), fwd(f)]
            p[f'forearm_{s}'] = [fwd(bend)]
        return p


    def stance():
        """Guardia di combattimento: gambe piegate, busto in avanti."""
        return {'thigh_L': [fwd(14)], 'shin_L': [('X', 16)], 'thigh_R': [fwd(-8)], 'shin_R': [('X', 12)], 'foot_L': [('X', -4)],
                'spine': [lean(6)], 'head': [lean(-4)], 'loc': (0, 0, -.03),
                'upper_arm_L': [down('L', 28), fwd(28)], 'forearm_L': [fwd(55)],
                'upper_arm_R': [down('R', 22), fwd(14)], 'forearm_R': [fwd(35)]}


    ACTIONS = {}

    # Direzione delle armi rispetto alla mano a riposo (stessa convenzione dell'impugnatura nel gioco):
    # Y dell'impugnatura = verso il gomito, Z = davanti. Lama: -0.22 Y + 0.976 Z; asta del bastone: +Y.
    def grip_axes(s):
        hb = arm.data.bones[f'hand_{s}']
        y = -(hb.tail_local - hb.head_local).normalized()
        z = Vector((0, -1, 0))
        z = (z - y * z.dot(y)).normalized()
        return y, z


    def weapon_dir(s, kind):
        y, z = grip_axes(s)
        return (y * -0.22 + z * 0.976).normalized() if kind == 'blade' else y


    def aim_hand2(s, t_axis, t_front):
        """Orienta l'impugnatura su due assi: Y dell'impugnatura verso t_axis, Z verso t_front (per l'arco)."""
        bpy.context.view_layer.update()
        pb = arm.pose.bones[f'hand_{s}']
        P = pb.matrix.to_3x3().normalized()
        y, z = grip_axes(s)
        Rinv = REST[f'hand_{s}'].inverted()
        cy, cz = P @ (Rinv @ y), P @ (Rinv @ z)
        a = Vector(t_axis).normalized()
        Q1 = cy.rotation_difference(a)
        cz = Q1 @ cz
        f = Vector(t_front)
        f = (f - a * f.dot(a)).normalized()
        cz = (cz - a * cz.dot(a)).normalized()
        Q = cz.rotation_difference(f) @ Q1
        pb.rotation_quaternion = pb.rotation_quaternion @ (P.inverted() @ Q.to_matrix() @ P).to_quaternion()


    def aim_hand(s, kind, target):
        """Ruota il polso perché l'arma punti verso target (assi dell'armatura)."""
        bpy.context.view_layer.update()
        pb = arm.pose.bones[f'hand_{s}']
        P = pb.matrix.to_3x3().normalized()
        local = REST[f'hand_{s}'].inverted() @ weapon_dir(s, kind)
        cur = P @ local
        Q = cur.rotation_difference(Vector(target).normalized())
        pb.rotation_quaternion = pb.rotation_quaternion @ (P.inverted() @ Q.to_matrix() @ P).to_quaternion()


    def make_action(name, keys, loop=False):
        """keys: lista di (frame, posa). Ogni posa: {osso: [(asse, gradi)...], 'loc': (x, y, z)}."""
        act = bpy.data.actions.new(name)
        arm.animation_data_create()
        arm.animation_data.action = act
        for frame, pose in keys:
            for pb in arm.pose.bones:
                pb.rotation_mode = 'QUATERNION'
                pb.rotation_quaternion = local_quat(pb.name, pose.get(pb.name, []))
                if pb.name == 'hips':
                    pb.location = REST['hips'].inverted() @ (Vector(pose.get('loc', (0, 0, 0))) * scala)
            for key, (s, kind) in (('blade_R', ('R', 'blade')), ('blade_L', ('L', 'blade')), ('staff_R', ('R', 'staff'))):
                if key in pose:
                    aim_hand(s, kind, pose[key])
            if 'bow_L' in pose:
                aim_hand2('L', *pose['bow_L'])
            for pb in arm.pose.bones:
                pb.keyframe_insert('rotation_quaternion', frame=frame, group=pb.name)
                if pb.name == 'hips':
                    pb.keyframe_insert('location', frame=frame, group=pb.name)
        act.use_frame_range = True
        act.frame_start, act.frame_end = keys[0][0], keys[-1][0]
        act.use_cyclic = loop
        act.use_fake_user = True
        ACTIONS[name] = act
        arm.animation_data.action = None
        return act


    def cycle(name, frames, steps, fn):
        keys = [(round(frames * i / steps), fn(i / steps)) for i in range(steps)]
        keys.append((frames, fn(0.0)))
        make_action(name, keys, loop=True)


    TAU = math.pi * 2

    # fermo: respiro lento
    cycle('fermo', 60, 6, lambda p: merge(relaxed_arms(f=4 + math.sin(TAU * p)), {
        'spine': [lean(2)], 'chest': [lean(1 + 1.2 * math.sin(TAU * p))], 'neck': [lean(-2)],
        'head': [lean(-1 - .8 * math.sin(TAU * p))], 'shin_L': [('X', 3)], 'shin_R': [('X', 3)],
        'loc': (0, 0, -.004 + .004 * math.sin(TAU * p))}))


    def walk(p, amp=26, knee=42, arm=22, lean_=4, bob=.022, elbow=14, twist=6):
        s, c = math.sin(TAU * p), math.cos(TAU * p)
        return {
            'thigh_L': [fwd(amp * s)], 'thigh_R': [fwd(-amp * s)],
            'shin_L': [('X', 6 + knee * max(0, c) ** 2)], 'shin_R': [('X', 6 + knee * max(0, -c) ** 2)],
            'foot_L': [('X', -8 * s)], 'foot_R': [('X', 8 * s)],
            'hips': [turn(-twist * s)], 'chest': [turn(twist * 1.2 * s)], 'spine': [lean(lean_)],
            'head': [lean(-lean_ * .6), turn(-2 * s)],
            'upper_arm_L': [down('L', 20), fwd(-arm * s)], 'upper_arm_R': [down('R', 20), fwd(arm * s)],
            'forearm_L': [fwd(elbow + 12 * max(0, -s))], 'forearm_R': [fwd(elbow + 12 * max(0, s))],
            'loc': (0, 0, bob * math.cos(2 * TAU * p) - bob * .6),
        }


    cycle('camminata', 30, 10, lambda p: walk(p))
    cycle('corsa', 18, 9, lambda p: walk(p, amp=44, knee=80, arm=40, lean_=13, bob=.04, elbow=70, twist=9))

    # in sella: gambe aperte e piegate, mani alle redini
    cycle('sella', 30, 6, lambda p: {
        'thigh_L': [down('R', 28), fwd(78)], 'thigh_R': [down('L', 28), fwd(78)],
        'shin_L': [('X', 85)], 'shin_R': [('X', 85)], 'foot_L': [('X', -15)], 'foot_R': [('X', -15)],
        'spine': [lean(6 + 2 * math.sin(TAU * p))], 'head': [lean(-6)],
        'upper_arm_L': [down('L', 22), fwd(38)], 'upper_arm_R': [down('R', 22), fwd(38)],
        'forearm_L': [fwd(60)], 'forearm_R': [fwd(60)], 'loc': (0, 0, .01 * math.sin(TAU * p))})


    def strike(name, wind, hit, follow=None, total=15, w=4, h=8):
        keys = [(0, stance()), (w, merge(stance(), wind)), (h, merge(stance(), hit))]
        if follow:
            keys.append((h + 3, merge(stance(), follow)))
        keys.append((total, stance()))
        make_action(name, keys)


    # spada: fendente orizzontale, colpo dall'alto, affondo
    strike('spada_1',
           {'chest': [turn(-38)], 'spine': [turn(-10)], 'upper_arm_R': [down('R', -55), fwd(-15)], 'forearm_R': [fwd(65)], 'blade_R': (-0.75, 0.35, 0.55)},
           {'chest': [turn(36)], 'spine': [turn(12)], 'upper_arm_R': [down('R', -58), fwd(78)], 'forearm_R': [fwd(10)], 'blade_R': (0.2, -1, 0.05)},
           {'chest': [turn(48)], 'spine': [turn(14)], 'upper_arm_R': [down('R', -35), fwd(88)], 'forearm_R': [fwd(15)], 'blade_R': (0.9, -0.35, -0.1)})
    strike('spada_2',
           {'chest': [lean(-10), turn(-14)], 'upper_arm_R': [down('R', -18), fwd(165)], 'forearm_R': [fwd(70)], 'blade_R': (-0.2, 0.75, 0.55)},
           {'chest': [lean(20), turn(14)], 'spine': [lean(10)], 'upper_arm_R': [down('R', -8), fwd(48)], 'forearm_R': [fwd(5)], 'blade_R': (0.15, -0.8, -0.55),
            'thigh_L': [fwd(30)], 'shin_L': [('X', 38)], 'loc': (0, 0, -.06)})
    strike('spada_3',
           {'chest': [turn(-26)], 'upper_arm_R': [down('R', 8), fwd(-35)], 'forearm_R': [fwd(105)], 'blade_R': (0.05, -1, 0.1)},
           {'chest': [turn(24), lean(10)], 'upper_arm_R': [down('R', -6), fwd(86)], 'forearm_R': [fwd(4)], 'blade_R': (0.05, -1, 0.02),
            'thigh_L': [fwd(36)], 'shin_L': [('X', 30)], 'thigh_R': [fwd(-22)], 'loc': (0, -.10, -.05)}, h=7)


    def stab(name, s, kick=False):
        o = mir(s)
        tw = 1 if s == 'R' else -1
        if kick:
            strike(name, {'thigh_' + s: [fwd(40)], 'shin_' + s: [('X', 90)], 'spine': [lean(-8)]},
                   {'thigh_' + s: [fwd(85)], 'shin_' + s: [('X', 8)], 'foot_' + s: [('X', 20)], 'spine': [lean(-14)],
                    'upper_arm_' + o: [down(o, 10), fwd(20)]}, total=12, w=4, h=7)
            return
        blade = {'blade_' + s: (0, -1, 0.15)} if name.startswith('pugnali') else {}
        strike(name, merge({f'upper_arm_{s}': [down(s, 12), fwd(-25)], f'forearm_{s}': [fwd(115)], 'chest': [turn(-14 * tw)]}, blade),
               merge({f'upper_arm_{s}': [down(s, -8), fwd(75)], f'forearm_{s}': [fwd(18)], 'chest': [turn(26 * tw)], 'spine': [lean(6)]},
                     {'blade_' + s: (0, -1, -0.05)} if blade else {}),
               total=10, w=3, h=6)


    stab('pugnali_1', 'R'); stab('pugnali_2', 'L')
    stab('pugni_1', 'R'); stab('pugni_2', 'L'); stab('pugni_3', 'R', kick=True)

    # arco: braccio sinistro teso, la destra tende la corda fino al mento e rilascia
    bow_hold = {'upper_arm_L': [down('L', -8), fwd(84)], 'forearm_L': [fwd(4)], 'chest': [turn(-12)], 'head': [turn(12)],
                'bow_L': ((0, 0.05, 1), (0, -1, 0))}
    make_action('arco', [
        (0, stance()),
        (5, merge(stance(), bow_hold, {'upper_arm_R': [down('R', -6), fwd(82)], 'forearm_R': [fwd(40)]})),
        (11, merge(stance(), bow_hold, {'upper_arm_R': [down('R', -18), fwd(78)], 'forearm_R': [fwd(150)]})),
        (13, merge(stance(), bow_hold, {'upper_arm_R': [down('R', -30), fwd(60)], 'forearm_R': [fwd(165)]})),
        (20, stance())])

    # magia: le mani si alzano e poi spingono in avanti
    make_action('magia', [
        (0, stance()),
        (6, merge(stance(), {s: [down(s[-1], 6), fwd(130)] for s in ('upper_arm_L', 'upper_arm_R')},
                  {'forearm_L': [fwd(30)], 'forearm_R': [fwd(30)], 'chest': [lean(-8)], 'head': [lean(-8)], 'staff_R': (0, 0.1, 1)})),
        (11, merge(stance(), {s: [down(s[-1], 8), fwd(82)] for s in ('upper_arm_L', 'upper_arm_R')},
                   {'forearm_L': [fwd(8)], 'forearm_R': [fwd(8)], 'chest': [lean(10)], 'staff_R': (0, -0.3, 1)})),
        (18, stance())])
    # bastone: colpo in avanti con l'asta
    strike('bastone',
           {'upper_arm_R': [down('R', 4), fwd(-20)], 'forearm_R': [fwd(95)], 'chest': [turn(-20)], 'staff_R': (0, 0.4, 1)},
           {'upper_arm_R': [down('R', -2), fwd(70)], 'forearm_R': [fwd(30)], 'chest': [turn(18), lean(8)], 'staff_R': (0, -1, 0.35)},
           {'upper_arm_R': [down('R', 10), fwd(40)], 'forearm_R': [fwd(45)], 'chest': [turn(8)], 'staff_R': (0, -0.45, 0.9)}, total=15, w=4, h=8)

    # colpito e morte
    make_action('colpito', [(0, merge(relaxed_arms(), {})),
                            (3, merge(relaxed_arms(d=10, f=-10, bend=30), {'chest': [lean(-14), turn(8)], 'head': [lean(-12)], 'loc': (0, .04, 0)})),
                            (9, merge(relaxed_arms(), {}))])
    make_action('morte', [
        (0, merge(relaxed_arms(), {})),
        (8, merge(relaxed_arms(d=10, f=20, bend=40), {'thigh_L': [fwd(55)], 'thigh_R': [fwd(50)], 'shin_L': [('X', 75)], 'shin_R': [('X', 70)],
                                                      'spine': [lean(22)], 'head': [lean(15)], 'loc': (0, 0, -.32)})),
        (18, merge(relaxed_arms(d=-20, f=-30, bend=20), {'hips': [lean(-70)], 'thigh_L': [fwd(30)], 'thigh_R': [fwd(20)],
                                                         'shin_L': [('X', 30)], 'shin_R': [('X', 20)], 'head': [lean(-10)],
                                                         'loc': (0, .45, -.62)})),
        (30, merge(relaxed_arms(d=-55, f=-10, bend=10), {'hips': [lean(-90)], 'thigh_L': [fwd(4)], 'thigh_R': [fwd(-4)],
                                                         'shin_L': [('X', 6)], 'shin_R': [('X', 4)], 'head': [turn(20)],
                                                         'loc': (0, .82, -.78)}))])

    # tutte le azioni nelle tracce NLA, così l'esportatore glTF le include
    arm.animation_data_create()
    for name, act in ACTIONS.items():
        tr = arm.animation_data.nla_tracks.new()
        tr.name = name
        tr.strips.new(name, int(act.frame_range[0]), act)
        tr.mute = True
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()

    return ACTIONS
