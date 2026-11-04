class_name Quests
extends Node3D
## Nhiệm vụ theo kịch bản tiến trình, chỉ dẫn lần đầu (mỗi lần một chỉ dẫn),
## cột sáng chỉ đường và điều kiện nghiệm thu.

const HINTS := {
	"start": "Nhắm vào rác trong tầm tay và nhấp chuột trái để nhặt. W A S D để đi, chuột để nhìn, Tab mở nhiệm vụ.",
	"full": "Giỏ đã đầy. Mang về bàn phân loại ở khu C (theo cột sáng) và bấm E.",
	"sort": "Chọn một cụm rác rồi bấm vào thùng đúng nhóm. Bấm vào món trong thùng để trả lại bàn nếu nhầm, rồi Xác nhận.",
	"net": "Vợt với xa hơn và vớt được rác trên mặt nước. Giữ chuột trái để vớt liên tục.",
	"buy": "Đồ đã mua nằm trong kho. Bấm B để vào chế độ đặt máy, nhắm vào khung xanh và nhấp chuột.",
	"build_mode": "Chế độ đặt máy: khung xanh là vị trí lắp hợp lệ, khung đỏ là máy có thể tháo về kho. Bấm B để thoát.",
	"conveyor": "Băng chuyền đã lắp. Bấm E tại máy để nạp giỏ; máy tự phân loại. Nhớ bấm Xử lý đầu ra để nhận tiền.",
	"hook": "Bạn nhận được Móc kéo (phím 3). Dọn đống rác quanh lốp xe tải cũ ở cửa xả, rồi nhắm và nhấp để móc.",
	"drag": "Đã móc lốp. Đi về Điểm nhận vật lớn (vòng xanh lá gần khu C): lốp nặng trượt theo sau, kéo nó vào trong vòng. Nhấp lần nữa để thả dây.",
	"flow": "Rác bị kẹt sau cửa xả đang trôi ra và dồn vào vùng xoáy ở khu E. Lắp máy vớt ở đó.",
	"skimmer": "Máy vớt gom rác vào thùng cạnh máy. Bấm E để lấy thùng, mang tới phễu băng chuyền.",
	"crate": "Bạn đang mang thùng máy vớt. Bấm E tại băng chuyền (Nạp) hoặc bàn phân loại để đổ.",
	"plant": "Công trình đang xử lý nguồn ô nhiễm – mặt nước sẽ trong dần.",
	"accept": "Đủ điều kiện nghiệm thu! Mở Tab → Nghiệm thu.",
	"automate": "Cửa hàng đã mở robot gom rác, máy hút rác và các nâng cấp tự động. Rác nhiều lắm – hãy để máy làm thay!",
	"heap": "Đống rác chất cao: phải dọn lớp trên mới lấy được lớp dưới. Nghe nói có đồ quý bị vùi dưới đáy vài đống…",
}

var trash: Trash
var machines: Machines
var beam: MeshInstance3D
var target = null # Vector2 hoặc null
var target_dist := 0

var _list: Array[Dictionary] = []
var _queue: Array = [] # [id, thời điểm]
var _showing := ""
var _timer := 0.0


func _s() -> Dictionary:
	return Game.state


static func zone_center(id: String) -> Vector2:
	for z in Data.ZONES:
		if z.id == id:
			return Vector2((z.x0 + z.x1) / 2.0, 11.0)
	return Vector2.ZERO


func _zone(id: String) -> Dictionary:
	return trash.zones[id]


func _ready() -> void:
	beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.25
	cyl.bottom_radius = 0.25
	cyl.height = 30.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	beam.mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.36, 0.95, 0.77, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	beam.material_override = m
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position.y = 14.0
	add_child(beam)

	var L: Dictionary = Data.LEVEL
	var s := _s
	_list = [
		{"id": "pick", "title": func(): return "Nhặt món rác đầu tiên", "at": func(): return zone_center("A"), "done": func(): return trash.collected_mass > 0},
		{"id": "dump", "req": ["pick"], "title": func(): return "Mang giỏ về bàn phân loại (khu C) và bấm E", "at": func(): return L.table, "done": func(): return s.call().stats.dumped > 0},
		{"id": "sort", "req": ["dump"], "title": func(): return "Phân loại và xử lý một mẻ", "at": func(): return L.table, "done": func(): return s.call().stats.manual_batches > 0},
		{"id": "buy_net", "req": ["sort"], "title": func(): return "Mua vợt (Tab → Cửa hàng)", "done": func(): return s.call().tools.net},
		{"id": "clear_a", "req": ["sort"], "title": func(): return "Dọn một nửa khu A (%d/%d)" % [_zone("A").done, ceili(_zone("A").total * 0.5)], "at": func(): return zone_center("A"), "done": func(): return _zone("A").done >= _zone("A").total * 0.5},
		{"id": "part_b", "req": ["buy_net"], "title": func(): return "Vớt 30%% rác khu B (%d/%d)" % [_zone("B").done, ceili(_zone("B").total * 0.3)], "at": func(): return zone_center("B"), "done": func(): return _zone("B").done >= _zone("B").total * 0.3},
		{"id": "belt", "req": ["clear_a", "part_b"], "title": func(): return "Lắp băng chuyền ở khu C (phím B)" if (s.call().stock.conveyor or s.call().placed.conveyor) else "Mua băng chuyền (Tab → Cửa hàng)", "at": func(): return L.slots.conveyor, "done": func(): return s.call().placed.conveyor},
		{"id": "auto", "req": ["belt"], "title": func(): return "Cho băng chuyền xử lý một mẻ tự động (%d/10)" % mini(10, s.call().stats.auto_items), "at": func(): return L.slots.conveyor, "done": func(): return s.call().stats.auto_items >= 10},
		{"id": "outfall", "req": ["auto"], "title": func(): return "Dọn cửa xả, kéo %s về điểm nhận" % L.obstacle_name, "at": func(): return L.receive if machines.hooked else L.obstacle, "done": func(): return s.call().obstacle.done, "start": _grant_hook},
		{"id": "skimmer", "req": ["outfall"], "title": func(): return "Lắp máy vớt ở khu E (phím B)" if (s.call().stock.skimmer or s.call().placed.skimmer) else "Mua máy vớt (Tab → Cửa hàng)", "at": func(): return L.slots.skimmer, "done": func(): return s.call().placed.skimmer},
		{"id": "plant", "req": ["outfall"], "title": func(): return "Xây công trình xử lý ở khu D (phím B)" if (s.call().stock.plant or s.call().placed.plant) else "Mua công trình xử lý nước thải (Tab → Cửa hàng)", "at": func(): return L.slots.plant, "done": func(): return s.call().placed.plant},
		{"id": "collect", "req": ["skimmer"], "title": func(): return "Thu gom ít nhất 90%% rác (%d%%)" % floori(trash.ratio * 100), "done": func(): return trash.ratio >= Data.ECON.accept_ratio},
		{"id": "queue", "req": ["collect"], "title": func(): return "Xử lý hết rác đang chờ (còn %d)" % Game.pending_count(), "at": func(): return L.table, "done": func(): return Game.pending_count() == 0},
		{"id": "accept", "req": ["queue", "plant"], "title": func(): return "Nghiệm thu công trình (Tab → Nghiệm thu)", "done": func(): return s.call().accepted},
	]


func _grant_hook() -> void:
	if _s().tools.hook:
		return
	_s().tools.hook = true
	Game.say("Nhận Móc kéo (phím 3) – dụng cụ bắt buộc được cấp miễn phí.", "good")
	hint("hook")


func _ready_for(q: Dictionary) -> bool:
	var done: Dictionary = _s().quests
	if done.get(q.id, false):
		return false
	for r in q.get("req", []):
		if not done.get(r, false):
			return false
	return true


## Hàng đợi chỉ dẫn: mỗi lần một chỉ dẫn, mỗi chỉ dẫn hiện một lần.
func hint(id: String) -> void:
	var s := _s()
	if s.is_empty() or s.hints.get(id, false) or _showing == id or not HINTS.has(id):
		return
	for q in _queue:
		if q[0] == id:
			return
	_queue.append([id, Time.get_ticks_msec()])


func dismiss_hint() -> void:
	_timer = 0.0


func reset() -> void:
	_queue.clear()
	_showing = ""


func conditions() -> Array:
	var s := _s()
	return [
		["Thu gom ≥ 90% khối lượng rác (hiện " + str(floori(trash.ratio * 100)) + "%)", trash.ratio >= Data.ECON.accept_ratio],
		["Xử lý vật cản bắt buộc ở cửa xả", s.obstacle.done],
		["Không còn rác chờ trong giỏ, thùng, bàn và dây chuyền (còn %d)" % Game.pending_count(), Game.pending_count() == 0],
		["Công trình xử lý nước thải đang hoạt động", s.placed.plant],
		["Hoàn thành nhiệm vụ chính: băng chuyền, mẻ tự động, máy vớt", s.placed.conveyor and s.stats.auto_items >= 10 and s.placed.skimmer],
	]


func can_accept() -> bool:
	if _s().accepted:
		return false
	for c in conditions():
		if not c[1]:
			return false
	return true


## Tối đa ba nhiệm vụ đang liên quan.
func active() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for q in _list:
		if _ready_for(q):
			out.append(q)
			if out.size() == 3:
				break
	return out


## Đánh dấu nhiệm vụ đầu tiên đang mở là xong (chế độ phát triển).
func skip_current() -> void:
	var a := active()
	if a.is_empty():
		return
	if a[0].id == "outfall":
		_s().obstacle.done = true
	_s().quests[a[0].id] = true
	Game.save_game()


## Kiểm tra hoàn thành; trả về chỉ dẫn đang hiện (hoặc chuỗi rỗng).
func update(delta: float, player_pos: Vector3) -> String:
	var s := _s()
	var changed := false
	for q in _list:
		if not _ready_for(q):
			continue
		if q.has("start"):
			q.start.call()
		if q.done.call():
			s.quests[q.id] = true
			changed = true
			if q.id != "pick":
				Game.say("Hoàn thành: " + q.title.call(), "good")
				Sfx.play("collect")
	if changed:
		Game.save_game()
	if can_accept():
		hint("accept")
	if s.quests.get("belt", false):
		hint("automate")
	if s.quests.get("sort", false):
		hint("heap")

	# Chỉ dẫn; chỉ dẫn chờ quá 15 giây đã lỗi thời nên bỏ qua
	if _showing != "":
		_timer -= delta
		if _timer <= 0.0:
			s.hints[_showing] = true
			_showing = ""
	var now := Time.get_ticks_msec()
	while not _queue.is_empty() and now - _queue[0][1] > 15000:
		_queue.pop_front()
	if _showing == "" and not _queue.is_empty():
		_showing = _queue.pop_front()[0]
		_timer = 5.0 if not _queue.is_empty() else 8.0

	# Chỉ đường: ưu tiên việc đang dở (đang mang thùng, giỏ đầy)
	target = null
	if not s.crate.is_empty():
		target = Data.LEVEL.slots.conveyor if s.placed.conveyor else Data.LEVEL.table
	elif Game.basket_load() >= Game.basket_cap():
		target = Data.LEVEL.table
	else:
		for q in active():
			if q.has("at"):
				target = q.at.call()
				break
	var dist := 0.0
	if target != null:
		dist = (target as Vector2).distance_to(Vector2(player_pos.x, player_pos.z))
		beam.position = Vector3(target.x, 14.0, target.y)
	beam.visible = Game.settings.guide and target != null and not s.accepted and dist > 3.0
	(beam.material_override as StandardMaterial3D).albedo_color.a = minf(0.35, dist / 40.0)
	target_dist = roundi(dist)
	return HINTS.get(_showing, "")
