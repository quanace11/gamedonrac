// Các bảng giao diện: menu, Tab (nhiệm vụ, cửa hàng, nghiệm thu, cài đặt), bàn phân loại,
// bảng máy, bản đồ chiến dịch, kết quả trước–sau và chế độ phát triển.
import { TRASH, CATS, CAT_KEYS, SHOP, CAMPAIGN, LEVEL, KEY_LABELS, DEFAULT_KEYS, ECON } from '../data.js';
import { store, settings, saveSettings, saveGame, spend, fmtMat, processBatch, valueOf, hasSave, loadGame, loadImage } from '../core/state.js';
import { input } from '../core/input.js';
import { audio } from '../core/audio.js';

const keyName = (code) => code.replace(/^Key|^Digit/, '').replace('Backquote', '`').replace('ShiftLeft', 'Shift trái').replace('ShiftRight', 'Shift phải');
const dot = (t) => `<i class="dot" style="background:#${TRASH[t].color.toString(16).padStart(6, '0')}"></i>`;
const examples = (cat) => TRASH.filter((t) => t.cat === cat).map((t) => t.name.toLowerCase()).join(', ');

export function createPanels(ctx) {
  const root = document.getElementById('overlay');
  let cur = null;
  const S = () => store.state;

  function open(name, render, acts = {}, refresh = 0) {
    close(false);
    cur = { name, render, acts };
    root.hidden = false;
    input.unlock();
    draw();
    if (refresh) cur.timer = setInterval(draw, refresh);
  }
  function draw() { if (cur) root.innerHTML = cur.render(); }
  function close(resume = true) {
    if (!cur) return;
    clearInterval(cur.timer);
    const was = cur;
    cur = null;
    root.hidden = true;
    root.innerHTML = '';
    was.acts.onClose?.();
    if (resume) ctx.resume();
  }

  root.addEventListener('click', (e) => {
    const b = e.target.closest('[data-act]');
    if (!b || b.disabled || !cur) return;
    audio.play('ui');
    const fn = cur.acts[b.dataset.act] || common[b.dataset.act];
    fn?.call(cur.acts, b.dataset.arg);
    if (cur) draw();
  });
  root.addEventListener('input', (e) => {
    const k = e.target.dataset.set;
    if (!k) return;
    settings[k] = e.target.type === 'checkbox' ? e.target.checked : Number(e.target.value);
    if (k === 'volume') audio.setVolume(settings.volume);
    if (k === 'shadows') ctx.applySettings();
    saveSettings();
  });

  const common = {
    close: () => close(),
    tab: (t) => tab(t),
    menu: () => menu(),
    campaign: () => campaign(),
  };

  // ---------- Menu chính / tạm dừng ----------
  let confirmNew = false;
  function menu() {
    confirmNew = false;
    const main = hasSave('main');
    const done = (ctx.running && S().slot === 'main' ? S() : loadGame('main'))?.accepted;
    open('menu', () => `
      <div class="panel menu">
        <h1>Dòng Nước Xanh</h1>
        <p class="sub">Bản chơi thử · Màn 1: ${LEVEL.name}</p>
        <div class="col">
          ${ctx.running ? '<button class="primary" data-act="resume">Tiếp tục chơi</button>' : main ? '<button class="primary" data-act="cont">Tiếp tục</button>' : ''}
          <button class="${main || ctx.running ? '' : 'primary'}" data-act="fresh">${confirmNew ? 'Bấm lần nữa để xóa tiến độ cũ' : 'Chơi mới'}</button>
          ${done ? '<button data-act="replay">Chơi lại màn (tiến độ riêng)</button>' : ''}
          <button data-act="campaign">Bản đồ chiến dịch</button>
          <button data-act="tab" data-arg="settings">Cài đặt</button>
        </div>
        <div class="help">
          <b>Điều khiển</b>: ${['forward', 'left', 'back', 'right'].map((k) => keyName(settings.keys[k])).join(' ')} đi · Chuột nhìn · Chuột trái nhặt/dùng dụng cụ (giữ để vớt liên tục)
          · ${keyName(settings.keys.interact)} tương tác · 1/2/3 hoặc con lăn đổi dụng cụ · ${keyName(settings.keys.menu)} nhiệm vụ & nâng cấp · ${keyName(settings.keys.build)} đặt máy · Esc tạm dừng
        </div>
      </div>`, {
      resume: () => close(),
      cont: () => { close(false); ctx.start('main', false); },
      fresh: () => {
        if ((main || ctx.running) && !confirmNew) { confirmNew = true; return; }
        close(false); ctx.start('main', true);
      },
      replay: () => { close(false); ctx.start('replay', true); },
    });
  }

  // ---------- Tab: nhiệm vụ, cửa hàng, nghiệm thu, cài đặt ----------
  const TABS = { quests: 'Nhiệm vụ', shop: 'Cửa hàng', accept: 'Nghiệm thu', settings: 'Cài đặt' };

  function questsTab() {
    const s = S(), { trash } = ctx;
    const stock = Object.keys(s.stock).filter((k) => s.stock[k]);
    return `
      <h3>Đang làm</h3>${ctx.quests.active().map((q) => `<div class="quest">${q.title()}</div>`).join('') || '<p>Không còn nhiệm vụ.</p>'}
      ${stock.length ? `<h3>Trong kho</h3><p>${stock.map((k) => SHOP[k].name).join(', ')} – bấm <kbd>${keyName(settings.keys.build)}</kbd> để đặt tại vị trí lắp.</p>` : ''}
      <h3>Tiến độ từng khu</h3>
      <table class="grid">${LEVEL.zones.map((z) => {
        const st = trash.zones[z.id];
        return `<tr><td>${z.name}</td><td>${st.done}/${st.total}</td><td><div class="bar small"><i style="width:${st.done / st.total * 100}%"></i></div></td></tr>`;
      }).join('')}</table>
      <p class="muted">Đã xử lý ${s.stats.processed} món · ${s.stats.manualBatches} mẻ thủ công · ${s.stats.autoItems} món qua băng chuyền</p>`;
  }

  function shopLock(item) {
    const s = S();
    if (item.unlock === 'outfall' && !s.obstacle.done) return 'Mở sau khi kéo vật cản khỏi cửa xả';
    if (item.unlock === 'skimmer' && !s.quests.skimmer) return 'Mở sau khi lắp máy vớt (đã bảo đảm ngân sách tuyến chính)';
    return '';
  }
  function shopTab() {
    const s = S();
    return `<p class="muted">Dụng cụ và nâng cấp thuộc đội, mang sang màn sau. Máy và công trình là hạ tầng, ở lại hiện trường. Được hoàn trả toàn bộ giá máy chưa lắp khi màn chưa nghiệm thu.</p>
      <div class="shop">${Object.entries(SHOP).map(([k, it]) => {
        const lock = shopLock(it);
        const owned = it.kind === 'tool' ? s.tools[k] : it.kind === 'upgrade' ? s.upgrades[k] : s.placed[k] || s.stock[k];
        const cost = `${it.price} tiền${it.mat ? ` + ${fmtMat(it.mat)} vật liệu` : ''}`;
        let btn;
        if (lock) btn = `<span class="lock">🔒 ${lock}</span>`;
        else if (it.kind === 'machine' && s.placed[k]) btn = '<span class="own">Đã lắp</span>';
        else if (it.kind === 'machine' && s.stock[k]) btn = `<span class="own">Trong kho – bấm ${keyName(settings.keys.build)} để đặt</span>${s.accepted ? '' : `<button data-act="refund" data-arg="${k}">Hoàn trả</button>`}`;
        else if (owned) btn = '<span class="own">Đã có</span>';
        else btn = `<button class="primary" data-act="buy" data-arg="${k}" ${s.money >= it.price && s.mat >= it.mat ? '' : 'disabled'}>Mua</button>`;
        return `<div class="item ${lock ? 'locked' : ''}"><div><b>${it.name}</b> <small class="tag">${it.kind === 'machine' ? 'Hạ tầng' : 'Thuộc đội'}</small><br><small>${it.desc}</small></div><div class="price">${cost}</div><div class="act">${btn}</div></div>`;
      }).join('')}</div>`;
  }
  function buy(k) {
    const it = SHOP[k], s = S();
    if (!spend(it.price, it.mat)) { audio.play('error'); return ctx.toast('Chưa đủ tiền hoặc vật liệu.', 'warn'); }
    if (it.kind === 'tool') { s.tools[k] = true; s.tool = k; }
    else if (it.kind === 'upgrade') s.upgrades[k] = true;
    else { s.stock[k] = true; ctx.hint('buy'); }
    saveGame();
    audio.play('coin');
    ctx.toast(`Đã mua ${it.name}.`, 'good');
  }
  function refund(k) {
    const it = SHOP[k], s = S();
    if (!s.stock[k] || s.accepted) return;
    s.stock[k] = false;
    s.money += it.price;
    s.mat += it.mat;
    saveGame();
    ctx.toast(`Đã hoàn trả ${it.name}: +${it.price} tiền.`, 'info');
  }

  function acceptTab() {
    const s = S();
    if (s.accepted) return `<p class="ok big">✓ Công trình đã nghiệm thu.</p><div class="row"><button class="primary" data-act="results">Xem trước và sau</button><button data-act="campaign">Bản đồ chiến dịch</button></div>`;
    const ok = ctx.quests.canAccept();
    return `<p>Nút nghiệm thu chỉ bật khi đủ mọi điều kiện. Dọn 100% và tìm đồ sưu tầm là mục tiêu tự chọn.</p>
      <ul class="checks">${ctx.quests.conditions().map(([t, c]) => `<li class="${c ? 'ok' : ''}">${c ? '✓' : '○'} ${t}</li>`).join('')}</ul>
      <button class="primary big" data-act="accept" ${ok ? '' : 'disabled'}>Nghiệm thu công trình</button>
      <p class="muted">Thưởng nghiệm thu: ${ECON.acceptBonus.money} tiền + ${fmtMat(ECON.acceptBonus.mat)} vật liệu${s.slot === 'replay' ? ' (chế độ chơi lại không cộng thưởng chiến dịch)' : ''}.</p>`;
  }

  function settingsTab() {
    const tog = (k, label) => `<label class="tog"><input type="checkbox" data-set="${k}" ${settings[k] ? 'checked' : ''}> ${label}</label>`;
    return `
      <label>Độ nhạy chuột <input type="range" min="0.2" max="3" step="0.1" value="${settings.sens}" data-set="sens"></label>
      <label>Âm lượng <input type="range" min="0" max="1" step="0.05" value="${settings.volume}" data-set="volume"></label>
      ${tog('headBob', 'Rung camera khi đi')}
      ${tog('waterFx', 'Hiệu ứng mặt nước')}
      ${tog('guide', 'Cột sáng chỉ đường nhiệm vụ')}
      ${tog('shadows', 'Đổ bóng')}
      <h3>Gán phím</h3>
      <table class="grid keys">${Object.keys(KEY_LABELS).map((a) => `<tr><td>${KEY_LABELS[a]}</td><td><button data-act="rebind" data-arg="${a}">${rebinding === a ? 'Nhấn phím… (Esc hủy)' : keyName(settings.keys[a])}</button></td></tr>`).join('')}</table>
      <button data-act="resetKeys">Khôi phục mặc định</button>`;
  }
  let rebinding = null;

  function tab(which = 'quests') {
    const inGame = !!ctx.running;
    if (!inGame) which = 'settings';
    open('tab', () => `
      <div class="panel wide">
        <nav>${Object.entries(TABS).filter(([k]) => inGame || k === 'settings').map(([k, n]) => `<button class="${k === which ? 'on' : ''}" data-act="tab" data-arg="${k}">${n}</button>`).join('')}
          <button class="x" data-act="${inGame ? 'close' : 'menu'}">✕</button></nav>
        <div class="body">${{ quests: questsTab, shop: shopTab, accept: acceptTab, settings: settingsTab }[which]()}</div>
      </div>`, {
      buy, refund,
      accept: () => { close(false); ctx.accept(); },
      results: () => results(),
      rebind: (a) => {
        rebinding = a;
        input.captureKey((code) => {
          if (code) settings.keys[a] = code;
          rebinding = null;
          saveSettings();
          draw();
        });
      },
      resetKeys: () => { settings.keys = { ...DEFAULT_KEYS }; saveSettings(); },
    }, which === 'quests' || which === 'accept' ? 500 : 0);
  }

  // ---------- Bàn phân loại ----------
  function sort() {
    const assigned = { plastic: [], metal: [], other: [] }; // chỉ số trên bàn
    let selected = null, wrongFlash = new Set();
    const onTable = () => S().table.map((t, i) => i).filter((i) => !CAT_KEYS.some((c) => assigned[c].includes(i)));
    const groups = (idx) => {
      const g = new Map();
      for (const i of idx) { const t = S().table[i]; g.set(t, (g.get(t) || []).concat(i)); }
      return [...g.entries()];
    };
    ctx.hint('sort');
    open('sort', () => {
      const rest = onTable();
      return `
      <div class="panel wide sort">
        <nav><b>Bàn phân loại</b><button class="x" data-act="close">✕</button></nav>
        <p class="muted">Chọn một cụm cùng loại rồi bấm vào thùng. Bấm vào cụm trong thùng để trả lại bàn. Không bị trừ tiền khi phân nhầm.</p>
        <div class="table">${groups(rest).map(([t, ids]) => `<button class="chip ${selected === t ? 'sel' : ''} ${wrongFlash.has(t) ? 'wrong' : ''}" data-act="pick" data-arg="${t}">${dot(t)}${TRASH[t].name} ×${ids.length}</button>`).join('') || '<span class="muted">Bàn đã trống – bấm Xác nhận xử lý.</span>'}</div>
        <div class="bins">${CAT_KEYS.map((c) => `
          <div class="bin" data-act="drop" data-arg="${c}" style="--c:${CATS[c].color}">
            <div class="head">${CATS[c].icon} ${CATS[c].name}</div>
            <small>${examples(c)}</small>
            <div>${groups(assigned[c]).map(([t, ids]) => `<button class="chip" data-act="back" data-arg="${c}:${t}">${dot(t)}${TRASH[t].name} ×${ids.length}</button>`).join('')}</div>
          </div>`).join('')}</div>
        <div class="row"><button class="primary big" data-act="confirm" ${rest.length ? 'disabled' : ''}>Xác nhận xử lý (${S().table.length} món · ${valueOf(S().table).money} tiền)</button><button data-act="close">Để lại trên bàn</button></div>
      </div>`;
    }, {
      pick: (t) => { selected = Number(t); },
      drop(c) {
        if (selected == null) return;
        const ids = onTable().filter((i) => S().table[i] === selected);
        assigned[c].push(...ids);
        wrongFlash.delete(selected);
        selected = null;
      },
      back(arg) {
        const [c, t] = arg.split(':');
        if (selected != null) return this.drop(c); // đang chọn cụm thì bấm đâu trong thùng cũng là bỏ vào
        assigned[c] = assigned[c].filter((i) => S().table[i] !== Number(t));
      },
      confirm: () => {
        const s = S();
        const good = [], bad = [];
        for (const c of CAT_KEYS) for (const i of assigned[c]) (TRASH[s.table[i]].cat === c ? good : bad).push(s.table[i]);
        // Giao dịch: thay bàn bằng phần sai và cấp thưởng cho phần đúng trong cùng một bước rồi lưu.
        s.table = bad;
        const r = processBatch(good, false);
        for (const c of CAT_KEYS) assigned[c] = [];
        wrongFlash = new Set(bad);
        if (good.length) { audio.play('coin'); ctx.toast(`Xử lý ${good.length} món: +${r.money} tiền, +${fmtMat(r.mat)} vật liệu`, 'good'); }
        if (bad.length) { audio.play('error'); ctx.toast(`${bad.length} món bị phân nhầm đã được trả lại bàn. Thử lại nhé!`, 'warn'); }
        else close();
      },
    });
  }

  // ---------- Bảng máy ----------
  function machine(k) {
    open('machine', () => {
      const i = ctx.machines.info(k);
      return `
      <div class="panel machine">
        <nav><b>${i.title}</b><button class="x" data-act="close">✕</button></nav>
        <div class="state ${i.stateKey}">${i.state}</div>
        ${i.cause ? `<p><b>Nguyên nhân:</b> ${i.cause[0]}<br><b>Cách khắc phục:</b> ${i.cause[1]}</p>` : ''}
        <table class="grid">${i.rows.map(([a, b]) => `<tr><td>${a}</td><td><b>${b}</b></td></tr>`).join('')}</table>
        <div class="row">${i.actions.map((a, n) => `<button class="${a.primary ? 'primary' : ''}" data-act="run" data-arg="${n}" ${a.disabled ? 'disabled' : ''}>${a.label}</button>`).join('')}</div>
      </div>`;
    }, { run: (n) => ctx.machines.info(k).actions[n].fn() }, 300);
  }

  // ---------- Bản đồ chiến dịch ----------
  function campaign() {
    const c = (ctx.running ? S() : loadGame('main'))?.campaign || { done: [], unlocked: ['tolich'] };
    open('campaign', () => `
      <div class="panel wide">
        <nav><b>Bản đồ chiến dịch</b><button class="x" data-act="${ctx.running ? 'close' : 'menu'}">✕</button></nav>
        <div class="map">${CAMPAIGN.map((m, i) => {
          const done = c.done.includes(m.id), open = c.unlocked.includes(m.id) || i === 0;
          const status = done ? '✓ Đã nghiệm thu' : open ? (i === 0 ? 'Đang chơi' : 'Đã mở – chưa có trong bản chơi thử') : '🔒 Nghiệm thu màn trước để mở';
          return `<button class="node ${done ? 'done' : open ? 'open' : 'locked'}" data-act="go" data-arg="${m.id}"><b>${i + 1}. ${m.name}</b><small>${m.mech}</small><em>${status}</em></button>`;
        }).join('')}</div>
      </div>`, {
      go: (id) => {
        if (id !== 'tolich') return ctx.toast(c.unlocked.includes(id) ? 'Màn này đã mở khóa nhưng chưa được triển khai trong bản chơi thử.' : 'Màn này chưa mở khóa.', 'info');
        if (ctx.running) close(); else { close(false); ctx.start('main', !hasSave('main')); }
      },
    });
  }

  // ---------- Kết quả nghiệm thu ----------
  function results() {
    const s = S();
    const before = loadImage(s.slot, 'before'), after = loadImage(s.slot, 'after');
    const min = Math.round(s.time / 60);
    open('results', () => `
      <div class="panel wide results">
        <nav><b>Nghiệm thu: ${LEVEL.name}</b><button class="x" data-act="close">✕</button></nav>
        <div class="ba">
          <figure>${before ? `<img src="${before}" alt="Trước">` : '<div class="noimg"></div>'}<figcaption>Trước</figcaption></figure>
          <figure>${after ? `<img src="${after}" alt="Sau">` : '<div class="noimg"></div>'}<figcaption>Sau</figcaption></figure>
        </div>
        <table class="grid">
          <tr><td>Rác đã thu gom</td><td><b>${Math.floor(ctx.trash.ratio * 100)}%</b></td></tr>
          <tr><td>Tổng rác đã xử lý</td><td><b>${s.stats.processed} món</b></td></tr>
          <tr><td>Tiền dịch vụ đã nhận</td><td><b>${s.stats.earned}</b></td></tr>
          <tr><td>Thưởng nghiệm thu</td><td><b>${s.slot === 'replay' ? 'Không áp dụng (chơi lại)' : `${ECON.acceptBonus.money} tiền + ${fmtMat(ECON.acceptBonus.mat)} vật liệu`}</b></td></tr>
          <tr><td>Đồ sưu tầm</td><td><b>${s.collectibles.length}/${LEVEL.collectibles.length}</b></td></tr>
          <tr><td>Thời gian</td><td><b>${min} phút</b></td></tr>
        </table>
        <p>Hồ thành phố đã mở trên bản đồ chiến dịch.</p>
        <div class="row"><button class="primary" data-act="campaign">Bản đồ chiến dịch</button><button data-act="close">Dạo bờ sông đã sạch</button></div>
      </div>`);
  }

  // ---------- Chế độ phát triển ----------
  function dev() {
    const d = ctx.dev;
    open('dev', () => `
      <div class="panel">
        <nav><b>Chế độ phát triển</b><button class="x" data-act="close">✕</button></nav>
        <p class="muted">Dữ liệu thử lưu ở khe riêng, không ảnh hưởng tiến độ người chơi.</p>
        <div class="col">
          <button data-act="money">+1000 tiền, +20 vật liệu</button>
          <button data-act="tools">Mở mọi công cụ</button>
          <button data-act="speed">Tốc độ máy: x${ctx.devSpeed}</button>
          <button data-act="markers">${d.showMarkers ? 'Ẩn' : 'Hiện'} rác còn sót</button>
          <button data-act="quest">Hoàn thành nhiệm vụ hiện tại</button>
          <div class="row">${LEVEL.zones.filter((z) => z.id !== 'T').map((z) => `<button data-act="tp" data-arg="${z.id}">Tới khu ${z.id}</button>`).join('')}</div>
        </div>
      </div>`, d);
  }

  return {
    get isOpen() { return !!cur; },
    get name() { return cur?.name; },
    close, menu, tab, sort, machine, campaign, results, dev,
  };
}
