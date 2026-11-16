extends Node3D
## Bestiario: tutti i mostri di MOBS in fila, costruiti come nel gioco (Entita.da_info), senza server.
## Serve a guardare (e fotografare) le figure dei mostri: sagome, taglie, élite, animazioni.
##   godot --path godot res://scene/bestiario.tscn --fixed-fps 30 -- [--gruppo=lupi|bestie|spiriti|banditi|statue|capi|tutti]
##         [--lista=lupo,orso_nero,...] [--posa=fermo|passo|corsa|attacco|morte] [--colonne=6] [--yaw=0.5]
##         [--dopo=1.6] [--foto=cartella/nome.png] [--zoom=1] [--mira=1.0] [--nomi=0]
## Gli obelischi hanno la loro figura (obelischi.gd) e qui si vedono solo con --lista.

const GRUPPI := {
	"lupi": ["lupo", "lupo_branco", "lupo_canne", "sciacallo_dune", "lupo_alfa", "lupo_anziano"],
	"bestie": ["cinghiale", "cinghiale_zanne_ferro", "orso_nero", "orso_ventre_giada", "tigre_spettrale", "tigre_smeraldo", "tigre_sole_rovente", "scimmia", "scimmia_urlatrice"],
	"spiriti": ["spirito_lanterna", "lanterna_cripta", "lanterna_instabile", "eco_spirito", "spirito_canna", "ombra_cripta", "anima_miraggio"],
	"banditi": ["bandito", "arciere_bandito", "predone", "razziatore_gola", "brigante_selva", "cerbottaniere_selva", "predone_dune", "arciere_simun"],
	"statue": ["soldato_terracotta", "lanciere_bronzo", "terracotta", "sentinella_cripta", "guerriero_arenaria", "campione_arenaria"],
	"capi": ["generale", "custode_insonne"],
}

var _arg := {}
var _entita: Array = []
var _t := 0.0
var _colpo := 0.0
var _morti := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			_arg[kv[0]] = kv[1]
	var lista: Array = []
	if _arg.has("lista"):
		lista = Array(String(_arg.lista).split(","))
	else:
		var g := String(_arg.get("gruppo", "tutti"))
		if GRUPPI.has(g):
			lista = GRUPPI[g]
		else:
			for k in ["lupi", "bestie", "spiriti", "banditi", "statue", "capi"]:
				lista.append_array(GRUPPI[k])
	_ambiente()
	var colonne := int(_arg.get("colonne", str(mini(lista.size(), 6))))
	var yaw := float(_arg.get("yaw", "0.5"))
	var mostra_nomi := String(_arg.get("nomi", "1")) != "0"
	# file di figure affiancate: ognuna occupa la sua larghezza (taglia del modello × scala di MOBS)
	var righe: Array = []
	for i in range(lista.size()):
		if i % colonne == 0:
			righe.append([])
		righe[righe.size() - 1].append(String(lista[i]))
	var largo := 0.0
	var alto := 0.0
	var z := 0.0
	var n := 0
	for riga: Array in righe:
		var larghezze: Array = []
		var tot := 0.0
		var prof := 0.0
		for ty: String in riga:
			var w := _larghezza(ty)
			larghezze.append(w)
			tot += w
			prof = maxf(prof, w)
		largo = maxf(largo, tot)
		var x := -tot * 0.5
		for j in range(riga.size()):
			var ty: String = riga[j]
			var w: float = larghezze[j]
			x += w * 0.5
			n += 1
			if not Dati.MOBS.has(ty):
				push_warning("bestiario: mostro sconosciuto " + ty)
				x += w * 0.5
				continue
			var d: Dictionary = Dati.MOBS[ty]
			alto = maxf(alto, 2.1 * float(d.get("scale", 1.0)) * (1.1 if String(d.get("model", "")) in ["general", "custode", "terracotta", "bandit", "bandit_archer", "shade", "lantern"] else 0.75))
			var info := {"id": n, "k": "m", "ty": ty, "n": String(d.get("name", ty)), "x": 0.0, "z": 0.0, "r": 0.0,
					"hp": float(d.get("hp", 100)), "mhp": float(d.get("hp", 100)), "lvl": int(d.get("lvl", 1))}
			var e := Entita.da_info(info)
			add_child(e)
			e.set_process(false)          # niente terreno né interpolazione: la posizione la decide il bestiario
			e.position = Vector3(x, 0, z)
			e.rotation.y = yaw
			_entita.append(e)
			if mostra_nomi:
				var l := Label3D.new()
				l.text = "%s\n%s · %d" % [String(d.get("name", ty)), ty, int(d.get("hp", 0))]
				l.font_size = 36
				l.pixel_size = 0.005
				l.outline_size = 10
				l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				l.position = Vector3(x, 0.12, z + minf(w * 0.45, 1.2))
				add_child(l)
			x += w * 0.5
		z -= prof + 1.0
	var cam := Camera3D.new()
	cam.fov = 30.0
	var dist := maxf(maxf(4.0, alto * 3.2), largo * 1.2 / (2.0 * tan(deg_to_rad(cam.fov * 0.5)) * 1.78) + 2.0)
	var zoom := float(_arg.get("zoom", "1"))
	var mira := float(_arg.get("mira", str(maxf(0.8, alto * 0.5))))
	var cz := z * 0.35
	cam.position = Vector3(0, mira + dist * 0.33 / zoom, cz + dist / zoom)
	add_child(cam)
	cam.look_at(Vector3(0, mira, cz))
	cam.current = true


## Spazio occupato da una figura nella fila (metri).
func _larghezza(ty: String) -> float:
	var d: Dictionary = Dati.MOBS.get(ty, {})
	var taglia: float = {"wolf": 1.5, "boar": 1.5, "bear": 2.1, "tiger": 2.2, "monkey": 1.8, "lantern": 1.3, "shade": 1.4,
			"general": 1.7, "custode": 1.7, "obelisk": 3.2}.get(String(d.get("model", "")), 1.35)
	return taglia * float(d.get("scale", 1.0)) + 0.25


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
	sole.directional_shadow_max_distance = 80.0
	add_child(sole)
	var terra := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2000, 2000)
	terra.mesh = pm
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.3, 0.33, 0.22)
	tm.roughness = 1.0
	terra.material_override = tm
	add_child(terra)


func _process(dt: float) -> void:
	_t += dt
	var posa := String(_arg.get("posa", "fermo"))
	var vel: float = {"passo": 1.8, "corsa": 6.5}.get(posa, 0.0)
	for e: Entita in _entita:
		if e.corpo != null:
			e.corpo.muovi(vel, dt)
	if posa == "attacco":
		_colpo -= dt
		if _colpo <= 0.0:
			_colpo = 1.2
			for e: Entita in _entita:
				if e.corpo != null:
					e.corpo.attacca()
	elif posa == "morte" and not _morti and _t > 0.3:
		_morti = true
		for e: Entita in _entita:
			if e.corpo != null:
				e.corpo.muori()
	var quando := float(_arg.get("dopo", "1.6"))
	if _t >= quando and _arg.has("foto"):
		get_viewport().get_texture().get_image().save_png(String(_arg.foto))
		print("foto: ", _arg.foto)
		_arg.erase("foto")
		get_tree().quit()
