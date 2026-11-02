// Thiết bị, công trình và vật cản: bàn phân loại, băng chuyền, máy vớt, công trình xử lý nước thải,
// vật cản cửa xả kéo bằng móc. Logic máy trả về dữ liệu trạng thái để giao diện hiển thị.
import * as THREE from 'three';
import { TRASH, CATS, CAT_KEYS, ECON, LEVEL, SHOP } from '../data.js';
import { store, saveGame, processBatch } from '../core/state.js';
import { groundAt, makeLabel } from './level.js';

const STATE = { running: 'Đang chạy', idle: 'Chờ', starved: 'Thiếu đầu vào', full: 'Đầu ra đầy', paused: 'Tạm dừng', done: 'Hoàn tất' };
const SLOTS = LEVEL.slots;
const INTAKE = { x: LEVEL.eddy.x, z: LEVEL.eddy.z + 0.2 };
const BELT_EXIT = { metal: 0.35, plastic: 0.7, other: 1 }; // vị trí mô-đun trên băng (0..1)

const mat = (color, extra) => new THREE.MeshStandardMaterial({ color, roughness: 0.6, ...extra });
function part(geo, material, x, y, z, parent) {
  const m = new THREE.Mesh(geo, material);
  m.position.set(x, y, z);
  m.castShadow = m.receiveShadow = true;
  parent.add(m);
  return m;
}
const B = (w, h, d) => new THREE.BoxGeometry(w, h, d);

/** Thùng có vạch đầy bên trong. */
function fillBin(parent, color, x, z, label) {
  const g = new THREE.Group();
  g.position.set(x, 0, z);
  part(B(0.7, 0.7, 0.6), mat(color, { transparent: true, opacity: 0.55 }), 0, 0.35, 0, g);
  const fill = part(B(0.6, 0.6, 0.5), mat(0x333333), 0, 0.05, 0, g);
  fill.geometry.translate(0, 0.3, 0);
  if (label) { const l = makeLabel(label, { w: 0.7, h: 0.18, bg: color, size: 56 }); l.position.set(0, 0.85, 0); g.add(l); }
  parent.add(g);
  return (ratio) => { fill.scale.y = Math.max(0.001, Math.min(1, ratio)); };
}

export function createMachines(ctx) {
  const { scene, trash, audio } = ctx;
  const S = () => store.state;
  const tmp = new THREE.Object3D();

  // ---------- Băng chuyền ----------
  const conv = new THREE.Group();
  conv.position.set(SLOTS.conveyor.x, 0, SLOTS.conveyor.z);
  const steel = mat(0x7f8c8d, { metalness: 0.5 });
  part(B(4.4, 0.1, 0.8), mat(0x222222), 0, 0.85, 0, conv);
  for (const x of [-2, 2]) for (const z of [-0.35, 0.35]) part(B(0.08, 0.85, 0.08), steel, x, 0.42, z, conv);
  part(B(0.9, 0.6, 0.9), mat(0xd4ac0d), -2.55, 1.15, 0, conv);
  const hopperLabel = makeLabel('PHỄU NẠP', { w: 0.9, h: 0.2, size: 56 });
  hopperLabel.position.set(-2.55, 1.65, 0);
  conv.add(hopperLabel);
  const modules = [['NAM CHÂM', 0xc0392b, -0.6], ['TÁCH NHỰA', 0x2f80ed, 0.8]];
  for (const [name, color, x] of modules) {
    part(B(0.5, 0.45, 1), mat(color), x, 1.35, 0, conv);
    const l = makeLabel(name, { w: 0.9, h: 0.2, bg: '#222', size: 56 });
    l.position.set(x, 1.75, 0);
    conv.add(l);
  }
  const outFill = {
    metal: fillBin(conv, CATS.metal.color, -0.6, 0.85, 'KIM LOẠI'),
    plastic: fillBin(conv, CATS.plastic.color, 0.8, 0.85, 'NHỰA'),
    other: fillBin(conv, CATS.other.color, 2.6, 0, 'CÒN LẠI'),
  };
  const transitMesh = new THREE.InstancedMesh(B(0.16, 0.12, 0.16), new THREE.MeshStandardMaterial({ roughness: 0.6 }), 40);
  transitMesh.frustumCulled = false;
  conv.add(transitMesh);
  const catColor = Object.fromEntries(CAT_KEYS.map((k) => [k, new THREE.Color(CATS[k].color)]));
  scene.add(conv);

  // ---------- Máy vớt ----------
  const skim = new THREE.Group();
  skim.position.set(SLOTS.skimmer.x, 0, SLOTS.skimmer.z);
  part(B(1.6, 1, 1.4), mat(0x16a085), 0, 0.5, 0, skim);
  const armLen = SLOTS.skimmer.z - INTAKE.z;
  part(B(0.25, 0.25, armLen), steel, 0, 0.45, -armLen / 2, skim);
  part(B(0.12, 1.8, 0.12), steel, 0, -0.4, -armLen + 0.2, skim);
  const drum = part(new THREE.CylinderGeometry(0.45, 0.45, 1.8, 8), mat(0xf39c12), 0, LEVEL.waterY + 0.25, -armLen, skim);
  drum.rotation.z = Math.PI / 2;
  const skimFill = fillBin(skim, '#16a085', 1.4, 0.3, 'THÙNG');
  const ring = new THREE.Mesh(new THREE.RingGeometry(ECON.skimmer.radius - 0.08, ECON.skimmer.radius, 48), new THREE.MeshBasicMaterial({ color: 0x1abc9c, transparent: true, opacity: 0.6, side: THREE.DoubleSide }));
  ring.rotation.x = -Math.PI / 2;
  ring.position.set(INTAKE.x, LEVEL.waterY + 0.03, INTAKE.z);
  scene.add(skim, ring);

  // ---------- Công trình xử lý nước thải ----------
  const plant = new THREE.Group();
  plant.position.set(SLOTS.plant.x, 0, SLOTS.plant.z);
  part(B(2.4, 2.2, 1.8), mat(0xecf0f1), 0, 1.1, 0, plant);
  for (const x of [-2, 2]) part(new THREE.CylinderGeometry(0.75, 0.75, 1.6, 20), mat(0x95a5a6, { metalness: 0.3 }), x, 0.8, 0, plant);
  const stirrer = part(B(1.2, 0.08, 0.15), steel, 2, 1.7, 0, plant);
  const lamp = part(new THREE.SphereGeometry(0.15, 10, 8), new THREE.MeshStandardMaterial({ color: 0x2ecc71, emissive: 0x2ecc71 }), 0, 2.35, -0.9, plant);
  part(new THREE.CylinderGeometry(0.15, 0.15, 4.8), steel, 0, 0.15, -3.3, plant).rotation.x = Math.PI / 2;
  const plantLabel = makeLabel('XỬ LÝ NƯỚC THẢI', { w: 2.2, h: 0.35, bg: '#1e8449', size: 44 });
  plantLabel.position.set(0, 1.7, -0.92);
  plantLabel.rotation.y = Math.PI;
  plant.add(plantLabel);
  scene.add(plant);

  const groups = { conveyor: conv, skimmer: skim, plant };

  // ---------- Hình xem trước tại vị trí lắp ----------
  const ghostSize = { conveyor: [6, 1.6, 2], skimmer: [2.4, 1.2, 1.8], plant: [6, 2.4, 2.2] };
  const ghostMat = new THREE.MeshBasicMaterial({ color: 0x2ecc71, transparent: true, opacity: 0.35, depthWrite: false });
  const ghostRed = new THREE.MeshBasicMaterial({ color: 0xe74c3c, transparent: true, opacity: 0.3, depthWrite: false });
  const ghosts = Object.fromEntries(Object.entries(ghostSize).map(([k, [w, h, d]]) => {
    const g = new THREE.Mesh(B(w, h, d), ghostMat);
    g.position.set(SLOTS[k].x, h / 2, SLOTS[k].z);
    g.visible = false;
    scene.add(g);
    return [k, g];
  }));

  // ---------- Vật cản cửa xả ----------
  const fridge = new THREE.Group();
  part(B(1.5, 0.7, 0.75), mat(0xd9d4c7, { roughness: 0.9 }), 0, 0.35, 0, fridge);
  part(B(0.05, 0.5, 0.6), mat(0x8e6b3b), 0.76, 0.35, 0, fridge);
  fridge.rotation.y = 0.2;
  scene.add(fridge);
  const ropeGeo = new THREE.BufferGeometry().setAttribute('position', new THREE.Float32BufferAttribute(6, 3));
  const rope = new THREE.Line(ropeGeo, new THREE.LineBasicMaterial({ color: 0xf1c40f }));
  rope.frustumCulled = false;
  rope.visible = false;
  scene.add(rope);
  let hooked = false;
  const obsPos = () => {
    const o = S().obstacle;
    return o.x == null ? { x: LEVEL.obstacle.x, z: LEVEL.obstacle.z } : o;
  };

  // ---------- Logic ----------
  const unlocked = (k) => !SHOP[k].unlock || S().obstacle.done;
  const beltSpeed = () => ECON.belt.speed * (S().upgrades.upBelt ? 2 : 1) * ctx.devSpeed;
  const skimCap = () => (S().upgrades.upSkimBin ? ECON.skimmer.binUp : ECON.skimmer.bin);
  const skimRate = () => ECON.skimmer.rate * ctx.devSpeed;
  const outTotal = () => CAT_KEYS.reduce((n, k) => n + S().conveyor.out[k].length, 0);

  function convState() {
    const c = S().conveyor;
    if (c.paused) return 'paused';
    if (c.blocked) return 'full';
    if (!c.hopper.length && !c.transit.length) return 'starved';
    return 'running';
  }
  function skimState() {
    const k = S().skimmer;
    if (k.paused) return 'paused';
    if (k.bin.length >= skimCap()) return 'full';
    if (trash.nearestFloating(INTAKE.x, INTAKE.z, ECON.skimmer.radius) >= 0) return 'running';
    return trash.flowIncoming() > 0 ? 'idle' : 'starved';
  }

  function updateConveyor(dt) {
    const c = S().conveyor;
    if (!S().placed.conveyor || c.paused) return;
    const step = dt * beltSpeed() / ECON.belt.travel;
    c.blocked = false;
    for (let i = c.transit.length - 1; i >= 0; i--) {
      const it = c.transit[i];
      const cat = TRASH[it[0]].cat;
      const exit = BELT_EXIT[cat];
      if (it[1] < exit) { it[1] = Math.min(exit, it[1] + step); continue; }
      if (c.out[cat].length >= ECON.belt.out) { c.blocked = cat; continue; }
      c.out[cat].push(it[0]);
      c.transit.splice(i, 1);
    }
    if (c.blocked) return;
    c.feed += dt;
    if (c.hopper.length && c.feed >= 1 / beltSpeed()) {
      c.feed = 0;
      c.transit.push([c.hopper.shift(), 0]);
    }
  }

  function updateSkimmer(dt) {
    const k = S().skimmer;
    if (!S().placed.skimmer || k.paused || k.bin.length >= skimCap()) return;
    k.timer += dt;
    if (k.timer < 1 / skimRate()) return;
    const i = trash.nearestFloating(INTAKE.x, INTAKE.z, ECON.skimmer.radius);
    if (i < 0) return;
    k.timer = 0;
    const type = trash.items[i].type;
    const target = new THREE.Vector3(SLOTS.skimmer.x + 1.4, 0.8, SLOTS.skimmer.z + 0.3);
    if (trash.collect(i, () => target)) { k.bin.push(type); audio.play('splash'); }
  }

  function updatePlant(dt) {
    const p = S().plant;
    if (S().placed.plant && p.progress < 1) p.progress = Math.min(1, p.progress + dt * ctx.devSpeed / ECON.plant.duration);
  }

  function updateObstacle(camPos) {
    const o = S().obstacle;
    fridge.visible = !o.done;
    if (o.done) { rope.visible = false; hooked = false; return; }
    const p = obsPos();
    if (hooked) {
      const dx = p.x - camPos.x, dz = p.z - camPos.z, d = Math.hypot(dx, dz);
      const L = 3;
      if (d > 12) { hooked = false; ctx.toast('Dây móc bị tuột – móc lại vật cản.', 'warn'); }
      else if (d > L) {
        const nx = camPos.x + dx / d * L, nz = camPos.z + dz / d * L;
        if (groundAt(nx, nz) != null) { o.x = nx; o.z = nz; }
        else if (groundAt(nx, p.z) != null) { o.x = nx; o.z = p.z; }
        else if (groundAt(p.x, nz) != null) { o.x = p.x; o.z = nz; }
      }
      const q = obsPos();
      if (Math.hypot(q.x - LEVEL.receive.x, q.z - LEVEL.receive.z) < 1.8) finishObstacle();
    }
    const q = obsPos();
    if (groundAt(q.x, q.z) == null) { o.x = LEVEL.obstacle.x; o.z = LEVEL.obstacle.z; } // điểm phục hồi hợp lệ
    fridge.position.set(q.x, groundAt(q.x, q.z) ?? 0, q.z);
    rope.visible = hooked;
    if (hooked) {
      const a = ropeGeo.attributes.position;
      a.setXYZ(0, camPos.x, camPos.y - 0.5, camPos.z);
      a.setXYZ(1, fridge.position.x, fridge.position.y + 0.5, fridge.position.z);
      a.needsUpdate = true;
    }
  }

  function finishObstacle() {
    const s = S();
    hooked = false;
    s.obstacle.done = true;
    s.money += ECON.obstacleReward.money;
    s.mat += ECON.obstacleReward.mat;
    saveGame();
    audio.play('collect');
    ctx.toast(`Đã kéo ${LEVEL.obstacle.name} về điểm nhận: +${ECON.obstacleReward.money} tiền, +${ECON.obstacleReward.mat / 10} vật liệu. Cửa xả thông, rác trôi bắt đầu chảy ra.`, 'good');
    ctx.hint('flow');
  }

  // ---------- Thao tác ----------
  function dumpToTable() {
    const s = S();
    const n = s.basket.length + s.crate.length;
    if (n) {
      s.table.push(...s.basket, ...s.crate);
      s.basket = []; s.crate = [];
      s.stats.dumped++;
      saveGame();
      audio.play('dump');
    }
    return n;
  }

  function feedConveyor() {
    const s = S(), c = s.conveyor;
    let moved = 0;
    for (const src of [s.crate, s.basket]) {
      while (src.length && c.hopper.length < ECON.belt.hopper) { c.hopper.push(src.shift()); moved++; }
    }
    if (moved) { saveGame(); audio.play('dump'); }
    if (s.crate.length || s.basket.length) ctx.toast('Phễu đầy – chờ băng chuyền chạy bớt hoặc nâng tốc độ.', 'warn');
    return moved;
  }

  function processOutputs() {
    const c = S().conveyor;
    const all = CAT_KEYS.flatMap((k) => c.out[k]);
    if (!all.length) return;
    for (const k of CAT_KEYS) c.out[k] = [];
    const r = processBatch(all, true);
    audio.play('coin');
    ctx.toast(`Xử lý ${all.length} món: +${r.money} tiền, +${r.mat / 10} vật liệu`, 'good');
  }

  function takeSkimBin() {
    const s = S();
    if (s.crate.length) return ctx.toast('Bạn đang mang một thùng. Đổ vào phễu băng chuyền hoặc bàn phân loại trước.', 'warn');
    if (!s.skimmer.bin.length) return ctx.toast('Thùng máy vớt đang trống.', 'warn');
    s.crate = s.skimmer.bin;
    s.skimmer.bin = [];
    saveGame();
    audio.play('dump');
    ctx.hint('crate');
  }

  const isEmpty = (k) => {
    const s = S();
    if (k === 'conveyor') return !s.conveyor.hopper.length && !s.conveyor.transit.length && !outTotal();
    if (k === 'skimmer') return !s.skimmer.bin.length;
    return true;
  };

  /** Dữ liệu bảng máy cho giao diện: trạng thái, nguyên nhân, cách khắc phục, hàng chờ, nút. */
  function info(k) {
    const s = S();
    if (k === 'conveyor') {
      const c = s.conveyor, st = convState();
      const cause = {
        starved: ['Phễu nạp đang trống.', 'Mang giỏ hoặc thùng máy vớt tới và bấm Nạp.'],
        full: [`Thùng đầu ra ${CATS[c.blocked]?.name ?? ''} đã đầy.`, 'Bấm Xử lý đầu ra để nhận tiền và giải phóng thùng.'],
        paused: ['Bạn đã tạm dừng máy.', 'Bấm Tiếp tục.'],
      }[st];
      const carry = s.basket.length + s.crate.length;
      return {
        title: 'Băng chuyền (2 mô-đun)', state: STATE[st], stateKey: st, cause,
        rows: [
          ['Tốc độ', `${beltSpeed().toFixed(1)} món/giây`],
          ['Phễu (hàng chờ)', `${c.hopper.length}/${ECON.belt.hopper}`],
          ['Đang trên băng', c.transit.length],
          ...CAT_KEYS.map((ck) => [`Đầu ra ${CATS[ck].name}`, `${c.out[ck].length}/${ECON.belt.out}`]),
          ['Nút thắt', c.hopper.length > 10 ? 'Tốc độ băng chuyền – nâng cấp động cơ' : st === 'full' ? 'Thùng đầu ra – xử lý thường xuyên' : 'Lượng nạp vào'],
        ],
        actions: [
          { label: `Nạp ${carry} món từ giỏ/thùng`, fn: feedConveyor, disabled: !carry },
          { label: `Xử lý đầu ra (${outTotal()} món)`, fn: processOutputs, disabled: !outTotal(), primary: true },
          { label: c.paused ? 'Tiếp tục' : 'Tạm dừng', fn: () => { c.paused = !c.paused; saveGame(); } },
        ],
      };
    }
    if (k === 'skimmer') {
      const st = skimState();
      const cause = {
        full: ['Thùng máy vớt đã đầy.', 'Lấy thùng mang tới băng chuyền hoặc bàn phân loại; hoặc mua Thùng máy vớt lớn.'],
        idle: [s.obstacle.done ? 'Rác từ cửa xả chưa trôi tới vùng hoạt động.' : 'Cửa xả còn bị chặn.', 'Chờ một chút – trong lúc đó hãy nhặt rác ở khu khác.'],
        starved: ['Không còn rác nổi trong vùng.', 'Máy đã gom hết. Có thể tháo về kho để hoàn tiền nếu muốn.'],
        paused: ['Bạn đã tạm dừng máy.', 'Bấm Tiếp tục.'],
      }[st];
      return {
        title: 'Máy vớt', state: STATE[st], stateKey: st, cause,
        rows: [
          ['Tốc độ vớt', `${skimRate().toFixed(1)} món/giây`],
          ['Thùng', `${s.skimmer.bin.length}/${skimCap()}`],
          ['Rác sắp trôi tới', trash.flowIncoming()],
        ],
        actions: [
          { label: `Lấy thùng (${s.skimmer.bin.length} món)`, fn: takeSkimBin, disabled: !s.skimmer.bin.length || !!s.crate.length, primary: true },
          { label: s.skimmer.paused ? 'Tiếp tục' : 'Tạm dừng', fn: () => { s.skimmer.paused = !s.skimmer.paused; saveGame(); } },
        ],
      };
    }
    const done = s.plant.progress >= 1;
    return {
      title: 'Công trình xử lý nước thải', state: done ? 'Đã kiểm soát nguồn ô nhiễm' : 'Đang xử lý', stateKey: done ? 'done' : 'running',
      rows: [['Tiến độ làm sạch nước', `${Math.round(s.plant.progress * 100)}%`]],
      actions: [],
    };
  }

  // ---------- Điểm tương tác (phím E) ----------
  const interactables = [
    {
      x: LEVEL.table.x, z: LEVEL.table.z, r: 2.4,
      label: () => {
        const s = S(), n = s.basket.length + s.crate.length;
        return n ? `Đổ ${n} món lên bàn và phân loại` : s.table.length ? `Phân loại ${s.table.length} món trên bàn` : 'Bàn phân loại (giỏ đang trống)';
      },
      act: () => { dumpToTable(); if (S().table.length) ctx.ui.sort(); else ctx.toast('Giỏ trống – hãy nhặt rác trước.', 'warn'); },
    },
    { x: SLOTS.conveyor.x - 1, z: SLOTS.conveyor.z, r: 3, when: () => S().placed.conveyor, label: () => 'Băng chuyền – nạp rác và xem trạng thái', act: () => ctx.ui.machine('conveyor') },
    {
      x: SLOTS.skimmer.x, z: SLOTS.skimmer.z, r: 2.6, when: () => S().placed.skimmer,
      label: () => (S().skimmer.bin.length && !S().crate.length ? `Lấy thùng máy vớt (${S().skimmer.bin.length} món)` : 'Máy vớt – xem trạng thái'),
      act: () => (S().skimmer.bin.length && !S().crate.length ? takeSkimBin() : ctx.ui.machine('skimmer')),
    },
    { x: SLOTS.plant.x, z: SLOTS.plant.z - 1, r: 3, when: () => S().placed.plant, label: () => 'Công trình xử lý – xem trạng thái', act: () => ctx.ui.machine('plant') },
  ];

  /** Vật cản tròn cho người chơi. */
  const solids = [
    { x: LEVEL.table.x, z: LEVEL.table.z, r: 1.3 },
    { x: SLOTS.conveyor.x - 2.2, z: SLOTS.conveyor.z, r: 0.8, when: 'conveyor' },
    { x: SLOTS.conveyor.x, z: SLOTS.conveyor.z, r: 0.8, when: 'conveyor' },
    { x: SLOTS.conveyor.x + 2.3, z: SLOTS.conveyor.z, r: 0.8, when: 'conveyor' },
    { x: SLOTS.skimmer.x + 0.5, z: SLOTS.skimmer.z, r: 1.1, when: 'skimmer' },
    { x: SLOTS.plant.x, z: SLOTS.plant.z, r: 1.4, when: 'plant' },
    { x: SLOTS.plant.x - 2, z: SLOTS.plant.z, r: 0.8, when: 'plant' },
    { x: SLOTS.plant.x + 2, z: SLOTS.plant.z, r: 0.8, when: 'plant' },
  ];

  const v = new THREE.Vector3();
  return {
    interactables,
    solids: () => solids.filter((s) => !s.when || S().placed[s.when]),
    info,
    isEmpty,
    unlocked,
    states: () => ({ conveyor: S().placed.conveyor && convState(), skimmer: S().placed.skimmer && skimState() }),
    get hooked() { return hooked; },

    /** Thử gắn móc vào vật cản theo tia ngắm. */
    tryHook(origin, dir, reach) {
      if (hooked) { hooked = false; ctx.toast('Đã thả móc.', 'info'); return true; }
      if (S().obstacle.done) return false;
      const p = obsPos();
      v.set(p.x, (groundAt(p.x, p.z) ?? 0) + 0.35, p.z).sub(origin);
      const t = v.dot(dir);
      if (t < 0 || t > reach || v.lengthSq() - t * t > 1.2) return false;
      const n = trash.pileNear(p.x, p.z, 2.2);
      if (n) { ctx.toast(`Còn ${n} món rác đè quanh ${LEVEL.obstacle.name}. Dọn đống rác trước khi kéo.`, 'warn'); audio.play('error'); return true; }
      hooked = true;
      audio.play('hook');
      ctx.hint('drag');
      return true;
    },
    aimObstacle(origin, dir, reach) {
      if (S().obstacle.done) return false;
      const p = obsPos();
      v.set(p.x, (groundAt(p.x, p.z) ?? 0) + 0.35, p.z).sub(origin);
      const t = v.dot(dir);
      return t > 0 && t < reach && v.lengthSq() - t * t < 1.2;
    },

    /** Vị trí lắp đang nhắm trong chế độ đặt máy. */
    buildTarget(origin, dir) {
      let best = null, bestDot = 0.93;
      for (const k of Object.keys(SLOTS)) {
        const s = S();
        const mode = s.placed[k] ? 'remove' : s.stock[k] && unlocked(k) ? 'place' : null;
        if (!mode) continue;
        v.set(SLOTS[k].x, 0.8, SLOTS[k].z).sub(origin);
        const d = v.length();
        if (d > 14) continue;
        const dot = v.dot(dir) / d;
        if (dot > bestDot) { bestDot = dot; best = { key: k, mode, label: `${mode === 'place' ? 'Đặt' : 'Tháo về kho'}: ${SHOP[k].name}` }; }
      }
      return best;
    },
    applyBuild(t) {
      const s = S();
      if (t.mode === 'place') { s.placed[t.key] = true; s.stock[t.key] = false; ctx.hint(t.key); }
      else {
        if (t.key === 'plant' && s.accepted) return ctx.toast('Công trình đã nghiệm thu thuộc về hiện trường.', 'warn');
        if (!isEmpty(t.key)) return ctx.toast('Máy còn rác bên trong. Xử lý hết trước khi tháo.', 'warn');
        s.placed[t.key] = false; s.stock[t.key] = true;
      }
      saveGame();
      audio.play('place');
    },

    update(dt, time, camPos) {
      const s = S();
      updateConveyor(dt);
      updateSkimmer(dt);
      updatePlant(dt);
      updateObstacle(camPos);

      for (const k of Object.keys(groups)) groups[k].visible = s.placed[k];
      ring.visible = s.placed.skimmer || (ctx.build && s.stock.skimmer && unlocked('skimmer'));
      for (const [k, g] of Object.entries(ghosts)) {
        const show = ctx.build && (s.placed[k] || (s.stock[k] && unlocked(k)));
        g.visible = show;
        g.material = s.placed[k] ? ghostRed : ghostMat;
      }

      // Hình ảnh băng chuyền
      const c = s.conveyor;
      transitMesh.count = Math.min(40, c.transit.length);
      for (let i = 0; i < transitMesh.count; i++) {
        const [type, t] = c.transit[i];
        tmp.position.set(-2 + 4 * t, 0.97, 0);
        tmp.rotation.set(0, t * 6, 0);
        tmp.updateMatrix();
        transitMesh.setMatrixAt(i, tmp.matrix);
        transitMesh.setColorAt(i, catColor[TRASH[type].cat]);
      }
      transitMesh.instanceMatrix.needsUpdate = true;
      if (transitMesh.instanceColor) transitMesh.instanceColor.needsUpdate = true;
      for (const k of CAT_KEYS) outFill[k](c.out[k].length / ECON.belt.out);
      skimFill(s.skimmer.bin.length / skimCap());

      // Chuyển động và tiếng máy theo khoảng cách
      const near = (x, z) => Math.max(0, 1 - Math.hypot(camPos.x - x, camPos.z - z) / 20);
      const convOn = s.placed.conveyor && convState() === 'running';
      const skimOn = s.placed.skimmer && skimState() === 'running';
      const plantOn = s.placed.plant && s.plant.progress < 1;
      if (skimOn) drum.rotation.x += dt * 3;
      if (s.placed.plant) stirrer.rotation.y += dt * (plantOn ? 3 : 0.6);
      lamp.material.emissiveIntensity = s.placed.plant ? 0.6 + Math.sin(time * 3) * 0.4 : 0;
      audio.hum('conveyor', 55, convOn ? near(SLOTS.conveyor.x, SLOTS.conveyor.z) : 0);
      audio.hum('skimmer', 73, skimOn ? near(SLOTS.skimmer.x, SLOTS.skimmer.z) : 0);
      audio.hum('plant', 41, plantOn ? near(SLOTS.plant.x, SLOTS.plant.z) * 0.6 : 0);
    },
  };
}
