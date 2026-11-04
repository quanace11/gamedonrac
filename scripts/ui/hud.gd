class_name Hud
extends Control
## HUD trong lúc chơi: tâm ngắm, nhiệm vụ, tiền, bảng công trình, thẻ máy, thanh dụng cụ, chỉ dẫn, thông báo.

const KIND_COLORS := {"info": Style.ACCENT, "good": Style.GOOD, "warn": Style.WARN}
const STATE_COLORS := {"running": Style.GOOD, "idle": Style.MUTED, "starved": Style.WARN, "full": Style.BAD, "paused": Style.MUTED, "done": Style.GOOD}

var main: Node

var _aim: Label
var _cross: Control
var _interact: Label
var _quests: Array[Label] = []
var _quest_box: PanelContainer
var _money: Label
var _mat: Label
var _gems: Label
var _slot_tag: Label
var _site_bar: ProgressBar
var _site_pct: Label
var _site_pending: Label
var _site_pollution: Label
var _cards := {}
var _tools: Array[PanelContainer] = []
var _tool_labels: Array[Label] = []
var _basket: Label
var _cells: Array[ColorRect] = []
var _crate: Label
var _hint: PanelContainer
var _hint_label: Label
var _toasts: VBoxContainer
var _build_bar: PanelContainer
var _last_hint := ""
var _slot_on: StyleBoxFlat
var _slot_off: StyleBoxFlat
var _slot_locked: StyleBoxFlat


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Style.theme()

	# Tâm ngắm
	_cross = Control.new()
	_cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_cross.draw.connect(func():
		_cross.draw_circle(Vector2.ZERO, 3.5, Color(0, 0, 0, 0.5))
		_cross.draw_circle(Vector2.ZERO, 2.2, Color.WHITE))
	add_child(_cross)
	_aim = _centered_label(Vector2(0, 26), 18)
	_interact = _centered_label(Vector2(0, 58), 18)
	_interact.add_theme_color_override("font_color", Style.ACCENT.lightened(0.3))

	# Nhiệm vụ (trên trái)
	var qv := Style.vbox([Style.label("NHIỆM VỤ", 13, Style.ACCENT)], 6)
	for i in 3:
		var l := Style.label("", 16, Style.TEXT, true)
		l.custom_minimum_size.x = 340
		qv.add_child(l)
		_quests.append(l)
	_quest_box = Style.panel(qv)
	_pin(_quest_box, Control.PRESET_TOP_LEFT, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_END)
	add_child(_quest_box)

	# Tiền, công trình, máy (trên phải)
	var right := Style.vbox([], 10)
	_pin(right, Control.PRESET_TOP_RIGHT, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)
	right.custom_minimum_size.x = 300
	add_child(right)
	_money = Style.label("", 20, Color("#ffd166"))
	_mat = Style.label("", 20, Color("#cdb4db"))
	_gems = Style.label("", 16, Style.MUTED)
	_slot_tag = Style.label("", 13, Style.WARN)
	right.add_child(Style.panel(Style.hbox([_money, _mat, _gems, _slot_tag], 16)))
	_site_bar = Style.bar(0.0, Style.ACCENT, 12)
	var mark := ColorRect.new()
	mark.color = Color.WHITE
	mark.size = Vector2(2, 16)
	mark.position.y = -2
	_site_bar.add_child(mark)
	_site_bar.resized.connect(func(): mark.position.x = _site_bar.size.x * Data.ECON.accept_ratio)
	_site_pct = Style.label("")
	_site_pending = Style.label("")
	_site_pollution = Style.label("")
	right.add_child(Style.panel(Style.vbox([Style.label("CÔNG TRÌNH", 13, Style.ACCENT), _site_bar, _site_pct, _site_pending, _site_pollution], 5)))
	for k in ["conveyor", "skimmer", "robots"]:
		var l := Style.label("", 15, Style.TEXT, true)
		var p := Style.panel(l, Style.box(Style.BG, 10, 10))
		p.visible = false
		right.add_child(p)
		_cards[k] = [p, l]

	# Thanh dụng cụ và giỏ (dưới giữa)
	_slot_on = Style.box(Style.ACCENT.darkened(0.6), 10, 10, Style.ACCENT, 2)
	_slot_off = Style.box(Style.BG, 10, 10, Style.LINE, 2)
	_slot_locked = Style.box(Color(0, 0, 0, 0.4), 10, 10, Color.TRANSPARENT, 2)
	var bottom := Style.vbox([], 10)
	_pin(bottom, Control.PRESET_CENTER_BOTTOM, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	add_child(bottom)
	_hint_label = Style.label("", 17, Style.TEXT, true)
	_hint_label.custom_minimum_size.x = 640
	_hint = Style.panel(_hint_label, Style.box(Color(0.1, 0.25, 0.22, 0.92), 12, 14, Style.ACCENT, 1))
	_hint.visible = false
	_hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom.add_child(_hint)
	var bar := Style.hbox([], 8)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_child(bar)
	for i in Data.TOOL_ORDER.size():
		var l := Style.label("", 15)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var p := Style.panel(l, _slot_off)
		p.custom_minimum_size = Vector2(110, 0)
		bar.add_child(p)
		_tools.append(p)
		_tool_labels.append(l)
	_basket = Style.label("", 15)
	var cells := Style.hbox([], 3)
	for i in Data.ECON.basket_up:
		var c := ColorRect.new()
		c.custom_minimum_size = Vector2(12, 16)
		cells.add_child(c)
		_cells.append(c)
	_crate = Style.label("", 14, Style.WARN)
	bar.add_child(Style.panel(Style.vbox([_basket, cells, _crate], 4), _slot_off))

	# Thông báo và chế độ đặt máy (trên giữa)
	var top := Style.vbox([], 8)
	_pin(top, Control.PRESET_CENTER_TOP, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)
	add_child(top)
	_build_bar = Style.panel(Style.label("CHẾ ĐỘ ĐẶT MÁY – nhắm vào khung và nhấp chuột · B để thoát", 16, Style.WARN), Style.box(Color(0.25, 0.18, 0.02, 0.9), 10, 10, Style.WARN, 1))
	_build_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(_build_bar)
	_toasts = Style.vbox([], 6)
	_toasts.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(_toasts)
	_set_mouse_ignore(self)


## Ghim khung vào góc màn hình, cách mép 20 px, tự giãn theo hướng grow.
static func _pin(c: Control, preset: int, gh: int, gv: int, margin := 20) -> void:
	c.grow_horizontal = gh
	c.grow_vertical = gv
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, margin)


func _set_mouse_ignore(n: Node) -> void:
	for c in n.get_children():
		if c is Control:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_mouse_ignore(c)


func _centered_label(offset: Vector2, size: int) -> Label:
	var l := Style.label("", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pin(l, Control.PRESET_CENTER, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH, 0)
	l.offset_top += offset.y
	l.offset_bottom += offset.y
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l


func toast(text: String, kind := "info") -> void:
	var l := Style.label(text, 16, Style.TEXT, true)
	l.custom_minimum_size.x = 520
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var p := Style.panel(l, Style.box(Style.BG_SOLID, 10, 10, KIND_COLORS.get(kind, Style.ACCENT), 1))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_child(p)
	_toasts.move_child(p, 0)
	while _toasts.get_child_count() > 4:
		var last := _toasts.get_child(_toasts.get_child_count() - 1)
		_toasts.remove_child(last)
		last.queue_free()
	var tw := p.create_tween()
	p.modulate.a = 0.0
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(4.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func update(hint_text: String) -> void:
	var s := Game.state
	var player: Player = main.player
	var quests: Quests = main.quests
	var machines: Machines = main.machines
	var a: Dictionary = player.aim
	_aim.text = a.text
	_aim.add_theme_color_override("font_color", Style.WARN if a.far else Color.WHITE)
	_interact.text = ("[%s] %s" % [Game.key_name("interact"), a.interact]) if a.interact != "" else ""
	_build_bar.visible = machines.build_mode

	var act := quests.active()
	for i in 3:
		if i < act.size():
			var q: Dictionary = act[i]
			var t: String = "› " + q.title.call()
			if i == 0 and quests.target != null and q.has("at"):
				t += "  ·  %d m" % quests.target_dist
			_quests[i].text = t
			_quests[i].visible = true
		else:
			_quests[i].visible = false
	if act.is_empty():
		_quests[0].text = "Không còn nhiệm vụ – hãy tận hưởng bờ sông sạch!"
		_quests[0].visible = true

	_money.text = "%d tiền" % s.money
	_mat.text = "%s vật liệu" % Game.fmt_mat(s.mat)
	_gems.text = "Sưu tầm %d/%d" % [s.collectibles.size(), Data.COLLECTIBLES.size()]
	_slot_tag.text = "" if s.slot == "main" else ("DỮ LIỆU THỬ" if s.slot == "dev" else "CHƠI LẠI")
	_slot_tag.visible = s.slot != "main"

	var ratio: float = main.trash.ratio
	_site_bar.value = ratio
	_site_pct.text = "Đã thu gom %d%%  (cần 90%%)" % floori(ratio * 100)
	_site_pending.text = "Rác chờ xử lý: %d" % Game.pending_count()
	if not s.placed.plant:
		_site_pollution.text = "Nguồn ô nhiễm: chưa xử lý"
		_site_pollution.add_theme_color_override("font_color", Style.BAD)
	elif s.plant.progress < 1.0:
		_site_pollution.text = "Nguồn ô nhiễm: đang xử lý %d%%" % roundi(s.plant.progress * 100)
		_site_pollution.add_theme_color_override("font_color", Style.WARN)
	else:
		_site_pollution.text = "Nguồn ô nhiễm: đã kiểm soát"
		_site_pollution.add_theme_color_override("font_color", Style.GOOD)

	var rc: PanelContainer = _cards.robots[0]
	rc.visible = not s.robots.is_empty()
	if rc.visible:
		(_cards.robots[1] as Label).text = main.robots.status()
	for k in ["conveyor", "skimmer"]:
		var p: PanelContainer = _cards[k][0]
		p.visible = s.placed[k]
		if not p.visible:
			continue
		var info := machines.info(k)
		var txt: String = "%s · %s\n%s" % [info.title, info.state, "  ·  ".join(info.rows.slice(0, 2).map(func(r): return "%s: %s" % r))]
		if not info.cause.is_empty() and info.key != "running":
			txt += "\n→ " + info.cause[1]
		(_cards[k][1] as Label).text = txt
		var sb := p.get_theme_stylebox("panel") as StyleBoxFlat
		var col: Color = STATE_COLORS.get(info.key, Style.MUTED)
		if sb.border_color != col:
			p.add_theme_stylebox_override("panel", Style.box(Style.BG, 10, 10, col, 2))

	for i in Data.TOOL_ORDER.size():
		var t: String = Data.TOOL_ORDER[i]
		var d: Dictionary = Data.TOOLS[t]
		_tool_labels[i].text = "%d  %s\n%s m" % [i + 1, d.name, d.reach]
		_tools[i].add_theme_stylebox_override("panel", _slot_on if s.tool == t else (_slot_off if s.tools[t] else _slot_locked))
		_tools[i].modulate.a = 1.0 if s.tools[t] else 0.45
	var cap := Game.basket_cap()
	var load := Game.basket_load()
	_basket.text = "Giỏ  %d/%d" % [load, cap]
	_basket.add_theme_color_override("font_color", Style.BAD if load >= cap else Style.TEXT)
	for i in _cells.size():
		_cells[i].visible = i < cap
		_cells[i].color = (Style.BAD if load >= cap else Style.ACCENT) if i < load else Color(1, 1, 1, 0.12)
	_crate.visible = not s.crate.is_empty()
	_crate.text = "Đang mang thùng: %d món" % s.crate.size()

	if hint_text != _last_hint:
		Sfx.duck(hint_text != "")
		_last_hint = hint_text
	_hint.visible = hint_text != ""
	_hint_label.text = hint_text
