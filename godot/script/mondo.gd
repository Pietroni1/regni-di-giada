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
	_mat_terreno.set_shader_parameter("strati", strati_terreno())
	_mat_terreno.set_shader_parameter("variazione", _immagine("res://texture/variazione.png"))
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


## Immagine letta come file (non come risorsa importata): funziona anche senza passare dall'editor.
static func _immagine(percorso: String) -> ImageTexture:
	var img := Image.new()
	img.load_png_from_buffer(FileAccess.get_file_as_bytes(percorso))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Gli 8 materiali dipinti del terreno: l'atlante 4 x 2 di texture/terreno.png diventa una pila di texture con mipmap.
static var _strati: Texture2DArray = null
static func strati_terreno() -> Texture2DArray:
	if _strati == null:
		_strati = strati_da(["t0", "t1", "t2", "t3", "t4", "t5", "t6", "t7"])
	return _strati


## Riquadri dei due atlanti già tagliati (con mipmap): «t3» = riquadro 3 di terreno.png, «m5» = riquadro 5 di
## terreno_mappe.png (materiali delle mappe lontane, tools/godot/texture_terreno.py).
static var _riquadri: Dictionary = {}
static func _riquadro(nome: String) -> Image:
	if not _riquadri.has(nome):
		var file := "res://texture/terreno.png" if nome.begins_with("t") else "res://texture/terreno_mappe.png"
		var atl := Image.new()
		atl.load_png_from_buffer(FileAccess.get_file_as_bytes(file))
		var lato := atl.get_width() / 4
		for k in range(8):
			var im := atl.get_region(Rect2i((k % 4) * lato, (k / 4) * lato, lato, lato))
			im.generate_mipmaps()
			_riquadri[nome.substr(0, 1) + str(k)] = im
	return _riquadri[nome]


## Pila di 8 materiali scelti fra i due atlanti (l'ordine è quello dei pesi in terreno.gdshader).
static func strati_da(nomi: Array) -> Texture2DArray:
	var lista: Array[Image] = []
	for n in nomi:
		lista.append(_riquadro(String(n)))
	var t := Texture2DArray.new()
	t.create_from_images(lista)
	return t


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
		var vista := 130.0 if specie == "cespuglio" else 240.0
		_semina(forme.get(specie + "_tronco"), corteccia, arr, 1.0, 0.0, [], specie != "cespuglio", minf(vista, 170.0))
		_semina(forme.get(specie + "_chioma"), chioma, arr, 1.0, 0.0, TINTE[specie], true, vista)
	var rocce: Array = liste.get("roccia", [])
	for v in range(3):
		var parte := []
		for i in range(rocce.size()):
			if i % 3 == v:
				parte.append(rocce[i])
		_semina(forme.get("roccia_%d" % (v + 1)), roccia, parte, 1.1, 0.15, [], true, 190.0)


## Le piante si dividono in zolle di ZOLLA metri: così quelle fuori vista o lontane non vengono disegnate
## (prima ogni specie era un blocco unico, disegnato sempre per intero anche nelle ombre). Usata anche dalle mappe lontane.
const ZOLLA := 64.0

func _semina(forma: Mesh, materiale: Material, tutte: Array, scala: float, alza: float, tinte: Array, ombra: bool, vista := 240.0) -> void:
	semina(self, forma, materiale, tutte, scala, alza, tinte, ombra, vista)


static func semina(genitore: Node3D, forma: Mesh, materiale: Material, tutte: Array, scala: float, alza: float, tinte: Array, ombra: bool, vista := 240.0) -> void:
	if forma == null or tutte.is_empty():
		return
	var zolle := {}
	for e in tutte:
		var chiave := Vector2i(int(floor(float(e[0]) / ZOLLA)), int(floor(float(e[2]) / ZOLLA)))
		if not zolle.has(chiave):
			zolle[chiave] = []
		zolle[chiave].append(e)
	for chiave in zolle:
		_semina_zolla(genitore, forma, materiale, zolle[chiave], scala, alza, tinte, ombra, vista)


static func _semina_zolla(genitore: Node3D, forma: Mesh, materiale: Material, arr: Array, scala: float, alza: float, tinte: Array, ombra: bool, vista: float) -> void:
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
	mi.visibility_range_end = vista
	mi.visibility_range_end_margin = 12.0
	genitore.add_child(mi)


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
			"forge": m = Edifici.fucina(w, d, tetto_col, accento)
			"hall": m = Edifici.casa(w, d, tetto_col, 3.2, 2.8, accento)
			_: m = Edifici.casa(w, d, tetto_col, 2.8, 2.4, accento)
		m.position = Vector3(b.x, 0, b.z)
		m.rotation.y = float(b.face)
		radice.add_child(m)

	var teli := {"armi": Color(0.62, 0.16, 0.14), "erbe": Color(0.20, 0.46, 0.26)}
	for s in disp.stalls:
		var banco := Edifici.bancarella(teli.get(String(s.role), accento), String(s.role))
		banco.position = Vector3(s.x, 0, s.z)
		radice.add_child(banco)

	# piazza: lastricato con cordolo e, al posto del pozzo (stesso ostacolo), un elemento diverso per regno
	var piazza := Vector3(disp.well.x, 0, disp.well.z)
	Edifici.piazzale(6.5, piazza, radice)
	var cp := Edifici.centro_piazza(kid, accento)
	cp.position = piazza
	radice.add_child(cp)

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

	_dettagli_villaggio(radice, kid, disp, tetto_col, accento)
	# stendardi del regno ai lati della piazza
	for sx in [-1.0, 1.0]:
		var asta := Edifici.cilindro(0.07, 0.09, 6.0, Vector3(sx * 10.5, 3.0, 36.5), Edifici.legno(Edifici.LEGNO), radice, 8)
		Edifici.scatola(Vector3(0.9, 2.6, 0.04), Vector3(0.52, 1.5, 0), Edifici.mat(accento, 0.85), asta)
	# centinaia di pezzi (travi, muri, coppi) diventano poche mesh, una per materiale
	Edifici.fondi(radice, 330.0)


## Torri, lanterne appese, merci e alberi in vaso. Tutto sta sopra ostacoli che il server conosce già (mura, case)
## o in alto: niente di nuovo blocca la vista dove si cammina liberamente.
func _dettagli_villaggio(radice: Node3D, kid: String, disp: Dictionary, tetto_col: Color, accento: Color) -> void:
	var R := float(Dati.costanti.WALL_RADIUS)
	var mura: Array = Dati.gioco.mura
	# torri: ai lati di ogni porta (sui primi tratti di mura) e qualcuna lungo il giro; centrate su un tratto (raggio ≤ 2 m)
	var torri: Array = []
	for g in disp.gates:
		for s in [-1.0, 1.0]:
			torri.append([_angolo_mura(mura, float(g) + s * 0.25), 8.6])
	for a in [0.74, -0.74, 3.09]:
		torri.append([_angolo_mura(mura, a), 7.4])
	for t in torri:
		var a: float = t[0]
		var tr := Edifici.torre(t[1], tetto_col, accento)
		tr.position = Vector3(sin(a) * R, 0, cos(a) * R)
		tr.rotation.y = a
		radice.add_child(tr)
		for lato in [0.0, PI]:
			var faccia := Node3D.new()
			faccia.rotation.y = lato
			tr.add_child(faccia)
			Edifici.stendardo(Vector3(0, float(t[1]) - 1.9, 1.98), 2.6, accento, faccia)
	# fili di lanterne di carta fra le gronde delle case (sopra la testa)
	var colori := [Edifici.CARTA, accento.lerp(Color(1, 0.95, 0.85), 0.35)]
	var case_x := 18.4
	for z in [14.0, -11.0]:
		Edifici.filo_lanterne(Vector3(-case_x + 1.2, 3.35, z), Vector3(case_x - 1.2, 3.35, z), 7, colori, radice, 0.45)
	for sx in [-1.0, 1.0]:
		Edifici.filo_lanterne(Vector3(sx * (case_x - 1.0), 3.35, -5.0), Vector3(sx * (case_x - 1.0), 3.35, 8.0), 4, colori, radice, 0.35)
	# casse, botti e alberi in vaso a ridosso delle mura, dentro l'ostacolo dei tratti (fra 38 e 39,2 m dal centro)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kid)
	var k := 0
	for a in [0.5, -0.5, 1.0, -1.0, 2.05, -2.05, 2.7, -2.7, 2.85, -2.85]:
		var dir := Vector3(sin(a), 0, cos(a))
		var lat := Vector3(cos(a), 0, -sin(a))
		var c := dir * 38.75
		match k % 3:
			0:
				Edifici.cassa(c - lat * 0.55, 0.8, a + rng.randf_range(-0.2, 0.2), radice)
				Edifici.botte(c + lat * 0.5, radice)
				Edifici.cassa(c - lat * 0.55 + Vector3(0, 0.64, 0), 0.55, a + rng.randf_range(-0.5, 0.5), radice)
			1:
				Edifici.albero_vaso(c, rng.randi(), radice)
			_:
				Edifici.botte(c - lat * 0.45, radice)
				Edifici.botte(c + lat * 0.4, radice)
				Edifici.cassa(c + lat * 1.3, 0.75, a, radice)
		k += 1


## L'angolo di un tratto di mura più vicino ad «a» (le torri stanno sugli ostacoli dei tratti).
static func _angolo_mura(mura: Array, a: float) -> float:
	var meglio := a
	var d := INF
	for m in mura:
		var x := absf(angle_difference(float(m), a))
		if x < d:
			d = x
			meglio = float(m)
	return meglio


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
