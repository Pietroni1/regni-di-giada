extends Node3D
## Vetrina dei completi: una fila di personaggi della stessa classe, uno per grado d'armatura, senza server.
## Serve a guardare (e fotografare) i completi di tools/blender/completi.py con gli shader del gioco.
##   godot --path godot res://scene/vetrina.tscn -- --classe=lama --sesso=m --posa=fermo|corsa|attacco
##         [--gradi=0,1,2,3,4] [--yaw=0] [--foto=cartella/nome.png] [--zoom=3 --mira=1.45 --fuoco=2]
## Il grado 4 porta anche gli effetti dell'armatura +15 Leggendaria (aura e cerchio di rune di Equip).

const ARMI := {"lama": "sword", "ombra": "daggers", "monaco": "fists", "mistico": "staff"}

var _arg := {}
var _figure: Array = []
var _t := 0.0
var _colpo := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			_arg[kv[0]] = kv[1]
	var classe := String(_arg.get("classe", "lama"))
	var donna := String(_arg.get("sesso", "m")) == "f"
	var gradi: Array = []
	for g in String(_arg.get("gradi", "0,1,2,3,4")).split(","):
		gradi.append(int(g))
	_ambiente()
	var look: Dictionary = Dati.CLASSES.get(classe, {}).get("look", {})
	var regno := Color(0.16, 0.42, 0.82)
	var colori := {"stoffa": Dati.colore(look.get("robe", 0x555555)), "stoffa2": Dati.colore(look.get("pants", 0x333333)),
			"fascia": Dati.colore(look.get("trim", 0x8a7a5a)), "regno": regno}
	var modello := "base_donna" if donna else "base_uomo"
	var passo := float(_arg.get("passo", "1.5"))
	var yaw := float(_arg.get("yaw", "0"))
	for i in range(gradi.size()):
		var g: int = gradi[i]
		var wear := Entita.completo(classe, g, colori)
		wear[String(_arg.get("piedi", "sandali"))] = true
		if _arg.has("elmo"):
			# --elmo=1: ogni figura porta il copricapo della classe del suo grado (1-4); --elmo=vecchio: gli elmi di prima
			if String(_arg.elmo) == "vecchio":
				wear[["cappello_paglia", "elmo_bronzo", "elmo_cornuto", "elmo_drago"][clampi(g, 1, 4) - 1]] = true
			else:
				wear["%s_e%d" % [classe, clampi(g, 1, 4)]] = colori
		var p := Personaggio.umano(modello, wear, ARMI.get(classe, "sword"), clampi(g, 1, 4), Color(0.8, 0.56, 0.4), colori.fascia)
		var stile := String(look.get("hairStyle", "short"))
		if donna and stile in ["topknot", "bald"]:
			stile = "long"
		if _arg.has("elmo"):
			stile = "short" if stile != "bald" else "bald"
		p.metti_testa(stile, Dati.colore(look.get("hair", 0x1a1210)) if look.get("hair") != null else Color(0.1, 0.08, 0.07), colori.stoffa)
		if _arg.has("up"):
			# --up=7,9,12,15: un potenziamento per figura (arma e armatura), per provare gli effetti
			var ups := String(_arg.up).split(",")
			var u := int(ups[mini(i, ups.size() - 1)])
			p.metti_effetti(u, 0, u, 0, false)
		elif g >= 4:
			p.metti_effetti(15, 4, 15, 4, false)
		p.position = Vector3((i - (gradi.size() - 1) / 2.0) * passo, 0, 0)
		p.rotation.y = yaw
		add_child(p)
		_figure.append(p)
	var cam := Camera3D.new()
	cam.fov = 26.0
	var largo := gradi.size() * passo
	var dist := maxf(5.0, largo * 1.02 / (2.0 * tan(deg_to_rad(cam.fov * 0.5)) * 1.78))
	# primo piano: --zoom=3 (distanza divisa), --mira=1.45 (quota guardata), --fuoco=2 (figura al centro, da 0)
	var zoom := float(_arg.get("zoom", "1"))
	var mira := float(_arg.get("mira", "1.2"))
	var cx := 0.0
	if _arg.has("fuoco"):
		cx = (int(_arg.fuoco) - (gradi.size() - 1) / 2.0) * passo
	cam.position = Vector3(cx, mira + 0.1, dist / zoom)
	add_child(cam)
	cam.look_at(Vector3(cx, mira, 0))
	cam.current = true


func _ambiente() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var cielo := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.36, 0.55, 0.82)
	mat.sky_horizon_color = Color(0.75, 0.8, 0.85)
	mat.ground_horizon_color = Color(0.5, 0.52, 0.5)
	cielo.sky_material = mat
	env.background_mode = Environment.BG_SKY
	env.sky = cielo
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_hdr_threshold = 1.0
	we.environment = env
	add_child(we)
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-48, 30, 0)
	sole.light_energy = 1.3
	sole.shadow_enabled = true
	add_child(sole)
	var terra := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	terra.mesh = pm
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.24, 0.3, 0.19)
	tm.roughness = 1.0
	terra.material_override = tm
	add_child(terra)


func _process(dt: float) -> void:
	_t += dt
	var posa := String(_arg.get("posa", "fermo"))
	for p: Personaggio in _figure:
		p.muovi(6.5 if posa == "corsa" else 0.0, dt)
	if posa == "attacco":
		_colpo -= dt
		if _colpo <= 0.0:
			_colpo = 1.0
			for p: Personaggio in _figure:
				p.attacca()
	var quando := float(_arg.get("dopo", "1.6"))
	if _t >= quando and _arg.has("foto"):
		get_viewport().get_texture().get_image().save_png(String(_arg.foto))
		print("foto: ", _arg.foto)
		_arg.erase("foto")
		get_tree().quit()
