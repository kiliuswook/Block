extends Node
## Procedural audio engine: every SFX and BGM track is synthesized in code at
## startup — the project ships no audio asset files, matching the draw-in-code
## rendering style. Creates BGM/SFX buses at runtime; volume settings live in
## GameState (save.json) and are applied here.

const RATE := 22050
const POOL_SIZE := 12
const BGM_FADE := 0.8

enum { SINE, SQUARE, TRIANGLE, SAW, NOISE }

var _sounds := {}  # name -> AudioStreamWAV
var _bgm_tracks := {}  # name -> AudioStreamWAV, rendered lazily and cached
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _bgm_player: AudioStreamPlayer
var _bgm_name := ""
var _bgm_tween: Tween


func _ready() -> void:
	for bus in ["BGM", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			var i := AudioServer.bus_count
			AudioServer.add_bus(i)
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "BGM"
	add_child(_bgm_player)
	_build_sounds()
	apply_volumes()


## Fire-and-forget SFX through a rotating player pool (oldest gets cut off).
func play(sound: String, pitch := 1.0, vol_db := 0.0) -> void:
	if not _sounds.has(sound):
		return
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % POOL_SIZE
	p.stream = _sounds[sound]
	p.pitch_scale = pitch
	p.volume_db = vol_db
	p.play()


## Starts a looping BGM track ("title" / "game"); ignores repeat requests for
## the track already playing. Tracks render on first request (a few hundred ms)
## and stay cached for the session.
func play_bgm(track: String) -> void:
	if _bgm_name == track and _bgm_player.playing:
		return
	_bgm_name = track
	if not _bgm_tracks.has(track):
		_bgm_tracks[track] = _render_title_bgm() if track == "title" \
				else _render_game_bgm()
	if _bgm_tween:
		_bgm_tween.kill()
	_bgm_player.stream = _bgm_tracks[track]
	_bgm_player.volume_db = -18.0
	_bgm_player.play()
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_bgm_player, "volume_db", 0.0, BGM_FADE)


func stop_bgm() -> void:
	_bgm_name = ""
	_bgm_player.stop()


# --- Volume settings ----------------------------------------------------------


## v is linear 0..1. persist=false while a slider drags; save on release.
func set_volume(kind: String, v: float, persist := true) -> void:
	v = clampf(v, 0.0, 1.0)
	match kind:
		"master": GameState.vol_master = v
		"bgm": GameState.vol_bgm = v
		"sfx": GameState.vol_sfx = v
	_apply_bus(kind, v)
	if persist:
		GameState.save_game()


func get_volume(kind: String) -> float:
	match kind:
		"master": return GameState.vol_master
		"bgm": return GameState.vol_bgm
		"sfx": return GameState.vol_sfx
	return 1.0


func apply_volumes() -> void:
	_apply_bus("master", GameState.vol_master)
	_apply_bus("bgm", GameState.vol_bgm)
	_apply_bus("sfx", GameState.vol_sfx)


func _apply_bus(kind: String, v: float) -> void:
	var bus := "Master" if kind == "master" else ("BGM" if kind == "bgm" else "SFX")
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(v) if v > 0.001 else -80.0)


# --- Synthesis core -----------------------------------------------------------


func _buf(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * RATE))
	return b


## Mixes one voice into buf: frequency sweeps f0→f1 over dur seconds starting
## at t0, with a fast attack and a (1-t)^curve decay envelope.
func _add_tone(buf: PackedFloat32Array, t0: float, dur: float, f0: float,
		f1: float, amp: float, wave: int, curve := 1.0) -> void:
	var n0 := int(t0 * RATE)
	var n := int(dur * RATE)
	var attack := maxi(1, int(0.004 * RATE))
	var phase := 0.0
	for i in n:
		var idx := n0 + i
		if idx >= buf.size():
			break
		var t := float(i) / n
		phase += lerpf(f0, f1, t) / RATE
		var s: float
		match wave:
			SQUARE:
				s = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			TRIANGLE:
				s = 4.0 * absf(fmod(phase, 1.0) - 0.5) - 1.0
			SAW:
				s = 2.0 * fmod(phase, 1.0) - 1.0
			NOISE:
				s = randf() * 2.0 - 1.0
			_:
				s = sin(phase * TAU)
		var env := minf(float(i) / attack, 1.0) * pow(1.0 - t, curve)
		buf[idx] += s * amp * env


func _wav(buf: PackedFloat32Array, looped := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = buf.size()
	return wav


## Note run: each freq (0 = rest) starts every `step` s and rings step*ring.
func _jingle(notes: Array, step: float, wave: int, amp: float,
		ring := 2.0) -> AudioStreamWAV:
	var buf := _buf(step * (notes.size() + ring))
	for i in notes.size():
		var f: float = notes[i]
		if f > 0.0:
			_add_tone(buf, i * step, step * ring, f, f, amp, wave)
	return _wav(buf)


func _midi(m: int) -> float:
	return 440.0 * pow(2.0, (m - 69) / 12.0)


# --- SFX definitions ----------------------------------------------------------


func _build_sounds() -> void:
	var b: PackedFloat32Array
	# Jump: short rising chirp. Wall jump: same, a fifth higher.
	b = _buf(0.14)
	_add_tone(b, 0.0, 0.14, 320.0, 640.0, 0.28, SQUARE)
	_sounds["jump"] = _wav(b)
	b = _buf(0.14)
	_add_tone(b, 0.0, 0.14, 480.0, 960.0, 0.26, SQUARE)
	_sounds["walljump"] = _wav(b)
	# Dash: noise whoosh with a falling sweep under it.
	b = _buf(0.16)
	_add_tone(b, 0.0, 0.16, 0.0, 0.0, 0.2, NOISE, 2.0)
	_add_tone(b, 0.0, 0.14, 900.0, 250.0, 0.1, SAW)
	_sounds["dash"] = _wav(b)
	# Hard landing thud.
	b = _buf(0.1)
	_add_tone(b, 0.0, 0.1, 130.0, 55.0, 0.5, SINE)
	_add_tone(b, 0.0, 0.04, 0.0, 0.0, 0.15, NOISE)
	_sounds["land"] = _wav(b)
	# Piece lock: soft wooden tock.
	b = _buf(0.09)
	_add_tone(b, 0.0, 0.09, 240.0, 150.0, 0.35, TRIANGLE)
	_add_tone(b, 0.0, 0.03, 0.0, 0.0, 0.18, NOISE)
	_sounds["lock"] = _wav(b)
	# 회전: 짧고 마른 클릭.
	b = _buf(0.06)
	_add_tone(b, 0.0, 0.05, 900.0, 1500.0, 0.14, SQUARE, 2.0)
	_sounds["rotate"] = _wav(b)
	# 하드드롭: 아래로 빨려 드는 휘파람 + 바람 소리.
	b = _buf(0.16)
	_add_tone(b, 0.0, 0.14, 1200.0, 260.0, 0.16, SAW, 1.6)
	_add_tone(b, 0.0, 0.16, 0.0, 0.0, 0.12, NOISE, 2.5)
	_sounds["harddrop"] = _wav(b)
	# 착지 충격: 배를 치는 저음 + 짧은 파열음. 낙하 거리에 따라 음정·음량이 붙는다.
	b = _buf(0.22)
	_add_tone(b, 0.0, 0.22, 155.0, 42.0, 0.55, SINE, 1.4)
	_add_tone(b, 0.0, 0.09, 90.0, 40.0, 0.28, TRIANGLE, 1.2)
	_add_tone(b, 0.0, 0.05, 0.0, 0.0, 0.22, NOISE, 2.0)
	_sounds["impact"] = _wav(b)
	# 콤보: 위로 튀는 두 음 — 콤보 수만큼 피치가 올라간다.
	_sounds["combo"] = _jingle([784.0, 1046.5], 0.05, SQUARE, 0.18, 2.0)
	# Dash shove impact.
	b = _buf(0.14)
	_add_tone(b, 0.0, 0.14, 170.0, 80.0, 0.45, SQUARE)
	_add_tone(b, 0.0, 0.07, 0.0, 0.0, 0.22, NOISE)
	_sounds["shove"] = _wav(b)
	# First hit cracks, second destroys.
	b = _buf(0.06)
	_add_tone(b, 0.0, 0.06, 0.0, 0.0, 0.4, NOISE, 2.0)
	_sounds["crack"] = _wav(b)
	b = _buf(0.2)
	_add_tone(b, 0.0, 0.2, 0.0, 0.0, 0.45, NOISE, 2.5)
	_add_tone(b, 0.0, 0.1, 420.0, 160.0, 0.18, SQUARE)
	_sounds["break"] = _wav(b)
	# Line clear: C-major sweep (pitch-scaled up for multi-line clears).
	_sounds["clear"] = _jingle([523.25, 659.25, 783.99, 1046.5], 0.06, SQUARE, 0.2)
	# Coin ("+N G").
	b = _buf(0.22)
	_add_tone(b, 0.0, 0.06, 987.77, 987.77, 0.2, SQUARE)
	_add_tone(b, 0.06, 0.16, 1318.5, 1318.5, 0.2, SQUARE)
	_sounds["gold"] = _wav(b)
	# Escape fanfare.
	_sounds["escape"] = _jingle([523.25, 659.25, 783.99, 1046.5, 0.0, 1318.5],
			0.09, SQUARE, 0.18, 3.0)
	# Arcade level-clear shutter: slatted steel rolling down the well.
	b = _buf(0.55)
	_add_tone(b, 0.0, 0.55, 0.0, 0.0, 0.22, NOISE, 1.6)
	_add_tone(b, 0.0, 0.5, 280.0, 90.0, 0.16, SQUARE)
	_add_tone(b, 0.42, 0.13, 150.0, 70.0, 0.3, SINE)  # the clunk at the bottom
	_sounds["shutter"] = _wav(b)
	# Death: sad two-voice slide down.
	b = _buf(0.7)
	_add_tone(b, 0.0, 0.6, 392.0, 98.0, 0.28, SQUARE, 0.8)
	_add_tone(b, 0.08, 0.6, 196.0, 49.0, 0.18, TRIANGLE, 0.8)
	_sounds["death"] = _wav(b)
	# New record fanfare.
	_sounds["record"] = _jingle([880.0, 1108.7, 1318.5, 1760.0], 0.1, TRIANGLE,
			0.22, 3.5)
	# 골드러시 발동: 위로 치솟는 팡파르 + 금이 쏟아지는 잔향.
	b = _buf(0.6)
	_add_tone(b, 0.0, 0.09, 659.25, 659.25, 0.2, SQUARE)
	_add_tone(b, 0.08, 0.09, 830.61, 830.61, 0.2, SQUARE)
	_add_tone(b, 0.16, 0.09, 987.77, 987.77, 0.2, SQUARE)
	_add_tone(b, 0.24, 0.3, 1318.5, 1318.5, 0.22, TRIANGLE, 2.5)
	_add_tone(b, 0.24, 0.36, 1760.0, 1760.0, 0.12, SQUARE, 3.0)
	_add_tone(b, 0.0, 0.5, 0.0, 0.0, 0.07, NOISE, 2.0)
	_sounds["goldrush"] = _wav(b)
	# Milestone ding (every 10 floors).
	b = _buf(0.45)
	_add_tone(b, 0.0, 0.35, 659.25, 659.25, 0.2, TRIANGLE)
	_add_tone(b, 0.08, 0.37, 987.77, 987.77, 0.16, TRIANGLE)
	_sounds["milestone"] = _wav(b)
	# UI click / cat purchase / not-enough-money buzz / pause blip.
	b = _buf(0.05)
	_add_tone(b, 0.0, 0.05, 750.0, 600.0, 0.22, SINE)
	_sounds["click"] = _wav(b)
	_sounds["buy"] = _jingle([987.77, 1318.5, 1760.0], 0.07, SQUARE, 0.2, 2.5)
	b = _buf(0.24)
	_add_tone(b, 0.0, 0.1, 185.0, 175.0, 0.26, SQUARE)
	_add_tone(b, 0.12, 0.12, 165.0, 155.0, 0.26, SQUARE)
	_sounds["error"] = _wav(b)
	b = _buf(0.12)
	_add_tone(b, 0.0, 0.12, 620.0, 420.0, 0.2, TRIANGLE)
	_sounds["pause"] = _wav(b)


# --- BGM ----------------------------------------------------------------------


## In-game loop: 128 BPM, 8 bars of Am–F–C–G chiptune with a walking bass,
## triangle lead, kick and off-beat hats.
func _render_game_bgm() -> AudioStreamWAV:
	var step := 60.0 / 128.0 / 2.0  # 8th note
	var melody := [
		69, 72, 76, 72, 69, 0, 64, 67, 69, 72, 76, 79, 76, 72, 69, 0,
		65, 69, 72, 69, 65, 0, 60, 64, 65, 69, 72, 76, 72, 69, 65, 0,
		64, 67, 72, 67, 64, 0, 67, 72, 76, 74, 72, 67, 69, 72, 74, 76,
		62, 67, 71, 67, 74, 71, 67, 0, 71, 69, 67, 64, 69, 0, 0, 0,
	]
	var roots := [45, 45, 41, 41, 48, 48, 43, 43]  # A2 A2 F2 F2 C3 C3 G2 G2
	var buf := _buf(step * melody.size())
	for i in melody.size():
		var t0 := i * step
		if melody[i] > 0:
			var f := _midi(melody[i])
			_add_tone(buf, t0, step * 1.9, f, f, 0.13, TRIANGLE, 0.6)
		var root: int = roots[(i / 8) % roots.size()]
		var bass := _midi(root + (12 if i % 2 == 1 else 0))
		_add_tone(buf, t0, step * 0.9, bass, bass, 0.11, SQUARE, 0.5)
		if i % 4 == 0:
			_add_tone(buf, t0, 0.08, 110.0, 45.0, 0.28, SINE)
		elif i % 2 == 0:
			_add_tone(buf, t0, 0.03, 0.0, 0.0, 0.05, NOISE, 2.0)
	return _wav(buf, true)


## Title loop: 84 BPM, gentle Am–F–C–G arpeggio over a sine pad — the calm
## before the pit.
func _render_title_bgm() -> AudioStreamWAV:
	var step := 60.0 / 84.0 / 2.0
	var chords := [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]
	var arp := [0, 1, 2, 1, 0, 1, 2, 1]
	var buf := _buf(step * 8 * chords.size())
	for c in chords.size():
		var t0 := c * 8 * step
		var ch: Array = chords[c]
		var pad := _midi(ch[0] - 12)
		_add_tone(buf, t0, 8 * step, pad, pad, 0.09, SINE, 0.3)
		for i in 8:
			var m: int = ch[arp[i]] + 12 + (12 if i >= 4 else 0)
			var f := _midi(m)
			_add_tone(buf, t0 + i * step, step * 1.6, f, f, 0.08, TRIANGLE, 0.5)
	return _wav(buf, true)
