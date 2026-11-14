extends Node
## Suoni del gioco, tutti generati da codice all'avvio (nessun file audio): colpi, fendenti, saette, magie, interfaccia.
## Uso: Suoni.suona("colpo") oppure Suoni.suona("fulmine", -4.0, 0.9) con volume in dB e intonazione.

const FREQ := 22050

var _campioni: Dictionary = {}
var _voci: Array = []
var _prossima := 0
var _ultimo: Dictionary = {}     # nome → millisecondi dell'ultima volta (per non sovrapporre dieci colpi identici)


func _ready() -> void:
	for i in range(12):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voci.append(p)
	# nome: [durata, funzione(t, durata) → ampiezza -1..1]
	_crea("colpo", 0.14, func(t: float, d: float) -> float: return (_rumore() * 0.7 + sin(t * 520.0) * 0.5) * _cala(t, d, 3.0))
	_crea("critico", 0.22, func(t: float, d: float) -> float: return (_rumore() * 0.6 + sin(t * 400.0) * 0.5 + sin(t * 2600.0) * 0.25 * _cala(t, d, 6.0)) * _cala(t, d, 2.5))
	_crea("subito", 0.16, func(t: float, d: float) -> float: return (_rumore() * 0.4 + sin(t * 300.0 - t * t * 900.0) * 0.7) * _cala(t, d, 2.5))
	_crea("fendente", 0.24, func(t: float, d: float) -> float: return _filtra(_rumore(), 0.25 + 0.6 * sin(PI * t / d)) * sin(PI * t / d) * 0.9)
	_crea("freccia", 0.18, func(t: float, d: float) -> float: return _filtra(_rumore(), 0.7) * sin(PI * t / d) * 0.6 + sin(t * (5200.0 - t * 14000.0)) * 0.12 * _cala(t, d, 2.0))
	_crea("fulmine", 0.9, func(t: float, d: float) -> float: return (_rumore() * (0.9 if t < 0.06 else 0.35) * _cala(t, d, 2.0) + sin(t * 380.0 + sin(t * 31.0) * 6.0) * 0.5 * _cala(t, d, 1.5)) * 0.9)
	_crea("terra", 0.7, func(t: float, d: float) -> float: return (sin(t * (440.0 - t * 380.0)) * 0.9 + _filtra(_rumore(), 0.08) * 0.8) * _cala(t, d, 2.0))
	_crea("magia", 0.45, func(t: float, d: float) -> float: return (sin(t * TAU * (500.0 + t * 900.0)) * 0.4 + sin(t * TAU * (750.0 + t * 1350.0)) * 0.25) * sin(PI * t / d))
	_crea("cura", 0.7, func(t: float, d: float) -> float: return (_nota(t, 0.0, 660.0) + _nota(t, 0.12, 880.0) + _nota(t, 0.24, 1320.0)) * 0.3)
	_crea("aura", 0.6, func(t: float, d: float) -> float: return (sin(t * TAU * (180.0 + t * 260.0)) * 0.5 + _filtra(_rumore(), 0.15) * 0.4) * sin(PI * t / d))
	_crea("suprema", 1.3, func(t: float, d: float) -> float: return (sin(t * TAU * (90.0 + t * 60.0)) * 0.6 + sin(t * TAU * (270.0 + t * 400.0)) * 0.3 * (t / d) + _filtra(_rumore(), 0.3) * 0.4 * (t / d)) * sin(PI * t / d))
	_crea("squilibrio", 0.5, func(t: float, d: float) -> float: return (_rumore() * 0.5 * _cala(t, d, 4.0) + sin(t * TAU * 1568.0) * 0.3 * _cala(t, d, 2.0) + sin(t * TAU * 2093.0) * 0.2 * _cala(t, d, 2.0)))
	_crea("livello", 1.0, func(t: float, _d: float) -> float: return (_nota(t, 0.0, 523.0) + _nota(t, 0.13, 659.0) + _nota(t, 0.26, 784.0) + _nota(t, 0.39, 1047.0)) * 0.3)
	_crea("clic", 0.05, func(t: float, d: float) -> float: return sin(t * TAU * 1100.0) * 0.4 * _cala(t, d, 2.0))
	_crea("errore", 0.16, func(t: float, d: float) -> float: return signf(sin(t * TAU * 150.0)) * 0.22 * _cala(t, d, 1.5))
	_crea("moneta", 0.25, func(t: float, d: float) -> float: return (sin(t * TAU * 2100.0) * 0.3 + sin(t * TAU * 3150.0) * 0.2) * _cala(t, d, 2.5))
	_crea("raccolta", 0.2, func(t: float, d: float) -> float: return sin(t * TAU * (600.0 + t * 1800.0)) * 0.35 * _cala(t, d, 1.5))
	_crea("morte", 0.9, func(t: float, d: float) -> float: return (sin(t * TAU * (220.0 - t * 150.0)) * 0.5 + sin(t * TAU * (110.0 - t * 60.0)) * 0.4) * _cala(t, d, 1.5))
	_crea("passo", 0.07, func(t: float, d: float) -> float: return _filtra(_rumore(), 0.12) * 0.7 * _cala(t, d, 2.0))


var _f := 0.0


func _rumore() -> float:
	return randf() * 2.0 - 1.0


## Passa-basso a un polo: k vicino a 0 = cupo, vicino a 1 = chiaro.
func _filtra(x: float, k: float) -> float:
	_f += (x - _f) * clampf(k, 0.01, 1.0)
	return _f


func _cala(t: float, d: float, forza: float) -> float:
	return pow(maxf(0.0, 1.0 - t / d), forza)


func _nota(t: float, inizio: float, hz: float) -> float:
	if t < inizio:
		return 0.0
	var u := t - inizio
	return sin(u * TAU * hz) * exp(-u * 6.0) * minf(1.0, u * 200.0)


func _crea(nome: String, durata: float, f: Callable) -> void:
	var n := int(durata * FREQ)
	var dati := PackedByteArray()
	dati.resize(n * 2)
	_f = 0.0
	for i in range(n):
		var t := float(i) / FREQ
		var v := clampf(float(f.call(t, durata)), -1.0, 1.0) * minf(1.0, i / 40.0)
		dati.encode_s16(i * 2, int(v * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = FREQ
	w.stereo = false
	w.data = dati
	_campioni[nome] = w


func suona(nome: String, volume_db := 0.0, intonazione := 1.0) -> void:
	if not _campioni.has(nome):
		return
	var ora := Time.get_ticks_msec()
	if ora - int(_ultimo.get(nome, -1000)) < 45:
		return
	_ultimo[nome] = ora
	var p: AudioStreamPlayer = _voci[_prossima]
	_prossima = (_prossima + 1) % _voci.size()
	p.stream = _campioni[nome]
	p.volume_db = volume_db - 4.0
	p.pitch_scale = intonazione * randf_range(0.95, 1.05)
	p.play()
