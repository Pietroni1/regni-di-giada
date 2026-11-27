class_name Effetti
extends Node3D
## Effetti a vista delle tecniche. Mattoni riusabili (anello, fendente, saetta, colonna, crepe, rune, spirale, bagliore,
## scintille, proiettile, lampo) composti in base al campo `fx` della tecnica e al suo ruolo; le quattro Tecniche Supreme
## hanno una regia propria (`_suprema`).

const SH_ANELLO := preload("res://shader/fx_anello.gdshader")
const SH_FENDENTE := preload("res://shader/fx_fendente.gdshader")
const SH_FULMINE := preload("res://shader/fx_fulmine.gdshader")
const SH_COLONNA := preload("res://shader/fx_colonna.gdshader")
const SH_SCIA := preload("res://shader/fx_scia.gdshader")
const SH_CREPE := preload("res://shader/fx_crepe.gdshader")
const SH_FORMA := preload("res://shader/fx_forma.gdshader")
const SH_OMBRA := preload("res://shader/fx_ombra.gdshader")
const SH_CUPOLA := preload("res://shader/fx_cupola.gdshader")

## Gradi di padronanza di una tecnica in base al suo livello: l'effetto a vista cresce a ogni grado.
const GRADI := [[20, "Perfetta"], [15, "Maestra"], [10, "Esperta"], [5, "Affinata"], [1, "Appresa"]]
const ORO_PERFETTO := Color(1.0, 0.82, 0.32)

var tremore := 0.0          # letto dalla visuale (Gioco)
var _proiettili: Array = []


func _dopo(sec: float, f: Callable) -> void:
	get_tree().create_timer(maxf(0.01, sec)).timeout.connect(f)


func _anima(m: ShaderMaterial, durata: float, nodo: Node) -> void:
	var t := create_tween()
	t.tween_method(func(v: float) -> void: m.set_shader_parameter("fase", v), 0.0, 1.0, durata)
	t.tween_callback(nodo.queue_free)


func _piano(shader: Shader, colore: Color, durata: float, lato: float, extra := {}) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = Vector2(lato, lato)
	mi.mesh = p
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("colore", colore)
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_anima(m, durata, mi)
	return mi


# ------------------------------------------------------------------ mattoni
## Onda d'urto sul terreno.
func anello(pos: Vector3, colore: Color, raggio: float, durata := 0.5, spessore := 0.16, pieno := 0.0) -> void:
	var mi := _piano(SH_ANELLO, colore, durata, raggio * 2.0, {"spessore": spessore, "pieno": pieno})
	mi.position = pos + Vector3(0, 0.12, 0)


## Mezzaluna di un colpo di lama in un punto qualsiasi. yaw = direzione del colpo, inclina = piega del piano.
func taglio(pos: Vector3, yaw: float, colore: Color, raggio := 2.8, arco := 2.6, durata := 0.28, inclina := 0.0, bianco := 1.0) -> void:
	var mi := _piano(SH_FENDENTE, colore, durata, raggio * 2.0, {"arco": arco, "bianco": bianco})
	mi.position = pos
	mi.rotation = Vector3(0, yaw + PI, 0)
	mi.rotate_object_local(Vector3(0, 0, 1), inclina)
	# un secondo arco più sottile e chiaro, appena dopo: dà spessore al colpo
	var mi2 := _piano(SH_FENDENTE, colore.lightened(0.55 * bianco), durata * 0.8, raggio * 2.12, {"arco": arco * 0.9, "interno": 0.86, "bianco": bianco})
	mi2.transform = mi.transform


func fendente(da: Entita, colore: Color, raggio := 2.8, arco := 2.6, durata := 0.28, inclina := 0.0, alza := 1.2) -> void:
	taglio(da.global_position + Vector3(0, alza, 0), da.r, colore, raggio, arco, durata, inclina)


## Saetta dal cielo su un punto.
func fulmine(pos: Vector3, colore: Color, altezza := 16.0, larghezza := 5.0, durata := 0.4, luce := true) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(larghezza, altezza)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = SH_FULMINE
	m.set_shader_parameter("colore", colore)
	m.set_shader_parameter("seme", randf() * 50.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(0, altezza * 0.5, 0)
	add_child(mi)
	_anima(m, durata, mi)
	if luce:
		lampo(pos + Vector3(0, 1.5, 0), colore, 7.0, 12.0, durata)
	bagliore(pos + Vector3(0, 0.6, 0), colore.lightened(0.2), larghezza * 0.6, durata * 0.8)
	anello(pos, colore, larghezza * 0.55, 0.4)
	crepe(pos, colore, larghezza * 0.45, 1.6)
	scintille(pos + Vector3(0, 0.4, 0), colore, 22, 8.0, 0.55)


## Colonna di luce che sale da un punto.
func colonna(pos: Vector3, colore: Color, raggio := 1.2, altezza := 7.0, durata := 0.9) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = raggio * 0.85
	c.bottom_radius = raggio
	c.height = altezza
	c.cap_top = false
	c.cap_bottom = false
	c.radial_segments = 20
	mi.mesh = c
	var m := ShaderMaterial.new()
	m.shader = SH_COLONNA
	m.set_shader_parameter("colore", colore)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(0, altezza * 0.5, 0)
	add_child(mi)
	_anima(m, durata, mi)


## Crepe incandescenti che restano a terra per un momento.
func crepe(pos: Vector3, colore: Color, raggio: float, durata := 2.2) -> void:
	var mi := _piano(SH_CREPE, colore, durata, raggio * 2.0, {"seme": randf() * 40.0})
	mi.position = pos + Vector3(0, 0.09, 0)
	mi.rotation.y = randf() * TAU


## Cerchio di rune a terra che appare, ruota e svanisce.
func rune(pos: Vector3, colore: Color, raggio: float, durata := 1.0) -> void:
	var mi := Equip.cerchio_rune(raggio, colore, false)
	mi.position = pos + Vector3(0, 0.1, 0)
	add_child(mi)
	_anima(mi.material_override, durata, mi)


## Macchia di luce che si gonfia e svanisce (impatti, cariche).
func bagliore(pos: Vector3, colore: Color, grande := 2.0, durata := 0.3) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = Equip.alone()
	m.albedo_color = Color(colore.r, colore.g, colore.b, 0.5)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.no_depth_test = false
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.scale = Vector3.ONE * grande * 0.35
	add_child(mi)
	var t := create_tween().set_parallel()
	t.tween_property(mi, "scale", Vector3.ONE * grande, durata).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(m, "albedo_color:a", 0.0, durata).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(mi.queue_free)


func _particelle(pos: Vector3, colore: Color, quante: int, durata: float, grandezza: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(grandezza, grandezza)
	p.mesh = q
	p.material_override = Equip.mat_particella()
	p.amount = quante
	p.lifetime = durata
	p.scale_amount_min = 0.45
	p.scale_amount_max = 1.5
	var sf := Gradient.new()
	sf.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	sf.colors = PackedColorArray([Color(minf(1.0, colore.r + 0.5), minf(1.0, colore.g + 0.5), minf(1.0, colore.b + 0.5), 1.0), Color(colore.r, colore.g, colore.b, 0.95), Color(colore.r, colore.g, colore.b, 0.0)])
	p.color_ramp = sf
	p.position = pos
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


## Scintille che schizzano da un punto.
func scintille(pos: Vector3, colore: Color, quante := 16, velocita := 5.0, durata := 0.5, gravita := -12.0, grandezza := 0.22) -> void:
	var p := _particelle(pos, colore, quante, durata, grandezza)
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = velocita * 0.35
	p.initial_velocity_max = velocita
	p.damping_min = velocita * 0.6
	p.damping_max = velocita * 1.2
	p.gravity = Vector3(0, gravita, 0)
	p.emitting = true
	_dopo(durata + 0.3, p.queue_free)


## Doppia spirale di luce che sale attorno a un punto (cure, aure, cariche).
func spirale(pos: Vector3, colore: Color, raggio := 1.0, altezza := 3.0, durata := 1.0, giri := 2.5, tex := "", dim := 0.2, add := true) -> void:
	for k in range(2):
		var perno := Node3D.new()
		perno.position = pos
		perno.rotation.y = k * PI
		add_child(perno)
		var p := _pezzi(Vector3(raggio, 0, 0), tex, colore, 40 if tex == "" else 22, 0.55, Vector2(dim, dim), add)
		remove_child(p)
		perno.add_child(p)
		p.local_coords = false
		p.gravity = Vector3.ZERO
		p.initial_velocity_max = 0.1
		var t := create_tween().set_parallel()
		t.tween_property(perno, "rotation:y", k * PI + TAU * giri, durata)
		t.tween_property(perno, "position:y", pos.y + altezza, durata)
		t.tween_property(p, "position:x", raggio * 0.35, durata)
		t.chain().tween_callback(func() -> void: p.emitting = false)
		_dopo(durata + 0.7, perno.queue_free)


## Polvere e sassi sollevati da un colpo a terra.
func polvere(pos: Vector3, raggio: float, quante := 20) -> void:
	fumo(pos + Vector3(0, 0.7, 0), Color(0.66, 0.58, 0.46), maxi(5, quante / 2), raggio * 0.55, 0.9, 1.3, 0.3)
	scintille(pos + Vector3(0, 0.3, 0), Color(0.45, 0.38, 0.28), quante, 9.0, 0.8, -20.0, 0.16)


## Lampo di luce che si spegne.
func lampo(pos: Vector3, colore: Color, energia := 5.0, raggio := 10.0, durata := 0.3) -> void:
	var l := OmniLight3D.new()
	l.light_color = colore
	l.light_energy = energia * 0.4
	l.omni_range = raggio
	l.position = pos
	add_child(l)
	var t := create_tween()
	t.tween_property(l, "light_energy", 0.0, durata)
	t.tween_callback(l.queue_free)


## Striscia luminosa fra due punti (scatti, frecce che trapassano).
func scia(da: Vector3, a: Vector3, colore: Color, larghezza := 1.0, durata := 0.35) -> void:
	var d := a - da
	var lung := d.length()
	if lung < 0.2:
		return
	var mi := _piano(SH_SCIA, colore, durata, 1.0)
	mi.scale = Vector3(larghezza, 1.0, lung)
	mi.position = (da + a) * 0.5 + Vector3(0, 0.9, 0)
	mi.rotation.y = atan2(d.x, d.z) + PI


## Globo che vola verso un bersaglio lasciando una coda; all'arrivo chiama `fine`.
func proiettile(da: Vector3, verso, colore: Color, velocita := 28.0, raggio := 0.22, fine := Callable(), luce := true, codaq := 36) -> void:
	var nodo := Node3D.new()
	nodo.position = da
	add_child(nodo)
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = raggio
	s.height = raggio * 2.0
	mi.mesh = s
	mi.material_override = Edifici.mat(colore.lightened(0.4), 0.3, 0.0, 6.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nodo.add_child(mi)
	var coda := _particelle(Vector3.ZERO, colore, codaq, 0.4, raggio * 2.6)
	remove_child(coda)
	nodo.add_child(coda)
	coda.local_coords = false
	coda.gravity = Vector3.ZERO
	coda.initial_velocity_max = 0.3
	coda.spread = 180.0
	if luce:
		var l := OmniLight3D.new()
		l.light_color = colore
		l.light_energy = 2.0
		l.omni_range = 5.0
		nodo.add_child(l)
	_proiettili.append({"n": nodo, "verso": verso, "v": velocita, "c": colore, "fine": fine, "t": 0.0, "r": raggio})


func _process(dt: float) -> void:
	tremore = maxf(0.0, tremore - dt * 2.2)
	for i in range(_proiettili.size() - 1, -1, -1):
		var p: Dictionary = _proiettili[i]
		var n: Node3D = p.n
		var meta: Vector3
		if p.verso is Entita:
			if not is_instance_valid(p.verso):
				n.queue_free()
				_proiettili.remove_at(i)
				continue
			meta = (p.verso as Entita).petto()
		else:
			meta = p.verso
		var d := meta - n.position
		var passo: float = float(p.v) * dt
		p.t += dt
		if d.length() <= passo or p.t > 3.0:
			if not p.has("dardo"):
				scintille(meta, p.c, 16, 6.0, 0.4)
				bagliore(meta, (p.c as Color).lightened(0.4), float(p.r) * 9.0, 0.25)
			if (p.fine as Callable).is_valid():
				(p.fine as Callable).call()
			n.queue_free()
			_proiettili.remove_at(i)
		else:
			n.position += d.normalized() * passo
			if p.has("dardo") and p.verso is Entita and d.length() > 0.2:
				n.look_at(meta, Vector3.UP if absf(d.normalized().y) < 0.98 else Vector3.RIGHT)


func scuoti(forza: float) -> void:
	tremore = maxf(tremore, forza)


## Grado (0-4) per un livello di abilità: 1-4 Appresa, 5 Affinata, 10 Esperta, 15 Maestra, 20 Perfetta.
static func grado(livello: int) -> int:
	return 4 if livello >= 20 else (3 if livello >= 15 else (2 if livello >= 10 else (1 if livello >= 5 else 0)))


static func nome_grado(livello: int) -> String:
	for g in GRADI:
		if livello >= int(g[0]):
			return String(g[1])
	return "Appresa"


## Rende più saturo il colore di una tecnica: molti sono pastello e, sommati alla luce, diventerebbero bianchi.
func vivo(c: Color) -> Color:
	return Color.from_hsv(c.h, clampf(c.s * 1.7 + 0.2, 0.0, 0.95), c.v)


# ------------------------------------------------------------------ mattoni dei temi
## Texture piccole generate da codice per le particelle: stella a quattro punte, petalo/penna.
static var _tex: Dictionary = {}
static var _mat_p: Dictionary = {}
static var _mat_roccia: StandardMaterial3D = null
const F_MIRINO := 0
const F_LOTO := 1
const F_COSTELLAZIONE := 2
const F_SIGILLO := 3
const F_PALMO := 4
const F_VENTO := 5
const F_STELLA := 6


static func _texture(nome: String) -> Texture2D:
	if _tex.has(nome):
		return _tex[nome]
	var n := 32
	var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in range(n):
		for x in range(n):
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0
			var a := 0.0
			if nome == "stella":
				a = clampf(1.0 - (pow(absf(u), 0.5) + pow(absf(v), 0.5)), 0.0, 1.0) * 2.2
				a += clampf(1.0 - Vector2(u, v).length() * 2.4, 0.0, 1.0)
			else:
				# petalo / penna: foglia appuntita lungo y
				var w := 0.78 * pow(sin(PI * (v * 0.5 + 0.5)), 0.85)
				a = clampf((w - absf(u)) * 7.0, 0.0, 1.0) * (0.75 + 0.25 * (1.0 - absf(u)))
			im.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	var t := ImageTexture.create_from_image(im)
	_tex[nome] = t
	return t


static func _mat_sasso() -> StandardMaterial3D:
	if _mat_roccia == null:
		_mat_roccia = StandardMaterial3D.new()
		_mat_roccia.albedo_color = Color(0.5, 0.45, 0.4)
		_mat_roccia.roughness = 1.0
		_mat_roccia.emission_enabled = true
		_mat_roccia.emission = Color(0.22, 0.13, 0.04)
	return _mat_roccia


static func _materiale(tex: String, add: bool) -> StandardMaterial3D:
	var k := tex + ("+" if add else "-")
	if _mat_p.has(k):
		return _mat_p[k]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _texture(tex) if tex != "" else Equip.alone()
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_mat_p[k] = m
	return m


## Particelle con una texture a scelta (stella, petalo) e una grandezza non quadrata (penne). add = luminose o opache.
func _pezzi(pos: Vector3, tex: String, colore: Color, quante: int, durata: float, dim: Vector2, add := true) -> CPUParticles3D:
	if tex == "" and add:
		return _particelle(pos, colore, quante, durata, dim.x)
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = dim
	p.mesh = q
	p.material_override = _materiale(tex, add)
	p.amount = quante
	p.lifetime = durata
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var sf := Gradient.new()
	sf.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	sf.colors = PackedColorArray([Color(colore.r, colore.g, colore.b, 0.0), Color(colore.r, colore.g, colore.b, 0.95), Color(colore.r, colore.g, colore.b, 0.0)])
	p.color_ramp = sf
	p.position = pos
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


## Segno luminoso di un tema (vedi fx_forma.gdshader). pos è il centro; per default giace a terra.
func forma(pos: Vector3, tipo: int, colore: Color, c2: Color, raggio: float, durata := 1.0, alza := 0.1) -> MeshInstance3D:
	var mi := _piano(SH_FORMA, colore, durata, raggio * 2.0, {"colore2": c2, "forma": tipo, "seme": randf() * 20.0})
	mi.position = pos + Vector3(0, alza, 0)
	mi.rotation.y = randf() * TAU
	return mi


## Pezzi di roccia (cubetti scuri) lanciati in aria da un colpo a terra.
func schegge(pos: Vector3, quante := 14, velocita := 7.0) -> void:
	var p := CPUParticles3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.2, 0.14, 0.17)
	p.mesh = b
	p.material_override = _mat_sasso()
	p.amount = quante
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = velocita * 0.5
	p.initial_velocity_max = velocita
	p.gravity = Vector3(0, -20, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.6
	p.angular_velocity_min = -300.0
	p.angular_velocity_max = 300.0
	p.position = pos
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.emitting = true
	_dopo(1.4, p.queue_free)


## Lastre di roccia che spuntano dal suolo in cerchio attorno a un punto, restano e poi rientrano.
func lastre(centro: Vector3, raggio: float, quante := 8, alt := 1.8, durata := 1.0) -> void:
	for i in range(quante):
		var a := TAU * i / quante + randf() * 0.4
		var d := raggio * (0.55 + 0.4 * randf())
		var base := Dati.suolo(centro.x + cos(a) * d, centro.z + sin(a) * d)
		_lastra(base, PI * 0.5 - a, alt * (0.6 + 0.8 * randf()), randf_range(0.5, 0.95), deg_to_rad(randf_range(12.0, 28.0)), durata, 0.03 * i)


func _lastra(base: Vector3, yaw: float, h: float, larg: float, inclina: float, durata: float, ritardo: float) -> void:
	var perno := Node3D.new()
	perno.position = base - Vector3(0, 0.1, 0)
	perno.rotation = Vector3(inclina, yaw, 0.0)
	perno.scale = Vector3(1, 0.02, 1)
	var mi := MeshInstance3D.new()
	if randf() < 0.45:
		var pr := PrismMesh.new()
		pr.size = Vector3(larg, h, 0.34)
		pr.left_to_right = randf_range(0.3, 0.7)
		mi.mesh = pr
	else:
		var b := BoxMesh.new()
		b.size = Vector3(larg, h, 0.3)
		mi.mesh = b
	mi.position = Vector3(0, h * 0.5, 0)
	mi.material_override = _mat_sasso()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	perno.add_child(mi)
	add_child(perno)
	var t := create_tween()
	t.tween_interval(ritardo)
	t.tween_property(perno, "scale", Vector3.ONE, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_interval(durata)
	t.tween_property(perno, "position:y", perno.position.y - h * 0.9, 0.45).set_ease(Tween.EASE_IN)
	t.tween_callback(perno.queue_free)


## Una fila di lastre che sale lungo il percorso da un punto a un altro (onda di roccia).
func lastre_linea(da: Vector3, a: Vector3, quante := 6, durata := 0.8) -> void:
	var d := a - da
	var lung := d.length()
	if lung < 1.0:
		return
	var yaw := atan2(d.x, d.z)
	for i in range(quante):
		var f := (i + 0.7) / quante
		var lato := randf_range(-0.5, 0.5)
		var p := da + d * f + Vector3(d.z, 0, -d.x).normalized() * lato
		_lastra(Dati.suolo(p.x, p.z), yaw + randf_range(-0.4, 0.4), randf_range(0.8, 1.6), randf_range(0.4, 0.8), deg_to_rad(randf_range(10.0, 25.0)), durata, 0.05 * i)


## Nube di fumo che sale da un punto: scura, non additiva. raggio = estensione a terra.
func fumo(pos: Vector3, colore: Color, quante := 10, raggio := 0.8, durata := 1.0, grandezza := 1.2, sale := 0.8) -> void:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(grandezza, grandezza)
	p.mesh = q
	p.material_override = Equip.mat_fumo()
	p.amount = quante
	p.lifetime = durata
	p.one_shot = true
	p.explosiveness = 0.85
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = maxf(raggio, 0.05)
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 1.1
	p.gravity = Vector3(0, sale, 0)
	p.damping_min = 0.5
	p.damping_max = 1.0
	p.preprocess = 0.07      # senza, nei primi due fotogrammi le particelle non ancora partite si vedono come una macchia nera
	var sf := Gradient.new()
	sf.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	sf.colors = PackedColorArray([Color(colore.r, colore.g, colore.b, 0.0), Color(colore.r, colore.g, colore.b, 0.75), Color(colore.r, colore.g, colore.b, 0.0)])
	p.color_ramp = sf
	p.position = pos
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.emitting = true
	_dopo(durata + 0.4, p.queue_free)


## Anello di nube a terra (veleno, velo d'ombra): fumo che si allarga sul suolo.
func nube(pos: Vector3, raggio: float, durata := 1.4, colore := Color(0.3, 0.1, 0.4), veleno := Color(0.4, 0.9, 0.2)) -> void:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.3, 1.3)
	p.mesh = q
	p.material_override = Equip.mat_fumo()
	p.amount = clampi(int(raggio * 5.0), 8, 28)
	p.lifetime = durata
	p.one_shot = true
	p.explosiveness = 0.7
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = raggio * 0.75
	p.emission_ring_inner_radius = 0.0
	p.emission_ring_height = 0.2
	p.direction = Vector3.UP
	p.spread = 20.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.6
	p.gravity = Vector3(0, 0.25, 0)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.8
	p.preprocess = 0.07
	var sf := Gradient.new()
	sf.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	sf.colors = PackedColorArray([Color(colore.r, colore.g, colore.b, 0.0), Color(colore.r, colore.g, colore.b, 0.7), Color(colore.r, colore.g, colore.b, 0.0)])
	p.color_ramp = sf
	p.position = pos + Vector3(0, 0.65, 0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.emitting = true
	_dopo(durata + 0.4, p.queue_free)
	# il veleno: bollicine luminose che affiorano dalla nube
	var b := _particelle(pos + Vector3(0, 0.2, 0), veleno, clampi(int(raggio * 3.0), 6, 16), durata, 0.2)
	b.one_shot = true
	b.explosiveness = 0.4
	b.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	b.emission_sphere_radius = raggio * 0.7
	b.direction = Vector3.UP
	b.spread = 30.0
	b.initial_velocity_min = 0.3
	b.initial_velocity_max = 1.0
	b.gravity = Vector3(0, 0.4, 0)
	b.emitting = true
	_dopo(durata + 0.4, b.queue_free)


## Gocce di veleno che schizzano e ricadono.
func gocce(pos: Vector3, colore: Color, quante := 10) -> void:
	scintille(pos, colore, quante, 4.5, 0.7, -14.0, 0.16)


## Sagoma scura di una persona (copia d'ombra): compare, scivola di lato e svanisce.
func sagoma(pos: Vector3, yaw: float, colore := Color(0.14, 0.05, 0.22), scivola := Vector3.ZERO, durata := 0.7) -> void:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.26
	cm.height = 1.75
	cm.radial_segments = 10
	cm.rings = 4
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(colore.r, colore.g, colore.b, 0.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(0, 0.95, 0) + Vector3(cos(yaw), 0, -sin(yaw)) * 0.9
	mi.rotation.y = yaw
	add_child(mi)
	var t := create_tween().set_parallel()
	t.tween_property(m, "albedo_color:a", 0.42, durata * 0.3)
	t.chain().tween_property(m, "albedo_color:a", 0.0, durata * 0.75)
	t.parallel().tween_property(mi, "position", mi.position + scivola, durata)
	t.chain().tween_callback(mi.queue_free)
	# un bordo acceso attorno alla sagoma: sfera di luce acida piccola alla testa (occhi)
	scintille(pos + Vector3(0, 1.7, 0), Color(0.55, 1.0, 0.2), 3, 1.0, 0.4, 0.0, 0.14)


## Taglio sottile d'ombra: mezzaluna scura con il bordo acido (vedi fx_ombra.gdshader).
func taglio_ombra(pos: Vector3, yaw: float, acido: Color, scuro: Color, raggio := 2.6, arco := 2.2, durata := 0.4, inclina := 0.0) -> void:
	var mi := _piano(SH_OMBRA, acido, durata, raggio * 2.0, {"colore2": scuro, "arco": arco, "interno": 0.5})
	# il taglio passa per il punto dato: il centro del disco sta dietro, lungo la direzione del colpo
	mi.position = pos - Vector3(sin(yaw), 0, cos(yaw)) * raggio * 0.85
	mi.rotation = Vector3(0, yaw + PI, 0)
	mi.rotate_object_local(Vector3(0, 0, 1), inclina)
	# bordo acido che brilla (additivo) sopra al corpo scuro
	var mi2 := _piano(SH_FENDENTE, acido, durata * 0.9, raggio * 2.04, {"arco": arco, "interno": 0.84, "bianco": 0.0})
	mi2.transform = mi.transform


## Lama di luce obliqua dal cielo a un punto: due piani incrociati lungo l'asse, così si vede da ogni lato.
func raggio_luce(da: Vector3, a: Vector3, colore: Color, larghezza := 1.0, durata := 0.35) -> void:
	var d := a - da
	var lung := d.length()
	if lung < 0.3:
		return
	var base := Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT)
	for k in range(2):
		var mi := _piano(SH_SCIA, colore, durata, 1.0)
		var b := base.rotated(base.z, k * PI * 0.5)
		mi.transform = Transform3D(b * Basis.from_scale(Vector3(larghezza, 1.0, lung)), (da + a) * 0.5)
	bagliore(a + Vector3(0, 0.4, 0), colore.lightened(0.3), larghezza * 2.2, durata * 0.8)


## Cupola di protezione attorno a un punto (scudi).
func cupola(pos: Vector3, raggio: float, colore: Color, c2: Color, durata := 1.6) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = raggio
	s.height = raggio * 2.0
	s.radial_segments = 24
	s.rings = 12
	mi.mesh = s
	var m := ShaderMaterial.new()
	m.shader = SH_CUPOLA
	m.set_shader_parameter("colore", colore)
	m.set_shader_parameter("colore2", c2)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(0, raggio * 0.55, 0)
	add_child(mi)
	_anima(m, durata, mi)


## Petali o piume che volteggiano. sale > 0: salgono (cure, luce); sale < 0: cadono (penne).
func petali(pos: Vector3, colore: Color, quante := 16, raggio := 1.0, durata := 1.4, sale := 0.6, dim := Vector2(0.16, 0.26), add := false, c2 := Color(0, 0, 0, 0)) -> void:
	var p := _pezzi(pos, "petalo", colore, quante, durata, dim, add)
	p.one_shot = true
	p.explosiveness = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = maxf(raggio, 0.05)
	p.direction = Vector3.UP
	p.spread = 120.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0, sale * 2.0, 0)
	p.damping_min = 0.6
	p.damping_max = 1.4
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
	p.preprocess = 0.07
	if c2.a > 0.0:
		var ini := Gradient.new()
		ini.colors = PackedColorArray([colore, c2])
		p.color_initial_ramp = ini
	p.emitting = true
	_dopo(durata + 0.5, p.queue_free)


## Stelle a quattro punte che schizzano (o, con sale > 0, salgono lente).
func stelle(pos: Vector3, colore: Color, quante := 12, velocita := 3.0, durata := 0.9, sale := 0.0, grandezza := 0.28) -> void:
	var p := _pezzi(pos, "stella", colore, quante, durata, Vector2(grandezza, grandezza), true)
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = velocita * 0.3
	p.initial_velocity_max = velocita
	p.damping_min = velocita * 0.5
	p.damping_max = velocita
	p.gravity = Vector3(0, sale, 0)
	p.angle_min = 0.0
	p.angle_max = 90.0
	p.emitting = true
	_dopo(durata + 0.4, p.queue_free)


## Pioggia di stelle che cade da un'area sopra un punto (buff del Mistico, Suprema).
func pioggia_stelle(centro: Vector3, raggio: float, durata := 1.4, quante := 26, colore := Color(1.0, 0.9, 0.5)) -> void:
	var p := _pezzi(centro + Vector3(0, 6.0, 0), "stella", colore, quante, 1.0, Vector2(0.5, 0.5), true)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(raggio, 0.2, raggio)
	p.direction = Vector3.DOWN
	p.spread = 6.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 7.0
	p.gravity = Vector3(0, -3.0, 0)
	p.angle_min = 0.0
	p.angle_max = 90.0
	p.local_coords = false
	p.emitting = true
	_dopo(durata, func() -> void: p.emitting = false)
	_dopo(durata + 1.4, p.queue_free)


## Fiamme che salgono. raggio > 0 in anello attorno al punto.
func fiamme(pos: Vector3, colore: Color, quante := 18, raggio := 0.4, altezza := 2.0, durata := 0.7) -> void:
	var p := _particelle(pos, colore, quante, durata, 0.55)
	p.one_shot = true
	p.explosiveness = 0.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = maxf(raggio, 0.05)
	p.emission_ring_inner_radius = raggio * 0.5
	p.emission_ring_height = 0.1
	p.direction = Vector3.UP
	p.spread = 14.0
	p.initial_velocity_min = altezza * 0.5
	p.initial_velocity_max = altezza * 1.1
	p.gravity = Vector3(0, altezza * 0.5, 0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.emitting = true
	_dopo(durata + 0.4, p.queue_free)


## Scia d'aria: striscia chiara e sottile a mezz'altezza (frecce, raffiche).
func scia_aria(da: Vector3, a: Vector3, colore: Color, larghezza := 0.5, durata := 0.4) -> void:
	scia(da + Vector3(0, 0.6, 0), a + Vector3(0, 0.6, 0), colore, larghezza, durata)


## Impronta di un punto d'arrivo o di partenza: sbuffo di fumo d'ombra con un anello scuro (teletrasporto).
func sbuffo_ombra(pos: Vector3, c: Dictionary, grande := 1.0) -> void:
	fumo(pos + Vector3(0, 0.9, 0), c.c2, 14, 0.7 * grande, 1.0, 1.5 * grande, 0.4)
	nube(pos, 1.6 * grande, 1.0, c.c2, c.colore)
	anello(pos, c.colore, 2.2 * grande, 0.45, 0.07)
	scintille(pos + Vector3(0, 1.0, 0), c.colore, 8, 3.0, 0.5, 0.0, 0.14)
	sagoma(pos, randf() * TAU, c.c2, Vector3.ZERO, 0.5)


# ------------------------------------------------------------------ temi per classe e Via
## Ogni classe ha un aspetto proprio, usato da tutte le sue tecniche; le Vie lo variano:
##   Lama: base = acciaio (fendenti netti, scintille di metallo), Fulmine = saette, Montagna = roccia (lastre, crepe, polvere);
##   Ombra: base e Pugnali = ombra e veleno (fumo viola, tagli scuri col bordo acido, gocce, copie), Arco = vento e penne;
##   Monaco: base e Ferro = fiamma del chi (pugni di fuoco, impronte di palmo, onde calde), Loto = fiori di loto e petali;
##   Mistico: base e Tempesta = astrale (stelle, costellazioni, lance di luce, vento stellato), Benedizione = luce di giada.
## Palette: [colore principale, secondario, terzo].
const PALETTE := {
	"acciaio": [Color(0.72, 0.82, 0.96), Color(1.0, 0.7, 0.25), Color(0.6, 0.66, 0.78)],
	"fulmine": [Color(0.3, 0.7, 1.0), Color(0.85, 0.95, 1.0), Color(0.62, 0.4, 1.0)],
	"roccia": [Color(0.85, 0.62, 0.25), Color(0.55, 0.5, 0.45), Color(1.0, 0.45, 0.15)],
	"ombra": [Color(0.55, 1.0, 0.15), Color(0.38, 0.14, 0.55), Color(0.7, 0.3, 1.0)],
	"vento": [Color(1.0, 0.76, 0.25), Color(0.96, 0.93, 0.8), Color(0.7, 0.95, 0.9)],
	"fiamma": [Color(1.0, 0.36, 0.04), Color(1.0, 0.68, 0.18), Color(1.0, 0.2, 0.03)],
	"loto": [Color(1.0, 0.45, 0.72), Color(1.0, 0.93, 0.96), Color(0.25, 0.9, 0.7)],
	"astrale": [Color(0.36, 0.26, 1.0), Color(1.0, 0.86, 0.45), Color(0.3, 0.8, 1.0)],
	"giada": [Color(0.25, 0.95, 0.5), Color(1.0, 0.88, 0.4), Color(0.7, 1.0, 0.8)],
}
const FORMA_TEMA := {"ombra": F_MIRINO, "vento": F_MIRINO, "fiamma": F_PALMO, "loto": F_LOTO, "astrale": F_COSTELLAZIONE, "giada": F_SIGILLO}


## Il tema di una tecnica: dalla Via, altrimenti dalla classe; "neutro" per le cavalcature e le tecniche senza classe.
static func tema_di(sk: Dictionary) -> String:
	match String(sk.get("via", "")):
		"fulmine": return "fulmine"
		"montagna": return "roccia"
		"pugnali": return "ombra"
		"arco": return "vento"
		"ferro": return "fiamma"
		"loto": return "loto"
		"tempesta": return "astrale"
		"benedizione": return "giada"
	match String(sk.get("cls", "")):
		"lama": return "acciaio"
		"ombra": return "ombra"
		"monaco": return "fiamma"
		"mistico": return "astrale"
	return "neutro"


## sk: voce di SKILLS; da: chi la usa; su: bersaglio (può mancare); m: messaggio `fx` del server
## (x, z dell'area, fx/fz di partenza dello scatto, ris, l livello, ally).
func tecnica(sk: Dictionary, da: Entita, su: Entita, m: Dictionary) -> void:
	var tema := tema_di(sk)
	var pal: Array = PALETTE.get(tema, [])
	var colore := vivo(Dati.colore(sk.get("color", 0xffffff)))
	var c2 := Color.WHITE
	var c3 := Color.WHITE
	if not pal.is_empty():
		colore = pal[0]
		c2 = pal[1]
		c3 = pal[2]
	var qui := da.global_position
	var la := su.global_position if su != null else qui
	if m.has("x") and m.has("z"):
		la = Dati.suolo(float(m.x), float(m.z))
	var tipo := String(sk.get("type", ""))
	# grado di padronanza: dal livello dell'abilità mandato dal server con l'effetto (`l`)
	var g := grado(int(m.get("l", 1)))
	if g == 4:
		colore = colore.lerp(ORO_PERFETTO, 0.55 if pal.is_empty() else 0.35)   # una tecnica Perfetta vira verso l'oro
	var c := {"sk": sk, "da": da, "su": su, "m": m, "colore": colore, "c2": c2, "c3": c3, "qui": qui, "la": la,
			"raggio": float(sk.get("radius", 3.0)), "forte": String(sk.get("ruolo", "")) == "potente", "tipo": tipo,
			"area": tipo.begins_with("aoe"), "g": g, "k": 1.0 + 0.08 * g, "mano": qui + Vector3(0, 1.5, 0),
			"fx": String(sk.get("fx", "")), "tema": tema, "cls": String(sk.get("cls", ""))}
	if sk.get("mount", false):
		TecnicheDestriero.tecnica(self, c)      # tecniche a cavallo: effetti propri per classe, niente segni a terra
		return
	if sk.get("sup", false):
		_suprema(c)
		_arricchisci(c)
		return
	if String(c.fx) == "risveglio":
		_risveglio_accendi(c)
		return
	# colpo base durante il Risveglio: colori del Risveglio e un effetto in più, diverso per classe
	c["pot"] = int(m.get("pot", 0)) == 1 and PALETTE_RISVEGLIO.has(c.cls)
	if c.pot:
		var pr: Array = PALETTE_RISVEGLIO[c.cls]
		c.colore = pr[0]
		c.c2 = pr[1]
		c.c3 = pr[2]
	if String(c.fx).begins_with("buff_"):
		if int(m.get("off", 0)) == 0:      # spegnendo l'aura non si rifà l'effetto d'accensione
			_buff_classe(c)
		return
	if c.cls == "ombra" and not c.fx in ["dash"]:
		# Ombra: effetti propri per ogni tecnica, lame o frecce secondo l'arma; niente segni a terra
		_ombra_kit(c)
		if c.pot:
			_potenziato(c)
		return
	if c.pot:
		_potenziato(c)
	_arricchisci(c)
	if int(m.get("ris", 0)) == 1:
		_risonanza(c)
	if c.forte:
		# gli scarichi potenti si annunciano: il segno del tema sotto i piedi e una carica di luce
		_firma(c, qui, 2.3, 0.9)
		bagliore(c.mano, colore, 2.6, 0.25)
	if c.fx == "dash":
		match String(c.tema):
			"vento": _folata(c)
			"fiamma", "loto": _balzo(c)
			"astrale", "giada": _passo_luce(c)
			_:
				if c.cls == "ombra":
					_teletrasporto(c)
				else:
					_carica(c)
		return
	match tema:
		"acciaio": _acciaio(c)
		"roccia": _roccia(c)
		"ombra": _ombra(c)
		"vento": _vento(c)
		"fiamma": _fiamma(c)
		"loto": _loto(c)
		"astrale": _astrale(c)
		"giada": _giada(c)
		_: _generico(c)


## Il segno del tema a terra: anello di rune, polvere, nube, fiore, sigillo… (annuncio dei colpi forti e grado Affinata).
func _firma(c: Dictionary, pos: Vector3, raggio: float, durata: float) -> void:
	var col: Color = c.colore
	match String(c.tema):
		"acciaio":
			anello(pos, col, raggio, 0.4, 0.06)
			scintille(pos + Vector3(0, 0.3, 0), c.c2, 10, 4.0, 0.4, -10.0, 0.12)
		"roccia":
			polvere(pos, raggio * 0.8, 12)
			anello(pos, col, raggio, 0.5, 0.2)
		"ombra":
			nube(pos, raggio * 0.9, durata + 0.3, c.c2, col)
		"vento":
			forma(pos, F_VENTO, c.c3, c.c2, raggio * 1.1, durata)
		"fiamma":
			fiamme(pos, col, 14, raggio * 0.5, 1.8, 0.7)
			anello(pos, col, raggio, 0.5, 0.14)
		"loto":
			forma(pos, F_LOTO, col, c.c2, raggio * 0.9, durata)
		"giada":
			forma(pos, F_SIGILLO, col, c.c2, raggio * 0.9, durata)
		"astrale":
			forma(pos, F_STELLA, col, c.c3, raggio * 0.95, durata)
		_:
			rune(pos, col, raggio, durata)


# ------------------------------------------------------------------ Lama
func _acciaio(c: Dictionary) -> void:
	var da: Entita = c.da
	var su: Entita = c.su
	var col: Color = c.colore
	var qui: Vector3 = c.qui
	var la: Vector3 = c.la
	var forte: bool = c.forte
	var k: float = c.k
	match String(c.fx):
		"slash":
			var inc := randf_range(-0.6, 0.6)
			taglio(qui + Vector3(0, 1.2, 0), da.r, col, (3.3 if forte else 2.6) * k, 2.5, 0.26, inc)
			if su != null:
				scintille(su.petto(), c.c2, 26 if forte else 12, 8.0, 0.4, -18.0, 0.12)
				bagliore(su.petto(), col.lightened(0.3), 2.4 if forte else 1.6, 0.15)
			if forte:
				# affondo e croce: un secondo fendente di traverso e una linea netta fino al bersaglio
				_dopo(0.07, taglio.bind(qui + Vector3(0, 1.2, 0), da.r, col.lightened(0.3), 3.6, 2.6, 0.3, -inc * 1.3 + 0.6))
				scia(qui, la, col, 0.5, 0.3)
				anello(la, col, 2.8, 0.32, 0.06)
				scuoti(0.35)
		"spin":
			taglio(qui + Vector3(0, 1.1, 0), da.r, col, float(c.raggio) * 0.95, TAU, 0.3)
			anello(qui, col, float(c.raggio), 0.4, 0.07)
			scintille(qui + Vector3(0, 1.0, 0), c.c2, 28, 9.0, 0.45, -10.0, 0.12)
		_:
			_generico(c)


func _roccia(c: Dictionary) -> void:
	var col: Color = c.colore
	var qui: Vector3 = c.qui
	var la: Vector3 = c.la
	var k: float = c.k
	match String(c.fx):
		"quake":
			var centro := la if c.tipo == "strike" else qui
			var r := (float(c.raggio) if c.area else 3.6) * k
			anello(centro, col, r, 0.6, 0.24)
			anello(centro, c.c2, r * 0.7, 0.45, 0.3, 1.0)
			crepe(centro, col.lerp(c.c3, 0.25), r, 2.6)
			if c.tipo == "strike":
				lastre_linea(qui, la, 5, 0.7)
			_dopo(0.1, lastre.bind(centro, r * 0.8, 7 + int(c.g), 2.2 * k, 1.0))
			polvere(centro, r, 28 if c.forte else 14)
			schegge(centro + Vector3(0, 0.4, 0), 16, 7.0)
			bagliore(centro + Vector3(0, 0.5, 0), col.lightened(0.3), r * 1.1, 0.25)
			if c.forte:
				_dopo(0.18, anello.bind(centro, col.lightened(0.3), r * 1.35, 0.6, 0.1))
			scuoti(0.8 if c.forte else 0.45)
		_:
			_generico(c)


# ------------------------------------------------------------------ Ombra
func _ombra(c: Dictionary) -> void:
	var da: Entita = c.da
	var su: Entita = c.su
	var col: Color = c.colore
	var c2: Color = c.c2
	var qui: Vector3 = c.qui
	var la: Vector3 = c.la
	var forte: bool = c.forte
	var k: float = c.k
	match String(c.fx):
		"slash":
			var veleno := String(c.sk.get("via", "")) == "pugnali"
			var p := su.petto() if su != null else qui + Vector3(0, 1.2, 0)
			for i in range(3 if forte else 2):
				_dopo(0.06 * i, taglio_ombra.bind(p, da.r + randf_range(-1.0, 1.0), col, c2, (2.2 + 0.25 * i) * k, 2.2, 0.4, randf_range(-1.2, 1.2)))
			fumo(p - Vector3(0, 0.5, 0), c2, 12 if forte else 6, 0.7, 0.9, 1.1)
			if veleno:
				gocce(p, col, 18 if forte else 8)
			if forte:
				sagoma(qui, da.r, c2, (la - qui) * 0.9, 0.5)
				nube(la, 2.4, 1.2, c2, col)
				anello(la, col, 2.6, 0.4, 0.07)
				scuoti(0.4)
		"rain":
			var R := float(c.raggio)
			anello(la, col, R, 0.8, 0.07, 0.4)
			nube(la, R * 0.85, 1.6, c2, col)
			for i in range(12 + int(c.g) * 2):
				var a := randf() * TAU
				var d := R * sqrt(randf())
				_dopo(0.04 * i, _lama_dal_cielo.bind(Dati.suolo(la.x + cos(a) * d, la.z + sin(a) * d), col, c2))
		"mark":
			if su != null:
				forma(la, F_MIRINO, col, c.c3, 2.2, 1.1)
				fumo(la + Vector3(0, 0.3, 0), c2, 8, 0.4, 1.2, 1.0, 1.4)
				gocce(su.testa(), col, 8)
				bagliore(su.testa(), c.c3, 1.8, 0.3)
		_:
			_generico(c)


# ------------------------------------------------------------------ Risvegli (cooldown offensivi)
## Colori dei colpi base durante il Risveglio: [principale, secondo, terzo]. Lama rosso e oro del drago, Ombra bianco
## lunare con bordo cremisi, Monaco bianco e oro del sole, Mistico oro e bianco degli astri.
const PALETTE_RISVEGLIO := {
	"lama": [Color(1.0, 0.3, 0.08), Color(1.0, 0.8, 0.25), Color(1.0, 0.55, 0.1)],
	"ombra": [Color(0.95, 0.95, 1.0), Color(0.05, 0.03, 0.08), Color(1.0, 0.15, 0.25)],
	"monaco": [Color(1.0, 0.95, 0.7), Color(1.0, 0.8, 0.3), Color(1.0, 1.0, 1.0)],
	"mistico": [Color(1.0, 0.85, 0.3), Color(1.0, 1.0, 0.9), Color(1.0, 0.6, 0.15)],
}
const RISVEGLIO_DI := {"risveglio_drago": "lama", "eclissi": "ombra", "cuore_sole": "monaco", "congiunzione": "mistico"}


## Accensione del Risveglio: uno scoppio attorno al corpo nei colori della classe (niente segni a terra).
func _risveglio_accendi(c: Dictionary) -> void:
	var pr: Array = PALETTE_RISVEGLIO.get(c.cls, [Color.WHITE, Color.WHITE, Color.WHITE])
	var p: Vector3 = c.qui + Vector3(0, 1.1, 0)
	bagliore(p, pr[0], 4.5, 0.4)
	scintille(p, pr[1], 40, 9.0, 0.7, -3.0, 0.16)
	match String(c.cls):
		"lama":
			fiamme(c.qui, pr[0], 26, 0.7, 3.2, 0.9)
			for i in range(3):
				_dopo(0.08 * i, taglio.bind(p, randf() * TAU, pr[1], 2.6 + 0.4 * i, TAU, 0.35, randf_range(-0.5, 0.5)))
		"ombra":
			fumo(p, pr[1], 16, 1.0, 1.2, 1.6, 0.4)
			for i in range(4):
				_dopo(0.06 * i, taglio_ombra.bind(p, randf() * TAU, pr[0], pr[1], 2.6, 2.6, 0.35, randf_range(-1.2, 1.2)))
		"monaco":
			fiamme(c.qui, pr[1], 30, 0.8, 3.6, 1.0)
			stelle(p, pr[2], 16, 6.0, 0.8, 1.5, 0.3)
		_:
			stelle(p, pr[0], 28, 7.0, 1.0, 2.0, 0.34)
			spirale(c.qui, pr[1], 1.0, 3.0, 1.0, 2.5, "stella", 0.3)
	scuoti(0.35)


## L'effetto in più di un colpo base risvegliato (il server ha già fatto il secondo colpo o lo scoppio).
func _potenziato(c: Dictionary) -> void:
	var da: Entita = c.da
	var su: Entita = c.su
	var col: Color = c.colore
	var c2: Color = c.c2
	var c3: Color = c.c3
	var la: Vector3 = c.la
	var p := su.petto() if su != null else la + Vector3(0, 1.2, 0)
	if c.area and su == null:
		p = c.qui + Vector3(0, 1.2, 0)
	match String(c.cls):
		"lama":
			# il secondo colpo: un fendente d'oro di traverso, con lingue di fuoco e scintille
			_dopo(0.14, taglio.bind(c.qui + Vector3(0, 1.2, 0), da.r, c2, (float(c.raggio) if c.area else 3.2), (TAU if c.area else 2.6), 0.3, randf_range(0.7, 1.1)))
			_dopo(0.14, fiamme.bind(p - Vector3(0, 0.9, 0), col, 12, 0.5, 2.2, 0.5))
			_dopo(0.14, scintille.bind(p, c2, 22, 9.0, 0.45, -14.0, 0.13))
		"ombra":
			# il taglio d'eclissi: una mezzaluna bianca col bordo cremisi e un alone scuro
			_dopo(0.16, taglio_ombra.bind(p, da.r + PI * 0.5, col, c2, 2.9, 2.8, 0.34, randf_range(-0.4, 0.4)))
			_dopo(0.16, scintille.bind(p, c3, 12, 6.0, 0.4, -6.0, 0.11))
			_dopo(0.16, bagliore.bind(p, col, 1.8, 0.16))
		"monaco":
			# la vampa del sole: scoppio di fiamme chiare e faville tutt'attorno al bersaglio
			_dopo(0.08, fiamme.bind(p - Vector3(0, 1.0, 0), c2, 26, 2.2, 2.6, 0.6))
			_dopo(0.08, stelle.bind(p, c3, 14, 8.0, 0.5, 0.0, 0.3))
			_dopo(0.08, bagliore.bind(p, col, 4.0, 0.25))
			_dopo(0.08, scuoti.bind(0.25))
		"mistico":
			# il secondo astro: una stella d'oro che segue la prima, con una pioggia di scintille all'arrivo
			if su != null:
				_dopo(0.14, proiettile.bind(c.mano + Vector3(randf_range(-0.6, 0.6), 0.8, 0), su, c3, 34.0, 0.2, stelle.bind(p, c2, 14, 6.0, 0.6, 0.5, 0.3), false, 20))
			else:
				_dopo(0.14, stelle.bind(p, c2, 20, 7.0, 0.7, 0.5, 0.32))


## Finché dura il Risveglio il corpo arde nei colori della classe: particelle agganciate a chi l'ha acceso.
class Temporaneo:
	extends Node3D
	var resto := 1.0

	func _process(dt: float) -> void:
		resto -= dt
		if resto <= 0.0:
			set_process(false)
			for f in get_children():
				if f is CPUParticles3D:
					(f as CPUParticles3D).emitting = false
			get_tree().create_timer(1.6).timeout.connect(queue_free)


func risveglio(chi: Entita, id: String, ms: float) -> void:
	var cls := String(RISVEGLIO_DI.get(id, ""))
	if chi == null or not PALETTE_RISVEGLIO.has(cls):
		return
	var vecchio := chi.get_node_or_null("risveglio")
	if vecchio != null:
		vecchio.name = "risveglio_vecchio"
		vecchio.queue_free()
	var pr: Array = PALETTE_RISVEGLIO[cls]
	var g := Temporaneo.new()
	g.name = "risveglio"
	g.resto = ms / 1000.0
	chi.add_child(g)
	var h := chi.corpo.altezza if chi.corpo != null else 2.0
	# lingue che salgono lungo il corpo
	var su := Equip.particelle(g, 22, 0.42, 0.8, pr[0], pr[2], 0.85, cls == "ombra")
	su.position = Vector3(0, 0.3, 0)
	su.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	su.emission_sphere_radius = 0.45
	su.direction = Vector3.UP
	su.spread = 14.0
	su.initial_velocity_min = 1.6
	su.initial_velocity_max = 3.2
	su.gravity = Vector3(0, 1.2, 0)
	# faville (o stelle) che orbitano all'altezza del petto
	var fa := Equip.particelle(g, 14, 0.2, 1.1, pr[1] if cls != "ombra" else pr[2], pr[0], 0.95)
	fa.position = Vector3(0, h * 0.55, 0)
	fa.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	fa.emission_ring_axis = Vector3.UP
	fa.emission_ring_radius = 0.75
	fa.emission_ring_inner_radius = 0.6
	fa.emission_ring_height = h * 0.5
	fa.direction = Vector3.UP
	fa.spread = 40.0
	fa.initial_velocity_min = 0.4
	fa.initial_velocity_max = 1.2
	if cls == "mistico" or cls == "monaco":
		fa.material_override = Afflizioni.mat_stella().duplicate()
		(fa.material_override as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		(fa.material_override as StandardMaterial3D).vertex_color_use_as_albedo = true
		(fa.material_override as StandardMaterial3D).albedo_color = Color.WHITE


# ------------------------------------------------------------------ Ombra: kit a generatore e scarichi
## Ogni tecnica dell'Ombra ha il suo effetto, diverso con i pugnali (tagli d'ombra dal bordo acido, fumo viola, copie
## d'ombra, gocce di veleno) e con l'arco (frecce vere, scie d'aria, penne). Niente cerchi, rune o segni sul terreno:
## solo colpi, proiettili, fumo e particelle. I gradi dell'abilità aggiungono colpi e copie, non strati a terra.
func _arma_di(e: Entita) -> String:
	var w = e.info.get("w") if e != null else null
	if w != null and Dati.ITEMS.has(w):
		return String(Dati.ITEMS[w].get("wt", ""))
	return ""


func _ombra_kit(c: Dictionary) -> void:
	var da: Entita = c.da
	var arco := _arma_di(da) == "bow"
	if c.get("pot", false):
		if arco:
			_ombra_arco(c)
		else:
			_ombra_lame(c)
		return
	if arco:
		var pv: Array = PALETTE.vento
		c.colore = pv[0] if int(c.g) < 4 else (pv[0] as Color).lerp(ORO_PERFETTO, 0.35)
		c.c2 = pv[1]
		c.c3 = pv[2]
		_ombra_arco(c)
	else:
		var po: Array = PALETTE.ombra
		c.colore = po[0] if int(c.g) < 4 else (po[0] as Color).lerp(ORO_PERFETTO, 0.35)
		c.c2 = po[1]
		c.c3 = po[2]
		_ombra_lame(c)


func _ombra_lame(c: Dictionary) -> void:
	var da: Entita = c.da
	var su: Entita = c.su
	var col: Color = c.colore
	var c2: Color = c.c2
	var c3: Color = c.c3
	var qui: Vector3 = c.qui
	var la: Vector3 = c.la
	var g: int = c.g
	var veleno := String(c.sk.get("via", "")) == "pugnali"
	var p := su.petto() if su != null else la + Vector3(0, 1.2, 0)
	match String(c.fx):
		"slash":
			# Colpo Rapido: una stoccata sola, secca
			taglio_ombra(p, da.r + randf_range(-0.5, 0.5), col, c2, 1.9, 1.7, 0.22, randf_range(-0.9, 0.9))
			scintille(p, c3, 6 + g * 2, 4.5, 0.3, -8.0, 0.1)
			fumo(p - Vector3(0, 0.3, 0), c2, 3, 0.3, 0.6, 0.8)
		"gemello":
			# Taglio Gemello: due tagli che si incrociano a X, il secondo viola
			var inc := randf_range(0.7, 1.0)
			taglio_ombra(p, da.r, col, c2, 2.3, 2.0, 0.26, inc)
			_dopo(0.11, taglio_ombra.bind(p, da.r, c3, c2, 2.4, 2.0, 0.26, -inc))
			_dopo(0.11, scintille.bind(p, col, 10 + g * 3, 6.0, 0.35, -10.0, 0.11))
			if g >= 2:
				_dopo(0.2, taglio_ombra.bind(p, da.r + PI, col, c2, 2.0, 1.8, 0.22, 0.0))
			if veleno:
				gocce(p, col, 6)
		"pesante":
			# colpo pesante: una copia d'ombra si lancia sul bersaglio, poi il colpo
			_guizzo(qui, la, c2, c3)
			if veleno:
				# Morso della Vipera: due zanne che si chiudono dall'alto, schizzo di veleno
				var lato := Vector3(cos(da.r), 0, -sin(da.r)) * 0.35
				_dopo(0.1, taglio_ombra.bind(p + lato + Vector3(0, 0.5, 0), da.r, col, c2, 2.6, 1.5, 0.3, 1.35))
				_dopo(0.1, taglio_ombra.bind(p - lato + Vector3(0, 0.5, 0), da.r, col, c2, 2.6, 1.5, 0.3, -1.35))
				_dopo(0.18, gocce.bind(p, col, 26 + g * 4))
				_dopo(0.18, fumo.bind(p, Color(0.12, 0.4, 0.08), 8, 0.6, 1.0, 1.1, 1.0))
				_dopo(0.18, bagliore.bind(p, col, 2.6, 0.2))
			else:
				_dopo(0.1, taglio_ombra.bind(p, da.r, c3, c2, 3.5, 2.6, 0.32, randf_range(-0.3, 0.3)))
				_dopo(0.16, scintille.bind(p, c3, 22, 8.0, 0.4, -12.0, 0.12))
				_dopo(0.16, bagliore.bind(p, c3, 2.4, 0.18))
			_dopo(0.16, fumo.bind(p - Vector3(0, 0.4, 0), c2, 10, 0.8, 0.9, 1.2))
			_dopo(0.16, scuoti.bind(0.4))
		"danza":
			# Danza delle Lame: copie d'ombra che attraversano il gruppo da ogni lato, un fendente a ondata
			var R := float(c.raggio)
			var onde := int(c.sk.get("waves", 5))
			var passo := float(c.sk.get("waveGap", 0.28))
			for i in range(onde):
				_dopo(passo * i, _onda_danza.bind(la, R, col, c2, c3, i == onde - 1, g))
		"ventaglio":
			# Ventaglio di Lame: una raggiera di coltelli lanciati che attraversa la zona
			var R2 := float(c.raggio)
			var verso := atan2(la.x - qui.x, la.z - qui.z)
			taglio_ombra(qui + Vector3(0, 1.2, 0), verso, col, c2, 2.4, 3.0, 0.26, 0.0)
			var n := 8 + g * 2
			for i in range(n):
				var a := verso + lerpf(-1.9, 1.9, float(i) / float(n - 1))
				var fine := Dati.suolo(la.x + sin(a) * R2 * 0.9, la.z + cos(a) * R2 * 0.9) + Vector3(0, 0.9, 0)
				dardo(c.mano, fine, col if i % 2 == 0 else c3, 34.0, "lama", fumo.bind(fine, c2, 2, 0.25, 0.5, 0.7))
			_dopo(0.12, scintille.bind(p, col, 14, 7.0, 0.35, -8.0, 0.11))
		"mark":
			# Colpo alla Gola: una stoccata muta, fumo attorno alla testa
			if su != null:
				var gola := su.testa() - Vector3(0, 0.3, 0)
				taglio_ombra(gola, da.r, c3, c2, 1.5, 1.2, 0.2, 0.0)
				bagliore(gola, c3, 1.4, 0.15)
				fumo(gola, c2, 7, 0.35, 1.0, 0.9, 0.6)
				scintille(gola, Color.WHITE, 6, 3.5, 0.3, -6.0, 0.1)
		_:
			_ombra(c)


func _onda_danza(la: Vector3, R: float, col: Color, c2: Color, c3: Color, ultima: bool, g: int) -> void:
	var a := randf() * TAU
	var fuori := Vector3(sin(a), 0, cos(a)) * R * 0.8
	_guizzo(la + fuori, la - fuori, c2, c3)
	var centro := la + Vector3(0, 1.2, 0)
	taglio_ombra(centro, a + PI, col if not ultima else c3, c2, minf(R, 4.2), 2.8, 0.3, randf_range(-0.5, 0.5))
	for k in range(2 + (1 if g >= 2 else 0)):
		var b := randf() * TAU
		var d := R * sqrt(randf()) * 0.85
		var q := la + Vector3(sin(b) * d, 1.1, cos(b) * d)
		taglio_ombra(q, randf() * TAU, c3 if k % 2 == 0 else col, c2, 1.7, 1.8, 0.24, randf_range(-1.1, 1.1))
		scintille(q, col, 5, 4.0, 0.3, -8.0, 0.1)
	fumo(la + Vector3(0, 0.5, 0), c2, 5, R * 0.45, 0.8, 1.2)
	if ultima:
		scintille(centro, c3, 26, 9.0, 0.45, -10.0, 0.13)
		scuoti(0.4)


func _ombra_arco(c: Dictionary) -> void:
	var da: Entita = c.da
	var su: Entita = c.su
	var col: Color = c.colore
	var c2: Color = c.c2
	var c3: Color = c.c3
	var qui: Vector3 = c.qui
	var la: Vector3 = c.la
	var g: int = c.g
	var mano: Vector3 = c.mano
	var p := su.petto() if su != null else la + Vector3(0, 1.2, 0)
	var dir := (la - qui)
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3(sin(da.r), 0, cos(da.r))
	var lato := Vector3(dir.z, 0, -dir.x)
	match String(c.fx):
		"slash":
			# Colpo Rapido: una freccia tesa
			dardo(mano, su if su != null else p, col, 52.0, "freccia", _impatto_freccia.bind(p, c2, col, 5))
		"gemello":
			# Taglio Gemello: due frecce una dietro l'altra, da due lati
			dardo(mano + lato * 0.25, su if su != null else p, col, 52.0, "freccia", _impatto_freccia.bind(p, c2, col, 5))
			_dopo(0.12, dardo.bind(mano - lato * 0.25, su if su != null else p, c3, 52.0, "freccia", _impatto_freccia.bind(p, c2, c3, 7 + g * 2)))
		"pesante":
			# Freccia Perforante: una freccia grossa che passa il bersaglio da parte a parte
			bagliore(mano, col, 1.6, 0.18)
			dardo(mano, su if su != null else p, col, 64.0, "freccia", _impatto_perforante.bind(p, dir, col, c2, c3, g), 1.9)
		"danza":
			# Pioggia di Frecce: scrosci che cadono dal cielo su tutta la zona
			var R := float(c.raggio)
			var onde := int(c.sk.get("waves", 5))
			var passo := float(c.sk.get("waveGap", 0.28))
			# la salva che sale: un fascio di frecce verso il cielo
			for i in range(5):
				dardo(mano, mano + Vector3(randf_range(-1.5, 1.5), 16.0, randf_range(-1.5, 1.5)) + dir * 4.0, col, 60.0, "freccia")
			for i in range(onde):
				_dopo(0.2 + passo * i, _scroscio.bind(la, R, col, c2, 7 + g, i == onde - 1))
		"ventaglio":
			# Ventaglio: una raggiera di frecce che si apre sulla zona
			var R2 := float(c.raggio)
			var verso := atan2(dir.x, dir.z)
			var n := 7 + g
			for i in range(n):
				var a := verso + lerpf(-1.25, 1.25, float(i) / float(n - 1))
				var dist := (la - qui).length()
				var fine := Dati.suolo(la.x + sin(a) * R2 * 0.85 - dir.x * 0.5, la.z + cos(a) * R2 * 0.85 - dir.z * 0.5) + Vector3(0, 1.0, 0)
				if dist > R2 * 1.5:
					fine = Dati.suolo(la.x + lato.x * lerpf(-R2, R2, float(i) / float(n - 1)) * 0.9, la.z + lato.z * lerpf(-R2, R2, float(i) / float(n - 1)) * 0.9) + Vector3(0, 1.0, 0)
				dardo(mano, fine, col, 50.0, "freccia", _impatto_freccia.bind(fine, c2, col, 3))
			petali(mano, c2, 6, 0.4, 0.9, -0.5, Vector2(0.07, 0.3))
		"mark":
			# Colpo alla Gola con l'arco: una freccia corta alla gola
			if su != null:
				var gola := su.testa() - Vector3(0, 0.3, 0)
				dardo(mano, gola, c3, 60.0, "freccia", bagliore.bind(gola, c3, 1.3, 0.15), 0.8)
				_dopo(0.1, fumo.bind(gola, Color(0.25, 0.25, 0.3), 6, 0.3, 0.9, 0.8, 0.6))
		_:
			_vento(c)


func _impatto_freccia(p: Vector3, penne: Color, col: Color, quante: int) -> void:
	scintille(p, col, quante, 4.5, 0.3, -8.0, 0.1)
	petali(p, penne, maxi(2, quante / 2), 0.3, 0.9, -0.7, Vector2(0.06, 0.28))


func _impatto_perforante(p: Vector3, dir: Vector3, col: Color, c2: Color, c3: Color, g: int) -> void:
	# la freccia esce dall'altra parte e prosegue: scia oltre il bersaglio, penne e scintille
	var oltre := p + dir * (5.0 + g)
	dardo(p, oltre, col, 64.0, "freccia", Callable(), 1.9)
	scintille(p, col, 24 + g * 4, 9.0, 0.45, -10.0, 0.13)
	petali(p, c2, 12, 0.5, 1.2, -0.6, Vector2(0.07, 0.34))
	bagliore(p, col.lightened(0.3), 2.4, 0.16)
	scuoti(0.4)


func _scroscio(la: Vector3, R: float, col: Color, c2: Color, quante: int, ultima: bool) -> void:
	for i in range(quante):
		var a := randf() * TAU
		var d := R * sqrt(randf())
		var q := Dati.suolo(la.x + sin(a) * d, la.z + cos(a) * d)
		_dopo(randf() * 0.15, dardo.bind(q + Vector3(randf_range(-2.0, 2.0), 14.0, randf_range(-2.0, 2.0)), q + Vector3(0, 0.15, 0), col, 62.0, "freccia",
				_impatto_freccia.bind(q + Vector3(0, 0.4, 0), c2, col, 3)))
	if ultima:
		scuoti(0.3)
		polvere(la, R * 0.7, 14)


## I Marchi esplodono (Esecuzione dell'Ombra): le schegge cremisi si chiudono sul nemico una dopo l'altra, poi lo scoppio.
## Più Marchi, più grande: n = 1..5. Niente segni a terra.
func esplosione_marchi(su: Entita, n: int) -> void:
	if su == null:
		return
	var p := su.petto()
	var rosso := Color(1.0, 0.12, 0.3)
	var scuro := Color(0.08, 0.02, 0.1)
	var k := float(clampi(n, 1, 5))
	for i in range(int(k)):
		var a := TAU * i / k + randf() * 0.4
		_dopo(0.035 * i, taglio_ombra.bind(p, a, rosso, scuro, 2.0 + 0.25 * k, 2.0, 0.3, randf_range(-1.3, 1.3)))
	var t0 := 0.035 * k + 0.03
	_dopo(t0, bagliore.bind(p, Color(1.0, 0.85, 0.9), 1.6 + 0.9 * k, 0.22))
	_dopo(t0, bagliore.bind(p, rosso, 2.4 + 1.1 * k, 0.35))
	_dopo(t0, scintille.bind(p, rosso, 10 + int(8 * k), 6.0 + 1.6 * k, 0.55, -9.0, 0.14))
	_dopo(t0, fumo.bind(p - Vector3(0, 0.3, 0), scuro, 4 + int(2 * k), 0.4 + 0.15 * k, 0.9, 1.3, 0.5))
	_dopo(t0, petali.bind(p, rosso, 4 + int(3 * k), 0.4, 0.9, -1.2, Vector2(0.08, 0.3), true, rosso))
	_dopo(t0, scuoti.bind(0.2 + 0.1 * k))


## Guizzo d'ombra da un punto a un altro: una fila di sbuffi di fumo scuro e scintille viola (una copia che attraversa).
func _guizzo(da: Vector3, a: Vector3, scuro: Color, viola: Color) -> void:
	var n := clampi(int((a - da).length() / 0.9), 3, 7)
	for i in range(n):
		var q := da.lerp(a, float(i) / float(n - 1)) + Vector3(0, 1.0, 0)
		_dopo(0.025 * i, fumo.bind(q, scuro, 3, 0.25, 0.5, 1.4, 0.2))
	scintille(a + Vector3(0, 1.1, 0), viola, 6, 3.0, 0.3, 0.0, 0.1)


static var _mat_coda: Dictionary = {}


## Dardo che vola dritto verso un punto o un bersaglio: una freccia vera o un coltello da lancio, con una coda sottile.
## Niente globi di luce: all'arrivo chiama solo `fine`.
func dardo(da: Vector3, verso, colore: Color, velocita := 50.0, tipo := "freccia", fine := Callable(), scala := 1.0) -> void:
	var nodo := Node3D.new()
	nodo.position = da
	add_child(nodo)
	var corpo := Node3D.new()
	corpo.scale = Vector3.ONE * scala
	nodo.add_child(corpo)
	if tipo == "lama":
		var lama := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.075, 0.014, 0.36)
		lama.mesh = b
		lama.material_override = Edifici.mat(Color(0.1, 0.09, 0.14), 0.3, 0.8, 0.0)
		lama.position.z = -0.12
		corpo.add_child(lama)
		var filo := MeshInstance3D.new()
		var bf := BoxMesh.new()
		bf.size = Vector3(0.09, 0.006, 0.34)
		filo.mesh = bf
		filo.material_override = Edifici.mat(colore, 0.3, 0.0, 2.5)
		filo.position.z = -0.12
		corpo.add_child(filo)
		var manico := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.03, 0.03, 0.14)
		manico.mesh = bm
		manico.material_override = Edifici.mat(Color(0.2, 0.1, 0.25), 0.8, 0.0, 0.0)
		manico.position.z = 0.13
		corpo.add_child(manico)
	else:
		var asta := MeshInstance3D.new()
		var b2 := BoxMesh.new()
		b2.size = Vector3(0.024, 0.024, 0.85)
		asta.mesh = b2
		asta.material_override = Edifici.mat(Color(0.45, 0.3, 0.16), 0.8, 0.0, 0.0)
		corpo.add_child(asta)
		var punta := MeshInstance3D.new()
		var cp := CylinderMesh.new()
		cp.top_radius = 0.0
		cp.bottom_radius = 0.04
		cp.height = 0.16
		cp.radial_segments = 6
		punta.mesh = cp
		punta.material_override = Edifici.mat(colore.lightened(0.3), 0.3, 0.6, 1.5)
		punta.rotation.x = -PI * 0.5
		punta.position.z = -0.5
		corpo.add_child(punta)
		for k in range(2):
			var penna := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(0.11, 0.2)
			penna.mesh = q
			var mp := Edifici.mat(Color(0.95, 0.93, 0.85), 0.9, 0.0, 0.0)
			mp.cull_mode = BaseMaterial3D.CULL_DISABLED
			penna.material_override = mp
			penna.rotation = Vector3(PI * 0.5, 0, k * PI * 0.5)
			penna.position.z = 0.36
			corpo.add_child(penna)
	for mi in corpo.get_children():
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# coda: due nastri incrociati che sfumano dietro al dardo
	var chiave := colore.to_html()
	if not _mat_coda.has(chiave):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var gr := Gradient.new()
		gr.offsets = PackedFloat32Array([0.0, 1.0])
		gr.colors = PackedColorArray([Color(colore.r, colore.g, colore.b, 0.55), Color(colore.r, colore.g, colore.b, 0.0)])
		var gt := GradientTexture2D.new()
		gt.gradient = gr
		gt.fill_from = Vector2(0.5, 0.0)
		gt.fill_to = Vector2(0.5, 1.0)
		gt.width = 4
		gt.height = 32
		m.albedo_texture = gt
		_mat_coda[chiave] = m
	for k in range(2):
		var nastro := MeshInstance3D.new()
		var qn := QuadMesh.new()
		qn.size = Vector2(0.07 * scala, 1.5 * scala)
		nastro.mesh = qn
		nastro.material_override = _mat_coda[chiave]
		nastro.rotation = Vector3(-PI * 0.5, 0, 0)
		nastro.rotate_object_local(Vector3(0, 1, 0), k * PI * 0.5)
		nastro.position.z = 0.75 * scala + 0.2
		nastro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nodo.add_child(nastro)
	var meta0: Vector3 = (verso as Entita).petto() if verso is Entita else verso
	if (meta0 - da).length() > 0.05:
		nodo.look_at(meta0, Vector3.UP if absf((meta0 - da).normalized().y) < 0.98 else Vector3.RIGHT)
	_proiettili.append({"n": nodo, "verso": verso, "v": velocita, "c": colore, "fine": fine, "t": 0.0, "r": 0.1, "dardo": true})


## Un coltello d'ombra che cala dal cielo: bordo acido, lascia uno sbuffo di fumo.
func _lama_dal_cielo(p: Vector3, col: Color, c2: Color) -> void:
	proiettile(p + Vector3(randf_range(-1, 1), 12.0, randf_range(-1, 1)), p + Vector3(0, 0.2, 0), col, 45.0, 0.11,
			fumo.bind(p + Vector3(0, 0.6, 0), c2, 4, 0.4, 0.7, 1.0), false, 14)


func _vento(c: Dictionary) -> void:
	var su: Entita = c.su
	var col: Color = c.colore
	var qui: Vector3 = c.qui
	var la: Vector3 = c.la
	var forte: bool = c.forte
	match String(c.fx):
		"arrow":
			if su != null:
				proiettile(c.mano, su, col, 48.0, 0.09, _impatto_vento.bind(la, c), false, 24)
			scia_aria(qui, la, c.c2, 0.7 if forte else 0.35, 0.35)
			petali(c.mano, c.c2, 5, 0.4, 1.0, -0.5, Vector2(0.07, 0.34))
			if forte:
				scia_aria(qui, la, c.c3, 1.1, 0.45)
				forma(la, F_MIRINO, col, c.c2, 1.9, 0.9)
				forma(la, F_VENTO, c.c3, c.c2, 3.0, 1.1)
				scuoti(0.3)
		_:
			_generico(c)


func _impatto_vento(la: Vector3, c: Dictionary) -> void:
	petali(la + Vector3(0, 1.2, 0), c.c2, 12 if c.forte else 6, 0.5, 1.2, -0.6, Vector2(0.07, 0.34))
	anello(la, c.c3, 2.6 if c.forte else 1.4, 0.35, 0.07)
	scintille(la + Vector3(0, 1.2, 0), c.colore, 8, 4.0, 0.4, -6.0, 0.12)


# ------------------------------------------------------------------ Monaco
func _fiamma(c: Dictionary) -> void:
	var da: Entita = c.da
	var su: Entita = c.su
	var col: Color = c.colore
	var c2: Color = c.c2
	var qui: Vector3 = c.qui
	var la: Vector3 = c.la
	var forte: bool = c.forte
	var k: float = c.k
	match String(c.fx):
		"slash":
			var p := su.petto() if su != null else qui + Vector3(0, 1.2, 0)
			taglio(qui + Vector3(0, 1.2, 0), da.r, col, 2.4 * k, 2.0, 0.3, randf_range(-0.4, 0.4), 0.25)
			forma(la, F_PALMO, col, c2, (3.4 if forte else 2.3), 0.8)
			fiamme(p, col, 22 if forte else 12, 0.4, 1.8, 0.7)
			bagliore(p, c2, 3.4 if forte else 2.2, 0.2)
			anello(la, col, 2.8 if forte else 2.0, 0.4, 0.14)
			if forte:
				# raffica: una fila di pugni in rapida successione, poi l'impronta grande e l'onda calda
				for i in range(6):
					_dopo(0.06 * i, _pugno_fuoco.bind(p + Vector3(randf_range(-0.5, 0.5), randf_range(-0.4, 0.4), randf_range(-0.5, 0.5)), col, c2))
				_dopo(0.36, forma.bind(la, F_PALMO, c2, col, 3.0, 1.0))
				_dopo(0.36, anello.bind(la, col, 4.6, 0.6, 0.12, 1.0))
				scuoti(0.5)
		"spin":
			taglio(qui + Vector3(0, 1.1, 0), da.r, col, float(c.raggio) * 0.95, TAU, 0.38, 0.0, 0.25)
			anello(qui, col, float(c.raggio), 0.5, 0.18)
			_dopo(0.1, anello.bind(qui, c2, float(c.raggio) * 0.65, 0.5, 0.1))
			fiamme(qui, col, 28, float(c.raggio) * 0.6, 2.2, 0.7)
		"bolt":
			bagliore(c.mano, c2, 1.8, 0.2)
			if su != null:
				proiettile(c.mano, su, col, 28.0, (0.34 if forte else 0.24) * k, _impatto_fuoco.bind(la, c), true, 30)
		_:
			_generico(c)


func _pugno_fuoco(p: Vector3, col: Color, c2: Color) -> void:
	bagliore(p, c2, 1.6, 0.14)
	scintille(p, col, 8, 5.0, 0.35)
	fiamme(p, col, 5, 0.2, 1.2, 0.4)


## Il colpo di chi arriva: l'impronta di palmo sul terreno, onde calde che si allargano e fiamme.
func _impatto_fuoco(la: Vector3, c: Dictionary) -> void:
	var f: bool = c.forte
	forma(la, F_PALMO, c.colore, c.c2, 3.4 if f else 2.4, 1.0)
	anello(la, c.colore, 3.4 if f else 2.2, 0.45, 0.16)
	_dopo(0.1, anello.bind(la, c.c2, 4.6 if f else 3.0, 0.5, 0.09))
	fiamme(la + Vector3(0, 0.2, 0), c.colore, 16 if f else 9, 0.6, 2.0, 0.7)
	scuoti(0.5 if f else 0.25)


# ------------------------------------------------------------------ Loto
func _loto(c: Dictionary) -> void:
	var su: Entita = c.su
	var la: Vector3 = c.la
	match String(c.fx):
		"bolt":
			petali(c.mano, c.colore, 6, 0.4, 0.9, 0.3, Vector2(0.16, 0.26), false, c.c2)
			if su != null:
				proiettile(c.mano, su, c.colore.lerp(c.c2, 0.3), 26.0, 0.26 * float(c.k), _fioritura.bind(la, c, 3.0 if c.forte else 2.2), true, 28)
		"heal":
			_fioritura(la, c, 2.3)
			colonna(la, c.c3, 0.9, 3.4, 1.2)
		_:
			_generico(c)


## Un loto che sboccia a terra, onde d'acqua verde giada e petali in vortice.
func _fioritura(p: Vector3, c: Dictionary, r: float) -> void:
	forma(p, F_LOTO, c.colore, c.c2, r, 1.5)
	anello(p, c.c3, r * 0.8, 0.8, 0.07)
	_dopo(0.2, anello.bind(p, c.c3, r * 1.15, 0.8, 0.06))
	_dopo(0.4, anello.bind(p, c.c3.lightened(0.2), r * 1.5, 0.8, 0.05))
	petali(p + Vector3(0, 0.4, 0), c.colore, 18, r * 0.5, 1.4, 0.8, Vector2(0.18, 0.28), false, c.c2)
	spirale(p, c.colore, r * 0.55, 2.6, 1.0, 2.0, "petalo", 0.2, false)


# ------------------------------------------------------------------ Mistico
func _astrale(c: Dictionary) -> void:
	var su: Entita = c.su
	var col: Color = c.colore
	var c2: Color = c.c2
	var qui: Vector3 = c.qui
	var la: Vector3 = c.la
	var forte: bool = c.forte
	match String(c.fx):
		"bolt":
			stelle(c.mano, c2, 6, 2.5, 0.6)
			if c.area:
				proiettile(c.mano, la + Vector3(0, 0.6, 0), c.c3, 24.0, 0.3, _astro_area.bind(la, c, float(c.raggio)), true, 30)
			elif su != null:
				proiettile(c.mano, su, c2, 30.0, 0.22 * float(c.k), _astro_impatto.bind(la, c, 1.6), true, 30)
		"lightning":
			if String(c.sk.get("via", "")) == "tempesta":
				# Giudizio del Cielo: la tempesta stellata, vento e luce senza saette
				forma(la, F_VENTO, c.c3, c2, 3.4, 1.1)
				colonna(la, col, 1.5, 14.0, 0.8)
				for i in range(3):
					var a := TAU * i / 3.0 + randf()
					_dopo(0.06 * i, raggio_luce.bind(la + Vector3(cos(a) * 6.0, 18.0, sin(a) * 6.0), la + Vector3(cos(a) * 1.4, 0, sin(a) * 1.4), c2, 1.1, 0.4))
				spirale(la, c2, 1.6, 4.0, 0.9, 3.0, "stella", 0.26)
				anello(la, c.c3, 5.0, 0.55, 0.1)
				stelle(la + Vector3(0, 1.0, 0), c2, 16, 4.0, 0.9)
			else:
				# Lancia di Luce: un'asta di luce obliqua e la costellazione che si accende dove cade
				raggio_luce(la + Vector3(5.0, 18.0, 3.0), la, c2, 1.5, 0.4)
				_dopo(0.05, raggio_luce.bind(la + Vector3(5.0, 18.0, 3.0), la, col, 0.7, 0.35))
				forma(la, F_COSTELLAZIONE, col, c2, 2.4, 1.1)
				stelle(la + Vector3(0, 0.8, 0), c2, 14, 4.0, 0.8)
				anello(la, col, 3.6, 0.45, 0.1)
			scuoti(0.55)
		"mark":
			if su != null:
				forma(la, F_COSTELLAZIONE, col, c2, 2.4, 1.3)
				forma(su.testa() + Vector3(0, 0.6, 0), F_STELLA, c2, col, 0.7, 1.0, 0.0)
				stelle(su.testa(), c2, 8, 2.0, 0.7)
				bagliore(su.testa(), c2, 1.8, 0.3)
		_:
			_generico(c)


func _astro_impatto(p: Vector3, c: Dictionary, r: float) -> void:
	stelle(p + Vector3(0, 1.0, 0), c.c2, 12, 3.5, 0.7)
	bagliore(p + Vector3(0, 1.0, 0), c.c2, r * 1.4, 0.25)
	anello(p, c.colore, r, 0.4, 0.1)
	forma(p, F_STELLA, c.colore, c.c2, r * 0.9, 0.6)


func _astro_area(p: Vector3, c: Dictionary, R: float) -> void:
	forma(p, F_COSTELLAZIONE, c.colore, c.c2, R, 1.4)
	rune(p, c.colore, R * 0.9, 1.0)
	anello(p, c.c3, R, 0.55, 0.1, 0.5)
	stelle(p + Vector3(0, 0.8, 0), c.c2, 18, 5.0, 0.9)


# ------------------------------------------------------------------ Benedizione (giada)
func _giada(c: Dictionary) -> void:
	var la: Vector3 = c.la
	var col: Color = c.colore
	var c2: Color = c.c2
	match String(c.fx):
		"heal":
			var R := 1.2 if not c.area else float(c.raggio) * 0.6
			colonna(la, col, R, 6.5, 1.1)
			colonna(la, c2, R * 0.4, 8.5, 0.9)
			forma(la, F_SIGILLO, col, c2, 2.3 if not c.area else float(c.raggio), 1.2)
			petali(la + Vector3(0, 0.3, 0), c2, 16, 1.0, 1.6, 1.0, Vector2(0.1, 0.3), true, col)
			spirale(la, c2, 0.9, 3.0, 1.0, 2.0, "petalo", 0.16, true)
			anello(la, col, 3.0, 0.7, 0.08)
		"shield":
			cupola(la, 1.9, col, c2, 1.6)
			forma(la, F_SIGILLO, c2, col, 2.1, 1.3)
			colonna(la, c2, 0.6, 5.0, 0.8)
			bagliore(la + Vector3(0, 1.3, 0), col, 3.0, 0.4)
		_:
			_generico(c)


# ------------------------------------------------------------------ aure e potenziamenti
func _aura(c: Dictionary) -> void:
	var qui: Vector3 = c.qui
	var col: Color = c.colore
	var c2: Color = c.c2
	var c3: Color = c.c3
	match String(c.tema):
		"vento":
			forma(qui, F_VENTO, c3, c2, 2.8, 1.3)
			forma(qui + Vector3(0, 3.3, 0), F_MIRINO, col, c2, 1.2, 1.4, 0.0)
			petali(qui + Vector3(0, 0.4, 0), c2, 10, 1.0, 1.4, -0.3, Vector2(0.07, 0.34))
			spirale(qui, c2, 1.2, 3.0, 1.0, 2.0, "petalo", 0.14, false)
		"fiamma":
			fiamme(qui, col, 22, 1.1, 2.4, 0.9)
			anello(qui, col, 2.6, 0.6, 0.12)
			_dopo(0.15, anello.bind(qui, c2, 3.6, 0.7, 0.08))
			colonna(qui, col, 1.0, 4.5, 1.0)
			bagliore(qui + Vector3(0, 1.3, 0), c2, 3.0, 0.35)
		"astrale":
			if c.fx == "wind":
				# vortice stellato
				forma(qui, F_VENTO, c3, c2, 3.8, 1.3)
			else:
				forma(qui + Vector3(0, 3.0, 0), F_COSTELLAZIONE, col, c2, 1.8, 1.6, 0.0)
			spirale(qui, c2, 1.3, 3.4, 1.0, 3.0, "stella", 0.26)
			rune(qui, col, 2.4, 1.2)
		"giada":
			forma(qui, F_SIGILLO, col, c2, 2.3, 1.3)
			colonna(qui, col, 1.2, 5.5, 1.1)
			petali(qui + Vector3(0, 0.3, 0), c2, 12, 0.9, 1.5, 1.0, Vector2(0.1, 0.3), true, col)
		"ombra":
			nube(qui, 2.0, 1.4, c2, col)
			fumo(qui + Vector3(0, 0.9, 0), c2, 10, 0.8, 1.2, 1.3, 0.6)
		"loto":
			_fioritura(qui, c, 2.3)
		_:
			rune(qui, col, 2.4, 1.2)
			colonna(qui, col, 1.3, 5.5, 1.0)
			spirale(qui, col, 1.1, 2.8, 0.9)
			bagliore(qui + Vector3(0, 1.3, 0), col, 3.0, 0.35)


# ------------------------------------------------------------------ scatti
## Punto di partenza e di arrivo dello scatto. Il server manda la partenza (fx, fz); l'arrivo è tx, tz se c'è, altrimenti si
## ricava dal bersaglio (davanti a lui, o alle spalle con `dietro`) perché chi scatta può non essere ancora stato spostato.
func _punti_scatto(c: Dictionary, dietro: bool) -> Array:
	var m: Dictionary = c.m
	var qui: Vector3 = c.qui
	var partenza := Dati.suolo(float(m.get("fx", qui.x)), float(m.get("fz", qui.z)))
	var arrivo := qui
	if m.has("tx") and m.has("tz"):
		arrivo = Dati.suolo(float(m.tx), float(m.tz))
	elif c.su != null:
		var su: Entita = c.su
		var d := su.global_position - partenza
		d.y = 0.0
		if d.length() > 0.1:
			var p := su.global_position + d.normalized() * (su.raggio + 1.1) * (1.0 if dietro else -1.0)
			arrivo = Dati.suolo(p.x, p.z)
	return [partenza, arrivo]


## Carica della Lama: una striscia a terra dalla partenza all'arrivo, polvere (o saette, o lastre secondo la Via) lungo il
## percorso e un impatto frontale.
func _carica(c: Dictionary) -> void:
	var su: Entita = c.su
	var pp := _punti_scatto(c, false)
	var partenza: Vector3 = pp[0]
	var arrivo: Vector3 = pp[1]
	var col: Color = c.colore
	scia(partenza, arrivo, col, 1.8, 0.5)
	scia(partenza, arrivo, col.lightened(0.5), 0.55, 0.35)
	for i in range(4):
		var p := partenza.lerp(arrivo, (i + 0.5) / 4.0)
		_dopo(0.05 * i, polvere.bind(Dati.suolo(p.x, p.z), 1.3, 8))
	match String(c.tema):
		"fulmine":
			for i in range(3):
				var p := partenza.lerp(arrivo, (i + 0.6) / 3.4) + Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))
				_dopo(0.06 * i, fulmine.bind(Dati.suolo(p.x, p.z), col, 9.0, 2.4, 0.3, false))
		"roccia":
			lastre_linea(partenza, arrivo, 6, 0.7)
		_:
			for i in range(3):
				var p := partenza.lerp(arrivo, (i + 0.5) / 3.0)
				_dopo(0.05 * i, scintille.bind(Dati.suolo(p.x, p.z) + Vector3(0, 0.3, 0), c.c2 if c.tema != "neutro" else col, 10, 5.0, 0.4, -14.0, 0.12))
	var yaw := atan2(arrivo.x - partenza.x, arrivo.z - partenza.z)
	taglio(arrivo + Vector3(0, 1.2, 0), yaw, col, 3.2, 2.6, 0.28)
	anello(arrivo, col, 2.8, 0.4, 0.14)
	if su != null:
		scintille(su.petto(), c.c2 if c.tema != "neutro" else col, 22, 7.0, 0.45, -14.0, 0.14)
		bagliore(su.petto(), col.lightened(0.4), 3.0, 0.2)
	scuoti(0.5)


## Teletrasporto dell'Ombra: sparisce in uno sbuffo di fumo dove si trovava e riappare alle spalle del bersaglio con un altro
## sbuffo; niente scia lungo il percorso.
func _teletrasporto(c: Dictionary) -> void:
	var su: Entita = c.su
	var pp := _punti_scatto(c, true)
	var partenza: Vector3 = pp[0]
	var arrivo: Vector3 = pp[1]
	sbuffo_ombra(partenza, c, 1.0)
	var col: Color = c.colore
	var c2: Color = c.c2
	_dopo(0.12, func() -> void:
		sbuffo_ombra(arrivo, c, 1.2)
		var p := (su.petto() if is_instance_valid(su) else arrivo + Vector3(0, 1.2, 0))
		var yaw := atan2(arrivo.x - partenza.x, arrivo.z - partenza.z)
		taglio_ombra(p, yaw, col, c2, 2.8, 2.2, 0.26, -0.7)
		taglio_ombra(p, yaw + 0.5, col, c2, 2.6, 2.0, 0.24, 0.8)
		gocce(p, col, 8)
		scuoti(0.3))


## Ala di Vento (Arco): una folata porta l'arciere al punto d'arrivo, con scie d'aria e penne; verso il bersaglio parte una
## raffica di penne.
func _folata(c: Dictionary) -> void:
	var pp := _punti_scatto(c, false)
	var partenza: Vector3 = pp[0]
	var arrivo: Vector3 = pp[1]
	var col: Color = c.colore
	var su: Entita = c.su
	var alto := Vector3(0, 1.1, 0)
	for i in range(3):
		var lato := Vector3(randf_range(-0.5, 0.5), 0.35 * i, randf_range(-0.5, 0.5))
		scia_aria(partenza + alto + lato, arrivo + alto + lato, col, 0.5, 0.45)
	spirale(partenza, col, 0.9, 2.2, 0.6)
	petali(partenza + alto, c.c2, 10, 0.8, 1.0, 0.8)
	polvere(arrivo, 1.2, 8)
	_dopo(0.1, petali.bind(arrivo + alto, c.c2, 8, 0.7, 1.0, 0.5))
	if su != null:
		for i in range(5):
			var da := arrivo + Vector3(randf_range(-0.6, 0.6), 1.2 + randf_range(-0.2, 0.5), randf_range(-0.6, 0.6))
			_dopo(0.08 + 0.04 * i, proiettile.bind(da, su, col, 34.0, 0.1, Callable(), false, 10))
		_dopo(0.3, func() -> void:
			if is_instance_valid(su):
				scintille(su.petto(), c.c2, 10, 4.0, 0.35, -8.0, 0.1))


## Calcio Volante (Monaco): balzo ad arco con scia di chi (fiamme, o petali con il Loto) e scoppio all'arrivo.
func _balzo(c: Dictionary) -> void:
	var pp := _punti_scatto(c, false)
	var partenza: Vector3 = pp[0]
	var arrivo: Vector3 = pp[1]
	var col: Color = c.colore
	var su: Entita = c.su
	var loto := String(c.tema) == "loto"
	anello(partenza, col, 1.6, 0.35, 0.12)
	polvere(partenza, 1.0, 8)
	var prima := partenza + Vector3(0, 0.9, 0)
	for i in range(1, 7):
		var t := i / 6.0
		var p := partenza.lerp(arrivo, t) + Vector3(0, 0.9 + sin(t * PI) * 2.2, 0)
		_dopo(0.03 * i, scia.bind(prima, p, col, 0.9, 0.4))
		if loto:
			_dopo(0.03 * i, petali.bind(p, c.c2, 4, 0.4, 0.9, -0.3))
		else:
			_dopo(0.03 * i, fiamme.bind(p - Vector3(0, 0.4, 0), col, 5, 0.25, 0.9, 0.45))
		prima = p
	_dopo(0.2, func() -> void:
		var q := (su.petto() if is_instance_valid(su) else arrivo + Vector3(0, 1.2, 0))
		var yaw := atan2(arrivo.x - partenza.x, arrivo.z - partenza.z)
		taglio(q, yaw, col, 2.4, 2.2, 0.26, -0.9)
		bagliore(q, col.lightened(0.3), 2.6, 0.22)
		scintille(q, c.c2, 18, 6.5, 0.45, -12.0, 0.14)
		anello(arrivo, col, 2.6, 0.4, 0.14)
		scuoti(0.45))


## Passo di Luce (Mistico): ci si scioglie in una colonna di stelle e si riappare più avanti in un cerchio di rune.
func _passo_luce(c: Dictionary) -> void:
	var pp := _punti_scatto(c, false)
	var partenza: Vector3 = pp[0]
	var arrivo: Vector3 = pp[1]
	var col: Color = c.colore
	colonna(partenza, col, 0.7, 5.0, 0.6)
	stelle(partenza + Vector3(0, 1.0, 0), c.c2, 14, 2.5, 0.9, 1.5)
	anello(partenza, col, 1.4, 0.4, 0.1)
	for i in range(1, 6):
		var p := partenza.lerp(arrivo, i / 6.0) + Vector3(0, 1.1, 0)
		_dopo(0.025 * i, stelle.bind(p, col, 3, 0.8, 0.6, 0.3, 0.2))
	_dopo(0.14, func() -> void:
		rune(arrivo, col, 1.6, 0.9)
		colonna(arrivo, col.lightened(0.3), 0.5, 4.0, 0.45)
		stelle(arrivo + Vector3(0, 1.0, 0), c.c2, 12, 3.0, 0.8, 0.8)
		bagliore(arrivo + Vector3(0, 1.2, 0), col, 2.4, 0.25))


# ------------------------------------------------------------------ buff di classe
## Attivazione breve e d'effetto in tema (fx buff_lama, buff_ombra, buff_monaco, buff_mistico). Con `ally` (il server
## manda l'effetto anche agli alleati colpiti) la versione è ridotta.
func _buff_classe(c: Dictionary) -> void:
	var da: Entita = c.da
	var qui: Vector3 = c.qui
	var ally := int(c.m.get("ally", 0)) == 1
	var s := 0.55 if ally else 1.0
	match String(c.fx):
		"buff_lama":
			# Grido di Guerra: onda d'urto rosso-oro dal personaggio e lame di luce come uno stendardo
			var rosso := Color(1.0, 0.2, 0.12)
			var oro := Color(1.0, 0.78, 0.25)
			anello(qui, rosso, 9.0 * s, 0.7, 0.16)
			_dopo(0.12, anello.bind(qui, oro, 7.0 * s, 0.6, 0.1))
			anello(qui, oro, 4.0 * s, 0.5, 0.3, 1.0)
			taglio(qui + Vector3(0, 1.2, 0), da.r, oro, 3.4 * s, TAU, 0.35)
			for i in range(6):
				var a := TAU * i / 6.0
				colonna(Dati.suolo(qui.x + cos(a) * 2.0 * s, qui.z + sin(a) * 2.0 * s), rosso if i % 2 == 0 else oro, 0.28, (6.5 + (i % 2) * 1.5) * s, 0.9)
			polvere(qui, 4.0 * s, 16)
			bagliore(qui + Vector3(0, 1.4, 0), oro, 4.0 * s, 0.3)
			scuoti(0.5 * s)
		"buff_ombra":
			# Velo d'Ombra: il fumo scuro si stringe attorno al personaggio e lo avvolge
			var scuro: Color = PALETTE.ombra[1]
			var acido: Color = PALETTE.ombra[0]
			_avvolgi_fumo(qui + Vector3(0, 0.9, 0), scuro)
			nube(qui, 2.2 * s, 1.2, scuro, acido)
			_dopo(0.7, func() -> void:
				fumo(qui + Vector3(0, 1.0, 0), scuro, 12, 0.5, 0.9, 1.3, 0.3)
				anello(qui, acido, 2.4, 0.4, 0.06)
				scintille(qui + Vector3(0, 1.0, 0), acido, 10, 3.0, 0.5, 0.0, 0.14))
		"buff_monaco":
			# Respiro del Drago: una colonna di chi dorata sale dal personaggio, anelli a terra
			var f: Color = PALETTE.fiamma[0]
			var o: Color = PALETTE.fiamma[1]
			colonna(qui, f, 1.2 * s, 10.0 * s, 1.1)
			colonna(qui, o, 0.5 * s, 12.0 * s, 0.9)
			anello(qui, f, 3.0 * s, 0.7, 0.14)
			_dopo(0.15, anello.bind(qui, o, 4.4 * s, 0.7, 0.1))
			_dopo(0.3, anello.bind(qui, f, 5.8 * s, 0.7, 0.07))
			fiamme(qui, f, 24, 1.0 * s, 3.5, 1.0)
			spirale(qui, o, 1.1, 4.5, 1.0, 3.0)
			forma(qui, F_SIGILLO, o, f, 2.6 * s, 1.2)
			bagliore(qui + Vector3(0, 1.3, 0), o, 3.6 * s, 0.35)
		"buff_mistico":
			# Benedizione degli Astri: sopra la testa si disegna una costellazione, poi piove una pioggia di stelle
			var v: Color = PALETTE.astrale[0]
			var d: Color = PALETTE.astrale[1]
			if not ally:
				forma(qui + Vector3(0, 3.8, 0), F_COSTELLAZIONE, v, d, 3.2, 1.7, 0.0)
				forma(qui, F_STELLA, v, d, 2.6, 1.3)
			pioggia_stelle(qui, 3.0 if ally else 5.0, 1.2, 18 if ally else 36, d)
			_dopo(0.5, func() -> void:
				stelle(qui + Vector3(0, 1.4, 0), d, 10, 3.0, 0.8)
				anello(qui, v, 3.2 * s, 0.6, 0.08))
		_:
			_aura(c)


## Fumo che arriva da un anello attorno al punto e si richiude su di esso.
func _avvolgi_fumo(pos: Vector3, colore: Color) -> void:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.3, 1.3)
	p.mesh = q
	p.material_override = Equip.mat_fumo()
	p.amount = 20
	p.lifetime = 0.8
	p.one_shot = true
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 2.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.2
	p.radial_accel_min = -9.0
	p.radial_accel_max = -6.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.5
	var sf := Gradient.new()
	sf.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	sf.colors = PackedColorArray([Color(colore.r, colore.g, colore.b, 0.0), Color(colore.r, colore.g, colore.b, 0.8), Color(colore.r, colore.g, colore.b, 0.0)])
	p.color_ramp = sf
	p.position = pos
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.emitting = true
	_dopo(1.4, p.queue_free)


# ------------------------------------------------------------------ cavalcature e tecniche senza classe (aspetto neutro)
func _generico(c: Dictionary) -> void:
	var sk: Dictionary = c.sk
	var da: Entita = c.da
	var su: Entita = c.su
	var colore: Color = c.colore
	var forte: bool = c.forte
	var raggio: float = c.raggio
	var qui: Vector3 = c.qui
	var la: Vector3 = c.la
	var tipo: String = c.tipo
	var area: bool = c.area
	var mano: Vector3 = c.mano
	var k: float = c.k
	var g: int = c.g
	var m: Dictionary = c.m
	match String(c.fx):
		"spin":
			taglio(qui + Vector3(0, 1.1, 0), da.r, colore, raggio * 0.95, TAU, 0.38 if forte else 0.3)
			anello(qui, colore, raggio, 0.45)
			if String(sk.get("via", "")) == "fulmine":
				for i in range(5 if forte else 3):
					var a := randf() * TAU
					var d := raggio * (0.4 + 0.5 * randf())
					_dopo(0.05 * i, fulmine.bind(Dati.suolo(qui.x + cos(a) * d, qui.z + sin(a) * d), colore, 11.0, 3.2, 0.32, false))
			if forte:
				_dopo(0.12, taglio.bind(qui + Vector3(0, 1.5, 0), da.r + 1.0, colore.lightened(0.35), raggio * 1.15, TAU, 0.34, 0.25))
				anello(qui, colore, raggio * 1.2, 0.6, 0.1, 1.0)
				scintille(qui + Vector3(0, 1.0, 0), colore, 40, 10.0, 0.6, -6.0)
				scuoti(0.45)
		"slash":
			fendente(da, colore, (3.4 if forte else 2.6) * k, 2.9 if forte else 2.4, 0.3, randf_range(-0.5, 0.5))
			if su != null:
				scintille(su.petto(), colore, 26 if forte else 12, 6.5, 0.4)
				bagliore(su.petto(), colore.lightened(0.4), 3.2 if forte else 1.8, 0.2)
			if forte:
				_dopo(0.08, taglio.bind(qui + Vector3(0, 1.2, 0), da.r, colore.lightened(0.4), 3.9, 2.9, 0.36, randf_range(0.7, 1.1)))
				_dopo(0.16, taglio.bind(qui + Vector3(0, 1.2, 0), da.r, colore, 3.6, 2.6, 0.3, randf_range(-1.1, -0.7)))
				anello(la, colore, 3.2, 0.4)
				crepe(la, colore, 2.4, 1.4)
				scuoti(0.4)
		"lightning":
			if area:
				var quante := (9 if forte else 5) + g * 2
				rune(la, colore, raggio, 1.2)
				for i in range(quante):
					var a := randf() * TAU
					var d := raggio * sqrt(randf())
					_dopo(0.07 * i, fulmine.bind(Dati.suolo(la.x + cos(a) * d, la.z + sin(a) * d), colore, 16.0, 4.5, 0.4, i % 3 == 0))
				anello(la, colore, raggio, 0.7, 0.1, 1.0)
			else:
				fulmine(la, colore, (20.0 if forte else 15.0) * k, (7.0 if forte else 4.5) * k, 0.5 if forte else 0.38)
				if su != null:
					scintille(su.petto(), colore, 28 if forte else 12, 8.0, 0.5)
			if forte:
				# il colpo potente: fendente carico, tre saette di contorno, onda d'urto
				fendente(da, colore.lightened(0.3), 3.6, 2.9, 0.32, randf_range(-0.4, 0.4))
				for i in range(3):
					var a := TAU * i / 3.0 + randf()
					_dopo(0.08 + 0.06 * i, fulmine.bind(Dati.suolo(la.x + cos(a) * 2.2, la.z + sin(a) * 2.2), colore.lightened(0.2), 13.0, 3.5, 0.3, false))
				anello(la, colore, 5.0, 0.55)
				scuoti(0.6)
		"quake":
			var centro := la if tipo == "strike" else qui
			var r := raggio if area else 3.5
			anello(centro, colore, r, 0.6, 0.22)
			anello(centro, colore.darkened(0.3), r * 0.7, 0.45, 0.3, 1.0)
			crepe(centro, colore.lerp(Color(1.0, 0.55, 0.2), 0.5), r * 0.9, 2.6)
			polvere(centro, r, 30 if forte else 16)
			bagliore(centro + Vector3(0, 0.5, 0), colore.lightened(0.3), r * 1.2, 0.25)
			if tipo == "strike":
				fendente(da, colore, 3.0, 2.4, 0.3, 1.3)
			if forte:
				_dopo(0.15, anello.bind(centro, colore.lightened(0.3), r * 1.35, 0.6, 0.1))
			scuoti(0.7 if forte else 0.4)
		"bolt":
			bagliore(mano, colore, 1.6, 0.2)
			if area:
				proiettile(mano, la + Vector3(0, 0.6, 0), colore, 26.0, 0.3, _esplosione.bind(la, colore, raggio))
			elif su != null:
				proiettile(mano, su, colore, 30.0, (0.34 if forte else 0.22) * k, anello.bind(la, colore, (2.8 if forte else 1.5) * k, 0.35))
				if forte:
					for i in range(2):
						_dopo(0.08 * (i + 1), proiettile.bind(mano + Vector3(randf_range(-0.6, 0.6), 0.4, 0), su, colore.lightened(0.3), 26.0, 0.16, Callable(), false))
		"arrow":
			if su != null:
				proiettile(mano, su, colore, 46.0, 0.1, Callable(), false)
				if forte:
					scia(qui, la, colore, 0.8, 0.45)
					scia(qui, la, colore.lightened(0.6), 0.25, 0.3)
					anello(la, colore, 2.6, 0.35)
					crepe(la, colore, 1.8, 1.2)
		"rain":
			rune(la, colore, raggio, 1.3)
			anello(la, colore, raggio, 0.9, 0.08, 1.0)
			for i in range((16 if forte else 10) + g * 3):
				var a := randf() * TAU
				var d := raggio * sqrt(randf())
				_dopo(0.05 * i, _freccia_dal_cielo.bind(Dati.suolo(la.x + cos(a) * d, la.z + sin(a) * d), colore, forte))
		"heal":
			colonna(la, colore, 1.0 if not area else raggio * 0.6, 5.0, 1.0)
			rune(la, colore, raggio if area else 1.9, 1.1)
			spirale(la, colore, 0.9 if not area else raggio * 0.5, 2.6, 0.9)
			scintille(la + Vector3(0, 0.6, 0), colore, 18, 2.2, 1.0, 3.0)
		"shield":
			colonna(la, colore, 1.1, 3.2, 0.9)
			rune(la, colore, 1.9, 1.0)
			bagliore(la + Vector3(0, 1.3, 0), colore, 3.4, 0.4)
		"mark", "taunt":
			if su != null:
				rune(la, colore, 2.0, 0.9)
				colonna(la, colore, 0.6, 5.0, 0.6)
				bagliore(su.testa(), colore, 1.8, 0.3)
				scintille(su.testa(), colore, 10, 3.0, 0.5)
		_:
			# aure e potenziamenti; un fx sconosciuto finisce qui senza errori
			_aura(c)


# ------------------------------------------------------------------ Risonanza
## Finale con la Risonanza: lo stesso colpo si apre su tutta la zona attorno al bersaglio, nel tema della classe.
func _risonanza(c: Dictionary) -> void:
	var la: Vector3 = c.la
	var col: Color = c.colore
	var c2: Color = c.c2
	var R := float(Dati.gioco.COMBAT.risRaggio)
	anello(la, col, R, 0.55, 0.12, 0.6)
	_dopo(0.12, anello.bind(la, col.lightened(0.3), R * 1.1, 0.5, 0.07))
	scuoti(0.5)
	match String(c.tema):
		"fulmine":
			rune(la, col, R, 1.1)
			for i in range(7):
				var a := TAU * i / 7.0 + randf() * 0.5
				var d := R * (0.35 + 0.6 * randf())
				_dopo(0.05 * i, fulmine.bind(Dati.suolo(la.x + cos(a) * d, la.z + sin(a) * d), col, 15.0, 4.0, 0.36, i % 3 == 0))
		"acciaio":
			taglio(la + Vector3(0, 1.1, 0), randf() * TAU, col, R * 0.95, TAU, 0.36)
			_dopo(0.1, taglio.bind(la + Vector3(0, 1.5, 0), randf() * TAU, col.lightened(0.35), R * 0.8, TAU, 0.32, 0.3))
			scintille(la + Vector3(0, 1.0, 0), c2, 36, 9.0, 0.5, -14.0, 0.12)
		"roccia":
			crepe(la, col.lerp(c.c3, 0.25), R, 2.6)
			lastre(la, R * 0.8, 9, 2.0, 0.9)
			polvere(la, R, 30)
		"ombra":
			nube(la, R, 1.6, c2, col)
			fumo(la + Vector3(0, 0.6, 0), c2, 10, R * 0.4, 1.0, 1.4)
			for i in range(3):
				_dopo(0.05 * i, taglio_ombra.bind(la + Vector3(0, 1.1, 0), randf() * TAU, col, c2, R * 0.8, 2.4, 0.3, randf_range(-0.5, 0.5)))
		"vento":
			forma(la, F_VENTO, c.c3, c2, R, 1.1)
			petali(la + Vector3(0, 1.0, 0), c2, 18, R * 0.4, 1.3, -0.6, Vector2(0.07, 0.34))
		"fiamma":
			forma(la, F_PALMO, col, c2, R * 0.9, 1.0)
			fiamme(la, col, 28, R * 0.6, 2.4, 0.8)
		"loto":
			forma(la, F_LOTO, col, c2, R, 1.4)
			petali(la + Vector3(0, 0.4, 0), col, 22, R * 0.5, 1.5, 0.8, Vector2(0.18, 0.28), false, c2)
		"astrale":
			forma(la, F_COSTELLAZIONE, col, c2, R, 1.3)
			stelle(la + Vector3(0, 0.8, 0), c2, 18, 5.0, 0.9)
		"giada":
			forma(la, F_SIGILLO, col, c2, R, 1.2)
			colonna(la, col, R * 0.5, 6.0, 1.0)
			spirale(la, c2, R * 0.45, 3.0, 0.9)
		_:
			rune(la, col, R, 1.1)
			_esplosione(la, col, R)


# ------------------------------------------------------------------ gradi di padronanza
## Strati in più per grado, sopra l'effetto di base, nel tema della tecnica.
func _arricchisci(c: Dictionary) -> void:
	var g: int = c.g
	if g <= 0:
		return
	var da: Entita = c.da
	var su: Entita = c.su
	var col: Color = c.colore
	var qui: Vector3 = c.qui
	var la: Vector3 = c.la
	var raggio: float = c.raggio
	var area: bool = c.area
	var fx: String = c.fx
	var tema: String = c.tema
	var sul_bersaglio := la if (su != null or area) else qui
	var mischia := fx in ["slash", "spin", "dash", "quake"]
	# Affinata (5): il segno del tema sotto chi la usa
	_firma(c, qui, 1.5 + 0.35 * g, 0.7)
	if g >= 2:
		# Esperta (10): l'effetto ha un'eco
		match tema:
			"roccia":
				_dopo(0.12, lastre.bind(sul_bersaglio, 2.4, 3 + g, 1.4, 0.8))
			"ombra":
				_dopo(0.1, taglio_ombra.bind(sul_bersaglio + Vector3(0, 1.2, 0), randf() * TAU, col, c.c2, 2.8 + 0.3 * g, 2.2, 0.28, randf_range(-1.0, 1.0)))
				if su != null:
					sagoma(qui, da.r, c.c2, (la - qui) * 0.9, 0.5)
			"vento":
				if su != null:
					for i in range(g - 1):
						_dopo(0.07 * (i + 1), proiettile.bind(qui + Vector3(randf_range(-0.7, 0.7), 1.9, 0), su, col, 38.0, 0.08, Callable(), false, 12))
				petali(sul_bersaglio + Vector3(0, 1.2, 0), c.c2, 6 + g * 2, 0.6, 1.2, -0.6, Vector2(0.07, 0.34))
			"fiamma":
				_dopo(0.1, fiamme.bind(sul_bersaglio, col, 8 + g * 2, 0.6, 2.0, 0.7))
				_dopo(0.1, anello.bind(sul_bersaglio, c.c2, 2.6 + 0.3 * g, 0.4, 0.1))
			"loto":
				spirale(sul_bersaglio, col, 0.9, 2.6, 0.9, 2.0, "petalo", 0.2, false)
			"astrale":
				stelle(sul_bersaglio + Vector3(0, 1.0, 0), c.c2, 6 + g * 2, 3.5, 0.8)
				spirale(sul_bersaglio, c.c2, 0.9, 2.6, 0.8, 2.0, "stella", 0.24)
			"giada":
				spirale(sul_bersaglio, c.c2, 0.9, 2.8, 0.9, 2.0, "petalo", 0.16, true)
			"fulmine":
				for i in range(g):
					var a := TAU * i / g + randf()
					_dopo(0.1 + 0.05 * i, fulmine.bind(Dati.suolo(sul_bersaglio.x + cos(a) * 2.8, sul_bersaglio.z + sin(a) * 2.8), col.lightened(0.2), 12.0, 3.0, 0.3, false))
			_:
				if mischia:
					_dopo(0.1, taglio.bind(qui + Vector3(0, 1.25, 0), da.r + randf_range(-0.4, 0.4), col.lightened(0.35), (raggio * 0.9 if fx == "spin" else 3.0) + 0.3 * g, TAU if fx == "spin" else 2.6, 0.3, randf_range(-0.9, 0.9)))
				elif fx in ["bolt", "arrow"] and su != null:
					for i in range(g - 1):
						_dopo(0.07 * (i + 1), proiettile.bind(qui + Vector3(randf_range(-0.7, 0.7), 1.9, 0), su, col.lightened(0.3), 34.0, 0.13, Callable(), false, 14))
				else:
					spirale(sul_bersaglio, col, 0.9, 2.6, 0.8)
	if g >= 3:
		# Maestra (15): l'impatto lascia il segno, nel tema
		var r := (raggio if area else 2.4)
		match tema:
			"roccia":
				_dopo(0.12, crepe.bind(sul_bersaglio, col, r * 0.9, 2.0))
				schegge(sul_bersaglio + Vector3(0, 0.4, 0), 10, 6.0)
			"ombra":
				_dopo(0.12, nube.bind(sul_bersaglio, r * 0.9, 1.4, c.c2, col))
			"vento":
				_dopo(0.12, forma.bind(sul_bersaglio, F_MIRINO, col, c.c2, r * 0.8, 1.0, 0.1))
			"fiamma":
				_dopo(0.12, forma.bind(sul_bersaglio, F_PALMO, col, c.c2, r * 0.9, 0.9, 0.1))
			"loto":
				_dopo(0.12, forma.bind(sul_bersaglio, F_LOTO, col, c.c2, r * 0.9, 1.2, 0.1))
			"astrale":
				_dopo(0.12, forma.bind(sul_bersaglio, F_COSTELLAZIONE, col, c.c2, r * 0.9, 1.2, 0.1))
			"giada":
				_dopo(0.12, forma.bind(sul_bersaglio, F_SIGILLO, col, c.c2, r * 0.9, 1.2, 0.1))
			_:
				_dopo(0.12, crepe.bind(sul_bersaglio, col, r * 0.8, 2.0))
				_dopo(0.12, anello.bind(sul_bersaglio, col.lightened(0.3), r * 1.15, 0.5, 0.08))
				scintille(sul_bersaglio + Vector3(0, 0.8, 0), col, 24, 7.0, 0.5, -6.0)
		bagliore(sul_bersaglio + Vector3(0, 1.0, 0), col, 3.0, 0.25)
		scuoti(0.3)
	if g >= 4:
		# Perfetta (20): sigillo d'oro (la forma del tema), spirale e colonna
		var r := (raggio if area else 2.6) * 1.1
		if FORMA_TEMA.has(tema):
			forma(sul_bersaglio, FORMA_TEMA[tema], ORO_PERFETTO, Color(1.0, 0.95, 0.75), r, 1.4)
		else:
			rune(sul_bersaglio, ORO_PERFETTO, r, 1.4)
		spirale(qui, ORO_PERFETTO, 1.0, 3.2, 0.9, 3.0)
		_dopo(0.18, colonna.bind(sul_bersaglio, ORO_PERFETTO, 0.9, 9.0, 0.7))
		scintille(qui + Vector3(0, 1.2, 0), ORO_PERFETTO, 30, 4.0, 0.9, 2.0)


func _esplosione(pos: Vector3, colore: Color, raggio: float) -> void:
	anello(pos, colore, raggio, 0.5, 0.16, 1.0)
	bagliore(pos + Vector3(0, 0.8, 0), colore.lightened(0.4), raggio * 1.3, 0.3)
	scintille(pos + Vector3(0, 0.6, 0), colore, 30, 8.0, 0.6, -5.0)
	lampo(pos + Vector3(0, 1.5, 0), colore, 5.0, raggio * 2.0, 0.3)


func _freccia_dal_cielo(p: Vector3, colore: Color, esplode: bool) -> void:
	proiettile(p + Vector3(randf_range(-1, 1), 14.0, randf_range(-1, 1)), p + Vector3(0, 0.2, 0), colore, 60.0, 0.08, anello.bind(p, colore, 2.2 if esplode else 0.9, 0.3), false, 14)


# ------------------------------------------------------------------ Tecniche Supreme
## Ogni classe ha la sua regia, distesa sulle ondate della tecnica (waves × waveGap), nel tema della classe.
func _suprema(c: Dictionary) -> void:
	var sk: Dictionary = c.sk
	var da: Entita = c.da
	var su: Entita = c.su
	var col: Color = c.colore
	var c2: Color = c.c2
	var c3: Color = c.c3
	var qui: Vector3 = c.qui
	var la: Vector3 = c.la
	var ondate := int(sk.get("waves", 1))
	var passo := float(sk.get("waveGap", 0.35))
	var r := maxf(float(c.raggio), 6.0)
	scuoti(0.9)
	match String(sk.get("cls", "")):
		"lama":
			# Giudizio dei Cento Tuoni: la Lama carica sul bersaglio (acciaio), il cielo si spezza in saette a ogni ondata e la
			# terra si solleva in lastre; in chiusura cade il fulmine maestro
			var azzurro: Color = PALETTE.fulmine[0]
			var pp := _punti_scatto(c, false)
			var partenza: Vector3 = pp[0]
			var arrivo: Vector3 = pp[1]
			scia(partenza, arrivo, col, 2.2, 0.55)
			scia(partenza, arrivo, azzurro, 0.8, 0.4)
			anello(partenza, col, 6.0, 0.6, 0.12)
			for i in range(6):
				var a := TAU * i / 6.0
				colonna(Dati.suolo(partenza.x + cos(a) * 2.0, partenza.z + sin(a) * 2.0), col if i % 2 == 0 else c2, 0.25, 7.0, 0.8)
			var p0 := su.global_position if is_instance_valid(su) else la
			lampo(arrivo + Vector3(0, 2, 0), azzurro, 10.0, 24.0, 0.8)
			for i in range(ondate):
				_dopo(0.12 + passo * i, func() -> void:
					var p := su.global_position if is_instance_valid(su) else la
					taglio(p + Vector3(0, 1.3, 0), da.r, col, 4.6, 3.0, 0.32, 0.9 if i % 2 == 0 else -0.9)
					fulmine(p, azzurro, 24.0, 8.0, 0.45, i == 0)
					lastre(p, 3.5 + i, 4 + i, 1.8, 0.5)
					anello(p, col, 5.0 + i, 0.5)
					polvere(p, 3.0, 10)
					scuoti(0.6))
			_dopo(0.12 + passo * ondate + 0.05, func() -> void:
				var p := su.global_position if is_instance_valid(su) else p0
				for k in range(5):
					var a := TAU * k / 5.0
					fulmine(Dati.suolo(p.x + cos(a) * 2.6, p.z + sin(a) * 2.6), azzurro.lightened(0.3), 20.0, 5.0, 0.5, false)
				fulmine(p, Color(0.85, 0.95, 1.0), 30.0, 10.0, 0.6)
				lastre(p, 6.0, 10, 2.6, 1.1)
				taglio(p + Vector3(0, 1.4, 0), 0.0, col, 5.5, 3.0, 0.4, 0.8)
				taglio(p + Vector3(0, 1.4, 0), 0.0, col, 5.5, 3.0, 0.4, -0.8)
				crepe(p, col.lerp(c.c3, 0.4), 6.0, 3.0)
				schegge(p + Vector3(0, 0.4, 0), 20, 9.0)
				scuoti(1.0))
		"ombra":
			# Danza delle Mille Ombre: sparisce in fumo, copie d'ombra circondano il bersaglio e lo colpiscono da ogni lato in
			# una raffica di tagli scuri col bordo acido, poi la croce finale
			var pp := _punti_scatto(c, true)
			var partenza: Vector3 = pp[0]
			var arrivo: Vector3 = pp[1]
			sbuffo_ombra(partenza, c, 1.6)
			_dopo(0.15, sbuffo_ombra.bind(arrivo, c, 1.8))
			var tot := passo * ondate
			var copie := 7
			for i in range(copie):
				var a := TAU * i / copie + 0.3
				var pos := Dati.suolo(la.x + cos(a) * 2.6, la.z + sin(a) * 2.6)
				_dopo(0.2 + tot * float(i) / copie, sagoma.bind(pos, -a - PI * 0.5, c2, Vector3(la.x - pos.x, 0, la.z - pos.z) * 0.85, 0.5))
			var quanti := maxi(10, ondate * 4)
			for i in range(quanti):
				_dopo(0.25 + tot * float(i) / quanti, func() -> void:
					var p := (su.petto() if is_instance_valid(su) else la + Vector3(0, 1.2, 0))
					taglio_ombra(p, randf() * TAU, col, c2, randf_range(2.6, 3.6), 2.2, 0.22, randf_range(-1.4, 1.4))
					if i % 3 == 0:
						fumo(p, c2, 4, 0.5, 0.7, 0.9)
						gocce(p, col, 6)
					scuoti(0.25))
			nube(la, 5.5, 2.2, c2, col)
			anello(la, col, r, 1.0, 0.07)
			_dopo(0.3 + tot, func() -> void:
				var p := (su.petto() if is_instance_valid(su) else la + Vector3(0, 1.2, 0))
				taglio(p, 0.0, Color(1, 1, 1), 5.0, 3.0, 0.4, 0.8)
				taglio(p, 0.0, Color(1, 1, 1), 5.0, 3.0, 0.4, -0.8)
				taglio_ombra(p, 0.0, col, c2, 5.5, 3.0, 0.45, 0.8)
				taglio_ombra(p, 0.0, col, c2, 5.5, 3.0, 0.45, -0.8)
				forma(la, F_MIRINO, col, c3, 4.0, 1.0)
				anello(la, col, 6.5, 0.6, 0.1)
				gocce(p, col, 24)
				scuoti(0.9))
		"monaco":
			# Ascesa del Drago Celeste: il chi sale in spirali di fuoco, onde calde a ogni ondata, la terra si spacca e dal
			# suolo si alza la colonna del drago
			forma(qui, F_PALMO, col, c2, r * 0.55, 0.8 + ondate * passo)
			spirale(qui, col, 2.2, 9.0, 0.5 + ondate * passo, 4.0)
			spirale(qui + Vector3(0, 0.5, 0), c2, 1.2, 8.0, 0.4 + ondate * passo, 5.0)
			fiamme(qui, col, 36, r * 0.4, 4.5, 1.0)
			crepe(qui, Color(col.r, col.g * 0.7, col.b * 0.4, 0.7), r * 0.85, 3.5)
			bagliore(qui + Vector3(0, 1.4, 0), c2, 5.0, 0.4)
			lampo(qui + Vector3(0, 2, 0), col, 10.0, 24.0, 0.8)
			for i in range(maxi(ondate, 3)):
				_dopo(passo * i, func() -> void:
					anello(qui, col, r * (0.7 + 0.25 * i), 0.7, 0.14, 0.25)
					fiamme(qui, col, 20, r * 0.5, 3.0, 0.8)
					polvere(qui, r * 0.8, 16)
					taglio(qui + Vector3(0, 1.0 + 0.5 * i, 0), randf() * TAU, col, r * 0.7, TAU, 0.4, 0.2, 0.2)
					scuoti(0.7))
			_dopo(passo * maxi(ondate, 3), func() -> void:
				colonna(qui, col, 2.6, 20.0, 1.1)
				colonna(qui, c2, 1.2, 24.0, 0.9)
				anello(qui, c2, r * 1.3, 0.8, 0.1)
				fiamme(qui, col, 40, r * 0.3, 6.0, 1.2)
				scuoti(1.0))
		_:
			# Collera del Cielo: il cielo stellato si dipinge sull'area (una costellazione a terra e una in alto), poi cadono
			# comete e lance di luce per tutta la durata e il cerchio si chiude con una colonna di luce
			var tot := passo * ondate
			forma(la, F_COSTELLAZIONE, col, c2, r, 1.0 + tot)
			forma(la + Vector3(0, 9.0, 0), F_COSTELLAZIONE, c2, col, r * 0.8, 1.0 + tot, 0.0)
			forma(la, F_STELLA, col, c3, r * 0.85, 1.0 + tot, 0.14)
			anello(la, c3, r, 1.0, 0.06)
			colonna(qui, col, 1.4, 12.0, 1.0)
			bagliore(qui + Vector3(0, 1.4, 0), c2, 5.0, 0.4)
			lampo(qui + Vector3(0, 2, 0), col, 10.0, 24.0, 0.8)
			pioggia_stelle(la, r * 0.8, tot, 30, c2)
			var comete := 6 + ondate * 4
			for i in range(comete):
				_dopo(tot * float(i) / comete, func() -> void:
					var a := randf() * TAU
					var d := r * sqrt(randf())
					var p := Dati.suolo(la.x + cos(a) * d, la.z + sin(a) * d)
					if i % 3 == 0:
						raggio_luce(p + Vector3(5.0, 20.0, 3.0), p, c2, 1.3, 0.4)
						anello(p, col, 2.6, 0.45, 0.1)
					else:
						proiettile(p + Vector3(randf_range(-3, 3), 18.0, randf_range(-3, 3)), p, c3, 40.0, 0.2, stelle.bind(p + Vector3(0, 0.6, 0), c2, 8, 3.5, 0.6), false, 16)
					scuoti(0.3))
			_dopo(tot + 0.1, func() -> void:
				colonna(la, col, 2.2, 24.0, 1.0)
				raggio_luce(la + Vector3(5.0, 22.0, 3.0), la, Color(1, 1, 1), 2.4, 0.6)
				stelle(la + Vector3(0, 1.0, 0), c2, 30, 8.0, 1.2)
				forma(la, F_STELLA, c2, col, r, 1.1)
				_esplosione(la, col, r)
				scuoti(1.0))


## Colpo andato a segno: scintille e un piccolo bagliore sul bersaglio.
func colpo(su: Entita, critico: bool) -> void:
	scintille(su.petto(), Color(1.0, 0.8, 0.4) if critico else Color(1.0, 0.92, 0.75), 14 if critico else 6, 5.5 if critico else 3.0, 0.3, -12.0, 0.2 if critico else 0.15)
	if critico:
		bagliore(su.petto(), Color(1.0, 0.9, 0.6), 2.2, 0.18)


func salita_livello(chi: Entita) -> void:
	var p := chi.global_position
	rune(p, Color(1.0, 0.85, 0.4), 3.2, 1.8)
	colonna(p, Color(1.0, 0.85, 0.4), 1.6, 10.0, 1.6)
	spirale(p, Color(1.0, 0.9, 0.5), 1.3, 4.0, 1.3, 3.0)
	anello(p, Color(1.0, 0.85, 0.4), 5.0, 1.0)
	scintille(chi.petto(), Color(1.0, 0.9, 0.5), 40, 5.0, 1.2, 2.0)
