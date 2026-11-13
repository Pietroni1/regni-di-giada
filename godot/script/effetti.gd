class_name Effetti
extends Node3D
## Effetti a vista delle tecniche. Ogni effetto è composto da pochi mattoni (anello, fendente, saetta, colonna,
## scintille, proiettile, lampo) scelti in base al campo `fx` della tecnica e al suo ruolo (medio, potente, Suprema).

const SH_ANELLO := preload("res://shader/fx_anello.gdshader")
const SH_FENDENTE := preload("res://shader/fx_fendente.gdshader")
const SH_FULMINE := preload("res://shader/fx_fulmine.gdshader")
const SH_COLONNA := preload("res://shader/fx_colonna.gdshader")
const SH_SCIA := preload("res://shader/fx_scia.gdshader")

var tremore := 0.0          # letto dalla visuale (Gioco)
var _proiettili: Array = []
var _mat_scintilla: StandardMaterial3D


func _ready() -> void:
	_mat_scintilla = StandardMaterial3D.new()
	_mat_scintilla.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_scintilla.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_scintilla.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mat_scintilla.vertex_color_use_as_albedo = true
	_mat_scintilla.albedo_color = Color(1, 1, 1)


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
	var t := create_tween()
	t.tween_method(func(v: float) -> void: m.set_shader_parameter("fase", v), 0.0, 1.0, durata)
	t.tween_callback(mi.queue_free)
	return mi


## Onda d'urto sul terreno.
func anello(pos: Vector3, colore: Color, raggio: float, durata := 0.5, spessore := 0.16, pieno := 0.0) -> void:
	var mi := _piano(SH_ANELLO, colore, durata, raggio * 2.0, {"spessore": spessore, "pieno": pieno})
	mi.position = pos + Vector3(0, 0.12, 0)


## Mezzaluna di un colpo di lama davanti a chi colpisce (giro = tutto intorno).
func fendente(da: Entita, colore: Color, raggio := 2.8, arco := 2.6, durata := 0.28, inclina := 0.0, alza := 1.2) -> void:
	var mi := _piano(SH_FENDENTE, colore, durata, raggio * 2.0, {"arco": arco})
	mi.position = da.global_position + Vector3(0, alza, 0)
	mi.rotation = Vector3(0, da.r + PI, 0)
	mi.rotate_object_local(Vector3(0, 0, 1), inclina)


## Saetta dal cielo su un punto.
func fulmine(pos: Vector3, colore: Color, altezza := 16.0, larghezza := 5.0, durata := 0.4) -> void:
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
	var t := create_tween()
	t.tween_method(func(v: float) -> void: m.set_shader_parameter("fase", v), 0.0, 1.0, durata)
	t.tween_callback(mi.queue_free)
	lampo(pos + Vector3(0, 1.5, 0), colore, 7.0, 12.0, durata)
	anello(pos, colore, 2.6, 0.4)
	scintille(pos + Vector3(0, 0.4, 0), colore, 18, 7.0, 0.5)


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
	var t := create_tween()
	t.tween_method(func(v: float) -> void: m.set_shader_parameter("fase", v), 0.0, 1.0, durata)
	t.tween_callback(mi.queue_free)


## Scintille che schizzano da un punto.
func scintille(pos: Vector3, colore: Color, quante := 16, velocita := 5.0, durata := 0.5, gravita := -12.0, grandezza := 0.14) -> void:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(grandezza, grandezza)
	p.mesh = q
	p.material_override = _mat_scintilla
	p.amount = quante
	p.lifetime = durata
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = velocita * 0.4
	p.initial_velocity_max = velocita
	p.gravity = Vector3(0, gravita, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	var sf := Gradient.new()
	sf.set_color(0, Color(colore.r * 1.6 + 0.3, colore.g * 1.6 + 0.3, colore.b * 1.6 + 0.3, 1.0))
	sf.set_color(1, Color(colore.r, colore.g, colore.b, 0.0))
	p.color_ramp = sf
	p.position = pos
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.emitting = true
	get_tree().create_timer(durata + 0.3).timeout.connect(p.queue_free)


## Lampo di luce che si spegne.
func lampo(pos: Vector3, colore: Color, energia := 5.0, raggio := 10.0, durata := 0.3) -> void:
	var l := OmniLight3D.new()
	l.light_color = colore
	l.light_energy = energia
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


## Globo che vola verso un bersaglio; all'arrivo chiama `fine`.
func proiettile(da: Vector3, verso, colore: Color, velocita := 28.0, raggio := 0.22, fine := Callable()) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = raggio
	s.height = raggio * 2.0
	mi.mesh = s
	mi.material_override = Edifici.mat(colore.lightened(0.3), 0.3, 0.0, 5.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = da
	var l := OmniLight3D.new()
	l.light_color = colore
	l.light_energy = 2.0
	l.omni_range = 5.0
	mi.add_child(l)
	add_child(mi)
	_proiettili.append({"n": mi, "verso": verso, "v": velocita, "c": colore, "fine": fine, "t": 0.0})


func _process(dt: float) -> void:
	tremore = maxf(0.0, tremore - dt * 2.2)
	for i in range(_proiettili.size() - 1, -1, -1):
		var p: Dictionary = _proiettili[i]
		var n: MeshInstance3D = p.n
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
			scintille(meta, p.c, 14, 5.0, 0.4)
			if (p.fine as Callable).is_valid():
				(p.fine as Callable).call()
			n.queue_free()
			_proiettili.remove_at(i)
		else:
			n.position += d.normalized() * passo
			if randf() < 0.6:
				scintille(n.position, p.c, 2, 0.8, 0.3, 0.0, 0.1)


func scuoti(forza: float) -> void:
	tremore = maxf(tremore, forza)


# ------------------------------------------------------------------ tecniche
## sk: voce di SKILLS; da: chi la usa; su: bersaglio (può mancare); m: messaggio `fx` del server (x, z dell'area, fx/fz di partenza).
func tecnica(sk: Dictionary, da: Entita, su: Entita, m: Dictionary) -> void:
	var colore := Dati.colore(sk.get("color", 0xffffff))
	var ruolo := String(sk.get("ruolo", ""))
	var forte := ruolo == "potente"
	var suprema: bool = sk.get("sup", false)
	var raggio := float(sk.get("radius", 3.0))
	var qui := da.global_position
	var la := su.global_position if su != null else qui
	if m.has("x") and m.has("z"):
		la = Dati.suolo(float(m.x), float(m.z))
	var tipo := String(sk.get("type", ""))
	var area := tipo.begins_with("aoe")

	if suprema:
		colonna(qui, colore, 2.2, 16.0, 1.4)
		lampo(qui + Vector3(0, 2, 0), colore, 10.0, 22.0, 0.8)
		for i in range(3):
			get_tree().create_timer(0.15 * i).timeout.connect(anello.bind(la if area else qui, colore, maxf(raggio, 6.0) * (1.0 + 0.25 * i), 0.8, 0.12))
		scuoti(0.9)

	match String(sk.get("fx", "")):
		"spin":
			fendente(da, colore, raggio * 0.95, TAU, 0.38 if forte else 0.3)
			anello(qui, colore, raggio, 0.45)
			if forte or String(sk.get("via", "")) == "fulmine":
				for i in range(5 if forte else 3):
					var a := randf() * TAU
					var d := raggio * (0.4 + 0.5 * randf())
					fulmine(Dati.suolo(qui.x + cos(a) * d, qui.z + sin(a) * d), colore, 11.0, 3.2, 0.32)
			if forte:
				scuoti(0.45)
		"slash":
			fendente(da, colore, 3.4 if forte else 2.6, 2.9 if forte else 2.4, 0.3, randf_range(-0.5, 0.5))
			if su != null:
				scintille(su.petto(), colore, 22 if forte else 10, 6.0, 0.4)
			if forte:
				fendente(da, colore.lightened(0.4), 3.9, 2.9, 0.36, randf_range(0.6, 1.0))
				anello(la, colore, 3.0, 0.4)
				scuoti(0.4)
		"dash":
			var partenza := Dati.suolo(float(m.get("fx", qui.x)), float(m.get("fz", qui.z)))
			scia(partenza, qui, colore, 1.4, 0.45)
			fendente(da, colore, 3.0, 2.6, 0.28)
			if su != null:
				scintille(su.petto(), colore, 16, 6.0, 0.4)
				anello(la, colore, 2.4, 0.35)
		"lightning":
			if area:
				var quante := 9 if forte or suprema else 5
				for i in range(quante):
					var a := randf() * TAU
					var d := raggio * sqrt(randf())
					var p := Dati.suolo(la.x + cos(a) * d, la.z + sin(a) * d)
					get_tree().create_timer(0.07 * i).timeout.connect(fulmine.bind(p, colore, 16.0, 4.5, 0.4))
				anello(la, colore, raggio, 0.7, 0.1, 1.0)
			else:
				fulmine(la, colore, 20.0 if forte else 15.0, 7.0 if forte else 4.5, 0.5 if forte else 0.38)
				if su != null:
					scintille(su.petto(), colore, 26 if forte else 12, 8.0, 0.5)
			if forte or suprema:
				# il colpo potente: tre saette di contorno, onda d'urto e fendente carico
				fendente(da, colore.lightened(0.3), 3.6, 2.9, 0.32, randf_range(-0.4, 0.4))
				for i in range(3):
					var a := TAU * i / 3.0 + randf()
					get_tree().create_timer(0.08 + 0.06 * i).timeout.connect(fulmine.bind(Dati.suolo(la.x + cos(a) * 2.2, la.z + sin(a) * 2.2), colore.lightened(0.2), 13.0, 3.5, 0.3))
				anello(la, colore, 5.0, 0.55)
				scuoti(0.6)
		"quake":
			var centro := la if tipo == "strike" else qui
			var r := raggio if area else 3.5
			anello(centro, colore, r, 0.6, 0.22)
			anello(centro, colore.darkened(0.3), r * 0.7, 0.45, 0.3, 1.0)
			scintille(centro + Vector3(0, 0.3, 0), Color(0.5, 0.42, 0.3), 30 if forte else 16, 8.0, 0.8, -18.0, 0.26)
			if tipo == "strike":
				fendente(da, colore, 3.0, 2.4, 0.3, 1.3)
			scuoti(0.7 if forte else 0.4)
		"bolt":
			var mano := qui + Vector3(0, 1.5, 0)
			if area:
				proiettile(mano, la + Vector3(0, 0.6, 0), colore, 26.0, 0.3, anello.bind(la, colore, raggio, 0.5, 0.16, 1.0))
			elif su != null:
				proiettile(mano, su, colore, 30.0, 0.34 if forte else 0.22, anello.bind(la, colore, 2.6 if forte else 1.5, 0.35))
			if forte:
				anello(qui, colore, 2.4, 0.35)
		"arrow":
			if su != null:
				proiettile(qui + Vector3(0, 1.5, 0), su, colore, 46.0, 0.1)
				if forte:
					scia(qui, la, colore, 0.7, 0.4)
					anello(la, colore, 2.4, 0.35)
		"rain":
			anello(la, colore, raggio, 0.9, 0.08, 1.0)
			for i in range(14 if forte else 9):
				var a := randf() * TAU
				var d := raggio * sqrt(randf())
				var p := Dati.suolo(la.x + cos(a) * d, la.z + sin(a) * d)
				get_tree().create_timer(0.05 * i).timeout.connect(_freccia_dal_cielo.bind(p, colore, forte))
		"heal":
			colonna(la, colore, 1.0 if not area else raggio * 0.6, 5.0, 1.0)
			anello(la, colore, raggio if area else 1.8, 0.8, 0.12, 1.0)
			scintille(la + Vector3(0, 0.6, 0), colore, 18, 2.2, 1.0, 3.0)
		"shield":
			colonna(la, colore, 1.1, 3.2, 0.9)
			anello(la, colore, 1.8, 0.6)
		"mark", "taunt":
			if su != null:
				anello(la, colore, 2.0, 0.5)
				colonna(la, colore, 0.6, 5.0, 0.6)
				scintille(su.testa(), colore, 10, 3.0, 0.5)
		_:
			# aure e potenziamenti
			colonna(qui, colore, 1.3, 5.5, 1.0)
			anello(qui, colore, 2.6, 0.6)
			scintille(qui + Vector3(0, 1.0, 0), colore, 20, 3.5, 0.8, 2.0)


func _freccia_dal_cielo(p: Vector3, colore: Color, esplode: bool) -> void:
	proiettile(p + Vector3(randf_range(-1, 1), 14.0, randf_range(-1, 1)), p + Vector3(0, 0.2, 0), colore, 60.0, 0.08, anello.bind(p, colore, 2.2 if esplode else 0.9, 0.3))


## Colpo andato a segno: scintille sul bersaglio.
func colpo(su: Entita, critico: bool) -> void:
	scintille(su.petto(), Color(1.0, 0.85, 0.5) if critico else Color(1.0, 0.95, 0.85), 12 if critico else 5, 5.0 if critico else 3.0, 0.3)


func salita_livello(chi: Entita) -> void:
	colonna(chi.global_position, Color(1.0, 0.85, 0.4), 1.6, 10.0, 1.6)
	anello(chi.global_position, Color(1.0, 0.85, 0.4), 5.0, 1.0)
	scintille(chi.petto(), Color(1.0, 0.9, 0.5), 40, 5.0, 1.2, 2.0)
