class_name Edifici
## Edifici del villaggio costruiti da codice in stile orientale: tetti a falde concave con gli angoli rialzati,
## telaio di legno scuro, intonaco chiaro, basamento di pietra. Sono provvisori ma sostituibili uno a uno
## con modelli fatti in Blender (basta restituire un altro Node3D dalle stesse funzioni).

const INTONACO := Color(0.80, 0.74, 0.62)
const LEGNO := Color(0.20, 0.12, 0.08)
const PIETRA := Color(0.42, 0.40, 0.37)
const ORO := Color(0.85, 0.65, 0.22)
const BRONZO := Color(0.42, 0.28, 0.13)
const CARTA := Color(1.0, 0.78, 0.45)

static var _tetto_shader: Shader = preload("res://shader/tetto.gdshader")
static var _mat_cache: Dictionary = {}


static func mat(c: Color, ruvido := 0.85, metallo := 0.0, emissione := 0.0) -> StandardMaterial3D:
	var k := "%s|%s|%s|%s" % [c.to_html(), ruvido, metallo, emissione]
	if _mat_cache.has(k):
		return _mat_cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = ruvido
	m.metallic = metallo
	if emissione > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emissione
	_mat_cache[k] = m
	return m


## Materiali dipinti da codice (shader/intonaco, legno, pietra): un materiale per colore, riusato.
static func _dipinto(nome: String, c: Color) -> ShaderMaterial:
	var k := nome + c.to_html()
	if _mat_cache.has(k):
		return _mat_cache[k]
	var m := ShaderMaterial.new()
	m.shader = load("res://shader/%s.gdshader" % nome)
	m.set_shader_parameter("colore", c)
	_mat_cache[k] = m
	return m


static func intonaco(c: Color) -> ShaderMaterial:
	return _dipinto("intonaco", c)


static func legno(c: Color) -> ShaderMaterial:
	return _dipinto("legno", c)


static func pietra(c: Color) -> ShaderMaterial:
	return _dipinto("pietra", c)


static func scatola(dim: Vector3, pos: Vector3, m: Material, genitore: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = dim
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	genitore.add_child(mi)
	return mi


static func cilindro(r_alto: float, r_basso: float, h: float, pos: Vector3, m: Material, genitore: Node3D, lati := 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_alto
	c.bottom_radius = r_basso
	c.height = h
	c.radial_segments = lati
	c.rings = 1
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	genitore.add_child(mi)
	return mi


## Tetto a padiglione con falde concave e angoli all'insù. w, d: pianta coperta; h: altezza del colmo.
## ornati: code ricurve alle estremità del colmo, punte e campanelle di bronzo agli angoli (case, pagode, porte, torri).
static func tetto(w: float, d: float, h: float, sporto: float, colore: Color, rialzo := 0.55, ornati := false) -> MeshInstance3D:
	var W := w + sporto * 2.0
	var D := d + sporto * 2.0
	var n := clampi(int(maxf(W, D) * 1.6), 8, 24)      # riquadri in proporzione: i tetti piccoli (mura) ne hanno bisogno di pochi
	var emax := minf(W, D) * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(n + 1):
		for i in range(n + 1):
			var x := (float(i) / n - 0.5) * W
			var z := (float(j) / n - 0.5) * D
			var ex := W * 0.5 - absf(x)
			var ez := D * 0.5 - absf(z)
			var t := clampf(minf(ex, ez) / emax, 0.0, 1.0)
			var ang := pow(absf(x) / (W * 0.5), 4.0) * pow(absf(z) / (D * 0.5), 4.0)
			var y := h * pow(t, 1.55) + rialzo * ang + 0.12 * (1.0 - t) * (1.0 - t)
			var lungo := z if ex < ez else x
			st.set_uv(Vector2(lungo, (1.0 - t) * emax * 1.15))
			st.add_vertex(Vector3(x, y, z))
	for j in range(n):
		for i in range(n):
			var a := j * (n + 1) + i
			var b := a + 1
			var c := a + n + 1
			var dd := c + 1
			st.add_index(a); st.add_index(b); st.add_index(c)
			st.add_index(b); st.add_index(dd); st.add_index(c)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var sm := ShaderMaterial.new()
	sm.shader = _tetto_shader
	sm.set_shader_parameter("colore", colore)
	mi.material_override = sm
	# colmo: trave lungo l'asse più lungo
	var lung := absf(W - D) + 0.6
	var colmo := Vector3(lung, 0.28, 0.34) if W >= D else Vector3(0.34, 0.28, lung)
	scatola(colmo, Vector3(0, h + 0.1, 0), mat(colore.darkened(0.45), 0.6), mi)
	if ornati:
		_ornati_tetto(mi, W, D, h, rialzo, lung, W >= D, colore)
	return mi


## Code del colmo (riccioli all'insù), fascia sul colmo, punte agli angoli e campanelle appese.
static func _ornati_tetto(t: Node3D, W: float, D: float, h: float, rialzo: float, lung: float, lungo_x: bool, colore: Color) -> void:
	var scuro := mat(colore.darkened(0.45), 0.6)
	var bronzo := mat(BRONZO, 0.45, 0.6)
	var asse := Vector3(1, 0, 0) if lungo_x else Vector3(0, 0, 1)
	var alto := clampf(minf(W, D) * 0.06, 0.25, 0.45)
	scatola(Vector3(lung, 0.1, 0.42) if lungo_x else Vector3(0.42, 0.1, lung), Vector3(0, h + 0.27, 0), mat(colore.lightened(0.15), 0.6), t)
	for s in ([-1.0, 1.0] if lung > 1.2 else []):      # i tetti quadrati (torri, pagode) hanno solo il pinnacolo
		var c: Vector3 = asse * (lung * 0.5 - 0.1) * s + Vector3(0, h + 0.2, 0)
		# ricciolo: tre blocchi sempre più inclinati verso l'esterno, come una coda che si arriccia
		for k in range(3):
			var b := scatola(Vector3(0.3, alto * (0.75 - k * 0.15), 0.3), c + asse * s * (k * 0.13) + Vector3(0, alto * (0.35 + k * 0.42), 0), scuro if k < 2 else bronzo, t)
			b.rotation = (Vector3(0, 0, -1) if lungo_x else Vector3(1, 0, 0)) * s * (0.25 + k * 0.45)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var ang := Vector3(sx * W * 0.5, rialzo + 0.12, sz * D * 0.5)
			var punta := cilindro(0.0, 0.05, 0.3, ang + Vector3(sx * 0.05, 0.1, sz * 0.05), bronzo, t, 5)
			punta.rotation = Vector3(sz * 0.7, 0, -sx * 0.7)
			cilindro(0.012, 0.012, 0.35, ang + Vector3(-sx * 0.25, -0.2, -sz * 0.25), scuro, t, 3)
			cilindro(0.07, 0.11, 0.18, ang + Vector3(-sx * 0.25, -0.44, -sz * 0.25), bronzo, t, 6)


## Casa: muri intonacati con telaio di legno, porta sul lato +z, tetto a coppi.
## accento (facoltativo): tendina sulla porta, insegna, lanterne di carta alla gronda e tetto ornato.
static func casa(w: float, d: float, tetto_col: Color, muro_h := 2.8, tetto_h := 2.4, accento := Color(0, 0, 0, 0)) -> Node3D:
	var g := Node3D.new()
	var travi := legno(LEGNO)
	scatola(Vector3(w + 0.7, 0.45, d + 0.7), Vector3(0, 0.22, 0), pietra(PIETRA), g)
	scatola(Vector3(w, muro_h, d), Vector3(0, 0.45 + muro_h * 0.5, 0), intonaco(INTONACO), g)
	# telaio: montanti agli angoli e a intervalli, travi in alto e a mezza altezza
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			scatola(Vector3(0.3, muro_h, 0.3), Vector3(sx * w * 0.5, 0.45 + muro_h * 0.5, sz * d * 0.5), travi, g)
	var nx := maxi(1, int(w / 2.4))
	for i in range(1, nx):
		var x := -w * 0.5 + w * i / nx
		for sz in [-1.0, 1.0]:
			scatola(Vector3(0.18, muro_h, 0.08), Vector3(x, 0.45 + muro_h * 0.5, sz * (d * 0.5 + 0.02)), travi, g)
	var nz := maxi(1, int(d / 2.4))
	for i in range(1, nz):
		var z := -d * 0.5 + d * i / nz
		for sx in [-1.0, 1.0]:
			scatola(Vector3(0.08, muro_h, 0.18), Vector3(sx * (w * 0.5 + 0.02), 0.45 + muro_h * 0.5, z), travi, g)
	for y in [0.45 + muro_h - 0.12, 0.45 + muro_h * 0.52]:
		scatola(Vector3(w + 0.12, 0.2, d + 0.12), Vector3(0, y, 0), travi, g)
	# porta scorrevole e finestre a grata
	scatola(Vector3(1.5, 2.1, 0.1), Vector3(0, 0.45 + 1.05, d * 0.5 + 0.06), mat(Color(0.30, 0.18, 0.10), 0.7), g)
	scatola(Vector3(0.06, 2.1, 0.12), Vector3(0, 0.45 + 1.05, d * 0.5 + 0.07), travi, g)
	var carta := mat(Color(0.95, 0.88, 0.66), 0.9, 0.0, 0.35)
	for sx in [-1.0, 1.0]:
		if w > 5.0:
			var fx: float = sx * (w * 0.5 - 1.3)
			scatola(Vector3(1.1, 0.9, 0.08), Vector3(fx, 0.45 + muro_h * 0.62, d * 0.5 + 0.05), carta, g)
			for k in range(-1, 2):
				scatola(Vector3(0.05, 0.9, 0.1), Vector3(fx + k * 0.3, 0.45 + muro_h * 0.62, d * 0.5 + 0.06), travi, g)
	var t := tetto(w, d, tetto_h, 1.25, tetto_col, 0.55, accento.a > 0.0)
	t.position.y = 0.45 + muro_h
	g.add_child(t)
	if accento.a > 0.0:
		# tendina divisa sopra la porta, insegna verticale accanto, lanterne di carta appese alla gronda
		var y_porta := 0.45 + 2.1
		for k in range(4):
			scatola(Vector3(0.36, 0.62, 0.03), Vector3(-0.57 + k * 0.38, y_porta - 0.25, d * 0.5 + 0.13), mat(accento.darkened(0.2), 0.9), g)
		scatola(Vector3(1.7, 0.08, 0.08), Vector3(0, y_porta + 0.08, d * 0.5 + 0.14), travi, g)
		insegna(Vector3(1.3, 0.45 + muro_h * 0.55, d * 0.5 + 0.08), accento, g)
		for sx in [-1.0, 1.0]:
			lanterna_carta(Vector3(sx * (w * 0.5 + 0.55), 0.45 + muro_h - 0.05, d * 0.5 + 0.75), CARTA, g, 0.8)
	return g


## Pagoda a tre piani con colonne laccate e pinnacolo dorato.
static func pagoda(lato: float, tetto_col: Color, accento: Color) -> Node3D:
	var g := Node3D.new()
	scatola(Vector3(lato + 2.4, 0.5, lato + 2.4), Vector3(0, 0.25, 0), pietra(PIETRA), g)
	scatola(Vector3(lato + 1.2, 0.35, lato + 1.2), Vector3(0, 0.67, 0), pietra(PIETRA.lightened(0.1)), g)
	var y := 0.85
	var lacca := mat(accento.darkened(0.15), 0.45)
	for piano in range(3):
		var l := lato * (1.0 - 0.24 * piano)
		var hm := 3.2 - 0.5 * piano
		scatola(Vector3(l * 0.86, hm, l * 0.86), Vector3(0, y + hm * 0.5, 0), intonaco(INTONACO), g)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				cilindro(0.2, 0.22, hm, Vector3(sx * l * 0.47, y + hm * 0.5, sz * l * 0.47), lacca, g, 10)
		scatola(Vector3(l + 0.1, 0.26, l + 0.1), Vector3(0, y + hm - 0.13, 0), lacca, g)
		if piano == 0:
			scatola(Vector3(1.9, 2.4, 0.12), Vector3(0, y + 1.2, l * 0.43 + 0.05), mat(Color(0.25, 0.12, 0.08), 0.6), g)
		else:
			scatola(Vector3(l * 0.5, hm * 0.4, l * 0.87), Vector3(0, y + hm * 0.55, 0), mat(Color(0.95, 0.86, 0.6), 0.9, 0.0, 0.5), g)
		var sporto := 1.5 - 0.2 * piano
		var t := tetto(l, l, 1.5 if piano < 2 else 2.4, sporto, tetto_col, 0.8, true)
		t.position.y = y + hm
		g.add_child(t)
		if piano < 2:
			var e := l * 0.5 + sporto - 0.35
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					lanterna_carta(Vector3(sx * e, y + hm + 0.55, sz * e), CARTA, g, 0.9 - piano * 0.15)
		y += hm + (0.75 if piano < 2 else 2.4)
	cilindro(0.06, 0.16, 2.2, Vector3(0, y + 1.0, 0), mat(ORO, 0.3, 0.9), g, 8)
	for k in range(3):
		cilindro(0.3 - k * 0.07, 0.3 - k * 0.07, 0.07, Vector3(0, y + 0.5 + k * 0.45, 0), mat(ORO, 0.3, 0.9), g, 12)
	# stendardi lunghi ai lati del portone (appesi alla trave, dentro la pianta della pagoda)
	for sx in [-1.0, 1.0]:
		stendardo(Vector3(sx * lato * 0.3, 0.85 + 3.0, lato * 0.43 + 0.12), 2.2, accento, g)
	return g


## Fucina: casa bassa con camino e bagliore del fuoco.
static func fucina(w: float, d: float, tetto_col: Color, accento := Color(0, 0, 0, 0)) -> Node3D:
	var g := casa(w, d, tetto_col, 2.6, 2.0, accento)
	scatola(Vector3(1.1, 5.6, 1.1), Vector3(w * 0.5 - 1.0, 2.8, -d * 0.5 + 1.0), pietra(PIETRA.darkened(0.2)), g)
	scatola(Vector3(1.6, 0.9, 1.0), Vector3(-w * 0.5 + 1.6, 0.9, d * 0.5 + 1.2), mat(Color(0.12, 0.12, 0.13), 0.5, 0.6), g)   # incudine
	scatola(Vector3(1.2, 0.7, 1.2), Vector3(w * 0.5 - 1.2, 0.8, d * 0.5 + 1.2), mat(Color(1.0, 0.45, 0.1), 0.6, 0.0, 3.0), g)  # braci
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 2.5
	l.omni_range = 9.0
	l.distance_fade_enabled = true
	l.distance_fade_begin = 45.0
	l.distance_fade_length = 15.0
	l.position = Vector3(w * 0.5 - 1.2, 1.8, d * 0.5 + 1.4)
	g.add_child(l)
	return g


## Bancarella del mercato: banco, quattro pali e telo colorato.
static func bancarella(telo: Color, ruolo := "") -> Node3D:
	var g := Node3D.new()
	var travi := legno(Color(0.36, 0.24, 0.14))
	scatola(Vector3(4.0, 0.95, 1.4), Vector3(0, 0.48, 0), travi, g)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			scatola(Vector3(0.12, 2.9, 0.12), Vector3(sx * 1.95, 1.45, sz * 0.75), travi, g)
	var t := scatola(Vector3(4.6, 0.08, 2.4), Vector3(0, 2.95, 0.15), mat(telo, 0.9), g)
	t.rotation.x = 0.18
	# balza del telo con frangia a denti sul davanti
	scatola(Vector3(4.6, 0.32, 0.04), Vector3(0, 2.62, 1.32), mat(telo.darkened(0.25), 0.9), g)
	for k in range(9):
		scatola(Vector3(0.24, 0.16, 0.035), Vector3(-2.0 + k * 0.5, 2.4, 1.33), mat(telo.darkened(0.25), 0.9), g).rotation.z = PI / 4.0
	merci(ruolo, g)
	lanterna_carta(Vector3(1.85, 2.75, 1.15), CARTA, g, 0.7)
	return g


static func pozzo() -> Node3D:
	var g := Node3D.new()
	cilindro(1.25, 1.3, 0.95, Vector3(0, 0.47, 0), pietra(PIETRA), g, 14)
	cilindro(0.95, 0.95, 0.06, Vector3(0, 0.82, 0), mat(Color(0.05, 0.12, 0.16), 0.1), g, 14)
	for sx in [-1.0, 1.0]:
		scatola(Vector3(0.16, 2.6, 0.16), Vector3(sx * 1.15, 1.3, 0), legno(LEGNO), g)
	var t := tetto(2.2, 1.2, 0.7, 0.4, Color(0.25, 0.14, 0.1), 0.2)
	t.position.y = 2.6
	g.add_child(t)
	return g


## Lanterna di pietra con la fiamma accesa (la luce vera si aggiunge solo ad alcune, per non pesare).
static func lanterna(con_luce: bool) -> Node3D:
	var g := Node3D.new()
	var pietra := pietra(PIETRA.lightened(0.08))
	scatola(Vector3(0.7, 0.2, 0.7), Vector3(0, 0.1, 0), pietra, g)
	cilindro(0.14, 0.18, 1.2, Vector3(0, 0.8, 0), pietra, g, 8)
	scatola(Vector3(0.62, 0.12, 0.62), Vector3(0, 1.46, 0), pietra, g)
	scatola(Vector3(0.36, 0.42, 0.36), Vector3(0, 1.73, 0), mat(Color(1.0, 0.72, 0.32), 0.6, 0.0, 4.0), g)
	cilindro(0.0, 0.55, 0.38, Vector3(0, 2.13, 0), pietra, g, 4).rotation.y = PI / 4.0
	if con_luce:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.7, 0.35)
		l.light_energy = 1.6
		l.omni_range = 8.0
		l.distance_fade_enabled = true       # le luci lontane si spengono: ogni luce accesa costa
		l.distance_fade_begin = 45.0
		l.distance_fade_length = 15.0
		l.position = Vector3(0, 1.8, 0)
		g.add_child(l)
	return g


## Tratto di mura: pietra in basso, intonaco e copertura a coppi.
static func tratto_mura(larghezza: float, tetto_col: Color) -> Node3D:
	var g := Node3D.new()
	scatola(Vector3(larghezza, 1.8, 1.55), Vector3(0, 0.9, 0), pietra(PIETRA), g)
	scatola(Vector3(larghezza + 0.02, 0.14, 1.62), Vector3(0, 1.82, 0), pietra(PIETRA.darkened(0.2)), g)
	scatola(Vector3(larghezza, 2.7, 1.1), Vector3(0, 3.2, 0), intonaco(INTONACO.darkened(0.08)), g)
	scatola(Vector3(larghezza + 0.02, 0.2, 1.2), Vector3(0, 4.45, 0), legno(LEGNO), g)
	var t := tetto(larghezza + 0.1, 1.2, 0.6, 0.35, tetto_col, 0.0)
	t.position.y = 4.55
	g.add_child(t)
	return g


## Porta del villaggio: due colonne laccate e un tetto sopra l'architrave.
static func porta(luce: float, tetto_col: Color, accento: Color) -> Node3D:
	var g := Node3D.new()
	var lacca := mat(accento.darkened(0.1), 0.45)
	var bronzo := mat(BRONZO, 0.4, 0.7)
	var oro := mat(ORO, 0.35, 0.8)
	for sx in [-1.0, 1.0]:
		cilindro(0.45, 0.5, 6.4, Vector3(sx * luce * 0.5, 3.2, 0), lacca, g, 12)
		scatola(Vector3(1.3, 0.5, 1.3), Vector3(sx * luce * 0.5, 0.25, 0), pietra(PIETRA), g)
		scatola(Vector3(1.05, 0.3, 1.05), Vector3(sx * luce * 0.5, 0.62, 0), pietra(PIETRA.lightened(0.1)), g)
		for y in [0.85, 4.35]:
			cilindro(0.53, 0.53, 0.16, Vector3(sx * luce * 0.5, y, 0), bronzo, g, 12)
	scatola(Vector3(luce + 2.6, 0.5, 0.6), Vector3(0, 5.6, 0), lacca, g)
	scatola(Vector3(luce + 2.7, 0.08, 0.66), Vector3(0, 5.88, 0), oro, g)
	scatola(Vector3(luce + 1.2, 0.36, 0.5), Vector3(0, 4.7, 0), lacca, g)
	# targa: cornice d'oro, fondo scuro, emblema a disco (nessuna scritta vera)
	scatola(Vector3(2.6, 1.0, 0.12), Vector3(0, 5.15, 0), oro, g)
	scatola(Vector3(2.4, 0.8, 0.16), Vector3(0, 5.15, 0), mat(Color(0.1, 0.08, 0.07), 0.6), g)
	for sz in [-1.0, 1.0]:
		var em := cilindro(0.28, 0.28, 0.03, Vector3(0, 5.15, sz * 0.09), oro, g, 12)
		em.rotation.x = PI / 2.0
		for sx in [-1.0, 1.0]:
			scatola(Vector3(0.5, 0.06, 0.03), Vector3(sx * 0.7, 5.15, sz * 0.09), oro, g)
	# mensole a grappolo sotto la gronda
	var nm := maxi(3, int(luce / 1.4))
	for k in range(nm + 1):
		var x := lerpf(-luce * 0.5 - 0.8, luce * 0.5 + 0.8, float(k) / nm)
		scatola(Vector3(0.3, 0.18, 0.75), Vector3(x, 6.0, 0), lacca, g)
		scatola(Vector3(0.42, 0.14, 0.95), Vector3(x, 6.2, 0), legno(LEGNO), g)
		scatola(Vector3(0.25, 0.12, 0.25), Vector3(x, 6.33, 0), oro, g)
	var t := tetto(luce + 2.0, 1.6, 1.3, 1.0, tetto_col, 0.7, true)
	t.position.y = 6.4
	g.add_child(t)
	# secondo tetto, più piccolo, sopra il centro
	if luce >= 5.0:
		scatola(Vector3(luce * 0.42, 0.9, 0.8), Vector3(0, 7.85, 0), lacca, g)
		scatola(Vector3(luce * 0.42 + 0.1, 0.12, 0.86), Vector3(0, 8.32, 0), oro, g)
		var t2 := tetto(luce * 0.42, 0.8, 0.8, 0.7, tetto_col, 0.5, true)
		t2.position.y = 8.3
		g.add_child(t2)
	return g


# ------------------------------------------------------------------ dettagli dei villaggi
## Lanterna di carta appesa: corpo bombato luminoso, coperchi di legno, nappa. pos = punto d'aggancio (in alto).
static func lanterna_carta(pos: Vector3, colore: Color, genitore: Node3D, scala := 1.0) -> void:
	var legno_s := mat(Color(0.14, 0.08, 0.05), 0.6)
	var corpo := MeshInstance3D.new()
	var sf := SphereMesh.new()
	sf.radius = 0.24 * scala
	sf.height = 0.56 * scala
	sf.radial_segments = 8
	sf.rings = 3
	corpo.mesh = sf
	corpo.material_override = mat(colore, 0.9, 0.0, 1.4)
	corpo.position = pos + Vector3(0, -0.42 * scala, 0)
	corpo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	genitore.add_child(corpo)
	# coperchi e nappa non fanno ombra (materiali solo loro: la fusione non si divide)
	for pezzo in [cilindro(0.01, 0.01, 0.14 * scala, pos + Vector3(0, -0.07 * scala, 0), legno_s, genitore, 3),
			cilindro(0.11 * scala, 0.13 * scala, 0.06 * scala, pos + Vector3(0, -0.16 * scala, 0), legno_s, genitore, 6),
			cilindro(0.13 * scala, 0.11 * scala, 0.06 * scala, pos + Vector3(0, -0.69 * scala, 0), legno_s, genitore, 6),
			cilindro(0.025 * scala, 0.05 * scala, 0.22 * scala, pos + Vector3(0, -0.83 * scala, 0), mat(Color(0.7, 0.14, 0.08), 0.9), genitore, 4)]:
		pezzo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Filo teso fra due punti con lanterne appese (catenaria approssimata a tratti dritti).
static func filo_lanterne(a: Vector3, b: Vector3, quante: int, colori: Array, genitore: Node3D, freccia := 0.6) -> void:
	var corda := mat(Color(0.12, 0.08, 0.05), 0.9)
	var tratti := 8
	var punto := func(t: float) -> Vector3: return a.lerp(b, t) - Vector3(0, freccia * 4.0 * t * (1.0 - t), 0)
	for k in range(tratti):
		var p0: Vector3 = punto.call(float(k) / tratti)
		var p1: Vector3 = punto.call(float(k + 1) / tratti)
		var seg := scatola(Vector3(0.045, 0.045, p0.distance_to(p1) + 0.02), Vector3.ZERO, corda, genitore)
		seg.transform = Transform3D(Basis.looking_at(p1 - p0, Vector3.UP), (p0 + p1) * 0.5)
	for k in range(quante):
		lanterna_carta(punto.call((k + 1.0) / (quante + 1.0)), colori[k % colori.size()], genitore, 0.75)


## Insegna verticale di legno con pannello laccato e segni dorati (motivo astratto, non scrittura vera).
static func insegna(pos: Vector3, accento: Color, genitore: Node3D) -> void:
	scatola(Vector3(0.62, 1.5, 0.08), pos, legno(LEGNO), genitore)
	scatola(Vector3(0.48, 1.32, 0.04), pos + Vector3(0, 0, 0.045), mat(accento.darkened(0.35), 0.5), genitore)
	var oro := mat(ORO, 0.35, 0.8)
	for k in range(3):
		var y := 0.4 - k * 0.42
		scatola(Vector3(0.26, 0.05, 0.02), pos + Vector3(0, y + 0.08, 0.07), oro, genitore)
		scatola(Vector3(0.05, 0.22, 0.02), pos + Vector3(-0.05 + (k % 2) * 0.1, y - 0.02, 0.07), oro, genitore)
		scatola(Vector3(0.14, 0.04, 0.02), pos + Vector3(0.04, y - 0.1, 0.07), oro, genitore)


## Stendardo appeso a un'asta orizzontale (torri, pagode): telo nel colore del regno, bordo e disco d'oro, due code.
## La faccia guarda +z del genitore.
static func stendardo(pos: Vector3, alto: float, accento: Color, genitore: Node3D) -> void:
	scatola(Vector3(1.2, 0.08, 0.08), pos, legno(LEGNO), genitore)
	scatola(Vector3(0.95, alto, 0.04), pos + Vector3(0, -alto * 0.5 - 0.05, 0), mat(accento, 0.85), genitore)
	var oro := mat(ORO, 0.35, 0.8)
	scatola(Vector3(0.95, 0.1, 0.05), pos + Vector3(0, -alto - 0.05, 0), oro, genitore)
	var disco := cilindro(0.26, 0.26, 0.03, pos + Vector3(0, -alto * 0.38, 0.03), oro, genitore, 12)
	disco.rotation.x = PI / 2.0
	var rombo := scatola(Vector3(0.2, 0.2, 0.02), pos + Vector3(0, -alto * 0.38, 0.05), mat(accento.darkened(0.3), 0.85), genitore)
	rombo.rotation.z = PI / 4.0
	for sx in [-1.0, 1.0]:
		var coda := scatola(Vector3(0.22, 0.45, 0.03), pos + Vector3(sx * 0.32, -alto - 0.3, 0), mat(accento.darkened(0.25), 0.85), genitore)
		coda.rotation.z = sx * 0.08


## Torre ottagonale di pietra e intonaco con tetto ornato (sta sopra un ostacolo delle mura: raggio ≤ 2 m).
static func torre(alto: float, tetto_col: Color, accento: Color) -> Node3D:
	var g := Node3D.new()
	var travi := legno(LEGNO)
	cilindro(1.95, 2.05, 2.4, Vector3(0, 1.2, 0), pietra(PIETRA), g, 8).rotation.y = PI / 8.0
	cilindro(1.7, 1.8, alto - 2.4, Vector3(0, 2.4 + (alto - 2.4) * 0.5, 0), intonaco(INTONACO.darkened(0.05)), g, 8).rotation.y = PI / 8.0
	cilindro(1.95, 1.95, 0.22, Vector3(0, alto - 0.1, 0), travi, g, 8).rotation.y = PI / 8.0
	cilindro(1.85, 1.85, 0.16, Vector3(0, 2.45, 0), travi, g, 8).rotation.y = PI / 8.0
	var carta := mat(Color(0.95, 0.88, 0.66), 0.9, 0.0, 0.35)
	for k in range(4):
		var a := TAU * k / 4.0
		var fin := scatola(Vector3(0.5, 0.75, 0.06), Vector3(sin(a) * 1.66, alto - 1.3, cos(a) * 1.66), carta, g)
		fin.rotation.y = a
		var tr := scatola(Vector3(0.06, 0.75, 0.08), Vector3(sin(a) * 1.7, alto - 1.3, cos(a) * 1.7), travi, g)
		tr.rotation.y = a
	var t := tetto(3.0, 3.0, 1.7, 0.75, tetto_col, 0.6, true)
	t.position.y = alto
	g.add_child(t)
	cilindro(0.04, 0.12, 1.2, Vector3(0, alto + 2.3, 0), mat(ORO, 0.3, 0.9), g, 6)
	for k in range(2):
		cilindro(0.18 - k * 0.05, 0.18 - k * 0.05, 0.05, Vector3(0, alto + 2.05 + k * 0.3, 0), mat(ORO, 0.3, 0.9), g, 8)
	return g


## Cassa di legno con fascia scura (pos = centro della base).
static func cassa(pos: Vector3, lato: float, rot: float, genitore: Node3D) -> void:
	var c := scatola(Vector3(lato, lato * 0.8, lato), pos + Vector3(0, lato * 0.4, 0), legno(Color(0.42, 0.29, 0.16)), genitore)
	c.rotation.y = rot
	var b := scatola(Vector3(lato + 0.03, 0.06, lato + 0.03), pos + Vector3(0, lato * 0.62, 0), legno(LEGNO), genitore)
	b.rotation.y = rot


## Botte con due cerchi di ferro (pos = centro della base).
static func botte(pos: Vector3, genitore: Node3D) -> void:
	cilindro(0.38, 0.38, 0.95, pos + Vector3(0, 0.48, 0), legno(Color(0.4, 0.26, 0.14)), genitore, 10)
	cilindro(0.33, 0.33, 0.02, pos + Vector3(0, 0.96, 0), legno(LEGNO), genitore, 10)
	for y in [0.18, 0.78]:
		cilindro(0.395, 0.395, 0.07, pos + Vector3(0, y, 0), mat(Color(0.16, 0.14, 0.13), 0.5, 0.6), genitore, 10)


## Albero in vaso (pino potato a nuvole): vaso di ceramica, tronco piegato, tre cuscini di aghi.
static func albero_vaso(pos: Vector3, seme: int, genitore: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seme
	cilindro(0.5, 0.36, 0.55, pos + Vector3(0, 0.28, 0), mat(Color(0.18, 0.28, 0.32), 0.35), genitore, 10)
	cilindro(0.52, 0.52, 0.06, pos + Vector3(0, 0.55, 0), mat(Color(0.14, 0.2, 0.24), 0.35), genitore, 10)
	var tronco := cilindro(0.07, 0.12, 1.3, pos + Vector3(0.1, 1.15, 0), legno(Color(0.3, 0.2, 0.13)), genitore, 6)
	tronco.rotation.z = rng.randf_range(-0.35, 0.35)
	var aghi := mat(Color(0.17, 0.3, 0.12), 0.9)
	for k in range(3):
		var a := rng.randf() * TAU
		var c := MeshInstance3D.new()
		var sf := SphereMesh.new()
		sf.radius = 0.42 - k * 0.07
		sf.height = 0.38 - k * 0.05
		sf.radial_segments = 10
		sf.rings = 4
		c.mesh = sf
		c.material_override = aghi
		c.position = pos + Vector3(sin(a) * 0.35 * (1 - k * 0.4), 1.55 + k * 0.38, cos(a) * 0.35 * (1 - k * 0.4))
		c.scale = Vector3(1.4, 1.0, 1.2)
		genitore.add_child(c)


## Lastricato della piazza: disco di lastre chiare con cordolo scuro e raggi (sottile: si cammina sopra come sul terreno).
static func piazzale(raggio: float, pos: Vector3, genitore: Node3D) -> void:
	cilindro(raggio, raggio, 0.06, pos + Vector3(0, 0.02, 0), pietra(PIETRA.lightened(0.18)), genitore, 40)
	var scura := pietra(PIETRA.darkened(0.15))
	var anello := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = raggio - 0.45
	tor.outer_radius = raggio + 0.1
	tor.rings = 40
	tor.ring_segments = 4
	anello.mesh = tor
	anello.material_override = scura
	anello.position = pos + Vector3(0, 0.04, 0)
	anello.scale = Vector3(1, 0.22, 1)
	genitore.add_child(anello)
	for k in range(8):
		var a := TAU * k / 8.0
		var r := scatola(Vector3(0.35, 0.04, raggio - 1.9), pos + Vector3(sin(a), 0, cos(a)) * (raggio * 0.5 + 0.7) + Vector3(0, 0.06, 0), scura, genitore)
		r.rotation.y = a


## Elemento al centro della piazza, diverso per regno (sta dentro l'ostacolo del vecchio pozzo, raggio 1,3 m).
static func centro_piazza(regno: String, accento: Color) -> Node3D:
	var g := Node3D.new()
	var oro := mat(ORO, 0.3, 0.85)
	cilindro(1.25, 1.3, 0.5, Vector3(0, 0.25, 0), pietra(PIETRA.lightened(0.05)), g, 8).rotation.y = PI / 8.0
	cilindro(1.05, 1.15, 0.2, Vector3(0, 0.6, 0), pietra(PIETRA.darkened(0.1)), g, 8).rotation.y = PI / 8.0
	match regno:
		"fenice":
			# braciere sacro: treppiede di bronzo, conca con le braci, fiamme stilizzate e piume d'oro attorno
			var bronzo := mat(BRONZO, 0.4, 0.7)
			for k in range(3):
				var a := TAU * k / 3.0
				var gamba := cilindro(0.06, 0.1, 1.3, Vector3(sin(a) * 0.55, 1.25, cos(a) * 0.55), bronzo, g, 6)
				gamba.rotation = Vector3(cos(a) * 0.25, 0, -sin(a) * 0.25)
			cilindro(0.95, 0.5, 0.55, Vector3(0, 2.0, 0), bronzo, g, 14)
			cilindro(1.0, 1.0, 0.08, Vector3(0, 2.28, 0), oro, g, 14)
			var braci := cilindro(0.85, 0.85, 0.06, Vector3(0, 2.25, 0), mat(Color(1.0, 0.42, 0.1), 0.6, 0.0, 4.0), g, 14)
			braci.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var fuoco := mat(Color(1.0, 0.55, 0.15), 0.6, 0.0, 5.0)
			for k in range(5):
				var a := TAU * k / 5.0 + 0.3
				var f := cilindro(0.0, 0.2, 0.9 - (k % 2) * 0.3, Vector3(sin(a) * 0.35, 2.7 - (k % 2) * 0.12, cos(a) * 0.35), fuoco, g, 5)
				f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var cuore := cilindro(0.0, 0.3, 1.4, Vector3(0, 2.95, 0), mat(Color(1.0, 0.8, 0.35), 0.6, 0.0, 6.0), g, 6)
			cuore.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for k in range(6):
				var a := TAU * k / 6.0
				var piuma := scatola(Vector3(0.14, 0.7, 0.04), Vector3(sin(a) * 1.0, 2.55, cos(a) * 1.0), oro, g)
				piuma.rotation = Vector3(0, a, 0)
				piuma.rotate_object_local(Vector3.RIGHT, 0.5)
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.6, 0.25)
			l.light_energy = 2.2
			l.omni_range = 10.0
			l.distance_fade_enabled = true
			l.distance_fade_begin = 45.0
			l.distance_fade_length = 15.0
			l.position = Vector3(0, 3.0, 0)
			g.add_child(l)
		"tigre":
			# stele della tigre: lastra di pietra con fasce incise, volto stilizzato, cappello a tetto, due lanterne
			var lastra := pietra(Color(0.55, 0.55, 0.53))
			scatola(Vector3(1.6, 0.35, 0.8), Vector3(0, 0.88, 0), lastra, g)
			scatola(Vector3(1.0, 3.0, 0.32), Vector3(0, 2.55, 0), lastra, g)
			for k in range(3):
				scatola(Vector3(0.78, 0.05, 0.36), Vector3(0, 1.6 + k * 0.85, 0), pietra(PIETRA.darkened(0.25)), g)
			for lato in [1.0, -1.0]:
				for sx in [-1.0, 1.0]:
					for k in range(3):
						var st := scatola(Vector3(0.32, 0.06, 0.04), Vector3(sx * 0.2, 3.5 - k * 0.15, lato * 0.17), mat(Color(0.1, 0.1, 0.1), 0.7), g)
						st.rotation.z = sx * 0.45
					scatola(Vector3(0.1, 0.06, 0.04), Vector3(sx * 0.16, 3.72, lato * 0.18), oro, g)
			var cap := tetto(1.0, 0.32, 0.35, 0.25, Color(0.28, 0.27, 0.28), 0.25)
			cap.position.y = 4.05
			g.add_child(cap)
			for sx in [-1.0, 1.0]:
				cilindro(0.13, 0.15, 1.6, Vector3(sx * 0.95, 1.5, 0.45), lastra, g, 6)
				scatola(Vector3(0.36, 0.3, 0.36), Vector3(sx * 0.95, 2.45, 0.45), mat(Color(1.0, 0.75, 0.4), 0.6, 0.0, 3.0), g)
				scatola(Vector3(0.48, 0.08, 0.48), Vector3(sx * 0.95, 2.64, 0.45), lastra, g)
		_:
			# fontana del drago: vasca d'acqua, colonna di giada con spire che salgono, testa e perla in cima
			cilindro(0.98, 0.98, 0.04, Vector3(0, 0.72, 0), mat(Color(0.12, 0.3, 0.32), 0.05, 0.3), g, 16)
			var giada := mat(accento.lerp(Color(0.2, 0.55, 0.4), 0.5), 0.35, 0.1)
			cilindro(0.2, 0.26, 2.6, Vector3(0, 2.0, 0), giada, g, 8)
			for k in range(14):
				var a := k * 0.9
				var sp := cilindro(0.11, 0.11, 0.42, Vector3(sin(a) * 0.32, 1.0 + k * 0.17, cos(a) * 0.32), giada, g, 6)
				sp.rotation = Vector3(0, a, PI / 2.0 - 0.35)
			var testa := scatola(Vector3(0.3, 0.26, 0.55), Vector3(0, 3.35, 0.22), giada, g)
			testa.rotation.x = 0.35
			for sx in [-1.0, 1.0]:
				var corno := cilindro(0.0, 0.05, 0.4, Vector3(sx * 0.1, 3.6, 0.05), oro, g, 4)
				corno.rotation.x = -0.7
			var perla := MeshInstance3D.new()
			var sf := SphereMesh.new()
			sf.radius = 0.2
			sf.height = 0.4
			sf.radial_segments = 12
			sf.rings = 6
			perla.mesh = sf
			perla.material_override = mat(Color(0.85, 0.95, 0.9), 0.2, 0.0, 1.2)
			perla.position = Vector3(0, 3.62, 0.55)
			g.add_child(perla)
			for k in range(4):
				var a := TAU * k / 4.0 + PI / 4.0
				var bocca := cilindro(0.06, 0.09, 0.2, Vector3(sin(a) * 1.15, 0.62, cos(a) * 1.15), giada, g, 6)
				bocca.rotation = Vector3(cos(a) * 1.2, 0, -sin(a) * 1.2)
	return g


## Merci sopra il banco di una bancarella (stanno dentro l'ostacolo del banco; coordinate della bancarella).
static func merci(ruolo: String, genitore: Node3D) -> void:
	var metallo := mat(Color(0.62, 0.64, 0.66), 0.3, 0.85)
	match ruolo:
		"armi":
			for k in range(3):
				var x := -1.3 + k * 1.3
				var rot := 0.5 - k * 0.5
				scatola(Vector3(0.06, 0.03, 1.0), Vector3(x, 1.0, 0.0), metallo, genitore).rotation.y = rot
				scatola(Vector3(0.25, 0.05, 0.06), Vector3(x + sin(rot) * 0.5, 1.02, cos(rot) * 0.5), mat(ORO, 0.35, 0.8), genitore).rotation.y = rot
			for sx in [-1.0, 1.0]:
				var scudo := cilindro(0.38, 0.38, 0.06, Vector3(sx * 1.55, 1.5, -0.62), legno(Color(0.5, 0.18, 0.12)), genitore, 12)
				scudo.rotation.x = PI / 2.0 - 0.15
				cilindro(0.12, 0.12, 0.08, Vector3(sx * 1.55, 1.5, -0.58), metallo, genitore, 8).rotation.x = PI / 2.0 - 0.15
			# rastrelliera con lance dietro il banco
			scatola(Vector3(1.4, 0.08, 0.08), Vector3(0, 1.8, -0.64), legno(LEGNO), genitore)
			for k in range(4):
				cilindro(0.025, 0.025, 1.9, Vector3(-0.5 + k * 0.33, 1.9, -0.6), legno(Color(0.36, 0.24, 0.14)), genitore, 4)
				cilindro(0.0, 0.05, 0.25, Vector3(-0.5 + k * 0.33, 2.95, -0.6), metallo, genitore, 4)
		_:
			var cesta := legno(Color(0.6, 0.45, 0.22))
			var tinte := [Color(0.25, 0.5, 0.18), Color(0.6, 0.15, 0.12), Color(0.82, 0.62, 0.2), Color(0.35, 0.55, 0.3)]
			for k in range(4):
				var x := -1.45 + k * 0.95
				cilindro(0.34, 0.26, 0.22, Vector3(x, 1.06, 0.15), cesta, genitore, 10)
				cilindro(0.3, 0.3, 0.06, Vector3(x, 1.18, 0.15), mat(tinte[k], 0.9), genitore, 10)
			for k in range(3):
				var x := -1.0 + k * 1.0
				cilindro(0.12, 0.16, 0.38, Vector3(x, 1.14, -0.42), mat(Color(0.62, 0.55, 0.42), 0.4), genitore, 8)
				cilindro(0.07, 0.07, 0.08, Vector3(x, 1.37, -0.42), mat(Color(0.3, 0.12, 0.08), 0.6), genitore, 6)
			# mazzi d'erbe appesi sotto il telo
			for k in range(5):
				var x := -1.6 + k * 0.8
				cilindro(0.008, 0.008, 0.3, Vector3(x, 2.62, 0.55), mat(Color(0.12, 0.08, 0.05), 0.9), genitore, 3)
				cilindro(0.11, 0.03, 0.35, Vector3(x, 2.32, 0.55), mat(tinte[k % 4].darkened(0.2), 0.9), genitore, 6)


# ------------------------------------------------------------------ fusione
## Firma di un materiale: due materiali con la stessa firma si disegnano insieme.
static func _firma(m: Material) -> String:
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		var t := sm.shader.resource_path
		for u in sm.shader.get_shader_uniform_list():
			t += "|%s=%s" % [u.name, var_to_str(sm.get_shader_parameter(u.name))]
		return t
	if m is StandardMaterial3D:
		var b := m as StandardMaterial3D
		return "std|%s|%.2f|%.2f|%s|%.2f|%d|%d" % [b.albedo_color, b.roughness, b.metallic, b.emission if b.emission_enabled else Color.BLACK,
				b.emission_energy_multiplier, b.transparency, b.cull_mode]
	return str(m.get_instance_id()) if m != null else "nullo"


## Fonde tutte le mesh ferme sotto «radice» in poche mesh, una per materiale (e per ombra sì/no): meno disegni.
## Restano fuori quelli trasparenti e ciò che non è fatto di triangoli; una mesh con figli si fonde e resta come nodo vuoto.
## vista: oltre questa distanza (metri) il gruppo non si disegna.
static func fondi(radice: Node3D, vista := 0.0) -> void:
	var gruppi := {}
	for n in radice.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.visible or mi.get_script() != null:
			continue
		# trasformazione rispetto alla radice
		var rel := Transform3D.IDENTITY
		var p: Node = mi
		while p != null and p != radice:
			if p is Node3D:
				rel = (p as Node3D).transform * rel
			p = p.get_parent()
		var nb := rel.basis.inverse().transposed()
		var tolte := true
		for si in range(mi.mesh.get_surface_count()):
			var mat: Material = mi.material_override if mi.material_override != null else mi.mesh.surface_get_material(si)
			var arr := mi.mesh.surface_get_arrays(si)
			if mat == null or arr.is_empty() or arr[Mesh.ARRAY_VERTEX] == null:
				tolte = false
				continue
			if mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				tolte = false
				continue
			var chiave := "%s#%d" % [_firma(mat), mi.cast_shadow]
			if not gruppi.has(chiave):
				gruppi[chiave] = {"mat": mat, "ombra": mi.cast_shadow, "v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "i": PackedInt32Array()}
			var g: Dictionary = gruppi[chiave]
			var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var base: int = (g.v as PackedVector3Array).size()
			var nn = arr[Mesh.ARRAY_NORMAL]
			var uu = arr[Mesh.ARRAY_TEX_UV]
			for k in range(vv.size()):
				g.v.append(rel * vv[k])
				g.n.append((nb * (nn[k] as Vector3)).normalized() if nn != null else Vector3.UP)
				g.uv.append(uu[k] if uu != null else Vector2.ZERO)
			var ii = arr[Mesh.ARRAY_INDEX]
			if ii != null:
				for k in ii:
					g.i.append(base + int(k))
			else:
				for k in range(vv.size()):
					g.i.append(base + k)
		if tolte and mi.get_child_count() > 0:
			mi.mesh = null          # resta come nodo vuoto: i figli (colmo del tetto, telo dello stendardo) si fondono a parte
		elif tolte:
			mi.get_parent().remove_child(mi)
			mi.free()
	for chiave in gruppi:
		var g: Dictionary = gruppi[chiave]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = g.v
		arr[Mesh.ARRAY_NORMAL] = g.n
		arr[Mesh.ARRAY_TEX_UV] = g.uv
		arr[Mesh.ARRAY_INDEX] = g.i
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.name = "Fuso"
		mi.mesh = mesh
		mi.material_override = g.mat
		mi.cast_shadow = g.ombra
		if vista > 0.0:
			mi.visibility_range_end = vista
		radice.add_child(mi)
