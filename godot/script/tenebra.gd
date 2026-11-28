class_name Tenebra
extends Node
## Stile «tenebra»: prova di grafica dark fantasy (ramo `prova-dark-fantasy`). Non cambia modelli né dati: cambia l'aria.
##  - una tavolozza di tre toni per zona (ombra → mezzo → luce) applicata a tutto il 3D da `tenebra_post` (pixel grossi,
##    contrasto schiacciato, retinatura), sotto l'interfaccia che resta nitida;
##  - cielo a cupola (`tenebra_cielo`): nubi a fasce, eclissi o luna, guglie nere all'orizzonte;
##  - nebbia fitta e colorata, luce d'ambiente e sole nel colore della zona;
##  - cristalli luminosi accanto alle rocce del mondo aperto.
## Si accende e spegne dalle Impostazioni («Stile dark fantasy», `Impostazioni.stile`) o con l'argomento `--stile=0|1`.
## Le zone passano una nell'altra in un paio di secondi (i valori si inseguono, non scattano).

const Forme := preload("res://script/forme_armi.gd")

## ombra/mezzo/luce: tavolozza della passata finale; alto/basso/nubi/astro: cielo; tipo 0 eclissi, 1 luna.
const TAVOLOZZE := {
	"sangue": {"ombra": Color(0.02, 0.01, 0.05), "mezzo": Color(0.30, 0.2, 0.42), "luce": Color(1.0, 0.72, 0.55),
		"alto": Color(0.05, 0.04, 0.14), "basso": Color(0.62, 0.16, 0.12), "nubi": Color(0.24, 0.14, 0.36), "astro": Color(1.0, 0.3, 0.12), "tipo": 0.0,
		"nebbia": Color(0.2, 0.11, 0.18), "densita": 0.006, "sole": Color(1.0, 0.84, 0.76), "sole_e": 0.95, "amb": Color(0.5, 0.5, 0.75), "amb_e": 0.55,
		"forza": 0.26, "soglia": 0.42},
	"borgo": {"ombra": Color(0.03, 0.01, 0.04), "mezzo": Color(0.34, 0.2, 0.36), "luce": Color(1.0, 0.76, 0.5),
		"alto": Color(0.05, 0.04, 0.14), "basso": Color(0.62, 0.16, 0.12), "nubi": Color(0.24, 0.14, 0.36), "astro": Color(1.0, 0.3, 0.12), "tipo": 0.0,
		"nebbia": Color(0.2, 0.12, 0.17), "densita": 0.004, "sole": Color(1.0, 0.86, 0.78), "sole_e": 1.0, "amb": Color(0.55, 0.52, 0.72), "amb_e": 0.6,
		"forza": 0.22},
	"gelo": {"ombra": Color(0.0, 0.015, 0.06), "mezzo": Color(0.2, 0.3, 0.5), "luce": Color(0.8, 0.92, 1.0),
		"alto": Color(0.02, 0.04, 0.14), "basso": Color(0.2, 0.34, 0.6), "nubi": Color(0.14, 0.2, 0.4), "astro": Color(0.85, 0.92, 1.0), "tipo": 1.0,
		"nebbia": Color(0.14, 0.2, 0.36), "densita": 0.008, "sole": Color(0.78, 0.86, 1.0), "sole_e": 0.9, "amb": Color(0.5, 0.6, 0.85), "amb_e": 0.6,
		"forza": 0.3},
	"selva": {"ombra": Color(0.0, 0.025, 0.03), "mezzo": Color(0.1, 0.32, 0.3), "luce": Color(0.7, 1.0, 0.85),
		"alto": Color(0.01, 0.05, 0.07), "basso": Color(0.06, 0.28, 0.26), "nubi": Color(0.08, 0.25, 0.25), "astro": Color(0.7, 1.0, 0.85), "tipo": 1.0,
		"nebbia": Color(0.05, 0.2, 0.18), "densita": 0.011, "sole": Color(0.82, 1.0, 0.92), "sole_e": 0.9, "amb": Color(0.5, 0.75, 0.7), "amb_e": 0.65,
		"forza": 0.26, "soglia": 0.36},
	"distesa": {"ombra": Color(0.05, 0.01, 0.0), "mezzo": Color(0.45, 0.2, 0.12), "luce": Color(1.0, 0.8, 0.5),
		"alto": Color(0.12, 0.04, 0.06), "basso": Color(0.75, 0.3, 0.1), "nubi": Color(0.35, 0.12, 0.08), "astro": Color(1.0, 0.55, 0.2), "tipo": 0.0,
		"nebbia": Color(0.35, 0.16, 0.1), "densita": 0.006, "sole": Color(1.0, 0.86, 0.72), "sole_e": 1.0, "amb": Color(0.75, 0.6, 0.55), "amb_e": 0.6,
		"forza": 0.26},
	"arena": {"ombra": Color(0.05, 0.0, 0.02), "mezzo": Color(0.42, 0.14, 0.2), "luce": Color(1.0, 0.7, 0.6),
		"alto": Color(0.08, 0.02, 0.08), "basso": Color(0.6, 0.1, 0.16), "nubi": Color(0.3, 0.08, 0.2), "astro": Color(1.0, 0.25, 0.25), "tipo": 1.0,
		"nebbia": Color(0.24, 0.08, 0.12), "densita": 0.006, "sole": Color(1.0, 0.84, 0.82), "sole_e": 0.95, "amb": Color(0.65, 0.5, 0.6), "amb_e": 0.55,
		"forza": 0.26},
	# dentro le Prove l'ambiente resta il loro (ogni ala ha il suo tema)
	"cripta": {"ombra": Color(0.02, 0.0, 0.05), "mezzo": Color(0.3, 0.22, 0.5), "luce": Color(1.0, 0.86, 0.9), "forza": 0.18, "soglia": 0.3},
	"forgia": {"ombra": Color(0.05, 0.0, 0.0), "mezzo": Color(0.5, 0.2, 0.1), "luce": Color(1.0, 0.82, 0.5), "forza": 0.2, "soglia": 0.32},
}
const CHIAVI_COLORE := ["ombra", "mezzo", "luce", "alto", "basso", "nubi", "astro", "nebbia", "sole", "amb"]
const CHIAVI_NUMERO := ["tipo", "densita", "sole_e", "amb_e", "forza", "soglia"]

var gioco
var env: Environment                 # l'ambiente all'aperto di questo stile (uno solo: cambia colore con la zona)
var _strato: CanvasLayer
var _post: ShaderMaterial
var _cupola: MeshInstance3D
var _cielo: ShaderMaterial
var _cristalli: Node3D
var _ora: Dictionary = {}
var _meta := "sangue"
var _zona := ""
var _dentro := false
var _conta := 0.0
static var _veli: Dictionary = {}    # colore → materiale del velo dei personaggi
var _giro := 0                       # a ogni fotogramma si guarda un'entità (i modelli si rifanno quando cambia l'equipaggiamento)
var _velati := false

## Colore del contorno acceso: per classe ai giocatori, rosso ai nemici, oro spento ai PNG.
const ACCENTI := {"lama": Color(0.35, 0.62, 1.0), "ombra": Color(0.72, 0.28, 1.0), "monaco": Color(1.0, 0.55, 0.15), "mistico": Color(0.5, 0.75, 1.0)}


static func attivo() -> bool:
	return Impostazioni.stile == 1


func _ready() -> void:
	_strato = CanvasLayer.new()
	_strato.layer = -1                       # sopra il 3D, sotto tutta l'interfaccia
	add_child(_strato)
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post = ShaderMaterial.new()
	_post.shader = preload("res://shader/tenebra_post.gdshader")
	r.material = _post
	_strato.add_child(r)
	_cupola = MeshInstance3D.new()
	var sfera := SphereMesh.new()
	sfera.radius = 1.0
	sfera.height = 2.0
	sfera.radial_segments = 48
	sfera.rings = 24
	_cupola.mesh = sfera
	_cielo = ShaderMaterial.new()
	_cielo.shader = preload("res://shader/tenebra_cielo.gdshader")
	_cupola.material_override = _cielo
	_cupola.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cupola.extra_cull_margin = 16384.0
	add_child(_cupola)
	_ora = _copia(TAVOLOZZE.sangue)
	_applica_valori()
	_mostra()


func _copia(t: Dictionary) -> Dictionary:
	var o := (TAVOLOZZE.sangue as Dictionary).duplicate()
	for k in t:
		o[k] = t[k]
	return o


## L'ambiente all'aperto: quello della scena, senza cielo vero (c'è la cupola) e con la luce d'ambiente a colore fisso.
func _prepara_env(base: Environment) -> void:
	env = base.duplicate() as Environment
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.fog_enabled = true
	env.fog_aerial_perspective = 0.0
	env.fog_sun_scatter = 0.0
	env.fog_sky_affect = 0.0
	env.fog_light_energy = 1.0
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.95
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 1.3


## Chiamata da Gioco._ambiente dopo che ha scelto l'ambiente di sempre: zona = "" mondo aperto, id di una mappa lontana,
## oppure "cripta" (dentro una Prova: `prova` dice quale).
func zona(z: String, dentro: bool, prova: String, we: WorldEnvironment, base: Environment) -> void:
	_zona = z
	_dentro = dentro
	_mostra()
	if not attivo():
		return
	if dentro:
		_meta = prova if TAVOLOZZE.has(prova) else "cripta"
		return
	if env == null:
		_prepara_env(base)
	we.environment = env
	_meta = z if TAVOLOZZE.has(z) else _zona_aperta()
	_conta = 0.0


func _mostra() -> void:
	var si := attivo()
	_strato.visible = si
	_cupola.visible = si and not _dentro
	if _cristalli != null:
		_cristalli.visible = si
	elif si and gioco != null and gioco.mondo != null:
		_semina_cristalli()


## Nel mondo aperto la tavolozza segue il luogo: villaggi caldi, Altopiano di ghiaccio, il resto viola e rosso.
func _zona_aperta() -> String:
	if gioco == null or gioco.me == null:
		return "sangue"
	var n: String = gioco.nome_zona()
	if n.contains("Altopiano"):
		return "gelo"
	for kid in Dati.KINGDOMS:
		if n == String(Dati.KINGDOMS[kid].villageName):
			return "borgo"
	return "sangue"


func _process(dt: float) -> void:
	if not attivo():
		if _velati:
			_togli_veli()
		return
	_vela_un_po()
	if gioco != null and gioco.cam != null:
		_cupola.global_position = gioco.cam.global_position
		_cupola.scale = Vector3.ONE * gioco.cam.far * 0.88
	if not _dentro and _zona == "":
		_conta -= dt
		if _conta <= 0.0:
			_conta = 0.4
			_meta = _zona_aperta()
	var meta := _copia(TAVOLOZZE[_meta])
	var k := 1.0 - exp(-dt * 1.6)
	for c in CHIAVI_COLORE:
		_ora[c] = (_ora[c] as Color).lerp(meta[c], k)
	for c in CHIAVI_NUMERO:
		_ora[c] = lerpf(float(_ora[c]), float(meta[c]), k)
	_applica_valori()


func _applica_valori() -> void:
	for c in ["ombra", "mezzo", "luce"]:
		_post.set_shader_parameter(c, _ora[c])
	_post.set_shader_parameter("forza", float(_ora.forza))
	_post.set_shader_parameter("soglia", float(_ora.soglia))
	# pixel più grossi sugli schermi grandi: l'immagine resta di circa 450-500 righe (300 erano troppo poche)
	var alto := float(get_viewport().get_visible_rect().size.y) if is_inside_tree() else 900.0
	_post.set_shader_parameter("pixel", maxf(1.0, round(alto / 450.0)))
	for c in ["alto", "basso", "nubi", "astro"]:
		_cielo.set_shader_parameter(c, _ora[c])
	_cielo.set_shader_parameter("tipo", float(_ora.tipo))
	if _dentro or env == null:
		return
	env.background_color = _ora.basso
	env.fog_light_color = _ora.nebbia
	env.fog_density = float(_ora.densita)
	env.ambient_light_color = _ora.amb
	env.ambient_light_energy = float(_ora.amb_e)
	var sole: DirectionalLight3D = get_tree().current_scene.get_node_or_null("Sole") if get_tree().current_scene != null else null
	if sole != null:
		sole.light_color = _ora.sole
		sole.light_energy = float(_ora.sole_e)
		# l'astro sta dalla parte del sole ma basso sull'orizzonte, dove lo si vede anche con la visuale dall'alto
		var verso: Vector3 = sole.global_transform.basis.z
		_cielo.set_shader_parameter("astro_dir", Vector3(verso.x, 0.0, verso.z).normalized() + Vector3(0, 0.25, 0))


# ------------------------------------------------------------------ personaggi
static func _velo(colore: Color, forza: float, bordo: float) -> ShaderMaterial:
	var chiave := "%s:%.2f:%.2f" % [colore.to_html(false), forza, bordo]
	if not _veli.has(chiave):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shader/tenebra_velo.gdshader")
		m.set_shader_parameter("accento", colore)
		m.set_shader_parameter("velo", forza)
		m.set_shader_parameter("bordo", bordo)
		_veli[chiave] = m
	return _veli[chiave]


## Le parti che fanno luce (aloni, rune, fiamme, scie) non si velano: sono materiali senza ombreggiatura o additivi.
static func _fa_luce(mi: MeshInstance3D) -> bool:
	var m: Material = mi.material_override
	if m == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
		m = mi.get_active_material(0)
	if m is ShaderMaterial:
		var sh: Shader = (m as ShaderMaterial).shader
		return sh == null or sh.code.contains("unshaded") or sh.code.contains("blend_add")
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		return b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or b.blend_mode == BaseMaterial3D.BLEND_MODE_ADD or b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	return false


## Mette il velo alle mesh del modello che ancora non l'hanno (e non fanno luce).
static func vela_corpo(corpo: Node3D, colore: Color, forza: float, bordo: float) -> void:
	var velo := _velo(colore, forza, bordo)
	for n in corpo.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.has_meta("ten"):
			continue
		mi.set_meta("ten", true)
		if mi.material_overlay == null and not _fa_luce(mi):
			mi.material_overlay = velo
			mi.set_meta("ten_velo", true)


## I colori dei completi nello stile: stoffe quasi nere, metalli bruniti, un solo colore d'accento per classe.
## Le chiavi sono le parti dei completi (personaggio.gd: stoffa, stoffa2, fascia, regno, piastre, lamelle, bordo, cuoio…).
static func colori(classe: String, regno: Color) -> Dictionary:
	var r := regno.darkened(0.6)
	match classe:
		"lama":
			return {"stoffa": Color(0.06, 0.07, 0.12), "stoffa2": Color(0.04, 0.04, 0.06), "fascia": Color(0.16, 0.24, 0.42), "regno": r,
				"piastre": Color(0.12, 0.13, 0.17), "lamelle": Color(0.09, 0.1, 0.15), "bordo": Color(0.26, 0.28, 0.34), "cuoio": Color(0.07, 0.06, 0.06)}
		"ombra":
			return {"stoffa": Color(0.045, 0.04, 0.055), "stoffa2": Color(0.035, 0.035, 0.045), "fascia": Color(0.36, 0.04, 0.07), "regno": Color(0.3, 0.03, 0.05),
				"piastre": Color(0.1, 0.1, 0.12), "lamelle": Color(0.09, 0.09, 0.11), "bordo": Color(0.22, 0.2, 0.22), "cuoio": Color(0.06, 0.045, 0.04)}
		"monaco":
			return {"stoffa": Color(0.1, 0.07, 0.05), "stoffa2": Color(0.09, 0.065, 0.05), "fascia": Color(0.42, 0.18, 0.06), "regno": r,
				"piastre": Color(0.22, 0.15, 0.08), "bordo": Color(0.26, 0.18, 0.09), "grani": Color(0.45, 0.42, 0.36), "cuoio": Color(0.07, 0.05, 0.04)}
		"mistico":
			return {"stoffa": Color(0.05, 0.06, 0.13), "stoffa2": Color(0.04, 0.045, 0.09), "fascia": Color(0.4, 0.5, 0.65), "regno": r,
				"piastre": Color(0.16, 0.2, 0.26), "bordo": Color(0.45, 0.5, 0.6), "carta": Color(0.5, 0.48, 0.42), "cuoio": Color(0.06, 0.05, 0.06)}
	return {"stoffa": Color(0.06, 0.06, 0.08), "stoffa2": Color(0.04, 0.04, 0.05), "fascia": Color(0.3, 0.3, 0.35), "regno": r}


## Un'entità per fotogramma: alle sue mesh ancora senza velo si mette quello del suo colore.
func _vela_un_po() -> void:
	if gioco == null or gioco.me == null:
		return
	var tutte: Array = gioco.ents.values()
	tutte.append(gioco.me)                   # il proprio personaggio non sta fra le entità
	_giro = (_giro + 1) % tutte.size()
	var e: Entita = tutte[_giro]
	if e == null or e.corpo == null or e.tipo == "d":
		return
	var colore := Color(0.85, 0.7, 0.4)
	var forza := 0.45
	var bordo := 0.85
	if e.tipo == "p":
		colore = ACCENTI.get(String(e.info.get("cls", "")), Color(0.6, 0.7, 1.0))
		forza = 0.5
		bordo = 1.25
	elif e.tipo == "m":
		colore = Color(1.0, 0.16, 0.1)
		forza = 0.62
		bordo = 1.4
	# prima il trucco (copricapo, occhi, mantello), così le parti nuove prendono il velo nello stesso giro
	if e.corpo.scheletro != null and not e.corpo.has_meta("ten_trucco") and (e.tipo == "p" or e.tipo == "m"):
		e.corpo.set_meta("ten_trucco", true)
		if e.tipo == "p":
			trucca(e.corpo, String(e.info.get("cls", "")), colore)
		elif e.corpo.scheletro.find_bone("head") >= 0 and e.corpo.scheletro.find_bone("hand_R") >= 0:
			occhi(e.corpo, Color(1.0, 0.12, 0.05))          # i nemici in forma d'uomo: occhi di brace
	vela_corpo(e.corpo, colore, forza, bordo)
	if OS.get_cmdline_user_args().has("--ten_debug"):
		var si := 0
		var tot := 0
		for n in e.corpo.find_children("*", "MeshInstance3D", true, false):
			tot += 1
			si += int((n as MeshInstance3D).has_meta("ten_velo"))
		print("VELO ", e.nome, " ", e.tipo, " ", si, "/", tot)
	_velati = true


func _togli_veli() -> void:
	_velati = false
	if gioco == null:
		return
	var tutte: Array = gioco.ents.values()
	tutte.append(gioco.me)
	for e: Entita in tutte:
		if e == null or e.corpo == null:
			continue
		togli_trucco(e.corpo)
		for n in e.corpo.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.has_meta("ten_velo"):
				mi.material_overlay = null
				mi.remove_meta("ten_velo")
			if mi.has_meta("ten"):
				mi.remove_meta("ten")


# ------------------------------------------------------------------ trucco dei personaggi
## Il cambio d'aspetto dello stile: sopra i completi di sempre ogni classe prende un copricapo che le nasconde il volto,
## occhi accesi e un mantello lacero. Tutto da codice, agganciato alle ossa «head» e «chest» (gli stessi strumenti degli
## accessori dei banditi in mostri.gd); si toglie spegnendo lo stile. Figure di genere, niente di copiato:
##   Lama     cavaliere: elmo chiuso d'acciaio nero con la feritoia accesa, cresta e due corna all'indietro, lungo mantello;
##   Ombra    sicario: cappuccio, bavaglio cremisi, occhi rossi, mantellina a brandelli e due code di sciarpa;
##   Monaco   pellegrino: largo cappello a cono con le strisce di carta appese, occhi di brace, due stole sulla schiena;
##   Mistico  veggente: cappuccio a punta, occhi pallidi, anello spezzato dietro la testa, mantello lungo fino ai piedi.
static func trucca(p: Personaggio, classe: String, accento: Color) -> void:
	if p == null or p.scheletro == null or p.scheletro.find_bone("head") < 0:
		return
	var t := Mostri._testa(p)
	var ba: BoneAttachment3D = t[0]
	var c: Vector3 = t[1]
	var r: float = t[2]
	var nodi: Array = [ba]
	var nero := Forme.acciaio(Color(0.06, 0.065, 0.085), 0.42)
	var panno := Mostri._stoffa(Color(0.05, 0.045, 0.06))
	var lume := Forme.luce(accento, 3.0)
	match classe:
		"lama":
			Mostri._sfera(r * 1.17, c + Vector3(0, 0.012, 0.0), nero, ba, Vector3(1.0, 1.1, 1.08))
			# visiera a becco e feritoia accesa
			Mostri._cil(0.0, r * 0.62, 0.2, c + Vector3(0, -0.035, r * 1.02), nero, ba, Vector3(1.75, 0, 0), 4)
			_luce_box(ba, Vector3(0.13, 0.014, 0.02), c + Vector3(0, 0.022, r * 1.2), lume)
			# cresta alta e due corna che piegano all'indietro
			Mostri._cil(0.0, 0.034, 0.42, c + Vector3(0, r * 1.62, -0.06), nero, ba, Vector3(-0.42, 0, 0), 4)
			for sx in [-1.0, 1.0]:
				Mostri._cil(0.0, 0.058, 0.3, c + Vector3(sx * r * 1.3, r * 0.72, -0.07), nero, ba, Vector3(-0.75, 0, -sx * 0.95), 5)
			# gorgiera
			Mostri._cil(r * 1.1, r * 1.3, 0.07, c + Vector3(0, -r * 1.02, 0), nero, ba, Vector3.ZERO, 10)
			nodi.append(_mantello(p, Color(0.035, 0.045, 0.1), accento.darkened(0.45), [1.0, 1.22, 1.3, 1.16, 1.28, 0.95], 0.46, 0.2))
		"ombra":
			Mostri._sfera(r * 1.22, c + Vector3(0, 0.025, -0.03), panno, ba, Vector3(1.0, 1.06, 1.1))
			Mostri._cil(0.0, r * 0.9, 0.16, c + Vector3(0, r * 1.05, -r * 0.75), panno, ba, Vector3(-1.1, 0, 0), 6)         # la punta del cappuccio ricade dietro
			var bav := Mostri._cil(r * 1.06, r * 1.0, 0.1, c + Vector3(0, -0.08, 0.006), Mostri._stoffa(Color(0.32, 0.03, 0.05)), ba, Vector3.ZERO, 16)
			bav.scale = Vector3(1.0, 1.0, 1.07)
			_occhi_su(ba, c, r, lume)
			nodi.append(_mantello(p, Color(0.05, 0.04, 0.06), Color(0.4, 0.04, 0.06), [0.42, 0.62, 0.5, 0.66, 0.44], 0.36, 0.26))
			nodi.append(_mantello(p, Color(0.42, 0.04, 0.06), Color(0.2, 0.02, 0.03), [1.0, 0.82], 0.1, 0.34, 0.07))        # code della sciarpa
		"monaco":
			var paglia := Forme.opaco(Color(0.11, 0.085, 0.06), 0.95)
			# (niente velo sul cappello: visto dall'alto il contorno acceso lo prenderebbe tutto)
			Mostri._cil(0.02, 0.36, 0.17, c + Vector3(0, r * 0.98, 0), paglia, ba, Vector3.ZERO, 14).set_meta("ten", true)
			Mostri._cil(0.36, 0.37, 0.012, c + Vector3(0, r * 0.98 - 0.09, 0), paglia, ba, Vector3.ZERO, 14).set_meta("ten", true)
			# il volto in ombra sotto la tesa e le strisce di carta appese
			Mostri._sfera(r * 1.06, c + Vector3(0, 0.02, -0.004), Forme.opaco(Color(0.02, 0.02, 0.025), 1.0), ba, Vector3(1.0, 0.9, 1.0), true)
			for i in range(5):
				var ang := -1.1 + i * 0.55
				var carta := MeshInstance3D.new()
				carta.mesh = Mostri._striscia(0.05, 0.2 + 0.05 * (i % 2))
				carta.material_override = Mostri._nastro(Color(0.62, 0.56, 0.42), accento.darkened(0.2), 0.03, 0.0, 0.0, 0.0)
				carta.position = c + Vector3(sin(ang) * 0.33, r * 0.98 - 0.09, cos(ang) * 0.33)
				carta.rotation.y = ang
				ba.add_child(carta)
			_occhi_su(ba, c, r, lume)
			nodi.append(_mantello(p, Color(0.1, 0.07, 0.05), accento.darkened(0.5), [0.95, 0.0, 0.0, 1.05], 0.34, 0.2, 0.09))
		"mistico":
			Mostri._sfera(r * 1.22, c + Vector3(0, 0.025, -0.03), Mostri._stoffa(Color(0.04, 0.05, 0.11)), ba, Vector3(1.0, 1.08, 1.1))
			Mostri._cil(0.0, r * 0.95, 0.4, c + Vector3(0, r * 1.5, -0.085), Mostri._stoffa(Color(0.04, 0.05, 0.11)), ba, Vector3(-0.38, 0, 0), 8)
			_occhi_su(ba, c, r, lume)
			# l'anello spezzato dietro la testa
			for k in range(7):
				var a2 := -2.2 + k * 0.73
				if k == 3:
					continue
				var tac := _luce_box(ba, Vector3(0.1, 0.012, 0.012), c + Vector3(sin(a2) * 0.3, 0.06 + cos(a2) * 0.3, -r * 1.55), Forme.luce(accento, 2.0))
				tac.rotation.z = -a2
			nodi.append(_mantello(p, Color(0.035, 0.045, 0.11), accento.darkened(0.3), [1.25, 1.42, 1.5, 1.38, 1.48, 1.2], 0.5, 0.2))
		_:
			_occhi_su(ba, c, r, lume)
	p.set_meta("ten_nodi", nodi)


## Solo gli occhi accesi (nemici in forma d'uomo).
static func occhi(p: Personaggio, colore: Color) -> void:
	var t := Mostri._testa(p)
	_occhi_su(t[0], t[1], t[2], Forme.luce(colore, 3.0))
	p.set_meta("ten_nodi", [t[0]])


static func _occhi_su(ba: Node3D, c: Vector3, r: float, lume: Material) -> void:
	for sx in [-1.0, 1.0]:
		var o := Mostri._sfera(0.013, c + Vector3(sx * 0.033, 0.012, r * 0.9), lume, ba, Vector3(1.25, 0.8, 0.6))
		o.set_meta("ten", true)              # fanno luce: niente velo


static func _luce_box(gen: Node3D, dim: Vector3, pos: Vector3, lume: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = dim
	mi.mesh = b
	mi.material_override = lume
	mi.position = pos
	mi.set_meta("ten", true)
	gen.add_child(mi)
	return mi


## Mantello a brandelli sulla schiena: strisce di lunghezze diverse appese alle spalle, che ondeggiano (nastro.gdshader).
## lunghe: una lunghezza per striscia (0 = niente striscia in quel posto); larga: da spalla a spalla; dietro: quanto sta
## scostato dalla schiena.
static func _mantello(p: Personaggio, colore: Color, orlo: Color, lunghe: Array, larga: float, dietro: float, striscia := 0.0) -> Node3D:
	var ps := Mostri._osso(p, "chest")
	var n := lunghe.size()
	var w := striscia if striscia > 0.0 else larga / float(n) * 1.25
	for i in range(n):
		var lung := float(lunghe[i])
		if lung <= 0.0:
			continue
		var x := (float(i) / float(maxi(1, n - 1)) - 0.5) * larga if n > 1 else 0.0
		var f := MeshInstance3D.new()
		f.mesh = Mostri._striscia(w, lung)
		f.material_override = Mostri._nastro(colore.lightened(0.02 * (i % 3)), orlo, 0.07 + 0.02 * (i % 2), 0.0, 0.0, 1.0)
		f.position = Vector3(x, 0.2 - absf(x) * 0.25, -dietro + absf(x) * 0.12)
		f.rotation = Vector3(0.14, x * 0.9, -x * 0.35)
		ps.add_child(f)
	return ps


static func togli_trucco(p: Personaggio) -> void:
	if p == null or not p.has_meta("ten_trucco"):
		return
	for n in p.get_meta("ten_nodi", []):
		if is_instance_valid(n):
			(n as Node).queue_free()
	p.remove_meta("ten_trucco")
	if p.has_meta("ten_nodi"):
		p.remove_meta("ten_nodi")


# ------------------------------------------------------------------ cristalli
func _mesh_cristallo() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# un grappolo: una punta grande e quattro più piccole inclinate attorno
	var punte := [[0.0, 0.0, 1.0, 0.0, 0.0], [0.34, 0.1, 0.62, 0.42, 0.4], [-0.3, 0.22, 0.5, -0.5, 1.9], [0.08, -0.36, 0.56, 0.38, 3.6], [-0.22, -0.2, 0.36, -0.6, 5.0]]
	for p in punte:
		var c := CylinderMesh.new()
		c.radial_segments = 6
		c.rings = 1
		c.top_radius = 0.03
		c.bottom_radius = 0.26
		c.height = 2.6
		var b := Basis(Vector3(cos(float(p[4])), 0, sin(float(p[4]))), float(p[3])).scaled(Vector3.ONE * float(p[2]))
		st.append_from(c, 0, Transform3D(b, Vector3(float(p[0]), 0, float(p[1])) + b * Vector3(0, 1.1, 0)))
	return st.commit()


## Un grappolo di cristalli accanto a una roccia su due del mondo aperto: azzurri sull'Altopiano, rossi e viola altrove.
func _semina_cristalli() -> void:
	_cristalli = Node3D.new()
	_cristalli.name = "Cristalli"
	gioco.mondo.add_child(_cristalli)
	var rocce: Array = Dati.gioco.get("vegetazione", {}).get("roccia", [])
	var voci: Array = []
	var centro: Dictionary = Dati.costanti.CENTER
	for i in range(rocce.size()):
		if i % 2 == 1:
			continue
		var e: Array = rocce[i]
		var ang := float(i) * 2.399
		var x := float(e[0]) + cos(ang) * 1.3
		var z := float(e[2]) + sin(ang) * 1.3
		var freddo := Vector2(x - float(centro.x), z - float(centro.z)).length() < 110.0
		var caldi: Array[Color] = [Color(1.0, 0.16, 0.2), Color(0.62, 0.25, 1.0), Color(1.0, 0.3, 0.75)]
		var col: Color = Color(0.2, 0.75, 1.0) if freddo else caldi[(i / 2) % 3]
		var s := 0.7 + 1.1 * fposmod(float(i) * 0.618, 1.0)
		voci.append([Transform3D(Basis(Vector3.UP, ang).scaled(Vector3.ONE * s), Vector3(x, Dati.altezza(x, z) - 0.15, z)), col])
	# e uno piccolo ai piedi di un albero ogni sei (i tronchi sono già ostacoli: non si finisce a camminarci dentro)
	var veg: Dictionary = Dati.gioco.get("vegetazione", {})
	var n := 0
	for specie in veg:
		if String(specie) == "roccia" or String(specie) == "cespuglio":
			continue
		for e in veg[specie]:
			n += 1
			if n % 6 != 0:
				continue
			var ang2 := float(n) * 1.71
			var x2 := float(e[0]) + cos(ang2) * 0.9
			var z2 := float(e[2]) + sin(ang2) * 0.9
			var freddo2 := Vector2(x2 - float(centro.x), z2 - float(centro.z)).length() < 110.0
			var caldi2: Array[Color] = [Color(1.0, 0.16, 0.2), Color(0.62, 0.25, 1.0), Color(1.0, 0.3, 0.75)]
			var col2: Color = Color(0.2, 0.75, 1.0) if freddo2 else caldi2[n % 3]
			var s2 := 0.3 + 0.35 * fposmod(float(n) * 0.618, 1.0)
			voci.append([Transform3D(Basis(Vector3.UP, ang2).scaled(Vector3.ONE * s2), Vector3(x2, Dati.altezza(x2, z2) - 0.08, z2)), col2])
	if voci.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _mesh_cristallo()
	mm.instance_count = voci.size()
	for i in range(voci.size()):
		mm.set_instance_transform(i, voci[i][0])
		mm.set_instance_color(i, voci[i][1])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shader/tenebra_cristallo.gdshader")
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cristalli.add_child(mi)
