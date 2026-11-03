class_name Assets
## Nạp asset Poly Haven (CC0): gộp các mảnh mô hình thành một Mesh (dùng cho MultiMesh),
## chuẩn hóa kích thước, và tạo vật liệu PBR từ bộ vân bề mặt.

static var _meshes := {}
static var _mats := {}


static func scene(model: String) -> Node3D:
	return (load("res://assets/models/%s/%s.gltf" % [model, model]) as PackedScene).instantiate()


## Gộp mọi mảnh (hoặc các mảnh trong parts) thành một Mesh, đáy đặt ở y = 0, tâm ở gốc.
## size > 0: co giãn để cạnh dài nhất bằng size; size = 0 giữ kích thước thật.
static func mesh(model: String, parts: Array = [], size := 0.0) -> ArrayMesh:
	var key := "%s|%s|%s" % [model, parts, size]
	if _meshes.has(key):
		return _meshes[key]
	var root := scene(model)
	var found: Array[MeshInstance3D] = []
	_collect(root, Transform3D.IDENTITY, found)
	var aabb := AABB()
	var first := true
	for mi in found:
		if parts.is_empty() or parts.has(String(mi.name)):
			var a: AABB = mi.get_meta("xf") * mi.mesh.get_aabb()
			aabb = a if first else aabb.merge(a)
			first = false
	var k := 1.0 if size <= 0.0 else size / maxf(aabb.size[aabb.get_longest_axis_index()], 0.001)
	var norm := Transform3D(Basis.from_scale(Vector3.ONE * k), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -Vector3(aabb.get_center().x, aabb.position.y, aabb.get_center().z))
	var out := ArrayMesh.new()
	for mi in found:
		if not (parts.is_empty() or parts.has(String(mi.name))):
			continue
		var xf: Transform3D = norm * mi.get_meta("xf")
		for s in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for i in v.size():
				v[i] = xf * v[i]
			arr[Mesh.ARRAY_VERTEX] = v
			if arr[Mesh.ARRAY_NORMAL] != null:
				var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
				for i in n.size():
					n[i] = (xf.basis * n[i]).normalized()
				arr[Mesh.ARRAY_NORMAL] = n
			if arr[Mesh.ARRAY_TANGENT] != null:
				var tg: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT]
				for i in range(0, tg.size(), 4):
					var t := (xf.basis * Vector3(tg[i], tg[i + 1], tg[i + 2])).normalized()
					tg[i] = t.x; tg[i + 1] = t.y; tg[i + 2] = t.z
				arr[Mesh.ARRAY_TANGENT] = tg
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var m := mi.get_surface_override_material(s)
			out.surface_set_material(out.get_surface_count() - 1, m if m else mi.mesh.surface_get_material(s))
	root.free()
	_meshes[key] = out
	return out


static func _collect(n: Node, xf: Transform3D, out: Array[MeshInstance3D]) -> void:
	var here: Transform3D = xf * n.transform if n is Node3D else xf
	if n is MeshInstance3D and n.mesh:
		n.set_meta("xf", here)
		out.append(n)
	for c in n.get_children():
		_collect(c, here, out)


## Vật liệu PBR (ORM = AO, độ nhám, kim loại) từ assets/textures/<tên>.
static func pbr(tex: String, uv := Vector3.ONE, tint := Color.WHITE) -> ORMMaterial3D:
	var key := "%s|%s|%s" % [tex, uv, tint]
	if _mats.has(key):
		return _mats[key]
	var base := "res://assets/textures/%s/%s_" % [tex, tex]
	var m := ORMMaterial3D.new()
	m.albedo_texture = load(base + "diff.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(base + "nor.jpg")
	m.orm_texture = load(base + "arm.jpg")
	m.uv1_scale = uv
	m.uv1_triplanar = false
	_mats[key] = m
	return m
