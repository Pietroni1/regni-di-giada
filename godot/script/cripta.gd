class_name Cripta
extends Node3D
## Le Prove del Sigillo: stanze e muri dalla definizione della Prova (PROVE in shared/data.js: la Cripta delle Mille
## Lanterne e la Forgia del Drago Addormentato), costruiti all'origine dell'istanza che il server comunica con `dg_start`.
## La Forgia ha un suo `tema`: muri bruniti, lumi arancio, canali di lava, incudini e la grande fornace del boss.

const ALTEZZA := 6.5

var origine := Vector2.ZERO
var definizione: Dictionary = {}
var _luci: Array = []


static func crea(ox: float, oz: float, id := "cripta") -> Cripta:
	var c := Cripta.new()
	c.origine = Vector2(ox, oz)
	c.definizione = Dati.gioco.get("PROVE", {}).get(id, Dati.gioco.DUNGEON)
	c.position = Vector3(ox, 0, oz)
	c._costruisci()
	return c


## Il punto (coordinate del mondo) è calpestabile? Come dungeonWalkable in shared/data.js.
func calpestabile(x: float, z: float, margine := 0.5) -> bool:
	var lx := x - origine.x
	var lz := z - origine.y
	for r in definizione.rooms:
		if lx >= float(r[0]) + margine and lx <= float(r[2]) - margine and lz >= float(r[1]) + margine and lz <= float(r[3]) - margine:
			return true
	return false


## Il punto calpestabile più vicino a (x, z): serve a liberare chi è finito dentro un muro.
func piu_vicino(x: float, z: float, margine := 0.6) -> Vector2:
	var lx := x - origine.x
	var lz := z - origine.y
	var meglio := Vector2(lx, lz)
	var md := INF
	for r in definizione.rooms:
		var q := Vector2(clampf(lx, float(r[0]) + margine, float(r[2]) - margine), clampf(lz, float(r[1]) + margine, float(r[3]) - margine))
		var d := q.distance_squared_to(Vector2(lx, lz))
		if d < md:
			md = d
			meglio = q
	return meglio + origine


func _costruisci() -> void:
	var D: Dictionary = definizione
	var tema: Dictionary = D.get("tema", {})
	var pav := ShaderMaterial.new()
	pav.shader = preload("res://shader/pavimento.gdshader")
	var muro := ShaderMaterial.new()
	muro.shader = preload("res://shader/roccia.gdshader")
	muro.set_shader_parameter("muschio_forza", 0.0)
	muro.set_shader_parameter("tinta", Color.html(String(tema.muro)) if tema.has("muro") else Color(0.55, 0.52, 0.6))
	var col_lume := Color.html(String(tema.lume)) if tema.has("lume") else Color(1.0, 0.68, 0.36)
	var col_boss := Color.html(String(tema.lumeBoss)) if tema.has("lumeBoss") else Color(1.0, 0.45, 0.3)
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
					_lanterna(c + Vector3(0, 3.6, 0), lume, ferro, col_boss if nella_sala_del_boss else col_lume)
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
		# zoccolo e pilastri stanno dentro il mezzo metro che il personaggio non può calpestare: niente compenetrazioni
		var zoccolo := Vector3(lung, 0.7, 0.98) if orizz else Vector3(0.98, 0.7, lung)
		Edifici.scatola(zoccolo, Vector3(centro.x, 0.35, centro.y), muro, self)
		# pilastri ogni 8 m
		var quanti := int(a.distance_to(b) / 8.0)
		for k in range(quanti + 1):
			var p := a.lerp(b, float(k) / maxf(1.0, quanti))
			Edifici.scatola(Vector3(0.98, ALTEZZA + 0.3, 0.98), Vector3(p.x, (ALTEZZA + 0.3) * 0.5, p.y), muro, self)

	if tema.has("lava"):
		_forgia(D, muro, ferro, Color.html(String(tema.lava)))
		return
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


## Arredi della Forgia: canali di lava lungo le stanze, incudini, crogioli e la grande fornace dietro il boss.
func _forgia(D: Dictionary, muro: Material, ferro: Material, lava: Color) -> void:
	var m_lava := Edifici.mat(lava, 0.3, 0.0, 6.0)
	var m_brace := Edifici.mat(lava.darkened(0.35), 0.6, 0.0, 2.5)
	var boss: Dictionary = D.boss
	var n := 0
	for r in D.rooms:
		var x1 := float(r[0])
		var z1 := float(r[1])
		var x2 := float(r[2])
		var z2 := float(r[3])
		if x2 - x1 < 12.0 or z2 - z1 < 12.0:
			continue
		# canale di lava lungo un lato della stanza, con il bordo di pietra
		var lungo := (z2 - z1) - 4.0
		var cx := x1 + 2.2 if n % 2 == 0 else x2 - 2.2
		Edifici.scatola(Vector3(1.2, 0.06, lungo), Vector3(cx, 0.03, (z1 + z2) * 0.5), m_lava, self)
		Edifici.scatola(Vector3(0.3, 0.25, lungo), Vector3(cx - 0.75, 0.12, (z1 + z2) * 0.5), muro, self)
		Edifici.scatola(Vector3(0.3, 0.25, lungo), Vector3(cx + 0.75, 0.12, (z1 + z2) * 0.5), muro, self)
		var l := OmniLight3D.new()
		l.light_color = lava
		l.light_energy = 4.0
		l.omni_range = 12.0
		l.position = Vector3(cx, 0.8, (z1 + z2) * 0.5)
		add_child(l)
		_luci.append(l)
		# incudini e crogioli
		var c := Vector3((x1 + x2) * 0.5, 0, (z1 + z2) * 0.5)
		if absf(c.x - float(boss.x)) > 10.0 or absf(c.z - float(boss.z)) > 10.0:
			for k in range(2):
				var p := c + Vector3((k * 2 - 1) * (x2 - x1) * 0.22, 0, (z2 - z1) * 0.18)
				Edifici.scatola(Vector3(0.9, 0.6, 0.6), p + Vector3(0, 0.3, 0), ferro, self)
				Edifici.scatola(Vector3(1.5, 0.3, 0.7), p + Vector3(0, 0.75, 0), ferro, self)
				Edifici.cilindro(0.5, 0.35, 0.7, p + Vector3(0, 0.35, 1.6), ferro, self, 10)
				Edifici.cilindro(0.42, 0.42, 0.06, p + Vector3(0, 0.71, 1.6), m_brace, self, 10)
		n += 1
	# la grande fornace in fondo al Cuore della Forgia: bocca ardente e due colonne
	var fondo := Vector3(float(boss.x), 0, float(boss.z) + 11.0)
	Edifici.scatola(Vector3(14.0, 9.0, 3.0), fondo + Vector3(0, 4.5, 0), muro, self)
	Edifici.scatola(Vector3(6.0, 4.0, 0.4), fondo + Vector3(0, 2.2, -1.5), m_lava, self)
	for sx in [-1.0, 1.0]:
		Edifici.cilindro(0.8, 0.9, 10.0, fondo + Vector3(sx * 6.0, 5.0, -1.8), muro, self, 12)
		Edifici.scatola(Vector3(1.0, 1.0, 1.0), fondo + Vector3(sx * 6.0, 10.4, -1.8), m_lava, self)
	var lf := OmniLight3D.new()
	lf.light_color = lava
	lf.light_energy = 9.0
	lf.omni_range = 26.0
	lf.position = fondo + Vector3(0, 3.0, -4.0)
	add_child(lf)
	_luci.append(lf)
