class_name Machines
extends Node3D
## Thiết bị, công trình và vật cản: bàn phân loại, băng chuyền, máy vớt, công trình xử lý nước thải,
## vật cản cửa xả kéo bằng móc. Logic máy trả về dữ liệu trạng thái để giao diện hiển thị.

const STATE_NAMES := {"running": "Đang chạy", "idle": "Chờ", "starved": "Thiếu đầu vào", "full": "Đầu ra đầy", "paused": "Tạm dừng", "done": "Hoàn tất"}
const ROPE := 3.0 # dây căng từ độ dài này thì lốp bắt đầu trượt theo
const ROPE_MAX := 3.8 # người chơi không đi xa lốp hơn
const RECEIVE_R := 1.6 # bán kính vòng điểm nhận
const BELT_EXIT := {"metal": 0.35, "plastic": 0.7, "other": 1.0} # vị trí mô-đun trên băng (0..1)

var main: Node # main.gd: toast, hint, ui
var trash: Trash
var interactables: Array[Dictionary] = []
var hooked := false
var build_mode := false
var dev_speed := 1.0

var _slots: Dictionary = Data.LEVEL.slots
var _intake := Vector2(Data.LEVEL.eddy.x, Data.LEVEL.eddy.y + 0.2)
var _groups := {}
var _ghosts := {}
var _out_fill := {}
var _skim_fill: Node3D
var _transit: MultiMeshInstance3D
var _belt_mat: StandardMaterial3D
var _drum: Node3D
var _stirrer: Node3D
var _lamp: StandardMaterial3D
var _ring: MeshInstance3D
var _bubbles: CPUParticles3D
var _sparks: CPUParticles3D
var _tyre: Node3D
var _rope: MultiMeshInstance3D
var _tyre_y := 0.0
var _tyre_yaw := 0.0
var _tilt := 0.0
var _slide := 0.0
var _ghost_ok: StandardMaterial3D
var _ghost_red: StandardMaterial3D


func _s() -> Dictionary:
	return Game.state


static func _mat(c: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m


static func _bm(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


## Thùng nhựa tô màu theo nhóm, có khối "rác" dâng lên theo độ đầy.
func _bin(parent: Node3D, color: Color, pos: Vector3, text: String) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	var crate := MeshInstance3D.new()
	crate.mesh = Assets.mesh("plastic_crate_01", [], 0.75)
	crate.rotation.y = PI / 2
	var tinted := (crate.mesh.surface_get_material(0) as BaseMaterial3D).duplicate() as BaseMaterial3D
	tinted.albedo_color = color.lightened(0.2)
	crate.material_override = tinted
	g.add_child(crate)
	var fill := _part(g, _bm(0.42, 0.5, 0.62), _mat(Color(0.25, 0.22, 0.18), 0.95), Vector3(0, 0.03, 0))
	(fill.mesh as BoxMesh).size.y = 0.5
	fill.set_meta("fill", true)
	g.set_meta("fill", fill)
	if text != "":
		g.add_child(Level.label(text, Vector3(0, 0.75, 0), 40, color.lightened(0.4)))
	parent.add_child(g)
	return g


static func _set_fill(bin: Node3D, ratio: float) -> void:
	var f: MeshInstance3D = bin.get_meta("fill")
	var r := clampf(ratio, 0.0, 1.0)
	f.visible = r > 0.01
	f.scale.y = maxf(r, 0.001)
	f.position.y = 0.03 + 0.25 * r


func build() -> void:
	var steel := _mat(Color(0.5, 0.55, 0.58), 0.35, 0.8)

	# ---------- Bàn phân loại (có sẵn từ đầu) ----------
	var t: Vector2 = Data.LEVEL.table
	var table := Node3D.new()
	table.position = Vector3(t.x, 0, t.y)
	var tm := MeshInstance3D.new()
	tm.mesh = Assets.mesh("wooden_table_02", [], 2.2)
	table.add_child(tm)
	for i in 3:
		var k: String = Data.CAT_KEYS[i]
		_bin(table, Data.CATS[k].color, Vector3(-0.9 + i * 0.9, 0, 1.15), Data.CATS[k].name.to_upper())
	table.add_child(Level.label("BÀN PHÂN LOẠI", Vector3(0, 1.8, -0.4), 64))
	add_child(table)

	# ---------- Băng chuyền ----------
	var conv := Node3D.new()
	conv.position = Vector3(_slots.conveyor.x, 0, _slots.conveyor.y)
	_belt_mat = _mat(Color(0.12, 0.12, 0.12), 0.9)
	_belt_mat.albedo_texture = _stripes()
	_belt_mat.uv1_scale = Vector3(6, 1, 1)
	_part(conv, _bm(4.4, 0.1, 0.8), _belt_mat, Vector3(0, 0.85, 0))
	for x in [-2.0, 0.0, 2.0]:
		for z in [-0.35, 0.35]:
			_part(conv, _bm(0.08, 0.85, 0.08), steel, Vector3(x, 0.42, z))
	_part(conv, _bm(0.9, 0.6, 0.9), _mat(Color(0.85, 0.68, 0.05), 0.5, 0.3), Vector3(-2.55, 1.15, 0))
	conv.add_child(Level.label("PHỄU NẠP", Vector3(-2.55, 1.75, 0), 40))
	for m in [["NAM CHÂM", Color(0.75, 0.2, 0.18), -0.6], ["TÁCH NHỰA", Color(0.18, 0.5, 0.93), 0.8]]:
		_part(conv, _bm(0.5, 0.45, 1.0), _mat(m[1], 0.5, 0.4), Vector3(m[2], 1.35, 0))
		conv.add_child(Level.label(m[0], Vector3(m[2], 1.85, 0), 36))
	_out_fill.metal = _bin(conv, Data.CATS.metal.color, Vector3(-0.6, 0, 0.95), "KIM LOẠI")
	_out_fill.plastic = _bin(conv, Data.CATS.plastic.color, Vector3(0.8, 0, 0.95), "NHỰA")
	_out_fill.other = _bin(conv, Data.CATS.other.color, Vector3(2.65, 0, 0), "CÒN LẠI")
	var tmm := MultiMesh.new()
	tmm.transform_format = MultiMesh.TRANSFORM_3D
	tmm.use_colors = true
	tmm.mesh = _bm(0.16, 0.12, 0.16)
	tmm.instance_count = 40
	tmm.visible_instance_count = 0
	_transit = MultiMeshInstance3D.new()
	_transit.multimesh = tmm
	var tmat := _mat(Color.WHITE)
	tmat.vertex_color_use_as_albedo = true
	_transit.material_override = tmat
	conv.add_child(_transit)
	_sparks = CPUParticles3D.new()
	_sparks.emitting = false
	_sparks.amount = 12
	_sparks.lifetime = 0.5
	_sparks.direction = Vector3.UP
	_sparks.initial_velocity_min = 1.0; _sparks.initial_velocity_max = 2.0
	var sm := SphereMesh.new()
	sm.radius = 0.02; sm.height = 0.04
	var smat := _mat(Color(0.6, 0.85, 1.0))
	smat.emission_enabled = true
	smat.emission = Color(0.4, 0.7, 1.0)
	sm.material = smat
	_sparks.mesh = sm
	_sparks.position = Vector3(-0.6, 1.1, 0)
	conv.add_child(_sparks)
	add_child(conv)
	_groups.conveyor = conv

	# ---------- Máy vớt ----------
	var skim := Node3D.new()
	skim.position = Vector3(_slots.skimmer.x, 0, _slots.skimmer.y)
	var gen := MeshInstance3D.new()
	gen.mesh = Assets.mesh("portable_generator", [], 1.6)
	gen.rotation.y = PI
	skim.add_child(gen)
	var arm_len: float = _slots.skimmer.y - _intake.y
	_part(skim, _bm(0.25, 0.25, arm_len), steel, Vector3(0, 0.45, -arm_len / 2.0))
	_part(skim, _bm(0.12, 1.8, 0.12), steel, Vector3(0, -0.4, -arm_len + 0.2))
	var drum_mesh := CylinderMesh.new()
	drum_mesh.top_radius = 0.45; drum_mesh.bottom_radius = 0.45; drum_mesh.height = 1.8; drum_mesh.radial_segments = 8
	_drum = Node3D.new()
	_drum.position = Vector3(0, Level.WATER_Y + 0.25, -arm_len)
	var dm := _part(_drum, drum_mesh, _mat(Color(0.95, 0.6, 0.1), 0.5, 0.2), Vector3.ZERO)
	dm.rotation.z = PI / 2
	skim.add_child(_drum)
	_skim_fill = _bin(skim, Color(0.1, 0.65, 0.55), Vector3(1.4, 0, 0.3), "THÙNG")
	skim.add_child(Level.label("MÁY VỚT", Vector3(0, 1.8, 0), 56))
	add_child(skim)
	_groups.skimmer = skim
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = Data.ECON.skim_radius - 0.08
	torus.outer_radius = Data.ECON.skim_radius
	_ring.mesh = torus
	var rmat := _mat(Color(0.1, 0.9, 0.75))
	rmat.emission_enabled = true
	rmat.emission = Color(0.1, 0.9, 0.75)
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_color.a = 0.6
	_ring.material_override = rmat
	_ring.scale = Vector3(1, 0.05, 1)
	_ring.position = Vector3(_intake.x, Level.WATER_Y + 0.04, _intake.y)
	add_child(_ring)

	# ---------- Công trình xử lý nước thải ----------
	var plant := Node3D.new()
	plant.position = Vector3(_slots.plant.x, 0, _slots.plant.y)
	var concrete := Assets.pbr("concrete_moss", Vector3(0.6, 0.6, 0.6), Color(0.95, 0.95, 0.95))
	_part(plant, _bm(2.4, 2.2, 1.8), concrete, Vector3(0, 1.1, 0))
	for x in [-2.0, 2.0]:
		var tank := MeshInstance3D.new()
		tank.mesh = Assets.mesh("propane_tank", [], 1.8)
		tank.position = Vector3(x, 0, 0)
		plant.add_child(tank)
	_stirrer = _part(plant, _bm(1.2, 0.08, 0.15), steel, Vector3(2, 1.95, 0))
	_lamp = _mat(Color(0.2, 0.9, 0.4))
	_lamp.emission_enabled = true
	_lamp.emission = Color(0.2, 1.0, 0.4)
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.15; lamp_mesh.height = 0.3
	_part(plant, lamp_mesh, _lamp, Vector3(0, 2.35, -0.9))
	var pipe := CylinderMesh.new()
	pipe.top_radius = 0.15; pipe.bottom_radius = 0.15; pipe.height = 4.8
	_part(plant, pipe, steel, Vector3(0, 0.15, -3.3)).rotation.x = PI / 2
	plant.add_child(Level.label("XỬ LÝ NƯỚC THẢI", Vector3(0, 2.8, -0.9), 56, Color(0.6, 1, 0.75)))
	add_child(plant)
	_groups.plant = plant
	_bubbles = CPUParticles3D.new()
	_bubbles.amount = 40
	_bubbles.lifetime = 2.5
	_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_bubbles.emission_sphere_radius = 0.9
	_bubbles.direction = Vector3(0, 0.2, -1)
	_bubbles.spread = 25
	_bubbles.gravity = Vector3(0, 0.2, 0)
	_bubbles.initial_velocity_min = 0.3; _bubbles.initial_velocity_max = 0.8
	var bm := SphereMesh.new()
	bm.radius = 0.05; bm.height = 0.1
	var bmat := _mat(Color(0.9, 1, 1, 0.6), 0.05)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.material = bmat
	_bubbles.mesh = bm
	_bubbles.position = Vector3(Data.LEVEL.outfall.x, Level.WATER_Y + 0.05, Data.LEVEL.outfall.y - 0.8)
	_bubbles.emitting = false
	add_child(_bubbles)

	# ---------- Hình xem trước tại vị trí lắp ----------
	_ghost_ok = _mat(Color(0.2, 0.9, 0.45, 0.3))
	_ghost_ok.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_ok.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_red = _ghost_ok.duplicate()
	_ghost_red.albedo_color = Color(0.95, 0.3, 0.25, 0.3)
	var sizes := {"conveyor": Vector3(6, 1.6, 2), "skimmer": Vector3(2.4, 1.2, 1.8), "plant": Vector3(6, 2.4, 2.2)}
	for k in sizes:
		var g := _part(self, _bm(sizes[k].x, sizes[k].y, sizes[k].z), _ghost_ok, Vector3(_slots[k].x, sizes[k].y / 2.0, _slots[k].y))
		g.visible = false
		_ghosts[k] = g

	# ---------- Vật cản cửa xả ----------
	# Lốp nằm phẳng, tâm đặt đúng gốc của nút để vị trí lưu trùng với hình
	_tyre = Node3D.new()
	var ty := MeshInstance3D.new()
	ty.mesh = Assets.mesh("old_tyre", [], 1.4)
	var ab := ty.mesh.get_aabb()
	ty.rotation.x = PI / 2
	ty.position = Vector3(0, ab.size.z / 2.0, -ab.size.y / 2.0)
	_tyre.add_child(ty)
	add_child(_tyre)
	_tyre_y = Level.ground_at(Data.LEVEL.obstacle.x, Data.LEVEL.obstacle.y)
	var seg := CylinderMesh.new()
	seg.top_radius = 0.018; seg.bottom_radius = 0.018; seg.height = 1.0; seg.radial_segments = 6; seg.rings = 1
	var rmm := MultiMesh.new()
	rmm.transform_format = MultiMesh.TRANSFORM_3D
	rmm.mesh = seg
	rmm.instance_count = 16
	_rope = MultiMeshInstance3D.new()
	_rope.multimesh = rmm
	_rope.material_override = _mat(Color(0.95, 0.75, 0.1), 0.7)
	_rope.visible = false
	add_child(_rope)

	_make_interactables()


func _stripes() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 0.51, 1.0])
	g.colors = PackedColorArray([Color(0.1, 0.1, 0.1), Color(0.1, 0.1, 0.1), Color(0.25, 0.25, 0.25), Color(0.25, 0.25, 0.25)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64; t.height = 4
	return t


# ---------- Logic ----------
func unlocked(k: String) -> bool:
	return not Data.SHOP[k].has("unlock") or _s().obstacle.done


func belt_speed() -> float:
	return Data.ECON.belt_speed * (2.0 if _s().upgrades.up_belt else 1.0) * dev_speed


func skim_cap() -> int:
	return Data.ECON.skim_bin_up if _s().upgrades.up_skim_bin else Data.ECON.skim_bin


func skim_rate() -> float:
	return Data.ECON.skim_rate * dev_speed


func out_total() -> int:
	var n := 0
	for k in Data.CAT_KEYS:
		n += _s().conveyor.out[k].size()
	return n


func conv_state() -> String:
	var c: Dictionary = _s().conveyor
	if c.paused:
		return "paused"
	if c.blocked != "":
		return "full"
	if c.hopper.is_empty() and c.transit.is_empty():
		return "starved"
	return "running"


func skim_state() -> String:
	var k: Dictionary = _s().skimmer
	if k.paused:
		return "paused"
	if k.bin.size() >= skim_cap():
		return "full"
	if trash.nearest_floating(_intake.x, _intake.y, Data.ECON.skim_radius) >= 0:
		return "running"
	return "idle" if trash.flow_incoming() > 0 else "starved"


func _update_conveyor(delta: float) -> void:
	var c: Dictionary = _s().conveyor
	if not _s().placed.conveyor or c.paused:
		return
	var step := delta * belt_speed() / Data.ECON.belt_travel
	c.blocked = ""
	for i in range(c.transit.size() - 1, -1, -1):
		var it: Array = c.transit[i]
		var cat: String = Data.TRASH[it[0]].cat
		var exit: float = BELT_EXIT[cat]
		if it[1] < exit:
			it[1] = minf(exit, it[1] + step)
			continue
		if c.out[cat].size() >= Data.ECON.belt_out:
			c.blocked = cat
			continue
		c.out[cat].append(it[0])
		c.transit.remove_at(i)
		if cat == "metal":
			_sparks.restart()
	if c.blocked != "":
		return
	c.feed += delta
	if not c.hopper.is_empty() and c.feed >= 1.0 / belt_speed():
		c.feed = 0.0
		c.transit.append([c.hopper.pop_front(), 0.0])


func _update_skimmer(delta: float) -> void:
	var k: Dictionary = _s().skimmer
	if not _s().placed.skimmer or k.paused or k.bin.size() >= skim_cap():
		return
	k.timer += delta
	if k.timer < 1.0 / skim_rate():
		return
	var i := trash.nearest_floating(_intake.x, _intake.y, Data.ECON.skim_radius)
	if i < 0:
		return
	k.timer = 0.0
	var type := trash.items[i].type
	var target := Vector3(_slots.skimmer.x + 1.4, 0.8, _slots.skimmer.y + 0.3)
	if trash.collect(i, func(): return target):
		k.bin.append(type)
		Sfx.play("splash")


func _update_plant(delta: float) -> void:
	var p: Dictionary = _s().plant
	if _s().placed.plant and p.progress < 1.0:
		p.progress = minf(1.0, p.progress + delta * dev_speed / Data.ECON.plant_duration)


## Dây kéo: lốp bị kéo khi dây căng quá ROPE; người chơi không đi xa lốp quá ROPE_MAX
## (lốp nặng giữ lại), nên lốp luôn trượt theo sau như kéo thật.
func _update_obstacle(delta: float, cam: Vector3) -> void:
	var o: Dictionary = _s().obstacle
	_tyre.visible = not o.done
	if o.done:
		_rope.visible = false
		hooked = false
		return
	var p: Vector2 = o.pos
	var moved := 0.0
	var hp := Vector2(cam.x, cam.z)
	if hooked:
		var d := hp - p
		var dist := d.length()
		if dist > 12.0: # chỉ xảy ra khi dịch chuyển (chế độ phát triển)
			hooked = false
			Game.say("Dây móc bị tuột – móc lại vật cản.", "warn")
		elif dist > ROPE:
			var n := p + d / dist * (dist - ROPE)
			for c in [n, Vector2(n.x, p.y), Vector2(p.x, n.y)]:
				if _tyre_can_go(p, c):
					o.pos = c
					break
			moved = p.distance_to(o.pos)
			# Lốp quay đầu theo hướng kéo
			_tyre_yaw = lerp_angle(_tyre_yaw, atan2(d.x, d.y), minf(1.0, delta * 4.0))
		if o.pos.distance_to(Data.LEVEL.receive) < RECEIVE_R:
			_finish_obstacle()
			return
	if is_nan(Level.ground_at(o.pos.x, o.pos.y)):
		o.pos = Data.LEVEL.obstacle # điểm phục hồi hợp lệ
	var g := Level.ground_at(o.pos.x, o.pos.y)
	_tyre_y = g if absf(_tyre_y - g) > 1.0 else lerpf(_tyre_y, g, minf(1.0, delta * 10.0))
	# Bụi và tiếng sột soạt khi lốp trượt trên nền
	_slide += moved
	if _slide > 0.7:
		_slide = 0.0
		trash.puff(Vector3(o.pos.x, _tyre_y + 0.05, o.pos.y), false)
		Sfx.play("drag", 0.1)
	var tilt := clampf(moved / maxf(delta, 0.001) * 0.04, 0.0, 0.18) # mép trước hơi nhấc lên khi bị kéo
	_tilt = lerpf(_tilt, tilt, minf(1.0, delta * 6.0))
	_tyre.position = Vector3(o.pos.x, _tyre_y, o.pos.y)
	_tyre.basis = Basis(Vector3.UP, _tyre_yaw) * Basis(Vector3.RIGHT, -_tilt)
	_rope.visible = hooked
	if hooked:
		_draw_rope(cam)


## Dây gồm nhiều đoạn, võng xuống khi chùng và thẳng khi căng.
func _draw_rope(cam: Vector3) -> void:
	var b := _tyre.position + _tyre.basis * Vector3(0, 0.34, 0.6) # móc vào mép lốp phía người kéo
	var flat := Vector3(b.x - cam.x, 0, b.z - cam.z).normalized()
	var a := cam + Vector3(0, -0.75, 0) + flat * 0.35 # tay người chơi
	var span := a.distance_to(b)
	var sag := clampf((ROPE + 0.4 - span) * 0.45, 0.02, 0.9)
	var mm := _rope.multimesh
	var prev := a
	for i in mm.instance_count:
		var t := float(i + 1) / mm.instance_count
		var q := a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		var seg := q - prev
		var len := seg.length()
		var up := seg / maxf(len, 0.0001)
		var side := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
		mm.set_instance_transform(i, Transform3D(Basis(side, up * len, side.cross(up)), (prev + q) / 2.0))
		prev = q


func _tyre_can_go(from: Vector2, to: Vector2) -> bool:
	var g := Level.ground_at(to.x, to.y)
	var g0 := Level.ground_at(from.x, from.y)
	if is_nan(g) or (not is_nan(g0) and absf(g - g0) > 0.5):
		return false
	for sd in solids():
		if to.distance_to(sd[0]) < sd[1] + 0.5:
			return false
	return true


## Người chơi đang kéo lốp có được bước tới `to` không (không đi xa quá dây).
func rope_ok(from: Vector2, to: Vector2) -> bool:
	if not hooked:
		return true
	var p: Vector2 = _s().obstacle.pos
	var d := to.distance_to(p)
	return d <= ROPE_MAX or d <= from.distance_to(p)


func _finish_obstacle() -> void:
	var s := _s()
	hooked = false
	s.obstacle.done = true
	s.money += Data.ECON.obstacle_money
	s.mat += Data.ECON.obstacle_mat
	Game.save_game()
	Sfx.play("collect")
	Game.say("Đã kéo %s về điểm nhận: +%d tiền, +%s vật liệu. Cửa xả thông, rác trôi bắt đầu chảy ra." % [Data.LEVEL.obstacle_name, Data.ECON.obstacle_money, Game.fmt_mat(Data.ECON.obstacle_mat)], "good")
	Game.show_hint("flow")


# ---------- Thao tác ----------
func dump_to_table() -> int:
	var s := _s()
	var n: int = s.basket.size() + s.crate.size()
	if n > 0:
		s.table.append_array(s.basket)
		s.table.append_array(s.crate)
		s.basket = []
		s.crate = []
		s.stats.dumped += 1
		Game.save_game()
		Sfx.play("dump")
	return n


func feed_conveyor() -> void:
	var s := _s()
	var c: Dictionary = s.conveyor
	var moved := 0
	for src in ["crate", "basket"]:
		while not s[src].is_empty() and c.hopper.size() < Data.ECON.belt_hopper:
			c.hopper.append(s[src].pop_front())
			moved += 1
	if moved > 0:
		Game.save_game()
		Sfx.play("dump")
	if not s.crate.is_empty() or not s.basket.is_empty():
		Game.say("Phễu đầy – chờ băng chuyền chạy bớt hoặc nâng tốc độ.", "warn")


func process_outputs() -> void:
	var c: Dictionary = _s().conveyor
	var all := []
	for k in Data.CAT_KEYS:
		all.append_array(c.out[k])
		c.out[k] = []
	if all.is_empty():
		return
	var r := Game.process_batch(all, true)
	Sfx.play("coin")
	Game.say("Xử lý %d món: +%d tiền, +%s vật liệu" % [all.size(), r.x, Game.fmt_mat(r.y)], "good")


func take_skim_bin() -> void:
	var s := _s()
	if not s.crate.is_empty():
		Game.say("Bạn đang mang một thùng. Đổ vào phễu băng chuyền hoặc bàn phân loại trước.", "warn")
		return
	if s.skimmer.bin.is_empty():
		Game.say("Thùng máy vớt đang trống.", "warn")
		return
	s.crate = s.skimmer.bin
	s.skimmer.bin = []
	Game.save_game()
	Sfx.play("dump")
	Game.show_hint("crate")


func is_empty(k: String) -> bool:
	var s := _s()
	if k == "conveyor":
		return s.conveyor.hopper.is_empty() and s.conveyor.transit.is_empty() and out_total() == 0
	if k == "skimmer":
		return s.skimmer.bin.is_empty()
	return true


## Dữ liệu bảng máy cho giao diện: trạng thái, nguyên nhân, cách khắc phục, hàng chờ, nút.
func info(k: String) -> Dictionary:
	var s := _s()
	if k == "conveyor":
		var c: Dictionary = s.conveyor
		var st := conv_state()
		var causes := {
			"starved": ["Phễu nạp đang trống.", "Mang giỏ hoặc thùng máy vớt tới và bấm Nạp."],
			"full": ["Thùng đầu ra %s đã đầy." % Data.CATS.get(c.blocked, {"name": ""}).name, "Bấm Xử lý đầu ra để nhận tiền và giải phóng thùng."],
			"paused": ["Bạn đã tạm dừng máy.", "Bấm Tiếp tục."],
		}
		var carry: int = s.basket.size() + s.crate.size()
		var rows := [
			["Tốc độ", "%.1f món/giây" % belt_speed()],
			["Phễu (hàng chờ)", "%d/%d" % [c.hopper.size(), Data.ECON.belt_hopper]],
			["Đang trên băng", str(c.transit.size())],
		]
		for ck in Data.CAT_KEYS:
			rows.append(["Đầu ra " + Data.CATS[ck].name, "%d/%d" % [c.out[ck].size(), Data.ECON.belt_out]])
		rows.append(["Nút thắt", "Tốc độ băng chuyền – nâng cấp động cơ" if c.hopper.size() > 10 else ("Thùng đầu ra – xử lý thường xuyên" if st == "full" else "Lượng nạp vào")])
		return {
			"title": "Băng chuyền (2 mô-đun)", "state": STATE_NAMES[st], "key": st, "cause": causes.get(st, []), "rows": rows,
			"actions": [
				{"label": "Nạp %d món từ giỏ/thùng" % carry, "fn": feed_conveyor, "disabled": carry == 0},
				{"label": "Xử lý đầu ra (%d món)" % out_total(), "fn": process_outputs, "disabled": out_total() == 0, "primary": true},
				{"label": "Tiếp tục" if c.paused else "Tạm dừng", "fn": func(): c.paused = not c.paused; Game.save_game()},
			],
		}
	if k == "skimmer":
		var st := skim_state()
		var causes := {
			"full": ["Thùng máy vớt đã đầy.", "Lấy thùng mang tới băng chuyền hoặc bàn phân loại; hoặc mua Thùng máy vớt lớn."],
			"idle": ["Rác từ cửa xả chưa trôi tới vùng hoạt động." if s.obstacle.done else "Cửa xả còn bị chặn.", "Chờ một chút – trong lúc đó hãy nhặt rác ở khu khác."],
			"starved": ["Không còn rác nổi trong vùng.", "Máy đã gom hết. Có thể tháo về kho để hoàn tiền nếu muốn."],
			"paused": ["Bạn đã tạm dừng máy.", "Bấm Tiếp tục."],
		}
		return {
			"title": "Máy vớt", "state": STATE_NAMES[st], "key": st, "cause": causes.get(st, []),
			"rows": [["Tốc độ vớt", "%.1f món/giây" % skim_rate()], ["Thùng", "%d/%d" % [s.skimmer.bin.size(), skim_cap()]], ["Rác sắp trôi tới", str(trash.flow_incoming())]],
			"actions": [
				{"label": "Lấy thùng (%d món)" % s.skimmer.bin.size(), "fn": take_skim_bin, "disabled": s.skimmer.bin.is_empty() or not s.crate.is_empty(), "primary": true},
				{"label": "Tiếp tục" if s.skimmer.paused else "Tạm dừng", "fn": func(): s.skimmer.paused = not s.skimmer.paused; Game.save_game()},
			],
		}
	var done: bool = s.plant.progress >= 1.0
	return {
		"title": "Công trình xử lý nước thải", "state": "Đã kiểm soát nguồn ô nhiễm" if done else "Đang xử lý", "key": "done" if done else "running",
		"cause": [], "rows": [["Tiến độ làm sạch nước", "%d%%" % roundi(s.plant.progress * 100)]], "actions": [],
	}


# ---------- Điểm tương tác (phím E) ----------
func _make_interactables() -> void:
	var t: Vector2 = Data.LEVEL.table
	interactables = [
		{"pos": t, "r": 2.4, "when": func(): return true,
			"label": func():
				var s := _s()
				var n: int = s.basket.size() + s.crate.size()
				if n > 0: return "Đổ %d món lên bàn và phân loại" % n
				if not s.table.is_empty(): return "Phân loại %d món trên bàn" % s.table.size()
				return "Bàn phân loại (giỏ đang trống)",
			"act": func():
				dump_to_table()
				if _s().table.is_empty(): Game.say("Giỏ trống – hãy nhặt rác trước.", "warn")
				else: main.ui.sort()},
		{"pos": _slots.conveyor - Vector2(1, 0), "r": 3.0, "when": func(): return _s().placed.conveyor,
			"label": func(): return "Băng chuyền – nạp rác và xem trạng thái",
			"act": func(): main.ui.machine("conveyor")},
		{"pos": _slots.skimmer, "r": 2.6, "when": func(): return _s().placed.skimmer,
			"label": func(): return ("Lấy thùng máy vớt (%d món)" % _s().skimmer.bin.size()) if (not _s().skimmer.bin.is_empty() and _s().crate.is_empty()) else "Máy vớt – xem trạng thái",
			"act": func():
				if not _s().skimmer.bin.is_empty() and _s().crate.is_empty(): take_skim_bin()
				else: main.ui.machine("skimmer")},
		{"pos": _slots.plant - Vector2(0, 1), "r": 3.0, "when": func(): return _s().placed.plant,
			"label": func(): return "Công trình xử lý – xem trạng thái",
			"act": func(): main.ui.machine("plant")},
	]


## Vật cản tròn cho người chơi: [tâm, bán kính, máy cần đã lắp].
func solids() -> Array:
	var out := [[Data.LEVEL.table, 1.3]]
	var p: Dictionary = _s().placed
	if p.conveyor:
		for dx in [-2.2, 0.0, 2.3]:
			out.append([_slots.conveyor + Vector2(dx, 0), 0.8])
	if p.skimmer:
		out.append([_slots.skimmer + Vector2(0.5, 0), 1.1])
	if p.plant:
		for dx in [-2.0, 0.0, 2.0]:
			out.append([_slots.plant + Vector2(dx, 0), 1.4 if dx == 0.0 else 0.8])
	return out


func _aim_tyre(origin: Vector3, dir: Vector3, reach: float) -> bool:
	if _s().obstacle.done:
		return false
	var v := _tyre.position + Vector3(0, 0.2, 0) - origin
	var t := v.dot(dir)
	return t > 0.0 and t < reach and v.length_squared() - t * t < 1.2


func aim_obstacle(origin: Vector3, dir: Vector3, reach: float) -> bool:
	return _aim_tyre(origin, dir, reach)


## Thử gắn móc vào vật cản theo tia ngắm (nhấp lần nữa để thả).
func try_hook(origin: Vector3, dir: Vector3, reach: float) -> void:
	if hooked:
		hooked = false
		Game.say("Đã thả móc.")
		return
	if not _aim_tyre(origin, dir, reach):
		return
	var n := trash.pile_near(_s().obstacle.pos, 2.2)
	if n > 0:
		Game.say("Còn %d món rác đè quanh %s. Dọn đống rác trước khi kéo." % [n, Data.LEVEL.obstacle_name], "warn")
		Sfx.play("error")
		return
	hooked = true
	_tyre_yaw = _tyre.rotation.y
	Sfx.play("hook")
	Game.show_hint("drag")


## Vị trí lắp đang nhắm trong chế độ đặt máy.
func build_target(origin: Vector3, dir: Vector3) -> Dictionary:
	var best := {}
	var best_dot := 0.93
	for k in _slots:
		var s := _s()
		var mode := "remove" if s.placed[k] else ("place" if s.stock[k] and unlocked(k) else "")
		if mode == "":
			continue
		var v := Vector3(_slots[k].x, 0.8, _slots[k].y) - origin
		var d := v.length()
		if d > 14.0:
			continue
		var dot := v.dot(dir) / d
		if dot > best_dot:
			best_dot = dot
			best = {"key": k, "mode": mode, "label": ("Đặt: " if mode == "place" else "Tháo về kho: ") + Data.SHOP[k].name}
	return best


func apply_build(t: Dictionary) -> void:
	var s := _s()
	if t.mode == "place":
		s.placed[t.key] = true
		s.stock[t.key] = false
		Game.show_hint(t.key)
	else:
		if t.key == "plant" and s.accepted:
			Game.say("Công trình đã nghiệm thu thuộc về hiện trường.", "warn")
			return
		if not is_empty(t.key):
			Game.say("Máy còn rác bên trong. Xử lý hết trước khi tháo.", "warn")
			return
		s.placed[t.key] = false
		s.stock[t.key] = true
	Game.save_game()
	Sfx.play("place")


func update(delta: float, t: float, cam: Vector3) -> void:
	var s := _s()
	_update_conveyor(delta)
	_update_skimmer(delta)
	_update_plant(delta)
	_update_obstacle(delta, cam)

	for k in _groups:
		_groups[k].visible = s.placed[k]
	_ring.visible = s.placed.skimmer or (build_mode and s.stock.skimmer and unlocked("skimmer"))
	for k in _ghosts:
		_ghosts[k].visible = build_mode and (s.placed[k] or (s.stock[k] and unlocked(k)))
		_ghosts[k].material_override = _ghost_red if s.placed[k] else _ghost_ok

	# Hình ảnh băng chuyền
	var c: Dictionary = s.conveyor
	var mm := _transit.multimesh
	mm.visible_instance_count = mini(40, c.transit.size())
	for i in mm.visible_instance_count:
		var it: Array = c.transit[i]
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, it[1] * 6.0), Vector3(-2.0 + 4.0 * it[1], 0.97, 0)))
		mm.set_instance_color(i, Data.CATS[Data.TRASH[it[0]].cat].color)
	for k in Data.CAT_KEYS:
		_set_fill(_out_fill[k], c.out[k].size() / float(Data.ECON.belt_out))
	_set_fill(_skim_fill, s.skimmer.bin.size() / float(skim_cap()))

	# Chuyển động, hạt và tiếng máy theo khoảng cách
	var near := func(p: Vector2) -> float: return maxf(0.0, 1.0 - Vector2(cam.x, cam.z).distance_to(p) / 20.0)
	var conv_on: bool = s.placed.conveyor and conv_state() == "running"
	var skim_on: bool = s.placed.skimmer and skim_state() == "running"
	var plant_on: bool = s.placed.plant and s.plant.progress < 1.0
	if conv_on:
		_belt_mat.uv1_offset.x -= delta * belt_speed() * 0.4
	if skim_on:
		_drum.rotation.x += delta * 3.0
	if s.placed.plant:
		_stirrer.rotation.y += delta * (3.0 if plant_on else 0.6)
	_lamp.emission_energy_multiplier = (1.0 + sin(t * 3.0) * 0.6) if s.placed.plant else 0.0
	_bubbles.emitting = plant_on
	Sfx.hum("conveyor", 55.0, near.call(_slots.conveyor) if conv_on else 0.0)
	Sfx.hum("skimmer", 73.0, near.call(_slots.skimmer) if skim_on else 0.0)
	Sfx.hum("plant", 41.0, near.call(_slots.plant) * 0.6 if plant_on else 0.0)
