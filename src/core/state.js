// Trạng thái ván chơi, cài đặt, lưu/tải và giao dịch kinh tế.
// Mọi giao dịch trừ đầu vào và cấp thưởng trong cùng một lời gọi đồng bộ rồi mới lưu,
// nên tải lại không thể nhân đôi tiền hay mất rác.
import { SAVE_VERSION, ECON, TRASH, CAT_KEYS, DEFAULT_KEYS } from '../data.js';

const PREFIX = 'dnx_';
const SETTINGS_KEY = PREFIX + 'settings';

function storageGet(key) {
  try { return JSON.parse(localStorage.getItem(key)); } catch { return null; }
}
function storageSet(key, value) {
  try { localStorage.setItem(key, JSON.stringify(value)); } catch { /* bộ nhớ đầy hoặc bị chặn */ }
}

// ---------- Cài đặt (tách khỏi tiến độ) ----------
export const settings = Object.assign(
  { sens: 1, volume: 0.7, headBob: true, waterFx: true, guide: true, shadows: true },
  storageGet(SETTINGS_KEY) || {},
);
settings.keys = Object.assign({}, DEFAULT_KEYS, settings.keys || {});
export const saveSettings = () => storageSet(SETTINGS_KEY, settings);

// ---------- Ván chơi ----------
/** Khe lưu: main (chiến dịch), replay (chơi lại riêng), dev (dữ liệu thử). */
export function newState(slot, itemCount, flowCount) {
  return {
    v: SAVE_VERSION,
    slot,
    money: ECON.startMoney,
    mat: 0, // đơn vị 1/10 vật liệu
    tool: 'hand',
    tools: { hand: true, net: false, hook: false },
    stock: { conveyor: false, skimmer: false, plant: false }, // đã mua, đang trong kho
    placed: { conveyor: false, skimmer: false, plant: false },
    upgrades: { upBasket: false, upBelt: false, upSkimBin: false },
    items: new Array(itemCount).fill(0), // 0 còn ở hiện trường, 1 đã thu gom
    flow: Array.from({ length: flowCount }, () => [0, 0, 0]), // [pha, x, z]; pha 0 chờ, 1 trôi, 2 xoáy
    flowTimer: 0,
    basket: [],
    table: [],
    crate: [],
    conveyor: { hopper: [], transit: [], out: { plastic: [], metal: [], other: [] }, paused: false, feed: 0 },
    skimmer: { bin: [], paused: false, timer: 0 },
    plant: { progress: 0 },
    obstacle: { x: null, z: null, done: false },
    collectibles: [],
    stats: { manualBatches: 0, autoItems: 0, processed: 0, earned: 0, dumped: 0 },
    quests: {},
    hints: {},
    player: null,
    accepted: false,
    campaign: { done: [], unlocked: ['tolich'] },
    time: 0,
  };
}

export const store = { state: null };

export function saveGame() {
  const s = store.state;
  if (s) storageSet(PREFIX + s.slot, s);
}
export function loadGame(slot) {
  const s = storageGet(PREFIX + slot);
  return s && s.v === SAVE_VERSION ? s : null;
}
export const hasSave = (slot) => !!loadGame(slot);
export function deleteSave(slot) {
  try {
    localStorage.removeItem(PREFIX + slot);
    localStorage.removeItem(PREFIX + slot + '_before');
  } catch { /* bỏ qua */ }
}
export const saveImage = (slot, which, url) => { try { localStorage.setItem(`${PREFIX}${slot}_${which}`, url); } catch { /* ảnh quá lớn */ } };
export const loadImage = (slot, which) => { try { return localStorage.getItem(`${PREFIX}${slot}_${which}`); } catch { return null; } };

// ---------- Kinh tế ----------
export const fmtMat = (m) => (m / 10).toFixed(m % 10 ? 1 : 0);
export const canAfford = (price, mat = 0) => store.state.money >= price && store.state.mat >= mat;

export function spend(price, mat = 0) {
  if (!canAfford(price, mat)) return false;
  store.state.money -= price;
  store.state.mat -= mat;
  return true;
}

/** Giá trị xử lý của một danh sách mã loại rác. */
export function valueOf(types) {
  let money = 0, mat = 0;
  for (const t of types) { money += TRASH[t].value; mat += TRASH[t].mat; }
  return { money, mat };
}

/** Xử lý một mẻ: cấp thưởng và ghi thống kê trong cùng giao dịch, rồi lưu. */
export function processBatch(types, auto) {
  const s = store.state;
  const { money, mat } = valueOf(types);
  s.money += money;
  s.mat += mat;
  s.stats.processed += types.length;
  s.stats.earned += money;
  if (auto) s.stats.autoItems += types.length;
  else s.stats.manualBatches++;
  saveGame();
  return { money, mat };
}

export const basketCap = () => (store.state.upgrades.upBasket ? ECON.basketUp : ECON.basket);
export const basketLoad = () => store.state.basket.reduce((n, t) => n + TRASH[t].vol, 0);

/** Tổng rác đang chờ xử lý ở mọi nơi (giỏ, thùng mang, bàn, máy). */
export function pendingCount() {
  const s = store.state;
  const c = s.conveyor;
  return s.basket.length + s.crate.length + s.table.length + s.skimmer.bin.length
    + c.hopper.length + c.transit.length + CAT_KEYS.reduce((n, k) => n + c.out[k].length, 0);
}
