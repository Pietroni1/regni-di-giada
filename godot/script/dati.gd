extends Node
## Tabelle del gioco e terreno, letti dai file scritti da `npm run godot:dati` (tools/godot/esporta.mjs).
## Sono gli stessi numeri del server: qui non si decide nulla, si mostra soltanto.

var gioco: Dictionary = {}
var indice: Dictionary = {}
var SKILLS: Dictionary
var CLASSES: Dictionary
var VIE: Dictionary
var MOBS: Dictionary
var ITEMS: Dictionary
var BUFFS: Dictionary
var RESOURCES: Dictionary
var KINGDOMS: Dictionary
var costanti: Dictionary

var lato_h := 0
var passo_h := 2.0
var lato_p := 0
var passo_p := 1.0
var meta := 300.0
var altezze: PackedFloat32Array
var pesi_a: Image
var pesi_b: Image


func _ready() -> void:
	gioco = _json("res://dati/gioco.json")
	indice = _json("res://dati/indice.json")
	SKILLS = gioco.SKILLS
	CLASSES = gioco.CLASSES
	VIE = gioco.VIE
	MOBS = gioco.MOBS
	ITEMS = gioco.ITEMS
	BUFFS = gioco.BUFFS
	RESOURCES = gioco.RESOURCES
	KINGDOMS = gioco.KINGDOMS
	costanti = gioco.costanti
	meta = float(costanti.WORLD_HALF)
	_terreno()


func _json(percorso: String) -> Dictionary:
	var testo := FileAccess.get_file_as_string(percorso)
	if testo.is_empty():
		push_error("Manca %s: lancia `npm run godot:dati` nella cartella del progetto." % percorso)
		return {}
	return JSON.parse_string(testo)


func _terreno() -> void:
	var f := FileAccess.open("res://dati/terreno.bin", FileAccess.READ)
	if f == null:
		push_error("Manca res://dati/terreno.bin: lancia `npm run godot:dati`.")
		return
	f.get_buffer(4)
	lato_h = f.get_32()
	passo_h = f.get_float()
	lato_p = f.get_32()
	passo_p = f.get_float()
	altezze = f.get_buffer(lato_h * lato_h * 4).to_float32_array()
	pesi_a = Image.create_from_data(lato_p, lato_p, false, Image.FORMAT_RGBA8, f.get_buffer(lato_p * lato_p * 4))
	pesi_b = Image.create_from_data(lato_p, lato_p, false, Image.FORMAT_RGBA8, f.get_buffer(lato_p * lato_p * 4))


## Altezza del terreno in un punto (interpolazione sulla griglia esportata dal server).
func altezza(x: float, z: float) -> float:
	if x > float(costanti.DUNGEON_X) or lato_h == 0:
		return 0.0
	var gx := clampf((x + meta) / passo_h, 0.0, lato_h - 1.001)
	var gz := clampf((z + meta) / passo_h, 0.0, lato_h - 1.001)
	var ix := int(gx)
	var iz := int(gz)
	var fx := gx - ix
	var fz := gz - iz
	var a := altezze[iz * lato_h + ix]
	var b := altezze[iz * lato_h + ix + 1]
	var c := altezze[(iz + 1) * lato_h + ix]
	var d := altezze[(iz + 1) * lato_h + ix + 1]
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)


func suolo(x: float, z: float) -> Vector3:
	return Vector3(x, altezza(x, z), z)


## Colore da un numero 0xRRGGBB delle tabelle.
func colore(v, alfa := 1.0) -> Color:
	if v == null:
		return Color(1, 1, 1, alfa)
	if v is String:
		return Color(v, alfa)
	var n := int(v)
	return Color(((n >> 16) & 255) / 255.0, ((n >> 8) & 255) / 255.0, (n & 255) / 255.0, alfa)


## Dalle coordinate locali di un villaggio a quelle del mondo (come toWorld in shared/world.js).
func nel_villaggio(kid: String, lx: float, lz: float) -> Vector2:
	var f: Dictionary = gioco.villaggi[kid]
	return Vector2(f.x + lx * f.cos + lz * f.sin, f.z - lx * f.sin + lz * f.cos)


## Spinge fuori dagli ostacoli (edifici, mura, pozzo): come resolveCollisions in shared/world.js.
func risolvi_urti(x: float, z: float, raggio: float) -> Vector2:
	for c in gioco.ostacoli:
		var dx: float = x - c.x
		var dz: float = z - c.z
		if dx * dx + dz * dz > 400.0:
			continue
		if c.t == "circle":
			var d := sqrt(dx * dx + dz * dz)
			var m: float = c.r + raggio
			if d < m and d > 1e-6:
				x = c.x + dx / d * m
				z = c.z + dz / d * m
			continue
		var lx: float = dx * c.cos - dz * c.sin
		var lz: float = dx * c.sin + dz * c.cos
		var px := clampf(lx, -c.hw, c.hw)
		var pz := clampf(lz, -c.hd, c.hd)
		var ex := lx - px
		var ez := lz - pz
		var dd := sqrt(ex * ex + ez * ez)
		if dd >= raggio:
			continue
		if dd > 1e-6:
			lx = px + ex / dd * raggio
			lz = pz + ez / dd * raggio
		else:
			var ox: float = c.hw - absf(lx)
			var oz: float = c.hd - absf(lz)
			if ox < oz:
				lx = (1.0 if lx >= 0.0 else -1.0) * (c.hw + raggio)
			else:
				lz = (1.0 if lz >= 0.0 else -1.0) * (c.hd + raggio)
		x = c.x + lx * c.cos + lz * c.sin
		z = c.z - lx * c.sin + lz * c.cos
	return Vector2(x, z)


## Valore di una tecnica al livello dato: [base, incremento per livello] oppure un numero.
func valore(arr, lvl: int) -> float:
	if arr is Array:
		return float(arr[0]) + float(arr[1]) * (lvl - 1)
	return float(arr)
