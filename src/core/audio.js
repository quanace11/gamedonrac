// Âm thanh tổng hợp bằng WebAudio, không cần tệp âm thanh.
// Nhặt nhựa, lon va, nước, đổ mẻ và máy chạy có âm sắc phân biệt.
import { settings } from './state.js';

let ctx = null, master = null, ambient = null, noiseBuf = null;
const hums = new Map();

function noise() {
  if (!noiseBuf) {
    noiseBuf = ctx.createBuffer(1, ctx.sampleRate, ctx.sampleRate);
    const d = noiseBuf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
  }
  const src = ctx.createBufferSource();
  src.buffer = noiseBuf;
  return src;
}

function env(node, t, peak, attack, decay) {
  node.gain.setValueAtTime(0.0001, t);
  node.gain.exponentialRampToValueAtTime(peak, t + attack);
  node.gain.exponentialRampToValueAtTime(0.0001, t + attack + decay);
}

function tone(type, f0, f1, dur, vol, delay = 0) {
  const t = ctx.currentTime + delay;
  const o = ctx.createOscillator(), g = ctx.createGain();
  o.type = type;
  o.frequency.setValueAtTime(f0, t);
  o.frequency.exponentialRampToValueAtTime(f1, t + dur);
  env(g, t, vol, 0.005, dur);
  o.connect(g).connect(master);
  o.start(t);
  o.stop(t + dur + 0.05);
}

function burst(freq, q, dur, vol, delay = 0, type = 'bandpass') {
  const t = ctx.currentTime + delay;
  const src = noise(), f = ctx.createBiquadFilter(), g = ctx.createGain();
  f.type = type; f.frequency.value = freq; f.Q.value = q;
  env(g, t, vol, 0.01, dur);
  src.connect(f).connect(g).connect(master);
  src.start(t);
  src.stop(t + dur + 0.05);
}

const SOUNDS = {
  plastic: () => { tone('triangle', 520, 300, 0.09, 0.25); burst(2500, 2, 0.06, 0.12); },
  metal: () => { tone('sine', 1800, 1500, 0.25, 0.15); tone('sine', 2700, 2300, 0.18, 0.08); },
  other: () => { burst(700, 1, 0.12, 0.3); },
  splash: () => { burst(900, 0.7, 0.35, 0.35); tone('sine', 300, 120, 0.2, 0.1); },
  dump: () => { tone('sine', 140, 60, 0.3, 0.4); for (let i = 0; i < 6; i++) burst(1500 + i * 300, 3, 0.07, 0.12, 0.05 + i * 0.05); },
  coin: () => { tone('square', 990, 990, 0.08, 0.1); tone('square', 1320, 1320, 0.25, 0.1, 0.08); },
  error: () => { tone('sawtooth', 180, 140, 0.18, 0.12); },
  ui: () => { tone('sine', 700, 900, 0.05, 0.08); },
  place: () => { tone('sine', 200, 80, 0.25, 0.4); burst(400, 1, 0.2, 0.2); },
  hook: () => { tone('sawtooth', 400, 900, 0.12, 0.1); burst(3000, 4, 0.1, 0.1); },
  collect: () => { tone('triangle', 660, 660, 0.1, 0.15); tone('triangle', 880, 880, 0.12, 0.15, 0.1); tone('triangle', 1320, 1320, 0.3, 0.15, 0.2); },
  fanfare: () => [523, 659, 784, 1046].forEach((f, i) => tone('triangle', f, f, 0.35, 0.18, i * 0.14)),
};

export const audio = {
  /** Gọi trong một thao tác người dùng (trình duyệt yêu cầu). */
  init() {
    if (ctx) { ctx.resume(); return; }
    ctx = new AudioContext();
    master = ctx.createGain();
    master.connect(ctx.destination);
    // Tiếng nước nền: nhiễu lọc thấp, lặp vô hạn.
    const src = noise(), f = ctx.createBiquadFilter();
    src.loop = true; f.type = 'lowpass'; f.frequency.value = 500;
    ambient = ctx.createGain(); ambient.gain.value = 0.05;
    src.connect(f).connect(ambient).connect(master);
    src.start();
    this.setVolume(settings.volume);
  },
  setVolume(v) { if (master) master.gain.value = v; },
  play(name) { if (ctx && SOUNDS[name]) SOUNDS[name](); },
  /** Giảm âm nền khi có chỉ dẫn quan trọng. */
  duck(on) { if (ambient) ambient.gain.setTargetAtTime(on ? 0.015 : 0.05, ctx.currentTime, 0.3); },
  /** Tiếng máy chạy liên tục; vol 0 để tắt. Mỗi máy một âm sắc. */
  hum(id, freq, vol) {
    if (!ctx) return;
    let h = hums.get(id);
    if (!h) {
      const o = ctx.createOscillator(), o2 = ctx.createOscillator(), g = ctx.createGain(), f = ctx.createBiquadFilter();
      o.type = 'sawtooth'; o.frequency.value = freq;
      o2.type = 'square'; o2.frequency.value = freq * 1.51;
      f.type = 'lowpass'; f.frequency.value = freq * 4;
      g.gain.value = 0;
      o.connect(f); o2.connect(f); f.connect(g).connect(master);
      o.start(); o2.start();
      h = g; hums.set(id, g);
    }
    h.gain.setTargetAtTime(vol * 0.05, ctx.currentTime, 0.15);
  },
};
