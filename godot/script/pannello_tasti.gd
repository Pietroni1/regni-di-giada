class_name PannelloTasti
extends PanelContainer
## Pagina delle impostazioni per riassegnare i tasti (tasti.gd). Clic su un tasto, poi si preme quello nuovo; se è già
## usato da un'altra azione i due si scambiano. Esc annulla. Le assegnazioni si salvano con le altre impostazioni.

var gioco
var _lista: VBoxContainer
var _avviso: Label
var _in_attesa := ""
var _bottoni: Dictionary = {}


func _ready() -> void:
	add_theme_stylebox_override("panel", Hud.stile(Color(0.07, 0.06, 0.06, 0.96), Hud.ORO.darkened(0.35), 8, 2))
	position = Vector2(420, 70)
	custom_minimum_size = Vector2(430, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var testa := HBoxContainer.new()
	v.add_child(testa)
	var t := Label.new()
	t.text = "Tasti"
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
	sc.custom_minimum_size = Vector2(410, 470)
	v.add_child(sc)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 3)
	sc.add_child(_lista)
	_avviso = Label.new()
	_avviso.add_theme_font_size_override("font_size", 12)
	_avviso.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	_avviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_avviso.text = "Clic su un tasto, poi premi quello nuovo (Esc annulla). Se è già usato i due si scambiano. Fissi: Esc, F1, F11 e le frecce."
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
			var g := Label.new()
			g.text = gruppo
			g.add_theme_color_override("font_color", Hud.ORO)
			g.add_theme_font_size_override("font_size", 14)
			_lista.add_child(g)
		var id := String(a[0])
		var riga := HBoxContainer.new()
		_lista.add_child(riga)
		var n := Label.new()
		n.text = String(a[1])
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.add_theme_font_size_override("font_size", 13)
		riga.add_child(n)
		var b := Button.new()
		b.custom_minimum_size = Vector2(110, 0)
		b.pressed.connect(func() -> void: _comincia(id))
		riga.add_child(b)
		_bottoni[id] = b
		_aggiorna(id)


func _aggiorna(id: String) -> void:
	var b: Button = _bottoni.get(id)
	if b == null:
		return
	b.text = "Premi un tasto…" if _in_attesa == id else Tasti.nome(id)
	var cambiato := Tasti.codice(id) != Tasti.predefinito(id)
	b.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45) if cambiato else Color(0.9, 0.88, 0.82))


func _comincia(id: String) -> void:
	var prima := _in_attesa
	_in_attesa = id
	if prima != "":
		_aggiorna(prima)
	_aggiorna(id)
	_avviso.text = "Premi il nuovo tasto per «%s» (Esc annulla)." % _nome_azione(id)


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
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = ev.physical_keycode
		get_viewport().set_input_as_handled()
		if k in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
			return
		var id := _in_attesa
		_in_attesa = ""
		if k == KEY_ESCAPE:
			_aggiorna(id)
			_avviso.text = "Annullato."
			return
		var altra := Tasti.assegna(id, k)
		if altra == "!":
			_avviso.text = "Quel tasto è riservato: scegline un altro."
			_aggiorna(id)
			return
		if altra != "":
			_avviso.text = "«%s» ora è %s; «%s» ha preso il vecchio tasto." % [_nome_azione(id), Tasti.nome_tasto(k), _nome_azione(altra)]
		else:
			_avviso.text = "«%s» ora è %s." % [_nome_azione(id), Tasti.nome_tasto(k)]
		_salva()
