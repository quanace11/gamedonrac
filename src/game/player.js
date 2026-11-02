// Người chơi góc nhìn thứ nhất: di chuyển, va chạm, dùng dụng cụ, tương tác và chế độ đặt máy.
import * as THREE from 'three';
import { TRASH, TOOLS, TOOL_ORDER, LEVEL } from '../data.js';
import { store, settings, saveGame, basketCap, basketLoad } from '../core/state.js';
import { input } from '../core/input.js';
import { groundAt } from '../world/level.js';

const EYE = 1.6;

export function createPlayer(ctx) {
  const { camera, trash, machines, audio } = ctx;
  const S = () => store.state;
  const pos = new THREE.Vector3();
  const dir = new THREE.Vector3();
  const handPoint = new THREE.Vector3();
  let yaw = 0, pitch = 0, eye = EYE, bobT = 0, useTimer = 0, fullWarn = 0;

  /** Thông tin tâm ngắm cho HUD. */
  const aim = { text: '', far: false, interact: '', build: null };

  function setTool(id) {
    if (!S().tools[id]) {
      ctx.toast(`Chưa có ${TOOLS[id].name}.${id === 'net' ? ' Mua trong cửa hàng (Tab).' : ''}`, 'warn');
      return;
    }
    if (S().tool !== id) { S().tool = id; audio.play('ui'); if (id === 'net') ctx.hint('net'); }
  }

  function move(dt) {
    const f = (input.held('forward') ? 1 : 0) - (input.held('back') ? 1 : 0);
    const r = (input.held('right') ? 1 : 0) - (input.held('left') ? 1 : 0);
    if (!f && !r) return false;
    const speed = (input.held('sprint') ? 7 : 4.5) * (machines.hooked ? 0.55 : 1);
    const sin = Math.sin(yaw), cos = Math.cos(yaw);
    let vx = -sin * f + cos * r, vz = -cos * f - sin * r;
    const len = Math.hypot(vx, vz);
    vx = vx / len * speed * dt; vz = vz / len * speed * dt;
    const here = groundAt(pos.x, pos.z) ?? 0;
    const ok = (x, z) => {
      const g = groundAt(x, z);
      return g != null && g - here < 0.45;
    };
    if (ok(pos.x + vx + Math.sign(vx) * 0.25, pos.z)) pos.x += vx;
    if (ok(pos.x, pos.z + vz + Math.sign(vz) * 0.25)) pos.z += vz;
    for (const s of machines.solids()) {
      const dx = pos.x - s.x, dz = pos.z - s.z, d = Math.hypot(dx, dz), min = s.r + 0.3;
      if (d < min && d > 0.001 && ok(s.x + dx / d * min, s.z + dz / d * min)) {
        pos.x = s.x + dx / d * min;
        pos.z = s.z + dz / d * min;
      }
    }
    return true;
  }

  function collect(i) {
    const s = S();
    const it = trash.items[i], t = TRASH[it.type];
    if (basketLoad() + t.vol > basketCap()) {
      if (performance.now() - fullWarn > 1500) {
        fullWarn = performance.now();
        const d = Math.round(Math.hypot(pos.x - LEVEL.table.x, pos.z - LEVEL.table.z));
        ctx.toast(`Giỏ đầy! Về bàn phân loại ở khu C (cách ${d} m)${s.placed.conveyor ? ' hoặc phễu băng chuyền' : ''}.`, 'warn');
        audio.play('error');
        ctx.hint('full');
      }
      return;
    }
    if (trash.collect(i, () => handPoint)) {
      s.basket.push(it.type);
      audio.play(it.water ? 'splash' : t.cat);
      if (basketLoad() >= basketCap()) ctx.hint('full');
    }
  }

  return {
    pos,
    dir,
    aim,
    get yaw() { return yaw; },

    spawn() {
      const p = S().player || LEVEL.spawn;
      pos.set(p.x, 0, p.z);
      if (groundAt(pos.x, pos.z) == null) pos.set(LEVEL.spawn.x, 0, LEVEL.spawn.z);
      yaw = p.yaw ?? LEVEL.spawn.yaw;
      pitch = p.pitch ?? -0.15;
      eye = (groundAt(pos.x, pos.z) ?? 0) + EYE;
    },
    teleport(x, z) { pos.set(x, 0, z); },
    remember() { S().player = { x: pos.x, z: pos.z, yaw, pitch }; },

    update(dt, active) {
      const s = S();
      let moving = false;
      if (active) {
        const [mx, my] = input.look();
        const k = 0.0022 * settings.sens;
        yaw -= mx * k;
        pitch = Math.max(-1.45, Math.min(1.45, pitch - my * k));

        if (input.hit('tool1')) setTool('hand');
        if (input.hit('tool2')) setTool('net');
        if (input.hit('tool3')) setTool('hook');
        const w = input.wheel();
        if (w) {
          const owned = TOOL_ORDER.filter((t) => s.tools[t]);
          setTool(owned[(owned.indexOf(s.tool) + w + owned.length) % owned.length]);
        }
        if (input.hit('build')) { ctx.build = !ctx.build; audio.play('ui'); if (ctx.build) ctx.hint('buildMode'); }
        moving = move(dt);
      }

      // Máy ảnh
      const ground = groundAt(pos.x, pos.z) ?? 0;
      eye += (ground + EYE - eye) * Math.min(1, dt * 12);
      bobT = moving ? bobT + dt * 9 : 0;
      const bob = settings.headBob ? Math.sin(bobT) * 0.04 : 0;
      camera.position.set(pos.x, eye + bob, pos.z);
      camera.rotation.set(pitch, yaw, 0, 'YXZ');
      camera.updateMatrixWorld();
      camera.getWorldDirection(dir);
      handPoint.copy(camera.position).addScaledVector(dir, 0.5).y -= 0.4;

      // Tâm ngắm
      const tool = TOOLS[s.tool];
      aim.text = ''; aim.far = false; aim.build = null;
      let target = -1, gem = -1;
      if (ctx.build) {
        aim.build = machines.buildTarget(camera.position, dir);
        aim.text = aim.build ? aim.build.label : 'Nhắm vào khung lắp đặt';
      } else {
        gem = trash.pickGem(camera.position, dir, TOOLS.net.reach);
        if (gem >= 0) aim.text = `Đồ sưu tầm: ${LEVEL.collectibles[gem].name}`;
        else if (s.tool === 'hook') {
          if (machines.hooked) aim.text = 'Đang kéo – nhấp để thả';
          else if (machines.aimObstacle(camera.position, dir, tool.reach)) aim.text = `${LEVEL.obstacle.name} – nhấp để móc`;
        } else {
          const any = trash.pick(camera.position, dir, TOOLS.net.reach, tool.radius, s.tool === 'hand');
          if (any >= 0) {
            const it = trash.items[any];
            const d = camera.position.distanceTo(new THREE.Vector3(it.x, it.water ? LEVEL.waterY : it.y, it.z));
            aim.text = TRASH[it.type].name;
            if (d > tool.reach) { aim.far = true; aim.text += ' – ngoài tầm với' + (s.tool === 'hand' ? ', cần vợt' : ''); }
            else target = any;
          }
        }
      }

      // Dùng dụng cụ
      if (active) {
        useTimer -= dt;
        if (input.lmbHit && ctx.build) { if (aim.build) machines.applyBuild(aim.build); }
        else if (input.lmbHit && gem >= 0) {
          trash.takeGem(gem);
          audio.play('collect');
          ctx.toast(`Tìm thấy đồ sưu tầm: ${LEVEL.collectibles[gem].name} (${s.collectibles.length}/${LEVEL.collectibles.length})`, 'good');
          saveGame();
        } else if (s.tool === 'hook') { if (input.lmbHit) machines.tryHook(camera.position, dir, tool.reach); }
        else if (target >= 0 && (input.lmbHit || (tool.rate && input.lmb && useTimer <= 0))) {
          collect(target);
          useTimer = tool.rate;
        }
      }

      // Điểm tương tác gần nhất trước mặt
      let best = null, bestD = Infinity;
      for (const it of ctx.interactables) {
        if (it.when && !it.when()) continue;
        const dx = it.x - pos.x, dz = it.z - pos.z, d = Math.hypot(dx, dz);
        if (d > it.r || d >= bestD) continue;
        if (d > 0.8 && (dx * dir.x + dz * dir.z) / d < 0.3) continue;
        best = it; bestD = d;
      }
      aim.interact = best && !ctx.build ? best.label() : '';
      if (active && best && !ctx.build && input.hit('interact')) best.act();
    },
  };
}
