class_name Finestre
extends Control
## Finestre di gioco: Inventario (I), Personaggio (C), Abilità (K), negozio, fabbro e dialoghi dei PNG.
## Ogni azione è un messaggio al server (`use`, `mv`, `stat`, `skup`, `via`, `qb`, `buy`, `sell`, `up`): qui si mostra soltanto.

const NOMI_RUOLO := {"accumulo": "Accumulo", "medio": "Scarico medio", "potente": "Scarico potente"}

var gioco
var inventario: PanelContainer
var personaggio: PanelContainer
var abilita: PanelContainer
var negozio: PanelContainer
var fabbro: PanelContainer
var dialogo: PanelContainer
var caselle: Array = []          # caselle dell'inventario
var caselle_eq: Dictionary = {}  # spazio → casella dell'equipaggiamento
var tael: Label
var scelta := -1                 # casella dell'inventario selezionata
var tecnica_scelta := ""
var negozio_png := 0
var fabbro_png := 0
var _corpo_pg: VBoxContainer
var _corpo_ab: VBoxContainer
var _corpo_neg: VBoxContainer
var _testo_dialogo: Label
var _titolo_dialogo: Label
var _testo_fabbro: Label
var _riga_tasti_inv: HBoxContainer
var _firma_ab := ""
var _firma_pg := ""
var prove: PanelContainer
var scuderia: PanelContainer
var prove_png := 0
var scuderia_png := 0
var _testo_prove: Label
var _testo_scuderia: Label
var _compra_cavallo: Button
var _addestra: Button
var menu: PanelContainer
var impostazioni: PanelContainer
var aiuto: PanelContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crea_inventario()
	_crea_personaggio()
	_crea_abilita()
	_crea_negozio()
	_crea_fabbro()
	_crea_dialogo()
	Rete.su("shop", _su_negozio)
	Rete.su("smith", func(m: Dictionary) -> void:
		fabbro_png = int(m.npc)
		fabbro.visible = true
		inventario.visible = true
		_testo_fabbro.text = "Scegli un oggetto nell'inventario, poi premi Potenzia.")
	Rete.su("smith_res", _su_fabbro)
	Rete.su("dialog", func(m: Dictionary) -> void:
		_titolo_dialogo.text = String(m.get("n", ""))
		_testo_dialogo.text = String(m.get("m", ""))
		dialogo.visible = true)
	_crea_prove()
	_crea_scuderia()
	_crea_menu()
	_crea_impostazioni()
	_crea_aiuto()
	Rete.su("stable", func(m: Dictionary) -> void:
		scuderia_png = int(m.npc)
		scuderia.visible = true
		aggiorna())
	Rete.su("trial", _su_prove)
	Rete.su("applied", func(m: Dictionary) -> void: gioco.hud.avvisa(String(m.get("m", ""))))


# ------------------------------------------------------------------ struttura comune
func _finestra(titolo: String, pos: Vector2, larga: float) -> Array:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Hud.stile(Color(0.07, 0.06, 0.06, 0.94), Hud.ORO.darkened(0.35), 8, 2))
	p.position = pos
	p.custom_minimum_size = Vector2(larga, 0)
	p.visible = false
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var testa := HBoxContainer.new()
	v.add_child(testa)
	var t := Label.new()
	t.text = titolo
	t.add_theme_color_override("font_color", Hud.ORO)
	t.add_theme_font_size_override("font_size", 18)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	t.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion and ev.button_mask & MOUSE_BUTTON_MASK_LEFT:
			p.position += ev.relative)
	testa.add_child(t)
	var x := Button.new()
	x.text = "✕"
	x.flat = true
	x.pressed.connect(func() -> void: p.visible = false)
	testa.add_child(x)
	return [p, v]


func _etichetta(genitore: Control, testo: String, colore := Color(0.9, 0.88, 0.82), misura := 14) -> Label:
	var l := Label.new()
	l.text = testo
	l.add_theme_color_override("font_color", colore)
	l.add_theme_font_size_override("font_size", misura)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	genitore.add_child(l)
	return l


func _bottone(genitore: Control, testo: String, azione: Callable) -> Button:
	var b := Button.new()
	b.text = testo
	b.pressed.connect(azione)
	genitore.add_child(b)
	return b


func apri_chiudi(quale: String) -> void:
	var f: PanelContainer = {"inventario": inventario, "personaggio": personaggio, "abilita": abilita, "menu": menu, "impostazioni": impostazioni, "aiuto": aiuto}[quale]
	f.visible = not f.visible
	Suoni.suona("clic", -12.0)
	aggiorna()


## Chiude tutto; restituisce true se c'era qualcosa di aperto.
func chiudi_tutto() -> bool:
	var aperta := false
	for f in [inventario, personaggio, abilita, negozio, fabbro, dialogo, prove, scuderia, menu, impostazioni, aiuto]:
		if f.visible:
			aperta = true
		f.visible = false
	negozio_png = 0
	fabbro_png = 0
	return aperta


# ------------------------------------------------------------------ descrizioni
func testo_oggetto(s) -> String:
	if not (s is Dictionary) or not Dati.ITEMS.has(s.id):
		return ""
	var it: Dictionary = Dati.ITEMS[s.id]
	var rar: Dictionary = Dati.gioco.RARITIES[clampi(int(s.get("r", 0)), 0, 4)]
	var righe: Array = []
	var nome := String(it.name)
	if int(s.get("up", 0)) > 0:
		nome += " +%d" % int(s.up)
	righe.append(nome)
	if it.has("atk") or it.has("def"):
		righe.append(String(rar.name))
	if it.has("atk"):
		righe.append("Attacco %d" % int(it.atk))
	if it.has("def"):
		righe.append("Difesa %d" % int(it.def))
	if it.has("lvl"):
		righe.append("Livello richiesto %d" % int(it.lvl))
	for b in s.get("b", []):
		var stat := ""
		var val := 0.0
		if b is Array and b.size() >= 2:
			stat = String(b[0])
			val = float(b[1])
		elif b is Dictionary:
			stat = String(b.get("s", b.get("stat", "")))
			val = float(b.get("v", 0))
		var bs: Dictionary = Dati.gioco.BONUS_STATS.get(stat, {})
		if not bs.is_empty():
			righe.append("%s +%s" % [bs.name, str(int(round(val))) if bs.get("flat", false) else (str(val).replace(".", ",") + "%")])
	if it.has("desc"):
		righe.append(String(it.desc))
	if it.has("price"):
		righe.append("Valore %d tael" % int(it.price))
	return "\n".join(righe)


func testo_tecnica(sid: String, lvl: int) -> String:
	var sk: Dictionary = Dati.SKILLS[sid]
	var righe: Array = [String(sk.name) + ("  (livello %d — %s)" % [lvl, Effetti.nome_grado(lvl)] if lvl > 0 else "")]
	if NOMI_RUOLO.has(String(sk.get("ruolo", ""))):
		righe.append(NOMI_RUOLO[String(sk.ruolo)])
	righe.append(String(sk.get("desc", "")))
	var R: Dictionary = Dati.RESOURCES.get(String(gioco.io.get("rt", "")), {})
	if sk.has("cost"):
		righe.append("Costo: %d%s %s" % [int(sk.cost), "%" if String(gioco.io.get("rt", "")) == "mana" else "", R.get("name", "")])
	if sk.has("gen"):
		righe.append("Genera: %d %s" % [int(sk.gen), R.get("name", "")])
	if float(sk.get("cd", 0)) > 0.0:
		righe.append("Ricarica: %s s" % str(sk.cd))
	if float(sk.get("cast", 0)) > 0.0:
		righe.append("Tempo di lancio: %s s" % str(sk.cast))
	if lvl > 0 and lvl < 20:
		var prossimo := 5 if lvl < 5 else (10 if lvl < 10 else (15 if lvl < 15 else 20))
		righe.append("Al livello %d diventa %s: l'effetto si arricchisce." % [prossimo, Effetti.nome_grado(prossimo)])
	if sk.has("mult"):
		righe.append("Danni: %d%% dell'attacco" % int(round(Dati.valore(sk.mult, maxi(lvl, 1)) * 100.0)))
	return "\n".join(righe)


# ------------------------------------------------------------------ inventario
func _crea_inventario() -> void:
	var f := _finestra("Inventario  [I]", Vector2(760, 430), 0)
	inventario = f[0]
	var v: VBoxContainer = f[1]
	var griglia := GridContainer.new()
	griglia.columns = 9
	griglia.add_theme_constant_override("h_separation", 4)
	griglia.add_theme_constant_override("v_separation", 4)
	v.add_child(griglia)
	for i in range(int(Dati.costanti.INV_SIZE)):
		var c := Casella.new()
		c.indice = i
		c.finestre = self
		c.sinistro.connect(_clic_inventario)
		c.destro.connect(_destro_inventario)
		griglia.add_child(c)
		caselle.append(c)
	tael = _etichetta(v, "", Color(1.0, 0.85, 0.4))
	_etichetta(v, "Trascina per spostare, indossare o mettere nella barra. Clic destro: usa, indossa, fondi 3 gemme uguali, o vendi (col negozio aperto). Gemme e pergamene: trascinale su un'arma o un'armatura.", Color(0.65, 0.63, 0.58), 11)
	_riga_tasti_inv = HBoxContainer.new()
	v.add_child(_riga_tasti_inv)
	_etichetta(_riga_tasti_inv, "Nella barra:", Color(0.7, 0.68, 0.62), 12).autowrap_mode = TextServer.AUTOWRAP_OFF
	for i in range(10):
		var n := i
		var b := _bottone(_riga_tasti_inv, str((i + 1) % 10), func() -> void:
			var s = _inv()[scelta] if scelta >= 0 else null
			if s is Dictionary:
				Rete.manda({"t": "qb", "i": n, "v": {"k": "i", "id": s.id}}))
		b.custom_minimum_size = Vector2(26, 0)
	_bottone(_riga_tasti_inv, "Getta", func() -> void:
		if scelta >= 0:
			Rete.manda({"t": "drop", "i": scelta})
			scelta = -1)


func _inv() -> Array:
	return gioco.inv.get("inv", [])


func _tipo(s) -> String:
	if s is Dictionary and Dati.ITEMS.has(s.id):
		return String(Dati.ITEMS[s.id].get("type", ""))
	return ""


func _e_equip(s) -> bool:
	return _tipo(s) in ["weapon", "body", "head", "feet"]


## Rilascio di un oggetto trascinato su una casella (dell'inventario o dell'equipaggiamento).
func rilascia(d: Dictionary, su: Casella) -> void:
	var inv := _inv()
	var da_eq := String(d.get("eq", ""))
	var portato = inv[int(d.i)] if da_eq.is_empty() and int(d.i) < inv.size() else null
	if not da_eq.is_empty():
		if su.spazio.is_empty():
			Rete.manda({"t": "mv", "a": {"k": "e", "i": da_eq}, "b": {"k": "i", "i": su.indice}})
	elif not su.spazio.is_empty():
		if _tipo(portato) in ["gem", "mod"]:
			Rete.manda({"t": "apply", "i": int(d.i), "tgt": {"k": "e", "i": su.spazio}})
		else:
			Rete.manda({"t": "mv", "a": {"k": "i", "i": int(d.i)}, "b": {"k": "e", "i": su.spazio}})
	elif int(d.i) != su.indice:
		var sotto = inv[su.indice] if su.indice < inv.size() else null
		if _tipo(portato) in ["gem", "mod"] and _e_equip(sotto):
			Rete.manda({"t": "apply", "i": int(d.i), "tgt": {"k": "i", "i": su.indice}})
		else:
			Rete.manda({"t": "mv", "a": {"k": "i", "i": int(d.i)}, "b": {"k": "i", "i": su.indice}})
	scelta = -1
	Suoni.suona("clic", -10.0)


func _clic_inventario(i: int) -> void:
	var inv := _inv()
	if scelta >= 0 and scelta != i:
		if _tipo(inv[scelta] if scelta < inv.size() else null) in ["gem", "mod"] and _e_equip(inv[i] if i < inv.size() else null):
			Rete.manda({"t": "apply", "i": scelta, "tgt": {"k": "i", "i": i}})
		else:
			Rete.manda({"t": "mv", "a": {"k": "i", "i": scelta}, "b": {"k": "i", "i": i}})
		scelta = -1
	elif i < inv.size() and inv[i] != null:
		scelta = i if scelta != i else -1
	aggiorna()


func _destro_inventario(i: int) -> void:
	var inv := _inv()
	if i >= inv.size() or inv[i] == null:
		return
	if negozio.visible and negozio_png != 0:
		Rete.manda({"t": "sell", "npc": negozio_png, "i": i})
		Suoni.suona("moneta", -8.0)
	elif _tipo(inv[i]) == "gem":
		Rete.manda({"t": "combine", "i": i})
	else:
		Rete.manda({"t": "use", "i": i})
	scelta = -1


# ------------------------------------------------------------------ personaggio
func _crea_personaggio() -> void:
	var f := _finestra("Personaggio  [C]", Vector2(350, 110), 330)
	personaggio = f[0]
	var v: VBoxContainer = f[1]
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 8)
	v.add_child(riga)
	for spazio in Dati.gioco.EQUIP_SLOTS:
		var col := VBoxContainer.new()
		riga.add_child(col)
		var c := Casella.new()
		c.finestre = self
		c.spazio = String(spazio)
		var sp := String(spazio)
		c.sinistro.connect(func(_i: int) -> void: _togli(sp))
		c.destro.connect(func(_i: int) -> void: _togli(sp))
		col.add_child(c)
		col.custom_minimum_size = Vector2(70, 0)
		_etichetta(col, String(Dati.gioco.EQUIP_NAMES[spazio]), Color(0.65, 0.63, 0.58), 11).autowrap_mode = TextServer.AUTOWRAP_OFF
		caselle_eq[sp] = c
	_corpo_pg = VBoxContainer.new()
	v.add_child(_corpo_pg)


func _togli(spazio: String) -> void:
	var inv := _inv()
	for i in range(inv.size()):
		if inv[i] == null:
			Rete.manda({"t": "mv", "a": {"k": "e", "i": spazio}, "b": {"k": "i", "i": i}})
			return
	gioco.hud.avvisa("Inventario pieno", true)


func _riempi_personaggio() -> void:
	var io: Dictionary = gioco.io
	var firma := JSON.stringify([io.get("st"), io.get("sp"), io.get("atk"), io.get("matk"), io.get("def"), io.get("crit"), io.get("lvl"), io.get("exp"), io.get("mhp"), io.get("haste")])
	if firma == _firma_pg:
		return
	_firma_pg = firma
	for c in _corpo_pg.get_children():
		c.queue_free()
	var cls: Dictionary = Dati.CLASSES.get(gioco.classe, {})
	_etichetta(_corpo_pg, "%s  ·  %s  ·  livello %d" % [gioco.me.nome, cls.get("name", ""), int(io.get("lvl", 1))], Hud.ORO)
	_etichetta(_corpo_pg, "Esperienza %d / %d" % [int(io.get("exp", 0)), int(io.get("need", 1))], Color(0.75, 0.6, 1.0), 12)
	var liberi := int(io.get("sp", 0))
	_etichetta(_corpo_pg, "Punti da assegnare: %d" % liberi, Color(1.0, 0.85, 0.4) if liberi > 0 else Color(0.6, 0.6, 0.6), 13)
	var st: Dictionary = io.get("st", {})
	for s in ["vit", "str", "dex", "int"]:
		var riga := HBoxContainer.new()
		_corpo_pg.add_child(riga)
		var l := _etichetta(riga, "%s  %d" % [Dati.gioco.STAT_NAMES[s], int(st.get(s, 0))])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.tooltip_text = String(Dati.gioco.STAT_DESC[s])
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		if liberi > 0:
			var nome := String(s)
			_bottone(riga, "+", func() -> void: Rete.manda({"t": "stat", "s": nome})).custom_minimum_size = Vector2(30, 0)
	_corpo_pg.add_child(HSeparator.new())
	var righe := [
		["Vita", "%d" % int(io.get("mhp", 0))], ["Attacco", "%d" % int(io.get("atk", 0))], ["Attacco magico", "%d" % int(io.get("matk", 0))],
		["Difesa", "%d" % int(io.get("def", 0))], ["Critico", "%s%%" % str(io.get("crit", 0))], ["Evasione", "%s%%" % str(io.get("ev", 0))],
		["Rapidità", "%s%%" % str(io.get("haste", 0))], ["Danni", "+%s%%" % str(io.get("dmgPct", 0))], ["Velocità", "%s m/s" % str(io.get("spd", 0))],
	]
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 30)
	_corpo_pg.add_child(g)
	for r in righe:
		_etichetta(g, r[0], Color(0.7, 0.68, 0.62), 13).autowrap_mode = TextServer.AUTOWRAP_OFF
		_etichetta(g, r[1], Color(0.95, 0.93, 0.88), 13).autowrap_mode = TextServer.AUTOWRAP_OFF


# ------------------------------------------------------------------ abilità
func _crea_abilita() -> void:
	var f := _finestra("Abilità  [K]", Vector2(350, 110), 520)
	abilita = f[0]
	var scorri := ScrollContainer.new()
	scorri.custom_minimum_size = Vector2(520, 520)
	(f[1] as VBoxContainer).add_child(scorri)
	_corpo_ab = VBoxContainer.new()
	_corpo_ab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scorri.add_child(_corpo_ab)
	var riga := HBoxContainer.new()
	(f[1] as VBoxContainer).add_child(riga)
	_etichetta(riga, "Trascina una tecnica sulla barra, oppure sceglila e premi:", Color(0.7, 0.68, 0.62), 12).autowrap_mode = TextServer.AUTOWRAP_OFF
	for i in range(10):
		var n := i
		_bottone(riga, str((i + 1) % 10), func() -> void:
			if not tecnica_scelta.is_empty():
				Rete.manda({"t": "qb", "i": n, "v": {"k": "s", "id": tecnica_scelta}})).custom_minimum_size = Vector2(28, 0)


func _riempi_abilita() -> void:
	var io: Dictionary = gioco.io
	var firma := JSON.stringify([io.get("sk"), io.get("kp"), io.get("via"), io.get("lvl"), tecnica_scelta])
	if firma == _firma_ab:
		return
	_firma_ab = firma
	for c in _corpo_ab.get_children():
		c.queue_free()
	var cls: Dictionary = Dati.CLASSES.get(gioco.classe, {})
	var via = io.get("via")
	var lvl := int(io.get("lvl", 1))
	var punti := int(io.get("kp", 0))
	_etichetta(_corpo_ab, "Punti abilità: %d" % punti, Color(1.0, 0.85, 0.4) if punti > 0 else Color(0.6, 0.6, 0.6))
	if via == null:
		if lvl >= int(Dati.costanti.VIA_LEVEL):
			_etichetta(_corpo_ab, "Scegli la tua Via (la scelta è definitiva):", Hud.ORO)
			for v in cls.get("vie", []):
				var d: Dictionary = Dati.VIE[v]
				var nome := String(v)
				_bottone(_corpo_ab, "%s — %s" % [d.name, d.role], func() -> void: Rete.manda({"t": "via", "v": nome})).tooltip_text = String(d.desc)
		else:
			_etichetta(_corpo_ab, "Al livello %d potrai scegliere una Via." % int(Dati.costanti.VIA_LEVEL), Color(0.7, 0.68, 0.62), 12)
	else:
		var d: Dictionary = Dati.VIE.get(String(via), {})
		_etichetta(_corpo_ab, "%s — %s" % [d.get("name", ""), d.get("role", "")], Hud.ORO)
		_etichetta(_corpo_ab, String(d.get("desc", "")), Color(0.75, 0.73, 0.68), 12)
	var lista: Array = []
	for sid in Dati.SKILLS:
		var sk: Dictionary = Dati.SKILLS[sid]
		if String(sk.get("cls", "")) != gioco.classe or sk.get("mount", false):
			continue
		if sk.has("via") and (via == null or String(sk.via) != String(via)):
			continue
		lista.append(sid)
	lista.sort_custom(func(a: String, b: String) -> bool: return int(Dati.SKILLS[a].get("lvl", 1)) < int(Dati.SKILLS[b].get("lvl", 1)))
	for sid in lista:
		var sk: Dictionary = Dati.SKILLS[sid]
		var imparata := lvl >= int(sk.get("lvl", 1))
		var liv := int(io.get("sk", {}).get(sid, 0))
		if imparata and liv < 1:
			liv = 1
		var riga := PanelContainer.new()
		riga.add_theme_stylebox_override("panel", Hud.stile(Color(0.2, 0.17, 0.1, 0.9) if sid == tecnica_scelta else Color(0, 0, 0, 0.35), Hud.ORO if sid == tecnica_scelta else Color(0, 0, 0, 0), 4))
		_corpo_ab.add_child(riga)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		riga.add_child(h)
		var glifo := _etichetta(h, String(sk.get("glyph", "?")), Dati.colore(sk.get("color", 0xcccccc)) if imparata else Color(0.4, 0.4, 0.4), 26)
		glifo.autowrap_mode = TextServer.AUTOWRAP_OFF
		glifo.custom_minimum_size = Vector2(36, 0)
		var testo := VBoxContainer.new()
		testo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(testo)
		var ruolo := String(sk.get("ruolo", ""))
		var titolo := String(sk.name)
		if sk.get("sup", false):
			titolo += "  ·  Tecnica Suprema"
		elif NOMI_RUOLO.has(ruolo):
			titolo += "  ·  " + NOMI_RUOLO[ruolo]
		_etichetta(testo, titolo, Hud.RUOLI.get(ruolo, Color(0.95, 0.93, 0.88)) if imparata else Color(0.5, 0.5, 0.5), 14)
		_etichetta(testo, String(sk.get("desc", "")) if imparata else "Si sblocca al livello %d" % int(sk.get("lvl", 1)), Color(0.72, 0.7, 0.65), 11)
		if imparata:
			_etichetta(h, "liv. %d\n%s" % [liv, Effetti.nome_grado(liv)], Effetti.ORO_PERFETTO if liv >= 20 else Color(0.8, 0.8, 0.75), 11).autowrap_mode = TextServer.AUTOWRAP_OFF
			var nome := String(sid)
			if punti > 0 and liv < int(Dati.gioco.SKILL_MAX_POINTS):
				_bottone(h, "+", func() -> void: Rete.manda({"t": "skup", "s": nome})).custom_minimum_size = Vector2(30, 0)
			riga.tooltip_text = testo_tecnica(sid, liv)
			var glifo_tr := String(sk.get("glyph", "?"))
			riga.set_drag_forwarding(func(_p: Vector2) -> Variant:
				var l := Label.new()
				l.text = glifo_tr
				l.add_theme_font_size_override("font_size", 28)
				riga.set_drag_preview(l)
				return {"tipo": "tec", "id": nome}, Callable(), Callable())
			riga.gui_input.connect(func(ev: InputEvent) -> void:
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					tecnica_scelta = nome
					aggiorna())


# ------------------------------------------------------------------ negozio, fabbro, dialoghi
func _crea_negozio() -> void:
	var f := _finestra("Mercante", Vector2(560, 150), 440)
	negozio = f[0]
	var scorri := ScrollContainer.new()
	scorri.custom_minimum_size = Vector2(440, 440)
	(f[1] as VBoxContainer).add_child(scorri)
	_corpo_neg = VBoxContainer.new()
	_corpo_neg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scorri.add_child(_corpo_neg)
	_etichetta(f[1], "Per vendere: clic destro su un oggetto dell'inventario.", Color(0.65, 0.63, 0.58), 11)


func _su_negozio(m: Dictionary) -> void:
	negozio_png = int(m.npc)
	for c in _corpo_neg.get_children():
		c.queue_free()
	for id in m.get("items", []):
		if not Dati.ITEMS.has(id):
			continue
		var it: Dictionary = Dati.ITEMS[id]
		var h := HBoxContainer.new()
		_corpo_neg.add_child(h)
		var g := _etichetta(h, String(it.get("glyph", "?")), Color(it.color) if it.has("color") else Color(0.9, 0.88, 0.8), 22)
		g.autowrap_mode = TextServer.AUTOWRAP_OFF
		g.custom_minimum_size = Vector2(32, 0)
		var n := _etichetta(h, String(it.name))
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.tooltip_text = testo_oggetto({"id": id})
		n.mouse_filter = Control.MOUSE_FILTER_STOP
		_etichetta(h, "%d tael" % int(it.price), Color(1.0, 0.85, 0.4), 13).autowrap_mode = TextServer.AUTOWRAP_OFF
		var oggetto := String(id)
		_bottone(h, "Compra", func() -> void: Rete.manda({"t": "buy", "npc": negozio_png, "it": oggetto, "n": 1}))
		if it.get("stack", false):
			_bottone(h, "×10", func() -> void: Rete.manda({"t": "buy", "npc": negozio_png, "it": oggetto, "n": 10}))
	negozio.visible = true
	inventario.visible = true
	aggiorna()


func _crea_fabbro() -> void:
	var f := _finestra("Fabbro", Vector2(560, 150), 380)
	fabbro = f[0]
	_testo_fabbro = _etichetta(f[1], "")
	var h := HBoxContainer.new()
	(f[1] as VBoxContainer).add_child(h)
	_bottone(h, "Potenzia", func() -> void: _potenzia(false))
	_bottone(h, "Potenzia con Sigillo del Fabbro", func() -> void: _potenzia(true))
	_bottone(h, "Smonta", func() -> void:
		if scelta >= 0:
			Rete.manda({"t": "salvage", "npc": fabbro_png, "i": scelta}))


func _potenzia(sigillo: bool) -> void:
	if scelta < 0:
		gioco.hud.avvisa("Scegli prima un oggetto nell'inventario", true)
		return
	Rete.manda({"t": "up", "npc": fabbro_png, "i": scelta, "seal": sigillo})


func _su_fabbro(m: Dictionary) -> void:
	if int(m.get("salvaged", 0)) == 1:
		_testo_fabbro.text = "%s smontato." % m.get("name", "")
	elif m.get("destroyed", false):
		_testo_fabbro.text = "Il potenziamento è fallito: %s è andato distrutto." % m.get("name", "")
	elif m.get("ok", false):
		_testo_fabbro.text = "Riuscito! %s è ora +%d." % [m.get("name", ""), int(m.get("up", 0))]
	else:
		_testo_fabbro.text = "Fallito. %s resta +%d." % [m.get("name", ""), int(m.get("up", 0))]


func _descrivi_potenziamento() -> void:
	if not fabbro.visible or scelta < 0:
		return
	var s = _inv()[scelta] if scelta < _inv().size() else null
	if not (s is Dictionary) or not Dati.ITEMS.has(s.id):
		return
	var su := int(s.get("up", 0))
	var U: Dictionary = Dati.gioco.UPGRADE
	if su >= int(U.max):
		_testo_fabbro.text = "%s è già al massimo." % Dati.ITEMS[s.id].name
		return
	if not (Dati.ITEMS[s.id].has("atk") or Dati.ITEMS[s.id].has("def")):
		return
	_testo_fabbro.text = "%s +%d → +%d\nProbabilità %d%%  ·  costo %d tael" % [Dati.ITEMS[s.id].name, su, su + 1, int(U.chance[su]), int(U.cost[su])]


func _crea_dialogo() -> void:
	var f := _finestra("", Vector2(560, 560), 480)
	dialogo = f[0]
	_titolo_dialogo = ((f[1] as VBoxContainer).get_child(0) as HBoxContainer).get_child(0)
	_testo_dialogo = _etichetta(f[1], "")
	_testo_dialogo.custom_minimum_size = Vector2(460, 0)


# ------------------------------------------------------------------ Prove del Sigillo e scuderia
func _crea_prove() -> void:
	var f := _finestra("Prove del Sigillo", Vector2(560, 180), 440)
	prove = f[0]
	_testo_prove = _etichetta(f[1], "")
	_testo_prove.custom_minimum_size = Vector2(420, 0)
	var h := HBoxContainer.new()
	(f[1] as VBoxContainer).add_child(h)
	_bottone(h, "Ricevi un Sigillo", func() -> void: Rete.manda({"t": "trial", "npc": prove_png, "a": "key"}))
	_bottone(h, "Apri la Prova", func() -> void:
		Rete.manda({"t": "trial", "npc": prove_png, "a": "open"})
		prove.visible = false)


func _su_prove(m: Dictionary) -> void:
	prove_png = int(m.npc)
	var D: Dictionary = Dati.gioco.DUNGEON
	var righe: Array = ["%s — una corsa a tempo (%d minuti) da soli o in gruppo fino a 5." % [D.name, int(D.timeLimit) / 60]]
	righe.append("Livello minimo: %d" % int(m.get("minLevel", D.minLevel)))
	righe.append("Il tuo Sigillo: %s" % ("+%d" % int(m.key) if m.get("key") != null else "nessuno"))
	righe.append("Miglior prova superata: %s" % ("+%d" % int(m.best) if int(m.get("best", 0)) > 0 else "—"))
	righe.append("Gruppo: %d%s" % [int(m.get("party", 1)), "" if m.get("leader", true) else "  (solo il capogruppo può aprire)"])
	righe.append("")
	righe.append("Modificatori della settimana (dal +3 il primo, dal +6 entrambi):")
	for a in m.get("week", []):
		var d: Dictionary = Dati.gioco.AFFIXES.get(String(a), {})
		if not d.is_empty():
			righe.append("%s  %s — %s" % [d.glyph, d.name, d.desc])
	_testo_prove.text = "\n".join(PackedStringArray(righe))
	prove.visible = true


func _crea_scuderia() -> void:
	var f := _finestra("Scuderia", Vector2(560, 200), 400)
	scuderia = f[0]
	_testo_scuderia = _etichetta(f[1], "")
	_testo_scuderia.custom_minimum_size = Vector2(380, 0)
	var h := HBoxContainer.new()
	(f[1] as VBoxContainer).add_child(h)
	_compra_cavallo = _bottone(h, "Compra un Puledro", func() -> void: Rete.manda({"t": "stable", "npc": scuderia_png, "a": "buy"}))
	_addestra = _bottone(h, "Addestra", func() -> void: Rete.manda({"t": "stable", "npc": scuderia_png, "a": "train"}))


func _riempi_scuderia() -> void:
	var H: Dictionary = Dati.gioco.HORSE
	var c = gioco.io.get("horse")
	_compra_cavallo.visible = not (c is Dictionary)
	_addestra.visible = c is Dictionary
	if not (c is Dictionary):
		_testo_scuderia.text = "Un Puledro costa %d tael (dal livello %d).\nIn sella ti muovi più in fretta e usi le tecniche a cavallo; il destriero cresce combattendo con te." % [int(H.price), int(H.minLevel)]
		_compra_cavallo.text = "Compra un Puledro (%d tael)" % int(H.price)
		return
	var lv := int(c.lvl)
	var grado := 3 if lv >= 20 else (2 if lv >= 10 else 1)
	var righe: Array = ["%s  ·  livello %d" % [H.names[grado], lv]]
	if lv < int(H.maxLevel):
		righe.append("Esperienza %d / %d" % [int(c.exp), int(c.need)])
		_addestra.text = "Addestra (%d tael, +%d%%)" % [int(H.trainCost[lv]), int(H.trainPct)]
	else:
		righe.append("Ha raggiunto il livello massimo.")
		_addestra.visible = false
	righe.append("Premi R per salire in sella o scendere.")
	for sid in Dati.gioco.MOUNT_SKILLS:
		var sk: Dictionary = Dati.SKILLS[sid]
		righe.append("%s  %s%s" % [sk.glyph, sk.name, "" if lv >= int(sk.hlvl) else "  (dal livello %d)" % int(sk.hlvl)])
	_testo_scuderia.text = "\n".join(PackedStringArray(righe))


# ------------------------------------------------------------------ menu, impostazioni, aiuto
func _crea_menu() -> void:
	var f := _finestra("Regni di Giada", Vector2(660, 250), 280)
	menu = f[0]
	_bottone(f[1], "Riprendi", func() -> void: menu.visible = false)
	_bottone(f[1], "Impostazioni  [O]", func() -> void:
		menu.visible = false
		impostazioni.visible = true)
	_bottone(f[1], "Comandi e aiuto  [H]", func() -> void:
		menu.visible = false
		aiuto.visible = true)
	_bottone(f[1], "Cambia personaggio", func() -> void:
		if Rete.ws != null:
			Rete.ws.close())
	_bottone(f[1], "Esci dal gioco", func() -> void: get_tree().quit())


func _crea_impostazioni() -> void:
	var f := _finestra("Impostazioni  [O]", Vector2(620, 220), 380)
	impostazioni = f[0]
	var v: VBoxContainer = f[1]
	var intero := CheckButton.new()
	intero.text = "Schermo intero  [F11]"
	intero.button_pressed = Impostazioni.schermo_intero
	intero.toggled.connect(func(si: bool) -> void:
		Impostazioni.schermo_intero = si
		_salva_impostazioni())
	v.add_child(intero)
	var riga := HBoxContainer.new()
	v.add_child(riga)
	_etichetta(riga, "Qualità grafica").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var q := OptionButton.new()
	for nome in ["Bassa", "Media", "Alta"]:
		q.add_item(nome)
	q.selected = Impostazioni.qualita
	q.item_selected.connect(func(i: int) -> void:
		Impostazioni.qualita = i
		_salva_impostazioni())
	riga.add_child(q)
	_cursore(v, "Volume", 0.0, 1.0, Impostazioni.volume, func(x: float) -> void:
		Impostazioni.volume = x
		_salva_impostazioni())
	_cursore(v, "Sensibilità della visuale", 0.3, 2.5, Impostazioni.sensibilita, func(x: float) -> void:
		Impostazioni.sensibilita = x
		_salva_impostazioni())
	var num := CheckButton.new()
	num.text = "Numeri di danno"
	num.button_pressed = Impostazioni.numeri_danno
	num.toggled.connect(func(si: bool) -> void:
		Impostazioni.numeri_danno = si
		_salva_impostazioni())
	v.add_child(num)
	_etichetta(v, "Il motore grafico (Compatibilità o Forward+) si cambia dall'editor di Godot, in alto a destra.", Color(0.65, 0.63, 0.58), 11)


func _cursore(genitore: Control, testo: String, minimo: float, massimo: float, valore: float, azione: Callable) -> void:
	var riga := HBoxContainer.new()
	genitore.add_child(riga)
	_etichetta(riga, testo).custom_minimum_size = Vector2(190, 0)
	var s := HSlider.new()
	s.min_value = minimo
	s.max_value = massimo
	s.step = 0.05
	s.value = valore
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(azione)
	riga.add_child(s)


func _salva_impostazioni() -> void:
	Impostazioni.applica()
	Impostazioni.salva()


func _crea_aiuto() -> void:
	var f := _finestra("Comandi e aiuto  [H]", Vector2(470, 110), 660)
	aiuto = f[0]
	var testo := """MOVIMENTO E VISUALE
WASD o clic sul terreno: muoversi  ·  tasto destro trascinato, Q / E: girare la visuale  ·  rotellina: zoom

COMBATTIMENTO
Clic su un nemico o Tab: bersaglio e attacco automatico  ·  1-0: barra rapida  ·  V: Tecnica Suprema (dal livello 15)
Gli ACCUMULI (tacca verde) sono gratuiti e generano risorsa o punti; gli SCARICHI MEDI (oro) la spendono;
gli SCARICHI POTENTI (rosso) costano molto e, per Ombra, Monaco e Mistico, consumano tutti i punti: più punti, più danni.
Ogni colpo a segno dà una tacca di SLANCIO (fino a 5): più risorsa e rapidità finché continui a colpire.
Élite e boss hanno la POSTURA (barra gialla): gli scarichi la abbassano; a zero il nemico è Squilibrato, stordito e fragile.
Spendendo risorsa si riempie la barra della TECNICA SUPREMA.

FINESTRE
I: inventario  ·  C: personaggio e punti statistica  ·  K: abilità e Via (dal livello 5)  ·  O: impostazioni  ·  Esc: chiude / menu
Trascina tecniche e pozioni sulla barra rapida; tasto destro su un tasto della barra per svuotarlo.
Z: raccoglie il bottino  ·  R: sale o scende da cavallo  ·  Invio: chat

IN GIRO PER IL MONDO
Clic su un abitante del villaggio per parlargli: mercanti, fabbro (potenziamenti), maestro delle Vie,
stalliere (cavalcature dal livello 10), custode (Prove del Sigillo dal livello 20, da soli o in gruppo).
Per fare gruppo: clic su un giocatore del tuo regno e «Invita nel gruppo», oppure scrivi /invita nome.
Chat: !testo grida al regno  ·  #testo al gruppo  ·  @nome testo sussurra."""
	var l := _etichetta(f[1], testo, Color(0.88, 0.86, 0.8), 13)
	l.custom_minimum_size = Vector2(640, 0)


# ------------------------------------------------------------------ aggiornamento
func aggiorna() -> void:
	if gioco == null or gioco.me == null:
		return
	if inventario.visible:
		var inv := _inv()
		for i in range(caselle.size()):
			var c: Casella = caselle[i]
			c.imposta(inv[i] if i < inv.size() else null, i == scelta)
			c.tooltip_text = testo_oggetto(inv[i] if i < inv.size() else null)
		tael.text = "%d tael" % int(gioco.io.get("tael", 0))
		_descrivi_potenziamento()
	if personaggio.visible:
		var eq: Dictionary = gioco.inv.get("eq", {})
		for sp in caselle_eq:
			(caselle_eq[sp] as Casella).imposta(eq.get(sp), false)
			(caselle_eq[sp] as Casella).tooltip_text = testo_oggetto(eq.get(sp))
		_riempi_personaggio()
	if abilita.visible:
		_riempi_abilita()
	if scuderia.visible:
		_riempi_scuderia()


# ------------------------------------------------------------------ casella di un oggetto
class Casella:
	extends Control
	signal sinistro(indice: int)
	signal destro(indice: int)

	var indice := 0
	var voce = null
	var scelta := false
	var spazio := ""            # per le caselle dell'equipaggiamento: weapon, head, body, feet
	var finestre                # Finestre

	func _init() -> void:
		custom_minimum_size = Vector2(46, 46)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _get_drag_data(_p: Vector2) -> Variant:
		if not (voce is Dictionary) or not Dati.ITEMS.has(voce.id):
			return null
		var l := Label.new()
		l.text = String(Dati.ITEMS[voce.id].get("glyph", "?"))
		l.add_theme_font_size_override("font_size", 26)
		set_drag_preview(l)
		return {"tipo": "ogg", "i": indice, "id": voce.id, "eq": spazio}

	func _can_drop_data(_p: Vector2, d: Variant) -> bool:
		return d is Dictionary and String(d.get("tipo", "")) == "ogg"

	func _drop_data(_p: Vector2, d: Variant) -> void:
		if finestre != null:
			finestre.rilascia(d, self)

	func imposta(v, selezionata: bool) -> void:
		if v == voce and selezionata == scelta:
			return
		voce = v
		scelta = selezionata
		queue_redraw()

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			if ev.button_index == MOUSE_BUTTON_LEFT:
				sinistro.emit(indice)
			elif ev.button_index == MOUSE_BUTTON_RIGHT:
				destro.emit(indice)
			accept_event()

	func _draw() -> void:
		var bordo := Color(0.35, 0.3, 0.2)
		var it: Dictionary = {}
		if voce is Dictionary and Dati.ITEMS.has(voce.id):
			it = Dati.ITEMS[voce.id]
			var r := int(voce.get("r", 0))
			if r > 0:
				bordo = Color(String(Dati.gioco.RARITIES[clampi(r, 0, 4)].color))
		if scelta:
			bordo = Color(1.0, 0.9, 0.5)
		draw_style_box(Hud.stile(Color(0.1, 0.09, 0.08, 0.95), bordo, 4, 3 if scelta else 2), Rect2(Vector2.ZERO, size))
		if it.is_empty():
			return
		var f := ThemeDB.fallback_font
		var glifo := String(it.get("glyph", "?"))
		var col := Color(String(it.color)) if it.has("color") else Color(0.92, 0.9, 0.82)
		var larg := f.get_string_size(glifo, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(f, Vector2((size.x - larg) * 0.5, 32), glifo, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)
		if int(voce.get("n", 1)) > 1:
			var t := str(int(voce.n))
			var lt := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string_outline(f, Vector2(size.x - lt - 4, size.y - 4), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color.BLACK)
			draw_string(f, Vector2(size.x - lt - 4, size.y - 4), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		if int(voce.get("up", 0)) > 0:
			draw_string_outline(f, Vector2(4, 13), "+%d" % int(voce.up), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color.BLACK)
			draw_string(f, Vector2(4, 13), "+%d" % int(voce.up), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.85, 0.4))
