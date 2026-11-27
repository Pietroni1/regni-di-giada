extends Node
## Impostazioni del giocatore, salvate in user://impostazioni.cfg (schermo, qualità, volume, visuale, ultimo accesso).

const FILE := "user://impostazioni.cfg"

var schermo_intero := false
var qualita := 2               # 0 bassa, 1 media, 2 alta
var volume := 0.7              # 0..1
var sensibilita := 1.0         # visuale col mouse
var numeri_danno := true
var contatore := true          # contatore dei danni visibile
var stile := 1                 # 0 grafica di sempre, 1 «tenebra» (prova dark fantasy: tenebra.gd)
var server := "localhost:3000"
var utente := ""
var _tema: Theme


func _ready() -> void:
	_metti_font()
	var c := ConfigFile.new()
	if c.load(FILE) == OK:
		schermo_intero = c.get_value("schermo", "intero", schermo_intero)
		qualita = c.get_value("schermo", "qualita", qualita)
		volume = c.get_value("audio", "volume", volume)
		sensibilita = c.get_value("comandi", "sensibilita", sensibilita)
		numeri_danno = c.get_value("comandi", "numeri_danno", numeri_danno)
		contatore = c.get_value("comandi", "contatore", contatore)
		stile = c.get_value("schermo", "stile", stile)
		server = c.get_value("accesso", "server", server)
		utente = c.get_value("accesso", "utente", utente)
		Tasti.carica(c)
	applica.call_deferred()


func salva() -> void:
	var c := ConfigFile.new()
	c.set_value("schermo", "intero", schermo_intero)
	c.set_value("schermo", "qualita", qualita)
	c.set_value("audio", "volume", volume)
	c.set_value("comandi", "sensibilita", sensibilita)
	c.set_value("comandi", "numeri_danno", numeri_danno)
	c.set_value("comandi", "contatore", contatore)
	c.set_value("schermo", "stile", stile)
	c.set_value("accesso", "server", server)
	c.set_value("accesso", "utente", utente)
	Tasti.salva(c)
	c.save(FILE)


## Applica schermo, qualità e volume. La qualità tocca ombre, antialiasing e risoluzione interna.
func applica() -> void:
	if DisplayServer.get_name() != "headless":
		var modo := DisplayServer.WINDOW_MODE_FULLSCREEN if schermo_intero else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != modo and not OS.has_feature("movie"):
			DisplayServer.window_set_mode(modo)
	var vp := get_viewport()
	var q := clampi(qualita, 0, 2)
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X][q]
	vp.screen_space_aa = [Viewport.SCREEN_SPACE_AA_DISABLED, Viewport.SCREEN_SPACE_AA_FXAA, Viewport.SCREEN_SPACE_AA_DISABLED][q]
	vp.scaling_3d_scale = [0.75, 1.0, 1.0][q]
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 2048][q], true)
	var sole: DirectionalLight3D = get_tree().current_scene.get_node_or_null("Sole") if get_tree().current_scene != null else null
	if sole != null:
		# ombre: due fasce invece di quattro e più vicine (ogni fascia ridisegna tutto ciò che fa ombra)
		sole.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if q == 0 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sole.directional_shadow_blend_splits = false
		sole.directional_shadow_max_distance = [45.0, 70.0, 95.0][q]
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.001)


## Font dei testi: Tahoma libero (vedi font/LEGGIMI.md); kanji e simboli mancanti dal font predefinito di Godot.
func _metti_font() -> void:
	# letto come file (non come risorsa importata): funziona anche senza passare dall'editor
	# (negli eseguibili esportati e nel browser il file .ttf non c'è: lì si prende la risorsa importata)
	var f: FontFile = null
	if FileAccess.file_exists("res://font/testo.ttf"):
		var dati := FileAccess.get_file_as_bytes("res://font/testo.ttf")
		if not dati.is_empty():
			f = FontFile.new()
			f.data = dati
	if f == null:
		var ris := load("res://font/testo.ttf") as FontFile
		if ris != null:
			f = ris.duplicate() as FontFile
	if f == null:
		return
	f.fallbacks = [ThemeDB.fallback_font]
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	ThemeDB.fallback_font = f
	_tema = Theme.new()
	_tema.default_font = f
	get_tree().root.set_deferred("theme", _tema)
	# il tema non attraversa i nodi che non sono Control (CanvasLayer, Node3D): lo si dà al primo Control di ogni ramo
	get_tree().node_added.connect(func(n: Node) -> void:
		if n is Control and not (n.get_parent() is Control) and n.theme == null:
			n.theme = _tema)
