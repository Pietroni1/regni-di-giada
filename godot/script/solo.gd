class_name Solo
extends RefCounted
## Partita in solitaria: se accanto all'eseguibile c'è la cartella `server_locale` (la mette `tools/pacchetto/solo.mjs`:
## il server del gioco e un Node già pronto), il gioco avvia da sé quel server, senza finestre, e ci si collega.
## Chi gioca non deve installare né aprire nulla. Il server ascolta solo su questo computer e si spegne da solo una
## decina di secondi dopo la chiusura del gioco (vedi `SOLO` in server/index.js): qui non lo si uccide mai, così ha
## sempre il tempo di salvare.
## I salvataggi stanno nella cartella dei dati dell'utente (non accanto all'eseguibile): sostituendo la cartella del gioco
## con una versione nuova i personaggi restano.

const PORTA := 31717           # porta insolita: non deve scontrarsi con un server «vero» sulla 3000
const TENTATIVI_PORTA := 3     # se la porta è presa da un altro programma si provano le successive
const UTENTE := "giocatore"    # account interno della partita in solitaria
const PASSWORD := "solitaria"

static var pid := -1
static var porta := PORTA
static var _cartella := "?"


## La cartella del server accanto all'eseguibile, o "" se non c'è (editor, browser, eseguibile da solo).
static func cartella() -> String:
	if _cartella != "?":
		return _cartella
	_cartella = ""
	if not OS.has_feature("web"):
		var c := OS.get_executable_path().get_base_dir().path_join("server_locale")
		if FileAccess.file_exists(c.path_join("server/index.js")):
			_cartella = c
	return _cartella


static func disponibile() -> bool:
	return not cartella().is_empty()


static func indirizzo() -> String:
	return "127.0.0.1:%d" % porta


static func cartella_salvataggi() -> String:
	return OS.get_user_data_dir().path_join("salvataggi")


static func in_piedi() -> bool:
	return pid > 0 and OS.is_process_running(pid)


## Avvia il server interno (se non è già quello avviato da noi). Vero se il processo è partito.
static func avvia() -> bool:
	if in_piedi():
		return true
	var c := cartella()
	if c.is_empty():
		return false
	# il Node del pacchetto; se manca si prova quello installato nel computer
	var node := c.path_join("node.exe" if OS.get_name() == "Windows" else "node")
	if not FileAccess.file_exists(node):
		node = "node"
	DirAccess.make_dir_recursive_absolute(cartella_salvataggi())
	# le variabili d'ambiente passano al processo figlio
	OS.set_environment("SOLO", "1")
	OS.set_environment("PORT", str(porta))
	OS.set_environment("DB_FILE", cartella_salvataggi().path_join("solitaria.json"))
	var copione := c.path_join("server/index.js")
	if OS.get_name() == "Windows":
		# percorsi alla maniera di Windows per l'avvio del processo (falso = senza finestra della console)
		node = node.replace("/", "\\")
		copione = copione.replace("/", "\\")
	pid = OS.create_process(node, [copione], false)
	return pid > 0


## Il server avviato è morto subito (di solito: porta occupata da un altro programma): si passa alla porta dopo.
static func porta_successiva() -> bool:
	if porta >= PORTA + TENTATIVI_PORTA - 1:
		return false
	porta += 1
	pid = -1
	return true
