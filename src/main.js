// Khởi động game, kết nối các hệ thống và chạy vòng lặp chính.
import * as THREE from 'three';
import './style.css';
import { LEVEL, ECON } from './data.js';
import { store, settings, newState, saveGame, loadGame, deleteSave, saveImage } from './core/state.js';
import { input } from './core/input.js';
import { audio } from './core/audio.js';
import { buildLevel } from './world/level.js';
import { createTrash } from './world/trash.js';
import { createMachines } from './world/machines.js';
import { createPlayer } from './game/player.js';
import { createQuests } from './game/quests.js';
import { createHud } from './ui/hud.js';
import { createPanels } from './ui/panels.js';

// ---------- Kết xuất ----------
const canvas = document.getElementById('game');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(devicePixelRatio, 1.5));
renderer.shadowMap.enabled = settings.shadows;
renderer.shadowMap.type = THREE.PCFShadowMap;
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(70, 1, 0.05, 300);

function resize() {
  renderer.setSize(innerWidth, innerHeight, false);
  camera.aspect = innerWidth / innerHeight;
  camera.updateProjectionMatrix();
}
addEventListener('resize', resize);
resize();

// ---------- Ngữ cảnh dùng chung ----------
const ctx = { scene, camera, audio, build: false, devSpeed: 1, running: false };
ctx.level = buildLevel(scene);
ctx.trash = createTrash(scene);
ctx.machines = createMachines(ctx);
ctx.interactables = ctx.machines.interactables;
ctx.player = createPlayer(ctx);
ctx.quests = createQuests(ctx);
const hud = createHud(ctx);
ctx.toast = hud.toast;
ctx.hint = (id) => ctx.quests.hint(id);
const ui = createPanels(ctx);
ctx.ui = ui;
const { level, trash, machines, player, quests } = ctx;

let needBefore = false, growStart = -1, clock = 0;

ctx.resume = () => {
  if (ctx.running && !ui.isOpen) input.lock(canvas);
};

ctx.applySettings = () => {
  renderer.shadowMap.enabled = settings.shadows;
  scene.traverse((o) => { if (o.material) o.material.needsUpdate = true; });
};

/** Bắt đầu hoặc tiếp tục một khe lưu. */
ctx.start = (slot, fresh) => {
  audio.init();
  if (fresh) deleteSave(slot);
  let s = fresh ? null : loadGame(slot);
  needBefore = !s;
  if (!s) s = newState(slot, trash.items.length, trash.flowCount);
  store.state = s;
  trash.restore();
  player.spawn();
  quests.reset();
  ctx.build = false;
  ctx.devSpeed = 1;
  ctx.running = true;
  growStart = s.accepted ? -Infinity : -1;
  hud.show(true);
  if (needBefore) ctx.hint('start');
  saveGame();
  ctx.resume();
};

/** Chụp cùng một góc máy cố định cho ảnh trước và sau. */
function capture(which) {
  const cam = level.photoCam;
  cam.position.x = -16;
  cam.aspect = canvas.width / canvas.height;
  cam.updateProjectionMatrix();
  const beam = quests.beam.visible;
  quests.beam.visible = false;
  renderer.render(scene, cam);
  quests.beam.visible = beam;
  const c = document.createElement('canvas');
  c.width = 480;
  c.height = Math.round(480 * canvas.height / canvas.width);
  c.getContext('2d').drawImage(canvas, 0, 0, c.width, c.height);
  saveImage(store.state.slot, which, c.toDataURL('image/jpeg', 0.8));
}

/** Nghiệm thu: chỉ bật khi đủ điều kiện, mở màn tiếp theo đúng một lần. */
ctx.accept = () => {
  const s = store.state;
  if (!quests.canAccept()) return;
  s.accepted = true;
  s.quests.accept = true;
  if (s.slot !== 'replay') {
    s.money += ECON.acceptBonus.money;
    s.mat += ECON.acceptBonus.mat;
    if (!s.campaign.done.includes(LEVEL.id)) s.campaign.done.push(LEVEL.id);
    if (!s.campaign.unlocked.includes('lake')) s.campaign.unlocked.push('lake');
  }
  player.remember();
  saveGame();
  audio.play('fanfare');
  ctx.toast('Nghiệm thu thành công! Bờ sông đang hồi sinh…', 'good');
  growStart = clock;
  ctx.resume();
  setTimeout(() => { capture('after'); ui.results(); }, 4500);
};

// ---------- Chế độ phát triển (khe lưu riêng) ----------
ctx.dev = {
  showMarkers: false,
  money: () => { store.state.money += 1000; store.state.mat += 200; saveGame(); },
  tools: () => { for (const k of Object.keys(store.state.tools)) store.state.tools[k] = true; saveGame(); },
  speed: () => { ctx.devSpeed = ctx.devSpeed === 1 ? 5 : 1; },
  markers: () => { ctx.dev.showMarkers = !ctx.dev.showMarkers; trash.showMarkers(ctx.dev.showMarkers); },
  quest: () => {
    const q = quests.active()[0];
    if (!q) return;
    if (q.id === 'outfall') store.state.obstacle.done = true;
    store.state.quests[q.id] = true;
    saveGame();
  },
  tp: (id) => {
    const z = LEVEL.zones.find((x) => x.id === id);
    player.teleport((z.x0 + z.x1) / 2, 11);
  },
};
function enterDev() {
  const s = store.state;
  if (s.slot !== 'dev') {
    player.remember();
    saveGame();
    store.state = structuredClone(s);
    store.state.slot = 'dev';
    saveGame();
    ctx.toast('Đã chuyển sang dữ liệu thử – tiến độ chính được giữ nguyên.', 'info');
  }
  ui.dev();
}

// ---------- Sự kiện ----------
canvas.addEventListener('click', () => ctx.resume());
document.addEventListener('pointerlockchange', () => {
  if (!input.locked && ctx.running && !ui.isOpen) ui.menu();
});
addEventListener('keydown', (e) => {
  if (e.code === 'Escape' && ui.isOpen && ctx.running && ui.name !== 'menu') ui.close();
});
const persist = () => { if (ctx.running) { player.remember(); saveGame(); } };
addEventListener('visibilitychange', () => { if (document.hidden) persist(); });
addEventListener('beforeunload', persist);

// ---------- Vòng lặp ----------
let last = performance.now(), autosave = 0;
function frame(now) {
  requestAnimationFrame(frame);
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;
  clock += dt;

  if (ctx.running) {
    const s = store.state;
    s.time += dt;
    const active = input.locked && !ui.isOpen;
    if (input.hit('menu')) { if (ui.name === 'tab') ui.close(); else if (!ui.isOpen) ui.tab('quests'); }
    if (input.hit('dev') && !ui.isOpen) enterDev();

    player.update(dt, active);
    trash.update(dt, clock, settings.waterFx);
    machines.update(dt, clock, camera.position);
    const hint = quests.update(dt, player.pos);
    const grow = s.accepted ? Math.min(1, (clock - growStart) / 4) : 0;
    level.update(dt, { clean: trash.ratio, purity: s.plant.progress, grow, time: clock });
    hud.update(hint);

    if (needBefore) { needBefore = false; capture('before'); }
    autosave += dt;
    if (autosave > ECON.autosave) { autosave = 0; persist(); }
    renderer.render(scene, camera);
  } else {
    // Nền menu: góc máy chụp trước–sau, lia chậm
    const cam = level.photoCam;
    cam.aspect = camera.aspect;
    cam.updateProjectionMatrix();
    cam.position.x = -16 + Math.sin(clock * 0.1) * 6;
    level.update(dt, { clean: 0, purity: 0, grow: 0, time: clock });
    renderer.render(scene, cam);
  }
  input.endFrame();
}

// Xem trước cảnh ở menu bằng ván đã lưu (hoặc ván mới, không lưu)
store.state = loadGame('main') || newState('main', trash.items.length, trash.flowCount);
trash.restore();
machines.update(0, 0, camera.position);
hud.show(false);
ui.menu();
requestAnimationFrame(frame);

if (import.meta.env.DEV) Object.assign(window, { game: ctx, store }); // tiện gỡ lỗi khi chạy npm run dev
