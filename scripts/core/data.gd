class_name Data
## Toàn bộ nội dung và thông số cân bằng của bản chơi thử.
## Thay số ở đây để thử cân bằng, không cần sửa logic.

const SAVE_VERSION := 1

## Ba nhóm phân loại.
const CATS := {
	"plastic": {"name": "Nhựa", "color": Color("#2f80ed")},
	"metal": {"name": "Kim loại", "color": Color("#e0b100")},
	"other": {"name": "Rác còn lại", "color": Color("#8d6e63")},
}
const CAT_KEYS := ["plastic", "metal", "other"]

## Định nghĩa rác. model: thư mục trong assets/models, parts: chỉ lấy các mảnh có tên này (rỗng = mọi mảnh),
## size: cạnh dài nhất khi hiển thị (m, phóng to vật nhỏ cho dễ nhìn), vol: ô giỏ, mass: khối lượng tiến độ,
## value: tiền xử lý, mat: vật liệu (đơn vị 1/10). Mẻ chuẩn 10 món = 50 tiền + 2 vật liệu.
const TRASH := [
	{"id": "bottle", "name": "Chai nhựa", "cat": "plastic", "model": "bleach_bottle", "size": 0.32, "float": true},
	{"id": "cleaner", "name": "Chai nước rửa", "cat": "plastic", "model": "multi_cleaner_bottle", "size": 0.3, "float": true},
	{"id": "bag", "name": "Túi rác nilon", "cat": "plastic", "model": "trashbag", "size": 0.5, "float": true},
	{"id": "box", "name": "Hộp nhựa", "cat": "plastic", "model": "plastic_container", "size": 0.45, "float": true},
	{"id": "jug", "name": "Can nhựa", "cat": "plastic", "model": "plastic_jerrycan", "size": 0.38, "float": true, "vol": 2, "mass": 2},
	{"id": "boot", "name": "Ủng cao su", "cat": "plastic", "model": "rubber_boots", "parts": ["rubber_boots_dirty_l"], "size": 0.36, "float": true},
	{"id": "can", "name": "Lon rỉ sét", "cat": "metal", "model": "can_rusted", "size": 0.22, "float": true},
	{"id": "tin", "name": "Hộp thiếc", "cat": "metal", "model": "russian_food_cans_01", "parts": ["russian_food_cans_01_can_fish"], "size": 0.2, "float": false},
	{"id": "spray", "name": "Bình xịt", "cat": "metal", "model": "lubricant_spray", "size": 0.25, "float": false},
	{"id": "oil", "name": "Can dầu thiếc", "cat": "metal", "model": "oil_tin", "size": 0.28, "float": false},
	{"id": "carton", "name": "Thùng giấy", "cat": "other", "model": "cardboard_box_01", "size": 0.42, "float": true},
	{"id": "pack", "name": "Vỏ bao thuốc", "cat": "other", "model": "cigarette_pack", "parts": ["cigarette_pack_main"], "size": 0.18, "float": true},
	{"id": "ball", "name": "Bóng cũ", "cat": "other", "model": "dirty_football", "size": 0.26, "float": true},
	{"id": "glove", "name": "Găng tay vải", "cat": "other", "model": "garden_gloves_01", "size": 0.3, "float": true},
]

## Dụng cụ. reach: tầm với (m), radius: bán kính quét quanh tâm ngắm, rate: giây/món khi giữ chuột.
const TOOLS := {
	"hand": {"name": "Tay", "reach": 3.2, "radius": 0.4, "rate": 0.0},
	"net": {"name": "Vợt", "reach": 8.6, "radius": 0.9, "rate": 0.12},
	"hook": {"name": "Móc kéo", "reach": 9.0, "radius": 1.1, "rate": 0.0},
}
const TOOL_ORDER := ["hand", "net", "hook"]

## Cửa hàng. mat tính theo đơn vị 1/10 vật liệu.
const SHOP := {
	"net": {"name": "Vợt", "kind": "tool", "price": 150, "mat": 0, "desc": "Với rác trên mặt nước, giữ chuột để vớt liên tục theo cụm."},
	"conveyor": {"name": "Băng chuyền (2 mô-đun)", "kind": "machine", "price": 300, "mat": 40, "desc": "Nam châm tách kim loại, mô-đun tách nhựa. Tự phân loại rác hỗn hợp."},
	"skimmer": {"name": "Máy vớt", "kind": "machine", "price": 450, "mat": 60, "desc": "Gom rác trôi trong vùng hoạt động vào thùng cạnh máy.", "unlock": "outfall"},
	"plant": {"name": "Công trình xử lý nước thải", "kind": "machine", "price": 200, "mat": 40, "desc": "Thu gom và xử lý nước thải tại cửa xả. Bắt buộc trước nghiệm thu.", "unlock": "outfall"},
	"up_basket": {"name": "Giỏ lớn (+6 ô)", "kind": "upgrade", "price": 60, "mat": 0, "desc": "Tăng sức chứa giỏ từ 10 lên 16 ô.", "unlock": "skimmer"},
	"up_belt": {"name": "Động cơ băng chuyền", "kind": "upgrade", "price": 80, "mat": 10, "desc": "Gấp đôi tốc độ băng chuyền.", "unlock": "skimmer"},
	"up_skim_bin": {"name": "Thùng máy vớt lớn", "kind": "upgrade", "price": 60, "mat": 10, "desc": "Thùng máy vớt chứa 40 món thay vì 20.", "unlock": "skimmer"},
}

const ECON := {
	"start_money": 100,
	"basket": 10, "basket_up": 16,
	"accept_ratio": 0.9,
	"accept_bonus_money": 300, "accept_bonus_mat": 50,
	"obstacle_money": 60, "obstacle_mat": 30,
	"belt_speed": 1.0, "belt_travel": 3.0, "belt_hopper": 40, "belt_out": 15,
	"skim_rate": 0.9, "skim_bin": 20, "skim_bin_up": 40, "skim_radius": 3.2,
	"plant_duration": 90.0,
	"flow_interval": 2.4, "flow_speed": 0.75,
	"autosave": 30.0,
}

## Bố trí màn 1. Trục x dọc theo sông, z dương là bờ người chơi.
const LEVEL := {
	"id": "tolich", "name": "Đoạn sông Tô Lịch",
	"x0": -40.0, "x1": 40.0, "water_y": -1.2,
	"spawn": Vector3(-33, 0, 12), "spawn_yaw": -PI / 2,
	"table": Vector2(-3, 12.2),
	"receive": Vector2(9, 12.5),
	"outfall": Vector2(23, 3.8),
	"obstacle": Vector2(23, 5.1), "obstacle_name": "Lốp xe tải cũ",
	"eddy": Vector3(33, 2.8, 1.8), # x, z, bán kính
	"slots": {
		"conveyor": Vector2(3, 12.4),
		"skimmer": Vector2(33, 9.6),
		"plant": Vector2(23, 12.8),
	},
}

const ZONES := [
	{"id": "A", "name": "Khu A – Bậc xuống bờ", "x0": -40.0, "x1": -22.0},
	{"id": "B", "name": "Khu B – Mặt nước sát bờ", "x0": -22.0, "x1": -8.0},
	{"id": "C", "name": "Khu C – Điểm tập kết", "x0": -8.0, "x1": 6.0},
	{"id": "T", "name": "Đoạn chuyển tiếp", "x0": 6.0, "x1": 17.0},
	{"id": "D", "name": "Khu D – Cửa xả", "x0": 17.0, "x1": 29.0},
	{"id": "E", "name": "Khu E – Vị trí máy vớt", "x0": 29.0, "x1": 40.0},
]

## Nhóm rác: area = walk | steps | slope | water | pile | flow. Tổng 280 món ≈ 28 mẻ chuẩn.
const TRASH_GROUPS := [
	{"zone": "A", "n": 22, "area": "walk", "x": Vector2(-39, -22)},
	{"zone": "A", "n": 12, "area": "steps", "x": Vector2(-35.5, -24.5)},
	{"zone": "A", "n": 8, "area": "water", "x": Vector2(-35, -25), "z": Vector2(2.7, 3.7)},
	{"zone": "B", "n": 10, "area": "slope", "x": Vector2(-21.5, -8.5)},
	{"zone": "B", "n": 28, "area": "water", "x": Vector2(-21.5, -8.5), "z": Vector2(1.4, 4.6)},
	{"zone": "C", "n": 10, "area": "walk", "x": Vector2(-8, 6)},
	{"zone": "C", "n": 8, "area": "water", "x": Vector2(-8, 6), "z": Vector2(1.4, 4.6)},
	{"zone": "T", "n": 10, "area": "walk", "x": Vector2(6, 17)},
	{"zone": "T", "n": 6, "area": "slope", "x": Vector2(6, 16.5)},
	{"zone": "D", "n": 40, "area": "pile"},
	{"zone": "D", "n": 10, "area": "water", "x": Vector2(17.5, 28.5), "z": Vector2(1.6, 3.4)},
	{"zone": "E", "n": 10, "area": "walk", "x": Vector2(29, 39.5)},
	{"zone": "E", "n": 6, "area": "slope", "x": Vector2(29.5, 39.5)},
	{"zone": "D", "n": 100, "area": "flow"},
]

## Đồ sưu tầm (mục tiêu tự chọn, đếm riêng).
const COLLECTIBLES := [
	{"name": "Vịt cao su", "model": "rubber_duck_toy", "pos": Vector3(-38.5, -0.9, 4.4)},
	{"name": "Đồng hồ quả quýt", "model": "pocket_watch", "pos": Vector3(-4.6, 0.0, 7.6)},
	{"name": "La bàn cổ", "model": "seadogs_compass", "pos": Vector3(28.4, -0.6, 4.4)},
	{"name": "Vỏ ốc biển", "model": "lambis_shell", "pos": Vector3(39.4, 0.0, 14.6)},
	{"name": "Chú lùn làm vườn", "model": "garden_gnome", "pos": Vector3(15.5, 0.0, 14.7)},
]

## Bản đồ chiến dịch. Chỉ màn 1 chơi được trong bản thử.
const CAMPAIGN := [
	{"id": "tolich", "name": "Đoạn sông Tô Lịch", "mech": "Nhặt, vợt, phân loại, máy vớt"},
	{"id": "lake", "name": "Hồ thành phố", "mech": "Thuyền và vùng gom mặt nước rộng"},
	{"id": "canal", "name": "Kênh gần khu chợ", "mech": "Bố trí tuyến hẹp, máy ép rác"},
	{"id": "bridge", "name": "Đoạn sông có gầm cầu", "mech": "Phao chắn, dòng rác và robot gom"},
	{"id": "mangrove", "name": "Cửa sông và rừng ngập mặn", "mech": "Gỡ lưới, tiếp cận khe nhỏ"},
	{"id": "beach", "name": "Bãi biển", "mech": "Sàng cát và rác bị vùi"},
	{"id": "reef", "name": "Đáy biển có xác tàu", "mech": "Lặn, túi nâng và robot dưới nước"},
]

## Hành động gán phím: tên → [nhãn, phím mặc định].
const ACTIONS := {
	"forward": ["Tiến", KEY_W], "back": ["Lùi", KEY_S], "left": ["Sang trái", KEY_A], "right": ["Sang phải", KEY_D],
	"sprint": ["Chạy nhanh", KEY_SHIFT], "interact": ["Tương tác", KEY_E], "menu": ["Nhiệm vụ & nâng cấp", KEY_TAB],
	"build": ["Chế độ đặt máy", KEY_B], "tool1": ["Dụng cụ 1", KEY_1], "tool2": ["Dụng cụ 2", KEY_2],
	"tool3": ["Dụng cụ 3", KEY_3], "dev": ["Chế độ phát triển", KEY_QUOTELEFT],
}


static func trash_vol(t: int) -> int:
	return TRASH[t].get("vol", 1)


static func trash_mass(t: int) -> int:
	return TRASH[t].get("mass", 1)


static func trash_value(t: int) -> int:
	return 5 * trash_mass(t)


static func trash_mat(t: int) -> int:
	return 2 * trash_mass(t)
