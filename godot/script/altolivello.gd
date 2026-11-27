class_name AltoLivello
extends Control
## Contenuto per il livello alto (server/altolivello.js): riquadro del boss con le fasi, boss del mondo sulla minimappa e
## sulla mappa grande, premi dei boss in chat, finestra delle Imprese e dei titoli (tasto delle imprese, predefinito J), finestra dell'Araldo
## (stagione dell'Arena, classifica e negozio dell'onore), titoli sopra i nomi.
## Messaggi del server: `boss_mondo`, `boss`, `boss_premi`, `imprese`, `impresa`, `onori`. Qui non si decide nulla.

const ROSSO := Color(1.0, 0.35, 0.25)
const ORO_CHIARO := Color(1.0, 0.86, 0.45)
const GRIGIO := Color(0.72, 0.7, 0.64)

var gioco
var boss_mondo: Array = []          # ultimo elenco `boss_mondo` (con `ricevuto` per il conto alla rovescia)
var _boss_ricevuto := 0.0
var stato_boss: Dictionary = {}     # ultimo messaggio `boss` (combattimento in corso)
var _stato_t := 0.0
var riquadro: PanelContainer
var _nome_boss: Label
var _barra_boss: BarraFasi
var _riga_boss: Label
var imprese: PanelContainer
var _corpo_imprese: VBoxContainer
var _ultime_imprese: Dictionary = {}
var onori: PanelContainer
var _corpo_onori: VBoxContainer
var _ultimi_onori: Dictionary = {}
var _onori_ricevuti := 0.0
var titoli: Control                 # titoli sopra i nomi (disegnati sopra le targhette)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crea_riquadro()
	imprese = _finestra("Imprese e titoli", Vector2(80, 120), 500)
	_corpo_imprese = imprese.get_meta("corpo")
	onori = _finestra("Onori dell'Arena", Vector2(24, 190), 490)
	_corpo_onori = onori.get_meta("corpo")
	Rete.su("boss_mondo", _su_boss_mondo)
	Rete.su("boss", _su_boss)
	Rete.su("boss_premi", _su_premi)
	Rete.su("imprese", _su_imprese)
	Rete.su("impresa", _su_impresa)
	Rete.su("onori", _su_onori)


## Da chiamare dopo che il gioco ha creato l'interfaccia: titoli sopra le targhette e segni sulla minimappa.
func aggancia() -> void:
	titoli = Control.new()
	titoli.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	titoli.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titoli.draw.connect(_disegna_titoli)
	gioco.hud.radice.add_child(titoli)
	gioco.hud.radice.move_child(titoli, gioco.hud.targhette.get_index() + 1)
	gioco.hud.minimappa.draw.connect(_disegna_minimappa)


func apri_imprese() -> void:
	imprese.visible = not imprese.visible
	if imprese.visible:
		Rete.manda({"t": "alto", "a": "imprese"})
		_riempi_imprese()
	Suoni.suona("clic", -12.0)


## Chiude le finestre; true se qualcosa era aperto (per Esc).
func chiudi() -> bool:
	var era := imprese.visible or onori.visible
	imprese.visible = false
	onori.visible = false
	return era


# ------------------------------------------------------------------ costruzione
func _finestra(titolo: String, pos: Vector2, larga: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Hud.stile(Color(0.07, 0.06, 0.06, 0.95), Hud.ORO.darkened(0.35), 8, 2))
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
	var corpo := VBoxContainer.new()
	corpo.add_theme_constant_override("separation", 5)
	v.add_child(corpo)
	p.set_meta("corpo", corpo)
	return p


func _etichetta(genitore: Control, testo: String, colore := Color(0.9, 0.88, 0.82), misura := 14, larga := 470.0) -> Label:
	var l := Label.new()
	l.text = testo
	l.add_theme_color_override("font_color", colore)
	l.add_theme_font_size_override("font_size", misura)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if larga > 0.0:
		l.custom_minimum_size = Vector2(larga, 0)
	genitore.add_child(l)
	return l


func _svuota(c: Control) -> void:
	for f in c.get_children():
		c.remove_child(f)
		f.queue_free()


func _crea_riquadro() -> void:
	riquadro = PanelContainer.new()
	riquadro.add_theme_stylebox_override("panel", Hud.stile(Color(0.06, 0.03, 0.03, 0.86), Color(0.8, 0.3, 0.15), 6, 2))
	riquadro.set_anchors_preset(Control.PRESET_CENTER_TOP)
	riquadro.offset_left = -260.0
	riquadro.offset_right = 260.0
	riquadro.offset_top = 176.0   # sotto il riquadro del bersaglio e gli avvisi
	riquadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	riquadro.visible = false
	add_child(riquadro)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	riquadro.add_child(v)
	_nome_boss = Label.new()
	_nome_boss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nome_boss.add_theme_font_size_override("font_size", 17)
	_nome_boss.add_theme_color_override("font_color", Color(1.0, 0.78, 0.5))
	_nome_boss.add_theme_color_override("font_outline_color", Color.BLACK)
	_nome_boss.add_theme_constant_override("outline_size", 4)
	v.add_child(_nome_boss)
	_barra_boss = BarraFasi.new()
	_barra_boss.custom_minimum_size = Vector2(500, 22)
	v.add_child(_barra_boss)
	_riga_boss = Label.new()
	_riga_boss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_riga_boss.add_theme_font_size_override("font_size", 13)
	_riga_boss.add_theme_color_override("font_outline_color", Color.BLACK)
	_riga_boss.add_theme_constant_override("outline_size", 3)
	v.add_child(_riga_boss)


# ------------------------------------------------------------------ messaggi
func _su_boss_mondo(m: Dictionary) -> void:
	if boss_mondo.is_empty() and _ultime_imprese.is_empty():
		Rete.manda({"t": "alto", "a": "imprese"})   # all'ingresso: titolo mostrato e imprese
	boss_mondo = m.get("l", [])
	_boss_ricevuto = gioco.ora()
	if imprese.visible:
		_riempi_imprese()


func _su_boss(m: Dictionary) -> void:
	stato_boss = m
	_stato_t = gioco.ora()


func _su_premi(m: Dictionary) -> void:
	gioco.hud.riga_chat("Bottino di %s:" % String(m.get("n", "boss")), Hud.ORO)
	for voce in m.get("got", []):
		var nome := String(voce)
		var q := nome.rfind(" x")
		var base := nome.substr(0, q) if q > 0 else nome
		var par := base.rfind(" (")
		if par > 0:
			base = base.substr(0, par)
		var id_ogg := IconeOggetti.id_da_nome(base)
		if id_ogg == "" and nome.ends_with("tael"):
			id_ogg = "tael"
		var rr := IconeOggetti.rarita(id_ogg) if id_ogg != "" and id_ogg != "tael" else 0
		for r in range(Dati.gioco.RARITIES.size()):
			if nome.ends_with("(%s)" % String(Dati.gioco.RARITIES[r].name)):
				rr = r
		gioco.hud.riga_chat_oggetto("  " + nome, Hud.ORO if id_ogg == "tael" else IconeOggetti.colore_rarita(rr), id_ogg, rr)
	Suoni.suona("livello", -6.0, 1.2)


func _su_impresa(m: Dictionary) -> void:
	# il testo arriva anche come avviso (notice): qui solo il suono e la finestra aggiornata
	Suoni.suona("livello", -4.0, 0.9)
	if imprese.visible:
		Rete.manda({"t": "alto", "a": "imprese"})


func _su_imprese(m: Dictionary) -> void:
	_ultime_imprese = m
	if imprese.visible:
		_riempi_imprese()


func _su_onori(m: Dictionary) -> void:
	_ultimi_onori = m
	_onori_ricevuti = gioco.ora()
	_riempi_onori()
	onori.visible = true


# ------------------------------------------------------------------ finestra delle imprese (J)
func _tempo(ms: float) -> String:
	var s := int(maxf(0.0, ms) / 1000.0)
	if s >= 3600:
		return "%d h %02d min" % [s / 3600, (s % 3600) / 60]
	return "%d:%02d" % [s / 60, s % 60]


func _riempi_imprese() -> void:
	_svuota(_corpo_imprese)
	var m := _ultime_imprese
	var T: Dictionary = Dati.gioco.get("TITOLI", {})
	# boss del mondo: dove e quando
	_etichetta(_corpo_imprese, "Boss del mondo", Hud.ORO, 15)
	for b in boss_mondo:
		var quando := "VIVO ora — %d%% di vita" % int(b.hp) if int(b.vivo) == 1 else "fra %s" % _tempo(float(b.tra) - (gioco.ora() - _boss_ricevuto))
		var uccisi := int(m.get("boss", {}).get(String(b.id), 0))
		_etichetta(_corpo_imprese, "%s  (liv. %d) — %s\n   %s%s" % [String(b.n), int(b.liv), quando, String(b.zona), ("   ·   abbattuto %d volte" % uccisi) if uccisi > 0 else ""], ROSSO if int(b.vivo) == 1 else Color(0.85, 0.82, 0.74), 13)
	_corpo_imprese.add_child(HSeparator.new())
	_etichetta(_corpo_imprese, "Imprese", Hud.ORO, 15)
	for v in m.get("l", []):
		var fatto := int(v.fatto) == 1
		var testo := "%s %s — %s" % ["✓" if fatto else "·", String(v.n), String(v.desc)]
		if not fatto and int(v.max) > 1:
			testo += "  (%d/%d)" % [int(v.v), int(v.max)]
		if String(v.get("ti", "")) != "" and T.has(String(v.ti)):
			testo += "  →  «%s»" % String(T[String(v.ti)].nome)
		_etichetta(_corpo_imprese, testo, Color(0.6, 0.95, 0.55) if fatto else GRIGIO, 13)
	_corpo_imprese.add_child(HSeparator.new())
	var miei: Array = m.get("titoli", [])
	_etichetta(_corpo_imprese, "Titoli (sopra il tuo nome)" if not miei.is_empty() else "Titoli: compi un'impresa o compralo con l'onore dall'Araldo dell'Arena.", Hud.ORO, 15)
	var riga := HFlowContainer.new()
	riga.custom_minimum_size = Vector2(470, 0)
	_corpo_imprese.add_child(riga)
	for id in [""] + miei:
		var b := Button.new()
		b.text = "Nessuno" if id == "" else String(T.get(String(id), {}).get("nome", id))
		b.toggle_mode = true
		b.button_pressed = String(m.get("tit", "")) == String(id)
		if id != "":
			b.add_theme_color_override("font_color", Color.html(String(T.get(String(id), {}).get("colore", "#ffffff"))))
		var scelto := String(id)
		b.pressed.connect(func() -> void: Rete.manda({"t": "alto", "a": "titolo", "id": scelto}))
		riga.add_child(b)


# ------------------------------------------------------------------ finestra dell'Araldo: stagione e negozio dell'onore
func _riempi_onori() -> void:
	_svuota(_corpo_onori)
	var m := _ultimi_onori
	var T: Dictionary = Dati.gioco.get("TITOLI", {})
	var io: Dictionary = m.get("io", {})
	_etichetta(_corpo_onori, "Onore: %d   ·   stagione %d, finisce fra %s" % [int(m.get("onore", 0)), int(m.get("sett", 0)), _tempo(float(m.get("fine", 0)))], ORO_CHIARO, 15)
	_etichetta(_corpo_onori, "Ogni avversario abbattuto nell'Arena vale 10 punti (di più in serie o spezzando una serie); a fine settimana i primi tre ricevono onore e tael, il primo il titolo «%s»." % String(T.get("campione_loto", {}).get("nome", "Campione")), GRIGIO, 12)
	var pos := int(io.get("pos", 0))
	_etichetta(_corpo_onori, ("Tu: %d° con %d punti (%d abbattuti, %d cadute, serie migliore %d)" % [pos, int(io.p), int(io.u), int(io.m), int(io.b)]) if pos > 0 else "Non sei ancora in classifica questa settimana.", Color(0.6, 0.9, 0.6), 13)
	var cl: Array = m.get("cl", [])
	if not cl.is_empty():
		_etichetta(_corpo_onori, "Classifica della settimana", Hud.ORO, 14)
		var i := 1
		for r in cl:
			var kd: Dictionary = Dati.KINGDOMS.get(String(r.get("kd", "")), {})
			var col := Dati.colore(kd.get("hex", 0xcccccc)).lightened(0.3)
			_etichetta(_corpo_onori, "%d. %s — %d punti  (%d / %d)" % [i, String(r.n), int(r.p), int(r.u), int(r.m)], col, 13)
			i += 1
	var camp: Array = m.get("campioni", [])
	if not camp.is_empty():
		_etichetta(_corpo_onori, "Campione della settimana scorsa: %s" % ", ".join(PackedStringArray(camp)), Color(1.0, 0.88, 0.45), 13)
	_corpo_onori.add_child(HSeparator.new())
	_etichetta(_corpo_onori, "Negozio dell'onore", Hud.ORO, 14)
	for v in m.get("negozio", []):
		var h := HBoxContainer.new()
		_corpo_onori.add_child(h)
		var nome := ""
		if String(v.get("titolo", "")) != "":
			nome = "Titolo «%s»" % String(T.get(String(v.titolo), {}).get("nome", v.titolo))
		elif int(v.get("tael", 0)) > 0:
			nome = "%d tael" % int(v.tael)
		else:
			nome = String(Dati.ITEMS.get(String(v.id), {}).get("name", v.id))
			if int(v.get("n", 1)) > 1:
				nome += " ×%d" % int(v.n)
		if String(v.get("titolo", "")) == "" and int(v.get("tael", 0)) == 0:
			var ic := IconeOggetti.Vista.new()
			ic.id = String(v.id)
			ic.custom_minimum_size = Vector2(28, 28)
			h.add_child(ic)
		var l := _etichetta(h, nome, Color(0.92, 0.9, 0.84), 13, 300)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b := Button.new()
		var gia := int(v.get("ha", 0)) == 1
		b.text = "Già tuo" if gia else "%d onore" % int(v.costo)
		b.disabled = gia or int(m.get("onore", 0)) < int(v.costo)
		var i_v := int(v.i)
		b.pressed.connect(func() -> void: Rete.manda({"t": "alto", "a": "compra", "npc": int(m.get("npc", 0)), "i": i_v}))
		h.add_child(b)


# ------------------------------------------------------------------ boss sulla mappa e sulla minimappa
## Boss del mondo con la posizione: [ { p: Vector2, n, vivo, tra (ms), liv } ]
func segni_boss() -> Array:
	var out: Array = []
	var trascorso: float = gioco.ora() - _boss_ricevuto if gioco != null else 0.0
	for b in boss_mondo:
		out.append({"p": Vector2(float(b.x), float(b.z)), "n": String(b.n), "vivo": int(b.vivo) == 1, "tra": maxf(0.0, float(b.tra) - trascorso), "liv": int(b.liv), "hp": int(b.hp)})
	return out


func _teschio(c: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	c.draw_circle(p, r + 2.0, Color(0.05, 0.02, 0.02, 0.9))
	c.draw_circle(p, r, col)
	# corna: il segno del boss
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.8, -r * 0.4), p + Vector2(-r * 1.5, -r * 1.6), p + Vector2(-r * 0.25, -r * 0.85)]), col)
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(r * 0.8, -r * 0.4), p + Vector2(r * 1.5, -r * 1.6), p + Vector2(r * 0.25, -r * 0.85)]), col)
	c.draw_circle(p + Vector2(-r * 0.35, -r * 0.05), r * 0.22, Color(0.1, 0.02, 0.0))
	c.draw_circle(p + Vector2(r * 0.35, -r * 0.05), r * 0.22, Color(0.1, 0.02, 0.0))


func disegna_mappa(mappa: Control) -> void:
	var f := ThemeDB.fallback_font
	var t := Time.get_ticks_msec() * 0.004
	for b in segni_boss():
		var p = mappa.call("punto_mappa", b.p.x, b.p.y)
		if p == null:
			continue
		var col := ROSSO if b.vivo else Color(0.75, 0.55, 0.45)
		if b.vivo:
			mappa.draw_arc(p, 12.0 + 3.0 * sin(t), 0, TAU, 28, ROSSO, 2.0)
		_teschio(mappa, p, 6.0, col)
		var testo := "%s (liv. %d) — %s" % [b.n, b.liv, "VIVO %d%%" % b.hp if b.vivo else "fra " + _tempo(b.tra)]
		var larg := f.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		mappa.draw_string_outline(f, p + Vector2(-larg * 0.5, 22), testo, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0.05, 0.03, 0.02, 0.95))
		mappa.draw_string(f, p + Vector2(-larg * 0.5, 22), testo, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col.lightened(0.3))


func _disegna_minimappa() -> void:
	if gioco == null or gioco.me == null:
		return
	var mm: Control = gioco.hud.minimappa
	var lato := mm.size.x
	var c := Vector2(lato, lato) * 0.5
	var scala := lato * 0.5 / 60.0
	var io := Vector2(gioco.me.x, gioco.me.z)
	for b in segni_boss():
		if not b.vivo:
			continue
		var rel: Vector2 = (b.p - io) * scala
		if rel.length() < lato * 0.5 - 8.0:
			_teschio(mm, c + rel, 4.5, ROSSO)
		elif (b.p - io).length() < 400.0:
			var dir: Vector2 = rel.normalized()
			var p := c + dir * (lato * 0.5 - 7.0)
			var lat := Vector2(dir.y, -dir.x)
			mm.draw_colored_polygon(PackedVector2Array([p + dir * 7.0, p - dir * 4.0 + lat * 6.0, p - dir * 4.0 - lat * 6.0]), ROSSO)


# ------------------------------------------------------------------ titoli sopra i nomi
func _disegna_titoli() -> void:
	if gioco == null or gioco.cam == null:
		return
	var cam: Camera3D = gioco.cam
	var f := ThemeDB.fallback_font
	var T: Dictionary = Dati.gioco.get("TITOLI", {})
	var tutti: Array = gioco.ents.values()
	if gioco.me != null:
		tutti.append(gioco.me)
	for v in tutti:
		if not is_instance_valid(v):
			continue
		var e: Entita = v
		if e.tipo != "p":
			continue
		var id = e.info.get("ti")
		if e == gioco.me:
			id = _ultime_imprese.get("tit", "")   # il proprio titolo arriva con le imprese (il server non rimanda le proprie info)
		if id == null or String(id) == "" or not T.has(String(id)):
			continue
		var p3 := e.testa() + Vector3(0, 0.3, 0)
		var dist := p3.distance_to(cam.global_position)
		if dist > 45.0 or cam.is_position_behind(p3):
			continue
		var p := cam.unproject_position(p3) + Vector2(0, -17)
		var testo := "«%s»" % String(T[String(id)].nome)
		var larg := f.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		titoli.draw_string_outline(f, p + Vector2(-larg * 0.5, 0), testo, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0, 0.9))
		titoli.draw_string(f, p + Vector2(-larg * 0.5, 0), testo, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.html(String(T[String(id)].colore)))


# ------------------------------------------------------------------ ogni fotogramma
func _process(_dt: float) -> void:
	if gioco == null or gioco.me == null:
		return
	if titoli != null:
		titoli.queue_redraw()
	# riquadro del boss: durante il combattimento (il server manda lo stato ogni mezzo secondo)
	# resta visibile finché il boss è vicino e vivo (fino a 20 s dall'ultimo stato: il server lo manda solo mentre combatte)
	var ent = gioco.ents.get(int(stato_boss.get("id", 0))) if not stato_boss.is_empty() else null
	var vivo: bool = not stato_boss.is_empty() and gioco.ora() - _stato_t < 20000.0 and int(stato_boss.get("hp", 0)) > 0
	if ent != null and is_instance_valid(ent):
		vivo = vivo and not ent.morto and ent.hp > 0.0 and Vector2(ent.x - gioco.me.x, ent.z - gioco.me.z).length() < 90.0
		stato_boss["hp"] = ent.hp
	riquadro.visible = vivo
	if vivo:
		var d: Dictionary = Dati.MOBS.get(String(stato_boss.get("ty", "")), {})
		var fasi: Array = d.get("mecc", {}).get("fasi", [])
		var f := int(stato_boss.get("f", 0))
		var nome_fase := String(fasi[f].nome) if f < fasi.size() else ""
		_nome_boss.text = "%s  —  %s" % [String(stato_boss.get("n", "")), nome_fase]
		_barra_boss.quota = float(stato_boss.hp) / maxf(1.0, float(stato_boss.mhp))
		var soglie: Array = []
		for i in range(1, fasi.size()):
			soglie.append(float(fasi[i].sotto))
		_barra_boss.soglie = soglie
		_barra_boss.testo = "%d / %d" % [int(stato_boss.hp), int(stato_boss.mhp)]
		_barra_boss.corazza = int(stato_boss.get("sc", 0)) > 0
		_barra_boss.queue_redraw()
		var righe: Array = []
		var le: Dictionary = gioco.lanci_nemici.get(int(stato_boss.get("id", 0)), {})
		if not le.is_empty() and float(le.fine) > gioco.ora():
			righe.append("Lancia: %s — INTERROMPI!" % String(le.nome))
		if int(stato_boss.get("sc", 0)) > 0:
			righe.append("Corazza: abbattete i servitori (%d)" % int(stato_boss.sc))
		if int(stato_boss.get("fu", 0)) == 1:
			righe.append("IN FURIA")
		elif int(stato_boss.get("fuS", -1)) >= 0:
			righe.append("Furia fra %s" % _tempo(float(stato_boss.fuS) * 1000.0))
		_riga_boss.text = "   ·   ".join(PackedStringArray(righe))
		_riga_boss.add_theme_color_override("font_color", ROSSO if int(stato_boss.get("fu", 0)) == 1 or not le.is_empty() else ORO_CHIARO)
	# la finestra dell'Araldo si chiude allontanandosi
	if onori.visible and int(_ultimi_onori.get("npc", 0)) != 0:
		var n = gioco.ents.get(int(_ultimi_onori.npc))
		if n == null or Vector2(n.x - gioco.me.x, n.z - gioco.me.z).length() > 10.0:
			onori.visible = false


# ------------------------------------------------------------------ barra della vita con le soglie delle fasi
class BarraFasi:
	extends Control
	var quota := 1.0
	var soglie: Array = []
	var testo := ""
	var corazza := false

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.05, 0.02, 0.02, 0.95))
		var piena := Rect2(r.position + Vector2(2, 2), Vector2((r.size.x - 4) * clampf(quota, 0.0, 1.0), r.size.y - 4))
		draw_rect(piena, Color(0.62, 0.12, 0.08) if not corazza else Color(0.55, 0.45, 0.35))
		draw_rect(Rect2(piena.position, Vector2(piena.size.x, piena.size.y * 0.4)), Color(1, 0.5, 0.35, 0.25))
		for s in soglie:
			var x := 2.0 + (r.size.x - 4) * float(s)
			draw_line(Vector2(x, 0), Vector2(x, r.size.y), Color(1.0, 0.85, 0.4, 0.9), 2.0)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 4, 0), Vector2(x + 4, 0), Vector2(x, 5)]), Color(1.0, 0.85, 0.4))
		draw_rect(r, Color(0.85, 0.45, 0.2), false, 1.5)
		var f := ThemeDB.fallback_font
		var larg := f.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string_outline(f, Vector2((r.size.x - larg) * 0.5, r.size.y * 0.5 + 5), testo, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color.BLACK)
		draw_string(f, Vector2((r.size.x - larg) * 0.5, r.size.y * 0.5 + 5), testo, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
