extends SkeletonModifier3D
## Dopo l'animazione: per ogni braccio che regge un'arma chiude le dita sull'impugnatura, ruota il polso attorno
## all'avambraccio e piega il gomito. Sono scostamenti sopra la posa animata (restano le oscillazioni della corsa).
## braccia: { "R": { "curl": 0..1, "roll": gradi, "flex": gradi, "pollice": 0..1, "alza": gradi }, "L": {...} }
##   curl   = quanto si chiudono le dita (1 = pugno)
##   roll   = rotazione del polso: positivo porta il pollice verso l'alto
##   flex   = piegamento del gomito: positivo porta la mano in avanti
##   alza   = apertura della spalla in avanti (porta tutto il braccio avanti)
## «tiro» (0..1) governa la posa dell'arco: braccio sinistro teso in avanti, destro che tira la corda alla guancia.

const DITA := ["index", "middle", "ring", "pinky"]
const CURVE := [64.0, 80.0, 52.0]          # gradi per falange (1, 2, 3) a pugno chiuso

var braccia: Dictionary = {}
var peso := 1.0
var arco := false
var tiro := 0.0
var _segni: Dictionary = {}


func _osso(sk: Skeleton3D, nome: String) -> int:
	return sk.find_bone(nome)


## Segno con cui ruotare attorno all'asse locale perché il vettore «da» vada verso «verso» (riposo dello scheletro).
func _segno(sk: Skeleton3D, i: int, asse: Vector3, da: Vector3, verso: Vector3) -> float:
	var g := sk.get_bone_global_rest(i).basis
	var a := (g * asse).normalized()
	var d := (g * da).normalized() if da.length() > 0.0 else Vector3.ZERO
	var s := a.cross(d).dot(verso)
	return 1.0 if s >= 0.0 else -1.0


func _ruota(sk: Skeleton3D, i: int, asse: Vector3, gradi: float) -> void:
	if i < 0 or absf(gradi) < 0.01:
		return
	sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i) * Quaternion(asse, deg_to_rad(gradi)))


var _arco_dopo := false


func _process_modification() -> void:
	_arco_dopo = false
	_principale()
	if _arco_dopo:
		_arco()


func _principale() -> void:
	var sk := get_skeleton()
	if sk == null or peso <= 0.001:
		return
	if arco and tiro > 0.001:
		_arco_dopo = true
	for lato in braccia:
		var c: Dictionary = braccia[lato]
		var mano := _osso(sk, "hand_" + lato)
		var avam := _osso(sk, "forearm_" + lato)
		var brac := _osso(sk, "upper_arm_" + lato)
		if mano < 0:
			continue
		var k := String(lato)
		if not _segni.has(k):
			var dito := _osso(sk, "hand_%s_index1" % lato)
			_segni[k] = {
				# le dita si chiudono verso il palmo (asse locale x, palmo = z locale dell'osso del dito)
				"curl": _segno(sk, dito, Vector3.RIGHT, Vector3.UP, (sk.get_bone_global_rest(dito).basis * Vector3.BACK).normalized()) if dito >= 0 else 1.0,
				# il pollice (avanti, +z) sale se si ruota il polso attorno al suo asse
				"roll": _segno(sk, mano, Vector3.UP, Vector3.BACK, Vector3.UP),
				# il gomito porta la mano in avanti (+z)
				"flex": _segno(sk, avam, Vector3.RIGHT, Vector3.UP, Vector3.BACK) if avam >= 0 else 1.0,
				"alza": _segno(sk, brac, Vector3.RIGHT, Vector3.UP, Vector3.BACK) if brac >= 0 else 1.0,
			}
		var sg: Dictionary = _segni[k]
		var w := peso
		_ruota(sk, brac, Vector3.RIGHT, float(sg.alza) * float(c.get("alza", 0.0)) * w)
		_ruota(sk, avam, Vector3.RIGHT, float(sg.flex) * float(c.get("flex", 0.0)) * w)
		_ruota(sk, mano, Vector3.UP, float(sg.roll) * float(c.get("roll", 0.0)) * w)
		var curl := float(c.get("curl", 0.0)) * w
		if curl > 0.01:
			for d in DITA:
				for n in range(3):
					_ruota(sk, _osso(sk, "hand_%s_%s%d" % [lato, d, n + 1]), Vector3.RIGHT, float(sg.curl) * CURVE[n] * curl)
			# pollice: si piega sopra le altre dita
			var pol := float(c.get("pollice", 1.0)) * curl
			_ruota(sk, _osso(sk, "hand_%s_thumb2" % lato), Vector3.RIGHT, float(sg.curl) * 25.0 * pol)
			_ruota(sk, _osso(sk, "hand_%s_thumb3" % lato), Vector3.RIGHT, float(sg.curl) * 30.0 * pol)


# ------------------------------------------------------------------ posa dell'arco (cinematica inversa a due ossa)
var presa_arco := Transform3D.IDENTITY        # presa della mano sinistra nello spazio dell'osso (posa del telaio dell'arco)


func _arco() -> void:
	var sk := get_skeleton()
	var w := smoothstep(0.0, 1.0, tiro)
	if sk == null or w <= 0.001:
		return
	var testa := sk.find_bone("head")
	var sp_l := sk.find_bone("upper_arm_L")
	var sp_r := sk.find_bone("upper_arm_R")
	if testa < 0 or sp_l < 0 or sp_r < 0:
		return
	var o_testa := sk.get_bone_global_pose(testa).origin
	# braccio sinistro: teso in avanti, il telaio dell'arco verticale con la pancia verso il bersaglio
	var spalla_l := sk.get_bone_global_pose(sp_l).origin
	var mano_l := sk.find_bone("hand_L")
	var t_l := spalla_l.lerp(spalla_l + Vector3(0.1, 0.02, 0.68), 1.0)
	_ik(sk, "L", spalla_l.lerp(t_l, 1.0) if false else t_l, Vector3(0.4, -0.7, 0.0), w)
	var base := presa_arco.basis.orthonormalized().inverse()
	var g := sk.get_bone_global_pose(mano_l)
	g.basis = g.basis.orthonormalized().slerp(base, w)
	sk.set_bone_global_pose(mano_l, g)
	# braccio destro: la mano tira la corda fino alla guancia, il gomito alto e indietro
	var t_r := o_testa + Vector3(-0.14, -0.1, 0.12)
	_ik(sk, "R", t_r, Vector3(-0.6, 0.35, -1.0), w)


## Porta la mano del lato dato verso `bersaglio` (spazio dello scheletro) con peso w; `polo` indica dove guarda il gomito.
func _ik(sk: Skeleton3D, lato: String, bersaglio: Vector3, polo: Vector3, w: float) -> void:
	var su := sk.find_bone("upper_arm_" + lato)
	var av := sk.find_bone("forearm_" + lato)
	var ma := sk.find_bone("hand_" + lato)
	var a := sk.get_bone_global_pose(su).origin
	var b := sk.get_bone_global_pose(av).origin
	var c := sk.get_bone_global_pose(ma).origin
	var l1 := a.distance_to(b)
	var l2 := b.distance_to(c)
	var meta := c.lerp(bersaglio, w)
	var d := clampf(a.distance_to(meta), 0.05, l1 + l2 - 0.002)
	var u := (meta - a).normalized()
	var x := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var h := l1 * sqrt(1.0 - x * x)
	var perp := (polo - u * polo.dot(u)).normalized()
	var gomito := a + u * (l1 * x) + perp * h
	# braccio: l'asse dell'osso va da a verso il gomito
	var g := sk.get_bone_global_pose(su)
	g.basis = Basis(Quaternion((b - a).normalized(), (gomito - a).normalized())) * g.basis
	sk.set_bone_global_pose(su, g)
	# avambraccio: dal gomito verso la mano di destinazione
	var b2 := sk.get_bone_global_pose(av).origin
	var c2 := sk.get_bone_global_pose(ma).origin
	var ga := sk.get_bone_global_pose(av)
	ga.basis = Basis(Quaternion((c2 - b2).normalized(), (a + u * d - b2).normalized())) * ga.basis
	sk.set_bone_global_pose(av, ga)
