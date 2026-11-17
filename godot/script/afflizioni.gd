class_name Afflizioni
extends Node3D
## Gli effetti messi addosso a qualcuno, visti SUL bersaglio finché durano: veleno che cola, ferite che sanguinano,
## stelle dello stordimento, gelo del rallentamento, marchi. Il server li annuncia a tutti i vicini con l'effetto `aff`
## (`a` = id dell'effetto, `ms` = durata); lo stordimento arriva con `stun`.
## Niente segni a terra e niente luci: solo particelle leggere agganciate al corpo.

var altezza := 2.0                    # altezza del corpo (testa)
var _attivi: Dictionary = {}          # tipo → { "resto": secondi rimasti, "nodo": Node3D }

static var _mat_goccia: StandardMaterial3D
static var _mat_stella: StandardMaterial3D


## Tipo visivo di un effetto: dal campo `tipo` dell'effetto (shared/data.js), altrimenti dall'id.
static func tipo_di(nome: String) -> String:
	if nome.begins_with("__"):
		return nome.substr(2)
	var b: Dictionary = Dati.BUFFS.get(nome, {})
	if b.has("tipo"):
		return String(b.tipo)
	var sk: Dictionary = Dati.SKILLS.get(nome, {})
	if sk.has("dot"):
		return String((sk.dot as Dictionary).get("tipo", "fuoco" if String(sk.get("dmg", "")) != "phys" else "sangue"))
	return "marchio"


static func mat_goccia() -> StandardMaterial3D:
	if _mat_goccia == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = Equip.alone()
		_mat_goccia = m
	return _mat_goccia


static func mat_stella() -> StandardMaterial3D:
	if _mat_stella == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_texture = Effetti._texture("stella")
		m.albedo_color = Color(1.0, 0.92, 0.4)
		_mat_stella = m
	return _mat_stella


func metti(nome: String, ms: float) -> void:
	var tipo := tipo_di(nome)
	if _attivi.has(tipo):
		_attivi[tipo].resto = maxf(float(_attivi[tipo].resto), ms / 1000.0)
		return
	var n := _crea(tipo)
	if n == null:
		return
	add_child(n)
	_attivi[tipo] = {"resto": ms / 1000.0, "nodo": n}
	set_process(true)


## Marchi dell'Ombra: n schegge cremisi che girano attorno al petto del nemico (0 = tolti).
func marchi(n: int, ms: float) -> void:
	if _attivi.has("marchi"):
		(_attivi["marchi"].nodo as Node3D).queue_free()
		_attivi.erase("marchi")
	if n <= 0:
		return
	var g := Node3D.new()
	g.set_meta("giro", 2.6)
	g.position = Vector3(0, altezza * 0.62, 0)
	var raggio := clampf(altezza * 0.3, 0.45, 1.2)
	for i in range(n):
		var perno := Node3D.new()
		perno.rotation.y = TAU * i / float(n)
		g.add_child(perno)
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.2, 0.52)
		mi.mesh = q
		mi.material_override = mat_marchio()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(raggio, 0, 0)
		mi.rotation = Vector3(0, PI * 0.5, PI)        # la punta in giù, la lama rivolta al nemico
		perno.add_child(mi)
		var mi2 := MeshInstance3D.new()             # una seconda lamina di traverso: si vede da ogni lato
		mi2.mesh = q
		mi2.material_override = mat_marchio()
		mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi2.position = Vector3(raggio, 0, 0)
		mi2.rotation = Vector3(0, 0, PI)
		perno.add_child(mi2)
	add_child(g)
	_attivi["marchi"] = {"resto": ms / 1000.0, "nodo": g}
	set_process(true)


static var _mat_marchio: StandardMaterial3D


static func mat_marchio() -> StandardMaterial3D:
	if _mat_marchio == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_texture = Effetti._texture("petalo")
		m.albedo_color = Color(1.0, 0.12, 0.3)
		_mat_marchio = m
	return _mat_marchio


func togli_tutto() -> void:
	for t in _attivi.keys():
		(_attivi[t].nodo as Node3D).queue_free()
	_attivi.clear()


func _process(dt: float) -> void:
	if _attivi.is_empty():
		set_process(false)
		return
	for t in _attivi.keys():
		var v: Dictionary = _attivi[t]
		var n := v.nodo as Node3D
		v.resto = float(v.resto) - dt
		if float(v.resto) <= 0.0:
			# le particelle già nate finiscono la loro vita, poi il nodo sparisce
			for f in n.get_children():
				if f is CPUParticles3D:
					(f as CPUParticles3D).emitting = false
				else:
					(f as Node3D).visible = false
			get_tree().create_timer(1.4).timeout.connect(n.queue_free)
			_attivi.erase(t)
		elif n.has_meta("giro"):
			n.rotation.y += dt * float(n.get_meta("giro"))


func _gocce(g: Node3D, colore: Color, scuro: Color, quante: int, misura: float, y: float, raggio: float, cade: float, vita: float) -> CPUParticles3D:
	var p := Equip.particelle(g, quante, misura, vita, colore, scuro, 0.95)
	p.material_override = mat_goccia()
	p.position = Vector3(0, y, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = raggio
	p.direction = Vector3.DOWN
	p.spread = 25.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.6
	p.gravity = Vector3(0, -cade, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	return p


func _crea(tipo: String) -> Node3D:
	var g := Node3D.new()
	var h := altezza
	var largo := clampf(h * 0.22, 0.3, 0.9)
	match tipo:
		"veleno":
			# gocce verde acido che colano dal corpo, bolle che salgono sopra la testa, un velo di vapore verde scuro
			_gocce(g, Color(0.5, 1.0, 0.1), Color(0.15, 0.6, 0.05), 18, 0.3, h * 0.62, largo, 6.0, 0.8)
			var bolle := Equip.particelle(g, 10, 0.34, 1.3, Color(0.6, 1.0, 0.25), Color(0.2, 0.8, 0.1), 0.9)
			bolle.position = Vector3(0, h * 0.75, 0)
			bolle.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			bolle.emission_sphere_radius = largo * 0.9
			bolle.direction = Vector3.UP
			bolle.spread = 25.0
			bolle.initial_velocity_min = 0.3
			bolle.initial_velocity_max = 0.9
			bolle.gravity = Vector3(0, 0.6, 0)
			var vap := Equip.particelle(g, 8, 1.3, 1.5, Color(0.2, 0.6, 0.1), Color(0.1, 0.3, 0.05), 0.6, true)
			vap.position = Vector3(0, h * 0.45, 0)
			vap.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			vap.emission_sphere_radius = largo
			vap.direction = Vector3.UP
			vap.spread = 50.0
			vap.initial_velocity_min = 0.1
			vap.initial_velocity_max = 0.4
		"sangue":
			# gocce rosso scuro che cadono dalle ferite, con qualche schizzo
			_gocce(g, Color(0.85, 0.03, 0.02), Color(0.45, 0.0, 0.0), 18, 0.28, h * 0.62, largo, 9.0, 0.7)
			var neb := Equip.particelle(g, 5, 1.0, 1.0, Color(0.7, 0.02, 0.02), Color(0.35, 0.0, 0.0), 0.45, true)
			neb.position = Vector3(0, h * 0.55, 0)
			neb.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			neb.emission_sphere_radius = largo * 0.8
			neb.initial_velocity_min = 0.1
			neb.initial_velocity_max = 0.3
			var sch := Equip.particelle(g, 6, 0.32, 0.45, Color(0.95, 0.06, 0.04), Color(0.5, 0.0, 0.0), 0.95)
			sch.material_override = mat_goccia()
			sch.position = Vector3(0, h * 0.62, 0)
			sch.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			sch.emission_sphere_radius = largo * 0.6
			sch.spread = 180.0
			sch.initial_velocity_min = 1.2
			sch.initial_velocity_max = 2.4
			sch.gravity = Vector3(0, -9.0, 0)
			sch.explosiveness = 0.7
			sch.lifetime = 0.5
		"stordito", "squilibrato":
			# tre stelle che girano sopra la testa
			g.set_meta("giro", 5.0)
			g.position = Vector3(0, h + 0.3, 0)
			for i in range(3):
				var mi := MeshInstance3D.new()
				var q := QuadMesh.new()
				q.size = Vector2(0.5, 0.5)
				mi.mesh = q
				mi.material_override = mat_stella()
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var a := TAU * i / 3.0
				mi.position = Vector3(cos(a), 0.06 * sin(a * 2.0), sin(a)) * (largo + 0.15)
				g.add_child(mi)
		"lento":
			# brina azzurra che sale lenta attorno alle gambe
			var br := Equip.particelle(g, 14, 0.36, 1.2, Color(0.6, 0.85, 1.0), Color(0.3, 0.55, 1.0), 0.85)
			br.position = Vector3(0, h * 0.2, 0)
			br.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			br.emission_sphere_radius = largo
			br.direction = Vector3.UP
			br.spread = 30.0
			br.initial_velocity_min = 0.15
			br.initial_velocity_max = 0.5
			br.local_coords = true
		"fuoco":
			var fi := Equip.particelle(g, 12, 0.3, 0.7, Color(1.0, 0.7, 0.15), Color(1.0, 0.15, 0.02), 0.9)
			fi.position = Vector3(0, h * 0.4, 0)
			fi.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			fi.emission_sphere_radius = largo
			fi.direction = Vector3.UP
			fi.spread = 20.0
			fi.initial_velocity_min = 0.8
			fi.initial_velocity_max = 1.8
			fi.gravity = Vector3(0, 1.5, 0)
		_:
			# marchio: una stella viola che ruota piano sopra la testa, con un filo di fumo scuro
			g.set_meta("giro", 1.6)
			g.position = Vector3(0, h + 0.45, 0)
			var mi := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(0.5, 0.5)
			mi.mesh = q
			var m := mat_stella().duplicate() as StandardMaterial3D
			m.albedo_color = Color(0.75, 0.3, 1.0)
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			g.add_child(mi)
			var fu := Equip.particelle(g, 4, 0.5, 1.0, Color(0.3, 0.1, 0.45), Color(0.15, 0.05, 0.25), 0.5, true)
			fu.direction = Vector3.UP
			fu.spread = 30.0
			fu.initial_velocity_min = 0.2
			fu.initial_velocity_max = 0.5
	return g
