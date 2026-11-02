extends Node3D
## Khởi động game, nối các hệ thống và chạy vòng lặp chính.

var level: Level
var trash: Trash
var machines: Machines
var player: Player
var quests: Quests
var hud: Hud
var ui: Panels
var running := false
var dev_markers := false

var _clock := 0.0
var _grow_start := -1.0
var _need_before := false
var _autosave := 0.0
var _shot: SubViewport
var _shot_cam: Camera3D


func _ready() -> void:
	level = Level.new()
	add_child(level)
	level.build()
	trash = Trash.new()
	add_child(trash)
	trash.build()
	machines = Machines.new()
	machines.main = self
	machines.trash = trash
	add_child(machines)
	machines.build()
	player = Player.new()
	player.trash = trash
	player.machines = machines
	add_child(player)
	quests = Quests.new()
	quests.trash = trash
	quests.machines = machines
	add_child(quests)

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.main = self
	layer.add_child(hud)
	ui = Panels.new()
	ui.main = self
	layer.add_child(ui)
	Game.toast.connect(hud.toast)
	Game.hint.connect(quests.hint)

	# Máy ảnh phụ chụp ảnh trước–sau cùng một góc cố định
	_shot = SubViewport.new()
	_shot.size = Vector2i(800, 450)
	_shot.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_shot_cam = Camera3D.new()
	_shot_cam.transform = level.photo_cam.transform
	_shot.add_child(_shot_cam)
	add_child(_shot)

	# Xem trước cảnh ở menu bằng ván đã lưu (hoặc ván mới, không lưu)
	Game.state = Game.load_game("main")
	if Game.state.is_empty():
		Game.state = Game.new_state("main", trash.items.size(), trash.flow_items.size())
	trash.restore()
	machines.update(0.0, 0.0, Vector3.ZERO)
	hud.visible = false
	level.photo_cam.current = true
	apply_settings()
	ui.menu()
	_make_thumbs()


## Ảnh thu nhỏ từng loại rác cho bàn phân loại, dựng từ chính mô hình 3D.
func _make_thumbs() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(96, 96)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.25
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(1.4, 1.5, 2.0), Vector3(0, 0.35, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	vp.add_child(light)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.85)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var mi := MeshInstance3D.new()
	vp.add_child(mi)
	add_child(vp)
	for t in Data.TRASH.size():
		var d: Dictionary = Data.TRASH[t]
		mi.mesh = Assets.mesh(d.model, d.get("parts", []), d.size)
		mi.scale = Vector3.ONE / d.size
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		if img and not img.is_empty():
			Style.thumbs[t] = ImageTexture.create_from_image(img)
	vp.queue_free()


func apply_settings() -> void:
	level.sun.shadow_enabled = Game.settings.shadows
	Sfx.set_volume(Game.settings.volume)


func resume() -> void:
	if running and not ui.is_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Bắt đầu hoặc tiếp tục một khe lưu.
func start(slot: String, fresh: bool) -> void:
	if fresh:
		Game.delete_save(slot)
	var s := {} if fresh else Game.load_game(slot)
	_need_before = s.is_empty()
	if s.is_empty():
		s = Game.new_state(slot, trash.items.size(), trash.flow_items.size())
	Game.state = s
	trash.restore()
	player.spawn()
	quests.reset()
	machines.build_mode = false
	machines.hooked = false
	machines.dev_speed = 1.0
	running = true
	_grow_start = -INF if s.accepted else -1.0
	hud.visible = true
	player.cam.current = true
	if _need_before:
		Game.show_hint("start")
	Game.save_game()
	resume()


func persist() -> void:
	if running:
		player.remember()
		Game.save_game()


## Chụp ảnh từ góc máy cố định vào khe lưu hiện tại.
func capture(which: String) -> void:
	var beam := quests.beam.visible
	quests.beam.visible = false
	_shot.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	quests.beam.visible = beam
	var img := _shot.get_texture().get_image()
	if img and not img.is_empty():
		img.save_png(Game.image_path(Game.state.slot, which))


## Nghiệm thu: chỉ bật khi đủ điều kiện, mở màn tiếp theo đúng một lần.
func accept() -> void:
	var s := Game.state
	if not quests.can_accept():
		return
	s.accepted = true
	s.quests.accept = true
	if s.slot != "replay":
		s.money += Data.ECON.accept_bonus_money
		s.mat += Data.ECON.accept_bonus_mat
		if not s.campaign.done.has(Data.LEVEL.id):
			s.campaign.done.append(Data.LEVEL.id)
		if not s.campaign.unlocked.has("lake"):
			s.campaign.unlocked.append("lake")
	player.remember()
	Game.save_game()
	Sfx.play("fanfare")
	Game.say("Nghiệm thu thành công! Bờ sông đang hồi sinh…", "good")
	_grow_start = _clock
	resume()
	await get_tree().create_timer(4.5).timeout
	await capture("after")
	ui.results()


# ---------- Chế độ phát triển (khe lưu riêng) ----------
func _enter_dev() -> void:
	var s := Game.state
	if s.slot != "dev":
		persist()
		Game.state = s.duplicate(true)
		Game.state.slot = "dev"
		Game.save_game()
		Game.say("Đã chuyển sang dữ liệu thử – tiến độ chính được giữ nguyên.")
	ui.dev()


func dev_money() -> void:
	Game.state.money += 1000
	Game.state.mat += 200
	Game.save_game()


func dev_tools() -> void:
	for k in Game.state.tools:
		Game.state.tools[k] = true
	Game.save_game()


func dev_speed() -> void:
	machines.dev_speed = 5.0 if machines.dev_speed == 1.0 else 1.0


func dev_toggle_markers() -> void:
	dev_markers = not dev_markers
	trash.show_markers(dev_markers)


func dev_tp(id: String) -> void:
	var c := Quests.zone_center(id)
	player.teleport(c.x, c.y)


# ---------- Sự kiện ----------
func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if e.keycode == KEY_ESCAPE:
		if ui.is_open and ui.current != "menu":
			if running:
				ui.close()
			else:
				ui.menu()
		elif ui.current == "menu" and running:
			ui.close()
		elif running and not ui.is_open:
			ui.menu()
		get_viewport().set_input_as_handled()
	elif running and e.is_action("menu"):
		if ui.current == "tab":
			ui.close()
		elif not ui.is_open:
			ui.tab("quests")
		get_viewport().set_input_as_handled()
	elif running and e.is_action("dev") and not ui.is_open:
		_enter_dev()


func _unhandled_input(e: InputEvent) -> void:
	# Nhấp vào cảnh để bắt lại chuột (sau khi chuyển cửa sổ)
	if running and not ui.is_open and e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		resume()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		persist()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		persist()
		if running and not ui.is_open:
			ui.menu()


# ---------- Vòng lặp ----------
func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	_clock += delta
	var s := Game.state
	if running:
		s.time += delta
		player.active = not ui.is_open and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		player.update(delta)
		trash.update(delta, _clock)
		machines.update(delta, _clock, player.cam.position)
		var hint := quests.update(delta, player.pos)
		var grow := clampf((_clock - _grow_start) / 4.0, 0.0, 1.0) if s.accepted else 0.0
		level.update_look(delta, trash.ratio, s.plant.progress, grow, _clock)
		hud.update(hint)
		if _need_before:
			_need_before = false
			capture("before")
		_autosave += delta
		if _autosave > Data.ECON.autosave:
			_autosave = 0.0
			persist()
	else:
		# Nền menu: góc máy chụp trước–sau, lia chậm
		var cam := level.photo_cam
		cam.position.x = -16.0 + sin(_clock * 0.1) * 6.0
		trash.update(delta, _clock)
		level.update_look(delta, trash.ratio, s.plant.progress, 1.0 if s.accepted else 0.0, _clock)
