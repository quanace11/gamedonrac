// HUD trong lúc chơi: tâm ngắm, nhiệm vụ, tiền, bảng công trình, bảng máy, thanh dụng cụ, chỉ dẫn, thông báo.
import { TOOLS, TOOL_ORDER, LEVEL } from '../data.js';
import { store, fmtMat, basketCap, basketLoad, pendingCount } from '../core/state.js';
import { audio } from '../core/audio.js';

const $ = (id) => document.getElementById(id);
/** Chỉ ghi DOM khi nội dung đổi. */
const set = (el, html) => { if (el._h !== html) { el._h = html; el.innerHTML = html; } };

export function createHud(ctx) {
  const el = Object.fromEntries(['hud', 'aim', 'quests', 'wallet', 'site', 'machines', 'toolbar', 'interact', 'hint', 'toasts', 'buildbar'].map((id) => [id, $(id)]));
  let lastHint = null;

  return {
    show(on) { el.hud.hidden = !on; },

    toast(msg, kind = 'info') {
      const d = document.createElement('div');
      d.className = `toast ${kind}`;
      d.textContent = msg;
      el.toasts.prepend(d);
      while (el.toasts.children.length > 4) el.toasts.lastChild.remove();
      setTimeout(() => d.classList.add('out'), 4200);
      setTimeout(() => d.remove(), 4700);
    },

    update(hintText) {
      const s = store.state, { player, quests, trash, machines } = ctx;
      const a = player.aim;
      set(el.aim, a.text ? `<span class="${a.far ? 'far' : ''}">${a.text}</span>` : '');
      set(el.interact, a.interact ? `<kbd>E</kbd> ${a.interact}` : '');
      el.buildbar.hidden = !ctx.build;

      set(el.quests, '<h3>Nhiệm vụ</h3>' + quests.active().map((q, i) =>
        `<div class="quest">${q.title()}${i === 0 && quests.target && q.at ? ` <small>· ${quests.targetDist} m</small>` : ''}</div>`).join(''));

      set(el.wallet, `<b>💰 ${s.money}</b> tiền <b>🧱 ${fmtMat(s.mat)}</b> vật liệu <span>✨ ${s.collectibles.length}/${LEVEL.collectibles.length}</span>${s.slot !== 'main' ? `<em>${s.slot === 'dev' ? 'DỮ LIỆU THỬ' : 'CHƠI LẠI'}</em>` : ''}`);

      const pct = Math.floor(trash.ratio * 100);
      const pollution = !s.placed.plant ? '<span class="bad">Chưa xử lý</span>' : s.plant.progress < 1 ? `<span class="warn">Đang xử lý ${Math.round(s.plant.progress * 100)}%</span>` : '<span class="ok">Đã kiểm soát</span>';
      set(el.site, `<h3>Công trình</h3>
        <div class="bar"><i style="width:${pct}%"></i><b style="left:90%"></b></div>
        <div>Đã thu gom <b>${pct}%</b> <small>(cần 90%)</small></div>
        <div>Rác chờ xử lý: <b>${pendingCount()}</b></div>
        <div>Nguồn ô nhiễm: ${pollution}</div>`);

      const st = machines.states();
      const rows = [];
      for (const k of ['conveyor', 'skimmer']) {
        if (!st[k]) continue;
        const i = machines.info(k);
        rows.push(`<div class="mcard ${i.stateKey}"><b>${i.title}</b> · ${i.state}<br><small>${i.rows.slice(0, 2).map((r) => `${r[0]}: ${r[1]}`).join(' · ')}</small>${i.cause && i.stateKey !== 'running' ? `<br><small>${i.cause[1]}</small>` : ''}</div>`);
      }
      set(el.machines, rows.join(''));

      const cap = basketCap(), load = basketLoad();
      set(el.toolbar, TOOL_ORDER.map((t, i) => `<div class="slot ${s.tool === t ? 'on' : ''} ${s.tools[t] ? '' : 'locked'}"><kbd>${i + 1}</kbd>${TOOLS[t].name}<small>${TOOLS[t].reach} m</small></div>`).join('')
        + `<div class="basket ${load >= cap ? 'full' : ''}">Giỏ <b>${load}/${cap}</b><div class="cells">${Array.from({ length: cap }, (_, i) => `<i class="${i < load ? 'f' : ''}"></i>`).join('')}</div></div>`
        + (s.crate.length ? `<div class="basket crate">Đang mang thùng: <b>${s.crate.length}</b> món</div>` : ''));

      if (hintText !== lastHint) { audio.duck(!!hintText); lastHint = hintText; }
      el.hint.hidden = !hintText;
      set(el.hint, hintText ? `💡 ${hintText}` : '');
    },
  };
}
