// Màn 1: đoạn sông hư cấu lấy cảm hứng từ Tô Lịch.
// Dựng địa hình, nước, cảnh quan, va chạm và hiệu ứng phục hồi.
import * as THREE from 'three';
import { LEVEL, CATS } from '../data.js';
import { settings } from '../core/state.js';

const { x0: X0, x1: X1, waterY } = LEVEL;

// ---------- Va chạm và độ cao ----------
const STEPS_A = { x0: -36, x1: -24, tops: [-0.3, -0.6, -0.9] }; // bậc xuống bờ khu A
const APRON_D = { x0: 17, x1: 29, tops: [-0.2, -0.4, -0.6] }; // sân bê tông cửa xả khu D
const DOCK = { x0: -6, x1: -2, z0: 1 }; // bến nhỏ khu C
const BANDS = [[7, 8], [6, 7], [4, 6]];
const stepTop = (s, z) => (z >= 7 ? s.tops[0] : z >= 6 ? s.tops[1] : s.tops[2]);
const inX = (s, x) => x >= s.x0 && x <= s.x1;

/** Độ cao mặt đi được tại (x, z), hoặc null nếu không đi được. */
export function groundAt(x, z) {
  if (x < X0 || x > X1) return null;
  if (z >= 8 && z <= 15) return 0;
  if (z >= 4 && z < 8) {
    if (inX(STEPS_A, x)) return stepTop(STEPS_A, z);
    if (inX(APRON_D, x)) return stepTop(APRON_D, z);
  }
  if (inX(DOCK, x) && z >= DOCK.z0 && z < 8) return 0;
  return null;
}
/** Bờ đất dốc từ mép lối đi (z = 8, y = 0) xuống đáy sông. */
export const slopeY = (z) => (z - 8) * 0.5;
/** Mặt đặt rác: nền đi được, bờ dốc hoặc mặt nước. */
export const surfaceY = (x, z) => groundAt(x, z) ?? Math.max(slopeY(z), waterY);

// ---------- Tiện ích dựng hình ----------
export function canvasTexture(w, h, draw) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  draw(c.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 4;
  return t;
}

/** Biển chữ hai mặt. */
export function makeLabel(text, { w = 2, h = 0.5, bg = '#1e3d2f', fg = '#fff', size = 40 } = {}) {
  const tex = canvasTexture(512, Math.round(512 * h / w), (g, cw, ch) => {
    g.fillStyle = bg; g.fillRect(0, 0, cw, ch);
    g.fillStyle = fg; g.font = `bold ${size}px system-ui, sans-serif`;
    g.textAlign = 'center'; g.textBaseline = 'middle';
    g.fillText(text, cw / 2, ch / 2);
  });
  const mat = new THREE.MeshBasicMaterial({ map: tex });
  const group = new THREE.Group();
  const geo = new THREE.PlaneGeometry(w, h);
  const front = new THREE.Mesh(geo, mat), back = new THREE.Mesh(geo, mat);
  back.rotation.y = Math.PI;
  back.position.z = -0.01;
  group.add(front, back);
  return group;
}

const box = (w, h, d, mat, x, y, z) => {
  const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat);
  m.position.set(x, y, z);
  m.castShadow = m.receiveShadow = true;
  return m;
};

/** Tứ giác trải dọc trục x, từ cạnh "xa" (phía -z) đến cạnh "gần". */
function quad(xa, xb, [yFar, zFar], [yNear, zNear], mat) {
  const g = new THREE.PlaneGeometry(1, 1);
  const p = g.attributes.position;
  p.setXYZ(0, xa, yFar, zFar); p.setXYZ(1, xb, yFar, zFar);
  p.setXYZ(2, xa, yNear, zNear); p.setXYZ(3, xb, yNear, zNear);
  g.computeVertexNormals();
  const m = new THREE.Mesh(g, mat);
  m.receiveShadow = true;
  return m;
}

function seeded(seed) {
  return () => ((seed = (seed * 16807) % 2147483647) - 1) / 2147483646;
}

function waterNormalMap() {
  const N = 128, TAU = Math.PI * 2;
  const h = (x, y) => Math.sin(TAU * (x * 3 + y * 2) / N) + 0.6 * Math.sin(TAU * (x * 5 - y * 7) / N + 1) + 0.4 * Math.sin(TAU * (y * 11) / N + 2);
  return (() => {
    const t = canvasTexture(N, N, (g) => {
      const img = g.createImageData(N, N);
      for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
        const dx = h(x + 1, y) - h(x - 1, y), dy = h(x, y + 1) - h(x, y - 1);
        const len = Math.hypot(dx, dy, 3);
        const i = (y * N + x) * 4;
        img.data[i] = (-dx / len * 0.5 + 0.5) * 255;
        img.data[i + 1] = (-dy / len * 0.5 + 0.5) * 255;
        img.data[i + 2] = (3 / len * 0.5 + 0.5) * 255;
        img.data[i + 3] = 255;
      }
      g.putImageData(img, 0, 0);
    });
    t.colorSpace = THREE.NoColorSpace;
    t.wrapS = t.wrapT = THREE.RepeatWrapping;
    t.repeat.set(30, 3);
    return t;
  })();
}

// ---------- Dựng màn ----------
export function buildLevel(scene) {
  const rnd = seeded(7);
  const SKY_DIRTY = new THREE.Color(0xb7c3c4), SKY_CLEAN = new THREE.Color(0x9fd4f5);
  scene.background = SKY_DIRTY.clone();
  scene.fog = new THREE.Fog(SKY_DIRTY.clone(), 45, 150);

  // Ánh sáng
  scene.add(new THREE.HemisphereLight(0xdcefff, 0x5a4a3a, 1.1));
  const sun = new THREE.DirectionalLight(0xfff0d0, 2.2);
  sun.position.set(-25, 40, 30);
  sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048);
  Object.assign(sun.shadow.camera, { left: -50, right: 50, top: 30, bottom: -30, near: 1, far: 120 });
  sun.shadow.bias = -0.0005;
  scene.add(sun);

  // Vật liệu
  const paving = canvasTexture(128, 128, (g) => {
    g.fillStyle = '#77736c'; g.fillRect(0, 0, 128, 128);
    for (let y = 0; y < 4; y++) for (let x = 0; x < 4; x++) {
      const v = 150 + Math.floor(rnd() * 30);
      g.fillStyle = `rgb(${v},${v - 4},${v - 10})`;
      g.fillRect(x * 32 + 1, y * 32 + 1, 30, 30);
    }
  });
  paving.wrapS = paving.wrapT = THREE.RepeatWrapping;
  paving.repeat.set(40, 1.75);
  const M = {
    paving: new THREE.MeshStandardMaterial({ map: paving, roughness: 0.9 }),
    concrete: new THREE.MeshStandardMaterial({ color: 0x9a9890, roughness: 0.95 }),
    wood: new THREE.MeshStandardMaterial({ color: 0x8b5a2b, roughness: 0.8 }),
    metal: new THREE.MeshStandardMaterial({ color: 0x5d6d7e, roughness: 0.5, metalness: 0.6 }),
    slope: new THREE.MeshStandardMaterial({ color: 0x5b4a36, roughness: 1 }),
    grass: new THREE.MeshStandardMaterial({ color: 0x6b6a45, roughness: 1 }),
    bed: new THREE.MeshStandardMaterial({ color: 0x2d2a22, roughness: 1 }),
  };

  // Lối đi ven bờ, bờ dốc, đáy sông, bờ đối diện
  scene.add(box(160, 0.6, 7, M.paving, 0, -0.3, 11.5));
  scene.add(box(160, 0.12, 0.3, M.concrete, 0, 0.06, 8.15));
  scene.add(quad(-80, 80, [-3, 2], [0, 8], M.slope));
  scene.add(quad(-80, 80, [-3, -6], [-3, 2], M.bed));
  scene.add(box(160, 3.6, 0.8, M.concrete, 0, -1.2, -6.4));
  scene.add(box(160, 0.4, 3, M.paving, 0, 0.4, -8.3));
  const grass = new THREE.Mesh(new THREE.PlaneGeometry(160, 5), M.grass);
  grass.rotation.x = -Math.PI / 2;
  grass.position.set(0, 0.01, 17.5);
  grass.receiveShadow = true;
  scene.add(grass);

  // Bậc xuống bờ (A) và sân cửa xả (D)
  for (const s of [STEPS_A, APRON_D]) {
    BANDS.forEach(([z0, z1], i) => {
      const top = s.tops[i];
      scene.add(box(s.x1 - s.x0, top + 3, z1 - z0, M.concrete, (s.x0 + s.x1) / 2, (top - 3) / 2, (z0 + z1) / 2));
    });
  }

  // Bến nhỏ (C)
  scene.add(box(DOCK.x1 - DOCK.x0, 0.15, 8 - DOCK.z0, M.wood, (DOCK.x0 + DOCK.x1) / 2, -0.075, (DOCK.z0 + 8) / 2));
  for (const [x, z] of [[DOCK.x0, DOCK.z0], [DOCK.x1, DOCK.z0], [DOCK.x0, 4.5], [DOCK.x1, 4.5]]) {
    const post = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.1, 3.4), M.wood);
    post.position.set(x, -1.6, z);
    scene.add(post);
  }

  // Cửa xả
  const pipe = new THREE.Mesh(new THREE.CylinderGeometry(0.6, 0.6, 1.2, 24, 1, true), M.concrete);
  pipe.rotation.x = Math.PI / 2;
  pipe.position.set(LEVEL.outfall.x, -0.95, LEVEL.outfall.z + 0.2);
  scene.add(pipe);
  const hole = new THREE.Mesh(new THREE.CircleGeometry(0.58, 24), new THREE.MeshBasicMaterial({ color: 0x111111 }));
  hole.position.set(LEVEL.outfall.x, -0.95, LEVEL.outfall.z + 0.3);
  scene.add(hole);

  // Nước
  const waterMat = new THREE.MeshStandardMaterial({
    color: 0x5a5a2c, roughness: 0.25, metalness: 0.1, transparent: true, opacity: 0.92,
    normalMap: waterNormalMap(), normalScale: new THREE.Vector2(0.4, 0.4),
  });
  const water = new THREE.Mesh(new THREE.PlaneGeometry(200, 12.7), waterMat);
  water.rotation.x = -Math.PI / 2;
  water.position.set(0, waterY, -0.15);
  scene.add(water);

  // Váng bẩn trên mặt nước: mờ dần khi công trình xử lý chạy
  const scumMat = new THREE.MeshBasicMaterial({ color: 0x4a4a1a, transparent: true, opacity: 0.5, depthWrite: false });
  const scum = new THREE.InstancedMesh(new THREE.CircleGeometry(1, 16), scumMat, 24);
  const tmp = new THREE.Object3D();
  for (let i = 0; i < 24; i++) {
    tmp.position.set(-40 + rnd() * 80, waterY + 0.02, -5 + rnd() * 9.5);
    tmp.rotation.set(-Math.PI / 2, 0, 0);
    tmp.scale.set(1 + rnd() * 2.5, 0.6 + rnd() * 1.5, 1);
    tmp.updateMatrix();
    scum.setMatrixAt(i, tmp.matrix);
  }
  scene.add(scum);

  // Nhà phố hai bên (instanced, một lần vẽ)
  const winTex = canvasTexture(64, 128, (g) => {
    g.fillStyle = '#fff'; g.fillRect(0, 0, 64, 128);
    g.fillStyle = '#5b6770';
    for (let y = 0; y < 4; y++) g.fillRect(14, 10 + y * 30, 36, 18);
  });
  const houseMat = new THREE.MeshStandardMaterial({ map: winTex, roughness: 0.9 });
  const houseColors = [0xf6e3a1, 0xe8b4a0, 0xc9d6df, 0xf1f1e6, 0xb5d3a7, 0xf3c98b, 0xd9c2e9];
  const HOUSES = 64;
  const houses = new THREE.InstancedMesh(new THREE.BoxGeometry(1, 1, 1), houseMat, HOUSES);
  const col = new THREE.Color();
  for (let i = 0; i < HOUSES; i++) {
    const far = i % 2, k = i >> 1;
    const w = 4 + rnd() * 2.5, h = 6 + rnd() * 10, d = 8 + rnd() * 4;
    tmp.position.set(-78 + k * 5, h / 2 + (far ? 0.6 : 0), far ? -10 - d / 2 : 20 + d / 2);
    tmp.rotation.set(0, 0, 0);
    tmp.scale.set(w, h, d);
    tmp.updateMatrix();
    houses.setMatrixAt(i, tmp.matrix);
    houses.setColorAt(i, col.setHex(houseColors[Math.floor(rnd() * houseColors.length)]));
  }
  houses.castShadow = true;
  scene.add(houses);

  // Lan can sau lối đi
  const posts = new THREE.InstancedMesh(new THREE.BoxGeometry(0.08, 1, 0.08), M.metal, 81);
  for (let i = 0; i <= 80; i++) {
    tmp.position.set(-80 + i * 2, 0.5, 15.2); tmp.scale.set(1, 1, 1); tmp.updateMatrix();
    posts.setMatrixAt(i, tmp.matrix);
  }
  scene.add(posts, box(160, 0.06, 0.06, M.metal, 0, 1, 15.2), box(160, 0.04, 0.04, M.metal, 0, 0.55, 15.2));

  // Ranh giới công việc: rào sọc vàng đen trên bờ và phao trên sông
  const tape = canvasTexture(64, 16, (g) => {
    for (let i = 0; i < 8; i++) { g.fillStyle = i % 2 ? '#111' : '#f5c400'; g.beginPath(); g.moveTo(i * 8 + 8, 0); g.lineTo(i * 8 + 16, 0); g.lineTo(i * 8 + 8, 16); g.lineTo(i * 8, 16); g.fill(); }
  });
  tape.wrapS = THREE.RepeatWrapping; tape.repeat.set(6, 1);
  const tapeMat = new THREE.MeshBasicMaterial({ map: tape, side: THREE.DoubleSide });
  const buoyMat = new THREE.MeshStandardMaterial({ color: 0xffb000, roughness: 0.6 });
  for (const x of [X0 - 0.3, X1 + 0.3]) {
    const t = new THREE.Mesh(new THREE.PlaneGeometry(7, 0.25), tapeMat);
    t.position.set(x, 0.9, 11.5); t.rotation.y = Math.PI / 2;
    scene.add(t, box(0.1, 1.1, 0.1, M.metal, x, 0.55, 8.2), box(0.1, 1.1, 0.1, M.metal, x, 0.55, 14.9));
    for (let z = -5.5; z <= 5; z += 0.8) {
      const b = new THREE.Mesh(new THREE.SphereGeometry(0.18, 8, 6), buoyMat);
      b.position.set(x, waterY + 0.05, z);
      scene.add(b);
    }
  }

  // Biển khu vực
  for (const zone of LEVEL.zones) {
    if (zone.id === 'T') continue;
    const sign = makeLabel(zone.name, { w: 2.6, h: 0.45, size: 34 });
    sign.position.set(zone.x0 + 1.2, 2.1, 14.6);
    sign.rotation.y = -Math.PI / 2;
    scene.add(sign, box(0.08, 1.9, 0.08, M.metal, zone.x0 + 1.2, 0.95, 14.6));
  }

  // Bàn phân loại và ba thùng màu (đã có sẵn từ đầu)
  const T = LEVEL.table;
  scene.add(box(2.4, 0.08, 1.1, M.wood, T.x, 0.9, T.z));
  for (const [dx, dz] of [[-1.1, -0.45], [1.1, -0.45], [-1.1, 0.45], [1.1, 0.45]]) scene.add(box(0.08, 0.9, 0.08, M.wood, T.x + dx, 0.45, T.z + dz));
  Object.entries(CATS).forEach(([, c], i) => {
    const bin = new THREE.Mesh(new THREE.CylinderGeometry(0.35, 0.3, 0.8, 16), new THREE.MeshStandardMaterial({ color: c.color, roughness: 0.6 }));
    bin.position.set(T.x - 0.9 + i * 0.9, 0.4, T.z + 1.2);
    bin.castShadow = true;
    const label = makeLabel(c.name.toUpperCase(), { w: 0.8, h: 0.22, bg: c.color, size: 52 });
    label.position.set(T.x - 0.9 + i * 0.9, 0.95, T.z + 0.84);
    scene.add(bin, label);
  });
  const tableSign = makeLabel('BÀN PHÂN LOẠI', { w: 1.6, h: 0.3, size: 52 });
  tableSign.position.set(T.x, 1.5, T.z - 0.5);
  scene.add(tableSign);

  // Điểm nhận vật lớn
  const R = LEVEL.receive;
  const ring = new THREE.Mesh(new THREE.RingGeometry(1.4, 1.7, 32), new THREE.MeshBasicMaterial({ color: 0x2ecc71, side: THREE.DoubleSide }));
  ring.rotation.x = -Math.PI / 2;
  ring.position.set(R.x, 0.02, R.z);
  const rsign = makeLabel('ĐIỂM NHẬN VẬT LỚN', { w: 2, h: 0.35, bg: '#1e8449', size: 44 });
  rsign.position.set(R.x, 2, R.z + 2.1);
  scene.add(ring, rsign, box(0.08, 1.9, 0.08, M.metal, R.x, 0.95, R.z + 2.1));

  // Cảnh quan phục hồi: cây, hoa ven bờ, vịt trên sông (lớn dần sau nghiệm thu)
  const TREES = 34, FLOWERS = 160, DUCKS = 5;
  const trunks = new THREE.InstancedMesh(new THREE.CylinderGeometry(0.12, 0.18, 1.6), M.wood, TREES);
  const crowns = new THREE.InstancedMesh(new THREE.IcosahedronGeometry(1.2, 1), new THREE.MeshStandardMaterial({ color: 0x3f9b4a, roughness: 0.9, flatShading: true }), TREES);
  const flowers = new THREE.InstancedMesh(new THREE.SphereGeometry(0.12, 6, 4), new THREE.MeshStandardMaterial({ roughness: 0.8 }), FLOWERS);
  const treePos = Array.from({ length: TREES }, (_, i) => [-80 + i * 4.8 + rnd() * 2, i % 3 === 0 ? 16.2 : 18.3]);
  const flowerPos = Array.from({ length: FLOWERS }, () => {
    const z = 6 + rnd() * 1.8;
    return [X0 + rnd() * (X1 - X0), slopeY(z) + 0.08, z];
  });
  const flowerCols = [0xff6b9a, 0xffd23f, 0xffffff, 0xb388ff];
  flowerPos.forEach((_, i) => flowers.setColorAt(i, col.setHex(flowerCols[i % 4])));
  const duckGeo = new THREE.SphereGeometry(0.22, 10, 8);
  duckGeo.scale(1.4, 0.8, 1);
  const duckMat = new THREE.MeshStandardMaterial({ color: 0xf5f5f0, roughness: 0.7 });
  const ducks = Array.from({ length: DUCKS }, (_, i) => {
    const d = new THREE.Mesh(duckGeo, duckMat);
    const head = new THREE.Mesh(new THREE.SphereGeometry(0.12, 8, 6), duckMat);
    const beak = new THREE.Mesh(new THREE.ConeGeometry(0.05, 0.14, 6), new THREE.MeshStandardMaterial({ color: 0xff9f1a }));
    head.position.set(0.28, 0.2, 0); beak.position.set(0.42, 0.18, 0); beak.rotation.z = -Math.PI / 2;
    d.add(head, beak);
    d.userData = { cx: -30 + i * 15, r: 2 + rnd() * 2, a: rnd() * 6 };
    d.visible = false;
    scene.add(d);
    return d;
  });
  for (const m of [trunks, crowns, flowers]) { m.castShadow = m !== flowers; scene.add(m); }
  let lastGrow = -1;
  function setGrow(g) {
    if (Math.abs(g - lastGrow) < 0.002) return;
    lastGrow = g;
    treePos.forEach(([x, z], i) => {
      const s = Math.max(0.001, g * (0.8 + (i % 4) * 0.12));
      tmp.rotation.set(0, i, 0);
      tmp.position.set(x, 0.8 * s, z); tmp.scale.setScalar(s); tmp.updateMatrix(); trunks.setMatrixAt(i, tmp.matrix);
      tmp.position.set(x, 2.2 * s, z); tmp.updateMatrix(); crowns.setMatrixAt(i, tmp.matrix);
    });
    flowerPos.forEach(([x, y, z], i) => {
      tmp.position.set(x, y, z); tmp.scale.setScalar(Math.max(0.001, g)); tmp.updateMatrix(); flowers.setMatrixAt(i, tmp.matrix);
    });
    trunks.instanceMatrix.needsUpdate = crowns.instanceMatrix.needsUpdate = flowers.instanceMatrix.needsUpdate = true;
    for (const d of ducks) d.visible = g > 0.5;
  }
  setGrow(0);

  // Màu theo trạng thái môi trường
  const C = {
    slopeDirty: new THREE.Color(0x5b4a36), slopeClean: new THREE.Color(0x6f8f4e),
    grassDirty: new THREE.Color(0x6b6a45), grassClean: new THREE.Color(0x5fa04e),
    waterDirty: new THREE.Color(0x5a5a2c), waterClean: new THREE.Color(0x2f8fb8),
  };

  /** Máy ảnh cố định cho ảnh trước và sau. */
  const photoCam = new THREE.PerspectiveCamera(55, 16 / 9, 0.1, 300);
  photoCam.position.set(-16, 5, 17);
  photoCam.lookAt(6, -1, 2);

  return {
    photoCam,
    sun,
    /** clean: tỉ lệ rác đã gom, purity: tiến độ xử lý nước, grow: cảnh quan sau nghiệm thu. */
    update(dt, { clean, purity, grow, time }) {
      M.slope.color.lerpColors(C.slopeDirty, C.slopeClean, clean * clean);
      M.grass.color.lerpColors(C.grassDirty, C.grassClean, Math.max(clean * 0.5, grow));
      waterMat.color.lerpColors(C.waterDirty, C.waterClean, purity);
      waterMat.opacity = 0.92 - purity * 0.2;
      scumMat.opacity = 0.5 * (1 - purity);
      scum.visible = purity < 1;
      scene.background.lerpColors(SKY_DIRTY, SKY_CLEAN, purity);
      scene.fog.color.copy(scene.background);
      if (settings.waterFx) {
        waterMat.normalMap.offset.x = time * 0.02;
        waterMat.normalMap.offset.y = time * 0.007;
      }
      setGrow(grow);
      for (const d of ducks) {
        if (!d.visible) continue;
        const u = d.userData;
        u.a += dt * 0.15;
        d.position.set(u.cx + Math.cos(u.a) * u.r, waterY + 0.08, -1 + Math.sin(u.a) * u.r * 0.6);
        d.rotation.y = -u.a - Math.PI / 2;
      }
    },
  };
}
