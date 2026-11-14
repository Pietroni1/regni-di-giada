class_name Edifici
## Edifici del villaggio costruiti da codice in stile orientale: tetti a falde concave con gli angoli rialzati,
## telaio di legno scuro, intonaco chiaro, basamento di pietra. Sono provvisori ma sostituibili uno a uno
## con modelli fatti in Blender (basta restituire un altro Node3D dalle stesse funzioni).

const INTONACO := Color(0.80, 0.74, 0.62)
const LEGNO := Color(0.20, 0.12, 0.08)
const PIETRA := Color(0.42, 0.40, 0.37)
const ORO := Color(0.85, 0.65, 0.22)

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
static func tetto(w: float, d: float, h: float, sporto: float, colore: Color, rialzo := 0.55) -> MeshInstance3D:
	var W := w + sporto * 2.0
	var D := d + sporto * 2.0
	var n := 28
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
	return mi


## Casa: muri intonacati con telaio di legno, porta sul lato +z, tetto a coppi.
static func casa(w: float, d: float, tetto_col: Color, muro_h := 2.8, tetto_h := 2.4) -> Node3D:
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
	var t := tetto(w, d, tetto_h, 1.25, tetto_col)
	t.position.y = 0.45 + muro_h
	g.add_child(t)
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
		var t := tetto(l, l, 1.5 if piano < 2 else 2.4, 1.5 - 0.2 * piano, tetto_col, 0.8)
		t.position.y = y + hm
		g.add_child(t)
		y += hm + (0.75 if piano < 2 else 2.4)
	cilindro(0.06, 0.16, 2.2, Vector3(0, y + 1.0, 0), mat(ORO, 0.3, 0.9), g, 8)
	for k in range(3):
		cilindro(0.3 - k * 0.07, 0.3 - k * 0.07, 0.07, Vector3(0, y + 0.5 + k * 0.45, 0), mat(ORO, 0.3, 0.9), g, 12)
	return g


## Fucina: casa bassa con camino e bagliore del fuoco.
static func fucina(w: float, d: float, tetto_col: Color) -> Node3D:
	var g := casa(w, d, tetto_col, 2.6, 2.0)
	scatola(Vector3(1.1, 5.6, 1.1), Vector3(w * 0.5 - 1.0, 2.8, -d * 0.5 + 1.0), pietra(PIETRA.darkened(0.2)), g)
	scatola(Vector3(1.6, 0.9, 1.0), Vector3(-w * 0.5 + 1.6, 0.9, d * 0.5 + 1.2), mat(Color(0.12, 0.12, 0.13), 0.5, 0.6), g)   # incudine
	scatola(Vector3(1.2, 0.7, 1.2), Vector3(w * 0.5 - 1.2, 0.8, d * 0.5 + 1.2), mat(Color(1.0, 0.45, 0.1), 0.6, 0.0, 3.0), g)  # braci
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 2.5
	l.omni_range = 9.0
	l.position = Vector3(w * 0.5 - 1.2, 1.8, d * 0.5 + 1.4)
	g.add_child(l)
	return g


## Bancarella del mercato: banco, quattro pali e telo colorato.
static func bancarella(telo: Color) -> Node3D:
	var g := Node3D.new()
	var travi := legno(Color(0.36, 0.24, 0.14))
	scatola(Vector3(4.0, 0.95, 1.4), Vector3(0, 0.48, 0), travi, g)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			scatola(Vector3(0.12, 2.9, 0.12), Vector3(sx * 1.95, 1.45, sz * 0.75), travi, g)
	var t := scatola(Vector3(4.6, 0.08, 2.4), Vector3(0, 2.95, 0.15), mat(telo, 0.9), g)
	t.rotation.x = 0.18
	for i in range(5):
		var c := Color.from_hsv(fmod(0.07 + i * 0.13, 1.0), 0.5, 0.75)
		scatola(Vector3(0.45, 0.3, 0.45), Vector3(-1.5 + i * 0.75, 1.1, 0.1), mat(c, 0.8), g)
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
		l.position = Vector3(0, 1.8, 0)
		g.add_child(l)
	return g


## Tratto di mura: pietra in basso, intonaco e copertura a coppi.
static func tratto_mura(larghezza: float, tetto_col: Color) -> Node3D:
	var g := Node3D.new()
	scatola(Vector3(larghezza, 1.4, 1.5), Vector3(0, 0.7, 0), pietra(PIETRA), g)
	scatola(Vector3(larghezza, 2.6, 1.1), Vector3(0, 2.7, 0), intonaco(INTONACO.darkened(0.08)), g)
	var t := tetto(larghezza + 0.1, 1.2, 0.6, 0.35, tetto_col, 0.0)
	t.position.y = 4.0
	g.add_child(t)
	return g


## Porta del villaggio: due colonne laccate e un tetto sopra l'architrave.
static func porta(luce: float, tetto_col: Color, accento: Color) -> Node3D:
	var g := Node3D.new()
	var lacca := mat(accento.darkened(0.1), 0.45)
	for sx in [-1.0, 1.0]:
		cilindro(0.45, 0.5, 6.4, Vector3(sx * luce * 0.5, 3.2, 0), lacca, g, 12)
		scatola(Vector3(1.3, 0.5, 1.3), Vector3(sx * luce * 0.5, 0.25, 0), pietra(PIETRA), g)
	scatola(Vector3(luce + 2.6, 0.5, 0.6), Vector3(0, 5.6, 0), lacca, g)
	scatola(Vector3(luce + 1.2, 0.36, 0.5), Vector3(0, 4.7, 0), lacca, g)
	scatola(Vector3(2.4, 0.8, 0.14), Vector3(0, 5.15, 0), mat(Color(0.1, 0.08, 0.07), 0.6), g)
	var t := tetto(luce + 2.0, 1.6, 1.3, 1.0, tetto_col, 0.7)
	t.position.y = 6.4
	g.add_child(t)
	return g
