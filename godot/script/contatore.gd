class_name Contatore
extends Control
## Contatore dei danni: quanto danno fa ogni giocatore che vedi (tu, il gruppo, chi combatte vicino), al secondo e in
## totale, più le tue tecniche che pesano di più. Si alimenta dagli stessi effetti `hit` che disegnano i numeri di danno:
## niente messaggi nuovi dal server. Tasto del contatore (predefinito N) per mostrarlo o nasconderlo.
##
## Due viste: «Scontro» (dal primo colpo all'ultimo; uno scontro si chiude dopo 6 secondi senza colpi e il prossimo colpo
## ne apre uno nuovo, ma l'ultimo resta visibile) e «Totale» (da quando sei entrato o hai azzerato).
## Clic sul titolo: cambia vista. Clic destro: azzera.

const PAUSA_MS := 6000.0
const RIGHE := 6
const LARGO := 290.0

var gioco
var vista := "scontro"
var scontro := {"inizio": 0.0, "fine": 0.0, "per": {}}
var totale := {"inizio": 0.0, "fine": 0.0, "attivo": 0.0, "per": {}}
var _ridisegna := 0.0


func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -LARGO - 14.0
	offset_right = -14.0
	offset_top = -250.0
	offset_bottom = -92.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = Impostazioni.contatore
	tooltip_text = "Contatore dei danni\nClic: Scontro / Totale  ·  Clic destro: azzera  ·  %s: mostra o nascondi" % Tasti.nome("contatore")


func apri_chiudi() -> void:
	visible = not visible
	Impostazioni.contatore = visible
	Impostazioni.salva()
	Suoni.suona("clic", -10.0)


func azzera() -> void:
	scontro = {"inizio": 0.0, "fine": 0.0, "per": {}}
	totale = {"inizio": 0.0, "fine": 0.0, "attivo": 0.0, "per": {}}
	queue_redraw()


## Un colpo andato a segno: chi l'ha dato (solo i giocatori contano), quanto e con quale tecnica.
func colpo(chi: Entita, danno: int, tecnica: String) -> void:
	if chi == null or chi.tipo != "p" or danno <= 0:
		return
	var ora: float = gioco.ora()
	if float(scontro.fine) > 0.0 and ora - float(scontro.fine) > PAUSA_MS:
		scontro = {"inizio": ora, "fine": ora, "per": {}}        # scontro nuovo
	if float(scontro.inizio) == 0.0:
		scontro.inizio = ora
	# il tempo «attivo» del totale non conta le pause fra uno scontro e l'altro
	if float(totale.fine) > 0.0:
		totale.attivo = float(totale.attivo) + minf(ora - float(totale.fine), PAUSA_MS * 0.25)
	if float(totale.inizio) == 0.0:
		totale.inizio = ora
	scontro.fine = ora
	totale.fine = ora
	for reg in [scontro, totale]:
		var per: Dictionary = reg.per
		if not per.has(chi.id):
			per[chi.id] = {"nome": chi.nome, "cls": String(chi.info.get("cls", "")), "tot": 0, "tec": {}, "io": chi.io}
		var v: Dictionary = per[chi.id]
		v.tot = int(v.tot) + danno
		if chi.io:
			var k := tecnica if not tecnica.is_empty() else "auto"
			v.tec[k] = int(v.tec.get(k, 0)) + danno


func _secondi(reg: Dictionary) -> float:
	if reg == totale:
		return maxf(1.0, float(totale.attivo) / 1000.0)
	var fine := float(scontro.fine)
	var ora: float = gioco.ora()
	if ora - fine < PAUSA_MS:
		fine = ora                         # scontro in corso: il tempo scorre anche fra un colpo e l'altro
	return maxf(1.0, (fine - float(scontro.inizio)) / 1000.0)


func _process(dt: float) -> void:
	if not visible:
		return
	_ridisegna -= dt
	if _ridisegna <= 0.0:
		_ridisegna = 0.25
		queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			vista = "totale" if vista == "scontro" else "scontro"
			Suoni.suona("clic", -12.0)
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			azzera()
		queue_redraw()
		accept_event()


static func breve(n: float) -> String:
	if n >= 1000000.0:
		return "%.1fM" % (n / 1000000.0)
	if n >= 10000.0:
		return "%.0fk" % (n / 1000.0)
	if n >= 1000.0:
		return "%.1fk" % (n / 1000.0)
	return str(int(n))


func _colore_classe(cls: String) -> Color:
	var look: Dictionary = Dati.CLASSES.get(cls, {}).get("look", {})
	var c := Dati.colore(look.get("trim", 0x8a7a5a))
	match cls:
		"lama": c = Color(0.82, 0.3, 0.22)
		"ombra": c = Color(0.55, 0.35, 0.8)
		"monaco": c = Color(0.9, 0.6, 0.2)
		"mistico": c = Color(0.3, 0.6, 0.95)
	return c


func _draw() -> void:
	var f := ThemeDB.fallback_font
	var reg: Dictionary = scontro if vista == "scontro" else totale
	var sec := _secondi(reg)
	var r := Rect2(Vector2.ZERO, size)
	draw_style_box(Hud.stile(Color(0.06, 0.05, 0.05, 0.78), Hud.ORO.darkened(0.5), 5, 1), r)
	var titolo := ("Danni  ·  Scontro  %d:%02d" % [int(sec) / 60, int(sec) % 60]) if vista == "scontro" else ("Danni  ·  Totale  %d:%02d" % [int(sec) / 60, int(sec) % 60])
	draw_string(f, Vector2(8, 16), titolo, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Hud.ORO)
	var per: Dictionary = reg.per
	if per.is_empty():
		draw_string(f, Vector2(8, 40), "Colpisci qualcosa: qui vedi i danni al secondo.", HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 11, Color(0.7, 0.7, 0.68))
		return
	var righe: Array = per.values()
	righe.sort_custom(func(a, b): return int(a.tot) > int(b.tot))
	var primo := maxf(1.0, float(righe[0].tot))
	var somma := 0.0
	for v in righe:
		somma += float(v.tot)
	var y := 22.0
	var mio: Dictionary = {}
	for i in range(mini(RIGHE, righe.size())):
		var v: Dictionary = righe[i]
		if v.io:
			mio = v
		var col := _colore_classe(String(v.cls))
		var larg := (size.x - 12.0) * float(v.tot) / primo
		draw_rect(Rect2(6, y, larg, 17), Color(col.r, col.g, col.b, 0.62 if v.io else 0.4))
		if v.io:
			draw_rect(Rect2(6, y, size.x - 12.0, 17), Color(1, 1, 1, 0.5), false, 1.0)
		var sinistra := "%d. %s" % [i + 1, String(v.nome)]
		var destra := "%s al s   %s  %d%%" % [breve(float(v.tot) / sec), breve(float(v.tot)), int(round(float(v.tot) / somma * 100.0))]
		draw_string_outline(f, Vector2(10, y + 13), sinistra, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.85))
		draw_string(f, Vector2(10, y + 13), sinistra, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		var ld := f.get_string_size(destra, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string_outline(f, Vector2(size.x - 10 - ld, y + 13), destra, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.85))
		draw_string(f, Vector2(size.x - 10 - ld, y + 13), destra, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.95, 0.8))
		y += 19.0
	# se io non sono fra i primi, la mia riga la cerco comunque per il dettaglio delle tecniche
	if mio.is_empty():
		for v in righe:
			if v.io:
				mio = v
	if mio.is_empty() or int(mio.tot) <= 0:
		return
	# le mie tecniche che pesano di più
	y += 3.0
	draw_line(Vector2(6, y), Vector2(size.x - 6, y), Hud.ORO.darkened(0.55), 1.0)
	y += 4.0
	var tec: Array = []
	for k in (mio.tec as Dictionary).keys():
		tec.append([k, int(mio.tec[k])])
	tec.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	for i in range(mini(4, tec.size())):
		if y + 14.0 > size.y:
			break
		var id := String(tec[i][0])
		var nome := "Attacco base" if id == "auto" else String(Dati.SKILLS.get(id, Dati.BUFFS.get(id, {})).get("name", id))
		var quota := float(tec[i][1]) / float(mio.tot)
		draw_rect(Rect2(6, y + 1, (size.x - 12.0) * quota, 12), Color(1.0, 0.85, 0.4, 0.22))
		draw_string(f, Vector2(10, y + 11), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.88, 0.86, 0.8))
		var pt := "%d%%" % int(round(quota * 100.0))
		var lp := f.get_string_size(pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(f, Vector2(size.x - 10 - lp, y + 11), pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.88, 0.86, 0.8))
		y += 14.0
