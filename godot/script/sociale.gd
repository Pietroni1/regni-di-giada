class_name Sociale
extends Control
## Comodità sociali (server/sociale.js): scambio fra giocatori, deposito del Magazziniere, amici e sussurri, clic sui nomi
## in chat, tasto «Ordina» dell'inventario, «Vendi comuni» del negozio, pagina dei tasti nelle impostazioni.
## Qui non si decide nulla: si mostra lo stato che manda il server. Messaggi: `scambio`, `dep`, `amici`, `amico_on`.

const ORO_CHIARO := Color(1.0, 0.86, 0.45)
const VERDE := Color(0.55, 0.92, 0.5)
const GRIGIO := Color(0.72, 0.7, 0.64)
const CASELLE_SCAMBIO := 8
const CASELLE_DEPOSITO := 48

var gioco

# scambio
var scambio: PanelContainer
var _st: Dictionary = {}                # ultimo stato dello scambio
var _mie: Array = []                    # caselle delle mie offerte
var _sue: Array = []                    # caselle delle offerte dell'altro
var _titolo_mio: Label
var _titolo_suo: Label
var _tael_mio: SpinBox
var _tael_suo: Label
var _stato_mio: Label
var _stato_suo: Label
var _conferma: Button
var _aggiorno_tael := false
var richiesta: PanelContainer
var _testo_richiesta: Label
var _richiesta_t := 0.0

# deposito
var deposito: PanelContainer
var _dep: Array = []                    # 48 voci
var _dep_npc := 0
var _caselle_dep: Array = []

# amici
var amici: PanelContainer
var _lista_amici: VBoxContainer
var _campo_amico: LineEdit
var _amici: Array = []
var _amici_t := 0.0
var _firma_amici := ""

# altro
var menu_nome: PopupMenu
var _nome_scelto := ""
var tasti: PannelloTasti
var quantita: PanelContainer
var _spin_quantita: SpinBox
var _titolo_quantita: Label
var _azione_quantita: Callable
var _bott_scambia: Button
var _bott_amico: Button
var ultimo_sussurro := ""
var _ogg_chat: Array = []              # oggetti collegati in chat (per la descrizione al passaggio del mouse)
var _tip_ogg: Control = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crea_scambio()
	_crea_richiesta()
	_crea_deposito()
	_crea_amici()
	_crea_quantita()
	menu_nome = PopupMenu.new()
	menu_nome.id_pressed.connect(_su_menu_nome)
	add_child(menu_nome)
	tasti = PannelloTasti.new()
	tasti.gioco = gioco
	tasti.visible = false
	add_child(tasti)
	Rete.su("scambio", _su_scambio)
	Rete.su("dep", _su_deposito)
	Rete.su("amici", _su_amici)
	Rete.su("amico_on", func(m: Dictionary) -> void: Suoni.suona("clic", -8.0))


## Da chiamare dopo che il gioco ha creato l'interfaccia: bottoni aggiunti alle finestre esistenti, nomi cliccabili in chat.
func aggancia() -> void:
	var hud = gioco.hud
	var fin = hud.finestre
	# riquadro del bersaglio: Scambia e Amico accanto a «Invita nel gruppo»
	var vb: Control = hud.bott_invita.get_parent()
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 4)
	vb.add_child(riga)
	_bott_scambia = Button.new()
	_bott_scambia.text = "Scambia"
	_bott_scambia.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bott_scambia.pressed.connect(func() -> void:
		if gioco.bersaglio != null:
			Rete.manda({"t": "scambio", "a": "chiedi", "id": gioco.bersaglio.id}))
	riga.add_child(_bott_scambia)
	_bott_amico = Button.new()
	_bott_amico.text = "Amico"
	_bott_amico.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bott_amico.pressed.connect(func() -> void:
		if gioco.bersaglio != null:
			Rete.manda({"t": "amico", "a": "aggiungi", "n": gioco.bersaglio.nome}))
	riga.add_child(_bott_amico)
	riga.visible = false
	_bott_scambia.set_meta("riga", riga)
	# inventario: Ordina
	var ordina := Button.new()
	ordina.text = "Ordina"
	ordina.tooltip_text = "Raggruppa le pile e mette gli oggetti in ordine (armi, armature, pozioni, gemme, materiali)."
	ordina.pressed.connect(func() -> void: Rete.manda({"t": "ordina"}))
	fin._riga_tasti_inv.add_child(ordina)
	# negozio: Vendi comuni
	var vneg: Control = fin.negozio.get_child(0)
	var vendi := Button.new()
	vendi.text = "Vendi comuni"
	vendi.tooltip_text = "Vende in un colpo le armi e le armature comuni (senza potenziamenti né gemme) e i trofei di caccia."
	vendi.pressed.connect(func() -> void:
		if fin.negozio_png != 0:
			Rete.manda({"t": "vendi_comuni", "npc": fin.negozio_png}))
	vneg.add_child(vendi)
	# impostazioni: pagina dei tasti
	var vimp: Control = fin.impostazioni.get_child(0)
	var bt := Button.new()
	bt.text = "Personalizza i tasti…"
	bt.tooltip_text = "Due tasti per ogni azione, anche con Maiusc / Ctrl / Alt e con i tasti laterali del mouse."
	bt.pressed.connect(func() -> void:
		tasti.visible = not tasti.visible
		tasti.riempi())
	vimp.add_child(bt)
	# menu Esc: Amici
	var vmenu: Control = fin.menu.get_child(0)
	var ba := Button.new()
	Tasti.registra(ba, "Amici  [{amici}]")
	ba.pressed.connect(func() -> void:
		fin.menu.visible = false
		apri_chiudi("amici"))
	vmenu.add_child(ba)
	vmenu.move_child(ba, 1)
	# menu Esc: Personalizza i tasti
	var bm := Button.new()
	bm.text = "Personalizza i tasti…"
	bm.pressed.connect(func() -> void:
		fin.menu.visible = false
		tasti.visible = true
		tasti.riempi())
	vmenu.add_child(bm)
	vmenu.move_child(bm, 3)
	# chat: nomi cliccabili
	hud.chat.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.chat.meta_clicked.connect(_su_nome_chat)
	hud.chat.meta_hover_started.connect(_su_ogg_sopra)
	hud.chat.meta_hover_ended.connect(_su_ogg_fuori)


func _process(dt: float) -> void:
	if gioco == null or gioco.me == null:
		return
	var b = gioco.bersaglio
	var riga: Control = _bott_scambia.get_meta("riga") if _bott_scambia != null else null
	if riga != null:
		riga.visible = b != null and b.tipo == "p" and b != gioco.me
	if richiesta.visible and gioco.ora() > _richiesta_t:
		richiesta.visible = false
	if amici.visible:
		_amici_t -= dt
		if _amici_t <= 0.0:
			_amici_t = 4.0
			Rete.manda({"t": "amici"})
	# i riquadri dei PNG restano aperti solo vicino a lui
	if deposito.visible and _dep_npc != 0:
		var e = gioco.ents.get(_dep_npc)
		if e == null or Vector2(e.x - gioco.me.x, e.z - gioco.me.z).length() > 9.0:
			deposito.visible = false
			_dep_npc = 0


func apri_chiudi(quale: String) -> void:
	match quale:
		"amici":
			amici.visible = not amici.visible
			if amici.visible:
				Rete.manda({"t": "amici"})
				_riempi_amici()
		"tasti":
			tasti.visible = not tasti.visible
			tasti.riempi()
	Suoni.suona("clic", -12.0)


## Esc: chiude le finestre sociali (lo scambio si annulla). true se qualcosa era aperto.
func chiudi() -> bool:
	var era := scambio.visible or deposito.visible or amici.visible or tasti.visible or richiesta.visible or quantita.visible
	if scambio.visible:
		Rete.manda({"t": "scambio", "a": "annulla"})
	scambio.visible = false
	deposito.visible = false
	_dep_npc = 0
	amici.visible = false
	tasti.visible = false
	richiesta.visible = false
	quantita.visible = false
	return era


# ------------------------------------------------------------------ costruzione
func _pannello(titolo: String, pos: Vector2, larga: float, colore_bordo := Color(0.55, 0.45, 0.2)) -> Array:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Hud.stile(Color(0.07, 0.06, 0.06, 0.95), colore_bordo, 8, 2))
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
	x.pressed.connect(func() -> void:
		if p == scambio:
			Rete.manda({"t": "scambio", "a": "annulla"})
		p.visible = false
		if p == deposito:
			_dep_npc = 0)
	testa.add_child(x)
	return [p, v, t]


func _etichetta(genitore: Control, testo: String, colore := Color(0.9, 0.88, 0.82), misura := 14) -> Label:
	var l := Label.new()
	l.text = testo
	l.add_theme_color_override("font_color", colore)
	l.add_theme_font_size_override("font_size", misura)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	genitore.add_child(l)
	return l


func _casella(origine: String, indice: int) -> CasellaS:
	var c := CasellaS.new()
	c.indice = indice
	c.origine = origine
	c.proprietario = self
	c.finestre = self
	return c


func _crea_scambio() -> void:
	var f := _pannello("Scambio", Vector2(330, 80), 560, Color(0.75, 0.6, 0.25))
	scambio = f[0]
	var v: VBoxContainer = f[1]
	var due := HBoxContainer.new()
	due.add_theme_constant_override("separation", 14)
	v.add_child(due)
	for lato in ["mio", "suo"]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		due.add_child(col)
		var tit := _etichetta(col, "", ORO_CHIARO, 15)
		var griglia := GridContainer.new()
		griglia.columns = 4
		griglia.add_theme_constant_override("h_separation", 4)
		griglia.add_theme_constant_override("v_separation", 4)
		col.add_child(griglia)
		for i in range(CASELLE_SCAMBIO):
			var c := _casella(lato + "_scambio", i)
			griglia.add_child(c)
			if lato == "mio":
				c.sinistro.connect(_togli_offerta)
				c.destro.connect(_togli_offerta)
				_mie.append(c)
			else:
				_sue.append(c)
		var rt := HBoxContainer.new()
		col.add_child(rt)
		_etichetta(rt, "Tael", GRIGIO, 13).autowrap_mode = TextServer.AUTOWRAP_OFF
		if lato == "mio":
			_titolo_mio = tit
			_tael_mio = SpinBox.new()
			_tael_mio.min_value = 0
			_tael_mio.max_value = 100000000
			_tael_mio.step = 1
			_tael_mio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_tael_mio.value_changed.connect(func(x: float) -> void:
				if not _aggiorno_tael:
					Rete.manda({"t": "scambio", "a": "tael", "n": int(x)}))
			rt.add_child(_tael_mio)
			_stato_mio = _etichetta(col, "", GRIGIO, 13)
		else:
			_titolo_suo = tit
			_tael_suo = _etichetta(rt, "0", Color(1.0, 0.85, 0.4), 14)
			_tael_suo.autowrap_mode = TextServer.AUTOWRAP_OFF
			_stato_suo = _etichetta(col, "", GRIGIO, 13)
	_etichetta(v, "Trascina qui gli oggetti dall'inventario (o clic destro su un oggetto). Clic su un tuo oggetto offerto per ritirarlo. Ogni modifica azzera le conferme: lo scambio si chiude solo quando entrambi hanno confermato.", Color(0.65, 0.63, 0.58), 11)
	var bt := HBoxContainer.new()
	bt.add_theme_constant_override("separation", 8)
	v.add_child(bt)
	_conferma = Button.new()
	_conferma.text = "Conferma"
	_conferma.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_conferma.pressed.connect(func() -> void:
		Rete.manda({"t": "scambio", "a": "conferma", "v": int(_st.get("v", 0))}))
	bt.add_child(_conferma)
	var an := Button.new()
	an.text = "Annulla scambio"
	an.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	an.pressed.connect(func() -> void: Rete.manda({"t": "scambio", "a": "annulla"}))
	bt.add_child(an)


func _crea_richiesta() -> void:
	richiesta = PanelContainer.new()
	richiesta.add_theme_stylebox_override("panel", Hud.stile(Color(0.07, 0.06, 0.06, 0.95), Color(0.75, 0.6, 0.25), 8, 2))
	richiesta.set_anchors_preset(Control.PRESET_CENTER_TOP)
	richiesta.position = Vector2(-150, 200)
	richiesta.visible = false
	add_child(richiesta)
	var v := VBoxContainer.new()
	richiesta.add_child(v)
	_testo_richiesta = _etichetta(v, "", Color(0.95, 0.92, 0.85), 15)
	var h := HBoxContainer.new()
	v.add_child(h)
	for coppia in [["Accetta", true], ["Rifiuta", false]]:
		var b := Button.new()
		b.text = coppia[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var si: bool = coppia[1]
		b.pressed.connect(func() -> void:
			Rete.manda({"t": "scambio", "a": "rispondi", "ok": si})
			richiesta.visible = false)
		h.add_child(b)


func _crea_deposito() -> void:
	var f := _pannello("Deposito del Magazziniere", Vector2(300, 160), 0)
	deposito = f[0]
	var v: VBoxContainer = f[1]
	var griglia := GridContainer.new()
	griglia.columns = 8
	griglia.add_theme_constant_override("h_separation", 4)
	griglia.add_theme_constant_override("v_separation", 4)
	v.add_child(griglia)
	for i in range(CASELLE_DEPOSITO):
		var c := _casella("dep", i)
		c.sinistro.connect(_clic_deposito)
		c.destro.connect(_destro_deposito)
		griglia.add_child(c)
		_caselle_dep.append(c)
	_etichetta(v, "Uno solo per tutti i tuoi personaggi. Trascina gli oggetti dall'inventario (aperto accanto) o clic destro per depositare; clic destro su una casella per ritirare.", Color(0.65, 0.63, 0.58), 11)
	var h := HBoxContainer.new()
	v.add_child(h)
	var o := Button.new()
	o.text = "Ordina"
	o.pressed.connect(func() -> void: Rete.manda({"t": "dep", "a": "ordina", "npc": _dep_npc}))
	h.add_child(o)


func _crea_amici() -> void:
	var f := _pannello("Amici", Vector2(900, 120), 470)
	amici = f[0]
	Tasti.registra(f[2], "Amici  [{amici}]")
	var v: VBoxContainer = f[1]
	var h := HBoxContainer.new()
	v.add_child(h)
	_campo_amico = LineEdit.new()
	_campo_amico.placeholder_text = "Nome del personaggio"
	_campo_amico.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_campo_amico.max_length = 16
	_campo_amico.text_submitted.connect(func(_t: String) -> void: _aggiungi_amico())
	h.add_child(_campo_amico)
	var b := Button.new()
	b.text = "Aggiungi"
	b.pressed.connect(_aggiungi_amico)
	h.add_child(b)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(450, 260)
	v.add_child(sc)
	_lista_amici = VBoxContainer.new()
	_lista_amici.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista_amici.add_theme_constant_override("separation", 3)
	sc.add_child(_lista_amici)
	_etichetta(v, "Clic su un amico per sussurrargli, invitarlo nel gruppo o toglierlo. Ti avviso quando entra nel mondo. /amico nome, /s nome testo, /r testo.", Color(0.65, 0.63, 0.58), 11)


func _crea_quantita() -> void:
	var f := _pannello("Quanti?", Vector2(560, 300), 220)
	quantita = f[0]
	_titolo_quantita = f[2]
	var v: VBoxContainer = f[1]
	_spin_quantita = SpinBox.new()
	_spin_quantita.min_value = 1
	_spin_quantita.step = 1
	v.add_child(_spin_quantita)
	var h := HBoxContainer.new()
	v.add_child(h)
	var ok := Button.new()
	ok.text = "Conferma"
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func() -> void:
		quantita.visible = false
		_azione_quantita.call(int(_spin_quantita.value)))
	h.add_child(ok)
	var tutto := Button.new()
	tutto.text = "Tutti"
	tutto.pressed.connect(func() -> void:
		_spin_quantita.value = _spin_quantita.max_value)
	h.add_child(tutto)


## Chiede la quantità se la pila ne ha più di una, poi chiama azione(n).
func _chiedi_quantita(titolo: String, massimo: int, azione: Callable) -> void:
	if massimo <= 1:
		azione.call(1)
		return
	_titolo_quantita.text = titolo
	_spin_quantita.max_value = massimo
	_spin_quantita.value = massimo
	_azione_quantita = azione
	quantita.visible = true
	quantita.move_to_front()


# ------------------------------------------------------------------ trascinamento (dalle caselle di queste finestre)
## Rilascio di un oggetto trascinato su una casella di queste finestre (chiamato da CasellaS).
func rilascia_su(su: CasellaS, d: Dictionary) -> void:
	var da := String(d.get("da", ""))
	var inv: Array = gioco.inv.get("inv", [])
	if su.origine == "mio_scambio" and da == "" and String(d.get("eq", "")) == "":
		_offri_da_inventario(int(d.i))
	elif su.origine == "dep":
		if da == "" and String(d.get("eq", "")) == "":
			var s = inv[int(d.i)] if int(d.i) < inv.size() else null
			_chiedi_quantita("Quanti ne depositi?", int(s.get("n", 1)) if s is Dictionary else 1, func(n: int) -> void:
				Rete.manda({"t": "dep", "a": "metti", "npc": _dep_npc, "i": int(d.i), "n": n, "s": su.indice}))
		elif da == "dep" and int(d.i) != su.indice:
			Rete.manda({"t": "dep", "a": "sposta", "npc": _dep_npc, "da": int(d.i), "a2": su.indice})


func accetta(origine: String, d: Dictionary) -> bool:
	var da := String(d.get("da", ""))
	if origine == "mio_scambio":
		return da == "" and String(d.get("eq", "")) == "" and scambio.visible
	if origine == "dep":
		return deposito.visible and (da == "dep" or (da == "" and String(d.get("eq", "")) == ""))
	return false


## Oggetto del deposito trascinato su una casella dell'inventario (chiamato da Finestre.rilascia).
func da_altrove(d: Dictionary, su) -> void:
	if String(d.get("da", "")) == "dep" and su.spazio.is_empty() and _dep_npc != 0:
		var s = _dep[int(d.i)] if int(d.i) < _dep.size() else null
		_chiedi_quantita("Quanti ne ritiri?", int(s.get("n", 1)) if s is Dictionary else 1, func(n: int) -> void:
			Rete.manda({"t": "dep", "a": "prendi", "npc": _dep_npc, "s": int(d.i), "n": n, "i": su.indice}))


## Clic destro su un oggetto dell'inventario (Finestre._destro_inventario): con scambio o deposito aperti lo sposta lì.
## true se ha gestito il clic.
func destro_inventario(i: int) -> bool:
	var inv: Array = gioco.inv.get("inv", [])
	if i >= inv.size() or not (inv[i] is Dictionary):
		return false
	if scambio.visible:
		_offri_da_inventario(i, true)
		return true
	if deposito.visible and _dep_npc != 0:
		Rete.manda({"t": "dep", "a": "metti", "npc": _dep_npc, "i": i})
		Suoni.suona("clic", -10.0)
		return true
	return false


func _offri_da_inventario(i: int, tutto := false) -> void:
	var inv: Array = gioco.inv.get("inv", [])
	var s = inv[i] if i < inv.size() else null
	if not (s is Dictionary):
		return
	if tutto:
		Rete.manda({"t": "scambio", "a": "offri", "i": i, "n": int(s.get("n", 1))})
		return
	_chiedi_quantita("Quanti ne offri?", int(s.get("n", 1)), func(n: int) -> void:
		Rete.manda({"t": "scambio", "a": "offri", "i": i, "n": n}))


func _togli_offerta(k: int) -> void:
	Rete.manda({"t": "scambio", "a": "togli", "k": k})


func _clic_deposito(i: int) -> void:
	pass


func _destro_deposito(i: int) -> void:
	if i < _dep.size() and _dep[i] is Dictionary and _dep_npc != 0:
		Rete.manda({"t": "dep", "a": "prendi", "npc": _dep_npc, "s": i})
		Suoni.suona("clic", -10.0)


# ------------------------------------------------------------------ messaggi dello scambio
func _su_scambio(m: Dictionary) -> void:
	match String(m.get("a", "")):
		"richiesta":
			_testo_richiesta.text = "%s ti propone uno scambio" % m.n
			richiesta.visible = true
			richiesta.move_to_front()
			_richiesta_t = gioco.ora() + 30000.0
			Suoni.suona("clic", -6.0)
		"stato":
			_st = m
			if not scambio.visible:
				scambio.visible = true
				scambio.move_to_front()
				gioco.hud.finestre.inventario.visible = true
				gioco.hud.finestre.aggiorna()
			_riempi_scambio()
		"fine":
			scambio.visible = false
			quantita.visible = false
			_st = {}
			if int(m.get("ok", 0)) == 1:
				gioco.hud.avvisa("Scambio concluso")
				Suoni.suona("moneta", -6.0)
			elif String(m.get("m", "")) != "":
				gioco.hud.avvisa("Scambio annullato: " + String(m.m), true)


func _riempi_scambio() -> void:
	var mio: Dictionary = _st.get("mio", {})
	var suo: Dictionary = _st.get("suo", {})
	_titolo_mio.text = "Le tue offerte"
	_titolo_suo.text = "Offerte di %s" % _st.get("con", "?")
	var fin = gioco.hud.finestre
	for k in range(CASELLE_SCAMBIO):
		var a: Array = mio.get("o", [])
		var b: Array = suo.get("o", [])
		var cm: Finestre.Casella = _mie[k]
		var cs: Finestre.Casella = _sue[k]
		cm.imposta(a[k] if k < a.size() else null, false)
		cs.imposta(b[k] if k < b.size() else null, false)
		cm.tooltip_text = fin.testo_oggetto(a[k]) if k < a.size() else ""
		cs.tooltip_text = fin.testo_oggetto(b[k]) if k < b.size() else ""
	_aggiorno_tael = true
	_tael_mio.max_value = int(gioco.io.get("tael", 0)) + int(mio.get("tael", 0))
	_tael_mio.set_value_no_signal(int(mio.get("tael", 0)))
	_aggiorno_tael = false
	_tael_suo.text = str(int(suo.get("tael", 0)))
	_stato_mio.text = "Hai confermato" if int(mio.get("ok", 0)) == 1 else "Non hai ancora confermato"
	_stato_mio.add_theme_color_override("font_color", VERDE if int(mio.get("ok", 0)) == 1 else GRIGIO)
	_stato_suo.text = "%s ha confermato" % _st.get("con", "?") if int(suo.get("ok", 0)) == 1 else "%s non ha ancora confermato" % _st.get("con", "?")
	_stato_suo.add_theme_color_override("font_color", VERDE if int(suo.get("ok", 0)) == 1 else GRIGIO)
	_conferma.disabled = int(mio.get("ok", 0)) == 1
	_conferma.text = "Confermato — in attesa" if int(mio.get("ok", 0)) == 1 else "Conferma"


# ------------------------------------------------------------------ deposito
func _su_deposito(m: Dictionary) -> void:
	if String(m.get("a", "")) != "stato":
		return
	_dep = m.get("slots", [])
	_dep_npc = int(m.get("npc", 0))
	if not deposito.visible:
		deposito.visible = true
		deposito.move_to_front()
		gioco.hud.finestre.inventario.visible = true
		gioco.hud.finestre.aggiorna()
	var fin = gioco.hud.finestre
	for i in range(CASELLE_DEPOSITO):
		var c: Finestre.Casella = _caselle_dep[i]
		var s = _dep[i] if i < _dep.size() else null
		c.imposta(s, false)
		c.tooltip_text = fin.testo_oggetto(s)


# ------------------------------------------------------------------ amici
func _su_amici(m: Dictionary) -> void:
	_amici = m.get("list", [])
	if amici.visible:
		_riempi_amici()


func _aggiungi_amico() -> void:
	var n := _campo_amico.text.strip_edges()
	if n.is_empty():
		return
	Rete.manda({"t": "amico", "a": "aggiungi", "n": n})
	_campo_amico.text = ""


func _riempi_amici() -> void:
	var firma := JSON.stringify(_amici)
	if firma == _firma_amici:
		return
	_firma_amici = firma
	for c in _lista_amici.get_children():
		c.queue_free()
	if _amici.is_empty():
		_etichetta(_lista_amici, "Non hai ancora amici. Scrivi un nome qui sopra o usa «Amico» sul bersaglio.", GRIGIO, 13)
	var ordinati := _amici.duplicate()
	ordinati.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("on", 0)) != int(b.get("on", 0)):
			return int(a.get("on", 0)) > int(b.get("on", 0))
		return String(a.n).naturalnocasecmp_to(String(b.n)) < 0)
	for a: Dictionary in ordinati:
		var on := int(a.get("on", 0)) == 1
		var riga := Button.new()
		riga.alignment = HORIZONTAL_ALIGNMENT_LEFT
		riga.flat = true
		riga.clip_text = true
		var cls: Dictionary = Dati.CLASSES.get(String(a.get("cls", "")), {})
		var info := ""
		if int(a.get("lvl", 0)) > 0:
			info = "  ·  livello %d %s" % [int(a.lvl), String(cls.get("name", ""))]
		if on:
			info += "  ·  " + String(a.get("z", ""))
		riga.text = "%s %s%s" % ["●" if on else "○", a.n, info]
		riga.add_theme_color_override("font_color", VERDE if on else GRIGIO)
		riga.add_theme_color_override("font_hover_color", ORO_CHIARO)
		var nome := String(a.n)
		riga.pressed.connect(func() -> void: _menu_per(nome, true, riga.get_screen_position() + Vector2(20, 24)))
		_lista_amici.add_child(riga)


# ------------------------------------------------------------------ nomi in chat e menu del nome
func riga_chat(m: Dictionary) -> void:
	var canali := {"say": Color(0.95, 0.95, 0.9), "shout": Color(1.0, 0.7, 0.4), "party": Color(0.5, 0.8, 1.0), "wh": Color(0.9, 0.6, 0.95)}
	var colore: Color = canali.get(String(m.get("ch", "say")), Color.WHITE)
	var nome := String(m.get("n", "?"))
	var testo := _con_oggetti(String(m.get("m", "")).replace("[", "[lb]"))
	var riga := ""
	if String(m.get("ch", "")) == "wh":
		if m.has("to"):
			riga = "A [url=%s]%s[/url]: %s" % [m.to, m.to, testo]
		else:
			riga = "[url=%s]%s[/url] ti sussurra: %s" % [nome, nome, testo]
			ultimo_sussurro = nome
	else:
		riga = "[url=%s]%s[/url]: %s" % [nome, nome, testo]
	gioco.hud.chat.append_text("[color=#%s]%s[/color]\n" % [colore.to_html(false), riga])


## Gli oggetti collegati in chat (⟦json⟧ dal server) diventano «[Nome]» colorato; il passaggio del mouse mostra la descrizione.
func _con_oggetti(testo: String) -> String:
	if not testo.contains("⟦"):
		return testo
	var out := ""
	var pos := 0
	var rx := RegEx.create_from_string("⟦([^⟧]*)⟧")
	for r in rx.search_all(testo):
		out += testo.substr(pos, r.get_start() - pos)
		pos = r.get_end()
		var j = JSON.parse_string(r.get_string(1).uri_decode())
		if j is Dictionary and Dati.ITEMS.has(String(j.get("id", ""))):
			_ogg_chat.append(j)
			var rar := IconeOggetti.rarita(String(j.id), j)
			var nome := String(Dati.ITEMS[j.id].name)
			if int(j.get("up", 0)) > 0:
				nome += " +%d" % int(j.up)
			out += "[url=ogg:%d][color=#%s][lb]%s[rb][/color][/url]" % [_ogg_chat.size() - 1, IconeOggetti.colore_rarita(rar).to_html(false), nome]
	return out + testo.substr(pos)


func _su_ogg_sopra(meta: Variant) -> void:
	_su_ogg_fuori(meta)
	var k := String(meta)
	if not k.begins_with("ogg:"):
		return
	var i := int(k.substr(4))
	if i < 0 or i >= _ogg_chat.size():
		return
	var j: Dictionary = _ogg_chat[i]
	var t = IconeOggetti.tooltip(gioco.hud.finestre.testo_oggetto(j), String(j.id), IconeOggetti.rarita(String(j.id), j), int(j.get("up", 0)))
	if t is Control:
		_tip_ogg = t
		add_child(t)
		var mp := get_viewport().get_mouse_position()
		t.position = Vector2(mp.x + 16.0, maxf(8.0, mp.y - 220.0))


func _su_ogg_fuori(_meta: Variant) -> void:
	if _tip_ogg != null and is_instance_valid(_tip_ogg):
		_tip_ogg.queue_free()
	_tip_ogg = null


## Maiusc+clic su un oggetto dell'inventario: lo scrive nella chat come collegamento («[[casella]]», il server lo allega).
func link_inventario(i: int) -> bool:
	var inv: Array = gioco.inv.get("inv", [])
	if i >= inv.size() or not (inv[i] is Dictionary):
		return false
	var hud = gioco.hud
	hud.scrivi.text += "[[%d]]" % i
	hud.apri_chat()
	hud.scrivi.caret_column = hud.scrivi.text.length()
	return true


func _su_nome_chat(meta: Variant) -> void:
	if String(meta).begins_with("ogg:"):
		return
	_menu_per(String(meta), false, get_viewport().get_mouse_position())


func _menu_per(nome: String, amico: bool, pos: Vector2) -> void:
	if gioco.me != null and nome == String(gioco.me.nome):
		return
	_nome_scelto = nome
	menu_nome.clear()
	menu_nome.add_separator(nome)
	menu_nome.add_item("Sussurra", 1)
	menu_nome.add_item("Invita nel gruppo", 2)
	menu_nome.add_item("Scambia", 3)
	if amico:
		menu_nome.add_item("Togli dagli amici", 4)
	else:
		menu_nome.add_item("Aggiungi agli amici", 5)
	menu_nome.position = Vector2i(pos)
	menu_nome.popup()


func _su_menu_nome(id: int) -> void:
	match id:
		1:
			gioco.hud.scrivi.text = "/s %s " % _nome_scelto
			gioco.hud.apri_chat()
			gioco.hud.scrivi.caret_column = gioco.hud.scrivi.text.length()
		2: Rete.manda({"t": "pinv", "n": _nome_scelto})
		3: Rete.manda({"t": "scambio", "a": "chiedi", "n": _nome_scelto})
		4: Rete.manda({"t": "amico", "a": "rimuovi", "n": _nome_scelto})
		5: Rete.manda({"t": "amico", "a": "aggiungi", "n": _nome_scelto})


# ------------------------------------------------------------------ copione di prova (principale.gd, comando «sociale»)
## sociale apri amici|tasti|deposito · scambia nome · offri indice [n] · conferma · tael n · aspetta_scambio · aspetta_deposito
## · deposita indice [n] · ritira casella · aspetta_amici · tasto azione codice
func copione(p: PackedStringArray) -> void:
	match p[1]:
		"apri":
			if p[2] == "deposito":
				for e: Entita in gioco.ents.values():
					if e.tipo == "n" and String(e.info.get("role", "")) == "magazziniere":
						Rete.manda({"t": "npc", "id": e.id})
						break
			else:
				apri_chiudi(p[2])
		"vai":
			# vai ruolo: GM, si porta accanto al PNG di quel ruolo più vicino
			for e: Entita in gioco.ents.values():
				if e.tipo == "n" and String(e.info.get("role", "")) == p[2]:
					Rete.manda({"t": "chat", "m": "/tp %d %d" % [int(e.x) + 1, int(e.z) + 1]})
					break
		"scambia": Rete.manda({"t": "scambio", "a": "chiedi", "n": p[2]})
		"offri":
			Rete.manda({"t": "scambio", "a": "offri", "i": int(p[2]), "n": int(p[3]) if p.size() > 3 else 1})
		"conferma": Rete.manda({"t": "scambio", "a": "conferma", "v": int(_st.get("v", 0))})
		"tael": Rete.manda({"t": "scambio", "a": "tael", "n": int(p[2])})
		"aspetta_scambio":
			var scade := Time.get_ticks_msec() + 400000
			while Time.get_ticks_msec() < scade and not (scambio.visible and not _st.is_empty()):
				await get_tree().process_frame
			await get_tree().create_timer(0.3, true, false, true).timeout
		"aspetta_offerta":
			var scade4 := Time.get_ticks_msec() + 400000
			while Time.get_ticks_msec() < scade4 and (_st.get("mio", {}).get("o", []) as Array).is_empty():
				await get_tree().process_frame
			await get_tree().create_timer(0.3, true, false, true).timeout
		"aspetta_tael":
			var scade7 := Time.get_ticks_msec() + 400000
			while Time.get_ticks_msec() < scade7 and int(_st.get("mio", {}).get("tael", 0)) <= 0:
				await get_tree().process_frame
			await get_tree().create_timer(0.3, true, false, true).timeout
		"aspetta_conferma":
			var scade5 := Time.get_ticks_msec() + 400000
			while Time.get_ticks_msec() < scade5 and int(_st.get("mio", {}).get("ok", 0)) != 1:
				await get_tree().process_frame
			await get_tree().create_timer(0.3, true, false, true).timeout
		"aspetta_deposito_pieno":
			var scade6 := Time.get_ticks_msec() + 400000
			while Time.get_ticks_msec() < scade6 and _dep.filter(func(x) -> bool: return x != null).is_empty():
				await get_tree().process_frame
			await get_tree().create_timer(0.3, true, false, true).timeout
		"aspetta_deposito":
			var scade2 := Time.get_ticks_msec() + 400000
			while Time.get_ticks_msec() < scade2 and not deposito.visible:
				await get_tree().process_frame
			await get_tree().create_timer(0.3, true, false, true).timeout
		"deposita": Rete.manda({"t": "dep", "a": "metti", "npc": _dep_npc, "i": int(p[2]), "n": int(p[3]) if p.size() > 3 else 0})
		"ritira": Rete.manda({"t": "dep", "a": "prendi", "npc": _dep_npc, "s": int(p[2])})
		"amico": Rete.manda({"t": "amico", "a": "aggiungi", "n": p[2]})
		"aspetta_amici":
			var scade3 := Time.get_ticks_msec() + 400000
			while Time.get_ticks_msec() < scade3 and _amici.is_empty():
				await get_tree().process_frame
		"cattura":
			# sociale cattura azione [posto]: la casella aspetta un comando (poi `premi` o `mouse` nel copione)
			tasti._comincia("%s:%d" % [p[2], int(p[3]) if p.size() > 3 else 0])
		"ripristina_tasti":
			Tasti.ripristina()
			tasti._salva()
		"tasto":
			# sociale tasto azione codice [posto]   (posto 1 = alternativo)
			Tasti.assegna(p[2], int(p[4]) if p.size() > 4 else 0, int(p[3]))
			tasti._salva()


# ------------------------------------------------------------------ casella con origine
class CasellaS:
	extends Finestre.Casella
	var origine := ""
	var proprietario

	func _get_drag_data(p: Vector2) -> Variant:
		var d = super._get_drag_data(p)
		if d is Dictionary:
			d["da"] = origine
		return d

	func _can_drop_data(_p: Vector2, d: Variant) -> bool:
		return d is Dictionary and String(d.get("tipo", "")) == "ogg" and proprietario != null and proprietario.accetta(origine, d)

	func _drop_data(_p: Vector2, d: Variant) -> void:
		if proprietario != null:
			proprietario.rilascia_su(self, d)
