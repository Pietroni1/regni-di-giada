extends SkeletonModifier3D
## Dopo l'animazione «sella» (che è una seduta su sedia, a gambe unite): apre le cosce attorno al cavallo, le abbassa
## e lascia pendere gli stinchi lungo i fianchi, così le gambe non entrano nel corpo del destriero.
## Rotazioni nello spazio dello scheletro (x = sinistra del personaggio, y = alto, z = avanti).

var apri := 30.0        # gradi: ginocchia verso l'esterno
var giu := 34.0         # gradi: cosce abbassate rispetto alla seduta
var stinco := 22.0      # gradi: quanto lo stinco torna verso la verticale
var piede := 12.0       # gradi: punta del piede rialzata (tallone basso, come in staffa)
var busto := 0.0        # gradi: busto in avanti
var peso := 1.0


func _gira(sk: Skeleton3D, i: int, giro: Basis) -> void:
	if i < 0:
		return
	var g := sk.get_bone_global_pose(i)
	var genitore := sk.get_bone_parent(i)
	var gp := sk.get_bone_global_pose(genitore).basis if genitore >= 0 else Basis.IDENTITY
	var nuovo := (giro * g.basis).orthonormalized()
	sk.set_bone_pose_rotation(i, (gp.inverse() * nuovo).get_rotation_quaternion())


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or peso <= 0.001:
		return
	if absf(busto) > 0.01:
		_gira(sk, sk.find_bone("spine"), Basis(Vector3.RIGHT, deg_to_rad(busto * peso)))
	for lato in ["L", "R"]:
		var coscia := sk.find_bone("thigh_" + lato)
		if coscia < 0:
			continue
		var s := 1.0 if sk.get_bone_global_rest(coscia).origin.x > 0.0 else -1.0
		_gira(sk, coscia, Basis(Vector3.UP, deg_to_rad(apri * s * peso)) * Basis(Vector3.RIGHT, deg_to_rad(giu * peso)))
		_gira(sk, sk.find_bone("shin_" + lato), Basis(Vector3.RIGHT, deg_to_rad(-stinco * peso)))
		_gira(sk, sk.find_bone("foot_" + lato), Basis(Vector3.RIGHT, deg_to_rad(-piede * peso)))
