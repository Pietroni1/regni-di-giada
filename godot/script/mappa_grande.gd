class_name MappaGrande
extends Control
## Mappa grande (tasto M): le terre dei tre regni dipinte dai dati del terreno, con zone, livelli consigliati,
## villaggi e strade; a destra i Sentieri Lontani (Selva, Distesa, Arena). Mostra dove sei e chi hai attorno.

const CARTA := Color(0.16, 0.13, 0.09, 0.97)
const INCHIOSTRO := Color(0.96, 0.9, 0.74)
const MEZZO := 256.0            # si mostra il mondo da -256 a +256 (oltre ci sono solo i monti di confine)

## Zone del mondo aperto: nome, livelli, centro dell'etichetta (coordinate del mondo).
const ZONE := [
	{"nome": "Altopiano delle Spade Spezzate", "liv": "liv. 16-25", "x": 0.0, "z": 8.0},
	{"nome": "Terre di Confine", "liv": "liv. 8-16", "x": 0.0, "z": 150.0},
	{"nome": "Terre di Confine", "liv": "liv. 8-16", "x": -135.0, "z": -70.0},
	{"nome": "Terre di Confine", "liv": "liv. 8-16", "x": 135.0, "z": -70.0},
	{"nome": "Monti Nebbiosi", "liv": "", "x": 0.0, "z": 244.0},
]
const ANELLI := {"fenice": "Piana dei Ciliegi Rossi", "tigre": "Boschi del Sussurro", "drago": "Riva delle Gru"}

var gioco: Gioco
var _tex: ImageTexture
var _tex_mappe: Dictionary = {}     # id della mappa lontana → ImageTexture del suo disco
var _rett := Rect2()                # riquadro del mondo sullo schermo
var _dischi: Dictionary = {}        # id → [centro, raggio] sullo schermo


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func apri_chiudi() -> void:
	visible = not visible
	mouse_filter = Control.MOUSE_FILTER_STOP if visible else Control.MOUSE_FILTER_IGNORE
	if visible and _tex == null:
		_dipingi()
	Suoni.suona("clic", -12.0)
	queue_redraw()


## Chiude la mappa; true se era aperta (per Esc).
func chiudi() -> bool:
	var era := visible
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	return era


func _process(_dt: float) -> void:
	if visible:
		queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		# clic fuori dal foglio: chiude
		if not _foglio().has_point(ev.position):
			chiudi()
		accept_event()


# ------------------------------------------------------------------ pittura (una volta sola)
## Colore del terreno in un punto del mondo, dai pesi dei materiali esportati dal server.
func _colore_terreno(x: float, z: float, h: float) -> Color:
	var n := Dati.lato_p
	var px := clampi(int((x + Dati.meta) / Dati.passo_p), 0, n - 1)
	var pz := clampi(int((z + Dati.meta) / Dati.passo_p), 0, n - 1)
	var a := Dati.pesi_a.get_pixel(px, pz)     # secco, bosco, sabbia, terra
	var b := Dati.pesi_b.get_pixel(px, pz)     # roccia, neve, lastricato
	var c := Color(0.42, 0.56, 0.27)           # prato
	c = c.lerp(Color(0.62, 0.6, 0.33), a.r)
	c = c.lerp(Color(0.2, 0.38, 0.2), a.g)
	c = c.lerp(Color(0.8, 0.72, 0.5), a.b)
	c = c.lerp(Color(0.5, 0.38, 0.25), a.a)
	c = c.lerp(Color(0.5, 0.49, 0.47), b.r)
	c = c.lerp(Color(0.93, 0.94, 0.96), b.g)
	c = c.lerp(Color(0.7, 0.66, 0.58), b.b)
	if h < -0.05:
		c = Color(0.25, 0.47, 0.6).lerp(Color(0.12, 0.27, 0.42), clampf(-h / 4.0, 0.0, 1.0))
	return c


func _dipingi() -> void:
	var lato := 400
	var img := Image.create(lato, lato, false, Image.FORMAT_RGB8)
	var passo := MEZZO * 2.0 / lato
	for j in range(lato):
		for i in range(lato):
			var x := -MEZZO + (i + 0.5) * passo
			var z := -MEZZO + (j + 0.5) * passo
			var h := Dati.altezza(x, z)
			var c := _colore_terreno(x, z, h)
			# ombreggiatura del rilievo: luce da nord-ovest
			var d := (Dati.altezza(x - 2.0, z - 2.0) - Dati.altezza(x + 2.0, z + 2.0)) * 0.16
			if h >= -0.05:
				c = c.lightened(clampf(d, 0.0, 0.3)) if d > 0.0 else c.darkened(clampf(-d, 0.0, 0.4))
			# tono di carta: un po' meno saturo
			c = c.lerp(Color(0.72, 0.64, 0.46), 0.14)
			img.set_pixel(i, j, c)
	_tex = ImageTexture.create_from_image(img)
	# dischi delle mappe lontane
	var defs := Mappe.definizioni()
	for id: String in defs:
		var m: Dictionary = defs[id]
		var r := float(m.raggio)
		var n := 128
		var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var suolo: Array = m.tema.get("suolo", ["#3a5a30", "#56703c"])
		var basso := Color(String(suolo[0])).lightened(0.12)
		var alto := Color(String(suolo[1])).lightened(0.25)
		for j in range(n):
			for i in range(n):
				var lx := (i + 0.5 - n * 0.5) / (n * 0.5) * r
				var lz := (j + 0.5 - n * 0.5) / (n * 0.5) * r
				if lx * lx + lz * lz > r * r:
					im.set_pixel(i, j, Color(0, 0, 0, 0))
					continue
				var x := float(m.cx) + lx
				var z := float(m.cz) + lz
				var h := Mappe.altezza(x, z)
				var c := basso.lerp(alto, clampf(h / 9.0 + 0.35, 0.0, 1.0))
				var d := (Mappe.altezza(x - 3.0, z - 3.0) - Mappe.altezza(x + 3.0, z + 3.0)) * 0.14
				c = c.lightened(clampf(d, 0.0, 0.3)) if d > 0.0 else c.darkened(clampf(-d, 0.0, 0.4))
				if String(m.tipo) == "arena" and Vector2(lx, lz).length() < float(m.get("pavimento", 58)):
					c = Color(0.74, 0.72, 0.68)
				im.set_pixel(i, j, c)
		_tex_mappe[id] = ImageTexture.create_from_image(im)


# ------------------------------------------------------------------ disegno
func _foglio() -> Rect2:
	var lato := minf(size.y - 110.0, 760.0)
	var larg := lato + 270.0
	return Rect2((size.x - larg) * 0.5 - 14.0, (size.y - lato) * 0.5 - 44.0, larg + 28.0, lato + 74.0)


func _su(x: float, z: float) -> Vector2:
	return _rett.position + Vector2((x + MEZZO) / (MEZZO * 2.0), (z + MEZZO) / (MEZZO * 2.0)) * _rett.size


func _scritta(pos: Vector2, testo: String, misura: int, colore: Color, centrata := true) -> void:
	var f := ThemeDB.fallback_font
	var larg := f.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, misura).x
	var p := pos - Vector2(larg * 0.5, 0) if centrata else pos
	draw_string_outline(f, p, testo, HORIZONTAL_ALIGNMENT_LEFT, -1, misura, 4, Color(0.05, 0.04, 0.03, 0.9))
	draw_string(f, p, testo, HORIZONTAL_ALIGNMENT_LEFT, -1, misura, colore)


func _tratteggio(centro: Vector2, r: float, colore: Color) -> void:
	var n := 72
	for i in range(0, n, 2):
		# solo i tratti dentro il riquadro del mondo
		if _rett.has_point(centro + Vector2(cos(TAU * (i + 0.5) / n), sin(TAU * (i + 0.5) / n)) * r):
			draw_arc(centro, r, TAU * i / n, TAU * (i + 1) / n, 4, colore, 1.5)


func _freccia(p: Vector2, rot: float, colore: Color, misura := 9.0) -> void:
	var dir := Vector2(sin(rot), cos(rot))
	var lat := Vector2(dir.y, -dir.x)
	var punti := PackedVector2Array([p + dir * misura, p - dir * misura * 0.6 + lat * misura * 0.6, p - dir * misura * 0.2, p - dir * misura * 0.6 - lat * misura * 0.6])
	draw_colored_polygon(punti, colore)
	punti.append(punti[0])
	draw_polyline(punti, Color(0.1, 0.05, 0.0), 1.5)


func _draw() -> void:
	if gioco == null or gioco.me == null or _tex == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	var foglio := _foglio()
	draw_style_box(Hud.stile(CARTA, Hud.ORO.darkened(0.3), 10, 2), foglio)
	var lato := foglio.size.y - 74.0
	_rett = Rect2(foglio.position + Vector2(14, 52), Vector2(lato, lato))
	_scritta(foglio.position + Vector2(foglio.size.x * 0.5, 32), "Mappa dei Regni di Giada", 22, Hud.ORO)
	_scritta(foglio.position + Vector2(foglio.size.x - 150, 30), "M o Esc per chiudere", 12, INCHIOSTRO.darkened(0.3), false)
	var io: Entita = gioco.me
	var qui := Mappe.mappa_a(io.x, io.z)
	var nel_mondo := qui == "" and absf(io.x) <= MEZZO + 40.0

	# --- il mondo dei tre regni
	draw_texture_rect(_tex, _rett, false)
	draw_rect(_rett, Hud.ORO.darkened(0.45), false, 2.0)
	var k := _rett.size.x / (MEZZO * 2.0)
	# confini delle zone
	_tratteggio(_su(0, 0), 95.0 * k, Color(1, 0.95, 0.8, 0.45))
	for kid: String in Dati.KINGDOMS:
		var v: Dictionary = Dati.KINGDOMS[kid].village
		_tratteggio(_su(float(v.x), float(v.z)), 125.0 * k, Dati.colore(Dati.KINGDOMS[kid].color, 0.55))
	# strade
	for s in Dati.gioco.strade:
		draw_line(_su(float(s[0]), float(s[1])), _su(float(s[2]), float(s[3])), Color(0.86, 0.76, 0.55, 0.95), 2.5)
	# etichette delle zone
	for z: Dictionary in ZONE:
		var p := _su(z.x, z.z)
		_scritta(p, z.nome, 14, INCHIOSTRO)
		if z.liv != "":
			_scritta(p + Vector2(0, 16), z.liv, 12, Color(1.0, 0.82, 0.45))
	# villaggi e i loro dintorni
	for kid: String in Dati.KINGDOMS:
		var reg: Dictionary = Dati.KINGDOMS[kid]
		var v: Dictionary = reg.village
		var p := _su(float(v.x), float(v.z))
		var col := Dati.colore(reg.color)
		draw_circle(p, 9.0, Color(0.08, 0.06, 0.04))
		draw_circle(p, 7.0, col)
		draw_circle(p, 3.0, INCHIOSTRO)
		_scritta(p + Vector2(0, -14), String(reg.villageName), 15, col.lightened(0.45))
		_scritta(p + Vector2(0, 26), "Regno " + _articolo(String(reg.short)), 11, INCHIOSTRO.darkened(0.15))
		# nome dell'anello di caccia, spostato verso il centro del mondo
		var verso := (Vector2(0, 0) - Vector2(float(v.x), float(v.z))).normalized() * 62.0
		var q := _su(float(v.x) + verso.x, float(v.z) + verso.y)
		_scritta(q, String(ANELLI.get(kid, "")), 13, INCHIOSTRO)
		_scritta(q + Vector2(0, 15), "liv. 1-8", 12, Color(1.0, 0.82, 0.45))
	# chi hai attorno (solo ciò che il server ti mostra)
	if nel_mondo:
		for e: Entita in gioco.ents.values():
			if e == io or e.tipo == "d" or e.morto:
				continue
			var col := Color(0.95, 0.3, 0.25) if e.tipo == "m" else (Color(0.45, 0.95, 0.5) if e.tipo == "n" else Color(0.5, 0.78, 1.0))
			draw_circle(_su(e.x, e.z), 2.0 if e.tipo == "m" else 3.0, col)
		var pio := _su(clampf(io.x, -MEZZO, MEZZO), clampf(io.z, -MEZZO, MEZZO))
		draw_arc(pio, 14.0 + 3.0 * sin(Time.get_ticks_msec() * 0.005), 0, TAU, 32, Color(1, 0.95, 0.6, 0.8), 2.0)
		_freccia(pio, io.r, Color(1.0, 0.93, 0.55))

	# --- Sentieri Lontani (colonna a destra)
	var cx := _rett.end.x + 135.0
	_scritta(Vector2(cx, _rett.position.y + 12), "Sentieri Lontani", 16, Hud.ORO)
	_scritta(Vector2(cx, _rett.position.y + 28), "si parte dal Viandante Lu, nei villaggi", 11, INCHIOSTRO.darkened(0.25))
	var defs := Mappe.definizioni()
	var alto := (_rett.size.y - 40.0) / maxf(1.0, float(defs.size()))
	var rd := minf(alto * 0.5 - 34.0, 92.0)
	var i := 0
	_dischi.clear()
	for id: String in defs:
		var m: Dictionary = defs[id]
		var centro := Vector2(cx, _rett.position.y + 44.0 + alto * i + rd + 2.0)
		_dischi[id] = [centro, rd]
		draw_circle(centro, rd + 3.0, Color(0.06, 0.05, 0.04))
		draw_texture_rect(_tex_mappe[id], Rect2(centro - Vector2(rd, rd), Vector2(rd, rd) * 2.0), false)
		draw_arc(centro, rd + 1.0, 0, TAU, 64, Color(1.0, 0.9, 0.5) if qui == id else Hud.ORO.darkened(0.4), 3.0 if qui == id else 2.0)
		var kk := rd / float(m.raggio)
		if String(m.tipo) == "arena":
			for n in range(int(m.porte)):
				var a := Mappe.angolo_porta(n)
				draw_circle(centro + Vector2(sin(a), cos(a)) * float(m.distNicchia) * kk, 4.0, Color(0.45, 0.9, 0.55))
		else:
			var arr := centro + Vector2(float(m.arrivo.x), float(m.arrivo.z)) * kk
			draw_circle(arr, 5.0, Color(0.08, 0.06, 0.04))
			draw_circle(arr, 3.5, Color(0.45, 0.9, 0.55))
			for o in m.get("obelischi", []):
				var po := centro + Vector2(float(o[1]), float(o[2])) * kk
				draw_colored_polygon(PackedVector2Array([po + Vector2(0, -7), po + Vector2(3.5, 4), po + Vector2(-3.5, 4)]), Color(0.75, 0.5, 1.0))
		if qui == id:
			for e: Entita in gioco.ents.values():
				if e == io or e.tipo == "d" or e.morto:
					continue
				var pe := centro + Vector2(e.x - float(m.cx), e.z - float(m.cz)) * kk
				if pe.distance_to(centro) < rd:
					draw_circle(pe, 1.6 if e.tipo == "m" else 2.5, Color(0.95, 0.3, 0.25) if e.tipo == "m" else (Color(0.45, 0.95, 0.5) if e.tipo == "n" else Color(0.5, 0.78, 1.0)))
			_freccia(centro + Vector2(io.x - float(m.cx), io.z - float(m.cz)) * kk, io.r, Color(1.0, 0.93, 0.55), 7.0)
		if String(m.tipo) == "arena":
			# il loto cremisi al centro del pavimento
			draw_arc(centro, float(m.get("pavimento", 58)) * kk, 0, TAU, 48, Color(0.75, 0.2, 0.18), 2.0)
			for n in range(8):
				draw_circle(centro + Vector2(cos(TAU * n / 8.0), sin(TAU * n / 8.0)) * rd * 0.16, rd * 0.1, Color(0.82, 0.16, 0.16))
			draw_circle(centro, rd * 0.08, Color(0.98, 0.85, 0.5))
		_scritta(centro + Vector2(0, rd + 18.0), String(m.nome), 14, INCHIOSTRO)
		var sotto := "PvP · tutti contro tutti" if String(m.tipo) == "arena" else "liv. %d-%d · dal %d" % [int(m.liv[0]), int(m.liv[1]), int(m.minLvl)]
		if int(m.get("prezzo", 0)) > 0:
			sotto += " · %d tael" % int(m.prezzo)
		_scritta(centro + Vector2(0, rd + 33.0), sotto, 11, Color(1.0, 0.82, 0.45))
		i += 1

	# --- legenda e posizione
	var ly := foglio.end.y - 12.0
	var lx := _rett.position.x + 4.0
	for voce in [[Color(1.0, 0.93, 0.55), "tu"], [Color(0.45, 0.95, 0.5), "PNG / arrivo sicuro"], [Color(0.5, 0.78, 1.0), "giocatori"], [Color(0.95, 0.3, 0.25), "mostri vicini"], [Color(0.75, 0.5, 1.0), "obelischi"]]:
		draw_circle(Vector2(lx + 5, ly - 4), 4.0, voce[0])
		_scritta(Vector2(lx + 14, ly), voce[1], 12, INCHIOSTRO.darkened(0.1), false)
		lx += 26.0 + ThemeDB.fallback_font.get_string_size(voce[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var dove := Mappe.nome_zona(io.x, io.z) if qui != "" else ("Cripta delle Mille Lanterne" if not nel_mondo else _zona_mondo(io.x, io.z))
	_scritta(Vector2(foglio.end.x - 16.0 - ThemeDB.fallback_font.get_string_size("Sei qui: " + dove, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, ly), "Sei qui: " + dove, 13, Color(1.0, 0.93, 0.55), false)
	# zona sotto il puntatore
	var mouse := get_local_mouse_position()
	if _rett.has_point(mouse):
		var w := (mouse - _rett.position) / _rett.size * MEZZO * 2.0 - Vector2(MEZZO, MEZZO)
		_scritta(mouse + Vector2(0, -12), "%s  (%d, %d)" % [_zona_mondo(w.x, w.y), int(w.x), int(w.y)], 12, Color.WHITE)


func _articolo(corto: String) -> String:
	return ("del " if corto == "Drago" else "della ") + corto


## Nome della zona nel mondo aperto (stessa logica di `zoneAt` nel server).
func _zona_mondo(x: float, z: float) -> String:
	for kid: String in Dati.KINGDOMS:
		var v: Dictionary = Dati.KINGDOMS[kid].village
		if Vector2(x - float(v.x), z - float(v.z)).length() < float(Dati.costanti.get("SAFE_RADIUS", 30)):
			return String(Dati.KINGDOMS[kid].villageName)
	if maxf(absf(x), absf(z)) > 236.0:
		return "Monti Nebbiosi"
	if Vector2(x, z).length() < 95.0:
		return "Altopiano delle Spade Spezzate"
	for kid: String in Dati.KINGDOMS:
		var v: Dictionary = Dati.KINGDOMS[kid].village
		if Vector2(x - float(v.x), z - float(v.z)).length() < 125.0:
			return String(ANELLI.get(kid, ""))
	return "Terre di Confine"
