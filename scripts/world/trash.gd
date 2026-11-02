class_name Trash
extends Node3D
## Rác trong màn: sinh vị trí cố định theo hạt giống, vẽ bằng MultiMesh (mỗi loại một lần vẽ),
## chọn bằng tia ngắm, hiệu ứng bay về giỏ, bọt nước, bụi, ruồi trên đống rác,
## rác trôi hữu hạn từ cửa xả và đồ sưu tầm.

class Item:
	var type: int
	var zone: String
	var area: String
	var water: bool
	var pos: Vector3
	var yaw: float
	var flow := -1 # chỉ số trong state.flow nếu là rác trôi

var items: Array[Item] = []
var flow_items: Array[Item] = []
var zones := {}
var total_mass := 0
var collected_mass := 0

var _mm: Array[MultiMesh] = []
var _slot: Array[int] = [] # chỉ số instance trong MultiMesh của từng vật
var _anims: Array = [] # [item_index, t, from, target_callable]
var _gems: Array[Node3D] = []
var _markers: MultiMeshInstance3D
var _flies: CPUParticles3D
var _fx_splash: Array[CPUParticles3D] = []
var _fx_dust: Array[CPUParticles3D] = []
var _fx_i := 0

var ratio: float:
	get: return float(collected_mass) / total_mass


func build() -> void:
	_generate()
	var counts := []
	counts.resize(Data.TRASH.size())
	counts.fill(0)
	for it in items:
		_slot.append(counts[it.type])
		counts[it.type] += 1
	for t in Data.TRASH.size():
		var d: Dictionary = Data.TRASH[t]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = Assets.mesh(d.model, d.get("parts", []), d.size)
		mm.instance_count = counts[t]
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mmi)
		_mm.append(mm)
	for it in items:
		total_mass += Data.trash_mass(it.type)
		if not zones.has(it.zone):
			zones[it.zone] = {"total": 0, "done": 0}
		zones[it.zone].total += 1

	# Đồ sưu tầm: lấp lánh, đếm riêng, không tính tiến độ
	for c in Data.COLLECTIBLES:
		var g := Node3D.new()
		var m := MeshInstance3D.new()
		m.mesh = Assets.mesh(c.model, [], 0.3)
		g.add_child(m)
		var light := OmniLight3D.new()
		light.light_color = Color(1, 0.85, 0.4)
		light.light_energy = 0.8
		light.omni_range = 1.2
		light.position.y = 0.3
		g.add_child(light)
		g.add_child(_sparkle())
		g.position = c.pos + Vector3(0, 0.02, 0)
		add_child(g)
		_gems.append(g)

	# Đánh dấu rác còn sót (chế độ phát triển)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.04; cyl.bottom_radius = 0.04; cyl.height = 3.0
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.albedo_color = Color(1, 0.2, 0.3)
	cyl.material = red
	mm.mesh = cyl
	mm.instance_count = items.size()
	_markers = MultiMeshInstance3D.new()
	_markers.multimesh = mm
	_markers.visible = false
	add_child(_markers)

	# Ruồi bay quanh đống rác cửa xả: tắt khi đống rác được dọn
	_flies = CPUParticles3D.new()
	_flies.amount = 40
	_flies.lifetime = 3.0
	_flies.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_flies.emission_sphere_radius = 2.0
	_flies.gravity = Vector3.ZERO
	_flies.initial_velocity_min = 0.5; _flies.initial_velocity_max = 1.5
	_flies.spread = 180
	_flies.direction = Vector3.UP
	var q := SphereMesh.new()
	q.radius = 0.015; q.height = 0.03
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.05, 0.05, 0.05)
	q.material = fm
	_flies.mesh = q
	_flies.position = Vector3(Data.LEVEL.obstacle.x, 0.2, Data.LEVEL.obstacle.y)
	add_child(_flies)

	for i in 6:
		_fx_splash.append(_burst(Color(0.85, 0.95, 1.0, 0.9), 24, 3.0, -9.0))
		_fx_dust.append(_burst(Color(0.55, 0.48, 0.38, 0.6), 14, 1.0, -1.5))


func _burst(color: Color, amount: int, speed: float, grav: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.8
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 45
	p.initial_velocity_min = speed * 0.5; p.initial_velocity_max = speed
	p.gravity = Vector3(0, grav, 0)
	p.scale_amount_min = 0.5; p.scale_amount_max = 1.2
	var m := SphereMesh.new()
	m.radius = 0.035; m.height = 0.07
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.1
	m.material = mat
	p.mesh = m
	add_child(p)
	return p


func _sparkle() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 8
	p.lifetime = 1.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.gravity = Vector3(0, 0.3, 0)
	p.initial_velocity_max = 0.1
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(1, 0.9, 0.5)
	m.emission_enabled = true
	m.emission = Color(1, 0.85, 0.3)
	q.material = m
	p.mesh = q
	p.position.y = 0.2
	return p


## Hiệu ứng tại chỗ nhặt: bọt nước hoặc bụi.
func puff(pos: Vector3, water: bool) -> void:
	var p := (_fx_splash if water else _fx_dust)[_fx_i % 6]
	_fx_i += 1
	p.position = pos
	p.restart()
	p.emitting = true


# ---------- Sinh rác ----------
func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var float_types := []
	for i in Data.TRASH.size():
		if Data.TRASH[i].float:
			float_types.append(i)
	var keep_out := [Data.LEVEL.table, Data.LEVEL.receive] + Data.LEVEL.slots.values()
	var obs: Vector2 = Data.LEVEL.obstacle
	var out: Vector2 = Data.LEVEL.outfall
	var flow_i := 0
	for g in Data.TRASH_GROUPS:
		for k in g.n:
			var water: bool = g.area == "water" or g.area == "flow"
			var type: int = float_types[rng.randi() % float_types.size()] if water else rng.randi() % Data.TRASH.size()
			var x := 0.0
			var z := 0.0
			for tries in 20:
				match g.area:
					"walk":
						x = rng.randf_range(g.x.x, g.x.y); z = rng.randf_range(8.5, 14.6)
					"steps":
						x = rng.randf_range(g.x.x, g.x.y); z = rng.randf_range(4.2, 7.8)
					"slope":
						x = rng.randf_range(g.x.x, g.x.y); z = rng.randf_range(6.3, 7.7)
					"water":
						x = rng.randf_range(g.x.x, g.x.y); z = rng.randf_range(g.z.x, g.z.y)
					"pile":
						var a := rng.randf() * TAU
						var r := 0.75 + sqrt(rng.randf()) * 1.3
						x = obs.x + cos(a) * r * 1.7
						z = clampf(obs.y + sin(a) * r, 4.15, 7.8)
					_:
						x = out.x; z = out.y
				var blocked := false
				if g.area == "walk":
					for p in keep_out:
						if Vector2(x, z).distance_to(p) < 2.6:
							blocked = true
				elif g.area == "water":
					blocked = x > Level.DOCK.x0 - 0.8 and x < Level.DOCK.x1 + 0.8
				if not blocked:
					break
			var it := Item.new()
			it.type = type
			it.zone = g.zone
			it.area = g.area
			it.water = water
			it.pos = Vector3(x, 0, z)
			it.yaw = rng.randf() * TAU
			if g.area == "flow":
				it.flow = flow_i
				flow_i += 1
				flow_items.append(it)
			items.append(it)


# ---------- Trạng thái ----------
func is_hidden(i: int) -> bool:
	var it := items[i]
	return Game.state.items[i] == 1 or (it.flow >= 0 and Game.state.flow[it.flow].x == 0)


func _write(i: int, scale := 1.0, t := 0.0) -> void:
	var it := items[i]
	var y := it.pos.y
	var tilt := 0.0
	if it.water:
		y = Level.WATER_Y - 0.06
		if t > 0.0:
			y += sin(t * 1.6 + it.yaw * 5.0) * 0.03
			tilt = sin(t * 1.2 + it.yaw * 3.0) * 0.12
	var b := Basis.from_euler(Vector3(tilt, it.yaw, tilt * 0.5)).scaled(Vector3.ONE * scale)
	_mm[it.type].set_instance_transform(_slot[i], Transform3D(b, Vector3(it.pos.x, y, it.pos.z)))


## Áp trạng thái đã lưu lên cảnh (khi bắt đầu hoặc tải ván).
func restore() -> void:
	var s := Game.state
	collected_mass = 0
	_anims.clear()
	for z in zones.values():
		z.done = 0
	for i in items.size():
		var it := items[i]
		if it.flow >= 0:
			var f: Vector3 = s.flow[it.flow]
			it.pos = Vector3(f.y, 0, f.z) if f.x > 0 else Vector3(Data.LEVEL.outfall.x, 0, Data.LEVEL.outfall.y)
		it.pos.y = Level.WATER_Y if it.water else Level.surface_y(it.pos.x, it.pos.z)
		if s.items[i] == 1:
			collected_mass += Data.trash_mass(it.type)
			zones[it.zone].done += 1
		_write(i, 0.0 if is_hidden(i) else 1.0)
	for i in _gems.size():
		_gems[i].visible = not s.collectibles.has(i)


## Vật gần tia ngắm nhất trong tầm với. prefer_near: ưu tiên vật gần (tay) hay gần tâm (vợt).
func pick(origin: Vector3, dir: Vector3, reach: float, radius: float, prefer_near: bool) -> int:
	var best := -1
	var best_score := INF
	for i in items.size():
		if is_hidden(i):
			continue
		var v := items[i].pos + Vector3(0, 0.12, 0) - origin
		var t := v.dot(dir)
		if t < 0.0 or t > reach:
			continue
		var perp2 := v.length_squared() - t * t
		if perp2 > radius * radius:
			continue
		var score := t if prefer_near else perp2
		if score < best_score:
			best_score = score
			best = i
	return best


## Thu gom vật i; target trả về điểm bay tới (giỏ hoặc máy).
func collect(i: int, target: Callable) -> bool:
	if is_hidden(i):
		return false
	var it := items[i]
	Game.state.items[i] = 1
	if it.flow >= 0:
		Game.state.flow[it.flow] = Vector3(3, it.pos.x, it.pos.z)
	collected_mass += Data.trash_mass(it.type)
	zones[it.zone].done += 1
	_anims.append([i, 0.0, it.pos, target])
	puff(it.pos + Vector3(0, 0.05, 0), it.water)
	return true


## Rác nổi gần nhất trong bán kính r quanh (x, z), dùng cho máy vớt.
func nearest_floating(x: float, z: float, r: float) -> int:
	var best := -1
	var bd := r
	for i in items.size():
		if not items[i].water or is_hidden(i):
			continue
		var d := Vector2(items[i].pos.x - x, items[i].pos.z - z).length()
		if d < bd:
			bd = d
			best = i
	return best


## Số rác trôi đang chờ thoát khỏi cửa xả hoặc còn trôi tới vùng xoáy.
func flow_incoming() -> int:
	var n := 0
	for f in Game.state.flow:
		if f.x <= 1:
			n += 1
	return n


## Rác đống cửa xả còn đè quanh vật cản.
func pile_near(p: Vector2, r: float) -> int:
	var n := 0
	for i in items.size():
		if items[i].area == "pile" and not is_hidden(i) and Vector2(items[i].pos.x, items[i].pos.z).distance_to(p) < r:
			n += 1
	return n


func pick_gem(origin: Vector3, dir: Vector3, reach: float) -> int:
	for i in _gems.size():
		if not _gems[i].visible:
			continue
		var v := _gems[i].position + Vector3(0, 0.15, 0) - origin
		var t := v.dot(dir)
		if t > 0.0 and t < reach and v.length_squared() - t * t < 0.16:
			return i
	return -1


func take_gem(i: int) -> void:
	_gems[i].visible = false
	Game.state.collectibles.append(i)


func show_markers(on: bool) -> void:
	_markers.visible = on


func update(delta: float, t: float) -> void:
	var s := Game.state
	var eddy: Vector3 = Data.LEVEL.eddy
	# Rác trôi hữu hạn: chỉ thoát ra sau khi kéo vật cản khỏi cửa xả
	if s.obstacle.done:
		s.flow_timer += delta
		while s.flow_timer >= Data.ECON.flow_interval:
			s.flow_timer -= Data.ECON.flow_interval
			var k := -1
			for j in s.flow.size():
				if s.flow[j].x == 0:
					k = j
					break
			if k < 0:
				s.flow_timer = 0.0
				break
			var it := flow_items[k]
			it.pos = Vector3(Data.LEVEL.outfall.x + randf_range(-0.5, 0.5), Level.WATER_Y, Data.LEVEL.outfall.y - 0.5)
			s.flow[k] = Vector3(1, it.pos.x, it.pos.z)
	for it in flow_items:
		var f: Vector3 = s.flow[it.flow]
		if f.x == 1:
			it.pos.x += Data.ECON.flow_speed * delta
			it.pos.z += (eddy.y - it.pos.z) * 0.5 * delta + sin(t + it.yaw * 7.0) * 0.2 * delta
			if it.pos.x >= eddy.x - eddy.z * 0.6:
				f.x = 2
		elif f.x == 2:
			var d := Vector2(it.pos.x - eddy.x, it.pos.z - eddy.y)
			var r := clampf(d.length() * 0.999, 0.4, eddy.z)
			var a := d.angle() + delta * 0.35
			it.pos.x = eddy.x + cos(a) * r
			it.pos.z = eddy.y + sin(a) * r
		else:
			continue
		f.y = it.pos.x
		f.z = it.pos.z
		s.flow[it.flow] = f
		it.yaw += delta * 0.3

	# Mặt nước nhấp nhô
	var fx: bool = Game.settings.water_fx
	for i in items.size():
		if items[i].water and (fx or items[i].flow >= 0) and not is_hidden(i):
			_write(i, 1.0, t if fx else 0.0)

	# Hiệu ứng bay về giỏ / máy
	for k in range(_anims.size() - 1, -1, -1):
		var a: Array = _anims[k]
		a[1] += delta / 0.32
		var e := minf(a[1], 1.0)
		var p: Vector3 = (a[2] as Vector3).lerp(a[3].call(), e * e)
		p.y += sin(e * PI) * 0.6
		var it := items[a[0]]
		var b := Basis.from_euler(Vector3(e * 6.0, it.yaw + e * 4.0, 0)).scaled(Vector3.ONE * maxf(0.001, 1.0 - e * 0.7))
		_mm[it.type].set_instance_transform(_slot[a[0]], Transform3D(b, p))
		if a[1] >= 1.0:
			_write(a[0], 0.0)
			_anims.remove_at(k)

	for g in _gems:
		g.rotation.y = t
	_flies.emitting = pile_near(Data.LEVEL.obstacle, 3.0) > 4

	if _markers.visible:
		for i in items.size():
			var it := items[i]
			var sc := 0.001 if is_hidden(i) else 1.0
			_markers.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * sc), it.pos + Vector3(0, 1.5, 0)))
