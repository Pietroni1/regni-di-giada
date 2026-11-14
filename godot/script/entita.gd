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
var sella := 0            # grado del destriero su cui è in sella (0 = a piedi)
var cavallo: Personaggio = null

const MANTELLI := [Color(0.54, 0.37, 0.22), Color(0.54, 0.37, 0.22), Color(0.29, 0.18, 0.11), Color(0.12, 0.1, 0.11)]


## Sale o scende da cavallo (grado 0 = a piedi).
func in_sella(grado: int) -> void:
	if grado == sella or corpo == null:
		return
	sella = grado
	if cavallo != null:
		cavallo.queue_free()
		cavallo = null
	corpo.in_sella = grado > 0
	corpo.position = Vector3.ZERO
	if grado > 0:
		var scala := 1.0 + 0.08 * (grado - 1)
		cavallo = Personaggio.animale("horse", MANTELLI[clampi(grado, 0, 3)], scala)
		if cavallo != null:
			add_child(cavallo)
			corpo.position = Vector3(0, 0.62 * scala, -0.1)
	else:
		corpo._stato = ""


static func da_info(i: Dictionary, mio := false) -> Entita:
	var e := Entita.new()
	e.id = int(i.id)
	e.info = i
	e.tipo = String(i.get("k", "p"))
	e.nome = String(i.get("n", ""))
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
			if d.get("dummy", false):
				corpo = Personaggio.fantoccio()
			elif Personaggio.SPECIE.has(modello):
				corpo = Personaggio.animale(modello, colore, scala)
			elif modello.begins_with("bandit") or modello == "general":
				var veste := {"veste": colore, "pantaloni": colore.darkened(0.3)}
				if modello == "general":
					veste["nubi"] = {"stoffa": Color(0.5, 0.1, 0.1)}
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
			corpo = Personaggio.umano("base_donna" if String(info.get("role", "")) == "erbe" else "base_uomo", veste, arma, 1)
			var ruolo := String(info.get("role", ""))
			corpo.metti_testa("long" if ruolo == "erbe" else ("short" if veste.has("elmo_bronzo") or veste.has("cappello_paglia") else "topknot"), Color(0.75, 0.75, 0.72) if ruolo in ["maestro", "erbe"] else Color(0.1, 0.08, 0.07))
		"d":
			corpo = Personaggio.new()
			var rar := int(info.get("r", 0))
			var c: Color = [Color(0.9, 0.9, 0.85), Color(0.4, 0.9, 0.4), Color(0.4, 0.6, 1.0), Color(0.8, 0.4, 1.0), Color(1.0, 0.7, 0.2)][clampi(rar, 0, 4)]
			var cassa := Edifici.scatola(Vector3(0.36, 0.36, 0.36), Vector3(0, 0.3, 0), Edifici.mat(c, 0.5, 0.0, 1.5), corpo)
			cassa.rotation = Vector3(0.6, 0.8, 0)
			# colonna di luce del colore della rarità, per vedere il bottino da lontano
			var raggio := Edifici.cilindro(0.03, 0.06, 3.2 + rar * 0.8, Vector3(0, 1.8 + rar * 0.4, 0), Edifici.mat(c, 0.5, 0.0, 3.0 + rar), corpo, 6)
			raggio.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			corpo.altezza = 0.8
	if corpo != null:
		add_child(corpo)
		if morto:
			corpo.muori()
	if tipo == "p":
		var grado := sella
		sella = -1
		in_sella(grado if grado > 0 else int(info.get("mt", 0)))


func _giocatore() -> Personaggio:
	var cls: Dictionary = Dati.CLASSES.get(String(info.get("cls", "lama")), {})
	var look: Dictionary = cls.get("look", {})
	var k: Dictionary = Dati.KINGDOMS.get(String(info.get("kd", "")), {})
	var regno := Dati.colore(k.get("hex", 0x888888))
	var wear := {"veste": Dati.colore(look.get("robe", 0x555555)), "pantaloni": Dati.colore(look.get("pants", 0x333333))}
	var corazza = info.get("b")
	if corazza != null and Dati.ITEMS.has(corazza):
		var grado := int(Dati.ITEMS[corazza].get("tier", 0))
		if grado >= 1:
			var capo: String = ["", "tunica", "lamellare", "giada", "nubi"][clampi(grado, 0, 4)]
			wear[capo] = {"stoffa": regno, "piastre": Dati.colore(look.get("trim", 0x999999))} if grado == 1 else {"stoffa": regno}
	if info.get("f") != null:
		wear[String(info.f)] = true
	if info.get("h") != null:
		wear[String(info.h)] = true
	var tipo_arma := "fists"
	var grado_arma := 1
	var arma = info.get("w")
	if arma != null and Dati.ITEMS.has(arma):
		tipo_arma = String(Dati.ITEMS[arma].get("wt", "sword"))
		grado_arma = int(Dati.ITEMS[arma].get("tier", 1))
	var lista: Array = Dati.indice.get("classi", {}).get(String(info.get("cls", "lama")), ["base_uomo", "base_donna"])
	var modello: String = lista[mini(1 if String(info.get("sx", "m")) == "f" else 0, lista.size() - 1)]
	var p := Personaggio.umano(modello, wear, tipo_arma, grado_arma)
	var donna := String(info.get("sx", "m")) == "f"
	var stile := String(look.get("hairStyle", "short"))
	if donna and stile in ["topknot", "bald"]:
		stile = "long"
	if info.get("h") != null:
		stile = "short" if stile != "bald" else "bald"      # sotto l'elmo niente crocchie o code
	p.metti_testa(stile, Dati.colore(look.get("hair", 0x1a1210)) if look.get("hair") != null else Color(0.1, 0.08, 0.07), Dati.colore(look.get("robe", 0x26293a)))
	p.metti_effetti(int(info.get("wu", 0)), int(info.get("wr", 0)), int(info.get("bu", 0)), int(info.get("br", 0)), io)
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
		if morto and not era_morto:
			corpo.muori()
		elif era_morto and not morto:
			corpo.rialza()


func guarda(verso: Entita) -> void:
	if verso != null:
		r = atan2(verso.x - x, verso.z - z)
		br = r


func testa() -> Vector3:
	return global_position + Vector3(0, (corpo.altezza if corpo != null else 2.0) * scale.y + (0.62 if sella > 0 else 0.0), 0)


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
	if corpo != null:
		corpo.muovi(velocita, dt)
	if cavallo != null:
		cavallo.muovi(velocita, dt)
