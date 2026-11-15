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
## Forme delle armi (geometria da codice): vedi forme_armi.gd.
const Forme := preload("res://script/forme_armi.gd")

## Inclinazione della presa per tipo (gradi attorno all'asse del palmo): positivo = la lama scende verso le dita.
static var RZ := {"staff": -52.0}      # rotazione extra dell'arma attorno all'asse delle dita (gradi)
static var INCLINA := {"sword": 48.0, "daggers": 18.0, "bow": -60.0, "staff": -12.0, "fists": 0.0}

## Posa delle braccia per tipo di arma (vedi posa_arma.gd): dita chiuse, polso ruotato, gomito piegato (gradi).
static var POSE := {
	"sword": {"R": {"curl": 1.0}},
	"daggers": {"R": {"curl": 1.0}, "L": {"curl": 1.0}},
	"fists": {"R": {"curl": 1.0}, "L": {"curl": 1.0}},
	"bow": {"L": {"curl": 1.0, "roll": 60.0, "flex": 30.0}, "R": {"curl": 0.7}},
	"staff": {"R": {"curl": 1.0, "roll": 70.0, "flex": 40.0}},
}


## Corda dell'arco: due tratti che si incontrano nel punto d'incocco; con «tiro» > 0 il punto segue la mano che tira.
class Corda:
	extends Node3D
	var alto := Vector3.ZERO
	var basso := Vector3.ZERO
	var mano: Node3D = null            # nodo della mano destra (la corda va lì quando si tira)
	var arco: Node3D = null
	var tiro := 0.0
	var _su: MeshInstance3D
	var _giu: MeshInstance3D
	var _freccia: Node3D

	func _init() -> void:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.92, 0.9, 0.8)
		m.roughness = 0.7
		for i in range(2):
			var mi := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.006, 0.006, 1.0)
			mi.mesh = b
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			if i == 0:
				_su = mi
			else:
				_giu = mi
		# freccia incoccata: asta lungo +z dal punto d'incocco, punta e penne
		_freccia = Node3D.new()
		var asta := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.006
		cm.bottom_radius = 0.006
		cm.height = 0.9
		asta.mesh = cm
		asta.rotation.x = PI / 2
		asta.position.z = 0.45
		asta.material_override = Forme.opaco(Color(0.7, 0.55, 0.3), 0.6)
		_freccia.add_child(asta)
		var punta := MeshInstance3D.new()
		var pc := CylinderMesh.new()
		pc.top_radius = 0.0
		pc.bottom_radius = 0.016
		pc.height = 0.07
		punta.mesh = pc
		punta.rotation.x = PI / 2
		punta.position.z = 0.935
		punta.material_override = Forme.acciaio(Color(0.8, 0.82, 0.86), 0.3)
		_freccia.add_child(punta)
		for k in range(3):
			var penna := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.002, 0.04, 0.1)
			penna.mesh = bm
			penna.position = Vector3(0, 0, 0.07)
			penna.rotation.z = k * TAU / 3.0
			penna.material_override = Forme.opaco(Color(0.85, 0.2, 0.15), 0.8)
			_freccia.add_child(penna)
		_freccia.visible = false
		add_child(_freccia)

	func _process(_dt: float) -> void:
		var riposo := (alto + basso) * 0.5
		var p := riposo
		if tiro > 0.001 and mano != null and arco != null and mano.is_inside_tree():
			p = riposo.lerp(arco.to_local(mano.global_position), tiro)
		_segmento(_su, alto, p)
		_segmento(_giu, p, basso)
		_freccia.visible = tiro > 0.05
		_freccia.position = p

	func _segmento(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
		var d := b - a
		var l := d.length()
		if l < 0.001:
			return
		var su := Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		mi.transform = Transform3D(Basis.looking_at(d / l, su) * Basis.from_scale(Vector3(1, 1, l)), (a + b) * 0.5)


## Costruisce le armi in mano. Restituisce i nodi delle armi (ognuno con meta «lama»: [base, punta] in coordinate sue).
static func metti(sk: Skeleton3D, tipo: String, grado: int) -> Array:
	var armi: Array = []
	if sk == null:
		return armi
	grado = clampi(grado, 1, 4)
	match tipo:
		"sword":
			var a := impugna(sk, "hand_R", INCLINA.sword)
			var p := Node3D.new()
			a.add_child(p)
			p.rotation.y = PI / 2.0                    # il filo guarda verso le dita (in basso a braccio lungo il fianco), le facce piatte verso l'esterno
			Forme.spada(p, grado)
			armi.append(p)
		"daggers":
			for osso in ["hand_R", "hand_L"]:
				var d := impugna(sk, osso, INCLINA.daggers)
				var p := Node3D.new()
				d.add_child(p)
				p.rotation.y = PI / 2.0
				Forme.pugnale(p, grado)
				armi.append(p)
		"fists":
			for osso in ["hand_R", "hand_L"]:
				var d := impugna(sk, osso, 0.0)
				var p := Node3D.new()
				d.add_child(p)
				Forme.pugni(p, grado, 1.0 if osso == "hand_R" else -1.0)
				armi.append(p)
		"bow":
			var b := impugna(sk, "hand_L", INCLINA.bow)
			var p := Node3D.new()
			b.add_child(p)
			var punte: Array = Forme.arco(p, grado)
			var corda := Corda.new()
			corda.arco = p
			corda.alto = punte[0]
			corda.basso = punte[1]
			corda.mano = impugna(sk, "hand_R", 0.0)
			p.add_child(corda)
			p.set_meta("corda", corda)
			armi.append(p)
		"staff":
			var s2 := impugna(sk, "hand_R", INCLINA.staff)
			var p := Node3D.new()
			s2.add_child(p)
			p.rotation.z = deg_to_rad(RZ.staff)
			var gira: Node3D = Forme.bastone(p, grado)
			if gira != null and grado >= 2:
				var tw := p.create_tween().set_loops()
				tw.tween_property(gira, "rotation:y", TAU, 9.0 - grado).from(0.0)
			armi.append(p)
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
	for n in arma.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi != null and mi.has_meta(Forme.ACCENDI) and mi.material_override is StandardMaterial3D:
			var m: StandardMaterial3D = (mi.material_override as StandardMaterial3D).duplicate()
			m.emission_enabled = true
			m.emission = colore
			m.emission_energy_multiplier = 0.45 if l.is_empty() else (0.7 + 0.1 * (up - 7))     # col bloom oltre ~1,3 diventa bianco
			mi.material_override = m
	if l.is_empty():
		return
	# particelle lungo la lama, lasciate indietro nel mondo quando l'arma si muove
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	# armi corte (pugnali, guanti): meno particelle e più piccole, altrimenti coprono l'arma con una macchia bianca
	var lunga := (punta - base).length()
	var corta := clampf(lunga / 1.0, 0.35, 1.0)
	var grande := (0.085 if String(l.nome) != "leggenda" else 0.11) * (0.6 + 0.4 * corta)
	q.size = Vector2(grande, grande)
	p.mesh = q
	p.material_override = mat_particella()
	p.amount = maxi(8, int(float(l.quante) * 0.85 * corta))
	p.lifetime = 0.7
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.03, 0.03, 0.03) + (punta - base).abs() * 0.5
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
	sf.colors = PackedColorArray([Color(l.c1.r, l.c1.g, l.c1.b, 0.0), Color(l.c1.r, l.c1.g, l.c1.b, 0.7), Color(l.c2.r, l.c2.g, l.c2.b, 0.0)])
	p.color_ramp = sf
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arma.add_child(p)
	# alone attorno alla lama
	var al := MeshInstance3D.new()
	var qa := QuadMesh.new()
	var largo: float = arma.get_meta("largo", 0.5)
	var lungo_y := absf(punta.y - base.y) > absf(punta.z - base.z)
	qa.size = Vector2(largo, (punta - base).length() * 1.25) if lungo_y else Vector2(largo, largo)
	al.mesh = qa
	var ma := StandardMaterial3D.new()
	ma.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ma.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ma.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ma.albedo_texture = alone()
	ma.albedo_color = Color(l.c1.r, l.c1.g, l.c1.b, (0.2 + 0.035 * (up - 7)) * (0.4 if lunga < 0.6 else 1.0))     # armi corte: alone più tenue
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
		luce.light_energy = 0.6 + 0.07 * (up - 9)
		luce.omni_range = 3.5
		luce.position = centro
		arma.add_child(luce)
	if String(l.nome) == "leggenda" and lunga >= 0.6:
		# due spirali che salgono lungo la lama (solo sulle armi lunghe)
		for k in range(2):
			var perno := Node3D.new()
			perno.position = base
			arma.add_child(perno)
			var sfera := CPUParticles3D.new()
			var q2 := QuadMesh.new()
			q2.size = Vector2(0.06, 0.06)
			sfera.mesh = q2
			sfera.material_override = mat_particella()
			sfera.amount = 14
			sfera.lifetime = 0.5
			sfera.local_coords = false
			sfera.gravity = Vector3.ZERO
			sfera.initial_velocity_max = 0.05
			var g2 := Gradient.new()
			g2.colors = PackedColorArray([Color(l.c2.r, l.c2.g, l.c2.b, 0.6), Color(l.c1.r, l.c1.g, l.c1.b, 0.0)])
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
