extends RefCounted
## Forme delle armi costruite da codice (nessun asset esterno, tutto originale): lame a sezione esagonale con filo
## e dorso, sagome estruse, tubi curvi, anelli. Ogni funzione riempie un nodo «presa» creato da Equip.impugna:
## origine = centro del pugno, +y = lato del pollice (verso la punta della lama), +z = lato delle dita (direzione
## di un pugno), +x = palmo nella mano destra e dorso della mano nella sinistra. Il filo delle lame sta verso -x.
## Ogni parte che deve accendersi con il potenziamento (lama, filo, incisioni) ha il metadato «accendi».

const ACCENDI := "accendi"

static var _mats: Dictionary = {}
static var _mesh: Dictionary = {}


# ------------------------------------------------------------------ materiali
static func acciaio(c: Color, ruvido := 0.3, vertici := false) -> StandardMaterial3D:
	var k := "a%s%s%s" % [c.to_html(), ruvido, vertici]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.5
	m.roughness = ruvido
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = vertici
	_mats[k] = m
	return m


static func opaco(c: Color, ruvido := 0.8) -> StandardMaterial3D:
	var k := "o%s%s" % [c.to_html(), ruvido]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = ruvido
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[k] = m
	return m


## Parte luminosa (gemme, incisioni): emissione moderata, il bloom fa il resto.
static func luce(c: Color, en := 1.5) -> StandardMaterial3D:
	var k := "l%s%s" % [c.to_html(), en]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = c.darkened(0.25)
	m.roughness = 0.25
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = en
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[k] = m
	return m


# ------------------------------------------------------------------ mattoni
static func _mi(mesh: Mesh, m: Material, gen: Node3D, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gen.add_child(mi)
	return mi


static func cil(r_alto: float, r_basso: float, h: float, pos: Vector3, m: Material, gen: Node3D, rot := Vector3.ZERO, lati := 10) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_alto
	c.bottom_radius = r_basso
	c.height = h
	c.radial_segments = lati
	c.rings = 1
	return _mi(c, m, gen, pos, rot)


static func scatola(dim: Vector3, pos: Vector3, m: Material, gen: Node3D, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = dim
	return _mi(b, m, gen, pos, rot)


static func sfera(r: float, pos: Vector3, m: Material, gen: Node3D, scala := Vector3.ONE, lati := 12) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = lati
	s.rings = maxi(4, lati / 2)
	var mi := _mi(s, m, gen, pos)
	mi.scale = scala
	return mi


## Anello (toro) nel piano XZ, ruotato da rot.
static func anello(r: float, sp: float, m: Material, gen: Node3D, pos: Vector3, rot := Vector3.ZERO, lati := 20) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = r - sp
	t.outer_radius = r + sp
	t.rings = lati
	t.ring_segments = 8
	return _mi(t, m, gen, pos, rot)


## Lama a stazioni [y, x_filo, x_dorso, spessore]: sezione a sei punti (filo, spigoli del dorso piatto, davanti e dietro),
## ombreggiatura piatta e colori dei vertici che schiariscono il filo.
static func lama(st: Array, m: Material, gen: Node3D) -> MeshInstance3D:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	s.set_smooth_group(-1)
	var anelli: Array = []
	for r in st:
		var y: float = r[0]
		var xl: float = r[1]
		var xr: float = r[2]
		var h: float = r[3]
		var xa := lerpf(xl, xr, 0.36)
		var xb := lerpf(xl, xr, 0.64)
		anelli.append([Vector3(xl, y, 0), Vector3(xa, y, h), Vector3(xb, y, h), Vector3(xr, y, 0), Vector3(xb, y, -h), Vector3(xa, y, -h)])
	var col := [Color(1, 1, 1), Color(0.8, 0.8, 0.82), Color(0.8, 0.8, 0.82), Color(0.62, 0.62, 0.66), Color(0.8, 0.8, 0.82), Color(0.8, 0.8, 0.82)]
	for k in range(anelli.size() - 1):
		var r0: Array = anelli[k]
		var r1: Array = anelli[k + 1]
		for j in range(6):
			var j2 := (j + 1) % 6
			for v in [[r0[j], col[j]], [r0[j2], col[j2]], [r1[j2], col[j2]], [r0[j], col[j]], [r1[j2], col[j2]], [r1[j], col[j]]]:
				s.set_color(v[1])
				s.add_vertex(v[0])
	s.generate_normals()
	var mi := _mi(s.commit(), m, gen)
	mi.set_meta(ACCENDI, true)
	return mi


## Profilo di una lama: l'ultimo tratto si stringe in punta. denti = [[t, lunghezza_t, altezza]] sul dorso (uncini rivolti
## all'elsa); onda = ampiezza di un'ondulazione (lame serpentine); filo_denti = come denti ma sul filo.
static func profilo(y0: float, lunga: float, w0: float, w1: float, curva: float, h: float, punta := 0.14, denti := [], onda := 0.0, onde := 0.0, filo_denti := []) -> Array:
	var ys: Array = []
	var n := 14
	for i in range(n + 1):
		ys.append(y0 + lunga * float(i) / n)
	for d in denti + filo_denti:
		ys.append(y0 + lunga * d[0] - 0.0004)
		ys.append(y0 + lunga * d[0])
		ys.append(y0 + lunga * (d[0] + d[1]))
	ys.sort()
	var out: Array = []
	for y in ys:
		var t := clampf((y - y0) / lunga, 0.0, 1.0)
		var w := lerpf(w0, w1, smoothstep(0.0, 1.0, t))
		var fp := clampf((t - (1.0 - punta)) / punta, 0.0, 1.0)
		w *= 1.0 - pow(fp, 1.6)
		var cx := curva * t * t + onda * sin(t * TAU * onde) * (1.0 - fp)
		var dorso := 0.0
		for d in denti:
			var u: float = (t - d[0]) / d[1]
			if u >= 0.0 and u < 1.0:
				dorso += d[2] * (1.0 - u)
		var filo := 0.0
		for d in filo_denti:
			var u: float = (t - d[0]) / d[1]
			if u >= 0.0 and u < 1.0:
				filo += d[2] * (1.0 - u)
		var hh := h * (1.0 - 0.4 * t) * (1.0 - pow(fp, 2.2))
		out.append([y, cx - w * 0.5 - filo, cx + w * 0.5 + dorso, hh])
	return out


## Sagoma estrusa: poligono nel piano xy, spessore lungo z (centrato).
static func estrudi(poly: PackedVector2Array, spess: float, m: Material, gen: Node3D, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var area := 0.0
	for i in range(poly.size()):
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		area += a.x * b.y - b.x * a.y
	if area < 0.0:
		poly.reverse()
	var tri := Geometry2D.triangulate_polygon(poly)
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	s.set_smooth_group(-1)
	var z := spess * 0.5
	for i in range(0, tri.size(), 3):
		for k in range(3):
			var p := poly[tri[i + k]]
			s.add_vertex(Vector3(p.x, p.y, z))
		for k in [2, 1, 0]:
			var p := poly[tri[i + k]]
			s.add_vertex(Vector3(p.x, p.y, -z))
	for i in range(poly.size()):
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		for v in [Vector3(a.x, a.y, z), Vector3(a.x, a.y, -z), Vector3(b.x, b.y, -z), Vector3(a.x, a.y, z), Vector3(b.x, b.y, -z), Vector3(b.x, b.y, z)]:
			s.add_vertex(v)
	s.generate_normals()
	return _mi(s.commit(), m, gen, pos, rot)


## Tubo curvo che segue una spezzata, con raggio variabile (rag = raggi nei punti); chiuso a un capo se il raggio lo permette.
static func tubo(pt: Array, rag: Array, m: Material, gen: Node3D, lati := 7, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var n := pt.size()
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var anelli: Array = []
	var nor: Array = []
	var prec := Vector3.ZERO
	for i in range(n):
		var a: Vector3 = pt[maxi(i - 1, 0)]
		var b: Vector3 = pt[mini(i + 1, n - 1)]
		var t := (b - a).normalized()
		var nn: Vector3
		if i == 0:
			nn = t.cross(Vector3.FORWARD if absf(t.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		else:
			nn = (prec - t * prec.dot(t)).normalized()
		prec = nn
		var bi := t.cross(nn)
		var r: Array = []
		var rn: Array = []
		for j in range(lati):
			var an := TAU * float(j) / lati
			var d := nn * cos(an) + bi * sin(an)
			rn.append(d)
			r.append((pt[i] as Vector3) + d * float(rag[i]))
		anelli.append(r)
		nor.append(rn)
	for i in range(n - 1):
		for j in range(lati):
			var j2 := (j + 1) % lati
			var q := [[i, j], [i, j2], [i + 1, j2], [i, j], [i + 1, j2], [i + 1, j]]
			for e in q:
				s.set_normal(nor[e[0]][e[1]])
				s.add_vertex(anelli[e[0]][e[1]])
	for capo in [0, n - 1]:
		if float(rag[capo]) < 0.003:
			continue
		var cen: Vector3 = pt[capo]
		var verso := -1.0 if capo == 0 else 1.0
		var tt := ((pt[mini(capo + 1, n - 1)] as Vector3) - (pt[maxi(capo - 1, 0)] as Vector3)).normalized() * verso
		for j in range(lati):
			var j2 := (j + 1) % lati
			s.set_normal(tt)
			s.add_vertex(cen)
			if capo == 0:
				s.set_normal(tt)
				s.add_vertex(anelli[capo][j2])
				s.set_normal(tt)
				s.add_vertex(anelli[capo][j])
			else:
				s.set_normal(tt)
				s.add_vertex(anelli[capo][j])
				s.set_normal(tt)
				s.add_vertex(anelli[capo][j2])
	return _mi(s.commit(), m, gen, pos, rot)


## Foglia/penna allungata nel piano xy, dall'origine verso +x (poi ruotata da rot).
static func foglia(lung: float, larg: float, m: Material, gen: Node3D, pos := Vector3.ZERO, rot := Vector3.ZERO, spess := 0.012) -> MeshInstance3D:
	var p := PackedVector2Array([Vector2(0, -larg * 0.35), Vector2(lung * 0.4, -larg), Vector2(lung * 0.85, -larg * 0.45), Vector2(lung, 0), Vector2(lung * 0.55, larg * 0.55), Vector2(lung * 0.1, larg * 0.3)])
	return estrudi(p, spess, m, gen, pos, rot)


## Mezzaluna (arco fra due cerchi) centrata nell'origine, aperta verso +y se a0..a1 sta sotto l'orizzontale.
static func mezzaluna(re: float, ri: float, a0: float, a1: float, passi := 10) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in range(passi + 1):
		var a := deg_to_rad(lerpf(a0, a1, float(i) / passi))
		p.append(Vector2(cos(a), sin(a)) * re)
	for i in range(passi, -1, -1):
		var a := deg_to_rad(lerpf(a0, a1, float(i) / passi))
		var rr := ri
		p.append(Vector2(cos(a), sin(a)) * rr)
	return p


static func _lega(y0: float, y1: float, r: float, m: Material, gen: Node3D) -> void:
	# fasce dell'impugnatura: anelli sottili ogni 4,5 cm
	var y := y0 + 0.02
	while y < y1 - 0.01:
		cil(r * 1.12, r * 1.12, 0.014, Vector3(0, y, 0), m, gen)
		y += 0.045


## Incisioni luminose a trattini lungo la lama (centro, entrambe le facce).
static func _incisioni(y0: float, y1: float, h: float, n: int, m: Material, gen: Node3D, x := 0.0) -> void:
	for i in range(n):
		var t := float(i) / maxf(1.0, n - 1.0)
		var y := lerpf(y0, y1, t)
		var spess := h * (1.0 - 0.4 * clampf((y - y0) / maxf(0.01, y1 - y0 + 0.2), 0.0, 1.0))
		for lato in [1.0, -1.0]:
			var tr := scatola(Vector3(0.016, 0.05 if i % 2 == 0 else 0.028, 0.004), Vector3(x, y, lato * (spess + 0.001)), m, gen)
			tr.set_meta(ACCENDI, true)


# ================================================================== SPADA (Lama)
## Gradi: 1 spada larga di ferro · 2 sciabola di bronzo con guardia a mezzaluna · 3 spada di giada a due mani con
## guardia cornuta e uncini sul dorso · 4 «Cento Gru»: lama enorme, guardia ad ali di gru, incisioni luminose.
static func spada(a: Node3D, g: int) -> void:
	var lame := [Color(0.7, 0.72, 0.76), Color(0.8, 0.6, 0.3), Color(0.52, 0.84, 0.68), Color(0.88, 0.92, 0.98)]
	var guardie := [Color(0.28, 0.28, 0.32), Color(0.55, 0.37, 0.17), Color(0.92, 0.72, 0.3), Color(0.96, 0.76, 0.32)]
	var fasce := [Color(0.3, 0.16, 0.1), Color(0.48, 0.1, 0.08), Color(0.08, 0.08, 0.1), Color(0.1, 0.05, 0.08)]
	var mlama := acciaio(lame[g - 1], 0.26 - 0.02 * g, true)
	var mgu := acciaio(guardie[g - 1], 0.3)
	var mgr := opaco(fasce[g - 1], 0.85)
	var mcorda := opaco(fasce[g - 1].lightened(0.22), 0.8)
	var gem: Color = [Color(0.9, 0.5, 0.2), Color(1.0, 0.45, 0.15), Color(0.3, 1.0, 0.65), Color(1.0, 0.2, 0.2)][g - 1]
	var yg := 0.085                                            # la guardia sta subito oltre l'indice
	var coda := -0.15 if g < 3 else -0.34                      # a due mani da g3: impugnatura lunga
	cil(0.027, 0.027, yg - coda, Vector3(0, (yg + coda) * 0.5, 0), mgr, a)
	_lega(coda, yg, 0.027, mcorda, a)
	var lunga: float = [1.0, 1.16, 1.34, 1.52][g - 1]
	var w0: float = [0.085, 0.085, 0.105, 0.125][g - 1]
	var w1: float = [0.085, 0.115, 0.145, 0.175][g - 1]
	var curva: float = [0.0, 0.1, 0.06, 0.09][g - 1]
	var h: float = [0.010, 0.012, 0.014, 0.016][g - 1]
	var denti: Array = []
	if g == 2:
		denti = [[0.8, 0.08, 0.03]]                                 # falsa lama: un dente vicino alla punta
	elif g == 3:
		denti = [[0.32, 0.09, 0.034], [0.5, 0.09, 0.038], [0.68, 0.085, 0.034]]
	elif g == 4:
		denti = [[0.2, 0.1, 0.04], [0.36, 0.1, 0.046], [0.52, 0.095, 0.05], [0.68, 0.09, 0.046]]
	var fd: Array = [[0.46, 0.06, 0.02], [0.62, 0.06, 0.022]] if g == 4 else []
	var pf := profilo(yg - 0.01, lunga, w0, w1, curva, h, 0.15, denti, 0.0, 0.0, fd)
	lama(pf, mlama, a)
	# guardia
	match g:
		1:
			scatola(Vector3(0.3, 0.036, 0.055), Vector3(0, yg, 0), mgu, a)
			for s in [-1.0, 1.0]:
				scatola(Vector3(0.06, 0.03, 0.05), Vector3(s * 0.165, yg - 0.018, 0), mgu, a, Vector3(0, 0, s * 0.5))
			cil(0.034, 0.03, 0.05, Vector3(0, yg, 0), mgu, a)
			sfera(0.036, Vector3(0, coda - 0.02, 0), mgu, a)
		2:
			estrudi(mezzaluna(0.19, 0.145, -165, -15), 0.05, mgu, a, Vector3(0, yg + 0.145 + 0.02, 0))
			cil(0.034, 0.03, 0.05, Vector3(0, yg, 0), mgu, a)
			sfera(0.04, Vector3(0, coda - 0.02, 0), mgu, a, Vector3(1, 1.15, 1))
			anello(0.04, 0.008, mgu, a, Vector3(0, coda - 0.075, 0), Vector3(PI / 2, 0, 0))
		3:
			estrudi(mezzaluna(0.2, 0.15, -170, -10), 0.05, mgu, a, Vector3(0, yg + 0.15 + 0.02, 0))
			for s in [-1.0, 1.0]:                       # corna che salgono lungo la lama
				tubo([Vector3(s * 0.15, yg + 0.07, 0), Vector3(s * 0.2, yg + 0.14, 0), Vector3(s * 0.19, yg + 0.24, 0), Vector3(s * 0.14, yg + 0.33, 0)], [0.022, 0.018, 0.012, 0.002], mgu, a)
			sfera(0.026, Vector3(0, yg + 0.045, 0.034), luce(gem, 1.4), a)
			cil(0.034, 0.03, 0.05, Vector3(0, yg, 0), mgu, a)
			anello(0.055, 0.009, mgu, a, Vector3(0, coda - 0.06, 0), Vector3(PI / 2, 0, 0))
			cil(0.012, 0.012, 0.2, Vector3(0, coda - 0.18, 0.0), opaco(Color(0.7, 0.12, 0.1)), a)           # nappa rossa
		4:
			# ali di gru: due ordini di penne per lato, quelle di sopra lunghe e rivolte alla punta, quelle di sotto corte
			for s in [-1.0, 1.0]:
				for k in range(3):
					var ang := deg_to_rad(10.0 + k * 24.0)
					var lung := 0.21 - 0.045 * k
					foglia(lung, 0.04 - 0.004 * k, mgu, a, Vector3(s * 0.035, yg + 0.015, 0), Vector3(0, 0, ang if s > 0 else PI - ang), 0.014)
				for k in range(2):
					var ang := deg_to_rad(-14.0 - k * 22.0)
					foglia(0.12 - 0.03 * k, 0.028, mgu, a, Vector3(s * 0.035, yg + 0.005, 0), Vector3(0, 0, ang if s > 0 else PI - ang), 0.012)
			estrudi(mezzaluna(0.115, 0.07, -175, -5), 0.06, mgu, a, Vector3(0, yg + 0.07, 0))
			cil(0.04, 0.036, 0.06, Vector3(0, yg, 0), mgu, a)
			sfera(0.034, Vector3(0, yg + 0.025, 0.045), luce(gem, 1.2), a, Vector3(1, 1.3, 0.8))
			sfera(0.034, Vector3(0, yg + 0.025, -0.045), luce(gem, 1.2), a, Vector3(1, 1.3, 0.8))
			# pomolo ad artiglio che stringe una gemma
			sfera(0.04, Vector3(0, coda - 0.03, 0), luce(gem, 1.6), a)
			for k in range(3):
				var an := k * TAU / 3.0
				tubo([Vector3(cos(an) * 0.05, coda + 0.03, sin(an) * 0.05), Vector3(cos(an) * 0.07, coda - 0.04, sin(an) * 0.07), Vector3(cos(an) * 0.03, coda - 0.11, sin(an) * 0.03)], [0.014, 0.011, 0.002], mgu, a, 6)
			_incisioni(yg + 0.16, yg + lunga * 0.78, h, 7, luce(gem.lightened(0.15), 1.7), a, 0.0)
	a.set_meta("lama", [Vector3(0, yg + 0.12, 0), Vector3(curva, yg - 0.01 + lunga, 0)])
	a.set_meta("largo", 0.4 + 0.08 * g)


# ================================================================== PUGNALI (Ombra)
## Gradi: 1 zanna d'osso · 2 acciaio con dente · 3 lama serpentina con testa di serpe · 4 lama d'eclissi scura
## con filo luminoso e guardia a falce di luna. `sinistra`: lama specchiata.
static func pugnale(a: Node3D, g: int) -> void:
	var lame := [Color(0.9, 0.86, 0.76), Color(0.74, 0.76, 0.8), Color(0.5, 0.72, 0.5), Color(0.2, 0.16, 0.3)]
	var mlama := acciaio(lame[g - 1], 0.28 if g != 1 else 0.55, true)
	if g == 1:
		mlama = opaco(lame[0], 0.55)
		mlama = _osso()
	var mgu := acciaio([Color(0.35, 0.3, 0.22), Color(0.3, 0.3, 0.34), Color(0.9, 0.72, 0.3), Color(0.9, 0.8, 0.55)][g - 1], 0.3)
	var mgr := opaco([Color(0.5, 0.12, 0.1), Color(0.1, 0.1, 0.12), Color(0.1, 0.16, 0.1), Color(0.08, 0.06, 0.1)][g - 1], 0.85)
	var gem: Color = [Color(0.9, 0.5, 0.2), Color(1.0, 0.5, 0.2), Color(0.5, 1.0, 0.3), Color(0.75, 0.45, 1.0)][g - 1]
	var yg := 0.07
	var coda := -0.1
	cil(0.021, 0.021, yg - coda, Vector3(0, (yg + coda) * 0.5, 0), mgr, a)
	_lega(coda, yg, 0.021, opaco(Color(0.85, 0.8, 0.7)), a)
	var lunga: float = [0.38, 0.44, 0.5, 0.54][g - 1]
	var w0: float = [0.06, 0.065, 0.06, 0.075][g - 1]
	var w1: float = [0.07, 0.085, 0.075, 0.115][g - 1]
	var curva: float = [0.07, 0.04, 0.0, 0.11][g - 1]
	var denti: Array = []
	var onda := 0.0
	var onde := 0.0
	if g == 2:
		denti = [[0.35, 0.16, 0.03], [0.58, 0.14, 0.03]]
	if g == 3:
		onda = 0.017
		onde = 2.5
	var pf := profilo(yg - 0.01, lunga, w0, w1, curva, 0.009 + 0.001 * g, 0.2, denti, onda, onde)
	lama(pf, mlama, a)
	var gemm := luce(gem, 1.6)
	match g:
		1:
			scatola(Vector3(0.12, 0.024, 0.04), Vector3(0, yg, 0), mgu, a)
			anello(0.03, 0.007, mgu, a, Vector3(0, coda - 0.02, 0), Vector3(PI / 2, 0, 0))
		2:
			scatola(Vector3(0.15, 0.028, 0.045), Vector3(0.0, yg, 0), mgu, a)
			sfera(0.03, Vector3(0, coda - 0.015, 0), mgu, a)
		3:
			# testa di serpe sull'elsa: cranio, occhi, zanne
			sfera(0.04, Vector3(0, yg + 0.005, 0), mgu, a, Vector3(1.5, 0.75, 1.0))
			for s in [-1.0, 1.0]:
				sfera(0.01, Vector3(s * 0.03, yg + 0.02, 0.025), gemm, a)
				tubo([Vector3(s * 0.022, yg + 0.005, -0.02), Vector3(s * 0.03, yg - 0.045, -0.025)], [0.007, 0.001], opaco(Color(0.95, 0.95, 0.85)), a, 5)
			sfera(0.028, Vector3(0, coda - 0.02, 0), mgu, a)
		4:
			estrudi(mezzaluna(0.1, 0.065, -170, -10), 0.04, mgu, a, Vector3(0, yg + 0.065 + 0.01, 0))
			cil(0.03, 0.026, 0.035, Vector3(0, yg, 0), mgu, a)
			sfera(0.022, Vector3(0, yg + 0.012, 0.027), luce(gem, 1.7), a)
			sfera(0.03, Vector3(0, coda - 0.02, 0), mgu, a)
			# filo luminoso: una sottile lista lungo il filo
			var fl := profilo(yg + 0.04, lunga - 0.05, 0.012, 0.012, curva * 0.93, 0.002, 0.05)
			for r in fl:
				var t := clampf((float(r[0]) - (yg - 0.01)) / lunga, 0.0, 1.0)
				var wl := lerpf(w0, w1, smoothstep(0.0, 1.0, t)) * 0.5
				r[1] = curva * t * t - wl - 0.004
				r[2] = curva * t * t - wl + 0.012
			var l := lama(fl, luce(Color(0.78, 0.55, 1.0), 2.0), a)
			l.set_meta(ACCENDI, true)
	a.set_meta("lama", [Vector3(0, yg + 0.06, 0), Vector3(curva, yg + lunga - 0.02, 0)])
	a.set_meta("largo", 0.28)


static func _osso() -> StandardMaterial3D:
	return opaco(Color(0.9, 0.86, 0.74), 0.5)


# ================================================================== ARCO (Ombra)
## Telaio: limbi lungo y, punte verso -z (verso l'arciere), pancia verso +z. Gradi: 1 bambù · 2 corno con puntali
## d'osso · 3 airone con ali piumate e punte a lama · 4 vento d'autunno: ali, foglie e lame alle estremità.
## Restituisce i punti d'incocco [alto, basso] per la corda.
static func arco(a: Node3D, g: int) -> Array:
	var legni := [Color(0.62, 0.55, 0.22), Color(0.2, 0.1, 0.07), Color(0.93, 0.92, 0.86), Color(0.55, 0.14, 0.1)]
	var mleg := opaco(legni[g - 1], 0.45)
	var mor := acciaio([Color(0.5, 0.4, 0.2), Color(0.9, 0.86, 0.74), Color(0.92, 0.72, 0.3), Color(0.95, 0.78, 0.35)][g - 1], 0.3)
	var gem: Color = [Color(0.9, 0.6, 0.2), Color(1.0, 0.5, 0.2), Color(0.5, 0.85, 1.0), Color(1.0, 0.45, 0.1)][g - 1]
	var L: float = [0.86, 0.92, 0.98, 1.04][g - 1]
	var c: float = [0.3, 0.32, 0.34, 0.36][g - 1]
	var rec: float = [0.05, 0.08, 0.1, 0.12][g - 1]
	var tips: Array = []
	for s in [1.0, -1.0]:
		var pts: Array = []
		var rag: Array = []
		for k in range(13):
			var t := float(k) / 12.0
			var y: float = s * (0.07 + (L - 0.07) * t)
			var z: float = -c * pow(t, 2.1) + rec * pow(smoothstep(0.7, 1.0, t), 1.5)
			pts.append(Vector3(0, y, z))
			rag.append(lerpf(0.026, 0.011, t))
		tubo(pts, rag, mleg, a, 7)
		var tip: Vector3 = pts[12]
		tips.append(tip + Vector3(0, 0, 0))
		# puntale
		match g:
			1:
				sfera(0.014, tip, mor, a)
			2:
				cil(0.006, 0.016, 0.07, tip + Vector3(0, s * 0.03, 0.0), mor, a, Vector3(s * 0.3, 0, 0), 7)
			3:
				tubo([tip, tip + Vector3(0, s * 0.05, 0.05), tip + Vector3(0, s * 0.09, 0.14)], [0.014, 0.01, 0.002], mor, a, 6)
			4:
				tubo([tip, tip + Vector3(0, s * 0.06, 0.04), tip + Vector3(0, s * 0.12, 0.16)], [0.016, 0.011, 0.002], mor, a, 6)
		# ali: penne che escono di lato dai flettenti, a ventaglio verso la punta
		if g >= 3:
			var mpenna := mleg if g == 3 else mor
			var npenne := 3 if g == 3 else 4
			for k in range(npenne):
				var tt := 0.22 + 0.1 * k
				var p0 := Vector3(0, s * (0.07 + (L - 0.07) * tt), -c * pow(tt, 2.1))
				var lung := (0.26 - 0.04 * k) * (1.0 if g == 3 else 1.2)
				for lx in [1.0, -1.0]:
					var ang := deg_to_rad(48.0 + 11.0 * k)
					var rz: float = ang * s if lx > 0 else PI - ang * s
					var pe := foglia(lung, 0.032 if g == 3 else 0.036, mpenna, a, p0, Vector3(0, 0, rz), 0.01)
					if g == 4:
						pe.position.z += 0.0
	# impugnatura
	cil(0.031, 0.031, 0.24, Vector3.ZERO, opaco(Color(0.1, 0.07, 0.07)), a)
	_lega(-0.12, 0.12, 0.031, opaco(Color(0.85, 0.8, 0.68)), a)
	if g >= 2:
		sfera(0.03, Vector3(0, 0.0, 0.035), luce(gem, 1.5), a, Vector3(0.8, 1.3, 0.8))
	# poggiafrecce
	scatola(Vector3(0.016, 0.03, 0.03), Vector3(0.025, 0.07, 0.01), mor, a)
	a.set_meta("lama", [Vector3(0, -L * 0.8, -c * 0.4), Vector3(0, L * 0.8, -c * 0.4)])
	a.set_meta("largo", 0.5)
	return tips


# ================================================================== PUGNI (Monaco)
## Su ogni mano. Gradi: 1 bende di seta · 2 tirapugni e artigli di ferro · 3 guanti d'arme della Tigre Bianca con
## borchie e grossi artigli · 4 guanti del Sole con dischi dorati. lato: +1 destra, -1 sinistra.
static func pugni(a: Node3D, g: int, lato: float) -> void:
	var seta := opaco([Color(0.9, 0.85, 0.75), Color(0.6, 0.6, 0.64), Color(0.9, 0.9, 0.92), Color(0.9, 0.7, 0.25)][g - 1], 0.7)
	var ferro := acciaio([Color(0.55, 0.55, 0.58), Color(0.5, 0.5, 0.55), Color(0.82, 0.84, 0.88), Color(0.95, 0.75, 0.3)][g - 1], 0.3)
	var scuro := acciaio(Color(0.16, 0.16, 0.2), 0.4)
	var osso := _osso()
	var rosso := opaco(Color(0.6, 0.1, 0.1), 0.7)
	var sole := luce(Color(1.0, 0.75, 0.25), 1.5)
	var rz := Vector3(PI / 2, 0, 0)                       # cilindri lungo z (l'avambraccio)
	if g == 1:
		# bende: spire sul polso e sulla mano, con un nastro rosso e code
		for i in range(6):
			cil(0.058, 0.058, 0.03, Vector3(0, 0, -0.17 + i * 0.04), seta, a, rz, 12)
		cil(0.064, 0.064, 0.05, Vector3(0, 0, 0.005), seta, a, rz, 12)
		cil(0.066, 0.066, 0.012, Vector3(0, 0, -0.09), rosso, a, rz, 12)
		for k in range(2):
			scatola(Vector3(0.012, 0.012, 0.22), Vector3(-0.03 * lato + k * 0.025 * lato, -0.06 - k * 0.02, -0.28), rosso, a, Vector3(0.2, 0, 0))
	else:
		# bracciale sull'avambraccio
		cil(0.07, 0.065, 0.16, Vector3(0, 0, -0.2), ferro if g != 2 else scuro, a, rz, 12)
		cil(0.074, 0.074, 0.02, Vector3(0, 0, -0.28), ferro, a, rz, 12)
		cil(0.074, 0.074, 0.02, Vector3(0, 0, -0.12), ferro, a, rz, 12)
		# piastra sul dorso della mano
		scatola(Vector3(0.026, 0.1, 0.12), Vector3(-0.065 * lato, 0.0, -0.02), ferro if g != 2 else scuro, a)
		# fascia sulle nocche (davanti al pugno)
		scatola(Vector3(0.1, 0.12, 0.03), Vector3(0.0, 0.0, 0.055), ferro, a)
		for i in range(4):
			sfera(0.016, Vector3(lerpf(-0.04, 0.04, i / 3.0) * 0.0 - 0.0, lerpf(-0.045, 0.045, i / 3.0), 0.075), ferro, a)
	match g:
		2:
			# tre artigli di ferro dalle nocche, in avanti e leggermente curvi
			for i in range(3):
				var y := lerpf(-0.04, 0.04, i / 2.0)
				tubo([Vector3(0, y, 0.06), Vector3(-0.01 * lato, y, 0.14), Vector3(-0.03 * lato, y, 0.24), Vector3(-0.07 * lato, y, 0.31)], [0.013, 0.011, 0.008, 0.001], ferro, a, 6)
		3:
			# grandi artigli bianchi dalle nocche (4), borchie sul dorso e sulle fasce
			for i in range(4):
				var y := lerpf(-0.055, 0.055, i / 3.0)
				tubo([Vector3(0, y, 0.06), Vector3(-0.02 * lato, y, 0.17), Vector3(-0.05 * lato, y, 0.3), Vector3(-0.1 * lato, y, 0.4)], [0.017, 0.014, 0.009, 0.001], osso, a, 6)
			for i in range(3):
				for j in range(2):
					sfera(0.012, Vector3(-0.081 * lato, lerpf(-0.03, 0.03, j), lerpf(-0.07, 0.03, i / 2.0)), ferro, a)
			# strisce scure da tigre sul bracciale
			for i in range(3):
				cil(0.0725, 0.0725, 0.012, Vector3(0, 0, -0.17 - i * 0.035), scuro, a, rz, 12)
			# zanna sul dorso della mano
			cil(0.0, 0.025, 0.08, Vector3(-0.09 * lato, 0, 0.04), osso, a, Vector3(PI / 2, 0, 0), 6)
		4:
			# disco del sole sul dorso della mano, con raggi, e un secondo disco più piccolo sul bracciale
			var d := cil(0.1, 0.1, 0.022, Vector3(-0.095 * lato, 0, -0.03), ferro, a, Vector3(0, 0, PI / 2), 20)
			cil(0.06, 0.06, 0.03, Vector3(-0.098 * lato, 0, -0.03), sole, a, Vector3(0, 0, PI / 2), 16)
			for i in range(12):
				var an := i * TAU / 12.0
				var raggio := foglia(0.07, 0.014, ferro, a, Vector3(-0.1 * lato, 0, -0.03), Vector3(an, PI / 2 if lato > 0 else -PI / 2, 0))
			cil(0.045, 0.045, 0.02, Vector3(-0.088 * lato, 0, -0.16), ferro, a, Vector3(0, 0, PI / 2), 16)
			cil(0.026, 0.026, 0.024, Vector3(-0.092 * lato, 0, -0.16), sole, a, Vector3(0, 0, PI / 2), 12)
			# artigli dorati corti
			for i in range(4):
				var y := lerpf(-0.055, 0.055, i / 3.0)
				tubo([Vector3(0, y, 0.06), Vector3(-0.01 * lato, y, 0.15), Vector3(-0.035 * lato, y, 0.24)], [0.016, 0.012, 0.001], ferro, a, 6)
	a.set_meta("lama", [Vector3(0, 0, 0.08), Vector3(-0.05 * lato, 0, 0.3)])
	a.set_meta("largo", 0.3)


# ================================================================== BASTONE (Mistico)
## Bastone poggiato a terra: l'origine è il pugno, il puntale sta a y = -base. Gradi: 1 salice con testa ricurva ·
## 2 pruno con mezzaluna e sfera · 3 cielo limpido con anello e sfera · 4 mille nubi: corona d'oro con riccioli di nube
## e gemma sospesa che ruota lentamente. Restituisce il nodo della gemma/sfera da animare (o null).
static func bastone(a: Node3D, g: int, base := 1.0) -> Node3D:
	var legni := [Color(0.5, 0.36, 0.19), Color(0.4, 0.19, 0.15), Color(0.45, 0.3, 0.17), Color(0.3, 0.15, 0.17)]
	var mleg := opaco(legni[g - 1], 0.55)
	var mor := acciaio([Color(0.5, 0.4, 0.22), Color(0.8, 0.65, 0.3), Color(0.55, 0.85, 0.7), Color(0.95, 0.76, 0.32)][g - 1], 0.28)
	var colori := [Color(1.0, 0.9, 0.55), Color(1.0, 0.6, 0.78), Color(0.45, 0.95, 0.85), Color(0.7, 0.55, 1.0)]
	var mgem := luce(colori[g - 1], 1.0)
	var alt: float = [2.15, 2.4, 2.65, 2.95][g - 1]               # lunghezza totale
	var cima: float = alt - base
	var r: float = [0.022, 0.024, 0.026, 0.03][g - 1]
	# asta
	cil(r, r * 1.12, alt - 0.1, Vector3(0, (cima - base) * 0.5 - 0.0 + 0.0, 0), mleg, a, Vector3.ZERO, 10)
	cil(r * 1.4, r * 1.4, 0.22, Vector3(0, 0, 0), opaco(Color(0.12, 0.09, 0.09), 0.85), a)                 # fasciatura della presa
	_lega(-0.1, 0.1, r * 1.4, opaco(Color(0.85, 0.78, 0.6)), a)
	# puntale
	cil(r * 1.1, 0.0, 0.14, Vector3(0, -base - 0.04, 0), mor, a)
	cil(r * 1.5, r * 1.5, 0.025, Vector3(0, -base + 0.08, 0), mor, a)
	var anim: Node3D = null
	var centro := Vector3(0, cima, 0)
	match g:
		1:
			# testa ricurva a ricciolo con una piccola perla
			var pts: Array = []
			var rag: Array = []
			for k in range(11):
				var t := float(k) / 10.0
				pts.append(centro + Vector3(0, 0.02 + sin(t * 2.6) * 0.1, -0.1 + cos(t * 2.6) * 0.1 - 0.0))
				rag.append(lerpf(r, 0.008, t))
			tubo(pts, rag, mleg, a, 7)
			sfera(0.04, centro + Vector3(0, 0.08, 0.0), mgem, a)
			for i in range(3):
				cil(r * 1.45, r * 1.45, 0.02, Vector3(0, cima - 0.05 - i * 0.07, 0), mor, a)
			anim = a.get_child(a.get_child_count() - 4) as Node3D
		2:
			# mezzaluna aperta verso l'alto che culla una sfera rosata
			estrudi(mezzaluna(0.17, 0.125, -200, 20, 14), 0.04, mor, a, centro + Vector3(0, 0.2, 0))
			cil(r * 1.4, r * 1.2, 0.08, centro + Vector3(0, 0.0, 0), mor, a)
			anim = sfera(0.07, centro + Vector3(0, 0.17, 0), mgem, a)
			for i in range(3):
				cil(r * 1.45, r * 1.45, 0.02, Vector3(0, cima - 0.12 - i * 0.07, 0), mor, a)
		3:
			# anello verticale con sfera fluttuante e due anelli minori, nappe di giada
			anello(0.19, 0.016, mor, a, centro + Vector3(0, 0.27, 0), Vector3(PI / 2, 0, 0), 28)
			anello(0.12, 0.01, mor, a, centro + Vector3(0, 0.27, 0), Vector3(PI / 2, 0, PI / 2), 22)
			cil(r * 1.5, r * 1.1, 0.12, centro + Vector3(0, 0.02, 0), mor, a)
			for s in [-1.0, 1.0]:
				tubo([centro + Vector3(s * 0.02, 0.05, 0), centro + Vector3(s * 0.12, 0.1, 0), centro + Vector3(s * 0.19, 0.2, 0)], [0.014, 0.012, 0.008], mor, a, 6)
			anim = sfera(0.075, centro + Vector3(0, 0.27, 0), mgem, a)
			for i in range(3):
				cil(r * 1.5, r * 1.5, 0.022, Vector3(0, cima - 0.1 - i * 0.08, 0), mor, a)
			for i in range(2):
				cil(0.012, 0.004, 0.2, Vector3(0.04 * (i * 2 - 1), cima - 0.35, 0.03), opaco(Color(0.2, 0.7, 0.6)), a)
		4:
			# corona d'oro: cinque riccioli di nube attorno a una gemma sospesa; dietro, un disco di rune
			cil(r * 1.7, r * 1.2, 0.14, centro + Vector3(0, 0.01, 0), mor, a)
			for k in range(5):
				var an := k * TAU / 5.0
				var dx := cos(an)
				var dz := sin(an)
				var pts: Array = []
				var rag: Array = []
				for q in range(9):
					var t := float(q) / 8.0
					var rr := 0.05 + 0.15 * sin(t * 1.5) * 1.0
					pts.append(centro + Vector3(dx * (0.04 + 0.16 * t * (1.0 - 0.25 * t)), 0.08 + 0.42 * t - 0.0, dz * (0.04 + 0.16 * t * (1.0 - 0.25 * t))) + Vector3(-dz, 0, dx) * sin(t * 3.0) * 0.03)
					rag.append(lerpf(0.02, 0.006, t))
				tubo(pts, rag, mor, a, 6)
				# ricciolo di nube alla punta
				var pc := centro + Vector3(dx * 0.19, 0.5, dz * 0.19)
				anello(0.032, 0.008, mor, a, pc, Vector3(PI / 2 if k % 2 == 0 else 0.0, 0, 0), 14)
			var pivot := Node3D.new()
			pivot.position = centro + Vector3(0, 0.3, 0)
			a.add_child(pivot)
			var gm := sfera(0.09, Vector3.ZERO, mgem, pivot, Vector3(1, 1.4, 1), 14)
			anello(0.13, 0.006, mgem, pivot, Vector3.ZERO, Vector3(0.5, 0, 0.3), 24)
			anello(0.15, 0.005, mgem, pivot, Vector3.ZERO, Vector3(-0.4, 0, -0.5), 24)
			anim = pivot
			gm.set_meta(ACCENDI, true)
			for i in range(4):
				cil(r * 1.6, r * 1.6, 0.02, Vector3(0, cima - 0.14 - i * 0.07, 0), mor, a)
			for i in range(2):
				cil(0.012, 0.004, 0.32, Vector3(0.035 * (i * 2 - 1), cima - 0.45, 0.03), opaco(Color(0.7, 0.1, 0.12)), a)
	a.set_meta("lama", [Vector3(0, cima - 0.05, 0), Vector3(0, cima + 0.4, 0)])
	a.set_meta("largo", 0.6)
	return anim
