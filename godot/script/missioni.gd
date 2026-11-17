class_name Missioni
extends Control
## Missioni (server/missioni.js): diario (tasto L), elenco delle missioni aperte a lato dello schermo, dialogo dei PNG
## che affidano o ricevono missioni, segni «!» e «?» sopra i PNG, obiettivo sulla minimappa e sulla mappa grande,
## avvisi di avanzamento e del passaggio di livello. Messaggi del server: `mis`, `mis_png`, `mis_ev`, `sblocchi`.
## Qui non si decide nulla: si mostra lo stato che manda il server.

const ORO_CHIARO := Color(1.0, 0.86, 0.45)
const VERDE := Color(0.55, 0.92, 0.5)
const GRIGIO := Color(0.72, 0.7, 0.64)

var gioco
var stato: Dictionary = {}         # ultimo messaggio `mis`
var diario: PanelContainer
var _corpo_diario: VBoxContainer
var elenco: PanelContainer
var _testo_elenco: RichTextLabel
var dialogo: PanelContainer
var _corpo_dialogo: VBoxContainer
var _titolo_dialogo: Label
var _png_dialogo := 0
var _ultimo_dialogo: Dictionary = {}
var segni: Control                 # disegna «!» e «?» sopra i PNG (sotto le finestre)
var riquadro_livello: PanelContainer
var _testo_livello: RichTextLabel
var _livello_t := 0.0
var progresso: Label               # riga piccola dell'avanzamento («Lupi abbattuti 3/6»)
var _progresso_t := 0.0
var _firma_elenco := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crea_elenco()
	_crea_diario()
	_crea_dialogo()
	_crea_livello()
	progresso = Label.new()
	progresso.set_anchors_preset(Control.PRESET_CENTER_TOP)
	progresso.offset_left = -300.0
	progresso.offset_right = 300.0
	progresso.offset_top = 164.0
	progresso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progresso.add_theme_font_size_override("font_size", 16)
	progresso.add_theme_color_override("font_color", ORO_CHIARO)
	progresso.add_theme_color_override("font_outline_color", Color.BLACK)
	progresso.add_theme_constant_override("outline_size", 5)
	progresso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(progresso)
	Rete.su("mis", _su_stato)
	Rete.su("mis_png", _su_dialogo)
	Rete.su("mis_ev", _su_evento)
	Rete.su("sblocchi", _su_sblocchi)


## Da chiamare dopo che il gioco ha creato l'interfaccia: segni sopra i PNG (subito sopra le targhette) e minimappa.
func aggancia() -> void:
	segni = Control.new()
	segni.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	segni.mouse_filter = Control.MOUSE_FILTER_IGNORE
	segni.draw.connect(_disegna_segni)
	gioco.hud.radice.add_child(segni)
	gioco.hud.radice.move_child(segni, gioco.hud.targhette.get_index() + 1)
	gioco.hud.minimappa.draw.connect(_disegna_minimappa)


func apri_chiudi() -> void:
	diario.visible = not diario.visible
	if diario.visible:
		_riempi_diario()
	Suoni.suona("clic", -12.0)


## Chiude diario e dialogo; true se qualcosa era aperto (per Esc).
func chiudi() -> bool:
	var era := diario.visible or dialogo.visible or riquadro_livello.visible
	diario.visible = false
	dialogo.visible = false
	riquadro_livello.visible = false
	return era


# ------------------------------------------------------------------ costruzione
func _pannello(colore_bordo: Color, spessore := 2) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Hud.stile(Color(0.07, 0.06, 0.06, 0.94), colore_bordo, 8, spessore))
	add_child(p)
	return p


func _testata(p: PanelContainer, titolo: String) -> Array:
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
	return [v, t]


func _etichetta(genitore: Control, testo: String, colore := Color(0.9, 0.88, 0.82), misura := 14, larga := 0.0) -> Label:
	var l := Label.new()
	l.text = testo
	l.add_theme_color_override("font_color", colore)
	l.add_theme_font_size_override("font_size", misura)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if larga > 0.0:
		l.custom_minimum_size = Vector2(larga, 0)
	genitore.add_child(l)
	return l


func _crea_elenco() -> void:
	elenco = PanelContainer.new()
	elenco.add_theme_stylebox_override("panel", Hud.stile(Color(0.05, 0.04, 0.04, 0.55), Color(0, 0, 0, 0), 6))
	# ancorato in alto a destra, sotto la minimappa (offset espliciti: quando nasce il genitore ha già la sua misura)
	elenco.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	elenco.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	elenco.offset_right = -16.0
	elenco.offset_left = -16.0 - 270.0
	elenco.offset_top = 246.0
	elenco.custom_minimum_size = Vector2(270, 0)
	elenco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(elenco)
	_testo_elenco = RichTextLabel.new()
	_testo_elenco.bbcode_enabled = true
	_testo_elenco.fit_content = true
	_testo_elenco.scroll_active = false
	_testo_elenco.custom_minimum_size = Vector2(270, 0)
	_testo_elenco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_testo_elenco.add_theme_font_size_override("normal_font_size", 13)
	_testo_elenco.add_theme_font_size_override("bold_font_size", 14)
	_testo_elenco.add_theme_constant_override("outline_size", 4)
	_testo_elenco.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	elenco.add_child(_testo_elenco)


func _crea_diario() -> void:
	diario = _pannello(Hud.ORO.darkened(0.35))
	diario.position = Vector2(60, 110)
	diario.custom_minimum_size = Vector2(560, 0)
	diario.visible = false
	var t := _testata(diario, "")
	Tasti.registra(t[1], "Diario delle missioni  [{diario}]")
	var scorri := ScrollContainer.new()
	scorri.custom_minimum_size = Vector2(540, 560)
	scorri.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(t[0] as VBoxContainer).add_child(scorri)
	_corpo_diario = VBoxContainer.new()
	_corpo_diario.add_theme_constant_override("separation", 6)
	_corpo_diario.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scorri.add_child(_corpo_diario)


func _crea_dialogo() -> void:
	dialogo = _pannello(Hud.ORO, 2)
	dialogo.position = Vector2(60, 140)
	dialogo.custom_minimum_size = Vector2(470, 0)
	dialogo.visible = false
	var t := _testata(dialogo, "")
	_titolo_dialogo = t[1]
	_corpo_dialogo = VBoxContainer.new()
	_corpo_dialogo.add_theme_constant_override("separation", 6)
	(t[0] as VBoxContainer).add_child(_corpo_dialogo)


func _crea_livello() -> void:
	riquadro_livello = _pannello(Hud.ORO, 2)
	riquadro_livello.set_anchors_preset(Control.PRESET_CENTER_TOP)
	riquadro_livello.grow_horizontal = Control.GROW_DIRECTION_BOTH
	riquadro_livello.offset_left = -260.0
	riquadro_livello.offset_right = 260.0
	riquadro_livello.offset_top = 196.0
	riquadro_livello.custom_minimum_size = Vector2(520, 0)
	riquadro_livello.visible = false
	riquadro_livello.mouse_filter = Control.MOUSE_FILTER_STOP
	riquadro_livello.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			riquadro_livello.visible = false)
	_testo_livello = RichTextLabel.new()
	_testo_livello.bbcode_enabled = true
	_testo_livello.fit_content = true
	_testo_livello.scroll_active = false
	_testo_livello.custom_minimum_size = Vector2(500, 0)
	_testo_livello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_testo_livello.add_theme_font_size_override("normal_font_size", 14)
	_testo_livello.add_theme_font_size_override("bold_font_size", 24)
	riquadro_livello.add_child(_testo_livello)


# ------------------------------------------------------------------ messaggi del server
func _su_stato(m: Dictionary) -> void:
	stato = m
	_scrivi_elenco()
	if diario.visible:
		_riempi_diario()


func _su_dialogo(m: Dictionary) -> void:
	_png_dialogo = int(m.get("npc", 0))
	_ultimo_dialogo = m
	_titolo_dialogo.text = String(m.get("n", ""))
	for c in _corpo_dialogo.get_children():
		c.queue_free()
	var consegne: Array = m.get("consegne", [])
	var offerte: Array = m.get("offerte", [])
	if consegne.is_empty() and offerte.is_empty():
		_etichetta(_corpo_dialogo, "«Per oggi non ho altro da chiederti. Torna domani: il regno ha sempre bisogno di qualcuno.»", GRIGIO, 13, 440)
	for v in consegne:
		_voce_dialogo(v, true)
	for v in offerte:
		_voce_dialogo(v, false)
	dialogo.visible = true
	Suoni.suona("clic", -10.0)


func _voce_dialogo(v: Dictionary, consegna: bool) -> void:
	var riquadro := PanelContainer.new()
	riquadro.add_theme_stylebox_override("panel", Hud.stile(Color(0.12, 0.1, 0.08, 0.9), (VERDE if consegna else Hud.ORO).darkened(0.4), 6))
	_corpo_dialogo.add_child(riquadro)
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 3)
	riquadro.add_child(c)
	var segno := "?" if consegna else "!"
	var tipo := "Incarico del giorno" if int(v.get("g", 0)) == 1 else "Missione"
	_etichetta(c, "%s  %s — %s" % [segno, tipo, String(v.ti)], VERDE if consegna else ORO_CHIARO, 16, 430)
	if not consegna:
		_etichetta(c, String(v.get("d", "")), Color(0.86, 0.84, 0.78), 13, 430)
		for o in v.get("ob", []):
			_etichetta(c, "•  %s%s" % [String(o.t), "" if int(o.n) <= 1 else "  (0/%d)" % int(o.n)], Color(0.8, 0.85, 0.9), 13, 430)
	_etichetta(c, "Premio: %s" % String(v.get("pr", "")), Color(0.95, 0.8, 0.45), 12, 430)
	var b := Button.new()
	b.text = "Consegna" if consegna else "Accetta"
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	var id := String(v.id)
	b.pressed.connect(func() -> void:
		Rete.manda({"t": "mis", "a": "consegna" if consegna else "accetta", "id": id, "npc": _png_dialogo})
		dialogo.visible = false)
	c.add_child(b)


func _su_evento(m: Dictionary) -> void:
	var k := String(m.get("k", ""))
	var hud = gioco.hud
	match k:
		"nuova":
			hud.avvisa(String(m.get("m", "")))
			hud.riga_chat(String(m.get("m", "")), ORO_CHIARO)
			if String(m.get("d", "")) != "":
				hud.riga_chat(String(m.d), Color(0.82, 0.8, 0.72))
			Suoni.suona("aura", -10.0, 1.3)
		"avanza":
			progresso.text = String(m.get("m", ""))
			progresso.modulate.a = 1.0
			_progresso_t = 2.2
		"pronta":
			hud.avvisa(String(m.get("m", "")))
			hud.riga_chat(String(m.get("m", "")), VERDE)
			Suoni.suona("raccolta", -6.0, 1.2)
		"fatta":
			hud.avvisa(String(m.get("m", "")))
			hud.riga_chat(String(m.get("m", "")), Hud.ORO)
			if String(m.get("d", "")) != "":
				hud.riga_chat(String(m.d), Color(0.86, 0.84, 0.76))
			Suoni.suona("moneta", -6.0)
		"via":
			hud.riga_chat(String(m.get("m", "")), GRIGIO)


func _su_sblocchi(m: Dictionary) -> void:
	var righe: Array = ["[center][b][color=#f0c860]Livello %d[/color][/b][/center]" % int(m.get("lvl", 1))]
	for t in m.get("m", []):
		righe.append("[color=#e8e2d0]•  %s[/color]" % String(t))
		gioco.hud.riga_chat("Livello %d — %s" % [int(m.get("lvl", 1)), String(t)], Color(0.95, 0.85, 0.55))
	if (m.get("m", []) as Array).is_empty():
		righe.append("[center][color=#c8c0b0]Più forte di prima.[/color][/center]")
	righe.append("[center][color=#8a8478](clic per chiudere)[/color][/center]")
	_testo_livello.text = "\n".join(PackedStringArray(righe))
	riquadro_livello.visible = true
	_livello_t = 9.0


# ------------------------------------------------------------------ elenco a lato
func _scrivi_elenco() -> void:
	var righe: Array = []
	var aperte: Array = stato.get("a", [])
	# prima la catena, poi gli incarichi
	aperte.sort_custom(func(a, b) -> bool: return int(a.get("g", 0)) < int(b.get("g", 0)))
	for v in aperte.slice(0, 5):
		var ok := int(v.get("ok", 0)) == 1
		var col := "#90e888" if ok else ("#f0c860" if int(v.get("g", 0)) == 0 else "#d8c8a0")
		righe.append("[b][color=%s]%s%s[/color][/b]" % [col, "◆ " if int(v.get("g", 0)) == 0 else "◇ ", String(v.ti)])
		if ok:
			righe.append("   [color=#90e888]✓ Torna da %s[/color]" % String(v.get("a", "")))
			continue
		for o in v.get("ob", []):
			var fatto := int(o.p) >= int(o.n)
			var testo := String(o.t)
			if int(o.n) > 1:
				testo += " %d/%d" % [int(o.p), int(o.n)]
			righe.append("   [color=%s]%s%s[/color]" % ["#80c878" if fatto else "#e8e4d8", "✓ " if fatto else "", testo])
	if aperte.size() > 5:
		righe.append("[color=#a09a8c]   …e altre %d nel diario (L)[/color]" % (aperte.size() - 5))
	var pross = stato.get("pross")
	if pross is Dictionary and aperte.filter(func(v) -> bool: return int(v.get("g", 0)) == 0).is_empty():
		if int(pross.get("ok", 0)) == 1:
			righe.append("[color=#f0c860]! %s ha una missione per te[/color]" % String(pross.da))
		else:
			righe.append("[color=#a09a8c]Prossima missione al livello %d[/color]" % int(pross.liv))
	var gg = stato.get("gg")
	if gg is Dictionary and int(gg.get("libere", 0)) > 0:
		righe.append("[color=#c8b890]◇ %d incarichi del giorno dallo Scrivano Ming[/color]" % int(gg.libere))
	var testo := "\n".join(PackedStringArray(righe))
	if testo != _firma_elenco:
		_firma_elenco = testo
		_testo_elenco.text = testo
	elenco.visible = not righe.is_empty()


# ------------------------------------------------------------------ diario
func _riempi_diario() -> void:
	for c in _corpo_diario.get_children():
		c.queue_free()
	var cat := int(stato.get("cat", 0))
	var tot := int(stato.get("tot", 1))
	_etichetta(_corpo_diario, "Cammino del regno: %d di %d missioni compiute" % [mini(cat, tot), tot], Hud.ORO, 15, 520)
	var barra := ProgressBar.new()
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(520, 8)
	barra.max_value = tot
	barra.value = cat
	barra.add_theme_stylebox_override("background", Hud.stile(Color(0, 0, 0, 0.6), Color(0, 0, 0, 0), 3))
	barra.add_theme_stylebox_override("fill", Hud.stile(Hud.ORO.darkened(0.2), Color(0, 0, 0, 0), 3))
	_corpo_diario.add_child(barra)
	var gg = stato.get("gg")
	if gg is Dictionary:
		_etichetta(_corpo_diario, "Incarichi di oggi: %d compiuti su %d (dallo Scrivano Ming, nei villaggi; nelle terre lontane dal Viandante Lu)" % [int(gg.fatte), int(gg.tot)], Color(0.85, 0.8, 0.65), 12, 520)
	var aperte: Array = stato.get("a", [])
	aperte.sort_custom(func(a, b) -> bool: return int(a.get("g", 0)) < int(b.get("g", 0)))
	if aperte.is_empty():
		_etichetta(_corpo_diario, "Nessuna missione aperta.", GRIGIO, 13, 520)
	for v in aperte:
		_corpo_diario.add_child(HSeparator.new())
		var ok := int(v.get("ok", 0)) == 1
		var testa := "%s  %s" % ["Incarico del giorno" if int(v.get("g", 0)) == 1 else "Livello %d" % int(v.get("liv", 1)), String(v.ti)]
		_etichetta(_corpo_diario, testa, VERDE if ok else ORO_CHIARO, 16, 520)
		_etichetta(_corpo_diario, String(v.get("d", "")), Color(0.84, 0.82, 0.76), 13, 520)
		for o in v.get("ob", []):
			var fatto := int(o.p) >= int(o.n)
			_etichetta(_corpo_diario, "%s  %s  %d/%d" % ["✓" if fatto else "•", String(o.t), int(o.p), int(o.n)], VERDE if fatto else Color(0.85, 0.88, 0.92), 13, 520)
		var dove = v.get("dove")
		var riga := "Consegna a: %s" % String(v.get("a", ""))
		if dove is Dictionary and not ok:
			riga += "   ·   obiettivo: %s (segnato sulla mappa, M)" % String(dove.get("n", ""))
		_etichetta(_corpo_diario, riga, Color(0.7, 0.85, 0.7), 12, 520)
		_etichetta(_corpo_diario, "Premio: %s" % String(v.get("pr", "")), Color(0.95, 0.8, 0.45), 12, 520)
		var b := Button.new()
		b.text = "Abbandona"
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		var id := String(v.id)
		b.pressed.connect(func() -> void: Rete.manda({"t": "mis", "a": "abbandona", "id": id}))
		_corpo_diario.add_child(b)
	var pross = stato.get("pross")
	if pross is Dictionary:
		_corpo_diario.add_child(HSeparator.new())
		var t := "Prossima missione: «%s»" % String(pross.ti)
		t += (" — parla con %s" % String(pross.da)) if int(pross.get("ok", 0)) == 1 else (" — dal livello %d" % int(pross.liv))
		_etichetta(_corpo_diario, t, Color(0.8, 0.76, 0.62), 13, 520)


# ------------------------------------------------------------------ obiettivi sulla mappa
## Punti delle missioni aperte: [ { p: Vector2 (x, z del mondo), n: nome, ok: completa } ]
func obiettivi() -> Array:
	var out: Array = []
	for v in stato.get("a", []):
		var d = v.get("dove")
		if d is Dictionary:
			out.append({"p": Vector2(float(d.x), float(d.z)), "n": String(d.get("n", "")), "ok": int(v.get("ok", 0)) == 1, "ti": String(v.ti)})
	return out


func _disegna_minimappa() -> void:
	if gioco == null or gioco.me == null:
		return
	var mm: Control = gioco.hud.minimappa
	var lato := mm.size.x
	var c := Vector2(lato, lato) * 0.5
	var scala := lato * 0.5 / 60.0
	var io := Vector2(gioco.me.x, gioco.me.z)
	for o in obiettivi():
		var rel: Vector2 = (o.p - io) * scala
		var col: Color = VERDE if o.ok else ORO_CHIARO
		if rel.length() < lato * 0.5 - 8.0:
			var p := c + rel
			mm.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(5, 0), p + Vector2(0, 6), p + Vector2(-5, 0)]), col)
			mm.draw_polyline(PackedVector2Array([p + Vector2(0, -6), p + Vector2(5, 0), p + Vector2(0, 6), p + Vector2(-5, 0), p + Vector2(0, -6)]), Color(0.1, 0.06, 0.0), 1.2)
		elif (o.p - io).length() < 2500.0:
			# fuori dalla minimappa: una freccia sul bordo nella sua direzione
			var dir: Vector2 = rel.normalized()
			var p := c + dir * (lato * 0.5 - 7.0)
			var lat := Vector2(dir.y, -dir.x)
			mm.draw_colored_polygon(PackedVector2Array([p + dir * 6.0, p - dir * 4.0 + lat * 5.0, p - dir * 4.0 - lat * 5.0]), col)


func disegna_mappa(mappa: MappaGrande) -> void:
	var f := ThemeDB.fallback_font
	for o in obiettivi():
		var p = mappa.punto_mappa(o.p.x, o.p.y)
		if p == null:
			continue
		var col: Color = VERDE if o.ok else ORO_CHIARO
		var t := Time.get_ticks_msec() * 0.004
		mappa.draw_arc(p, 9.0 + 2.0 * sin(t), 0, TAU, 24, col, 2.0)
		mappa.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(5, 0), p + Vector2(0, 6), p + Vector2(-5, 0)]), col)
		var testo := "%s: %s" % [o.ti, o.n]
		var larg := f.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		mappa.draw_string_outline(f, p + Vector2(-larg * 0.5, -14), testo, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0.05, 0.04, 0.03, 0.95))
		mappa.draw_string(f, p + Vector2(-larg * 0.5, -14), testo, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)


# ------------------------------------------------------------------ segni sopra i PNG
func _disegna_segni() -> void:
	if gioco == null or gioco.cam == null or gioco.me == null:
		return
	var png: Dictionary = stato.get("png", {})
	if png.is_empty():
		return
	var cam: Camera3D = gioco.cam
	var f := ThemeDB.fallback_font
	var t := Time.get_ticks_msec() * 0.003
	for v in gioco.ents.values():
		if not is_instance_valid(v):
			continue
		var e: Entita = v
		if e.tipo != "n":
			continue
		var kd := String(e.info.get("kd", ""))
		if kd != "" and kd != gioco.regno:
			continue
		var segno := String(png.get(String(e.info.get("role", "")), ""))
		if segno == "":
			continue
		var p3 := e.testa() + Vector3(0, 1.05 + 0.08 * sin(t + e.id), 0)
		var dist := p3.distance_to(cam.global_position)
		if dist > 70.0 or cam.is_position_behind(p3):
			continue
		var p := cam.unproject_position(p3)
		var misura := int(clampf(46.0 - dist * 0.35, 22.0, 44.0))
		var col := Color(1.0, 0.82, 0.2) if segno == "!" else Color(0.55, 0.95, 0.45)
		var larg := f.get_string_size(segno, HORIZONTAL_ALIGNMENT_LEFT, -1, misura).x
		segni.draw_circle(p + Vector2(0, -misura * 0.32), misura * 0.48, Color(0, 0, 0, 0.35))
		segni.draw_string_outline(f, p + Vector2(-larg * 0.5, 0), segno, HORIZONTAL_ALIGNMENT_LEFT, -1, misura, 7, Color(0.15, 0.08, 0.0, 0.95))
		segni.draw_string(f, p + Vector2(-larg * 0.5, 0), segno, HORIZONTAL_ALIGNMENT_LEFT, -1, misura, col)


func _process(dt: float) -> void:
	if gioco == null or gioco.me == null:
		return
	if segni != null:
		segni.queue_redraw()
	if _progresso_t > 0.0:
		_progresso_t -= dt
		progresso.modulate.a = clampf(_progresso_t / 0.5, 0.0, 1.0)
	if _livello_t > 0.0:
		_livello_t -= dt
		if _livello_t <= 0.0:
			riquadro_livello.visible = false
	# l'elenco scende sotto i riquadri della Prova e dell'arena, se ci sono
	var y := 246.0
	if gioco.hud.riq_prova.visible:
		y += gioco.hud.riq_prova.size.y + 8.0
	if gioco.viaggi != null and gioco.viaggi.riquadro_arena.visible:
		y += gioco.viaggi.riquadro_arena.size.y + 8.0
	elenco.offset_top = y
	# il dialogo si chiude se ci si allontana dal PNG
	if dialogo.visible and _png_dialogo != 0:
		var n = gioco.ents.get(_png_dialogo)
		if n == null or Vector2(n.x - gioco.me.x, n.z - gioco.me.z).length() > 10.0:
			dialogo.visible = false
