extends Node
## Avvio: schermata d'accesso, scelta del personaggio, poi la partita.
## Per le prove automatiche: argomenti dopo `--`, per esempio
##   godot --path godot -- --server=localhost:3999 --auto=admin:password:Nome --comandi="/level 30;/via fulmine" --foto=cartella

var gioco: Gioco = null
var schermo: Control
var messaggio: Label
var campo_server: LineEdit
var campo_utente: LineEdit
var campo_pass: LineEdit
var elenco: ItemList
var personaggi: Array = []
var riq_accesso: Control
var riq_scelta: Control
var campo_nome: LineEdit
var scelta_classe: OptionButton
var scelta_regno: OptionButton
var scelta_sesso: OptionButton
var _registra := false
var _arg: Dictionary = {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var p := a.trim_prefix("--").split("=", true, 1)
		_arg[p[0]] = p[1] if p.size() > 1 else "1"
	_interfaccia()
	Rete.aperta.connect(_connesso)
	Rete.chiusa.connect(_disconnesso)
	Rete.su("auth_err", func(m: Dictionary) -> void: messaggio.text = String(m.get("m", "")))
	Rete.su("auth_ok", func(_m: Dictionary) -> void:
		riq_accesso.visible = false
		riq_scelta.visible = true
		messaggio.text = "")
	Rete.su("chars", _su_personaggi)
	Rete.su("enter", _su_entra)
	if _arg.has("auto"):
		var p := String(_arg.auto).split(":")
		campo_utente.text = p[0]
		campo_pass.text = p[1]
		if _arg.has("server"):
			campo_server.text = String(_arg.server)
		_accedi(false)


func _interfaccia() -> void:
	var strato := CanvasLayer.new()
	strato.layer = 5
	add_child(strato)
	schermo = ColorRect.new()
	(schermo as ColorRect).color = Color(0.07, 0.06, 0.07)
	schermo.set_anchors_preset(Control.PRESET_FULL_RECT)
	strato.add_child(schermo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	schermo.add_child(centro)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(380, 0)
	centro.add_child(col)
	var titolo := Label.new()
	titolo.text = "Regni di Giada"
	titolo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titolo.add_theme_font_size_override("font_size", 44)
	titolo.add_theme_color_override("font_color", Hud.ORO)
	col.add_child(titolo)
	messaggio = Label.new()
	messaggio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	messaggio.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	messaggio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	riq_accesso = VBoxContainer.new()
	col.add_child(riq_accesso)
	campo_server = _campo(riq_accesso, "Server", "localhost:3000")
	campo_utente = _campo(riq_accesso, "Account", "")
	campo_pass = _campo(riq_accesso, "Password", "")
	campo_pass.secret = true
	campo_pass.text_submitted.connect(func(_t: String) -> void: _accedi(false))
	var riga := HBoxContainer.new()
	riq_accesso.add_child(riga)
	_bottone(riga, "Entra", func() -> void: _accedi(false))
	_bottone(riga, "Crea account", func() -> void: _accedi(true))

	riq_scelta = VBoxContainer.new()
	riq_scelta.visible = false
	col.add_child(riq_scelta)
	elenco = ItemList.new()
	elenco.custom_minimum_size = Vector2(380, 150)
	elenco.item_activated.connect(func(_i: int) -> void: _gioca())
	riq_scelta.add_child(elenco)
	_bottone(riq_scelta, "Entra nel mondo", _gioca)
	var sep := HSeparator.new()
	riq_scelta.add_child(sep)
	campo_nome = _campo(riq_scelta, "Nuovo personaggio", "")
	var riga2 := HBoxContainer.new()
	riq_scelta.add_child(riga2)
	scelta_classe = OptionButton.new()
	for c in Dati.CLASSES:
		scelta_classe.add_item(String(Dati.CLASSES[c].name))
		scelta_classe.set_item_metadata(scelta_classe.item_count - 1, c)
	riga2.add_child(scelta_classe)
	scelta_regno = OptionButton.new()
	for k in Dati.KINGDOMS:
		scelta_regno.add_item(String(Dati.KINGDOMS[k].short))
		scelta_regno.set_item_metadata(scelta_regno.item_count - 1, k)
	riga2.add_child(scelta_regno)
	scelta_sesso = OptionButton.new()
	scelta_sesso.add_item("Uomo")
	scelta_sesso.add_item("Donna")
	riga2.add_child(scelta_sesso)
	_bottone(riq_scelta, "Crea personaggio", func() -> void:
		Rete.manda({"t": "create", "name": campo_nome.text.strip_edges(), "cls": scelta_classe.get_selected_metadata(), "kd": scelta_regno.get_selected_metadata(), "sex": "f" if scelta_sesso.selected == 1 else "m"}))
	col.add_child(messaggio)


func _campo(genitore: Control, etichetta: String, valore: String) -> LineEdit:
	var l := Label.new()
	l.text = etichetta
	genitore.add_child(l)
	var c := LineEdit.new()
	c.text = valore
	genitore.add_child(c)
	return c


func _bottone(genitore: Control, testo: String, azione: Callable) -> Button:
	var b := Button.new()
	b.text = testo
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(azione)
	genitore.add_child(b)
	return b


func _accedi(registra: bool) -> void:
	_registra = registra
	messaggio.text = "Connessione..."
	Rete.connetti(campo_server.text)


func _connesso() -> void:
	Rete.manda({"t": "register" if _registra else "login", "user": campo_utente.text.strip_edges(), "pass": campo_pass.text})


func _disconnesso() -> void:
	messaggio.text = "Connessione al server non riuscita o interrotta."
	if gioco != null:
		gioco.queue_free()
		gioco = null
		Rete.togli_gestori()
		get_tree().reload_current_scene()


func _su_personaggi(m: Dictionary) -> void:
	personaggi = m.get("list", [])
	elenco.clear()
	for c in personaggi:
		elenco.add_item("%s  —  %s livello %d  (%s)" % [c.name, Dati.CLASSES[c.cls].name, int(c.lvl), Dati.KINGDOMS[c.kd].short])
	if not personaggi.is_empty():
		elenco.select(0)
	if _arg.has("auto") and gioco == null:
		var voluto := String(_arg.auto).split(":")[2] if String(_arg.auto).split(":").size() > 2 else ""
		for i in range(personaggi.size()):
			if String(personaggi[i].name) == voluto or voluto.is_empty():
				elenco.select(i)
				_gioca()
				return


func _gioca() -> void:
	var sel := elenco.get_selected_items()
	if sel.is_empty() or gioco != null:
		return
	gioco = Gioco.new()
	add_child(gioco)
	Rete.manda({"t": "play", "id": int(personaggi[sel[0]].id)})


func _su_entra(m: Dictionary) -> void:
	schermo.visible = false
	gioco.entra(m)
	if _arg.has("comandi") or _arg.has("foto"):
		_prova_automatica()


# ------------------------------------------------------------------ prove automatiche (immagini senza intervento)
func _attendi(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var cartella := String(_arg.get("foto", "user://"))
	get_viewport().get_texture().get_image().save_png(cartella.path_join(nome + ".png"))
	print("foto: ", nome)


## Copione: voci separate da «;». Una voce che inizia con «/» è un comando di chat; le altre:
## attendi N · foto nome · tecnica id · suprema · bersaglio · visuale yaw pitch distanza · attacca · guarda
func _prova_automatica() -> void:
	await _attendi(1.5)
	for voce in String(_arg.get("comandi", "attendi 2;foto prova")).split(";"):
		var v := voce.strip_edges()
		if v.is_empty():
			continue
		var p := v.split(" ")
		if v.begins_with("/"):
			Rete.manda({"t": "chat", "m": v})
			for i in range(3):
				await get_tree().process_frame
			continue
		match p[0]:
			"attendi": await _attendi(float(p[1]))
			"foto": await _foto(p[1])
			"tecnica": gioco.usa_tecnica(p[1])
			"finestra": gioco.hud.finestre.apri_chiudi(p[1])
			"png":
				for e: Entita in gioco.ents.values():
					if e.tipo == "n" and String(e.info.get("role", "")) == p[1]:
						Rete.manda({"t": "npc", "id": e.id})
						break
			"sella": Rete.manda({"t": "mount"})
			"accetta": Rete.manda({"t": "preply", "ok": true})
			"scegli":
				gioco.hud.finestre.scelta = int(p[1])
				gioco.hud.finestre.aggiorna()
			"potenzia": gioco.hud.finestre._potenzia(false)
			"usa":
				var lista: Array = gioco.inv.get("inv", [])
				for j in range(lista.size()):
					if lista[j] is Dictionary and String(lista[j].id) == p[1]:
						Rete.manda({"t": "use", "i": j})
						break
			"prova":
				for e: Entita in gioco.ents.values():
					if e.tipo == "n" and String(e.info.get("role", "")) == "custode":
						Rete.manda({"t": "trial", "npc": e.id, "a": p[1]})
						break
			"impara": Rete.manda({"t": "skup", "s": p[1]})
			"cammina": gioco.intento = {"tipo": "muovi", "x": float(p[1]), "z": float(p[2])}
			"suprema": gioco.usa_suprema()
			"bersaglio":
				gioco.bersaglio = gioco.ostile_vicino()
				if gioco.bersaglio != null:
					gioco.me.guarda(gioco.bersaglio)
			"attacca":
				if gioco.bersaglio != null:
					gioco.intento = {"tipo": "attacco", "id": gioco.bersaglio.id}
			"visuale":
				gioco.yaw = float(p[1])
				gioco.pitch = float(p[2])
				gioco.distanza = float(p[3])
			"dietro":
				gioco.yaw = gioco.me.r + PI + (float(p[1]) if p.size() > 1 else 0.0)
	print("prova finita")
	get_tree().quit()
