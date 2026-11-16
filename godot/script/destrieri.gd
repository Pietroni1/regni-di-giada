class_name Destrieri
## Destrieri per classe e livello (modelli/destrieri.glb, fatto da tools/blender/destrieri.py).
## Ogni classe ha il suo cavallo (corporatura, mantello, crini, bardatura); la bardatura cresce in quattro passi col
## livello del destriero (1-5, 6-12, 13-19, 20) e al livello massimo si accendono gli effetti del tema della classe:
## Lama = fulmine, Ombra = fumo e sagome, Monaco = fiamma del chi, Mistico = stelle.
##   var d := Destrieri.crea("lama", 20, colore_del_regno)     → Destrieri.Destriero (un Personaggio)
##   d.muovi(velocita, dt) · d.impenna() · d.posto() = dove siede il cavaliere

const PASSI := [1, 6, 13, 20]
const NOMI_PASSI := ["Puledro", "Destriero", "Destriero da battaglia", "Destriero leggendario"]

## Mantello e materiali per classe. I colori dei finimenti che non compaiono restano quelli dello shader.
const CLASSI := {
	"lama": {
		"nome": "Destriero da guerra", "taglia": 1.05, "motivo": 0,
		"pelo": Color(0.2, 0.095, 0.05), "criniera": Color(0.035, 0.03, 0.03), "punte": 1.0, "stella": 0.75,
		"balzane": [0.27, 0.0, 0.25, 0.3], "zoccoli": Color(0.12, 0.1, 0.08),
		"cuoio": Color(0.2, 0.1, 0.06), "metallo": Color(0.34, 0.35, 0.38), "stoffa": Color(0.42, 0.07, 0.05), "lacca": Color(0.5, 0.05, 0.04),
		"lamelle": Color(0.45, 0.06, 0.045), "oro": Color(0.85, 0.62, 0.25),
		"tema": "fulmine", "luce1": Color(0.4, 0.72, 1.0), "luce2": Color(0.92, 0.97, 1.0), "forza_luce": 1.5, "occhi_luce": 0.0,
	},
	"ombra": {
		"nome": "Corsiero d'ombra", "taglia": 1.0, "motivo": 1,
		"pelo": Color(0.04, 0.04, 0.055), "pelo_chiaro": Color(0.06, 0.055, 0.075), "criniera": Color(0.015, 0.012, 0.02), "punte": 0.0, "stella": 0.0,
		"balzane": [0.0, 0.0, 0.0, 0.0], "zoccoli": Color(0.03, 0.03, 0.035), "occhi": Color(0.75, 0.35, 1.0), "occhi_luce": 2.2,
		"cuoio": Color(0.11, 0.09, 0.105), "metallo": Color(0.5, 0.5, 0.56), "stoffa": Color(0.36, 0.035, 0.06), "lacca": Color(0.1, 0.08, 0.12),
		"lamelle": Color(0.1, 0.09, 0.12), "oro": Color(0.55, 0.5, 0.6), "ricamo": Color(0.08, 0.06, 0.08), "corda": Color(0.4, 0.05, 0.07),
		"tema": "ombra", "luce1": Color(0.6, 0.28, 0.95), "luce2": Color(0.75, 1.0, 0.4), "forza_luce": 1.2, "bordo_col": Color(0.2, 0.09, 0.34),
	},
	"monaco": {
		"nome": "Sauro del tempio", "taglia": 0.98, "motivo": 2,
		"pelo": Color(0.46, 0.2, 0.07), "criniera": Color(0.74, 0.55, 0.3), "punte": 0.0, "stella": 1.0,
		"balzane": [0.33, 0.3, 0.36, 0.28], "zoccoli": Color(0.35, 0.27, 0.18),
		"cuoio": Color(0.3, 0.17, 0.08), "metallo": Color(0.8, 0.6, 0.25), "stoffa": Color(0.85, 0.4, 0.08), "lacca": Color(0.55, 0.12, 0.05),
		"corda": Color(0.75, 0.63, 0.42), "grani": Color(0.36, 0.14, 0.07), "oro": Color(0.9, 0.68, 0.25),
		"tema": "fiamma", "luce1": Color(1.0, 0.3, 0.04), "luce2": Color(1.0, 0.62, 0.16), "forza_luce": 1.0, "occhi_luce": 0.0,
	},
	"mistico": {
		"nome": "Bianco delle stelle", "taglia": 1.02, "motivo": 3,
		"pelo": Color(0.8, 0.8, 0.84), "pelo_chiaro": Color(0.9, 0.9, 0.93), "criniera": Color(0.9, 0.9, 0.96), "punte": 0.0, "stella": 0.0, "pomelli": 0.7,
		"balzane": [0.0, 0.0, 0.0, 0.0], "zoccoli": Color(0.5, 0.48, 0.45), "occhi": Color(0.05, 0.08, 0.2),
		"cuoio": Color(0.62, 0.5, 0.34), "metallo": Color(0.85, 0.66, 0.3), "stoffa": Color(0.16, 0.2, 0.5), "lacca": Color(0.2, 0.25, 0.55),
		"giada": Color(0.35, 0.78, 0.6), "oro": Color(0.9, 0.72, 0.32), "corda": Color(0.9, 0.88, 0.8),
		"tema": "astrale", "luce1": Color(0.6, 0.8, 1.0), "luce2": Color(1.0, 0.95, 0.75), "forza_luce": 1.3, "occhi_luce": 0.0,
	},
}
const STILI_LUCE := {"fulmine": 1, "ombra": 2, "fiamma": 3, "astrale": 4}
const AZIONI := ["fermo", "passo", "corsa", "impennata"]
const FILE := "destrieri"

static var _mat: Dictionary = {}
static var senza_effetti := false      # per le prove: niente effetti del livello massimo
static var _lib: Dictionary = {}


## Passo della bardatura (1-4) per il livello del destriero.
static func passo_di(livello: int) -> int:
	var p := 1
	for i in range(PASSI.size()):
		if livello >= int(PASSI[i]):
			p = i + 1
	return p


static func disponibile() -> bool:
	return ResourceLoader.exists("res://modelli/%s.glb" % FILE)


## Godot rinomina le ossa degli scheletri successivi al primo dello stesso file («hips_2», «hips_3»...):
## il suffisso di questo scheletro, da aggiungere ai nomi delle ossa.
static func suffisso(sk: Skeleton3D) -> String:
	for i in range(sk.get_bone_count()):
		var n := sk.get_bone_name(i)
		if n == "hips" or n.begins_with("hips_"):
			return n.trim_prefix("hips")
	return ""


static func osso(sk: Skeleton3D, nome: String) -> int:
	return sk.find_bone(nome + suffisso(sk))


## Materiali di una classe (corpo e finimenti), condivisi fra i destrieri uguali.
static func materiali(classe: String, regno: Color, acceso: bool, sk: Skeleton3D) -> Array:
	var chiave := "%s:%s:%s" % [classe, regno.to_html(false), acceso]
	if _mat.has(chiave):
		return _mat[chiave]
	var c: Dictionary = CLASSI[classe]
	var coppia: Array = []
	for nome in ["destriero", "destriero_finimenti"]:
		var m := ShaderMaterial.new()
		m.shader = load("res://shader/%s.gdshader" % nome)
		for k in ["pelo", "pelo_chiaro", "criniera", "zoccoli", "occhi", "pelle_scura", "cuoio", "metallo", "oro", "stoffa", "lacca", "giada",
				"corda", "grani", "lamelle", "carta", "ricamo", "punte", "stella", "pomelli", "motivo", "occhi_luce", "bordo_col"]:
			if c.has(k):
				m.set_shader_parameter(k, c[k])
		var b: Array = c.get("balzane", [0, 0, 0, 0])
		m.set_shader_parameter("balzane", Vector4(b[0], b[1], b[2], b[3]))
		m.set_shader_parameter("regno", regno)
		# punti della testa a riposo (lo shader lavora in: x, quota, lunghezza = −z di Godot)
		var it := osso(sk, "head")
		var im := osso(sk, "muso")
		if it >= 0 and im >= 0:
			var n := sk.get_bone_global_rest(it).origin
			var mu := sk.get_bone_global_rest(im).origin
			var nuca := Vector3(n.x, n.y, -n.z)
			var muso := Vector3(mu.x, mu.y, -mu.z)
			var hd := (muso - nuca).normalized()
			var hup := Vector3(0, -hd.z, hd.y)
			m.set_shader_parameter("fronte", nuca + hd * 0.08 + hup * 0.085)
			m.set_shader_parameter("muso", muso)
		if acceso:
			m.set_shader_parameter("stile_luce", int(STILI_LUCE.get(String(c.get("tema", "")), 0)))
			m.set_shader_parameter("luce1", c.get("luce1", Color.WHITE))
			m.set_shader_parameter("luce2", c.get("luce2", Color.WHITE))
			m.set_shader_parameter("forza_luce", float(c.get("forza_luce", 1.0)))
			if classe == "lama":
				m.set_shader_parameter("occhi", Color(0.6, 0.85, 1.0))
				m.set_shader_parameter("occhi_luce", 2.0)
			elif classe == "monaco":
				m.set_shader_parameter("occhi", Color(1.0, 0.6, 0.15))
				m.set_shader_parameter("occhi_luce", 2.0)
			elif classe == "mistico":
				m.set_shader_parameter("occhi", Color(0.7, 0.85, 1.0))
				m.set_shader_parameter("occhi_luce", 1.6)
		coppia.append(m)
	_mat[chiave] = coppia
	return coppia


static func _libreria(classe: String, ap: AnimationPlayer, sk: Skeleton3D) -> AnimationLibrary:
	if _lib.has(classe):
		return _lib[classe]
	var lib := AnimationLibrary.new()
	for nome in ap.get_animation_list():
		if not String(nome).begins_with(classe + "_"):
			continue
		var corta := String(nome).trim_prefix(classe + "_")
		if not corta in AZIONI:
			continue
		var a: Animation = ap.get_animation(nome).duplicate(true)
		for i in range(a.get_track_count() - 1, -1, -1):
			var nome_osso := String(a.track_get_path(i).get_concatenated_subnames())
			if sk.find_bone(nome_osso) < 0:
				a.remove_track(i)
			else:
				a.track_set_path(i, NodePath("%s_scheletro/Skeleton3D:%s" % [classe, nome_osso]))
		a.loop_mode = Animation.LOOP_NONE if corta == "impennata" else Animation.LOOP_LINEAR
		lib.add_animation(corta, a)
	_lib[classe] = lib
	return lib


## Il destriero di una classe al livello dato. regno = colore del regno (drappi, lacci). Null se manca il modello.
static func crea(classe: String, livello: int, regno := Color(0.5, 0.5, 0.5)) -> Destriero:
	if not CLASSI.has(classe):
		classe = "lama"
	if not disponibile():
		return null
	var c: Dictionary = CLASSI[classe]
	var p := Destriero.new()
	p.classe = classe
	p.livello = livello
	p.passo = passo_di(livello)
	var radice: Node3D = Personaggio._scena(FILE).instantiate()
	p.add_child(radice)
	for n in radice.get_children():
		if n is Node3D and String(n.name) != classe + "_scheletro" and not n is AnimationPlayer:
			radice.remove_child(n)
			n.free()
	var sk := radice.get_node_or_null(classe + "_scheletro/Skeleton3D") as Skeleton3D
	if sk == null:
		p.free()
		return null
	p.scheletro = sk
	var acceso := p.passo >= 4
	var mm := materiali(classe, regno, acceso, sk)
	for n in sk.get_children():
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		var nome := String(mi.name)
		if nome == classe:
			mi.material_override = mm[0]
			p.pelle = mi
			continue
		# finimenti «<classe>_tAB»: visibili dal passo A al passo B
		var coda := nome.get_slice("_t", 1)
		var da := int(coda.substr(0, 1))
		var a := int(coda.substr(1, 1))
		if p.passo < da or p.passo > a:
			sk.remove_child(mi)
			mi.free()
			continue
		mi.material_override = mm[1]
	var sorgente: AnimationPlayer = radice.find_children("*", "AnimationPlayer", true, false)[0]
	var lib := _libreria(classe, sorgente, sk)
	radice.remove_child(sorgente)
	sorgente.free()
	p.player = AnimationPlayer.new()
	radice.add_child(p.player)
	p.player.add_animation_library("", lib)
	p.taglia = float(c.get("taglia", 1.0)) * (0.94 + 0.03 * p.passo)
	radice.scale = Vector3.ONE * p.taglia
	p._radice = radice
	p._osso_sella = osso(sk, "sella")
	var testa := osso(sk, "head")
	p.altezza = (sk.get_bone_global_rest(testa).origin.y + 0.4) * p.taglia if testa >= 0 else 2.4
	p._suona("fermo", 0.0)
	if acceso and not senza_effetti:
		p.effetti = EffettiDestriero.new()
		p.effetti.prepara(p, c)
		p.add_child(p.effetti)
	return p


## Quota dei fianchi del cavaliere nella posa «sella» (per sederlo all'altezza giusta).
static func quota_seduta(cavaliere: Personaggio) -> float:
	if cavaliere == null or cavaliere.player == null or not cavaliere.player.has_animation("sella"):
		return 0.55
	var a := cavaliere.player.get_animation("sella")
	for i in range(a.get_track_count()):
		if a.track_get_type(i) == Animation.TYPE_POSITION_3D and String(a.track_get_path(i)).ends_with(":hips") and a.track_get_key_count(i) > 0:
			return (a.track_get_key_value(i, 0) as Vector3).y
	return 0.55


# ====================================================================== il destriero
class Destriero:
	extends Personaggio
	var classe := ""
	var livello := 1
	var passo := 1
	var taglia := 1.0
	var pelle: MeshInstance3D = null
	var effetti: EffettiDestriero = null
	var _radice: Node3D
	var _osso_sella := -1
	var _az := ""
	var _impennata := 0.0

	## Andatura dalla velocità (m/s): fermo, passo, galoppo. In sella si va a 12-16 m/s: il galoppo ha una falcata di
	## 6-7 metri in poco meno di mezzo secondo, come un cavallo vero lanciato.
	func muovi(velocita: float, dt: float) -> void:
		if player == null or morto:
			return
		_muove = velocita > 0.3
		if effetti != null:
			effetti.aggiorna(velocita, dt)
		if _impennata > 0.0:
			_impennata -= dt
			if _impennata > 0.0 and velocita < 4.0:
				return
			_impennata = 0.0
			_az = ""
		var voglio := "fermo"
		var ritmo := 1.0
		if velocita > 4.2:
			voglio = "corsa"
			ritmo = clampf(velocita / 13.5, 0.75, 1.2)
		elif velocita > 0.3:
			voglio = "passo"
			ritmo = clampf(velocita / 1.25, 0.6, 2.4)
		if voglio != _az:
			_az = voglio
			player.play(voglio, 0.22, ritmo)
		elif voglio != "fermo":
			player.speed_scale = ritmo

	## Impennata (alla salita in sella): poco più di un secondo, poi riprende l'andatura.
	func impenna() -> void:
		if player == null or not player.has_animation("impennata"):
			return
		_az = "impennata"
		player.speed_scale = 1.0
		player.play("impennata", 0.1, 1.0)
		_impennata = player.get_animation("impennata").length

	## Dove sta la sella, nello spazio del genitore del destriero (l'entità): origine sul seggio, assi inclinati come il dorso.
	func posto() -> Transform3D:
		if scheletro == null or _osso_sella < 0:
			return Transform3D(Basis.IDENTITY, Vector3(0, 1.6 * taglia, 0))
		var t := transform * _radice.transform * (scheletro.get_parent() as Node3D).transform * scheletro.transform
		var riposo := scheletro.get_bone_global_rest(_osso_sella)
		var ora := scheletro.get_bone_global_pose(_osso_sella)
		# rotazione del dorso rispetto al riposo (beccheggio del galoppo, impennata)
		var giro := (ora.basis * riposo.basis.inverse()).orthonormalized()
		return t * Transform3D(giro, ora.origin)


# ====================================================================== effetti del livello massimo
## Tutto ciò che si accende al livello 20: fiamme, saette, fumo, stelle, scie e sagome agganciate alle ossa del cavallo.
## Niente luci dinamiche e niente segni a terra; poche particelle per emettitore, il resto sono quadrati con uno shader.
class EffettiDestriero:
	extends Node3D
	var cavallo: Destriero
	var tema := ""
	var c1 := Color.WHITE
	var c2 := Color.WHITE
	var _in_corsa: Array = []        # emettitori accesi solo quando si corre
	var _da_fermo: Array = []        # nodi visibili solo da fermi o al passo
	var _scie: Array = []
	var _sagome: Array = []
	var _storia: Array = []          # trasformazioni passate della pelle (per le sagome)
	var _vel := 0.0
	var _n := 0

	func prepara(d: Destriero, c: Dictionary) -> void:
		cavallo = d
		tema = String(c.get("tema", ""))
		c1 = c.get("luce1", Color.WHITE)
		c2 = c.get("luce2", Color.WHITE)
		match tema:
			"fulmine": _fulmine()
			"ombra": _ombra()
			"fiamma": _fiamma()
			"astrale": _astrale()

	# ------------------------------------------------ agganci
	func _attacco(nome: String) -> BoneAttachment3D:
		var ba := BoneAttachment3D.new()
		ba.bone_name = nome + Destrieri.suffisso(cavallo.scheletro)
		cavallo.scheletro.add_child(ba)
		return ba

	func _riposo(nome: String) -> Transform3D:
		var i := Destrieri.osso(cavallo.scheletro, nome)
		return cavallo.scheletro.get_bone_global_rest(i) if i >= 0 else Transform3D.IDENTITY

	## Nodo appeso a un osso, nel punto dato nello spazio dello scheletro a riposo (x = lato, y = alto, z = avanti).
	func _presso(nome: String, punto: Vector3) -> Node3D:
		var n := Node3D.new()
		n.transform = Transform3D(Basis.IDENTITY, _riposo(nome).affine_inverse() * punto)
		_attacco(nome).add_child(n)
		return n

	## Punto lungo un osso (f = 0 alla testa dell'osso, 1 al figlio), spostato verso il dorso e di lato.
	func _lungo(nome: String, figlio: String, f: float, dorso := 0.0, lato := 0.0) -> Node3D:
		var a := _riposo(nome).origin
		var b := _riposo(figlio).origin
		var d := (b - a).normalized()
		var n := Vector3(0, d.z, -d.y)          # verso il dorso (cresta del collo, fronte)
		return _presso(nome, a.lerp(b, f) + n * dorso + Vector3(lato, 0, 0))

	func _zoccoli() -> Array:
		var out: Array = []
		for o in ["piede_aL", "piede_aR", "piede_pL", "piede_pR"]:
			out.append(_presso(o, _riposo(o).origin + Vector3(0, -0.13, 0.06)))
		return out

	## Quadrato con lo shader degli effetti (0 fiamma, 1 stella, 2 saette), appoggiato sulla base.
	func _quadro(genitore: Node3D, forma: int, misura: Vector2, col1: Color, col2: Color, forza := 1.2, pos := Vector3.ZERO) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = misura
		q.center_offset = Vector3(0, misura.y * (0.5 if forma != 1 else 0.0), 0)
		mi.mesh = q
		var m := ShaderMaterial.new()
		m.shader = load("res://shader/destriero_fx.gdshader")
		m.set_shader_parameter("forma", forma)
		m.set_shader_parameter("colore", col1)
		m.set_shader_parameter("colore2", col2)
		m.set_shader_parameter("forza", forza)
		_n += 1
		m.set_shader_parameter("fase", fmod(_n * 0.618, 1.0))
		mi.material_override = m
		mi.position = pos
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 1.0
		genitore.add_child(mi)
		return mi

	func _lume(genitore: Node3D, misura: float, c: Color, pos := Vector3.ZERO) -> MeshInstance3D:
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
		m.albedo_color = c
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mi.material_override = m
		mi.position = pos
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		genitore.add_child(mi)
		return mi

	func _scia(sorgente: Node3D, col1: Color, col2: Color, durata: float, tremito: float, alto: float, alfa := 0.8) -> void:
		var s := Scia.new(col1, col2, durata, tremito, alto)
		s.sorgente = sorgente
		s.alfa = alfa
		add_child(s)
		_scie.append(s)

	# ------------------------------------------------ Lama: saette agli zoccoli e lungo la criniera, scintille, scia elettrica
	func _fulmine() -> void:
		var oro := Color(1.0, 0.85, 0.45)
		var blu := Color(c1.r, c1.g, c1.b, 0.55)
		for z in _zoccoli():
			# ciuffo di saette che sale dallo zoccolo, alone azzurro, scintille al galoppo
			_quadro(z, 2, Vector2(0.55, 0.75), c1, c2, 1.5)
			_lume(z, 0.55, blu)
			var p := Equip.particelle(z, 9, 0.08, 0.45, c2, oro, 1.0)
			p.direction = Vector3(0, 1, 0)
			p.spread = 60.0
			p.initial_velocity_min = 1.5
			p.initial_velocity_max = 4.0
			p.gravity = Vector3(0, -9.0, 0)
			p.emitting = false
			_in_corsa.append(p)
		# archi che risalgono gli stinchi
		for coppia in [["stinco_aL", "piede_aL"], ["stinco_aR", "piede_aR"], ["stinco_pL", "piede_pL"], ["stinco_pR", "piede_pR"]]:
			var sa := Equip.Saette.new(c2, c1)
			sa.a = Vector3.ZERO
			sa.b = _riposo(coppia[0]).affine_inverse() * _riposo(coppia[1]).origin
			sa.quante = 1
			sa.ampiezza = 0.06
			sa.spessore = 0.011
			_attacco(coppia[0]).add_child(sa)
		# criniera che crepita: ciuffi di saette lungo la cresta, uno fra le orecchie, uno sulla coda
		for dati in [["neck1", "neck2", 0.35, 0.6], ["neck1", "neck2", 0.9, 0.52], ["neck2", "head", 0.6, 0.48]]:
			_quadro(_lungo(dati[0], dati[1], float(dati[2]), 0.18), 2, Vector2(float(dati[3]), float(dati[3]) * 1.1), c1, c2, 1.25)
		_quadro(_presso("head", _riposo("head").origin + Vector3(0, 0.1, -0.02)), 2, Vector2(0.4, 0.5), c1, c2, 1.4)
		_quadro(_lungo("tail1", "tail2", 0.6), 2, Vector2(0.55, 0.6), c1, c2, 1.4)
		# scariche che corrono attorno al corpo
		var giro := Equip.Saette.new(c2, c1)
		giro.raggio = 0.8
		giro.quante = 3
		giro.ampiezza = 0.12
		giro.spessore = 0.012
		giro.position = Vector3(0, 0.25, 0.1)
		add_child(giro)
		# scintille che si staccano da criniera e coda
		for nodo in [_lungo("neck1", "neck2", 0.7, 0.15), _lungo("tail2", "tail3", 0.3)]:
			var p := Equip.particelle(nodo, 10, 0.07, 0.55, c2, c1, 1.0)
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 0.25
			p.initial_velocity_max = 1.6
			p.gravity = Vector3(0, -2.5, 0)
		# scia elettrica al galoppo: nastri frastagliati dai fianchi e dalla coda
		for lato in [-1.0, 1.0]:
			_scia(_presso("spine", _riposo("spine").origin + Vector3(lato * 0.42, -0.3, 0.0)), c1, c2, 0.5, 0.2, 0.045, 0.9)
			_scia(_presso("spine", _riposo("spine").origin + Vector3(lato * 0.3, -0.75, 0.3)), c1, c2, 0.4, 0.25, 0.035, 0.8)
		_scia(_lungo("tail2", "tail3", 0.5), c1, c2, 0.65, 0.3, 0.05, 0.9)

	# ------------------------------------------------ Ombra: fumo che cola da criniera e coda, sbuffi agli zoccoli, sagome
	func _ombra() -> void:
		var nero := Color(0.012, 0.0, 0.03)
		var viola := Color(0.2, 0.05, 0.34)
		for dati in [[_lungo("neck1", "neck2", 0.3, 0.12), 10, 0.5], [_lungo("neck1", "neck2", 0.95, 0.1), 10, 0.45], [_lungo("neck2", "head", 0.7, 0.08), 6, 0.36],
				[_lungo("tail1", "tail2", 0.5), 9, 0.45], [_lungo("tail2", "tail3", 0.4), 10, 0.5], [_lungo("tail2", "tail3", 1.0), 7, 0.45]]:
			var p := Equip.particelle(dati[0], int(dati[1]), float(dati[2]), 1.7, viola, nero, 0.85, true)
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 0.14
			p.initial_velocity_max = 0.3
			p.gravity = Vector3(0, -0.8, 0)          # cola verso il basso
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.2
		for z in _zoccoli():
			var p := Equip.particelle(z, 7, 0.6, 1.0, viola, nero, 0.8, true)
			p.direction = Vector3(0, 1, 0)
			p.spread = 70.0
			p.initial_velocity_max = 0.7
			p.gravity = Vector3(0, 0.35, 0)
			p.emitting = false
			_in_corsa.append(p)
			var q := Equip.particelle(z, 4, 0.42, 1.4, viola, nero, 0.7, true)
			q.initial_velocity_max = 0.2
			q.gravity = Vector3(0, 0.15, 0)
		# lingue viola, basse e scure, lungo la cresta e sulla coda: il fumo prende fuoco
		var cupo := Color(0.32, 0.1, 0.6)
		for dati in [["neck1", "neck2", 0.3, 0.5], ["neck1", "neck2", 0.95, 0.56], ["neck2", "head", 0.7, 0.46]]:
			_quadro(_lungo(dati[0], dati[1], float(dati[2]), 0.1), 0, Vector2(float(dati[3]) * 0.7, float(dati[3])), cupo, c1, 0.9)
		_quadro(_lungo("tail1", "tail2", 0.7), 0, Vector2(0.4, 0.55), cupo, c1, 0.8, Vector3(0, -0.1, 0))
		# faville viola-acide che salgono dal corpo
		var f := Equip.particelle(_presso("spine", _riposo("spine").origin + Vector3(0, -0.2, 0)), 12, 0.07, 1.2, c1, c2, 1.0)
		f.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		f.emission_box_extents = Vector3(0.4, 0.4, 1.0)
		f.gravity = Vector3(0, 0.9, 0)
		f.initial_velocity_max = 0.3
		# occhi: due braci viola che lasciano la scia
		var testa := _riposo("head").origin
		var muso := _riposo("muso").origin
		for lato in [-1.0, 1.0]:
			var o := _presso("head", testa.lerp(muso, 0.24) + Vector3(lato * 0.11, 0.05, -0.02))
			_lume(o, 0.2, Color(c1.r, c1.g, c1.b, 0.9))
			_scia(o, c1, c1.lightened(0.4), 0.35, 0.0, 0.03, 0.9)
		# scia di sagome al galoppo: copie scure della pelle, in ritardo
		if cavallo.pelle != null:
			for i in range(3):
				var m := ShaderMaterial.new()
				m.shader = load("res://shader/destriero_sagoma.gdshader")
				m.set_shader_parameter("colore", c1)
				m.set_shader_parameter("forza", 0.55 - 0.14 * i)
				var g := MeshInstance3D.new()
				g.mesh = cavallo.pelle.mesh
				g.skin = cavallo.pelle.skin
				g.material_override = m
				g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				g.visible = false
				cavallo.scheletro.add_child(g)
				g.skeleton = g.get_path_to(cavallo.scheletro)
				g.top_level = true
				_sagome.append(g)

	# ------------------------------------------------ Monaco: zoccoli di fiamma, criniera e coda di fuoco del chi, onde calde
	func _fiamma() -> void:
		var rosso := Color(1.0, 0.16, 0.03)
		for z in _zoccoli():
			_quadro(z, 0, Vector2(0.42, 0.66), c1, c2, 1.05, Vector3(0, -0.05, 0))
			# al galoppo le fiamme restano indietro, una per falcata
			var p := Equip.particelle(z, 8, 0.34, 0.55, c1, rosso, 0.9)
			p.direction = Vector3(0, 1, 0)
			p.spread = 25.0
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 1.3
			p.gravity = Vector3(0, 1.6, 0)
			p.emitting = false
			_in_corsa.append(p)
		# criniera di fuoco: lingue lungo la cresta, più alte verso la nuca; coda di fuoco
		for dati in [["neck1", "neck2", 0.15, 0.6], ["neck1", "neck2", 0.6, 0.78], ["neck1", "neck2", 1.0, 0.9], ["neck2", "head", 0.55, 0.78], ["neck2", "head", 0.95, 0.6]]:
			_quadro(_lungo(dati[0], dati[1], float(dati[2]), -0.02), 0, Vector2(float(dati[3]) * 0.66, float(dati[3])), c1, c2, 1.05)
		for dati in [["tail1", "tail2", 0.5, 0.7], ["tail2", "tail3", 0.3, 0.85], ["tail2", "tail3", 0.9, 0.7]]:
			_quadro(_lungo(dati[0], dati[1], float(dati[2])), 0, Vector2(float(dati[3]) * 0.68, float(dati[3])), c1, c2, 1.0, Vector3(0, -0.15, 0))
		# faville che salgono
		var f := Equip.particelle(_presso("spine", _riposo("spine").origin + Vector3(0, -0.1, 0)), 14, 0.06, 1.4, c2, rosso, 1.0)
		f.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		f.emission_box_extents = Vector3(0.45, 0.6, 1.1)
		f.gravity = Vector3(0, 1.5, 0)
		f.initial_velocity_max = 0.5
		# onde calde: grandi veli tenui che salgono dal corpo
		var o := Equip.particelle(_presso("spine", _riposo("spine").origin + Vector3(0, -0.3, 0)), 5, 1.5, 1.4, Color(c1.r, c1.g * 0.8, c1.b), rosso, 0.16)
		o.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		o.emission_box_extents = Vector3(0.25, 0.2, 0.8)
		o.gravity = Vector3(0, 1.3, 0)
		o.initial_velocity_max = 0.2
		# al galoppo: strisce di fuoco dai fianchi e dalla coda
		for lato in [-1.0, 1.0]:
			_scia(_presso("spine", _riposo("spine").origin + Vector3(lato * 0.36, -0.55, 0.2)), rosso, c2, 0.45, 0.06, 0.09, 0.5)
		_scia(_lungo("tail2", "tail3", 0.4), rosso, c2, 0.6, 0.08, 0.14, 0.55)

	# ------------------------------------------------ Mistico: stelle in orbita, criniera luminosa, polvere di stelle, corona
	func _astrale() -> void:
		var chiaro := Color(c1.r, c1.g, c1.b, 0.4)
		# stelle in orbita attorno al cavallo, ognuna con la sua scia corta
		var giro := Orbita.new()
		_presso("spine", _riposo("spine").origin + Vector3(0, -0.2, 0)).add_child(giro)
		for i in range(5):
			var perno := Node3D.new()
			var ang := TAU * i / 5.0
			perno.position = Vector3(cos(ang) * 0.95, sin(ang * 2.0) * 0.5, sin(ang) * 1.5)
			giro.add_child(perno)
			_quadro(perno, 1, Vector2(0.5, 0.5), c1, c2, 1.5)
			var st := Equip.particelle(perno, 8, 0.14, 0.5, c2, c1, 0.9)
			st.initial_velocity_max = 0.03
			st.scale_amount_min = 0.4
			st.scale_amount_max = 1.0
		# stelle che palpitano lungo criniera e coda, con qualche scintilla che cade
		for dati in [["neck1", "neck2", 0.3, 0.26], ["neck1", "neck2", 0.95, 0.3], ["neck2", "head", 0.7, 0.24]]:
			_quadro(_lungo(dati[0], dati[1], float(dati[2]), 0.16), 1, Vector2(float(dati[3]), float(dati[3])), c1, c2, 1.4)
		for nodo in [_lungo("neck1", "neck2", 0.7, 0.05), _lungo("tail2", "tail3", 0.2), _lungo("tail2", "tail3", 0.9)]:
			_quadro(nodo, 1, Vector2(0.28, 0.28), c1, c2, 1.3)
			var p := Equip.particelle(nodo, 7, 0.1, 1.0, c2, c1, 1.0)
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 0.28
			p.initial_velocity_max = 0.15
			p.gravity = Vector3(0, -0.3, 0)
		# polvere di stelle che resta sospesa dietro gli zoccoli
		for z in _zoccoli():
			_lume(z, 0.45, chiaro)
			var p := Equip.particelle(z, 7, 0.12, 1.6, c2, c1, 1.0)
			p.initial_velocity_max = 0.45
			p.gravity = Vector3(0, 0.25, 0)
			p.emitting = false
			_in_corsa.append(p)
		# corona di luce sopra la testa: otto stelle in cerchio che girano piano, con un alone al centro
		var corona := Orbita.new()
		corona.velocita = 0.9
		_presso("head", _riposo("head").origin + Vector3(0, 0.34, -0.02)).add_child(corona)
		for i in range(8):
			var ang := TAU * i / 8.0
			_quadro(corona, 1, Vector2(0.16, 0.16), c2, Color.WHITE, 1.5, Vector3(cos(ang) * 0.24, 0, sin(ang) * 0.24))
		_lume(corona, 0.75, chiaro)
		# scia di polvere di stelle al galoppo
		_scia(_lungo("tail1", "tail2", 0.5), c1, c2, 0.9, 0.0, 0.16, 0.3)
		for lato in [-1.0, 1.0]:
			_scia(_presso("spine", _riposo("spine").origin + Vector3(lato * 0.4, 0.1, 0.0)), c1, c2, 0.6, 0.0, 0.025, 0.7)

	## Chiamato a ogni fotogramma con la velocità: accende scie, sbuffi e sagome solo quando si corre.
	func aggiorna(velocita: float, dt: float) -> void:
		_vel = lerpf(_vel, velocita, minf(1.0, dt * 6.0))
		var corre := _vel > 4.0
		for p in _in_corsa:
			(p as CPUParticles3D).emitting = corre
		for s in _scie:
			(s as Scia).attiva = corre
		if _sagome.is_empty() or cavallo.pelle == null:
			return
		_storia.push_front([cavallo.pelle.global_transform, 0.0])
		for e in _storia:
			e[1] += dt
		while _storia.size() > 2 and float(_storia[-1][1]) > 0.5:
			_storia.pop_back()
		for i in range(_sagome.size()):
			var g: MeshInstance3D = _sagome[i]
			g.visible = corre
			if not corre:
				continue
			var ritardo := 0.07 + 0.075 * i
			var scelta: Transform3D = _storia[-1][0]
			for e in _storia:
				if float(e[1]) >= ritardo:
					scelta = e[0]
					break
			g.global_transform = scelta


## Nodo che gira attorno al proprio asse verticale (stelle in orbita, corona).
class Orbita:
	extends Node3D
	var velocita := 1.6
	func _process(dt: float) -> void:
		rotate_object_local(Vector3.UP, dt * velocita)


## Scia nel mondo dietro un punto del cavallo: nastro verticale che svanisce. tremito > 0 lo spezza come una saetta.
class Scia:
	extends MeshInstance3D
	var sorgente: Node3D
	var attiva := false
	var vita := 0.5
	var tremito := 0.0
	var alto := 0.1
	var alfa := 0.8
	var c1 := Color.WHITE
	var c2 := Color.WHITE
	var _campioni: Array = []       # [posizione, età, scarto]
	var _im: ImmediateMesh

	func _init(colore1: Color, colore2: Color, durata: float, tremito_ := 0.0, altezza := 0.1) -> void:
		c1 = colore1
		c2 = colore2
		vita = durata
		tremito = tremito_
		alto = altezza
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
			c[1] += dt
		while not _campioni.is_empty() and float(_campioni[-1][1]) > vita:
			_campioni.pop_back()
		if attiva and is_instance_valid(sorgente) and sorgente.is_inside_tree():
			var p := sorgente.global_position
			if not _campioni.is_empty() and (_campioni[0][0] as Vector3).distance_to(p) > 6.0:
				_campioni.clear()                # teletrasporto: niente scia
			if _campioni.is_empty() or (_campioni[0][0] as Vector3).distance_to(p) > 0.12:
				var scarto := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * tremito
				_campioni.push_front([p, 0.0, scarto])
		_im.clear_surfaces()
		if _campioni.size() < 2:
			return
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in range(_campioni.size()):
			var c: Array = _campioni[i]
			var eta := float(c[1]) / vita
			var f := maxf(0.0, 1.0 - eta)
			var centro: Vector3 = (c[0] as Vector3) + (c[2] as Vector3) * (0.3 + eta)
			var mezzo := alto * (0.35 + 0.65 * f) * (1.0 if tremito <= 0.0 else 0.6)
			var col := c2.lerp(c1, minf(1.0, eta * 2.0))
			_im.surface_set_color(Color(col.r, col.g, col.b, f * f * alfa))
			_im.surface_add_vertex(centro + Vector3(0, mezzo, 0))
			_im.surface_set_color(Color(c1.r, c1.g, c1.b, 0.0))
			_im.surface_add_vertex(centro - Vector3(0, mezzo, 0))
		_im.surface_end()
