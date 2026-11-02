// Toàn bộ nội dung và thông số cân bằng của bản chơi thử.
// Thay số ở đây để thử cân bằng, không cần sửa logic.

export const SAVE_VERSION = 1;

/** Ba nhóm phân loại. */
export const CATS = {
  plastic: { name: 'Nhựa', color: '#2f80ed', icon: '🧴' },
  metal: { name: 'Kim loại', color: '#e0b100', icon: '🥫' },
  other: { name: 'Rác còn lại', color: '#8d6e63', icon: '🗑️' },
};
export const CAT_KEYS = Object.keys(CATS);

/**
 * Định nghĩa rác: mã, tên, nhóm, dung tích (ô giỏ), khối lượng tính tiến độ,
 * giá trị xử lý (tiền), vật liệu (đơn vị 1/10), nổi được không, mẫu hình, màu.
 * Mẻ chuẩn 10 món phổ thông = 50 tiền + 2 vật liệu.
 */
export const TRASH = [
  { id: 'bottle', name: 'Chai nhựa', cat: 'plastic', vol: 1, mass: 1, value: 5, mat: 2, float: true, shape: 'bottle', color: 0x8fd3f4 },
  { id: 'bag', name: 'Túi nilon', cat: 'plastic', vol: 1, mass: 1, value: 5, mat: 2, float: true, shape: 'bag', color: 0xf2f2f2 },
  { id: 'cup', name: 'Cốc nhựa', cat: 'plastic', vol: 1, mass: 1, value: 5, mat: 2, float: true, shape: 'cup', color: 0xff6b81 },
  { id: 'foam', name: 'Hộp xốp', cat: 'plastic', vol: 1, mass: 1, value: 5, mat: 2, float: true, shape: 'foam', color: 0xfffbf0 },
  { id: 'sandal', name: 'Dép nhựa', cat: 'plastic', vol: 1, mass: 1, value: 5, mat: 2, float: true, shape: 'sandal', color: 0x3867d6 },
  { id: 'jug', name: 'Can nhựa', cat: 'plastic', vol: 2, mass: 2, value: 10, mat: 4, float: true, shape: 'jug', color: 0xf7d794 },
  { id: 'can', name: 'Lon nước', cat: 'metal', vol: 1, mass: 1, value: 5, mat: 2, float: true, shape: 'can', color: 0xe74c3c },
  { id: 'tin', name: 'Hộp thiếc', cat: 'metal', vol: 1, mass: 1, value: 5, mat: 2, float: false, shape: 'tin', color: 0xb8c4c8 },
  { id: 'spray', name: 'Bình xịt', cat: 'metal', vol: 1, mass: 1, value: 5, mat: 2, float: false, shape: 'spray', color: 0x20bf6b },
  { id: 'wire', name: 'Cuộn dây thép', cat: 'metal', vol: 1, mass: 1, value: 5, mat: 2, float: false, shape: 'wire', color: 0x57606f },
  { id: 'carton', name: 'Hộp giấy', cat: 'other', vol: 1, mass: 1, value: 5, mat: 2, float: true, shape: 'carton', color: 0xd1a46b },
  { id: 'glass', name: 'Chai thủy tinh', cat: 'other', vol: 1, mass: 1, value: 5, mat: 2, float: false, shape: 'bottle', color: 0x2e8b57 },
  { id: 'rag', name: 'Giẻ vải', cat: 'other', vol: 1, mass: 1, value: 5, mat: 2, float: true, shape: 'rag', color: 0x9b5de5 },
  { id: 'coconut', name: 'Vỏ dừa', cat: 'other', vol: 1, mass: 1, value: 5, mat: 2, float: true, shape: 'coconut', color: 0x7a5230 },
];

/** Dụng cụ cầm tay. reach: tầm với (m), radius: bán kính quét quanh tâm ngắm, rate: giây/món khi giữ chuột. */
export const TOOLS = {
  hand: { name: 'Tay', reach: 3.2, radius: 0.35, rate: 0 },
  net: { name: 'Vợt', reach: 8.6, radius: 0.9, rate: 0.12 },
  hook: { name: 'Móc kéo', reach: 9, radius: 1.1, rate: 0 },
};
export const TOOL_ORDER = ['hand', 'net', 'hook'];

/** Cửa hàng. mat tính theo đơn vị 1/10 vật liệu (40 = 4 vật liệu). */
export const SHOP = {
  net: { name: 'Vợt', kind: 'tool', price: 150, mat: 0, desc: 'Với rác trên mặt nước, giữ chuột để vớt liên tục theo cụm.' },
  conveyor: { name: 'Băng chuyền (2 mô-đun)', kind: 'machine', price: 300, mat: 40, desc: 'Nam châm tách kim loại, mô-đun tách nhựa. Tự phân loại rác hỗn hợp.' },
  skimmer: { name: 'Máy vớt', kind: 'machine', price: 450, mat: 60, desc: 'Gom rác trôi trong vùng hoạt động vào thùng cạnh máy.', unlock: 'outfall' },
  plant: { name: 'Công trình xử lý nước thải', kind: 'machine', price: 200, mat: 40, desc: 'Thu gom và xử lý nước thải tại cửa xả. Bắt buộc trước nghiệm thu.', unlock: 'outfall' },
  upBasket: { name: 'Giỏ lớn (+6 ô)', kind: 'upgrade', price: 60, mat: 0, desc: 'Tăng sức chứa giỏ từ 10 lên 16 ô.', unlock: 'skimmer' },
  upBelt: { name: 'Động cơ băng chuyền', kind: 'upgrade', price: 80, mat: 10, desc: 'Gấp đôi tốc độ băng chuyền.', unlock: 'skimmer' },
  upSkimBin: { name: 'Thùng máy vớt lớn', kind: 'upgrade', price: 60, mat: 10, desc: 'Thùng máy vớt chứa 40 món thay vì 20.', unlock: 'skimmer' },
};

export const ECON = {
  startMoney: 100,
  basket: 10,
  basketUp: 16,
  acceptRatio: 0.9,
  acceptBonus: { money: 300, mat: 50 },
  obstacleReward: { money: 60, mat: 30 },
  belt: { speed: 1, travel: 3, hopper: 40, out: 15 },
  skimmer: { rate: 0.9, bin: 20, binUp: 40, radius: 3.2 },
  plant: { duration: 90 },
  flow: { count: 100, interval: 2.4, speed: 0.75 },
  autosave: 30,
};

/** Bố trí màn 1. Trục x dọc theo sông, z dương là bờ người chơi. */
export const LEVEL = {
  id: 'tolich',
  name: 'Đoạn sông Tô Lịch',
  x0: -40,
  x1: 40,
  waterY: -1.2,
  spawn: { x: -33, z: 12, yaw: -Math.PI / 2 },
  zones: [
    { id: 'A', name: 'Khu A – Bậc xuống bờ', x0: -40, x1: -22 },
    { id: 'B', name: 'Khu B – Mặt nước sát bờ', x0: -22, x1: -8 },
    { id: 'C', name: 'Khu C – Điểm tập kết', x0: -8, x1: 6 },
    { id: 'T', name: 'Đoạn chuyển tiếp', x0: 6, x1: 17 },
    { id: 'D', name: 'Khu D – Cửa xả', x0: 17, x1: 29 },
    { id: 'E', name: 'Khu E – Vị trí máy vớt', x0: 29, x1: 40 },
  ],
  table: { x: -3, z: 12.2 },
  receive: { x: 9, z: 12.5 },
  outfall: { x: 23, z: 3.8 },
  obstacle: { x: 23, z: 5.1, name: 'Tủ lạnh cũ' },
  eddy: { x: 33, z: 2.8, r: 1.8 },
  slots: {
    conveyor: { x: 3, z: 12.4, name: 'Vị trí băng chuyền' },
    skimmer: { x: 33, z: 9.6, name: 'Vị trí máy vớt' },
    plant: { x: 23, z: 12.8, name: 'Vị trí công trình xử lý' },
  },
  /** Nhóm rác: area = walk | steps | slope | water | pile | flow. Tổng 280 món ≈ 28 mẻ chuẩn. */
  trash: [
    { zone: 'A', n: 22, area: 'walk', x: [-39, -22] },
    { zone: 'A', n: 12, area: 'steps', x: [-35.5, -24.5] },
    { zone: 'A', n: 8, area: 'water', x: [-35, -25], z: [2.7, 3.7] },
    { zone: 'B', n: 10, area: 'slope', x: [-21.5, -8.5] },
    { zone: 'B', n: 28, area: 'water', x: [-21.5, -8.5], z: [1.4, 4.6] },
    { zone: 'C', n: 10, area: 'walk', x: [-8, 6] },
    { zone: 'C', n: 8, area: 'water', x: [-8, 6], z: [1.4, 4.6] },
    { zone: 'T', n: 10, area: 'walk', x: [6, 17] },
    { zone: 'T', n: 6, area: 'slope', x: [6, 16.5] },
    { zone: 'D', n: 40, area: 'pile' },
    { zone: 'D', n: 10, area: 'water', x: [17.5, 28.5], z: [1.6, 3.4] },
    { zone: 'E', n: 10, area: 'walk', x: [29, 39.5] },
    { zone: 'E', n: 6, area: 'slope', x: [29.5, 39.5] },
    { zone: 'D', n: 100, area: 'flow' },
  ],
  /** Đồ sưu tầm (mục tiêu tự chọn, đếm riêng). */
  collectibles: [
    { name: 'Vịt cao su', x: -38.5, y: -0.85, z: 4.4 },
    { name: 'Đồng xu cũ', x: -4.6, y: 0.05, z: 7.6 },
    { name: 'Huy hiệu Đội Xanh', x: 28.4, y: -0.55, z: 4.4 },
    { name: 'Chuông xe đạp', x: 39.4, y: 0.05, z: 14.6 },
    { name: 'Bình gốm nhỏ', x: 15.5, y: 0.05, z: 14.7 },
  ],
};

/** Bản đồ chiến dịch. Chỉ màn 1 chơi được trong bản thử. */
export const CAMPAIGN = [
  { id: 'tolich', name: 'Đoạn sông Tô Lịch', mech: 'Nhặt, vợt, phân loại, máy vớt' },
  { id: 'lake', name: 'Hồ thành phố', mech: 'Thuyền và vùng gom mặt nước rộng' },
  { id: 'canal', name: 'Kênh gần khu chợ', mech: 'Bố trí tuyến hẹp, máy ép rác' },
  { id: 'bridge', name: 'Đoạn sông có gầm cầu', mech: 'Phao chắn, dòng rác và robot gom' },
  { id: 'mangrove', name: 'Cửa sông và rừng ngập mặn', mech: 'Gỡ lưới, tiếp cận khe nhỏ' },
  { id: 'beach', name: 'Bãi biển', mech: 'Sàng cát và rác bị vùi' },
  { id: 'reef', name: 'Đáy biển có xác tàu', mech: 'Lặn, túi nâng và robot dưới nước' },
];

/** Phím mặc định (KeyboardEvent.code). Người chơi gán lại được trong Cài đặt. */
export const DEFAULT_KEYS = {
  forward: 'KeyW',
  back: 'KeyS',
  left: 'KeyA',
  right: 'KeyD',
  sprint: 'ShiftLeft',
  interact: 'KeyE',
  menu: 'Tab',
  build: 'KeyB',
  tool1: 'Digit1',
  tool2: 'Digit2',
  tool3: 'Digit3',
  dev: 'Backquote',
};
export const KEY_LABELS = {
  forward: 'Tiến', back: 'Lùi', left: 'Sang trái', right: 'Sang phải', sprint: 'Chạy nhanh',
  interact: 'Tương tác', menu: 'Nhiệm vụ & nâng cấp', build: 'Chế độ đặt máy',
  tool1: 'Dụng cụ 1', tool2: 'Dụng cụ 2', tool3: 'Dụng cụ 3', dev: 'Chế độ phát triển',
};
