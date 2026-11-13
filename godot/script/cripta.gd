class_name Cripta
extends Node3D
## La Cripta delle Mille Lanterne (Prove del Sigillo): stanze e muri da DUNGEON in shared/data.js, costruiti
## all'origine dell'istanza che il server comunica con `dg_start`.

const ALTEZZA := 6.5

var origine := Vector2.ZERO
var _luci: Array = []


static func crea(ox: float, oz: float) -> Cripta:
	var c := Cripta.new()
	c.origine = Vector2(ox, oz)
	c.position = Vector3(ox, 0, oz)
	c._costruisci()
	return c


## Il punto (coordinate del mondo) è calpestabile? Come dungeonWalkable in shared/data.js.
func calpestabile(x: float, z: float, margine := 0.5) -> bool:
	var lx := x - origine.x
	var lz := z - origine.y
	for r in Dati.gioco.DUNGEON.rooms:
		if lx >= float(r[0]) + margine and lx <= float(r[2]) - margine and lz >= float(r[1]) + margine and lz <= float(r[3]) - margine:
			return true
	return false


func _costruisci() -> void:
	var D: Dictionary = Dati.gioco.DUNGEON
	var pav := ShaderMaterial.new()
	pav.shader = preload("res://shader/pavimento.gdshader")
	var muro := ShaderMaterial.new()
	muro.shader = preload("res://shader/roccia.gdshader")
	muro.set_shader_parameter("muschio_forza", 0.0)
	muro.set_shader_parameter("tinta", Color(0.55, 0.52, 0.6))
	var lume := Edifici.mat(Color(1.0, 0.62, 0.25), 0.5, 0.0, 5.0)
	var ferro := Edifici.mat(Color(0.08, 0.07, 0.07), 0.6, 0.5)
	var boss: Dictionary = D.boss

	# pavimento a riquadri di 10 m (così ogni riquadro riceve poche luci) e lanterne appese
	var n_stanza := 0
	for r in D.rooms:
		var x1 := float(r[0])
		var z1 := float(r[1])
		var x2 := float(r[2])
		var z2 := float(r[3])
		var nx := maxi(1, int(ceil((x2 - x1) / 10.0)))
		var nz := maxi(1, int(ceil((z2 - z1) / 10.0)))
		var lx := (x2 - x1) / nx
		var lz := (z2 - z1) / nz
		for i in range(nx):
			for j in range(nz):
				var c := Vector3(x1 + (i + 0.5) * lx, 0, z1 + (j + 0.5) * lz)
				Edifici.scatola(Vector3(lx, 0.4, lz), c + Vector3(0, -0.2, 0), pav, self)
				# una lanterna appesa ogni due riquadri (sempre nei corridoi stretti)
				if (i + j + n_stanza) % 2 == 0 or (nx == 1 and j % 2 == 0) or (nz == 1 and i % 2 == 0):
					var nella_sala_del_boss := absf(c.x - float(boss.x)) < 24.0 and absf(c.z - float(boss.z)) < 22.0
					_lanterna(c + Vector3(0, 3.6, 0), lume, ferro, Color(1.0, 0.45, 0.3) if nella_sala_del_boss else Color(1.0, 0.68, 0.36))
		n_stanza += 1

	# muri: scatole lungo i segmenti, con uno zoccolo più largo
	for w in D.walls:
		var a := Vector2(w[0], w[1])
		var b := Vector2(w[2], w[3])
		var lung := a.distance_to(b) + 0.9
		var centro := (a + b) * 0.5
		var orizz := absf(a.y - b.y) < 0.01
		var dim := Vector3(lung, ALTEZZA, 0.9) if orizz else Vector3(0.9, ALTEZZA, lung)
		Edifici.scatola(dim, Vector3(centro.x, ALTEZZA * 0.5, centro.y), muro, self)
		var zoccolo := Vector3(lung, 0.7, 1.3) if orizz else Vector3(1.3, 0.7, lung)
		Edifici.scatola(zoccolo, Vector3(centro.x, 0.35, centro.y), muro, self)
		# pilastri ogni 8 m
		var quanti := int(a.distance_to(b) / 8.0)
		for k in range(quanti + 1):
			var p := a.lerp(b, float(k) / maxf(1.0, quanti))
			Edifici.scatola(Vector3(1.3, ALTEZZA + 0.3, 1.3), Vector3(p.x, (ALTEZZA + 0.3) * 0.5, p.y), muro, self)

	# altare nella sala del boss
	var altare := Vector3(float(boss.x), 0, float(boss.z) + 9.0)
	Edifici.scatola(Vector3(6.0, 0.5, 3.0), altare + Vector3(0, 0.25, 0), muro, self)
	Edifici.scatola(Vector3(4.0, 0.5, 2.0), altare + Vector3(0, 0.75, 0), muro, self)
	for sx in [-1.0, 1.0]:
		Edifici.cilindro(0.5, 0.6, 5.0, altare + Vector3(sx * 4.0, 2.5, 0), muro, self, 10)
		Edifici.scatola(Vector3(0.5, 0.5, 0.5), altare + Vector3(sx * 4.0, 5.3, 0), Edifici.mat(Color(1.0, 0.35, 0.2), 0.5, 0.0, 6.0), self)


func _lanterna(pos: Vector3, lume: Material, ferro: Material, colore: Color) -> void:
	Edifici.scatola(Vector3(0.03, ALTEZZA - pos.y, 0.03), Vector3(pos.x, (ALTEZZA + pos.y) * 0.5, pos.z), ferro, self)
	Edifici.scatola(Vector3(0.5, 0.08, 0.5), pos + Vector3(0, 0.3, 0), ferro, self)
	Edifici.scatola(Vector3(0.36, 0.5, 0.36), pos, lume, self)
	var l := OmniLight3D.new()
	l.light_color = colore
	l.light_energy = 7.0
	l.omni_range = 17.0
	l.omni_attenuation = 0.9
	l.position = pos + Vector3(0, -0.4, 0)
	add_child(l)
	_luci.append(l)


## Il renderer leggero regge poche luci insieme: restano accese solo le lanterne vicine alla visuale.
func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var qui := cam.global_position
	for l: OmniLight3D in _luci:
		l.visible = l.global_position.distance_squared_to(qui) < 42.0 * 42.0
