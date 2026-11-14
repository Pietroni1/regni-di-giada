class_name Equip
## Armi in mano ed effetti dell'equipaggiamento: forma delle armi per tipo e grado, presa calcolata sulla posa a riposo,
## scia dei colpi, bagliore e particelle per livello di potenziamento, aura dell'armatura e cerchio di rune.

## Livelli di potenziamento dell'arma: dal più alto. c1/c2 = colori, quante = particelle.
const LIVELLI := [
	{"min": 15, "nome": "leggenda", "c1": Color(1.0, 0.75, 0.25), "c2": Color(1.0, 0.38, 0.88), "quante": 46},
	{"min": 12, "nome": "tempesta", "c1": Color(0.69, 0.38, 1.0), "c2": Color(0.44, 0.69, 1.0), "quante": 30},
	{"min": 9, "nome": "fuoco", "c1": Color(1.0, 0.63, 0.13), "c2": Color(1.0, 0.25, 0.06), "quante": 22},
	{"min": 7, "nome": "gelo", "c1": Color(0.38, 0.75, 1.0), "c2": Color(0.75, 0.94, 1.0), "quante": 14},
]
const RARITA := [Color(0, 0, 0, 0), Color(0.42, 0.85, 0.42), Color(0.35, 0.63, 1.0), Color(0.75, 0.44, 1.0), Color(1.0, 0.6, 0.19)]

static var _alone: GradientTexture2D = null
static var _mat_particella: StandardMaterial3D = null


## Macchia luminosa morbida per particelle e bagliori.
static func alone() -> GradientTexture2D:
	if _alone == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.18), Color(1, 1, 1, 0)])
		_alone = GradientTexture2D.new()
		_alone.gradient = g
		_alone.fill = GradientTexture2D.FILL_RADIAL
		_alone.fill_from = Vector2(0.5, 0.5)
		_alone.fill_to = Vector2(1.0, 0.5)
		_alone.width = 64
		_alone.height = 64
	return _alone


static func mat_particella() -> StandardMaterial3D:
	if _mat_particella == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = alone()
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_mat_particella = m
	return _mat_particella


static func livello(up: int) -> Dictionary:
	for l in LIVELLI:
		if up >= int(l.min):
			return l
	return {}


# ------------------------------------------------------------------ presa
## Nodo dentro il pugno. Assi del nodo: +y = lato del pollice (dove esce la lama), +z = verso le dita.
## Si calcola sulla posa a riposo (braccia aperte, palmo in giù): lì il pollice guarda in avanti (+z dello scheletro).
## inclina: gradi di cui la lama piega verso le dita (positivo) o verso il braccio (negativo) rispetto al pollice.
static func impugna(sk: Skeleton3D, osso: String, inclina := 0.0) -> Node3D:
	var i := sk.find_bone(osso)
	var ba := BoneAttachment3D.new()
	ba.bone_name = osso
	sk.add_child(ba)
	var presa := Node3D.new()
	ba.add_child(presa)
	if i < 0:
		return presa
	var riposo := sk.get_bone_global_rest(i)
	var dita := riposo.basis.y.normalized()
	var pollice := Vector3(0, 0, 1)
	pollice = (pollice - dita * pollice.dot(dita)).normalized()
	var base := Basis(pollice.cross(dita).normalized(), pollice, dita)
	# centro del pugno: a metà del palmo, un poco sotto il dorso della mano
	var centro := riposo.origin + dita * 0.095 + Vector3(0, -0.028, 0)
	base = base * Basis(Vector3.RIGHT, deg_to_rad(inclina))
	presa.transform = riposo.affine_inverse() * Transform3D(base, centro)
	return presa


# ------------------------------------------------------------------ armi
static func _metallo(grado: int) -> StandardMaterial3D:
	var c: Color = [Color(0.78, 0.79, 0.82), Color(0.80, 0.68, 0.42), Color(0.55, 0.88, 0.70), Color(0.90, 0.94, 1.0)][clampi(grado - 1, 0, 3)]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.9
	m.roughness = 0.22
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Lama curva a sezione piatta lungo +y, con il filo verso -x. Restituisce la mesh.
static func _lama(lunga: float, larga: float, curva: float, m: Material, genitore: Node3D, y0: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 10
	for k in range(2):                       # due facce leggermente bombate, così prende la luce
		var lato := 1.0 if k == 0 else -1.0
		for i in range(n + 1):
			var t := float(i) / n
			var w := larga * (1.0 - pow(t, 3.0) * 0.85)
			var cx := -curva * t * t
			var y := y0 + lunga * t
			st.set_normal(Vector3(-0.35, 0, lato).normalized())
			st.add_vertex(Vector3(cx - w * 0.5, y, 0.0))                 # filo
			st.set_normal(Vector3(0.0, 0, lato))
			st.add_vertex(Vector3(cx, y, lato * 0.006))                  # costa centrale
			st.set_normal(Vector3(0.35, 0, lato).normalized())
			st.add_vertex(Vector3(cx + w * 0.5, y, 0.0))                 # dorso
		for i in range(n):
			var a := k * (n + 1) * 3 + i * 3
			for j in range(2):
				st.add_index(a + j); st.add_index(a + j + 1); st.add_index(a + j + 3)
				st.add_index(a + j + 1); st.add_index(a + j + 4); st.add_index(a + j + 3)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	genitore.add_child(mi)
	return mi


## Costruisce le armi in mano. Restituisce i nodi delle armi (ognuno con meta «lama»: [base, punta] in coordinate sue).
static func metti(sk: Skeleton3D, tipo: String, grado: int) -> Array:
	var armi: Array = []
	if sk == null or tipo == "fists":
		return armi
	var metallo := _metallo(grado)
	var oro := Edifici.mat(Color(0.85, 0.66, 0.26) if grado >= 3 else Color(0.5, 0.4, 0.2), 0.35, 0.85)
	var fascia := Edifici.mat(Color(0.12, 0.1, 0.12) if grado >= 2 else Color(0.35, 0.12, 0.1), 0.85)
	var corda := Edifici.mat(Color(0.88, 0.85, 0.78) if grado >= 2 else Color(0.5, 0.16, 0.1), 0.8)
	var legno := Edifici.mat(Color(0.32, 0.2, 0.11), 0.8)
	match tipo:
		"sword":
			var a := impugna(sk, "hand_R", 28.0)
			Edifici.cilindro(0.021, 0.023, 0.3, Vector3(0, -0.02, 0), fascia, a, 8)                 # impugnatura
			for i in range(4):
				Edifici.cilindro(0.025, 0.025, 0.018, Vector3(0, -0.12 + i * 0.065, 0), corda, a, 8)
			Edifici.cilindro(0.027, 0.024, 0.035, Vector3(0, -0.185, 0), oro, a, 8)                  # pomolo
			Edifici.cilindro(0.062, 0.062, 0.016, Vector3(0, 0.14, 0), oro, a, 14)                   # guardia tonda
			Edifici.cilindro(0.026, 0.024, 0.03, Vector3(0, 0.162, 0), oro, a, 8)
			var lunga := 1.05 + grado * 0.07
			_lama(lunga, 0.062, 0.085, metallo, a, 0.175)
			a.set_meta("lama", [Vector3(0, 0.2, 0), Vector3(-0.085, 0.175 + lunga, 0)])
			armi.append(a)
		"daggers":
			for osso in ["hand_R", "hand_L"]:
				var d := impugna(sk, osso, 20.0)
				Edifici.cilindro(0.019, 0.02, 0.15, Vector3(0, -0.005, 0), fascia, d, 8)
				Edifici.cilindro(0.045, 0.045, 0.014, Vector3(0, 0.075, 0), oro, d, 12)
				_lama(0.42, 0.05, 0.03, metallo, d, 0.085)
				d.set_meta("lama", [Vector3(0, 0.1, 0), Vector3(-0.03, 0.5, 0)])
				armi.append(d)
		"bow":
			var b := impugna(sk, "hand_L")
			# arco ricurvo: due flettenti ad arco lungo y, la corda dietro (verso -z, dalla parte di chi tira)
			for s in [-1.0, 1.0]:
				for k in range(5):
					var t0 := float(k) / 5.0
					var t1 := float(k + 1) / 5.0
					var p0 := Vector3(0, s * (0.06 + 0.66 * t0), -0.2 * t0 * t0)
					var p1 := Vector3(0, s * (0.06 + 0.66 * t1), -0.2 * t1 * t1)
					var pezzo := Edifici.cilindro(0.016 - 0.008 * t1, 0.018 - 0.008 * t0, p0.distance_to(p1) * 1.08, (p0 + p1) * 0.5, legno if grado < 3 else metallo, b, 6)
					pezzo.rotation.x = atan2(p1.z - p0.z, absf(p1.y - p0.y)) * s
			Edifici.cilindro(0.024, 0.024, 0.16, Vector3.ZERO, fascia, b, 8)
			Edifici.scatola(Vector3(0.004, 1.44, 0.004), Vector3(0, 0, -0.2), Edifici.mat(Color(0.92, 0.92, 0.86), 0.6), b)
			b.set_meta("lama", [Vector3(0, -0.7, -0.1), Vector3(0, 0.7, -0.1)])
			armi.append(b)
		"staff":
			var s2 := impugna(sk, "hand_R", -78.0)
			Edifici.cilindro(0.02, 0.026, 1.95, Vector3(0, 0.42, 0), legno, s2, 8)
			for i in range(3):
				Edifici.cilindro(0.031, 0.031, 0.025, Vector3(0, 1.1 + i * 0.07, 0), oro, s2, 8)
			var colore: Color = [Color(1.0, 0.94, 0.6), Color(0.6, 0.85, 1.0), Color(0.6, 1.0, 0.75), Color(1.0, 0.65, 0.95)][clampi(grado - 1, 0, 3)]
			# gemma in cima fra tre artigli
			var gemma := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.085
			sm.height = 0.19
			sm.radial_segments = 12
			sm.rings = 6
			gemma.mesh = sm
			gemma.material_override = Edifici.mat(colore, 0.2, 0.0, 3.5)
			gemma.position.y = 1.5
			s2.add_child(gemma)
			for i in range(3):
				var art := Edifici.cilindro(0.004, 0.014, 0.2, Vector3(cos(i * TAU / 3.0) * 0.07, 1.46, sin(i * TAU / 3.0) * 0.07), oro, s2, 5)
				art.rotation = Vector3(sin(i * TAU / 3.0) * -0.35, 0, cos(i * TAU / 3.0) * 0.35)
			s2.set_meta("lama", [Vector3(0, 1.3, 0), Vector3(0, 1.62, 0)])
			armi.append(s2)
	return armi


# ------------------------------------------------------------------ effetti per livello di potenziamento
## Bagliore, particelle e (al +15) spirali sull'arma. up: potenziamento, rar: rarità (0-4).
static func effetti_arma(arma: Node3D, up: int, rar: int, con_luce: bool) -> void:
	var l := livello(up)
	var punti: Array = arma.get_meta("lama", [Vector3.ZERO, Vector3(0, 1, 0)])
	var base: Vector3 = punti[0]
	var punta: Vector3 = punti[1]
	var centro := (base + punta) * 0.5
	var colore := Color(0, 0, 0, 0)
	if not l.is_empty():
		colore = l.c1
	elif rar >= 1 and up >= 4:
		colore = RARITA[clampi(rar, 0, 4)]
	if colore.a <= 0.0:
		return
	# la lama si accende
	for n in arma.get_children():
		var mi := n as MeshInstance3D
		if mi != null and mi.mesh is ArrayMesh:
			var m: StandardMaterial3D = (mi.material_override as StandardMaterial3D).duplicate()
			m.emission_enabled = true
			m.emission = colore
			m.emission_energy_multiplier = 0.6 if l.is_empty() else (1.2 + 0.25 * (up - 7))
			mi.material_override = m
	if l.is_empty():
		return
	# particelle lungo la lama, lasciate indietro nel mondo quando l'arma si muove
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	var grande := 0.11 if String(l.nome) != "leggenda" else 0.15
	q.size = Vector2(grande, grande)
	p.mesh = q
	p.material_override = mat_particella()
	p.amount = int(l.quante)
	p.lifetime = 0.7
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.03, (punta - base).length() * 0.5, 0.03)
	p.position = centro
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.4
	p.gravity = Vector3(0, 0.9 if String(l.nome) != "gelo" else -0.5, 0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.2
	var sf := Gradient.new()
	sf.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	sf.colors = PackedColorArray([Color(l.c1.r, l.c1.g, l.c1.b, 0.0), Color(l.c1.r, l.c1.g, l.c1.b, 0.9), Color(l.c2.r, l.c2.g, l.c2.b, 0.0)])
	p.color_ramp = sf
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arma.add_child(p)
	# alone attorno alla lama
	var al := MeshInstance3D.new()
	var qa := QuadMesh.new()
	qa.size = Vector2(0.5, (punta - base).length() * 1.25)
	al.mesh = qa
	var ma := StandardMaterial3D.new()
	ma.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ma.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ma.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ma.albedo_texture = alone()
	ma.albedo_color = Color(l.c1.r, l.c1.g, l.c1.b, 0.3 + 0.05 * (up - 7))
	ma.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	ma.billboard_keep_scale = true
	ma.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	al.material_override = ma
	al.position = centro
	al.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arma.add_child(al)
	if con_luce and up >= 9:
		var luce := OmniLight3D.new()
		luce.light_color = l.c1
		luce.light_energy = 0.9 + 0.12 * (up - 9)
		luce.omni_range = 3.5
		luce.position = centro
		arma.add_child(luce)
	if String(l.nome) == "leggenda":
		# due spirali che salgono lungo la lama
		for k in range(2):
			var perno := Node3D.new()
			perno.position = base
			arma.add_child(perno)
			var sfera := CPUParticles3D.new()
			var q2 := QuadMesh.new()
			q2.size = Vector2(0.09, 0.09)
			sfera.mesh = q2
			sfera.material_override = mat_particella()
			sfera.amount = 26
			sfera.lifetime = 0.5
			sfera.local_coords = false
			sfera.gravity = Vector3.ZERO
			sfera.initial_velocity_max = 0.05
			var g2 := Gradient.new()
			g2.colors = PackedColorArray([Color(l.c2.r, l.c2.g, l.c2.b, 1.0), Color(l.c1.r, l.c1.g, l.c1.b, 0.0)])
			sfera.color_ramp = g2
			sfera.position = Vector3(0.13, 0, 0)
			perno.add_child(sfera)
			var gira := arma.create_tween().set_loops()
			gira.tween_property(perno, "rotation:y", TAU * (1.0 if k == 0 else -1.0), 0.9).from(float(k) * PI)
			var sale := arma.create_tween().set_loops()
			sale.tween_property(perno, "position", punta, 1.3).from(base)


## Aura dell'armatura: scintille che salgono dal +9 (o dalla rarità Epica), cerchio di rune al +15 o Leggendaria.
static func aura_armatura(corpo: Node3D, bu: int, br: int) -> void:
	if bu < 9 and br < 3:
		return
	var colore: Color = RARITA[clampi(br, 0, 4)] if br >= 3 else (Color(0.69, 0.44, 1.0) if bu >= 12 else Color(1.0, 0.78, 0.38))
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.1, 0.1)
	p.mesh = q
	p.material_override = mat_particella()
	p.amount = 14 + (12 if bu >= 12 else 0) + (14 if br >= 4 else 0)
	p.lifetime = 1.6
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.75
	p.emission_ring_inner_radius = 0.45
	p.emission_ring_height = 0.2
	p.position.y = 0.2
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.1
	p.gravity = Vector3(0, 0.25, 0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.1
	var sf := Gradient.new()
	sf.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	sf.colors = PackedColorArray([Color(colore.r, colore.g, colore.b, 0.0), Color(colore.r, colore.g, colore.b, 0.85), Color(colore.r, colore.g, colore.b, 0.0)])
	p.color_ramp = sf
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	corpo.add_child(p)
	if br >= 4 or bu >= 15:
		corpo.add_child(cerchio_rune(1.5, RARITA[4] if br >= 4 else Color(1.0, 0.78, 0.38), true))


## Cerchio di rune a terra. fisso = resta acceso (aure); altrimenti chi lo crea anima il parametro «fase».
static func cerchio_rune(raggio: float, colore: Color, fisso: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(raggio * 2.0, raggio * 2.0)
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = preload("res://shader/fx_rune.gdshader")
	m.set_shader_parameter("colore", colore)
	m.set_shader_parameter("fisso", 1.0 if fisso else 0.0)
	mi.material_override = m
	mi.position.y = 0.07
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ------------------------------------------------------------------ scia dei colpi
class Scia:
	extends MeshInstance3D
	## Nastro luminoso che segue la lama durante gli attacchi (campioni nel mondo degli ultimi istanti).
	const VITA := 0.22
	var arma: Node3D
	var colore := Color(1.0, 0.95, 0.85)
	var attiva := false
	var _campioni: Array = []       # [base, punta, età]
	var _im: ImmediateMesh

	func _init() -> void:
		_im = ImmediateMesh.new()
		mesh = _im
		top_level = true
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		material_override = m

	func _process(dt: float) -> void:
		global_transform = Transform3D.IDENTITY
		for c in _campioni:
			c[2] += dt
		while not _campioni.is_empty() and _campioni[-1][2] > VITA:
			_campioni.pop_back()
		if attiva and is_instance_valid(arma):
			var punti: Array = arma.get_meta("lama", [Vector3.ZERO, Vector3(0, 1, 0)])
			var a: Vector3 = arma.global_transform * (punti[0] as Vector3)
			var b: Vector3 = arma.global_transform * (punti[1] as Vector3)
			if not _campioni.is_empty() and (_campioni[0][1] as Vector3).distance_to(b) > 4.0:
				_campioni.clear()                # teletrasporto o scatto: niente scia
			_campioni.push_front([a, b, 0.0])
		_im.clear_surfaces()
		if _campioni.size() < 2:
			return
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in range(_campioni.size()):
			var c: Array = _campioni[i]
			var f := maxf(0.0, 1.0 - float(c[2]) / VITA) * (1.0 - float(i) / _campioni.size())
			_im.surface_set_color(Color(colore.r, colore.g, colore.b, f * 0.15))
			_im.surface_add_vertex(c[0])
			_im.surface_set_color(Color(colore.r, colore.g, colore.b, f * 0.9))
			_im.surface_add_vertex(c[1])
		_im.surface_end()
