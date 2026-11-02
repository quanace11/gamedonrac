// Bàn phím, chuột, khóa con trỏ và gán lại phím.
import { settings } from './state.js';

const down = new Set();
const pressed = new Set();
let mouseDX = 0, mouseDY = 0, wheel = 0;
let lmb = false, lmbPressed = false;
let capture = null;

export const input = {
  /** Hành động đang giữ (theo tên trong settings.keys). */
  held: (action) => down.has(settings.keys[action]),
  /** Hành động vừa bấm trong khung hình này. */
  hit: (action) => pressed.has(settings.keys[action]),
  get lmb() { return lmb; },
  get lmbHit() { return lmbPressed; },
  get locked() { return document.pointerLockElement != null; },
  look() { const d = [mouseDX, mouseDY]; mouseDX = mouseDY = 0; return d; },
  wheel() { const w = wheel; wheel = 0; return Math.sign(w); },
  endFrame() { pressed.clear(); lmbPressed = false; },
  reset() { down.clear(); pressed.clear(); lmb = false; },
  /** Chờ phím kế tiếp để gán lại; Escape để hủy. */
  captureKey(cb) { capture = cb; },
  lock(el) { el.requestPointerLock?.()?.catch?.(() => {}); },
  unlock() { if (document.pointerLockElement) document.exitPointerLock(); },
};

addEventListener('keydown', (e) => {
  if (capture) {
    e.preventDefault();
    const cb = capture; capture = null;
    cb(e.code === 'Escape' ? null : e.code);
    return;
  }
  if (e.target instanceof HTMLInputElement) return;
  if (e.code === 'Tab' || e.code === 'Space' || Object.values(settings.keys).includes(e.code)) e.preventDefault();
  if (!down.has(e.code)) pressed.add(e.code);
  down.add(e.code);
});
addEventListener('keyup', (e) => down.delete(e.code));
addEventListener('blur', () => input.reset());
addEventListener('mousemove', (e) => {
  // Bỏ cú nhảy chuột bất thường ngay sau khi khóa con trỏ (lỗi đã biết của trình duyệt)
  if (!input.locked || Math.abs(e.movementX) > 250 || Math.abs(e.movementY) > 250) return;
  mouseDX += e.movementX;
  mouseDY += e.movementY;
});
addEventListener('mousedown', (e) => {
  if (e.button === 0 && input.locked) { lmb = true; lmbPressed = true; }
});
addEventListener('mouseup', (e) => { if (e.button === 0) lmb = false; });
addEventListener('wheel', (e) => { if (input.locked) wheel += e.deltaY; }, { passive: true });
