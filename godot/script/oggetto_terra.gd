class_name OggettoTerra
extends Node3D
## Un oggetto caduto a terra, riconoscibile «in piccolo» (0,4-0,6 m): un modellino dell'oggetto vero costruito da codice
## (armi con le stesse forme che si hanno in mano, `forme_armi.gd`), che gira piano, con un alone sul terreno e una
## sottile colonna di luce nel colore della rarità (più alta e più viva per le rarità alte; i comuni sono discreti).
## Leggero: nessuna luce dinamica, meshes semplici condivise dalla cache dei materiali; le particelle solo dall'Epico in su.
##   OggettoTerra.crea(info) -> nodo da aggiungere; info = {it, n, up, r} come nel messaggio `v` del server.
## Per tipo: weapon (spada, pugnali, arco, pugni, bastone nel grado `tier`), body, head, feet, potion, scroll, book,
## seal, key, mod, gem, material (forma dalle parole dell'id) e il tael (id «tael»: pila di monete). Id sconosciuti: sacchetto.

const Forme := preload("res://script/forme_armi.gd")
const SH_COLONNA := preload("res://shader/oggetto_colonna.gdshader")

## altezza della colonna e intensità per rarità
const COLONNA_ALTA := [0.9, 1.7, 2.5, 3.5, 4.6]
const COLONNA_FORZA := [0.10, 0.18, 0.27, 0.36, 0.46]
const ALONE_RAGGIO := [0.38, 0.5, 0.6, 0.72, 0.9]

var id := ""
var rar := 0
var up := 0
var quantita := 1
var colore := Color.WHITE
var _piv: Node3D
var _fisso := false
var _quota := 0.06
var _taglia := 0.56                 # dimensione massima del modellino (m): le armi, sottili, sono un po' più grandi
var _fase := 0.0
var _t := 0.0
var _colonna: MeshInstance3D
var _lampo := 0.0

static var _mat_vetro: StandardMaterial3D = null
static var _mat_alone: Dictionary = {}
static var _mesh_alone: QuadMesh = null


static func crea(info: Dictionary) -> OggettoTerra:
	var o := OggettoTerra.new()
	o.id = String(info.get("it", ""))
	o.up = int(info.get("up", 0))
	o.quantita = int(info.get("n", 1)) if info.get("n") != null else 1
	o.rar = IconeOggetti.rarita(o.id, info)
	o.colore = IconeOggetti.colore_rarita(o.rar)
	o._fase = randf() * TAU
	o._costruisci()
	return o


## Nome da mostrare nell'etichetta: «Spada di Giada +3», «Zanna di Lupo ×2», «120 tael».
static func nome_di(info: Dictionary) -> String:
	var i := String(info.get("it", ""))
	var n := int(info.get("n", 1)) if info.get("n") != null else 1
	if i == "tael":
		return "%d tael" % n
	var t := String(Dati.ITEMS.get(i, {}).get("name", "Oggetto"))
	if int(info.get("up", 0)) > 0:
		t += " +%d" % int(info.up)
	if n > 1:
		t += " ×%d" % n
	return t


func _costruisci() -> void:
	var it: Dictionary = Dati.ITEMS.get(id, {})
	# alone sul terreno
	var al := MeshInstance3D.new()
	al.mesh = _quad_alone()
	al.material_override = _alone(colore, rar)
	al.rotation.x = -PI / 2.0
	al.position.y = 0.04
	al.scale = Vector3.ONE * ALONE_RAGGIO[rar] * 2.0
	al.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(al)
	# colonna di luce
	var h: float = COLONNA_ALTA[rar]
	var cm := CylinderMesh.new()
	cm.top_radius = 0.012 + 0.004 * rar
	cm.bottom_radius = 0.035 + 0.008 * rar
	cm.height = h
	cm.radial_segments = 8
	cm.rings = 1
	var sm := ShaderMaterial.new()
	sm.shader = SH_COLONNA
	sm.set_shader_parameter("colore", colore)
	sm.set_shader_parameter("forza", COLONNA_FORZA[rar])
	sm.set_shader_parameter("fase", _fase)
	_colonna = MeshInstance3D.new()
	_colonna.mesh = cm
	_colonna.material_override = sm
	_colonna.position.y = h * 0.5
	_colonna.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_colonna)
	# modellino
	_piv = Node3D.new()
	add_child(_piv)
	var incl := Node3D.new()
	_piv.add_child(incl)
	var g := clampi(int(it.get("tier", 1)), 1, 4)
	if id == "tael":
		_monete(incl)
	else:
		match String(it.get("type", "")):
			"weapon": _arma(incl, String(it.get("wt", "sword")), g)
			"body": _corazza(incl, g)
			"head": _elmo(incl, g)
			"feet": _calzari(incl, g)
			"potion": _pozione(incl, it)
			"scroll": _rotolo(incl, IconeOggetti.colore_oggetto(it, Color(0.7, 0.5, 0.2)))
			"book": _libro(incl, IconeOggetti.colore_oggetto(it, Color(0.2, 0.5, 0.35)))
			"seal": _sigillo(incl, IconeOggetti.colore_oggetto(it, Color(0.8, 0.7, 0.3)))
			"key": _chiave(incl, IconeOggetti.colore_oggetto(it, Color(0.7, 0.2, 0.2)))
			"mod": _modificatore(incl, String(it.get("mod", "")), IconeOggetti.colore_oggetto(it, Color(0.5, 0.5, 0.6)))
			"gem": _gemma(incl, it)
			_: _materiale(incl, it)
	_poggia(incl, 0.05 if _fisso else 0.0)
	if rar >= 3:
		var n := 8 if rar == 3 else 14
		var p := Equip.particelle(self, n, 0.07, 1.8, colore.lightened(0.3), colore, 0.9)
		p.position = Vector3(0, 0.1, 0)
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.3
		p.direction = Vector3.UP
		p.spread = 20.0
		p.initial_velocity_min = 0.25
		p.initial_velocity_max = 0.6
	# alla caduta di un oggetto raro o migliore: un lampo della colonna
	if rar >= 2:
		_lampo = 1.0


func _process(dt: float) -> void:
	_t += dt
	if _piv != null:
		_piv.rotation.y += dt * 0.9
		_piv.position.y = _quota + (0.0 if _fisso else 0.035 * sin(_t * 1.7 + _fase))
	if _lampo > 0.0 and _colonna != null:
		_lampo = maxf(0.0, _lampo - dt * 1.1)
		var sm := _colonna.material_override as ShaderMaterial
		sm.set_shader_parameter("forza", COLONNA_FORZA[rar] + _lampo * 1.6)
		_colonna.scale.x = 1.0 + _lampo * 2.2
		_colonna.scale.z = 1.0 + _lampo * 2.2


# ------------------------------------------------------------------ messa a terra
## Riquadro del modellino nello spazio di `n` (tutti i figli con le loro trasformazioni).
static func _riquadro(n: Node3D, t: Transform3D) -> Array:
	var ok := false
	var r := AABB()
	for c in n.get_children():
		if not (c is Node3D):
			continue
		var tc: Transform3D = t * (c as Node3D).transform
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			var a: AABB = tc * (c as MeshInstance3D).mesh.get_aabb()
			r = a if not ok else r.merge(a)
			ok = true
		var sub := _riquadro(c, tc)
		if sub[0]:
			r = sub[1] if not ok else r.merge(sub[1])
			ok = true
	return [ok, r]


## Centra il modellino sull'origine e lo appoggia al suolo (o lo affonda un po': armi infilzate).
func _poggia(incl: Node3D, affondo := 0.0) -> void:
	var rq := _riquadro(incl.get_parent(), Transform3D.IDENTITY)
	if not rq[0]:
		return
	var bb: AABB = rq[1]
	var c := bb.get_center()
	incl.position += Vector3(-c.x, -bb.position.y - affondo, -c.z)
	# un oggetto molto grande si rimpicciolisce (resta sotto ~0,6 m), uno minuscolo si ingrandisce
	var alto := maxf(bb.size.y, maxf(bb.size.x, bb.size.z))
	if alto > _taglia * 1.15 or alto < 0.38:
		var f := clampf((_taglia if alto > 0.38 else 0.46) / maxf(alto, 0.01), 0.3, 3.0)
		incl.scale *= f
		incl.position *= f


func _mat(c: Color, ruv := 0.7) -> StandardMaterial3D:
	return Forme.opaco(c, ruv)


func _met(c: Color) -> StandardMaterial3D:
	return Forme.acciaio(c, 0.32)


func _lum(c: Color, en := 1.4) -> StandardMaterial3D:
	return Forme.luce(c, en)


static func _vetro() -> StandardMaterial3D:
	if _mat_vetro == null:
		_mat_vetro = StandardMaterial3D.new()
		_mat_vetro.albedo_color = Color(0.85, 0.95, 1.0, 0.34)
		_mat_vetro.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_vetro.roughness = 0.1
		_mat_vetro.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _mat_vetro


static func _quad_alone() -> QuadMesh:
	if _mesh_alone == null:
		_mesh_alone = QuadMesh.new()
		_mesh_alone.size = Vector2.ONE
	return _mesh_alone


static func _alone(c: Color, r: int) -> StandardMaterial3D:
	var k := "%s|%d" % [c.to_html(), r]
	if _mat_alone.has(k):
		return _mat_alone[k]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = Equip.alone()
	m.albedo_color = Color(c.r, c.g, c.b, [0.4, 0.55, 0.7, 0.85, 1.0][r])
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_mat_alone[k] = m
	return m


# ------------------------------------------------------------------ armi: le forme che si hanno in mano, in piccolo
func _arma(incl: Node3D, wt: String, g: int) -> void:
	_taglia = 0.78 if wt in ["sword", "staff", "bow"] else 0.62
	match wt:
		"daggers":
			# due pugnali infilzati, inclinati uno verso l'altro
			for s in [-1.0, 1.0]:
				var p := Node3D.new()
				incl.add_child(p)
				p.position = Vector3(s * 0.07, 0, 0)
				p.rotation = Vector3(PI, 0, s * 0.3)
				p.scale = Vector3.ONE * 0.62
				Forme.pugnale(p, g)
			_fisso = true
		"bow":
			var p := Node3D.new()
			incl.add_child(p)
			var punte: Array = Forme.arco(p, g)
			# la corda tesa fra le punte
			var a: Vector3 = punte[0]
			var b: Vector3 = punte[1]
			var l := a.distance_to(b)
			var corda := Forme.cil(0.004, 0.004, l, (a + b) * 0.5, Forme.opaco(Color(0.95, 0.93, 0.85)), p)
			corda.basis = Basis(Quaternion(Vector3.UP, (a - b).normalized()))
			p.rotation = Vector3(0.0, -PI / 2.0, 0.22)
			p.scale = Vector3.ONE * 0.27
			_fisso = true
		"fists":
			for s in [-1.0, 1.0]:
				var p := Node3D.new()
				incl.add_child(p)
				p.position = Vector3(s * 0.16, 0, 0)
				p.rotation = Vector3(-0.15, s * 0.5, 0)
				p.scale = Vector3.ONE * 1.0
				Forme.pugni(p, g, s)
			_quota = 0.05
		"staff":
			var p := Node3D.new()
			incl.add_child(p)
			Forme.bastone(p, g, 1.14)
			p.scale = Vector3.ONE * 0.19
			p.rotation.z = 0.2
			_fisso = true
		_:
			var p := Node3D.new()
			incl.add_child(p)
			Forme.spada(p, g)
			p.rotation = Vector3(PI, 0, 0.18)
			p.scale = Vector3.ONE * [0.40, 0.38, 0.34, 0.31][g - 1]
			_fisso = true
	if _fisso:
		_quota = -0.0


# ------------------------------------------------------------------ armature
func _corazza(incl: Node3D, g: int) -> void:
	var panno: Color = [Color(0.82, 0.74, 0.54), Color(0.62, 0.18, 0.14), Color(0.28, 0.76, 0.60), Color(0.20, 0.24, 0.52)][g - 1]
	var piastra: Color = [Color(0.7, 0.62, 0.45), Color(0.80, 0.32, 0.22), Color(0.50, 0.94, 0.78), Color(0.38, 0.44, 0.80)][g - 1]
	var oro := Color(0.92, 0.74, 0.30)
	var mp := _mat(panno, 0.75)
	var ml := _met(piastra)
	var mo := _met(oro)
	Forme.cil(0.15, 0.17, 0.3, Vector3(0, 0.15, 0), mp, incl, Vector3.ZERO, 14)
	Forme.cil(0.18, 0.18, 0.05, Vector3(0, 0.05, 0), mo if g > 1 else _mat(Color(0.5, 0.36, 0.2)), incl, Vector3.ZERO, 14)
	for s in [-1.0, 1.0]:
		Forme.cil(0.05, 0.06, 0.2, Vector3(s * 0.24, 0.26, 0), mp, incl, Vector3(0, 0, -s * 1.1))
		if g >= 2:
			var r := 0.085 if g == 2 else 0.1
			Forme.sfera(r, Vector3(s * 0.19, 0.31, 0), ml, incl, Vector3(1.1, 0.6, 1.0))
	if g >= 2:
		for i in 3:
			Forme.cil(0.172 + 0.004 * i, 0.172 + 0.004 * i, 0.03, Vector3(0, 0.08 + i * 0.08, 0), ml, incl, Vector3.ZERO, 14)
	match g:
		3:
			Forme.sfera(0.035, Vector3(0, 0.22, 0.15), _lum(Color(0.4, 1.0, 0.8), 1.2), incl)
			Forme.anello(0.045, 0.008, mo, incl, Vector3(0, 0.22, 0.15), Vector3(PI / 2, 0, 0))
		4:
			for s in [-1.0, 1.0]:
				for i in 3:
					Forme.cil(0.0, 0.025, 0.14, Vector3(s * (0.22 + i * 0.03), 0.38 + i * 0.01, 0), mo, incl, Vector3(0, 0, -s * (0.5 + i * 0.35)))
			Forme.sfera(0.04, Vector3(0, 0.25, 0.155), _lum(Color(0.5, 0.7, 1.0), 1.6), incl)


func _elmo(incl: Node3D, g: int) -> void:
	match g:
		1:
			Forme.cil(0.0, 0.27, 0.15, Vector3(0, 0.1, 0), _mat(Color(0.94, 0.82, 0.46), 0.9), incl, Vector3.ZERO, 16)
			Forme.cil(0.27, 0.27, 0.012, Vector3(0, 0.03, 0), _mat(Color(0.8, 0.66, 0.32), 0.9), incl, Vector3.ZERO, 16)
		2:
			var br := Color(0.86, 0.58, 0.28)
			Forme.sfera(0.17, Vector3(0, 0.14, 0), _met(br), incl, Vector3(1, 0.85, 1.05), 14)
			Forme.cil(0.18, 0.18, 0.03, Vector3(0, 0.06, 0), _met(br.darkened(0.2)), incl, Vector3.ZERO, 14)
			Forme.scatola(Vector3(0.025, 0.1, 0.02), Vector3(0, 0.06, 0.17), _met(br), incl)
			Forme.cil(0.0, 0.02, 0.1, Vector3(0, 0.34, 0), _mat(Color(0.7, 0.12, 0.1)), incl)
		3:
			var fe := Color(0.5, 0.52, 0.64)
			Forme.sfera(0.17, Vector3(0, 0.14, 0), _met(fe), incl, Vector3(1, 0.85, 1.05), 14)
			Forme.cil(0.18, 0.18, 0.03, Vector3(0, 0.07, 0), _met(Color(0.92, 0.72, 0.3)), incl, Vector3.ZERO, 14)
			for s in [-1.0, 1.0]:
				Forme.tubo([Vector3(s * 0.16, 0.14, 0), Vector3(s * 0.25, 0.2, 0), Vector3(s * 0.3, 0.32, 0), Vector3(s * 0.28, 0.46, 0)], [0.028, 0.022, 0.015, 0.003], _mat(Color(0.94, 0.9, 0.8)), incl)
			Forme.scatola(Vector3(0.16, 0.07, 0.02), Vector3(0, 0.08, 0.17), _mat(Color(0.05, 0.05, 0.08)), incl)
		_:
			var rs := Color(0.5, 0.14, 0.18)
			var oro := Color(0.95, 0.76, 0.3)
			Forme.sfera(0.17, Vector3(0, 0.14, 0), _met(rs), incl, Vector3(1, 0.85, 1.05), 14)
			Forme.cil(0.18, 0.18, 0.03, Vector3(0, 0.07, 0), _met(oro), incl, Vector3.ZERO, 14)
			for i in 5:
				var h := 0.08 + (2 - absi(i - 2)) * 0.04
				Forme.scatola(Vector3(0.025, h, 0.02), Vector3((i - 2) * 0.05, 0.28 + h * 0.4, 0), _met(oro), incl)
			for s in [-1.0, 1.0]:
				Forme.tubo([Vector3(s * 0.16, 0.14, 0), Vector3(s * 0.28, 0.17, 0), Vector3(s * 0.34, 0.3, 0), Vector3(s * 0.28, 0.42, 0)], [0.026, 0.02, 0.014, 0.003], _met(oro), incl)
				Forme.sfera(0.02, Vector3(s * 0.07, 0.13, 0.17), _lum(Color(1.0, 0.7, 0.2), 2.0), incl)


func _calzari(incl: Node3D, g: int) -> void:
	var col: Color = [Color(0.84, 0.70, 0.40), Color(0.60, 0.36, 0.18), Color(0.20, 0.64, 0.72), Color(0.90, 0.88, 1.0)][g - 1]
	var m := _mat(col, 0.75)
	var suola := _mat(Color(0.2, 0.13, 0.1), 0.9)
	for s in [-1.0, 1.0]:
		var x: float = s * 0.1
		if g == 1:
			Forme.scatola(Vector3(0.1, 0.02, 0.26), Vector3(x, 0.01, 0.0), m, incl)
			for z in [-0.04, 0.05]:
				Forme.scatola(Vector3(0.1, 0.02, 0.012), Vector3(x, 0.03, z), _mat(Color(0.95, 0.84, 0.5)), incl)
			Forme.scatola(Vector3(0.012, 0.1, 0.03), Vector3(x - 0.04, 0.07, -0.1), _mat(Color(0.95, 0.84, 0.5)), incl)
			Forme.scatola(Vector3(0.012, 0.1, 0.03), Vector3(x + 0.04, 0.07, -0.1), _mat(Color(0.95, 0.84, 0.5)), incl)
		else:
			Forme.scatola(Vector3(0.1, 0.2, 0.1), Vector3(x, 0.14, -0.05), m, incl)
			Forme.scatola(Vector3(0.1, 0.075, 0.2), Vector3(x, 0.05, 0.03), m, incl)
			Forme.scatola(Vector3(0.105, 0.02, 0.26), Vector3(x, 0.0, 0.0), suola, incl)
			Forme.scatola(Vector3(0.11, 0.035, 0.11), Vector3(x, 0.255, -0.05), _mat(col.lightened(0.25)), incl)
			if g == 3:
				for k in 3:
					Forme.foglia(0.1, 0.03, _mat(Color(1, 1, 1)), incl, Vector3(x + s * 0.06, 0.14 + k * 0.025, -0.06), Vector3(0, 0, 0.5 * s + (0 if s > 0 else PI) + (k - 1) * 0.3 * s), 0.01)
			if g == 4:
				Forme.sfera(0.03, Vector3(x, 0.255, 0.01), _lum(Color(0.5, 0.8, 1.0), 1.4), incl)
				Forme.cil(0.11, 0.11, 0.02, Vector3(x, 0.025, 0.02), _met(Color(0.95, 0.76, 0.3)), incl, Vector3.ZERO, 10)
	_quota = 0.03


# ------------------------------------------------------------------ pozioni, rotoli, libri
func _pozione(incl: Node3D, it: Dictionary) -> void:
	var nome_icona := ""
	if Icone.MAPPA.has(id):
		nome_icona = String(Icone.MAPPA[id][1])
	var c := IconeOggetti.colore_oggetto(it, Color(0.7, 0.2, 0.2))
	var pr := float(it.get("price", 100))
	var sc := 0.85 if pr < 60 else (1.0 if pr < 200 else 1.2)
	if nome_icona.begins_with("te_"):
		Forme.cil(0.11 * sc, 0.065 * sc, 0.09 * sc, Vector3(0, 0.045 * sc, 0), _mat(Color(0.93, 0.95, 1.0), 0.3), incl, Vector3.ZERO, 14)
		Forme.cil(0.095 * sc, 0.095 * sc, 0.005, Vector3(0, 0.085 * sc, 0), _lum(c.lightened(0.2), 1.1), incl, Vector3.ZERO, 14)
		return
	Forme.sfera(0.085 * sc, Vector3(0, 0.09 * sc, 0), _lum(c, 0.8), incl, Vector3(1, 1.05, 1), 12)
	Forme.sfera(0.095 * sc, Vector3(0, 0.1 * sc, 0), _vetro(), incl, Vector3(1, 1.05, 1), 12)
	Forme.cil(0.028 * sc, 0.034 * sc, 0.09 * sc, Vector3(0, 0.2 * sc, 0), _vetro(), incl)
	Forme.cil(0.03 * sc, 0.03 * sc, 0.035 * sc, Vector3(0, 0.27 * sc, 0), _mat(Color(0.5, 0.34, 0.18)), incl)


func _rotolo(incl: Node3D, c: Color) -> void:
	var carta := _mat(Color(0.93, 0.86, 0.68), 0.9)
	Forme.cil(0.04, 0.04, 0.3, Vector3(0, 0.04, 0), carta, incl, Vector3(0, 0, PI / 2), 10)
	for s in [-1.0, 1.0]:
		Forme.cil(0.022, 0.022, 0.05, Vector3(s * 0.16, 0.04, 0), _mat(Color(0.5, 0.3, 0.16)), incl, Vector3(0, 0, PI / 2), 8)
		Forme.sfera(0.03, Vector3(s * 0.19, 0.04, 0), _mat(Color(0.5, 0.3, 0.16)), incl)
	Forme.cil(0.046, 0.046, 0.04, Vector3(0, 0.04, 0), _mat(c, 0.6), incl, Vector3(0, 0, PI / 2), 10)
	Forme.sfera(0.028, Vector3(0, 0.04, 0.045), _lum(Color(0.9, 0.2, 0.15), 0.8), incl)
	_quota = 0.03


func _libro(incl: Node3D, c: Color) -> void:
	Forme.scatola(Vector3(0.22, 0.05, 0.3), Vector3(0, 0.04, 0), _mat(c, 0.6), incl)
	Forme.scatola(Vector3(0.2, 0.034, 0.28), Vector3(0.012, 0.04, 0.0), _mat(Color(0.93, 0.88, 0.74)), incl)
	Forme.scatola(Vector3(0.22, 0.012, 0.3), Vector3(0, 0.07, 0), _mat(c, 0.6), incl)
	Forme.scatola(Vector3(0.03, 0.062, 0.3), Vector3(-0.1, 0.04, 0), _mat(c.darkened(0.3)), incl)
	Forme.cil(0.05, 0.05, 0.006, Vector3(0.0, 0.079, 0), _met(Color(0.92, 0.74, 0.3)), incl, Vector3.ZERO, 10)
	_quota = 0.02


func _sigillo(incl: Node3D, c: Color) -> void:
	Forme.scatola(Vector3(0.2, 0.09, 0.2), Vector3(0, 0.045, 0), _met(c), incl)
	Forme.cil(0.05, 0.07, 0.1, Vector3(0, 0.14, 0), _met(c.lightened(0.15)), incl)
	Forme.sfera(0.06, Vector3(0, 0.22, 0), _met(c.lightened(0.2)), incl)
	Forme.scatola(Vector3(0.17, 0.012, 0.17), Vector3(0, 0.0, 0), _mat(Color(0.8, 0.12, 0.1)), incl)


func _chiave(incl: Node3D, c: Color) -> void:
	var oro := _met(Color(0.92, 0.74, 0.3))
	Forme.anello(0.07, 0.016, oro, incl, Vector3(0, 0.02, 0.17), Vector3.ZERO)
	Forme.sfera(0.03, Vector3(0, 0.02, 0.17), _lum(c, 1.3), incl)
	Forme.cil(0.014, 0.014, 0.3, Vector3(0, 0.02, -0.02), oro, incl, Vector3(PI / 2, 0, 0))
	for k in 3:
		Forme.scatola(Vector3(0.04, 0.02, 0.025), Vector3(0.03, 0.02, -0.12 + k * 0.03), oro, incl)
	_quota = 0.03


func _modificatore(incl: Node3D, mod: String, c: Color) -> void:
	match mod:
		"refine":
			Forme.scatola(Vector3(0.28, 0.07, 0.12), Vector3(0, 0.035, 0), _mat(Color(0.52, 0.58, 0.64), 0.4), incl)
			Forme.scatola(Vector3(0.28, 0.01, 0.12), Vector3(0, 0.073, 0), _met(Color(0.78, 0.84, 0.9)), incl)
		"reroll":
			_rotolo(incl, Color(0.6, 0.2, 0.5))
		"ascend":
			_sigillo(incl, c.lerp(Color(0.62, 0.4, 0.95), 0.5))
			Forme.cil(0.0, 0.06, 0.14, Vector3(0, 0.38, 0), _lum(Color(1.0, 0.88, 0.4), 1.4), incl)
		"extract":
			Forme.cil(0.022, 0.022, 0.14, Vector3(0, 0.03, 0.1), _mat(Color(0.55, 0.36, 0.18)), incl, Vector3(PI / 2, 0, 0))
			Forme.cil(0.014, 0.014, 0.2, Vector3(0, 0.03, -0.07), _met(Color(0.85, 0.88, 0.95)), incl, Vector3(PI / 2, 0, 0))
			Forme.cil(0.0, 0.014, 0.05, Vector3(0, 0.03, -0.2), _met(Color(0.85, 0.88, 0.95)), incl, Vector3(-PI / 2, 0, 0))
		_:
			Forme.sfera(0.12, Vector3(0, 0.1, 0), _mat(Color(0.6, 0.58, 0.54), 0.8), incl, Vector3(1, 0.8, 1), 8)
			Forme.sfera(0.03, Vector3(0, 0.2, 0), _lum(c.lightened(0.3), 1.4), incl)
	_quota = 0.03


# ------------------------------------------------------------------ gemme e materiali
func _gemma(incl: Node3D, it: Dictionary) -> void:
	var c := IconeOggetti.colore_oggetto(it, Color(0.8, 0.3, 0.3))
	if c.get_luminance() < 0.2:
		c = c.lightened(0.35)
	var kind := String(it.get("gem", ""))
	var gr := int(it.get("grade", 1))
	if gr <= 0:
		for q in [[-0.07, 0.0, 0.05, 0.5], [0.07, 0.01, 0.03, -0.6], [0.0, 0.0, -0.06, 0.2]]:
			var n := Node3D.new()
			incl.add_child(n)
			n.position = Vector3(q[0], 0.0, q[2])
			n.rotation = Vector3(q[3], q[3] * 2.0, q[3])
			_cristallo(n, c, 0.55)
		return
	var sc := 1.0 if gr == 1 else 1.4
	match kind:
		"perla":
			Forme.sfera(0.1 * sc, Vector3(0, 0.1 * sc, 0), _met(Color(0.96, 0.95, 1.0)), incl, Vector3.ONE, 14)
		"giada":
			Forme.anello(0.1 * sc, 0.04 * sc, _lum(c, 0.7), incl, Vector3(0, 0.12 * sc, 0), Vector3(PI / 2 - 0.5, 0, 0), 18)
		"ambra":
			Forme.sfera(0.1 * sc, Vector3(0, 0.11 * sc, 0), _lum(c, 0.9), incl, Vector3(0.85, 1.15, 0.7), 12)
		_:
			_cristallo(incl, c, sc * 1.0)
	if gr >= 2:
		Forme.sfera(0.03, Vector3(0, 0.36, 0), _lum(Color(1, 1, 1), 2.0), incl)


## Cristallo a doppia punta (due coni) nel colore dato.
func _cristallo(n: Node3D, c: Color, sc: float) -> void:
	Forme.cil(0.0, 0.085 * sc, 0.16 * sc, Vector3(0, 0.22 * sc, 0), _lum(c, 1.0), n, Vector3.ZERO, 6)
	Forme.cil(0.085 * sc, 0.0, 0.14 * sc, Vector3(0, 0.07 * sc, 0), _lum(c.darkened(0.1), 0.8), n, Vector3.ZERO, 6)


func _materiale(incl: Node3D, it: Dictionary) -> void:
	var c := IconeOggetti.colore_oggetto(it, Color(0.6, 0.55, 0.45))
	_quota = 0.03
	match IconeOggetti.forma_materiale(id, it):
		"zanna":
			for q in [[-0.06, 0.4], [0.06, -0.5]]:
				var n := Node3D.new()
				incl.add_child(n)
				n.position = Vector3(q[0], 0.05, 0)
				n.rotation = Vector3(PI / 2, 0, q[1])
				Forme.cil(0.035, 0.0, 0.22, Vector3.ZERO, _mat(Color(0.96, 0.92, 0.8), 0.5), n, Vector3.ZERO, 8)
		"pelle":
			Forme.scatola(Vector3(0.3, 0.025, 0.24), Vector3(0, 0.015, 0), _mat(c.lightened(0.1), 0.95), incl, Vector3(0, 0.3, 0))
			Forme.scatola(Vector3(0.22, 0.02, 0.18), Vector3(0.03, 0.035, 0.02), _mat(c.darkened(0.15), 0.95), incl, Vector3(0, -0.4, 0))
		"benda":
			Forme.cil(0.09, 0.09, 0.16, Vector3(0, 0.09, 0), _mat(c, 0.9), incl, Vector3(PI / 2, 0, 0), 12)
			Forme.scatola(Vector3(0.05, 0.01, 0.16), Vector3(0.12, 0.01, 0.1), _mat(c.lightened(0.1), 0.9), incl, Vector3(0, 0.5, 0))
		"coccio":
			for q in [[0.0, 0.0, 0.5], [0.09, 0.06, -0.8], [-0.08, -0.07, 1.4]]:
				Forme.scatola(Vector3(0.14, 0.02, 0.1), Vector3(q[0], 0.03, q[1]), _mat(c, 0.9), incl, Vector3(0.25, q[2], 0.2))
		"lingotto":
			Forme.scatola(Vector3(0.26, 0.09, 0.12), Vector3(0, 0.045, 0), _met(c.lightened(0.2)), incl)
			Forme.scatola(Vector3(0.24, 0.02, 0.1), Vector3(0, 0.1, 0), _met(c.lightened(0.5)), incl)
		"essenza":
			Forme.sfera(0.1, Vector3(0, 0.12, 0), _lum(c, 1.5), incl, Vector3.ONE, 12)
			Forme.sfera(0.04, Vector3(0, 0.26, 0), _lum(c.lightened(0.4), 1.5), incl, Vector3(0.6, 1.2, 0.6))
		"osso":
			Forme.cil(0.025, 0.025, 0.26, Vector3(0, 0.04, 0), _mat(Color(0.93, 0.9, 0.8), 0.7), incl, Vector3(0, 0, PI / 2), 8)
			for s in [-1.0, 1.0]:
				Forme.sfera(0.04, Vector3(s * 0.13, 0.04, 0.02), _mat(Color(0.93, 0.9, 0.8), 0.7), incl)
				Forme.sfera(0.04, Vector3(s * 0.13, 0.04, -0.02), _mat(Color(0.93, 0.9, 0.8), 0.7), incl)
		"erba":
			for q in [-0.7, 0.0, 0.7]:
				Forme.foglia(0.22, 0.07, _mat(Color(0.4, 0.78, 0.34)), incl, Vector3(0, 0.02, 0), Vector3(0, q, 1.1), 0.01)
		"cristallo":
			_cristallo(incl, c.lightened(0.2), 1.5)
		"minerale":
			Forme.sfera(0.13, Vector3(0, 0.08, 0), _mat(c.lightened(0.15), 0.6), incl, Vector3(1.1, 0.7, 0.9), 7)
			for q in [[0.05, 0.14, 0.06], [-0.07, 0.1, 0.09], [0.1, 0.07, -0.05]]:
				Forme.scatola(Vector3(0.03, 0.03, 0.03), Vector3(q[0], q[1], q[2]), _met(Color(0.85, 0.92, 1.0)), incl, Vector3(0.5, 0.5, 0.5))
		_:
			# sacchetto legato
			var m := _mat(c.lightened(0.1) if c.get_luminance() < 0.2 else c, 0.9)
			Forme.sfera(0.12, Vector3(0, 0.11, 0), m, incl, Vector3(1, 1, 1), 10)
			Forme.cil(0.03, 0.06, 0.06, Vector3(0, 0.24, 0), m, incl)
			Forme.cil(0.05, 0.05, 0.015, Vector3(0, 0.215, 0), _mat(Color(0.5, 0.34, 0.18)), incl)


func _monete(incl: Node3D) -> void:
	var oro := _met(Color(1.0, 0.82, 0.3))
	for q in [[-0.09, 0.03, 4], [0.09, -0.02, 6], [0.0, 0.09, 3]]:
		for i in int(q[2]):
			Forme.cil(0.075, 0.075, 0.016, Vector3(q[0], 0.008 + i * 0.018, q[1]), oro, incl, Vector3.ZERO, 12)
	_quota = 0.02
