class_name Tasti
extends RefCounted
## Tasti personalizzabili. Ogni azione del gioco ha fino a DUE comandi (principale e alternativo); un comando è un tasto
## fisico della tastiera (come in `gioco.gd`: `physical_keycode`), da solo o con Maiusc / Ctrl / Alt, oppure un tasto del
## mouse (centrale e laterali). Le scelte del giocatore sono salvate da `Impostazioni` (sezione «tasti» di
## impostazioni.cfg). I testi di aiuto, le intestazioni delle finestre e i numeri della barra rapida mostrano il tasto
## vero: i testi si scrivono con segnaposto `{azione}` (per esempio «Inventario [{inventario}]») e si registrano con
## `Tasti.registra(controllo, modello)`.
## Un comando è un intero: codice fisico del tasto | MAIUSC | CTRL | ALT, oppure TOPO | indice del tasto del mouse.
## Fissi: Esc (chiude/menu), tasto sinistro (clic), destro (visuale) e rotella (distanza della visuale).

const MAIUSC := 1 << 25        # come KEY_MASK_SHIFT
const CTRL := 1 << 26          # come KEY_MASK_CTRL
const ALT := 1 << 27           # come KEY_MASK_ALT
const MODIFICATORI := MAIUSC | CTRL | ALT
const TOPO := 1 << 30          # tasto del mouse: TOPO | indice
const T_CENTRALE := TOPO | 3   # MOUSE_BUTTON_MIDDLE
const T_LATO_1 := TOPO | 8     # MOUSE_BUTTON_XBUTTON1
const T_LATO_2 := TOPO | 9     # MOUSE_BUTTON_XBUTTON2

# [id, nome, gruppo, comando predefinito, alternativo predefinito (facoltativo)]
const AZIONI := [
	["avanti", "Avanti", "Movimento", KEY_W, KEY_UP],
	["indietro", "Indietro", "Movimento", KEY_S, KEY_DOWN],
	["sinistra", "Sinistra", "Movimento", KEY_A, KEY_LEFT],
	["destra", "Destra", "Movimento", KEY_D, KEY_RIGHT],
	["ruota_sx", "Gira la visuale a sinistra", "Movimento", KEY_Q],
	["ruota_dx", "Gira la visuale a destra", "Movimento", KEY_E],
	["autocorsa", "Corsa automatica", "Movimento", KEY_X, T_CENTRALE],
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
	["bersaglio_prec", "Bersaglio precedente", "Combattimento", KEY_TAB | MAIUSC],
	["attacca", "Attacca il bersaglio", "Combattimento", KEY_T],
	["interagisci", "Raccogli / interagisci", "Azioni", KEY_Z],
	["cavalcatura", "Sali / scendi da cavallo", "Azioni", KEY_R],
	["chat", "Scrivi in chat", "Azioni", KEY_ENTER, KEY_KP_ENTER],
	["inventario", "Inventario", "Finestre", KEY_I, KEY_B],
	["personaggio", "Personaggio", "Finestre", KEY_C],
	["abilita", "Abilità", "Finestre", KEY_K],
	["mappa", "Mappa grande", "Finestre", KEY_M],
	["diario", "Diario delle missioni", "Finestre", KEY_L],
	["imprese", "Imprese e titoli", "Finestre", KEY_J],
	["amici", "Amici", "Finestre", KEY_F],
	["contatore", "Contatore dei danni", "Finestre", KEY_N],
	["aiuto", "Comandi e aiuto", "Finestre", KEY_H, KEY_F1],
	["impostazioni", "Impostazioni", "Finestre", KEY_O],
	["schermo_intero", "Schermo intero", "Finestre", KEY_F11],
]

## Tasti che non si possono assegnare (hanno un significato fisso).
const RISERVATI := [KEY_ESCAPE]

const NOMI_SPECIALI := {
	KEY_ENTER: "Invio", KEY_KP_ENTER: "Invio (tn)", KEY_SPACE: "Spazio", KEY_TAB: "Tab",
	KEY_BACKSPACE: "Backspace", KEY_DELETE: "Canc", KEY_INSERT: "Ins", KEY_HOME: "Inizio", KEY_END: "Fine",
	KEY_PAGEUP: "Pag su", KEY_PAGEDOWN: "Pag giù", KEY_QUOTELEFT: "\\", KEY_CAPSLOCK: "Bloc Maiusc",
	KEY_UP: "Freccia su", KEY_DOWN: "Freccia giù", KEY_LEFT: "Freccia sx", KEY_RIGHT: "Freccia dx",
}
const NOMI_TOPO := {3: "Tasto centrale", 8: "Mouse 4", 9: "Mouse 5"}
const BREVI_TOPO := {3: "Rot", 8: "Ms4", 9: "Ms5"}
const BREVI_SPECIALI := {
	KEY_ENTER: "Inv", KEY_KP_ENTER: "Inv", KEY_SPACE: "Spz", KEY_UP: "↑", KEY_DOWN: "↓", KEY_LEFT: "←", KEY_RIGHT: "→",
	KEY_DELETE: "Canc", KEY_INSERT: "Ins", KEY_HOME: "Iniz", KEY_END: "Fine", KEY_PAGEUP: "Pg↑", KEY_PAGEDOWN: "Pg↓",
}

static var mappa: Dictionary = {}          # id → [principale, alternativo] (solo le azioni cambiate)
static var registrati: Array = []          # [{ "c": controllo, "m": modello }]
static var _indice: Dictionary = {}        # comando → id dell'azione (ricostruito a ogni modifica)
static var _indice_ok := false


# ------------------------------------------------------------------ lettura
static func predefiniti(id: String) -> Array:
	for a in AZIONI:
		if a[0] == id:
			return [int(a[3]), int(a[4]) if a.size() > 4 else KEY_NONE]
	return [KEY_NONE, KEY_NONE]


static func predefinito(id: String) -> int:
	return int(predefiniti(id)[0])


## I due comandi dell'azione: [principale, alternativo] (KEY_NONE = nessuno).
static func codici(id: String) -> Array:
	return mappa[id] if mappa.has(id) else predefiniti(id)


static func codice(id: String) -> int:
	return int(codici(id)[0])


static func cambiata(id: String, posto: int) -> bool:
	return int(codici(id)[posto]) != int(predefiniti(id)[posto])


static func _rifai_indice() -> void:
	_indice = {}
	for a in AZIONI:
		for k in codici(String(a[0])):
			if int(k) != KEY_NONE and not _indice.has(int(k)):
				_indice[int(k)] = String(a[0])
	_indice_ok = true


## Quale azione ha questo comando (stringa vuota se nessuna).
static func azione_di(comando: int) -> String:
	if not _indice_ok:
		_rifai_indice()
	return String(_indice.get(comando, ""))


## Il comando di un evento della tastiera o del mouse, con i modificatori tenuti premuti. KEY_NONE se l'evento non è
## un comando possibile (Maiusc/Ctrl/Alt da soli, tasto sinistro o destro, rotella).
static func comando_evento(ev: InputEvent) -> int:
	var k := KEY_NONE
	if ev is InputEventKey:
		k = int(ev.physical_keycode)
		if k in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_NONE]:
			return KEY_NONE
	elif ev is InputEventMouseButton:
		if not NOMI_TOPO.has(int(ev.button_index)):
			return KEY_NONE
		k = TOPO | int(ev.button_index)
	else:
		return KEY_NONE
	var e := ev as InputEventWithModifiers
	if e.shift_pressed:
		k |= MAIUSC
	if e.ctrl_pressed:
		k |= CTRL
	if e.alt_pressed:
		k |= ALT
	return k


## L'azione di un evento: prima il comando esatto (Maiusc+1), poi lo stesso tasto senza modificatori (così W cammina
## anche tenendo premuto Maiusc, se «Maiusc+W» non è di nessuno).
static func azione_evento(ev: InputEvent) -> String:
	var k := comando_evento(ev)
	if k == KEY_NONE:
		return ""
	var az := azione_di(k)
	if az.is_empty() and k & MODIFICATORI:
		az = azione_di(k & ~MODIFICATORI)
	return az


static func _tenuto(comando: int) -> bool:
	if comando == KEY_NONE:
		return false
	if comando & MAIUSC and not Input.is_physical_key_pressed(KEY_SHIFT):
		return false
	if comando & CTRL and not Input.is_physical_key_pressed(KEY_CTRL):
		return false
	if comando & ALT and not Input.is_physical_key_pressed(KEY_ALT):
		return false
	var base := comando & ~MODIFICATORI
	if base & TOPO:
		return Input.is_mouse_button_pressed((base & ~TOPO) as MouseButton)
	return Input.is_physical_key_pressed(base as Key)


## Il comando dell'azione è tenuto premuto adesso? (movimento, visuale)
static func premuto(id: String) -> bool:
	for k in codici(id):
		if _tenuto(int(k)):
			return true
	return false


# ------------------------------------------------------------------ nomi
static func _nome_base(tasto: int) -> String:
	if NOMI_SPECIALI.has(tasto):
		return String(NOMI_SPECIALI[tasto])
	var etichetta: int = tasto
	if DisplayServer.get_name() != "headless" and not OS.has_feature("web"):      # nel browser la funzione non esiste
		var e: int = DisplayServer.keyboard_get_label_from_physical(tasto as Key)
		if e != 0:
			etichetta = e
	var s := OS.get_keycode_string(etichetta as Key)
	if s.is_empty():
		s = OS.get_keycode_string(tasto as Key)
	return s if not s.is_empty() else "?"


## Nome per esteso di un comando: «Maiusc+1», «Mouse 4», «Invio».
static func nome_tasto(comando: int) -> String:
	if comando == KEY_NONE:
		return "—"
	var s := ""
	if comando & CTRL:
		s += "Ctrl+"
	if comando & ALT:
		s += "Alt+"
	if comando & MAIUSC:
		s += "Maiusc+"
	var base := comando & ~MODIFICATORI
	if base & TOPO:
		return s + String(NOMI_TOPO.get(base & ~TOPO, "Mouse %d" % (base & ~TOPO)))
	return s + _nome_base(base)


## Nome corto, per i tasti della barra rapida: «M-1» (Maiusc), «C-Q» (Ctrl), «A-2» (Alt), «Ms4».
static func nome_breve(comando: int) -> String:
	if comando == KEY_NONE:
		return ""
	var s := ""
	if comando & CTRL:
		s += "C-"
	if comando & ALT:
		s += "A-"
	if comando & MAIUSC:
		s += "M-"
	var base := comando & ~MODIFICATORI
	if base & TOPO:
		return s + String(BREVI_TOPO.get(base & ~TOPO, "Ms"))
	if BREVI_SPECIALI.has(base):
		return s + String(BREVI_SPECIALI[base])
	return s + _nome_base(base)


## Il comando da mostrare per un'azione: il principale, o l'alternativo se il principale manca.
static func _mostrato(id: String) -> int:
	var c := codici(id)
	return int(c[0]) if int(c[0]) != KEY_NONE else int(c[1])


## Nome del tasto di un'azione, per i testi («I», «Tab», «Invio»…).
static func nome(id: String) -> String:
	return nome_tasto(_mostrato(id))


## Scritta sul tasto della barra rapida (indice 0-9).
static func nome_barra(indice: int) -> String:
	return nome_breve(_mostrato("barra_%d" % (indice + 1)))


## Sostituisce i segnaposto «{azione}» col tasto vero.
static func sostituisci(modello: String) -> String:
	var out := modello
	for a in AZIONI:
		var seg := "{%s}" % a[0]
		if out.contains(seg):
			# i tasti della barra rapida si scrivono in breve («M-1»), gli altri per esteso
			out = out.replace(seg, nome_breve(_mostrato(String(a[0]))) if String(a[0]).begins_with("barra_") else nome(String(a[0])))
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


# ------------------------------------------------------------------ modifica
static func _scrivi(id: String, posto: int, comando: int) -> void:
	var c: Array = codici(id).duplicate()
	c[posto] = comando
	if c == predefiniti(id):
		mappa.erase(id)
	else:
		mappa[id] = c
	_indice_ok = false


## Dà un comando a un'azione (posto 0 = principale, 1 = alternativo). Se quel comando era di un'altra azione le viene
## tolto. Restituisce l'id dell'azione che l'ha perso (stringa vuota se nessuna) oppure «!» se il tasto è riservato.
static func assegna(id: String, posto: int, comando: int) -> String:
	if (comando & ~MODIFICATORI) in RISERVATI or comando == KEY_NONE:
		return "!"
	var persa := ""
	for a in AZIONI:
		var altra := String(a[0])
		var c := codici(altra)
		for p in range(2):
			if int(c[p]) == comando and not (altra == id and p == posto):
				_scrivi(altra, p, KEY_NONE)
				if altra != id:
					persa = altra
	_scrivi(id, posto, comando)
	return persa


## Toglie un comando a un'azione.
static func togli(id: String, posto: int) -> void:
	_scrivi(id, posto, KEY_NONE)


static func ripristina() -> void:
	mappa = {}
	_indice_ok = false


## Azioni rimaste senza nessun comando (da segnalare nella pagina dei tasti).
static func senza_tasto() -> Array:
	var out: Array = []
	for a in AZIONI:
		var c := codici(String(a[0]))
		if int(c[0]) == KEY_NONE and int(c[1]) == KEY_NONE:
			out.append(String(a[1]))
	return out


# ------------------------------------------------------------------ salvataggio
static func carica(c: ConfigFile) -> void:
	mappa = {}
	_indice_ok = false
	if not c.has_section("tasti"):
		return
	for a in AZIONI:
		var id := String(a[0])
		if not c.has_section_key("tasti", id):
			continue
		var v = c.get_value("tasti", id)
		var coppia: Array = predefiniti(id)
		if v is Array and v.size() >= 2:
			coppia = [int(v[0]), int(v[1])]
		elif v is int or v is float:
			coppia[0] = int(v)                 # file di prima: un solo tasto per azione
		for p in range(2):
			if (int(coppia[p]) & ~MODIFICATORI) in RISERVATI:
				coppia[p] = KEY_NONE
		if coppia != predefiniti(id):
			mappa[id] = coppia
	# lo stesso comando su due azioni (file ritoccato a mano, o un predefinito nuovo che cade su un tasto già scelto):
	# resta alla prima, e fra le due vince quella scelta dal giocatore
	var visti := {}
	var ordine: Array = []
	for a in AZIONI:
		if mappa.has(String(a[0])):
			ordine.append(String(a[0]))
	for a in AZIONI:
		if not mappa.has(String(a[0])):
			ordine.append(String(a[0]))
	for id in ordine:
		var cc: Array = codici(id).duplicate()
		var cambiato := false
		for p in range(2):
			var k := int(cc[p])
			if k == KEY_NONE:
				continue
			if visti.has(k):
				cc[p] = KEY_NONE
				cambiato = true
			else:
				visti[k] = true
		if cambiato:
			mappa[id] = cc
	_indice_ok = false


static func salva(c: ConfigFile) -> void:
	for a in AZIONI:
		var id := String(a[0])
		if mappa.has(id):
			c.set_value("tasti", id, [int(mappa[id][0]), int(mappa[id][1])])
