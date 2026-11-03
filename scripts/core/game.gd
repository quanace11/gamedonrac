extends Node
## Autoload "Game": trạng thái ván chơi, cài đặt, lưu/tải, gán phím và giao dịch kinh tế.
## Mọi giao dịch trừ đầu vào và cấp thưởng trong cùng một bước đồng bộ rồi mới lưu,
## nên tải lại không thể nhân đôi tiền hay mất rác.

signal toast(text: String, kind: String)
signal hint(id: String)

const SETTINGS_PATH := "user://settings.cfg"

var state: Dictionary = {}
var settings := {
	"sens": 1.0, "volume": 0.8, "head_bob": true, "water_fx": true, "guide": true, "shadows": true,
	"keys": {},
}


func _ready() -> void:
	_load_settings()
	apply_keys()


# ---------- Cài đặt (tách khỏi tiến độ) ----------
func _load_settings() -> void:
	for a in Data.ACTIONS:
		settings.keys[a] = Data.ACTIONS[a][1]
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for k in settings:
		if k != "keys":
			settings[k] = cfg.get_value("game", k, settings[k])
	for a in Data.ACTIONS:
		settings.keys[a] = cfg.get_value("keys", a, settings.keys[a])


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings:
		if k != "keys":
			cfg.set_value("game", k, settings[k])
	for a in settings.keys:
		cfg.set_value("keys", a, settings.keys[a])
	cfg.save(SETTINGS_PATH)


## Đăng ký hành động vào InputMap theo phím đã gán.
func apply_keys() -> void:
	for a in Data.ACTIONS:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		InputMap.action_erase_events(a)
		var ev := InputEventKey.new()
		ev.physical_keycode = settings.keys[a]
		InputMap.action_add_event(a, ev)
	if not InputMap.has_action("use"):
		InputMap.add_action("use")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("use", mb)


func key_name(action: String) -> String:
	return OS.get_keycode_string(settings.keys[action])


# ---------- Ván chơi ----------
## Khe lưu: main (chiến dịch), replay (chơi lại riêng), dev (dữ liệu thử).
func new_state(slot: String, item_count: int, flow_count: int) -> Dictionary:
	var items := PackedByteArray()
	items.resize(item_count)
	var flow := []
	for i in flow_count:
		flow.append(Vector3.ZERO) # x: pha (0 chờ, 1 trôi, 2 xoáy, 3 đã gom), y: x, z: z
	return {
		"v": Data.SAVE_VERSION, "slot": slot,
		"money": Data.ECON.start_money, "mat": 0,
		"tool": "hand", "tools": {"hand": true, "net": false, "hook": false},
		"stock": {"conveyor": false, "skimmer": false, "plant": false},
		"placed": {"conveyor": false, "skimmer": false, "plant": false},
		"upgrades": {"up_basket": false, "up_belt": false, "up_skim_bin": false},
		"items": items, "flow": flow, "flow_timer": 0.0,
		"basket": [], "table": [], "crate": [],
		"conveyor": {"hopper": [], "transit": [], "out": {"plastic": [], "metal": [], "other": []}, "paused": false, "feed": 0.0, "blocked": ""},
		"skimmer": {"bin": [], "paused": false, "timer": 0.0},
		"plant": {"progress": 0.0},
		"obstacle": {"pos": Data.LEVEL.obstacle, "done": false},
		"collectibles": [],
		"stats": {"manual_batches": 0, "auto_items": 0, "processed": 0, "earned": 0, "dumped": 0},
		"quests": {}, "hints": {},
		"player": null,
		"accepted": false,
		"campaign": {"done": [], "unlocked": ["tolich"]},
		"time": 0.0,
	}


func _path(slot: String) -> String:
	return "user://save_%s.dat" % slot


func save_game() -> void:
	if state.is_empty():
		return
	var f := FileAccess.open(_path(state.slot), FileAccess.WRITE)
	if f:
		f.store_var(state)


func load_game(slot: String) -> Dictionary:
	if not FileAccess.file_exists(_path(slot)):
		return {}
	var f := FileAccess.open(_path(slot), FileAccess.READ)
	var s = f.get_var() if f else null
	return s if s is Dictionary and s.get("v") == Data.SAVE_VERSION else {}


func has_save(slot: String) -> bool:
	return not load_game(slot).is_empty()


func delete_save(slot: String) -> void:
	for p in [_path(slot), image_path(slot, "before"), image_path(slot, "after")]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func image_path(slot: String, which: String) -> String:
	return "user://%s_%s.png" % [slot, which]


# ---------- Kinh tế ----------
static func fmt_mat(m: int) -> String:
	return str(m / 10) if m % 10 == 0 else "%.1f" % (m / 10.0)


func can_afford(price: int, mat: int = 0) -> bool:
	return state.money >= price and state.mat >= mat


func spend(price: int, mat: int = 0) -> bool:
	if not can_afford(price, mat):
		return false
	state.money -= price
	state.mat -= mat
	return true


static func value_of(types: Array) -> Vector2i:
	var r := Vector2i.ZERO
	for t in types:
		r += Vector2i(Data.trash_value(t), Data.trash_mat(t))
	return r


## Xử lý một mẻ: cấp thưởng và ghi thống kê trong cùng giao dịch, rồi lưu.
func process_batch(types: Array, auto: bool) -> Vector2i:
	var v := value_of(types)
	state.money += v.x
	state.mat += v.y
	state.stats.processed += types.size()
	state.stats.earned += v.x
	if auto:
		state.stats.auto_items += types.size()
	else:
		state.stats.manual_batches += 1
	save_game()
	return v


func basket_cap() -> int:
	return Data.ECON.basket_up if state.upgrades.up_basket else Data.ECON.basket


func basket_load() -> int:
	var n := 0
	for t in state.basket:
		n += Data.trash_vol(t)
	return n


## Tổng rác đang chờ xử lý ở mọi nơi (giỏ, thùng mang, bàn, máy).
func pending_count() -> int:
	var c: Dictionary = state.conveyor
	var n: int = state.basket.size() + state.crate.size() + state.table.size() + state.skimmer.bin.size()
	n += c.hopper.size() + c.transit.size()
	for k in Data.CAT_KEYS:
		n += c.out[k].size()
	return n


func say(text: String, kind := "info") -> void:
	toast.emit(text, kind)


func show_hint(id: String) -> void:
	hint.emit(id)
