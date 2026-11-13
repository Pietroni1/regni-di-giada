class_name Personaggio
extends Node3D
## Aspetto di una creatura: modello con scheletro, capi indossati, arma e animazioni.
## Umani: corpo base di modelli/ + animazioni condivise di mixamo_anim.glb. Animali: animali.glb.

const CICLICHE := ["fermo", "camminata", "corsa", "sella", "passo"]
const ATTACCHI := {
	"sword": ["spada_1", "spada_2", "spada_3"], "daggers": ["pugnali"], "bow": ["arco"],
	"fists": ["pugni", "calcio"], "staff": ["magia"],
}
const SPECIE := {"wolf": "lupo", "boar": "cinghiale", "bear": "orso", "tiger": "tigre", "horse": "cavallo"}

static var _scene: Dictionary = {}
static var _librerie: Dictionary = {}

var player: AnimationPlayer
var scheletro: Skeleton3D
var altezza := 2.2
var morto := false
var attacchi: Array = ["spada_1", "spada_2", "spada_3"]
var _lancio := "magia"
var _cammina := "camminata"
var _corsa := "corsa"
var _blocco := 0.0         # secondi rimasti di un'animazione singola (attacco, colpito)
var _base := ""
var _att_i := 0
var _arma: Node3D = null
var _albero: AnimationTree = null      # solo umani: movimento sotto, colpi sulla parte alta del corpo
var _nodo_colpo: AnimationNodeAnimation
var _nodo_singola: AnimationNodeOneShot
var _stato := ""
var _muove := false
var in_sella := false

const PARTE_ALTA := ["spine", "spine_1", "chest", "neck", "head", "shoulder_L", "upper_arm_L", "forearm_L", "hand_L", "shoulder_R", "upper_arm_R", "forearm_R", "hand_R"]


static func _scena(nome: String) -> PackedScene:
	if not _scene.has(nome):
		_scene[nome] = load("res://modelli/%s.glb" % nome)
	return _scene[nome]


# ------------------------------------------------------------------ umani
## wear: quali capi mostrare — { "veste": Color, "lamellare": { "stoffa": Color }, "elmo_bronzo": true }
static func umano(modello: String, wear: Dictionary, tipo_arma := "sword", grado_arma := 1, pelle := Color(0.86, 0.66, 0.52)) -> Personaggio:
	var p := Personaggio.new()
	var radice: Node3D = _scena(modello).instantiate()
	p.add_child(radice)
	p.scheletro = radice.find_children("*", "Skeleton3D", true, false)[0]
	for n in p.scheletro.get_children():
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		var nome := String(mi.name)
		if not nome.begins_with("capo_"):
			# corpo: manichino provvisorio, gli si dà il colore della pelle
			var m := StandardMaterial3D.new()
			m.albedo_color = pelle
			m.roughness = 0.75
			mi.material_override = m
			continue
		var parti := nome.trim_prefix("capo_").split("__")
		var capo := parti[0]
		var parte := parti[1] if parti.size() > 1 else ""
		if not wear.has(capo):
			mi.visible = false
			continue
		var v = wear[capo]
		var c = null
		if v is Color:
			c = v
		elif v is Dictionary and v.has(parte):
			c = v[parte]
		if c != null:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = c
			mat.roughness = 0.8
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mi.material_override = mat
	var testa := p.scheletro.find_bone("head")
	if testa >= 0:
		p.altezza = p.scheletro.get_bone_global_rest(testa).origin.y + 0.28
	p.player = AnimationPlayer.new()
	radice.add_child(p.player)
	p.player.add_animation_library("", _libreria_umani(modello, p.scheletro))
	p.attacchi = ATTACCHI.get(tipo_arma, ATTACCHI.sword)
	p._metti_arma(tipo_arma, grado_arma)
	p._crea_albero(radice)
	return p


## Animazioni condivise adattate a un corpo: solo rotazioni, più il bacino riscalato e tenuto sul posto.
static func _libreria_umani(modello: String, sk: Skeleton3D) -> AnimationLibrary:
	if _librerie.has(modello):
		return _librerie[modello]
	var lib := AnimationLibrary.new()
	var sorgente: Node = _scena("mixamo_anim").instantiate()
	var ap: AnimationPlayer = sorgente.find_children("*", "AnimationPlayer", true, false)[0]
	var sk_src: Skeleton3D = sorgente.find_children("*", "Skeleton3D", true, false)[0]
	var h_src := sk_src.get_bone_rest(sk_src.find_bone("hips")).origin.y
	var h_dst := sk.get_bone_rest(sk.find_bone("hips")).origin.y
	var fatt := h_dst / h_src if absf(h_src) > 1e-6 else 1.0
	for nome in ap.get_animation_list():
		var a: Animation = ap.get_animation(nome).duplicate(true)
		for i in range(a.get_track_count() - 1, -1, -1):
			var tipo := a.track_get_type(i)
			var bacino := String(a.track_get_path(i)).ends_with(":hips")
			if tipo == Animation.TYPE_SCALE_3D or (tipo == Animation.TYPE_POSITION_3D and not bacino):
				a.remove_track(i)
			elif tipo == Animation.TYPE_POSITION_3D:
				for k in range(a.track_get_key_count(i)):
					var v: Vector3 = a.track_get_key_value(i, k)
					a.track_set_key_value(i, k, Vector3(0.0, v.y * fatt, 0.0))
		a.loop_mode = Animation.LOOP_LINEAR if nome in CICLICHE else Animation.LOOP_NONE
		lib.add_animation(nome, a)
	sorgente.free()
	_librerie[modello] = lib
	return lib


## Albero di animazione degli umani: fermo/camminata/corsa/morte sfumati fra loro, e sopra un colpo singolo che,
## se ci si sta muovendo, prende solo la parte alta del corpo (così si colpisce correndo senza far scivolare i piedi).
func _crea_albero(radice: Node3D) -> void:
	var bt := AnimationNodeBlendTree.new()
	var tr := AnimationNodeTransition.new()
	tr.xfade_time = 0.2
	var stati := ["fermo", "camminata", "corsa", "morte", "sella"]
	tr.input_count = stati.size()
	bt.add_node("base", tr)
	for i in range(stati.size()):
		tr.set_input_name(i, stati[i])
		var an := AnimationNodeAnimation.new()
		an.animation = stati[i]
		bt.add_node("a_" + stati[i], an)
		bt.connect_node("base", i, "a_" + stati[i])
	bt.add_node("vel_base", AnimationNodeTimeScale.new())
	bt.connect_node("vel_base", 0, "base")
	_nodo_colpo = AnimationNodeAnimation.new()
	_nodo_colpo.animation = attacchi[0] if not attacchi.is_empty() else "colpito"
	bt.add_node("colpo", _nodo_colpo)
	bt.add_node("vel_colpo", AnimationNodeTimeScale.new())
	bt.connect_node("vel_colpo", 0, "colpo")
	_nodo_singola = AnimationNodeOneShot.new()
	_nodo_singola.fadein_time = 0.08
	_nodo_singola.fadeout_time = 0.18
	var percorso := String(radice.get_path_to(scheletro))
	for osso in PARTE_ALTA:
		_nodo_singola.set_filter_path(NodePath("%s:%s" % [percorso, osso]), true)
	for i in range(scheletro.get_bone_count()):
		var nome := scheletro.get_bone_name(i)
		if nome.begins_with("hand_L_") or nome.begins_with("hand_R_"):
			_nodo_singola.set_filter_path(NodePath("%s:%s" % [percorso, nome]), true)
	bt.add_node("singola", _nodo_singola)
	bt.connect_node("singola", 0, "vel_base")
	bt.connect_node("singola", 1, "vel_colpo")
	bt.connect_node("output", 0, "singola")
	_albero = AnimationTree.new()
	_albero.tree_root = bt
	radice.add_child(_albero)
	_albero.anim_player = _albero.get_path_to(player)
	_albero.active = true
	_stato = "fermo"
	_albero.set("parameters/base/transition_request", "fermo")


# ------------------------------------------------------------------ animali
## Animazioni di una sola specie, con i percorsi delle tracce puntati al suo scheletro (animali.glb contiene
## cinque scheletri e un solo AnimationPlayer: all'importazione i percorsi non sempre indicano quello giusto).
static func _libreria_animale(specie: String, ap: AnimationPlayer, sk: Skeleton3D) -> AnimationLibrary:
	if _librerie.has("animale:" + specie):
		return _librerie["animale:" + specie]
	var lib := AnimationLibrary.new()
	for nome in ap.get_animation_list():
		if not String(nome).begins_with(specie + "_"):
			continue
		var corta := String(nome).trim_prefix(specie + "_")
		var a: Animation = ap.get_animation(nome).duplicate(true)
		for i in range(a.get_track_count() - 1, -1, -1):
			var osso := String(a.track_get_path(i).get_concatenated_subnames())
			if sk.find_bone(osso) < 0:
				a.remove_track(i)
			else:
				a.track_set_path(i, NodePath("%s_scheletro/Skeleton3D:%s" % [specie, osso]))
		a.loop_mode = Animation.LOOP_LINEAR if corta in CICLICHE or corta == "corsa" else Animation.LOOP_NONE
		lib.add_animation(corta, a)
	_librerie["animale:" + specie] = lib
	return lib


static func animale(modello: String, tinta: Color, scala := 1.0) -> Personaggio:
	var specie: String = SPECIE.get(modello, "")
	if specie.is_empty():
		return null
	var p := Personaggio.new()
	var radice: Node3D = _scena("animali").instantiate()
	p.add_child(radice)
	for n in radice.get_children():
		if n is Node3D and not String(n.name).begins_with(specie) and not n is AnimationPlayer:
			radice.remove_child(n)
			n.free()
	p.scheletro = radice.get_node(specie + "_scheletro/Skeleton3D")
	for n in p.scheletro.get_children():
		if n is MeshInstance3D:
			var m := StandardMaterial3D.new()
			m.albedo_color = tinta
			m.vertex_color_use_as_albedo = false
			m.roughness = 0.9
			n.material_override = m
	var sorgente: AnimationPlayer = radice.find_children("*", "AnimationPlayer", true, false)[0]
	var lib := _libreria_animale(specie, sorgente, p.scheletro)
	radice.remove_child(sorgente)
	sorgente.free()
	p.player = AnimationPlayer.new()
	radice.add_child(p.player)
	p.player.add_animation_library("", lib)
	p._cammina = "passo"
	p._lancio = "attacco"
	p.attacchi = ["attacco"]
	radice.scale = Vector3.ONE * scala
	p.altezza = 1.3 * scala
	p._suona("fermo", 0.0)
	return p


## Sagoma provvisoria per i mostri che non hanno ancora un modello.
static func sagoma(colore: Color, scala := 1.0, alta := 1.8) -> Personaggio:
	var p := Personaggio.new()
	var m := Edifici.mat(colore, 0.8)
	var corpo := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = 0.42 * scala
	c.height = alta * scala
	corpo.mesh = c
	corpo.material_override = m
	corpo.position.y = alta * scala * 0.5
	p.add_child(corpo)
	for sx in [-1.0, 1.0]:
		var o := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.07 * scala
		s.height = 0.14 * scala
		o.mesh = s
		o.material_override = Edifici.mat(Color(1.0, 0.85, 0.3), 0.4, 0.0, 3.0)
		o.position = Vector3(sx * 0.16 * scala, alta * scala * 0.82, 0.36 * scala)
		p.add_child(o)
	p.altezza = alta * scala + 0.1
	return p


## Fantoccio d'addestramento: palo, traversa e sacco di paglia.
static func fantoccio() -> Personaggio:
	var p := Personaggio.new()
	var legno := Edifici.mat(Color(0.42, 0.28, 0.16), 0.9)
	var paglia := Edifici.mat(Color(0.78, 0.66, 0.36), 0.95)
	Edifici.cilindro(0.09, 0.11, 2.0, Vector3(0, 1.0, 0), legno, p, 8)
	Edifici.scatola(Vector3(1.5, 0.12, 0.12), Vector3(0, 1.55, 0), legno, p)
	Edifici.cilindro(0.34, 0.3, 0.95, Vector3(0, 1.25, 0), paglia, p, 10)
	var testa := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.24
	s.height = 0.48
	testa.mesh = s
	testa.material_override = paglia
	testa.position.y = 2.0
	p.add_child(testa)
	Edifici.scatola(Vector3(0.5, 0.06, 0.02), Vector3(0, 1.35, 0.33), Edifici.mat(Color(0.7, 0.12, 0.1), 0.8), p)
	p.altezza = 2.4
	return p


# ------------------------------------------------------------------ armi
func _metti_arma(tipo: String, grado: int) -> void:
	if scheletro == null or tipo == "fists":
		return
	var metallo := Edifici.mat([Color(0.72, 0.72, 0.74), Color(0.78, 0.64, 0.36), Color(0.5, 0.86, 0.66), Color(0.88, 0.92, 0.98)][clampi(grado - 1, 0, 3)], 0.3, 0.85)
	var legno := Edifici.mat(Color(0.3, 0.18, 0.1), 0.8)
	match tipo:
		"sword":
			_arma = _impugna("hand_R")
			Edifici.scatola(Vector3(0.05, 1.15, 0.012), Vector3(0, 0.68, 0), metallo, _arma)
			Edifici.scatola(Vector3(0.2, 0.03, 0.07), Vector3(0, 0.1, 0), Edifici.mat(Edifici.ORO, 0.4, 0.8), _arma)
			Edifici.cilindro(0.022, 0.022, 0.26, Vector3(0, -0.03, 0), legno, _arma, 8)
		"daggers":
			for osso in ["hand_R", "hand_L"]:
				var d := _impugna(osso)
				Edifici.scatola(Vector3(0.04, 0.42, 0.01), Vector3(0, 0.3, 0), metallo, d)
				Edifici.cilindro(0.02, 0.02, 0.16, Vector3(0, 0.02, 0), legno, d, 8)
				_arma = d
		"bow":
			_arma = _impugna("hand_L")
			for s in [-1.0, 1.0]:
				var ramo := Edifici.scatola(Vector3(0.035, 0.75, 0.05), Vector3(0, s * 0.36, -0.07), legno, _arma)
				ramo.rotation.x = s * 0.28
			Edifici.scatola(Vector3(0.006, 1.42, 0.006), Vector3(0, 0, -0.17), Edifici.mat(Color(0.9, 0.9, 0.85), 0.6), _arma)
		"staff":
			_arma = _impugna("hand_R")
			Edifici.cilindro(0.025, 0.03, 1.9, Vector3(0, 0.45, 0), legno, _arma, 8)
			var sfera := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.11
			sm.height = 0.22
			sfera.mesh = sm
			sfera.material_override = Edifici.mat([Color(1.0, 0.94, 0.6), Color(0.6, 0.85, 1.0), Color(0.6, 1.0, 0.75), Color(1.0, 0.65, 0.95)][clampi(grado - 1, 0, 3)], 0.3, 0.0, 3.0)
			sfera.position.y = 1.48
			_arma.add_child(sfera)


## Nodo agganciato a un osso della mano; l'asse lungo dell'arma è +y del nodo restituito.
func _impugna(osso: String) -> Node3D:
	var ba := BoneAttachment3D.new()
	ba.bone_name = osso
	scheletro.add_child(ba)
	var presa := Node3D.new()
	# le ossa della mano di Mixamo hanno +y lungo le dita: l'arma esce dal palmo, perpendicolare alle dita
	presa.position = Vector3(0, 0.09, 0.03)
	presa.rotation = Vector3(PI * 0.5, 0, 0)
	ba.add_child(presa)
	return presa


# ------------------------------------------------------------------ animazioni
func _nome(n: String) -> String:
	return n


func _suona(n: String, sfuma := 0.18, velocita := 1.0) -> void:
	if player == null:
		return
	var nome := _nome(n)
	if not player.has_animation(nome):
		return
	player.play(nome, sfuma, velocita)


## Da chiamare a ogni fotogramma con la velocità di spostamento (m/s).
func muovi(velocita: float, dt: float) -> void:
	if player == null or morto:
		return
	_muove = velocita > 0.3
	if in_sella:
		if _stato != "sella" and _albero != null:
			_stato = "sella"
			_albero.set("parameters/vel_base/scale", 1.0)
			_albero.set("parameters/base/transition_request", "sella")
		return
	if _albero != null:
		var stato := "fermo"
		var passo := 1.0
		if velocita > 3.6:
			stato = "corsa"
			passo = clampf(velocita / 6.5, 0.8, 1.5)
		elif _muove:
			stato = "camminata"
			passo = clampf(velocita / 2.0, 0.7, 1.6)
		if stato != _stato:
			_stato = stato
			_albero.set("parameters/base/transition_request", stato)
		_albero.set("parameters/vel_base/scale", passo)
		return
	if _blocco > 0.0:
		_blocco -= dt
		if _blocco > 0.0:
			return
		_base = ""
	var voglio := "fermo"
	var ritmo := 1.0
	if velocita > 3.6:
		voglio = _corsa
		ritmo = clampf(velocita / 6.5, 0.8, 1.5)
	elif velocita > 0.3:
		voglio = _cammina
		ritmo = clampf(velocita / 2.0, 0.7, 1.6)
	if voglio != _base:
		_base = voglio
		_suona(voglio, 0.2, ritmo)
	elif voglio != "fermo":
		player.speed_scale = ritmo


func _singola(n: String, durata_max := 0.8) -> void:
	if player == null or morto:
		return
	var nome := _nome(n)
	if not player.has_animation(nome):
		return
	var lung := player.get_animation(nome).length
	var vel := maxf(1.0, lung / durata_max)
	if _albero != null:
		_nodo_colpo.animation = nome
		_nodo_singola.filter_enabled = _muove
		_albero.set("parameters/vel_colpo/scale", vel)
		_albero.set("parameters/singola/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		return
	player.speed_scale = 1.0
	player.play(nome, 0.08, vel)
	_blocco = lung / vel
	_base = ""


func attacca() -> void:
	if attacchi.is_empty():
		return
	_singola(attacchi[_att_i % attacchi.size()])
	_att_i += 1


func lancia() -> void:
	_singola(_lancio, 0.9)


func colpito() -> void:
	if _albero != null:
		if not _albero.get("parameters/singola/active"):
			_singola("colpito", 0.45)
		return
	if _blocco <= 0.0:
		_singola("colpito", 0.45)


func muori() -> void:
	if morto:
		return
	if _albero != null:
		_albero.set("parameters/singola/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		_albero.set("parameters/vel_base/scale", 1.0)
		_albero.set("parameters/base/transition_request", "morte")
		_stato = "morte"
		morto = true
		return
	if player != null and player.has_animation(_nome("morte")):
		player.speed_scale = 1.0
		player.play(_nome("morte"), 0.1)
	else:
		var t := create_tween()
		t.tween_property(self, "rotation:x", -PI * 0.5, 0.5)
	morto = true


func rialza() -> void:
	morto = false
	if _albero != null:
		_stato = "fermo"
		_albero.set("parameters/base/transition_request", "fermo")
		return
	rotation.x = 0.0
	_blocco = 0.0
	_base = ""
	_suona("fermo", 0.2)


# ------------------------------------------------------------------ figure dei mostri senza modello
## Lanterna spettrale che fluttua.
static func lanterna_spettrale(colore: Color, scala := 1.0) -> Personaggio:
	var p := Personaggio.new()
	var corpo := Node3D.new()
	corpo.position.y = 1.5 * scala
	p.add_child(corpo)
	var ferro := Edifici.mat(Color(0.1, 0.08, 0.08), 0.6, 0.5)
	Edifici.scatola(Vector3(0.5, 0.7, 0.5) * scala, Vector3.ZERO, Edifici.mat(colore.lightened(0.3), 0.5, 0.0, 4.0), corpo)
	Edifici.cilindro(0.0, 0.45 * scala, 0.3 * scala, Vector3(0, 0.5 * scala, 0), ferro, corpo, 4).rotation.y = PI / 4.0
	Edifici.scatola(Vector3(0.6, 0.08, 0.6) * scala, Vector3(0, -0.38 * scala, 0), ferro, corpo)
	for i in range(3):
		Edifici.scatola(Vector3(0.05, 0.5 - i * 0.1, 0.05) * scala, Vector3((i - 1) * 0.16, -0.7 + i * 0.03, 0) * scala, Edifici.mat(Color(0.7, 0.15, 0.1), 0.8), corpo)
	var t := p.create_tween().set_loops()
	t.tween_property(corpo, "position:y", 1.75 * scala, 1.1).set_trans(Tween.TRANS_SINE)
	t.tween_property(corpo, "position:y", 1.5 * scala, 1.1).set_trans(Tween.TRANS_SINE)
	p.altezza = 2.3 * scala
	return p


## Ombra: sagoma scura semitrasparente con occhi accesi.
static func ombra(colore: Color, scala := 1.0) -> Personaggio:
	var p := Personaggio.sagoma(colore, scala, 1.9)
	for n in p.get_children():
		var mi := n as MeshInstance3D
		if mi != null and mi.mesh is CapsuleMesh:
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(colore.r * 0.4, colore.g * 0.4, colore.b * 0.5, 0.72)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.emission_enabled = true
			m.emission = Color(0.25, 0.1, 0.45)
			m.emission_energy_multiplier = 0.6
			mi.material_override = m
	return p


## Obelisco: prisma di pietra con rune accese.
static func obelisco(colore: Color, scala := 1.0) -> Personaggio:
	var p := Personaggio.new()
	var pietra := ShaderMaterial.new()
	pietra.shader = preload("res://shader/roccia.gdshader")
	pietra.set_shader_parameter("muschio_forza", 0.3)
	Edifici.cilindro(0.35 * scala, 0.8 * scala, 4.2 * scala, Vector3(0, 2.1 * scala, 0), pietra, p, 4)
	Edifici.cilindro(0.0, 0.36 * scala, 0.6 * scala, Vector3(0, 4.5 * scala, 0), pietra, p, 4)
	for i in range(4):
		Edifici.scatola(Vector3(0.5, 0.12, 0.5) * scala * (1.0 - i * 0.12), Vector3(0, (0.9 + i * 0.8) * scala, 0), Edifici.mat(colore.lightened(0.2), 0.5, 0.0, 3.5), p).rotation.y = PI / 4.0
	p.altezza = 5.0 * scala
	return p
