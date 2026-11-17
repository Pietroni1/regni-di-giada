class_name Obelisco
extends Personaggio
## Obelisco: monolite scolpito con fasce di rune che brillano, schegge di cristallo in orbita, cerchio di rune a terra,
## nucleo luminoso e scintille che salgono. Più è danneggiato più si vede (crepe accese, schegge agitate, luce che vira
## e lampeggia); alla fine si frantuma. Taglia, colore e numero di schegge derivano da `color` e `scale` di `MOBS`.
## Aggancio con `Entita`: `stato(frazione_di_vita)` a ogni cambio di vita, `ondata()` quando evoca, `muori()` / `rialza()`.

const SH_FUSTO := preload("res://shader/obelisco.gdshader")
const SH_CRISTALLO := preload("res://shader/obelisco_cristallo.gdshader")
const SH_ANELLO := preload("res://shader/fx_anello.gdshader")
const SH_PIETRA := preload("res://shader/pietra.gdshader")

## Profilo del fusto: [quota, mezza larghezza]. Poi il collare a gradino e la cuspide che si chiude in punta.
const ANELLI := [[0.45, 0.74], [4.30, 0.47], [4.38, 0.56], [4.66, 0.56], [4.72, 0.45], [6.10, 0.015]]
const Y0 := 0.45
const Y_FASCE := 4.3
const Y_PUNTA := 6.1

static var _m_cristallo: ArrayMesh = null

class Scheggia:
	var n: MeshInstance3D
	var a := 0.0        # angolo dell'orbita
	var r := 2.0        # raggio
	var y := 2.0        # quota media
	var v := 0.3        # velocità angolare (rad/s)
	var f := 1.0        # frequenza del saliscendi
	var ph := 0.0
	var spin := 1.0

class Detrito:
	var n: MeshInstance3D
	var v := Vector3.ZERO
	var w := Vector3.ZERO
	var scala := Vector3.ONE
	var raggio := 0.15
	var svanisce := 4.0     # secondi dalla frantumazione a cui inizia a rimpicciolire
	var fermo := false

class Onda:
	var mi: MeshInstance3D
	var mat: ShaderMaterial
	var t := 0.0
	var durata := 1.0

var _scala_mob := 1.0
var _t := 0.0                  # 0 obelisco minore → 1 obelisco dell'abisso (da `scale`)
var _ky := 1.0                 # allungamento del fusto
var _base_en := Color(0.7, 0.3, 1.0)
var _pietra := Color(0.3, 0.28, 0.33)
var _danno := 0.0
var _danno_t := 0.0
var _pulso := 0.0
var _colpo := 0.0
var _tempo := 0.0
var _eta := 0.0
var _fine := false
var _t_morte := 0.0

var _vivo: Node3D
var _mi_fusto: MeshInstance3D
var _mat_fusto: ShaderMaterial
var _mat_crist: ShaderMaterial
var _mat_en: StandardMaterial3D
var _luce: OmniLight3D
var _cerchio: MeshInstance3D
var _nucleo: Node3D
var _anelli_nucleo: Array = []
var _schegge: Array = []
var _detriti: Array = []
var _onde: Array = []
var _salita: CPUParticles3D
var _burst: CPUParticles3D
var _alone_nucleo: MeshInstance3D
var _alone_colonna: MeshInstance3D
var _lampo: MeshInstance3D
var _offerte: Array = []


static func crea(colore: Color, scala := 1.0) -> Personaggio:
	var o := Obelisco.new()
	o._costruisci(colore, scala)
	return o


# ------------------------------------------------------------------ mesh
## Un triangolo con la normale rivolta verso `fuori` (Godot vuole i triangoli frontali in senso orario).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, col: Color, fuori: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length() < 1e-7:
		return
	if n.dot(fuori) > 0.0:
		var tp := b
		b = c
		c = tp
		var tu := ub
		ub = uc
		uc = tu
		n = -n
	var nn := -n.normalized()
	var pts := [a, b, c]
	var uvs := [ua, ub, uc]
	for i in range(3):
		st.set_normal(nn)
		st.set_color(col)
		st.set_uv(uvs[i])
		st.add_vertex(pts[i])


static func _ruota(p: Vector2, k: int) -> Vector2:
	var q := p
	for i in range(k):
		q = Vector2(-q.y, q.x)
	return q


## Ottagono irregolare: quattro facce larghe e quattro spigoli smussati. Restituisce [A_k, B_k] (inizio e fine della faccia larga k).
static func _punti(a: float, k: int) -> Array:
	var c := a * 0.30
	return [_ruota(Vector2(a, -(a - c)), k), _ruota(Vector2(a, a - c), k)]


static func _malla_fusto(ky: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(ANELLI.size() - 1):
		var y0: float = Y0 + (float(ANELLI[i][0]) - Y0) * ky
		var y1: float = Y0 + (float(ANELLI[i + 1][0]) - Y0) * ky
		var a0: float = ANELLI[i][1]
		var a1: float = ANELLI[i + 1][1]
		for k in range(4):
			var p0 := _punti(a0, k)
			var p1 := _punti(a1, k)
			var q0 := _punti(a0, (k + 1) % 4)
			var q1 := _punti(a1, (k + 1) % 4)
			# faccia larga
			_quad(st, p0[0], p0[1], p1[1], p1[0], y0, y1, Color(1, (float(k) + 0.0) / 4.0, 0))
			# spigolo smussato
			_quad(st, p0[1], q0[0], q1[0], p1[1], y0, y1, Color(0, (float(k) + 0.5) / 4.0, 0))
	# fondo piatto non serve (poggia sul basamento)
	return st.commit()


static func _quad(st: SurfaceTool, b0: Vector2, b1: Vector2, t1: Vector2, t0: Vector2, y0: float, y1: float, col: Color) -> void:
	var v0 := Vector3(b0.x, y0, b0.y)
	var v1 := Vector3(b1.x, y0, b1.y)
	var v2 := Vector3(t1.x, y1, t1.y)
	var v3 := Vector3(t0.x, y1, t0.y)
	var fuori := Vector3((b0.x + b1.x + t1.x + t0.x) * 0.25, 0.0, (b0.y + b1.y + t1.y + t0.y) * 0.25)
	_tri(st, v0, v1, v2, Vector2(0, y0), Vector2(1, y0), Vector2(1, y1), col, fuori)
	_tri(st, v0, v2, v3, Vector2(0, y0), Vector2(1, y1), Vector2(0, y1), col, fuori)


## Cristallo allungato a sei facce, appuntito ai due capi (da -0.6 a +1.0 in altezza).
static func _malla_cristallo() -> ArrayMesh:
	if _m_cristallo != null:
		return _m_cristallo
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var anelli := [[-0.6, 0.0], [-0.15, 0.30], [0.35, 0.30], [1.0, 0.0]]
	var col := Color(1, 0, 0)
	for i in range(3):
		var ya: float = anelli[i][0]
		var yb: float = anelli[i + 1][0]
		var ra: float = anelli[i][1]
		var rb: float = anelli[i + 1][1]
		for k in range(6):
			var a0 := float(k) / 6.0 * TAU + 0.2
			var a1 := float(k + 1) / 6.0 * TAU + 0.2
			var p00 := Vector3(cos(a0) * ra, ya, sin(a0) * ra)
			var p01 := Vector3(cos(a1) * ra, ya, sin(a1) * ra)
			var p10 := Vector3(cos(a0) * rb, yb, sin(a0) * rb)
			var p11 := Vector3(cos(a1) * rb, yb, sin(a1) * rb)
			var c := (p00 + p01 + p10 + p11) * 0.25
			var fuori := c - Vector3(0, 0.2, 0)
			_tri(st, p00, p01, p11, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), col, fuori)
			_tri(st, p00, p11, p10, Vector2(0, 0), Vector2(1, 1), Vector2(0, 1), col, fuori)
	_m_cristallo = st.commit()
	return _m_cristallo


# ------------------------------------------------------------------ costruzione
func _sprite(dim: Vector2, modo: int, colore: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = dim
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = Equip.alone()
	m.albedo_color = colore
	m.billboard_mode = modo
	m.billboard_keep_scale = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _particelle(quante: int, vita: float, lato: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(lato, lato)
	p.mesh = q
	p.material_override = Equip.mat_particella()
	p.amount = quante
	p.lifetime = vita
	p.local_coords = true
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.0)])
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _costruisci(colore: Color, scala: float) -> void:
	_scala_mob = scala
	_t = clampf((scala - 1.0) / 0.3, 0.0, 1.0)
	_ky = 1.0 + 0.2 * _t
	scale = Vector3.ONE * scala
	_base_en = Color.from_hsv(colore.h, maxf(colore.s, 0.75), 1.0)
	_pietra = Color(0.30, 0.28, 0.33).lerp(colore.darkened(0.5), 0.25).lerp(Color(0.11, 0.10, 0.12), _t * 0.7)
	altezza = (Y_PUNTA * _ky + 0.6) * scala

	_vivo = Node3D.new()
	add_child(_vivo)

	_mat_en = StandardMaterial3D.new()
	_mat_en.albedo_color = Color(0.05, 0.05, 0.05)
	_mat_en.emission_enabled = true
	_mat_en.emission = _base_en
	_mat_en.emission_energy_multiplier = 2.5

	_mat_fusto = ShaderMaterial.new()
	_mat_fusto.shader = SH_FUSTO
	_mat_fusto.set_shader_parameter("pietra", Vector3(_pietra.r, _pietra.g, _pietra.b))
	_mat_fusto.set_shader_parameter("energia", Vector3(_base_en.r, _base_en.g, _base_en.b))
	_mat_fusto.set_shader_parameter("fascia_max", Y0 + (Y_FASCE - Y0) * _ky)
	_mat_crist = ShaderMaterial.new()
	_mat_crist.shader = SH_CRISTALLO
	_mat_crist.set_shader_parameter("energia", Vector3(_base_en.r, _base_en.g, _base_en.b))

	_costruisci_basamento()
	_costruisci_offerte()

	# fusto
	_mi_fusto = MeshInstance3D.new()
	_mi_fusto.mesh = _malla_fusto(_ky)
	_mi_fusto.material_override = _mat_fusto
	_vivo.add_child(_mi_fusto)

	# cerchio di rune a terra
	_cerchio = Equip.cerchio_rune(3.9, _base_en, true)
	add_child(_cerchio)

	_costruisci_nucleo()
	_costruisci_schegge()

	# scintille che salgono
	_salita = _particelle(18 + int(14.0 * _t), 3.4, 0.15)
	_salita.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_salita.emission_ring_axis = Vector3.UP
	_salita.emission_ring_height = 0.1
	_salita.emission_ring_radius = 1.7
	_salita.emission_ring_inner_radius = 0.7
	_salita.direction = Vector3.UP
	_salita.spread = 10.0
	_salita.initial_velocity_min = 0.7
	_salita.initial_velocity_max = 1.6
	_salita.gravity = Vector3(0, 0.25, 0)
	_salita.scale_amount_min = 0.5
	_salita.scale_amount_max = 1.3
	_salita.position = Vector3(0, 0.5, 0)
	_salita.color = _base_en
	_vivo.add_child(_salita)

	# lampo / scintille del colpo finale e delle ondate
	_burst = _particelle(48, 1.5, 0.22)
	_burst.one_shot = true
	_burst.emitting = false
	_burst.explosiveness = 1.0
	_burst.direction = Vector3.UP
	_burst.spread = 180.0
	_burst.initial_velocity_min = 3.0
	_burst.initial_velocity_max = 8.0
	_burst.gravity = Vector3(0, -6.0, 0)
	_burst.position = Vector3(0, 3.0, 0)
	_burst.color = _base_en
	add_child(_burst)

	_lampo = _sprite(Vector2(10, 10), BaseMaterial3D.BILLBOARD_ENABLED, Color(_base_en.r, _base_en.g, _base_en.b, 0.0))
	_lampo.position = Vector3(0, 3.0 * _ky, 0)
	_lampo.visible = false
	add_child(_lampo)

	# una sola luce dinamica
	_luce = OmniLight3D.new()
	_luce.light_color = _base_en
	_luce.light_energy = 1.4
	_luce.omni_range = 12.0
	_luce.shadow_enabled = false
	_luce.position = Vector3(0, 3.2 * _ky, 0)
	add_child(_luce)


func _costruisci_basamento() -> void:
	var m := ShaderMaterial.new()
	m.shader = SH_PIETRA
	m.set_shader_parameter("colore", Vector3(_pietra.r * 1.15, _pietra.g * 1.15, _pietra.b * 1.15))
	m.set_shader_parameter("concio", 0.6)
	var gradini := [[2.1, 0.16, 0.08], [1.7, 0.16, 0.24], [1.3, 0.16, 0.40]]
	for g in gradini:
		var c := Edifici.cilindro(float(g[0]) * 0.97, float(g[0]), float(g[1]), Vector3(0, float(g[2]), 0), m, self, 8)
		c.rotation.y = PI / 8.0
	# filetti luminosi nelle commessure fra i gradini
	for q in [[1.78, 0.165], [1.38, 0.325]]:
		var f := Edifici.cilindro(float(q[0]), float(q[0]), 0.025, Vector3(0, float(q[1]), 0), _mat_en, self, 8)
		f.rotation.y = PI / 8.0
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _costruisci_offerte() -> void:
	var m := ShaderMaterial.new()
	m.shader = SH_PIETRA
	m.set_shader_parameter("colore", Vector3(_pietra.r, _pietra.g, _pietra.b))
	m.set_shader_parameter("concio", 0.35)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	if _t < 0.5:
		# offerte: lastre di pietra con un piccolo stelo e una sfera di luce che fluttua
		for i in range(6):
			var a := float(i) / 6.0 * TAU + 0.3
			var perno := Node3D.new()
			perno.position = Vector3(cos(a) * 2.9, 0, sin(a) * 2.9)
			perno.rotation.y = -a
			add_child(perno)
			Edifici.scatola(Vector3(0.62, 0.12, 0.62), Vector3(0, 0.06, 0), m, perno)
			Edifici.scatola(Vector3(0.26, 0.42 + rng.randf() * 0.2, 0.26), Vector3(0, 0.33, 0), m, perno)
			var o := MeshInstance3D.new()
			var sf := SphereMesh.new()
			sf.radius = 0.11
			sf.height = 0.22
			sf.radial_segments = 8
			sf.rings = 4
			o.mesh = sf
			o.material_override = _mat_en
			o.position = Vector3(0, 0.95, 0)
			o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			perno.add_child(o)
			_offerte.append(o)
	else:
		# abisso: punte di pietra scura piegate verso l'esterno
		for i in range(7):
			var a := float(i) / 7.0 * TAU + 0.2
			var perno := Node3D.new()
			perno.position = Vector3(cos(a) * 2.7, 0.0, sin(a) * 2.7)
			perno.rotation.y = -a
			perno.rotation.z = -(0.28 + rng.randf() * 0.2)
			add_child(perno)
			var h := 1.7 + rng.randf() * 1.3
			var c := Edifici.cilindro(0.0, 0.3 + rng.randf() * 0.1, h, Vector3(0, h * 0.5, 0), m, perno, 5)
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			var punta := MeshInstance3D.new()
			var sf := SphereMesh.new()
			sf.radius = 0.09
			sf.height = 0.18
			sf.radial_segments = 6
			sf.rings = 3
			punta.mesh = sf
			punta.material_override = _mat_en
			punta.position = Vector3(0, h * 0.72, 0)
			punta.scale = Vector3(1, 1.6, 1)
			perno.add_child(punta)
			_offerte.append(punta)


func _costruisci_nucleo() -> void:
	var yp := Y0 + (Y_PUNTA - Y0) * _ky
	_nucleo = Node3D.new()
	_nucleo.position = Vector3(0, yp + 0.95, 0)
	_vivo.add_child(_nucleo)
	var c := MeshInstance3D.new()
	c.mesh = _malla_cristallo()
	c.material_override = _mat_crist
	c.scale = Vector3(0.5, 0.5, 0.5) * (1.0 + 0.3 * _t)
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_nucleo.add_child(c)
	for i in range(2):
		var mi := MeshInstance3D.new()
		var tr := TorusMesh.new()
		tr.inner_radius = 0.62 + 0.18 * i
		tr.outer_radius = 0.68 + 0.18 * i
		tr.rings = 28
		tr.ring_segments = 5
		mi.mesh = tr
		mi.material_override = _mat_en
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.rotation = Vector3(0.9 * i + 0.3, 0, 0.5 * i)
		_nucleo.add_child(mi)
		_anelli_nucleo.append(mi)
	_alone_nucleo = _sprite(Vector2(3.4, 3.4), BaseMaterial3D.BILLBOARD_ENABLED, Color(_base_en.r, _base_en.g, _base_en.b, 0.5))
	_nucleo.add_child(_alone_nucleo)
	_alone_colonna = _sprite(Vector2(2.4, yp * 1.15), BaseMaterial3D.BILLBOARD_FIXED_Y, Color(_base_en.r, _base_en.g, _base_en.b, 0.1))
	_alone_colonna.position = Vector3(0, yp * 0.5, 0)
	_vivo.add_child(_alone_colonna)


func _costruisci_schegge() -> void:
	var n := 5 + int(4.0 * _t)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var yp := Y0 + (Y_PUNTA - Y0) * _ky
	for i in range(n):
		var s := Scheggia.new()
		s.n = MeshInstance3D.new()
		s.n.mesh = _malla_cristallo()
		s.n.material_override = _mat_crist
		var d := lerpf(0.26, 0.42, rng.randf()) * (1.0 + 0.45 * _t)
		s.n.scale = Vector3(d, d * 1.2, d)
		s.n.rotation = Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
		s.n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.a = float(i) * 2.399
		s.r = lerpf(1.55, 2.45, rng.randf()) + 0.2 * _t
		s.y = 1.0 + float(i) / float(maxi(n - 1, 1)) * (yp - 1.6)
		s.v = (0.28 + rng.randf() * 0.25) * (1.0 if i % 2 == 0 else -1.0)
		s.f = 0.8 + rng.randf() * 0.9
		s.ph = rng.randf() * TAU
		s.spin = rng.randf_range(0.6, 1.6)
		_vivo.add_child(s.n)
		_schegge.append(s)


# ------------------------------------------------------------------ aggancio con Entita
## Frazione di vita rimasta (0-1): decide crepe, agitazione e colore della luce.
func stato(frazione: float) -> void:
	_danno_t = clampf(1.0 - frazione, 0.0, 1.0)
	if _eta < 0.3:
		_danno = _danno_t


## L'obelisco evoca un'ondata di nemici: impulso di luce lungo il fusto, anelli che si allargano, scintille.
func ondata() -> void:
	if _fine:
		return
	_pulso = 1.0
	_anello(8.0 * (1.0 + 0.2 * _t), 1.0, 0.0)
	_anello(5.0, 0.8, 0.22)
	_burst.position = Vector3(0, 3.0 * _ky, 0)
	_burst.amount = 28
	_burst.initial_velocity_min = 2.0
	_burst.initial_velocity_max = 5.0
	_burst.restart()
	_burst.emitting = true


func colpito() -> void:
	_colpo = 1.0


func muovi(_velocita: float, _dt: float) -> void:
	pass


func attacca() -> void:
	pass


func lancia() -> void:
	pass


func _anello(raggio: float, durata: float, ritardo: float) -> void:
	var o := Onda.new()
	o.mi = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(raggio * 2.0, raggio * 2.0)
	o.mi.mesh = pm
	o.mat = ShaderMaterial.new()
	o.mat.shader = SH_ANELLO
	o.mat.set_shader_parameter("colore", Color(_base_en.r, _base_en.g, _base_en.b, 0.9))
	o.mat.set_shader_parameter("fase", 0.0)
	o.mat.set_shader_parameter("spessore", 0.2)
	o.mi.material_override = o.mat
	o.mi.position.y = 0.2
	o.mi.visible = false
	o.mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	o.t = -ritardo
	o.durata = durata
	add_child(o.mi)
	_onde.append(o)


# ------------------------------------------------------------------ frantumazione
func muori() -> void:
	if morto:
		return
	morto = true
	_fine = true
	_t_morte = 0.0
	_vivo.visible = false
	if _eta < 0.3:
		# già distrutto quando lo vediamo comparire: restano solo il basamento e il cerchio spento
		_t_morte = 10.0
		_luce.light_energy = 0.0
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var m := ShaderMaterial.new()
	m.shader = SH_PIETRA
	m.set_shader_parameter("colore", Vector3(_pietra.r, _pietra.g, _pietra.b))
	m.set_shader_parameter("concio", 0.5)
	var yp := Y0 + (Y_PUNTA - Y0) * _ky
	# pezzi di pietra del fusto
	for i in range(16 + int(8.0 * _t)):
		var d := Detrito.new()
		d.n = MeshInstance3D.new()
		var b := BoxMesh.new()
		var lato := rng.randf_range(0.18, 0.5)
		b.size = Vector3(lato, lato * rng.randf_range(0.6, 1.3), lato * rng.randf_range(0.6, 1.1))
		d.n.mesh = b
		d.n.material_override = m
		d.raggio = lato * 0.4
		var qy := rng.randf_range(0.7, yp)
		d.n.position = Vector3(rng.randf_range(-0.3, 0.3), qy, rng.randf_range(-0.3, 0.3))
		var a := rng.randf() * TAU
		var vel := rng.randf_range(1.5, 4.5) * (1.0 + 0.5 * (1.0 - qy / yp))
		d.v = Vector3(cos(a) * vel, rng.randf_range(1.0, 5.5), sin(a) * vel)
		d.w = Vector3(rng.randf_range(-6, 6), rng.randf_range(-6, 6), rng.randf_range(-6, 6))
		d.svanisce = rng.randf_range(3.3, 4.6)
		add_child(d.n)
		_detriti.append(d)
	# le schegge orbitanti schizzano via e si spengono
	for s in _schegge:
		var sc: Scheggia = s
		var d := Detrito.new()
		d.n = MeshInstance3D.new()
		d.n.mesh = _malla_cristallo()
		d.n.material_override = _mat_crist
		d.n.scale = sc.n.scale
		d.scala = sc.n.scale
		d.n.position = sc.n.position
		d.n.rotation = sc.n.rotation
		d.n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var dir := Vector3(sc.n.position.x, 0, sc.n.position.z).normalized()
		d.v = dir * rng.randf_range(4.0, 9.0) + Vector3(0, rng.randf_range(2.0, 7.0), 0)
		d.w = Vector3(rng.randf_range(-8, 8), rng.randf_range(-8, 8), rng.randf_range(-8, 8))
		d.svanisce = rng.randf_range(0.7, 1.6)
		d.raggio = 0.1
		add_child(d.n)
		_detriti.append(d)
	_burst.position = Vector3(0, 2.6 * _ky, 0)
	_burst.amount = 64
	_burst.initial_velocity_min = 3.0
	_burst.initial_velocity_max = 9.0
	_burst.restart()
	_burst.emitting = true
	_anello(11.0 * (1.0 + 0.25 * _t), 1.2, 0.0)
	_anello(7.0, 0.9, 0.12)
	_lampo.visible = true
	_lampo.position = Vector3(0, 2.8 * _ky, 0)


func rialza() -> void:
	morto = false
	_fine = false
	_eta = 0.0
	for d in _detriti:
		(d as Detrito).n.queue_free()
	_detriti.clear()
	for o in _onde:
		(o as Onda).mi.queue_free()
	_onde.clear()
	_vivo.visible = true
	_lampo.visible = false
	_danno = 0.0
	_burst.emitting = false


# ------------------------------------------------------------------ animazione
func _process(dt: float) -> void:
	dt = minf(dt, 0.1)
	_tempo += dt
	_eta += dt
	_tick_onde(dt)
	if _fine:
		_tick_morte(dt)
		return
	_danno = lerpf(_danno, _danno_t, minf(1.0, dt * 3.0))
	_pulso = maxf(0.0, _pulso - dt / 1.2)
	_colpo = maxf(0.0, _colpo - dt * 3.5)
	var d := _danno
	var crit := smoothstep(0.7, 0.9, d)
	# sul punto di cedere la luce lampeggia a scatti irregolari
	var spenta := sin(_tempo * 11.0) * sin(_tempo * 4.7) > 0.25
	var lamp := 1.0 - crit * (0.8 if spenta else 0.0)
	var luce := (0.8 + 0.6 * d + _pulso * 1.2 + _colpo * 0.8) * lamp
	# la luce vira dal colore dell'energia verso il bianco caldo con il danno
	var en := _base_en.lerp(Color(1.0, 0.85, 0.6), d * 0.4)
	var ev := Vector3(en.r, en.g, en.b)

	_mat_fusto.set_shader_parameter("energia", ev)
	_mat_fusto.set_shader_parameter("luce", luce)
	_mat_fusto.set_shader_parameter("danno", d)
	_mat_fusto.set_shader_parameter("pulso", _pulso)
	_mat_fusto.set_shader_parameter("colpo", _colpo)
	_mat_crist.set_shader_parameter("energia", ev)
	_mat_crist.set_shader_parameter("luce", luce)
	_mat_crist.set_shader_parameter("colpo", _colpo)
	_mat_en.emission = en
	_mat_en.emission_energy_multiplier = 2.5 * (0.5 + 0.5 * lamp) + _pulso * 2.0
	_luce.light_color = en
	_luce.light_energy = 1.4 * luce * (1.0 + 0.1 * sin(_tempo * 5.0))
	var mr := _cerchio.material_override as ShaderMaterial
	mr.set_shader_parameter("colore", Color(en.r, en.g, en.b, clampf(0.55 + 0.25 * d + _pulso * 0.4, 0.0, 1.0) * (0.6 + 0.4 * lamp)))

	# schegge in orbita: più danno = più veloci, più larghe e tremolanti
	var vel := 1.0 + 2.5 * d * d + _pulso * 1.5
	var agit := d * d * 0.12
	for s in _schegge:
		var sc: Scheggia = s
		sc.a += dt * sc.v * vel
		var r := sc.r * (1.0 + 0.12 * d * sin(_tempo * 3.0 + sc.ph)) + 0.5 * _pulso
		sc.n.position = Vector3(
			cos(sc.a) * r + agit * sin(_tempo * 17.0 + sc.ph * 3.0),
			sc.y + sin(_tempo * sc.f + sc.ph) * 0.18 + agit * sin(_tempo * 21.0 + sc.ph),
			sin(sc.a) * r + agit * sin(_tempo * 19.0 + sc.ph * 2.0))
		sc.n.rotation.y += dt * sc.spin * vel

	# nucleo e anelli
	var ps := 1.0 + 0.12 * sin(_tempo * 3.0) + _pulso * 0.5 + _colpo * 0.2
	_nucleo.scale = Vector3.ONE * ps
	_nucleo.position.y = Y0 + (Y_PUNTA - Y0) * _ky + 0.95 + 0.12 * sin(_tempo * 1.7)
	_nucleo.get_child(0).rotation.y += dt * (0.9 + 2.0 * d)
	for i in range(_anelli_nucleo.size()):
		var an := _anelli_nucleo[i] as Node3D
		an.rotation.y += dt * (1.2 + 0.8 * i) * (1.0 if i == 0 else -1.0) * vel
		an.rotation.x += dt * 0.5 * vel
	var ma := _alone_nucleo.material_override as StandardMaterial3D
	ma.albedo_color = Color(en.r, en.g, en.b, (0.45 + 0.25 * d + _pulso * 0.4) * lamp)
	var mc := _alone_colonna.material_override as StandardMaterial3D
	mc.albedo_color = Color(en.r, en.g, en.b, 0.08 + 0.06 * d + _pulso * 0.12)
	_salita.color = en
	_salita.speed_scale = 1.0 + d * 1.2 + _pulso
	_mi_fusto.position.x = sin(_tempo * 70.0) * (0.03 * _colpo + 0.025 * d * d * (0.4 + crit))
	_mi_fusto.position.z = cos(_tempo * 63.0) * (0.02 * _colpo + 0.02 * d * d * crit)


func _tick_onde(dt: float) -> void:
	var i := _onde.size() - 1
	while i >= 0:
		var o: Onda = _onde[i]
		o.t += dt
		if o.t >= o.durata:
			o.mi.queue_free()
			_onde.remove_at(i)
		elif o.t >= 0.0:
			o.mi.visible = true
			o.mat.set_shader_parameter("fase", o.t / o.durata)
		i -= 1


func _tick_morte(dt: float) -> void:
	_t_morte += dt
	var t := _t_morte
	_luce.light_energy = 9.0 * exp(-t * 3.0) + (0.5 * exp(-t * 0.8) if t < 6.0 else 0.0)
	_luce.light_color = _base_en.lerp(Color(1, 0.9, 0.7), exp(-t * 4.0))
	var mr := _cerchio.material_override as ShaderMaterial
	mr.set_shader_parameter("colore", Color(_base_en.r, _base_en.g, _base_en.b, clampf(1.0 - t / 3.0, 0.0, 0.8)))
	if _lampo.visible:
		var ml := _lampo.material_override as StandardMaterial3D
		var a := exp(-t * 4.5) * 0.95
		ml.albedo_color = Color(1.0, 0.95, 0.9, a)
		_lampo.scale = Vector3.ONE * (1.0 + t * 1.6)
		if a < 0.01:
			_lampo.visible = false
	for dd in _detriti:
		var d: Detrito = dd
		if not d.fermo:
			d.n.position += d.v * dt
			d.v.y -= 16.0 * dt
			d.n.rotation += d.w * dt
			if d.n.position.y < d.raggio:
				d.n.position.y = d.raggio
				if absf(d.v.y) > 2.0:
					d.v = Vector3(d.v.x * 0.6, -d.v.y * 0.35, d.v.z * 0.6)
					d.w *= 0.6
				else:
					d.v = Vector3.ZERO
					d.w = Vector3.ZERO
					d.fermo = true
		var k := 1.0 - smoothstep(d.svanisce, d.svanisce + 1.0, t)
		d.n.scale = d.scala * maxf(k, 0.001)
		if k <= 0.001:
			d.n.visible = false
