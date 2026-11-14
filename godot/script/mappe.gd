class_name Mappe
## Mappe da esperienza e Arena (shared/mappe.js): in quale mappa si è, confini, zone sicure e altezze.
## Le altezze arrivano in griglia da `npm run godot:dati` (dati/mappe.bin); le regole sono le stesse del server.

static var _griglie: Dictionary = {}     # id → PackedFloat32Array
static var _caricate := false


static func definizioni() -> Dictionary:
	return Dati.gioco.get("MAPPE", {})


## Id della mappa che contiene il punto ("" se è nel mondo dei regni o nella cripta).
static func mappa_a(x: float, z: float) -> String:
	if not Dati.costanti.has("MAPPE_X") or x <= float(Dati.costanti.MAPPE_X):
		return ""
	var reg := float(Dati.costanti.MAPPE_REGIONE)
	var defs := definizioni()
	for id in defs:
		var m: Dictionary = defs[id]
		if absf(x - float(m.cx)) < reg and absf(z - float(m.cz)) < reg:
			return String(id)
	return ""


static func in_arena(x: float, z: float) -> bool:
	return mappa_a(x, z) == "arena"


static func _carica() -> void:
	if _caricate:
		return
	_caricate = true
	var f := FileAccess.open("res://dati/mappe.bin", FileAccess.READ)
	if f == null:
		push_error("Manca res://dati/mappe.bin: lancia `npm run godot:dati`.")
		return
	var tutto := f.get_buffer(f.get_length())
	var defs := definizioni()
	for id in defs:
		var g: Dictionary = defs[id].griglia
		var n := int(g.lato) * int(g.lato) * 4
		_griglie[id] = tutto.slice(int(g.offset), int(g.offset) + n).to_float32_array()


## Griglia delle altezze di una mappa (lato × lato, passo `griglia.passo`).
static func griglia(id: String) -> PackedFloat32Array:
	_carica()
	return _griglie.get(id, PackedFloat32Array())


## Altezza del terreno (interpolata sulla griglia esportata; come altezzaMappa in shared/mappe.js).
static func altezza(x: float, z: float) -> float:
	var id := mappa_a(x, z)
	if id == "":
		return 0.0
	var arr := griglia(id)
	if arr.is_empty():
		return 0.0
	var g: Dictionary = definizioni()[id].griglia
	var lato := int(g.lato)
	var gx := clampf((x - float(g.x0)) / float(g.passo), 0.0, lato - 1.001)
	var gz := clampf((z - float(g.z0)) / float(g.passo), 0.0, lato - 1.001)
	var ix := int(gx)
	var iz := int(gz)
	var fx := gx - ix
	var fz := gz - iz
	var a := arr[iz * lato + ix]
	var b := arr[iz * lato + ix + 1]
	var c := arr[(iz + 1) * lato + ix]
	var d := arr[(iz + 1) * lato + ix + 1]
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)


## Angolo di una porta dell'arena (direzione (sin a, cos a), come portaArena).
static func angolo_porta(i: int) -> float:
	return TAU * i / float(definizioni().arena.porte)


static func _porta_di(m: Dictionary, lx: float, lz: float) -> int:
	for i in range(int(m.porte)):
		var a := angolo_porta(i)
		var sx := sin(a)
		var sz := cos(a)
		var lungo := lx * sx + lz * sz
		var lato := lx * sz - lz * sx
		if Vector2(lx - sx * float(m.distNicchia), lz - sz * float(m.distNicchia)).length() <= float(m.nicchia):
			return i
		if lungo >= float(m.raggio) - 3.0 and lungo <= float(m.distNicchia) and absf(lato) <= float(m.corridoio):
			return i
	return -1


## Zona sicura: spiazzo d'arrivo delle mappe da esperienza, porte e nicchie dell'arena.
static func sicuro(x: float, z: float) -> bool:
	var id := mappa_a(x, z)
	if id == "":
		return false
	var m: Dictionary = definizioni()[id]
	var lx := x - float(m.cx)
	var lz := z - float(m.cz)
	if String(m.tipo) == "arena":
		return Vector2(lx, lz).length() > float(m.raggio)
	return Vector2(lx - float(m.arrivo.x), lz - float(m.arrivo.z)).length() < float(m.sicuro)


## Riporta il punto dentro l'area percorribile (come limitaMappa in shared/mappe.js).
static func limita(id: String, x: float, z: float) -> Vector2:
	var m: Dictionary = definizioni()[id]
	var lx := x - float(m.cx)
	var lz := z - float(m.cz)
	var d := Vector2(lx, lz).length()
	var R := float(m.raggio)
	if String(m.tipo) != "arena":
		if d > R:
			lx *= R / d
			lz *= R / d
		return Vector2(float(m.cx) + lx, float(m.cz) + lz)
	if d <= R or _porta_di(m, lx, lz) >= 0:
		return Vector2(x, z)
	var meglio := Vector2(lx, lz) * (R / d)
	var md := d - R
	for i in range(int(m.porte)):
		var a := angolo_porta(i)
		var sx := sin(a)
		var sz := cos(a)
		var n := Vector2(sx, sz) * float(m.distNicchia)
		var dn := Vector2(lx, lz).distance_to(n)
		if dn - float(m.nicchia) < md:
			md = dn - float(m.nicchia)
			meglio = n + (Vector2(lx, lz) - n) / dn * float(m.nicchia) * 0.99
		var lungo := clampf(lx * sx + lz * sz, R - 3.0, float(m.distNicchia))
		var lato := clampf(lx * sz - lz * sx, -float(m.corridoio), float(m.corridoio))
		var c := Vector2(sx * lungo + sz * lato, sz * lungo - sx * lato)
		var dc := Vector2(lx, lz).distance_to(c)
		if dc < md:
			md = dc
			meglio = c
	return Vector2(float(m.cx) + meglio.x, float(m.cz) + meglio.y)


## Nome della zona per l'interfaccia ("" fuori dalle mappe).
static func nome_zona(x: float, z: float) -> String:
	var id := mappa_a(x, z)
	if id == "":
		return ""
	var nome := String(definizioni()[id].nome)
	if sicuro(x, z):
		nome += " — zona sicura"
	return nome


## Disegna sulla minimappa i confini della mappa e le zone sicure (c = centro della minimappa, `scala` px per metro).
static func disegna_minimappa(tela: Control, io_x: float, io_z: float, c: Vector2, scala: float, lato: float) -> void:
	var id := mappa_a(io_x, io_z)
	if id == "":
		return
	var m: Dictionary = definizioni()[id]
	var centro := c + Vector2(float(m.cx) - io_x, float(m.cz) - io_z) * scala
	var bordo := Color(0.85, 0.72, 0.42, 0.8)
	var sicura := Color(0.45, 0.85, 0.55, 0.55)
	var dentro := lato * 0.5 - 2.0
	_cerchio(tela, centro, float(m.raggio) * scala, c, dentro, bordo)
	if String(m.tipo) == "arena":
		for i in range(int(m.porte)):
			var a := angolo_porta(i)
			_cerchio(tela, centro + Vector2(sin(a), cos(a)) * float(m.distNicchia) * scala, float(m.nicchia) * scala, c, dentro, sicura)
	else:
		_cerchio(tela, centro + Vector2(float(m.arrivo.x), float(m.arrivo.z)) * scala, float(m.sicuro) * scala, c, dentro, sicura)


## Circonferenza disegnata solo dentro il disco della minimappa (raggio `dentro` attorno a `c`).
static func _cerchio(tela: Control, centro: Vector2, r: float, c: Vector2, dentro: float, colore: Color) -> void:
	var n := clampi(int(r * 0.6), 24, 160)
	var prec := centro + Vector2(r, 0)
	for i in range(1, n + 1):
		var a := TAU * i / n
		var p := centro + Vector2(cos(a), sin(a)) * r
		if prec.distance_to(c) < dentro and p.distance_to(c) < dentro:
			tela.draw_line(prec, p, colore, 2.0)
		prec = p
