extends Node3D
## Anteprima delle Prove del Sigillo senza server: costruisce la pianta come nel gioco (Cripta.crea) e la fotografa.
##   godot --path godot res://scene/anteprima_prova.tscn --fixed-fps 30 -- --prova=cripta|forgia [--var=0]
##         [--porte=sigilli:1,ponte:1] [--rit=sigilli] [--tes=1] --cartella=/percorso
##         [--viste=nome:x,y,z:tx,ty,tz;nome2:…]   visuali (coordinate locali della Prova: occhio e punto guardato)
##         [--alto=1]                               vista dall'alto di tutta la pianta (senza nebbia) → pianta_alto.png
##         [--mappa=1]                              la mappa della Prova come nel gioco (tasto M) → pianta_mappa.png
##         [--omino=x,z]                            una sagoma alta 1,8 m per la scala
##         [--stat=1]                               stampa disegni e triangoli di ogni visuale
##         [--conta=1]                              triangoli di tutta la Prova per famiglia (MultiMesh, stanze, pavimenti)
##         [--senza=0,2] [--grigio=1] [--buio=1]    spegne luci finte di un tipo, shader dei pavimenti, luci vere

var _arg := {}
var _cripta: Cripta
var _cam: Camera3D
var _env: Environment


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			_arg[kv[0]] = kv[1]
	var id := String(_arg.get("prova", "cripta"))
	var stato := {"v": int(_arg.get("var", "0")), "porte": {}, "rit": String(_arg.get("rit", "")), "tes": int(_arg.get("tes", "0"))}
	for voce in String(_arg.get("porte", "")).split(",", false):
		var kv := voce.split(":")
		stato.porte[kv[0]] = int(kv[1]) if kv.size() > 1 else 1
	var t0 := Time.get_ticks_msec()
	_cripta = Cripta.crea(0.0, 0.0, id, stato)
	add_child(_cripta)
	print("costruita in %d ms" % (Time.get_ticks_msec() - t0))
	var we := WorldEnvironment.new()
	_env = Cripta.ambiente(id)
	we.environment = _env
	add_child(we)
	_cam = Camera3D.new()
	_cam.fov = 60.0
	_cam.far = 400.0
	add_child(_cam)
	_cam.current = true
	if _arg.has("omino"):
		var p := String(_arg.omino).split(",")
		var o := MeshInstance3D.new()
		var c := CapsuleMesh.new()
		c.radius = 0.32
		c.height = 1.8
		o.mesh = c
		o.material_override = Edifici.mat(Color(0.75, 0.2, 0.15), 0.8)
		o.position = Vector3(float(p[0]), 0.9, float(p[1]))
		add_child(o)
	# --senza=0,2,3: nasconde le luci finte di quel tipo (0 fiamme, 1 aloni, 2 fasci, 3 nebbia), per capire chi disegna cosa
	for tolto in String(_arg.get("senza", "")).split(",", false):
		for n in _cripta.get_children():
			if n is MultiMeshInstance3D and (n as MultiMeshInstance3D).material_override is ShaderMaterial:
				var m := (n as MultiMeshInstance3D).material_override as ShaderMaterial
				if m.shader.resource_path.ends_with("prova_luce.gdshader") and int(m.get_shader_parameter("tipo")) == int(tolto):
					n.visible = false
	if _arg.has("grigio"):       # pavimenti con un materiale qualunque (per capire se un difetto viene dallo shader)
		for n in _cripta.get_children():
			if n is MeshInstance3D and (n as MeshInstance3D).material_override == _cripta._mat.pav:
				(n as MeshInstance3D).material_override = Edifici.mat(Color(0.4, 0.38, 0.42), 0.9)
	if _arg.has("buio"):         # senza luci vere
		_cripta.set_process(false)
		for l in _cripta._luci:
			(l as OmniLight3D).visible = false
	if _arg.has("conta"):        # triangoli per famiglia: luci finte in MultiMesh, stanze fuse, pavimenti, parti mobili
		var conto := {}
		for n in _cripta.find_children("*", "GeometryInstance3D", true, false):
			var tri := 0
			var chi := "altro"
			if n is MultiMeshInstance3D:
				var mm := (n as MultiMeshInstance3D).multimesh
				tri = mm.instance_count * _triangoli(mm.mesh)
				chi = "multimesh " + (((n as MultiMeshInstance3D).material_override as ShaderMaterial).shader.resource_path.get_file() if (n as MultiMeshInstance3D).material_override is ShaderMaterial else "fili")
			elif n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
				tri = _triangoli((n as MeshInstance3D).mesh)
				chi = "stanze fuse" if n.name.begins_with("Fuso") else ("pavimenti" if (n as MeshInstance3D).material_override == _cripta._mat.pav else "parti sciolte")
			conto[chi] = int(conto.get(chi, 0)) + tri
		print("TRIANGOLI ", conto)
	_gira.call_deferred()


func _triangoli(m: Mesh) -> int:
	var t := 0
	for i in range(m.get_surface_count()):
		var a := m.surface_get_arrays(i)
		t += ((a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() if a[Mesh.ARRAY_INDEX] != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return t


func _foto(nome: String) -> void:
	for i in range(int(_arg.get("fotogrammi", "8"))):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if _arg.has("stat"):
		print("STAT %s: %d disegni, %d triangoli" % [nome, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])
	get_viewport().get_texture().get_image().save_png(String(_arg.get("cartella", "user://")).path_join(nome + ".png"))
	print("foto: ", nome)


func _gira() -> void:
	for voce in String(_arg.get("viste", "")).split(";", false):
		var p := voce.split(":")
		var a := p[1].split(",")
		var b := p[2].split(",")
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		_cam.position = Vector3(float(a[0]), float(a[1]), float(a[2]))
		_cam.look_at(Vector3(float(b[0]), float(b[1]), float(b[2])))
		await _foto(p[0])
	if _arg.has("alto"):
		var b1: Array = _cripta.composta.boundsMin
		var b2: Array = _cripta.composta.boundsMax
		var cx := (float(b1[0]) + float(b2[0])) * 0.5
		var cz := (float(b1[1]) + float(b2[1])) * 0.5
		_env.fog_enabled = false
		_env.ambient_light_energy = 3.2
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		var vp := get_viewport().get_visible_rect().size
		_cam.size = maxf(float(b2[1]) - float(b1[1]) + 6.0, (float(b2[0]) - float(b1[0]) + 6.0) * vp.y / vp.x)
		_cam.position = Vector3(cx, 120.0, cz)
		_cam.rotation = Vector3(-PI * 0.5, PI, 0)      # nord (il boss) in alto, come sulla mappa
		for n in _cripta.get_children():
			if n is GeometryInstance3D:
				(n as GeometryInstance3D).visibility_range_end = 0.0
			for m in n.get_children():
				if m is GeometryInstance3D:
					(m as GeometryInstance3D).visibility_range_end = 0.0
		await _foto("pianta_alto")
	if _arg.has("mappa"):
		var strato := CanvasLayer.new()
		add_child(strato)
		var foglio := Control.new()
		foglio.set_anchors_preset(Control.PRESET_FULL_RECT)
		strato.add_child(foglio)
		foglio.draw.connect(func() -> void:
			var area := foglio.get_rect()
			foglio.draw_rect(area, Color(0.05, 0.05, 0.07))
			var sp: Array = _cripta.composta.spawn
			_cripta.disegna_pianta(foglio, Rect2(40, 40, area.size.x - 460, area.size.y - 80), Vector3(float(sp[0]), 0, float(sp[1])), PI, true, 0.0))
		foglio.queue_redraw()
		await _foto("pianta_mappa")
	print("anteprima finita")
	get_tree().quit()
