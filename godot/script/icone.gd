class_name Icone
extends RefCounted
## Icone delle tecniche e degli effetti, DISEGNATE DA CODICE (nessun file immagine, nessun kanji).
## Ogni icona è composta con pochi mattoni (lama, saetta, freccia, pugno, onda, scudo, goccia, loto,
## fiamma, turbine, occhio, stella...) su un fondo a gradiente nel colore dell'elemento.
## Uso: Icone.disegna(self, "lama_tuono", Rect2(3, 3, 52, 52), spento)  dentro un _draw().
## La cornice la disegna chi chiama. Per id sconosciuti c'è un simbolo generico.

const SCURO := Color(0.04, 0.03, 0.07)
const ACCIAIO := Color(0.90, 0.93, 0.98)
const ACCIAIO_O := Color(0.52, 0.60, 0.73)
const ORO := Color(1.0, 0.84, 0.34)
const ORO_O := Color(0.78, 0.50, 0.12)
const PELLE := Color(0.98, 0.80, 0.62)
const PELLE_O := Color(0.80, 0.52, 0.38)
const LEGNO := Color(0.50, 0.30, 0.16)
const BIANCO := Color(1.0, 0.98, 0.94)
const ROSSO := Color(0.95, 0.25, 0.20)
const ROSSO_C := Color(1.0, 0.55, 0.40)
const AZZURRO := Color(0.55, 0.78, 1.0)
const AZZURRO_C := Color(0.82, 0.92, 1.0)
const VIOLA := Color(0.62, 0.40, 0.95)
const VIOLA_C := Color(0.82, 0.68, 1.0)
const VERDE := Color(0.30, 0.82, 0.45)
const VERDE_C := Color(0.70, 1.0, 0.75)
const GIADA := Color(0.28, 0.85, 0.68)
const GIADA_C := Color(0.75, 1.0, 0.92)
const AMBRA := Color(1.0, 0.68, 0.18)
const AMBRA_C := Color(1.0, 0.88, 0.50)
const BRONZO := Color(0.82, 0.52, 0.24)
const BRONZO_C := Color(1.0, 0.76, 0.46)
const PIETRA := Color(0.62, 0.58, 0.54)
const PIETRA_C := Color(0.84, 0.80, 0.74)

## fondi: [alto, basso, bagliore]
const TEMI := {
	"fulmine": [Color(0.30, 0.32, 0.80), Color(0.06, 0.05, 0.22), Color(0.55, 0.65, 1.0)],
	"ira": [Color(0.66, 0.20, 0.14), Color(0.17, 0.04, 0.06), Color(1.0, 0.50, 0.30)],
	"ombra": [Color(0.38, 0.20, 0.55), Color(0.07, 0.04, 0.15), Color(0.75, 0.50, 1.0)],
	"veleno": [Color(0.22, 0.52, 0.20), Color(0.04, 0.13, 0.06), Color(0.60, 1.0, 0.45)],
	"chi": [Color(0.80, 0.48, 0.10), Color(0.20, 0.10, 0.03), Color(1.0, 0.80, 0.35)],
	"luce": [Color(0.84, 0.68, 0.22), Color(0.28, 0.16, 0.04), Color(1.0, 0.95, 0.6)],
	"cura": [Color(0.14, 0.60, 0.50), Color(0.03, 0.16, 0.15), Color(0.55, 1.0, 0.85)],
	"vento": [Color(0.20, 0.56, 0.72), Color(0.04, 0.12, 0.20), Color(0.6, 0.95, 1.0)],
	"terra": [Color(0.58, 0.40, 0.22), Color(0.14, 0.08, 0.05), Color(1.0, 0.75, 0.45)],
	"cielo": [Color(0.30, 0.50, 0.92), Color(0.06, 0.10, 0.30), Color(0.7, 0.85, 1.0)],
	"sangue": [Color(0.60, 0.10, 0.16), Color(0.14, 0.02, 0.05), Color(1.0, 0.4, 0.4)],
	"neutro": [Color(0.42, 0.40, 0.46), Color(0.10, 0.09, 0.12), Color(0.9, 0.9, 1.0)],
}

## id (tecnica, effetto o oggetto) -> [tema, disegno, suprema]
const MAPPA := {
	"squarcio": ["ira", "squarcio"], "fendente": ["ira", "fendente"], "affondo_ira": ["ira", "affondo"],
	"carica": ["fulmine", "carica"], "lama_tuono": ["fulmine", "lama_tuono"], "martello_monte": ["terra", "martello"],
	"colpo_rapido": ["ombra", "colpo_rapido"], "ventaglio": ["ombra", "ventaglio"], "taglio_netto": ["ombra", "taglio_netto"],
	"colpo_gola": ["sangue", "colpo_gola"], "taglio_finale": ["veleno", "morso_vipera"], "risveglio_drago": ["ira", "risv_drago"], "eclissi": ["neutro", "risv_eclissi"],
	"cuore_sole": ["luce", "risv_sole"], "congiunzione": ["cielo", "risv_astri"], "taglio_gemello": ["ombra", "taglio_gemello"], "agguato": ["ombra", "passo_ombra"],
	"danza_lame": ["ombra", "danza_lame"], "pioggia_frecce": ["vento", "pioggia_frecce"], "ferita": ["sangue", "ferita"], "flusso": ["ombra", "flusso"], "passo_ombra": ["ombra", "passo_ombra"],
	"freccia_perforante": ["luce", "freccia_perf"], "occhio_falco": ["luce", "occhio"],
	# scatti e mosse della fase «flow», potenziamenti di classe
	"ala_vento": ["vento", "ala_vento"], "calcio_volante": ["chi", "calcio_volante"], "passo_luce": ["luce", "passo_luce"],
	"radici_monte": ["terra", "radici"], "occasione": ["luce", "occasione"],
	"grido_guerra": ["ira", "grido"], "velo_ombra": ["ombra", "velo"], "respiro_drago": ["chi", "respiro"],
	"benedizione_astri": ["cielo", "astri"],
	"pugno_ferro": ["chi", "pugno"], "calcio_gru": ["chi", "calcio"], "onda_chi": ["chi", "onda"],
	"palmo_chi": ["chi", "palmo"], "raffica": ["chi", "raffica"], "pelle_bronzo": ["terra", "bronzo"],
	"vortice_interiore": ["chi", "vortice"], "meditazione": ["cura", "meditazione"],
	"dardo_luce": ["luce", "dardo"], "sfera_celeste": ["cielo", "sfera"], "lancia_luce": ["luce", "lancia"],
	"sigillo_silenzio": ["cielo", "sigillo_silenzio"], "giudizio_cielo": ["cielo", "giudizio"],
	"occhio_ciclone": ["vento", "ciclone"], "tocco_curativo": ["cura", "loto_cura"], "scudo_giada": ["cura", "scudo_giada"],
	"giudizio_tuoni": ["fulmine", "sup_tuoni", true], "mille_ombre": ["ombra", "sup_ombre", true],
	"drago_celeste": ["chi", "sup_drago", true], "collera_cielo": ["cielo", "sup_collera", true],
	"carica_destriero": ["terra", "dest_carica"], "fendente_corsa": ["ira", "dest_fendente"],
	"zoccoli_tuono": ["terra", "dest_zoccoli"], "turbine_galoppo": ["vento", "dest_turbine"],
	# effetti attivi (BUFFS e stati)
	"scintilla": ["luce", "scintilla"], "furia_tempesta": ["fulmine", "nube_saetta"], "pelle_pietra": ["terra", "roccia"],
	"nell_ombra": ["ombra", "passo_ombra"], "fuoco_rapido": ["luce", "frecce_rapide"], "forma_perfetta": ["chi", "enso"],
	"spirito_tigre": ["ira", "artigli"], "sigillo_interiore": ["chi", "sigillo"], "tempesta_imminente": ["fulmine", "nube_saetta"],
	"benedizione": ["cura", "loto_cura"], "risonanza": ["chi", "risonanza"], "baluardo": ["terra", "baluardo"],
	"veleno": ["veleno", "veleno"], "marchio_morte": ["sangue", "teschio"], "scudo": ["cura", "scudo_giada"],
	"stordimento": ["luce", "stordito"], "__stordito": ["luce", "stordito"],
	"squilibrio": ["ira", "squilibrato"], "__squilibrato": ["ira", "squilibrato"],
	# oggetti
	"ginseng_p": ["sangue", "pozione_p"], "ginseng_m": ["sangue", "pozione_m"], "ginseng_g": ["sangue", "pozione_g"],
	"loto_p": ["cielo", "te_p"], "loto_m": ["cielo", "te_m"], "loto_g": ["cielo", "te_g"],
}


static func ha(id: String) -> bool:
	return MAPPA.has(id)


## Disegna l'icona di `id` dentro `rett`. Ritorna true se esiste un disegno proprio, false se ha usato il simbolo generico.
static func disegna(ci: CanvasItem, id: String, rett: Rect2, spento := false) -> bool:
	var trovato := MAPPA.has(id)
	var voce: Array = MAPPA[id] if trovato else ["neutro", "generico"]
	var tema: Array = TEMI[voce[0]]
	var p := Pennello.new()
	p.ci = ci
	p.spento = spento
	ci.draw_set_transform(rett.position, 0.0, rett.size / 100.0)
	p.fondo(tema[0], tema[1], tema[2])
	p.disegno(String(voce[1]))
	if voce.size() > 2:
		p.corona()
	p.vetro()
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return trovato


## Controllo pronto: mostra l'icona di una tecnica, un effetto o un oggetto.
class Vista:
	extends Control
	var id := ""
	var spento := false

	func _init(i := "", dim := 44.0) -> void:
		id = i
		custom_minimum_size = Vector2(dim, dim)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		Icone.disegna(self, id, Rect2(Vector2.ZERO, size), spento)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.8), false, 1.5)


class Pennello:
	extends RefCounted
	var ci: CanvasItem
	var spento := false
	var al := 1.0
	var m := Transform2D.IDENTITY
	var k := 1.0
	var pila: Array = []

	# ---------------------------------------------------------------- base
	func col(c: Color) -> Color:
		var r := Color(c.r, c.g, c.b, c.a * al)
		if spento:
			var g := c.get_luminance()
			r = Color(c.r, c.g, c.b, r.a).lerp(Color(g, g, g, r.a), 0.65)
			r = Color(r.r * 0.42, r.g * 0.42, r.b * 0.42, r.a)
		return r

	func apri(pos: Vector2, ang := 0.0, sc := 1.0) -> void:
		pila.append([m, k])
		m = m * Transform2D(deg_to_rad(ang), Vector2(sc, sc), 0.0, pos)
		k *= sc

	func chiudi() -> void:
		var v: Array = pila.pop_back()
		m = v[0]
		k = v[1]

	func vs(pts: Array) -> PackedVector2Array:
		var o := PackedVector2Array()
		if pts.size() > 0 and pts[0] is Vector2:
			for q in pts:
				o.append(m * (q as Vector2))
		else:
			var i := 0
			while i + 1 < pts.size():
				o.append(m * Vector2(float(pts[i]), float(pts[i + 1])))
				i += 2
		return o

	func pol(pts: Array, fill: Color, bordo := SCURO, sp := 1.6) -> void:
		var P := vs(pts)
		if P.size() < 3:
			return
		if fill.a > 0.0:
			ci.draw_colored_polygon(P, col(fill))
		if sp > 0.0:
			var Q := P.duplicate()
			Q.append(P[0])
			ci.draw_polyline(Q, col(Color(bordo.r, bordo.g, bordo.b, bordo.a)), sp * k, true)

	func ptc(x: float, y: float, r: float, n := 24) -> Array:
		var a: Array = []
		for i in n:
			var t := TAU * i / n
			a.append(Vector2(x + cos(t) * r, y + sin(t) * r))
		return a

	func disco(x: float, y: float, r: float, fill: Color, sp := 1.6) -> void:
		pol(ptc(x, y, r), fill, SCURO, sp)

	func lin(x1: float, y1: float, x2: float, y2: float, w: float, c: Color) -> void:
		ci.draw_line(m * Vector2(x1, y1), m * Vector2(x2, y2), col(c), w * k, true)

	## segmento col bordo scuro e punte arrotondate
	func osso(x1: float, y1: float, x2: float, y2: float, w: float, c: Color, sp := 1.4) -> void:
		if sp > 0.0:
			lin(x1, y1, x2, y2, w + sp * 2.0, SCURO)
			ci.draw_circle(m * Vector2(x1, y1), (w * 0.5 + sp) * k, col(SCURO))
			ci.draw_circle(m * Vector2(x2, y2), (w * 0.5 + sp) * k, col(SCURO))
		lin(x1, y1, x2, y2, w, c)
		ci.draw_circle(m * Vector2(x1, y1), w * 0.5 * k, col(c))
		ci.draw_circle(m * Vector2(x2, y2), w * 0.5 * k, col(c))

	func poli(pts: Array, w: float, c: Color) -> void:
		ci.draw_polyline(vs(pts), col(c), w * k, true)

	func arcopts(cx: float, cy: float, r: float, a0: float, a1: float, n := 20) -> Array:
		var a: Array = []
		for i in n + 1:
			var t := deg_to_rad(lerpf(a0, a1, float(i) / n))
			a.append(Vector2(cx + cos(t) * r, cy + sin(t) * r))
		return a

	func arco(cx: float, cy: float, r: float, a0: float, a1: float, w: float, c: Color) -> void:
		poli(arcopts(cx, cy, r, a0, a1), w, c)

	## mezzaluna rastremata (scia di un colpo)
	func mezz(cx: float, cy: float, r: float, a0: float, a1: float, sp: float, c: Color, bordo := true) -> void:
		var o: Array = []
		var n := 22
		for i in n + 1:
			var f := float(i) / n
			var t := deg_to_rad(lerpf(a0, a1, f))
			o.append(Vector2(cx + cos(t) * r, cy + sin(t) * r))
		for i in range(n, -1, -1):
			var f := float(i) / n
			var t := deg_to_rad(lerpf(a0, a1, f))
			var rr := r - sp * sin(PI * f)
			o.append(Vector2(cx + cos(t) * rr, cy + sin(t) * rr))
		pol(o, c, SCURO, 1.2 if bordo else 0.0)

	func alone(x: float, y: float, r: float, c: Color, forza := 0.5) -> void:
		for i in 6:
			var f := 1.0 - float(i) / 6.0
			ci.draw_colored_polygon(vs(ptc(x, y, r * f, 20)), col(Color(c.r, c.g, c.b, forza * 0.16)))

	func scint(x: float, y: float, r: float, c: Color, sp := 1.0) -> void:
		pol([x, y - r, x + r * 0.2, y - r * 0.2, x + r, y, x + r * 0.2, y + r * 0.2, x, y + r, x - r * 0.2, y + r * 0.2, x - r, y, x - r * 0.2, y - r * 0.2], c, SCURO, sp)

	func esplosione(x: float, y: float, r1: float, r2: float, n: int, c: Color, rot := 0.0, sp := 1.2) -> void:
		var a: Array = []
		for i in n * 2:
			var t := deg_to_rad(rot) + PI * i / n
			var r := r2 if i % 2 == 0 else r1
			a.append(Vector2(x + cos(t) * r, y + sin(t) * r))
		pol(a, c, SCURO, sp)

	## unione di dischi con un solo contorno: [[x, y, r], ...]
	func unione(dischi: Array, fill: Color, bordo := 1.6) -> void:
		for d in dischi:
			ci.draw_colored_polygon(vs(ptc(d[0], d[1], d[2] + bordo, 20)), col(SCURO))
		for d in dischi:
			ci.draw_colored_polygon(vs(ptc(d[0], d[1], d[2], 20)), col(fill))

	# ---------------------------------------------------------------- fondo e finiture
	func fondo(alto: Color, basso: Color, bagliore: Color) -> void:
		var c := 5.0
		var pts := PackedVector2Array([Vector2(c, 0), Vector2(100 - c, 0), Vector2(100, c), Vector2(100, 100 - c), Vector2(100 - c, 100), Vector2(c, 100), Vector2(0, 100 - c), Vector2(0, c)])
		var cols := PackedColorArray([col(alto), col(alto), col(alto.lerp(basso, 0.15)), col(basso), col(basso), col(basso), col(basso), col(alto.lerp(basso, 0.15))])
		ci.draw_polygon(pts, cols)
		alone(50, 46, 48, bagliore, 0.42)

	func vetro() -> void:
		# riflesso in alto e filo scuro all'orlo, per dare corpo
		ci.draw_polygon(PackedVector2Array([Vector2(5, 0), Vector2(95, 0), Vector2(100, 5), Vector2(100, 22), Vector2(0, 30), Vector2(0, 5)]), PackedColorArray([col(Color(1, 1, 1, 0.20)), col(Color(1, 1, 1, 0.20)), col(Color(1, 1, 1, 0.09)), col(Color(1, 1, 1, 0.0)), col(Color(1, 1, 1, 0.0)), col(Color(1, 1, 1, 0.09))]))
		ci.draw_polyline(PackedVector2Array([Vector2(5, 0.5), Vector2(95, 0.5), Vector2(99.5, 5), Vector2(99.5, 95), Vector2(95, 99.5), Vector2(5, 99.5), Vector2(0.5, 95), Vector2(0.5, 5), Vector2(5, 0.5)]), col(Color(0, 0, 0, 0.7)), 2.0, true)

	func corona() -> void:
		var c := Color(1.0, 0.82, 0.30, 0.95)
		ci.draw_polyline(PackedVector2Array([Vector2(7, 3), Vector2(93, 3), Vector2(97, 7), Vector2(97, 93), Vector2(93, 97), Vector2(7, 97), Vector2(3, 93), Vector2(3, 7), Vector2(7, 3)]), col(c), 3.0, true)
		scint(10, 10, 7, ORO_O.lightened(0.5), 0.8)
		scint(90, 90, 7, ORO_O.lightened(0.5), 0.8)

	# ---------------------------------------------------------------- mattoni
	## lama dritta dall'impugnatura (bx,by) alla punta (tx,ty)
	func lama(bx: float, by: float, tx: float, ty: float, w: float, acc := ACCIAIO, ombra := ACCIAIO_O, elsa := ORO) -> void:
		var b := Vector2(bx, by)
		var t := Vector2(tx, ty)
		var d := (t - b)
		var L := d.length()
		d /= L
		var n := Vector2(-d.y, d.x)
		var a := b + d * L * 0.20
		var sh := a + d * (t - a).length() * 0.80
		# impugnatura
		osso(bx, by, a.x, a.y, w * 0.42, LEGNO, 1.2)
		# lama
		var pts := [a + n * w * 0.5, sh + n * w * 0.5, t, sh - n * w * 0.5, a - n * w * 0.5]
		pol(pts, acc, SCURO, 1.6)
		pol([a, sh - n * w * 0.5 + d * 0.0, t, sh - n * w * 0.5, a - n * w * 0.5], ombra, SCURO, 0.0)
		lin(a.x, a.y, t.x, t.y, 1.0, SCURO)
		# elsa
		osso(a.x - n.x * w * 0.95, a.y - n.y * w * 0.95, a.x + n.x * w * 0.95, a.y + n.y * w * 0.95, w * 0.34, elsa, 1.2)

	func saetta(x: float, y: float, s: float, c: Color, rot := 0.0, bordo := SCURO) -> void:
		apri(Vector2(x, y), rot, s / 100.0)
		pol([6, -50, -16, 6, -2, 6, -10, 50, 18, -8, 3, -8, 16, -50], c, bordo, 1.8 / (s / 100.0) * 0.55)
		chiudi()

	func freccia(x1: float, y1: float, x2: float, y2: float, c := AMBRA_C, w := 3.0) -> void:
		var d := Vector2(x2 - x1, y2 - y1).normalized()
		var n := Vector2(-d.y, d.x)
		var T := Vector2(x2, y2)
		lin(x1, y1, x2 - d.x * 4.0, y2 - d.y * 4.0, w + 2.2, SCURO)
		lin(x1, y1, x2 - d.x * 4.0, y2 - d.y * 4.0, w, LEGNO.lightened(0.25))
		pol([T, T - d * 11.0 + n * 5.6, T - d * 8.0, T - d * 11.0 - n * 5.6], c, SCURO, 1.4)
		var P := Vector2(x1, y1)
		pol([P + d * 1.0, P + d * 7.0 + n * 5.0, P + d * 9.0 + n * 5.0, P + d * 5.0, P + d * 9.0 - n * 5.0, P + d * 7.0 - n * 5.0], BIANCO, SCURO, 1.0)

	func goccia(x: float, y: float, r: float, c: Color, sp := 1.4) -> void:
		var a: Array = [Vector2(x, y - r * 2.1)]
		for i in 21:
			var t := deg_to_rad(lerpf(58.0, 302.0, float(i) / 20.0))
			a.append(Vector2(x + r * sin(t), y - r * cos(t)))
		pol(a, c, SCURO, sp)
		scint(x - r * 0.35, y + r * 0.1, r * 0.35, Color(1, 1, 1, 0.85), 0.0)

	func occhio_forma(x: float, y: float, w: float, h: float, c: Color) -> void:
		var a: Array = []
		for i in 13:
			var f := float(i) / 12.0
			var xx := lerpf(-w, w, f)
			a.append(Vector2(x + xx, y - h * (1.0 - pow(xx / w, 2.0))))
		for i in range(12, -1, -1):
			var f := float(i) / 12.0
			var xx := lerpf(-w, w, f)
			a.append(Vector2(x + xx, y + h * 0.9 * (1.0 - pow(xx / w, 2.0))))
		pol(a, c, SCURO, 1.8)

	func scudo(x: float, y: float, s: float, c: Color, bordo := ORO) -> void:
		apri(Vector2(x, y), 0.0, s)
		pol([-22, -26, 22, -26, 24, 2, 16, 20, 0, 34, -16, 20, -24, 2], bordo, SCURO, 2.0)
		pol([-17, -21, 17, -21, 19, 1, 12, 15, 0, 27, -12, 15, -19, 1], c, SCURO, 0.0)
		pol([0, -21, 17, -21, 19, 1, 12, 15, 0, 27], Color(0, 0, 0, 0.22), SCURO, 0.0)
		lin(0, -21, 0, 27, 1.2, Color(0, 0, 0, 0.35))
		chiudi()

	func fiamma(x: float, y: float, s: float, c: Color, c2 := AMBRA_C) -> void:
		apri(Vector2(x, y), 0.0, s)
		pol([0, -46, 10, -24, 20, -10, 22, 10, 14, 28, 0, 36, -14, 28, -22, 10, -18, -8, -8, -16, -6, -32], c, SCURO, 2.0)
		pol([0, -8, 8, 6, 8, 20, 0, 28, -8, 20, -8, 6], c2, SCURO, 0.0)
		chiudi()

	func spirale(cx: float, cy: float, r0: float, r1: float, giri: float, t0: float, w: float, c: Color) -> void:
		var a: Array = []
		var n := int(giri * 22.0)
		for i in n + 1:
			var f := float(i) / n
			var t := deg_to_rad(t0) + TAU * giri * f
			var r := lerpf(r0, r1, f)
			a.append(Vector2(cx + cos(t) * r, cy + sin(t) * r))
		poli(a, w + 2.0, SCURO)
		poli(a, w, c)

	func pugno(x: float, y: float, s: float, rot := 0.0) -> void:
		apri(Vector2(x, y), rot, s)
		pol([-10, 22, -10, 36, 10, 36, 10, 22], PELLE_O, SCURO, 1.6)
		pol([-19, -2, -15, -9, 15, -9, 19, -2, 19, 18, 12, 25, -12, 25, -19, 18], PELLE, SCURO, 1.8)
		for i in 4:
			var cx := -13.5 + 9.0 * i
			disco(cx, -7.0, 5.4, PELLE, 1.4)
		lin(-9, -2, -9, 11, 1.3, PELLE_O)
		lin(0, -2, 0, 11, 1.3, PELLE_O)
		lin(9, -2, 9, 11, 1.3, PELLE_O)
		pol([-21, 13, -4, 8, 14, 11, 15, 21, -2, 25, -18, 24], PELLE.darkened(0.12), SCURO, 1.6)
		lin(-14, 15, 9, 13, 1.2, PELLE_O)
		chiudi()

	func palmo(x: float, y: float, s: float, rot := 0.0) -> void:
		apri(Vector2(x, y), rot, s)
		osso(18, 8, 36, -8, 9, PELLE, 1.4)
		osso(-19, -4, -24, -26, 8, PELLE, 1.4)
		osso(-8, -6, -10, -35, 8.6, PELLE, 1.4)
		osso(2, -7, 3, -40, 8.8, PELLE, 1.4)
		osso(12, -5, 15, -35, 8.6, PELLE, 1.4)
		pol([-23, -6, 20, -8, 23, 10, 15, 28, -15, 28, -23, 14], PELLE, SCURO, 1.8)
		lin(-6, 6, 8, 22, 1.2, PELLE_O)
		osso(-10, 28, -9, 34, 14, PELLE_O, 1.4)
		chiudi()

	func corridore(x: float, y: float, s: float, c: Color, bordo := SCURO, rot := 0.0) -> void:
		apri(Vector2(x, y), rot, s)
		var seg := [
			[6, -22, -6, 2, 15], [6, -22, 20, -14, 7], [20, -14, 30, -26, 6.5], [6, -22, -8, -14, 7], [-8, -14, -20, -6, 6.5],
			[-6, 2, 18, 8, 9], [18, 8, 14, 30, 8], [-6, 2, -14, 16, 9], [-14, 16, -34, 30, 8],
		]
		for q in seg:
			lin(q[0], q[1], q[2], q[3], q[4] + 3.4, bordo)
			ci.draw_circle(m * Vector2(q[2], q[3]), (q[4] * 0.5 + 1.7) * k, col(bordo))
		ci.draw_circle(m * Vector2(12, -34), 10.0 * k, col(bordo))
		for q in seg:
			lin(q[0], q[1], q[2], q[3], q[4], c)
			ci.draw_circle(m * Vector2(q[2], q[3]), q[4] * 0.5 * k, col(c))
		ci.draw_circle(m * Vector2(12, -34), 8.0 * k, col(c))
		chiudi()

	func busto(x: float, y: float, s: float, c: Color, bordo := SCURO) -> void:
		apri(Vector2(x, y), 0.0, s)
		pol([-30, 36, -28, 14, -14, 6, 14, 6, 28, 14, 30, 36], c, bordo, 1.8)
		pol([-6, -2, 6, -2, 6, 10, -6, 10], c.darkened(0.2), bordo, 1.2)
		disco(0, -14, 12, c, 1.8)
		chiudi()

	func seduto(x: float, y: float, s: float, c: Color) -> void:
		apri(Vector2(x, y), 0.0, s)
		# gambe incrociate
		var g: Array = []
		for i in 25:
			var t := TAU * i / 25.0
			g.append(Vector2(cos(t) * 34.0, 30.0 + sin(t) * 11.0))
		pol(g, c.darkened(0.15), SCURO, 1.8)
		pol([-14, -8, 14, -8, 24, 28, -24, 28], c, SCURO, 1.8)
		osso(-12, -4, -18, 14, 7, c, 1.2)
		osso(12, -4, 18, 14, 7, c, 1.2)
		disco(0, -20, 11, c, 1.8)
		chiudi()

	func nuvola(x: float, y: float, s: float, c: Color) -> void:
		apri(Vector2(x, y), 0.0, s)
		unione([[-20, 4, 12], [-4, -8, 17], [14, -4, 14], [26, 6, 10], [0, 8, 14]], c, 2.0 / maxf(0.5, s) * 0.7)
		chiudi()

	func crepa(x1: float, y1: float, x2: float, y2: float, c: Color, w := 2.0) -> void:
		var d := Vector2(x2 - x1, y2 - y1)
		var n := Vector2(-d.y, d.x).normalized()
		var a: Array = [Vector2(x1, y1)]
		for i in range(1, 5):
			var f := float(i) / 5.0
			a.append(Vector2(x1, y1) + d * f + n * (6.0 if i % 2 == 0 else -6.0))
		a.append(Vector2(x2, y2))
		poli(a, w + 1.6, SCURO)
		poli(a, w, c)

	func ferro(x: float, y: float, s: float, c := ACCIAIO, rot := 0.0) -> void:
		# ferro di cavallo con apertura in alto
		apri(Vector2(x, y), rot, s)
		var cen: Array = []
		cen.append(Vector2(-23, -26))
		cen.append(Vector2(-25, -6))
		for i in 15:
			var t := deg_to_rad(lerpf(180.0, 0.0, float(i) / 14.0))
			cen.append(Vector2(cos(t) * 25.0, 4.0 + sin(t) * 28.0))
		cen.append(Vector2(25, -6))
		cen.append(Vector2(23, -26))
		poli(cen, 13.0, SCURO)
		poli(cen, 9.5, c)
		poli(cen, 2.0, Color(1, 1, 1, 0.5))
		for q in [[-24, -16], [-25, 0], [-19, 18], [-8, 28], [8, 28], [19, 18], [25, 0], [24, -16]]:
			ci.draw_circle(m * Vector2(q[0], q[1]), 1.9 * k, col(SCURO))
		chiudi()

	func teschio(x: float, y: float, s: float, c: Color) -> void:
		apri(Vector2(x, y), 0.0, s)
		unione([[0, -6, 24], [0, 16, 12]], c, 2.0)
		pol([-10, 18, 10, 18, 10, 34, -10, 34], c, SCURO, 1.8)
		pol([-9.5, 18, 9.5, 18, 9.5, 24, -9.5, 24], c, SCURO, 0.0)
		for i in 3:
			lin(-5.0 + 5.0 * i, 24, -5.0 + 5.0 * i, 33, 1.3, SCURO)
		disco(-9, -4, 6.5, SCURO, 0.0)
		disco(9, -4, 6.5, SCURO, 0.0)
		pol([0, 6, -3, 13, 3, 13], SCURO, SCURO, 0.0)
		chiudi()

	# ---------------------------------------------------------------- disegni
	func disegno(nome: String) -> void:
		match nome:
			"squarcio":
				mezz(48, 40, 44, 15, 165, 30, ROSSO_C)
				mezz(52, 46, 38, 30, 150, 14, BIANCO, false)
				lama(14, 88, 84, 14, 12)
				esplosione(80, 20, 4, 12, 5, AMBRA_C, 10, 1.0)
			"fendente":
				lama(18, 50, 82, 50, 13)
				mezz(50, 50, 40, 205, 335, 14, ROSSO_C)
				mezz(50, 50, 40, 25, 155, 14, ROSSO_C)
				for q in [[85, 38, 330], [15, 62, 150]]:
					apri(Vector2(q[0], q[1]), q[2], 1.0)
					pol([0, -9, 13, 0, 0, 9], BIANCO, SCURO, 1.3)
					chiudi()
			"affondo":
				for i in 3:
					lin(2, 34 + i * 16, 36 - i * 6, 34 + i * 16, 3.0 - i * 0.5, ROSSO_C)
				fiamma(30, 50, 0.42, ROSSO, AMBRA_C)
				lama(26, 50, 88, 50, 15)
				esplosione(88, 50, 6, 16, 8, AMBRA_C, 0, 1.2)
				disco(88, 50, 4, BIANCO, 0.0)
			"carica":
				for i in 3:
					lin(2 + i * 4, 30 + i * 18, 26 + i * 4, 30 + i * 18, 4.0, AZZURRO_C)
				corridore(46, 52, 0.85, AZZURRO_C, SCURO, 0)
				for i in 2:
					poli([Vector2(70 + i * 12, 22), Vector2(82 + i * 12, 50), Vector2(70 + i * 12, 78)], 5.0, SCURO)
					poli([Vector2(70 + i * 12, 22), Vector2(82 + i * 12, 50), Vector2(70 + i * 12, 78)], 3.0, ORO)
			"lama_tuono":
				alone(50, 50, 40, AZZURRO, 0.8)
				saetta(60, 44, 100, VIOLA_C, 14)
				saetta(50, 46, 78, Color(1, 0.97, 0.7), 14, Color(0.2, 0.1, 0.5))
				lama(36, 90, 36, 14, 12)
				scint(36, 14, 9, BIANCO, 0.0)
			"martello":
				for q in [[18, 90], [50, 70], [82, 90]]:
					pol([q[0] - 24, 92, q[0], q[1], q[0] + 24, 92], PIETRA.darkened(0.3), SCURO, 1.6)
				crepa(50, 94, 50, 62, ORO, 2.4)
				osso(30, 82, 66, 30, 7, LEGNO, 1.4)
				apri(Vector2(68, 28), 38.0, 1.0)
				pol([-24, -15, 24, -15, 24, 15, -24, 15], PIETRA, SCURO, 2.0)
				pol([-24, -15, 24, -15, 24, -5, -24, -5], PIETRA_C, SCURO, 0.0)
				pol([-30, -12, -24, -15, -24, 15, -30, 12], ACCIAIO_O, SCURO, 1.5)
				pol([24, -15, 30, -12, 30, 12, 24, 15], ACCIAIO_O, SCURO, 1.5)
				chiudi()
				esplosione(30, 84, 5, 12, 6, AMBRA_C, 0, 1.0)
			"colpo_rapido":
				for i in 4:
					lin(4 + i * 3, 74 - i * 14, 40 + i * 3, 38 - i * 14 + 14, 3.0, VIOLA_C)
				lama(18, 86, 82, 22, 11, ACCIAIO, ACCIAIO_O, VIOLA)
				scint(84, 20, 8, BIANCO, 0.0)
			"ventaglio":
				for ang in [-54, -27, 27, 54, 0]:
					var t := deg_to_rad(ang - 90.0)
					lama(50 + cos(t) * -4.0, 88 + sin(t) * -4.0, 50 + cos(t) * 62.0, 88 + sin(t) * 62.0, 10, ACCIAIO, ACCIAIO_O, ORO_O)
				disco(50, 88, 6, ORO, 1.4)
			"taglio_netto":
				var off := Vector2(4.5, -4.5)
				var mezzo_a: Array = []
				var mezzo_b: Array = []
				for i in 19:
					var t := deg_to_rad(lerpf(-45.0, 135.0, i / 18.0))
					mezzo_a.append(Vector2(50 + cos(t) * 33 - off.x, 52 + sin(t) * 33 - off.y))
					var u := deg_to_rad(lerpf(135.0, 315.0, i / 18.0))
					mezzo_b.append(Vector2(50 + cos(u) * 33 + off.x, 52 + sin(u) * 33 + off.y))
				pol(mezzo_a, VIOLA_C, SCURO, 2.0)
				pol(mezzo_b, VIOLA, SCURO, 2.0)
				disco(50, 52, 8, VIOLA.darkened(0.5), 1.0)
				lin(6, 94, 94, 6, 6.0, SCURO)
				lin(6, 94, 94, 6, 3.0, BIANCO)
				scint(86, 14, 9, BIANCO, 0.0)
			"colpo_gola":
				busto(50, 50, 1.0, Color(0.55, 0.52, 0.66))
				for q in [[36, 80], [60, 86]]:
					goccia(q[0], q[1], 3.6, ROSSO, 1.0)
				lin(14, 70, 86, 48, 9.0, SCURO)
				lin(14, 70, 86, 48, 5.5, ROSSO)
				lin(16, 68, 84, 47, 1.8, ROSSO_C)
			"risv_drago":
				# occhio di drago fra le fiamme
				fiamma(50, 54, 1.9, ROSSO, AMBRA_C)
				occhio_forma(50, 54, 30, 15, AMBRA_C)
				pol([48, 44, 52, 44, 53, 64, 47, 64], SCURO, SCURO, 0.0)
				esplosione(50, 54, 30, 44, 8, ORO, 0.4, 1.0)
			"risv_eclissi":
				# sole nero con la corona bianca
				esplosione(50, 50, 30, 46, 16, BIANCO, 0.0, 1.0)
				disco(50, 50, 31, BIANCO, 1.6)
				disco(53, 48, 27, Color(0.04, 0.03, 0.08), 1.2)
				arco(53, 48, 27, -2.2, 0.4, 2.2, Color(1.0, 0.2, 0.3))
			"risv_sole":
				# sole raggiante dentro un pugno di luce
				esplosione(50, 50, 20, 46, 12, ORO, 0.0, 1.4)
				disco(50, 50, 22, AMBRA_C, 1.8)
				disco(50, 50, 13, BIANCO, 0.0)
			"risv_astri":
				# due astri allineati su un'orbita
				arco(50, 50, 36, 0.0, TAU, 2.2, ORO)
				scint(28, 34, 15, ORO, 1.2)
				scint(72, 66, 15, BIANCO, 1.2)
				lin(28, 34, 72, 66, 2.0, AMBRA_C)
				disco(50, 50, 6, BIANCO, 1.0)
			"taglio_gemello":
				# due lame incrociate a X con la scintilla al centro
				lama(14, 88, 84, 14, 11, ACCIAIO, ACCIAIO_O, VIOLA)
				lama(86, 88, 16, 14, 11, ACCIAIO, ACCIAIO_O, VIOLA)
				scint(50, 50, 13, BIANCO, 0.0)
				scint(50, 50, 7, VIOLA_C, 0.0)
			"morso_vipera":
				# due zanne ricurve che si chiudono, con le gocce di veleno
				pol([24, 10, 44, 12, 46, 40, 40, 66, 34, 84, 30, 60, 24, 36], Color(0.95, 0.93, 0.82), SCURO, 2.0)
				pol([76, 10, 56, 12, 54, 40, 60, 66, 66, 84, 70, 60, 76, 36], Color(0.95, 0.93, 0.82), SCURO, 2.0)
				pol([18, 6, 82, 6, 78, 16, 22, 16], VERDE, SCURO, 1.6)
				goccia(34, 92, 4.2, VERDE_C, 1.0)
				goccia(66, 92, 4.2, VERDE_C, 1.0)
				goccia(50, 70, 5.5, VERDE_C, 1.2)
			"danza_lame":
				# lame a girandola attorno a una sagoma d'ombra
				for i in 5:
					var ta := TAU * i / 5.0 - 0.3
					lama(50 + cos(ta) * 14.0, 50 + sin(ta) * 14.0, 50 + cos(ta + 0.9) * 46.0, 50 + sin(ta + 0.9) * 46.0, 9, ACCIAIO, ACCIAIO_O, VIOLA)
				al = 0.85
				disco(50, 50, 13, VIOLA.darkened(0.55), 1.4)
				al = 1.0
				scint(50, 50, 8, VIOLA_C, 0.0)
			"pioggia_frecce":
				for q in [[22, 8, 40, 62], [48, 2, 66, 56], [70, 14, 88, 68], [10, 34, 28, 88], [52, 40, 70, 94]]:
					freccia(q[0], q[1], q[2], q[3], AMBRA_C, 2.8)
				for q in [[40, 66], [66, 60], [28, 92]]:
					scint(q[0], q[1], 5, BIANCO, 0.0)
			"ferita":
				# un taglio aperto che sanguina
				lin(14, 30, 86, 58, 9.0, SCURO)
				lin(14, 30, 86, 58, 5.5, ROSSO)
				lin(18, 32, 82, 56, 1.8, ROSSO_C)
				for q in [[34, 62, 5.0], [56, 74, 6.5], [72, 84, 4.2]]:
					goccia(q[0], q[1], q[2], ROSSO, 1.2)
			"flusso":
				# due onde che si inseguono
				spirale(50, 50, 6, 40, 1.6, 0.0, 6.0, VIOLA_C)
				spirale(50, 50, 6, 40, 1.6, PI, 6.0, Color(0.6, 1.0, 0.35))
				disco(50, 50, 6, BIANCO, 1.0)
			"taglio_finale":
				esplosione(50, 80, 11, 25, 8, ROSSO_C, 22, 1.4)
				esplosione(50, 80, 6, 14, 8, AMBRA_C, 0, 1.0)
				lama(50, 4, 50, 80, 12, ACCIAIO, ACCIAIO_O, ROSSO)
				for q in [[26, 30], [74, 38]]:
					goccia(q[0], q[1], 3.4, ROSSO, 1.0)
			"passo_ombra":
				al = 0.28
				corridore(26, 56, 0.85, VIOLA, SCURO)
				al = 0.5
				corridore(40, 56, 0.85, VIOLA_C, SCURO)
				al = 1.0
				corridore(62, 54, 0.9, Color(0.92, 0.85, 1.0), SCURO)
			"freccia_perf":
				scudo(48, 50, 1.4, ACCIAIO_O, ACCIAIO)
				crepa(48, 26, 48, 76, AMBRA_C, 1.8)
				freccia(6, 50, 94, 50, ORO, 3.4)
				for i in 2:
					lin(2, 44 + i * 12, 22, 44 + i * 12, 2.4, AMBRA_C)
			"occhio":
				for i in 12:
					var t := TAU * i / 12.0
					lin(50 + cos(t) * 34, 50 + sin(t) * 24, 50 + cos(t) * 46, 50 + sin(t) * 34, 3.0, AMBRA_C)
				occhio_forma(50, 50, 40, 26, BIANCO)
				disco(50, 50, 18, ORO, 2.0)
				disco(50, 50, 11, AMBRA, 0.0)
				pol([50, 38, 54, 50, 50, 62, 46, 50], SCURO, SCURO, 0.0)
				disco(44, 44, 3.2, BIANCO, 0.0)
			"pugno":
				esplosione(50, 50, 28, 46, 10, AMBRA_C, 8, 1.4)
				pugno(50, 46, 1.3)
			"calcio":
				al = 0.85
				for i in 5:
					apri(Vector2(34, 60), -60.0 + i * 30.0, 1.0)
					pol([0, 0, 9, -24, 0, -46, -9, -24], BIANCO if i % 2 == 0 else AMBRA_C, SCURO, 1.2)
					chiudi()
				al = 1.0
				mezz(46, 70, 44, 270, 350, 14, AMBRA_C)
				apri(Vector2(40, 60), 0.0, 1.0)
				var cp := Color(0.95, 0.92, 0.85)
				var seg2 := [[-6, -26, -10, 2, 14], [-6, -24, -20, -12, 6.5], [-20, -12, -26, -26, 6], [-6, -24, 12, -22, 6.5], [-10, 2, -12, 20, 9], [-12, 20, -16, 34, 8], [-10, 2, 14, -6, 10], [14, -6, 36, -22, 9]]
				for q in seg2:
					lin(q[0], q[1], q[2], q[3], q[4] + 3.4, SCURO)
					ci.draw_circle(m * Vector2(q[2], q[3]), (q[4] * 0.5 + 1.7) * k, col(SCURO))
				ci.draw_circle(m * Vector2(-4, -38), 10.0 * k, col(SCURO))
				for q in seg2:
					lin(q[0], q[1], q[2], q[3], q[4], PELLE if q[4] < 7.0 else cp)
					ci.draw_circle(m * Vector2(q[2], q[3]), q[4] * 0.5 * k, col(PELLE if q[4] < 7.0 else cp))
				ci.draw_circle(m * Vector2(-4, -38), 8.0 * k, col(PELLE))
				ci.draw_circle(m * Vector2(36, -22), 5.5 * k, col(PELLE))
				chiudi()
			"onda":
				disco(26, 50, 14, BIANCO, 1.6)
				alone(26, 50, 26, AMBRA_C, 1.0)
				for i in 3:
					arco(26, 50, 26 + i * 15, -50, 50, 7.0 - i * 1.5 + 2.2, SCURO)
					arco(26, 50, 26 + i * 15, -50, 50, 7.0 - i * 1.5, AMBRA_C if i < 2 else AMBRA_C.lightened(0.3))
				disco(26, 50, 7, AMBRA_C, 0.0)
			"palmo":
				alone(48, 46, 40, AMBRA_C, 1.0)
				for i in 2:
					arco(24, 52, 36 + i * 12, -32, 32, 4.0, AMBRA_C)
				palmo(46, 60, 1.0)
			"raffica":
				for i in 5:
					lin(2, 28 + i * 11, 30 - (i % 2) * 8, 28 + i * 11, 3.0, AMBRA_C)
				al = 0.55
				pugno(40, 32, 0.8, 8)
				pugno(52, 52, 0.85, 8)
				al = 1.0
				pugno(66, 60, 1.0, 8)
				esplosione(88, 58, 4, 11, 6, BIANCO, 0, 1.0)
			"bronzo":
				arco(50, 52, 44, 160, 380, 4.0, BRONZO_C)
				busto(50, 54, 1.25, BRONZO)
				scint(34, 38, 8, BRONZO_C.lightened(0.4), 0.0)
				scint(66, 70, 5, BRONZO_C.lightened(0.4), 0.0)
			"vortice":
				disco(50, 50, 40, Color(1.0, 0.8, 0.35, 0.18), 0.0)
				spirale(50, 50, 4, 40, 1.8, 0, 7.0, AMBRA_C)
				spirale(50, 50, 4, 40, 1.8, 180, 5.0, BIANCO)
				disco(50, 50, 8, BIANCO, 1.4)
			"meditazione":
				disco(50, 44, 40, Color(0.6, 1.0, 0.8, 0.22), 0.0)
				arco(50, 44, 40, 0, 360, 3.0, GIADA_C)
				seduto(50, 52, 1.2, GIADA_C)
				for q in [[18, 80], [82, 76], [24, 22]]:
					scint(q[0], q[1], 6, BIANCO, 0.0)
			"dardo":
				for i in 3:
					lin(4, 90 - i * 6, 36 + i * 4, 58 - i * 6, 3.0 - i * 0.6, ORO)
				alone(60, 40, 30, ORO, 1.0)
				apri(Vector2(58, 42), -45.0, 1.0)
				pol([-30, 0, -10, -9, 30, 0, -10, 9], BIANCO, ORO_O, 2.0)
				pol([-30, 0, -10, -9, -4, 0], ORO, SCURO, 0.0)
				pol([-34, 0, -26, -6, -26, 6], ORO, SCURO, 1.0)
				chiudi()
				scint(84, 16, 10, BIANCO, 0.0)
				scint(20, 24, 6, ORO, 0.0)
			"sfera":
				alone(50, 50, 46, AZZURRO, 1.0)
				arco(50, 50, 40, 0, 360, 3.0, AZZURRO_C)
				disco(50, 50, 22, AZZURRO, 2.0)
				disco(50, 50, 14, AZZURRO_C, 0.0)
				disco(44, 44, 5, BIANCO, 0.0)
				for i in 4:
					var t := deg_to_rad(45.0 + i * 90.0)
					scint(50 + cos(t) * 38, 50 + sin(t) * 38, 8, BIANCO, 0.8)
			"lancia":
				alone(78, 24, 30, ORO, 1.0)
				apri(Vector2(50, 50), -45.0, 1.0)
				lin(-52, 0, 30, 0, 5.0 + 2.4, SCURO)
				lin(-52, 0, 30, 0, 5.0, LEGNO.lightened(0.2))
				pol([26, 0, 36, -8, 56, 0, 36, 8], BIANCO, ORO_O, 2.0)
				pol([26, 0, 36, -8, 56, 0], ORO, SCURO, 0.0)
				osso(24, -8, 24, 8, 5, ORO, 1.0)
				pol([-52, 0, -42, -7, -38, 0, -42, 7], ROSSO, SCURO, 1.0)
				chiudi()
				scint(84, 16, 10, BIANCO, 0.0)
				for i in 2:
					lin(6 + i * 6, 86 - i * 4, 30 + i * 6, 62 - i * 4, 2.4, ORO)
			"sigillo_silenzio":
				pol([30, 12, 70, 12, 70, 88, 30, 88], Color(0.97, 0.93, 0.80), SCURO, 2.0)
				pol([30, 12, 70, 12, 70, 20, 30, 20], ROSSO, SCURO, 0.0)
				for i in 3:
					lin(40, 28 + i * 9, 60, 28 + i * 9, 2.4, SCURO)
					lin(50, 26 + i * 9, 50, 32 + i * 9, 2.0, SCURO)
				disco(50, 62, 13, ROSSO, 1.6)
				disco(50, 62, 7, Color(0.97, 0.93, 0.80), 0.0)
				arco(50, 50, 40, 0, 360, 9.0, SCURO)
				arco(50, 50, 40, 0, 360, 5.5, ROSSO)
				lin(20, 78, 80, 22, 9.0, SCURO)
				lin(20, 78, 80, 22, 5.5, ROSSO)
			"giudizio":
				nuvola(50, 32, 1.05, Color(0.55, 0.60, 0.80))
				saetta(52, 62, 62, Color(1, 0.97, 0.6), 10)
				pol([22, 94, 78, 94, 70, 88, 30, 88], PIETRA.darkened(0.2), SCURO, 1.4)
				esplosione(52, 90, 3, 10, 6, AZZURRO_C, 0, 1.0)
			"ciclone":
				var liv := [[50, 18, 38], [50, 33, 30], [50, 48, 22], [50, 62, 15], [50, 76, 8]]
				for i in liv.size():
					var q: Array = liv[i]
					var e: Array = []
					for j in 22:
						var t := TAU * j / 22.0
						e.append(Vector2(q[0] + cos(t) * q[2], q[1] + sin(t) * q[2] * 0.32))
					pol(e, VENTO_COL[i % 2], SCURO, 1.5)
				occhio_forma(76, 82, 14, 8, BIANCO)
				disco(76, 82, 4.4, VERDE, 0.0)
				lin(8, 94, 30, 88, 3.0, AZZURRO_C)
			"loto_cura":
				alone(50, 56, 40, GIADA_C, 1.0)
				for q in [[-62, 0.78], [62, 0.78], [-32, 0.95], [32, 0.95], [0, 1.1]]:
					apri(Vector2(50, 78), q[0], q[1])
					pol([0, 0, 11, -18, 0, -50, -11, -18], Color(1.0, 0.82, 0.9) if q[0] == 0 else Color(0.95, 0.65, 0.78), SCURO, 1.6)
					chiudi()
				pol([46, 20, 54, 20, 54, 28, 62, 28, 62, 36, 54, 36, 54, 44, 46, 44, 46, 36, 38, 36, 38, 28, 46, 28], VERDE_C, SCURO, 1.4)
			"scudo_giada":
				alone(50, 50, 42, GIADA_C, 1.0)
				scudo(50, 46, 1.45, GIADA, GIADA_C)
				disco(50, 40, 8, GIADA_C, 1.6)
				disco(50, 40, 3, Color(0.1, 0.3, 0.25), 0.0)
				scint(76, 22, 8, BIANCO, 0.0)
			"sup_tuoni":
				nuvola(50, 27, 1.0, Color(0.40, 0.40, 0.70))
				for q in [[24, 56, 70, -14], [76, 56, 70, 14]]:
					saetta(q[0], q[1], q[2], VIOLA_C, q[3])
				saetta(50, 58, 74, Color(1, 0.97, 0.7), 0, Color(0.2, 0.1, 0.5))
				lama(50, 98, 50, 52, 9)
				esplosione(50, 92, 4, 12, 8, AZZURRO_C, 0, 1.0)
			"sup_ombre":
				for i in 6:
					var t := TAU * i / 6.0 - PI / 2.0
					al = 0.55
					corridore(50 + cos(t) * 30, 52 + sin(t) * 28, 0.46, VIOLA, SCURO, 0)
				al = 1.0
				arco(50, 52, 30, 0, 360, 2.0, VIOLA_C)
				corridore(50, 52, 0.7, Color(0.92, 0.85, 1.0), SCURO)
			"sup_drago":
				var corpo: Array = []
				for i in 31:
					var f := float(i) / 30.0
					corpo.append(Vector2(50 + 26.0 * sin(f * PI * 2.2 + 0.6) * (1.0 - f * 0.25), 94 - f * 56.0))
				poli(corpo, 15.0, SCURO)
				poli(corpo, 11.0, AMBRA)
				poli(corpo.slice(4), 4.0, AMBRA_C)
				var tp: Vector2 = corpo[30]
				apri(tp, 0.0, 1.3)
				pol([-12, 6, -14, -10, -2, -20, 14, -14, 20, 0, 12, 10], AMBRA, SCURO, 1.8)
				pol([-12, -8, -26, -22, -8, -16], ORO, SCURO, 1.3)
				pol([2, -18, 14, -30, 10, -14], ORO, SCURO, 1.3)
				disco(6, -4, 3.2, SCURO, 0.0)
				disco(7, -5, 1.2, BIANCO, 0.0)
				pol([14, 4, 28, 8, 14, 10], ROSSO_C, SCURO, 1.0)
				chiudi()
				for q in [[16, 30], [86, 56], [20, 80]]:
					scint(q[0], q[1], 6, BIANCO, 0.0)
			"sup_collera":
				nuvola(50, 29, 1.05, Color(0.38, 0.38, 0.62))
				for i in 5:
					var ang := -36.0 + i * 18.0
					var dx := (i - 2) * 5.0
					saetta(50 + (i - 2) * 17, 70 + abs(i - 2) * 4, 56 if i != 2 else 70, VIOLA_C if i != 2 else Color(1, 0.97, 0.7), ang * 0.5)
				disco(50, 38, 8, ROSSO, 1.4)
				disco(50, 38, 3, SCURO, 0.0)
			"dest_carica":
				for i in 3:
					lin(2, 30 + i * 18, 34, 30 + i * 18, 4.0, ORO_O)
				ferro(56, 56, 1.0, ACCIAIO, 90)
				for i in 2:
					poli([Vector2(70 + i * 12, 20), Vector2(84 + i * 12, 50), Vector2(70 + i * 12, 80)], 5.0, SCURO)
					poli([Vector2(70 + i * 12, 20), Vector2(84 + i * 12, 50), Vector2(70 + i * 12, 80)], 3.0, ORO)
			"dest_fendente":
				ferro(50, 70, 0.7, ACCIAIO, 180)
				mezz(50, 62, 46, 185, 355, 26, ROSSO_C)
				mezz(50, 62, 36, 200, 340, 10, BIANCO, false)
				lama(16, 54, 84, 18, 9)
			"dest_zoccoli":
				crepa(10, 92, 50, 70, ORO, 2.2)
				crepa(90, 92, 50, 70, ORO, 2.2)
				ferro(50, 62, 0.9, ACCIAIO, 180)
				saetta(50, 26, 40, Color(1, 0.97, 0.7), 0, Color(0.2, 0.1, 0.5))
			"dest_turbine":
				spirale(50, 50, 6, 44, 1.7, 0, 6.0, AZZURRO_C)
				spirale(50, 50, 6, 44, 1.7, 180, 4.0, BIANCO)
				ferro(50, 54, 0.6, ACCIAIO, 180)
			"ala_vento":
				# folata di vento con tre penne che volano verso il bersaglio
				for i in 3:
					arco(30, 50, 22 + i * 12, -60, 60, 5.0, SCURO)
					arco(30, 50, 22 + i * 12, -60, 60, 3.0, VENTO_COL[i % 2])
				for q in [[66, 26, 30], [78, 50, 0], [66, 74, -30]]:
					apri(Vector2(q[0], q[1]), q[2], 0.9)
					pol([-22, 0, -8, -7, 16, -4, 22, 0, 16, 4, -8, 7], BIANCO, SCURO, 1.4)
					lin(-24, 0, 20, 0, 1.6, ACCIAIO_O)
					chiudi()
				scint(20, 50, 7, BIANCO, 0.0)
			"calcio_volante":
				# balzo in volo con la scia di chi infuocato
				for i in 4:
					lin(4 + i * 6, 86 - i * 4, 40 + i * 6, 52 - i * 4, 5.0 - i, AMBRA_C if i % 2 == 0 else ROSSO_C)
				fiamma(28, 74, 0.45, ROSSO, AMBRA_C)
				corridore(56, 44, 0.9, Color(0.95, 0.92, 0.85), SCURO, -35.0)
				esplosione(84, 22, 5, 15, 7, AMBRA_C, 0, 1.2)
				disco(84, 22, 4, BIANCO, 0.0)
			"passo_luce":
				# figura che si scioglie in luce e riappare più avanti
				al = 0.3
				corridore(26, 56, 0.8, AZZURRO_C, SCURO)
				al = 1.0
				for i in 5:
					scint(34 + i * 7, 40 + (i % 2) * 18, 4.0 + i, AMBRA_C if i % 2 == 0 else BIANCO, 0.0)
				alone(72, 52, 26, AMBRA_C, 0.9)
				corridore(72, 54, 0.85, BIANCO, SCURO)
				arco(72, 54, 34, 0, 360, 2.0, ORO)
			"radici":
				# il suolo si spacca e la roccia sale attorno a una figura salda
				for q in [[14, 92, 60], [86, 92, 60], [30, 94, 46], [70, 94, 46]]:
					pol([q[0] - 12, 94, q[0] - 3, q[2], q[0] + 5, q[2] - 6, q[0] + 12, 94], PIETRA if q[2] > 50 else PIETRA_C, SCURO, 1.6)
				crepa(50, 96, 28, 70, ORO, 2.2)
				crepa(50, 96, 72, 70, ORO, 2.2)
				busto(50, 54, 0.95, BRONZO)
				arco(50, 58, 44, 200, 340, 4.0, AMBRA_C)
			"occasione":
				# un varco di luce: l'occhio del momento giusto
				esplosione(50, 50, 18, 46, 8, ORO, 22, 1.4)
				occhio_forma(50, 50, 36, 20, BIANCO)
				disco(50, 50, 10, ORO, 1.6)
				disco(50, 50, 4, SCURO, 0.0)
			"grido":
				# urlo di guerra: onde che escono da un volto
				busto(30, 56, 0.9, Color(0.95, 0.75, 0.6))
				for i in 3:
					arco(36, 42, 22 + i * 14, -40, 40, 6.0, SCURO)
					arco(36, 42, 22 + i * 14, -40, 40, 3.6, ROSSO_C if i % 2 == 0 else AMBRA_C)
				esplosione(86, 42, 4, 11, 6, ORO, 0, 1.0)
			"velo":
				# velo d'ombra che avvolge una lama
				for i in 3:
					arco(50, 52, 18 + i * 12, 120 + i * 30, 330 + i * 30, 6.0, VIOLA if i % 2 == 0 else Color(0.25, 0.18, 0.38))
				lama(24, 84, 76, 18, 10, ACCIAIO, ACCIAIO_O, VIOLA)
				scint(78, 16, 8, VIOLA_C, 0.0)
			"respiro":
				# soffio di drago: spirale di fiamma del chi
				spirale(50, 52, 6, 40, 1.6, 0.0, 6.0, AMBRA_C)
				fiamma(50, 60, 0.7, ROSSO, AMBRA_C)
				disco(50, 50, 6, BIANCO, 1.2)
			"astri":
				# benedizione degli astri: stelle in cerchio attorno a una luce
				alone(50, 50, 36, AZZURRO_C, 0.9)
				for i in 6:
					var t := TAU * i / 6.0 - PI / 2.0
					esplosione(50 + cos(t) * 32, 50 + sin(t) * 32, 2.5, 8, 4, ORO if i % 2 == 0 else BIANCO, 45, 1.0)
				esplosione(50, 50, 6, 18, 4, BIANCO, 45, 1.4)
			"scintilla":
				esplosione(50, 50, 16, 44, 8, ORO, 0, 1.6)
				scint(50, 50, 30, BIANCO, 0.0)
			"nube_saetta":
				nuvola(50, 32, 1.1, Color(0.52, 0.56, 0.84))
				saetta(52, 68, 64, Color(1, 0.97, 0.6), 8)
			"roccia":
				pol([14, 76, 22, 36, 44, 16, 74, 22, 88, 52, 80, 80, 50, 88], PIETRA, SCURO, 2.0)
				pol([22, 36, 44, 16, 74, 22, 56, 40, 36, 50], PIETRA_C, SCURO, 1.2)
				pol([56, 40, 74, 22, 88, 52, 80, 80, 62, 66], PIETRA.darkened(0.25), SCURO, 1.2)
				crepa(36, 50, 50, 84, Color(0.2, 0.18, 0.16), 1.6)
			"frecce_rapide":
				for i in 3:
					freccia(6, 26 + i * 24, 70 + (i % 2) * 14, 26 + i * 24, ORO if i == 1 else AMBRA_C, 3.0)
			"enso":
				arco(50, 50, 34, -80, 240, 10.0, SCURO)
				arco(50, 50, 34, -80, 240, 6.5, AMBRA_C)
				scint(50, 50, 20, BIANCO, 0.0)
				scint(50, 50, 9, ORO, 0.0)
			"artigli":
				for i in 3:
					var x0 := 22.0 + i * 22
					pol([x0, 10, x0 + 14, 30, x0 + 6, 90, x0 - 4, 30], ROSSO_C if i != 1 else BIANCO, SCURO, 1.6)
				for q in [[30, 90], [60, 94]]:
					goccia(q[0], q[1] - 6, 3.2, ROSSO, 1.0)
			"sigillo":
				disco(50, 50, 38, Color(0.9, 0.55, 0.15), 2.0)
				arco(50, 50, 32, 0, 360, 2.0, AMBRA_C)
				pol([50, 22, 76, 50, 50, 78, 24, 50], AMBRA_C, SCURO, 1.6)
				pol([50, 34, 64, 50, 50, 66, 36, 50], ROSSO, SCURO, 1.2)
				disco(50, 50, 4, BIANCO, 0.0)
			"risonanza":
				for i in 4:
					arco(50, 50, 10 + i * 11, 0, 360, 4.0 - i * 0.5, AMBRA_C if i % 2 == 0 else BIANCO)
				disco(50, 50, 7, BIANCO, 1.4)
				for i in 4:
					var t := deg_to_rad(45.0 + i * 90.0)
					scint(50 + cos(t) * 44, 50 + sin(t) * 44, 5, ORO, 0.0)
			"baluardo":
				scudo(50, 48, 1.4, BRONZO, ACCIAIO)
				pol([40, 36, 50, 24, 60, 36, 55, 36, 55, 52, 45, 52, 45, 36], BRONZO_C, SCURO, 1.2)
			"veleno":
				goccia(46, 56, 22, VERDE, 2.0)
				goccia(46, 56, 14, VERDE_C, 0.0)
				disco(76, 28, 6, VERDE_C, 1.2)
				disco(84, 46, 4, VERDE_C, 1.0)
				disco(20, 24, 5, VERDE_C, 1.0)
			"stordito":
				busto(50, 66, 0.8, Color(0.82, 0.78, 0.9))
				for i in 3:
					var t := TAU * i / 3.0
					scint(50 + cos(t) * 30, 28 + sin(t) * 8, 8, ORO, 0.8)
				arco(50, 28, 30, 0, 360, 2.0, ORO_O)
			"squilibrato":
				scudo(50, 48, 1.4, ROSSO.darkened(0.2), ACCIAIO_O)
				crepa(50, 14, 56, 84, BIANCO, 2.6)
				crepa(30, 30, 76, 60, BIANCO, 2.0)
				esplosione(50, 50, 4, 10, 6, ORO, 0, 1.0)
			"pozione_p", "pozione_m", "pozione_g":
				var sc := 0.85 if nome == "pozione_p" else (1.0 if nome == "pozione_m" else 1.15)
				apri(Vector2(50, 54), 0.0, sc)
				pol([-6, -38, 6, -38, 6, -24, 22, -4, 22, 30, 14, 38, -14, 38, -22, 30, -22, -4, -6, -24], Color(0.85, 0.95, 1.0, 0.55), SCURO, 2.0)
				pol([-19, 4, 19, 4, 19, 29, 12, 35, -12, 35, -19, 29], ROSSO, SCURO, 0.0)
				pol([-19, 4, 19, 4, 17, 9, -17, 9], ROSSO_C, SCURO, 0.0)
				pol([-8, -42, 8, -42, 8, -36, -8, -36], LEGNO, SCURO, 1.4)
				pol([-14, 10, -10, 10, -10, 28, -14, 24], Color(1, 1, 1, 0.45), SCURO, 0.0)
				chiudi()
			"te_p", "te_m", "te_g":
				var sc := 0.85 if nome == "te_p" else (1.0 if nome == "te_m" else 1.15)
				apri(Vector2(50, 56), 0.0, sc)
				pol([-30, -8, 30, -8, 26, 22, 14, 34, -14, 34, -26, 22], Color(0.92, 0.95, 1.0), SCURO, 2.0)
				pol([-27, -5, 27, -5, 27, 2, -27, 2], AZZURRO, SCURO, 0.0)
				pol([-26, 8, 26, 8, 22, 22, 12, 32, -12, 32, -22, 22], Color(0.55, 0.78, 0.95, 0.6), SCURO, 0.0)
				poli([Vector2(-14, -20), Vector2(-6, -30), Vector2(-14, -40)], 3.0, AZZURRO_C)
				poli([Vector2(6, -20), Vector2(14, -30), Vector2(6, -40)], 3.0, AZZURRO_C)
				chiudi()
			_:
				# simbolo generico: rune a stella dentro un cerchio
				arco(50, 50, 36, 0, 360, 4.0, ACCIAIO_O)
				esplosione(50, 50, 12, 28, 4, ACCIAIO, 45, 1.6)
				disco(50, 50, 6, ORO, 1.4)

	const VENTO_COL := [Color(0.70, 0.90, 1.0), Color(0.48, 0.74, 0.92)]
