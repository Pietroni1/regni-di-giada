extends Node
## Impostazioni del giocatore, salvate in user://impostazioni.cfg (schermo, qualità, volume, visuale, ultimo accesso).

const FILE := "user://impostazioni.cfg"

var schermo_intero := false
var qualita := 2               # 0 bassa, 1 media, 2 alta
var volume := 0.7              # 0..1
var sensibilita := 1.0         # visuale col mouse
var numeri_danno := true
var server := "localhost:3000"
var utente := ""


func _ready() -> void:
	var c := ConfigFile.new()
	if c.load(FILE) == OK:
		schermo_intero = c.get_value("schermo", "intero", schermo_intero)
		qualita = c.get_value("schermo", "qualita", qualita)
		volume = c.get_value("audio", "volume", volume)
		sensibilita = c.get_value("comandi", "sensibilita", sensibilita)
		numeri_danno = c.get_value("comandi", "numeri_danno", numeri_danno)
		server = c.get_value("accesso", "server", server)
		utente = c.get_value("accesso", "utente", utente)
	applica.call_deferred()


func salva() -> void:
	var c := ConfigFile.new()
	c.set_value("schermo", "intero", schermo_intero)
	c.set_value("schermo", "qualita", qualita)
	c.set_value("audio", "volume", volume)
	c.set_value("comandi", "sensibilita", sensibilita)
	c.set_value("comandi", "numeri_danno", numeri_danno)
	c.set_value("accesso", "server", server)
	c.set_value("accesso", "utente", utente)
	c.save(FILE)


## Applica schermo, qualità e volume. La qualità tocca ombre, antialiasing e risoluzione interna.
func applica() -> void:
	if DisplayServer.get_name() != "headless":
		var modo := DisplayServer.WINDOW_MODE_FULLSCREEN if schermo_intero else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != modo and not OS.has_feature("movie"):
			DisplayServer.window_set_mode(modo)
	var vp := get_viewport()
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(qualita, 0, 2)]
	vp.scaling_3d_scale = [0.75, 1.0, 1.0][clampi(qualita, 0, 2)]
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 4096][clampi(qualita, 0, 2)], true)
	var sole: DirectionalLight3D = get_tree().current_scene.get_node_or_null("Sole") if get_tree().current_scene != null else null
	if sole != null:
		sole.directional_shadow_max_distance = [70.0, 120.0, 160.0][clampi(qualita, 0, 2)]
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.001)
