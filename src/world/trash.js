// Rác trong màn: sinh vị trí cố định theo hạt giống, vẽ bằng InstancedMesh (mỗi loại một lần vẽ),
// chọn bằng tia ngắm, hiệu ứng bay về giỏ, rác trôi hữu hạn từ cửa xả và đồ sưu tầm.
import * as THREE from 'three';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { TRASH, LEVEL, ECON } from '../data.js';
import { store } from '../core/state.js';
import { surfaceY } from './level.js';

const SCALE = 1.7;
const { waterY, eddy: EDDY, outfall: OUT, obstacle: OBS } = LEVEL;

function shapeGeo(shape) {
  const cyl = (rt, rb, h, seg = 10) => new THREE.CylinderGeometry(rt, rb, h, seg);
  let g;
  switch (shape) {
    case 'bottle': g = mergeGeometries([cyl(0.07, 0.07, 0.2), cyl(0.03, 0.065, 0.08).translate(0, 0.14, 0), cyl(0.033, 0.033, 0.03).translate(0, 0.19, 0)]); g.rotateZ(Math.PI / 2); break;
    case 'bag': g = new THREE.IcosahedronGeometry(0.13, 1); g.scale(1.3, 0.45, 1.1); break;
    case 'cup': g = cyl(0.055, 0.04, 0.12); g.rotateZ(Math.PI / 2); break;
    case 'foam': g = new THREE.BoxGeometry(0.24, 0.08, 0.18); break;
    case 'sandal': g = new THREE.SphereGeometry(0.07, 10, 6); g.scale(1, 0.3, 2); break;
    case 'jug': g = mergeGeometries([new THREE.BoxGeometry(0.18, 0.26, 0.13), cyl(0.035, 0.035, 0.05).translate(0.04, 0.155, 0)]); g.rotateZ(Math.PI / 2.3); break;
    case 'can': g = cyl(0.034, 0.034, 0.12, 12); g.rotateZ(Math.PI / 2); break;
    case 'tin': g = cyl(0.05, 0.05, 0.07, 12); break;
    case 'spray': g = mergeGeometries([cyl(0.035, 0.035, 0.17), cyl(0.02, 0.03, 0.04).translate(0, 0.105, 0)]); g.rotateZ(Math.PI / 2); break;
    case 'wire': g = new THREE.TorusGeometry(0.09, 0.014, 6, 16); g.rotateX(Math.PI / 2); break;
    case 'carton': g = new THREE.BoxGeometry(0.13, 0.08, 0.2); break;
    case 'rag': g = new THREE.DodecahedronGeometry(0.12); g.scale(1.4, 0.35, 1.2); break;
    default: g = new THREE.SphereGeometry(0.1, 10, 8); g.scale(1, 0.85, 1);
  }
  g.scale(SCALE, SCALE, SCALE);
  g.computeBoundingBox();
  g.translate(0, -g.boundingBox.min.y, 0); // đặt đáy vật lên mặt đất
  return g;
}

function seeded(seed) {
  return () => ((seed = (seed * 16807) % 2147483647) - 1) / 2147483646;
}

/** Sinh danh sách rác cố định. Mỗi vật có mã (chỉ số) duy nhất để lưu chính xác. */
function generate() {
  const rnd = seeded(2026);
  const lerp = ([a, b]) => a + rnd() * (b - a);
  const floatTypes = TRASH.map((_, i) => i).filter((i) => TRASH[i].float);
  const keepOut = [LEVEL.table, LEVEL.receive, ...Object.values(LEVEL.slots)];
  const blocked = (x, z, area) =>
    (area === 'walk' && keepOut.some((p) => Math.hypot(p.x - x, p.z - z) < 2.6))
    || (area === 'water' && x > -6.8 && x < -1.2); // dưới bến gỗ
  const items = [];
  let flowIndex = 0;
  for (const g of LEVEL.trash) {
    for (let k = 0; k < g.n; k++) {
      const water = g.area === 'water' || g.area === 'flow';
      const type = water ? floatTypes[Math.floor(rnd() * floatTypes.length)] : Math.floor(rnd() * TRASH.length);
      let x = 0, z = 0;
      for (let tries = 0; tries < 20; tries++) {
        if (g.area === 'walk') { x = lerp(g.x); z = 8.5 + rnd() * 6.1; }
        else if (g.area === 'steps') { x = lerp(g.x); z = 4.2 + rnd() * 3.6; }
        else if (g.area === 'slope') { x = lerp(g.x); z = 6.3 + rnd() * 1.4; }
        else if (g.area === 'water') { x = lerp(g.x); z = lerp(g.z); }
        else if (g.area === 'pile') {
          const a = rnd() * Math.PI * 2, r = 0.75 + Math.sqrt(rnd()) * 1.3;
          x = OBS.x + Math.cos(a) * r * 1.7;
          z = Math.min(7.8, Math.max(4.15, OBS.z + Math.sin(a) * r));
        } else { x = OUT.x; z = OUT.z; }
        if (!blocked(x, z, g.area)) break;
      }
      items.push({
        type, zone: g.zone, area: g.area, water, x, z, y: 0, ry: rnd() * Math.PI * 2,
        flow: g.area === 'flow' ? flowIndex++ : -1, inst: 0,
      });
    }
  }
  return items;
}

export function createTrash(scene) {
  const items = generate();
  const flowItems = items.filter((it) => it.flow >= 0);
  const flowCount = flowItems.length;
  const meshes = TRASH.map((t) => {
    const n = items.filter((it) => TRASH[it.type] === t).length;
    const mat = new THREE.MeshStandardMaterial({ color: t.color, roughness: t.id === 'glass' ? 0.2 : 0.6, metalness: t.cat === 'metal' ? 0.5 : 0 });
    const m = new THREE.InstancedMesh(shapeGeo(t.shape), mat, Math.max(n, 1));
    m.count = n;
    m.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    m.frustumCulled = false;
    scene.add(m);
    return m;
  });
  const counters = TRASH.map(() => 0);
  for (const it of items) it.inst = counters[it.type]++;

  const totalMass = items.reduce((n, it) => n + TRASH[it.type].mass, 0);
  const zones = {};
  for (const it of items) (zones[it.zone] ||= { total: 0, done: 0 }).total++;
  let collectedMass = 0;

  // Đồ sưu tầm: phát sáng nhẹ, đếm riêng, không tính tiến độ
  const gemMat = new THREE.MeshStandardMaterial({ color: 0xffd54a, emissive: 0xffb300, emissiveIntensity: 0.6, metalness: 0.4, roughness: 0.3 });
  const gems = LEVEL.collectibles.map((c) => {
    const m = new THREE.Mesh(new THREE.OctahedronGeometry(0.12), gemMat);
    m.position.set(c.x, c.y + 0.15, c.z);
    scene.add(m);
    return m;
  });

  // Đánh dấu rác còn sót (chế độ phát triển)
  const markers = new THREE.InstancedMesh(new THREE.CylinderGeometry(0.04, 0.04, 3), new THREE.MeshBasicMaterial({ color: 0xff2d55 }), items.length);
  markers.visible = false;
  markers.frustumCulled = false;
  scene.add(markers);

  const tmp = new THREE.Object3D();
  const anims = [];
  const v = new THREE.Vector3();

  function writeMatrix(it, scale = 1, time = 0) {
    let y = it.y, tilt = 0;
    if (it.water) {
      y = waterY - 0.05;
      if (time) { y += Math.sin(time * 1.6 + it.ry * 5) * 0.03; tilt = Math.sin(time * 1.2 + it.ry * 3) * 0.12; }
    }
    tmp.position.set(it.x, y, it.z);
    tmp.rotation.set(tilt, it.ry, tilt * 0.5);
    tmp.scale.setScalar(scale);
    tmp.updateMatrix();
    meshes[it.type].setMatrixAt(it.inst, tmp.matrix);
  }
  const hidden = (i) => {
    const it = items[i];
    return store.state.items[i] === 1 || (it.flow >= 0 && store.state.flow[it.flow][0] === 0);
  };

  const api = {
    items,
    flowCount,
    totalMass,
    zones,
    get collectedMass() { return collectedMass; },
    get ratio() { return collectedMass / totalMass; },

    /** Áp trạng thái đã lưu lên cảnh (khi bắt đầu hoặc tải ván). */
    restore() {
      const s = store.state;
      collectedMass = 0;
      anims.length = 0;
      for (const z of Object.values(zones)) z.done = 0;
      items.forEach((it, i) => {
        if (it.flow >= 0) {
          const f = s.flow[it.flow];
          if (f[0] > 0) { it.x = f[1]; it.z = f[2]; } else { it.x = OUT.x; it.z = OUT.z; }
        }
        it.y = it.water ? waterY : surfaceY(it.x, it.z);
        if (s.items[i]) { collectedMass += TRASH[it.type].mass; zones[it.zone].done++; }
        writeMatrix(it, hidden(i) ? 0 : 1);
      });
      for (const m of meshes) m.instanceMatrix.needsUpdate = true;
      gems.forEach((g, i) => { g.visible = !s.collectibles.includes(i); });
    },

    /** Vật gần tia ngắm nhất trong tầm với. preferNear: ưu tiên vật gần (tay) hay gần tâm (vợt). */
    pick(origin, dir, reach, radius, preferNear) {
      let best = -1, bestScore = Infinity;
      for (let i = 0; i < items.length; i++) {
        if (hidden(i)) continue;
        const it = items[i];
        v.set(it.x, (it.water ? waterY : it.y) + 0.1, it.z).sub(origin);
        const t = v.dot(dir);
        if (t < 0 || t > reach) continue;
        const perp2 = v.lengthSq() - t * t;
        if (perp2 > radius * radius) continue;
        const score = preferNear ? t : perp2;
        if (score < bestScore) { bestScore = score; best = i; }
      }
      return best;
    },

    /** Thu gom vật i; target() trả về điểm bay tới (giỏ hoặc máy). */
    collect(i, target) {
      const s = store.state;
      if (hidden(i)) return false;
      const it = items[i];
      s.items[i] = 1;
      if (it.flow >= 0) s.flow[it.flow] = [3, it.x, it.z];
      collectedMass += TRASH[it.type].mass;
      zones[it.zone].done++;
      anims.push({ it, t: 0, from: new THREE.Vector3(it.x, it.water ? waterY : it.y, it.z), target });
      return true;
    },

    /** Rác nổi gần nhất trong bán kính r quanh (x, z), dùng cho máy vớt. */
    nearestFloating(x, z, r) {
      let best = -1, bd = r;
      items.forEach((it, i) => {
        if (!it.water || hidden(i)) return;
        const d = Math.hypot(it.x - x, it.z - z);
        if (d < bd) { bd = d; best = i; }
      });
      return best;
    },
    /** Số rác trôi đang chờ thoát khỏi cửa xả hoặc còn trôi tới vùng xoáy. */
    flowIncoming() {
      return store.state.flow.filter((f) => f[0] <= 1).length;
    },
    /** Rác đống cửa xả còn đè quanh vật cản. */
    pileNear(x, z, r) {
      return items.filter((it, i) => it.area === 'pile' && !hidden(i) && Math.hypot(it.x - x, it.z - z) < r).length;
    },

    pickGem(origin, dir, reach) {
      for (let i = 0; i < gems.length; i++) {
        if (!gems[i].visible) continue;
        v.copy(gems[i].position).sub(origin);
        const t = v.dot(dir);
        if (t > 0 && t < reach && v.lengthSq() - t * t < 0.16) return i;
      }
      return -1;
    },
    takeGem(i) {
      gems[i].visible = false;
      store.state.collectibles.push(i);
    },

    showMarkers(on) { markers.visible = on; },

    update(dt, time, waterFx) {
      const s = store.state;
      // Rác trôi hữu hạn: chỉ thoát ra sau khi kéo vật cản khỏi cửa xả
      if (s.obstacle.done) {
        s.flowTimer += dt;
        while (s.flowTimer >= ECON.flow.interval) {
          s.flowTimer -= ECON.flow.interval;
          const k = s.flow.findIndex((f) => f[0] === 0);
          if (k < 0) { s.flowTimer = 0; break; }
          const it = flowItems[k];
          it.x = OUT.x + (Math.random() - 0.5); it.z = OUT.z - 0.5;
          s.flow[k] = [1, it.x, it.z];
        }
      }
      for (const it of items) {
        if (it.flow < 0) continue;
        const f = s.flow[it.flow];
        if (f[0] === 1) {
          it.x += ECON.flow.speed * dt;
          it.z += (EDDY.z - it.z) * 0.5 * dt + Math.sin(time + it.ry * 7) * 0.2 * dt;
          if (it.x >= EDDY.x - EDDY.r * 0.6) f[0] = 2;
        } else if (f[0] === 2) {
          const dx = it.x - EDDY.x, dz = it.z - EDDY.z;
          const r = Math.min(EDDY.r, Math.max(0.4, Math.hypot(dx, dz) * 0.999));
          const a = Math.atan2(dz, dx) + dt * 0.35;
          it.x = EDDY.x + Math.cos(a) * r;
          it.z = EDDY.z + Math.sin(a) * r;
        } else continue;
        f[1] = it.x; f[2] = it.z;
        it.ry += dt * 0.3;
      }

      // Mặt nước nhấp nhô
      let dirty = false;
      items.forEach((it, i) => {
        if (it.water && !hidden(i) && (waterFx || it.flow >= 0)) { writeMatrix(it, 1, waterFx ? time : 0); dirty = true; }
      });

      // Hiệu ứng bay về giỏ / máy
      for (let k = anims.length - 1; k >= 0; k--) {
        const a = anims[k];
        a.t += dt / 0.32;
        const e = Math.min(1, a.t);
        v.copy(a.from).lerp(a.target(), e * e);
        v.y += Math.sin(e * Math.PI) * 0.6;
        tmp.position.copy(v);
        tmp.rotation.set(e * 6, a.it.ry + e * 4, 0);
        tmp.scale.setScalar(Math.max(0.001, 1 - e * 0.7));
        tmp.updateMatrix();
        meshes[a.it.type].setMatrixAt(a.it.inst, tmp.matrix);
        if (a.t >= 1) { writeMatrix(a.it, 0); anims.splice(k, 1); }
        dirty = true;
      }
      if (dirty) for (const m of meshes) m.instanceMatrix.needsUpdate = true;

      gemMat.emissiveIntensity = 0.4 + Math.sin(time * 4) * 0.3;
      gems.forEach((g) => { g.rotation.y = time; });

      if (markers.visible) {
        items.forEach((it, i) => {
          tmp.position.set(it.x, (it.water ? waterY : it.y) + 1.5, it.z);
          tmp.rotation.set(0, 0, 0);
          tmp.scale.setScalar(hidden(i) ? 0 : 1);
          tmp.updateMatrix();
          markers.setMatrixAt(i, tmp.matrix);
        });
        markers.instanceMatrix.needsUpdate = true;
      }
    },
  };
  return api;
}
