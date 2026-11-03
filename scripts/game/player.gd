class_name Player
extends Node3D
## Người chơi góc nhìn thứ nhất: di chuyển, va chạm, dùng dụng cụ, tương tác và chế độ đặt máy.

const EYE := 1.6
const RADIUS := 0.25
const WALK := 4.0
const SPRINT := 6.5
const ACCEL := 24.0 # m/s² – tăng tốc và dừng mềm, tránh giật hình gây chóng mặt
const BOB_AMP := 0.012

var trash: Trash
var machines: Machines
var cam: Camera3D
var active := false
var pos := Vector3.ZERO # chân người chơi (y không dùng)
var dir := Vector3.FORWARD
var yaw := 0.0
var pitch := 0.0
## Thông tin tâm ngắm cho HUD.
var aim := {"text": "", "far": false, "interact": "", "build": {}}

var _eye := EYE
var _bob := 0.0
var _bob_amp := 0.0
var _vel := Vector2.ZERO
var _step_dist := 0.0
var _swing := 0.0
var _use_timer := 0.0
var _full_warn := -10.0
var _look := Vector2.ZERO
var _wheel := 0
var _click := false
var _hand_point := Vector3.ZERO
var _held := {} # dụng cụ cầm tay: tên → Node3D


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = Game.settings.fov
	cam.near = 0.05
	cam.far = 500.0
	add_child(cam)
	_build_held()


func _unhandled_input(e: InputEvent) -> void:
	if not active:
		return
	if e is InputEventMouseMotion:
		_look += e.screen_relative # không phụ thuộc tỉ lệ cửa sổ
	elif e is InputEventMouseButton and e.pressed:
		match e.button_index:
			MOUSE_BUTTON_WHEEL_UP: _wheel -= 1
			MOUSE_BUTTON_WHEEL_DOWN: _wheel += 1
			MOUSE_BUTTON_LEFT: _click = true


# ---------- Dụng cụ cầm tay ----------
func _build_held() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.38, 0.2)
	wood.roughness = 0.8
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.7, 0.72, 0.75)
	steel.metallic = 0.9
	steel.roughness = 0.3
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_color = Color(0.15, 0.5, 0.45, 0.55)
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	for k in ["net", "hook"]:
		var root := Node3D.new()
		root.position = Vector3(0.36, -0.42, -0.5)
		root.rotation = Vector3(0.2, 0.18, 0)
		var pole := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.014; pm.bottom_radius = 0.018; pm.height = 1.1
		pole.mesh = pm
		pole.material_override = wood
		pole.rotation.x = PI / 2
		pole.position.z = -0.35
		root.add_child(pole)
		var head := MeshInstance3D.new()
		var tm := TorusMesh.new()
		if k == "net":
			tm.inner_radius = 0.17; tm.outer_radius = 0.19
			var disc := MeshInstance3D.new()
			var dm := CylinderMesh.new()
			dm.top_radius = 0.17; dm.bottom_radius = 0.1; dm.height = 0.14
			disc.mesh = dm
			disc.material_override = mesh_mat
			disc.position = Vector3(0, -0.07, -1.08)
			root.add_child(disc)
			head.position = Vector3(0, 0, -1.08)
		else:
			tm.inner_radius = 0.06; tm.outer_radius = 0.085
			head.rotation.z = PI / 2
			head.position = Vector3(0, -0.05, -0.95)
		head.mesh = tm
		head.material_override = steel
		root.add_child(head)
		for m in root.get_children():
			(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.visible = false
		cam.add_child(root)
		_held[k] = root


# ---------- Trạng thái ----------
func spawn() -> void:
	var sp: Vector3 = Data.LEVEL.spawn
	pos = Vector3(sp.x, 0, sp.z)
	yaw = Data.LEVEL.spawn_yaw
	pitch = -0.15
	var p = Game.state.player
	if p is Dictionary:
		if not is_nan(Level.ground_at(p.x, p.z)):
			pos = Vector3(p.x, 0, p.z)
		yaw = p.yaw
		pitch = p.pitch
	_eye = _ground() + EYE
	_look = Vector2.ZERO
	_place_camera()


func teleport(x: float, z: float) -> void:
	pos = Vector3(x, 0, z)


func remember() -> void:
	Game.state.player = {"x": pos.x, "z": pos.z, "yaw": yaw, "pitch": pitch}


func _ground() -> float:
	var g := Level.ground_at(pos.x, pos.z)
	return 0.0 if is_nan(g) else g


func set_tool(id: String) -> void:
	var s := Game.state
	if not s.tools[id]:
		Game.say("Chưa có %s.%s" % [Data.TOOLS[id].name, " Mua trong cửa hàng (Tab)." if id == "net" else ""], "warn")
		return
	if s.tool != id:
		s.tool = id
		Sfx.play("ui")
		if id == "net":
			Game.show_hint("net")


# ---------- Di chuyển ----------
func _move(delta: float) -> bool:
	var f := Input.get_action_strength("forward") - Input.get_action_strength("back")
	var r := Input.get_action_strength("right") - Input.get_action_strength("left")
	if not active:
		f = 0.0
		r = 0.0
	var target := Vector2.ZERO
	if f != 0.0 or r != 0.0:
		var speed := (SPRINT if Input.is_action_pressed("sprint") else WALK) * (0.55 if machines.hooked else 1.0)
		target = Vector2(-sin(yaw) * f + cos(yaw) * r, -cos(yaw) * f - sin(yaw) * r).normalized() * speed
	_vel = _vel.move_toward(target, ACCEL * delta)
	if _vel.length_squared() < 0.0001:
		_vel = Vector2.ZERO
		return false
	var v := _vel * delta
	var start := Vector2(pos.x, pos.z)
	var here := _ground()
	var ok := func(x: float, z: float) -> bool:
		var g := Level.ground_at(x, z)
		return not is_nan(g) and g - here < 0.45
	if ok.call(pos.x + v.x + signf(v.x) * RADIUS, pos.z):
		pos.x += v.x
	else:
		_vel.x = 0.0
	if ok.call(pos.x, pos.z + v.y + signf(v.y) * RADIUS):
		pos.z += v.y
	else:
		_vel.y = 0.0
	for sd in machines.solids():
		var c: Vector2 = sd[0]
		var d := Vector2(pos.x, pos.z) - c
		var min_d: float = sd[1] + 0.3
		var l := d.length()
		if l < min_d and l > 0.001:
			var n := c + d / l * min_d
			if ok.call(n.x, n.y):
				pos.x = n.x
				pos.z = n.y
	# Tiếng bước chân nhẹ mỗi 0,7 m trên mặt đất
	_step_dist += start.distance_to(Vector2(pos.x, pos.z))
	if _step_dist > 0.7:
		_step_dist = 0.0
		Sfx.play("step", 0.12)
	return _vel.length() > 0.5


func _place_camera() -> void:
	var bob := sin(_bob) * _bob_amp if Game.settings.head_bob else 0.0
	cam.position = Vector3(pos.x, _eye + bob, pos.z)
	cam.basis = Basis.from_euler(Vector3(pitch, yaw, 0))
	dir = -cam.basis.z
	_hand_point = cam.position + dir * 0.5 + Vector3(0, -0.4, 0)


func _collect(i: int) -> void:
	var s := Game.state
	var it := trash.items[i]
	var t: Dictionary = Data.TRASH[it.type]
	if Game.basket_load() + Data.trash_vol(it.type) > Game.basket_cap():
		var now := Time.get_ticks_msec() / 1000.0
		if now - _full_warn > 1.5:
			_full_warn = now
			var d := roundi(Vector2(pos.x, pos.z).distance_to(Data.LEVEL.table))
			Game.say("Giỏ đầy! Về bàn phân loại ở khu C (cách %d m)%s." % [d, " hoặc phễu băng chuyền" if s.placed.conveyor else ""], "warn")
			Sfx.play("error")
			Game.show_hint("full")
		return
	if trash.collect(i, func(): return _hand_point):
		s.basket.append(it.type)
		Sfx.play("splash" if it.water else t.cat)
		_swing = 1.0
		if Game.basket_load() >= Game.basket_cap():
			Game.show_hint("full")


func update(delta: float) -> void:
	var s := Game.state
	var moving := false
	if active:
		var k: float = 0.0022 * Game.settings.sens
		yaw -= _look.x * k
		pitch = clampf(pitch - _look.y * k, -1.45, 1.45)
		if Input.is_action_just_pressed("tool1"): set_tool("hand")
		if Input.is_action_just_pressed("tool2"): set_tool("net")
		if Input.is_action_just_pressed("tool3"): set_tool("hook")
		if _wheel != 0:
			var owned := Data.TOOL_ORDER.filter(func(t): return s.tools[t])
			set_tool(owned[posmod(owned.find(s.tool) + signi(_wheel), owned.size())])
		if Input.is_action_just_pressed("build"):
			machines.build_mode = not machines.build_mode
			Sfx.play("ui")
			if machines.build_mode:
				Game.show_hint("build_mode")
	moving = _move(delta)
	_look = Vector2.ZERO
	_wheel = 0

	# Máy ảnh và dụng cụ cầm tay
	_eye = lerpf(_eye, _ground() + EYE, minf(1.0, delta * 8.0))
	# Nhún nhẹ theo bước, biên độ tăng giảm dần thay vì bật tắt đột ngột
	_bob += delta * _vel.length() * 1.9
	_bob_amp = move_toward(_bob_amp, BOB_AMP if moving else 0.0, delta * 0.05)
	cam.fov = Game.settings.fov
	_place_camera()
	_swing = maxf(0.0, _swing - delta * 4.0)
	for t in _held:
		var h: Node3D = _held[t]
		h.visible = s.tool == t and not machines.build_mode
		var sway := _bob_amp / BOB_AMP * 0.006
		h.position = Vector3(0.36 + sin(_bob * 0.5) * sway, -0.42 + absf(cos(_bob * 0.5)) * sway, -0.5)
		h.rotation.x = 0.2 - _swing * 0.5

	# Tâm ngắm
	var tool: Dictionary = Data.TOOLS[s.tool]
	var eye := cam.position
	aim.text = ""
	aim.far = false
	aim.build = {}
	var target := -1
	var gem := -1
	if machines.build_mode:
		aim.build = machines.build_target(eye, dir)
		aim.text = aim.build.label if not aim.build.is_empty() else "Nhắm vào khung lắp đặt"
	else:
		gem = trash.pick_gem(eye, dir, Data.TOOLS.net.reach)
		if gem >= 0:
			aim.text = "Đồ sưu tầm: " + Data.COLLECTIBLES[gem].name
		elif s.tool == "hook":
			if machines.hooked:
				aim.text = "Đang kéo – nhấp để thả"
			elif machines.aim_obstacle(eye, dir, tool.reach):
				aim.text = Data.LEVEL.obstacle_name + " – nhấp để móc"
		else:
			var any := trash.pick(eye, dir, Data.TOOLS.net.reach, tool.radius, s.tool == "hand")
			if any >= 0:
				var it := trash.items[any]
				var p := it.pos
				if it.water:
					p.y = Level.WATER_Y
				aim.text = Data.TRASH[it.type].name
				if eye.distance_to(p) > tool.reach:
					aim.far = true
					aim.text += " – ngoài tầm với" + (", cần vợt" if s.tool == "hand" else "")
				else:
					target = any

	# Dùng dụng cụ
	if active:
		_use_timer -= delta
		if _click and machines.build_mode:
			if not aim.build.is_empty():
				machines.apply_build(aim.build)
		elif _click and gem >= 0:
			trash.take_gem(gem)
			Sfx.play("collect")
			Game.say("Tìm thấy đồ sưu tầm: %s (%d/%d)" % [Data.COLLECTIBLES[gem].name, s.collectibles.size(), Data.COLLECTIBLES.size()], "good")
			Game.save_game()
		elif s.tool == "hook":
			if _click:
				_swing = 1.0
				machines.try_hook(eye, dir, tool.reach)
		elif target >= 0 and (_click or (tool.rate > 0.0 and Input.is_action_pressed("use") and _use_timer <= 0.0)):
			_collect(target)
			_use_timer = tool.rate
	_click = false

	# Điểm tương tác gần nhất trước mặt
	var best := {}
	var best_d := INF
	for it in machines.interactables:
		if not it.when.call():
			continue
		var d2: Vector2 = it.pos - Vector2(pos.x, pos.z)
		var d := d2.length()
		if d > it.r or d >= best_d:
			continue
		if d > 0.8 and (d2.x * dir.x + d2.y * dir.z) / d < 0.3:
			continue
		best = it
		best_d = d
	aim.interact = best.label.call() if not best.is_empty() and not machines.build_mode else ""
	if active and not best.is_empty() and not machines.build_mode and Input.is_action_just_pressed("interact"):
		best.act.call()
