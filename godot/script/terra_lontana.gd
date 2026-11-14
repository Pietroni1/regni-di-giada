class_name TerraLontana
extends Node3D
## Una mappa lontana (shared/mappe.js) costruita da codice: terreno dipinto coi colori del tema, piante da natura.glb
## (MultiMesh, come mondo.gd), spiazzo d'arrivo con portale e lanterne; per l'arena pavimento a loto, parapetto,
## porte, nicchie, gradinate e pagode. Si crea quando il personaggio entra nella mappa e si libera quando esce (gioco.gd).

const CELLE_PER_PEZZO := 50

var id := ""
var def: Dictionary = {}
var origine := Vector3.ZERO
var _localizzati: Dictionary = {}

static var _forme: Dictionary = {}        # nome della mesh in natura.glb → Mesh (caricate una volta)


static func crea(id_mappa: String) -> TerraLontana:
	var t := TerraLontana.new()
	t.id = id_mappa
	t.def = Mappe.definizioni()[id_mappa]
	t.name = "Mappa_" + id_mappa
	t.origine = Vector3(float(t.def.cx), 0, float(t.def.cz))
	t._costruisci()
	return t


func _costruisci() -> void:
	_terreno()
	_piante()
	if String(def.tipo) == "arena":
		_arena()
	else:
		_arrivo()
		_rovine()
	_localizza(self)


func _tema(chiave: String, predefinito := Color.WHITE) -> Color:
	var v = def.tema.get(chiave)
	return Color(String(v)) if v != null else predefinito


func _suolo(lx: float, lz: float) -> Vector3:
	var x := float(def.cx) + lx
	var z := float(def.cz) + lz
	return Vector3(x, Mappe.altezza(x, z), z)


# ------------------------------------------------------------------ terreno
func _terreno() -> void:
	var tema: Dictionary = def.tema
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shader/terreno_mappa.gdshader")
	mat.set_shader_parameter("suolo_a", Color(String(tema.suolo[0])))
	mat.set_shader_parameter("suolo_b", Color(String(tema.suolo[1])))
	mat.set_shader_parameter("macchie", _tema("macchie"))
	mat.set_shader_parameter("terra", _tema("terra"))
	mat.set_shader_parameter("roccia", _tema("roccia"))
	mat.set_shader_parameter("lastrico", _tema("lastrico"))
	mat.set_shader_parameter("centro", Vector2(float(def.cx), float(def.cz)))
	mat.set_shader_parameter("dune", float(tema.get("dune", 0)))
	mat.set_shader_parameter("quota_roccia", float(tema.get("quotaRoccia", 30)))
	if def.has("arrivo"):
		mat.set_shader_parameter("arrivo", Vector2(float(def.cx) + float(def.arrivo.x), float(def.cz) + float(def.arrivo.z)))
		mat.set_shader_parameter("raggio_arrivo", float(def.sicuro) + 4.0)
		mat.set_shader_parameter("sentiero", 1.0)
	var g: Dictionary = def.griglia
	var arr := Mappe.griglia(id)
	if arr.is_empty():
		return
	var lato := int(g.lato)
	var passo := float(g.passo)
	var x0 := float(g.x0)
	var z0 := float(g.z0)
	var h := func(i: int, j: int) -> float: return arr[clampi(j, 0, lato - 1) * lato + clampi(i, 0, lato - 1)]
	var n := lato - 1
	var pezzi := int(ceil(float(n) / CELLE_PER_PEZZO))
	for pj in range(pezzi):
		for pi in range(pezzi):
			var i0 := pi * CELLE_PER_PEZZO
			var j0 := pj * CELLE_PER_PEZZO
			var ni := mini(CELLE_PER_PEZZO, n - i0)
			var nj := mini(CELLE_PER_PEZZO, n - j0)
			var vert := PackedVector3Array()
			var norm := PackedVector3Array()
			var ind := PackedInt32Array()
			for j in range(nj + 1):
				for i in range(ni + 1):
					var gi := i0 + i
					var gj := j0 + j
					vert.append(Vector3(x0 + gi * passo, h.call(gi, gj), z0 + gj * passo))
					var dx: float = h.call(gi + 1, gj) - h.call(gi - 1, gj)
					var dz: float = h.call(gi, gj + 1) - h.call(gi, gj - 1)
					norm.append(Vector3(-dx, 2.0 * passo, -dz).normalized())
			for j in range(nj):
				for i in range(ni):
					var a := j * (ni + 1) + i
					var b := a + 1
					var c := a + ni + 1
					var d := c + 1
					ind.append_array([a, b, c, b, d, c])
			var arrs := []
			arrs.resize(Mesh.ARRAY_MAX)
			arrs[Mesh.ARRAY_VERTEX] = vert
			arrs[Mesh.ARRAY_NORMAL] = norm
			arrs[Mesh.ARRAY_INDEX] = ind
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)
			var mi := MeshInstance3D.new()
			mi.name = "Terreno_%d_%d" % [pi, pj]
			mi.mesh = mesh
			mi.material_override = mat
			add_child(mi)


# ------------------------------------------------------------------ piante (natura.glb)
static func _carica_forme() -> void:
	if not _forme.is_empty():
		return
	var scena: PackedScene = load("res://modelli/natura.glb")
	if scena == null:
		push_warning("natura.glb non importato: apri il progetto nell'editor una volta.")
		return
	var radice := scena.instantiate()
	for n in radice.find_children("*", "MeshInstance3D", true, false):
		_forme[String(n.name)] = (n as MeshInstance3D).mesh
	radice.free()


func _piante() -> void:
	_carica_forme()
	if _forme.is_empty():
		return
	var chioma := ShaderMaterial.new()
	chioma.shader = preload("res://shader/chioma.gdshader")
	var corteccia := ShaderMaterial.new()
	corteccia.shader = preload("res://shader/corteccia.gdshader")
	var roccia := ShaderMaterial.new()
	roccia.shader = preload("res://shader/roccia.gdshader")
	roccia.set_shader_parameter("tinta", _tema("roccia", Color.WHITE).lightened(0.35))
	roccia.set_shader_parameter("muschio_forza", 0.0 if float(def.tema.get("dune", 0)) > 0.0 else 0.8)
	var tinte_tema: Dictionary = def.tema.get("tinte", {})
	var liste: Dictionary = def.vegetazione
	for specie in liste:
		var arr: Array = liste[specie]
		if arr.is_empty():
			continue
		if specie == "roccia":
			for v in range(3):
				var parte := []
				for i in range(arr.size()):
					if i % 3 == v:
						parte.append(arr[i])
				_semina(_forme.get("roccia_%d" % (v + 1)), roccia, parte, 1.2, 0.15, [], true)
			continue
		var tinte: Array = []
		for c in tinte_tema.get(specie, ["#ffffff"]):
			tinte.append(Color(String(c)))
		_semina(_forme.get(specie + "_tronco"), corteccia, arr, 1.0, 0.0, [], specie != "cespuglio")
		_semina(_forme.get(specie + "_chioma"), chioma, arr, 1.0, 0.0, tinte, true)


func _semina(forma: Mesh, materiale: Material, arr: Array, scala: float, alza: float, tinte: Array, ombra: bool) -> void:
	if forma == null or arr.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not tinte.is_empty()
	mm.mesh = forma
	mm.instance_count = arr.size()
	for i in range(arr.size()):
		var e: Array = arr[i]
		var s: float = float(e[3]) * scala
		var base := Basis(Vector3.UP, float(e[4])).scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, Transform3D(base, Vector3(e[0], float(e[1]) + alza, e[2])))
		if mm.use_colors:
			mm.set_instance_color(i, tinte[i % tinte.size()])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = materiale
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ombra else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ------------------------------------------------------------------ arrivo delle mappe da esperienza
func _arrivo() -> void:
	var tetto := _tema("tetto", Color(0.3, 0.15, 0.1))
	var accento := _tema("accento", Color(0.7, 0.2, 0.15))
	var ax := float(def.arrivo.x)
	var az := float(def.arrivo.z)
	var radice := Node3D.new()
	radice.name = "Arrivo"
	radice.position = _suolo(ax, az)
	add_child(radice)
	# portale verso l'interno della mappa (+z locale), santuario alle spalle, lanterne attorno allo spiazzo
	var portale := Edifici.porta(6.0, tetto, accento)
	portale.position = Vector3(0, 0, 10.5)
	radice.add_child(portale)
	var santuario := Edifici.casa(5.0, 4.0, tetto, 2.4, 2.0)
	santuario.position = Vector3(-7.5, 0, -7.0)
	santuario.rotation.y = PI / 5.0
	radice.add_child(santuario)
	for k in range(6):
		var a := TAU * (k + 0.5) / 6.0
		var lan := Edifici.lanterna(k % 3 == 0)
		lan.position = Vector3(sin(a) * 12.5, 0, cos(a) * 12.5)
		radice.add_child(lan)
	# stendardi della mappa
	for sx in [-1.0, 1.0]:
		var asta := Edifici.cilindro(0.07, 0.09, 6.0, Vector3(sx * 5.5, 3.0, 12.5), Edifici.legno(Edifici.LEGNO), radice, 8)
		Edifici.scatola(Vector3(0.9, 2.6, 0.04), Vector3(0.52, 1.5, 0), Edifici.mat(accento, 0.85), asta)


# ------------------------------------------------------------------ rovine e paesaggio (solo decorazione)
func _rovine() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var R := float(def.raggio)
	var dune := float(def.tema.get("dune", 0)) > 0.0
	var roccia := ShaderMaterial.new()
	roccia.shader = preload("res://shader/roccia.gdshader")
	roccia.set_shader_parameter("muschio_forza", 0.0 if dune else 0.7)
	roccia.set_shader_parameter("tinta", _tema("roccia").lightened(0.45))
	var tetto := _tema("tetto", Color(0.3, 0.15, 0.1)).darkened(0.25)
	# portali in rovina dentro la mappa (lontani dall'arrivo e dagli obelischi)
	var fatti := 0
	var tentativi := 0
	while fatti < (3 if not dune else 2) and tentativi < 60:
		tentativi += 1
		var a := rng.randf() * TAU
		var d := rng.randf_range(30.0, R - 25.0)
		var lx := sin(a) * d
		var lz := cos(a) * d
		if Vector2(lx - float(def.arrivo.x), lz - float(def.arrivo.z)).length() < 45.0 or _vicino_obelisco(lx, lz, 14.0):
			continue
		var p := Edifici.porta(5.0, tetto, _tema("accento").darkened(0.45))
		p.position = _suolo(lx, lz) - Vector3(0, 0.3, 0)
		p.rotation = Vector3(rng.randf_range(-0.05, 0.05), rng.randf() * TAU, rng.randf_range(-0.06, 0.06))
		add_child(p)
		fatti += 1
	# pinnacoli e massi oltre il confine percorribile: fanno da cornice
	for k in range(26 if dune else 14):
		var a := TAU * (k + rng.randf() * 0.6) / (26.0 if dune else 14.0)
		var d := R + rng.randf_range(6.0, 30.0)
		var lx := sin(a) * d
		var lz := cos(a) * d
		var alto := rng.randf_range(8.0, 22.0) if dune else rng.randf_range(5.0, 12.0)
		var base := rng.randf_range(2.2, 4.5)
		var pin := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = base * rng.randf_range(0.45, 0.8)
		c.bottom_radius = base
		c.height = alto
		c.radial_segments = 7
		c.rings = 3
		pin.mesh = c
		pin.material_override = roccia
		pin.position = _suolo(lx, lz) + Vector3(0, alto * 0.45, 0)
		pin.rotation = Vector3(rng.randf_range(-0.08, 0.08), rng.randf() * TAU, rng.randf_range(-0.08, 0.08))
		add_child(pin)
		if dune and rng.randf() < 0.5:
			# cappello di roccia più larga in cima (erosione del vento)
			var cap := MeshInstance3D.new()
			var cc := CylinderMesh.new()
			cc.top_radius = base * 1.1
			cc.bottom_radius = base * 0.7
			cc.height = 1.6
			cc.radial_segments = 7
			cap.mesh = cc
			cap.material_override = roccia
			cap.position = Vector3(0, alto * 0.5 + 0.6, 0)
			pin.add_child(cap)


func _vicino_obelisco(lx: float, lz: float, r: float) -> bool:
	for o in def.get("obelischi", []):
		if Vector2(lx - float(o[1]), lz - float(o[2])).length() < r:
			return true
	return false


# ------------------------------------------------------------------ arena
func _arena() -> void:
	var R := float(def.raggio)
	var porte := int(def.porte)
	var dn := float(def.distNicchia)
	var nicchia := float(def.nicchia)
	var corr := float(def.corridoio)
	var base := Mappe.altezza(float(def.cx), float(def.cz))
	var tetto := _tema("tetto", Color(0.3, 0.1, 0.08))
	var accento := _tema("accento", Color(0.7, 0.15, 0.12))
	var radice := Node3D.new()
	radice.name = "Arena"
	radice.position = Vector3(float(def.cx), base, float(def.cz))
	add_child(radice)
	var pietra := Edifici.pietra(Edifici.PIETRA)
	var pietra_chiara := Edifici.pietra(Edifici.PIETRA.lightened(0.15))
	var lacca := Edifici.mat(accento.darkened(0.1), 0.45)

	# pavimento a loto
	var pav := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = R + 0.6
	disco.bottom_radius = R + 0.8
	disco.height = 0.8
	disco.radial_segments = 96
	disco.rings = 1
	pav.mesh = disco
	var mp := ShaderMaterial.new()
	mp.shader = preload("res://shader/arena.gdshader")
	mp.set_shader_parameter("centro", Vector2(float(def.cx), float(def.cz)))
	mp.set_shader_parameter("raggio", R)
	mp.set_shader_parameter("porte", float(porte))
	pav.material_override = mp
	pav.position = Vector3(0, -0.39, 0)
	radice.add_child(pav)

	# parapetto di pietra con corrimano laccato, aperto alle porte
	var n := 72
	var corda := TAU * (R + 1.0) / n
	for k in range(n):
		var a := TAU * (k + 0.5) / n
		if _vicino_porta(a, porte, (corr + 1.4) / (R + 1.0)):
			continue
		var seg := Node3D.new()
		seg.position = Vector3(sin(a) * (R + 1.0), 0, cos(a) * (R + 1.0))
		seg.rotation.y = a
		radice.add_child(seg)
		Edifici.scatola(Vector3(corda + 0.04, 1.1, 0.7), Vector3(0, 0.55, 0), pietra, seg)
		Edifici.scatola(Vector3(corda + 0.04, 0.14, 0.82), Vector3(0, 1.17, 0), lacca, seg)

	# gradinate fra una porta e l'altra
	var vuoto := asin(minf(0.99, (nicchia + 1.8) / dn))
	for i in range(porte):
		var a0 := Mappe.angolo_porta(i) + vuoto
		var a1 := Mappe.angolo_porta(i + 1) - vuoto
		for gradino in range(4):
			var r_in := R + 2.0 + gradino * 2.6
			_gradone(radice, r_in, r_in + 2.6, 1.0 + gradino * 0.95, a0, a1, pietra_chiara if gradino % 2 == 0 else pietra)

	# porte, corridoi e nicchie (zone sicure): lastricato, portale laccato, bracieri e lanterne
	for i in range(porte):
		var a := Mappe.angolo_porta(i)
		var dir := Vector3(sin(a), 0, cos(a))
		var lat := Vector3(cos(a), 0, -sin(a))
		var corridoio := Node3D.new()
		corridoio.position = dir * ((R + dn) * 0.5)
		corridoio.rotation.y = a
		radice.add_child(corridoio)
		Edifici.scatola(Vector3(corr * 2.0 + 0.6, 0.4, dn - R + 1.0), Vector3(0, -0.18, 0), pietra, corridoio)
		Edifici.cilindro(nicchia + 0.4, nicchia + 0.5, 0.4, dir * dn + Vector3(0, -0.18, 0), pietra_chiara, radice, 28)
		var portale := Edifici.porta(corr * 2.0 + 0.6, tetto, accento)
		portale.position = dir * (R + 1.0)
		portale.rotation.y = a
		radice.add_child(portale)
		for s in [-1.0, 1.0]:
			_braciere(radice, dir * (R + 1.0) + lat * s * (corr + 2.2))
			var lan := Edifici.lanterna(s > 0.0)
			lan.position = dir * (dn + 2.0) + lat * s * (nicchia - 0.8)
			radice.add_child(lan)

	# pagode agli angoli, fuori dalle gradinate
	for i in range(porte):
		var a := Mappe.angolo_porta(i) + PI / porte
		var lx := sin(a) * 92.0
		var lz := cos(a) * 92.0
		var pag := Edifici.pagoda(7.0, tetto, accento)
		pag.position = _suolo(lx, lz) - Vector3(float(def.cx), base, float(def.cz)) + Vector3(0, -0.2, 0)
		pag.rotation.y = a + PI
		radice.add_child(pag)

	# stendardi dei tre regni e d'oro sul gradone più alto
	var colori: Array = []
	for kid in Dati.KINGDOMS:
		colori.append(Dati.colore(Dati.KINGDOMS[kid].hex))
	colori.append(Edifici.ORO)
	for k in range(porte * 3):
		var a := TAU * (k + 0.5) / (porte * 3)
		if _vicino_porta(a, porte, vuoto + 0.05):
			continue
		var r := R + 2.0 + 4 * 2.6 - 0.6
		var asta := Edifici.cilindro(0.08, 0.1, 7.0, Vector3(sin(a) * r, 1.0 + 3 * 0.95 + 3.5, cos(a) * r), Edifici.legno(Edifici.LEGNO), radice, 8)
		Edifici.scatola(Vector3(1.0, 3.0, 0.05), Vector3(0.55, 1.6, 0), Edifici.mat(colori[k % colori.size()], 0.85), asta)
		asta.rotation.y = a


func _vicino_porta(a: float, porte: int, mezzo: float) -> bool:
	for i in range(porte):
		if absf(angle_difference(a, Mappe.angolo_porta(i))) < mezzo:
			return true
	return false


## Gradone ad arco: piano in alto, alzata verso l'interno e verso l'esterno (angoli come le porte: (sin a, cos a)).
func _gradone(genitore: Node3D, r_in: float, r_out: float, alto: float, a0: float, a1: float, m: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := maxi(4, int((a1 - a0) * r_out / 2.5))
	for k in range(n):
		var b0 := lerpf(a0, a1, float(k) / n)
		var b1 := lerpf(a0, a1, float(k + 1) / n)
		var d0 := Vector3(sin(b0), 0, cos(b0))
		var d1 := Vector3(sin(b1), 0, cos(b1))
		var su := Vector3(0, alto, 0)
		var giu := Vector3(0, -0.6, 0)
		# piano
		_quad(st, d0 * r_in + su, d1 * r_in + su, d1 * r_out + su, d0 * r_out + su)
		# alzata interna (verso il centro) ed esterna
		_quad(st, d0 * r_in + giu, d1 * r_in + giu, d1 * r_in + su, d0 * r_in + su)
		_quad(st, d1 * r_out + giu, d0 * r_out + giu, d0 * r_out + su, d1 * r_out + su)
	# testate
	for coppia in [[a0, 1.0], [a1, -1.0]]:
		var d := Vector3(sin(coppia[0]), 0, cos(coppia[0]))
		var q := [d * r_in + Vector3(0, -0.6, 0), d * r_in + Vector3(0, alto, 0), d * r_out + Vector3(0, alto, 0), d * r_out + Vector3(0, -0.6, 0)]
		if coppia[1] > 0.0:
			_quad(st, q[0], q[1], q[2], q[3])
		else:
			_quad(st, q[3], q[2], q[1], q[0])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	genitore.add_child(mi)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, b, c, a, c, d]:      # senso orario visto dal lato visibile (convenzione di Godot)
		st.add_vertex(v)


func _braciere(genitore: Node3D, pos: Vector3) -> void:
	var g := Node3D.new()
	g.position = pos
	genitore.add_child(g)
	var bronzo := Edifici.mat(Color(0.32, 0.2, 0.1), 0.45, 0.7)
	Edifici.cilindro(0.35, 0.45, 1.2, Vector3(0, 0.6, 0), Edifici.pietra(Edifici.PIETRA), g, 8)
	Edifici.cilindro(0.75, 0.4, 0.45, Vector3(0, 1.42, 0), bronzo, g, 12)
	var braci := Edifici.cilindro(0.62, 0.62, 0.08, Vector3(0, 1.62, 0), Edifici.mat(Color(1.0, 0.45, 0.12), 0.6, 0.0, 4.0), g, 12)
	braci.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ------------------------------------------------------------------ rumore preciso lontano dall'origine
## Gli shader di pietra, intonaco e roccia calcolano il rumore dalla posizione nel mondo: a x = 6000-8000 i numeri sono
## troppo grandi per la precisione della scheda. Qui i loro materiali (condivisi con i villaggi) si sostituiscono con
## copie che sottraggono il centro della mappa (parametro `origine`).
func _localizza(n: Node) -> void:
	if n is GeometryInstance3D:
		var gi := n as GeometryInstance3D
		var m := gi.material_override
		if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
			var percorso := (m as ShaderMaterial).shader.resource_path
			if percorso.ends_with("pietra.gdshader") or percorso.ends_with("intonaco.gdshader") or percorso.ends_with("roccia.gdshader"):
				if not _localizzati.has(m):
					var copia := (m as ShaderMaterial).duplicate() as ShaderMaterial
					copia.set_shader_parameter("origine", origine)
					_localizzati[m] = copia
				gi.material_override = _localizzati[m]
	for c in n.get_children():
		_localizza(c)
