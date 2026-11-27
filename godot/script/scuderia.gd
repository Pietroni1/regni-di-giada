extends Node3D
## Scuderia: i destrieri in fila, costruiti come nel gioco (Entita + Destrieri), senza server.
## Serve a guardare (e fotografare) i cavalli per classe e per livello, con o senza cavaliere, fermi o al galoppo.
##   godot --path godot res://scene/scuderia.tscn --fixed-fps 30 -- [--classi=lama,ombra,monaco,mistico] [--livelli=20]
##         [--cavaliere=1] [--sesso=m|f] [--regno=fenice|tigre|drago] [--posa=fermo|passo|galoppo|impennata]
##         [--corre=1]      le figure avanzano davvero (le scie restano indietro) e la visuale le segue
##         [--fasi=8 --azione=corsa]   una classe sola, la stessa azione fermata in N istanti (per controllare le andature)
##         [--vecchio=1]    il cavallo di prima (animali.glb), per il confronto
##         [--spento=1]     senza gli effetti del livello massimo (per guardare la bardatura)
##         [--yaw=1.1] [--passo=2.9] [--zoom=1] [--mira=1.3] [--su=0.25] [--dopo=1.6] [--foto=file.png] [--film=4]
##         [--equip=1]      cavaliere con armatura e arma del grado più alto; oppure [--armatura=id] [--arma=id]
## Le figure sono una per ogni coppia classe × livello, su una riga.

var _arg := {}
var _figure: Array = []         # [Entita o Destriero, direzione]
var _t := 0.0
var _cam: Camera3D
var _vel := Vector3.ZERO
var _impennati := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			_arg[kv[0]] = kv[1]
	_ambiente()
	Destrieri.senza_effetti = _arg.has("spento")
	var classi := String(_arg.get("classi", "lama,ombra,monaco,mistico")).split(",")
	var livelli: Array = []
	for l in String(_arg.get("livelli", "20")).split(","):
		livelli.append(int(l))
	var yaw := float(_arg.get("yaw", "1.1"))
	var passo := float(_arg.get("passo", "2.9"))
	var regno_id := String(_arg.get("regno", "drago"))
	var regno := Dati.colore(Dati.KINGDOMS.get(regno_id, {}).get("hex", 0x2f6ebe))
	var cavaliere := String(_arg.get("cavaliere", "0")) != "0"
	var fasi := int(_arg.get("fasi", "0"))
	var elenco: Array = []
	if fasi > 0:
		for i in range(fasi):
			elenco.append([String(classi[0]), int(livelli[0]), float(i) / fasi])
	else:
		for c in classi:
			for l in livelli:
				elenco.append([String(c), int(l), -1.0])
	var n := elenco.size()
	for i in range(n):
		var classe: String = elenco[i][0]
		var livello: int = elenco[i][1]
		var nodo: Node3D
		if cavaliere:
			var info := {"id": i + 1, "k": "p", "cls": classe, "kd": regno_id, "sx": String(_arg.get("sesso", "m")), "n": classe, "x": 0.0, "z": 0.0, "r": 0.0,
					"hp": 100.0, "mhp": 100.0, "lvl": 40, "mt": 3, "ml": livello}
			if _arg.has("equip"):
				# --equip=1: armatura e arma del grado più alto, come un personaggio di alto livello
				info["b"] = "armatura_nubi"
				info["w"] = {"lama": "spada_gru", "ombra": "pugnali_eclissi", "monaco": "guanti_sole", "mistico": "bastone_nubi"}.get(classe, "spada_gru")
			if _arg.has("armatura"):
				info["b"] = String(_arg.armatura)
			if _arg.has("arma"):
				info["w"] = String(_arg.arma)
			var e := Entita.da_info(info)
			if _arg.has("vecchio"):
				e.in_sella(0)
				e.sella = livello
				e.corpo.in_sella = true
				# com'era prima: tre gradi (1-9, 10-19, 20), stesso cavallo tinto e riscalato
				var grado := 3 if livello >= 20 else (2 if livello >= 10 else 1)
				var scala := 1.0 + 0.08 * (grado - 1)
				e.cavallo = Personaggio.animale("horse", Entita.MANTELLI[grado], scala)
				e.add_child(e.cavallo)
				e.corpo.position = Vector3(0, 0.62 * scala, -0.1)
			nodo = e
		elif _arg.has("vecchio"):
			nodo = Personaggio.animale("horse", Entita.MANTELLI[3 if livello >= 20 else (2 if livello >= 10 else 1)], 1.0)
		else:
			nodo = Destrieri.crea(classe, livello, regno)
		if nodo == null:
			push_warning("scuderia: destriero mancante " + classe)
			continue
		add_child(nodo)
		if nodo is Entita:
			nodo.set_process(false)          # dopo l'ingresso nell'albero: niente terreno né interpolazione
		nodo.position = Vector3((i - (n - 1) / 2.0) * passo, 0, 0)
		nodo.rotation.y = yaw
		_figure.append(nodo)
		if fasi > 0:
			var d := nodo as Personaggio
			var az := String(_arg.get("azione", "corsa"))
			if d.player.has_animation(az):
				d.player.play(az)
				d.player.seek(float(elenco[i][2]) * d.player.get_animation(az).length, true)
				d.player.pause()
	if String(_arg.get("corre", "0")) != "0":
		_vel = Vector3(sin(yaw), 0, cos(yaw)) * float(_arg.get("velocita", "13.5"))
	_cam = Camera3D.new()
	_cam.fov = 28.0
	var largo := n * passo
	var dist := maxf(6.5, largo * 1.02 / (2.0 * tan(deg_to_rad(_cam.fov * 0.5)) * 1.78))
	var zoom := float(_arg.get("zoom", "1"))
	var mira := float(_arg.get("mira", "1.3"))
	var su := float(_arg.get("su", "0.22"))
	var cx := float(_arg.get("cx", "0"))
	_cam.position = Vector3(cx, mira + dist * su / zoom, dist / zoom)
	add_child(_cam)
	_cam.look_at(Vector3(cx, mira, 0))
	_cam.current = true


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
	sole.directional_shadow_max_distance = 60.0
	add_child(sole)
	var terra := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4000, 4000)
	terra.mesh = pm
	var tm := ShaderMaterial.new()
	var sh := Shader.new()
	# prato a scacchi tenui: al galoppo si vede il terreno che scorre
	sh.code = "shader_type spatial;\nvarying vec3 w;\nvoid vertex(){ w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }\nvoid fragment(){ vec2 q = floor(w.xz / 2.0); float s = mod(q.x + q.y, 2.0); ALBEDO = mix(vec3(0.17, 0.22, 0.13), vec3(0.185, 0.235, 0.14), s); ROUGHNESS = 1.0; }"
	tm.shader = sh
	terra.material_override = tm
	add_child(terra)


func _process(dt: float) -> void:
	_t += dt
	var posa := String(_arg.get("posa", "fermo"))
	var vel: float = {"passo": 1.4, "galoppo": 13.5, "corsa": 13.5}.get(posa, 0.0)
	if int(_arg.get("fasi", "0")) == 0:
		for f in _figure:
			if f is Entita:
				var e := f as Entita
				e.velocita = vel
				e.passo_sella(dt)
			elif f is Personaggio:
				(f as Personaggio).muovi(vel, dt)
			f.position += _vel * dt
		_cam.position += _vel * dt
		if posa == "impennata" and not _impennati and _t > float(_arg.get("quando", "0.3")):
			_impennati = true
			for f in _figure:
				var d: Personaggio = (f as Entita).cavallo if f is Entita else f
				if d is Destrieri.Destriero:
					(d as Destrieri.Destriero).impenna()
	var quando := float(_arg.get("dopo", "1.6"))
	if _t >= quando and _arg.has("foto"):
		get_viewport().get_texture().get_image().save_png(String(_arg.foto))
		print("foto: ", _arg.foto)
		_arg.erase("foto")
		if not _arg.has("film"):
			get_tree().quit()
	if _arg.has("film") and _t >= float(_arg.film):
		get_tree().quit()
