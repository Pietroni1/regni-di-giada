class_name Entita
extends Node3D
## Una creatura o un oggetto del mondo come lo descrive il server (messaggio `v`): giocatori, mostri, PNG, oggetti a terra.

var id := 0
var info: Dictionary = {}
var tipo := ""           # p giocatore, m mostro, n PNG, d oggetto a terra
var nome := ""
var x := 0.0
var z := 0.0
var r := 0.0
var bx := 0.0            # posizione comunicata dal server, verso cui si interpola
var bz := 0.0
var br := 0.0
var hp := 0.0
var mhp := 1.0
var lvl := 1
var morto := false
var postura := -1        # % di Postura rimasta (-1: non ne ha)
var squilibrato := false
var io := false          # è il personaggio di chi gioca
var corpo: Personaggio = null
var raggio := 0.5
var velocita := 0.0
var ostile_base := false
var sella := 0            # livello del destriero su cui è in sella (0 = a piedi)
var cavallo: Personaggio = null
var _aff: Afflizioni = null       # effetti visibili addosso (afflizioni.gd)
var colore_nome := Color(0.95, 0.9, 0.6)     # oggetti a terra: colore della rarità
var rarita := 0
var _quota_seduta := 0.55    # quota dei fianchi del cavaliere nella posa «sella»
var _fianchi_letti := false

const MANTELLI := [Color(0.54, 0.37, 0.22), Color(0.54, 0.37, 0.22), Color(0.29, 0.18, 0.11), Color(0.12, 0.1, 0.11)]
## il cavaliere rispetto al seggio della sella: un po' sopra (spessore della sella) e un filo indietro
const SEGGIO := Vector3(0.0, 0.11, 0.0)


## Sale o scende da cavallo (livello del destriero, 0 = a piedi). Il destriero è quello della classe (destrieri.gd):
## bardatura secondo il livello, effetti al livello massimo. Salendo in sella il cavallo si impenna.
func in_sella(livello: int) -> void:
	if livello == sella or corpo == null:
		return
	var era := sella
	sella = livello
	if cavallo != null:
		cavallo.queue_free()
		cavallo = null
	corpo.in_sella = livello > 0
	corpo.transform = Transform3D.IDENTITY
	if livello > 0:
		var k: Dictionary = Dati.KINGDOMS.get(String(info.get("kd", "")), {})
		cavallo = Destrieri.crea(String(info.get("cls", "lama")), livello, Dati.colore(k.get("hex", 0x888888)))
		if cavallo != null:
			add_child(cavallo)
			_quota_seduta = Destrieri.quota_seduta(corpo)
			corpo.metti_posa_sella(true)
			_siedi()
			if era == 0:
				(cavallo as Destrieri.Destriero).impenna()
		else:
			# senza destrieri.glb: il cavallo di prima
			var grado := Destrieri.passo_di(livello)
			var scala := 1.0 + 0.08 * (mini(grado, 3) - 1)
			cavallo = Personaggio.animale("horse", MANTELLI[clampi(grado - 1, 0, 3)], scala)
			if cavallo != null:
				add_child(cavallo)
				corpo.position = Vector3(0, 0.62 * scala, -0.1)
	else:
		corpo.metti_posa_sella(false)
		corpo._stato = ""


## Il cavaliere segue la sella: tutta la posizione (sobbalzi del galoppo) e buona parte dell'inclinazione (impennata).
## I fianchi del cavaliere (dove li mette la posa «sella») vanno sul seggio.
func _siedi() -> void:
	var d := cavallo as Destrieri.Destriero
	if d == null or corpo == null:
		return
	var t := d.posto()
	var inclina := Basis.IDENTITY.slerp(t.basis.orthonormalized(), 0.75)
	var fianchi := Vector3(0, _quota_seduta, 0)
	var sk := corpo.scheletro
	if sk != null and sk.is_inside_tree():
		var i := sk.find_bone("hips")
		if i >= 0:
			var h := corpo.global_transform.affine_inverse() * (sk.global_transform * sk.get_bone_global_pose(i).origin)
			fianchi = fianchi.lerp(Vector3(0, h.y, h.z), 0.5) if _fianchi_letti else Vector3(0, h.y, h.z)
			_fianchi_letti = true
			_quota_seduta = fianchi.y
	corpo.transform = Transform3D(inclina, t.origin + inclina * (SEGGIO - fianchi))


## Un fotogramma di animazione di cavaliere e cavallo (chiamato da _process; la scuderia lo chiama da sé).
func passo_sella(dt: float) -> void:
	if corpo != null:
		corpo.muovi(velocita, dt)
	if cavallo != null:
		cavallo.muovi(velocita, dt)
		_siedi()


static func da_info(i: Dictionary, mio := false) -> Entita:
	var e := Entita.new()
	e.id = int(i.id)
	e.info = i
	e.tipo = String(i.get("k", "p"))
	e.nome = str(i.get("n", ""))
	e.io = mio
	e.x = float(i.x)
	e.z = float(i.z)
	e.r = float(i.get("r", 0.0))
	e.bx = e.x
	e.bz = e.z
	e.br = e.r
	e.hp = float(i.get("hp", 1))
	e.mhp = maxf(1.0, float(i.get("mhp", 1)))
	e.lvl = int(i.get("lvl", 1))
	e.morto = int(i.get("dead", 0)) == 1
	if i.has("po"):
		e.postura = int(i.po)
		e.squilibrato = float(i.get("sq", 0)) > 0.0
	e._costruisci()
	e._posa()
	return e


func _costruisci() -> void:
	if corpo != null:
		corpo.queue_free()
		corpo = null
	match tipo:
		"p":
			corpo = _giocatore()
		"m":
			var d: Dictionary = Dati.MOBS.get(String(info.get("ty", "")), {})
			var scala := float(d.get("scale", 1.0))
			raggio = 0.6 * scala
			var colore := Dati.colore(d.get("color", 0x777777))
			var modello := String(d.get("model", ""))
			# figure dei mostri (mostri.gd): bestie, spiriti, banditi, statue, capi; sotto i ripieghi di prima
			if not d.get("dummy", false) and modello != "obelisk":
				corpo = Mostri.crea(String(info.get("ty", "")), d)
			if corpo != null:
				pass
			elif d.get("dummy", false):
				corpo = Personaggio.fantoccio()
			elif Personaggio.SPECIE.has(modello):
				corpo = Personaggio.animale(modello, colore, scala)
			elif modello.begins_with("bandit") or modello == "general":
				var veste := {"veste": colore, "pantaloni": colore.darkened(0.3)}
				if modello == "general":
					veste["nubi"] = {"stoffa": Color(0.5, 0.1, 0.1)}
					veste["elmo_drago"] = true
				if ha_completi("base_uomo"):
					# banditi: completo dell'assassino nei colori del mostro; generale: corazza leggendaria della Lama
					var tinte := {"stoffa": colore, "stoffa2": colore.darkened(0.3), "fascia": colore.darkened(0.5), "regno": Color(0.45, 0.1, 0.08)}
					veste = completo("lama", 4, {"stoffa": Color(0.3, 0.08, 0.06), "stoffa2": Color(0.12, 0.08, 0.07), "fascia": Color(0.7, 0.55, 0.3), "regno": Color(0.5, 0.1, 0.1)}) if modello == "general" else completo("ombra", 1 if modello == "bandit_archer" else 0, tinte)
					if modello == "general":
						veste["elmo_drago"] = true
				corpo = Personaggio.umano("base_uomo", veste, "bow" if modello == "bandit_archer" else "sword", 2, Color(0.62, 0.48, 0.38))
				corpo.metti_testa("hood" if modello != "general" else "short", Color(0.08, 0.07, 0.06), colore.darkened(0.2))
				corpo.scale = Vector3.ONE * scala
			elif modello == "terracotta" or modello == "custode":
				# guerrieri di terracotta: il corpo base tutto color argilla, con corazza ed elmo
				var argilla := colore.lerp(Color(0.62, 0.36, 0.24), 0.6)
				var capi := {"veste": argilla.darkened(0.15), "pantaloni": argilla.darkened(0.25), "lamellare": {"stoffa": argilla.darkened(0.3), "piastre": argilla, "bordo": argilla.darkened(0.2)}, "elmo_bronzo": true, "stivali_cuoio": true}
				if modello == "custode":
					capi = {"veste": Color(0.12, 0.1, 0.16), "pantaloni": Color(0.08, 0.07, 0.1), "nubi": {"stoffa": Color(0.35, 0.1, 0.45)}, "elmo_drago": true, "stivali_nube": true}
				if ha_completi("base_uomo"):
					if modello == "custode":
						capi = completo("lama", 4, {"stoffa": Color(0.12, 0.1, 0.16), "stoffa2": Color(0.08, 0.07, 0.1), "fascia": Color(0.5, 0.3, 0.6), "regno": Color(0.35, 0.1, 0.45)})
						capi["elmo_drago"] = true
						capi["stivali_nube"] = true
					else:
						# tutto d'argilla, anche le piastre
						capi = completo("lama", 2, {"stoffa": argilla.darkened(0.15), "stoffa2": argilla.darkened(0.25), "fascia": argilla.darkened(0.1),
								"regno": argilla.darkened(0.3), "lamelle": argilla, "piastre": argilla.darkened(0.1), "bordo": argilla.darkened(0.2), "cuoio": argilla.darkened(0.35)})
						capi["elmo_bronzo"] = true
						capi["stivali_cuoio"] = true
				corpo = Personaggio.umano("base_uomo", capi, "sword", 4 if modello == "custode" else 2, argilla if modello == "terracotta" else Color(0.3, 0.28, 0.36))
				corpo.scale = Vector3.ONE * scala
			elif modello == "lantern":
				corpo = Personaggio.lanterna_spettrale(colore, scala)
			elif modello == "shade":
				corpo = Personaggio.ombra(colore, scala)
			elif modello == "obelisk":
				corpo = Personaggio.obelisco(colore, scala)
			else:
				corpo = Personaggio.sagoma(colore, scala, 1.8)
		"n":
			var k: Dictionary = Dati.KINGDOMS.get(String(info.get("kd", "")), {})
			var regno := Dati.colore(k.get("hex", 0x888888))
			var veste := {"veste": regno.darkened(0.35), "pantaloni": Color(0.18, 0.15, 0.13), "sandali": true}
			var arma := "fists"
			if String(info.get("role", "")) == "guardia":
				veste["lamellare"] = {"stoffa": regno}
				veste["elmo_bronzo"] = true
				arma = "sword"
			elif String(info.get("role", "")) in ["maestro", "custode"]:
				veste["cappello_paglia"] = true
				arma = "staff"
			elif String(info.get("role", "")) == "guida":
				# viandante delle mappe lontane: cappello di paglia, bastone, veste color terra
				veste = {"veste": Color(0.45, 0.36, 0.22), "pantaloni": Color(0.22, 0.18, 0.13), "cappello_paglia": true, "sandali": true}
				arma = "staff"
			elif String(info.get("role", "")) == "araldo":
				# araldo dell'arena: armatura laccata vermiglia
				veste = {"veste": Color(0.42, 0.08, 0.06), "pantaloni": Color(0.12, 0.08, 0.07), "lamellare": {"stoffa": Color(0.6, 0.1, 0.08), "piastre": Color(0.75, 0.6, 0.3)}, "elmo_bronzo": true, "stivali_cuoio": true}
				arma = "sword"
			var ruolo := String(info.get("role", ""))
			if ha_completi("base_uomo"):
				# PNG con i completi delle classi: abitanti con tunica e pantaloni, guardie e araldo in corazza,
				# maestri, guide ed erboriste con la veste lunga
				var tinte := {"stoffa": regno.darkened(0.35), "stoffa2": Color(0.18, 0.15, 0.13), "fascia": regno.darkened(0.6), "regno": regno}
				var extra := {}
				for c in ["sandali", "cappello_paglia", "elmo_bronzo", "stivali_cuoio"]:
					if veste.has(c):
						extra[c] = true
				match ruolo:
					"guardia": veste = completo("lama", 2, tinte)
					"araldo": veste = completo("lama", 3, {"stoffa": Color(0.42, 0.08, 0.06), "stoffa2": Color(0.12, 0.08, 0.07), "fascia": Color(0.75, 0.6, 0.3), "regno": Color(0.6, 0.1, 0.08), "lamelle": Color(0.55, 0.08, 0.05)})
					"maestro", "custode": veste = completo("mistico", 1, {"stoffa": Color(0.82, 0.78, 0.68), "stoffa2": Color(0.6, 0.56, 0.48), "fascia": regno.darkened(0.3), "regno": regno})
					"guida": veste = completo("mistico", 0, {"stoffa": Color(0.45, 0.36, 0.22), "stoffa2": Color(0.22, 0.18, 0.13), "fascia": Color(0.3, 0.22, 0.12), "regno": Color(0.5, 0.4, 0.2)})
					"erbe": veste = completo("mistico", 0, {"stoffa": Color(0.45, 0.55, 0.35), "stoffa2": Color(0.3, 0.28, 0.22), "fascia": Color(0.6, 0.5, 0.3), "regno": regno})
					_: veste = completo("lama", 0, tinte)
				veste.merge(extra)
			corpo = Personaggio.umano("base_donna" if ruolo == "erbe" else "base_uomo", veste, arma, 1)
			corpo.metti_testa("long" if ruolo == "erbe" else ("short" if veste.has("elmo_bronzo") or veste.has("cappello_paglia") else "topknot"), Color(0.75, 0.75, 0.72) if ruolo in ["maestro", "erbe"] else Color(0.1, 0.08, 0.07))
		"d":
			# oggetto caduto: modellino riconoscibile, alone e colonna di luce della rarità (oggetto_terra.gd)
			corpo = Personaggio.new()
			var og := OggettoTerra.crea(info)
			corpo.add_child(og)
			nome = OggettoTerra.nome_di(info)
			colore_nome = og.colore
			rarita = og.rar
			corpo.altezza = 0.75
	if corpo != null:
		add_child(corpo)
		if corpo.has_method("stato"):
			corpo.call("stato", hp / mhp)
		if morto:
			corpo.muori()
	if tipo == "p":
		# in sella: livello del destriero (`ml`); i server vecchi mandano solo il grado `mt` (1-3)
		var liv := sella
		sella = -1
		if liv <= 0:
			liv = int(info.get("ml", [0, 1, 10, 20][clampi(int(info.get("mt", 0)), 0, 3)]))
		in_sella(liv)


## Completo di una classe (tools/blender/completi.py): vesti di sotto «<classe>_base» + sopravveste o armatura del grado
## (0 = senza armatura, 1-4 = grado dell'armatura). colori: tinte delle parti stoffa, stoffa2, fascia, regno
## (e, per chi ne ha bisogno, anche piastre, lamelle, bordo, cuoio: altrimenti restano quelle del modello).
static func completo(classe: String, grado: int, colori: Dictionary) -> Dictionary:
	return {classe + "_base": colori, "%s_%d" % [classe, clampi(grado, 0, 4)]: colori}


## Il modello ha i completi per classe? (indice.json, capi del modello)
static func ha_completi(modello: String, classe := "lama") -> bool:
	return (Dati.indice.get("modelli", {}).get(modello, {}).get("capi", []) as Array).has(classe + "_base")


func _giocatore() -> Personaggio:
	var classe := String(info.get("cls", "lama"))
	var cls: Dictionary = Dati.CLASSES.get(classe, {})
	var look: Dictionary = cls.get("look", {})
	var k: Dictionary = Dati.KINGDOMS.get(String(info.get("kd", "")), {})
	var regno := Dati.colore(k.get("hex", 0x888888))
	var grado := 0
	var corazza = info.get("b")
	if corazza != null and Dati.ITEMS.has(corazza):
		grado = clampi(int(Dati.ITEMS[corazza].get("tier", 0)), 0, 4)
	var lista: Array = Dati.indice.get("classi", {}).get(classe, ["base_uomo", "base_donna"])
	var modello: String = lista[mini(1 if String(info.get("sx", "m")) == "f" else 0, lista.size() - 1)]
	var wear := {}
	if ha_completi(modello, classe):
		# completo della classe: colori del «look» della classe, accento nel colore del regno
		wear = completo(classe, grado, {"stoffa": Dati.colore(look.get("robe", 0x555555)), "stoffa2": Dati.colore(look.get("pants", 0x333333)),
				"fascia": Dati.colore(look.get("trim", 0x8a7a5a)), "regno": regno})
	else:
		# modelli senza completi: vesti ricavate dal corpo e armature uguali per tutte le classi
		wear = {"veste": Dati.colore(look.get("robe", 0x555555)), "pantaloni": Dati.colore(look.get("pants", 0x333333))}
		wear["bracciali"] = Dati.colore(look.get("trim", 0x8a7a5a)).darkened(0.35)
		wear["gambali"] = Dati.colore(look.get("robe", 0x555555)).darkened(0.25)
		if grado >= 1:
			var capo: String = ["", "tunica", "lamellare", "giada", "nubi"][grado]
			wear[capo] = {"stoffa": regno, "piastre": Dati.colore(look.get("trim", 0x999999))} if grado == 1 else {"stoffa": regno}
	# copricapi e calzari dei gradi intermedi usano il modello di un pezzo dei quattro gradi (campo `aspetto`)
	if info.get("f") != null:
		wear[String(Dati.ITEMS.get(String(info.f), {}).get("aspetto", info.f))] = true
	else:
		wear["sandali"] = true          # senza calzari equipaggiati: sandali, non piedi nudi
	if info.get("h") != null:
		# copricapo della classe (fasce, frontali, diademi: tools/blender/completi.py) secondo il grado del pezzo;
		# sui modelli che non li hanno resta l'elmo uguale per tutti
		var voce_h: Dictionary = Dati.ITEMS.get(String(info.h), {})
		var capo_h := "%s_e%d" % [classe, clampi(int(voce_h.get("tier", 1)), 1, 4)]
		if (Dati.indice.get("modelli", {}).get(modello, {}).get("capi", []) as Array).has(capo_h):
			wear[capo_h] = {"stoffa": Dati.colore(look.get("robe", 0x555555)), "stoffa2": Dati.colore(look.get("pants", 0x333333)),
					"fascia": Dati.colore(look.get("trim", 0x8a7a5a)), "regno": regno}
		else:
			wear[String(voce_h.get("aspetto", info.h))] = true
	var tipo_arma := "fists"
	var grado_arma := 1
	var arma = info.get("w")
	if arma != null and Dati.ITEMS.has(arma):
		tipo_arma = String(Dati.ITEMS[arma].get("wt", "sword"))
		grado_arma = int(Dati.ITEMS[arma].get("tier", 1))
	var p := Personaggio.umano(modello, wear, tipo_arma, grado_arma, Color(0.8, 0.56, 0.4), Dati.colore(look.get("trim", 0xb8a070)))
	var donna := String(info.get("sx", "m")) == "f"
	var stile := String(look.get("hairStyle", "short"))
	if donna and stile in ["topknot", "bald"]:
		stile = "long"
	if info.get("h") != null:
		stile = "short" if stile != "bald" else "bald"      # sotto l'elmo niente crocchie o code
	p.metti_testa(stile, Dati.colore(look.get("hair", 0x1a1210)) if look.get("hair") != null else Color(0.1, 0.08, 0.07), Dati.colore(look.get("robe", 0x26293a)))
	p.metti_effetti(int(info.get("wu", 0)), int(info.get("wr", 0)), int(info.get("bu", 0)), int(info.get("br", 0)), io)
	if info.get("au") != null:
		p.metti_aura(String(info.au))
	return p


## Aggiorna l'aspetto quando cambia l'equipaggiamento.
func cambia_aspetto(nuovo: Dictionary) -> void:
	var diverso := false
	for c in ["w", "b", "h", "f", "wu", "wr", "bu", "br"]:
		if info.get(c) != nuovo.get(c):
			diverso = true
		info[c] = nuovo.get(c)
	if diverso:
		_costruisci()


## Aggiornamento compatto dal server: [id, x, z, r, hp, mhp, lvl, morto, postura%, squilibrato]
func aggiorna(u: Array) -> void:
	bx = float(u[1])
	bz = float(u[2])
	br = float(u[3])
	hp = float(u[4])
	mhp = maxf(1.0, float(u[5]))
	lvl = int(u[6])
	var era_morto := morto
	morto = int(u[7]) == 1
	if u.size() > 8:
		postura = int(u[8])
		squilibrato = int(u[9]) == 1
	if corpo != null:
		if corpo.has_method("stato"):
			corpo.call("stato", hp / mhp)
		if morto and not era_morto:
			corpo.muori()
			if _aff != null:
				_aff.togli_tutto()
		elif era_morto and not morto:
			corpo.rialza()


## Un effetto messo addosso (veleno, ferita, stordimento, rallentamento, marchio): si vede sul corpo finché dura.
func afflizione(nome: String, ms: float) -> void:
	if morto or nome.is_empty():
		return
	if _aff == null:
		_aff = Afflizioni.new()
		_aff.altezza = corpo.altezza if corpo != null else 2.0
		add_child(_aff)
	_aff.metti(nome, ms)


## Marchi dell'Ombra addosso (0 = tolti).
func marchi(n: int, ms: float) -> void:
	if morto and n > 0:
		return
	if _aff == null:
		if n <= 0:
			return
		_aff = Afflizioni.new()
		_aff.altezza = corpo.altezza if corpo != null else 2.0
		add_child(_aff)
	_aff.marchi(n, ms)


func guarda(verso: Entita) -> void:
	if verso != null:
		r = atan2(verso.x - x, verso.z - z)
		br = r


func testa() -> Vector3:
	return global_position + Vector3(0, ((corpo.altezza if corpo != null else 2.0) + (corpo.position.y if corpo != null and sella > 0 else 0.0)) * scale.y, 0)


func petto() -> Vector3:
	return global_position + Vector3(0, (corpo.altezza if corpo != null else 2.0) * 0.55, 0)


func _posa() -> void:
	position = Vector3(x, Dati.altezza(x, z), z)
	rotation.y = r


func _process(dt: float) -> void:
	if not io:
		var px := x
		var pz := z
		var k := minf(1.0, dt * 10.0)
		x = lerpf(x, bx, k)
		z = lerpf(z, bz, k)
		r = lerp_angle(r, br, minf(1.0, dt * 12.0))
		var v := Vector2(x - px, z - pz).length() / maxf(dt, 1e-4)
		velocita = lerpf(velocita, v, minf(1.0, dt * 8.0))
	_posa()
	passo_sella(dt)
