class_name Cripta
extends Node3D
## Le Prove del Sigillo (la Cripta delle Mille Lanterne e la Forgia del Drago Addormentato) costruite da codice dalla
## pianta di shared/prove.js (Dati.gioco.PIANTE): la variante e lo stato delle porte li manda il server con `dg_start`
## e poi a ogni secondo con `dg` (aggiorna_stato). Stanze, muri, vuoti e ostacoli sono gli stessi del server.
##
## Ogni Prova ha il suo tema (TEMI): la Cripta è una tomba antica (conci consumati, fregio a greca, pilastri, nicchie
## con statue di terracotta, sarcofagi, urne, radici, lanterne appese a centinaia, nebbia bassa, lame di luce
## polverosa, l'abisso sotto il ponte); la Forgia una fucina dentro un vulcano (basalto fasciato di ferro, lago e
## cascate di lava, incudini, crogioli, mantici, catene, grate, il ponte che emerge dal lago).
## Leggerezza: le parti ferme di ogni stanza si fondono per materiale (Edifici.fondi), fiamme, aloni, fasci, nebbia e
## lanterne sono MultiMesh additivi senza luci; le poche luci vere si accendono solo vicino alla visuale.

const VISTA := 74.0
const TEMI := {
	"cripta": {"stile": 0, "alt": 7.0, "muro": Color(0.42, 0.40, 0.50), "pav": Color(0.36, 0.34, 0.40), "fregio": Color(0.3, 0.85, 0.7),
		"lume": Color(1.0, 0.66, 0.3), "boss": Color(0.75, 0.36, 1.0), "nebbia": Color(0.32, 0.38, 0.6), "fascio": Color(0.5, 0.62, 0.95),
		"vuoto": Color(0.3, 0.22, 0.5), "fondo": -16.0, "fluido": 1, "sfondo": Color(0.012, 0.012, 0.022), "ambiente": Color(0.44, 0.43, 0.56),
		"amb_forza": 1.05, "foschia": Color(0.045, 0.04, 0.085), "densita": 0.0155, "ferro": Color(0.09, 0.085, 0.09)},
	"forgia": {"stile": 1, "alt": 9.0, "muro": Color(0.52, 0.44, 0.40), "pav": Color(0.40, 0.36, 0.35), "fregio": Color(1.0, 0.5, 0.15),
		"lume": Color(1.0, 0.56, 0.2), "boss": Color(1.0, 0.62, 0.12), "nebbia": Color(0.75, 0.24, 0.05), "fascio": Color(1.0, 0.45, 0.15),
		"vuoto": Color(1.0, 0.36, 0.06), "fondo": -1.7, "fluido": 0, "sfondo": Color(0.03, 0.012, 0.008), "ambiente": Color(0.80, 0.62, 0.54),
		"amb_forza": 1.12, "foschia": Color(0.11, 0.04, 0.02), "densita": 0.013, "ferro": Color(0.075, 0.068, 0.065)},
}
## Tema di ogni ALA dentro una Prova (l'autore: «dai dei temi ai dungeon, non tutti con grafica uguale»): colori di muro
## e pavimento, variante del muro (`prova_muro`: 1 ossario, 2 bronzo e giada, 3 lacca rossa, 4 lamiera, 5 scoria,
## 6 tesoro, 7 ossidiana), motivo del pavimento ed emblema al centro delle sale (`prova_pavimento`), colore del fregio
## acceso e della nebbia bassa. La chiave "" vale per le sale comuni, "boss" per la sala del boss e il corridoio che ci
## porta, "tesoro" per la camera del tesoro. Una Prova nuova = una voce in TEMI e una qui.
const ALI_TEMI := {
	"cripta": {
		"": {"emblema": 0},
		"ovest": {"muro": Color(0.50, 0.43, 0.31), "pav": Color(0.40, 0.33, 0.24), "var": 1, "motivo": 1, "emblema": 2, "fregio": Color(0.35, 1.0, 0.6), "nebbia": Color(0.25, 0.6, 0.35)},
		"centro": {"muro": Color(0.26, 0.34, 0.32), "pav": Color(0.22, 0.34, 0.30), "var": 2, "motivo": 2, "emblema": 3, "fregio": Color(0.45, 1.0, 0.78), "nebbia": Color(0.3, 0.55, 0.5)},
		"est": {"muro": Color(0.50, 0.12, 0.08), "pav": Color(0.42, 0.13, 0.08), "var": 3, "motivo": 3, "emblema": 4, "fregio": Color(1.0, 0.75, 0.3), "nebbia": Color(0.7, 0.4, 0.15)},
		"tesoro": {"muro": Color(0.30, 0.25, 0.18), "pav": Color(0.34, 0.26, 0.12), "var": 6, "motivo": 2, "emblema": 4, "fregio": Color(1.0, 0.8, 0.3), "nebbia": Color(0.7, 0.55, 0.2)},
		"boss": {"muro": Color(0.30, 0.25, 0.44), "pav": Color(0.26, 0.21, 0.38), "var": 0, "motivo": 0, "emblema": 0},
	},
	"forgia": {
		"": {"emblema": 1},
		"ovest": {"muro": Color(0.34, 0.24, 0.20), "pav": Color(0.26, 0.19, 0.16), "var": 5, "motivo": 5, "emblema": 4, "fregio": Color(1.0, 0.8, 0.25), "nebbia": Color(0.9, 0.3, 0.05)},
		"est": {"muro": Color(0.30, 0.38, 0.46), "pav": Color(0.27, 0.34, 0.41), "var": 4, "motivo": 4, "emblema": 1, "fregio": Color(0.3, 0.8, 1.0), "nebbia": Color(0.45, 0.6, 0.7)},
		"ponte": {"muro": Color(0.15, 0.12, 0.17), "pav": Color(0.17, 0.13, 0.19), "var": 7, "motivo": 6, "emblema": 3, "fregio": Color(1.0, 0.4, 0.15), "nebbia": Color(0.8, 0.25, 0.1)},
		"tesoro": {"muro": Color(0.15, 0.12, 0.17), "pav": Color(0.17, 0.13, 0.19), "var": 7, "motivo": 6, "emblema": 3, "fregio": Color(1.0, 0.4, 0.15), "nebbia": Color(0.8, 0.25, 0.1)},
		"boss": {"muro": Color(0.40, 0.22, 0.16), "pav": Color(0.30, 0.2, 0.17), "var": 0, "motivo": 0, "emblema": 4},
	},
}
const TIPI_PAV := {"corridoio": 0.0, "cancello": 0.0, "ingresso": 0.2, "sala": 0.2, "bivio": 0.4, "boss": 0.6, "ponte": 0.8, "passerella": 0.8, "tesoro": 1.0}

var origine := Vector2.ZERO
var id_prova := "cripta"
var definizione: Dictionary = {}     # voce di PROVE (nome, tempo, forze richieste…)
var pianta: Dictionary = {}          # voce di PIANTE (stanze, ali, porte, varianti…)
var composta: Dictionary = {}        # la variante in uso: stanze, muri, vuoti, ostacoli, frane, branchi
var variante := 0
var porte: Dictionary = {}           # id → 0 chiusa, 1 aperta, -1 fuori uso
var ritorno := ""                    # id del Braciere del Ritorno acceso
var scrigno := false                 # lo scrigno del tesoro è aperto
var compagni: Array = []             # [[id, x, z, caduto], …] in coordinate locali (dal messaggio `dg`)

var _T: Dictionary = {}
var _stanze: Array = []              # dizionari delle stanze della variante (anche dietro porte chiuse)
var _vive: Array = []                # rettangoli calpestabili adesso
var _ostacoli: Array = []
var _radici: Dictionary = {}
var _luci: Array = []
var _mat: Dictionary = {}
var _mat_ala: Dictionary = {}        # chiave del tema → { muro, pav } (materiali dell'ala)
var _base: Dictionary = {}           # i materiali delle sale comuni
var _mobili: Dictionary = {}         # id porta → [{nodo, chiuso: Vector3, aperto: Vector3, sparisce: bool}]
var _accesi: Dictionary = {}         # "rit:id" / "tes" → nodi da mostrare quando lo stato cambia
var _fiamme: Array = []
var _aloni: Array = []
var _aloni_su: Array = []
var _fasci: Array = []
var _nebbie: Array = []
var _lanterne: Array = []
var _fili: Array = []
var _rng := RandomNumberGenerator.new()
var _verso_boss: Dictionary = {}
var _pronta := false
var _chiave := "resto"              # stanza a cui appartengono lanterne e fili che si stanno aggiungendo


static func crea(ox: float, oz: float, id := "cripta", stato := {}) -> Cripta:
	var c := Cripta.new()
	c.origine = Vector2(ox, oz)
	c.id_prova = id if Dati.gioco.get("PIANTE", {}).has(id) else "cripta"
	c.definizione = Dati.gioco.get("PROVE", {}).get(c.id_prova, Dati.gioco.DUNGEON)
	c.pianta = Dati.gioco.PIANTE[c.id_prova]
	c.variante = clampi(int(stato.get("v", 0)), 0, (c.pianta.composte as Array).size() - 1)
	c.composta = c.pianta.composte[c.variante]
	c._T = TEMI[c.id_prova]
	c.position = Vector3(ox, 0, oz)
	for k in c.composta.porte:
		c.porte[k] = int(c.composta.porte[k])
	c._costruisci()
	c.aggiorna_stato(stato.get("porte", {}), String(stato.get("rit", "")), int(stato.get("tes", 0)) == 1, true)
	return c


## Ambiente di una Prova: buio, foschia nel colore del tema, bagliore.
static func ambiente(id: String) -> Environment:
	var t: Dictionary = TEMI.get(id, TEMI.cripta)
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = t.sfondo
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = t.ambiente
	e.ambient_light_energy = float(t.amb_forza)
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_white = 6.0
	e.glow_enabled = true
	e.glow_intensity = 0.9
	e.glow_hdr_threshold = 1.0
	e.fog_enabled = true
	e.fog_light_color = t.foschia
	e.fog_density = float(t.densita)
	e.fog_sky_affect = 1.0
	return e


# ------------------------------------------------------------------ dove si cammina
func _locale(x: float, z: float) -> Vector2:
	return Vector2(x - origine.x, z - origine.y)


## Il punto (coordinate del mondo) è calpestabile? Come dungeonWalkable del server: stanze aperte e ostacoli.
func calpestabile(x: float, z: float, margine := 0.5) -> bool:
	var p := _locale(x, z)
	var dentro := false
	for r in _vive:
		if p.x >= float(r[0]) + margine and p.x <= float(r[2]) - margine and p.y >= float(r[1]) + margine and p.y <= float(r[3]) - margine:
			dentro = true
			break
	if not dentro:
		return false
	for o in _ostacoli:
		var lim := float(o[2]) + margine * 0.5
		if Vector2(p.x - float(o[0]), p.y - float(o[1])).length_squared() < lim * lim:
			return false
	return true


## La visuale può stare qui? Stanze (anche dietro una porta chiusa) e vuoti: i muri no.
func visuale_libera(x: float, z: float) -> bool:
	var p := _locale(x, z)
	for s in _stanze:
		var r: Array = s.r
		if p.x >= float(r[0]) + 0.8 and p.x <= float(r[2]) - 0.8 and p.y >= float(r[1]) + 0.8 and p.y <= float(r[3]) - 0.8:
			return true
	for r in composta.vuoti:
		if p.x >= float(r[0]) and p.x <= float(r[2]) and p.y >= float(r[1]) and p.y <= float(r[3]):
			return true
	return false


## Il punto calpestabile più vicino a (x, z): serve a liberare chi è finito dentro un muro o un ostacolo.
func piu_vicino(x: float, z: float, margine := 0.6) -> Vector2:
	var p := _locale(x, z)
	var meglio := p
	var md := INF
	for r in _vive:
		var q := Vector2(clampf(p.x, float(r[0]) + margine, float(r[2]) - margine), clampf(p.y, float(r[1]) + margine, float(r[3]) - margine))
		var d := q.distance_squared_to(p)
		if d < md:
			md = d
			meglio = q
	for o in _ostacoli:
		var c := Vector2(float(o[0]), float(o[1]))
		var lim := float(o[2]) + margine * 0.5 + 0.05
		var dd := meglio.distance_to(c)
		if dd < lim:
			meglio = c + ((meglio - c) / dd if dd > 0.01 else Vector2(1, 0)) * lim
	return meglio + origine


## Un passo da «da» verso «a» (coordinate del mondo): si scivola lungo i muri e attorno agli ostacoli.
func passo(da: Vector2, a: Vector2) -> Vector2:
	if not calpestabile(da.x, da.y):
		return piu_vicino(da.x, da.y)        # finito dentro un muro (scatto, spinta, ritardo di rete): si esce
	if calpestabile(a.x, a.y):
		return a
	# attorno a un ostacolo tondo: il punto si sposta sul suo bordo
	var p := _locale(a.x, a.y)
	for o in _ostacoli:
		var c := Vector2(float(o[0]), float(o[1]))
		var lim := float(o[2]) + 0.26
		if p.distance_to(c) < lim:
			var q := c + (p - c).normalized() * (lim + 0.01) + origine
			if calpestabile(q.x, q.y):
				return q
	if calpestabile(a.x, da.y):
		return Vector2(a.x, da.y)
	if calpestabile(da.x, a.y):
		return Vector2(da.x, a.y)
	return da


## Stato mandato dal server: porte aperte, braciere acceso, scrigno. Le porte che cambiano si animano.
func aggiorna_stato(nuove: Dictionary, rit: String, tes: bool, subito := false) -> void:
	var cambiato := not _pronta
	for k in nuove:
		var v := int(nuove[k])
		if int(porte.get(k, 0)) != v:
			porte[k] = v
			cambiato = true
			for m in _mobili.get(k, []):
				var nodo: Node3D = m.nodo
				if not is_instance_valid(nodo):
					continue
				var meta: Vector3 = m.aperto if v == 1 else m.chiuso
				if subito or not is_inside_tree():
					nodo.position = meta
					nodo.visible = not (v == 1 and m.sparisce)
				else:
					nodo.visible = true
					var tw := create_tween()
					tw.tween_property(nodo, "position", meta, 2.2).set_trans(Tween.TRANS_SINE)
					if v == 1 and m.sparisce:
						tw.tween_callback(nodo.hide)
					Suoni.suona("terra", -6.0, 0.7)
	if rit != ritorno:
		ritorno = rit
		for n in _accesi.get("rit:" + rit, []):
			(n as Node3D).visible = true
	if tes != scrigno:
		scrigno = tes
		for n in _accesi.get("tes", []):
			(n as Node3D).visible = tes
		for m in _mobili.get("__scrigno", []):
			(m.nodo as Node3D).rotation = m.aperto if tes else m.chiuso
	if cambiato:
		_vive.clear()
		for s in _stanze:
			if not s.has("porta") or int(porte.get(String(s.porta), 0)) == 1:
				_vive.append(s.r)
	_pronta = true


# ------------------------------------------------------------------ costruzione
func _costruisci() -> void:
	_rng.seed = hash(id_prova) + variante * 977
	var per_id := {}
	for s in pianta.stanze:
		per_id[String(s.id)] = s
	for sid in composta.stanze:
		_stanze.append(per_id[String(sid)])
	_ostacoli = composta.ostacoli
	_materiali()
	# i corridoi che portano alla sala del boss: i loro varchi hanno il colore del boss
	for s in _stanze:
		if String(s.tipo) != "boss":
			continue
		for q in _stanze:
			if q != s and String(q.tipo) == "corridoio" and not _sovrapposizione(s.r, q.r).is_empty():
				_verso_boss[String(q.id)] = true
	for s in _stanze:
		_chiave = String(s.id)
		_usa_tema(s)
		_pavimento(s)
		_arredo_stanza(s)
		_segna()
	for w in composta.walls:
		_muro(w)
		_segna()
	for i in range(_stanze.size()):
		for j in range(i + 1, _stanze.size()):
			var ov := _sovrapposizione(_stanze[i].r, _stanze[j].r)
			if not ov.is_empty():
				_varco(_stanze[i], _stanze[j], ov)
	_usa_tema({})
	_chiave = "vuoti"
	for r in composta.vuoti:
		_vuoto(r)
	_segna()
	for o in _ostacoli:
		var so := _stanza_a(Vector2(float(o[0]), float(o[1])))
		_chiave = String(so.get("id", "resto"))
		_usa_tema(so)
		_ostacolo(o)
		_segna()
	_usa_tema({})
	_chiave = "resto"
	for f in composta.frane:
		_frana(f)
	for t in composta.pericoli:
		_pericolo(t)
	_porte_e_leve()
	_tesoro_e_ritorni()
	# fusione per stanza e per materiale, poi le luci finte in MultiMesh
	for k in _radici:
		Edifici.fondi(_radici[k], VISTA)
	_multimesh()


func _materiali() -> void:
	var o3 := Vector3(origine.x, 0, origine.y)
	var muro := ShaderMaterial.new()
	muro.shader = preload("res://shader/prova_muro.gdshader")
	muro.set_shader_parameter("colore", _T.muro)
	muro.set_shader_parameter("fregio", _T.fregio)
	muro.set_shader_parameter("brace", _T.lume)
	muro.set_shader_parameter("origine", o3)
	muro.set_shader_parameter("altezza", float(_T.alt))
	muro.set_shader_parameter("stile", int(_T.stile))
	_mat.muro = muro
	var pav := ShaderMaterial.new()
	pav.shader = preload("res://shader/prova_pavimento.gdshader")
	pav.set_shader_parameter("colore", _T.pav)
	pav.set_shader_parameter("brace", _T.lume)
	pav.set_shader_parameter("stile", int(_T.stile))
	_mat.pav = pav
	_base = {"muro": muro, "pav": pav}
	var fluido := ShaderMaterial.new()
	fluido.shader = preload("res://shader/prova_fluido.gdshader")
	fluido.set_shader_parameter("colore", _T.vuoto)
	fluido.set_shader_parameter("tipo", int(_T.fluido))
	fluido.set_shader_parameter("origine", o3)
	_mat.fluido = fluido
	var cascata := fluido.duplicate() as ShaderMaterial
	cascata.set_shader_parameter("tipo", 0)
	cascata.set_shader_parameter("colore", Color(1.0, 0.36, 0.06))
	cascata.set_shader_parameter("scorre", Vector2(0.0, 0.3))
	cascata.set_shader_parameter("scala", Vector2(0.55, 0.2))
	_mat.cascata = cascata
	var roccia := ShaderMaterial.new()
	roccia.shader = preload("res://shader/roccia.gdshader")
	roccia.set_shader_parameter("muschio_forza", 0.0)
	roccia.set_shader_parameter("tinta", (_T.muro as Color).darkened(0.25))
	roccia.set_shader_parameter("origine", o3)
	_mat.roccia = roccia
	_mat.ferro = Edifici.mat(_T.ferro, 0.55, 0.6)
	_mat.bronzo = Edifici.mat(Color(0.36, 0.25, 0.12), 0.5, 0.7)
	_mat.oro = Edifici.mat(Color(0.95, 0.72, 0.25), 0.4, 0.8, 0.5)
	_mat.buio = Edifici.mat(Color(0.02, 0.02, 0.025), 1.0)
	_mat.legno = Edifici.legno(Color(0.16, 0.10, 0.07))
	_mat.cuoio = Edifici.mat(Color(0.30, 0.17, 0.10), 0.85)
	_mat.osso = Edifici.mat(Color(0.62, 0.58, 0.48), 0.9)
	_mat.radice = Edifici.legno(Color(0.13, 0.10, 0.07))
	var statua := ShaderMaterial.new()
	statua.shader = preload("res://shader/statua.gdshader")
	statua.set_shader_parameter("colore", Color(0.46, 0.33, 0.27))
	statua.set_shader_parameter("materia", 0)
	_mat.statua = statua
	var bronzea := statua.duplicate() as ShaderMaterial
	bronzea.set_shader_parameter("materia", 1)
	bronzea.set_shader_parameter("colore", Color(0.38, 0.3, 0.2))
	_mat.statua_bronzo = bronzea


## Quale tema di ALI_TEMI tocca a una stanza: boss, tesoro, la sua ala, oppure "" (sale comuni).
func _chiave_tema(s: Dictionary) -> String:
	if s.is_empty():
		return ""
	if String(s.get("tipo", "")) == "boss" or _verso_boss.has(String(s.get("id", ""))):
		return "boss"
	if String(s.get("ala", "")) == "tesoro" or String(s.get("tipo", "")) == "tesoro":
		return "tesoro"
	return String(s.get("ala", ""))


func _tema_ala(s: Dictionary) -> Dictionary:
	var t: Dictionary = ALI_TEMI.get(id_prova, {})
	return t.get(_chiave_tema(s), t.get("", {}))


## Da qui in poi muri e pavimenti prendono i materiali dell'ala di questa stanza (dizionario vuoto = sale comuni).
func _usa_tema(s: Dictionary) -> void:
	var k := _chiave_tema(s)
	if not _mat_ala.has(k):
		var t := _tema_ala(s)
		var muro := (_base.muro as ShaderMaterial).duplicate() as ShaderMaterial
		var pav := (_base.pav as ShaderMaterial).duplicate() as ShaderMaterial
		if t.has("muro"):
			muro.set_shader_parameter("colore", t.muro)
			pav.set_shader_parameter("colore", t.pav)
		if t.has("fregio"):
			muro.set_shader_parameter("fregio", t.fregio)
			muro.set_shader_parameter("fregio_luce", 0.24)
		muro.set_shader_parameter("variante", int(t.get("var", 0)))
		pav.set_shader_parameter("motivo", int(t.get("motivo", 0)))
		pav.set_shader_parameter("emblema", int(t.get("emblema", 0)))
		_mat_ala[k] = {"muro": muro, "pav": pav}
	_mat.muro = _mat_ala[k].muro
	_mat.pav = _mat_ala[k].pav


func _luce_mat(tipo: int, verso: bool, forza := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shader/prova_luce.gdshader")
	m.set_shader_parameter("tipo", tipo)
	m.set_shader_parameter("verso_visuale", verso)
	m.set_shader_parameter("forza", forza)
	return m


func _emissivo(c: Color, forza := 3.0) -> StandardMaterial3D:
	return Edifici.mat(c, 0.5, 0.0, forza)


## Lanterne e fili aggiunti dall'ultima chiamata prendono la stanza corrente: così ogni stanza ha il suo MultiMesh
## (si scarta fuori vista, a differenza di uno solo per tutta la Prova).
func _segna() -> void:
	for elenco in [_lanterne, _fili]:
		var i: int = (elenco as Array).size() - 1
		while i >= 0 and (elenco[i] as Array).size() < 3:
			(elenco[i] as Array).append(_chiave)
			i -= 1


func _radice(nome: String) -> Node3D:
	if not _radici.has(nome):
		var n := Node3D.new()
		n.name = "Stanza_" + nome
		add_child(n)
		_radici[nome] = n
	return _radici[nome]


func _sovrapposizione(a: Array, b: Array) -> Array:
	var x1 := maxf(float(a[0]), float(b[0]))
	var z1 := maxf(float(a[1]), float(b[1]))
	var x2 := minf(float(a[2]), float(b[2]))
	var z2 := minf(float(a[3]), float(b[3]))
	if x2 - x1 <= 0.01 or z2 - z1 <= 0.01:
		return []
	return [x1, z1, x2, z2]


func _stanza_a(p: Vector2) -> Dictionary:
	for s in _stanze:
		var r: Array = s.r
		if p.x >= float(r[0]) and p.x <= float(r[2]) and p.y >= float(r[1]) and p.y <= float(r[3]):
			return s
	return {}


func _in_vuoto(p: Vector2) -> bool:
	for r in composta.vuoti:
		if p.x >= float(r[0]) and p.x <= float(r[2]) and p.y >= float(r[1]) and p.y <= float(r[3]):
			return true
	return false


## Colore del segno di una stanza: quello della sua ala, del boss, o il lume del tema.
func _colore_stanza(s: Dictionary) -> Color:
	if String(s.get("tipo", "")) == "boss" or _verso_boss.has(String(s.get("id", ""))):
		return _T.boss
	var ala := String(s.get("ala", ""))
	if ala == "tesoro" or String(s.get("tipo", "")) == "tesoro":
		return Color(1.0, 0.8, 0.3)
	if ala != "" and pianta.ali.has(ala):
		return Color.html(String(pianta.ali[ala].colore))
	return _T.lume


func _box(root: Node3D, dim: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := Edifici.scatola(dim, pos, m, root)
	if rot != Vector3.ZERO:
		mi.rotation = rot
	return mi


func _cil(root: Node3D, r_alto: float, r_basso: float, h: float, pos: Vector3, m: Material, lati := 10, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := Edifici.cilindro(r_alto, r_basso, h, pos, m, root, lati)
	(mi.mesh as CylinderMesh).rings = 0          # pochi triangoli: una fascia sola
	if rot != Vector3.ZERO:
		mi.rotation = rot
	return mi


func _luce(pos: Vector3, colore: Color, energia: float, raggio: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = colore
	l.light_energy = energia
	l.omni_range = raggio
	l.omni_attenuation = 0.9
	l.shadow_enabled = false
	l.position = pos
	add_child(l)
	_luci.append(l)
	return l


## Fiamma (quadrato rivolto alla visuale) con il suo alone a terra.
func _fiamma(pos: Vector3, colore: Color, alta := 0.9, alone := 2.6) -> void:
	_fiamme.append([Transform3D(Basis().scaled(Vector3(alta * 0.75, alta, alta * 0.75)), pos + Vector3(0, alta * 0.5, 0)), colore])
	_aloni_su.append([Transform3D(Basis().scaled(Vector3(alta * 2.6, alta * 2.6, alta * 2.6)), pos + Vector3(0, alta * 0.45, 0)), Color(colore.r, colore.g, colore.b, 0.28)])
	if alone > 0.0:
		_alone(Vector3(pos.x, 0.03, pos.z), colore, alone, 0.3)


func _alone(pos: Vector3, colore: Color, raggio: float, forza := 0.35) -> void:
	var b := Basis(Vector3.RIGHT, -PI * 0.5).scaled(Vector3(raggio * 2.0, raggio * 2.0, raggio * 2.0))
	_aloni.append([Transform3D(b, pos), Color(colore.r, colore.g, colore.b, forza)])


# ------------------------------------------------------------------ pavimenti
## Rettangolo del pavimento: quello della stanza, accorciato dove un'estremità sta dentro una sala più importante
## (così due pavimenti con disegni diversi non si sovrappongono).
func _rett_pavimento(s: Dictionary) -> Array:
	var r: Array = [float(s.r[0]), float(s.r[1]), float(s.r[2]), float(s.r[3])]
	var mio := float(TIPI_PAV.get(String(s.tipo), 0.2))
	var io := _stanze.find(s)
	for k in range(_stanze.size()):
		var q: Dictionary = _stanze[k]
		if q == s:
			continue
		var suo := float(TIPI_PAV.get(String(q.tipo), 0.2))
		var conta := (suo > 0.1 and mio < 0.1) or (is_equal_approx(minf(suo, 0.1), minf(mio, 0.1)) and k < io)
		if String(s.tipo) in ["ponte", "passerella"]:
			conta = String(q.tipo) not in ["ponte", "passerella"]
		elif String(q.tipo) in ["ponte", "passerella"]:
			conta = false
		if not conta:
			continue
		var ov := _sovrapposizione(r, q.r)
		if ov.is_empty():
			continue
		if float(ov[0]) <= r[0] + 0.01 and float(ov[2]) >= r[2] - 0.01:      # tutta la larghezza: si accorcia in z
			if float(ov[1]) <= r[1] + 0.01:
				r[1] = float(ov[3])
			elif float(ov[3]) >= r[3] - 0.01:
				r[3] = float(ov[1])
		elif float(ov[1]) <= r[1] + 0.01 and float(ov[3]) >= r[3] - 0.01:    # tutta la profondità: si accorcia in x
			if float(ov[0]) <= r[0] + 0.01:
				r[0] = float(ov[2])
			elif float(ov[2]) >= r[2] - 0.01:
				r[2] = float(ov[0])
	return r


func _mesh_pavimento(r: Array, tipo: float, segno: Color, y: float) -> ArrayMesh:
	# a riquadri di 8 m al più: con triangoli enormi visti di taglio l'interpolazione delle coordinate perde precisione
	var hx := (float(r[2]) - float(r[0])) * 0.5
	var hz := (float(r[3]) - float(r[1])) * 0.5
	var cx := (float(r[0]) + float(r[2])) * 0.5
	var cz := (float(r[1]) + float(r[3])) * 0.5
	var nx := maxi(1, int(ceil(hx * 2.0 / 8.0)))
	var nz := maxi(1, int(ceil(hz * 2.0 / 8.0)))
	var vv := PackedVector3Array()
	var nn := PackedVector3Array()
	var uu := PackedVector2Array()
	var u2 := PackedVector2Array()
	var cc := PackedColorArray()
	var ii := PackedInt32Array()
	var c := Color(tipo, segno.r, segno.g, segno.b)
	for j in range(nz + 1):
		for i in range(nx + 1):
			var lx := -hx + 2.0 * hx * i / nx
			var lz := -hz + 2.0 * hz * j / nz
			vv.append(Vector3(cx + lx, y, cz + lz))
			nn.append(Vector3.UP)
			uu.append(Vector2(lx, lz))
			u2.append(Vector2(hx, hz))
			cc.append(c)
	for j in range(nz):
		for i in range(nx):
			var a := j * (nx + 1) + i
			ii.append_array([a, a + 1, a + nx + 2, a, a + nx + 2, a + nx + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vv
	arr[Mesh.ARRAY_NORMAL] = nn
	arr[Mesh.ARRAY_TEX_UV] = uu
	arr[Mesh.ARRAY_TEX_UV2] = u2
	arr[Mesh.ARRAY_COLOR] = cc
	arr[Mesh.ARRAY_INDEX] = ii
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


func _pavimento(s: Dictionary) -> void:
	if s.has("porta") and String(s.tipo) == "ponte":
		return                                   # il ponte mobile porta il suo impalcato (vedi _porte_e_leve)
	var tipo := float(TIPI_PAV.get(String(s.tipo), 0.2))
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh_pavimento(_rett_pavimento(s), tipo, _colore_stanza(s), -0.008 if tipo < 0.1 else 0.0)
	mi.material_override = _mat.pav
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = VISTA
	add_child(mi)


# ------------------------------------------------------------------ muri
func _muro(w: Array) -> void:
	var a := Vector2(float(w[0]), float(w[1]))
	var b := Vector2(float(w[2]), float(w[3]))
	var tipo := int(w[4]) if w.size() > 4 else 0
	var oriz := absf(a.y - b.y) < 0.01
	var t := {"c": (a + b) * 0.5, "d": Vector2(1, 0) if oriz else Vector2(0, 1), "n": Vector2(0, 1) if oriz else Vector2(1, 0), "oriz": oriz, "lung": a.distance_to(b)}
	if tipo == 2:
		if not _in_vuoto(t.c + t.n * 0.6):
			t.n = -t.n
		_muro_roccia(t)
		return
	var st := _stanza_a(t.c + t.n * 0.6)
	if st.is_empty():
		t.n = -t.n
		st = _stanza_a(t.c + t.n * 0.6)
	t["stanza"] = st
	_usa_tema(st)
	t["root"] = _radice(String(st.get("id", "resto")))
	_chiave = String(st.get("id", "resto"))
	if tipo == 1:
		if st.has("porta") and String(st.tipo) == "ponte":
			return                                # il ponte mobile porta le sue sponde
		_parapetto(t)
	else:
		_muro_pieno(t)


## Punto nello spazio a partire dal telaio di un muro: lungo il muro, verso l'interno della stanza, altezza.
func _pm(t: Dictionary, lungo: float, dentro: float, y: float) -> Vector3:
	var q: Vector2 = t.c + t.d * lungo + t.n * dentro
	return Vector3(q.x, y, q.y)


func _dm(t: Dictionary, lungo: float, alto: float, spesso: float) -> Vector3:
	return Vector3(lungo, alto, spesso) if t.oriz else Vector3(spesso, alto, lungo)


func _yaw_muro(t: Dictionary) -> float:
	return atan2(t.n.x, t.n.y)       # un oggetto con il davanti verso +z guarda dentro la stanza


func _muro_pieno(t: Dictionary) -> void:
	var H: float = _T.alt
	var root: Node3D = t.root
	var L: float = t.lung
	_box(root, _dm(t, L + 0.9, H, 0.9), _pm(t, 0, -0.3, H * 0.5), _mat.muro)
	_box(root, _dm(t, L + 0.9, 0.55, 1.1), _pm(t, 0, -0.3, 0.275), _mat.muro)
	_box(root, _dm(t, L + 0.9, 0.3, 1.24), _pm(t, 0, -0.25, 4.55), _mat.muro)
	if L < 4.0:
		return
	var q := maxi(1, int(round(L / 7.0)))
	var passo_c := (L - 0.8) / q
	for k in range(q + 1):
		var al := -L * 0.5 + 0.4 + passo_c * k
		_box(root, _dm(t, 0.8, 4.4, 0.3), _pm(t, al, 0.28, 2.2), _mat.muro)
		_box(root, _dm(t, 1.06, 0.3, 0.42), _pm(t, al, 0.28, 4.25), _mat.muro)
	for k in range(q):
		_campata(t, -L * 0.5 + 0.4 + passo_c * (k + 0.5), passo_c, k)


## Fra due pilastri: torce, nicchie con statue, radici (Cripta); bracieri a gabbia, catene, colate (Forgia).
func _campata(t: Dictionary, al: float, larga: float, k: int) -> void:
	var st: Dictionary = t.stanza
	var root: Node3D = t.root
	var tipo := String(st.get("tipo", ""))
	var ala := String(st.get("ala", ""))
	var col := _colore_stanza(st).lerp(_T.lume, 0.45)
	var caso := _rng.randf()
	if larga < 3.0:
		return
	if int(_T.stile) == 0:
		if tipo == "corridoio" or tipo == "cancello":
			if k % 2 == 0:
				_torcia(t, al, col)
			elif ala == "ovest":
				_radice_muro(t, al)
			return
		if (ala == "ovest" or tipo == "boss" or tipo == "ingresso") and k % 2 == 1:
			_nicchia(t, al, tipo == "boss")
		elif tipo == "boss":
			_torcia(t, al, _T.boss)
		elif k % 2 == 0:
			_torcia(t, al, col)
		elif caso < 0.5:
			_nicchia(t, al, false)
		elif ala == "ovest" or caso < 0.75:
			_radice_muro(t, al)
		else:
			_stendardo(t, al, _colore_stanza(st))
	else:
		if tipo == "corridoio":
			if k % 2 == 0:
				_torcia(t, al, col)
			else:
				_catene(t, al, 2)
			return
		if k % 3 == 1 or (tipo == "boss" and k % 2 == 0):
			_colata(t, al)
		elif k % 3 == 0:
			_torcia(t, al, col)
			_catene(t, al + larga * 0.3, 2)
		else:
			_tubi(t, al)


func _torcia(t: Dictionary, al: float, colore: Color) -> void:
	var root: Node3D = t.root
	_box(root, _dm(t, 0.1, 0.1, 0.34), _pm(t, al, 0.3, 2.35), _mat.ferro)
	_cil(root, 0.2, 0.08, 0.32, _pm(t, al, 0.42, 2.5), _mat.ferro, 6)
	_fiamma(_pm(t, al, 0.42, 2.6), colore, 1.05, 2.6)


func _stendardo(t: Dictionary, al: float, colore: Color) -> void:
	var root: Node3D = t.root
	_box(root, _dm(t, 1.5, 0.09, 0.12), _pm(t, al, 0.24, 4.15), _mat.legno)
	_telo(root, _pm(t, al, 0.22, 2.75), 1.3, 2.8, colore, _yaw_muro(t))


func _telo(root: Node3D, pos: Vector3, larga: float, alta: float, colore: Color, yaw: float, spento := false) -> void:
	var k := "telo%s%s" % [colore.to_html(), spento]
	if not _mat.has(k):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shader/prova_stendardo.gdshader")
		m.set_shader_parameter("colore", colore)
		m.set_shader_parameter("spento", 1.0 if spento else 0.0)
		_mat[k] = m
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(larga, alta)
	mi.mesh = q
	mi.material_override = _mat[k]
	mi.position = pos
	mi.rotation.y = yaw
	root.add_child(mi)


## Nicchia ad arco con una statua di terracotta (nella sala del boss: guerrieri di bronzo più grandi).
func _nicchia(t: Dictionary, al: float, grande: bool) -> void:
	var root: Node3D = t.root
	var s := 1.25 if grande else 1.0
	_box(root, _dm(t, 1.9 * s, 3.3 * s, 0.06), _pm(t, al, 0.17, 0.5 + 1.65 * s), _mat.buio)
	for lato in [-1.0, 1.0]:
		_box(root, _dm(t, 0.16, 3.3 * s, 0.26), _pm(t, al + lato * 1.0 * s, 0.26, 0.5 + 1.65 * s), _mat.muro)
	_box(root, _dm(t, 2.3 * s, 0.24, 0.3), _pm(t, al, 0.27, 0.5 + 3.4 * s), _mat.muro)
	_box(root, _dm(t, 2.3 * s, 0.5, 0.36), _pm(t, al, 0.3, 0.3), _mat.muro)
	var st := _statua(1.9 * s, _mat.statua_bronzo if grande else _mat.statua)
	st.position = _pm(t, al, 0.3, 0.55)
	st.rotation.y = _yaw_muro(t)
	st.scale = Vector3(1, 1, 0.55)
	root.add_child(st)
	if grande:
		_alone(_pm(t, al, 1.2, 0.03), _T.boss, 2.2, 0.22)


## Statua stilizzata di un guerriero (poche forme): base, veste, busto, spalle, testa con crocchia, spada a terra.
func _statua(alta: float, m: Material) -> Node3D:
	var n := Node3D.new()
	var k := alta / 1.95
	_box(n, Vector3(0.62, 0.14, 0.5) * k, Vector3(0, 0.07, 0) * k, m)
	_cil(n, 0.2 * k, 0.33 * k, 0.95 * k, Vector3(0, 0.61, 0) * k, m, 6)
	_cil(n, 0.25 * k, 0.2 * k, 0.5 * k, Vector3(0, 1.33, 0) * k, m, 6)
	_box(n, Vector3(0.66, 0.15, 0.3) * k, Vector3(0, 1.53, 0) * k, m)
	_cil(n, 0.11 * k, 0.13 * k, 0.24 * k, Vector3(0, 1.74, 0) * k, m, 6)
	_cil(n, 0.05 * k, 0.07 * k, 0.12 * k, Vector3(0, 1.91, 0) * k, m, 5)
	for lato in [-1.0, 1.0]:
		_box(n, Vector3(0.13, 0.62, 0.15) * k, Vector3(lato * 0.25, 1.22, 0.1) * k, m, Vector3(-0.35, 0, lato * 0.5))
	_box(n, Vector3(0.07, 1.05, 0.03) * k, Vector3(0, 0.62, 0.26) * k, m)
	_box(n, Vector3(0.3, 0.05, 0.05) * k, Vector3(0, 1.06, 0.26) * k, m)
	return n


## Radici che scendono lungo il muro (catacombe).
func _radice_muro(t: Dictionary, al: float) -> void:
	var root: Node3D = t.root
	for i in range(3):
		var x := al + _rng.randf_range(-0.8, 0.8)
		var y := float(_T.alt) * 0.75
		var spess := _rng.randf_range(0.07, 0.13)
		while y > 0.6:
			var h := _rng.randf_range(0.8, 1.5)
			var dx := _rng.randf_range(-0.35, 0.35)
			var inc := atan2(dx, h)
			_cil(root, spess, spess * 1.15, h * 1.05, _pm(t, x + dx * 0.5, 0.22, y - h * 0.5), _mat.radice, 5, Vector3(0, 0, inc) if t.oriz else Vector3(-inc, 0, 0))
			x += dx
			y -= h
			spess *= 0.85


func _catene(t: Dictionary, al: float, quante: int) -> void:
	for i in range(quante):
		var lunga := _rng.randf_range(2.5, 5.5)
		var p := _pm(t, al + (i - (quante - 1) * 0.5) * 0.5, 0.3, float(_T.alt) - lunga * 0.5)
		_fili.append([Transform3D(Basis().scaled(Vector3(0.07, lunga, 0.07)), p), Color(0.5, 0.45, 0.42)])
		if i == 0:
			_box(t.root, Vector3(0.3, 0.34, 0.12), p - Vector3(0, lunga * 0.5 + 0.12, 0), _mat.ferro)


func _tubi(t: Dictionary, al: float) -> void:
	var root: Node3D = t.root
	for i in range(2):
		var x := al + (i - 0.5) * 0.7
		_cil(root, 0.16, 0.16, 5.6, _pm(t, x, 0.3, 2.8), _mat.bronzo, 8)
		_cil(root, 0.21, 0.21, 0.14, _pm(t, x, 0.3, 1.6 + i * 1.9), _mat.ferro, 8)
	_box(root, _dm(t, 1.5, 0.2, 0.3), _pm(t, al, 0.3, 5.5), _mat.ferro)


## Colata di lava da una bocca nel muro fino a una vasca: illumina (alone e, in poche, una luce vera).
func _colata(t: Dictionary, al: float) -> void:
	var root: Node3D = t.root
	_box(root, _dm(t, 1.5, 0.7, 0.4), _pm(t, al, 0.28, 4.0), _mat.ferro)
	_box(root, _dm(t, 1.9, 0.5, 0.5), _pm(t, al, 0.3, 0.25), _mat.ferro)
	var lava := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 3.7)
	lava.mesh = q
	lava.material_override = _mat.cascata
	lava.position = _pm(t, al, 0.5, 2.1)
	lava.rotation.y = _yaw_muro(t)
	lava.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lava)
	_box(root, _dm(t, 1.5, 0.06, 0.34), _pm(t, al, 0.32, 0.5), _emissivo(Color(1.0, 0.4, 0.08), 4.0))
	_alone(_pm(t, al, 1.6, 0.03), Color(1.0, 0.4, 0.1), 3.4, 0.5)
	_aloni_su.append([Transform3D(Basis().scaled(Vector3(4.5, 5.5, 4.5)), _pm(t, al, 0.6, 2.2)), Color(1.0, 0.35, 0.08, 0.16)])


func _parapetto(t: Dictionary) -> void:
	var root: Node3D = t.root
	var L: float = t.lung
	var m: Material = _mat.ferro if int(_T.stile) == 1 else _mat.muro
	# il fianco sotto il pavimento, verso il vuoto
	_box(root, _dm(t, L + 0.2, absf(float(_T.fondo)) + 0.5, 1.0), _pm(t, 0, 0.5, float(_T.fondo) * 0.5 - 0.25), _mat.roccia)
	if int(_T.stile) == 1:
		_box(root, _dm(t, L, 0.09, 0.09), _pm(t, 0, 0.12, 1.05), m)
		_box(root, _dm(t, L, 0.06, 0.06), _pm(t, 0, 0.12, 0.55), m)
		_box(root, _dm(t, L, 0.14, 0.5), _pm(t, 0, 0.2, 0.07), m)
	else:
		_box(root, _dm(t, L, 0.5, 0.4), _pm(t, 0, 0.18, 0.25), m)
		_box(root, _dm(t, L, 0.14, 0.5), _pm(t, 0, 0.18, 0.95), m)
	var q := maxi(1, int(round(L / 3.0)))
	for k in range(q + 1):
		var al := -L * 0.5 + L * float(k) / q
		if int(_T.stile) == 1:
			_box(root, _dm(t, 0.12, 1.1, 0.12), _pm(t, al, 0.12, 0.55), m)
		else:
			_box(root, _dm(t, 0.34, 1.25, 0.44), _pm(t, al, 0.18, 0.62), m)
			if k % 2 == 0 and L > 5.0:
				_lanterne.append([Transform3D(Basis().scaled(Vector3(0.3, 0.42, 0.3)), _pm(t, al, 0.18, 1.5)), Color(_T.lume.r, _T.lume.g, _T.lume.b, 0.9)])


## Parete di roccia che chiude un vuoto (abisso, lago) dove non c'è una stanza.
func _muro_roccia(t: Dictionary) -> void:
	var fondo: float = _T.fondo
	var H: float = float(_T.alt) + 2.0
	_box(_radice("vuoti"), _dm(t, float(t.lung) + 1.6, H - fondo + 1.0, 1.6), _pm(t, 0, -0.8, (H + fondo - 1.0) * 0.5), _mat.roccia)


# ------------------------------------------------------------------ varchi fra le stanze
## Architrave e muro sopra il passaggio; i varchi che contano portano un segno: colore dell'ala (due grandi fiamme,
## disco con l'emblema, chiazza di luce sulla soglia) o del boss (portale più grande).
func _varco(sa: Dictionary, sb: Dictionary, ov: Array) -> void:
	var w := float(ov[2]) - float(ov[0])
	var h := float(ov[3]) - float(ov[1])
	if minf(w, h) > 2.5:
		return                                    # gomito di un corridoio
	var lungo_x := w > h                          # il varco è largo in x: si passa lungo z
	var larg := maxf(w, h)
	# la sala è la stanza più larga del varco; l'altra è quella che ci entra
	var est_a := (float(sa.r[2]) - float(sa.r[0])) if lungo_x else (float(sa.r[3]) - float(sa.r[1]))
	var est_b := (float(sb.r[2]) - float(sb.r[0])) if lungo_x else (float(sb.r[3]) - float(sb.r[1]))
	var sala: Dictionary = sa if est_a >= est_b else sb
	var entra: Dictionary = sb if est_a >= est_b else sa
	_usa_tema(entra if _chiave_tema(entra) != "" else sala)      # il varco annuncia l'ala in cui porta
	# il bordo della sala dentro la sovrapposizione
	var bordo := 0.0
	var fuori := 1.0                              # verso di chi esce dalla sala
	var i1 := 1 if lungo_x else 0
	var i2 := 3 if lungo_x else 2
	if float(sala.r[i1]) >= float(ov[i1]) - 0.01 and float(sala.r[i1]) <= float(ov[i2]) + 0.01:
		bordo = float(sala.r[i1])
		fuori = -1.0
	else:
		bordo = float(sala.r[i2])
	var c := Vector2((float(ov[0]) + float(ov[2])) * 0.5, bordo) if lungo_x else Vector2(bordo, (float(ov[1]) + float(ov[3])) * 0.5)
	var t := {"c": c, "d": Vector2(1, 0) if lungo_x else Vector2(0, 1), "n": (Vector2(0, -fuori) if lungo_x else Vector2(-fuori, 0)), "oriz": lungo_x, "lung": larg}
	var root := _radice(String(sala.id))
	t["root"] = root
	var H: float = _T.alt
	var tipi := [String(sa.tipo), String(sb.tipo)]
	var sul_vuoto := "ponte" in tipi or "passerella" in tipi
	var boss := "boss" in tipi or (_verso_boss.has(String(entra.id)) or _verso_boss.has(String(sala.id)))
	var alto := 5.4 if boss else 4.6
	var su_parapetto := _in_vuoto(c + t.d * (larg * 0.5 + 1.0) - t.n * 0.6) or _in_vuoto(c - t.d * (larg * 0.5 + 1.0) - t.n * 0.6)
	if not su_parapetto and not (sul_vuoto and larg > 7.0):
		_box(root, _dm(t, larg + 0.9, H - alto, 0.9), _pm(t, 0, -0.3, (H + alto) * 0.5), _mat.muro)
		_box(root, _dm(t, larg + 1.2, 0.5, 1.3), _pm(t, 0, -0.3, alto - 0.05), _mat.ferro if int(_T.stile) == 1 else _mat.muro)
		for lato in [-1.0, 1.0]:
			_box(root, _dm(t, 0.5, 0.9, 1.2), _pm(t, lato * (larg * 0.5 - 0.1), -0.3, alto - 0.7), _mat.muro, Vector3.ZERO)
	# che segno porta?
	var ala := ""
	if String(sala.tipo) in ["bivio", "sala", "ingresso"] and String(sala.get("ala", "")) == "" and String(entra.get("ala", "")) != "":
		ala = String(entra.ala)
	var colore := Color(0, 0, 0, 0)
	if boss:
		colore = _T.boss
	elif ala == "tesoro":
		colore = Color(1.0, 0.8, 0.3)
	elif ala != "" and pianta.ali.has(ala):
		colore = Color.html(String(pianta.ali[ala].colore))
	if colore.a <= 0.0:
		return
	var grande := 1.5 if boss else 1.0
	# due grandi fiamme ai lati, dal lato della sala (e due più piccole dall'altro)
	for lato in [-1.0, 1.0]:
		var al: float = lato * (larg * 0.5 + 0.75)
		if su_parapetto:
			# niente muro ai lati (parapetto sul vuoto): due pali con il braciere
			_box(root, _dm(t, 0.3, 3.4 * grande, 0.3), _pm(t, al, 0.2, 1.7 * grande), _mat.ferro)
			_cil(root, 0.42 * grande, 0.16, 0.45, _pm(t, al, 0.2, 3.5 * grande), _mat.bronzo, 8)
			_fiamma(_pm(t, al, 0.2, 3.7 * grande), colore, 1.6 * grande, 4.2)
			continue
		_box(root, _dm(t, 0.14, 0.14, 0.5), _pm(t, al, 0.34, 2.9 * grande), _mat.ferro)
		_cil(root, 0.3 * grande, 0.12, 0.4, _pm(t, al, 0.52, 3.1 * grande), _mat.bronzo, 8)
		_fiamma(_pm(t, al, 0.52, 3.25 * grande), colore, 1.5 * grande, 4.2)
		_fiamma(_pm(t, lato * (larg * 0.5 - 0.5), -0.95, 3.0), colore, 0.9, 0.0)
	# il disco con l'emblema sopra l'architrave, visibile dalle due parti
	if su_parapetto:
		_alone(_pm(t, 0, 0.4, 0.035), colore, larg * 0.75, 0.55)
		return
	for faccia in [0.2, -0.82]:
		_cil(root, 0.62 * grande, 0.62 * grande, 0.08, _pm(t, 0, faccia, alto + 0.85 * grande), _emissivo(colore, 1.1), 14, Vector3(PI * 0.5, 0, 0) if lungo_x else Vector3(0, 0, PI * 0.5))
		_cil(root, 0.82 * grande, 0.82 * grande, 0.06, _pm(t, 0, faccia - 0.03 * signf(faccia), alto + 0.85 * grande), _mat.bronzo, 14, Vector3(PI * 0.5, 0, 0) if lungo_x else Vector3(0, 0, PI * 0.5))
	# stendardi ai lati e luce sulla soglia
	for lato in [-1.0, 1.0]:
		var al2: float = lato * (larg * 0.5 + 1.9)
		_telo(root, _pm(t, al2, 0.2, 2.9 * grande), 1.2 * grande, 3.0 * grande, colore, _yaw_muro(t))
		_box(root, _dm(t, 1.4 * grande, 0.09, 0.12), _pm(t, al2, 0.22, 2.9 * grande + 1.53 * grande), _mat.legno)
	_alone(_pm(t, 0, 0.4, 0.035), colore, larg * 0.75, 0.55)
	_alone(_pm(t, 0, -1.6, 0.035), colore, larg * 0.6, 0.35)
	if boss:
		_luce(_pm(t, 0, 2.5, 3.6), colore, 3.0, 13.0)


# ------------------------------------------------------------------ vuoti: abisso e lago di lava
func _vuoto(r: Array) -> void:
	var x1 := float(r[0])
	var z1 := float(r[1])
	var x2 := float(r[2])
	var z2 := float(r[3])
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(x2 - x1 + 2.0, z2 - z1 + 2.0)
	q.subdivide_width = int(q.size.x / 10.0)
	q.subdivide_depth = int(q.size.y / 10.0)
	mi.mesh = q
	mi.material_override = _mat.fluido
	mi.position = Vector3((x1 + x2) * 0.5, float(_T.fondo), (z1 + z2) * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var area := (x2 - x1) * (z2 - z1)
	if int(_T.fluido) == 0:
		# il lago scalda l'aria: veli arancio bassi, bagliori, poche luci vere e qualche catena che pende
		var passo_v := 13.0
		var nx := maxi(1, int(round((x2 - x1) / passo_v)))
		var nz := maxi(1, int(round((z2 - z1) / passo_v)))
		for i in range(nx):
			for j in range(nz):
				var p := Vector3(x1 + (i + 0.5) * (x2 - x1) / nx, 0.0, z1 + (j + 0.5) * (z2 - z1) / nz)
				_nebbie.append([Transform3D(Basis().scaled(Vector3(passo_v * 1.5, 1, passo_v * 1.5)), p + Vector3(0, 0.5, 0)), Color(1.0, 0.32, 0.06, 0.5)])
				if (i + j) % 2 == 0:
					_luce(p + Vector3(0, 1.5, 0), Color(1.0, 0.42, 0.12), 3.2, 20.0)
		for i in range(int(area / 160.0)):
			var p2 := Vector3(_rng.randf_range(x1 + 2, x2 - 2), 0, _rng.randf_range(z1 + 2, z2 - 2))
			if not _stanza_a(Vector2(p2.x, p2.z)).is_empty():
				continue
			var lunga := _rng.randf_range(5.0, 11.0)
			_fili.append([Transform3D(Basis().scaled(Vector3(0.09, lunga, 0.09)), p2 + Vector3(0, float(_T.alt) + 3.0 - lunga * 0.5, 0)), Color(0.45, 0.4, 0.38)])
	else:
		# l'abisso: lanterne che galleggiano nel buio, sempre più piccole e lontane, e veli di nebbia
		for i in range(int(area / 7.0)):
			var p := Vector3(_rng.randf_range(x1, x2), _rng.randf_range(float(_T.fondo) + 1.0, -1.0), _rng.randf_range(z1, z2))
			if not _stanza_a(Vector2(p.x, p.z)).is_empty() and p.y > -3.0:
				continue
			var k := _rng.randf_range(0.25, 0.5)
			var c: Color = (_T.lume as Color).lerp(_T.boss, _rng.randf() * 0.5)
			_lanterne.append([Transform3D(Basis().scaled(Vector3(k, k * 1.3, k)), p), Color(c.r, c.g, c.b, clampf(1.0 + p.y / 22.0, 0.35, 1.0))])
		_nebbie.append([Transform3D(Basis().scaled(Vector3(x2 - x1 + 6.0, 1, z2 - z1 + 6.0)), Vector3((x1 + x2) * 0.5, -1.5, (z1 + z2) * 0.5)), Color(_T.nebbia.r, _T.nebbia.g, _T.nebbia.b, 0.8)])
		_nebbie.append([Transform3D(Basis().scaled(Vector3(x2 - x1 + 6.0, 1, z2 - z1 + 6.0)), Vector3((x1 + x2) * 0.5, -5.0, (z1 + z2) * 0.5)), Color(_T.nebbia.r, _T.nebbia.g, _T.nebbia.b, 0.8)])


# ------------------------------------------------------------------ arredo delle stanze
func _arredo_stanza(s: Dictionary) -> void:
	var r: Array = s.r
	var x1 := float(r[0])
	var z1 := float(r[1])
	var x2 := float(r[2])
	var z2 := float(r[3])
	var c := Vector3((x1 + x2) * 0.5, 0, (z1 + z2) * 0.5)
	var tipo := String(s.tipo)
	var col := _colore_stanza(s)
	var root := _radice(String(s.id))
	var H: float = _T.alt
	var area := (x2 - x1) * (z2 - z1)
	var stretto := minf(x2 - x1, z2 - z1) < 9.0
	# luci vere: una ogni ~16 m, nel colore della stanza mischiato al lume
	var lc := col.lerp(_T.lume, 0.55)
	var nx := maxi(1, int(round((x2 - x1) / 17.0)))
	var nz := maxi(1, int(round((z2 - z1) / 17.0)))
	if not (tipo in ["ponte", "passerella"] and int(_T.fluido) == 0):
		for i in range(nx):
			for j in range(nz):
				_luce(Vector3(x1 + (i + 0.5) * (x2 - x1) / nx, 3.4, z1 + (j + 0.5) * (z2 - z1) / nz), lc, 4.2 if stretto else 5.5, 13.0 if stretto else 17.0)
	if int(_T.stile) == 0:
		# lanterne appese: tante, a grappoli, nel colore dell'ala; i fili salgono nel buio
		var quante := int(area / (22.0 if tipo == "boss" else 30.0))
		if tipo in ["ponte"]:
			quante = int(area / 50.0)
		for i in range(quante):
			var p := Vector3(_rng.randf_range(x1 + 0.9, x2 - 0.9), _rng.randf_range(3.6, H - 0.2), _rng.randf_range(z1 + 0.9, z2 - 0.9))
			if tipo == "boss":
				p.y = _rng.randf_range(4.8, H + 1.5)
			var k := _rng.randf_range(0.34, 0.62)
			var cl := col.lerp(_T.lume, _rng.randf_range(0.15, 0.8))
			_lanterne.append([Transform3D(Basis().scaled(Vector3(k, k * 1.25, k)), p), Color(cl.r, cl.g, cl.b, _rng.randf_range(0.7, 1.0))])
			if i % 3 == 0:
				_fili.append([Transform3D(Basis().scaled(Vector3(0.018, 6.0, 0.018)), p + Vector3(0, 3.0 + k * 0.6, 0)), Color(0.2, 0.18, 0.2)])
		# nebbia bassa nelle sale, lame di luce polverosa in quelle grandi
		if not stretto:
			var nb: Color = _tema_ala(s).get("nebbia", _T.nebbia)
			_nebbie.append([Transform3D(Basis().scaled(Vector3(x2 - x1 - 1.0, 1, z2 - z1 - 1.0)), c + Vector3(0, 0.35, 0)), Color(nb.r, nb.g, nb.b, 0.55)])
			for i in range(1 + int(area / 420.0)):
				var p2 := Vector3(_rng.randf_range(x1 + 4, x2 - 4), 0, _rng.randf_range(z1 + 4, z2 - 4))
				_fasci.append([Transform3D(Basis().scaled(Vector3(_rng.randf_range(2.2, 3.6), H + 3.0, 1)), p2 + Vector3(0, (H + 3.0) * 0.5, 0)), Color(_T.fascio.r, _T.fascio.g, _T.fascio.b, 0.5)])
				_alone(p2 + Vector3(0, 0.03, 0), _T.fascio, 2.4, 0.25)
	else:
		# la fucina: catene dal buio, bagliore basso, grate sopra canali di lava lungo le sale
		for i in range(int(area / 55.0)):
			var p := Vector3(_rng.randf_range(x1 + 1.5, x2 - 1.5), 0, _rng.randf_range(z1 + 1.5, z2 - 1.5))
			var lunga := _rng.randf_range(2.5, 5.0)
			_fili.append([Transform3D(Basis().scaled(Vector3(0.08, lunga, 0.08)), p + Vector3(0, H + 1.5 - lunga * 0.5, 0)), Color(0.45, 0.4, 0.38)])
			if i % 2 == 0:
				# una gabbia di braci in fondo alla catena
				_lanterne.append([Transform3D(Basis().scaled(Vector3(0.42, 0.5, 0.42)), p + Vector3(0, H + 1.5 - lunga - 0.2, 0)), Color(1.0, 0.45, 0.12, 0.9)])
		if not stretto and tipo in ["sala", "bivio", "boss"]:
			_canale(s, root)
			var nf: Color = _tema_ala(s).get("nebbia", Color(0.8, 0.25, 0.05))
			_nebbie.append([Transform3D(Basis().scaled(Vector3(x2 - x1 - 1.0, 1, z2 - z1 - 1.0)), c + Vector3(0, 0.3, 0)), Color(nf.r, nf.g, nf.b, 0.3)])
	match tipo:
		"ingresso": _ingresso(s, root)
		"boss": _sala_boss(s, root)
		"bivio": _bivio(s, root)


## Canale di lava coperto da una grata, lungo il lato lungo della sala (si cammina sopra).
func _canale(s: Dictionary, root: Node3D) -> void:
	var r: Array = s.r
	var x1 := float(r[0])
	var z1 := float(r[1])
	var x2 := float(r[2])
	var z2 := float(r[3])
	var lungo_z := (z2 - z1) >= (x2 - x1)
	for lato in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		var q := PlaneMesh.new()
		var lung := ((z2 - z1) if lungo_z else (x2 - x1)) - 7.0
		q.size = Vector2(1.1, lung) if lungo_z else Vector2(lung, 1.1)
		mi.mesh = q
		mi.material_override = _mat.cascata
		var off := ((x2 - x1) if lungo_z else (z2 - z1)) * 0.5 - 2.6
		mi.position = Vector3((x1 + x2) * 0.5 + (lato * off if lungo_z else 0.0), 0.012, (z1 + z2) * 0.5 + (0.0 if lungo_z else lato * off))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		# traverse della grata e cordoli
		var n := int(lung / 1.8)
		for k in range(n):
			var al := -lung * 0.5 + (k + 0.5) * lung / n
			var p := mi.position + (Vector3(0, 0.02, al) if lungo_z else Vector3(al, 0.02, 0))
			_box(root, Vector3(1.3, 0.05, 0.22) if lungo_z else Vector3(0.22, 0.05, 1.3), p, _mat.ferro)
		for b in [-1.0, 1.0]:
			_box(root, Vector3(0.12, 0.06, lung) if lungo_z else Vector3(lung, 0.06, 0.12), mi.position + (Vector3(b * 0.62, 0.02, 0) if lungo_z else Vector3(0, 0.02, b * 0.62)), _mat.ferro)
		for k in range(maxi(1, int(lung / 9.0))):
			var al2 := -lung * 0.5 + (k + 0.5) * lung / maxi(1, int(lung / 9.0))
			_alone(mi.position + (Vector3(0, 0.03, al2) if lungo_z else Vector3(al2, 0.03, 0)), Color(1.0, 0.4, 0.1), 3.2, 0.4)


## L'ingresso: nella Cripta il portone sigillato alle spalle con due guardiani di bronzo; nella Forgia la bocca della
## montagna, da cui entra la luce del giorno.
func _ingresso(s: Dictionary, root: Node3D) -> void:
	var r: Array = s.r
	var cx := (float(r[0]) + float(r[2])) * 0.5
	var z1 := float(r[1])
	if int(_T.stile) == 0:
		for lato in [-1.0, 1.0]:
			_box(root, Vector3(1.7, 4.6, 0.2), Vector3(cx + lato * 0.87, 2.3, z1 + 0.26), _mat.bronzo)
			_box(root, Vector3(0.12, 3.6, 0.06), Vector3(cx + lato * 0.3, 2.3, z1 + 0.38), _emissivo(_T.fregio, 1.8))
			_box(root, Vector3(0.9, 0.9, 0.06), Vector3(cx + lato * 0.95, 2.6, z1 + 0.38), _emissivo(_T.fregio, 1.2), Vector3(0, 0, PI * 0.25))
			var st := _statua(3.3, _mat.statua_bronzo)
			st.position = Vector3(cx + lato * 3.6, 0.0, z1 + 0.95)
			st.scale = Vector3(1, 1, 0.8)
			root.add_child(st)
			_box(root, Vector3(1.6, 0.5, 1.2), Vector3(cx + lato * 3.6, 0.0, z1 + 0.9), _mat.muro)
		_box(root, Vector3(4.2, 0.6, 0.5), Vector3(cx, 4.9, z1 + 0.3), _mat.muro)
		_alone(Vector3(cx, 0.03, z1 + 2.2), _T.fregio, 3.2, 0.35)
	else:
		# bocca della galleria: cornice di travi, luce fredda da fuori
		for lato in [-1.0, 1.0]:
			_box(root, Vector3(0.6, 5.0, 0.6), Vector3(cx + lato * 2.6, 2.5, z1 + 0.5), _mat.legno)
		_box(root, Vector3(6.4, 0.6, 0.7), Vector3(cx, 5.2, z1 + 0.5), _mat.legno)
		_box(root, Vector3(4.6, 4.9, 0.1), Vector3(cx, 2.45, z1 + 0.22), _emissivo(Color(0.55, 0.7, 0.95), 2.2))
		_fasci.append([Transform3D(Basis().scaled(Vector3(4.6, 6.5, 1)), Vector3(cx, 2.6, z1 + 1.6)), Color(0.6, 0.75, 1.0, 0.55)])
		_alone(Vector3(cx, 0.03, z1 + 3.0), Color(0.6, 0.75, 1.0), 4.5, 0.45)
		# binari e un carrello di minerale
		for lato in [-1.0, 1.0]:
			_box(root, Vector3(0.1, 0.08, 9.0), Vector3(cx + lato * 0.6, 0.04, z1 + 5.0), _mat.ferro)
		_box(root, Vector3(1.5, 0.8, 2.0), Vector3(cx, 0.75, z1 + 4.4), _mat.ferro)
		_box(root, Vector3(1.3, 0.3, 1.8), Vector3(cx, 1.2, z1 + 4.4), _emissivo(Color(1.0, 0.45, 0.1), 1.6))


## Il bivio: al centro una stele che indica le strade (un lume per ala, nel suo colore, dal lato della sua porta).
func _bivio(s: Dictionary, root: Node3D) -> void:
	var r: Array = s.r
	var c := Vector3((float(r[0]) + float(r[2])) * 0.5, 0, (float(r[1]) + float(r[3])) * 0.5)
	_alone(c + Vector3(0, 0.03, 0), _T.lume, 7.5, 0.3)


## La sala del boss: pedana, trono o fornace in fondo, grandi bracieri, il segno che la rende riconoscibile da lontano.
func _sala_boss(s: Dictionary, root: Node3D) -> void:
	var r: Array = s.r
	var x1 := float(r[0])
	var x2 := float(r[2])
	var z2 := float(r[3])
	var cx := (x1 + x2) * 0.5
	var H: float = _T.alt
	var boss: Dictionary = composta.boss
	var col: Color = _T.boss
	_luce(Vector3(float(boss.x), 5.0, float(boss.z)), col, 6.5, 24.0)
	if int(_T.stile) == 0:
		# gradoni e trono del Custode, con un guardiano gigantesco alle spalle
		for k in range(3):
			_box(root, Vector3(20.0 - k * 4.0, 0.4, 7.0 - k * 1.6), Vector3(cx, 0.2 + k * 0.4, z2 - 3.9 + k * 0.6), _mat.muro)
		var st := _statua(8.5, _mat.statua_bronzo)
		st.position = Vector3(cx, 1.2, z2 - 2.2)
		st.rotation.y = PI
		root.add_child(st)
		# l'aureola dietro la testa e gli occhi accesi: si vedono dalla porta
		_cil(root, 2.5, 2.5, 0.1, Vector3(cx, 8.9, z2 - 1.3), _emissivo(col, 0.9), 20, Vector3(PI * 0.5, 0, 0))
		_cil(root, 2.05, 2.05, 0.14, Vector3(cx, 8.9, z2 - 1.32), _mat.buio, 20, Vector3(PI * 0.5, 0, 0))
		for lato in [-1.0, 1.0]:
			_box(root, Vector3(0.26, 0.09, 0.06), Vector3(cx + lato * 0.24, 8.92, z2 - 2.76), _emissivo(col.lightened(0.4), 3.0))
		_aloni_su.append([Transform3D(Basis().scaled(Vector3(16.0, 16.0, 16.0)), Vector3(cx, 7.0, z2 - 2.0)), Color(col.r, col.g, col.b, 0.3)])
		_luce(Vector3(cx, 5.5, z2 - 6.5), col.lightened(0.35), 6.0, 16.0)
		for lato in [-1.0, 1.0]:
			_cil(root, 0.9, 0.5, 1.5, Vector3(cx + lato * 7.0, 1.55, z2 - 4.6), _mat.bronzo, 10)
			_cil(root, 0.5, 0.7, 0.8, Vector3(cx + lato * 7.0, 0.8, z2 - 4.6), _mat.muro, 10)
			_fiamma(Vector3(cx + lato * 7.0, 2.2, z2 - 4.6), col, 2.6, 6.0)
		# un cerchio di lanterne sopra il centro della sala
		for k in range(20):
			var a := TAU * k / 20.0
			var p := Vector3(float(boss.x) + cos(a) * 10.5, 5.6 + sin(a * 3.0) * 0.4, float(boss.z) + sin(a) * 10.5)
			_lanterne.append([Transform3D(Basis().scaled(Vector3(0.45, 0.62, 0.45)), p), Color(col.r, col.g, col.b, 1.0)])
			_fili.append([Transform3D(Basis().scaled(Vector3(0.015, 6.0, 0.015)), p + Vector3(0, 3.3, 0)), Color(0.2, 0.18, 0.2)])
		_fasci.append([Transform3D(Basis().scaled(Vector3(7.0, H + 5.0, 1)), Vector3(float(boss.x), (H + 5.0) * 0.5, float(boss.z))), Color(col.r, col.g, col.b, 0.4)])
	else:
		# la grande fornace: bocca ardente, colata che scende in una vasca, e sopra gli occhi socchiusi del drago
		_box(root, Vector3(18.0, 11.0, 2.4), Vector3(cx, 5.5, z2 - 1.0), _mat.muro)
		_box(root, Vector3(9.0, 0.8, 3.0), Vector3(cx, 6.4, z2 - 1.3), _mat.ferro)
		for lato in [-1.0, 1.0]:
			_box(root, Vector3(1.2, 6.4, 3.0), Vector3(cx + lato * 4.6, 3.2, z2 - 1.3), _mat.ferro)
			_box(root, Vector3(2.4, 0.22, 0.12), Vector3(cx + lato * 3.3, 8.6, z2 - 2.26), _emissivo(Color(1.0, 0.6, 0.1), 3.5), Vector3(0, 0, -lato * 0.22))
			_cil(root, 0.5, 0.2, 4.2, Vector3(cx + lato * 7.4, 10.4, z2 - 1.9), _mat.muro, 6, Vector3(-0.5, 0, -lato * 0.5))
		var bocca := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(8.0, 6.0)
		bocca.mesh = q
		bocca.material_override = _mat.cascata
		bocca.position = Vector3(cx, 3.0, z2 - 2.3)
		bocca.rotation.y = PI
		bocca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(bocca)
		_box(root, Vector3(10.5, 0.7, 2.2), Vector3(cx, 0.35, z2 - 3.4), _mat.ferro)
		_box(root, Vector3(9.6, 0.08, 1.6), Vector3(cx, 0.72, z2 - 3.4), _emissivo(Color(1.0, 0.42, 0.08), 4.0))
		_alone(Vector3(cx, 0.03, z2 - 7.0), Color(1.0, 0.4, 0.1), 9.0, 0.6)
		_aloni_su.append([Transform3D(Basis().scaled(Vector3(20.0, 14.0, 20.0)), Vector3(cx, 4.0, z2 - 3.0)), Color(1.0, 0.3, 0.06, 0.22)])
		_luce(Vector3(cx, 3.0, z2 - 6.0), Color(1.0, 0.4, 0.1), 7.0, 24.0)
		for lato in [-1.0, 1.0]:
			_fili.append([Transform3D(Basis().scaled(Vector3(0.22, 9.0, 0.22)), Vector3(cx + lato * 9.5, H + 4.0 - 4.5, z2 - 3.5)), Color(0.45, 0.4, 0.38)])


# ------------------------------------------------------------------ ostacoli
func _ostacolo(o: Array) -> void:
	var p := Vector3(float(o[0]), 0, float(o[1]))
	var rg := float(o[2])
	var forma := String(o[3]) if o.size() > 3 else "pilastro"
	var st := _stanza_a(Vector2(p.x, p.z))
	var root := _radice(String(st.get("id", "resto")))
	var col := _colore_stanza(st) if not st.is_empty() else (_T.lume as Color)
	var H: float = _T.alt
	match forma:
		"pilastro", "colonna":
			var grossa := forma == "colonna"
			var lati := 12 if grossa else 8
			_cil(root, rg * 1.02, rg * 1.08, 0.5, p + Vector3(0, 0.25, 0), _mat.muro, lati)
			_cil(root, rg * 0.82, rg * 0.9, H + 1.0, p + Vector3(0, (H + 1.0) * 0.5, 0), _mat.muro, lati)
			_cil(root, rg * 0.98, rg * 0.86, 0.35, p + Vector3(0, 4.3, 0), _mat.ferro if int(_T.stile) == 1 else _mat.muro, lati)
			_cil(root, rg * 0.92, rg * 0.92, 0.22, p + Vector3(0, 1.5, 0), _mat.bronzo if grossa else _mat.muro, lati)
			# quattro lumi attorno al pilastro
			for k in range(4):
				var a := PI * 0.25 + k * PI * 0.5
				var q := p + Vector3(cos(a) * (rg * 0.95), 2.7, sin(a) * (rg * 0.95))
				if grossa or k % 2 == 0:
					_lanterne.append([Transform3D(Basis().scaled(Vector3(0.3, 0.42, 0.3)), q), Color(col.r, col.g, col.b, 1.0)])
			_alone(p + Vector3(0, 0.03, 0), col, rg + 2.6, 0.3)
		"sarcofago":
			var lungo_x := _rng.randf() < 0.5
			var d := Vector3(2.5, 0.85, 1.2) if lungo_x else Vector3(1.2, 0.85, 2.5)
			_box(root, d + Vector3(0.3, -0.5, 0.3), p + Vector3(0, 0.18, 0), _mat.muro)
			_box(root, d, p + Vector3(0, 0.75, 0), _mat.muro)
			_box(root, d + Vector3(0.16, -0.6, 0.16), p + Vector3(0, 1.28, 0), _mat.muro, Vector3(0, _rng.randf_range(-0.12, 0.12), 0))
			_box(root, Vector3(d.x * 0.6, 0.06, d.z * 0.6), p + Vector3(0, 1.44, 0), _emissivo(col, 0.9))
			_alone(p + Vector3(0, 0.03, 0), col, 2.8, 0.22)
		"urna":
			_cil(root, rg * 0.55, rg * 0.4, 0.3, p + Vector3(0, 0.15, 0), _mat.bronzo, 10)
			_cil(root, rg * 0.95, rg * 0.55, 1.1, p + Vector3(0, 0.85, 0), _mat.statua, 10)
			_cil(root, rg * 0.6, rg * 0.95, 0.7, p + Vector3(0, 1.75, 0), _mat.statua, 10)
			_cil(root, rg * 0.7, rg * 0.6, 0.16, p + Vector3(0, 2.18, 0), _mat.bronzo, 10)
			_fiamma(p + Vector3(0, 2.2, 0), col, 1.1, 3.4)
		"incudine":
			_box(root, Vector3(1.9, 0.5, 1.5), p + Vector3(0, 0.25, 0), _mat.muro)
			_box(root, Vector3(1.1, 0.8, 0.9), p + Vector3(0, 0.9, 0), _mat.ferro)
			_box(root, Vector3(2.9, 0.55, 1.2), p + Vector3(0, 1.55, 0), _mat.ferro)
			_cil(root, 0.05, 0.45, 1.3, p + Vector3(1.95, 1.6, 0), _mat.ferro, 8, Vector3(0, 0, -PI * 0.5))
			_box(root, Vector3(1.0, 0.07, 0.6), p + Vector3(-0.3, 1.86, 0), _emissivo(Color(1.0, 0.5, 0.1), 2.6))
			_alone(p + Vector3(0, 0.03, 0), Color(1.0, 0.45, 0.1), 3.4, 0.3)
		"crogiolo":
			_cil(root, rg * 0.95, rg * 0.7, 1.5, p + Vector3(0, 0.95, 0), _mat.ferro, 12)
			_cil(root, rg * 1.02, rg * 1.02, 0.16, p + Vector3(0, 1.72, 0), _mat.bronzo, 12)
			_cil(root, rg * 0.84, rg * 0.84, 0.06, p + Vector3(0, 1.74, 0), _emissivo(Color(1.0, 0.45, 0.08), 5.0), 12)
			for k in range(3):
				var a := k * TAU / 3.0
				_box(root, Vector3(0.22, 0.5, 0.22), p + Vector3(cos(a) * rg * 0.7, 0.25, sin(a) * rg * 0.7), _mat.ferro)
			_alone(p + Vector3(0, 0.03, 0), Color(1.0, 0.42, 0.1), rg + 3.0, 0.4)
			_aloni_su.append([Transform3D(Basis().scaled(Vector3(5.0, 5.0, 5.0)), p + Vector3(0, 2.3, 0)), Color(1.0, 0.4, 0.08, 0.22)])
		"mantice":
			var m := Mantice.new()
			m.costruisci(_mat.cuoio, _mat.ferro, _mat.legno, 1.0)
			m.position = p
			m.rotation.y = -PI * 0.5
			add_child(m)
			_alone(p + Vector3(-1.6, 0.03, 0), Color(1.0, 0.45, 0.1), 2.6, 0.35)
		"scrigno", "braciere", "leva":
			pass                                  # hanno una parte che si muove: vedi _tesoro_e_ritorni e _porte_e_leve


# ------------------------------------------------------------------ frane, trappole, porte, tesoro
## Il varco di un'ala chiusa questa settimana: arco crollato, massi, assi inchiodate, lo stendardo dell'ala a terra.
func _frana(f: Dictionary) -> void:
	var c := Vector2(float(f.x), float(f.z))
	var oriz := int(f.oriz) == 1
	var larg := float(f.w)
	# da che parte sta la stanza rimasta?
	var n := Vector2(0, 1) if oriz else Vector2(1, 0)
	var st := _stanza_a(c + n * 1.2)
	if st.is_empty():
		n = -n
		st = _stanza_a(c + n * 1.2)
	if st.is_empty():
		return
	# il muro della sala passa a mezzo metro dal centro della sovrapposizione, dalla parte della strada chiusa
	var bordo := c - n * 0.5
	var t := {"c": bordo, "d": Vector2(1, 0) if oriz else Vector2(0, 1), "n": n, "oriz": oriz, "lung": larg, "root": _radice(String(st.id))}
	var root: Node3D = t.root
	var col := Color(0.5, 0.5, 0.5)
	var ala := String(f.get("ala", ""))
	if pianta.ali.has(ala):
		col = Color.html(String(pianta.ali[ala].colore))
	var tavola := Edifici.legno(Color(0.34, 0.24, 0.15))
	_box(root, _dm(t, larg + 0.4, 4.4, 0.1), _pm(t, 0, 0.17, 2.2), _mat.buio)
	for lato in [-1.0, 1.0]:
		_box(root, _dm(t, 0.8, 4.9, 0.36), _pm(t, lato * (larg * 0.5 + 0.25), 0.3, 2.45), _mat.muro)
	# l'architrave spezzato: un pezzo ancora su, l'altro caduto di traverso
	_box(root, _dm(t, larg * 0.6, 0.65, 0.55), _pm(t, -larg * 0.24, 0.36, 4.55), _mat.muro, Vector3(0, 0, 0.12) if oriz else Vector3(0.12, 0, 0))
	_box(root, _dm(t, larg * 0.55, 0.65, 0.55), _pm(t, larg * 0.2, 0.5, 2.6), _mat.muro, Vector3(0, 0, -0.62) if oriz else Vector3(-0.62, 0, 0))
	# il cumulo: file di blocchi grandi appena smossi che riempiono il varco, pietrame ai piedi
	var y := 0.0
	var fila := 0
	while y < 3.6:
		var alto := _rng.randf_range(0.8, 1.15)
		var x := -larg * 0.5 + (0.0 if fila % 2 == 0 else -0.5)
		while x < larg * 0.5 - 0.2:
			var lungo := _rng.randf_range(1.0, 1.7)
			if y > 2.2 and _rng.randf() < 0.3:
				x += lungo
				continue
			_box(root, _dm(t, lungo - 0.06, alto - 0.05, 0.75), _pm(t, clampf(x + lungo * 0.5, -larg * 0.5 + 0.4, larg * 0.5 - 0.4), 0.42 + _rng.randf_range(-0.08, 0.16), y + alto * 0.5), _mat.roccia, Vector3(0, _rng.randf_range(-0.22, 0.22), _rng.randf_range(-0.09, 0.09)) if oriz else Vector3(_rng.randf_range(-0.09, 0.09), _rng.randf_range(-0.22, 0.22), 0))
			x += lungo
		y += alto
		fila += 1
	for i in range(9):
		var k := _rng.randf_range(0.35, 0.7)
		_box(root, Vector3(k, k * 0.7, k), _pm(t, _rng.randf_range(-larg * 0.5, larg * 0.5), _rng.randf_range(0.85, 1.15), k * 0.3), _mat.muro, Vector3(0, _rng.randf() * 3.0, 0))
	for i in range(2):
		_box(root, _dm(t, larg * 1.25, 0.34, 0.1), _pm(t, 0, 0.86, 2.0), tavola, (Vector3(0, 0, 0.55 - i * 1.1) if oriz else Vector3(0.55 - i * 1.1, 0, 0)))
	# lo stendardo dell'ala, stinto e strappato; il disco senza luce; una lama di luce fredda dalla volta crollata
	for lato in [-1.0, 1.0]:
		_telo(root, _pm(t, lato * (larg * 0.5 + 1.9), 0.2, 2.9), 1.2, 3.0, col, _yaw_muro(t), true)
	_fasci.append([Transform3D(Basis().scaled(Vector3(3.2, float(_T.alt) + 3.0, 1)), _pm(t, 0, 1.6, (float(_T.alt) + 3.0) * 0.5)), Color(_T.fascio.r, _T.fascio.g, _T.fascio.b, 0.7)])
	_alone(_pm(t, 0, 1.6, 0.035), _T.fascio, 3.0, 0.4)


## Bocca di una trappola a tempo: una grata tonda nel pavimento con un filo di luce (il preavviso lo dà il server).
func _pericolo(tr: Dictionary) -> void:
	var p := Vector3(float(tr.x), 0, float(tr.z))
	var rg := float(tr.r)
	var st := _stanza_a(Vector2(p.x, p.z))
	var root := _radice(String(st.get("id", "resto")))
	var col: Color = _T.boss if int(_T.stile) == 0 else Color(1.0, 0.45, 0.1)
	_cil(root, rg * 0.55, rg * 0.55, 0.05, p + Vector3(0, 0.025, 0), _mat.ferro, 14)
	_cil(root, rg * 0.42, rg * 0.42, 0.052, p + Vector3(0, 0.027, 0), _emissivo(col.darkened(0.3), 0.55), 14)
	for k in range(4):
		_box(root, Vector3(rg * 1.1, 0.07, 0.1), p + Vector3(0, 0.04, 0), _mat.ferro, Vector3(0, k * PI * 0.25, 0))
	_alone(p + Vector3(0, 0.035, 0), col, rg, 0.3)
	if String(tr.id).begins_with("maglio"):
		# il maglio sospeso sopra la passerella
		_box(root, Vector3(1.8, 2.2, 1.8), p + Vector3(0, 6.4, 0), _mat.ferro)
		_cil(root, 0.3, 0.3, 4.0, p + Vector3(0, 9.4, 0), _mat.bronzo, 8)


func _mobile(porta: String, nodo: Node3D, chiuso: Vector3, aperto: Vector3, sparisce := false) -> void:
	if not _mobili.has(porta):
		_mobili[porta] = []
	(_mobili[porta] as Array).append({"nodo": nodo, "chiuso": chiuso, "aperto": aperto, "sparisce": sparisce})
	var aperta := int(porte.get(porta, 0)) == 1
	nodo.position = aperto if aperta else chiuso
	nodo.visible = not (aperta and sparisce)


func _porte_e_leve() -> void:
	for s in _stanze:
		if not s.has("porta"):
			continue
		var pid := String(s.porta)
		var r: Array = s.r
		var x1 := float(r[0])
		var z1 := float(r[1])
		var x2 := float(r[2])
		var z2 := float(r[3])
		var c := Vector3((x1 + x2) * 0.5, 0, (z1 + z2) * 0.5)
		var col := _colore_stanza(s)
		var n := Node3D.new()
		add_child(n)
		if String(s.tipo) == "ponte":
			# il ponte mobile: impalcato di ferro con le sponde; chiuso è sommerso nel lago, aperto emerge
			var lungo_z := (z2 - z1) >= (x2 - x1)
			var d := Vector3(x2 - x1, 0.5, z2 - z1)
			_box(n, d, Vector3(0, -0.27, 0), _mat.ferro)
			for lato in [-1.0, 1.0]:
				var off := Vector3(lato * (x2 - x1) * 0.5, 0, 0) if lungo_z else Vector3(0, 0, lato * (z2 - z1) * 0.5)
				_box(n, Vector3(0.1, 0.1, z2 - z1) if lungo_z else Vector3(x2 - x1, 0.1, 0.1), off + Vector3(0, 1.05, 0), _mat.ferro)
				var lung := (z2 - z1) if lungo_z else (x2 - x1)
				for k in range(int(lung / 3.0) + 1):
					var al := -lung * 0.5 + k * lung / int(lung / 3.0)
					_box(n, Vector3(0.12, 1.1, 0.12), off + (Vector3(0, 0.55, al) if lungo_z else Vector3(al, 0.55, 0)), _mat.ferro)
			Edifici.fondi(n)
			var mi := MeshInstance3D.new()
			mi.mesh = _mesh_pavimento([x1 - c.x, z1 - c.z, x2 - c.x, z2 - c.z], 0.8, col, 0.0)
			mi.material_override = _mat.pav
			n.add_child(mi)
			_mobile(pid, n, c + Vector3(0, float(_T.fondo) - 0.55, 0), c)   # sommerso: dal lago spuntano solo le sponde
			# la catena che sbarra l'imbocco dal lato di terra finché il ponte è sotto
			for q in _stanze:
				if q == s or String(q.tipo) in ["ponte", "tesoro"]:
					continue
				var ov := _sovrapposizione(r, q.r)
				if ov.is_empty():
					continue
				var pc := Vector3((float(ov[0]) + float(ov[2])) * 0.5, 0, (float(ov[1]) + float(ov[3])) * 0.5)
				var sbarra := Node3D.new()
				add_child(sbarra)
				var larga := (x2 - x1) if lungo_z else (z2 - z1)
				for y in [0.5, 1.0]:
					_box(sbarra, Vector3(larga - 0.4, 0.12, 0.12) if lungo_z else Vector3(0.12, 0.12, larga - 0.4), Vector3(0, y, 0), _mat.ferro)
				_box(sbarra, Vector3(0.8, 0.8, 0.08) if lungo_z else Vector3(0.08, 0.8, 0.8), Vector3(0, 0.9, 0), _emissivo(col, 2.2), Vector3(0, 0, PI * 0.25) if lungo_z else Vector3(PI * 0.25, 0, 0))
				_mobile(pid, sbarra, pc, pc + Vector3(0, -2.5, 0), true)
		else:
			# cancello a sbarre con il sigillo: aperto, scende nel pavimento
			var lungo_x := (x2 - x1) <= (z2 - z1)          # la stanza è un corridoio lungo z: il cancello è largo in x
			var larg := (x2 - x1) if lungo_x else (z2 - z1)
			var nb := int(larg / 0.55)
			for k in range(nb + 1):
				var al := -larg * 0.5 + 0.25 + k * (larg - 0.5) / nb
				_cil(n, 0.07, 0.07, 4.5, Vector3(al, 2.25, 0) if lungo_x else Vector3(0, 2.25, al), _mat.ferro, 6)
				_cil(n, 0.0, 0.1, 0.3, Vector3(al, 4.65, 0) if lungo_x else Vector3(0, 4.65, al), _mat.bronzo, 6)
			for y in [0.5, 2.3, 4.1]:
				_box(n, Vector3(larg - 0.3, 0.16, 0.16) if lungo_x else Vector3(0.16, 0.16, larg - 0.3), Vector3(0, y, 0), _mat.ferro)
			_cil(n, 1.0, 1.0, 0.12, Vector3(0, 2.4, 0), _mat.bronzo, 16, Vector3(PI * 0.5, 0, 0) if lungo_x else Vector3(0, 0, PI * 0.5))
			_cil(n, 0.78, 0.78, 0.16, Vector3(0, 2.4, 0), _emissivo(col, 1.2), 16, Vector3(PI * 0.5, 0, 0) if lungo_x else Vector3(0, 0, PI * 0.5))
			Edifici.fondi(n)
			_mobile(pid, n, c, c + Vector3(0, -5.2, 0), true)
			_alone(c + Vector3(0, 0.03, 0), col, 3.0, 0.4)
	for l in composta.leve:
		var p := Vector3(float(l.x), 0, float(l.z))
		var root := _radice(String(_stanza_a(Vector2(p.x, p.z)).get("id", "resto")))
		var col2: Color = Color.html(String(pianta.ali[String(l.porta)].colore)) if pianta.ali.has(String(l.porta)) else (_T.boss as Color)
		_box(root, Vector3(0.9, 0.35, 0.9), p + Vector3(0, 0.17, 0), _mat.ferro)
		_box(root, Vector3(0.3, 1.0, 0.5), p + Vector3(0, 0.8, 0), _mat.ferro)
		var asta := Node3D.new()
		add_child(asta)
		_box(asta, Vector3(0.1, 1.5, 0.1), Vector3(0, 0.75, 0), _mat.bronzo)
		_cil(asta, 0.16, 0.16, 0.3, Vector3(0, 1.5, 0), _emissivo(col2, 3.0), 8, Vector3(0, 0, PI * 0.5))
		asta.position = p + Vector3(0, 1.0, 0)
		asta.rotation.x = -0.7
		if not _mobili.has("__leva:" + String(l.porta)):
			_mobili["__leva:" + String(l.porta)] = []
		(_mobili["__leva:" + String(l.porta)] as Array).append(asta)
		_alone(p + Vector3(0, 0.03, 0), col2, 2.8, 0.5)
		_aloni_su.append([Transform3D(Basis().scaled(Vector3(2.6, 2.6, 2.6)), p + Vector3(0, 2.4, 0)), Color(col2.r, col2.g, col2.b, 0.3)])


func _tesoro_e_ritorni() -> void:
	# lo scrigno: chiuso finché il suo guardiano è in piedi, poi il coperchio si alza e l'oro brilla
	if composta.get("tesoro") is Dictionary:
		var T: Dictionary = composta.tesoro
		var p := Vector3(float(T.x), 0, float(T.z))
		var root := _radice(String(_stanza_a(Vector2(p.x, p.z)).get("id", "resto")))
		var oro := Color(1.0, 0.8, 0.3)
		_box(root, Vector3(3.2, 0.3, 2.4), p + Vector3(0, 0.15, 0), _mat.muro)
		_box(root, Vector3(1.9, 0.9, 1.2), p + Vector3(0, 0.75, 0), _mat.legno)
		for lato in [-1.0, 1.0]:
			_box(root, Vector3(0.14, 0.94, 1.24), p + Vector3(lato * 0.7, 0.75, 0), _mat.oro)
			_box(root, Vector3(0.2, 0.2, 0.2), p + Vector3(lato * 0.9, 0.45, 0.66), _mat.oro)
		_box(root, Vector3(1.94, 0.12, 1.24), p + Vector3(0, 0.36, 0), _mat.oro)
		# offerte: mucchietti d'oro, ciotole e candele ai lati
		for i in range(7):
			var a := _rng.randf() * TAU
			var q := p + Vector3(cos(a) * _rng.randf_range(1.2, 2.3), 0, absf(sin(a)) * _rng.randf_range(0.5, 2.0) + 0.3)
			if i % 2 == 0:
				_cil(root, 0.05, 0.42, 0.3, q + Vector3(0, 0.15, 0), _mat.oro, 8)
			else:
				_cil(root, 0.34, 0.16, 0.2, q + Vector3(0, 0.1, 0), _mat.bronzo, 8)
				_fiamma(q + Vector3(0, 0.2, 0), oro, 0.4, 1.2)
		var coperchio := Node3D.new()
		add_child(coperchio)
		coperchio.position = p + Vector3(0, 1.2, -0.6)
		_box(coperchio, Vector3(1.96, 0.3, 1.26), Vector3(0, 0.15, 0.6), _mat.legno)
		_box(coperchio, Vector3(2.0, 0.1, 0.16), Vector3(0, 0.32, 0.6), _mat.bronzo)
		_box(coperchio, Vector3(0.3, 0.34, 0.1), Vector3(0, 0.1, 1.24), _mat.oro)
		_mobili["__scrigno"] = [{"nodo": coperchio, "chiuso": Vector3.ZERO, "aperto": Vector3(-1.25, 0, 0)}]
		var luce_oro := Node3D.new()
		add_child(luce_oro)
		_box(luce_oro, Vector3(1.7, 0.2, 1.0), p + Vector3(0, 1.15, 0), _emissivo(oro, 4.0))
		var l := OmniLight3D.new()
		l.light_color = oro
		l.light_energy = 5.0
		l.omni_range = 9.0
		l.position = p + Vector3(0, 2.0, 0.5)
		luce_oro.add_child(l)
		luce_oro.visible = false
		_accesi["tes"] = [luce_oro]
		_alone(p + Vector3(0, 0.03, 0.4), oro, 3.2, 0.4)
	# i Bracieri del Ritorno: spenti finché il gruppo non ci arriva
	for rt in composta.ritorni:
		var p2 := Vector3(float(rt.x), 0, float(rt.z))
		if _stanza_a(Vector2(p2.x, p2.z)).is_empty():
			continue
		var root2 := _radice(String(_stanza_a(Vector2(p2.x, p2.z)).get("id", "resto")))
		_cil(root2, 0.5, 0.65, 0.3, p2 + Vector3(0, 0.15, 0), _mat.muro, 10)
		for k in range(3):
			var a := k * TAU / 3.0
			_box(root2, Vector3(0.1, 1.2, 0.1), p2 + Vector3(cos(a) * 0.32, 0.8, sin(a) * 0.32), _mat.ferro, Vector3(sin(a) * 0.25, 0, -cos(a) * 0.25))
		_cil(root2, 0.72, 0.3, 0.42, p2 + Vector3(0, 1.5, 0), _mat.bronzo, 12)
		var acceso := Node3D.new()
		add_child(acceso)
		var col := Color(0.45, 0.85, 1.0)
		var q := QuadMesh.new()
		q.size = Vector2(1, 1)
		_multi(q, _luce_mat(0, true, 1.3), [[Transform3D(Basis().scaled(Vector3(1.5, 2.1, 1.5)), p2 + Vector3(0, 2.7, 0)), col]], acceso)
		_multi(q, _luce_mat(1, false, 1.0), [[Transform3D(Basis(Vector3.RIGHT, -PI * 0.5).scaled(Vector3(9, 9, 9)), p2 + Vector3(0, 0.04, 0)), Color(col.r, col.g, col.b, 0.5)]], acceso)
		var fl := OmniLight3D.new()
		fl.light_color = col
		fl.light_energy = 5.0
		fl.omni_range = 11.0
		fl.position = p2 + Vector3(0, 2.4, 0)
		acceso.add_child(fl)
		_box(acceso, Vector3(0.7, 0.08, 0.7), p2 + Vector3(0, 1.72, 0), _emissivo(col, 4.0))
		acceso.visible = false
		_accesi["rit:" + String(rt.id)] = [acceso]


# ------------------------------------------------------------------ luci finte in MultiMesh
func _multi(mesh: Mesh, mat: Material, voci: Array, genitore: Node3D = null, vista := 0.0) -> void:
	if voci.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = voci.size()
	for i in range(voci.size()):
		mm.set_instance_transform(i, voci[i][0])
		mm.set_instance_color(i, voci[i][1])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if vista > 0.0:
		mi.visibility_range_end = vista
	(genitore if genitore != null else self).add_child(mi)


func _multimesh() -> void:
	var quadrato := QuadMesh.new()
	quadrato.size = Vector2(1, 1)
	_multi(quadrato, _luce_mat(0, true, 1.0), _fiamme)
	_multi(quadrato, _luce_mat(1, false, 1.0), _aloni)
	_multi(quadrato, _luce_mat(1, true, 1.0), _aloni_su)
	_multi(quadrato, _luce_mat(2, true, 0.5), _fasci)
	var steso := PlaneMesh.new()
	steso.size = Vector2(1, 1)
	steso.subdivide_width = 5
	steso.subdivide_depth = 5
	_multi(steso, _luce_mat(3, false, 1.0), _nebbie)
	var lume := CylinderMesh.new()
	lume.top_radius = 0.38
	lume.bottom_radius = 0.38
	lume.height = 1.0
	lume.radial_segments = 6
	lume.rings = 1
	lume.cap_top = false
	lume.cap_bottom = false
	var ml := ShaderMaterial.new()
	ml.shader = preload("res://shader/prova_lanterna.gdshader")
	_per_stanza(lume, ml, _lanterne)
	var filo := BoxMesh.new()
	filo.size = Vector3(1, 1, 1)
	var mf := StandardMaterial3D.new()
	mf.vertex_color_use_as_albedo = true
	mf.albedo_color = Color(0.3, 0.3, 0.3)
	mf.roughness = 0.7
	mf.metallic = 0.4
	_per_stanza(filo, mf, _fili)


## Un MultiMesh per stanza (voci = [trasformazione, colore, stanza]).
func _per_stanza(mesh: Mesh, mat: Material, voci: Array) -> void:
	var gruppi := {}
	for v in voci:
		var k := String(v[2]) if (v as Array).size() > 2 else "resto"
		if not gruppi.has(k):
			gruppi[k] = []
		(gruppi[k] as Array).append(v)
	for k in gruppi:
		_multi(mesh, mat, gruppi[k], null, VISTA + 30.0)


## Il renderer leggero regge poche luci insieme: restano accese solo quelle vicine alla visuale.
func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var qui := cam.global_position
	for l: OmniLight3D in _luci:
		l.visible = l.global_position.distance_squared_to(qui) < 46.0 * 46.0
	# la leva resta tirata quando la sua porta è aperta
	for k in _mobili:
		if String(k).begins_with("__leva:"):
			var aperta := int(porte.get(String(k).substr(7), 0)) == 1
			for a in _mobili[k]:
				(a as Node3D).rotation.x = lerpf((a as Node3D).rotation.x, 0.7 if aperta else -0.7, minf(1.0, _dt * 4.0))


# ------------------------------------------------------------------ la mappa della Prova (minimappa e mappa grande)
## Disegna la pianta nel rettangolo dato: stanze nel colore della loro ala, vuoti, porte chiuse, ali franate, boss,
## tesoro, braciere, la propria posizione e quella dei compagni. `io` in coordinate del mondo.
func disegna_pianta(ci: CanvasItem, rett: Rect2, io: Vector3, rot: float, grande := false, forze := -1.0) -> void:
	var b1: Array = composta.boundsMin
	var b2: Array = composta.boundsMax
	var lx := float(b2[0]) - float(b1[0])
	var lz := float(b2[1]) - float(b1[1])
	var sc := minf(rett.size.x / lx, rett.size.y / lz)
	var o := rett.position + (rett.size - Vector2(lx, lz) * sc) * 0.5
	var su := func(x: float, z: float) -> Vector2: return o + Vector2(float(b2[0]) - x, float(b2[1]) - z) * sc     # nord (il boss) in alto, come si guarda entrando
	var rr := func(r: Array) -> Rect2:
		var a: Vector2 = su.call(float(r[2]), float(r[3]))
		var b: Vector2 = su.call(float(r[0]), float(r[1]))
		return Rect2(a, b - a)
	for r in composta.vuoti:
		ci.draw_rect(rr.call(r), Color(0.55, 0.16, 0.04, 0.75) if int(_T.fluido) == 0 else Color(0.1, 0.07, 0.2, 0.85))
	# prima il contorno scuro, poi le stanze
	for s in _stanze:
		ci.draw_rect((rr.call(s.r) as Rect2).grow(1.5 if grande else 1.0), Color(0.03, 0.03, 0.04, 0.9))
	for s in _stanze:
		var chiusa: bool = s.has("porta") and int(porte.get(String(s.porta), 0)) != 1
		var col := Color(0.42, 0.42, 0.46)
		var tipo := String(s.tipo)
		if tipo == "boss":
			col = (_T.boss as Color).darkened(0.25)
		elif String(s.get("ala", "")) != "" or tipo == "tesoro":
			col = _colore_stanza(s).darkened(0.35)
		if chiusa:
			col = col.darkened(0.6)
		ci.draw_rect(rr.call(s.r), col)
		if chiusa:
			var q: Rect2 = rr.call(s.r)
			ci.draw_line(q.position, q.end, Color(1, 0.9, 0.6, 0.9), 1.5)
			ci.draw_line(Vector2(q.end.x, q.position.y), Vector2(q.position.x, q.end.y), Color(1, 0.9, 0.6, 0.9), 1.5)
	for f in composta.frane:
		var p: Vector2 = su.call(float(f.x), float(f.z))
		var k := 4.0 if grande else 2.5
		ci.draw_line(p - Vector2(k, k), p + Vector2(k, k), Color(1.0, 0.3, 0.25), 2.0)
		ci.draw_line(p - Vector2(k, -k), p + Vector2(k, -k), Color(1.0, 0.3, 0.25), 2.0)
	for t in composta.pericoli:
		ci.draw_arc(su.call(float(t.x), float(t.z)), float(t.r) * sc, 0.0, TAU, 12, Color(1.0, 0.5, 0.2, 0.8), 1.0)
	# boss, tesoro, braciere, leve
	var boss: Dictionary = composta.boss
	var pb: Vector2 = su.call(float(boss.x), float(boss.z))
	var kb := 10.0 if grande else 4.5
	ci.draw_colored_polygon(PackedVector2Array([pb + Vector2(0, -kb), pb + Vector2(kb, 0), pb + Vector2(0, kb), pb + Vector2(-kb, 0)]), Color(1.0, 0.25, 0.2))
	ci.draw_polyline(PackedVector2Array([pb + Vector2(0, -kb), pb + Vector2(kb, 0), pb + Vector2(0, kb), pb + Vector2(-kb, 0), pb + Vector2(0, -kb)]), Color(1, 1, 1, 0.9), 1.0)
	if composta.get("tesoro") is Dictionary:
		var pt: Vector2 = su.call(float(composta.tesoro.x), float(composta.tesoro.z))
		var kt := 4.5 if grande else 3.0
		ci.draw_rect(Rect2(pt - Vector2(kt, kt * 0.8), Vector2(kt * 2.0, kt * 1.6)), Color(0.5, 0.42, 0.2) if scrigno else Color(1.0, 0.82, 0.25))
		ci.draw_rect(Rect2(pt - Vector2(kt, kt * 0.8), Vector2(kt * 2.0, kt * 1.6)), Color(0.1, 0.08, 0.02), false, 1.0)
	for rt in composta.ritorni:
		var pr: Vector2 = su.call(float(rt.x), float(rt.z))
		ci.draw_circle(pr, 4.0 if grande else 2.6, Color(0.45, 0.85, 1.0) if ritorno == String(rt.id) else Color(0.25, 0.3, 0.35))
	for l in composta.leve:
		var pl: Vector2 = su.call(float(l.x), float(l.z))
		var aperta := int(porte.get(String(l.porta), 0)) == 1
		ci.draw_rect(Rect2(pl - Vector2(2.5, 2.5), Vector2(5, 5)), Color(0.4, 0.9, 0.4) if aperta else Color(1.0, 0.6, 0.2))
	# l'ingresso
	var pi: Vector2 = su.call(float(composta.spawn[0]), float(composta.spawn[1]))
	ci.draw_circle(pi, 3.0 if grande else 2.0, Color(0.9, 0.9, 0.9, 0.8))
	# compagni e io
	for c in compagni:
		var pc: Vector2 = su.call(float(c[1]), float(c[2]))
		if Vector2(float(c[1]) + origine.x - io.x, float(c[2]) + origine.y - io.z).length() < 0.6:
			continue
		ci.draw_circle(pc, 4.0 if grande else 2.8, Color(0.45, 0.45, 0.45) if int(c[3]) == 1 else Color(0.45, 0.75, 1.0))
	var p_io: Vector2 = su.call(io.x - origine.x, io.z - origine.y)
	var dir := Vector2(-sin(rot), -cos(rot))
	var lat := Vector2(dir.y, -dir.x)
	var ki := 1.5 if grande else 1.0
	ci.draw_colored_polygon(PackedVector2Array([p_io + dir * 7.0 * ki, p_io - dir * 4.0 * ki + lat * 4.0 * ki, p_io - dir * 4.0 * ki - lat * 4.0 * ki]), Color(1.0, 0.95, 0.6))
	if not grande:
		return
	# nomi delle sale, legenda delle strade e nota della variante
	var f := ThemeDB.fallback_font
	var visti := {}
	for s in _stanze:
		var nome := String(s.nome)
		if String(s.tipo) in ["corridoio", "cancello"] or visti.has(nome):
			continue
		visti[nome] = true
		var q: Rect2 = rr.call(s.r)
		var w := f.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var dove := Vector2(q.get_center().x - w * 0.5, q.position.y + 15.0)
		ci.draw_string_outline(f, dove, nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0, 0.85))
		ci.draw_string(f, dove, nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.96, 0.93, 0.85))
	var y := rett.position.y + 6.0
	var x := rett.end.x + 18.0
	ci.draw_string(f, Vector2(x, y + 14), String(definizione.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.85, 0.45))
	y += 30.0
	var V: Dictionary = composta.variante
	if String(V.get("nome", "")) != "":
		ci.draw_string(f, Vector2(x, y + 12), "Questa settimana: " + String(V.nome), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.6, 0.45))
		y += 20.0
		ci.draw_multiline_string(f, Vector2(x, y + 12), String(V.nota), HORIZONTAL_ALIGNMENT_LEFT, 330.0, 12, 4, Color(0.85, 0.85, 0.8))
		y += 56.0
	ci.draw_string(f, Vector2(x, y + 12), "Le strade", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.85, 0.45))
	y += 22.0
	var per_ala := {}
	for b in composta.packs:
		var n := 0.0
		for m in b.mobs:
			n += float(composta.forces.get(String(m), 0))
		var k := String(b.get("ala", "tronco"))
		per_ala[k] = float(per_ala.get(k, 0.0)) + n
	for ala in pianta.ali:
		var A: Dictionary = pianta.ali[ala]
		var c := Color.html(String(A.colore))
		var aperta := per_ala.has(ala)
		ci.draw_rect(Rect2(x, y + 2, 14, 14), c if aperta else c.darkened(0.7))
		ci.draw_string(f, Vector2(x + 22, y + 14), "%s%s" % [String(A.nome), ("  ·  forze %d%%" % int(per_ala[ala])) if aperta else "  ·  chiusa"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.93, 0.88) if aperta else Color(0.55, 0.55, 0.55))
		y += 19.0
		ci.draw_multiline_string(f, Vector2(x + 22, y + 11), String(A.nota), HORIZONTAL_ALIGNMENT_LEFT, 310.0, 11, 3, Color(0.7, 0.7, 0.68))
		y += 34.0
	ci.draw_rect(Rect2(x, y + 2, 14, 14), Color(0.42, 0.42, 0.46))
	ci.draw_string(f, Vector2(x + 22, y + 14), "Sale comuni  ·  forze %d%%" % int(per_ala.get("tronco", 0.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.93, 0.88))
	y += 22.0
	if per_ala.has("tesoro"):
		ci.draw_rect(Rect2(x, y + 2, 14, 14), Color(1.0, 0.82, 0.25))
		ci.draw_string(f, Vector2(x + 22, y + 14), "Tesoro (facoltativo)  ·  forze %d%%" % int(per_ala.tesoro), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.93, 0.88))
		y += 22.0
	y += 8.0
	var righe := ["◆ rosso: il boss      ● azzurro: Braciere del Ritorno", "✕ rosso: strada franata      ╳ chiaro: porta chiusa"]
	if forze >= 0.0:
		righe.push_front("Forze abbattute: %d%% di %d%%" % [int(forze), int(definizione.forcesNeeded)])
	for t in righe:
		ci.draw_string(f, Vector2(x, y + 12), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.8, 0.76))
		y += 18.0


## Il «Mantice Ardente» che Yan chiama a metà scontro: un mantice vero di cuoio e ferro con la brace viva sotto, al
## posto dell'obelisco rimpicciolito di prima (lo usa Entita per il mostro `mantice_forgia`).
static func mantice_ardente(scala: float) -> Personaggio:
	var p := Personaggio.new()
	var m := Mantice.new()
	m.costruisci(Edifici.mat(Color(0.36, 0.17, 0.08), 0.85), Edifici.mat(Color(0.09, 0.08, 0.08), 0.5, 0.6), Edifici.legno(Color(0.18, 0.11, 0.07)), 1.6 * scala)
	p.add_child(m)
	Edifici.scatola(Vector3(3.0, 0.12, 1.7) * scala, Vector3(0, 0.36, 0) * scala, Edifici.mat(Color(1.0, 0.45, 0.1), 0.5, 0.0, 4.0), p)
	p.altezza = 3.2 * scala + 0.4
	return p


## Mantice di cuoio e ferro che soffia (arredo della Galleria dei Mantici; la stessa forma, più piccola, è il
## «Mantice Ardente» che Yan chiama a metà scontro: vedi mostri.gd).
class Mantice:
	extends Node3D
	var _soffietto: Node3D
	var _t := 0.0
	var _brace: MeshInstance3D

	func costruisci(cuoio: Material, ferro: Material, legno: Material, k: float) -> void:
		# telaio, ugello verso -x, soffietto a pieghe fra due tavole a goccia
		Edifici.scatola(Vector3(3.0, 0.3, 1.8) * k, Vector3(0, 0.15, 0) * k, ferro, self)
		for lato in [-1.0, 1.0]:
			Edifici.scatola(Vector3(0.18, 1.5, 0.18) * k, Vector3(0.9, 0.9, lato * 0.8) * k, ferro, self)
		Edifici.scatola(Vector3(0.2, 0.2, 1.9) * k, Vector3(0.9, 1.65, 0) * k, ferro, self)
		var ug := Edifici.cilindro(0.12 * k, 0.3 * k, 1.3 * k, Vector3(-1.9, 0.7, 0) * k, ferro, self, 8)
		ug.rotation.z = -PI * 0.5
		_brace = Edifici.cilindro(0.11 * k, 0.11 * k, 0.05 * k, Vector3(-2.56, 0.7, 0) * k, Edifici.mat(Color(1.0, 0.5, 0.12), 0.5, 0.0, 4.0), self, 8)
		_brace.rotation.z = -PI * 0.5
		Edifici.scatola(Vector3(2.5, 0.12, 1.5) * k, Vector3(-0.1, 0.42, 0) * k, legno, self)
		_soffietto = Node3D.new()
		_soffietto.position = Vector3(-1.3, 0.48, 0) * k
		add_child(_soffietto)
		for i in range(5):
			var q := Edifici.scatola(Vector3(2.4 - i * 0.1, 0.2, 1.4 - i * 0.06) * k, Vector3(1.2, 0.1 + i * 0.2, 0) * k, cuoio, _soffietto)
			q.set_meta("i", i)
		Edifici.scatola(Vector3(2.5, 0.12, 1.5) * k, Vector3(1.2, 1.1, 0) * k, legno, _soffietto)
		Edifici.scatola(Vector3(1.5, 0.1, 0.1) * k, Vector3(2.9, 1.2, 0) * k, ferro, _soffietto)
		for lato in [-1.0, 1.0]:
			for i in range(4):
				Edifici.cilindro(0.05 * k, 0.05 * k, 0.03 * k, Vector3(0.3 + i * 0.6, 1.17, lato * 0.62) * k, ferro, _soffietto, 6)
		_t = randf() * 6.0

	func _process(dt: float) -> void:
		_t += dt
		var s := 0.62 + 0.38 * (0.5 + 0.5 * sin(_t * 2.2))
		_soffietto.scale.y = s
		_soffietto.rotation.z = (1.0 - s) * 0.12
		if _brace != null:
			(_brace as MeshInstance3D).transparency = clampf(s - 0.55, 0.0, 0.6)
