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
var riq_solo: Control          # partita in solitaria (c'è solo se accanto all'eseguibile sta il server: vedi solo.gd)
var _solo := false             # il collegamento in corso è verso il server interno
var _solo_da := 0              # quando è partito il tentativo (ms)
var _solo_registrato := false
var _dentro := false           # accesso riuscito
var _arg: Dictionary = {}
var messaggio_iniziale := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var p := a.trim_prefix("--").split("=", true, 1)
		_arg[p[0]] = p[1] if p.size() > 1 else "1"
	_interfaccia()
	Rete.aperta.connect(_connesso)
	Rete.chiusa.connect(_disconnesso)
	Rete.su("auth_err", func(m: Dictionary) -> void:
		if _solo and not _dentro and not _solo_registrato:
			# prima partita su questo computer: l'account interno non c'è ancora
			_solo_registrato = true
			Rete.manda({"t": "register", "user": Solo.UTENTE, "pass": Solo.PASSWORD})
			return
		messaggio.text = String(m.get("m", "")))
	Rete.su("auth_ok", func(_m: Dictionary) -> void:
		_dentro = true
		if not _solo:
			Impostazioni.server = campo_server.text.strip_edges()
			Impostazioni.utente = campo_utente.text.strip_edges()
			Impostazioni.salva()
		riq_accesso.visible = false
		if riq_solo != null:
			riq_solo.visible = false
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
	elif _arg.has("solo") and Solo.disponibile():
		# prove automatiche del pacchetto: --solo=NomePersonaggio [--foto_inizio=1 fotografa prima la schermata]
		if _arg.has("foto_inizio"):
			await get_tree().process_frame
			await get_tree().process_frame
			await _foto("solo_inizio")
		_gioca_solo()


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
	if _arg.has("errore"):
		messaggio_iniziale = String(_arg.errore)
	titolo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titolo.add_theme_font_size_override("font_size", 44)
	titolo.add_theme_color_override("font_color", Hud.ORO)
	col.add_child(titolo)
	messaggio = Label.new()
	messaggio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	messaggio.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	messaggio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if Solo.disponibile() and not _arg.has("server"):
		# pacchetto «gioca da solo»: un tasto e basta; i campi del server restano per chi vuole giocare in rete
		riq_solo = VBoxContainer.new()
		riq_solo.add_theme_constant_override("separation", 10)
		col.add_child(riq_solo)
		var nota := Label.new()
		nota.text = "Partita in solitaria: il mondo gira su questo computer.\nNon serve Internet e non c'è niente da installare."
		nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		riq_solo.add_child(nota)
		var gioca := _bottone(riq_solo, "Gioca", _gioca_solo)
		gioca.custom_minimum_size = Vector2(0, 48)
		gioca.add_theme_font_size_override("font_size", 22)
		_bottone(riq_solo, "Gioca in rete con gli amici…", func() -> void:
			riq_solo.visible = false
			riq_accesso.visible = true)
	riq_accesso = VBoxContainer.new()
	riq_accesso.visible = riq_solo == null
	col.add_child(riq_accesso)
	campo_server = _campo(riq_accesso, "Server (chi ospita la partita: localhost:3000 sul suo PC, altrimenti il suo indirizzo)", Impostazioni.server)
	if OS.has_feature("web"):
		# nel browser il server è quello che ha servito la pagina: niente da scrivere
		campo_server.text = Rete.ospite_web()
		campo_server.visible = false
		(riq_accesso.get_child(campo_server.get_index() - 1) as Control).visible = false      # la sua etichetta
	campo_utente = _campo(riq_accesso, "Account", Impostazioni.utente)
	campo_pass = _campo(riq_accesso, "Password", "")
	campo_pass.secret = true
	campo_pass.text_submitted.connect(func(_t: String) -> void: _accedi(false))
	var riga := HBoxContainer.new()
	riq_accesso.add_child(riga)
	_bottone(riga, "Entra", func() -> void: _accedi(false))
	_bottone(riga, "Crea account", func() -> void: _accedi(true))
	if riq_solo != null:
		_bottone(riq_accesso, "← Partita in solitaria", func() -> void:
			riq_accesso.visible = false
			riq_solo.visible = true
			messaggio.text = "")

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
	_solo = false
	messaggio.text = "Connessione..."
	Rete.connetti(campo_server.text)


## Partita in solitaria: avvia il server che sta accanto all'eseguibile e ci si collega appena risponde.
func _gioca_solo() -> void:
	if _solo and not _dentro and Time.get_ticks_msec() - _solo_da < 45000 and _solo_da > 0:
		return                 # già in corso (secondo clic)
	_solo = true
	_solo_registrato = false
	_solo_da = Time.get_ticks_msec()
	messaggio.text = "Preparo il mondo..."
	Solo.avvia()
	Rete.connetti(Solo.indirizzo())


## Il server interno non ha (ancora) risposto: di solito sta finendo di avviarsi, e allora si riprova.
func _riprova_solo() -> void:
	if not Solo.in_piedi():
		# il processo non c'è più: porta presa da un altro programma (si prova la successiva) oppure non parte proprio
		if not Solo.porta_successiva() or not Solo.avvia():
			_solo_fallito()
			return
	elif Time.get_ticks_msec() - _solo_da > 45000:
		_solo_fallito()
		return
	await get_tree().create_timer(0.4).timeout
	if _solo and not _dentro:
		Rete.connetti(Solo.indirizzo())


func _solo_fallito() -> void:
	_solo = false
	_solo_da = 0
	Solo.porta = Solo.PORTA
	messaggio.text = "Il mondo non si avvia. Controlla che la cartella «server_locale» sia accanto al gioco (va estratto tutto lo zip) e che l'antivirus non abbia bloccato node.exe.\nDettagli: %s" % Solo.cartella_salvataggi().path_join("server.log")


func _connesso() -> void:
	if _solo:
		Rete.manda({"t": "login", "user": Solo.UTENTE, "pass": Solo.PASSWORD})
		return
	Rete.manda({"t": "register" if _registra else "login", "user": campo_utente.text.strip_edges(), "pass": campo_pass.text})


func _disconnesso() -> void:
	if _solo and not _dentro:
		_riprova_solo()
		return
	messaggio.text = "Il server %s non risponde. È avviato? (npm.cmd start sul PC di chi ospita)" % campo_server.text
	if OS.has_feature("web"):
		messaggio.text = "Il server non risponde: riprova fra poco o ricarica la pagina."
	if _solo:
		messaggio.text = "Il mondo si è fermato. Premi di nuovo Gioca."
	if _dentro and gioco == null:
		# caduto dalla scelta del personaggio: si torna all'inizio
		_dentro = false
		_solo = false
		riq_scelta.visible = false
		if riq_solo != null:
			riq_solo.visible = true
		else:
			riq_accesso.visible = true
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
	if _arg.has("solo") and _solo and gioco == null:
		# prova automatica del pacchetto: alla prima partita crea il personaggio, poi entra
		if personaggi.is_empty():
			Rete.manda({"t": "create", "name": String(_arg.solo), "cls": "lama", "kd": Dati.KINGDOMS.keys()[0], "sex": "m"})
		else:
			elenco.select(0)
			_gioca()
		return
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
## attendi N · reale N · aspetta_oggetto id · finche_vuoto raggio · finche_oggetti N raggio · foto nome · tecnica id · suprema · bersaglio · visuale yaw pitch distanza · attacca · guarda · butta id...
func _prova_automatica() -> void:
	await _attendi(1.5)
	for voce in String(_arg.get("comandi", "attendi 2;foto prova")).split(";"):
		var v := voce.strip_edges()
		if v.is_empty():
			continue
		var p := v.split(" ")
		if v.begins_with("/"):
			Rete.manda({"t": "chat", "m": v})
			for i in range(int(_arg.get("attesa_comandi", "3"))):
				await get_tree().process_frame
			continue
		match p[0]:
			"attendi": await _attendi(float(p[1]))
			"stat":
				# misura del peso: media su 12 fotogrammi di chiamate di disegno, triangoli e tempo del fotogramma
				var t0 := Time.get_ticks_usec()
				for _k in range(12):
					await get_tree().process_frame
				var ms := (Time.get_ticks_usec() - t0) / 12000.0
				print("STAT %s: %.0f ms/fotogramma, %d disegni, %d triangoli, %d oggetti, %d nodi" % [p[1] if p.size() > 1 else "",
						ms, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
						int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
						int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
						int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
			"foto": await _foto(p[1])
			"vicino":
				# vicino x z: aspetta (fino a 15 minuti veri) che il personaggio sia entro 4 m dal punto (dopo un /tp, col server lento)
				var lim4 := Time.get_ticks_msec() + 900000
				while Time.get_ticks_msec() < lim4 and Vector2(gioco.me.x - float(p[1]), gioco.me.z - float(p[2])).length() > 4.0:
					await get_tree().process_frame
			"tecnica": gioco.usa_tecnica(p[1])
			"premi", "mouse":
				# premi codice [maiusc] [ctrl] [alt]  ·  mouse indice [maiusc]…: un comando vero, come dalla tastiera o dal mouse
				var evento: InputEventWithModifiers
				if p[0] == "premi":
					var ek := InputEventKey.new()
					ek.physical_keycode = int(p[1]) as Key
					ek.keycode = int(p[1]) as Key
					evento = ek
				else:
					var em := InputEventMouseButton.new()
					em.button_index = int(p[1]) as MouseButton
					em.position = Vector2(8, 8)
					evento = em
				evento.shift_pressed = "maiusc" in p
				evento.ctrl_pressed = "ctrl" in p
				evento.alt_pressed = "alt" in p
				evento.set("pressed", true)
				Input.parse_input_event(evento)
				await get_tree().process_frame
				await get_tree().process_frame
				var su := evento.duplicate()
				su.set("pressed", false)
				Input.parse_input_event(su)
				await get_tree().process_frame
			"mappa": gioco.mappa.apri_chiudi()
			"diario": gioco.missioni.apri_chiudi()
			"imprese": gioco.altolivello.apri_imprese()
			"esci_prova": Rete.manda({"t": "tleave"})
			"spendi":
				# spendi vit|str|dex|int N: spende N punti statistica (per le prove con personaggi alzati con /level)
				for _k in range(int(p[2])):
					Rete.manda({"t": "stat", "s": p[1]})
			"sociale": await gioco.sociale.copione(p)   # scambio, deposito, amici, tasti (sociale.gd)
			"missione":
				# missione accetta|consegna id: risponde al dialogo delle missioni aperto («*» = la prima voce del dialogo)
				var mid := p[2]
				var chiave := "consegne" if p[1] == "consegna" else "offerte"
				var scade := Time.get_ticks_msec() + 300000
				while Time.get_ticks_msec() < scade and (gioco.missioni._ultimo_dialogo.get(chiave, []) as Array).is_empty():
					await get_tree().process_frame
				if mid == "*":
					var voci: Array = gioco.missioni._ultimo_dialogo.get("consegne" if p[1] == "consegna" else "offerte", [])
					mid = String(voci[0].id) if not voci.is_empty() else ""
				Rete.manda({"t": "mis", "a": p[1], "id": mid, "npc": gioco.missioni._png_dialogo})
				gioco.missioni._ultimo_dialogo = {}
			"finestra": gioco.hud.finestre.apri_chiudi(p[1])
			"png":
				# il PNG di quel ruolo più vicino
				var vicino: Entita = null
				for e: Entita in gioco.ents.values():
					if e.tipo == "n" and String(e.info.get("role", "")) == p[1]:
						if vicino == null or Vector2(e.x - gioco.me.x, e.z - gioco.me.z).length() < Vector2(vicino.x - gioco.me.x, vicino.z - gioco.me.z).length():
							vicino = e
				if vicino != null:
					Rete.manda({"t": "npc", "id": vicino.id})
			"sella": Rete.manda({"t": "mount"})
			"viaggio":
				# viaggio selva|distesa|arena|torna: con la Guida dei Sentieri o l'Araldo più vicino
				for e: Entita in gioco.ents.values():
					if e.tipo == "n" and String(e.info.get("role", "")) in ["guida", "araldo"] and Vector2(e.x - gioco.me.x, e.z - gioco.me.z).length() < 8.0:
						Rete.manda({"t": "viaggio", "npc": e.id, "a": "torna" if p[1] == "torna" else "vai", "m": p[1]})
						break
			"interrompi":
				# aspetta che il bersaglio inizi un lancio (fino a 20 s), fotografa la barra e poi usa l'interruzione
				var scade := Time.get_ticks_msec() + 20000
				while Time.get_ticks_msec() < scade and not (gioco.bersaglio != null and gioco.lanci_nemici.has(gioco.bersaglio.id)):
					await get_tree().process_frame
				await _foto(p[2] + "_lancio")
				gioco.usa_tecnica(p[1])
			"accetta":
				# aspetta (fino a 5 minuti veri) che arrivi l'invito, poi lo accetta come il pulsante del riquadro
				var fino := Time.get_ticks_msec() + 300000
				while not gioco.hud.riq_invito.visible and Time.get_ticks_msec() < fino:
					await get_tree().process_frame
				Rete.manda({"t": "preply", "ok": true})
				gioco.hud.riq_invito.visible = false
			"scegli":
				gioco.hud.finestre.scelta = int(p[1])
				gioco.hud.finestre.aggiorna()
			"potenzia": gioco.hud.finestre._potenzia(false)
			"usa":
				# fra più copie dello stesso oggetto si usa quella più potenziata
				var lista: Array = gioco.inv.get("inv", [])
				var scelta := -1
				for j in range(lista.size()):
					if lista[j] is Dictionary and String(lista[j].id) == p[1]:
						if scelta < 0 or int(lista[j].get("up", 0)) > int(lista[scelta].get("up", 0)):
							scelta = j
				if scelta >= 0:
					Rete.manda({"t": "use", "i": scelta})
			"chiudi": gioco.hud.finestre.chiudi_tutto()
			"raccogli": gioco._raccogli()
			"ricompense": gioco._su_dg_reward({"got": ["Essenza Celeste x3", "Gemma Perfetta di Rubino", "Pietra dell'Affinamento x2", "Tomo della Tecnica", "9.000 tael"]})
			"reale":
				# reale N: aspetta N secondi veri (il server, sotto carico, risponde con molto ritardo rispetto ai fotogrammi)
				var fine := Time.get_ticks_msec() + int(float(p[1]) * 1000.0)
				while Time.get_ticks_msec() < fine:
					await get_tree().process_frame
			"finche_vuoto":
				# finche_vuoto raggio: aspetta (fino a 3 minuti veri) che non resti nessun oggetto a terra entro il raggio (raccolti)
				var lim3 := Time.get_ticks_msec() + 180000
				while Time.get_ticks_msec() < lim3:
					var restano := 0
					for e: Entita in gioco.ents.values():
						if e != null and e.tipo == "d" and Vector2(e.x - gioco.me.x, e.z - gioco.me.z).length() <= float(p[1]):
							restano += 1
					if restano == 0:
						break
					await get_tree().process_frame
			"aspetta_oggetto":
				# aspetta_oggetto id: aspetta (fino a 3 minuti veri) che l'oggetto sia nell'inventario
				var lim2 := Time.get_ticks_msec() + 180000
				while Time.get_ticks_msec() < lim2:
					var trovato := false
					for q in gioco.inv.get("inv", []):
						if q is Dictionary and String(q.id) == p[1]:
							trovato = true
					if trovato:
						break
					await get_tree().process_frame
			"finche_oggetti":
				# finche_oggetti N raggio: aspetta (fino a 3 minuti veri) che N oggetti a terra siano visibili entro il raggio dal personaggio
				var lim := Time.get_ticks_msec() + 180000
				while Time.get_ticks_msec() < lim:
					var quanti := 0
					for e: Entita in gioco.ents.values():
						if e != null and e.tipo == "d" and Vector2(e.x - gioco.me.x, e.z - gioco.me.z).length() <= float(p[2]):
							quanti += 1
					if quanti >= int(p[1]):
						break
					await get_tree().process_frame
			"butta":
				# butta id [id ...]: getta a terra una copia (la più potenziata) di ciascun oggetto, per provare gli oggetti caduti.
				# Aspetta (fino a 3 minuti) che l'oggetto compaia nell'inventario.
				for k in range(1, p.size()):
					var sc := -1
					var limite := Time.get_ticks_msec() + 180000
					while sc < 0 and Time.get_ticks_msec() < limite:
						var lis: Array = gioco.inv.get("inv", [])
						for j in range(lis.size()):
							if lis[j] is Dictionary and String(lis[j].id) == p[k]:
								if sc < 0 or int(lis[j].get("up", 0)) > int(lis[sc].get("up", 0)):
									sc = j
						if sc < 0:
							await get_tree().process_frame
					if sc >= 0:
						Rete.manda({"t": "drop", "i": sc})
			"togli":
				# togli body|head|feet|weapon: rimette nel primo posto libero dell'inventario quel pezzo dell'equipaggiamento
				var libero: int = (gioco.inv.get("inv", []) as Array).find(null)
				if libero >= 0:
					Rete.manda({"t": "mv", "a": {"k": "e", "i": p[1]}, "b": {"k": "i", "i": libero}})
			"prova":
				for e: Entita in gioco.ents.values():
					if e.tipo == "n" and String(e.info.get("role", "")) == "custode":
						Rete.manda({"t": "trial", "npc": e.id, "a": p[1], "p": p[2] if p.size() > 2 else "cripta"})
						break
			"prova_tp":
				# prova_tp x z: dentro una Prova, teletrasporto GM in coordinate della pianta (shared/prove.js)
				if gioco.cripta != null:
					Rete.manda({"t": "chat", "m": "/tp %.1f %.1f" % [gioco.cripta.origine.x + float(p[1]), gioco.cripta.origine.y + float(p[2])]})
			"finche_prova":   # aspetta (fino a 5 minuti veri) di essere dentro una Prova
				var fino_p := Time.get_ticks_msec() + 300000
				while gioco.cripta == null and Time.get_ticks_msec() < fino_p:
					await get_tree().process_frame
			"impara": Rete.manda({"t": "skup", "s": p[1]})
			"cammina": gioco.intento = {"tipo": "muovi", "x": float(p[1]), "z": float(p[2])}
			"suprema": gioco.usa_suprema()
			"bersaglio":
				gioco.bersaglio = gioco.ostile_vicino()
				if gioco.bersaglio != null:
					gioco.me.guarda(gioco.bersaglio)
			"finche_gruppo":   # finche_gruppo N: aspetta (fino a 5 minuti veri) un gruppo di almeno N membri
				var fino_g := Time.get_ticks_msec() + 300000
				while gioco.gruppo.get("members", []).size() < int(p[1]) and Time.get_ticks_msec() < fino_g:
					await get_tree().process_frame
			"finche_vita":   # finche_vita < 50 | > 60: aspetta (fino a 5 minuti veri) che la propria vita in % passi la soglia
				var fino_v := Time.get_ticks_msec() + 300000
				while Time.get_ticks_msec() < fino_v:
					var pv := float(gioco.io.get("hp", 0)) / maxf(1.0, float(gioco.io.get("mhp", 1))) * 100.0
					if (p[1] == "<" and pv < float(p[2])) or (p[1] == ">" and pv > float(p[2])):
						break
					await get_tree().process_frame
			"finche_cura":   # aspetta (fino a 5 minuti veri) un balzo della propria vita di oltre il 15% (una cura, non la rigenerazione)
				var fino_c := Time.get_ticks_msec() + 300000
				var prima := float(gioco.io.get("hp", 0))
				while Time.get_ticks_msec() < fino_c:
					var ora_v := float(gioco.io.get("hp", 0))
					if ora_v - prima > 0.15 * float(gioco.io.get("mhp", 1)):
						break
					prima = ora_v
					await get_tree().process_frame
			"seleziona":   # seleziona nome: un'entità (compagno, PNG...) per nome
				for e: Entita in gioco.ents.values():
					if e.nome == p[1]:
						gioco.bersaglio = e
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
