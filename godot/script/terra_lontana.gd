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
	# centinaia di pezzi (portali, gradinate, parapetto, pinnacoli) diventano poche mesh, una per materiale
	for nome in ["Arrivo", "Rovine", "Arena"]:
		var n := get_node_or_null(nome)
		if n != null:
			Edifici.fondi(n, 0.0)


func _tema(chiave: String, predefinito := Color.WHITE) -> Color:
	var v = def.tema.get(chiave)
	return Color(String(v)) if v != null else predefinito


func _suolo(lx: float, lz: float) -> Vector3:
	var x := float(def.cx) + lx
	var z := float(def.cz) + lz
	return Vector3(x, Mappe.altezza(x, z), z)


# ------------------------------------------------------------------ terreno
## Stessa tecnica del mondo dei regni (terreno.gdshader): otto materiali dipinti presi dai due atlanti e due texture
## di pesi, calcolate qui una volta per mappa (1 px = 2 m) da pendenza, quota, rumore, sentieri e piante.
## Prima ogni punto dello schermo calcolava una decina di rumori (il vecchio terreno_mappa.gdshader, tolto).
const STRATI := {
	# 0 = materiale di fondo; poi pesi_a.rgba = 1-4, pesi_b.rgb = 5-7
	"selva": ["m0", "m1", "m2", "t2", "t4", "m3", "t0", "t7"],     # muschio, foglie di bambù, terra umida, sottobosco, sentiero, roccia muschiosa, radure, lastricato
	"distesa": ["m4", "m6", "m7", "t1", "t4", "m5", "t5", "t7"],   # sabbia rossa, argilla crepata, ghiaia, erba secca, pista, arenaria, roccia, lastricato
	"arena": ["t0", "t1", "t2", "t3", "t4", "t5", "t6", "t7"],     # come il mondo dei regni
}
static var _materiali: Dictionary = {}     # id → ShaderMaterial (i pesi si calcolano una volta sola)


func _terreno() -> void:
	if not _materiali.has(id):
		var t0 := Time.get_ticks_msec()
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shader/terreno.gdshader")
		var meta := float(def.griglia.lato - 1) * float(def.griglia.passo) * 0.5
		var pesi := _pesi(meta)
		mat.set_shader_parameter("pesi_a", ImageTexture.create_from_image(pesi[0]))
		mat.set_shader_parameter("pesi_b", ImageTexture.create_from_image(pesi[1]))
		mat.set_shader_parameter("meta", meta)
		mat.set_shader_parameter("centro", Vector2(float(def.cx), float(def.cz)))
		mat.set_shader_parameter("strati", Mondo.strati_da(STRATI.get(id, STRATI.arena)))
		mat.set_shader_parameter("variazione", Mondo._immagine("res://texture/variazione.png"))
		_materiali[id] = mat
		print("Terreno di %s: pesi in %d ms" % [id, Time.get_ticks_msec() - t0])
	var mat: ShaderMaterial = _materiali[id]
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


## Pesi dei materiali: due immagini RGBA con un pixel ogni PASSO_PESI metri (gli stessi punti della griglia delle
## altezze), centrate sulla mappa. Le regole cambiano per mappa; dove due materiali si contendono un punto vince quello
## che viene dopo in «ordine» (rocce e lastricato sopra a tutto). I confini restano netti lo stesso: nello shader
## l'altezza dipinta di ogni materiale decide il bordo («incastro»).
const PASSO_PESI := 2.0

func _pesi(meta: float) -> Array:
	var arr := Mappe.griglia(id)
	var gl := int(def.griglia.lato)
	var lato := int(round(meta * 2.0 / PASSO_PESI))
	var n := lato * lato
	# rumori calcolati in blocco dal motore (molto più rapidi che punto per punto), frequenze in cicli per metro
	var r1 := _rumore(lato, 0.018 * PASSO_PESI, 11)    # chiazze larghe
	var r2 := _rumore(lato, 0.05 * PASSO_PESI, 23)     # chiazze medie
	var r3 := _rumore(lato, 0.03 * PASSO_PESI, 37)
	var r4 := _rumore(lato, 0.11 * PASSO_PESI, 41)     # bordi frastagliati
	# densità delle piante (lettiera sotto i bambù, erba secca attorno ai cespugli, terra sotto gli alberi)
	var veg: Dictionary = def.vegetazione
	var dens_a := PackedFloat32Array()
	var dens_b := PackedFloat32Array()
	dens_a.resize(n)
	dens_b.resize(n)
	match id:
		"selva":
			_spargi(dens_a, lato, meta, veg.get("bambu", []), 3.5)
			_spargi(dens_b, lato, meta, veg.get("pino", []) + veg.get("acero", []), 4.0)
		"distesa":
			_spargi(dens_a, lato, meta, veg.get("cespuglio", []) + veg.get("acero", []) + veg.get("pino", []), 4.5)
			_spargi(dens_b, lato, meta, veg.get("roccia", []), 2.6)
		_:
			_spargi(dens_a, lato, meta, veg.get("ciliegio", []) + veg.get("pino", []), 5.0)
	# sentieri serpeggianti: dall'arrivo al centro e dal centro agli obelischi
	var tratti: Array = []
	var arrivo := Vector2(INF, INF)
	if def.has("arrivo"):
		arrivo = Vector2(float(def.arrivo.x), float(def.arrivo.z))
		tratti.append([arrivo, Vector2.ZERO])
		for o in def.get("obelischi", []):
			tratti.append([Vector2.ZERO, Vector2(float(o[1]), float(o[2]))])
	var rp := float(def.get("sicuro", 0)) + 4.0
	var quota := float(def.tema.get("quotaRoccia", 30))
	var R := float(def.raggio)
	var arena := String(def.tipo) == "arena"
	var porte := int(def.get("porte", 0))
	var dn := float(def.get("distNicchia", 0))
	var dirs: Array[Vector2] = []
	for p in range(porte):
		dirs.append(Vector2(sin(Mappe.angolo_porta(p)), cos(Mappe.angolo_porta(p))))
	# dal basso verso l'alto (indici di w = strato - 1): nella Selva le radure stanno sotto a tutto
	var ordine := PackedInt32Array([5, 2, 1, 0, 3, 4, 6] if id == "selva" else [0, 1, 2, 3, 4, 5, 6])
	var w := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0])
	var pa := PackedByteArray()
	var pb := PackedByteArray()
	pa.resize(n * 4)
	pb.resize(n * 4)
	for j in range(lato):
		var gj := mini(j, gl - 1)
		for i in range(lato):
			var k := j * lato + i
			var gi := mini(i, gl - 1)
			var gk := gj * gl + gi
			var l := Vector2((i + 0.5) * PASSO_PESI - meta, (j + 0.5) * PASSO_PESI - meta)
			var h := arr[gk]
			var dx := arr[gk + 1] - arr[gk - 1] if gi > 0 and gi < gl - 1 else 0.0
			var dz := arr[gk + gl] - arr[gk - gl] if gj > 0 and gj < gl - 1 else 0.0
			var pend := sqrt(dx * dx + dz * dz) / (2.0 * PASSO_PESI)
			var n1 := r1[k]
			var n2 := r2[k]
			var n3 := r3[k]
			var n4 := r4[k]
			for c in range(7):
				w[c] = 0.0
			var roccia := clampf(smoothstep(0.42, 0.7, pend + (n2 - 0.5) * 0.25) + smoothstep(quota, quota + 8.0, h), 0.0, 1.0)
			var sentiero := 0.0
			if not tratti.is_empty():
				var q := l + Vector2(sin(l.y * 0.045) * 6.0, cos(l.x * 0.04) * 4.0)
				for t in tratti:
					sentiero = maxf(sentiero, 1.0 - smoothstep(1.2 + n4 * 0.8, 2.8 + n4 * 1.6, _dist_tratto(q, t[0], t[1])))
			var piazza := 0.0
			if not arena:
				piazza = 1.0 - smoothstep(rp - 3.0 + n4 * 2.0, rp + 1.0 + n4 * 2.0, l.distance_to(arrivo))
			if id == "selva":
				w[5] = smoothstep(0.64, 0.8, n1) * smoothstep(R * 0.3, R * 0.5, l.length()) * 0.75          # radure
				w[2] = smoothstep(0.5, 0.68, n3) * 0.75 + smoothstep(0.1, 0.6, dens_b[k]) * 0.6                # sottobosco
				w[1] = smoothstep(0.6, 0.72, n2) * (1.0 - smoothstep(0.08, 0.3, pend)) * 0.9                # terra umida
				w[0] = maxf(smoothstep(0.08, 0.55, dens_a[k] + (n4 - 0.5) * 0.3), smoothstep(0.62, 0.78, n3) * 0.6)   # foglie di bambù
				w[3] = sentiero * 0.95
				w[4] = roccia
			elif id == "distesa":
				w[0] = smoothstep(0.55, 0.7, n1) * (1.0 - smoothstep(0.05, 0.16, pend))                      # argilla crepata nei piani
				w[1] = smoothstep(0.58, 0.72, n2) * 0.85                                                     # ghiaia
				w[2] = smoothstep(0.1, 0.6, dens_a[k] + (n4 - 0.5) * 0.4) * 0.8                             # erba secca
				w[3] = sentiero * 0.9
				w[4] = maxf(roccia, smoothstep(0.62, 0.74, n3) * smoothstep(R * 0.4, R * 0.7, l.length()) * 0.7)   # arenaria
				w[5] = maxf(smoothstep(0.6, 0.95, pend), smoothstep(0.2, 0.7, dens_b[k]) * 0.85)             # roccia viva
			else:
				var rl := l.length()
				var viale := 0.0
				for d in dirs:
					if l.dot(d) > dn:
						viale = maxf(viale, 1.0 - smoothstep(2.2 + n4, 3.6 + n4 * 1.5, absf(l.dot(Vector2(d.y, -d.x)))))
				var anello := 1.0 - smoothstep(2.0 + n4, 3.6 + n4 * 1.5, absf(rl - 84.0))
				w[0] = smoothstep(0.55, 0.7, n1) * 0.8                                                       # erba secca
				w[1] = smoothstep(0.15, 0.6, dens_a[k] + (n4 - 0.5) * 0.3) * 0.8                             # sotto gli alberi
				w[3] = maxf(viale, anello) * 0.95                                                            # viali e anello
				w[4] = roccia
				w[6] = 1.0 - smoothstep(73.0 + n4 * 2.0, 76.0 + n4 * 2.0, rl)                               # attorno all'arena
			w[6] = maxf(w[6], piazza)
			# priorità: ogni strato copre quelli che vengono prima di lui in «ordine»
			for a in range(5, -1, -1):
				var basso := ordine[a]
				for b in range(a + 1, 7):
					w[basso] *= 1.0 - w[ordine[b]]
			for c in range(4):
				pa[k * 4 + c] = int(clampf(w[c], 0.0, 1.0) * 255.0)
			for c in range(3):
				pb[k * 4 + c] = int(clampf(w[4 + c], 0.0, 1.0) * 255.0)
			pb[k * 4 + 3] = 255
	return [Image.create_from_data(lato, lato, false, Image.FORMAT_RGBA8, pa), Image.create_from_data(lato, lato, false, Image.FORMAT_RGBA8, pb)]


## Rumore 0..1 a lato x lato pixel, calcolato dal motore in un colpo solo (freq in cicli per pixel).
func _rumore(lato: int, freq: float, seme: int) -> PackedFloat32Array:
	var rumore := FastNoiseLite.new()
	rumore.seed = seme + hash(id) % 1000
	rumore.frequency = freq
	rumore.fractal_octaves = 3
	var dati := rumore.get_image(lato, lato, false, false, true).get_data()     # L8, già normalizzato 0..255
	var out := PackedFloat32Array()
	out.resize(lato * lato)
	for k in range(lato * lato):
		out[k] = dati[k] / 255.0
	return out


## Somma di «macchie» morbide attorno a ogni pianta (coordinate del mondo → pixel dei pesi).
func _spargi(dens: PackedFloat32Array, lato: int, meta: float, piante: Array, raggio: float) -> void:
	var rpx := raggio / PASSO_PESI
	var r := int(ceil(rpx))
	for e in piante:
		var px := (float(e[0]) - float(def.cx) + meta) / PASSO_PESI
		var pz := (float(e[2]) - float(def.cz) + meta) / PASSO_PESI
		for dj in range(-r, r + 1):
			var j := int(round(pz)) + dj
			if j < 0 or j >= lato:
				continue
			for di in range(-r, r + 1):
				var i := int(round(px)) + di
				if i < 0 or i >= lato:
					continue
				var d := Vector2(i + 0.5 - px, j + 0.5 - pz).length() / rpx
				if d < 1.0:
					dens[j * lato + i] += (1.0 - d * d) * 0.45


static func _dist_tratto(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-4), 0.0, 1.0)
	return p.distance_to(a + ab * t)


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


const VISTA := {"bambu": 170.0, "cespuglio": 110.0, "pino": 230.0, "acero": 200.0, "ciliegio": 220.0}


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
				Mondo.semina(self, _forme.get("roccia_%d" % (v + 1)), roccia, parte, 1.2, 0.15, [], true, 200.0)
			continue
		var tinte: Array = []
		for c in tinte_tema.get(specie, ["#ffffff"]):
			tinte.append(Color(String(c)))
		# a zolle con distanza di vista (come il mondo dei regni): i bambù della Selva sono migliaia
		var vista: float = VISTA.get(specie, 220.0)
		# i fusti dei bambù (1400 triangoli l'uno, migliaia nella Selva) non fanno ombra e si vedono fino a 120 m:
		# più in là, nella nebbia, bastano le chiome
		var bambu: bool = specie == "bambu"
		Mondo.semina(self, _forme.get(specie + "_tronco"), corteccia, arr, 1.0, 0.0, [], specie != "cespuglio" and not bambu, 120.0 if bambu else minf(vista, 170.0))
		Mondo.semina(self, _forme.get(specie + "_chioma"), chioma, arr, 1.0, 0.0, tinte, true, vista)


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
	var rovine := Node3D.new()
	rovine.name = "Rovine"
	rovine.position = origine
	add_child(rovine)
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
		p.position = _suolo(lx, lz) - origine - Vector3(0, 0.3, 0)
		p.rotation = Vector3(rng.randf_range(-0.05, 0.05), rng.randf() * TAU, rng.randf_range(-0.06, 0.06))
		rovine.add_child(p)
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
		pin.position = _suolo(lx, lz) - origine + Vector3(0, alto * 0.45, 0)
		pin.rotation = Vector3(rng.randf_range(-0.08, 0.08), rng.randf() * TAU, rng.randf_range(-0.08, 0.08))
		rovine.add_child(pin)
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
			cap.transform = pin.transform * Transform3D(Basis.IDENTITY, Vector3(0, alto * 0.5 + 0.6, 0))
			rovine.add_child(cap)


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
