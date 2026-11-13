extends Node
## Connessione WebSocket con il server di gioco (server/index.js): messaggi JSON con il campo `t`.

signal aperta
signal chiusa
signal messaggio(m: Dictionary)

var ws: WebSocketPeer = null
var _aperta := false
var _gestori: Dictionary = {}   # t → Array[Callable]


func connetti(indirizzo: String) -> void:
	var url := indirizzo.strip_edges()
	if not url.begins_with("ws"):
		url = "ws://" + url
	if not url.ends_with("/ws"):
		url = url.trim_suffix("/") + "/ws"
	ws = WebSocketPeer.new()
	_aperta = false
	var err := ws.connect_to_url(url)
	if err != OK:
		ws = null
		chiusa.emit()


## Registra una funzione per un tipo di messaggio.
func su(t: String, f: Callable) -> void:
	if not _gestori.has(t):
		_gestori[t] = []
	_gestori[t].append(f)


func togli_gestori() -> void:
	_gestori.clear()


func manda(m: Dictionary) -> void:
	if ws != null and _aperta:
		ws.send_text(JSON.stringify(m))


func _process(_dt: float) -> void:
	if ws == null:
		return
	ws.poll()
	var stato := ws.get_ready_state()
	if stato == WebSocketPeer.STATE_OPEN:
		if not _aperta:
			_aperta = true
			aperta.emit()
		while ws.get_available_packet_count() > 0:
			var m = JSON.parse_string(ws.get_packet().get_string_from_utf8())
			if m is Dictionary and m.has("t"):
				messaggio.emit(m)
				for f in _gestori.get(m.t, []):
					f.call(m)
	elif stato == WebSocketPeer.STATE_CLOSED:
		ws = null
		_aperta = false
		chiusa.emit()
