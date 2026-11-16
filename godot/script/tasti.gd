class_name Tasti
extends RefCounted
## Tasti rimappabili. Ogni azione del gioco ha un tasto fisico (come in `gioco.gd`: `physical_keycode`); le assegnazioni
## cambiate dal giocatore sono salvate da `Impostazioni` (sezione «tasti» di impostazioni.cfg). I testi di aiuto, le
## intestazioni delle finestre e i numeri della barra rapida li mostrano col tasto vero: i testi si scrivono con segnaposto
## `{azione}` (per esempio «Inventario [{inventario}]») e si registrano con `Tasti.registra(controllo, modello)`.
## Restano fissi (non rimappabili): Esc (chiude/menu), F1 (aiuto), F11 (schermo intero) e le frecce (alternativa al movimento).

# [id, nome, gruppo, tasto predefinito]
const AZIONI := [
	["avanti", "Avanti", "Movimento", KEY_W],
	["indietro", "Indietro", "Movimento", KEY_S],
	["sinistra", "Sinistra", "Movimento", KEY_A],
	["destra", "Destra", "Movimento", KEY_D],
	["ruota_sx", "Gira la visuale a sinistra", "Movimento", KEY_Q],
	["ruota_dx", "Gira la visuale a destra", "Movimento", KEY_E],
	["barra_1", "Barra rapida 1", "Combattimento", KEY_1],
	["barra_2", "Barra rapida 2", "Combattimento", KEY_2],
	["barra_3", "Barra rapida 3", "Combattimento", KEY_3],
	["barra_4", "Barra rapida 4", "Combattimento", KEY_4],
	["barra_5", "Barra rapida 5", "Combattimento", KEY_5],
	["barra_6", "Barra rapida 6", "Combattimento", KEY_6],
	["barra_7", "Barra rapida 7", "Combattimento", KEY_7],
	["barra_8", "Barra rapida 8", "Combattimento", KEY_8],
	["barra_9", "Barra rapida 9", "Combattimento", KEY_9],
	["barra_10", "Barra rapida 10", "Combattimento", KEY_0],
	["suprema", "Tecnica Suprema", "Combattimento", KEY_V],
	["bersaglio", "Bersaglio successivo", "Combattimento", KEY_TAB],
	["interagisci", "Raccogli / interagisci", "Azioni", KEY_Z],
	["cavalcatura", "Sali / scendi da cavallo", "Azioni", KEY_R],
	["chat", "Scrivi in chat", "Azioni", KEY_ENTER],
	["inventario", "Inventario", "Finestre", KEY_I],
	["personaggio", "Personaggio", "Finestre", KEY_C],
	["abilita", "Abilità", "Finestre", KEY_K],
	["mappa", "Mappa grande", "Finestre", KEY_M],
	["diario", "Diario delle missioni", "Finestre", KEY_L],
	["amici", "Amici", "Finestre", KEY_F],
	["aiuto", "Comandi e aiuto", "Finestre", KEY_H],
	["impostazioni", "Impostazioni", "Finestre", KEY_O],
]

## Tasti che non si possono assegnare (hanno un significato fisso).
const RISERVATI := [KEY_ESCAPE, KEY_F1, KEY_F11, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_KP_ENTER]

const NOMI_SPECIALI := {
	KEY_ENTER: "Invio", KEY_SPACE: "Spazio", KEY_SHIFT: "Maiusc", KEY_CTRL: "Ctrl", KEY_ALT: "Alt", KEY_TAB: "Tab",
	KEY_BACKSPACE: "Backspace", KEY_DELETE: "Canc", KEY_INSERT: "Ins", KEY_HOME: "Inizio", KEY_END: "Fine",
	KEY_PAGEUP: "Pag su", KEY_PAGEDOWN: "Pag giù", KEY_QUOTELEFT: "\\", KEY_CAPSLOCK: "Bloc Maiusc",
}

static var mappa: Dictionary = {}          # id → codice fisico del tasto (solo quelli cambiati)
static var registrati: Array = []          # [{ "c": controllo, "m": modello }]


static func predefinito(id: String) -> int:
	for a in AZIONI:
		if a[0] == id:
			return int(a[3])
	return KEY_NONE


static func codice(id: String) -> int:
	return int(mappa.get(id, predefinito(id)))


## Quale azione è assegnata a questo tasto fisico (stringa vuota se nessuna).
static func azione_di(tasto: int) -> String:
	for a in AZIONI:
		if codice(String(a[0])) == tasto:
			return String(a[0])
	return ""


## Il tasto dell'azione è premuto adesso? Per il movimento valgono anche le frecce.
static func premuto(id: String) -> bool:
	if Input.is_physical_key_pressed(codice(id)):
		return true
	match id:
		"avanti": return Input.is_physical_key_pressed(KEY_UP)
		"indietro": return Input.is_physical_key_pressed(KEY_DOWN)
		"sinistra": return Input.is_physical_key_pressed(KEY_LEFT)
		"destra": return Input.is_physical_key_pressed(KEY_RIGHT)
	return false


static func nome_tasto(tasto: int) -> String:
	if tasto == KEY_NONE:
		return "—"
	if NOMI_SPECIALI.has(tasto):
		return String(NOMI_SPECIALI[tasto])
	var etichetta: int = tasto
	if DisplayServer.get_name() != "headless":
		var e: int = DisplayServer.keyboard_get_label_from_physical(tasto as Key)
		if e != 0:
			etichetta = e
	var s := OS.get_keycode_string(etichetta as Key)
	if s.is_empty():
		s = OS.get_keycode_string(tasto as Key)
	return s if not s.is_empty() else "?"


## Nome del tasto di un'azione, per i testi («I», «Tab», «Invio»…).
static func nome(id: String) -> String:
	return nome_tasto(codice(id))


## Numero mostrato sul tasto della barra rapida (indice 0-9).
static func nome_barra(indice: int) -> String:
	return nome("barra_%d" % (indice + 1))


## Sostituisce i segnaposto «{azione}» col tasto vero.
static func sostituisci(modello: String) -> String:
	var out := modello
	for a in AZIONI:
		var seg := "{%s}" % a[0]
		if out.contains(seg):
			out = out.replace(seg, nome(String(a[0])))
	return out


## Registra un controllo di testo (Label, Button): il suo testo si ricalcola quando cambiano i tasti.
static func registra(c: Control, modello: String) -> void:
	registrati = registrati.filter(func(r: Dictionary) -> bool: return is_instance_valid(r.c))
	registrati.append({"c": c, "m": modello})
	_metti(c, modello)


static func _metti(c: Control, modello: String) -> void:
	if c is Label or c is Button:
		c.text = sostituisci(modello)


static func aggiorna_testi() -> void:
	registrati = registrati.filter(func(r: Dictionary) -> bool: return is_instance_valid(r.c))
	for r in registrati:
		_metti(r.c, String(r.m))


## Assegna un tasto a un'azione. Se lo usa già un'altra azione, i due tasti si scambiano. Restituisce l'azione scambiata
## (stringa vuota se nessuna) oppure «!» se il tasto è riservato.
static func assegna(id: String, tasto: int) -> String:
	if tasto in RISERVATI:
		return "!"
	var altra := azione_di(tasto)
	var mio := codice(id)
	mappa[id] = tasto
	if altra != "" and altra != id:
		mappa[altra] = mio
	_pulisci()
	return altra if altra != id else ""


static func ripristina() -> void:
	mappa = {}


static func _pulisci() -> void:
	for a in AZIONI:
		var id := String(a[0])
		if mappa.has(id) and int(mappa[id]) == predefinito(id):
			mappa.erase(id)


static func carica(c: ConfigFile) -> void:
	mappa = {}
	if not c.has_section("tasti"):
		return
	var viste := {}
	for a in AZIONI:
		var id := String(a[0])
		if c.has_section_key("tasti", id):
			var k := int(c.get_value("tasti", id))
			if k != KEY_NONE and not (k in RISERVATI):
				mappa[id] = k
	# un file modificato a mano potrebbe assegnare lo stesso tasto a due azioni: si torna ai predefiniti
	for a in AZIONI:
		var k := codice(String(a[0]))
		if viste.has(k):
			mappa = {}
			return
		viste[k] = true
	_pulisci()


static func salva(c: ConfigFile) -> void:
	for a in AZIONI:
		var id := String(a[0])
		if mappa.has(id):
			c.set_value("tasti", id, int(mappa[id]))
