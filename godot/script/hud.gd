class_name Hud
extends CanvasLayer
## Interfaccia di gioco: riquadri del giocatore e del bersaglio, barra rapida, chat, targhette sopra le teste.

const ORO := Color(0.86, 0.72, 0.40)
const SFONDO := Color(0.06, 0.05, 0.05, 0.82)
const RUOLI := {"accumulo": Color(0.35, 0.80, 0.40), "medio": Color(0.90, 0.75, 0.30), "potente": Color(0.90, 0.28, 0.22)}

var gioco                       # Gioco (non tipizzato per evitare il riferimento circolare)
var radice: Control
var nome_io: Label
var vita: ProgressBar
var vita_txt: Label
var risorsa: ProgressBar
var risorsa_txt: Label
var punti: Label
var slancio: HBoxContainer
var suprema: ProgressBar
var riq_bersaglio: PanelContainer
var nome_b: Label
var vita_b: ProgressBar
var vita_b_txt: Label
var postura_b: ProgressBar
var tasti: Array = []
var lancio: ProgressBar
var lancio_txt: Label
var chat: RichTextLabel
var scrivi: LineEdit
var avviso: Label
var zona: Label
var morte: PanelContainer
var targhette: Control
var finestre: Finestre
var minimappa: Control
var numeri: Array = []          # numeri di danno che salgono: {p: Vector3, t: String, c: Color, eta: float, g: float}
var _avviso_t := 0.0


static func stile(colore: Color, bordo := Color(0, 0, 0, 0), raggio := 4, spessore := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = colore
	s.set_corner_radius_all(raggio)
	if bordo.a > 0.0:
		s.border_color = bordo
		s.set_border_width_all(spessore)
	s.set_content_margin_all(6)
	return s


func _barra(colore: Color, alta := 18) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, alta)
	b.add_theme_stylebox_override("background", stile(Color(0, 0, 0, 0.65), Color(0, 0, 0, 0.9), 3))
	b.add_theme_stylebox_override("fill", stile(colore, Color(0, 0, 0, 0), 3))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _scritta_su(b: ProgressBar) -> Label:
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	b.add_child(l)
	return l


func _ready() -> void:
	radice = Control.new()
	radice.set_anchors_preset(Control.PRESET_FULL_RECT)
	radice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(radice)

	targhette = Control.new()
	targhette.set_anchors_preset(Control.PRESET_FULL_RECT)
	targhette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	targhette.draw.connect(_disegna_targhette)
	radice.add_child(targhette)

	finestre = Finestre.new()
	finestre.gioco = gioco
	radice.add_child(finestre)

	# --- minimappa
	minimappa = Control.new()
	minimappa.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimappa.position = Vector2(-186, 64)
	minimappa.custom_minimum_size = Vector2(170, 170)
	minimappa.size = Vector2(170, 170)
	minimappa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimappa.draw.connect(_disegna_minimappa)
	radice.add_child(minimappa)

	# --- riquadro del giocatore
	var io := PanelContainer.new()
	io.add_theme_stylebox_override("panel", stile(SFONDO, ORO.darkened(0.4), 6))
	io.position = Vector2(16, 16)
	io.custom_minimum_size = Vector2(310, 0)
	radice.add_child(io)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	io.add_child(v)
	nome_io = Label.new()
	nome_io.add_theme_color_override("font_color", ORO)
	v.add_child(nome_io)
	vita = _barra(Color(0.72, 0.16, 0.14), 20)
	v.add_child(vita)
	vita_txt = _scritta_su(vita)
	risorsa = _barra(Color(0.3, 0.5, 0.9), 16)
	v.add_child(risorsa)
	risorsa_txt = _scritta_su(risorsa)
	var riga := HBoxContainer.new()
	v.add_child(riga)
	punti = Label.new()
	punti.add_theme_font_size_override("font_size", 18)
	riga.add_child(punti)
	var molla := Control.new()
	molla.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	riga.add_child(molla)
	slancio = HBoxContainer.new()
	slancio.add_theme_constant_override("separation", 3)
	slancio.tooltip_text = "Slancio: ogni colpo a segno dà una tacca (più risorsa, rapidità e rigenerazione)"
	slancio.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	riga.add_child(slancio)
	for i in range(int(Dati.gioco.SLANCIO.max)):
		var tacca := ColorRect.new()
		tacca.custom_minimum_size = Vector2(22, 7)
		slancio.add_child(tacca)
	suprema = _barra(Color(0.95, 0.75, 0.25), 12)
	suprema.max_value = 100
	v.add_child(suprema)
	_scritta_su(suprema).text = "Tecnica Suprema  [V]"

	# --- riquadro del bersaglio
	riq_bersaglio = PanelContainer.new()
	riq_bersaglio.add_theme_stylebox_override("panel", stile(SFONDO, ORO.darkened(0.4), 6))
	riq_bersaglio.set_anchors_preset(Control.PRESET_CENTER_TOP)
	riq_bersaglio.custom_minimum_size = Vector2(340, 0)
	riq_bersaglio.position = Vector2(-170, 16)
	riq_bersaglio.visible = false
	radice.add_child(riq_bersaglio)
	var vb := VBoxContainer.new()
	riq_bersaglio.add_child(vb)
	nome_b = Label.new()
	nome_b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(nome_b)
	vita_b = _barra(Color(0.72, 0.16, 0.14), 18)
	vb.add_child(vita_b)
	vita_b_txt = _scritta_su(vita_b)
	postura_b = _barra(Color(0.92, 0.82, 0.45), 8)
	postura_b.max_value = 100
	vb.add_child(postura_b)

	# --- barra rapida
	var barra := HBoxContainer.new()
	barra.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	barra.grow_horizontal = Control.GROW_DIRECTION_BOTH
	barra.grow_vertical = Control.GROW_DIRECTION_BEGIN
	barra.position.y = -18
	barra.add_theme_constant_override("separation", 6)
	radice.add_child(barra)
	for i in range(10):
		var t := Tasto.new()
		t.indice = i
		t.premuto.connect(func(n: int) -> void: gioco.usa_tasto(n))
		barra.add_child(t)
		tasti.append(t)

	# --- barra del lancio
	lancio = _barra(Color(0.55, 0.75, 0.95), 16)
	lancio.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	lancio.custom_minimum_size = Vector2(280, 16)
	lancio.position = Vector2(-140, -120)
	lancio.visible = false
	radice.add_child(lancio)
	lancio_txt = _scritta_su(lancio)

	# --- chat
	var riq_chat := VBoxContainer.new()
	riq_chat.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	riq_chat.grow_vertical = Control.GROW_DIRECTION_BEGIN
	riq_chat.position = Vector2(16, -16)
	riq_chat.custom_minimum_size = Vector2(440, 0)
	radice.add_child(riq_chat)
	chat = RichTextLabel.new()
	chat.bbcode_enabled = true
	chat.scroll_following = true
	chat.custom_minimum_size = Vector2(440, 170)
	chat.add_theme_stylebox_override("normal", stile(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 4))
	chat.add_theme_font_size_override("normal_font_size", 13)
	chat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	riq_chat.add_child(chat)
	scrivi = LineEdit.new()
	scrivi.placeholder_text = "Invio per scrivere — /aiuto per i comandi"
	scrivi.max_length = 160
	scrivi.text_submitted.connect(_manda_chat)
	riq_chat.add_child(scrivi)

	# --- avvisi, zona, morte
	avviso = Label.new()
	avviso.set_anchors_preset(Control.PRESET_CENTER_TOP)
	avviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	avviso.position.y = 130
	avviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avviso.add_theme_font_size_override("font_size", 22)
	avviso.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	avviso.add_theme_color_override("font_outline_color", Color.BLACK)
	avviso.add_theme_constant_override("outline_size", 6)
	radice.add_child(avviso)
	zona = Label.new()
	zona.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	zona.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	zona.position = Vector2(-16, 12)
	zona.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	zona.add_theme_color_override("font_outline_color", Color.BLACK)
	zona.add_theme_constant_override("outline_size", 5)
	radice.add_child(zona)
	morte = PanelContainer.new()
	morte.add_theme_stylebox_override("panel", stile(SFONDO, Color(0.7, 0.15, 0.1), 8, 2))
	morte.set_anchors_preset(Control.PRESET_CENTER)
	morte.grow_horizontal = Control.GROW_DIRECTION_BOTH
	morte.grow_vertical = Control.GROW_DIRECTION_BOTH
	morte.visible = false
	radice.add_child(morte)
	var vm := VBoxContainer.new()
	morte.add_child(vm)
	var lm := Label.new()
	lm.text = "Sei caduto in battaglia"
	lm.add_theme_font_size_override("font_size", 24)
	vm.add_child(lm)
	var bm := Button.new()
	bm.text = "Rinasci al villaggio"
	bm.pressed.connect(func() -> void: Rete.manda({"t": "respawn", "mode": "town"}))
	vm.add_child(bm)


func chat_attiva() -> bool:
	return scrivi.has_focus()


func apri_chat() -> void:
	scrivi.grab_focus()


func _manda_chat(testo: String) -> void:
	scrivi.text = ""
	scrivi.release_focus()
	if not testo.strip_edges().is_empty():
		Rete.manda({"t": "chat", "m": testo.strip_edges()})


func riga_chat(testo: String, colore := Color(0.9, 0.9, 0.85)) -> void:
	chat.append_text("[color=#%s]%s[/color]\n" % [colore.to_html(false), testo.replace("[", "[lb]")])


func avvisa(testo: String, errore := false) -> void:
	avviso.text = testo
	avviso.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4) if errore else Color(1.0, 0.9, 0.6))
	avviso.modulate.a = 1.0
	_avviso_t = 2.6


func numero(pos: Vector3, testo: String, colore: Color, grande := 1.0) -> void:
	# i numeri recenti sullo stesso punto si scalano di lato, così non si coprono
	var vicini := 0
	for n in numeri:
		if n.eta < 0.5 and (n.p as Vector3).distance_to(pos) < 1.5:
			vicini += 1
	numeri.append({"p": pos, "t": testo, "c": colore, "eta": 0.0, "g": grande, "lato": (((vicini + 1) / 2) * (1 if vicini % 2 == 0 else -1)) * 46.0})


# ------------------------------------------------------------------ aggiornamento
func aggiorna_io(io: Dictionary, nome: String) -> void:
	if io.is_empty():
		return
	nome_io.text = "%s  ·  livello %d" % [nome, int(io.get("lvl", 1))]
	vita.max_value = float(io.get("mhp", 1))
	vita.value = float(io.get("hp", 0))
	vita_txt.text = "%d / %d" % [int(io.get("hp", 0)), int(io.get("mhp", 1))]
	var rt := String(io.get("rt", "ira"))
	var R: Dictionary = Dati.RESOURCES.get(rt, {})
	risorsa.max_value = float(io.get("rmax", 100))
	risorsa.value = float(io.get("res", 0))
	risorsa.add_theme_stylebox_override("fill", stile(Dati.colore(R.get("color", "#888888")), Color(0, 0, 0, 0), 3))
	risorsa_txt.text = "%s  %d / %d" % [R.get("name", ""), int(io.get("res", 0)), int(io.get("rmax", 100))]
	var cls: Dictionary = Dati.CLASSES.get(gioco.classe, {})
	if cls.has("pts"):
		var n := int(io.get("pts", 0))
		var g := String(cls.pts.glyph)
		punti.text = g.repeat(n)
		punti.tooltip_text = String(cls.pts.name)
		punti.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35) if n >= int(Dati.costanti.PTS_MAX) else Color(0.9, 0.9, 0.9))
	else:
		punti.text = ""
	var sl := int(io.get("sl", 0))
	for i in range(slancio.get_child_count()):
		(slancio.get_child(i) as ColorRect).color = Color(1.0, 0.72, 0.25) if i < sl else Color(0, 0, 0, 0.6)
	suprema.value = float(io.get("su", 0))
	suprema.visible = int(io.get("lvl", 1)) >= int(Dati.gioco.SUPREMA.lvl)
	morte.visible = int(io.get("dead", 0)) == 1
	var qb: Array = io.get("qb", [])
	for i in range(tasti.size()):
		(tasti[i] as Tasto).imposta(qb[i] if i < qb.size() else null, io)
	finestre.aggiorna()


func _process(dt: float) -> void:
	if gioco == null:
		return
	if _avviso_t > 0.0:
		_avviso_t -= dt
		avviso.modulate.a = clampf(_avviso_t / 0.6, 0.0, 1.0)
	# bersaglio
	var b: Entita = gioco.bersaglio
	riq_bersaglio.visible = b != null
	if b != null:
		nome_b.text = "%s  ·  livello %d" % [b.nome, b.lvl] if b.tipo != "n" else b.nome
		vita_b.max_value = b.mhp
		vita_b.value = b.hp
		vita_b_txt.text = "%d / %d" % [int(b.hp), int(b.mhp)]
		postura_b.visible = b.postura >= 0
		postura_b.value = 0 if b.squilibrato else b.postura
		if b.squilibrato:
			nome_b.text += "   — SQUILIBRATO —"
	# ricariche
	var ora := Time.get_ticks_msec()
	for t in tasti:
		(t as Tasto).tempo(ora, gioco.ricariche, gioco.gcd_fine, gioco.gcd_durata)
	# lancio
	if not gioco.lancio.is_empty():
		var l: Dictionary = gioco.lancio
		lancio.visible = true
		lancio.max_value = float(l.durata)
		lancio.value = float(l.durata) - maxf(0.0, float(l.fine) - ora)
		lancio_txt.text = String(l.nome)
		if ora >= float(l.fine):
			gioco.lancio = {}
	else:
		lancio.visible = false
	for i in range(numeri.size() - 1, -1, -1):
		numeri[i].eta += dt
		if numeri[i].eta > 1.1:
			numeri.remove_at(i)
	zona.text = "%s\n%d fps" % [gioco.nome_zona(), Engine.get_frames_per_second()]
	targhette.queue_redraw()
	minimappa.queue_redraw()


## Minimappa: nord in alto, 60 metri di raggio; edifici, strade, creature e il proprio personaggio.
func _disegna_minimappa() -> void:
	if gioco == null or gioco.me == null:
		return
	var lato := minimappa.size.x
	var c := Vector2(lato, lato) * 0.5
	var scala := lato * 0.5 / 60.0
	minimappa.draw_circle(c, lato * 0.5, Color(0.08, 0.1, 0.07, 0.78))
	var io: Entita = gioco.me
	var su := func(x: float, z: float) -> Vector2: return c + Vector2(x - io.x, z - io.z) * scala
	for s in Dati.gioco.strade:
		var a: Vector2 = su.call(float(s[0]), float(s[1]))
		var b: Vector2 = su.call(float(s[2]), float(s[3]))
		if a.distance_to(c) < lato * 0.5 and b.distance_to(c) < lato * 0.5:
			minimappa.draw_line(a, b, Color(0.55, 0.45, 0.3, 0.9), 3.0)
	for o in Dati.gioco.ostacoli:
		var p: Vector2 = su.call(float(o.x), float(o.z))
		if p.distance_to(c) > lato * 0.5 - 3.0:
			continue
		if o.t == "box":
			minimappa.draw_circle(p, maxf(float(o.hw), float(o.hd)) * scala, Color(0.5, 0.25, 0.2, 0.9))
		else:
			minimappa.draw_circle(p, 1.6, Color(0.6, 0.58, 0.52, 0.9))
	for e: Entita in gioco.ents.values():
		var p: Vector2 = su.call(e.x, e.z)
		if p.distance_to(c) > lato * 0.5 - 3.0 or e.tipo == "d":
			continue
		var col := Color(0.95, 0.35, 0.3) if e.tipo == "m" else (Color(0.5, 0.95, 0.5) if e.tipo == "n" else Color(0.5, 0.75, 1.0))
		if e.morto:
			col = Color(0.4, 0.4, 0.4)
		minimappa.draw_circle(p, 3.2 if e == gioco.bersaglio else 2.2, col)
	var dir := Vector2(sin(io.r), cos(io.r))
	var lat := Vector2(dir.y, -dir.x)
	minimappa.draw_colored_polygon(PackedVector2Array([c + dir * 7.0, c - dir * 4.0 + lat * 4.0, c - dir * 4.0 - lat * 4.0]), Color(1.0, 0.92, 0.6))
	minimappa.draw_arc(c, lato * 0.5 - 1.0, 0.0, TAU, 48, ORO.darkened(0.3), 2.0)


func _disegna_targhette() -> void:
	if gioco == null or gioco.cam == null:
		return
	var cam: Camera3D = gioco.cam
	var f := ThemeDB.fallback_font
	var tutti: Array = gioco.ents.values()
	if gioco.me != null:
		tutti.append(gioco.me)
	for e: Entita in tutti:
		if e.tipo == "d" and e.global_position.distance_to(cam.global_position) > 30.0:
			continue
		var p3 := e.testa() + Vector3(0, 0.3, 0)
		var dist := p3.distance_to(cam.global_position)
		if dist > (45.0 if e != gioco.bersaglio else 90.0) or cam.is_position_behind(p3):
			continue
		var p := cam.unproject_position(p3)
		var col := Color(0.95, 0.95, 0.9)
		match e.tipo:
			"m": col = Color(1.0, 0.55, 0.45)
			"n": col = Color(0.6, 0.95, 0.6)
			"p": col = Dati.colore(Dati.KINGDOMS.get(String(e.info.get("kd", "")), {}).get("hex", 0xffffff)).lightened(0.35)
			"d": col = Color(0.95, 0.9, 0.6)
		var testo := e.nome
		if e.tipo == "m":
			testo = "%s  [%d]" % [e.nome, e.lvl]
		var misura := 14
		var larg := f.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, misura).x
		targhette.draw_string_outline(f, p + Vector2(-larg * 0.5, 0), testo, HORIZONTAL_ALIGNMENT_LEFT, -1, misura, 4, Color(0, 0, 0, 0.9))
		targhette.draw_string(f, p + Vector2(-larg * 0.5, 0), testo, HORIZONTAL_ALIGNMENT_LEFT, -1, misura, col)
		if (e.tipo == "m" or (e.tipo == "p" and not e.io)) and (e.hp < e.mhp or e == gioco.bersaglio) and not e.morto:
			var w := 70.0
			var r := Rect2(p + Vector2(-w * 0.5, 5), Vector2(w, 6))
			targhette.draw_rect(r.grow(1), Color(0, 0, 0, 0.8))
			targhette.draw_rect(Rect2(r.position, Vector2(w * clampf(e.hp / e.mhp, 0, 1), 6)), Color(0.8, 0.18, 0.14))
			if e.postura >= 0:
				var r2 := Rect2(p + Vector2(-w * 0.5, 13), Vector2(w, 3))
				targhette.draw_rect(r2.grow(1), Color(0, 0, 0, 0.8))
				targhette.draw_rect(Rect2(r2.position, Vector2(w * (0.0 if e.squilibrato else e.postura / 100.0), 3)), Color(0.95, 0.85, 0.45))
	for n in numeri:
		var p3: Vector3 = n.p + Vector3(0, n.eta * 1.6, 0)
		if cam.is_position_behind(p3):
			continue
		var p := cam.unproject_position(p3) + Vector2(float(n.get("lato", 0.0)), 0.0)
		var misura := int(20.0 * float(n.g) * (1.0 + 0.5 * maxf(0.0, 0.15 - n.eta) / 0.15))
		var c: Color = n.c
		c.a = clampf((1.1 - n.eta) / 0.4, 0.0, 1.0)
		var larg := f.get_string_size(n.t, HORIZONTAL_ALIGNMENT_LEFT, -1, misura).x
		targhette.draw_string_outline(f, p + Vector2(-larg * 0.5, 0), n.t, HORIZONTAL_ALIGNMENT_LEFT, -1, misura, 5, Color(0, 0, 0, c.a))
		targhette.draw_string(f, p + Vector2(-larg * 0.5, 0), n.t, HORIZONTAL_ALIGNMENT_LEFT, -1, misura, c)


# ------------------------------------------------------------------ tasto della barra rapida
class Tasto:
	extends Control
	signal premuto(indice: int)

	var indice := 0
	var voce = null                # { k: "s"|"i", id }
	var glifo := ""
	var nome := ""
	var ruolo := ""
	var colore := Color(0.8, 0.8, 0.8)
	var spento := false            # risorsa insufficiente o non imparata
	var quota := 0.0               # 0..1 di ricarica rimasta
	var secondi := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(58, 58)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func imposta(v, io: Dictionary) -> void:
		voce = v
		glifo = ""
		nome = ""
		ruolo = ""
		spento = false
		tooltip_text = ""
		if v is Dictionary and v.get("k") == "s" and Dati.SKILLS.has(v.id):
			var sk: Dictionary = Dati.SKILLS[v.id]
			glifo = String(sk.get("glyph", "?"))
			nome = String(sk.name)
			ruolo = String(sk.get("ruolo", ""))
			colore = Dati.colore(sk.get("color", 0xcccccc))
			var costo := float(sk.get("cost", 0))
			var ho := float(io.get("res", 0))
			if String(io.get("rt", "")) == "mana":
				costo = float(io.get("rmax", 0)) * costo / 100.0
			spento = costo > ho + 0.5
			var nomi_ruolo := {"accumulo": "Accumulo", "medio": "Scarico medio", "potente": "Scarico potente"}
			tooltip_text = "%s%s\n%s%s" % [nome, ("  —  " + nomi_ruolo[ruolo]) if nomi_ruolo.has(ruolo) else "", sk.get("desc", ""), ("\nCosto: %d" % int(sk.cost)) if sk.has("cost") else ""]
		elif v is Dictionary and v.get("k") == "i" and Dati.ITEMS.has(v.id):
			var it: Dictionary = Dati.ITEMS[v.id]
			glifo = String(it.get("glyph", "?"))
			nome = String(it.name)
			colore = Color(0.85, 0.85, 0.8)
			tooltip_text = nome
		queue_redraw()

	func tempo(ora: int, ricariche: Dictionary, gcd_fine: float, gcd_durata: float) -> void:
		var q := 0.0
		var s := 0.0
		if voce is Dictionary and voce.get("k") == "s":
			var sk: Dictionary = Dati.SKILLS.get(voce.id, {})
			if ricariche.has(voce.id):
				var c: Dictionary = ricariche[voce.id]
				if float(c.fine) > ora:
					q = (float(c.fine) - ora) / maxf(1.0, float(c.durata))
					s = (float(c.fine) - ora) / 1000.0
			if not sk.get("offgcd", false) and gcd_fine > ora:
				var qg := (gcd_fine - ora) / maxf(1.0, gcd_durata)
				if qg > q:
					q = qg
					s = 0.0
		if absf(q - quota) > 0.005 or int(s * 10) != int(secondi * 10):
			quota = q
			secondi = s
			queue_redraw()

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			premuto.emit(indice)
			accept_event()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(Hud.stile(Color(0.08, 0.07, 0.06, 0.9), Hud.ORO.darkened(0.45), 5, 2), r)
		var f := ThemeDB.fallback_font
		if not glifo.is_empty():
			var c := colore if not spento else colore.darkened(0.6)
			var larg := f.get_string_size(glifo, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			draw_string(f, Vector2((size.x - larg) * 0.5, 40), glifo, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, c)
		if quota > 0.0:
			draw_rect(Rect2(2, 2 + (size.y - 4) * (1.0 - quota), size.x - 4, (size.y - 4) * quota), Color(0, 0, 0, 0.62))
			if secondi >= 1.0:
				var t := str(int(ceil(secondi)))
				var lt := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
				draw_string_outline(f, Vector2((size.x - lt) * 0.5, 36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color.BLACK)
				draw_string(f, Vector2((size.x - lt) * 0.5, 36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		draw_string(f, Vector2(5, 14), str((indice + 1) % 10), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.8, 0.75))
		if Hud.RUOLI.has(ruolo):
			draw_rect(Rect2(8, size.y - 6, size.x - 16, 3), Hud.RUOLI[ruolo])
