class_name IconeOggetti
extends RefCounted
## Icone degli OGGETTI, disegnate da codice (nessun file immagine, nessun kanji), nello stile di Icone.
## Una sola funzione per tutto: IconeOggetti.disegna(ci, id, rett, spento, rarita, potenziamento) dentro un _draw().
## Il disegno si ricava dal TIPO dell'oggetto (type, wt, tier, color, gem, grade, mod), non da un elenco di id:
##   weapon  -> sagoma del tipo (spada, pugnali, arco, pugni, bastone) nel grado 1-4 (come in forme_armi.gd)
##   body / head / feet -> corazza, elmo, calzari del grado 1-4
##   potion  -> fiala o tazza; scroll -> rotolo; book -> tomo; seal -> sigillo; key -> chiave
##   mod     -> pietra, rotolo, sigillo o scalpello a seconda di `mod`
##   gem     -> gemma sfaccettata nel suo colore (scheggia, gemma, perfetta)
##   material -> sagoma ricavata dalle parole dell'id (zanna, pelle, benda, coccio, minerale...) o sacchetto
## Id sconosciuti: simbolo generico per tipo, mai un errore. Fondo e cornice seguono la RARITÀ (0-4),
## in basso a sinistra compare il «+N» del potenziamento.

const SCURO := Icone.SCURO
const ACC := Icone.ACCIAIO
const ACC_O := Icone.ACCIAIO_O
const ORO := Icone.ORO
const ORO_O := Icone.ORO_O
const LEGNO := Icone.LEGNO
const BIANCO := Icone.BIANCO
const ROSSO := Icone.ROSSO
const AZZURRO := Icone.AZZURRO
const AZZURRO_C := Icone.AZZURRO_C
const VIOLA := Icone.VIOLA
const VIOLA_C := Icone.VIOLA_C
const GIADA := Icone.GIADA
const GIADA_C := Icone.GIADA_C
const BRONZO := Icone.BRONZO
const BRONZO_C := Icone.BRONZO_C
const PIETRA := Icone.PIETRA
const PIETRA_C := Icone.PIETRA_C
const CARTA := Color(0.93, 0.86, 0.68)

const RARITA_COL := [Color("#e8e0d0"), Color("#6ad86a"), Color("#5aa0ff"), Color("#c070ff"), Color("#ff9a30")]
const EQUIP := ["weapon", "body", "head", "feet"]

static var _nomi: Dictionary = {}
static var _tex: Dictionary = {}


# ------------------------------------------------------------------ rarità
static func colore_rarita(r: int) -> Color:
	var rr := clampi(r, 0, 4)
	var lista: Array = Dati.gioco.get("RARITIES", [])
	if rr < lista.size():
		return Color(String(lista[rr].color))
	return RARITA_COL[rr]


static func nome_rarita(r: int) -> String:
	var rr := clampi(r, 0, 4)
	var lista: Array = Dati.gioco.get("RARITIES", [])
	if rr < lista.size():
		return String(lista[rr].name)
	return ["Comune", "Pregiato", "Raro", "Epico", "Leggendario"][rr]


## Rarità da mostrare: per l'equipaggiamento quella dell'esemplare (campo `r`), per gli altri oggetti il `tier` o,
## in mancanza, un valore dedotto dal prezzo (così materiali e sigilli preziosi si distinguono dai comuni).
static func rarita(id: String, voce = null) -> int:
	var it: Dictionary = Dati.ITEMS.get(id, {})
	var tipo := String(it.get("type", ""))
	if voce is Dictionary and voce.has("r") and (tipo in EQUIP or int(voce.r) > 0):
		return clampi(int(voce.r), 0, 4)
	if tipo in EQUIP or tipo in ["potion", "scroll", ""]:
		return 0
	if it.has("tier"):
		return clampi(int(it.tier), 0, 4)
	var pr := int(it.get("price", 0))
	if pr >= 40000:
		return 4
	if pr >= 12000:
		return 3
	if pr >= 4000:
		return 2
	if pr >= 1000:
		return 1
	return 0


# ------------------------------------------------------------------ punto d'ingresso
## Disegna l'icona dell'oggetto `id` in `rett`. r < 0: rarità dedotta dall'oggetto. up: potenziamento (0 = nessun segno).
static func disegna(ci: CanvasItem, id: String, rett: Rect2, spento := false, r := -1, up := 0) -> void:
	var it: Dictionary = Dati.ITEMS.get(id, {})
	if r < 0:
		r = rarita(id)
	r = clampi(r, 0, 4)
	var col := colore_rarita(r)
	var s := Sarto.new()
	s.ci = ci
	s.spento = spento
	ci.draw_set_transform(rett.position, 0.0, rett.size / 100.0)
	s.sfondo(col, r)
	s.oggetto(id, it)
	s.vetro()
	s.cornice(col, r)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if up > 0:
		var f := ThemeDB.fallback_font
		var mis := int(clampf(rett.size.x * 0.27, 9.0, 20.0))
		var t := "+%d" % up
		var pos := rett.position + Vector2(rett.size.x * 0.06, rett.size.y * 0.06 + mis)
		ci.draw_string_outline(f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, mis, maxi(3, mis / 4), Color.BLACK)
		ci.draw_string(f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, mis, Color(1.0, 0.88, 0.42) if up < 9 else (Color(1.0, 0.6, 0.3) if up < 15 else Color(1.0, 0.45, 0.35)))


## Id dell'oggetto dal nome (le righe del bottino in chat portano solo il nome). Vuoto se non c'è.
static func id_da_nome(nome: String) -> String:
	if _nomi.is_empty():
		for i in Dati.ITEMS:
			_nomi[String(Dati.ITEMS[i].get("name", "")).to_lower()] = i
	return String(_nomi.get(nome.strip_edges().to_lower(), ""))


## Icona come texture (per le righe di chat e altri testi): si disegna una volta in un SubViewport sotto `host`.
static func texture(host: Node, id: String, r: int, up: int, dim: int) -> Texture2D:
	var chiave := "%s|%d|%d|%d" % [id, r, up, dim]
	if _tex.has(chiave) and is_instance_valid(_tex[chiave][0]):
		return _tex[chiave][1]
	var vp := SubViewport.new()
	vp.size = Vector2i(dim, dim)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var v := Vista.new(id, float(dim), r, up)
	v.size = Vector2(dim, dim)
	vp.add_child(v)
	host.add_child(vp)
	var t := vp.get_texture()
	_tex[chiave] = [vp, t]
	return t


## Descrizione con l'icona grande accanto: nome nel colore della rarità, poi le righe del testo.
static func tooltip(testo: String, id: String, r: int, up: int) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(Vista.new(id, 60.0, r, up))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	h.add_child(v)
	var righe := testo.split("\n")
	var l1 := Label.new()
	l1.text = righe[0]
	l1.add_theme_color_override("font_color", colore_rarita(r).lightened(0.15))
	v.add_child(l1)
	# le righe del confronto con il pezzo indossato hanno il loro colore: ▲ verde, ▼ e ✕ rosso
	for i in range(1, righe.size()):
		var riga := String(righe[i])
		var l2 := Label.new()
		l2.text = riga
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l2.custom_minimum_size = Vector2(240, 0)
		var col := Color(0.9, 0.88, 0.82)
		if riga.begins_with("▲"):
			col = Color(0.49, 0.91, 0.48)
		elif riga.begins_with("▼") or riga.begins_with("✕"):
			col = Color(1.0, 0.48, 0.42)
		l2.add_theme_color_override("font_color", col)
		v.add_child(l2)
	return h


## Controllo pronto: l'icona di un oggetto (id, rarità, potenziamento) con la quantità in basso a destra.
class Vista:
	extends Control
	var id := ""
	var r := -1
	var up := 0
	var n := 1
	var spento := false

	func _init(i := "", dim := 44.0, rar := -1, pot := 0) -> void:
		id = i
		r = rar
		up = pot
		custom_minimum_size = Vector2(dim, dim)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _make_custom_tooltip(for_text: String) -> Object:
		if for_text.is_empty():
			return null
		return IconeOggetti.tooltip(for_text, id, r if r >= 0 else IconeOggetti.rarita(id), up)

	func _draw() -> void:
		IconeOggetti.disegna(self, id, Rect2(Vector2.ZERO, size), spento, r, up)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.8), false, 1.5)
		if n > 1:
			var f := ThemeDB.fallback_font
			var t := str(n)
			var lt := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string_outline(f, Vector2(size.x - lt - 3, size.y - 3), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color.BLACK)
			draw_string(f, Vector2(size.x - lt - 3, size.y - 3), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


# ------------------------------------------------------------------ classificazione dei materiali (condivisa col modello a terra)
## Forma di un materiale/oggetto vario ricavata dall'id e dai dati: zanna, pelle, benda, coccio, minerale, cristallo,
## essenza, osso, erba, lingotto, polvere, sacchetto.
static func forma_materiale(id: String, it: Dictionary) -> String:
	var k := id.to_lower()
	var nome := String(it.get("name", "")).to_lower()
	var parole := {
		"zanna": ["zanna", "dente", "artiglio", "corno", "unghia"],
		"pelle": ["pelle", "cuoio", "pelliccia", "vello"],
		"benda": ["benda", "stoffa", "seta", "tessuto", "tela", "nastro"],
		"coccio": ["coccio", "cocci", "terracotta", "argilla", "ceramica"],
		"lingotto": ["lingotto", "barra"],
		"minerale": ["minerale", "ferro", "ore", "roccia", "sasso", "pietra"],
		"cristallo": ["frammento", "cristallo", "obelisco", "scheggia"],
		"essenza": ["essenza", "anima", "spirito", "lacrima"],
		"osso": ["osso", "ossa", "teschio"],
		"erba": ["erba", "radice", "fiore", "petalo", "foglia", "ginseng", "fungo"],
		"polvere": ["polvere", "cenere", "sabbia"],
	}
	for forma in ["zanna", "pelle", "benda", "coccio", "lingotto", "essenza", "osso", "erba", "polvere", "cristallo", "minerale"]:
		for p in parole[forma]:
			if k.contains(p) or nome.contains(p):
				return forma
	return "sacchetto"


static func colore_oggetto(it: Dictionary, base := Color(0.6, 0.6, 0.62)) -> Color:
	if it.has("color"):
		return Dati.colore(it.color)
	return base


# ================================================================== il pennello degli oggetti
class Sarto:
	extends Icone.Pennello

	func ell(cx: float, cy: float, rx: float, ry: float, n := 28) -> Array:
		var a: Array = []
		for i in n:
			var t := TAU * i / n
			a.append(Vector2(cx + cos(t) * rx, cy + sin(t) * ry))
		return a

	func chiaro(c: Color, f := 0.35) -> Color:
		return c.lightened(f)

	func scuro(c: Color, f := 0.35) -> Color:
		return c.darkened(f)

	func colore_oggetto(it: Dictionary, base := Color(0.6, 0.6, 0.62)) -> Color:
		return IconeOggetti.colore_oggetto(it, base)

	func vivo(c: Color) -> Color:
		return c.lightened(0.35) if c.get_luminance() < 0.22 else c

	# ---------------------------------------------------------------- fondo e cornice per rarità
	func sfondo(c: Color, r: int) -> void:
		var alto := Color(0.30, 0.30, 0.33)
		var basso := Color(0.07, 0.07, 0.09)
		var bag := Color(0.70, 0.70, 0.76)
		if r > 0:
			alto = c.darkened(0.55).lerp(Color(0.12, 0.12, 0.16), 0.25)
			basso = c.darkened(0.86)
			bag = c.lightened(0.1)
		fondo(alto, basso, bag)

	func cornice(c: Color, r: int) -> void:
		var pts: Array = [Vector2(7, 2), Vector2(93, 2), Vector2(98, 7), Vector2(98, 93), Vector2(93, 98), Vector2(7, 98), Vector2(2, 93), Vector2(2, 7), Vector2(7, 2)]
		var sp: float = [1.6, 3.0, 3.2, 3.6, 4.2][r]
		var cc := c if r > 0 else c.darkened(0.35)
		ci.draw_polyline(vs(pts), col(Color(cc.r, cc.g, cc.b, 0.95)), sp * k, true)
		if r >= 3:
			var interno: Array = [Vector2(10, 7), Vector2(90, 7), Vector2(93, 10), Vector2(93, 90), Vector2(90, 93), Vector2(10, 93), Vector2(7, 90), Vector2(7, 10), Vector2(10, 7)]
			ci.draw_polyline(vs(interno), col(Color(cc.r, cc.g, cc.b, 0.4)), 1.4 * k, true)
			scint(10, 10, 7, c.lightened(0.55), 0.8)
			scint(90, 90, 7, c.lightened(0.55), 0.8)
		if r >= 4:
			scint(90, 10, 6, ORO.lightened(0.3), 0.8)
			scint(10, 90, 6, ORO.lightened(0.3), 0.8)

	# ---------------------------------------------------------------- smistamento per tipo
	func oggetto(id: String, it: Dictionary) -> void:
		if id == "tael":
			monete()
			return
		var tipo := String(it.get("type", ""))
		var g := clampi(int(it.get("tier", 1)), 1, 4)
		match tipo:
			"weapon":
				match String(it.get("wt", "sword")):
					"daggers": pugnali(g)
					"bow": arco_p(g)
					"fists": pugni_p(g)
					"staff": bastone_p(g)
					_: spada(g)
			"body": corazza(g)
			"head": elmo(g)
			"feet": calzari(g)
			"potion": pozione(id, it)
			"scroll": rotolo(colore_oggetto(it, Color(0.7, 0.5, 0.2)), false)
			"book": libro(colore_oggetto(it, Color(0.2, 0.5, 0.35)))
			"seal": sigillo(colore_oggetto(it, Color(0.8, 0.7, 0.3)))
			"key": chiave(colore_oggetto(it, Color(0.7, 0.2, 0.2)))
			"mod": modificatore(String(it.get("mod", "")), colore_oggetto(it, Color(0.5, 0.5, 0.6)))
			"gem": gemma(it)
			"material": materiale(id, it)
			_: rune()

	func rune() -> void:
		arco(50, 50, 34, 0, 360, 4.0, ACC_O)
		esplosione(50, 50, 11, 26, 4, ACC, 45, 1.6)
		disco(50, 50, 6, ORO, 1.4)

	# ---------------------------------------------------------------- lame
	func _lp(t: float, y0: float, y1: float, w: float, curva: float, onda: float, punta: float, lato: float) -> Vector2:
		var y := lerpf(y0, y1, t)
		var xc := curva * t * t + onda * sin(t * TAU * 1.4)
		var hw := w * 0.5
		if t > 1.0 - punta:
			hw *= (1.0 - t) / punta
		return Vector2(xc + lato * hw, y)

	## Lama verticale in coordinate locali (la base a y0, la punta a y1 < y0). denti: [[t0, t1, altezza, lato], ...]
	func lama_p(y0: float, y1: float, w: float, curva: float, onda: float, c1: Color, c2: Color, punta := 0.2, denti := []) -> void:
		var n := 16
		var P: Array = []
		for i in n + 1:
			P.append(_lp(float(i) / n, y0, y1, w, curva, onda, punta, -1.0))
		for i in range(n, -1, -1):
			P.append(_lp(float(i) / n, y0, y1, w, curva, onda, punta, 1.0))
		for d in denti:
			var a := _lp(float(d[0]), y0, y1, w, curva, onda, punta, float(d[3]))
			var b := _lp(float(d[1]), y0, y1, w, curva, onda, punta, float(d[3]))
			var tip: Vector2 = a.lerp(b, 0.62) + Vector2(float(d[3]) * float(d[2]), 0.0)
			pol([a, tip, b], c1, SCURO, 1.3)
		pol(P, c1, SCURO, 0.0)
		var Q: Array = []
		for i in n + 1:
			Q.append(_lp(float(i) / n, y0, y1, w, curva, onda, punta, 0.0))
		for i in range(n, -1, -1):
			Q.append(_lp(float(i) / n, y0, y1, w, curva, onda, punta, 1.0))
		pol(Q, c2, SCURO, 0.0)
		var C: Array = []
		for i in range(1, n):
			C.append(_lp(float(i) / n, y0, y1, w, curva, onda, punta, 0.0))
		poli(C, 1.0, Color(0, 0, 0, 0.35))
		var O := P.duplicate()
		O.append(P[0])
		poli(O, 1.8, SCURO)

	func impugnatura(y0: float, y1: float, w: float, c: Color) -> void:
		pol([-w, y0, w, y0, w, y1, -w, y1], c, SCURO, 1.4)
		var y := y0 + 4.0
		while y < y1 - 1.0:
			lin(-w, y, w, y + 2.5, 1.0, c.lightened(0.35))
			y += 5.0

	func penna(x: float, y: float, ang: float, lung: float, larg: float, c1: Color, c2: Color) -> void:
		apri(Vector2(x, y), ang, 1.0)
		pol([0, 0, larg * 0.5, -lung * 0.3, larg * 0.42, -lung * 0.8, 0, -lung, -larg * 0.42, -lung * 0.8, -larg * 0.5, -lung * 0.3], c1, SCURO, 1.2)
		lin(0, -2, 0, -lung * 0.92, 1.0, c2)
		chiudi()

	# ---------------------------------------------------------------- spade
	func spada(g: int) -> void:
		var lame := [Color(0.74, 0.76, 0.80), Color(0.96, 0.72, 0.42), Color(0.58, 0.94, 0.80), Color(0.97, 0.98, 1.0)]
		var ombre := [Color(0.50, 0.52, 0.58), Color(0.74, 0.46, 0.22), Color(0.26, 0.64, 0.54), Color(0.62, 0.70, 0.90)]
		var guardie := [Color(0.42, 0.42, 0.48), BRONZO, ORO, ORO]
		var fasce := [Color(0.46, 0.26, 0.15), Color(0.66, 0.15, 0.10), Color(0.12, 0.34, 0.26), Color(0.16, 0.08, 0.14)]
		if g == 4:
			alone(50, 48, 42, ORO, 0.7)
		apri(Vector2(50, 52), 40.0, 1.0)
		var base := 15.0
		var coda := 36.0 if g < 3 else 45.0
		impugnatura(base, coda, 3.6, fasce[g - 1])
		disco(0, coda + 3.0, 4.4 if g < 3 else 5.2, guardie[g - 1], 1.4)
		match g:
			1:
				lama_p(base, -47, 16, 0, 0, lame[0], ombre[0], 0.18)
				osso(-15, base, 15, base, 5.5, guardie[0], 1.2)
			2:
				lama_p(base, -47, 13, 13, 0, lame[1], ombre[1], 0.26, [[0.78, 0.9, 5.0, 1.0]])
				mezz(0, 5, 18, 12, 168, 5.5, guardie[1])
			3:
				lama_p(base, -48, 16, 4, 0, lame[2], ombre[2], 0.2, [[0.28, 0.42, 7.0, -1.0], [0.48, 0.62, 7.0, -1.0], [0.68, 0.82, 6.0, -1.0]])
				pol([-4, base + 2, -21, base - 2, -25, base - 22, -17, base - 11, -4, base - 7], guardie[2], SCURO, 1.4)
				pol([4, base + 2, 21, base - 2, 25, base - 22, 17, base - 11, 4, base - 7], guardie[2], SCURO, 1.4)
				disco(0, base - 3, 3.6, Color(0.3, 1.0, 0.65), 1.0)
			_:
				lama_p(base, -53, 16, 4, 0, lame[3], ombre[3], 0.2, [[0.2, 0.32, 7.0, -1.0], [0.36, 0.48, 7.0, -1.0], [0.52, 0.64, 7.0, -1.0], [0.68, 0.8, 6.0, -1.0]])
				lin(1, base - 6, 4, -36, 2.0, Color(0.4, 0.95, 1.0))
				lin(1, base - 6, 4, -36, 0.8, Color(1, 1, 1))
				# ali di gru
				for s in [-1.0, 1.0]:
					penna(s * 4, base + 1, s * 62.0, 26, 9, ORO.lightened(0.2), ORO_O)
					penna(s * 4, base + 2, s * 40.0, 22, 8, BIANCO, ORO)
					penna(s * 4, base + 3, s * 82.0, 17, 7, BIANCO, ORO)
				disco(0, base + 1, 4.2, Color(1.0, 0.25, 0.2), 1.2)
		chiudi()

	# ---------------------------------------------------------------- pugnali
	func pugnali(g: int) -> void:
		if g == 4:
			alone(50, 50, 40, VIOLA, 0.7)
		apri(Vector2(50, 54), 36.0, 0.92)
		_pugnale(g)
		chiudi()
		apri(Vector2(50, 54), -36.0, 0.92)
		_pugnale(g)
		chiudi()

	func _pugnale(g: int) -> void:
		var lame := [Color(0.97, 0.93, 0.80), Color(0.82, 0.86, 0.93), Color(0.52, 0.90, 0.50), Color(0.24, 0.19, 0.36)]
		var ombre := [Color(0.76, 0.70, 0.56), Color(0.56, 0.60, 0.70), Color(0.26, 0.58, 0.28), Color(0.12, 0.09, 0.20)]
		var fasce := [Color(0.55, 0.30, 0.18), Color(0.20, 0.20, 0.26), Color(0.10, 0.28, 0.14), Color(0.55, 0.10, 0.22)]
		var base := 10.0
		impugnatura(base, 31.0, 3.2, fasce[g - 1])
		disco(0, 34, 3.8, ORO_O if g > 2 else ACC_O, 1.2)
		match g:
			1:
				lama_p(base, -42, 12, -12, 0, lame[0], ombre[0], 0.62)
				osso(-8, base, 8, base, 4, Color(0.7, 0.55, 0.35), 1.0)
			2:
				lama_p(base, -42, 10, 0, 0, lame[1], ombre[1], 0.22, [[0.2, 0.3, 4.0, 1.0], [0.34, 0.44, 4.0, 1.0], [0.48, 0.58, 4.0, 1.0], [0.62, 0.72, 4.0, 1.0]])
				osso(-9, base, 9, base, 4, ACC_O, 1.0)
			3:
				lama_p(base, -42, 13, 0, 3.0, lame[2], ombre[2], 0.2)
				disco(0, base + 1, 6.5, Color(0.40, 0.80, 0.40), 1.4)
				disco(-2.5, base - 0.5, 1.3, Color(1.0, 0.9, 0.2), 0.0)
				disco(2.5, base - 0.5, 1.3, Color(1.0, 0.9, 0.2), 0.0)
				lin(0, base + 7, -2, base + 11, 1.2, ROSSO)
				lin(0, base + 7, 2, base + 11, 1.2, ROSSO)
			_:
				lama_p(base, -43, 10, 3, 0, lame[3], ombre[3], 0.2)
				lin(5, base - 4, 7, -34, 1.6, Color(0.82, 0.55, 1.0))
				mezz(0, base - 2, 11, 10, 170, 4.0, Color(0.30, 0.24, 0.40))

	# ---------------------------------------------------------------- archi
	func arco_p(g: int) -> void:
		var legni := [Color(0.72, 0.80, 0.30), Color(0.92, 0.80, 0.56), Color(0.90, 0.95, 1.0), Color(0.88, 0.30, 0.16)]
		var l: Color = legni[g - 1]
		if g >= 3:
			alone(50, 50, 40, Color(1.0, 0.7, 0.3) if g == 4 else AZZURRO, 0.6)
		apri(Vector2(50, 52), -36.0, 1.0)
		var A := arcopts(-28, 0, 46, -54, 54, 22)
		poli(A, 7.0 + g * 0.4, SCURO)
		poli(A, 4.6 + g * 0.4, l)
		poli(A, 1.2, l.lightened(0.4))
		var a0: Vector2 = A[0]
		var a1: Vector2 = A[A.size() - 1]
		match g:
			1:
				for t in [0.25, 0.5, 0.75]:
					var p: Vector2 = A[int(t * (A.size() - 1))]
					lin(p.x - 3, p.y - 3, p.x + 3, p.y + 3, 1.2, Color(0.3, 0.4, 0.1))
			2:
				disco(a0.x, a0.y, 3.8, Color(0.25, 0.14, 0.10), 1.0)
				disco(a1.x, a1.y, 3.8, Color(0.25, 0.14, 0.10), 1.0)
				osso(14, -7, 14, 7, 6.5, Color(0.30, 0.16, 0.10), 1.0)
			3, 4:
				var pc: Color = Color(1.0, 1.0, 1.0) if g == 3 else Color(1.0, 0.72, 0.30)
				var pe: Color = AZZURRO if g == 3 else Color(0.85, 0.25, 0.12)
				for s in [-1.0, 1.0]:
					var b: Vector2 = a0 if s < 0 else a1
					for q in range(3 if g == 3 else 4):
						penna(b.x, b.y, (180.0 if s > 0 else 0.0) + (q - 1) * 26.0, 16.0 + 3.0 * (1 - absi(q - 1)), 7.0, pc, pe)
				if g == 4:
					pol([a0.x - 2, a0.y, a0.x + 4, a0.y - 12, a0.x + 6, a0.y], ACC, SCURO, 1.2)
					pol([a1.x - 2, a1.y, a1.x + 4, a1.y + 12, a1.x + 6, a1.y], ACC, SCURO, 1.2)
				osso(15, -7, 15, 7, 6.5, ORO_O, 1.0)
		lin(a0.x, a0.y, -14, 0, 1.6, BIANCO)
		lin(a1.x, a1.y, -14, 0, 1.6, BIANCO)
		freccia(-14, 0, 40, 0, ACC if g != 4 else ORO, 3.0)
		chiudi()

	# ---------------------------------------------------------------- pugni
	func guanto(c1: Color, c2: Color) -> void:
		pol([-10, 22, -10, 36, 10, 36, 10, 22], c2, SCURO, 1.6)
		pol([-19, -2, -15, -9, 15, -9, 19, -2, 19, 18, 12, 25, -12, 25, -19, 18], c1, SCURO, 1.8)
		for i in 4:
			disco(-13.5 + 9.0 * i, -7.0, 5.4, c1, 1.4)
		lin(-9, -2, -9, 11, 1.3, c2)
		lin(0, -2, 0, 11, 1.3, c2)
		lin(9, -2, 9, 11, 1.3, c2)
		pol([-21, 13, -4, 8, 14, 11, 15, 21, -2, 25, -18, 24], c1.darkened(0.12), SCURO, 1.6)
		lin(-14, 15, 9, 13, 1.2, c2)

	func artiglio(x: float, y: float, lung: float, curva: float, c: Color) -> void:
		pol([x - 3.4, y, x + 3.4, y, x + curva, y - lung * 0.7, x + curva * 1.6, y - lung], c, SCURO, 1.2)

	func pugni_p(g: int) -> void:
		if g == 4:
			alone(50, 52, 44, Color(1.0, 0.8, 0.3), 0.8)
		apri(Vector2(50, 56), 0.0, 1.15)
		match g:
			1:
				guanto(Color(0.96, 0.92, 0.82), Color(0.74, 0.68, 0.56))
				lin(-18, 2, 16, -4, 2.2, Color(0.80, 0.20, 0.18))
				lin(-18, 12, 18, 6, 2.2, Color(0.80, 0.20, 0.18))
				pol([-4, 34, 4, 34, 10, 46, 4, 44, 1, 49, -2, 44], Color(0.80, 0.20, 0.18), SCURO, 1.2)
			2:
				for i in 3:
					artiglio(-9.0 + 9.0 * i, -9.0, 24.0, 0.0, Color(0.80, 0.84, 0.92))
				guanto(Color(0.58, 0.58, 0.64), Color(0.38, 0.38, 0.44))
				pol([-19, -3, 19, -3, 19, 5, -19, 5], Color(0.70, 0.72, 0.80), SCURO, 1.4)
			3:
				for i in 4:
					artiglio(-13.5 + 9.0 * i, -10.0, 26.0, 4.0 - i * 2.2, Color(0.97, 0.94, 0.84))
				guanto(Color(0.95, 0.95, 0.98), Color(0.70, 0.72, 0.80))
				for i in 3:
					pol([-16 + i * 11, 0, -10 + i * 11, 0, -2 + i * 11, 22, -8 + i * 11, 22], Color(0.95, 0.52, 0.12), SCURO, 0.0)
			_:
				guanto(Color(1.0, 0.82, 0.30), Color(0.70, 0.44, 0.10))
				esplosione(0, 10, 7, 14, 8, ORO.lightened(0.4), 0, 1.0)
				disco(0, 10, 7, Color(1.0, 0.30, 0.18), 1.2)
				disco(0, 10, 3, Color(1.0, 0.85, 0.5), 0.0)
		chiudi()

	# ---------------------------------------------------------------- bastoni
	func bastone_p(g: int) -> void:
		var legni := [Color(0.62, 0.46, 0.26), Color(0.52, 0.22, 0.30), Color(0.62, 0.46, 0.26), Color(0.42, 0.22, 0.34)]
		var l: Color = legni[g - 1]
		if g >= 3:
			alone(58, 36, 36, AZZURRO if g == 3 else VIOLA_C, 0.7)
		apri(Vector2(45, 58), 36.0, 0.86)
		osso(0, 48, 0, -26, 6.5, l, 1.4)
		lin(-1.5, 40, -1.5, -22, 1.2, l.lightened(0.35))
		for y in [12.0, 20.0]:
			lin(-3.2, y, 3.2, y + 2, 1.4, SCURO)
		match g:
			1:
				poli([Vector2(0, -26), Vector2(-3, -34), Vector2(-10, -38), Vector2(-16, -33), Vector2(-14, -26)], 5.0, SCURO)
				poli([Vector2(0, -26), Vector2(-3, -34), Vector2(-10, -38), Vector2(-16, -33), Vector2(-14, -26)], 3.2, l)
				for q in [[-10, -39, -35.0], [-16, -33, -80.0], [2, -33, 30.0], [-4, -42, -10.0]]:
					penna(q[0], q[1], q[2], 13, 8, Color(0.50, 0.82, 0.32), Color(0.25, 0.5, 0.15))
				disco(-14, -26, 3.4, Color(1.0, 0.96, 0.8), 1.0)
			2:
				mezz(0, -34, 17, 200, 340, 7.0, Color(0.90, 0.80, 0.42))
				arco(0, -34, 14, 200, 340, 1.0, Color(1, 0.95, 0.7))
				for i in 5:
					var t := TAU * i / 5.0
					disco(cos(t) * 5.0, -36 + sin(t) * 5.0, 3.6, Color(1.0, 0.62, 0.78), 0.8)
				disco(0, -36, 2.4, Color(1.0, 0.86, 0.3), 0.0)
			3:
				arco(0, -38, 14, 0, 360, 6.0, SCURO)
				arco(0, -38, 14, 0, 360, 3.6, Color(0.62, 0.95, 0.82))
				disco(0, -38, 7.5, Color(0.46, 0.76, 1.0), 1.2)
				scint(-2.5, -41, 3, Color(1, 1, 1), 0.0)
				osso(-14, -38, -14, -34, 3, ORO, 0.8)
				osso(14, -38, 14, -34, 3, ORO, 0.8)
			_:
				nuvola(-9, -38, 0.42, Color(0.95, 0.93, 1.0))
				nuvola(10, -38, 0.42, Color(0.95, 0.93, 1.0))
				nuvola(0, -28, 0.36, Color(0.88, 0.84, 1.0))
				scint(0, -50, 10, VIOLA_C, 1.2)
				disco(0, -50, 5.2, Color(0.74, 0.50, 1.0), 1.2)
				scint(-14, -52, 4, BIANCO, 0.0)
				scint(15, -46, 3.5, BIANCO, 0.0)
		chiudi()

	# ---------------------------------------------------------------- armature
	func corazza(g: int) -> void:
		var panno := [Color(0.82, 0.74, 0.54), Color(0.62, 0.18, 0.14), Color(0.28, 0.76, 0.60), Color(0.20, 0.24, 0.52)]
		var piastra := [Color(0.82, 0.74, 0.54), Color(0.78, 0.30, 0.22), Color(0.46, 0.92, 0.76), Color(0.36, 0.42, 0.78)]
		var bordo := [Color(0.50, 0.36, 0.20), Color(0.92, 0.80, 0.50), ORO, ORO]
		var c: Color = panno[g - 1]
		var cp: Color = piastra[g - 1]
		var cb: Color = bordo[g - 1]
		if g == 4:
			alone(50, 50, 46, Color(0.5, 0.6, 1.0), 0.7)
		apri(Vector2(50, 53), 0.0, 0.98)
		pol([-12, -38, 12, -38, 36, -28, 46, -6, 30, -2, 24, -10, 24, 40, -24, 40, -24, -10, -30, -2, -46, -6, -36, -28], c, SCURO, 2.0)
		if g == 1:
			pol([-9, -38, 9, -38, 0, -17], SCURO.lightened(0.15), SCURO, 1.0)
			pol([-24, 16, 24, 16, 24, 25, -24, 25], cb, SCURO, 1.4)
			lin(0, -17, 0, 16, 1.3, cb.darkened(0.3))
			lin(-24, -8, -24, 40, 1.2, c.darkened(0.25))
			for q in [-34, 34]:
				lin(q, -22, q + (6 if q > 0 else -6), -8, 1.2, c.darkened(0.3))
		else:
			# file di piastre sul busto
			for riga in 7:
				var y := -16.0 + riga * 8.6
				var off := 0.0 if riga % 2 == 0 else 4.0
				var x := -24.0 - off
				while x < 22.0:
					var xa := maxf(x, -24.0)
					var xb := minf(x + 8.0, 24.0)
					if xb - xa > 1.5:
						pol([xa, y, xb, y, xb, y + 9.4, xa, y + 9.4], cp if (riga + int(x)) % 2 == 0 else cp.darkened(0.12), SCURO, 0.9)
					x += 8.0
			lin(0, -16, 0, 40, 1.6, cb)
			pol([-24, 36, 24, 36, 24, 41, -24, 41], cb, SCURO, 1.2)
			# spallacci a lame
			for s in [-1.0, 1.0]:
				for q in 3:
					pol(ell(s * (33 + q * 2.5), -22 + q * 7.0, 14.0 - q, 7.5), cp.darkened(0.08 * q), SCURO, 1.3)
					arco(s * (33 + q * 2.5), -22 + q * 7.0, 11.0 - q, 200, 340, 1.0, cb)
		if g == 3:
			disco(0, -6, 10, GIADA_C, 1.6)
			arco(0, -6, 10, 0, 360, 2.2, ORO)
			disco(0, -6, 3.5, Color(0.1, 0.4, 0.3), 0.0)
			pol([-12, -38, 12, -38, 0, -28], ORO, SCURO, 1.2)
		if g == 4:
			for s in [-1.0, 1.0]:
				for q in 3:
					pol([s * (28 + q * 6), -28, s * (44 + q * 7), -48 + q * 5, s * (38 + q * 6), -24], ORO, SCURO, 1.2)
			spirale(0, 8, 2.0, 11.0, 1.8, 0.0, 2.0, ORO)
			disco(0, -24, 5.5, AZZURRO_C, 1.4)
			scint(-1.5, -25.5, 2.5, BIANCO, 0.0)
			pol([-24, 36, 24, 36, 24, 41, -24, 41], ORO, SCURO, 1.2)
		chiudi()

	# ---------------------------------------------------------------- elmi
	func elmo(g: int) -> void:
		if g == 4:
			alone(50, 50, 42, Color(1.0, 0.4, 0.25), 0.6)
		apri(Vector2(50, 54), 0.0, 1.0)
		match g:
			1:
				var paglia := Color(0.94, 0.82, 0.46)
				pol([-44, 14, 0, -34, 44, 14, 36, 20, 0, 24, -36, 20], paglia, SCURO, 2.0)
				pol([0, -34, 44, 14, 36, 20, 0, 24], paglia.darkened(0.18), SCURO, 0.0)
				for q in [-30, -16, 0, 16, 30]:
					lin(0, -34, q * 1.35, 16, 1.0, paglia.darkened(0.35))
				for q in [-14.0, -2.0, 10.0]:
					poli(ell(0, q + 4, 18 + (q + 14) * 1.15, 3.0, 12).slice(0, 7), 1.0, paglia.darkened(0.35))
				pol([-44, 14, 0, 24, 44, 14, 38, 22, 0, 30, -38, 22], paglia.darkened(0.25), SCURO, 1.4)
				lin(-30, 20, -22, 44, 1.6, ROSSO)
				lin(30, 20, 22, 44, 1.6, ROSSO)
				disco(0, -34, 3, BRONZO, 1.0)
			2:
				var br := BRONZO_C
				pol([-26, 6, -26, -8, -18, -22, 0, -28, 18, -22, 26, -8, 26, 6], br, SCURO, 2.0)
				pol([0, -28, 18, -22, 26, -8, 26, 6, 0, 6], br.darkened(0.2), SCURO, 0.0)
				pol([-30, 4, 30, 4, 30, 13, -30, 13], BRONZO, SCURO, 1.6)
				pol([-30, 13, -22, 13, -20, 36, -30, 30], BRONZO, SCURO, 1.6)
				pol([30, 13, 22, 13, 20, 36, 30, 30], BRONZO.darkened(0.15), SCURO, 1.6)
				pol([-4, 13, 4, 13, 4, 30, 0, 34, -4, 30], BRONZO, SCURO, 1.4)
				pol([-4, -28, 4, -28, 3, -42, -3, -42], ROSSO, SCURO, 1.2)
				for q in [-18, -9, 0, 9, 18]:
					disco(q, 8.5, 1.4, SCURO.lightened(0.4), 0.0)
			3:
				var fe := Color(0.52, 0.54, 0.64)
				for s in [-1.0, 1.0]:
					poli([Vector2(s * 26, -4), Vector2(s * 36, -12), Vector2(s * 42, -26), Vector2(s * 40, -42)], 9.0, SCURO)
					poli([Vector2(s * 26, -4), Vector2(s * 36, -12), Vector2(s * 42, -26), Vector2(s * 40, -42)], 6.0, Color(0.94, 0.92, 0.84))
					poli([Vector2(s * 26, -4), Vector2(s * 36, -12), Vector2(s * 42, -26)], 6.4, Color(0.60, 0.56, 0.50))
				pol([-26, 8, -26, -8, -18, -24, 0, -30, 18, -24, 26, -8, 26, 8], fe, SCURO, 2.0)
				pol([0, -30, 18, -24, 26, -8, 26, 8, 0, 8], fe.darkened(0.22), SCURO, 0.0)
				pol([-28, 4, 28, 4, 28, 12, -28, 12], ORO, SCURO, 1.6)
				pol([-28, 12, -20, 12, -18, 38, -28, 32], fe, SCURO, 1.6)
				pol([28, 12, 20, 12, 18, 38, 28, 32], fe.darkened(0.2), SCURO, 1.6)
				pol([-18, 14, 18, 14, 14, 30, -14, 30], Color(0.06, 0.05, 0.08), SCURO, 1.2)
				lin(-12, 21, -4, 21, 2.0, Color(1.0, 0.7, 0.2))
				lin(12, 21, 4, 21, 2.0, Color(1.0, 0.7, 0.2))
				disco(0, -14, 3.4, ORO, 1.0)
			_:
				var rs := Color(0.50, 0.14, 0.18)
				for s in [-1.0, 1.0]:
					poli([Vector2(s * 26, 0), Vector2(s * 40, -6), Vector2(s * 48, -22), Vector2(s * 40, -38)], 8.0, SCURO)
					poli([Vector2(s * 26, 0), Vector2(s * 40, -6), Vector2(s * 48, -22), Vector2(s * 40, -38)], 5.0, ORO)
				for q in 5:
					var x := -20.0 + q * 10.0
					var h: float = 14.0 + (2 - absi(q - 2)) * 7.0
					pol([x - 5, -26, x, -26 - h, x + 5, -26], ORO if q % 2 == 0 else Color(0.95, 0.4, 0.25), SCURO, 1.2)
				pol([-27, 8, -27, -8, -18, -24, 0, -30, 18, -24, 27, -8, 27, 8], rs, SCURO, 2.0)
				pol([0, -30, 18, -24, 27, -8, 27, 8, 0, 8], rs.darkened(0.25), SCURO, 0.0)
				pol([-29, 3, 29, 3, 29, 11, -29, 11], ORO, SCURO, 1.6)
				pol([-29, 11, -20, 11, -18, 30, -29, 26], rs, SCURO, 1.6)
				pol([29, 11, 20, 11, 18, 30, 29, 26], rs.darkened(0.2), SCURO, 1.6)
				pol([-16, 14, 16, 14, 12, 38, 6, 32, 0, 40, -6, 32, -12, 38], Color(0.10, 0.04, 0.06), SCURO, 1.2)
				for q in [-9.0, -3.0, 3.0, 9.0]:
					pol([q - 2, 32, q, 38, q + 2, 32], BIANCO, SCURO, 0.8)
				pol([-20, -8, -6, -4, -8, 2, -22, 0], Color(1.0, 0.75, 0.2), SCURO, 1.0)
				pol([20, -8, 6, -4, 8, 2, 22, 0], Color(1.0, 0.75, 0.2), SCURO, 1.0)
		chiudi()

	# ---------------------------------------------------------------- calzari
	func calzari(g: int) -> void:
		if g >= 3:
			alone(50, 56, 40, Color(0.6, 0.95, 1.0) if g == 3 else Color(1.0, 0.9, 0.6), 0.6)
		apri(Vector2(48, 50), 0.0, 0.96)
		match g:
			1:
				var corda := Color(0.84, 0.70, 0.40)
				pol([-24, 26, 8, 22, 40, 26, 46, 34, 40, 40, -22, 40, -28, 34], corda.darkened(0.2), SCURO, 2.0)
				pol([-24, 26, 8, 22, 40, 26, 46, 34, 40, 40, -22, 40, -28, 34], Color(0.62, 0.46, 0.24), SCURO, 0.0)
				pol([-22, 24, 8, 20, 38, 24, 40, 30, -22, 32], corda, SCURO, 1.4)
				for q in [-8.0, 6.0]:
					lin(q, 24, q + 14, -12, 4.0, SCURO)
					lin(q, 24, q + 14, -12, 2.4, corda)
					lin(q + 14, 24, q, -12, 4.0, SCURO)
					lin(q + 14, 24, q, -12, 2.4, corda)
				arco(-6, -14, 14, 180, 360, 4.0, SCURO)
				arco(-6, -14, 14, 180, 360, 2.4, corda)
				lin(-20, 34, 38, 34, 1.0, Color(0.5, 0.36, 0.2))
			2:
				var cu := Color(0.60, 0.36, 0.18)
				pol([-18, -38, 14, -38, 14, 2, 36, 12, 46, 26, 42, 40, -20, 40, -22, 18], cu, SCURO, 2.0)
				pol([-4, -38, 14, -38, 14, 2, 36, 12, 46, 26, 42, 40, -4, 40], cu.darkened(0.18), SCURO, 0.0)
				pol([-20, 34, 42, 34, 44, 44, -22, 44], Color(0.22, 0.14, 0.10), SCURO, 1.6)
				pol([-20, -38, 16, -38, 16, -28, -20, -28], cu.lightened(0.2), SCURO, 1.4)
				pol([-4, -8, 14, -8, 14, 0, -4, 0], ORO_O, SCURO, 1.2)
				lin(-14, -22, -14, 24, 1.0, cu.lightened(0.4))
				arco(26, 22, 12, 180, 270, 1.2, cu.lightened(0.4))
			3:
				var te := Color(0.20, 0.64, 0.72)
				pol([-18, -34, 14, -34, 14, 4, 36, 12, 46, 26, 42, 40, -20, 40, -22, 18], te, SCURO, 2.0)
				pol([-2, -34, 14, -34, 14, 4, 36, 12, 46, 26, 42, 40, -2, 40], te.darkened(0.22), SCURO, 0.0)
				pol([-20, 34, 42, 34, 44, 44, -22, 44], Color(0.12, 0.22, 0.30), SCURO, 1.6)
				pol([-20, -34, 16, -34, 16, -24, -20, -24], BIANCO, SCURO, 1.4)
				for q in 3:
					penna(-20, -22 + q * 6.0, -90.0 - q * 18.0 + 0.0, 24.0 - q * 3.0, 9.0, BIANCO, AZZURRO)
				for q in 3:
					lin(-30, 6 + q * 8.0, -44, 6 + q * 8.0, 2.0, Color(0.7, 0.95, 1.0))
			_:
				var bi := Color(0.90, 0.88, 1.0)
				pol([-18, -34, 14, -34, 14, 4, 36, 12, 46, 26, 42, 38, -20, 38, -22, 18], bi, SCURO, 2.0)
				pol([-2, -34, 14, -34, 14, 4, 36, 12, 46, 26, 42, 38, -2, 38], bi.darkened(0.2), SCURO, 0.0)
				pol([-20, -34, 16, -34, 16, -24, -20, -24], ORO, SCURO, 1.4)
				disco(-2, -29, 3.6, Color(0.5, 0.8, 1.0), 1.0)
				pol([-20, 30, 42, 30, 44, 40, -22, 40], ORO, SCURO, 1.4)
				nuvola(-8, 40, 0.34, Color(1, 1, 1))
				nuvola(16, 42, 0.38, Color(0.96, 0.94, 1.0))
				nuvola(38, 40, 0.3, Color(1, 1, 1))
				spirale(-4, 0, 1.0, 7.0, 1.6, 0.0, 1.6, ORO)
				penna(-20, -10, -100.0, 20, 8, BIANCO, VIOLA_C)
		chiudi()

	# ---------------------------------------------------------------- pozioni, rotoli, libri
	func fiala(c: Color, sc: float) -> void:
		apri(Vector2(50, 54), 0.0, sc)
		pol([-6, -38, 6, -38, 6, -24, 22, -4, 22, 30, 14, 38, -14, 38, -22, 30, -22, -4, -6, -24], Color(0.85, 0.95, 1.0, 0.55), SCURO, 2.0)
		pol([-19, 4, 19, 4, 19, 29, 12, 35, -12, 35, -19, 29], c, SCURO, 0.0)
		pol([-19, 4, 19, 4, 17, 9, -17, 9], c.lightened(0.35), SCURO, 0.0)
		pol([-8, -42, 8, -42, 8, -36, -8, -36], LEGNO, SCURO, 1.4)
		pol([-14, 10, -10, 10, -10, 28, -14, 24], Color(1, 1, 1, 0.45), SCURO, 0.0)
		chiudi()

	func pozione(id: String, it: Dictionary) -> void:
		if Icone.MAPPA.has(id):
			var nome := String(Icone.MAPPA[id][1])
			if nome.begins_with("pozione_") or nome.begins_with("te_"):
				disegno(nome)
				return
		var c := colore_oggetto(it, Color(0.7, 0.2, 0.2))
		if it.has("mpPct") and not it.has("color"):
			c = Color(0.2, 0.4, 0.8)
		var pr := float(it.get("price", 100))
		fiala(c, 0.85 if pr < 60 else (1.0 if pr < 200 else 1.15))

	func rotolo(c: Color, vortice: bool) -> void:
		apri(Vector2(50, 52), -28.0, 1.0)
		pol([-34, -14, 34, -14, 34, 14, -34, 14], CARTA, SCURO, 1.6)
		pol([-34, 4, 34, 4, 34, 14, -34, 14], CARTA.darkened(0.18), SCURO, 0.0)
		for q in 3:
			lin(-26, -7 + q * 6.0, 8 + q * 4.0, -7 + q * 6.0, 1.2, Color(0.4, 0.28, 0.16, 0.7))
		for s in [-1.0, 1.0]:
			pol(ell(s * 34, 0, 8, 16), CARTA.darkened(0.12), SCURO, 1.6)
			arco(s * 34, 0, 4.5, 0, 300, 1.2, Color(0.5, 0.36, 0.2))
			osso(s * 40, -19, s * 40, 19, 4.4, LEGNO, 1.0)
		pol([-5, -16, 5, -16, 5, 16, -5, 16], c, SCURO, 1.4)
		disco(0, 0, 7.5, c.lightened(0.15), 1.4)
		disco(0, 0, 3.4, c.darkened(0.3), 0.0)
		if vortice:
			spirale(18, 0, 2.0, 8.0, 1.4, 0.0, 1.8, c)
		chiudi()

	func libro(c: Color) -> void:
		apri(Vector2(50, 52), -8.0, 1.0)
		pol([24, -32, 31, -28, 31, 34, 24, 38], CARTA, SCURO, 1.4)
		for q in 5:
			lin(25, -26 + q * 12.0, 30, -24 + q * 12.0, 0.8, Color(0.5, 0.4, 0.28))
		pol([-28, -36, 24, -36, 24, 38, -28, 38], c, SCURO, 2.0)
		pol([-28, -36, -20, -36, -20, 38, -28, 38], c.darkened(0.3), SCURO, 1.0)
		for yy in [-36.0, 38.0]:
			pol([-28, yy - 2, -16, yy - 2, -16, yy + (4 if yy < 0 else -4), -28, yy + (4 if yy < 0 else -4)], ORO, SCURO, 1.0)
			pol([12, yy - 2, 24, yy - 2, 24, yy + (4 if yy < 0 else -4), 12, yy + (4 if yy < 0 else -4)], ORO, SCURO, 1.0)
		arco(2, 0, 13, 0, 360, 2.4, ORO)
		esplosione(2, 0, 4, 9, 4, ORO, 45, 1.0)
		pol([-28, 20, 24, 20, 24, 26, -28, 26], ORO_O, SCURO, 1.0)
		chiudi()

	func sigillo(c: Color) -> void:
		apri(Vector2(50, 52), 0.0, 1.0)
		pol(ell(0, -28, 14, 14), c.lightened(0.15), SCURO, 1.8)
		pol([-9, -18, 9, -18, 13, 6, -13, 6], c, SCURO, 1.8)
		pol([-28, 4, 28, 4, 28, 26, -28, 26], c.darkened(0.12), SCURO, 2.0)
		pol([-28, 4, 28, 4, 28, 10, -28, 10], c.lightened(0.3), SCURO, 0.0)
		pol([-22, 26, 22, 26, 22, 36, -22, 36], Color(0.78, 0.12, 0.10), SCURO, 1.6)
		pol([-16, 28, 16, 28, 16, 34, -16, 34], Color(0.95, 0.4, 0.3), SCURO, 0.0)
		lin(-5, 14, 5, 14, 1.4, SCURO)
		lin(0, 10, 0, 22, 1.4, SCURO)
		chiudi()

	func chiave(c: Color) -> void:
		alone(50, 50, 38, c, 0.5)
		apri(Vector2(50, 52), -40.0, 1.0)
		osso(0, 22, 0, -32, 6.5, ORO, 1.4)
		pol([6, -32, 20, -32, 20, -24, 12, -24, 12, -18, 20, -18, 20, -10, 6, -10], ORO, SCURO, 1.4)
		arco(0, 34, 15, 0, 360, 7.0, SCURO)
		arco(0, 34, 15, 0, 360, 4.4, ORO)
		disco(0, 34, 8, vivo(c), 1.4)
		scint(-2, 32, 3.5, BIANCO, 0.0)
		chiudi()

	func modificatore(mod: String, c: Color) -> void:
		match mod:
			"refine":
				# pietra d'affinamento: cote con scintille e goccia d'acqua
				apri(Vector2(50, 54), -14.0, 1.0)
				pol([-36, 4, 30, -10, 38, 10, -30, 24], Color(0.50, 0.56, 0.62), SCURO, 2.0)
				pol([-36, 4, 30, -10, 32, -4, -34, 10], Color(0.72, 0.78, 0.84), SCURO, 0.0)
				pol([-30, 24, 38, 10, 38, 18, -30, 32], Color(0.34, 0.38, 0.44), SCURO, 1.4)
				lin(-20, 6, 20, -2, 1.0, Color(0.9, 0.95, 1.0, 0.6))
				chiudi()
				scint(20, 22, 9, Color(1.0, 0.95, 0.6), 0.9)
				scint(70, 34, 6, Color(1.0, 0.95, 0.6), 0.8)
				goccia(32, 62, 7, AZZURRO, 1.2)
			"reroll":
				rotolo(Color(0.60, 0.20, 0.50), false)
				arco(50, 50, 30, 200, 330, 4.0, SCURO)
				arco(50, 50, 30, 200, 330, 2.4, VIOLA_C)
				arco(50, 50, 30, 20, 150, 4.0, SCURO)
				arco(50, 50, 30, 20, 150, 2.4, VIOLA_C)
				pol([76, 40, 86, 50, 70, 54], VIOLA_C, SCURO, 1.0)
				pol([24, 60, 14, 50, 30, 46], VIOLA_C, SCURO, 1.0)
			"ascend":
				alone(50, 40, 36, VIOLA_C, 0.9)
				sigillo(c.lerp(VIOLA, 0.4))
				pol([50, 6, 64, 24, 55, 24, 55, 38, 45, 38, 45, 24, 36, 24], Color(1.0, 0.88, 0.4), SCURO, 1.4)
			"extract":
				# scalpello del gioielliere
				apri(Vector2(50, 52), 38.0, 1.0)
				osso(0, 46, 0, 12, 9.0, LEGNO.lightened(0.1), 1.4)
				pol([-6, 12, 6, 12, 5, 6, -5, 6], ORO_O, SCURO, 1.2)
				pol([-4, 6, 4, 6, 4, -34, 0, -46, -4, -34], ACC, SCURO, 1.6)
				pol([0, 6, 4, 6, 4, -34, 0, -46], ACC_O, SCURO, 0.0)
				chiudi()
				pol([22, 74, 28, 66, 34, 72, 30, 80, 24, 80], GIADA, SCURO, 1.0)
				scint(72, 28, 7, BIANCO, 0.8)
			_:
				pol(ell(50, 50, 28, 32, 8), PIETRA, SCURO, 2.0)
				esplosione(50, 50, 8, 18, 4, c.lightened(0.4), 45, 1.2)

	# ---------------------------------------------------------------- gemme
	func gemma(it: Dictionary) -> void:
		var c := vivo(colore_oggetto(it, Color(0.8, 0.3, 0.3)))
		var kind := String(it.get("gem", ""))
		var gr := int(it.get("grade", 1))
		if gr >= 2:
			alone(50, 50, 44, c, 0.9)
		if gr <= 0:
			# scheggia: tre frammenti taglienti
			apri(Vector2(34, 60), -20.0, 0.6)
			_cristallo(c)
			chiudi()
			apri(Vector2(66, 62), 25.0, 0.5)
			_cristallo(c.darkened(0.12))
			chiudi()
			apri(Vector2(50, 40), 5.0, 0.7)
			_cristallo(c.lightened(0.08))
			chiudi()
			return
		apri(Vector2(50, 52), 0.0, 1.05 if gr == 1 else 1.3)
		match kind:
			"zaffiro": _gemma_esa(c)
			"giada": _gemma_bi(c)
			"ambra": _gemma_ovale(c)
			"onice": _gemma_onice(c)
			"perla": _gemma_perla(c)
			_: _gemma_brillante(c)
		chiudi()
		if gr >= 2:
			scint(22, 22, 8, BIANCO, 0.8)
			scint(80, 70, 6, BIANCO, 0.8)
			scint(78, 20, 5, c.lightened(0.5), 0.6)

	func _cristallo(c: Color) -> void:
		pol([-12, 10, -16, -14, -4, -34, 8, -22, 14, 4, 6, 20], c, SCURO, 1.8)
		pol([-4, -34, 8, -22, 14, 4, 6, 20, -2, 6], c.darkened(0.25), SCURO, 0.0)
		pol([-12, 10, -16, -14, -4, -34, -2, 6], c.lightened(0.35), SCURO, 0.0)
		lin(-4, -34, -2, 6, 1.0, SCURO)

	func _gemma_brillante(c: Color) -> void:
		pol([-30, -12, -16, -28, 16, -28, 30, -12, 0, 34], c, SCURO, 2.2)
		pol([-30, -12, -8, -12, 0, 34], c.darkened(0.25), SCURO, 1.0)
		pol([30, -12, 8, -12, 0, 34], c.darkened(0.42), SCURO, 1.0)
		pol([-8, -12, 8, -12, 0, 34], c, SCURO, 1.0)
		pol([-30, -12, -16, -28, -8, -12], c.lightened(0.45), SCURO, 1.0)
		pol([-16, -28, 16, -28, 8, -12, -8, -12], c.lightened(0.62), SCURO, 1.0)
		pol([16, -28, 30, -12, 8, -12], c.lightened(0.2), SCURO, 1.0)

	func _gemma_esa(c: Color) -> void:
		pol([-18, -30, 18, -30, 34, 0, 18, 30, -18, 30, -34, 0], c, SCURO, 2.2)
		pol([-9, -15, 9, -15, 17, 0, 9, 15, -9, 15, -17, 0], c.lightened(0.45), SCURO, 1.2)
		for q in [[-18, -30, -9, -15], [18, -30, 9, -15], [34, 0, 17, 0], [18, 30, 9, 15], [-18, 30, -9, 15], [-34, 0, -17, 0]]:
			lin(q[0], q[1], q[2], q[3], 1.2, SCURO)
		pol([-18, -30, 18, -30, 9, -15, -9, -15], c.lightened(0.25), SCURO, 0.8)
		pol([18, 30, -18, 30, -9, 15, 9, 15], c.darkened(0.35), SCURO, 0.8)

	func _gemma_bi(c: Color) -> void:
		disco(0, 0, 33, c, 2.2)
		arco(0, 0, 26, 200, 330, 3.0, c.lightened(0.5))
		arco(0, 0, 22, 20, 150, 3.0, c.darkened(0.3))
		disco(0, 0, 10, Color(0.05, 0.1, 0.1), 1.8)
		scint(-17, -17, 5, BIANCO, 0.0)

	func _gemma_ovale(c: Color) -> void:
		pol(ell(0, 2, 24, 32), c, SCURO, 2.2)
		pol(ell(3, 8, 17, 22), c.darkened(0.22), SCURO, 0.0)
		pol(ell(-6, -10, 8, 12), c.lightened(0.55), SCURO, 0.0)
		pol(ell(2, 6, 3.4, 8), Color(0.25, 0.14, 0.05), SCURO, 0.0)
		lin(2, -2, -4, 4, 1.0, Color(0.25, 0.14, 0.05))
		lin(2, -2, 8, 4, 1.0, Color(0.25, 0.14, 0.05))

	func _gemma_onice(c: Color) -> void:
		pol([-14, -32, 14, -32, 26, -18, 26, 18, 14, 32, -14, 32, -26, 18, -26, -18], c.darkened(0.1), SCURO, 2.2)
		pol([-9, -20, 9, -20, 15, -10, 15, 10, 9, 20, -9, 20, -15, 10, -15, -10], c.darkened(0.45), SCURO, 1.4)
		pol([-14, -32, 14, -32, 9, -20, -9, -20], c.lightened(0.5), SCURO, 0.8)
		pol([-26, -18, -14, -32, -9, -20, -15, -10], c.lightened(0.3), SCURO, 0.8)
		lin(-8, -4, -2, -14, 2.0, Color(1, 1, 1, 0.6))

	func _gemma_perla(c: Color) -> void:
		disco(0, 0, 29, c.lightened(0.1), 2.2)
		disco(5, 6, 22, c.darkened(0.12), 0.0)
		disco(-4, -4, 18, Color(0.95, 0.9, 1.0), 0.0)
		disco(-10, -12, 6, BIANCO, 0.0)
		arco(0, 0, 24, 20, 100, 2.0, Color(0.7, 0.8, 1.0, 0.8))

	# ---------------------------------------------------------------- materiali
	func materiale(id: String, it: Dictionary) -> void:
		var c := colore_oggetto(it, Color(0.6, 0.55, 0.45))
		match IconeOggetti.forma_materiale(id, it):
			"zanna":
				apri(Vector2(34, 54), -24.0, 1.0)
				_dente(Color(0.96, 0.92, 0.80))
				chiudi()
				apri(Vector2(64, 50), 28.0, 0.85)
				_dente(Color(0.90, 0.86, 0.74))
				chiudi()
			"pelle":
				apri(Vector2(50, 52), 0.0, 1.0)
				pol([-34, -18, -12, -28, 12, -22, 34, -16, 28, 6, 36, 26, 10, 18, -8, 30, -24, 16, -36, 4], c.lightened(0.15), SCURO, 2.0)
				pol([-8, -24, 12, -22, 34, -16, 28, 6, 36, 26, 10, 18, -4, 6], c.darkened(0.2), SCURO, 0.0)
				for q in 7:
					var p := Vector2(-22 + q * 8.0, -12 + sin(q * 1.7) * 10.0)
					lin(p.x, p.y, p.x + 2, p.y + 6, 1.4, c.darkened(0.45))
				lin(-30, 6, 28, 2, 1.0, c.darkened(0.5))
				chiudi()
			"benda":
				apri(Vector2(50, 52), 0.0, 1.0)
				pol(ell(0, 0, 26, 26), c.lightened(0.1), SCURO, 2.0)
				spirale(0, 0, 3.0, 22.0, 3.0, 0.0, 3.0, c.darkened(0.3))
				pol([14, 14, 30, 22, 40, 42, 28, 38, 22, 46, 18, 30], c, SCURO, 1.6)
				lin(20, 24, 30, 36, 1.0, c.darkened(0.4))
				chiudi()
			"coccio":
				apri(Vector2(50, 52), 0.0, 1.0)
				pol([-30, 6, -20, -22, 6, -30, 30, -10, 26, 20, 4, 30, -14, 26], c, SCURO, 2.0)
				pol([6, -30, 30, -10, 26, 20, 4, 30, 0, 0], c.darkened(0.25), SCURO, 0.0)
				pol([-30, 6, -20, -22, 6, -30, 0, 0], c.lightened(0.25), SCURO, 0.0)
				arco(-4, 2, 14, 190, 350, 2.0, c.darkened(0.5))
				arco(-4, 2, 8, 190, 350, 2.0, c.darkened(0.5))
				lin(-14, 26, -4, 2, 1.2, SCURO)
				chiudi()
			"lingotto":
				apri(Vector2(50, 52), 0.0, 1.0)
				pol([-34, 10, -24, -10, 24, -10, 34, 10], c.lightened(0.3), SCURO, 2.0)
				pol([-34, 10, 34, 10, 34, 28, -34, 28], c, SCURO, 2.0)
				pol([-34, 10, -24, -10, -22, 10], c.lightened(0.5), SCURO, 0.0)
				scint(14, -2, 6, BIANCO, 0.0)
				chiudi()
			"essenza":
				alone(50, 50, 40, c, 1.0)
				disco(50, 54, 22, c.lightened(0.2), 2.0)
				disco(54, 58, 16, c, 0.0)
				disco(43, 46, 7, Color(1, 1, 1, 0.85), 0.0)
				goccia(50, 22, 7, c.lightened(0.5), 1.2)
				spirale(50, 54, 4.0, 18.0, 1.3, 30.0, 1.8, c.lightened(0.6))
			"osso":
				apri(Vector2(50, 52), -35.0, 1.0)
				osso(0, -28, 0, 28, 10, Color(0.93, 0.9, 0.8), 1.6)
				for p in [[-6, -30], [6, -30], [-6, 30], [6, 30]]:
					disco(p[0], p[1], 7, Color(0.93, 0.9, 0.8), 1.6)
				chiudi()
			"erba":
				for q in [[-14.0, -12.0], [0.0, 0.0], [14.0, 12.0]]:
					penna(50 + q[0], 78, q[0] * 1.8, 56 + q[1], 22, Color(0.40, 0.78, 0.34), Color(0.2, 0.5, 0.15))
				osso(50, 80, 50, 60, 4, Color(0.55, 0.38, 0.2), 1.0)
			"polvere":
				apri(Vector2(50, 56), 0.0, 1.0)
				pol([-22, 30, -26, 2, -10, -14, 10, -14, 26, 2, 22, 30], c, SCURO, 2.0)
				pol([-10, -14, 10, -14, 8, -22, -8, -22], Color(0.85, 0.8, 0.6), SCURO, 1.4)
				for q in 6:
					disco(-14 + q * 6.0, -30 - (q % 3) * 4.0, 1.8, c.lightened(0.4), 0.0)
				chiudi()
			"cristallo":
				alone(50, 50, 38, c, 0.8)
				apri(Vector2(50, 54), 0.0, 1.45)
				_cristallo(vivo(c).lightened(0.12))
				chiudi()
				esplosione(30, 72, 3, 6, 3, c.lightened(0.5), 0, 0.8)
				scint(72, 30, 6, BIANCO, 0.0)
			"minerale":
				apri(Vector2(50, 52), 0.0, 1.0)
				pol([-34, 12, -26, -14, -4, -26, 20, -20, 34, 0, 28, 24, 0, 30], vivo(c).lightened(0.12), SCURO, 2.0)
				pol([-4, -26, 20, -20, 34, 0, 28, 24, 0, 30, -2, 2], vivo(c).darkened(0.25), SCURO, 0.0)
				pol([-34, 12, -26, -14, -4, -26, -2, 2], vivo(c).lightened(0.35), SCURO, 0.0)
				for q in [[-14, -4], [8, -10], [14, 12], [-20, 14], [2, 10]]:
					pol([q[0], q[1] - 4, q[0] + 4, q[1], q[0], q[1] + 4, q[0] - 4, q[1]], Color(0.85, 0.92, 1.0), SCURO, 0.8)
				chiudi()
			_:
				apri(Vector2(50, 54), 0.0, 1.1)
				pol([-26, 30, -30, 4, -14, -14, 14, -14, 30, 4, 26, 30], vivo(c), SCURO, 2.0)
				pol([6, -14, 14, -14, 30, 4, 26, 30, 4, 30], vivo(c).darkened(0.25), SCURO, 0.0)
				pol([-14, -14, 14, -14, 12, -22, -12, -22], vivo(c).darkened(0.1), SCURO, 1.6)
				lin(-10, -20, 10, -20, 2.0, ORO_O)
				pol([-20, -2, -14, -8, -12, 8, -18, 14], vivo(c).lightened(0.4), SCURO, 0.0)
				chiudi()

	func _dente(c: Color) -> void:
		pol([-11, -28, 11, -28, 10, -10, 4, 10, -4, 28, -7, 8, -11, -10], c, SCURO, 1.8)
		pol([2, -28, 11, -28, 10, -10, 4, 10, -4, 28, -1, 6, 2, -10], c.darkened(0.15), SCURO, 0.0)
		pol([-12, -32, 12, -32, 12, -22, -12, -22], Color(0.62, 0.45, 0.30), SCURO, 1.4)

	# ---------------------------------------------------------------- tael
	func monete() -> void:
		for q in [[30.0, 66.0, 3], [62.0, 70.0, 4], [46.0, 46.0, 5]]:
			for i in int(q[2]):
				var y: float = float(q[1]) - i * 6.0
				pol([q[0] - 19, y, q[0] + 19, y, q[0] + 19, y + 6, q[0] - 19, y + 6], ORO_O, SCURO, 1.2)
				pol(ell(q[0], y + 6, 19, 6.5), ORO_O, SCURO, 1.2)
				pol(ell(q[0], y, 19, 6.5), ORO, SCURO, 1.4)
				pol([q[0] - 3, y - 2.2, q[0] + 3, y - 2.2, q[0] + 3, y + 2.2, q[0] - 3, y + 2.2], SCURO.lightened(0.1), SCURO, 0.8)
		scint(70, 30, 7, BIANCO, 0.8)
