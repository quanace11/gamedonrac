extends Node
## Autoload "Sfx": âm thanh tổng hợp lúc khởi động (không cần tệp âm thanh).
## Chỉ dùng sóng sin và nhiễu đã lọc, có vào/ra êm để không lách cách;
## vòng lặp nối liền mạch (nền nước, tiếng máy) để không có tiếng "tách" mỗi lần lặp.

const RATE := 32000

var _sounds := {}
var _pool: Array[AudioStreamPlayer] = []
var _hums := {}
var _ambient: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _last := {} # âm → thời điểm phát gần nhất (ms), tránh dồn dập khi vớt liên tục


func _ready() -> void:
	_rng.seed = 7
	_sounds = {
		# Âm nhặt: vào chậm (12–30 ms), không có nhiễu ở đầu âm nên không nghe như tiếng nổ
		# Nhựa: tiếng "túc" mềm
		"plastic": _mix(0.16, [_sweep(560, 430, 0.14, 0.16, 0.012), _hiss(0.015, 0.12, 0.03, 0.03)]),
		# Kim loại: tiếng "ting" nhỏ
		"metal": _mix(0.3, [_bell(1250, 0.2, 0.08, 0.008), _bell(1870, 0.12, 0.03, 0.008)]),
		# Rác còn lại: tiếng "bục" trầm, nhỏ
		"other": _mix(0.16, [_sweep(250, 190, 0.14, 0.18, 0.015)]),
		# Vớt dưới nước: tiếng "lõm bõm" nhẹ
		"splash": _mix(0.45, [_hiss(0.012, 0.4, 0.3, 0.06), _blips(3, 0.3, 0.08)]),
		"dump": _mix(0.55, [_sweep(130, 80, 0.4, 0.3, 0.02), _rattle(0.4, 0.06)]),
		"coin": _mix(0.5, [_bell(1318.5, 0.45, 0.16), _delay(_bell(1760, 0.4, 0.16), 0.07)]),
		"error": _mix(0.32, [_bell(330, 0.14, 0.22), _delay(_bell(262, 0.16, 0.22), 0.12)]),
		"ui": _mix(0.05, [_bell(1100, 0.04, 0.08)]),
		"place": _mix(0.4, [_sweep(150, 90, 0.32, 0.3, 0.02), _hiss(0.015, 0.2, 0.05, 0.04)]),
		"hook": _mix(0.25, [_whoosh(0.22, 0.1), _delay(_bell(900, 0.1, 0.1), 0.15)]),
		"collect": _mix(0.6, [_bell(659.3, 0.3, 0.16), _delay(_bell(880, 0.3, 0.16), 0.1), _delay(_bell(1318.5, 0.35, 0.14), 0.2)]),
		"fanfare": _mix(1.4, [_chime(523.3, 0.0), _chime(659.3, 0.14), _chime(784.0, 0.28), _chime(1046.5, 0.42), _delay(_bell(523.3, 0.9, 0.08), 0.42)]),
		# Bước chân: rất nhẹ, trầm
		# Lốp cao su cọ xuống nền khi bị kéo
		"drag": _mix(0.45, [_hiss(0.03, 0.4, 0.07, 0.08), _sweep(80, 65, 0.35, 0.08, 0.06)]),
		"step": _mix(0.12, [_hiss(0.01, 0.1, 0.05, 0.02), _sweep(95, 75, 0.09, 0.08, 0.015)]),
	}
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_ambient = AudioStreamPlayer.new()
	_ambient.stream = _ambient_loop()
	_ambient.volume_db = -20
	add_child(_ambient)
	_ambient.play()
	set_volume(Game.settings.volume)


func set_volume(v: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))


func play(name: String, pitch_jitter := 0.04) -> void:
	if not _sounds.has(name):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(name, -1000)) < 90:
		return
	_last[name] = now
	for p in _pool:
		if not p.playing:
			p.stream = _sounds[name]
			p.pitch_scale = 1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			return


## Giảm âm nền khi có chỉ dẫn quan trọng.
func duck(on: bool) -> void:
	create_tween().tween_property(_ambient, "volume_db", -28.0 if on else -20.0, 0.6)


## Tiếng máy chạy liên tục (sin trầm, êm); vol 0 để tắt. Mỗi máy một cao độ.
func hum(id: String, freq: float, vol: float) -> void:
	var p: AudioStreamPlayer = _hums.get(id)
	if p == null:
		p = AudioStreamPlayer.new()
		p.stream = _hum_loop(freq)
		p.volume_db = -80
		add_child(p)
		p.play()
		_hums[id] = p
	p.volume_db = lerpf(p.volume_db, linear_to_db(maxf(vol * 0.05, 0.00001)), 0.05)


# ---------- Tổng hợp ----------
# Mỗi hàm trả về PackedFloat32Array; _mix cộng lại, chuẩn hóa vào/ra và đổi sang PCM 16 bit.

func _n(dur: float) -> int:
	return int(dur * RATE)


## Bao hình: vào êm theo hình sin trong `attack` giây rồi tắt dần theo hàm mũ.
func _env(t: float, decay: float, attack := 0.006) -> float:
	var a := 1.0 if t >= attack else sin(t / attack * PI * 0.5) ** 2
	return a * exp(-t / maxf(decay, 0.001) * 3.0)


func _bell(f: float, decay: float, gain: float, attack := 0.006) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_n(decay * 1.6))
	for i in out.size():
		var t := float(i) / RATE
		out[i] = (sin(TAU * f * t) + 0.25 * sin(TAU * f * 2.0 * t)) * _env(t, decay, attack) * gain
	return out


func _chime(f: float, at: float) -> PackedFloat32Array:
	return _delay(_bell(f, 0.5, 0.13), at)


func _sweep(f0: float, f1: float, dur: float, gain: float, attack := 0.01) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_n(dur))
	var ph := 0.0
	for i in out.size():
		var t := float(i) / RATE
		ph += TAU * lerpf(f0, f1, t / dur) / RATE
		out[i] = sin(ph) * _env(t, dur * 0.6, attack) * gain
	return out


## Nhiễu đã lọc thông thấp (k nhỏ = trầm hơn).
func _hiss(k: float, dur: float, gain: float, attack := 0.02) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_n(dur))
	var lp := 0.0
	for i in out.size():
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * k
		out[i] = lp * 3.0 * _env(t, dur * 0.5, attack) * gain
	return out


func _whoosh(dur: float, gain: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_n(dur))
	var lp := 0.0
	for i in out.size():
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * lerpf(0.02, 0.2, t / dur)
		out[i] = lp * 3.0 * sin(PI * t / dur) * gain
	return out


## Bọt nước: vài tiếng "búp" ngắn, cao độ tăng dần.
func _blips(n: int, dur: float, gain: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_n(dur))
	for b in n:
		var at := _rng.randf_range(0.02, dur - 0.08)
		var f := _rng.randf_range(500, 900)
		var start := _n(at)
		var len := _n(0.05)
		var ph := 0.0
		for i in len:
			if start + i >= out.size():
				break
			var t := float(i) / RATE
			ph += TAU * f * (1.0 + t * 12.0) / RATE
			out[start + i] += sin(ph) * _env(t, 0.03) * gain
	return out


func _rattle(dur: float, gain: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_n(dur))
	for b in 9:
		var hit := _hiss(0.15, 0.04, gain * _rng.randf_range(0.5, 1.0))
		var start := _n(_rng.randf_range(0.0, dur - 0.05))
		for i in hit.size():
			if start + i < out.size():
				out[start + i] += hit[i]
	return out


func _delay(a: PackedFloat32Array, at: float) -> PackedFloat32Array:
	var pad := PackedFloat32Array()
	pad.resize(_n(at))
	pad.append_array(a)
	return pad


func _mix(dur: float, parts: Array) -> AudioStreamWAV:
	var n := _n(dur)
	for p in parts:
		n = maxi(n, p.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for p in parts:
		for i in p.size():
			out[i] += p[i]
	# Ra êm 15 ms để không lách cách khi kết thúc
	var fade := mini(_n(0.015), n)
	for i in fade:
		out[n - 1 - i] *= float(i) / fade
	return _wav(out, false)


func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s


## Nền: nước vỗ nhẹ (nhiễu trầm, lên xuống chậm). Nối vòng bằng cách đan chéo phần đuôi vào đầu.
func _ambient_loop() -> AudioStreamWAV:
	var length := _n(8.0)
	var xf := _n(1.0)
	var raw := PackedFloat32Array()
	raw.resize(length + xf)
	var lp := 0.0
	var lp2 := 0.0
	for i in raw.size():
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.04
		lp2 += (lp - lp2) * 0.08
		raw[i] = lp2 * 4.0
	var out := PackedFloat32Array()
	out.resize(length)
	for i in length:
		var t := float(i) / RATE
		var v := raw[i]
		if i < xf:
			var k := float(i) / xf
			v = raw[i] * k + raw[length + i] * (1.0 - k)
		# Sóng vỗ: biên độ lên xuống với chu kỳ chia hết độ dài vòng (2 s và 8/3 s)
		var swell := 0.55 + 0.3 * sin(TAU * t / 2.0) + 0.15 * sin(TAU * t * 3.0 / 8.0)
		out[i] = v * swell * 0.5
	return _wav(out, true)


## Tiếng máy: tần số làm tròn để vòng 1 giây luôn khép kín, không có tiếng tách.
func _hum_loop(freq: float) -> AudioStreamWAV:
	var f := roundf(freq)
	var out := PackedFloat32Array()
	out.resize(RATE)
	for i in RATE:
		var t := float(i) / RATE
		var wob := 0.85 + 0.15 * sin(TAU * 2.0 * t)
		out[i] = (sin(TAU * f * t) * 0.6 + sin(TAU * f * 2.0 * t) * 0.25 + sin(TAU * f * 3.0 * t) * 0.08) * wob * 0.6
	return _wav(out, true)
