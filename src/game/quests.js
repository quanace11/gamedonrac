// Nhiệm vụ theo kịch bản tiến trình, chỉ dẫn lần đầu (mỗi lần một chỉ dẫn),
// cột sáng chỉ đường và điều kiện nghiệm thu.
import * as THREE from 'three';
import { ECON, LEVEL } from '../data.js';
import { store, settings, saveGame, pendingCount, basketCap, basketLoad } from '../core/state.js';

const zoneCenter = (id) => {
  const z = LEVEL.zones.find((q) => q.id === id);
  return { x: (z.x0 + z.x1) / 2, z: 11 };
};

const HINTS = {
  start: 'Nhắm vào rác trong tầm tay và nhấp chuột trái để nhặt. W A S D để đi, chuột để nhìn, Tab mở nhiệm vụ.',
  full: 'Giỏ đã đầy. Mang về bàn phân loại ở khu C (theo cột sáng) và bấm E.',
  sort: 'Chọn một cụm rác rồi bấm vào thùng đúng nhóm. Bấm vào món trong thùng để trả lại bàn nếu nhầm, rồi Xác nhận.',
  net: 'Vợt với xa hơn và vớt được rác trên mặt nước. Giữ chuột trái để vớt liên tục.',
  buy: 'Đồ đã mua nằm trong kho. Bấm B để vào chế độ đặt máy, nhắm vào khung xanh và nhấp chuột.',
  buildMode: 'Chế độ đặt máy: khung xanh là vị trí lắp hợp lệ, khung đỏ là máy có thể tháo về kho. Bấm B để thoát.',
  conveyor: 'Băng chuyền đã lắp. Bấm E tại máy để nạp giỏ; máy tự phân loại. Nhớ bấm Xử lý đầu ra để nhận tiền.',
  hook: 'Bạn nhận được Móc kéo (phím 3). Dọn đống rác quanh tủ lạnh cũ ở cửa xả, rồi nhắm và nhấp để móc.',
  drag: 'Đi về Điểm nhận vật lớn (vòng xanh lá gần khu C), vật cản sẽ bị kéo theo. Nhấp lần nữa để thả.',
  flow: 'Rác bị kẹt sau cửa xả đang trôi ra và dồn vào vùng xoáy ở khu E. Lắp máy vớt ở đó.',
  skimmer: 'Máy vớt gom rác vào thùng cạnh máy. Bấm E để lấy thùng, mang tới phễu băng chuyền.',
  crate: 'Bạn đang mang thùng máy vớt. Bấm E tại băng chuyền (Nạp) hoặc bàn phân loại để đổ.',
  plant: 'Công trình đang xử lý nguồn ô nhiễm – mặt nước sẽ trong dần.',
  accept: 'Đủ điều kiện nghiệm thu! Mở Tab → Nghiệm thu.',
};

export function createQuests(ctx) {
  const { trash, scene } = ctx;
  const S = () => store.state;
  const zone = (id) => trash.zones[id];

  const QUESTS = [
    { id: 'pick', title: () => 'Nhặt món rác đầu tiên', at: () => zoneCenter('A'), done: () => trash.collectedMass > 0 },
    { id: 'dump', req: ['pick'], title: () => 'Mang giỏ về bàn phân loại (khu C) và bấm E', at: () => LEVEL.table, done: () => S().stats.dumped > 0 },
    { id: 'sort', req: ['dump'], title: () => 'Phân loại và xử lý một mẻ', at: () => LEVEL.table, done: () => S().stats.manualBatches > 0 },
    { id: 'buyNet', req: ['sort'], title: () => 'Mua vợt (Tab → Cửa hàng)', done: () => S().tools.net },
    { id: 'clearA', req: ['sort'], title: () => `Dọn sạch khu A (${zone('A').done}/${zone('A').total})`, at: () => zoneCenter('A'), done: () => zone('A').done >= zone('A').total },
    { id: 'partB', req: ['buyNet'], title: () => `Vớt một nửa rác khu B (${zone('B').done}/${Math.ceil(zone('B').total / 2)})`, at: () => zoneCenter('B'), done: () => zone('B').done >= zone('B').total / 2 },
    { id: 'belt', req: ['clearA', 'partB'], title: () => (S().stock.conveyor || S().placed.conveyor ? 'Lắp băng chuyền ở khu C (phím B)' : 'Mua băng chuyền (Tab → Cửa hàng)'), at: () => LEVEL.slots.conveyor, done: () => S().placed.conveyor },
    { id: 'auto', req: ['belt'], title: () => `Cho băng chuyền xử lý một mẻ tự động (${Math.min(10, S().stats.autoItems)}/10)`, at: () => LEVEL.slots.conveyor, done: () => S().stats.autoItems >= 10 },
    { id: 'outfall', req: ['auto'], title: () => `Dọn cửa xả, kéo ${LEVEL.obstacle.name} về điểm nhận`, at: () => (ctx.machines.hooked ? LEVEL.receive : LEVEL.obstacle), done: () => S().obstacle.done, start: grantHook },
    { id: 'skimmer', req: ['outfall'], title: () => (S().stock.skimmer || S().placed.skimmer ? 'Lắp máy vớt ở khu E (phím B)' : 'Mua máy vớt (Tab → Cửa hàng)'), at: () => LEVEL.slots.skimmer, done: () => S().placed.skimmer },
    { id: 'plant', req: ['outfall'], title: () => (S().stock.plant || S().placed.plant ? 'Xây công trình xử lý ở khu D (phím B)' : 'Mua công trình xử lý nước thải (Tab → Cửa hàng)'), at: () => LEVEL.slots.plant, done: () => S().placed.plant },
    { id: 'collect', req: ['skimmer'], title: () => `Thu gom ít nhất 90% rác (${Math.floor(trash.ratio * 100)}%)`, done: () => trash.ratio >= ECON.acceptRatio },
    { id: 'queue', req: ['collect'], title: () => `Xử lý hết rác đang chờ (còn ${pendingCount()})`, at: () => LEVEL.table, done: () => pendingCount() === 0 },
    { id: 'accept', req: ['queue', 'plant'], title: () => 'Nghiệm thu công trình (Tab → Nghiệm thu)', done: () => S().accepted },
  ];

  function grantHook() {
    if (S().tools.hook) return;
    S().tools.hook = true;
    ctx.toast('Nhận Móc kéo (phím 3) – dụng cụ bắt buộc được cấp miễn phí.', 'good');
    ctx.hint('hook');
  }

  // Chỉ dẫn: hàng đợi, mỗi lần một chỉ dẫn, mỗi chỉ dẫn hiện một lần
  const queue = [];
  let showing = null, hintTimer = 0;
  function hint(id) {
    const s = S();
    if (!s || s.hints[id] || showing === id || queue.some((q) => q.id === id) || !HINTS[id]) return;
    queue.push({ id, at: performance.now() });
  }

  // Cột sáng chỉ đường
  const beam = new THREE.Mesh(
    new THREE.CylinderGeometry(0.25, 0.25, 30, 12, 1, true),
    new THREE.MeshBasicMaterial({ color: 0x5cf2c4, transparent: true, opacity: 0.35, depthWrite: false, side: THREE.DoubleSide }),
  );
  beam.position.y = 14;
  scene.add(beam);

  const conditions = () => {
    const s = S();
    return [
      [`Thu gom ≥ 90% khối lượng rác (hiện ${Math.floor(trash.ratio * 100)}%)`, trash.ratio >= ECON.acceptRatio],
      ['Xử lý vật cản bắt buộc ở cửa xả', s.obstacle.done],
      [`Không còn rác chờ trong giỏ, thùng, bàn và dây chuyền (còn ${pendingCount()})`, pendingCount() === 0],
      ['Công trình xử lý nước thải đang hoạt động', s.placed.plant],
      ['Hoàn thành nhiệm vụ chính: băng chuyền, mẻ tự động, máy vớt', s.placed.conveyor && s.stats.autoItems >= 10 && s.placed.skimmer],
    ];
  };

  return {
    beam,
    hint,
    conditions,
    canAccept: () => !S().accepted && conditions().every((c) => c[1]),

    /** Tối đa ba nhiệm vụ đang liên quan. */
    active() {
      const q = S().quests;
      return QUESTS.filter((x) => !q[x.id] && (x.req || []).every((r) => q[r])).slice(0, 3);
    },

    /** Kiểm tra hoàn thành; trả về chỉ dẫn hiện tại (nếu có). */
    update(dt, playerPos) {
      const s = S();
      let changed = false;
      for (const x of QUESTS) {
        if (s.quests[x.id] || !(x.req || []).every((r) => s.quests[r])) continue;
        x.start?.();
        if (x.done()) {
          s.quests[x.id] = true;
          changed = true;
          if (x.id !== 'pick') { ctx.toast(`Hoàn thành: ${x.title()}`, 'good'); ctx.audio.play('collect'); }
        }
      }
      if (changed) saveGame();
      if (this.canAccept()) hint('accept');

      // Chỉ dẫn
      if (showing) {
        hintTimer -= dt;
        if (hintTimer <= 0) { s.hints[showing] = true; showing = null; }
      }
      // Chỉ dẫn chờ quá 15 giây đã lỗi thời: bỏ qua (vẫn hiện lại được lần sau nếu cần)
      while (queue.length && performance.now() - queue[0].at > 15000) queue.shift();
      if (!showing && queue.length) { showing = queue.shift().id; hintTimer = queue.length ? 5 : 8; }

      // Chỉ đường: ưu tiên việc đang dở (giỏ đầy, đang mang thùng)
      let target = null;
      const full = basketLoad() >= basketCap();
      if (s.crate.length) target = s.placed.conveyor ? LEVEL.slots.conveyor : LEVEL.table;
      else if (full) target = LEVEL.table;
      else target = this.active().find((x) => x.at)?.at();
      const dist = target ? Math.hypot(target.x - playerPos.x, target.z - playerPos.z) : 0;
      beam.visible = settings.guide && !!target && !s.accepted && dist > 3;
      if (target) beam.position.set(target.x, 14, target.z);
      beam.material.opacity = Math.min(0.35, dist / 40);
      this.target = target;
      this.targetDist = Math.round(dist);
      return showing ? HINTS[showing] : null;
    },
    dismissHint() { hintTimer = 0; },
    reset() { queue.length = 0; showing = null; },
  };
}
