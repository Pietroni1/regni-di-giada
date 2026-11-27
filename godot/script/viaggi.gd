class_name Viaggi
extends Control
## Viaggi verso le mappe lontane e Arena: finestra della Guida dei Sentieri (e dell'Araldo), riquadro della classifica
## dell'arena sotto la minimappa e annunci delle uccisioni. Messaggi del server: `viaggio`, `arena`, `arena_k`.

var gioco
var finestra: PanelContainer
var _corpo: VBoxContainer
var _png := 0
var _ultimo: Dictionary = {}       # ultimo messaggio `viaggio`
var riquadro_arena: PanelContainer
var _testo_arena: RichTextLabel
var classifica: Dictionary = {}    # ultimo messaggio `arena`


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crea_finestra()
	_crea_riquadro_arena()
	Rete.su("viaggio", _su_viaggio)
	Rete.su("arena", _su_arena)
	Rete.su("arena_k", _su_uccisione)


## Chiude la finestra dei viaggi; true se era aperta (per Esc).
func chiudi() -> bool:
	var era := finestra.visible
	finestra.visible = false
	return era


# ------------------------------------------------------------------ finestra dei viaggi
func _crea_finestra() -> void:
	finestra = PanelContainer.new()
	finestra.add_theme_stylebox_override("panel", Hud.stile(Color(0.07, 0.06, 0.06, 0.94), Hud.ORO.darkened(0.35), 8, 2))
	finestra.position = Vector2(520, 150)
	finestra.custom_minimum_size = Vector2(520, 0)
	finestra.visible = false
	add_child(finestra)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	finestra.add_child(v)
	var testa := HBoxContainer.new()
	v.add_child(testa)
	var t := Label.new()
	t.text = "Sentieri Lontani"
	t.add_theme_color_override("font_color", Hud.ORO)
	t.add_theme_font_size_override("font_size", 18)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	t.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion and ev.button_mask & MOUSE_BUTTON_MASK_LEFT:
			finestra.position += ev.relative)
	testa.add_child(t)
	var x := Button.new()
	x.text = "✕"
	x.flat = true
	x.pressed.connect(func() -> void: finestra.visible = false)
	testa.add_child(x)
	_corpo = VBoxContainer.new()
	_corpo.add_theme_constant_override("separation", 8)
	v.add_child(_corpo)


func _etichetta(genitore: Control, testo: String, colore := Color(0.9, 0.88, 0.82), misura := 14) -> Label:
	var l := Label.new()
	l.text = testo
	l.add_theme_color_override("font_color", colore)
	l.add_theme_font_size_override("font_size", misura)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(490, 0)
	genitore.add_child(l)
	return l


func _su_viaggio(m: Dictionary) -> void:
	_png = int(m.npc)
	_ultimo = m
	_riempi()
	finestra.visible = true
	Suoni.suona("clic", -12.0)


func _riempi() -> void:
	for c in _corpo.get_children():
		c.queue_free()
	var m := _ultimo
	var qui := String(m.get("qui", ""))
	var lvl := int(gioco.io.get("lvl", 1))
	var tael := int(gioco.io.get("tael", m.get("tael", 0)))
	var gente: Dictionary = m.get("n", {})
	var defs := Mappe.definizioni()
	if qui != "":
		_etichetta(_corpo, "Sei in: %s" % String(defs[qui].nome), Hud.ORO, 15)
		var torna := Button.new()
		torna.text = "Torna al tuo villaggio"
		torna.pressed.connect(func() -> void:
			Rete.manda({"t": "viaggio", "npc": _png, "a": "torna"})
			finestra.visible = false)
		_corpo.add_child(torna)
		_corpo.add_child(HSeparator.new())
	else:
		_etichetta(_corpo, "«Oltre i monti ci sono terre dove i forti diventano più forti. Dimmi dove vuoi andare.»", Color(0.82, 0.8, 0.74), 13)
	for id in defs:
		if id == qui:
			continue
		var d: Dictionary = defs[id]
		var riga := VBoxContainer.new()
		riga.add_theme_constant_override("separation", 2)
		_corpo.add_child(riga)
		var titolo := String(d.nome)
		if d.get("liv") is Array:
			titolo += "   ·   livelli %d-%d" % [int(d.liv[0]), int(d.liv[1])]
		else:
			titolo += "   ·   PvP libero"
		_etichetta(riga, titolo, Color(0.95, 0.85, 0.55), 15)
		_etichetta(riga, String(d.desc), Color(0.8, 0.78, 0.72), 12)
		var info := "Livello minimo %d" % int(d.minLvl)
		info += "   ·   viaggio: %s" % ("gratuito" if int(d.prezzo) == 0 else "%d tael" % int(d.prezzo))
		info += "   ·   presenti: %d" % int(gente.get(id, 0))
		var basso := lvl < int(d.minLvl)
		var povero := tael < int(d.prezzo)
		_etichetta(riga, info, Color(1.0, 0.5, 0.45) if basso or povero else Color(0.6, 0.85, 0.6), 12)
		var vai := Button.new()
		vai.text = "Viaggia" if not basso else "Serve il livello %d" % int(d.minLvl)
		vai.disabled = basso or povero
		vai.size_flags_horizontal = Control.SIZE_SHRINK_END
		var dest := String(id)
		vai.pressed.connect(func() -> void:
			Rete.manda({"t": "viaggio", "npc": _png, "a": "vai", "m": dest})
			finestra.visible = false)
		riga.add_child(vai)


# ------------------------------------------------------------------ arena: classifica e annunci
func _crea_riquadro_arena() -> void:
	riquadro_arena = PanelContainer.new()
	riquadro_arena.add_theme_stylebox_override("panel", Hud.stile(Hud.SFONDO, Color(0.75, 0.2, 0.15), 6))
	riquadro_arena.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	riquadro_arena.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	riquadro_arena.position = Vector2(-16, 246)
	riquadro_arena.custom_minimum_size = Vector2(250, 0)
	riquadro_arena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	riquadro_arena.visible = false
	add_child(riquadro_arena)
	_testo_arena = RichTextLabel.new()
	_testo_arena.bbcode_enabled = true
	_testo_arena.fit_content = true
	_testo_arena.scroll_active = false
	_testo_arena.custom_minimum_size = Vector2(250, 0)
	_testo_arena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_testo_arena.add_theme_font_size_override("normal_font_size", 13)
	riquadro_arena.add_child(_testo_arena)


func _su_arena(m: Dictionary) -> void:
	if int(m.get("fuori", 0)) == 1:
		classifica = {}
		riquadro_arena.visible = false
		return
	classifica = m
	_scrivi_classifica()


func _scrivi_classifica() -> void:
	var m := classifica
	var io: Dictionary = m.get("io", {})
	var righe: Array = ["[color=#e0b060][b]%s[/b][/color]" % String(Mappe.definizioni().get("arena", {}).get("nome", "Arena"))]
	righe.append("[color=#b0b0a8]Combattenti presenti: %d[/color]" % int(m.get("n", 0)))
	righe.append("Tu: [color=#90e090]%d abbattuti[/color] · [color=#e09090]%d cadute[/color] · serie %d (migliore %d)" % [int(io.get("u", 0)), int(io.get("m", 0)), int(io.get("s", 0)), int(io.get("b", 0))])
	var cl: Array = m.get("cl", [])
	if cl.is_empty():
		righe.append("[color=#a0a098]Nessuno è ancora caduto. Sii il primo a farti un nome.[/color]")
	else:
		righe.append("[color=#e0b060]Classifica della sessione[/color]")
	var pos := 1
	for r in cl:
		var kd: Dictionary = Dati.KINGDOMS.get(String(r.get("kd", "")), {})
		var col := Dati.colore(kd.get("hex", 0xcccccc)).lightened(0.3).to_html(false)
		var mio: bool = gioco.me != null and String(r.n) == gioco.me.nome
		var nome := "[b]%s[/b]" % String(r.n) if mio else String(r.n)
		righe.append("%d. [color=#%s]%s[/color]  %d / %d%s" % [pos, col, nome, int(r.u), int(r.m), "  (serie %d)" % int(r.s) if int(r.s) >= 3 else ""])
		pos += 1
	_testo_arena.text = "\n".join(PackedStringArray(righe))


func _su_uccisione(m: Dictionary) -> void:
	var io_nome: String = gioco.me.nome if gioco.me != null else ""
	var testo := String(m.get("m", ""))
	var colore := Color(1.0, 0.7, 0.45)
	if String(m.get("a", "")) == io_nome:
		colore = Color(1.0, 0.85, 0.35)
		Suoni.suona("critico", -4.0, 0.8)
	elif String(m.get("v", "")) == io_nome:
		colore = Color(1.0, 0.45, 0.4)
	gioco.hud.riga_chat(testo, colore)
	if String(m.get("a", "")) == io_nome or String(m.get("v", "")) == io_nome or int(m.get("s", 0)) >= 3:
		gioco.hud.avvisa(testo)


func _process(_dt: float) -> void:
	if gioco == null or gioco.me == null:
		return
	riquadro_arena.visible = not classifica.is_empty() and Mappe.in_arena(gioco.me.x, gioco.me.z)
	# la finestra dei viaggi si chiude se ci si allontana dal PNG
	if finestra.visible and _png != 0:
		var n = gioco.ents.get(_png)
		if n == null or Vector2(n.x - gioco.me.x, n.z - gioco.me.z).length() > 10.0:
			finestra.visible = false
