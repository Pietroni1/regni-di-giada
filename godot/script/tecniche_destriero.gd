class_name TecnicheDestriero
extends RefCounted
## Tecniche a cavallo: quattro per classe (shared/data.js, MOUNT_SKILLS), ognuna con il suo effetto nei colori del destriero
## della classe. Niente cerchi, rune o linee disegnate a terra: scie, saette, fumo, fiamme, proiettili veri e particelle.
## Nessuna luce dinamica. Effetti.tecnica passa di qui quando la tecnica ha `mount`; i mattoni sono quelli di effetti.gd.
##   Lama (saette e acciaio)    Falciata dalla Sella · Carica Travolgente · Impennata di Ferro · Galoppo del Tuono
##   Ombra (fumo e sagome)      Lame al Galoppo · Passaggio Tagliente · Agguato dal Buio · Branco d'Ombre
##   Monaco (fiamma del chi)    Onda Ardente · Zoccoli di Fiamma · Balzo della Gru Ardente · Ruota del Sole
##   Mistico (stelle)           Dardi d'Astri · Velo di Stelle · Cometa · Pioggia di Stelle
## In fondo: ciò che serve all'interfaccia (barra in sella, livello del destriero richiesto, elenco nella scuderia).

const SH_FX := preload("res://shader/destriero_fx.gdshader")
const SH_SAGOMA := preload("res://shader/fx_sagoma_destriero.gdshader")

## [principale, secondario, terzo, quarto] per classe: gli stessi toni degli effetti del destriero al livello massimo.
const PAL := {
	"lama": [Color(0.35, 0.68, 1.0), Color(0.9, 0.96, 1.0), Color(0.6, 0.4, 1.0), Color(1.0, 0.78, 0.35)],
	"ombra": [Color(0.6, 0.28, 0.95), Color(0.17, 0.07, 0.27), Color(0.72, 1.0, 0.35), Color(0.8, 0.08, 0.14)],
	"monaco": [Color(1.0, 0.34, 0.05), Color(1.0, 0.66, 0.18), Color(1.0, 0.18, 0.03), Color(1.0, 0.9, 0.5)],
	"mistico": [Color(0.42, 0.48, 1.0), Color(1.0, 0.88, 0.5), Color(0.55, 0.85, 1.0), Color(1.0, 1.0, 1.0)],
}


## c: il dizionario preparato da Effetti.tecnica (sk, da, su, m, qui, la...).
static func tecnica(fx: Effetti, c: Dictionary) -> void:
	var sk: Dictionary = c.sk
	var da: Entita = c.da
	if da == null:
		return
	if int((c.m as Dictionary).get("ally", 0)) == 1:
		_velo_addosso(fx, da, false)          # il Velo di Stelle ricevuto da un compagno
		return
	match String(sk.get("id", "")):
		"falciata_sella": _falciata(fx, c)
		"carica_travolgente": _carica(fx, c)
		"impennata_ferro": _impennata(fx, c)
		"galoppo_tuono": _galoppo_tuono(fx, c)
		"lame_galoppo": _lame(fx, c)
		"passaggio_tagliente": _passaggio(fx, c)
		"agguato_buio": _agguato(fx, c)
		"branco_ombre": _branco(fx, c)
		"onda_ardente": _onda(fx, c)
		"zoccoli_fiamma": _zoccoli_fiamma(fx, c)
		"balzo_gru": _balzo(fx, c)
		"ruota_sole": _ruota(fx, c)
		"dardi_astri": _dardi(fx, c)
		"velo_stelle": _velo_addosso(fx, da, true)
		"cometa": _cometa(fx, c)
		"pioggia_stelle": _pioggia(fx, c)
		_: fx._generico(c)


# ====================================================================== attrezzi
static func _vivo(e) -> bool:
	return e != null and is_instance_valid(e) and (e as Node).is_inside_tree()


static func _cav(e: Entita) -> Destrieri.Destriero:
	if not _vivo(e) or e.cavallo == null or not is_instance_valid(e.cavallo):
		return null
	return e.cavallo as Destrieri.Destriero


## Petto del cavaliere (in sella sta più in alto del petto dell'entità).
static func _petto(e: Entita) -> Vector3:
	if e.corpo != null and e.sella > 0:
		return e.corpo.global_position + Vector3(0, 1.25, 0)
	return e.petto()


static func _avanti(e: Entita) -> Vector3:
	return Vector3(sin(e.r), 0.0, cos(e.r))


## Posizioni nel mondo dei quattro zoccoli (davanti sinistro e destro, dietro sinistro e destro).
static func _zoccoli(e: Entita) -> Array:
	var out: Array = []
	var d := _cav(e)
	if d != null and d.scheletro != null and d.scheletro.is_inside_tree():
		for o in ["piede_aL", "piede_aR", "piede_pL", "piede_pR"]:
			var i := Destrieri.osso(d.scheletro, o)
			if i >= 0:
				out.append(d.scheletro.global_transform * d.scheletro.get_bone_global_pose(i).origin)
	if out.size() < 4:
		out.clear()
		var b := e.global_transform.basis
		for q in [Vector3(0.3, 0.1, 0.8), Vector3(-0.3, 0.1, 0.8), Vector3(0.3, 0.1, -0.8), Vector3(-0.3, 0.1, -0.8)]:
			out.append(e.global_position + b * q)
	return out


## Mostri vivi entro `raggio` da un punto (per mettere scintille e tagli su chi è stato preso).
static func _nemici(fx: Effetti, da: Entita, centro: Vector3, raggio: float, massimo := 8) -> Array:
	var out: Array = []
	var g := fx.get_parent()
	if g == null or not ("ents" in g):
		return out
	for v in (g.get("ents") as Dictionary).values():
		var q := v as Entita
		if not _vivo(q) or q == da or q.tipo != "m" or q.morto or q.hp <= 0.0:
			continue
		if Vector2(q.global_position.x - centro.x, q.global_position.z - centro.z).length() <= raggio + q.raggio:
			out.append(q)
			if out.size() >= massimo:
				break
	return out


## Mostri vivi entro `larg` metri dal segmento a-b; ognuno con la sua posizione lungo la linea (0..1).
static func _nemici_linea(fx: Effetti, da: Entita, a: Vector3, b: Vector3, larg: float, massimo := 8) -> Array:
	var out: Array = []
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var l2 := maxf(ab.length_squared(), 0.0001)
	for q: Entita in _nemici(fx, da, (a + b) * 0.5, ab.length() * 0.5 + larg, 24):
		var p := Vector2(q.global_position.x - a.x, q.global_position.z - a.z)
		var k := clampf(p.dot(ab) / l2, 0.0, 1.0)
		if (p - ab * k).length() <= larg + q.raggio:
			out.append([q, k])
			if out.size() >= massimo:
				break
	return out


## Quadrato con lo shader degli effetti dei destrieri, sempre rivolto alla visuale: 0 lingua di fuoco, 1 stella, 2 ciuffo
## di saette. Nasce piccolo, dura `vita` secondi e si spegne. Con genitore: resta appeso a lui (posizione locale).
static func _lingua(fx: Effetti, pos: Vector3, misura: Vector2, c1: Color, c2: Color, vita: float, forma := 0, forza := 1.2, genitore: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = misura
	q.center_offset = Vector3(0, misura.y * (0.5 if forma != 1 else 0.0), 0)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = SH_FX
	m.set_shader_parameter("forma", forma)
	m.set_shader_parameter("colore", c1)
	m.set_shader_parameter("colore2", c2)
	m.set_shader_parameter("forza", forza)
	m.set_shader_parameter("fase", randf())
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 1.5
	mi.position = pos
	mi.scale = Vector3.ONE * 0.2
	(genitore if genitore != null else fx).add_child(mi)
	if vita > 0.0:
		var t := mi.create_tween()
		t.tween_property(mi, "scale", Vector3.ONE, 0.1)
		t.tween_interval(maxf(0.02, vita - 0.36))
		t.tween_property(mi, "scale", Vector3(0.5, 0.04, 0.5), 0.26)
		t.tween_callback(mi.queue_free)
	else:
		mi.scale = Vector3.ONE
	return mi


## Mezzaluna larga e sottile di un colpo che spazza attorno al cavaliere (le mezzelune di effetti.gd, a questi raggi,
## sarebbero fasce larghe due metri). yaw = direzione del centro dell'arco, interno = dove comincia la lama (0..1).
static func _mezzaluna(fx: Effetti, pos: Vector3, yaw: float, col: Color, raggio: float, arco: float, durata := 0.3, inclina := 0.0, interno := 0.8, bianco := 0.35) -> void:
	var mi := fx._piano(Effetti.SH_FENDENTE, Color(col.r, col.g, col.b, 0.85), durata, raggio * 2.0, {"arco": arco, "interno": interno, "bianco": bianco})
	mi.position = pos
	mi.rotation = Vector3(0, yaw + PI, 0)
	mi.rotate_object_local(Vector3(0, 0, 1), inclina)


## Arco elettrico fra due punti del mondo, per un momento (nastri sottili rifatti più volte al secondo).
static func _arco_elettrico(fx: Effetti, a: Vector3, b: Vector3, col: Color, alone: Color, durata := 0.3, spessore := 0.035, ampiezza := 0.35, quante := 2) -> void:
	var s := Equip.Saette.new(col, alone)
	s.a = a
	s.b = b
	s.quante = quante
	s.ampiezza = ampiezza
	s.spessore = spessore
	fx.add_child(s)
	fx._dopo(durata, s.queue_free)


## Saetta dal cielo su un punto, senza segni a terra: il lampo, un bagliore e scintille.
static func _saetta_cielo(fx: Effetti, pos: Vector3, col: Color, altezza := 14.0, larghezza := 4.0, durata := 0.32, scintille := 12) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(larghezza, altezza)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = Effetti.SH_FULMINE
	m.set_shader_parameter("colore", col)
	m.set_shader_parameter("seme", randf() * 50.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(0, altezza * 0.5, 0)
	fx.add_child(mi)
	fx._anima(m, durata, mi)
	fx.bagliore(pos + Vector3(0, 0.7, 0), col.lightened(0.25), larghezza * 0.5, durata * 0.8)
	if scintille > 0:
		fx.scintille(pos + Vector3(0, 0.4, 0), col.lightened(0.3), scintille, 7.0, 0.45, -14.0, 0.16)


## Sbuffo di fumo d'ombra (partenze e arrivi dell'Ombra): fumo fitto che sale, nube bassa, faville viola. Nessun anello.
static func _sbuffo(fx: Effetti, pos: Vector3, scuro: Color, viola: Color, grande := 1.0) -> void:
	fx.fumo(pos + Vector3(0, 1.2, 0), scuro, 18, 1.1 * grande, 0.9, 1.9 * grande, 0.5)
	fx.fumo(pos + Vector3(0, 0.5, 0), scuro.lightened(0.12), 10, 1.4 * grande, 1.1, 1.5 * grande, 0.15)
	fx.scintille(pos + Vector3(0, 1.3, 0), viola, 10, 3.5, 0.5, 1.0, 0.13)


## Copia scura del destriero (la sua pelle sullo stesso scheletro): nasce dov'è il cavallo e si può spostare nel mondo.
## Null se il cavaliere non ha un destriero con la pelle (ripiego: nessuna sagoma).
static func _sagoma_cavallo(da: Entita, col: Color, forza := 1.0) -> MeshInstance3D:
	var d := _cav(da)
	if d == null or d.pelle == null or d.scheletro == null or not d.pelle.is_inside_tree():
		return null
	var m := ShaderMaterial.new()
	m.shader = SH_SAGOMA
	m.set_shader_parameter("colore", col)
	m.set_shader_parameter("forza", forza)
	var g := MeshInstance3D.new()
	g.mesh = d.pelle.mesh
	g.skin = d.pelle.skin
	g.material_override = m
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.extra_cull_margin = 30.0
	d.scheletro.add_child(g)
	g.skeleton = g.get_path_to(d.scheletro)
	g.top_level = true
	g.global_transform = d.pelle.global_transform
	return g


## Fa svanire una sagoma in `durata` secondi (e la toglie); `sposta` la fa scivolare intanto.
static func _spegni_sagoma(g: MeshInstance3D, durata: float, sposta := Vector3.ZERO, forza := 1.0) -> void:
	if g == null:
		return
	var m := g.material_override as ShaderMaterial
	var t := g.create_tween().set_parallel()
	t.tween_method(func(v: float) -> void: m.set_shader_parameter("forza", v), forza, 0.0, durata)
	if sposta.length() > 0.01:
		t.tween_property(g, "global_position", g.global_position + sposta, durata)
	t.chain().tween_callback(g.queue_free)


## Scatto a cavallo: il destriero galoppa per un momento e, per chi gioca (la cui posizione è già quella d'arrivo), scivola
## dal punto di partenza. Gli altri giocatori si vedono già correre lungo il tratto.
static func _scatto(da: Entita, partenza: Vector3, arrivo: Vector3, durata := 0.28) -> void:
	var d := _cav(da)
	if d != null:
		d.galoppa(durata + 0.3)
	if da.io and da.cavallo != null and Vector2(partenza.x - arrivo.x, partenza.z - arrivo.z).length() > 1.0:
		var s := Scivolo.new()
		s.e = da
		s.scarto = Vector3(partenza.x - arrivo.x, 0.0, partenza.z - arrivo.z)
		s.durata = durata
		da.add_child(s)
		da.move_child(s, 0)        # prima del corpo: così spegne le scie delle lame prima che campionino la scivolata


## Alone di luce rivolto alla visuale, appeso a un nodo (teste di stelle e comete).
static func _lume(genitore: Node3D, misura: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(misura, misura)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = Equip.alone()
	m.albedo_color = col
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	genitore.add_child(mi)
	return mi


## Nastro di luce che resta nell'aria dietro a un nodo in movimento (la scia dei destrieri) e svanisce da sé.
static func _nastro(fx: Effetti, sorgente: Node3D, c1: Color, c2: Color, vita: float, alto: float, per: float, tremito := 0.0) -> void:
	var n := Destrieri.Scia.new(c1, c2, vita, tremito, alto)
	n.sorgente = sorgente
	n.attiva = true
	fx.add_child(n)
	fx._dopo(per + vita + 0.1, n.queue_free)


## Emettitore di particelle che si può spostare e lascia la coda nel mondo (comete, onde, salti).
static func _coda(fx: Effetti, genitore: Node3D, tex: String, col: Color, quante: int, vita: float, misura: float, sparpaglia := 0.25, col2 := Color(0, 0, 0, 0)) -> CPUParticles3D:
	var p: CPUParticles3D
	if tex == "":
		# senza texture: il colore resta quello dato (le particelle di effetti.gd nascono quasi bianche)
		p = Equip.particelle(genitore, quante, misura, vita, col, col2 if col2.a > 0.0 else col.darkened(0.3), 0.85)
	else:
		p = fx._pezzi(Vector3.ZERO, tex, col, quante, vita, Vector2(misura, misura), true)
		fx.remove_child(p)
		genitore.add_child(p)
	p.local_coords = false
	p.gravity = Vector3.ZERO
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = sparpaglia * 4.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = sparpaglia
	p.emitting = true
	return p


# ====================================================================== Lama: saette e acciaio
## Falciata dalla Sella: la lama spazza tutt'attorno al destriero, a mezz'altezza, con una frustata elettrica su chi è preso.
static func _falciata(fx: Effetti, c: Dictionary) -> void:
	var da: Entita = c.da
	var P: Array = PAL.lama
	var R := float((c.sk as Dictionary).get("radius", 5.5))
	var centro := da.global_position + Vector3(0, 1.75, 0)
	var yaw := da.r
	_mezzaluna(fx, centro, yaw + 0.5, P[0], R * 0.97, 3.9, 0.3, 0.1, 0.8)
	_mezzaluna(fx, centro, yaw + 0.5, P[1], R * 0.99, 3.7, 0.24, 0.1, 0.93, 0.9)
	fx._dopo(0.09, func() -> void:
		if _vivo(da):
			_mezzaluna(fx, da.global_position + Vector3(0, 1.5, 0), yaw + PI + 0.5, P[0], R * 0.85, 3.7, 0.26, -0.14, 0.78))
	for q: Entita in _nemici(fx, da, da.global_position, R, 6):
		_arco_elettrico(fx, centro, q.petto(), P[0], P[2], 0.2, 0.03, 0.3, 1)
		fx.scintille(q.petto(), P[3], 8, 5.0, 0.35, -12.0, 0.12)


## Carica Travolgente: il destriero corre dritto sul bersaglio; polvere dagli zoccoli, archi elettrici bassi lungo la corsa,
## chi sta sulla strada viene sbalzato, spallata all'arrivo.
static func _carica(fx: Effetti, c: Dictionary) -> void:
	var da: Entita = c.da
	var P: Array = PAL.lama
	var pp := fx._punti_scatto(c, false)
	var partenza: Vector3 = pp[0]
	var arrivo: Vector3 = pp[1]
	var tratto := arrivo - partenza
	var lung := tratto.length()
	var yaw := atan2(tratto.x, tratto.z)
	_scatto(da, partenza, arrivo, 0.28)
	var n := clampi(int(lung / 2.2), 2, 8)
	var prima := partenza
	for i in range(n):
		var p := partenza.lerp(arrivo, (i + 1.0) / n)
		var lato := Vector3(tratto.z, 0, -tratto.x).normalized() * (0.7 if i % 2 == 0 else -0.7)
		var a := Dati.suolo(prima.x, prima.z) + Vector3(0, 0.35, 0)
		var b := Dati.suolo(p.x + lato.x, p.z + lato.z) + Vector3(0, 0.35, 0)
		fx._dopo(0.03 * i, func() -> void:
			fx.polvere(Dati.suolo(p.x, p.z), 1.2, 6)
			_arco_elettrico(fx, a, b, P[0], P[2], 0.3, 0.04, 0.3, 2))
		prima = p + lato
	for v in _nemici_linea(fx, da, partenza, arrivo, 3.0):
		var q: Entita = v[0]
		fx._dopo(0.24 * float(v[1]), func() -> void:
			if _vivo(q):
				fx.scintille(q.petto(), P[1], 12, 7.0, 0.4, -12.0, 0.14)
				fx.bagliore(q.petto(), P[0], 1.8, 0.2))
	# il petto del destriero fende l'aria: un ciuffo di saette davanti a lui finché corre
	_lingua(fx, Vector3(0, 0.9, 1.5), Vector2(1.5, 1.9), P[0], P[1], 0.34, 2, 1.6, da.cavallo if _cav(da) != null else da)
	fx._dopo(0.24, func() -> void:
		var dir := tratto.normalized() if lung > 0.1 else Vector3.FORWARD
		var urto := arrivo + dir * 1.5
		_mezzaluna(fx, arrivo + Vector3(0, 1.3, 0), yaw, P[0], 4.2, 2.6, 0.28, 0.0, 0.6, 0.5)
		_mezzaluna(fx, arrivo + Vector3(0, 1.3, 0), yaw, P[1], 4.4, 2.4, 0.22, 0.0, 0.9, 0.9)
		fx.bagliore(urto + Vector3(0, 1.3, 0), P[1], 4.2, 0.24)
		fx.polvere(Dati.suolo(urto.x, urto.z), 2.0, 16)
		fx.schegge(Dati.suolo(urto.x, urto.z) + Vector3(0, 0.3, 0), 8, 7.0)
		fx.scintille(urto + Vector3(0, 1.2, 0), P[3], 26, 9.0, 0.5, -14.0, 0.15)
		for k in range(3):
			_lingua(fx, Dati.suolo(urto.x + randf_range(-1.2, 1.2), urto.z + randf_range(-1.2, 1.2)), Vector2(1.0, 1.7), P[0], P[1], 0.35, 2, 1.5)
		fx.scuoti(0.6))


## Impennata di Ferro: il destriero si alza sui posteriori e ricade; dove battono gli zoccoli volano schegge e polvere e
## le scariche corrono via rasoterra in ogni direzione.
static func _impennata(fx: Effetti, c: Dictionary) -> void:
	var da: Entita = c.da
	var P: Array = PAL.lama
	var R := float((c.sk as Dictionary).get("radius", 6.5))
	var d := _cav(da)
	var quando := 0.3
	if d != null and da.velocita < 4.0:
		quando = clampf(d.impenna(2.4), 0.25, 0.6)
	# mentre sale: saette che si arrampicano sulle zampe davanti
	var z := _zoccoli(da)
	for k in range(2):
		_lingua(fx, z[k], Vector2(0.7, 1.1), P[0], P[1], quando + 0.1, 2, 1.5)
	fx._dopo(quando, func() -> void:
		if not _vivo(da):
			return
		var centro := da.global_position + _avanti(da) * 1.3
		centro = Dati.suolo(centro.x, centro.z)
		fx.schegge(centro + Vector3(0, 0.2, 0), 24, 9.5)
		fx.polvere(centro, R * 0.45, 24)
		fx.bagliore(centro + Vector3(0, 0.8, 0), P[1], 4.5, 0.22)
		fx.scintille(centro + Vector3(0, 0.4, 0), P[3], 22, 9.0, 0.5, -16.0, 0.15)
		for i in range(10):
			var ang := TAU * i / 10.0 + randf() * 0.3
			var p := Dati.suolo(centro.x + cos(ang) * R * 0.8, centro.z + sin(ang) * R * 0.8)
			_arco_elettrico(fx, centro + Vector3(0, 0.3, 0), p + Vector3(0, 0.35, 0), P[0], P[2], 0.34, 0.03, 0.32, 1)
			fx._dopo(0.05 + 0.015 * i, func() -> void:
				fx.polvere(p, 0.9, 5)
				_lingua(fx, p, Vector2(0.8, 1.3), P[0], P[1], 0.4, 2, 1.4))
		for q: Entita in _nemici(fx, da, centro, R, 8):
			fx.scintille(q.petto(), P[1], 8, 5.0, 0.35, -10.0, 0.12)
		fx.scuoti(0.8))


## Galoppo del Tuono: carica da lontano inseguita dalle saette che cadono dal cielo; all'arrivo tre scariche su tutta la
## zona del bersaglio.
static func _galoppo_tuono(fx: Effetti, c: Dictionary) -> void:
	var da: Entita = c.da
	var su: Entita = c.su
	var sk: Dictionary = c.sk
	var P: Array = PAL.lama
	var pp := fx._punti_scatto(c, false)
	var partenza: Vector3 = pp[0]
	var arrivo: Vector3 = pp[1]
	var tratto := arrivo - partenza
	var lung := tratto.length()
	_scatto(da, partenza, arrivo, 0.34)
	var n := clampi(int(lung / 3.2), 3, 7)
	for i in range(n):
		var f := (i + 0.5) / n
		var lato := Vector3(tratto.z, 0, -tratto.x).normalized() * randf_range(-1.6, 1.6)
		var p := Dati.suolo(partenza.x + tratto.x * f + lato.x, partenza.z + tratto.z * f + lato.z)
		fx._dopo(0.04 * i, func() -> void:
			_saetta_cielo(fx, p, P[0], 13.0, 3.2, 0.3, 8)
			fx.polvere(p, 1.0, 5))
	for v in _nemici_linea(fx, da, partenza, arrivo, 3.2):
		var q: Entita = v[0]
		fx._dopo(0.28 * float(v[1]), func() -> void:
			if _vivo(q):
				fx.scintille(q.petto(), P[1], 10, 6.0, 0.4, -12.0, 0.13))
	var centro: Vector3 = su.global_position if _vivo(su) else arrivo
	var R := float(sk.get("radius", 7.0))
	var onde := int(sk.get("waves", 3))
	var passo := float(sk.get("waveGap", 0.4))
	for w in range(onde):
		fx._dopo(0.26 + w * passo, func() -> void:
			var qui: Vector3 = su.global_position if _vivo(su) else centro
			_saetta_cielo(fx, Dati.suolo(qui.x, qui.z), P[1] if w == onde - 1 else P[0], 17.0, 5.5, 0.36, 18)
			for i in range(4):
				var ang := TAU * (i + 0.37 * w) / 4.0 + randf() * 0.5
				var r := R * randf_range(0.4, 0.9)
				_saetta_cielo(fx, Dati.suolo(qui.x + cos(ang) * r, qui.z + sin(ang) * r), P[0], 14.0, 3.6, 0.3, 8)
			for q: Entita in _nemici(fx, da, qui, R, 5):
				_arco_elettrico(fx, qui + Vector3(0, 1.2, 0), q.petto(), P[0], P[2], 0.22, 0.03, 0.35, 1)
			fx.scuoti(0.5 if w < onde - 1 else 0.75))


# ====================================================================== Ombra: fumo, lame e sagome
## Lame al Galoppo: un ventaglio di coltelli veri (o di frecce, con l'arco), uno per ogni nemico attorno al bersaglio.
static func _lame(fx: Effetti, c: Dictionary) -> void:
	var da: Entita = c.da
	var su: Entita = c.su
	if not _vivo(su):
		return
	var P: Array = PAL.ombra
	var tipo := "freccia" if fx._arma_di(da) == "bow" else "lama"
	var colpo := func(q: Entita) -> void:
		if _vivo(q):
			fx.fumo(q.petto(), P[1], 4, 0.3, 0.5, 1.0, 0.2)
			fx.scintille(q.petto(), P[0], 7, 3.8, 0.3, -6.0, 0.11)
	var mete: Array = [su]
	for q: Entita in _nemici(fx, da, su.global_position, float((c.sk as Dictionary).get("radius", 4.5)), 6):
		if q != su and mete.size() < 5:
			mete.append(q)
	var lato := Vector3(cos(da.r), 0, -sin(da.r))
	fx.fumo(_petto(da) + _avanti(da) * 0.5, P[1], 4, 0.3, 0.4, 0.9, 0.2)
	for i in range(mete.size()):
		var q: Entita = mete[i]
		fx._dopo(0.035 * i, func() -> void:
			if _vivo(q) and _vivo(da):
				fx.dardo(_petto(da) + lato * (0.5 if i % 2 == 0 else -0.5) + Vector3(0, 0.15 + 0.1 * i, 0), q, P[2], 48.0, tipo, colpo.bind(q), 1.6))


## Passaggio Tagliente: il corsiero attraversa il bersaglio; lungo la corsa restano le sue sagome e un filo di fumo, e
## su chi è stato sfiorato un taglio scuro e gocce di sangue (la Ferita poi si vede addosso: afflizioni.gd).
static func _passaggio(fx: Effetti, c: Dictionary) -> void:
	var da: Entita = c.da
	var P: Array = PAL.ombra
	var pp := fx._punti_scatto(c, false)
	var partenza: Vector3 = pp[0]
	var arrivo: Vector3 = pp[1]
	var tratto := arrivo - partenza
	var yaw := atan2(tratto.x, tratto.z)
	da.r = yaw
	da.br = yaw
	_scatto(da, partenza, arrivo, 0.24)
	fx._guizzo(partenza, arrivo, P[1], P[0])
	for i in range(3):
		var f := (i + 0.4) / 3.4
		var qui := partenza.lerp(arrivo, f)
		fx._dopo(0.04 + 0.05 * i, func() -> void:
			var g := _sagoma_cavallo(da, P[0], 0.9)
			if g != null:
				g.global_position += Vector3(qui.x - da.global_position.x, 0.0, qui.z - da.global_position.z)
				_spegni_sagoma(g, 0.6, Vector3.ZERO, 0.9)
			else:
				fx.fumo(qui + Vector3(0, 1.2, 0), P[1], 8, 0.8, 0.6, 1.6, 0.3))
	for v in _nemici_linea(fx, da, partenza, arrivo, 3.0):
		var q: Entita = v[0]
		fx._dopo(0.06 + 0.2 * float(v[1]), func() -> void:
			if _vivo(q):
				fx.taglio_ombra(q.petto(), yaw + randf_range(-0.5, 0.5), P[2], P[1], 2.3, 2.1, 0.32, randf_range(-0.8, 0.8))
				fx.gocce(q.petto(), P[3], 7))


## Agguato dal Buio: cavallo e cavaliere svaniscono in uno sbuffo (resta la sagoma che si scioglie) e riappaiono alle
## spalle del bersaglio con un colpo solo, pesante.
static func _agguato(fx: Effetti, c: Dictionary) -> void:
	var da: Entita = c.da
	var su: Entita = c.su
	var P: Array = PAL.ombra
	var pp := fx._punti_scatto(c, true)
	var partenza: Vector3 = pp[0]
	var arrivo: Vector3 = pp[1]
	_sbuffo(fx, partenza, P[1], P[0], 1.3)
	var g := _sagoma_cavallo(da, P[0], 1.0)
	if g != null:
		g.global_position += Vector3(partenza.x - da.global_position.x, 0.0, partenza.z - da.global_position.z)
		_spegni_sagoma(g, 0.7, Vector3(0, -0.9, 0), 1.0)
	da.visible = false
	fx._dopo(0.2, func() -> void:
		if not _vivo(da):
			return
		da.visible = true
		var d := _cav(da)
		if d != null and da.velocita < 4.0:
			d.impenna(2.6)
		_sbuffo(fx, arrivo, P[1], P[0], 1.4)
		var p: Vector3 = su.petto() if _vivo(su) else arrivo + Vector3(0, 1.2, 0)
		var yaw := atan2(p.x - arrivo.x, p.z - arrivo.z)
		fx.taglio_ombra(p, yaw, P[2], P[1], 3.6, 2.6, 0.34, -0.75)
		fx.taglio_ombra(p, yaw, P[0], P[1], 3.4, 2.6, 0.34, 0.75)
		fx.bagliore(p, P[0], 3.0, 0.22)
		fx.gocce(p, P[3], 10)
		fx.scintille(p, P[2], 10, 6.0, 0.4, -8.0, 0.12)
		fx.scuoti(0.5))


## Branco d'Ombre: a ogni ondata una sagoma del corsiero si stacca dal cavaliere e travolge il bersaglio, dovunque sia.
static func _branco(fx: Effetti, c: Dictionary) -> void:
	var da: Entita = c.da
	var su: Entita = c.su
	var sk: Dictionary = c.sk
	var P: Array = PAL.ombra
	var R := float(sk.get("radius", 4.0))
	var onde := int(sk.get("waves", 4))
	var passo := float(sk.get("waveGap", 0.4))
	var ultimo: Array = [c.la]
	for w in range(onde):
		fx._dopo(maxf(0.01, w * passo - 0.12), func() -> void:
			if not _vivo(da):
				return
			if _vivo(su):
				ultimo[0] = su.global_position
			var meta: Vector3 = ultimo[0]
			var qui := da.global_position
			var dir := Vector3(meta.x - qui.x, 0.0, meta.z - qui.z)
			var lung := dir.length()
			dir = dir.normalized() if lung > 0.1 else _avanti(da)
			var lato := Vector3(dir.z, 0, -dir.x) * (1.3 if w % 2 == 0 else -1.3)
			var g := _sagoma_cavallo(da, P[0], 1.0)
			if g != null:
				var base := g.global_transform
				var giro := Basis(Vector3.UP, atan2(dir.x, dir.z) - da.rotation.y)
				g.global_transform = Transform3D(giro * base.basis, base.origin + lato)
				var t := g.create_tween()
				t.tween_property(g, "global_position", base.origin + dir * (lung + 2.5) + lato * 0.2, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
				t.tween_callback(func() -> void: _spegni_sagoma(g, 0.3, dir * 2.0, 1.0))
			fx._guizzo(qui + lato, meta, P[1], P[0])
			fx._dopo(0.22, func() -> void:
				var p: Vector3 = su.petto() if _vivo(su) else meta + Vector3(0, 1.1, 0)
				var yaw := atan2(dir.x, dir.z)
				fx.taglio_ombra(p, yaw + (0.4 if w % 2 == 0 else -0.4), P[2], P[1], R * 0.8, 2.4, 0.3, 0.5 if w % 2 == 0 else -0.5)
				fx.fumo(p, P[1], 8, R * 0.35, 0.6, 1.5, 0.3)
				for q: Entita in _nemici(fx, da, meta, R, 5):
					fx.scintille(q.petto(), P[0], 6, 4.0, 0.3, -6.0, 0.11)
					fx.gocce(q.petto(), P[3], 4)
				if w == onde - 1:
					fx.scuoti(0.4)))


# ====================================================================== Monaco: fiamma del chi
## Chiazza di fuoco a terra che arde per `vita` secondi: lingue di fiamma e faville (la scia degli Zoccoli di Fiamma).
static func _chiazza(fx: Effetti, pos: Vector3, P: Array, vita: float, lingue := 3, largo := 1.3) -> void:
	for i in range(lingue):
		var ang := randf() * TAU
		var r := largo * sqrt(randf())
		var p := Dati.suolo(pos.x + cos(ang) * r, pos.z + sin(ang) * r)
		var alta := randf_range(1.5, 2.4)
		_lingua(fx, p, Vector2(alta * 0.6, alta), P[0] if i % 2 == 0 else P[2], P[1], vita * randf_range(0.8, 1.0), 0, 1.3)
	var f := Equip.particelle(fx, 6, 0.16, 0.8, P[1], P[2], 0.9)
	f.position = pos + Vector3(0, 0.3, 0)
	f.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	f.emission_sphere_radius = largo
	f.direction = Vector3.UP
	f.spread = 25.0
	f.initial_velocity_min = 0.8
	f.initial_velocity_max = 2.2
	f.gravity = Vector3(0, 1.5, 0)
	f.emitting = true
	fx._dopo(maxf(0.1, vita - 0.6), func() -> void: f.emitting = false)
	fx._dopo(vita + 0.5, f.queue_free)


## Onda Ardente: un fronte di fiamma parte dal palmo e corre dritto fino in fondo alla linea, lasciando lingue di fuoco.
static func _onda(fx: Effetti, c: Dictionary) -> void:
	var da: Entita = c.da
	var m: Dictionary = c.m
	var P: Array = PAL.monaco
	var a := da.global_position + _avanti(da) * 1.2
	var fine: Vector3 = c.la
	if m.has("tx") and m.has("tz"):
		fine = Dati.suolo(float(m.tx), float(m.tz))
	var tratto := Vector3(fine.x - a.x, 0.0, fine.z - a.z)
	var lung := tratto.length()
	if lung < 0.5:
		return
	var dir := tratto / lung
	var lato := Vector3(dir.z, 0, -dir.x)
	var tempo := clampf(lung / 36.0, 0.16, 0.45)
	fx.bagliore(_petto(da) + dir * 0.8, P[1], 2.0, 0.2)
	# la testa dell'onda: un nodo che corre con la sua coda di fuoco
	var testa := Node3D.new()
	testa.position = a + Vector3(0, 1.2, 0)
	fx.add_child(testa)
	_coda(fx, testa, "", P[0], 40, 0.45, 0.9, 0.7, P[2])
	for k in range(5):
		# cinque lingue affiancate, più alte al centro: il fronte dell'onda
		var dist := absf(k - 2.0)
		_lingua(fx, lato * (k - 2) * 0.62 - dir * dist * 0.35 + Vector3(0, -1.15, 0), Vector2(1.25, 3.0 - 0.55 * dist), P[0], P[1], 0.0, 0, 1.45, testa)
	var t := testa.create_tween()
	t.tween_property(testa, "position", Vector3(fine.x, a.y + 1.2, fine.z), tempo)
	t.tween_callback(func() -> void:
		fx.fiamme(Dati.suolo(fine.x, fine.z), P[0], 16, 0.7, 2.4, 0.5)
		fx.scintille(fine + Vector3(0, 1.0, 0), P[3], 14, 6.0, 0.4, -6.0, 0.13)
		testa.queue_free())
	# dietro all'onda il fuoco resta un momento
	var n := clampi(int(lung / 1.6), 2, 9)
	for i in range(n):
		var f := (i + 0.6) / n
		for s in [-0.7, 0.7]:
			var p := Dati.suolo(a.x + tratto.x * f + lato.x * s, a.z + tratto.z * f + lato.z * s)
			fx._dopo(tempo * f, func() -> void: _lingua(fx, p, Vector2(1.0, randf_range(1.5, 2.2)), P[2], P[1], 0.6, 0, 1.25))
	for v in _nemici_linea(fx, da, a, fine, 2.6):
		var q: Entita = v[0]
		fx._dopo(tempo * float(v[1]), func() -> void:
			if _vivo(q):
				fx.scintille(q.petto(), P[1], 9, 5.0, 0.35, 2.0, 0.14)
				fx.bagliore(q.petto(), P[0], 1.6, 0.2))


## Zoccoli di Fiamma: gli zoccoli si accendono e per tutta la durata lasciano a terra fuoco che resta ad ardere.
static func _zoccoli_fiamma(fx: Effetti, c: Dictionary) -> void:
	var da: Entita = c.da
	var sc: Dictionary = (c.sk as Dictionary).get("scia", {})
	var P: Array = PAL.monaco
	var dur := float(sc.get("dur", 5.0))
	var vita := float(sc.get("vita", 3.0))
	var largo := float(sc.get("raggio", 2.3)) * 0.6
	fx.fiamme(da.global_position, P[0], 22, float((c.sk as Dictionary).get("radius", 3.0)) * 0.6, 2.6, 0.6)
	for z: Vector3 in _zoccoli(da):
		_lingua(fx, Dati.suolo(z.x, z.z), Vector2(0.9, 1.5), P[0], P[1], 0.6, 0, 1.3)
	fx.scintille(da.global_position + Vector3(0, 0.5, 0), P[3], 16, 6.0, 0.5, 2.0, 0.13)
	var passi := int(dur / 0.25)
	var ultima: Array = [Vector3(1e9, 0, 1e9)]
	for i in range(passi + 1):
		fx._dopo(0.05 + 0.25 * i, func() -> void:
			if not _vivo(da) or da.sella <= 0 or da.morto:
				return
			var p := da.global_position - _avanti(da) * 0.6
			var mosso := Vector2(p.x - (ultima[0] as Vector3).x, p.z - (ultima[0] as Vector3).z).length() > 0.8
			# da fermi il fuoco si rinnova solo ai tempi della scia del server (ogni mezzo secondo)
			if mosso or i % 2 == 0:
				_chiazza(fx, Dati.suolo(p.x, p.z), P, vita, 3 if mosso else 2, largo)
				ultima[0] = p)


## Balzo della Gru Ardente: il cavaliere lascia la sella con una capriola, colpisce il suolo dov'è il bersaglio con un
## palmo di fuoco e torna in sella.
static func _balzo(fx: Effetti, c: Dictionary) -> void:
	var da: Entita = c.da
	var P: Array = PAL.monaco
	var R := float((c.sk as Dictionary).get("radius", 4.5))
	var centro: Vector3 = c.la
	var verso := Vector3(centro.x - da.global_position.x, 0.0, centro.z - da.global_position.z)
	var dir := verso.normalized() if verso.length() > 0.1 else _avanti(da)
	var atterra := Dati.suolo(centro.x - dir.x * 1.1, centro.z - dir.z * 1.1)
	var scoppio := func() -> void:
		fx.fiamme(centro, P[0], 28, R * 0.45, 3.2, 0.6)
		fx.colonna(centro, P[1], 0.9, 5.0, 0.45)
		fx.bagliore(centro + Vector3(0, 0.9, 0), P[1], 5.0, 0.25)
		fx.scintille(centro + Vector3(0, 0.5, 0), P[3], 26, 9.0, 0.55, -8.0, 0.15)
		fx.schegge(centro + Vector3(0, 0.2, 0), 10, 7.0)
		for i in range(9):
			var ang := TAU * i / 9.0 + randf() * 0.3
			var r := R * randf_range(0.45, 0.8)
			var p := Dati.suolo(centro.x + cos(ang) * r, centro.z + sin(ang) * r)
			fx._dopo(0.02 * i, func() -> void: _lingua(fx, p, Vector2(0.9, randf_range(1.4, 2.1)), P[0], P[1], 0.7, 0, 1.1))
		if _vivo(da) and da.corpo != null:
			da.corpo.attacca()
		fx.scuoti(0.65)
	if _cav(da) == null or da.corpo == null:
		fx._dopo(0.2, scoppio)
		return
	fx.scintille(_petto(da), P[1], 10, 4.0, 0.3, 2.0, 0.12)
	var s := Salto.new()
	s.e = da
	s.meta = atterra
	s.all_arrivo = scoppio
	s.scia = _coda(fx, fx, "", P[0], 30, 0.5, 0.75, 0.25, P[2])
	_nastro(fx, s.scia, P[0], P[1], 0.4, 0.45, 0.9)
	da.add_child(s)


## Ruota del Sole: in piedi sulla sella, tre calci di fuoco tutt'attorno che seguono il destriero.
static func _ruota(fx: Effetti, c: Dictionary) -> void:
	var da: Entita = c.da
	var sk: Dictionary = c.sk
	var P: Array = PAL.monaco
	var R := float(sk.get("radius", 6.0))
	var onde := int(sk.get("waves", 3))
	var passo := float(sk.get("waveGap", 0.3))
	if _cav(da) != null and da.corpo != null:
		var g := Giro.new()
		g.e = da
		g.durata = onde * passo + 0.15
		g.giri = float(onde)
		da.add_child(g)
	for w in range(onde):
		fx._dopo(maxf(0.01, w * passo), func() -> void:
			if not _vivo(da):
				return
			var centro := da.global_position + Vector3(0, 1.9 - 0.25 * w, 0)
			var yaw := da.r + TAU * w / 3.0
			_mezzaluna(fx, centro, yaw, P[0] if w < onde - 1 else P[1], R * 0.97, 5.8, passo + 0.12, 0.12 - 0.1 * w, 0.74, 0.3)
			_mezzaluna(fx, centro, yaw, P[3], R * 0.99, 5.6, passo + 0.06, 0.12 - 0.1 * w, 0.93, 0.8)
			fx.fiamme(da.global_position, P[0], 12, R * 0.35, 1.8, 0.4)
			for q: Entita in _nemici(fx, da, da.global_position, R, 6):
				_lingua(fx, q.global_position, Vector2(0.9, 1.7), P[0], P[1], 0.45, 0, 1.2)
				fx.scintille(q.petto(), P[3], 6, 5.0, 0.3, 2.0, 0.12)
			if w == onde - 1:
				fx.bagliore(centro, P[1], R * 0.9, 0.25)
				fx.scuoti(0.45))


# ====================================================================== Mistico: stelle
## Una stella che vola fino a un punto o a un bersaglio con la sua coda (proiettile vero: lo muove Effetti).
static func _stella(fx: Effetti, da: Vector3, verso, c1: Color, c2: Color, velocita: float, misura: float, fine := Callable(), coda := 14) -> void:
	var nodo := Node3D.new()
	nodo.position = da
	fx.add_child(nodo)
	_lingua(fx, Vector3.ZERO, Vector2(misura, misura), c1, c2, 0.0, 1, 1.7, nodo)
	_lume(nodo, misura * 0.75, Color(c1.r, c1.g, c1.b, 0.7))
	_nastro(fx, nodo, c1, c2, 0.28, misura * 0.13, 1.2)
	if coda > 0:
		_coda(fx, nodo, "stella", c1, coda, 0.32, misura * 0.3, misura * 0.08)
	fx._proiettili.append({"n": nodo, "verso": verso, "v": velocita, "c": c1, "fine": fine, "t": 0.0, "r": 0.1, "dardo": true})


## Dardi d'Astri: tre stelle con la coda, sul bersaglio e su chi gli sta accanto.
static func _dardi(fx: Effetti, c: Dictionary) -> void:
	var da: Entita = c.da
	var su: Entita = c.su
	if not _vivo(su):
		return
	var P: Array = PAL.mistico
	var mete: Array = [su]
	for q: Entita in _nemici(fx, da, su.global_position, float((c.sk as Dictionary).get("splash", 3.5)), 4):
		if q != su and mete.size() < 3:
			mete.append(q)
	while mete.size() < 3:
		mete.append(su)
	fx.bagliore(_petto(da) + Vector3(0, 0.7, 0), P[0], 1.8, 0.2)
	for i in range(3):
		var q: Entita = mete[i]
		fx._dopo(0.06 * i, func() -> void:
			if not _vivo(q) or not _vivo(da):
				return
			var parte := _petto(da) + Vector3(0, 0.6 + 0.35 * i, 0) + Vector3(cos(da.r), 0, -sin(da.r)) * (i - 1) * 0.6
			_stella(fx, parte, q, P[1] if i == 0 else P[2], P[3], 40.0, 1.5, func() -> void:
				if _vivo(q):
					fx.stelle(q.petto(), P[1], 8, 3.6, 0.5, 0.0, 0.26)
					fx.bagliore(q.petto(), P[0], 1.7, 0.2)))


## Velo di Stelle addosso a chi lo riceve: una cupola di luce che si chiude e, finché dura, stelle che gli girano attorno.
static func _velo_addosso(fx: Effetti, chi: Entita, pieno: bool) -> void:
	var P: Array = PAL.mistico
	var dur := float((Dati.BUFFS.get("velo_stelle", {}) as Dictionary).get("dur", 8.0))
	var alto := 1.0 if chi.sella > 0 else 0.0
	if pieno:
		fx.cupola(chi.global_position + Vector3(0, alto * 0.4, 0), 2.9, P[0], P[1], 1.3)
	fx.stelle(chi.global_position + Vector3(0, 1.4 + alto, 0), P[1], 16 if pieno else 9, 3.0, 0.9, 1.5, 0.3)
	var vecchio := chi.get_node_or_null("VeloStelle")
	if vecchio != null:
		vecchio.name = "VeloVecchio"
		vecchio.queue_free()
	var giro := Destrieri.Orbita.new()
	giro.name = "VeloStelle"
	giro.velocita = 2.2
	chi.add_child(giro)
	var n := 7 if pieno else 5
	for i in range(n):
		var ang := TAU * i / n
		var h := 0.7 + alto * 0.6 + 1.6 * fmod(i * 0.618, 1.0)
		_lingua(fx, Vector3(cos(ang) * 1.9, h, sin(ang) * 1.9), Vector2(0.55, 0.55), P[1] if i % 2 == 0 else P[2], P[3], 0.0, 1, 1.3, giro)
	var t := giro.create_tween()
	t.tween_interval(maxf(0.2, dur - 0.5))
	t.tween_property(giro, "scale", Vector3(0.05, 1.0, 0.05), 0.5)
	t.tween_callback(giro.queue_free)


## Cometa: scende dal cielo in diagonale da dietro il cavaliere, con la coda, ed esplode sulla zona del bersaglio.
static func _cometa(fx: Effetti, c: Dictionary) -> void:
	var da: Entita = c.da
	var P: Array = PAL.mistico
	var R := float((c.sk as Dictionary).get("radius", 5.5))
	var centro: Vector3 = c.la
	var verso := Vector3(centro.x - da.global_position.x, 0.0, centro.z - da.global_position.z)
	var dir := verso.normalized() if verso.length() > 0.1 else _avanti(da)
	var parte := centro - dir * 11.0 + Vector3(0, 19.0, 0)
	fx.bagliore(_petto(da) + Vector3(0, 0.9, 0), P[1], 1.8, 0.25)
	var testa := Node3D.new()
	testa.position = parte
	fx.add_child(testa)
	_lingua(fx, Vector3.ZERO, Vector2(4.2, 4.2), P[1], P[3], 0.0, 1, 1.8, testa)
	_lume(testa, 3.6, Color(P[2].r, P[2].g, P[2].b, 0.85))
	_lume(testa, 1.6, Color(1, 1, 1, 0.9))
	_nastro(fx, testa, P[0], P[3], 0.5, 0.75, 0.5)
	_nastro(fx, testa, P[1], P[3], 0.3, 0.3, 0.5)
	_coda(fx, testa, "", P[0], 44, 0.55, 1.2, 0.3, P[2])
	_coda(fx, testa, "stella", P[1], 18, 0.6, 0.4, 0.5)
	var t := testa.create_tween()
	t.tween_property(testa, "position", centro + Vector3(0, 0.6, 0), 0.42).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(func() -> void:
		fx.raggio_luce(parte.lerp(centro, 0.55), centro + Vector3(0, 0.3, 0), P[0], 1.6, 0.3)
		fx.bagliore(centro + Vector3(0, 1.0, 0), P[3], R * 1.5, 0.3)
		fx.colonna(centro, P[0], 1.5, 8.0, 0.5)
		fx.stelle(centro + Vector3(0, 0.6, 0), P[1], 34, 10.0, 0.9, -5.0, 0.36)
		fx.stelle(centro + Vector3(0, 0.6, 0), P[2], 20, 6.0, 1.1, 1.5, 0.26)
		fx.polvere(centro, R * 0.4, 14)
		for i in range(7):
			var ang := TAU * i / 7.0 + randf() * 0.4
			var p := Dati.suolo(centro.x + cos(ang) * R * 0.9, centro.z + sin(ang) * R * 0.9) + Vector3(0, 0.5, 0)
			_stella(fx, centro + Vector3(0, 0.7, 0), p, P[2], P[3], 26.0, 0.9, Callable(), 8)
		fx.scuoti(0.8)
		testa.queue_free())


## Pioggia di Stelle: a ogni scroscio le stelle cadono attorno al cavaliere, dovunque sia arrivato, e sui nemici vicini.
static func _pioggia(fx: Effetti, c: Dictionary) -> void:
	var da: Entita = c.da
	var sk: Dictionary = c.sk
	var P: Array = PAL.mistico
	var R := float(sk.get("radius", 6.5))
	var onde := int(sk.get("waves", 6))
	var passo := float(sk.get("waveGap", 0.5))
	fx.stelle(_petto(da) + Vector3(0, 1.0, 0), P[1], 14, 4.0, 0.8, 3.0, 0.3)
	for w in range(onde):
		fx._dopo(maxf(0.01, w * passo - 0.18), func() -> void:
			if not _vivo(da):
				return
			var qui := da.global_position
			var punti: Array = []
			for q: Entita in _nemici(fx, da, qui, R, 4):
				punti.append(q.global_position)
			while punti.size() < 7:
				var ang := randf() * TAU
				var r := R * sqrt(randf())
				punti.append(Dati.suolo(qui.x + cos(ang) * r, qui.z + sin(ang) * r))
			for i in range(punti.size()):
				var p: Vector3 = punti[i]
				var tocca := func() -> void:
					fx.stelle(p + Vector3(0, 0.3, 0), P[1], 5, 3.0, 0.45, 0.0, 0.24)
					fx.bagliore(p + Vector3(0, 0.4, 0), P[0], 1.4, 0.18)
				fx._dopo(0.03 * i, func() -> void:
					var parte := p + Vector3(randf_range(-2.0, 2.0) + 3.0, 11.0, randf_range(-2.0, 2.0))
					_stella(fx, parte, p + Vector3(0, 0.2, 0), P[1] if i % 2 == 0 else P[2], P[3], 42.0, 1.3, tocca, 8)))


# ====================================================================== cavaliere e cavallo in movimento
## Scivolata dello scatto per chi gioca: la posizione è già quella d'arrivo, il destriero vi arriva di corsa dalla partenza.
class Scivolo:
	extends Node
	var e: Entita
	var scarto := Vector3.ZERO      # nel mondo: partenza − arrivo
	var durata := 0.28
	var _t := 0.0

	func _process(dt: float) -> void:
		if e == null or not is_instance_valid(e) or e.cavallo == null or not is_instance_valid(e.cavallo):
			queue_free()
			return
		_t += dt
		var k := clampf(_t / durata, 0.0, 1.0)
		var resto := (1.0 - k) * (1.0 - k)
		e.cavallo.position = e.global_transform.basis.inverse() * (scarto * resto)
		e._siedi()
		if e.corpo != null:
			for sc in e.corpo._scie:      # la scia del colpo, trascinata per tutta la corsa, sarebbe un telo lungo metri
				(sc as Equip.Scia).attiva = false
		if k >= 1.0:
			e.cavallo.position = Vector3.ZERO
			e._siedi()
			queue_free()


## Salto dalla sella: capriola fino a `meta`, un attimo a terra (lì scatta `all_arrivo`), capriola di ritorno. Sta sotto
## l'entità, quindi lavora dopo che questa ha rimesso il cavaliere in sella a ogni fotogramma.
class Salto:
	extends Node
	var e: Entita
	var meta := Vector3.ZERO
	var andata := 0.26
	var sosta := 0.16
	var ritorno := 0.3
	var all_arrivo := Callable()
	var scia: CPUParticles3D = null
	var _t := 0.0
	var _fatto := false

	func _fine() -> void:
		if scia != null and is_instance_valid(scia):
			scia.emitting = false
			scia.get_tree().create_timer(0.6).timeout.connect(scia.queue_free)
		if not _fatto and all_arrivo.is_valid():
			all_arrivo.call()
		queue_free()

	func _process(dt: float) -> void:
		if e == null or not is_instance_valid(e) or e.corpo == null or e.sella <= 0:
			_fine()
			return
		_t += dt
		var k := 0.0
		var giro := 0.0
		if _t < andata:
			k = _t / andata
			giro = k
		elif _t < andata + sosta:
			k = 1.0
		else:
			var q := (_t - andata - sosta) / ritorno
			if q >= 1.0:
				_fine()
				return
			k = 1.0 - q
			giro = -q
		if k >= 1.0 and not _fatto:
			_fatto = true
			if all_arrivo.is_valid():
				all_arrivo.call()
		var c := e.corpo
		var base := c.global_transform
		var b := base.basis.orthonormalized()
		var dolce := k * k * (3.0 - 2.0 * k)
		var p := base.origin.lerp(meta + Vector3(0, 0.15, 0), dolce) + Vector3(0, sin(k * PI) * 2.8, 0)
		var perno := b * Vector3(0, 0.75, 0)
		var rot := Basis(b.x, giro * TAU)
		c.global_transform = Transform3D(rot * b, p + perno - rot * perno)
		if scia != null and is_instance_valid(scia):
			scia.global_position = p + Vector3(0, 0.8, 0)


## Il cavaliere si alza sulla sella e gira su sé stesso (Ruota del Sole).
class Giro:
	extends Node
	var e: Entita
	var durata := 0.9
	var giri := 3.0
	var _t := 0.0

	func _process(dt: float) -> void:
		if e == null or not is_instance_valid(e) or e.corpo == null or e.sella <= 0:
			queue_free()
			return
		_t += dt
		var k := _t / durata
		if k >= 1.0:
			queue_free()
			return
		var c := e.corpo
		var base := c.global_transform
		c.global_transform = Transform3D(Basis(Vector3.UP, k * giri * TAU) * base.basis, base.origin + Vector3(0, sin(k * PI) * 0.4, 0))


# ====================================================================== interfaccia
## Le quattro tecniche a cavallo di una classe, in ordine di livello del destriero.
static func della_classe(classe: String) -> Array:
	var t = Dati.gioco.get("MOUNT_SKILLS", {})
	if t is Dictionary:
		return (t as Dictionary).get(classe, [])
	return []


## Tasto della barra rapida con una tecnica a cavallo: spento finché il destriero non ha il livello richiesto, con la
## descrizione, la ricarica e il livello nel tooltip. (Chiamato da Hud.Tasto.imposta per ogni tecnica.)
static func imposta_tasto(tasto: Control, sk: Dictionary, io: Dictionary) -> void:
	if not sk.get("mount", false):
		return
	var liv := 0
	if io.get("horse") is Dictionary:
		liv = int((io.horse as Dictionary).get("lvl", 0))
	var serve := int(sk.get("hlvl", 1))
	tasto.set_meta("liv_destriero", liv)
	if liv < serve:
		tasto.set("spento", true)
	var stato := "disponibile" if liv >= serve else "si sblocca col destriero al livello %d (ora %d)" % [serve, liv]
	tasto.tooltip_text = "%s  —  Tecnica a cavallo\n%s\nRicarica: %s s · nessun costo · %s" % [sk.get("name", ""), sk.get("desc", ""), String.num(float(sk.get("cd", 0)), 1).trim_suffix(".0"), stato]


## Sopra il tasto di una tecnica a cavallo non ancora sbloccata: un velo scuro e il livello del destriero che serve.
static func disegna_tasto(tasto: Control) -> void:
	var v = tasto.get("voce")
	if not (v is Dictionary) or String((v as Dictionary).get("k", "")) != "s":
		return
	var sk: Dictionary = Dati.SKILLS.get(String(v.id), {})
	if not sk.get("mount", false):
		return
	var serve := int(sk.get("hlvl", 1))
	if int(tasto.get_meta("liv_destriero", 0)) >= serve:
		return
	var f := ThemeDB.fallback_font
	var s := tasto.size
	tasto.draw_rect(Rect2(3, 3, s.x - 6, s.y - 6), Color(0.03, 0.02, 0.02, 0.55))
	var riga := "liv. %d" % serve
	var l1 := f.get_string_size("destriero", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var l2 := f.get_string_size(riga, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	tasto.draw_string_outline(f, Vector2((s.x - l1) * 0.5, s.y * 0.5 - 2), "destriero", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0, 0, 0, 0.9))
	tasto.draw_string(f, Vector2((s.x - l1) * 0.5, s.y * 0.5 - 2), "destriero", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.9, 0.86, 0.75))
	tasto.draw_string_outline(f, Vector2((s.x - l2) * 0.5, s.y * 0.5 + 14), riga, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.95))
	tasto.draw_string(f, Vector2((s.x - l2) * 0.5, s.y * 0.5 + 14), riga, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.82, 0.35))


## Elenco delle tecniche a cavallo della classe sotto il testo della scuderia: icona, nome, livello del destriero
## richiesto (verde se già disponibile) e descrizione. livello = livello del destriero (0 se non lo si ha ancora).
static func elenco_scuderia(etichetta: Label, classe: String, livello: int) -> void:
	var genitore := etichetta.get_parent()
	if genitore == null:
		return
	var lista := genitore.get_node_or_null("TecnicheCavallo") as VBoxContainer
	if lista == null:
		lista = VBoxContainer.new()
		lista.name = "TecnicheCavallo"
		lista.add_theme_constant_override("separation", 6)
		genitore.add_child(lista)
		genitore.move_child(lista, etichetta.get_index() + 1)
	for figlio in lista.get_children():
		lista.remove_child(figlio)
		figlio.queue_free()
	var nome_classe := String((Dati.CLASSES.get(classe, {}) as Dictionary).get("name", classe))
	var titolo := Label.new()
	titolo.text = "Tecniche a cavallo — %s" % nome_classe
	titolo.add_theme_color_override("font_color", Hud.ORO)
	titolo.add_theme_font_size_override("font_size", 14)
	lista.add_child(titolo)
	for sid in della_classe(classe):
		var sk: Dictionary = Dati.SKILLS.get(String(sid), {})
		if sk.is_empty():
			continue
		var serve := int(sk.get("hlvl", 1))
		var ok := livello >= serve
		var riga := HBoxContainer.new()
		riga.add_theme_constant_override("separation", 8)
		lista.add_child(riga)
		var ic := Icone.Vista.new(String(sid), 42.0)
		ic.spento = not ok
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		riga.add_child(ic)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		riga.add_child(col)
		var testa := HBoxContainer.new()
		col.add_child(testa)
		var n := Label.new()
		n.text = String(sk.get("name", sid))
		n.add_theme_font_size_override("font_size", 14)
		n.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85) if ok else Color(0.62, 0.6, 0.56))
		testa.add_child(n)
		var quando := Label.new()
		quando.text = "   destriero liv. %d%s  ·  ricarica %s s" % [serve, "" if ok else " (non ancora)", String.num(float(sk.get("cd", 0)), 1).trim_suffix(".0")]
		quando.add_theme_font_size_override("font_size", 12)
		quando.add_theme_color_override("font_color", Color(0.45, 0.85, 0.5) if ok else Color(0.95, 0.6, 0.3))
		testa.add_child(quando)
		var d := Label.new()
		d.text = String(sk.get("desc", ""))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(330, 0)
		d.add_theme_font_size_override("font_size", 11)
		d.add_theme_color_override("font_color", Color(0.72, 0.7, 0.64))
		col.add_child(d)
