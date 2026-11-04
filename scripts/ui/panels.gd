class_name Panels
extends Control
## Các bảng giao diện: menu, Tab (nhiệm vụ, cửa hàng, nghiệm thu, cài đặt), bàn phân loại,
## bảng máy, bản đồ chiến dịch, kết quả trước–sau và chế độ phát triển.

const TABS := {"quests": "Nhiệm vụ", "shop": "Cửa hàng", "accept": "Nghiệm thu", "settings": "Cài đặt"}

var main: Node
var current := ""
var rebinding := ""
var is_open: bool:
	get: return current != ""

var _dim: ColorRect
var _center: CenterContainer
var _left: MarginContainer
var _shade: TextureRect
var _render: Callable
var _layout: Control
var _refresh := 0.0
var _timer := 0.0
var _confirm_new := false
var _tab := "quests"
var _sort := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Style.theme()
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	# Dải tối bên trái làm nền cho menu chính
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.01, 0.04, 0.05, 0.92), Color(0.01, 0.04, 0.05, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 4
	_shade = TextureRect.new()
	_shade.texture = gt
	_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shade.stretch_mode = TextureRect.STRETCH_SCALE
	_shade.custom_minimum_size.x = 820
	_shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	add_child(_shade)
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_center)
	_left = MarginContainer.new()
	_left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_left.add_theme_constant_override("margin_left", 72)
	add_child(_left)
	visible = false


func _process(delta: float) -> void:
	if _refresh > 0.0 and is_open:
		_timer -= delta
		if _timer <= 0.0:
			_timer = _refresh
			_draw_panel()


func _input(e: InputEvent) -> void:
	if rebinding == "" or not (e is InputEventKey) or not e.pressed:
		return
	get_viewport().set_input_as_handled()
	if e.keycode != KEY_ESCAPE:
		Game.settings.keys[rebinding] = e.physical_keycode
		Game.apply_keys()
		Game.save_settings()
	rebinding = ""
	redraw()


# ---------- Khung chung ----------
func _open(name: String, render: Callable, refresh := 0.0, left := false) -> void:
	close(false)
	current = name
	_render = render
	_refresh = refresh
	_timer = refresh
	_layout = _left if left else _center
	_dim.color = Color(0.02, 0.05, 0.06, 0.0 if left else 0.55)
	_shade.visible = left
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_draw_panel()


func _clear() -> void:
	for box in [_center, _left]:
		for c in box.get_children():
			box.remove_child(c)
			c.queue_free()


func _draw_panel() -> void:
	_clear()
	if is_open:
		_layout.add_child(_render.call())


func redraw() -> void:
	_draw_panel.call_deferred()


func close(resume := true) -> void:
	if not is_open:
		return
	current = ""
	rebinding = ""
	_refresh = 0.0
	visible = false
	_clear()
	if resume:
		main.resume()


## Nút làm mới bảng sau khi chạy hành động.
func _btn(text: String, fn: Callable, primary := false, disabled := false) -> Button:
	return Style.button(text, func():
		fn.call()
		redraw(), primary, disabled)


func _frame(title: String, content: Control, width := 760.0, on_x := Callable()) -> PanelContainer:
	var head := Style.hbox([], 12)
	var t := Style.label(title, 24)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(Style.button("×", on_x if on_x.is_valid() else close.bind(true)))
	var v := Style.vbox([head, _sep(), content], 12)
	var p := Style.panel(v, Style.box(Style.BG_SOLID, 16, 22, Style.LINE, 1))
	p.custom_minimum_size.x = width
	return p


func _sep() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_stylebox_override("separator", Style.box(Style.LINE, 0, 0))
	s.add_theme_constant_override("separation", 2)
	return s


func _scroll(content: Control, height: float) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size.y = height
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	return sc


func _grid(rows: Array, cols := 2) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 24)
	g.add_theme_constant_override("v_separation", 6)
	for r in rows:
		for i in r.size():
			var c = r[i]
			if c is Control:
				g.add_child(c)
			else:
				g.add_child(Style.label(str(c), 0, Style.MUTED if i == 0 else Style.TEXT))
	return g


# ---------- Menu chính / tạm dừng ----------
func menu() -> void:
	_confirm_new = false
	_open("menu", _menu_view, 0.0, true)


func _menu_view() -> Control:
	var has_main := Game.has_save("main")
	var running: bool = main.running
	var saved: Dictionary = Game.state if running and Game.state.slot == "main" else Game.load_game("main")
	var done: bool = saved.get("accepted", false)
	var v := Style.vbox([], 12)
	v.custom_minimum_size.x = 420
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var title := Style.label("Dòng Nước Xanh", 64, Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.2, 0.18))
	title.add_theme_constant_override("outline_size", 12)
	v.add_child(title)
	v.add_child(Style.label("Bản chơi thử · Màn 1: " + Data.LEVEL.name, 20, Style.ACCENT.lightened(0.3)))
	v.add_child(Control.new())
	if running:
		v.add_child(_btn("Tiếp tục chơi", close.bind(true), true))
	elif has_main:
		v.add_child(_btn("Tiếp tục", func(): close(false); main.start("main", false), true))
	v.add_child(_btn("Bấm lần nữa để xóa tiến độ cũ" if _confirm_new else "Chơi mới", func():
		if (has_main or running) and not _confirm_new:
			_confirm_new = true
			return
		close(false)
		main.start("main", true), not (has_main or running)))
	if done:
		v.add_child(_btn("Chơi lại màn (tiến độ riêng)", func(): close(false); main.start("replay", true)))
	v.add_child(_btn("Bản đồ chiến dịch", campaign))
	v.add_child(_btn("Cài đặt", tab.bind("settings")))
	if not running:
		v.add_child(_btn("Thoát", func(): get_tree().quit()))
	var k := func(a): return Game.key_name(a)
	var help := Style.label("Điều khiển: %s %s %s %s đi · Chuột nhìn · Chuột trái nhặt/dùng dụng cụ (giữ để vớt liên tục) · %s tương tác · 1/2/3 hoặc con lăn đổi dụng cụ · %s nhiệm vụ & nâng cấp · %s đặt máy · Esc tạm dừng" % [
		k.call("forward"), k.call("left"), k.call("back"), k.call("right"), k.call("interact"), k.call("menu"), k.call("build")], 14, Style.MUTED, true)
	help.custom_minimum_size.x = 420
	v.add_child(Control.new())
	v.add_child(Style.panel(help, Style.box(Color(0, 0, 0, 0.45), 10, 12)))
	return v


# ---------- Tab: nhiệm vụ, cửa hàng, nghiệm thu, cài đặt ----------
func tab(which := "quests") -> void:
	_tab = which if main.running else "settings"
	_open("tab", _tab_view, 0.5 if _tab in ["quests", "accept"] else 0.0)


func _tab_view() -> Control:
	var running: bool = main.running
	var nav := Style.hbox([], 6)
	for k in TABS:
		if not running and k != "settings":
			continue
		var b := Style.button(TABS[k], tab.bind(k), k == _tab)
		nav.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(spacer)
	nav.add_child(Style.button("×", close.bind(true) if running else menu))
	var body: Control = {"quests": _quests_tab, "shop": _shop_tab, "accept": _accept_tab, "settings": _settings_tab}[_tab].call()
	var p := Style.panel(Style.vbox([nav, _sep(), _scroll(body, 560)], 12), Style.box(Style.BG_SOLID, 16, 22, Style.LINE, 1))
	p.custom_minimum_size.x = 940
	return p


func _h(text: String) -> Label:
	return Style.label(text.to_upper(), 14, Style.ACCENT)


func _quests_tab() -> Control:
	var s := Game.state
	var v := Style.vbox([_h("Đang làm")], 8)
	var act: Array = main.quests.active()
	for q in act:
		v.add_child(Style.label("› " + q.title.call(), 18))
	if act.is_empty():
		v.add_child(Style.label("Không còn nhiệm vụ.", 0, Style.MUTED))
	var stock := []
	for k in s.stock:
		if s.stock[k]:
			stock.append(Data.SHOP[k].name)
	if not stock.is_empty():
		v.add_child(_h("Trong kho"))
		v.add_child(Style.label("%s – bấm %s để đặt tại vị trí lắp." % [", ".join(stock), Game.key_name("build")], 0, Style.TEXT, true))
	v.add_child(_h("Tiến độ từng khu"))
	var rows := []
	for z in Data.ZONES:
		var st: Dictionary = main.trash.zones[z.id]
		var b := Style.bar(float(st.done) / st.total, Style.GOOD if st.done >= st.total else Style.ACCENT, 10)
		b.custom_minimum_size.x = 260
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rows.append([z.name, "%d/%d" % [st.done, st.total], b])
	v.add_child(_grid(rows, 3))
	v.add_child(Style.label("Đã xử lý %d món · %d mẻ thủ công · %d món qua băng chuyền · %d phút chơi" % [s.stats.processed, s.stats.manual_batches, s.stats.auto_items, roundi(s.time / 60.0)], 14, Style.MUTED))
	return v


func _shop_lock(it: Dictionary) -> String:
	var s := Game.state
	if it.get("unlock") == "outfall" and not s.obstacle.done:
		return "Mở sau khi kéo vật cản khỏi cửa xả"
	if it.get("unlock") == "skimmer" and not s.quests.get("skimmer", false):
		return "Mở sau khi lắp máy vớt"
	if it.get("unlock") == "belt" and not s.quests.get("belt", false):
		return "Mở sau khi lắp băng chuyền"
	return ""


func _shop_tab() -> Control:
	var s := Game.state
	var v := Style.vbox([Style.label("Dụng cụ và nâng cấp thuộc đội, mang sang màn sau. Máy và công trình là hạ tầng, ở lại hiện trường. Được hoàn trả toàn bộ giá máy chưa lắp khi màn chưa nghiệm thu.", 14, Style.MUTED, true)], 8)
	for k in Data.SHOP:
		var it: Dictionary = Data.SHOP[k]
		var lock := _shop_lock(it)
		var owned: bool
		match it.kind:
			"tool": owned = s.tools[k]
			"upgrade": owned = s.upgrades[k]
			"fleet": owned = s.robots.size() >= it.max
			_: owned = s.placed[k] or s.stock[k]
		var title: String = it.name + ((" (%d/%d)" % [s.robots.size(), it.max]) if it.kind == "fleet" else "")
		var info := Style.vbox([
			Style.hbox([Style.label(title, 18), Style.label("Hạ tầng" if it.kind == "machine" else "Thuộc đội", 12, Style.ACCENT)]),
			Style.label(it.desc, 14, Style.MUTED, true)], 4)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var price := Style.label("%d tiền%s" % [it.price, (" + %s vật liệu" % Game.fmt_mat(it.mat)) if it.mat > 0 else ""], 15, Color("#ffd166"))
		price.custom_minimum_size.x = 170
		var act: Control
		if lock != "":
			act = Style.label("Khóa: " + lock, 13, Style.MUTED, true)
		elif it.kind == "machine" and s.placed[k]:
			act = Style.label("Đã lắp", 15, Style.GOOD)
		elif it.kind == "machine" and s.stock[k]:
			act = Style.vbox([Style.label("Trong kho – bấm %s để đặt" % Game.key_name("build"), 13, Style.GOOD, true)], 4)
			if not s.accepted:
				act.add_child(_btn("Hoàn trả", _refund.bind(k)))
		elif owned:
			act = Style.label("Đã có", 15, Style.GOOD)
		else:
			act = _btn("Mua", _buy.bind(k), true, not Game.can_afford(it.price, it.mat))
		act.custom_minimum_size.x = 190
		var row := Style.hbox([info, price, act], 16)
		var p := Style.panel(row, Style.box(Color(1, 1, 1, 0.04), 10, 12))
		p.modulate.a = 0.55 if lock != "" else 1.0
		v.add_child(p)
	return v


func _buy(k: String) -> void:
	var it: Dictionary = Data.SHOP[k]
	var s := Game.state
	if not Game.spend(it.price, it.mat):
		Sfx.play("error")
		Game.say("Chưa đủ tiền hoặc vật liệu.", "warn")
		return
	match it.kind:
		"tool":
			s.tools[k] = true
			s.tool = k
		"upgrade":
			s.upgrades[k] = true
		"fleet":
			main.robots.add_robot()
		_:
			s.stock[k] = true
			Game.show_hint("buy")
	Game.save_game()
	Sfx.play("coin")
	Game.say("Đã mua %s." % it.name, "good")


func _refund(k: String) -> void:
	var it: Dictionary = Data.SHOP[k]
	var s := Game.state
	if not s.stock[k] or s.accepted:
		return
	s.stock[k] = false
	s.money += it.price
	s.mat += it.mat
	Game.save_game()
	Game.say("Đã hoàn trả %s: +%d tiền." % [it.name, it.price])


func _accept_tab() -> Control:
	var s := Game.state
	var v := Style.vbox([], 10)
	if s.accepted:
		v.add_child(Style.label("Công trình đã nghiệm thu.", 26, Style.GOOD))
		v.add_child(Style.hbox([_btn("Xem trước và sau", results, true), _btn("Bản đồ chiến dịch", campaign)]))
		return v
	v.add_child(Style.label("Nút nghiệm thu chỉ bật khi đủ mọi điều kiện. Dọn 100% và tìm đồ sưu tầm là mục tiêu tự chọn.", 0, Style.TEXT, true))
	for c in main.quests.conditions():
		var l := Style.label(("[x]  " if c[1] else "[  ]  ") + c[0], 17, Style.GOOD if c[1] else Style.MUTED, true)
		v.add_child(l)
	var b := _btn("Nghiệm thu công trình", func(): close(false); main.accept(), true, not main.quests.can_accept())
	b.custom_minimum_size = Vector2(320, 52)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(b)
	v.add_child(Style.label("Thưởng nghiệm thu: %d tiền + %s vật liệu%s." % [Data.ECON.accept_bonus_money, Game.fmt_mat(Data.ECON.accept_bonus_mat), " (chế độ chơi lại không cộng thưởng chiến dịch)" if s.slot == "replay" else ""], 14, Style.MUTED, true))
	return v


func _settings_tab() -> Control:
	var st := Game.settings
	var v := Style.vbox([], 10)
	for row in [["sens", "Độ nhạy chuột", 0.2, 3.0, 0.1], ["fov", "Góc nhìn (FOV)", 65.0, 105.0, 1.0], ["volume", "Âm lượng", 0.0, 1.0, 0.05]]:
		var sl := HSlider.new()
		sl.min_value = row[2]
		sl.max_value = row[3]
		sl.step = row[4]
		sl.value = st[row[0]]
		sl.custom_minimum_size = Vector2(320, 24)
		sl.focus_mode = Control.FOCUS_NONE
		var fmt := "%.0f°" if row[4] >= 1.0 else "%.2f"
		var val := Style.label(fmt % st[row[0]], 0, Style.MUTED)
		sl.value_changed.connect(func(x):
			st[row[0]] = x
			val.text = fmt % x
			if row[0] == "volume":
				Sfx.set_volume(x)
			Game.save_settings())
		var name := Style.label(row[1])
		name.custom_minimum_size.x = 220
		v.add_child(Style.hbox([name, sl, val], 16))
	for row in [["head_bob", "Nhún camera khi đi (có thể gây chóng mặt)"], ["water_fx", "Hiệu ứng mặt nước"], ["guide", "Cột sáng chỉ đường nhiệm vụ"], ["shadows", "Đổ bóng"]]:
		var cb := CheckButton.new()
		cb.text = row[1]
		cb.button_pressed = st[row[0]]
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(func(on):
			st[row[0]] = on
			Game.save_settings()
			main.apply_settings())
		v.add_child(cb)
	v.add_child(_h("Gán phím"))
	var rows := []
	for a in Data.ACTIONS:
		var b := _btn("Nhấn phím… (Esc hủy)" if rebinding == a else Game.key_name(a), func(): rebinding = a)
		b.custom_minimum_size.x = 220
		rows.append([Data.ACTIONS[a][0], b])
	v.add_child(_grid(rows, 2))
	v.add_child(_btn("Khôi phục mặc định", func():
		for a in Data.ACTIONS:
			st.keys[a] = Data.ACTIONS[a][1]
		Game.apply_keys()
		Game.save_settings()))
	v.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return v


# ---------- Bàn phân loại ----------
func sort() -> void:
	_sort = {"assigned": {"plastic": [], "metal": [], "other": []}, "selected": -1, "wrong": []}
	Game.show_hint("sort")
	_open("sort", _sort_view)


func _sort_rest() -> Array:
	var out := []
	for i in Game.state.table.size():
		var used := false
		for c in Data.CAT_KEYS:
			if _sort.assigned[c].has(i):
				used = true
		if not used:
			out.append(i)
	return out


func _groups(idx: Array) -> Dictionary:
	var g := {}
	for i in idx:
		var t: int = Game.state.table[i]
		if not g.has(t):
			g[t] = []
		g[t].append(i)
	return g


func _chip(t: int, n: int, fn: Callable, selected := false, wrong := false) -> Button:
	var b := _btn("%s ×%d" % [Data.TRASH[t].name, n], fn)
	b.icon = Style.thumbs.get(t)
	b.add_theme_constant_override("icon_max_width", 34)
	if selected or wrong:
		var col := Style.ACCENT if selected else Style.BAD
		b.add_theme_stylebox_override("normal", Style.box(col.darkened(0.6), 8, 8, col, 2))
		b.add_theme_stylebox_override("hover", Style.box(col.darkened(0.5), 8, 8, col, 2))
	return b


func _drop(c: String) -> void:
	var sel: int = _sort.selected
	if sel < 0:
		return
	for i in _sort_rest():
		if Game.state.table[i] == sel:
			_sort.assigned[c].append(i)
	_sort.wrong.erase(sel)
	_sort.selected = -1
	Sfx.play("plastic")


func _sort_view() -> Control:
	var s := Game.state
	var rest := _sort_rest()
	var v := Style.vbox([Style.label("Chọn một cụm cùng loại rồi bấm vào thùng. Bấm vào cụm trong thùng để trả lại bàn. Không bị trừ tiền khi phân nhầm.", 14, Style.MUTED, true)], 14)
	var table := HFlowContainer.new()
	var g := _groups(rest)
	for t in g:
		table.add_child(_chip(t, g[t].size(), func(): _sort.selected = -1 if _sort.selected == t else t, _sort.selected == t, _sort.wrong.has(t)))
	if g.is_empty():
		table.add_child(Style.label("Bàn đã trống – bấm Xác nhận xử lý.", 0, Style.MUTED))
	v.add_child(Style.panel(table, Style.box(Color(0.35, 0.25, 0.15, 0.35), 10, 14)))

	var bins := Style.hbox([], 12)
	for c in Data.CAT_KEYS:
		var col: Color = Data.CATS[c].color
		var ex := []
		for d in Data.TRASH:
			if d.cat == c:
				ex.append(d.name.to_lower())
		var inner := Style.vbox([Style.label(Data.CATS[c].name.to_upper(), 20, col.lightened(0.35)), Style.label(", ".join(ex), 12, Style.MUTED, true)], 8)
		var chips := HFlowContainer.new()
		chips.mouse_filter = Control.MOUSE_FILTER_PASS
		inner.mouse_filter = Control.MOUSE_FILTER_PASS
		var bg := _groups(_sort.assigned[c])
		for t in bg:
			chips.add_child(_chip(t, bg[t].size(), func():
				if _sort.selected >= 0:
					_drop(c)
				else:
					_sort.assigned[c] = _sort.assigned[c].filter(func(i): return s.table[i] != t)))
		inner.add_child(chips)
		var armed: bool = _sort.selected >= 0
		var p := Style.panel(inner, Style.box(col.darkened(0.75 if not armed else 0.6), 12, 14, col, 3 if armed else 1))
		p.custom_minimum_size = Vector2(0, 220)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if armed else Control.CURSOR_ARROW
		p.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and _sort.selected >= 0:
				_drop(c)
				redraw())
		bins.add_child(p)
	v.add_child(bins)

	var val := Game.value_of(s.table)
	var ok := _btn("Xác nhận xử lý (%d món · %d tiền)" % [s.table.size(), val.x], _confirm_sort, true, not rest.is_empty() or s.table.is_empty())
	v.add_child(Style.hbox([ok, _btn("Để lại trên bàn", close.bind(true))], 10))
	return _frame("Bàn phân loại", v, 980)


func _confirm_sort() -> void:
	var s := Game.state
	var good := []
	var bad := []
	for c in Data.CAT_KEYS:
		for i in _sort.assigned[c]:
			var t: int = s.table[i]
			(good if Data.TRASH[t].cat == c else bad).append(t)
	# Giao dịch: thay bàn bằng phần sai và cấp thưởng cho phần đúng trong cùng một bước rồi lưu.
	s.table = bad
	var r := Game.process_batch(good, false) if not good.is_empty() else Vector2i.ZERO
	for c in Data.CAT_KEYS:
		_sort.assigned[c] = []
	_sort.wrong = bad.duplicate()
	if not good.is_empty():
		Sfx.play("coin")
		Game.say("Xử lý %d món: +%d tiền, +%s vật liệu" % [good.size(), r.x, Game.fmt_mat(r.y)], "good")
	if not bad.is_empty():
		Sfx.play("error")
		Game.save_game()
		Game.say("%d món bị phân nhầm đã được trả lại bàn. Thử lại nhé!" % bad.size(), "warn")
	else:
		close()


# ---------- Bảng máy ----------
func machine(k: String) -> void:
	_open("machine", _machine_view.bind(k), 0.3)


func _machine_view(k: String) -> Control:
	var i: Dictionary = main.machines.info(k)
	var col: Color = Hud.STATE_COLORS.get(i.key, Style.MUTED)
	var v := Style.vbox([Style.panel(Style.label(i.state, 18, col), Style.box(col.darkened(0.7), 8, 10, col, 1))], 12)
	if not i.cause.is_empty():
		v.add_child(Style.label("Nguyên nhân: " + i.cause[0], 0, Style.TEXT, true))
		v.add_child(Style.label("Cách khắc phục: " + i.cause[1], 0, Style.ACCENT.lightened(0.3), true))
	v.add_child(_grid(i.rows, 2))
	var acts := Style.hbox([], 10)
	for a in i.actions:
		acts.add_child(_btn(a.label, a.fn, a.get("primary", false), a.get("disabled", false)))
	v.add_child(acts)
	return _frame(i.title, v, 620)


# ---------- Bản đồ chiến dịch ----------
func campaign() -> void:
	_open("campaign", _campaign_view)


func _campaign_view() -> Control:
	var running: bool = main.running
	var saved: Dictionary = Game.state if running else Game.load_game("main")
	var c: Dictionary = saved.get("campaign", {"done": [], "unlocked": ["tolich"]})
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for i in Data.CAMPAIGN.size():
		var m: Dictionary = Data.CAMPAIGN[i]
		var done: bool = c.done.has(m.id)
		var unlocked: bool = c.unlocked.has(m.id) or i == 0
		var status := "Đã nghiệm thu" if done else (("Đang chơi" if i == 0 else "Đã mở – chưa có trong bản thử") if unlocked else "Khóa – nghiệm thu màn trước")
		var col := Style.GOOD if done else (Style.ACCENT if unlocked else Style.MUTED)
		var b := _btn("%d. %s\n%s\n%s" % [i + 1, m.name, m.mech, status], _go.bind(m.id, c))
		b.custom_minimum_size = Vector2(205, 120)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_stylebox_override("normal", Style.box(col.darkened(0.75), 12, 12, col, 2 if unlocked else 1))
		b.modulate.a = 1.0 if unlocked else 0.6
		grid.add_child(b)
	return _frame("Bản đồ chiến dịch", grid, 900, close.bind(true) if running else menu)


func _go(id: String, c: Dictionary) -> void:
	if id != "tolich":
		Game.say("Màn này đã mở khóa nhưng chưa được triển khai trong bản chơi thử." if c.unlocked.has(id) else "Màn này chưa mở khóa.")
		return
	if main.running:
		close()
	else:
		close(false)
		main.start("main", not Game.has_save("main"))


# ---------- Kết quả nghiệm thu ----------
func results() -> void:
	_open("results", _results_view)


func _photo(which: String) -> Control:
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(440, 248)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var img := Image.load_from_file(Game.image_path(Game.state.slot, which)) if FileAccess.file_exists(Game.image_path(Game.state.slot, which)) else null
	if img:
		tr.texture = ImageTexture.create_from_image(img)
	var cap := Style.label("TRƯỚC" if which == "before" else "SAU", 16, Style.ACCENT)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return Style.vbox([Style.panel(tr, Style.box(Color(0, 0, 0, 0.4), 10, 4)), cap], 6)


func _results_view() -> Control:
	var s := Game.state
	var v := Style.vbox([Style.hbox([_photo("before"), _photo("after")], 16)], 14)
	v.add_child(_grid([
		["Rác đã thu gom", "%d%%" % floori(main.trash.ratio * 100)],
		["Tổng rác đã xử lý", "%d món" % s.stats.processed],
		["Tiền dịch vụ đã nhận", str(s.stats.earned)],
		["Thưởng nghiệm thu", "Không áp dụng (chơi lại)" if s.slot == "replay" else "%d tiền + %s vật liệu" % [Data.ECON.accept_bonus_money, Game.fmt_mat(Data.ECON.accept_bonus_mat)]],
		["Đồ sưu tầm", "%d/%d" % [s.collectibles.size(), Data.COLLECTIBLES.size()]],
		["Thời gian", "%d phút" % roundi(s.time / 60.0)],
	], 2))
	v.add_child(Style.label("Hồ thành phố đã mở trên bản đồ chiến dịch.", 0, Style.GOOD))
	v.add_child(Style.hbox([_btn("Bản đồ chiến dịch", campaign, true), _btn("Dạo bờ sông đã sạch", close.bind(true))], 10))
	return _frame("Nghiệm thu: " + Data.LEVEL.name, v, 920)


# ---------- Chế độ phát triển ----------
func dev() -> void:
	_open("dev", _dev_view)


func _dev_view() -> Control:
	var v := Style.vbox([Style.label("Dữ liệu thử lưu ở khe riêng, không ảnh hưởng tiến độ người chơi.", 14, Style.MUTED, true)], 10)
	v.add_child(_btn("+1000 tiền, +20 vật liệu", main.dev_money))
	v.add_child(_btn("Mở mọi công cụ", main.dev_tools))
	v.add_child(_btn("Tốc độ máy: x%d" % main.machines.dev_speed, main.dev_speed))
	v.add_child(_btn(("Ẩn" if main.dev_markers else "Hiện") + " rác còn sót", main.dev_toggle_markers))
	v.add_child(_btn("Hoàn thành nhiệm vụ hiện tại", main.quests.skip_current))
	var tp := Style.hbox([], 6)
	for z in Data.ZONES:
		if z.id != "T":
			tp.add_child(_btn("Khu " + z.id, main.dev_tp.bind(z.id)))
	v.add_child(tp)
	return _frame("Chế độ phát triển", v, 520)
