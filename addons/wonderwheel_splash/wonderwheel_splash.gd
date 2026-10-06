class_name WonderWheelSplash
extends CanvasLayer
## 원더휠(WonderWheel) 회사 로고 스플래시 — 시안 3종.
##
##  A. NIGHT_LIGHTS : 어둠 속 곤돌라 불빛이 하나씩 켜짐 → 정전, 한 박자 정적 → 일제히 점등 + 폭죽
##  B. SPIN_UP      : 관람차가 잔상이 생길 만큼 가속 → '철컥' 급제동 + 충격파, 곤돌라가 관성으로 크게 흔들림
##  C. TWILIGHT     : 돌아가는 곤돌라 클로즈업 → 카메라가 확 빠지며 노을 앞 실루엣 공개 + 태양 광선
##
## 세 시안 모두 관람차는 처음부터 끝까지 계속 돌아간다.
## 사용법 1) 메인 씬으로: wonderwheel_splash.tscn 을 인스턴스로 두고 next_scene 에 게임 첫 씬 지정.
## 사용법 2) 오버레이로: next_scene 을 비우면 끝난 뒤 서서히 사라지며 스스로 free.

signal finished

enum Style { NIGHT_LIGHTS, SPIN_UP, TWILIGHT }

const Layout := preload("ww_layout.gd")
const ShineShader := preload("ww_shine.gdshader")

@export var style: Style = Style.NIGHT_LIGHTS
## 화면 짧은 변 대비 로고 크기 비율
@export_range(0.2, 0.95) var logo_fit := 0.6
@export var play_sound := true
@export_range(-40.0, 6.0) var sound_volume_db := -2.0
@export var skippable := true
@export var min_time_before_skip := 0.5
@export var auto_start := true
## 지정하면 끝난 뒤 이 씬으로 전환 (검은 화면으로 페이드 후 전환)
@export_file("*.tscn") var next_scene := ""
## next_scene 이 없을 때: 끝나면 스스로 사라지며 queue_free
@export var free_when_finished := true

# --- 타임라인 (초) : tools/build_sfx.py 와 싱크 ---
const A_T_LIGHT0 := 0.3
const A_LIGHT_STEP := 0.11
const A_T_FLICKER := 1.5
const A_FLICKER_ON := [Vector2(0.0, 0.05), Vector2(0.09, 0.12), Vector2(0.16, 0.19)]
const A_T_OUT := 1.72
const A_T_IMPACT := 2.0
const A_T_LEAVE := 4.4
const B_T_ACCEL := 0.55
const B_T_IMPACT := 2.0
const B_OMEGA_MAX := 26.0
const B_T_LEAVE := 4.3
const C_T_PULL := 1.3
const C_T_IMPACT := 2.15
const C_T_LEAVE := 4.4

const SFX := ["a_night_lights.wav", "b_spin_up.wav", "c_twilight.wav"]
const GHOSTS := 5

# 스타일별 색
var _sky: Array[Color] = []      # 위 / 가운데 / 아래
var _logo_col: Color
var _light_col: Color
var _star_count := 0

var _base_dir: String
var _root: Control
var _bg: Control
var _stage: Node2D
var _fx_back: Node2D
var _fx_front: Node2D
var _sun_glow: Sprite2D
var _sun_disc: Sprite2D
var _halo: Sprite2D
var _group: CanvasGroup
var _wheel: Sprite2D
var _stand: Sprite2D
var _wheel_ghosts: Array[Sprite2D] = []
var _gondolas: Array[Sprite2D] = []
var _gondola_ghosts: Array[Sprite2D] = []   # [gondola * GHOSTS + k]
var _glows: Array[Sprite2D] = []
var _letters: Array[Sprite2D] = []
var _burst_back: CPUParticles2D
var _burst_front: CPUParticles2D
var _ambient: CPUParticles2D
var _flash: ColorRect
var _fader: ColorRect
var _audio: AudioStreamPlayer
var _tween: Tween

# 상태 (tween 대상)
var _omega := 0.4                 # 바퀴 각속도 (rad/s)
var _wheel_scale := 1.0
var _cam_zoom := 1.0
var _cam_focus := Vector2.ZERO    # 화면 중앙에 올 로고 좌표
var _glow_master := 0.0
var _glow_on: Array[float] = []
var _trail := 0.0
var _tint := 0.0
var _ray_alpha := 0.0
var _stars_alpha := 0.0
var _rings: Array[Dictionary] = []

var _angle := 0.0
var _prev_omega := 0.4
var _swing := 0.0
var _swing_v := 0.0
var _shake := 0.0
var _shake_floor := 0.0
var _shake_off := Vector2.ZERO
var _base_scale := 1.0
var _stars: Array[Vector4] = []
var _time := 0.0
var _playing := false
var _leaving := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 100
	_base_dir = (get_script() as Script).resource_path.get_base_dir()
	_setup_palette()
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_reset_state()
	if auto_start:
		await get_tree().process_frame   # 첫 프레임 로딩 히치로 앞부분이 잘리지 않도록
		play()


## 처음부터 재생
func play() -> void:
	if _tween:
		_tween.kill()
	_reset_state()
	_playing = true
	_leaving = false
	_time = 0.0
	if play_sound and _audio.stream:
		_audio.volume_db = sound_volume_db
		_audio.play()
	_tween = create_tween().set_parallel(true)
	match style:
		Style.NIGHT_LIGHTS: _timeline_night_lights(_tween)
		Style.SPIN_UP: _timeline_spin_up(_tween)
		Style.TWILIGHT: _timeline_twilight(_tween)


## 즉시 끝내기 (스킵)
func skip() -> void:
	if _playing and not _leaving:
		_leave()


func _input(event: InputEvent) -> void:
	if not (skippable and _playing) or _leaving or _time < min_time_before_skip:
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventJoypadButton and event.pressed)
	if pressed:
		get_viewport().set_input_as_handled()
		skip()


# ================================================================== 시안 A. 점등

func _timeline_night_lights(tw: Tween) -> void:
	_group.self_modulate.a = 0.0
	_omega = 0.32
	_prev_omega = _omega
	tw.tween_property(self, "_stars_alpha", 1.0, 1.0)
	tw.tween_property(_group, "self_modulate:a", 0.2, 1.2).set_delay(0.15)   # 어둠 속 희미한 실루엣
	tw.tween_property(self, "_cam_zoom", 1.05, A_T_LEAVE).set_trans(Tween.TRANS_SINE)
	_glow_master = 1.0
	for i in Layout.GONDOLA_COUNT:
		var k := (i * 3) % Layout.GONDOLA_COUNT   # 불이 들어오는 순서를 흩어 놓음
		tw.tween_method(_set_glow_on.bind(k), 0.0, 1.0, 0.08).set_delay(A_T_LIGHT0 + i * A_LIGHT_STEP)
	# 정전 → 한 박자 정적
	tw.tween_callback(_lights_out).set_delay(A_T_OUT)
	# 임팩트
	tw.tween_callback(_impact_night_lights).set_delay(A_T_IMPACT)
	tw.tween_property(self, "_tint", 0.0, 0.9).from(1.0).set_delay(A_T_IMPACT) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(_flash, "color:a", 0.0, 0.55).from(0.45).set_delay(A_T_IMPACT) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(_halo, "modulate:a", 0.55, 1.2).from(1.0).set_delay(A_T_IMPACT)
	tw.tween_property(self, "_omega", 0.36, 1.6).set_delay(A_T_IMPACT + 0.02) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_stars_alpha", 1.0, 1.0).set_delay(A_T_IMPACT)
	for i in _letters.size():
		var l := _letters[i]
		var d := A_T_IMPACT + absf(i - 5) * 0.018
		tw.tween_property(l, "modulate:a", 1.0, 0.05).set_delay(d)
		tw.tween_property(l, "scale", Vector2.ONE, 0.6).from(Vector2.ONE * 1.28).set_delay(d) \
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_leave).set_delay(A_T_LEAVE)


func _lights_out() -> void:
	_group.self_modulate.a = 0.03
	_stars_alpha = 0.35


func _impact_night_lights() -> void:
	_group.self_modulate.a = 1.0
	_glow_master = 1.0
	for i in _glow_on.size():
		_glow_on[i] = 1.0
	_set_omega_instant(1.3, 2.2)          # 점등 순간 바퀴가 '덜컥' 힘을 받음
	_shake = 16.0
	_add_ring(40.0, 1150.0, 0.95, 26.0, _light_col)
	_add_ring(30.0, 780.0, 0.8, 10.0, Color(1, 1, 1, 0.9), 0.07)
	_burst_back.restart()
	_burst_back.emitting = true
	_ambient.emitting = true


# ================================================================== 시안 B. 가속

func _timeline_spin_up(tw: Tween) -> void:
	_group.self_modulate.a = 0.0
	_cam_zoom = 0.9
	_omega = 0.5
	_prev_omega = _omega
	tw.tween_property(self, "_stars_alpha", 1.0, 0.8)
	tw.tween_property(_group, "self_modulate:a", 1.0, 0.45)
	tw.tween_property(self, "_cam_zoom", 1.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# 가속 (exponential) + 카메라가 조여 들어감
	tw.tween_property(self, "_omega", B_OMEGA_MAX, B_T_IMPACT - B_T_ACCEL - 0.01).set_delay(B_T_ACCEL) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "_cam_zoom", 1.12, B_T_IMPACT - B_T_ACCEL).set_delay(B_T_ACCEL + 0.001) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# 급제동
	tw.tween_callback(_impact_spin_up).set_delay(B_T_IMPACT)
	tw.tween_property(self, "_cam_zoom", 1.0, 0.7).from(1.12).set_delay(B_T_IMPACT + 0.001) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_flash, "color:a", 0.0, 0.45).from(0.4).set_delay(B_T_IMPACT) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_tint", 0.0, 0.7).from(0.9).set_delay(B_T_IMPACT) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_glow_master", 0.35, 1.5).set_delay(B_T_IMPACT + 0.2)
	tw.tween_property(_halo, "modulate:a", 0.3, 1.0).from(0.9).set_delay(B_T_IMPACT)
	for i in _letters.size():
		var l := _letters[i]
		var d := B_T_IMPACT + absf(i - 5) * 0.022
		tw.tween_property(l, "modulate:a", 1.0, 0.08).set_delay(d)
		tw.tween_property(l, "scale", Vector2.ONE, 0.45).from(Vector2.ONE * 1.9).set_delay(d) \
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "position", Layout.LETTER_CENTERS[i], 0.45) \
				.from(Layout.LETTER_CENTERS[i] + Vector2((i - 5) * 18.0, -40)).set_delay(d) \
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_leave).set_delay(B_T_LEAVE)


func _impact_spin_up() -> void:
	_set_omega_instant(0.55, 7.5)          # 급제동 → 곤돌라가 관성으로 크게 휙
	_shake = 24.0
	_add_ring(150.0, 1250.0, 0.85, 30.0, _light_col)
	_add_ring(120.0, 900.0, 0.7, 8.0, Color(1, 1, 1, 0.95), 0.05)
	_add_ring(60.0, 560.0, 0.55, 5.0, _light_col, 0.12)
	_burst_front.restart()
	_burst_front.emitting = true


# ================================================================== 시안 C. 노을

func _timeline_twilight(tw: Tween) -> void:
	var start_focus := Layout.WHEEL_CENTER + Vector2(120, -150)
	_cam_focus = start_focus
	_cam_zoom = 3.0
	_omega = 0.38
	_prev_omega = _omega
	_fader.color.a = 1.0
	tw.tween_property(_fader, "color:a", 0.0, 0.6)
	tw.tween_property(self, "_stars_alpha", 1.0, 1.0)
	tw.tween_property(self, "_cam_zoom", 3.25, C_T_PULL)
	# 카메라 풀백
	var pull := C_T_IMPACT - C_T_PULL
	tw.tween_property(self, "_cam_zoom", 1.0, pull).set_delay(C_T_PULL + 0.001) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "_cam_focus", Vector2.ZERO, pull).set_delay(C_T_PULL) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	# 태양 개화
	tw.tween_callback(_impact_twilight).set_delay(C_T_IMPACT)
	tw.tween_property(_flash, "color:a", 0.0, 0.8).from(0.28).set_delay(C_T_IMPACT) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_ray_alpha", 0.55, 0.5).set_delay(C_T_IMPACT) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sun_disc, "scale", _sun_disc.scale, 0.9).from(_sun_disc.scale * 1.12).set_delay(C_T_IMPACT) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sun_glow, "modulate:a", 0.8, 1.2).from(1.0).set_delay(C_T_IMPACT)
	for i in _letters.size():
		var l := _letters[i]
		var d := C_T_IMPACT - 0.12 + i * 0.035
		tw.tween_property(l, "modulate:a", 1.0, 0.2).set_delay(d)
		tw.tween_property(l, "position", Layout.LETTER_CENTERS[i], 0.6) \
				.from(Layout.LETTER_CENTERS[i] + Vector2(0, 80)).set_delay(d) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_leave).set_delay(C_T_LEAVE)


func _impact_twilight() -> void:
	_set_omega_instant(_omega, 1.2)
	_shake = 5.0


# ================================================================== 매 프레임

func _process(delta: float) -> void:
	if not _playing:
		return
	_time += delta
	_angle += _omega * delta
	if delta > 0.0:
		# 각가속도 → 곤돌라 흔들림 (감쇠 진자)
		var accel := (_omega - _prev_omega) / delta
		_prev_omega = _omega
		var a := -50.0 * _swing - 2.6 * _swing_v - 0.22 * accel
		_swing_v += a * delta
		_swing = clampf(_swing + _swing_v * delta, -0.75, 0.75)
		# 카메라 흔들림
		_shake *= exp(-delta * 7.0)
		var amp := maxf(_shake, _shake_floor)
		_shake_off = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * amp if amp > 0.2 else Vector2.ZERO
	if style == Style.SPIN_UP and _time < B_T_IMPACT:
		_trail = clampf((_omega - 2.0) / 10.0, 0.0, 1.0)
		_glow_master = clampf((_omega - 1.0) / 14.0, 0.0, 1.0)
		_shake_floor = 5.0 * clampf(_omega / B_OMEGA_MAX, 0.0, 1.0)
	elif style == Style.SPIN_UP:
		_trail = 0.0
		_shake_floor = 0.0
	if style == Style.NIGHT_LIGHTS and _time < A_T_IMPACT:
		_glow_master = _night_flicker()
	_update_wheel()
	_update_glows()
	_update_camera()
	(_group.material as ShaderMaterial).set_shader_parameter("tint_amount", _tint)
	_fx_front.queue_redraw()
	if style == Style.TWILIGHT:
		_fx_back.queue_redraw()
	if _star_count > 0:
		_bg.queue_redraw()


func _night_flicker() -> float:
	if _time < A_T_FLICKER:
		return 1.0
	if _time >= A_T_OUT:
		return 0.0
	var t := _time - A_T_FLICKER
	for w: Vector2 in A_FLICKER_ON:
		if t >= w.x and t < w.y:
			return 1.0
	return 0.12


func _update_wheel() -> void:
	_wheel.rotation = _angle
	_wheel.scale = Vector2.ONE * _wheel_scale
	var n := Layout.GONDOLA_COUNT
	var spread := minf(_omega * 0.06, TAU / n)   # 잔상 각도 폭 (36° 이상은 대칭이라 무의미)
	for k in _wheel_ghosts.size():
		var gw := _wheel_ghosts[k]
		gw.visible = _trail > 0.01
		gw.rotation = _angle - spread * (k + 1) / GHOSTS
		gw.scale = _wheel.scale
		gw.self_modulate.a = _trail * 0.35
	for i in n:
		var a := _angle + TAU * i / n
		var g := _gondolas[i]
		g.position = _orbit(a)
		g.scale = Vector2.ONE * _wheel_scale
		g.rotation = _swing * (0.85 + 0.15 * cos(a))   # 항상 위를 향하고 관성으로만 흔들림
		for k in GHOSTS:
			var gg := _gondola_ghosts[i * GHOSTS + k]
			gg.visible = _trail > 0.01
			gg.position = _orbit(a - spread * (k + 1) / GHOSTS)
			gg.rotation = g.rotation
			gg.scale = g.scale
			gg.self_modulate.a = _trail * 0.3


func _orbit(a: float) -> Vector2:
	return Layout.WHEEL_CENTER + Vector2(sin(a), -cos(a)) * Layout.GONDOLA_ORBIT * _wheel_scale


func _update_glows() -> void:
	for i in _glows.size():
		var g := _glows[i]
		var gp := _gondolas[i]
		g.position = gp.position + Vector2(0, -14).rotated(gp.rotation)
		var chase := 1.0
		if style == Style.NIGHT_LIGHTS and _time >= A_T_IMPACT:
			chase = 0.72 + 0.28 * sin(_time * 5.0 - i * TAU / _glows.size())   # 마키 조명처럼 빛이 돈다
		g.modulate.a = _glow_on[i] * _glow_master * chase


func _update_camera() -> void:
	var size := get_viewport().get_visible_rect().size
	var s := _base_scale * _cam_zoom
	_stage.scale = Vector2(s, s)
	_stage.position = size * 0.5 - _cam_focus * s + _shake_off


func _set_glow_on(v: float, i: int) -> void:
	_glow_on[i] = v


## 각속도를 즉시 바꾸고 곤돌라에 충격(kick)을 준다
func _set_omega_instant(v: float, kick: float) -> void:
	_omega = v
	_prev_omega = v
	_swing_v += kick


func _add_ring(r0: float, r1: float, dur: float, width: float, col: Color, delay := 0.0) -> void:
	_rings.append({"t0": _time + delay, "dur": dur, "r0": r0, "r1": r1, "w": width, "c": col})


func _draw_fx_front() -> void:
	var keep: Array[Dictionary] = []
	for r in _rings:
		var x: float = (_time - r.t0) / r.dur
		if x < 0.0:
			keep.append(r)
			continue
		if x >= 1.0:
			continue
		keep.append(r)
		var e := 1.0 - pow(1.0 - x, 3.0)
		var radius: float = lerpf(r.r0, r.r1, e)
		var col: Color = r.c
		col.a *= (1.0 - x) * (1.0 - x)
		_fx_front.draw_arc(Layout.WHEEL_CENTER, radius, 0.0, TAU, 128, col, maxf(r.w * (1.0 - x), 1.0), true)
	_rings = keep


func _draw_fx_back() -> void:
	if _ray_alpha <= 0.0:
		return
	var c := _sun_disc.position
	var n := 18
	var rot := _time * 0.06
	for k in n:
		var a := rot + k * TAU / n
		var w := 0.05 + 0.03 * sin(k * 2.3)
		var length := 900.0 * (0.75 + 0.25 * sin(k * 1.7 + 0.5))
		var col := Color(_sky[2].lightened(0.5), _ray_alpha * (0.6 + 0.4 * sin(k * 3.1)))
		var tip := Color(col, 0.0)
		_fx_back.draw_polygon(
				PackedVector2Array([c, c + Vector2.from_angle(a - w) * length, c + Vector2.from_angle(a + w) * length]),
				PackedColorArray([col, tip, tip]))


# ================================================================== 구성

func _setup_palette() -> void:
	match style:
		Style.NIGHT_LIGHTS:
			_sky = [Color("04030a"), Color("07061a"), Color("0f0b24")]
			_logo_col = Color("f7f2e8")
			_light_col = Color("ffc65c")
			_star_count = 110
		Style.SPIN_UP:
			_sky = [Color("090820"), Color("130d33"), Color("2a1650")]
			_logo_col = Color("f4f6ff")
			_light_col = Color("8fe6ff")
			_star_count = 60
		Style.TWILIGHT:
			_sky = [Color("141033"), Color("62305f"), Color("f39150")]
			_logo_col = Color("0e0a1e")
			_light_col = Color("ffd27d")
			_star_count = 35


func _tex(name: String) -> Texture2D:
	return load(_base_dir.path_join("textures/%s.png" % name)) as Texture2D


func _radial_texture(size: int, stops: Array) -> GradientTexture2D:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for s: Vector2 in stops:   # (offset, alpha)
		offsets.append(s.x)
		colors.append(Color(1, 1, 1, s.y))
	g.offsets = offsets
	g.colors = colors
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size
	return t


func _particles(tex: Texture2D, mat: Material, amount: int, lifetime: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.material = mat
	p.emitting = false
	p.amount = amount
	p.lifetime = lifetime
	p.position = Layout.WHEEL_CENTER
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = ramp
	return p


func _build() -> void:
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var soft := _radial_texture(128, [Vector2(0, 1), Vector2(0.3, 0.55), Vector2(1, 0)])
	var dot := _radial_texture(64, [Vector2(0, 1), Vector2(0.25, 0.9), Vector2(0.6, 0.15), Vector2(1, 0)])

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_root)

	_bg = Control.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.draw.connect(_draw_background)
	_root.add_child(_bg)

	_stage = Node2D.new()
	_root.add_child(_stage)

	_fx_back = Node2D.new()
	_fx_back.material = add_mat
	_fx_back.draw.connect(_draw_fx_back)
	_stage.add_child(_fx_back)

	_sun_glow = Sprite2D.new()
	_sun_glow.texture = _radial_texture(256, [Vector2(0, 1), Vector2(0.2, 0.6), Vector2(0.55, 0.15), Vector2(1, 0)])
	_sun_glow.material = add_mat
	_sun_glow.position = Layout.WHEEL_CENTER + Vector2(0, 40)
	_sun_glow.scale = Vector2.ONE * 9.0
	_sun_glow.self_modulate = Color(_light_col, 0.55)
	_sun_glow.visible = style == Style.TWILIGHT
	_stage.add_child(_sun_glow)

	_sun_disc = Sprite2D.new()
	_sun_disc.texture = _radial_texture(256, [Vector2(0, 1), Vector2(0.8, 1), Vector2(0.86, 0.45), Vector2(1, 0)])
	_sun_disc.position = _sun_glow.position
	_sun_disc.scale = Vector2.ONE * 2.05
	_sun_disc.self_modulate = Color("ffe1a0")
	_sun_disc.visible = style == Style.TWILIGHT
	_stage.add_child(_sun_disc)

	_halo = Sprite2D.new()
	_halo.texture = _radial_texture(256, [Vector2(0, 1), Vector2(0.35, 0.25), Vector2(1, 0)])
	_halo.material = add_mat
	_halo.position = Layout.WHEEL_CENTER
	_halo.scale = Vector2.ONE * 3.8
	_halo.self_modulate = Color(_light_col, 0.25)
	_halo.visible = style != Style.TWILIGHT
	_stage.add_child(_halo)

	for i in Layout.GONDOLA_COUNT:
		var g := Sprite2D.new()
		g.texture = soft
		g.material = add_mat
		g.scale = Vector2.ONE * 1.15
		g.self_modulate = _light_col
		g.visible = style != Style.TWILIGHT
		_stage.add_child(g)
		_glows.append(g)
		_glow_on.append(0.0)

	# 시안 A: 바퀴 뒤에서 터지는 폭죽
	_burst_back = _particles(dot, add_mat, 160, 1.7)
	_burst_back.one_shot = true
	_burst_back.explosiveness = 0.95
	_burst_back.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_burst_back.emission_sphere_radius = 30.0
	_burst_back.spread = 180.0
	_burst_back.initial_velocity_min = 380.0
	_burst_back.initial_velocity_max = 1050.0
	_burst_back.damping_min = 450.0
	_burst_back.damping_max = 800.0
	_burst_back.gravity = Vector2(0, 140)
	_burst_back.scale_amount_min = 0.15
	_burst_back.scale_amount_max = 0.55
	_burst_back.color = _light_col
	_stage.add_child(_burst_back)

	_group = CanvasGroup.new()
	var sm := ShaderMaterial.new()
	sm.shader = ShineShader
	sm.set_shader_parameter("tint_color", _light_col.lerp(Color.WHITE, 0.35))
	_group.material = sm
	_stage.add_child(_group)

	_stand = Sprite2D.new()
	_stand.texture = _tex("stand")
	_stand.position = Layout.STAND_CENTER
	_stand.modulate = _logo_col
	_group.add_child(_stand)

	var wtex := _tex("wheel")
	for k in GHOSTS:
		var gw := Sprite2D.new()
		gw.texture = wtex
		gw.position = Layout.WHEEL_CENTER
		gw.modulate = _logo_col
		gw.visible = false
		_group.add_child(gw)
		_wheel_ghosts.append(gw)
	_wheel = Sprite2D.new()
	_wheel.texture = wtex
	_wheel.position = Layout.WHEEL_CENTER
	_wheel.modulate = _logo_col
	_group.add_child(_wheel)

	var gtex := _tex("gondola")
	for i in Layout.GONDOLA_COUNT:
		for k in GHOSTS:
			var gg := Sprite2D.new()
			gg.texture = gtex
			gg.modulate = _logo_col
			gg.visible = false
			_group.add_child(gg)
			_gondola_ghosts.append(gg)
	for i in Layout.GONDOLA_COUNT:
		var s := Sprite2D.new()
		s.texture = gtex
		s.modulate = _logo_col
		_group.add_child(s)
		_gondolas.append(s)

	for i in Layout.LETTER_CENTERS.size():
		var l := Sprite2D.new()
		l.texture = _tex("letter_%02d" % i)
		l.modulate = _logo_col
		_group.add_child(l)
		_letters.append(l)

	_fx_front = Node2D.new()
	_fx_front.material = add_mat
	_fx_front.draw.connect(_draw_fx_front)
	_stage.add_child(_fx_front)

	# 시안 B: 급제동 순간 바퀴에서 튕겨 나가는 불꽃 (궤도 회전하며 퍼짐)
	_burst_front = _particles(dot, add_mat, 140, 1.2)
	_burst_front.one_shot = true
	_burst_front.explosiveness = 1.0
	_burst_front.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	_burst_front.emission_sphere_radius = Layout.GONDOLA_ORBIT
	_burst_front.spread = 180.0
	_burst_front.initial_velocity_min = 60.0
	_burst_front.initial_velocity_max = 260.0
	_burst_front.radial_accel_min = 250.0
	_burst_front.radial_accel_max = 650.0
	_burst_front.orbit_velocity_min = 0.25
	_burst_front.orbit_velocity_max = 0.6
	_burst_front.damping_min = 100.0
	_burst_front.damping_max = 250.0
	_burst_front.scale_amount_min = 0.12
	_burst_front.scale_amount_max = 0.45
	_burst_front.gravity = Vector2(0, 40)
	_burst_front.color = _light_col.lerp(Color.WHITE, 0.4)
	_stage.add_child(_burst_front)

	# 분위기 입자: A 불씨가 피어오름 / C 햇빛 속 먼지
	_ambient = _particles(dot, add_mat, 40, 3.5)
	_ambient.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_ambient.emission_rect_extents = Vector2(420, 260)
	_ambient.direction = Vector2.UP
	_ambient.spread = 25.0
	_ambient.initial_velocity_min = 15.0
	_ambient.initial_velocity_max = 50.0
	_ambient.gravity = Vector2(0, -12)
	_ambient.scale_amount_min = 0.08
	_ambient.scale_amount_max = 0.25
	_ambient.color = Color(_light_col, 0.8)
	_stage.add_child(_ambient)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.material = add_mat
	_flash.color = Color(_light_col.lerp(Color.WHITE, 0.75), 0.0)
	_root.add_child(_flash)

	_fader = ColorRect.new()
	_fader.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fader.color = Color(0, 0, 0, 0)
	_root.add_child(_fader)

	_audio = AudioStreamPlayer.new()
	_audio.stream = load(_base_dir.path_join("sfx/" + SFX[style]))
	add_child(_audio)

	_rng.seed = 20261005
	for i in _star_count:
		var y := _rng.randf()
		if style == Style.TWILIGHT:
			y *= 0.4   # 노을: 하늘 위쪽에만
		_stars.append(Vector4(_rng.randf(), y, _rng.randf_range(0.6, 2.0), _rng.randf() * TAU))


func _reset_state() -> void:
	_rings.clear()
	_angle = 0.0
	_swing = 0.0
	_swing_v = 0.0
	_shake = 0.0
	_shake_floor = 0.0
	_shake_off = Vector2.ZERO
	_trail = 0.0
	_tint = 0.0
	_ray_alpha = 0.0
	_stars_alpha = 0.0
	_glow_master = 0.0
	_cam_zoom = 1.0
	_cam_focus = Vector2.ZERO
	_wheel_scale = 1.0
	for i in _glow_on.size():
		_glow_on[i] = 0.0
	for i in _letters.size():
		_letters[i].position = Layout.LETTER_CENTERS[i]
		_letters[i].scale = Vector2.ONE
		_letters[i].modulate.a = 0.0
	_halo.modulate.a = 0.0
	_group.self_modulate.a = 1.0
	_root.modulate.a = 1.0
	_flash.color.a = 0.0
	_fader.color.a = 0.0
	_ambient.emitting = style == Style.TWILIGHT
	if style == Style.TWILIGHT:
		_ambient.preprocess = 2.0
	var sm := _group.material as ShaderMaterial
	sm.set_shader_parameter("progress", -10.0)
	sm.set_shader_parameter("tint_amount", 0.0)
	_update_wheel()
	_update_glows()


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	_base_scale = minf(size.x * logo_fit / Layout.LOGO_SIZE.x, size.y * logo_fit / Layout.LOGO_SIZE.y)
	_update_camera()
	_bg.queue_redraw()


func _draw_background() -> void:
	var size := _bg.size
	var mid := size.y * 0.55
	_bg.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, mid), Vector2(0, mid)]),
			PackedColorArray([_sky[0], _sky[0], _sky[1], _sky[1]]))
	_bg.draw_polygon(PackedVector2Array([Vector2(0, mid), Vector2(size.x, mid), size, Vector2(0, size.y)]),
			PackedColorArray([_sky[1], _sky[1], _sky[2], _sky[2]]))
	if _stars_alpha <= 0.0:
		return
	var unit := minf(size.x, size.y) / 720.0
	for st in _stars:
		var tw := 0.35 + 0.65 * (0.5 + 0.5 * sin(_time * (1.2 + st.z) + st.w))
		var c := Color(1, 0.97, 0.92, 0.6 * tw * _stars_alpha * (st.z / 2.0))
		_bg.draw_circle(Vector2(st.x * size.x, st.y * size.y), st.z * unit, c)


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	if _tween:
		_tween.kill()
	var skipped := _time < A_T_IMPACT + 0.8
	var dur := 0.3 if skipped else 0.6
	var tw := create_tween().set_parallel(true)
	_tween = tw
	if next_scene != "":
		tw.tween_property(_fader, "color:a", 1.0, dur)
	else:
		tw.tween_property(_root, "modulate:a", 0.0, dur)
	if _audio.playing and skipped:
		tw.tween_property(_audio, "volume_db", -40.0, dur)
	tw.chain().tween_callback(_finish)


func _finish() -> void:
	_playing = false
	_audio.stop()
	finished.emit()
	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)
	elif free_when_finished:
		queue_free()
