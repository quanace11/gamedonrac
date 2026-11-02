extends Node
## Autoload "Sfx": âm thanh tổng hợp lúc khởi động (không cần tệp âm thanh).
## Nhặt nhựa, lon va, nước, đổ mẻ và máy chạy có âm sắc phân biệt.

const RATE := 22050

var _sounds := {}
var _pool: Array[AudioStreamPlayer] = []
var _hums := {}
var _ambient: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	_sounds = {
		"plastic": _make(0.14, func(t): return _tone(t, 520 - 1600 * t, 0.09) * 0.5 + _noise() * _env(t, 0.05) * 0.15),
		"metal": _make(0.4, func(t): return (sin(TAU * 1800 * t) * 0.5 + sin(TAU * 2710 * t) * 0.3) * exp(-t * 9) * 0.6),
		"other": _make(0.16, func(t): return _noise() * _env(t, 0.12) * 0.5),
		"splash": _make(0.45, func(t): return _lp_noise(0.35) * _env(t, 0.38) * 0.9 + sin(TAU * (300 - 300 * t) * t) * exp(-t * 10) * 0.2),
		"dump": _make(0.6, func(t): return sin(TAU * (140 - 120 * t) * t) * exp(-t * 6) * 0.7 + _noise() * (0.25 if fmod(t, 0.08) < 0.02 else 0.0)),
		"coin": _make(0.35, func(t): return signf(sin(TAU * (990.0 if t < 0.08 else 1320.0) * t)) * exp(-t * 8) * 0.18),
		"error": _make(0.2, func(t): return signf(sin(TAU * 170 * t)) * _env(t, 0.18) * 0.2),
		"ui": _make(0.06, func(t): return sin(TAU * (700 + 3000 * t) * t) * _env(t, 0.05) * 0.25),
		"place": _make(0.35, func(t): return sin(TAU * (200 - 300 * t) * t) * exp(-t * 7) * 0.7 + _lp_noise(0.2) * _env(t, 0.25) * 0.4),
		"hook": _make(0.18, func(t): return sin(TAU * (400 + 2500 * t) * t) * _env(t, 0.15) * 0.3),
		"collect": _make(0.45, func(t): return sin(TAU * [660.0, 880.0, 1320.0][mini(int(t / 0.12), 2)] * t) * exp(-fmod(t, 0.12) * 10) * 0.35),
		"fanfare": _make(0.9, func(t): return _tri(t * [523.0, 659.0, 784.0, 1046.0][mini(int(t / 0.15), 3)]) * exp(-fmod(t, 0.15) * 4) * 0.3),
	}
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_ambient = AudioStreamPlayer.new()
	_ambient.stream = _loop(2.0, func(_t): return _lp_noise(0.06) * 0.6)
	_ambient.volume_db = -22
	add_child(_ambient)
	_ambient.play()
	set_volume(Game.settings.volume)


func set_volume(v: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))


func play(name: String, pitch_jitter := 0.06) -> void:
	if not _sounds.has(name):
		return
	for p in _pool:
		if not p.playing:
			p.stream = _sounds[name]
			p.pitch_scale = 1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			return


## Giảm âm nền khi có chỉ dẫn quan trọng.
func duck(on: bool) -> void:
	create_tween().tween_property(_ambient, "volume_db", -32.0 if on else -22.0, 0.4)


## Tiếng máy chạy liên tục; vol 0 để tắt. Mỗi máy một âm sắc.
func hum(id: String, freq: float, vol: float) -> void:
	var p: AudioStreamPlayer = _hums.get(id)
	if p == null:
		p = AudioStreamPlayer.new()
		p.stream = _loop(1.0, func(t): return (_saw(t * freq) * 0.5 + signf(sin(TAU * freq * 1.5 * t)) * 0.2) * 0.5)
		p.volume_db = -80
		add_child(p)
		p.play()
		_hums[id] = p
	p.volume_db = lerpf(p.volume_db, linear_to_db(maxf(vol * 0.12, 0.0001)), 0.1)


# ---------- Tổng hợp ----------
var _lp := 0.0


func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)


func _lp_noise(k: float) -> float:
	_lp += (_noise() - _lp) * k
	return _lp * 2.0


func _env(t: float, dur: float) -> float:
	return clampf(t / 0.005, 0.0, 1.0) * clampf(1.0 - t / dur, 0.0, 1.0)


func _tone(t: float, f: float, dur: float) -> float:
	return sin(TAU * f * t) * _env(t, dur)


func _tri(x: float) -> float:
	return 1.0 - 4.0 * absf(fposmod(x, 1.0) - 0.5)


func _saw(x: float) -> float:
	return fposmod(x, 1.0) * 2.0 - 1.0


func _pcm(dur: float, fn: Callable) -> PackedByteArray:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(fn.call(float(i) / RATE), -1.0, 1.0) * 32000))
	return data


func _make(dur: float, fn: Callable) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = _pcm(dur, fn)
	return s


func _loop(dur: float, fn: Callable) -> AudioStreamWAV:
	var s := _make(dur, fn)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = int(dur * RATE)
	return s
