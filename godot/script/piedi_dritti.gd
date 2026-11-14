class_name PiediDritti
extends SkeletonModifier3D
## Raddrizza i piedi dopo l'animazione: le camminate di Mixamo li girano verso l'esterno. A ogni fotogramma toglie a ogni
## piede la rotazione attorno alla verticale rispetto alla direzione di marcia (avanti = +z dello scheletro).

var peso := 1.0              # 0 = lascia l'animazione com'è, 1 = piedi perfettamente dritti
var _piedi: Array = []


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or peso <= 0.001:
		return
	if _piedi.is_empty():
		for nome in ["foot_L", "foot_R"]:
			var i := sk.find_bone(nome)
			if i >= 0:
				_piedi.append(i)
	for i in _piedi:
		var g := sk.get_bone_global_pose(i)
		var punta := g.basis.y.normalized()                 # asse dell'osso: dal tallone verso la punta
		var orizz := Vector2(punta.x, punta.z).length()
		if orizz < 0.25:
			continue                                         # piede quasi verticale (in spinta): non c'è niente da raddrizzare
		var storto := atan2(punta.x, punta.z)
		if absf(storto) > 1.4:
			continue                                         # piede ribaltato all'indietro
		var quanto := -storto * peso * minf(1.0, (orizz - 0.25) / 0.35) * minf(1.0, (1.4 - absf(storto)) / 0.4)
		g.basis = Basis(Vector3.UP, quanto) * g.basis
		sk.set_bone_global_pose(i, g)
