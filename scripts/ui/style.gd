class_name Style
## Giao diện dùng chung: bảng màu, Theme, và các hàm tạo nhanh nhãn, nút, khung.

const BG := Color(0.05, 0.09, 0.11, 0.86)
const BG_SOLID := Color(0.07, 0.12, 0.14, 0.97)
const LINE := Color(1, 1, 1, 0.08)
const TEXT := Color(0.93, 0.96, 0.95)
const MUTED := Color(0.62, 0.7, 0.7)
const ACCENT := Color("#3fd7a8")
const GOOD := Color("#5be38f")
const WARN := Color("#f5b942")
const BAD := Color("#f06a5a")

## Ảnh thu nhỏ của từng loại rác (main.gd dựng khi khởi động).
static var thumbs := {}
static var _theme: Theme


static func box(bg: Color, radius := 10, pad := 12, border := Color.TRANSPARENT, bw := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	s.border_color = border
	s.set_border_width_all(bw)
	s.anti_aliasing = true
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 17
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", box(BG, 14, 16))
	t.set_stylebox("panel", "Panel", box(BG, 14, 16))

	var b := box(Color(1, 1, 1, 0.07), 8, 10, Color(1, 1, 1, 0.1), 1)
	b.content_margin_top = 7
	b.content_margin_bottom = 7
	var bh := b.duplicate() as StyleBoxFlat
	bh.bg_color = Color(1, 1, 1, 0.14)
	bh.border_color = ACCENT.darkened(0.2)
	var bp := b.duplicate() as StyleBoxFlat
	bp.bg_color = ACCENT.darkened(0.55)
	var bd := b.duplicate() as StyleBoxFlat
	bd.bg_color = Color(1, 1, 1, 0.03)
	bd.border_color = Color(1, 1, 1, 0.04)
	t.set_stylebox("normal", "Button", b)
	t.set_stylebox("hover", "Button", bh)
	t.set_stylebox("pressed", "Button", bp)
	t.set_stylebox("disabled", "Button", bd)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.3))

	# Nút chính (theme_type_variation = "Primary")
	t.set_type_variation("Primary", "Button")
	var p := b.duplicate() as StyleBoxFlat
	p.bg_color = ACCENT.darkened(0.25)
	p.border_color = ACCENT
	var ph := p.duplicate() as StyleBoxFlat
	ph.bg_color = ACCENT.darkened(0.1)
	t.set_stylebox("normal", "Primary", p)
	t.set_stylebox("hover", "Primary", ph)
	t.set_color("font_color", "Primary", Color(0.02, 0.1, 0.08))
	t.set_color("font_hover_color", "Primary", Color(0.02, 0.1, 0.08))

	var bar_bg := box(Color(1, 1, 1, 0.1), 5, 0)
	var bar_fill := box(ACCENT, 5, 0)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)
	t.set_constant("h_separation", "HFlowContainer", 6)
	t.set_constant("v_separation", "HFlowContainer", 6)
	t.set_stylebox("slider", "HSlider", box(Color(1, 1, 1, 0.15), 3, 2))
	t.set_stylebox("grabber_area", "HSlider", box(ACCENT.darkened(0.2), 3, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT, 3, 2))
	_theme = t
	return t


static func label(text: String, size := 0, color := TEXT, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	if color != TEXT:
		l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 120
	return l


static func button(text: String, fn: Callable, primary := false, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.focus_mode = Control.FOCUS_NONE
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS # bảng tự làm mới vẫn nhận nhấp
	if primary:
		b.theme_type_variation = "Primary"
	b.pressed.connect(func():
		Sfx.play("ui")
		fn.call())
	return b


static func hbox(children: Array = [], sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	for c in children:
		h.add_child(c)
	return h


static func vbox(children: Array = [], sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	for c in children:
		v.add_child(c)
	return v


static func panel(child: Control, style: StyleBox = null) -> PanelContainer:
	var p := PanelContainer.new()
	if style:
		p.add_theme_stylebox_override("panel", style)
	p.add_child(child)
	return p


static func bar(ratio: float, color := ACCENT, height := 10.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = 1.0
	b.value = ratio
	b.custom_minimum_size.y = height
	b.add_theme_stylebox_override("fill", box(color, 5, 0))
	return b


static func thumb(t: int, size := 40) -> Control:
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(size, size)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture = thumbs.get(t)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr
