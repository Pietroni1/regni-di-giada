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
	Rete.su("stable", func(_m: Dictionary) -> void: gioco.hud.avvisa("La scuderia non è ancora disponibile nel client Godot", true))
	Rete.su("trial", func(_m: Dictionary) -> void: gioco.hud.avvisa("Le Prove del Sigillo non sono ancora disponibili nel client Godot", true))
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
	var f: PanelContainer = {"inventario": inventario, "personaggio": personaggio, "abilita": abilita}[quale]
	f.visible = not f.visible
	aggiorna()


## Chiude tutto; restituisce true se c'era qualcosa di aperto.
func chiudi_tutto() -> bool:
	var aperta := false
	for f in [inventario, personaggio, abilita, negozio, fabbro, dialogo]:
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
	var righe: Array = [String(sk.name) + ("  (livello %d)" % lvl if lvl > 0 else "")]
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
	if sk.has("mult"):
		righe.append("Danni: %d%% dell'attacco" % int(round(Dati.valore(sk.mult, maxi(lvl, 1)) * 100.0)))
	return "\n".join(righe)


# ------------------------------------------------------------------ inventario
func _crea_inventario() -> void:
	var f := _finestra("Inventario  [I]", Vector2(1040, 300), 0)
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
		c.sinistro.connect(_clic_inventario)
		c.destro.connect(_destro_inventario)
		griglia.add_child(c)
		caselle.append(c)
	tael = _etichetta(v, "", Color(1.0, 0.85, 0.4))
	_etichetta(v, "Clic: seleziona, poi clic su un'altra casella per spostare. Clic destro: usa, indossa o vendi (con il negozio aperto).", Color(0.65, 0.63, 0.58), 11)
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


func _clic_inventario(i: int) -> void:
	var inv := _inv()
	if scelta >= 0 and scelta != i:
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
	_etichetta(riga, "Metti la tecnica scelta nel tasto:", Color(0.7, 0.68, 0.62), 12).autowrap_mode = TextServer.AUTOWRAP_OFF
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
			_etichetta(h, "liv. %d" % liv, Color(0.8, 0.8, 0.75), 12).autowrap_mode = TextServer.AUTOWRAP_OFF
			var nome := String(sid)
			if punti > 0 and liv < int(Dati.gioco.SKILL_MAX_POINTS):
				_bottone(h, "+", func() -> void: Rete.manda({"t": "skup", "s": nome})).custom_minimum_size = Vector2(30, 0)
			riga.tooltip_text = testo_tecnica(sid, liv)
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


# ------------------------------------------------------------------ casella di un oggetto
class Casella:
	extends Control
	signal sinistro(indice: int)
	signal destro(indice: int)

	var indice := 0
	var voce = null
	var scelta := false

	func _init() -> void:
		custom_minimum_size = Vector2(46, 46)
		mouse_filter = Control.MOUSE_FILTER_STOP

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
