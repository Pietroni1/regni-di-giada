class_name Mondo
extends Node3D
## Il mondo statico: terreno, acqua, vegetazione e i tre villaggi. Tutto è ricavato dai dati esportati dal server.

const CELLE_PER_PEZZO := 50

var _mat_terreno: ShaderMaterial


func _ready() -> void:
	_terreno()
	_acqua()
	_vegetazione()
	for kid in Dati.KINGDOMS:
		_villaggio(kid)
	_altopiano()


# ------------------------------------------------------------------ terreno
func _terreno() -> void:
	_mat_terreno = ShaderMaterial.new()
	_mat_terreno.shader = preload("res://shader/terreno.gdshader")
	_mat_terreno.set_shader_parameter("pesi_a", ImageTexture.create_from_image(Dati.pesi_a))
	_mat_terreno.set_shader_parameter("pesi_b", ImageTexture.create_from_image(Dati.pesi_b))
	_mat_terreno.set_shader_parameter("meta", Dati.meta)
	var n := Dati.lato_h - 1
	var passo := Dati.passo_h
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
					var x := -Dati.meta + (i0 + i) * passo
					var z := -Dati.meta + (j0 + j) * passo
					vert.append(Vector3(x, Dati.altezza(x, z), z))
					var dx := Dati.altezza(x + passo, z) - Dati.altezza(x - passo, z)
					var dz := Dati.altezza(x, z + passo) - Dati.altezza(x, z - passo)
					norm.append(Vector3(-dx, 2.0 * passo, -dz).normalized())
			for j in range(nj):
				for i in range(ni):
					var a := j * (ni + 1) + i
					var b := a + 1
					var c := a + ni + 1
					var d := c + 1
					ind.append_array([a, b, c, b, d, c])
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = vert
			arr[Mesh.ARRAY_NORMAL] = norm
			arr[Mesh.ARRAY_INDEX] = ind
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var mi := MeshInstance3D.new()
			mi.name = "Terreno_%d_%d" % [pi, pj]
			mi.mesh = mesh
			mi.material_override = _mat_terreno
			add_child(mi)


func _acqua() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Acqua"
	var p := PlaneMesh.new()
	p.size = Vector2(1400, 1400)
	mi.mesh = p
	var m := ShaderMaterial.new()
	m.shader = preload("res://shader/acqua.gdshader")
	mi.material_override = m
	mi.position.y = -0.05
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ------------------------------------------------------------------ vegetazione
const TINTE := {
	"pino": [Color(0.85, 1.0, 0.85), Color(1.0, 1.05, 0.9), Color(0.9, 1.0, 1.0)],
	"ciliegio": [Color(1, 1, 1), Color(1.05, 0.95, 1), Color(0.95, 0.92, 0.98)],
	"acero": [Color(1, 1, 1), Color(1.1, 1.0, 0.8), Color(0.9, 0.85, 0.85)],
	"bambu": [Color(1, 1, 1), Color(0.9, 1.05, 0.9)],
	"cespuglio": [Color(1, 1, 1), Color(1.1, 1.05, 0.85), Color(0.85, 1, 0.95)],
}


func _vegetazione() -> void:
	var scena: PackedScene = load("res://modelli/natura.glb")
	if scena == null:
		push_warning("natura.glb non importato: apri il progetto nell'editor una volta.")
		return
	var radice := scena.instantiate()
	var forme := {}
	for n in radice.find_children("*", "MeshInstance3D", true, false):
		forme[String(n.name)] = (n as MeshInstance3D).mesh
	radice.free()
	var chioma := ShaderMaterial.new()
	chioma.shader = preload("res://shader/chioma.gdshader")
	var corteccia := ShaderMaterial.new()
	corteccia.shader = preload("res://shader/corteccia.gdshader")
	var roccia := ShaderMaterial.new()
	roccia.shader = preload("res://shader/roccia.gdshader")
	var liste: Dictionary = Dati.gioco.vegetazione
	for specie in TINTE:
		var arr: Array = liste.get(specie, [])
		if arr.is_empty():
			continue
		_semina(forme.get(specie + "_tronco"), corteccia, arr, 1.0, 0.0, [], specie != "cespuglio")
		_semina(forme.get(specie + "_chioma"), chioma, arr, 1.0, 0.0, TINTE[specie], true)
	var rocce: Array = liste.get("roccia", [])
	for v in range(3):
		var parte := []
		for i in range(rocce.size()):
			if i % 3 == v:
				parte.append(rocce[i])
		_semina(forme.get("roccia_%d" % (v + 1)), roccia, parte, 1.1, 0.15, [], true)


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


# ------------------------------------------------------------------ villaggi
func _villaggio(kid: String) -> void:
	var k: Dictionary = Dati.KINGDOMS[kid]
	var f: Dictionary = Dati.gioco.villaggi[kid]
	var disp: Dictionary = Dati.gioco.VILLAGE_LAYOUT
	var tetto_col := Dati.colore(k.roof)
	var accento := Dati.colore(k.hex)
	var y0 := float(Dati.costanti.VILLAGE_HEIGHT)
	var radice := Node3D.new()
	radice.name = "Villaggio_" + kid
	radice.position = Vector3(f.x, y0, f.z)
	radice.rotation.y = f.a
	add_child(radice)

	for b in disp.buildings:
		var ruotata := absf(absf(float(b.face)) - PI / 2.0) < 0.1
		var w: float = b.d if ruotata else b.w
		var d: float = b.w if ruotata else b.d
		var m: Node3D
		match String(b.kind):
			"pagoda": m = Edifici.pagoda(float(b.w) - 1.0, tetto_col, accento)
			"forge": m = Edifici.fucina(w, d, tetto_col)
			"hall": m = Edifici.casa(w, d, tetto_col, 3.2, 2.8)
			_: m = Edifici.casa(w, d, tetto_col)
		m.position = Vector3(b.x, 0, b.z)
		m.rotation.y = float(b.face)
		radice.add_child(m)

	var teli := {"armi": Color(0.62, 0.16, 0.14), "erbe": Color(0.20, 0.46, 0.26)}
	for s in disp.stalls:
		var banco := Edifici.bancarella(teli.get(String(s.role), accento))
		banco.position = Vector3(s.x, 0, s.z)
		radice.add_child(banco)

	var pz := Edifici.pozzo()
	pz.position = Vector3(disp.well.x, 0, disp.well.z)
	radice.add_child(pz)

	var i := 0
	for l in disp.lanterns:
		var lan := Edifici.lanterna(i % 2 == 0)
		lan.position = Vector3(l[0], 0, l[1])
		radice.add_child(lan)
		i += 1

	# mura: un tratto per ogni angolo esportato (le porte sono i vuoti)
	var R := float(Dati.costanti.WALL_RADIUS)
	var passo_ang := TAU / 64.0
	for a in Dati.gioco.mura:
		var tr := Edifici.tratto_mura(R * passo_ang + 0.25, tetto_col)
		tr.position = Vector3(sin(a) * R, 0, cos(a) * R)
		tr.rotation.y = a
		radice.add_child(tr)
	for a in disp.gates:
		var luce: float = R * float(disp.gateHalf) * 2.0 + 1.2
		var p := Edifici.porta(luce, tetto_col, accento)
		p.position = Vector3(sin(a) * R, 0, cos(a) * R)
		p.rotation.y = a
		radice.add_child(p)

	# stendardi del regno ai lati della piazza
	for sx in [-1.0, 1.0]:
		var asta := Edifici.cilindro(0.07, 0.09, 6.0, Vector3(sx * 7.5, 3.0, 31.0), Edifici.mat(Edifici.LEGNO, 0.8), radice, 8)
		Edifici.scatola(Vector3(0.9, 2.6, 0.04), Vector3(0.52, 1.5, 0), Edifici.mat(accento, 0.85), asta)


# ------------------------------------------------------------------ altopiano centrale
func _altopiano() -> void:
	# «Altopiano delle Spade Spezzate»: un cerchio di grandi lame di pietra piantate nel terreno.
	var c: Dictionary = Dati.costanti.CENTER
	var pietra := ShaderMaterial.new()
	pietra.shader = preload("res://shader/roccia.gdshader")
	for i in range(9):
		var a := TAU * i / 9.0 + 0.3
		var r := 22.0 + (i % 3) * 2.5
		var x: float = float(c.x) + cos(a) * r
		var z: float = float(c.z) + sin(a) * r
		var h := 7.0 + (i * 37 % 5) * 1.3
		var lama := MeshInstance3D.new()
		var b := PrismMesh.new()
		b.size = Vector3(1.6, h, 0.5)
		lama.mesh = b
		lama.material_override = pietra
		lama.position = Vector3(x, Dati.altezza(x, z) + h * 0.42, z)
		lama.rotation = Vector3(0.12 * sin(i * 2.1), a, 0.18 * cos(i * 1.7))
		add_child(lama)
