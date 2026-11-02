class_name Level
extends Node3D
## Màn 1: đoạn sông hư cấu lấy cảm hứng từ Tô Lịch.
## Dựng địa hình, nước, phố hai bên, đạo cụ, va chạm và hiệu ứng phục hồi môi trường.

const WATER_Y := -1.2
const STEPS_A := {"x0": -36.0, "x1": -24.0, "tops": [-0.3, -0.6, -0.9]} # bậc xuống bờ khu A
const APRON_D := {"x0": 17.0, "x1": 29.0, "tops": [-0.2, -0.4, -0.6]} # sân bê tông cửa xả khu D
const DOCK := {"x0": -5.2, "x1": -2.8, "z0": 1.0} # bến gỗ khu C
const BANDS := [Vector2(7, 8), Vector2(6, 7), Vector2(4, 6)]

var env: Environment
var sun: DirectionalLight3D
var photo_cam: Camera3D

var _water_mat: ShaderMaterial
var _bank_mat: ShaderMaterial
var _restore: Array[Node3D] = [] # cây, hoa, ghế… lớn dần sau nghiệm thu
var _ducks: Array[Node3D] = []
var _butterflies: GPUParticles3D
var _rng := RandomNumberGenerator.new()
var _grow := -1.0


# ---------- Va chạm và độ cao ----------
static func _step_top(s: Dictionary, z: float) -> float:
	return s.tops[0] if z >= 7.0 else (s.tops[1] if z >= 6.0 else s.tops[2])


static func _in_x(s: Dictionary, x: float) -> bool:
	return x >= s.x0 and x <= s.x1


## Độ cao mặt đi được tại (x, z), hoặc NAN nếu không đi được.
static func ground_at(x: float, z: float) -> float:
	if x < Data.LEVEL.x0 or x > Data.LEVEL.x1:
		return NAN
	if z >= 8.0 and z <= 15.0:
		return 0.0
	if z >= 4.0 and z < 8.0:
		if _in_x(STEPS_A, x):
			return _step_top(STEPS_A, z)
		if _in_x(APRON_D, x):
			return _step_top(APRON_D, z)
	if _in_x(DOCK, x) and z >= DOCK.z0 and z < 8.0:
		return 0.0
	return NAN


## Bờ đất dốc từ mép lối đi (z = 8, y = 0) xuống đáy sông.
static func slope_y(z: float) -> float:
	return (z - 8.0) * 0.5


## Mặt đặt rác: nền đi được, bờ dốc hoặc mặt nước.
static func surface_y(x: float, z: float) -> float:
	var g := ground_at(x, z)
	return g if not is_nan(g) else maxf(slope_y(z), WATER_Y)


# ---------- Dựng màn ----------
func build() -> void:
	_rng.seed = 7
	_environment()
	_terrain()
	_water()
	_city()
	_props()
	_restoration()
	photo_cam = Camera3D.new()
	add_child(photo_cam)
	photo_cam.look_at_from_position(Vector3(-16, 5, 17), Vector3(6, -1, 2))


func _environment() -> void:
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = load("res://assets/sky/kloofendal_48d_partly_cloudy_puresky.hdr")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssr_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_density = 0.006
	env.fog_aerial_perspective = 0.6
	env.adjustment_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.4
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = Game.settings.shadows
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)


func _box(size: Vector3, pos: Vector3, mat: Material, shadow := true) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m


## Tứ giác trải dọc trục x từ cạnh xa (y0, z0) đến cạnh gần (y1, z1).
func _strip(x0: float, x1: float, far: Vector2, near: Vector2, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p := [Vector3(x0, far.x, far.y), Vector3(x1, far.x, far.y), Vector3(x1, near.x, near.y), Vector3(x0, near.x, near.y)]
	var uv := [Vector2(x0, far.y), Vector2(x1, far.y), Vector2(x1, near.y), Vector2(x0, near.y)]
	for i in [0, 2, 1, 0, 3, 2]:
		st.set_uv(uv[i] * 0.3)
		st.add_vertex(p[i])
	st.generate_normals()
	st.generate_tangents()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat
	add_child(m)
	return m


func _terrain() -> void:
	var paving := Assets.pbr("concrete_pavers", Vector3(0.5, 0.5, 0.5))
	paving.uv1_triplanar = true
	paving.uv1_world_triplanar = true
	var concrete := Assets.pbr("concrete_moss", Vector3(0.4, 0.4, 0.4))
	concrete.uv1_triplanar = true
	concrete.uv1_world_triplanar = true
	var mud := Assets.pbr("brown_mud_02", Vector3(0.3, 0.3, 0.3), Color(0.55, 0.5, 0.42))
	mud.uv1_triplanar = true
	mud.uv1_world_triplanar = true

	# Lối đi ven bờ, bờ đối diện, lề cỏ
	_box(Vector3(160, 0.6, 7), Vector3(0, -0.3, 11.5), paving)
	_box(Vector3(160, 0.14, 0.3), Vector3(0, 0.07, 8.15), concrete)
	_box(Vector3(160, 3.6, 0.8), Vector3(0, -1.2, -6.4), concrete)
	_box(Vector3(160, 0.4, 3.0), Vector3(0, 0.4, -8.3), paving)
	var grass := Assets.pbr("leafy_grass", Vector3(0.25, 0.25, 0.25), Color(0.75, 0.72, 0.5))
	grass.uv1_triplanar = true
	grass.uv1_world_triplanar = true
	_box(Vector3(160, 0.2, 6), Vector3(0, -0.08, 18.2), grass)

	# Bờ dốc: bùn → cỏ theo tiến độ dọn
	_bank_mat = ShaderMaterial.new()
	_bank_mat.shader = load("res://shaders/bank.gdshader")
	_bank_mat.set_shader_parameter("mud_albedo", load("res://assets/textures/brown_mud_02/brown_mud_02_diff.jpg"))
	_bank_mat.set_shader_parameter("mud_normal", load("res://assets/textures/brown_mud_02/brown_mud_02_nor.jpg"))
	_bank_mat.set_shader_parameter("grass_albedo", load("res://assets/textures/leafy_grass/leafy_grass_diff.jpg"))
	_bank_mat.set_shader_parameter("grass_normal", load("res://assets/textures/leafy_grass/leafy_grass_nor.jpg"))
	_bank_mat.set_shader_parameter("mask_noise", _noise_tex(0.02, false))
	_bank_mat.set_shader_parameter("wet_height", WATER_Y)
	_strip(-80, 80, Vector2(-3, 2), Vector2(0, 8), _bank_mat)
	_strip(-80, 80, Vector2(-3, -6), Vector2(-3, 2), mud)

	# Bậc xuống bờ (A) và sân cửa xả (D)
	for s in [STEPS_A, APRON_D]:
		for i in BANDS.size():
			var top: float = s.tops[i]
			var band: Vector2 = BANDS[i]
			_box(Vector3(s.x1 - s.x0, top + 3.0, band.y - band.x), Vector3((s.x0 + s.x1) / 2.0, (top - 3.0) / 2.0, (band.x + band.y) / 2.0), concrete)

	# Bến gỗ (C): hai đoạn cầu tàu mô-đun
	var pier := Assets.mesh("modular_wooden_pier", ["modular_wooden_pier_section_02"])
	for z in [2.75, 6.1]:
		var p := MeshInstance3D.new()
		p.mesh = pier
		var top := pier.get_aabb().end.y
		p.position = Vector3((DOCK.x0 + DOCK.x1) / 2.0, 0.02 - top, z)
		add_child(p)

	# Cửa xả: ống bê tông đen ngòm
	var pipe := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.65; cyl.bottom_radius = 0.65; cyl.height = 1.4
	pipe.mesh = cyl
	pipe.material_override = concrete
	pipe.rotation_degrees.x = 90
	pipe.position = Vector3(Data.LEVEL.outfall.x, -0.95, Data.LEVEL.outfall.y + 0.2)
	add_child(pipe)
	_box(Vector3(1.0, 1.0, 0.05), Vector3(Data.LEVEL.outfall.x, -0.95, Data.LEVEL.outfall.y - 0.5), _flat(Color(0.03, 0.03, 0.03)), false)


func _flat(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _noise_tex(freq: float, normal: bool, size := 512) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.frequency = freq
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = size; t.height = size
	t.seamless = true
	t.noise = n
	t.as_normal_map = normal
	t.bump_strength = 4.0
	return t


func _water() -> void:
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load("res://shaders/water.gdshader")
	_water_mat.set_shader_parameter("normal_a", _noise_tex(0.015, true))
	_water_mat.set_shader_parameter("normal_b", _noise_tex(0.03, true))
	_water_mat.set_shader_parameter("scum_noise", _noise_tex(0.01, false, 256))
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 12.7)
	plane.subdivide_width = 200
	plane.subdivide_depth = 12
	var w := MeshInstance3D.new()
	w.mesh = plane
	w.material_override = _water_mat
	w.position = Vector3(0, WATER_Y, -0.15)
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(w)


## Dãy nhà phố hai bên sông: khối tường gạch + cửa kính + mái, vẽ bằng MultiMesh.
func _city() -> void:
	var wall := Assets.pbr("brick_wall_02", Vector3(0.35, 0.35, 0.35))
	wall.uv1_triplanar = true
	wall.uv1_world_triplanar = true
	wall.vertex_color_use_as_albedo = true
	var glass := _flat(Color(0.12, 0.16, 0.2), 0.08, 0.6)
	var roof := _flat(Color(0.35, 0.2, 0.16), 0.9)
	var palette := [Color(1, 0.93, 0.75), Color(0.95, 0.8, 0.75), Color(0.85, 0.9, 0.95), Color(1, 1, 0.95), Color(0.85, 0.95, 0.8), Color(1, 0.85, 0.65)]
	var houses: Array[Transform3D] = []
	var colors: Array[Color] = []
	var windows: Array[Transform3D] = []
	var roofs: Array[Transform3D] = []
	for i in 64:
		var far := i % 2 == 1
		var k := i / 2
		var w := _rng.randf_range(4.0, 6.0)
		var h := _rng.randf_range(7.0, 16.0)
		var d := _rng.randf_range(8.0, 12.0)
		var base := 0.6 if far else 0.0
		var x := -78.0 + k * 5.0
		var front := -9.8 if far else 21.0 # mặt nhà nhìn ra sông
		var cz := front - d / 2.0 if far else front + d / 2.0
		houses.append(Transform3D(Basis.from_scale(Vector3(w, h, d)), Vector3(x, base + h / 2.0, cz)))
		colors.append(palette[_rng.randi() % palette.size()])
		roofs.append(Transform3D(Basis.from_scale(Vector3(w + 0.3, 0.3, d + 0.3)), Vector3(x, base + h + 0.15, cz)))
		var fz := front + (0.03 if far else -0.03)
		for row in range(1, int(h / 3.0)):
			for col in [-1, 1]:
				windows.append(Transform3D(Basis.from_scale(Vector3(1.2, 1.5, 0.05)), Vector3(x + col * w * 0.22, base + row * 3.0 + 0.4, fz)))
	_multimesh(BoxMesh.new(), wall, houses, colors)
	_multimesh(BoxMesh.new(), glass, windows)
	_multimesh(BoxMesh.new(), roof, roofs)


func _multimesh(mesh: Mesh, mat: Material, xfs: Array[Transform3D], colors: Array[Color] = []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if mat:
		mmi.material_override = mat
	add_child(mmi)
	return mmi


func _model(model: String, pos: Vector3, yaw := 0.0, parts: Array = [], size := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = Assets.mesh(model, parts, size)
	m.position = pos
	m.rotation.y = yaw
	add_child(m)
	return m


static func label(text: String, pos: Vector3, size := 48, color := Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.outline_size = 12
	l.modulate = color
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	return l


func _props() -> void:
	var metal := _flat(Color(0.22, 0.26, 0.3), 0.4, 0.8)
	# Lan can sau lối đi
	var posts: Array[Transform3D] = []
	for i in 81:
		posts.append(Transform3D(Basis.from_scale(Vector3(0.06, 1.0, 0.06)), Vector3(-80 + i * 2, 0.5, 15.2)))
	_multimesh(BoxMesh.new(), metal, posts)
	_box(Vector3(160, 0.06, 0.06), Vector3(0, 1.0, 15.2), metal)
	_box(Vector3(160, 0.04, 0.04), Vector3(0, 0.55, 15.2), metal)
	# Đèn đường
	for x in range(-36, 41, 12):
		_model("street_lamp_01", Vector3(x, 0, 14.8), PI)
	# Ranh giới công việc: rào bê tông trên bờ, phao trên sông
	for x in [Data.LEVEL.x0 - 0.6, Data.LEVEL.x1 + 0.6]:
		for z in [9.0, 10.6, 12.2, 13.8]:
			_model("concrete_road_barrier", Vector3(x, 0, z), PI / 2)
		for z in range(-5, 5, 2):
			var b := _model("ocean_buoy", Vector3(x, WATER_Y - 0.25, z), 0.0, [], 0.9)
			b.set_meta("bob", _rng.randf() * TAU)
			_ducks.append(b)
	# Biển khu vực
	for zone in Data.ZONES:
		if zone.id == "T":
			continue
		add_child(label(zone.name, Vector3(zone.x0 + 1.2, 2.3, 14.6), 56))
		_box(Vector3(0.08, 2.0, 0.08), Vector3(zone.x0 + 1.2, 1.0, 14.6), metal)
	# Phao cứu sinh, thùng rác, tủ điện cho đời sống phố
	_model("lifebuoy", Vector3(-12, 0.9, 15.15), PI)
	_model("utility_box_01", Vector3(14, 0, 14.7), PI)
	for x in [-20.0, 6.0, 30.0]:
		_model("metal_trash_can", Vector3(x, 0, 14.6), PI, ["metal_trash_can", "metal_trash_can_lid"])
	# Điểm nhận vật lớn
	var r: Vector2 = Data.LEVEL.receive
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.45; torus.outer_radius = 1.7
	ring.mesh = torus
	var green := _flat(Color(0.2, 0.9, 0.5))
	green.emission_enabled = true
	green.emission = Color(0.2, 0.9, 0.5)
	green.emission_energy_multiplier = 0.8
	ring.material_override = green
	ring.scale = Vector3(1, 0.1, 1)
	ring.position = Vector3(r.x, 0.03, r.y)
	add_child(ring)
	add_child(label("ĐIỂM NHẬN VẬT LỚN", Vector3(r.x, 2.0, r.y + 2.1), 56, Color(0.6, 1, 0.75)))


## Cảnh quan phục hồi: cây, bụi, hoa, ghế đá, vịt — xuất hiện sau nghiệm thu.
func _restoration() -> void:
	var bark := _flat(Color(0.35, 0.24, 0.16), 0.9)
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.28, 0.55, 0.22)
	leaf.roughness = 0.85
	for i in 30:
		var x := -78.0 + i * 5.3 + _rng.randf() * 2.0
		var z := 16.4 if i % 3 == 0 else 18.6
		if x > -27.0 and x < -5.0:
			continue # chừa chỗ cho góc máy chụp trước–sau
		var tree := Node3D.new()
		tree.position = Vector3(x, 0, z)
		var trunk := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.12; tm.bottom_radius = 0.2; tm.height = 2.2
		trunk.mesh = tm
		trunk.material_override = bark
		trunk.position.y = 1.1
		tree.add_child(trunk)
		for j in 4:
			var c := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = _rng.randf_range(0.8, 1.2); sm.height = sm.radius * 1.7
			c.mesh = sm
			c.material_override = leaf
			c.position = Vector3(_rng.randf_range(-0.6, 0.6), 2.6 + _rng.randf_range(0, 0.9), _rng.randf_range(-0.6, 0.6))
			tree.add_child(c)
		add_child(tree)
		_restore.append(tree)
	var plants := ["shrub_02", "shrub_03", "shrub_04", "flower_gazania", "celandine_01", "grass_medium_01"]
	for i in 90:
		var model: String = plants[i % plants.size()]
		var z := _rng.randf_range(6.1, 7.8) if i % 2 == 0 else _rng.randf_range(15.6, 20.0)
		var x := _rng.randf_range(Data.LEVEL.x0, Data.LEVEL.x1)
		if i % 2 == 0 and (_in_x(STEPS_A, x) or _in_x(APRON_D, x) or _in_x(DOCK, x)):
			continue
		var y := slope_y(z) if z < 8.0 else 0.02
		var m := _model(model, Vector3(x, y, z), _rng.randf() * TAU)
		m.scale = Vector3.ONE * (0.5 if model == "shrub_02" else 1.6)
		m.set_meta("s", m.scale.x)
		_restore.append(m)
	for x in [-30.0, -14.0, 12.0, 36.0]:
		var b := _model("painted_wooden_bench", Vector3(x, 0, 14.5), PI)
		b.set_meta("s", 1.0)
		_restore.append(b)
	var pt := _model("wooden_picnic_table", Vector3(-20, 0, 18), PI / 2)
	pt.set_meta("s", 1.0)
	_restore.append(pt)
	for i in 5:
		var d := _model("rubber_duck_toy", Vector3(-30 + i * 15, WATER_Y - 0.05, -1), 0.0, [], 0.45)
		d.set_meta("duck", Vector3(-30 + i * 15, 2.0 + _rng.randf() * 2.0, _rng.randf() * TAU))
		d.visible = false
		_ducks.append(d)
	# Bướm bay ven bờ sau phục hồi
	_butterflies = GPUParticles3D.new()
	_butterflies.amount = 60
	_butterflies.lifetime = 8.0
	_butterflies.visibility_aabb = AABB(Vector3(-45, -2, -6), Vector3(90, 8, 30))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(40, 1, 6)
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 2.0
	pm.initial_velocity_min = 0.2; pm.initial_velocity_max = 0.6
	pm.direction = Vector3(1, 0.3, 0); pm.spread = 180
	pm.color_ramp = _ramp([Color(1, 0.9, 0.3, 0), Color(1, 0.8, 0.2), Color(1, 0.5, 0.9), Color(1, 0.5, 0.9, 0)])
	_butterflies.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.08)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.vertex_color_use_as_albedo = true
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = qm
	_butterflies.draw_pass_1 = q
	_butterflies.position = Vector3(0, 1.2, 11)
	_butterflies.emitting = false
	add_child(_butterflies)
	_grow = -1.0
	set_grow(0.0)


static func _ramp(cols: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	for i in cols.size():
		offs.append(float(i) / (cols.size() - 1))
	g.offsets = offs
	g.colors = PackedColorArray(cols)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func set_grow(g: float) -> void:
	if absf(g - _grow) < 0.002:
		return
	_grow = g
	for i in _restore.size():
		var n := _restore[i]
		var s: float = n.get_meta("s", 1.0) * clampf(g * 1.4 - (i % 7) * 0.05, 0.0, 1.0)
		n.visible = s > 0.01
		n.scale = Vector3.ONE * maxf(s, 0.001)
	for d in _ducks:
		if d.has_meta("duck"):
			d.visible = g > 0.5
	_butterflies.emitting = g > 0.6


## clean: tỉ lệ rác đã gom, purity: tiến độ xử lý nước, grow: cảnh quan sau nghiệm thu.
func update_look(delta: float, clean: float, purity: float, grow: float, t: float) -> void:
	_bank_mat.set_shader_parameter("clean", clean)
	_water_mat.set_shader_parameter("purity", purity)
	_water_mat.set_shader_parameter("wave", 1.0 if Game.settings.water_fx else 0.0)
	env.fog_light_color = Color(0.62, 0.6, 0.5).lerp(Color(0.7, 0.8, 0.92), purity)
	env.fog_density = lerpf(0.012, 0.004, purity)
	env.adjustment_saturation = lerpf(0.75, 1.1, maxf(purity, grow))
	env.adjustment_brightness = lerpf(0.95, 1.03, purity)
	set_grow(grow)
	for d in _ducks:
		if d.has_meta("duck"):
			if not d.visible:
				continue
			var u: Vector3 = d.get_meta("duck")
			u.z += delta * 0.15
			d.set_meta("duck", u)
			d.position = Vector3(u.x + cos(u.z) * u.y, WATER_Y - 0.05, -1.0 + sin(u.z) * u.y * 0.6)
			d.rotation.y = -u.z
		elif Game.settings.water_fx:
			d.position.y = WATER_Y - 0.25 + sin(t * 1.4 + d.get_meta("bob")) * 0.06
