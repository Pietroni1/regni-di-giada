class_name Gioco
extends Node3D
## La partita: riceve lo stato dal server, muove il proprio personaggio, gestisce visuale, bersagli e tecniche.
## Il server resta autoritativo: qui si mandano intenzioni (`move`, `atk`, `skill`) e si mostra quello che risponde.

var mondo: Mondo
var hud: Hud
var fx: Effetti
var cam: Camera3D
var anello_bersaglio: MeshInstance3D

var mio_id := 0
var classe := "lama"
var regno := ""
var io: Dictionary = {}            # ultimo messaggio `me`
var inv: Dictionary = {}           # ultimo messaggio `inv`: { inv: [...], eq: {...} }
var ents: Dictionary = {}          # id → Entita
var me: Entita = null
var bersaglio: Entita = null
var pvp := false
var pvp_min := 1

var yaw := 0.0
var pitch := 0.42
var distanza := 13.0
var _trascina := false
var _dist_vista := 13.0

var intento: Dictionary = {}       # { tipo: "muovi" | "attacco" | "tecnica", ... }
var prossimo_attacco := 0.0
var ultimo_invio := 0.0
var inviata := Vector3.ZERO
var ricariche: Dictionary = {}     # id tecnica → { fine, durata } in millisecondi
var gcd_fine := 0.0
var gcd_durata := 1000.0
var lancio: Dictionary = {}
var stordito_fino := 0.0
var lento_fino := 0.0
var _fermo_immagine := 0.0
var cripta: Cripta = null
var prova: Dictionary = {}         # ultimo stato della Prova del Sigillo (messaggio `dg`)
var gruppo: Dictionary = {}        # ultimo messaggio `party`
var _amb_fuori: Environment = null
var _amb_cripta: Environment = null
var _dentro := false


func _ready() -> void:
	mondo = Mondo.new()
	add_child(mondo)
	fx = Effetti.new()
	add_child(fx)
	cam = Camera3D.new()
	cam.far = 900.0
	cam.fov = 60.0
	add_child(cam)
	cam.make_current()
	hud = Hud.new()
	hud.gioco = self
	add_child(hud)
	anello_bersaglio = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.92
	t.outer_radius = 1.0
	t.rings = 32
	t.ring_segments = 6
	anello_bersaglio.mesh = t
	anello_bersaglio.material_override = Edifici.mat(Color(1.0, 0.3, 0.2), 0.5, 0.0, 2.5)
	anello_bersaglio.scale = Vector3(1, 0.15, 1)
	anello_bersaglio.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	anello_bersaglio.visible = false
	add_child(anello_bersaglio)
	for t_msg in ["me", "r", "v", "fx", "cd", "cast", "castend", "pos", "dead", "sys", "chat", "notice", "err", "inv", "st", "gain", "kicked", "dg_start", "dg", "dg_end", "dg_reward", "party", "pinv"]:
		Rete.su(t_msg, Callable(self, "_su_" + t_msg))


## Primo messaggio dopo `play`: chi sono e dove.
func entra(m: Dictionary) -> void:
	mio_id = int(m.id)
	classe = String(m.cls)
	regno = String(m.kd)
	pvp = int(m.get("pvp", 0)) == 1
	pvp_min = int(m.get("pvpMin", 1))
	var info := {"id": m.id, "k": "p", "n": m.name, "cls": m.cls, "kd": m.kd, "sx": m.get("sx", "m"), "x": m.x, "z": m.z, "r": 0.0, "hp": 1, "mhp": 1}
	me = Entita.da_info(info, true)
	add_child(me)
	var c: Dictionary = Dati.costanti.CENTER
	yaw = atan2(me.x - float(c.x), me.z - float(c.z))
	me.r = yaw + PI
	hud.riga_chat("Benvenuto nei Regni di Giada. WASD per muoverti, tasto destro per girare la visuale, Tab per il bersaglio, 1-0 per le tecniche.", Hud.ORO)


func ora() -> float:
	return float(Time.get_ticks_msec())


func nome_zona() -> String:
	if me == null:
		return ""
	if me.x > float(Dati.costanti.DUNGEON_X):
		return String(Dati.gioco.DUNGEON.name)
	for kid in Dati.KINGDOMS:
		var v: Dictionary = Dati.KINGDOMS[kid].village
		if Vector2(me.x - float(v.x), me.z - float(v.z)).length() < float(Dati.costanti.SAFE_RADIUS):
			return String(Dati.KINGDOMS[kid].villageName)
	var c: Dictionary = Dati.costanti.CENTER
	if Vector2(me.x - float(c.x), me.z - float(c.z)).length() < 95.0:
		return "Altopiano delle Spade Spezzate"
	return "Terre di Confine"


# ------------------------------------------------------------------ messaggi dal server
func _su_me(m: Dictionary) -> void:
	io = m
	if me != null:
		me.hp = float(m.hp)
		me.mhp = float(m.mhp)
		me.lvl = int(m.lvl)
		var era := me.morto
		me.morto = int(m.get("dead", 0)) == 1
		if me.morto and not era:
			me.corpo.muori()
		elif era and not me.morto:
			me.corpo.rialza()
		var grado := 0
		if int(m.get("mounted", 0)) == 1 and m.get("horse") is Dictionary:
			var lv := int(m.horse.lvl)
			grado = 3 if lv >= 20 else (2 if lv >= 10 else 1)
		me.in_sella(grado)
		hud.aggiorna_io(io, me.nome)


func _su_r(m: Dictionary) -> void:
	for k in ["hp", "res", "pts", "sl", "su"]:
		if m.has(k):
			io[k] = m[k]
	if me != null:
		me.hp = float(io.get("hp", 0))
		hud.aggiorna_io(io, me.nome)


func _su_inv(m: Dictionary) -> void:
	inv = m
	if me == null:
		return
	hud.finestre.aggiorna()
	var eq: Dictionary = m.get("eq", {})
	var aspetto := {}
	for coppia in [["w", "weapon"], ["b", "body"], ["h", "head"], ["f", "feet"]]:
		var pezzo = eq.get(coppia[1])
		aspetto[coppia[0]] = pezzo.id if pezzo is Dictionary else null
	me.cambia_aspetto(aspetto)


func _su_v(m: Dictionary) -> void:
	for i in m.get("a", []):
		var id := int(i.id)
		if ents.has(id):
			(ents[id] as Entita).queue_free()
		var e := Entita.da_info(i)
		ents[id] = e
		add_child(e)
	for u in m.get("u", []):
		var e2: Entita = ents.get(int(u[0]))
		if e2 != null:
			e2.aggiorna(u)
	for id in m.get("r", []):
		var e3: Entita = ents.get(int(id))
		if e3 != null:
			if bersaglio == e3:
				bersaglio = null
			e3.queue_free()
			ents.erase(int(id))


func _ent(id) -> Entita:
	if id == null:
		return null
	if int(id) == mio_id:
		return me
	return ents.get(int(id))


func _su_fx(m: Dictionary) -> void:
	var s := _ent(m.get("s"))
	var d := _ent(m.get("d"))
	match String(m.get("k", "")):
		"hit":
			if d == null:
				return
			var v := int(m.get("v", 0))
			if int(m.get("miss", 0)) == 1:
				hud.numero(d.testa(), "schivato", Color(0.8, 0.8, 0.8), 0.8)
				return
			var critico := int(m.get("c", 0)) == 1
			var mio := s == me
			var colore := Color(1.0, 0.95, 0.8) if mio else Color(0.85, 0.85, 0.85)
			if d == me:
				colore = Color(1.0, 0.35, 0.3)
			elif critico:
				colore = Color(1.0, 0.8, 0.25)
			if int(m.get("dot", 0)) == 1:
				colore = Color(0.75, 0.9, 0.45) if mio else Color(0.7, 0.7, 0.7)
			if mio or d == me or v > 0:
				hud.numero(d.testa(), str(v) + ("!" if critico else ""), colore, 1.35 if critico else (0.8 if int(m.get("dot", 0)) == 1 else 1.0))
			if int(m.get("dot", 0)) != 1:
				fx.colpo(d, critico)
				if d.corpo != null and d != me:
					d.corpo.colpito()
				if s != null and s != me and String(m.get("sk", "")) == "auto" and s.corpo != null:
					s.guarda(d)
					s.corpo.attacca()
				if mio and critico:
					fx.scuoti(0.25)
		"auto":
			if s != null and s != me and s.corpo != null:
				s.corpo.attacca()
		"sk":
			if s == null:
				return
			var sk: Dictionary = Dati.SKILLS.get(String(m.get("sk", "")), {})
			if sk.is_empty():
				return
			if d != null and d != s:
				s.guarda(d)
			if s.corpo != null:
				if String(sk.get("fx", "")) in ["slash", "spin", "dash", "quake", "arrow", "rain"]:
					s.corpo.attacca()
				else:
					s.corpo.lancia()
			fx.tecnica(sk, s, d, m)
			if s == me:
				var forte: bool = String(sk.get("ruolo", "")) == "potente" or sk.get("sup", false)
				if forte:
					_fermo_immagine = 0.09 if not sk.get("sup", false) else 0.16
		"heal":
			if d != null and int(m.get("v", 0)) > 0 and int(m.get("q", 0)) != 1:
				hud.numero(d.testa(), "+" + str(int(m.v)), Color(0.4, 1.0, 0.5))
		"die":
			if d != null and d.corpo != null:
				d.corpo.muori()
				d.morto = true
				if d == bersaglio:
					get_tree().create_timer(0.8).timeout.connect(func() -> void:
						if bersaglio == d:
							bersaglio = null)
		"lvl":
			if s != null:
				fx.salita_livello(s)
		"stun":
			if d != null:
				fx.anello(d.global_position, Color(1.0, 1.0, 0.5), 1.5, 0.5)
		"post":
			if d != null:
				hud.numero(d.testa() + Vector3(0, 0.5, 0), "SQUILIBRATO", Color(1.0, 0.85, 0.3), 1.5)
				fx.anello(d.global_position, Color(1.0, 0.85, 0.3), 4.0, 0.6, 0.2)
				fx.scintille(d.petto(), Color(1.0, 0.85, 0.3), 30, 7.0, 0.6)
				fx.scuoti(0.5)
		"cast":
			if s != null and s != me and s.corpo != null:
				s.corpo.lancia()
		"slam":
			fx.anello(Dati.suolo(float(m.x), float(m.z)), Color(1.0, 0.25, 0.12), float(m.get("r", 5)), 0.6, 0.2, 1.0)
			fx.scuoti(0.5)
			if s != null and s.corpo != null:
				s.corpo.attacca()
		"warn":
			fx.anello(Dati.suolo(float(m.x), float(m.z)), Color(1.0, 0.2, 0.1), float(m.get("r", 4)), float(m.get("ms", 2000)) / 1000.0, 0.06, 1.0)
		"tp":
			if s != null:
				fx.colonna(s.global_position, Color(0.55, 0.82, 1.0), 1.2, 12.0, 1.0)
		"proc":
			if s == me:
				var b: Dictionary = Dati.BUFFS.get(String(m.get("b", "")), {})
				if b.has("name"):
					hud.avvisa(String(b.name))


func _su_cd(m: Dictionary) -> void:
	var t := ora()
	var ms := float(m.get("ms", 0))
	if ms > 0.0:
		ricariche[String(m.s)] = {"fine": t + ms, "durata": ms}
	var g := float(m.get("gcd", 0))
	if g > 0.0:
		gcd_fine = t + g
		gcd_durata = g


func _su_cast(m: Dictionary) -> void:
	var sk: Dictionary = Dati.SKILLS.get(String(m.get("s", "")), {})
	var ms := float(m.get("ms", 0))
	lancio = {"nome": sk.get("name", "In sella..."), "fine": ora() + ms, "durata": ms}
	var g := float(m.get("gcd", 0))
	if g > 0.0:
		gcd_fine = ora() + g
		gcd_durata = g
	if me != null and me.corpo != null:
		me.corpo.lancia()


func _su_castend(_m: Dictionary) -> void:
	lancio = {}


func _su_pos(m: Dictionary) -> void:
	if me == null:
		return
	me.x = float(m.x)
	me.z = float(m.z)
	if m.has("r"):
		me.r = float(m.r)
	inviata = Vector3(me.x, 0, me.z)
	intento = {}


func _su_dead(m: Dictionary) -> void:
	hud.riga_chat("Sei stato sconfitto da %s." % m.get("by", "?"), Color(1.0, 0.45, 0.4))


func _su_sys(m: Dictionary) -> void:
	hud.riga_chat(String(m.get("m", "")), Color(0.75, 0.85, 0.95))


func _su_notice(m: Dictionary) -> void:
	hud.avvisa(String(m.get("m", "")))
	hud.riga_chat(String(m.get("m", "")), Hud.ORO)


func _su_err(m: Dictionary) -> void:
	hud.avvisa(String(m.get("m", "")), true)


func _su_chat(m: Dictionary) -> void:
	var canali := {"say": Color(0.95, 0.95, 0.9), "shout": Color(1.0, 0.7, 0.4), "party": Color(0.5, 0.8, 1.0), "wh": Color(0.9, 0.6, 0.95)}
	hud.riga_chat("%s: %s" % [m.get("n", "?"), m.get("m", "")], canali.get(String(m.get("ch", "say")), Color.WHITE))


func _su_st(m: Dictionary) -> void:
	if m.has("stun"):
		stordito_fino = ora() + float(m.stun)
	if m.has("slow"):
		lento_fino = ora() + float(m.slow)


func _su_gain(m: Dictionary) -> void:
	if m.has("exp") and me != null:
		hud.numero(me.testa() + Vector3(0, 0.6, 0), "+%d esp" % int(m.exp), Color(0.75, 0.6, 1.0), 0.8)


func _su_dg_start(m: Dictionary) -> void:
	if cripta != null:
		cripta.queue_free()
	cripta = Cripta.crea(float(m.ox), float(m.oz))
	add_child(cripta)
	prova = {"kl": m.get("kl", 2), "affixes": m.get("affixes", [])}
	bersaglio = null
	intento = {}


func _su_dg(m: Dictionary) -> void:
	prova = m
	prova["ricevuto"] = ora()


func _su_dg_end(_m: Dictionary) -> void:
	prova = {}
	if cripta != null:
		cripta.queue_free()
		cripta = null


func _su_dg_reward(m: Dictionary) -> void:
	hud.riga_chat("Ricompense della Prova: " + ", ".join(PackedStringArray(m.get("got", []))), Hud.ORO)


func _su_party(m: Dictionary) -> void:
	gruppo = {} if int(m.get("none", 0)) == 1 else m


func _su_pinv(m: Dictionary) -> void:
	hud.invito(String(m.get("n", "?")))


## Dentro la cripta: buio, nebbia scura, niente sole. Fuori: l'ambiente della scena.
func _ambiente(dentro: bool) -> void:
	if dentro == _dentro:
		return
	_dentro = dentro
	var radice := get_tree().current_scene
	var we: WorldEnvironment = radice.get_node_or_null("Ambiente")
	var sole: DirectionalLight3D = radice.get_node_or_null("Sole")
	if we == null:
		return
	if _amb_fuori == null:
		_amb_fuori = we.environment
		_amb_cripta = Environment.new()
		_amb_cripta.background_mode = Environment.BG_COLOR
		_amb_cripta.background_color = Color(0.012, 0.012, 0.02)
		_amb_cripta.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_amb_cripta.ambient_light_color = Color(0.42, 0.42, 0.6)
		_amb_cripta.ambient_light_energy = 1.3
		_amb_cripta.tonemap_mode = Environment.TONE_MAPPER_ACES
		_amb_cripta.tonemap_white = 6.0
		_amb_cripta.glow_enabled = true
		_amb_cripta.glow_intensity = 0.9
		_amb_cripta.glow_hdr_threshold = 1.0
		_amb_cripta.fog_enabled = true
		_amb_cripta.fog_light_color = Color(0.05, 0.04, 0.08)
		_amb_cripta.fog_density = 0.009
		_amb_cripta.fog_sky_affect = 1.0
	we.environment = _amb_cripta if dentro else _amb_fuori
	if sole != null:
		sole.visible = not dentro
	mondo.visible = not dentro


func _su_kicked(m: Dictionary) -> void:
	hud.avvisa(String(m.get("m", "Disconnesso")), true)


# ------------------------------------------------------------------ bersagli e tecniche
func ostile(e: Entita) -> bool:
	if e == null or e == me:
		return false
	if e.tipo == "m":
		return e.hp > 0 and not e.morto
	if e.tipo == "p":
		return pvp and String(e.info.get("kd", "")) != regno and e.hp > 0 and int(io.get("lvl", 1)) >= pvp_min and e.lvl >= pvp_min
	return false


func ostile_vicino(salta: Entita = null) -> Entita:
	var meglio: Entita = null
	var md := 30.0
	for e: Entita in ents.values():
		if e == salta or not ostile(e):
			continue
		var d := Vector2(e.x - me.x, e.z - me.z).length()
		if d < md:
			md = d
			meglio = e
	return meglio


func prossimo_bersaglio() -> void:
	var lista: Array = []
	for e: Entita in ents.values():
		if ostile(e) and Vector2(e.x - me.x, e.z - me.z).length() < 30.0:
			lista.append(e)
	if lista.is_empty():
		return
	lista.sort_custom(func(a: Entita, b: Entita) -> bool: return Vector2(a.x - me.x, a.z - me.z).length() < Vector2(b.x - me.x, b.z - me.z).length())
	var i := lista.find(bersaglio)
	bersaglio = lista[(i + 1) % lista.size()]


func portata(sk: Dictionary) -> float:
	var r = sk.get("range")
	if r == null or (r is String and r == "weapon"):
		return float(io.get("range", 2.5))
	return float(r)


func livello_tecnica(sid: String) -> int:
	return int(io.get("sk", {}).get(sid, 0))


## Barra rapida in uso: in sella ci sono le tecniche a cavallo.
func barra() -> Array:
	if int(io.get("mounted", 0)) != 1:
		return io.get("qb", [])
	var b: Array = []
	for sid in Dati.gioco.MOUNT_SKILLS:
		b.append({"k": "s", "id": sid})
	return b


func usa_tasto(i: int) -> void:
	var qb: Array = barra()
	if i >= qb.size() or not (qb[i] is Dictionary):
		return
	if qb[i].get("k") == "s":
		usa_tecnica(String(qb[i].id))
	elif qb[i].get("k") == "i":
		var lista: Array = inv.get("inv", [])
		for j in range(lista.size()):
			if lista[j] is Dictionary and lista[j].id == qb[i].id:
				Rete.manda({"t": "use", "i": j})
				return
		hud.avvisa("Non ne hai più", true)


func usa_suprema() -> void:
	for sid in Dati.SKILLS:
		var sk: Dictionary = Dati.SKILLS[sid]
		if sk.get("sup", false) and String(sk.get("cls", "")) == classe:
			usa_tecnica(sid)
			return


func usa_tecnica(sid: String) -> void:
	var sk: Dictionary = Dati.SKILLS.get(sid, {})
	if sk.is_empty() or me == null or int(io.get("dead", 0)) == 1:
		return
	if int(io.get("mounted", 0)) == 1 and not sk.get("mount", false):
		hud.avvisa("Scendi da cavallo (R) per usare le tecniche della tua classe", true)
		return
	var tipo := String(sk.get("type", ""))
	var id_b = null
	if tipo in ["strike", "aoe_target", "debuff", "taunt"]:
		if not ostile(bersaglio):
			bersaglio = ostile_vicino()
		if bersaglio == null:
			hud.avvisa("Nessun bersaglio", true)
			return
		var d := Vector2(bersaglio.x - me.x, bersaglio.z - me.z).length() - bersaglio.raggio
		if d > portata(sk) - 0.25:
			intento = {"tipo": "tecnica", "id": bersaglio.id, "sid": sid}
			return
		me.guarda(bersaglio)
		id_b = bersaglio.id
		intento = {"tipo": "attacco", "id": bersaglio.id}
	elif bersaglio != null:
		id_b = bersaglio.id
	Rete.manda({"t": "skill", "s": sid, "id": id_b})


# ------------------------------------------------------------------ comandi
func _unhandled_input(ev: InputEvent) -> void:
	if me == null:
		return
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_RIGHT:
			_trascina = ev.pressed
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			distanza = maxf(4.0, distanza - 1.2)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			distanza = minf(32.0, distanza + 1.2)
		elif ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			_clic(ev.position)
	elif ev is InputEventMouseMotion and _trascina:
		yaw -= ev.relative.x * 0.006
		pitch = clampf(pitch + ev.relative.y * 0.005, 0.08, 1.35)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		if hud.chat_attiva():
			return
		var k: int = ev.physical_keycode
		if k >= KEY_0 and k <= KEY_9:
			usa_tasto((k - KEY_1 + 10) % 10)
		elif k == KEY_TAB:
			prossimo_bersaglio()
		elif k == KEY_V:
			usa_suprema()
		elif k == KEY_ENTER or k == KEY_KP_ENTER:
			hud.apri_chat()
			get_viewport().set_input_as_handled()
		elif k == KEY_ESCAPE:
			if not hud.finestre.chiudi_tutto():
				bersaglio = null
				intento = {}
		elif k == KEY_I:
			hud.finestre.apri_chiudi("inventario")
		elif k == KEY_C:
			hud.finestre.apri_chiudi("personaggio")
		elif k == KEY_K:
			hud.finestre.apri_chiudi("abilita")
		elif k == KEY_R:
			Rete.manda({"t": "mount"})
		elif k == KEY_Z:
			_raccogli()


func _clic(p: Vector2) -> void:
	# entità più vicina al puntatore sullo schermo
	var meglio: Entita = null
	var md := 60.0
	for e: Entita in ents.values():
		var c := e.petto()
		if cam.is_position_behind(c):
			continue
		var d := cam.unproject_position(c).distance_to(p)
		if d < md:
			md = d
			meglio = e
	if meglio != null:
		bersaglio = meglio
		if ostile(meglio):
			intento = {"tipo": "attacco", "id": meglio.id}
		elif meglio.tipo == "n":
			Rete.manda({"t": "npc", "id": meglio.id})
		elif meglio.tipo == "d":
			Rete.manda({"t": "pick", "id": meglio.id})
		return
	# altrimenti si cammina verso il punto del terreno
	var o := cam.project_ray_origin(p)
	var dir := cam.project_ray_normal(p)
	var t := 0.0
	while t < 200.0:
		var q := o + dir * t
		if q.y <= Dati.altezza(q.x, q.z):
			intento = {"tipo": "muovi", "x": q.x, "z": q.z}
			fx.anello(Dati.suolo(q.x, q.z), Color(1.0, 0.88, 0.55), 1.2, 0.4)
			return
		t += 0.5


func _raccogli() -> void:
	for e: Entita in ents.values():
		if e.tipo == "d" and Vector2(e.x - me.x, e.z - me.z).length() < 4.0:
			Rete.manda({"t": "pick", "id": e.id})


func _verso(x: float, z: float, ferma: float) -> Vector2:
	var d := Vector2(x - me.x, z - me.z)
	if d.length() <= ferma:
		return Vector2.ZERO
	return d.normalized()


func _segui_intento(t: float) -> Vector2:
	if intento.is_empty():
		return Vector2.ZERO
	if intento.tipo == "muovi":
		var dir := _verso(float(intento.x), float(intento.z), 0.4)
		if dir == Vector2.ZERO:
			intento = {}
		return dir
	var e: Entita = ents.get(int(intento.id))
	if e == null or not ostile(e):
		intento = {}
		return Vector2.ZERO
	if not lancio.is_empty():
		return Vector2.ZERO
	var d := Vector2(e.x - me.x, e.z - me.z).length() - e.raggio
	if intento.tipo == "attacco":
		if d > float(io.get("range", 2.5)) - 0.25:
			return _verso(e.x, e.z, 0.0)
		me.guarda(e)
		if t >= prossimo_attacco:
			Rete.manda({"t": "atk", "id": e.id})
			prossimo_attacco = t + float(io.get("aspd", 1000))
			me.corpo.attacca()
		return Vector2.ZERO
	if intento.tipo == "tecnica":
		var sk: Dictionary = Dati.SKILLS.get(String(intento.sid), {})
		if d > portata(sk) - 0.25:
			return _verso(e.x, e.z, 0.0)
		var sid := String(intento.sid)
		intento = {"tipo": "attacco", "id": e.id}
		usa_tecnica(sid)
	return Vector2.ZERO


func _process(dt: float) -> void:
	if me == null:
		return
	if _fermo_immagine > 0.0:
		_fermo_immagine -= dt / maxf(Engine.time_scale, 0.05)
		Engine.time_scale = 0.12 if _fermo_immagine > 0.0 else 1.0
	var t := ora()
	var dir := Vector2.ZERO
	var bloccato := int(io.get("dead", 0)) == 1 or stordito_fino > t
	if not bloccato:
		var avanti := 0.0
		var lato := 0.0
		if not hud.chat_attiva():
			avanti = float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
			lato = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
			if Input.is_physical_key_pressed(KEY_Q):
				yaw += dt * 2.2
			if Input.is_physical_key_pressed(KEY_E):
				yaw -= dt * 2.2
		if avanti != 0.0 or lato != 0.0:
			intento = {}
			dir = Vector2(-sin(yaw) * avanti + cos(yaw) * lato, -cos(yaw) * avanti - sin(yaw) * lato).normalized()
		else:
			dir = _segui_intento(t)
	var vel := float(io.get("spd", 6.0)) * (0.5 if lento_fino > t else 1.0)
	if dir != Vector2.ZERO:
		if not lancio.is_empty():
			Rete.manda({"t": "cancel"})
			lancio = {}
		var nx := me.x + dir.x * vel * dt
		var nz := me.z + dir.y * vel * dt
		if me.x > float(Dati.costanti.DUNGEON_X):
			# nella cripta si cammina solo in stanze e corridoi, scivolando lungo i muri
			if cripta != null and not cripta.calpestabile(nx, nz):
				if cripta.calpestabile(nx, me.z):
					nz = me.z
				elif cripta.calpestabile(me.x, nz):
					nx = me.x
				else:
					nx = me.x
					nz = me.z
		else:
			var u := Dati.risolvi_urti(nx, nz, 0.5)
			var lim := float(Dati.costanti.PLAY_LIMIT)
			nx = clampf(u.x, -lim, lim)
			nz = clampf(u.y, -lim, lim)
		me.velocita = Vector2(nx - me.x, nz - me.z).length() / maxf(dt, 1e-4)
		me.x = nx
		me.z = nz
		me.r = lerp_angle(me.r, atan2(dir.x, dir.y), minf(1.0, dt * 14.0))
	else:
		me.velocita = 0.0
	if t - ultimo_invio > 100.0:
		if Vector2(me.x - inviata.x, me.z - inviata.z).length() > 0.05 or absf(me.r - inviata.y) > 0.1:
			Rete.manda({"t": "move", "x": snappedf(me.x, 0.01), "z": snappedf(me.z, 0.01), "r": snappedf(me.r, 0.01)})
			inviata = Vector3(me.x, me.r, me.z)
		ultimo_invio = t
	_ambiente(me.x > float(Dati.costanti.DUNGEON_X))
	_visuale(dt)
	if bersaglio != null and is_instance_valid(bersaglio):
		anello_bersaglio.visible = true
		anello_bersaglio.position = bersaglio.global_position + Vector3(0, 0.12, 0)
		var s := bersaglio.raggio * 1.8 + 0.4
		anello_bersaglio.scale = Vector3(s, 0.15, s)
	else:
		bersaglio = null
		anello_bersaglio.visible = false


## Quanto può arretrare la visuale prima di entrare in un edificio (gli ostacoli a scatola del villaggio, alti ~8 m).
func _distanza_libera(centro: Vector3) -> float:
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var base := float(Dati.costanti.VILLAGE_HEIGHT)
	var t := 1.0
	while t < distanza:
		var q := centro + dir * t
		if q.y < base + 8.5:
			for o in Dati.gioco.ostacoli:
				if o.t != "box" or float(o.hd) < 2.0:
					continue
				var dx: float = q.x - o.x
				var dz: float = q.z - o.z
				if absf(dx) > 12.0 or absf(dz) > 12.0:
					continue
				var lx: float = dx * o.cos - dz * o.sin
				var lz: float = dx * o.sin + dz * o.cos
				if absf(lx) < o.hw + 1.6 and absf(lz) < o.hd + 1.6:
					return maxf(2.5, t - 0.6)
		t += 0.5
	return distanza


func _visuale(_dt: float) -> void:
	var centro := Vector3(me.x, Dati.altezza(me.x, me.z) + 1.7 + (1.0 if me.sella > 0 else 0.0), me.z)
	var libera := _distanza_libera(centro)
	if _dentro:
		# nella cripta la visuale non esce dai muri: si accorcia finché resta in una stanza
		libera = distanza
		var d := Vector3(sin(yaw) * cos(pitch), 0, cos(yaw) * cos(pitch))
		var t := 1.0
		while t < distanza and cripta != null:
			var q := centro + d * t
			if not cripta.calpestabile(q.x, q.z, -0.2):
				libera = maxf(3.5, t - 0.3)
				break
			t += 0.5
	_dist_vista = minf(libera, lerpf(_dist_vista, libera, minf(1.0, _dt * 6.0)))
	var orizz := cos(pitch) * _dist_vista
	var p := centro + Vector3(sin(yaw) * orizz, sin(pitch) * _dist_vista, cos(yaw) * orizz)
	var suolo := Dati.altezza(p.x, p.z) + 0.6
	if p.y < suolo:
		p.y = suolo
	if fx.tremore > 0.0:
		var f := fx.tremore * 0.35
		p += Vector3(randf_range(-f, f), randf_range(-f, f), randf_range(-f, f))
	cam.position = p
	cam.look_at(centro)
