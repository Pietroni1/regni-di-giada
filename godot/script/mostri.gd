class_name Mostri
extends RefCounted
## Figure dei mostri: una ricetta per ogni tipo di MOBS (lupi, cinghiali, orsi, tigri, scimmie, spiriti delle lanterne,
## ombre, banditi, statue, capi) in modo che ogni famiglia si riconosca dalla sagoma e ogni élite dal suo segno.
##  - bestie a quattro zampe: mostri.glb (tools/blender/mostri.py, scheletro degli animali) + bestia.gdshader;
##  - lanterne e ombre: figure costruite da codice che si animano da sole (classi Lanterna e Ombra qui sotto);
##  - umanoidi: corpo base con i completi delle classi, accessori (maschere, turbanti, cappelli, stendardi), armi;
##    le statue con statua.gdshader su tutto il corpo.
## Materiali e mesh condivisi fra i mostri dello stesso tipo (un branco usa un materiale solo); nessuna luce dinamica.
## Élite (vita ≥ 1000, come il server) e capi: un po' più grandi e con un segno a terra (alone_mostro.gdshader).

const Forme := preload("res://script/forme_armi.gd")

static var _mat: Dictionary = {}       # materiali condivisi per chiave
static var _mesh: Dictionary = {}      # mesh condivise per chiave

## Bestie: specie di mostri.glb e parametri del mantello (bestia.gdshaderinc). colore = `color` di MOBS se manca.
const BESTIE := {
	"lupo": {"specie": "lupo", "occhi": Color(0.95, 0.7, 0.2)},
	"lupo_branco": {"specie": "lupo", "sella": 0.9, "segni": Color(0.18, 0.14, 0.12), "ventre": Color(0.86, 0.8, 0.7), "occhi": Color(0.95, 0.75, 0.25)},
	"lupo_canne": {"specie": "lupo", "strisce": 0.7, "segni": Color(0.12, 0.17, 0.1), "criniera": Color(0.22, 0.3, 0.16), "occhi": Color(0.7, 1.0, 0.35)},
	"sciacallo_dune": {"specie": "sciacallo", "sella": 1.0, "segni": Color(0.12, 0.1, 0.09), "ventre": Color(0.95, 0.85, 0.66), "occhi": Color(1.0, 0.6, 0.15)},
	"lupo_alfa": {"specie": "lupo_capo", "criniera": Color(0.2, 0.19, 0.22), "ventre": Color(0.35, 0.34, 0.37), "occhi": Color(1.0, 0.18, 0.1), "occhi_luce": 3.0},
	"lupo_anziano": {"specie": "lupo_capo", "criniera": Color(0.82, 0.82, 0.88), "ventre": Color(0.95, 0.95, 0.98), "sella": 0.5, "segni": Color(0.45, 0.47, 0.55),
			"occhi": Color(0.4, 0.8, 1.0), "occhi_luce": 3.0},
	"cinghiale": {"specie": "cinghiale", "criniera": Color(0.16, 0.11, 0.08), "interno": Color(0.32, 0.2, 0.18)},
	"cinghiale_zanne_ferro": {"specie": "cinghiale_ferro", "criniera": Color(0.12, 0.08, 0.06), "metallo": Color(0.42, 0.42, 0.46), "interno": Color(0.3, 0.18, 0.16), "occhi": Color(1.0, 0.3, 0.1), "occhi_luce": 2.5},
	"orso_nero": {"specie": "orso", "mezzaluna": 1.0, "ventre": Color(0.2, 0.16, 0.14), "criniera": Color(0.1, 0.08, 0.08), "occhi": Color(1.0, 0.45, 0.1)},
	"orso_ventre_giada": {"specie": "orso", "ventre": Color(0.35, 0.85, 0.55), "ventre_luce": 0.9, "criniera": Color(0.08, 0.16, 0.1), "occhi": Color(0.4, 1.0, 0.6), "occhi_luce": 3.0},
	"tigre_spettrale": {"specie": "tigre", "spettro": Color(0.55, 0.8, 1.0), "strisce": 1.0, "segni": Color(0.7, 0.9, 1.0), "segni_luce": 1.6, "occhi": Color(0.6, 0.9, 1.0), "occhi_luce": 4.0},
	"tigre_smeraldo": {"specie": "tigre", "strisce": 1.0, "segni": Color(0.2, 1.0, 0.55), "segni_luce": 1.2, "ventre": Color(0.75, 0.9, 0.78), "occhi": Color(0.3, 1.0, 0.5), "occhi_luce": 3.0},
	"tigre_sole_rovente": {"specie": "tigre", "strisce": 1.0, "segni": Color(1.0, 0.25, 0.05), "segni_luce": 1.6, "ventre": Color(1.0, 0.85, 0.55), "occhi": Color(1.0, 0.8, 0.2), "occhi_luce": 3.5},
	"scimmia": {"specie": "scimmia", "taglia": 1.5, "faccia": Color(0.85, 0.42, 0.36), "criniera": Color(0.62, 0.5, 0.36), "scuro": Color(0.25, 0.15, 0.1), "occhi": Color(0.95, 0.6, 0.15)},
	"scimmia_urlatrice": {"specie": "scimmia_urlatrice", "taglia": 1.5, "faccia": Color(0.18, 0.12, 0.12), "criniera": Color(0.42, 0.18, 0.1), "scuro": Color(0.1, 0.07, 0.06), "occhi": Color(1.0, 0.35, 0.1), "occhi_luce": 2.2},
}
## Ripieghi per modello (mostri nuovi senza ricetta propria)
const SPECIE_DI := {"wolf": "lupo", "boar": "cinghiale", "bear": "orso", "tiger": "tigre", "monkey": "scimmia"}

## Lanterne: carta, fiamma, nastri e particolarità
const LANTERNE := {
	"spirito_lanterna": {"carta": Color(0.98, 0.6, 0.26), "fiamma": Color(1.0, 0.55, 0.15), "nastri": Color(0.75, 0.12, 0.08)},
	"lanterna_cripta": {"carta": Color(0.5, 0.42, 0.95), "fiamma": Color(0.55, 0.45, 1.0), "nastri": Color(0.12, 0.1, 0.16), "crepe": 1.0, "catene": true},
	"lanterna_instabile": {"carta": Color(1.0, 0.35, 0.22), "fiamma": Color(1.0, 0.3, 0.08), "nastri": Color(0.2, 0.08, 0.06), "crepe": 1.5, "tremolio": 1.0},
	"eco_spirito": {"carta": Color(0.75, 0.88, 1.0), "fiamma": Color(0.6, 0.85, 1.0), "nastri": Color(0.85, 0.9, 1.0), "luce": 1.0},
	"spirito_canna": {"carta": Color(0.62, 0.9, 0.42), "fiamma": Color(0.55, 1.0, 0.35), "nastri": Color(0.3, 0.45, 0.18), "canne": 1.0},
}
const OMBRE := {
	"ombra_cripta": {"veste": Color(0.07, 0.06, 0.1), "contorno": Color(0.45, 0.25, 0.95), "occhi": Color(0.75, 0.55, 1.0)},
	"anima_miraggio": {"veste": Color(0.5, 0.36, 0.2), "contorno": Color(1.0, 0.65, 0.25), "occhi": Color(1.0, 0.85, 0.4), "opacita": 0.5},
}

## Umanoidi. completo: [classe, grado]; arma: tipo del gioco o "lancia"/"falcione"/"cerbottana"; testa: stile di metti_testa;
## capi: capi extra del modello (elmi, cappelli); acc: accessori da codice; colori: stoffa, stoffa2, fascia, regno.
const UMANI := {
	"bandito": {"completo": ["ombra", 0], "arma": "sword", "testa": "hood", "acc": ["fazzoletto"], "stoffa": Color(0.36, 0.26, 0.18), "stoffa2": Color(0.2, 0.16, 0.12), "fascia": Color(0.55, 0.12, 0.08), "maschera": Color(0.6, 0.12, 0.08)},
	"arciere_bandito": {"completo": ["ombra", 1], "arma": "bow", "testa": "short", "capi": ["cappello_paglia"], "acc": ["fazzoletto"], "stoffa": Color(0.3, 0.32, 0.2), "stoffa2": Color(0.2, 0.18, 0.13), "fascia": Color(0.45, 0.35, 0.2), "maschera": Color(0.15, 0.13, 0.12)},
	"predone": {"completo": ["lama", 0], "arma": "daggers", "testa": "topknot", "acc": ["fascia_fronte", "pelliccia"], "stoffa": Color(0.48, 0.2, 0.12), "stoffa2": Color(0.18, 0.12, 0.1), "fascia": Color(0.25, 0.18, 0.12), "maschera": Color(0.85, 0.75, 0.55)},
	"razziatore_gola": {"completo": ["lama", 1], "arma": "sword", "testa": "short", "capi": ["elmo_cornuto"], "acc": ["pelliccia", "pittura"], "stoffa": Color(0.32, 0.36, 0.26), "stoffa2": Color(0.16, 0.15, 0.12), "fascia": Color(0.5, 0.4, 0.25), "cuoio": Color(0.3, 0.2, 0.13)},
	"brigante_selva": {"completo": ["ombra", 1], "arma": "daggers", "testa": "hood", "acc": ["fazzoletto", "foglie"], "stoffa": Color(0.16, 0.28, 0.14), "stoffa2": Color(0.12, 0.16, 0.1), "fascia": Color(0.4, 0.32, 0.15), "maschera": Color(0.1, 0.18, 0.08)},
	"cerbottaniere_selva": {"completo": ["ombra", 0], "arma": "cerbottana", "testa": "short", "capi": ["cappello_paglia"], "acc": ["fazzoletto", "foglie"], "stoffa": Color(0.24, 0.32, 0.16), "stoffa2": Color(0.14, 0.18, 0.1), "fascia": Color(0.55, 0.45, 0.2), "maschera": Color(0.35, 0.42, 0.2)},
	"predone_dune": {"completo": ["lama", 1], "arma": "sword", "testa": "bald", "acc": ["turbante", "velo"], "stoffa": Color(0.72, 0.58, 0.38), "stoffa2": Color(0.45, 0.32, 0.2), "fascia": Color(0.6, 0.2, 0.1), "maschera": Color(0.82, 0.72, 0.52)},
	"arciere_simun": {"completo": ["ombra", 1], "arma": "bow", "testa": "bald", "acc": ["turbante", "velo"], "stoffa": Color(0.55, 0.3, 0.16), "stoffa2": Color(0.35, 0.22, 0.14), "fascia": Color(0.75, 0.6, 0.3), "maschera": Color(0.3, 0.12, 0.08)},
	"generale": {"completo": ["lama", 4], "arma": "falcione", "testa": "short", "capi": ["elmo_drago"], "acc": ["stendardi", "pennacchio"], "stoffa": Color(0.3, 0.08, 0.06), "stoffa2": Color(0.12, 0.08, 0.07), "fascia": Color(0.75, 0.58, 0.3), "regno": Color(0.55, 0.1, 0.08)},
}
## Statue (corpo base + statua.gdshader). materia: 0 argilla, 1 bronzo, 2 arenaria, 3 pietra scura.
const STATUE := {
	"soldato_terracotta": {"completo": ["lama", 2], "arma": "sword", "testa": "topknot", "materia": 0, "colore": Color(0.66, 0.4, 0.27)},
	"lanciere_bronzo": {"completo": ["lama", 2], "arma": "lancia", "capi": ["elmo_bronzo"], "materia": 1, "colore": Color(0.55, 0.4, 0.22)},
	"terracotta": {"completo": ["lama", 3], "arma": "sword", "testa": "topknot", "materia": 0, "colore": Color(0.62, 0.34, 0.22), "luce": Color(1.0, 0.42, 0.08)},
	"sentinella_cripta": {"completo": ["lama", 4], "arma": "lancia", "capi": ["elmo_cornuto"], "materia": 1, "colore": Color(0.38, 0.3, 0.2), "luce": Color(0.6, 0.35, 1.0)},
	"guerriero_arenaria": {"completo": ["lama", 1], "arma": "sword", "capi": ["elmo_bronzo"], "materia": 2, "colore": Color(0.8, 0.64, 0.42)},
	"campione_arenaria": {"completo": ["lama", 4], "arma": "falcione", "capi": ["elmo_drago"], "materia": 2, "colore": Color(0.78, 0.6, 0.38), "luce": Color(1.0, 0.7, 0.25), "oro": 1.0},
	"custode_insonne": {"completo": ["lama", 4], "arma": "sword", "capi": ["elmo_drago"], "materia": 3, "colore": Color(0.22, 0.2, 0.26), "luce": Color(0.65, 0.3, 1.0), "aureola": true},
}


# ------------------------------------------------------------------ ingresso
## Figura di un mostro. ty = chiave di MOBS; d = la sua voce. null se il modello non è dei mostri (obelischi, fantocci).
static func crea(ty: String, d: Dictionary) -> Personaggio:
	var scala := float(d.get("scale", 1.0))
	var colore := Dati.colore(d.get("color", 0x777777))
	var modello := String(d.get("model", ""))
	var hp := float(d.get("hp", 0))
	var capo := modello in ["general", "custode"]
	var elite := hp >= 1000.0 and not capo
	# élite e capi un po' più grandi della taglia del server (la sagoma deve dirlo da lontano)
	var vista := scala * (1.08 if elite else (1.12 if capo else 1.0))
	var p: Personaggio = null
	if BESTIE.has(ty) or SPECIE_DI.has(modello):
		var r: Dictionary = BESTIE.get(ty, {"specie": SPECIE_DI.get(modello, "lupo")})
		p = bestia(ty, r, colore, vista)
	elif LANTERNE.has(ty) or modello == "lantern":
		p = Lanterna.crea(ty, LANTERNE.get(ty, {"carta": colore, "fiamma": colore, "nastri": colore.darkened(0.5)}), vista)
	elif OMBRE.has(ty) or modello == "shade":
		p = Ombra.crea(ty, OMBRE.get(ty, {"veste": colore.darkened(0.7), "contorno": colore, "occhi": colore.lightened(0.4)}), vista)
	elif STATUE.has(ty) or modello in ["terracotta", "custode"]:
		p = statua(ty, STATUE.get(ty, {"completo": ["lama", 2], "arma": "sword", "materia": 0, "colore": colore}), vista)
	elif UMANI.has(ty) or modello.begins_with("bandit") or modello == "general":
		var u: Dictionary = UMANI.get(ty, {"completo": ["ombra", 0], "arma": "bow" if modello == "bandit_archer" else "sword", "testa": "hood", "stoffa": colore})
		p = umanoide(ty, u, vista)
	if p == null:
		return null
	if capo:
		segno(p, Color(1.0, 0.35, 0.15) if modello == "general" else Color(0.65, 0.35, 1.0), 1.5 * vista, true)
	elif elite:
		segno(p, Color(1.0, 0.78, 0.35), 1.0 * vista * (1.25 if modello in ["tiger", "bear"] else 1.0), false)
	return p


# ------------------------------------------------------------------ bestie
static func bestia(ty: String, r: Dictionary, colore: Color, scala: float) -> Personaggio:
	var k := "bestia:" + ty
	if not _mat.has(k):
		var m := ShaderMaterial.new()
		var spettro := r.has("spettro")
		m.shader = load("res://shader/bestia_spettro.gdshader" if spettro else "res://shader/bestia.gdshader")
		m.set_shader_parameter("colore", r.get("colore", colore))
		for nome in ["ventre", "criniera", "scuro", "occhi", "zanne", "faccia", "metallo", "segni", "interno"]:
			if r.has(nome):
				m.set_shader_parameter(nome, r[nome])
		for nome in ["occhi_luce", "strisce", "sella", "mezzaluna", "segni_luce", "ventre_luce"]:
			if r.has(nome):
				m.set_shader_parameter(nome, r[nome])
		if spettro:
			m.set_shader_parameter("luce", r.spettro)
		_mat[k] = m
	var p := Personaggio.quadrupede("mostri", String(r.specie), _mat[k], scala * float(r.get("taglia", 1.0)))
	if p != null and r.has("spettro"):
		for n in p.scheletro.get_children():
			if n is GeometryInstance3D:
				(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


# ------------------------------------------------------------------ segno di élite e capi
static func segno(p: Personaggio, c: Color, raggio: float, capo: bool) -> void:
	var k := "alone:%s:%s" % [c.to_html(), capo]
	if not _mat.has(k):
		var m := ShaderMaterial.new()
		m.shader = load("res://shader/alone_mostro.gdshader")
		m.set_shader_parameter("colore", c)
		m.set_shader_parameter("capo", 1.0 if capo else 0.0)
		m.set_shader_parameter("forza", 1.1 if capo else 0.8)
		_mat[k] = m
	if not _mesh.has("piano"):
		var pm := PlaneMesh.new()
		pm.size = Vector2(2, 2)
		_mesh["piano"] = pm
	var mi := MeshInstance3D.new()
	mi.name = "SegnoElite"
	mi.mesh = _mesh["piano"]
	mi.material_override = _mat[k]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.04
	mi.scale = Vector3.ONE * raggio / maxf(0.01, p.scale.x)      # gli umanoidi sono già scalati
	p.add_child(mi)


# ------------------------------------------------------------------ umanoidi
static func _tinte(u: Dictionary) -> Dictionary:
	var stoffa: Color = u.get("stoffa", Color(0.4, 0.3, 0.2))
	var t := {"stoffa": stoffa, "stoffa2": u.get("stoffa2", stoffa.darkened(0.35)), "fascia": u.get("fascia", stoffa.darkened(0.5)),
			"regno": u.get("regno", u.get("fascia", Color(0.45, 0.1, 0.08)))}
	if u.has("cuoio"):
		t["cuoio"] = u.cuoio
	return t


static func _arma_gioco(arma: String) -> String:
	return {"lancia": "staff", "falcione": "staff", "cerbottana": "staff"}.get(arma, arma)


static func umanoide(ty: String, u: Dictionary, scala: float) -> Personaggio:
	var cl: Array = u.completo
	var wear := {}
	var tinte := _tinte(u)
	if Entita.ha_completi("base_uomo"):
		wear = Entita.completo(String(cl[0]), int(cl[1]), tinte)
	else:
		wear = {"veste": tinte.stoffa, "pantaloni": tinte.stoffa2}
	for c in u.get("capi", []):
		wear[c] = true
	wear["stivali_cuoio" if int(cl[1]) >= 1 else "sandali"] = true
	var arma := String(u.get("arma", "sword"))
	# armi speciali: forma rifatta su un bastone di grado 1 (quelli di grado più alto hanno parti animate)
	var grado := 1 if arma in ["lancia", "falcione", "cerbottana"] else clampi(int(cl[1]), 1, 4)
	var p := Personaggio.umano("base_uomo", wear, _arma_gioco(arma), grado, Color(0.62, 0.47, 0.36), tinte.fascia)
	p.metti_testa(String(u.get("testa", "short")), Color(0.08, 0.07, 0.06), tinte.stoffa.darkened(0.25))
	_arma_speciale(p, arma, tinte)
	for a in u.get("acc", []):
		_accessorio(p, String(a), u, tinte)
	p.scale = Vector3.ONE * scala
	return p


static func statua(ty: String, s: Dictionary, scala: float) -> Personaggio:
	var u := s.duplicate()
	u["stoffa"] = s.colore
	var p := umanoide(ty, u, scala)
	var k := "statua:" + ty
	if not _mat.has(k):
		var m := ShaderMaterial.new()
		m.shader = load("res://shader/statua.gdshader")
		m.set_shader_parameter("colore", s.colore)
		m.set_shader_parameter("materia", int(s.materia))
		if s.has("luce"):
			m.set_shader_parameter("crepe_col", s.luce)
			m.set_shader_parameter("crepe_luce", 2.2)
			m.set_shader_parameter("crepe", 1.4)
		m.set_shader_parameter("oro", float(s.get("oro", 0.0)))
		_mat[k] = m
	# tutto il corpo e le vesti di materia (i capi nascosti spariscono con sfoltisci)
	for n in p.scheletro.get_children():
		var mi := n as MeshInstance3D
		if mi != null and mi.visible:
			mi.material_override = _mat[k]
			for si in range(mi.get_surface_override_material_count()):
				mi.set_surface_override_material(si, null)
	if s.get("aureola", false):
		_aureola(p, s.get("luce", Color(0.65, 0.3, 1.0)))
	# occhi accesi nel volto della statua
	if s.has("luce"):
		_occhi(p, s.luce)
	return p


## Nodo agganciato alla testa e centro del cranio (le stesse misure di Personaggio.metti_testa).
static func _testa(p: Personaggio) -> Array:
	var ba := BoneAttachment3D.new()
	ba.bone_name = "head"
	p.scheletro.add_child(ba)
	var su := p.altezza - 0.28 - p.scheletro.get_bone_global_rest(p.scheletro.find_bone("head")).origin.y
	return [ba, Vector3(0, 0.125 + su, 0.012), 0.135]


static func _osso(p: Personaggio, osso: String) -> BoneAttachment3D:
	var ba := BoneAttachment3D.new()
	ba.bone_name = osso
	p.scheletro.add_child(ba)
	return ba


static func _stoffa(c: Color) -> ShaderMaterial:
	var k := "stoffa:" + c.to_html()
	if not _mat.has(k):
		var m := ShaderMaterial.new()
		m.shader = load("res://shader/stoffa.gdshader")
		m.set_shader_parameter("colore", c)
		_mat[k] = m
	return _mat[k]


static func _nastro(c: Color, orlo: Color, ampiezza := 0.12, stemma := 0.0, luce := 0.0, frange := 0.0) -> ShaderMaterial:
	var k := "nastro:%s:%s:%s:%s:%s:%s" % [c.to_html(), orlo.to_html(), ampiezza, stemma, luce, frange]
	if not _mat.has(k):
		var m := ShaderMaterial.new()
		m.shader = load("res://shader/nastro.gdshader")
		m.set_shader_parameter("colore", c)
		m.set_shader_parameter("orlo", orlo)
		m.set_shader_parameter("ampiezza", ampiezza)
		m.set_shader_parameter("stemma", stemma)
		m.set_shader_parameter("luce", luce)
		m.set_shader_parameter("frange", frange)
		_mat[k] = m
	return _mat[k]


## Striscia appesa per il bordo alto (UV.y = 0 in cima), suddivisa per ondeggiare (nastro.gdshader).
static func _striscia(larga: float, lunga: float) -> Mesh:
	var k := "striscia:%s:%s" % [larga, lunga]
	if not _mesh.has(k):
		var q := QuadMesh.new()
		q.size = Vector2(larga, lunga)
		q.subdivide_depth = 6
		q.center_offset = Vector3(0, -lunga * 0.5, 0)
		_mesh[k] = q
	return _mesh[k]


## Cilindro e anello come quelli di forme_armi.gd, ma con la mesh condivisa fra tutte le figure (branchi interi).
static func _cil(r_alto: float, r_basso: float, h: float, pos: Vector3, m: Material, gen: Node3D, rot := Vector3.ZERO, lati := 10) -> MeshInstance3D:
	var k := "cil:%s:%s:%s:%s" % [r_alto, r_basso, h, lati]
	if not _mesh.has(k):
		var c := CylinderMesh.new()
		c.top_radius = r_alto
		c.bottom_radius = r_basso
		c.height = h
		c.radial_segments = lati
		c.rings = 1
		_mesh[k] = c
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh[k]
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gen.add_child(mi)
	return mi


static func _anello(r: float, sp: float, m: Material, gen: Node3D, pos: Vector3, rot := Vector3.ZERO, lati := 20) -> MeshInstance3D:
	var k := "anello:%s:%s:%s" % [r, sp, lati]
	if not _mesh.has(k):
		var t := TorusMesh.new()
		t.inner_radius = r - sp
		t.outer_radius = r + sp
		t.rings = lati
		t.ring_segments = 6
		_mesh[k] = t
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh[k]
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gen.add_child(mi)
	return mi


static func _sfera(r: float, pos: Vector3, m: Material, gen: Node3D, scala := Vector3.ONE, mezza := false) -> MeshInstance3D:
	var k := "sfera:%s:%s" % [r, mezza]
	if not _mesh.has(k):
		var s := SphereMesh.new()
		s.radius = r
		s.height = r if mezza else r * 2.0
		s.is_hemisphere = mezza
		s.radial_segments = 16
		s.rings = 8
		_mesh[k] = s
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh[k]
	mi.material_override = m
	mi.position = pos
	mi.scale = scala
	gen.add_child(mi)
	return mi


static func _accessorio(p: Personaggio, a: String, u: Dictionary, tinte: Dictionary) -> void:
	var t := _testa(p)
	var ba: BoneAttachment3D = t[0]
	var centro: Vector3 = t[1]
	var r: float = t[2]
	var masc: Color = u.get("maschera", tinte.fascia)
	match a:
		"fazzoletto":
			# fazzoletto annodato sulla parte bassa del volto, con la punta che scende sul petto
			var m := _stoffa(masc)
			var c := Mostri._cil(r * 1.04, r * 0.98, 0.085, centro + Vector3(0, -0.075, 0.004), m, ba, Vector3.ZERO, 16)
			c.scale = Vector3(1.0, 1.0, 1.06)
			var punta := Mostri._cil(0.0, 0.07, 0.12, centro + Vector3(0, -0.16, r * 0.82), m, ba, Vector3(0.25, 0, 0), 4)
			punta.scale = Vector3(1.3, 1.0, 0.35)
			Mostri._cil(0.012, 0.012, 0.09, centro + Vector3(0, -0.06, -r * 1.02), m, ba, Vector3(0.9, 0, 0), 5)        # nodo dietro
		"velo":
			# velo del deserto: copre naso e bocca e ricade sulle spalle
			var m := _stoffa(masc)
			var v := Mostri._cil(r * 1.04, r * 1.1, 0.1, centro + Vector3(0, -0.085, 0.0), m, ba, Vector3.ZERO, 16)
			v.scale = Vector3(1.0, 1.0, 1.05)
			var cad := MeshInstance3D.new()
			cad.mesh = _striscia(0.26, 0.3)
			cad.material_override = _nastro(masc, masc.darkened(0.3), 0.04)
			cad.position = centro + Vector3(0, -0.02, -r * 1.05)
			ba.add_child(cad)
		"turbante":
			var m := _stoffa(tinte.stoffa.lightened(0.15))
			for i in range(3):
				var giro := TorusMesh.new()
				giro.inner_radius = r * (0.82 - i * 0.12)
				giro.outer_radius = r * (1.18 - i * 0.14)
				giro.rings = 16
				giro.ring_segments = 8
				var mi := MeshInstance3D.new()
				mi.mesh = giro
				mi.material_override = m
				mi.position = centro + Vector3(0, 0.065 + i * 0.04, -0.012)
				mi.rotation.x = -0.12 + i * 0.05
				ba.add_child(mi)
			_sfera(r * 0.85, centro + Vector3(0, 0.07, -0.012), m, ba, Vector3(1.0, 0.95, 1.0), true)
			_sfera(0.022, centro + Vector3(0, 0.085, r * 1.08), Forme.luce(Color(0.9, 0.2, 0.15), 1.2), ba)    # gemma sulla fronte
		"fascia_fronte":
			var m := _stoffa(masc)
			Mostri._cil(r * 1.02, r * 1.02, 0.035, centro + Vector3(0, 0.08, -0.005), m, ba, Vector3(0.12, 0, 0), 16)
			for sx in [-1.0, 1.0]:
				var coda := MeshInstance3D.new()
				coda.mesh = _striscia(0.035, 0.28)
				coda.material_override = _nastro(masc, masc, 0.06)
				coda.position = centro + Vector3(sx * 0.03, 0.075, -r * 1.02)
				coda.rotation.z = sx * 0.2
				ba.add_child(coda)
		"pittura":
			# segni di guerra sul volto: due bande rosse sotto gli occhi
			var m := Forme.opaco(Color(0.6, 0.05, 0.04), 0.9)
			for sx in [-1.0, 1.0]:
				Forme.scatola(Vector3(0.05, 0.012, 0.01), centro + Vector3(sx * 0.045, -0.02, r * 0.93), m, ba, Vector3(0, sx * 0.4, sx * 0.3))
		"pelliccia":
			# mantello di pelliccia sulle spalle: un collare folto
			var ps := _osso(p, "chest")
			var m := _stoffa(Color(0.35, 0.28, 0.22))
			m.set_shader_parameter("cuoio", 0.0)
			var giro := TorusMesh.new()
			giro.inner_radius = 0.09
			giro.outer_radius = 0.25
			giro.rings = 18
			giro.ring_segments = 10
			var c := MeshInstance3D.new()
			c.mesh = giro
			c.material_override = m
			c.position = Vector3(0, 0.27, -0.02)
			c.scale = Vector3(1.05, 0.55, 0.85)
			ps.add_child(c)
			for i in range(9):
				var ang := -PI * 0.6 + PI * 1.2 * float(i) / 8.0
				var ciuffo := _sfera(0.07, Vector3(sin(ang) * 0.2, 0.25, -cos(ang) * 0.16 - 0.03), m, ps, Vector3(1.0, 0.7, 1.6))
				ciuffo.rotation.y = ang
		"foglie":
			# mantellina di foglie e frasche sulle spalle
			var ps := _osso(p, "chest")
			var verdi := [Color(0.2, 0.36, 0.14), Color(0.28, 0.42, 0.16), Color(0.16, 0.28, 0.12)]
			for i in range(12):
				var ang := -PI * 0.65 + PI * 1.3 * float(i) / 11.0
				var f := MeshInstance3D.new()
				f.mesh = _striscia(0.11, 0.3)
				f.material_override = _nastro(verdi[i % 3], verdi[(i + 1) % 3], 0.03)
				f.position = Vector3(sin(ang) * 0.22, 0.3, -cos(ang) * 0.15)
				f.rotation = Vector3(-0.35, ang + PI, 0)
				ps.add_child(f)
		"pennacchio":
			# pennacchio rosso in cima all'elmo
			var m := _stoffa(Color(0.7, 0.08, 0.06))
			var c := Mostri._cil(0.0, 0.07, 0.34, centro + Vector3(0, r + 0.2, -0.05), m, ba, Vector3(-0.5, 0, 0), 8)
			c.scale = Vector3(1.0, 1.0, 1.4)
		"stendardi":
			# due stendardi sulla schiena, rossi con il disco d'oro
			var ps := _osso(p, "chest")
			var legno := Forme.opaco(Color(0.2, 0.12, 0.08), 0.6)
			for sx in [-1.0, 1.0]:
				var base := Vector3(sx * 0.12, 0.05, -0.2)
				Mostri._cil(0.014, 0.016, 1.5, base + Vector3(0, 0.75, 0), legno, ps, Vector3(0, 0, -sx * 0.08), 6)
				Mostri._cil(0.0, 0.03, 0.09, base + Vector3(-sx * 0.12, 1.55, 0), Forme.acciaio(Color(0.85, 0.65, 0.3)), ps, Vector3(0, 0, -sx * 0.08), 6)
				var f := MeshInstance3D.new()
				f.mesh = _striscia(0.3, 0.75)
				f.material_override = _nastro(Color(0.62, 0.08, 0.06), Color(0.85, 0.65, 0.3), 0.08, 1.0, 0.0, 1.0)
				f.position = base + Vector3(sx * 0.17, 1.48, -0.01)
				f.rotation = Vector3(0, 0, -sx * 0.08)
				ps.add_child(f)


## Armi che il gioco non ha: si tiene la presa del bastone (verticale, puntale a terra) e si cambia la forma.
static func _arma_speciale(p: Personaggio, arma: String, tinte: Dictionary) -> void:
	if not arma in ["lancia", "falcione", "cerbottana"]:
		return
	for a in p.armi:
		var n := a as Node3D
		for c in n.get_children():
			c.free()
		var legno := Forme.opaco(Color(0.28, 0.17, 0.1), 0.6)
		var ferro := Forme.acciaio(Color(0.62, 0.6, 0.58), 0.3)
		var oro := Forme.acciaio(Color(0.85, 0.62, 0.28), 0.3)
		match arma:
			"lancia":
				Mostri._cil(0.02, 0.022, 2.5, Vector3(0, 0.25, 0), legno, n, Vector3.ZERO, 8)
				var punta := Mostri._cil(0.0, 0.045, 0.34, Vector3(0, 1.66, 0), ferro, n, Vector3.ZERO, 4)
				punta.scale = Vector3(1.0, 1.0, 0.3)
				Mostri._cil(0.03, 0.026, 0.07, Vector3(0, 1.47, 0), oro, n, Vector3.ZERO, 8)
				var nappa := MeshInstance3D.new()
				nappa.mesh = _striscia(0.06, 0.18)
				nappa.material_override = _nastro(tinte.regno, tinte.regno, 0.05, 0.0, 0.0, 1.0)
				nappa.position = Vector3(0, 1.44, 0)
				n.add_child(nappa)
			"falcione":
				# lama larga e ricurva in cima a un'asta lunga, con il dorso uncinato
				Mostri._cil(0.024, 0.026, 2.4, Vector3(0, 0.2, 0), Forme.opaco(Color(0.35, 0.08, 0.06), 0.5), n, Vector3.ZERO, 8)
				var st := Forme.profilo(1.38, 0.62, 0.14, 0.09, 0.12, 0.02, 0.18)
				var lama := Forme.lama(st, ferro, n)
				lama.set_meta(Forme.ACCENDI, true)
				Mostri._cil(0.04, 0.034, 0.1, Vector3(0, 1.36, 0), oro, n, Vector3.ZERO, 8)
				Mostri._cil(0.0, 0.04, 0.12, Vector3(0, -0.98, 0), oro, n, Vector3.ZERO, 6)
			"cerbottana":
				Mostri._cil(0.016, 0.018, 1.7, Vector3(0, 0.45, 0), Forme.opaco(Color(0.55, 0.5, 0.3), 0.6), n, Vector3.ZERO, 8)
				for i in range(4):
					Mostri._cil(0.021, 0.021, 0.02, Vector3(0, -0.2 + i * 0.4, 0), legno, n, Vector3.ZERO, 8)


static func _occhi(p: Personaggio, c: Color) -> void:
	var t := _testa(p)
	var m := Forme.luce(c, 3.0)
	for sx in [-1.0, 1.0]:
		var o := _sfera(0.013, t[1] + Vector3(sx * 0.035, 0.0, float(t[2]) * 0.92), m, t[0], Vector3(1.4, 0.7, 0.6))
		o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _aureola(p: Personaggio, c: Color) -> void:
	var t := _testa(p)
	var anello := TorusMesh.new()
	anello.inner_radius = 0.3
	anello.outer_radius = 0.33
	anello.rings = 32
	anello.ring_segments = 6
	var mi := MeshInstance3D.new()
	mi.mesh = anello
	mi.material_override = Forme.luce(c, 2.2)
	mi.position = t[1] + Vector3(0, 0.04, -0.22)
	mi.rotation.x = PI * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t[0].add_child(mi)
	for i in range(8):
		var ang := TAU * float(i) / 8.0
		var s := Mostri._cil(0.0, 0.03, 0.09, Vector3(cos(ang) * 0.38, sin(ang) * 0.38, 0), Forme.luce(c, 2.2), mi, Vector3(0, 0, ang - PI * 0.5), 4)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ------------------------------------------------------------------ figure che fluttuano
## Base delle figure senza scheletro: si animano da codice in muovi() (fluttuare, inclinarsi, colpire, morire).
class Fluttuante:
	extends Personaggio
	var perno: Node3D            # parte che fluttua
	var quota := 1.5
	var t := 0.0
	var colpo := 0.0             # 1 → 0 durante un attacco
	var urto := 0.0              # 1 → 0 quando è colpito
	var fine := 0.0              # 0 → 1 durante la morte
	var vel := 0.0
	var scala := 1.0
	var fase := 0.0

	func _init() -> void:
		fase = randf() * TAU

	func muovi(v: float, dt: float) -> void:
		t += dt
		vel = lerpf(vel, v, minf(1.0, dt * 6.0))
		colpo = maxf(0.0, colpo - dt / 0.7)
		urto = maxf(0.0, urto - dt / 0.35)
		if morto:
			fine = minf(1.0, fine + dt / 1.2)
		anima(dt)

	func anima(_dt: float) -> void:
		pass

	func attacca() -> void:
		if not morto:
			colpo = 1.0

	func lancia() -> void:
		attacca()

	func colpito() -> void:
		urto = 1.0

	func muori() -> void:
		morto = true
		fine = 0.0
		_segno_elite(false)

	func rialza() -> void:
		morto = false
		fine = 0.0
		_segno_elite(true)


class Lanterna:
	extends Fluttuante
	var fiamma: MeshInstance3D
	var mat_accesa: Material
	var mat_spenta: Material
	var carta_mi: MeshInstance3D
	var tremolio := 0.0

	static func crea(ty: String, r: Dictionary, sc: float) -> Personaggio:
		var p := Lanterna.new()
		p.scala = sc
		p.quota = 1.45 * sc
		p.altezza = 2.25 * sc
		p.tremolio = float(r.get("tremolio", 0.0))
		p.perno = Node3D.new()
		p.add_child(p.perno)
		var corpo := Node3D.new()
		corpo.scale = Vector3.ONE * sc
		p.perno.add_child(corpo)
		var k := "lanterna:" + ty
		if not Mostri._mat.has(k):
			var m := ShaderMaterial.new()
			m.shader = load("res://shader/lanterna_spirito.gdshader")
			m.set_shader_parameter("carta", r.carta)
			m.set_shader_parameter("fiamma", r.fiamma)
			m.set_shader_parameter("crepe", float(r.get("crepe", 0.0)))
			m.set_shader_parameter("canne", float(r.get("canne", 0.0)))
			m.set_shader_parameter("tremolio", p.tremolio)
			m.set_shader_parameter("accesa", 1.8 + float(r.get("luce", 0.0)))
			var spenta: ShaderMaterial = m.duplicate()
			spenta.set_shader_parameter("accesa", 0.0)
			Mostri._mat[k] = m
			Mostri._mat[k + ":spenta"] = spenta
			var f := ShaderMaterial.new()
			f.shader = load("res://shader/fiammella.gdshader")
			f.set_shader_parameter("colore", r.fiamma)
			Mostri._mat[k + ":fiamma"] = f
		p.mat_accesa = Mostri._mat[k]
		p.mat_spenta = Mostri._mat[k + ":spenta"]
		p.carta_mi = MeshInstance3D.new()
		p.carta_mi.mesh = _carta()
		p.carta_mi.material_override = p.mat_accesa
		corpo.add_child(p.carta_mi)
		# anelli di legno laccato in cima e in fondo, gancio e cordino
		var lacca := Forme.opaco(Color(0.12, 0.06, 0.05), 0.4)
		Mostri._cil(0.19, 0.2, 0.06, Vector3(0, 0.34, 0), lacca, corpo, Vector3.ZERO, 14)
		Mostri._cil(0.2, 0.19, 0.06, Vector3(0, -0.34, 0), lacca, corpo, Vector3.ZERO, 14)
		Mostri._anello(0.06, 0.012, lacca, corpo, Vector3(0, 0.43, 0), Vector3(PI * 0.5, 0, 0), 12)
		# fiammella dello spirito che arde sopra la lanterna
		p.fiamma = MeshInstance3D.new()
		if not Mostri._mesh.has("fiammella"):
			var q := QuadMesh.new()
			q.size = Vector2(0.34, 0.6)
			Mostri._mesh["fiammella"] = q
		p.fiamma.mesh = Mostri._mesh["fiammella"]
		p.fiamma.material_override = Mostri._mat[k + ":fiamma"]
		p.fiamma.position = Vector3(0, 0.66, 0)
		p.fiamma.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		corpo.add_child(p.fiamma)
		# nastri (o catene) appesi sotto
		var catene: bool = r.get("catene", false)
		var mn := Mostri._nastro(r.nastri, Color(0.9, 0.85, 0.75) if not catene else r.nastri, 0.1, 0.0, 0.0 if not catene else 0.3, 0.0 if catene else 1.0)
		for i in range(4):
			var ang := TAU * float(i) / 4.0 + 0.4
			var n := MeshInstance3D.new()
			n.mesh = Mostri._striscia(0.05 if not catene else 0.035, 0.55 + 0.12 * float(i % 2))
			n.material_override = mn
			n.position = Vector3(cos(ang) * 0.13, -0.36, sin(ang) * 0.13)
			n.rotation.y = -ang
			corpo.add_child(n)
		return p

	## Carta della lanterna: tornio a 16 lati, aperto in alto e in basso; UV.x = giro (0,25 davanti), UV.y = in alto.
	static func _carta() -> Mesh:
		if Mostri._mesh.has("carta"):
			return Mostri._mesh["carta"]
		var prof := [[0.17, -0.34], [0.27, -0.27], [0.33, -0.12], [0.345, 0.0], [0.33, 0.12], [0.27, 0.27], [0.17, 0.34]]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var lati := 16
		for i in range(prof.size() - 1):
			for j in range(lati):
				var quad := [[i, j], [i + 1, j], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i, j + 1]]
				for v in quad:
					var pr: Array = prof[v[0]]
					var a := TAU * float(v[1]) / float(lati)
					st.set_uv(Vector2(float(v[1]) / float(lati), (float(pr[1]) + 0.34) / 0.68))
					st.add_vertex(Vector3(cos(a) * float(pr[0]), float(pr[1]), sin(a) * float(pr[0])))
		st.generate_normals()
		var m := st.commit()
		Mostri._mesh["carta"] = m
		return m

	func anima(dt: float) -> void:
		var su := sin(t * 1.9 + fase) * 0.12 * scala
		var avanti := clampf(vel / 6.0, 0.0, 1.0)
		if morto:
			# la fiamma si spegne, la lanterna cade e si accartoccia
			carta_mi.material_override = mat_spenta
			fiamma.visible = false
			perno.position.y = lerpf(quota, 0.25 * scala, fine * fine)
			perno.rotation.z = lerpf(0.0, 1.35, fine)
			perno.scale = Vector3(1.0 + 0.15 * fine, 1.0 - 0.35 * fine, 1.0 + 0.15 * fine)
			return
		carta_mi.material_override = mat_accesa
		fiamma.visible = true
		var sc := 1.0 + 0.18 * sin(colpo * PI)
		perno.scale = Vector3.ONE * sc
		perno.position = Vector3(0, quota + su, sin(colpo * PI) * 0.7 * scala)
		perno.rotation.x = avanti * 0.35 + sin(colpo * PI) * 0.5 - urto * 0.3
		perno.rotation.z = sin(t * 1.3 + fase) * 0.08 + urto * 0.25 * sin(t * 40.0)
		if tremolio > 0.0:
			perno.position.x = (randf() - 0.5) * 0.04 * tremolio * scala
		fiamma.scale = Vector3.ONE * (1.0 + 0.6 * colpo + 0.1 * sin(t * 9.0))


class Ombra:
	extends Fluttuante
	var braccia: Array = []      # perni delle maniche
	var cappuccio: Node3D

	static func crea(ty: String, r: Dictionary, sc: float) -> Personaggio:
		var p := Ombra.new()
		p.scala = sc
		p.quota = 0.15 * sc
		p.altezza = 2.05 * sc
		p.perno = Node3D.new()
		p.add_child(p.perno)
		var corpo := Node3D.new()
		corpo.scale = Vector3.ONE * sc
		p.perno.add_child(corpo)
		var k := "ombra:" + ty
		if not Mostri._mat.has(k):
			var m := ShaderMaterial.new()
			m.shader = load("res://shader/spettro.gdshader")
			m.set_shader_parameter("colore", r.veste)
			m.set_shader_parameter("contorno", r.contorno)
			m.set_shader_parameter("opacita", float(r.get("opacita", 0.85)))
			Mostri._mat[k] = m
		var mv: ShaderMaterial = Mostri._mat[k]
		var veste := MeshInstance3D.new()
		veste.mesh = _veste()
		veste.material_override = mv
		veste.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		corpo.add_child(veste)
		# cappuccio a punta, buio dentro, due occhi accesi
		p.cappuccio = Node3D.new()
		p.cappuccio.position = Vector3(0, 1.66, 0.02)
		corpo.add_child(p.cappuccio)
		var cap := MeshInstance3D.new()
		cap.mesh = _cappuccio()
		cap.material_override = mv
		p.cappuccio.add_child(cap)
		Mostri._sfera(0.15, Vector3(0, -0.02, 0.07), Forme.opaco(Color(0.0, 0.0, 0.0), 1.0), p.cappuccio, Vector3(0.9, 1.0, 0.6))
		var mo := Forme.luce(r.occhi, 4.0)
		for sx in [-1.0, 1.0]:
			var o := Mostri._sfera(0.022, Vector3(sx * 0.055, 0.0, 0.17), mo, p.cappuccio, Vector3(1.5, 0.6, 0.5))
			o.rotation.z = -sx * 0.35
		# maniche lunghe con mani ad artiglio
		var artiglio := Forme.opaco(Color(0.05, 0.04, 0.06), 0.4)
		for sx in [-1.0, 1.0]:
			var spalla := Node3D.new()
			spalla.position = Vector3(sx * 0.27, 1.42, 0.0)
			corpo.add_child(spalla)
			var manica := MeshInstance3D.new()
			manica.mesh = _manica()
			manica.material_override = mv
			manica.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			spalla.add_child(manica)
			for d in range(3):
				Mostri._cil(0.0, 0.018, 0.17, Vector3(sx * 0.0 + (d - 1) * 0.035, -0.72, 0.06), artiglio, spalla, Vector3(0.35, 0, 0), 4)
			p.braccia.append(spalla)
		return p

	## Veste: tornio dalle spalle all'orlo, aperta in fondo. UV.y = 0 in alto, 1 all'orlo (lo shader la sfrangia).
	static func _veste() -> Mesh:
		if Mostri._mesh.has("veste_ombra"):
			return Mostri._mesh["veste_ombra"]
		var prof := [[0.08, 1.62], [0.24, 1.52], [0.3, 1.38], [0.31, 1.1], [0.36, 0.8], [0.44, 0.45], [0.52, 0.1], [0.56, -0.12]]
		var m := Ombra._tornio(prof, 18)
		Mostri._mesh["veste_ombra"] = m
		return m

	static func _cappuccio() -> Mesh:
		if Mostri._mesh.has("cappuccio_ombra"):
			return Mostri._mesh["cappuccio_ombra"]
		var st := SphereMesh.new()
		st.radius = 0.2
		st.height = 0.46
		st.radial_segments = 16
		st.rings = 10
		Mostri._mesh["cappuccio_ombra"] = st
		return st

	static func _manica() -> Mesh:
		if Mostri._mesh.has("manica_ombra"):
			return Mostri._mesh["manica_ombra"]
		var prof := [[0.07, 0.04], [0.09, -0.2], [0.12, -0.5], [0.15, -0.7]]
		var m := Ombra._tornio(prof, 10)
		Mostri._mesh["manica_ombra"] = m
		return m

	static func _tornio(prof: Array, lati: int) -> Mesh:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var y0 := float(prof[0][1])
		var y1 := float(prof[prof.size() - 1][1])
		for i in range(prof.size() - 1):
			for j in range(lati):
				for v in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i, j + 1]]:
					var pr: Array = prof[v[0]]
					var a := TAU * float(v[1]) / float(lati)
					st.set_uv(Vector2(float(v[1]) / float(lati), (y0 - float(pr[1])) / (y0 - y1)))
					st.add_vertex(Vector3(cos(a) * float(pr[0]), float(pr[1]), sin(a) * float(pr[0])))
		st.generate_normals()
		return st.commit()

	func anima(_dt: float) -> void:
		var su := sin(t * 1.5 + fase) * 0.08 * scala
		var avanti := clampf(vel / 6.0, 0.0, 1.0)
		if morto:
			# si accascia e si dissolve nel suolo
			perno.position.y = lerpf(quota, -1.6 * scala, fine * fine)
			perno.scale = Vector3(1.0 + 0.4 * fine, maxf(0.05, 1.0 - 0.6 * fine), 1.0 + 0.4 * fine)
			return
		perno.scale = Vector3.ONE
		perno.position = Vector3(0, quota + su, sin(colpo * PI) * 0.4 * scala)
		perno.rotation.x = avanti * 0.3 + sin(colpo * PI) * 0.2 - urto * 0.2
		cappuccio.rotation.x = -sin(colpo * PI) * 0.3 + sin(t * 0.7 + fase) * 0.05
		for i in range(braccia.size()):
			var b: Node3D = braccia[i]
			var sx := -1.0 if i == 0 else 1.0
			# a riposo: braccia avanti, artigli che si muovono piano; colpo: su e poi giù di taglio
			var alza := 0.0
			if colpo > 0.0:
				var k := 1.0 - colpo
				alza = sin(minf(1.0, k * 2.2) * PI * 0.5) * 2.4 if k < 0.45 else lerpf(2.4, -0.4, minf(1.0, (k - 0.45) * 3.0))
			b.rotation.x = -0.55 - alza - avanti * 0.4 + sin(t * 2.0 + fase + i) * 0.08
			b.rotation.z = sx * (0.15 + 0.1 * sin(t * 1.3 + i))
