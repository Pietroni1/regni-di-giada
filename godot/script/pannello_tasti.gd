class_name PannelloTasti
extends PanelContainer
## Pagina per personalizzare i tasti (tasti.gd). Ogni azione ha due caselle: tasto principale e alternativo. Clic su una
## casella, poi si preme il comando nuovo: un tasto, anche con Maiusc / Ctrl / Alt, oppure un tasto del mouse (centrale
## o laterali). Se era già di un'altra azione le viene tolto. Esc annulla, Backspace o clic destro svuotano la casella.
## Le scelte si salvano con le altre impostazioni.

const GUIDA := "Clic su una casella, poi premi il comando nuovo: un tasto (anche con Maiusc, Ctrl o Alt) o un tasto del mouse (centrale, laterali). Esc annulla; Backspace o clic destro svuotano la casella."

var gioco
var _lista: VBoxContainer
var _avviso: Label
var _in_attesa := ""           # «id:posto» della casella che aspetta un comando
var _bottoni: Dictionary = {}  # «id:posto» → Button


func _ready() -> void:
	add_theme_stylebox_override("panel", Hud.stile(Color(0.07, 0.06, 0.06, 0.96), Hud.ORO.darkened(0.35), 8, 2))
	position = Vector2(380, 60)
	custom_minimum_size = Vector2(540, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var testa := HBoxContainer.new()
	v.add_child(testa)
	var t := Label.new()
	t.text = "Personalizza i tasti"
	t.add_theme_color_override("font_color", Hud.ORO)
	t.add_theme_font_size_override("font_size", 18)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	t.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion and ev.button_mask & MOUSE_BUTTON_MASK_LEFT:
			position += ev.relative)
	testa.add_child(t)
	var x := Button.new()
	x.text = "✕"
	x.flat = true
	x.pressed.connect(func() -> void:
		_in_attesa = ""
		visible = false)
	testa.add_child(x)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(520, 470)
	v.add_child(sc)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 3)
	sc.add_child(_lista)
	_avviso = Label.new()
	_avviso.add_theme_font_size_override("font_size", 12)
	_avviso.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	_avviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_avviso.custom_minimum_size = Vector2(0, 52)
	_avviso.text = GUIDA
	v.add_child(_avviso)
	var ripr := Button.new()
	ripr.text = "Ripristina i tasti predefiniti"
	ripr.pressed.connect(func() -> void:
		Tasti.ripristina()
		_salva()
		_avviso.text = "Tasti predefiniti ripristinati.")
	v.add_child(ripr)
	riempi()


func riempi() -> void:
	if _lista == null:
		return
	for c in _lista.get_children():
		c.queue_free()
	_bottoni.clear()
	var gruppo := ""
	for a in Tasti.AZIONI:
		if String(a[2]) != gruppo:
			gruppo = String(a[2])
			var rg := HBoxContainer.new()
			_lista.add_child(rg)
			var g := Label.new()
			g.text = gruppo
			g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.add_theme_color_override("font_color", Hud.ORO)
			g.add_theme_font_size_override("font_size", 14)
			rg.add_child(g)
			for testo in ["Tasto", "Alternativo"]:
				var e := Label.new()
				e.text = testo
				e.custom_minimum_size = Vector2(128, 0)
				e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				e.add_theme_font_size_override("font_size", 11)
				e.add_theme_color_override("font_color", Color(0.62, 0.6, 0.55))
				rg.add_child(e)
		var id := String(a[0])
		var riga := HBoxContainer.new()
		_lista.add_child(riga)
		var n := Label.new()
		n.text = String(a[1])
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.add_theme_font_size_override("font_size", 13)
		riga.add_child(n)
		for posto in range(2):
			var chiave := "%s:%d" % [id, posto]
			var b := Button.new()
			b.custom_minimum_size = Vector2(128, 0)
			b.clip_text = true
			b.tooltip_text = "Clic: cambia  ·  Clic destro: svuota"
			b.pressed.connect(func() -> void: _comincia(chiave))
			b.gui_input.connect(func(ev: InputEvent) -> void:
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
					_svuota(chiave))
			riga.add_child(b)
			_bottoni[chiave] = b
			_aggiorna(chiave)
	_mancanti()


func _id(chiave: String) -> String:
	return chiave.get_slice(":", 0)


func _posto(chiave: String) -> int:
	return int(chiave.get_slice(":", 1))


func _aggiorna(chiave: String) -> void:
	var b: Button = _bottoni.get(chiave)
	if b == null:
		return
	var id := _id(chiave)
	var posto := _posto(chiave)
	b.text = "Premi…" if _in_attesa == chiave else Tasti.nome_tasto(int(Tasti.codici(id)[posto]))
	var colore := Color(1.0, 0.86, 0.45) if Tasti.cambiata(id, posto) else Color(0.9, 0.88, 0.82)
	if int(Tasti.codici(id)[posto]) == KEY_NONE and _in_attesa != chiave:
		colore = Color(0.5, 0.48, 0.45)
	b.add_theme_color_override("font_color", colore)


func _comincia(chiave: String) -> void:
	var prima := _in_attesa
	_in_attesa = chiave
	if prima != "":
		_aggiorna(prima)
	_aggiorna(chiave)
	_avviso.text = "Premi il comando per «%s»%s. Esc annulla, Backspace svuota." % [_nome_azione(_id(chiave)), " (alternativo)" if _posto(chiave) == 1 else ""]


func _svuota(chiave: String) -> void:
	_in_attesa = ""
	Tasti.togli(_id(chiave), _posto(chiave))
	_salva()
	_avviso.text = "«%s»: casella svuotata." % _nome_azione(_id(chiave))
	_mancanti()


## Avvisa se qualche azione è rimasta senza nessun tasto.
func _mancanti() -> void:
	var m := Tasti.senza_tasto()
	if not m.is_empty():
		_avviso.text += "\nSenza tasto: %s." % ", ".join(m)


func _nome_azione(id: String) -> String:
	for a in Tasti.AZIONI:
		if a[0] == id:
			return String(a[1])
	return id


func _salva() -> void:
	Tasti.aggiorna_testi()
	Impostazioni.salva()
	riempi()
	if gioco != null and gioco.hud != null:
		for t in gioco.hud.tasti:
			t.queue_redraw()


func _input(ev: InputEvent) -> void:
	if _in_attesa == "" or not visible:
		return
	var premuto: bool = (ev is InputEventKey and ev.pressed and not ev.echo) or (ev is InputEventMouseButton and ev.pressed)
	if not premuto:
		return
	if ev is InputEventMouseButton and not Tasti.NOMI_TOPO.has(int(ev.button_index)):
		return                     # sinistro, destro e rotella restano del gioco (e servono a cliccare un'altra casella)
	get_viewport().set_input_as_handled()
	var chiave := _in_attesa
	var id := _id(chiave)
	if ev is InputEventKey and ev.physical_keycode == KEY_ESCAPE:
		_in_attesa = ""
		_aggiorna(chiave)
		_avviso.text = "Annullato."
		return
	if ev is InputEventKey and ev.physical_keycode == KEY_BACKSPACE:
		_svuota(chiave)
		return
	var k := Tasti.comando_evento(ev)
	if k == KEY_NONE:
		return                     # Maiusc, Ctrl o Alt da soli: si aspetta il tasto che li segue
	_in_attesa = ""
	var persa := Tasti.assegna(id, _posto(chiave), k)
	if persa == "!":
		_avviso.text = "Quel tasto è riservato: scegline un altro."
		_aggiorna(chiave)
		return
	_salva()
	if persa != "":
		_avviso.text = "«%s» ora è %s (tolto a «%s»)." % [_nome_azione(id), Tasti.nome_tasto(k), _nome_azione(persa)]
	else:
		_avviso.text = "«%s» ora è %s." % [_nome_azione(id), Tasti.nome_tasto(k)]
	_mancanti()
