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
func taglio(pos: Vector3, yaw: float, colore: Color, raggio := 2.8, arco := 2.6, durata := 0.28, inclina := 0.0) -> void:
	var mi := _piano(SH_FENDENTE, colore, durata, raggio * 2.0, {"arco": arco})
	mi.position = pos
	mi.rotation = Vector3(0, yaw + PI, 0)
	mi.rotate_object_local(Vector3(0, 0, 1), inclina)
	# un secondo arco più sottile e chiaro, appena dopo: dà spessore al colpo
	var mi2 := _piano(SH_FENDENTE, colore.lightened(0.55), durata * 0.8, raggio * 2.12, {"arco": arco * 0.9, "interno": 0.86})
	mi2.transform = mi.transform


func fendente(da: Entita, colore: Color, raggio := 2.8, arco := 2.6, durata := 0.28, inclina := 0.0, alza := 1.2) -> void:
	taglio(da.global_position + Vector3(0, alza, 0), da.r, colore, raggio, arco, durata, inclina)


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
	_anima(m, durata, mi)
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
func spirale(pos: Vector3, colore: Color, raggio := 1.0, altezza := 3.0, durata := 1.0, giri := 2.5) -> void:
	for k in range(2):
		var perno := Node3D.new()
		perno.position = pos
		perno.rotation.y = k * PI
		add_child(perno)
		var p := _particelle(Vector3(raggio, 0, 0), colore, 40, 0.55, 0.2)
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
	var p := _particelle(pos + Vector3(0, 0.2, 0), Color(0.62, 0.55, 0.44), quante, 0.9, 0.9)
	var m: StandardMaterial3D = Equip.mat_particella().duplicate()
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	p.material_override = m
	var sf := Gradient.new()
	sf.colors = PackedColorArray([Color(0.6, 0.54, 0.45, 0.55), Color(0.6, 0.54, 0.45, 0.0)])
	p.color_ramp = sf
	p.one_shot = true
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = raggio * 0.6
	p.emission_ring_inner_radius = raggio * 0.2
	p.emission_ring_height = 0.1
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -2.0, 0)
	p.emitting = true
	_dopo(1.3, p.queue_free)
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
func proiettile(da: Vector3, verso, colore: Color, velocita := 28.0, raggio := 0.22, fine := Callable()) -> void:
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
	var coda := _particelle(Vector3.ZERO, colore, 36, 0.4, raggio * 2.6)
	remove_child(coda)
	nodo.add_child(coda)
	coda.local_coords = false
	coda.gravity = Vector3.ZERO
	coda.initial_velocity_max = 0.3
	coda.spread = 180.0
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
			scintille(meta, p.c, 16, 6.0, 0.4)
			bagliore(meta, (p.c as Color).lightened(0.4), float(p.r) * 9.0, 0.25)
			if (p.fine as Callable).is_valid():
				(p.fine as Callable).call()
			n.queue_free()
			_proiettili.remove_at(i)
		else:
			n.position += d.normalized() * passo


func scuoti(forza: float) -> void:
	tremore = maxf(tremore, forza)


## Rende più saturo il colore di una tecnica: molti sono pastello e, sommati alla luce, diventerebbero bianchi.
func vivo(c: Color) -> Color:
	return Color.from_hsv(c.h, clampf(c.s * 1.7 + 0.2, 0.0, 0.95), c.v)


# ------------------------------------------------------------------ tecniche
## sk: voce di SKILLS; da: chi la usa; su: bersaglio (può mancare); m: messaggio `fx` del server (x, z dell'area, fx/fz di partenza).
func tecnica(sk: Dictionary, da: Entita, su: Entita, m: Dictionary) -> void:
	var colore := vivo(Dati.colore(sk.get("color", 0xffffff)))
	var ruolo := String(sk.get("ruolo", ""))
	var forte := ruolo == "potente"
	var raggio := float(sk.get("radius", 3.0))
	var qui := da.global_position
	var la := su.global_position if su != null else qui
	if m.has("x") and m.has("z"):
		la = Dati.suolo(float(m.x), float(m.z))
	var tipo := String(sk.get("type", ""))
	var area := tipo.begins_with("aoe")
	var mano := qui + Vector3(0, 1.5, 0)

	if sk.get("sup", false):
		_suprema(sk, da, su, colore, qui, la, raggio)
		return
	if forte:
		# gli scarichi potenti si annunciano: rune sotto i piedi e una carica di luce
		rune(qui, colore, 2.3, 0.9)
		bagliore(mano, colore, 2.6, 0.25)

	match String(sk.get("fx", "")):
		"spin":
			taglio(qui + Vector3(0, 1.1, 0), da.r, colore, raggio * 0.95, TAU, 0.38 if forte else 0.3)
			anello(qui, colore, raggio, 0.45)
			if String(sk.get("via", "")) == "fulmine":
				for i in range(5 if forte else 3):
					var a := randf() * TAU
					var d := raggio * (0.4 + 0.5 * randf())
					_dopo(0.05 * i, fulmine.bind(Dati.suolo(qui.x + cos(a) * d, qui.z + sin(a) * d), colore, 11.0, 3.2, 0.32))
			if forte:
				_dopo(0.12, taglio.bind(qui + Vector3(0, 1.5, 0), da.r + 1.0, colore.lightened(0.35), raggio * 1.15, TAU, 0.34, 0.25))
				anello(qui, colore, raggio * 1.2, 0.6, 0.1, 1.0)
				scintille(qui + Vector3(0, 1.0, 0), colore, 40, 10.0, 0.6, -6.0)
				scuoti(0.45)
		"slash":
			fendente(da, colore, 3.4 if forte else 2.6, 2.9 if forte else 2.4, 0.3, randf_range(-0.5, 0.5))
			if su != null:
				scintille(su.petto(), colore, 26 if forte else 12, 6.5, 0.4)
				bagliore(su.petto(), colore.lightened(0.4), 3.2 if forte else 1.8, 0.2)
			if forte:
				_dopo(0.08, taglio.bind(qui + Vector3(0, 1.2, 0), da.r, colore.lightened(0.4), 3.9, 2.9, 0.36, randf_range(0.7, 1.1)))
				_dopo(0.16, taglio.bind(qui + Vector3(0, 1.2, 0), da.r, colore, 3.6, 2.6, 0.3, randf_range(-1.1, -0.7)))
				anello(la, colore, 3.2, 0.4)
				crepe(la, colore, 2.4, 1.4)
				scuoti(0.4)
		"dash":
			var partenza := Dati.suolo(float(m.get("fx", qui.x)), float(m.get("fz", qui.z)))
			scia(partenza, qui, colore, 1.5, 0.45)
			scia(partenza, qui, colore.lightened(0.5), 0.5, 0.3)
			fendente(da, colore, 3.0, 2.6, 0.28)
			if su != null:
				scintille(su.petto(), colore, 18, 6.0, 0.4)
				bagliore(su.petto(), colore.lightened(0.4), 2.6, 0.2)
				anello(la, colore, 2.4, 0.35)
		"lightning":
			if area:
				var quante := 9 if forte else 5
				rune(la, colore, raggio, 1.2)
				for i in range(quante):
					var a := randf() * TAU
					var d := raggio * sqrt(randf())
					_dopo(0.07 * i, fulmine.bind(Dati.suolo(la.x + cos(a) * d, la.z + sin(a) * d), colore, 16.0, 4.5, 0.4))
				anello(la, colore, raggio, 0.7, 0.1, 1.0)
			else:
				fulmine(la, colore, 20.0 if forte else 15.0, 7.0 if forte else 4.5, 0.5 if forte else 0.38)
				if su != null:
					scintille(su.petto(), colore, 28 if forte else 12, 8.0, 0.5)
			if forte:
				# il colpo potente: fendente carico, tre saette di contorno, onda d'urto
				fendente(da, colore.lightened(0.3), 3.6, 2.9, 0.32, randf_range(-0.4, 0.4))
				for i in range(3):
					var a := TAU * i / 3.0 + randf()
					_dopo(0.08 + 0.06 * i, fulmine.bind(Dati.suolo(la.x + cos(a) * 2.2, la.z + sin(a) * 2.2), colore.lightened(0.2), 13.0, 3.5, 0.3))
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
				proiettile(mano, su, colore, 30.0, 0.34 if forte else 0.22, anello.bind(la, colore, 2.8 if forte else 1.5, 0.35))
				if forte:
					for i in range(2):
						_dopo(0.08 * (i + 1), proiettile.bind(mano + Vector3(randf_range(-0.6, 0.6), 0.4, 0), su, colore.lightened(0.3), 26.0, 0.16))
		"arrow":
			if su != null:
				proiettile(mano, su, colore, 46.0, 0.1)
				if forte:
					scia(qui, la, colore, 0.8, 0.45)
					scia(qui, la, colore.lightened(0.6), 0.25, 0.3)
					anello(la, colore, 2.6, 0.35)
					crepe(la, colore, 1.8, 1.2)
		"rain":
			rune(la, colore, raggio, 1.3)
			anello(la, colore, raggio, 0.9, 0.08, 1.0)
			for i in range(16 if forte else 10):
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
			# aure e potenziamenti
			rune(qui, colore, 2.4, 1.2)
			colonna(qui, colore, 1.3, 5.5, 1.0)
			spirale(qui, colore, 1.1, 2.8, 0.9)
			bagliore(qui + Vector3(0, 1.3, 0), colore, 3.0, 0.35)


func _esplosione(pos: Vector3, colore: Color, raggio: float) -> void:
	anello(pos, colore, raggio, 0.5, 0.16, 1.0)
	bagliore(pos + Vector3(0, 0.8, 0), colore.lightened(0.4), raggio * 1.3, 0.3)
	scintille(pos + Vector3(0, 0.6, 0), colore, 30, 8.0, 0.6, -5.0)
	lampo(pos + Vector3(0, 1.5, 0), colore, 5.0, raggio * 2.0, 0.3)


func _freccia_dal_cielo(p: Vector3, colore: Color, esplode: bool) -> void:
	proiettile(p + Vector3(randf_range(-1, 1), 14.0, randf_range(-1, 1)), p + Vector3(0, 0.2, 0), colore, 60.0, 0.08, anello.bind(p, colore, 2.2 if esplode else 0.9, 0.3))


# ------------------------------------------------------------------ Tecniche Supreme
## Ogni classe ha la sua regia, distesa sulle ondate della tecnica (waves × waveGap).
func _suprema(sk: Dictionary, da: Entita, su: Entita, colore: Color, qui: Vector3, la: Vector3, raggio: float) -> void:
	var ondate := int(sk.get("waves", 1))
	var passo := float(sk.get("waveGap", 0.35))
	var r := maxf(raggio, 6.0)
	# apertura comune: grande cerchio di rune, colonna, lampo, scossa
	rune(qui, colore, 4.5, 0.6 + ondate * passo)
	colonna(qui, colore, 1.6, 14.0, 1.0)
	bagliore(qui + Vector3(0, 1.4, 0), colore, 5.0, 0.4)
	lampo(qui + Vector3(0, 2, 0), colore, 10.0, 24.0, 0.8)
	scuoti(0.9)
	match String(sk.get("cls", "")):
		"lama":
			# Giudizio dei Tuoni: a ogni ondata un fendente incrociato e una saetta enorme; in chiusura cade il fulmine maestro
			for i in range(ondate):
				_dopo(passo * i, func() -> void:
					if is_instance_valid(da):
						taglio(da.global_position + Vector3(0, 1.3, 0), da.r, colore, 4.6, 3.0, 0.32, 0.9 if i % 2 == 0 else -0.9)
					var p := su.global_position if is_instance_valid(su) else la
					fulmine(p, colore, 24.0, 8.0, 0.45)
					anello(p, colore, 5.0 + i, 0.5)
					scuoti(0.6))
			_dopo(passo * ondate + 0.05, func() -> void:
				var p := su.global_position if is_instance_valid(su) else la
				for k in range(5):
					var a := TAU * k / 5.0
					fulmine(Dati.suolo(p.x + cos(a) * 2.6, p.z + sin(a) * 2.6), colore.lightened(0.3), 20.0, 5.0, 0.5)
				fulmine(p, colore.lightened(0.5), 30.0, 10.0, 0.6)
				crepe(p, colore, 6.0, 3.0)
				scuoti(1.0))
		"ombra":
			# Mille Ombre: una raffica di tagli da ogni lato del bersaglio, poi la croce finale
			var quanti := maxi(8, ondate * 3)
			for i in range(quanti):
				_dopo(passo * ondate * float(i) / quanti, func() -> void:
					var p := (su.petto() if is_instance_valid(su) else la + Vector3(0, 1.2, 0))
					var a := randf() * TAU
					taglio(p, a, colore.lerp(Color(0.6, 0.3, 1.0), 0.5), 3.2, 2.2, 0.2, randf_range(-1.4, 1.4))
					if randf() < 0.4:
						bagliore(p + Vector3(cos(a), 0, sin(a)) * 1.6, Color(0.5, 0.25, 0.9), 1.6, 0.18)
					scintille(p, colore, 8, 6.0, 0.3))
			_dopo(passo * ondate + 0.08, func() -> void:
				var p := (su.petto() if is_instance_valid(su) else la + Vector3(0, 1.2, 0))
				taglio(p, 0.0, Color(1, 1, 1), 5.0, 3.0, 0.4, 0.8)
				taglio(p, 0.0, Color(1, 1, 1), 5.0, 3.0, 0.4, -0.8)
				anello(p - Vector3(0, 1.2, 0), colore, 6.0, 0.6)
				scuoti(0.9))
		"monaco":
			# Drago Celeste: spirali d'oro che salgono, onde concentriche a ogni ondata, la terra che si spacca
			spirale(qui, colore, 2.2, 9.0, 0.5 + ondate * passo, 4.0)
			spirale(qui + Vector3(0, 0.5, 0), colore.lightened(0.4), 1.2, 8.0, 0.4 + ondate * passo, 5.0)
			crepe(qui, Color(colore.r, colore.g * 0.8, colore.b * 0.5, 0.7), r * 0.85, 3.5)
			for i in range(maxi(ondate, 3)):
				_dopo(passo * i, func() -> void:
					anello(qui, colore, r * (0.7 + 0.25 * i), 0.7, 0.14, 0.25)
					polvere(qui, r * 0.8, 20)
					taglio(qui + Vector3(0, 1.0 + 0.5 * i, 0), randf() * TAU, colore, r * 0.7, TAU, 0.4, 0.2)
					scuoti(0.7))
			_dopo(passo * maxi(ondate, 3), colonna.bind(qui, colore, 2.6, 20.0, 1.1))
		_:
			# Collera del Cielo: il cerchio si accende sull'area e piovono saette fitte per tutta la durata
			rune(la, colore, r, 1.0 + ondate * passo)
			anello(la, colore, r, 1.0, 0.08, 1.0)
			var saette := 6 + ondate * 5
			for i in range(saette):
				_dopo((ondate * passo) * float(i) / saette, func() -> void:
					var a := randf() * TAU
					var d := r * sqrt(randf())
					fulmine(Dati.suolo(la.x + cos(a) * d, la.z + sin(a) * d), colore, 22.0, 5.5, 0.4)
					scuoti(0.35))
			_dopo(ondate * passo + 0.1, func() -> void:
				fulmine(la, colore.lightened(0.5), 30.0, 10.0, 0.6)
				_esplosione(la, colore, r)
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
