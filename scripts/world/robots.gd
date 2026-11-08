class_name Robots
extends Node3D
## Robot gom rác: tự chạy trên bờ tìm rác gần nhất (kể cả trong đống, từ lớp trên xuống),
## đầy thì chạy về đổ vào phễu băng chuyền (hoặc bàn phân loại khi chưa có băng chuyền).

const BIN_POS := Vector3(0, 0.55, -0.05)

var trash: Trash
var dev_speed := 1.0

var _bots: Array[Dictionary] = [] # {node, fill, lamp, target, mode, timer, stuck}
var _skip := {} # món robot không tới được: chỉ số → thời điểm bỏ qua đến
var _body_mat: StandardMaterial3D
var _dark: StandardMaterial3D
var _lamp_mat: StandardMaterial3D


func _s() -> Dictionary:
	return Game.state


func build() -> void:
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.95, 0.72, 0.1)
	_body_mat.metallic = 0.3
	_body_mat.roughness = 0.45
	_dark = StandardMaterial3D.new()
	_dark.albedo_color = Color(0.12, 0.13, 0.14)
	_dark.roughness = 0.8
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = Color(0.3, 1.0, 0.6)
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color(0.3, 1.0, 0.6)


## Điểm đổ rác: trước phễu băng chuyền nếu đã lắp, không thì cạnh bàn phân loại.
func _dock() -> Vector2:
	if _s().placed.conveyor:
		return Data.LEVEL.slots.conveyor + Vector2(-2.55, 1.3)
	return Data.LEVEL.table + Vector2(0, 1.7)


func _make_bot() -> Dictionary:
	var n := Node3D.new()
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 0.3, 0.8)
	body.mesh = bm
	body.material_override = _body_mat
	body.position.y = 0.3
	n.add_child(body)
	var bin := MeshInstance3D.new()
	var binm := BoxMesh.new()
	binm.size = Vector3(0.5, 0.26, 0.5)
	bin.mesh = binm
	bin.material_override = _dark
	bin.position = Vector3(0, 0.58, -0.08)
	n.add_child(bin)
	var fill := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.42, 0.24, 0.42)
	fill.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.4, 0.33, 0.25)
	fill.material_override = fmat
	fill.position = Vector3(0, 0.6, -0.08)
	n.add_child(fill)
	for x in [-0.33, 0.33]:
		for z in [-0.28, 0.28]:
			var w := MeshInstance3D.new()
			var wm := CylinderMesh.new()
			wm.top_radius = 0.13; wm.bottom_radius = 0.13; wm.height = 0.1
			w.mesh = wm
			w.material_override = _dark
			w.rotation.z = PI / 2
			w.position = Vector3(x, 0.13, z)
			n.add_child(w)
	var lamp := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.05; lm.height = 0.1
	lamp.mesh = lm
	lamp.material_override = _lamp_mat
	lamp.position = Vector3(0, 0.5, 0.36)
	n.add_child(lamp)
	add_child(n)
	return {"node": n, "fill": fill, "target": -1, "mode": "seek", "timer": 0.0, "stuck": 0.0}


## Đồng bộ số robot với trạng thái (khi mua thêm hoặc tải ván).
func sync() -> void:
	var s := _s()
	while _bots.size() < s.robots.size():
		_bots.append(_make_bot())
	while _bots.size() > s.robots.size():
		_bots.pop_back().node.queue_free()
	for i in _bots.size():
		var b := _bots[i]
		b.target = -1
		b.mode = "unload" if s.robots[i].load.size() >= Data.ECON.robot_cap else "seek"
		b.node.position = Vector3(s.robots[i].x, _ground(s.robots[i].x, s.robots[i].z), s.robots[i].z)


func add_robot() -> void:
	var d := _dock()
	_s().robots.append({"x": d.x - _s().robots.size() * 0.9, "z": d.y, "load": []})
	sync()


static func _ground(x: float, z: float) -> float:
	var g := Level.ground_at(x, z)
	return 0.0 if is_nan(g) else g


## Điểm robot đứng để với tới món i (bờ dốc thì đứng ở mép lối đi).
func _approach(i: int) -> Vector2:
	var p := trash.items[i].pos
	if is_nan(Level.ground_at(p.x, p.z)):
		return Vector2(p.x, 8.3)
	return Vector2(p.x, p.z)


func _claimed(i: int) -> bool:
	for b in _bots:
		if b.target == i:
			return true
	return false


func _find_target(from: Vector2) -> int:
	var now := Time.get_ticks_msec()
	var best := -1
	var bd := INF
	for i in trash.items.size():
		var it := trash.items[i]
		if it.water or it.flow >= 0 or trash.is_hidden(i) or trash.covered(i):
			continue
		if it.area == "slope" and it.pos.z < 6.6: # quá xa mép lối đi
			continue
		if _skip.get(i, 0) > now or _claimed(i):
			continue
		var d := from.distance_squared_to(Vector2(it.pos.x, it.pos.z))
		if d < bd:
			bd = d
			best = i
	return best


## Chạy về phía goal; trả về true khi đã tới nơi.
func _drive(b: Dictionary, goal: Vector2, delta: float, stop := 0.3) -> bool:
	var n: Node3D = b.node
	var p := Vector2(n.position.x, n.position.z)
	var d := goal - p
	var dist := d.length()
	if dist <= stop:
		return true
	var step := minf(dist, Data.ECON.robot_speed * dev_speed * delta)
	var v := d / dist * step
	var moved := false
	for c in [p + v, p + Vector2(v.x, 0), p + Vector2(0, v.y)]:
		if not is_nan(Level.ground_at(c.x, c.y)):
			p = c
			moved = true
			break
	b.stuck = 0.0 if moved else b.stuck + delta
	n.position = Vector3(p.x, lerpf(n.position.y, _ground(p.x, p.y), minf(1.0, delta * 10.0)), p.y)
	n.rotation.y = lerp_angle(n.rotation.y, atan2(d.x, d.y), minf(1.0, delta * 8.0))
	return false


func update(delta: float, t: float) -> void:
	var s := _s()
	if _bots.size() != s.robots.size():
		sync()
	var cap: int = Data.ECON.robot_cap
	for i in _bots.size():
		var b := _bots[i]
		var r: Dictionary = s.robots[i]
		var n: Node3D = b.node
		b.timer -= delta
		match b.mode:
			"seek":
				if r.load.size() >= cap:
					b.mode = "unload"
				elif b.target < 0 or trash.is_hidden(b.target) or trash.covered(b.target):
					b.target = _find_target(Vector2(n.position.x, n.position.z))
					b.stuck = 0.0
					if b.target < 0 and not r.load.is_empty():
						b.mode = "unload"
				else:
					var it := trash.items[b.target]
					var reach: bool = Vector2(n.position.x, n.position.z).distance_to(Vector2(it.pos.x, it.pos.z)) <= Data.ECON.robot_reach
					if reach or _drive(b, _approach(b.target), delta, 0.4):
						if b.timer <= 0.0:
							var bin := n
							if trash.collect(b.target, func(): return bin.to_global(BIN_POS)):
								r.load.append(it.type)
								Sfx.play(Data.TRASH[it.type].cat, 0.1)
							b.target = -1
							b.timer = Data.ECON.robot_pick / dev_speed
					elif b.stuck > 1.5:
						_skip[b.target] = Time.get_ticks_msec() + 20000
						b.target = -1
			"unload":
				if _drive(b, _dock(), delta, 0.4) and b.timer <= 0.0:
					if r.load.is_empty():
						b.mode = "seek"
					elif s.placed.conveyor:
						if s.conveyor.hopper.size() < Data.ECON.belt_hopper:
							s.conveyor.hopper.append(r.load.pop_front())
							b.timer = 0.12 / dev_speed
					else:
						s.table.append_array(r.load)
						r.load = []
						Sfx.play("dump")
		r.x = n.position.x
		r.z = n.position.z
		var k: float = r.load.size() / float(cap)
		b.fill.visible = k > 0.01
		b.fill.scale.y = maxf(k, 0.01)
		b.fill.position.y = 0.48 + 0.12 * k
	_lamp_mat.emission_energy_multiplier = 1.0 + sin(t * 5.0) * 0.8


func carried() -> int:
	var n := 0
	for r in _s().robots:
		n += r.load.size()
	return n


## Dòng trạng thái cho HUD.
func status() -> String:
	var seeking := 0
	for b in _bots:
		if b.mode == "seek" and b.target >= 0:
			seeking += 1
	return "Robot gom rác · %d chiếc\nĐang gom: %d · đang mang %d món" % [_bots.size(), seeking, carried()]
