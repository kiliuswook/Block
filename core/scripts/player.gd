class_name Player
extends Node2D
## Cube-cat character: run, double-tap dash, jump with air control,
## balloon float (jump again in the air), fast fall. Custom AABB physics against the EscapeBoard grid.

const CatArt := preload("res://core/scripts/cat_art.gd")

const SIZE := 50.0
const SQUASH_TIME := 0.12
const SCARE_EASE := 7.0  # 놀람이 풀리는 속도 (놀라는 건 즉시, 푸는 건 천천히)
const JOLT_TIME := 0.22  # 착지 충격에 몸이 튀는 시간

const BODY_COLOR := Color("f4e3c8")
const EAR_COLOR := Color("d9a05c")
const DEAD_BODY_COLOR := Color("a8a29a")
const DEAD_EAR_COLOR := Color("7d7770")
const INK_COLOR := Color("4a3b30")
const RUN_SPEED := 330.0
const DASH_SPEED := 850.0
const DASH_TIME := 0.22
const DASH_COOLDOWN := 0.25
const DOUBLE_TAP := 0.3
const BREAK_PROBE := 10.0
const KNOCKBACK_SPEED := 420.0
const KNOCKBACK_TIME := 0.15
const WALL_SLIDE_SPEED := 160.0
const FLAP_TIME := 0.18  # 날갯짓 한 번에 몸이 출렁이는 시간
const PUFF_TIME := 0.14  # 부풀고 꺼지는 데 걸리는 시간
const GAUGE_SIZE := Vector2(58.0, 10.0)  # 머리 위 풍선 게이지 막대
const GAUGE_LINGER := 0.7  # 게이지가 다 찬 뒤 막대가 남아 있는 시간
const GAUGE_FLASH := 0.25  # 게이지가 모자라 거절당했을 때 막대가 번쩍이는 시간
const GRAVITY := 2300.0
const FAST_FALL_FACTOR := 2.2
const MAX_FALL := 1300.0
const JUMP_VEL := -840.0
const COYOTE := 0.1
const JUMP_BUFFER := 0.12
const STEP := 4.0

## 풍선 점프 (커비식): 공중에서 점프를 다시 누르면 몸을 부풀려 뜨고, 연타하면
## 더 오른다. 테스트 중인 값이라 인스펙터에서 바로 만질 수 있게 열어 둔다.
@export_group("풍선 점프")
## 공중에서 점프를 누를 때마다 위로 붙는 속도 (px/s, × jump 능력치)
@export var float_flap_velocity := -430.0
## 부푼 동안의 중력 (px/s²) — 평소 GRAVITY 보다 훨씬 가볍다
@export var float_gravity := 900.0
## 부푼 채 가만히 있으면 이 속도로 천천히 가라앉는다 (px/s)
@export var float_max_fall := 140.0
## 부푼 동안의 좌우 이동 배율
@export var float_move_factor := 0.75
## 마지막으로 디딘 자리에서 몇 칸 위까지 뜰 수 있는가 (칸 = board.CELL)
@export var float_max_height_cells := 5.0
## 부풀었을 때 몸 그림 배율 (판정 크기는 그대로)
@export var float_puff_scale := 1.28
## 풍선 게이지(0~1): 공중에서 점프를 한 번 누를 때마다 드는 양
@export var float_gauge_flap_cost := 0.12
## 부풀어 떠 있는 동안 초당 줄어드는 양
@export var float_gauge_drain := 0.25
## 바닥에 서 있는 동안 초당 차는 양 (공중에서는 차지 않는다)
@export var float_gauge_refill := 0.18
## 착지한 뒤 차기 시작할 때까지의 뜸 (초)
@export var float_gauge_refill_delay := 0.4

var velocity := Vector2.ZERO
var alive := true
var on_floor := false
var dash_timer := 0.0
var dash_dir := 0
var dash_cooldown := 0.0
var coyote_timer := 0.0
var jump_buffer := 0.0
var knockback_timer := 0.0
var knockback_vx := 0.0
var wall_dir := 0  # -1: wall on the left, 1: on the right, 0: none
var squash_timer := 0.0
var floating := false  # 풍선처럼 부풀어 떠 있는 중
var float_base_y := 0.0  # 마지막으로 디딘 자리 — 뜰 수 있는 높이의 기준
var flap_timer := 0.0
var float_gauge := 1.0  # 풍선 게이지 (0~1) — 바닥에서만 찬다
var gauge_wait := 0.0  # 착지 뒤 게이지가 차기 시작할 때까지 남은 시간
var gauge_show := 0.0  # 머리 위 게이지 막대가 보이는 남은 시간
var gauge_flash := 0.0
var puff := 0.0  # 부푼 정도 (0~1) — 그림만 따라간다
var facing := 1
var last_tap := {-1: -1e9, 1: -1e9}
var skin_override := ""
var scare := 0.0  # 머리 위 블록이 얼마나 가까운가 (0~1) — 움츠림·놀란 표정을 몬다
var jolt := 0.0  # 근처에 블록이 박힌 충격 (0~1) — 몸이 한 번 튄다
# Per-cat stat multipliers, refreshed from GameState on respawn.
var stat_speed := 1.0
var stat_jump := 1.0
var stat_dash := 1.0
var stat_weight := 1.0
var stat_push := 2  # dash shove power, in cells
@onready var board: EscapeBoard = get_parent()


func _ready() -> void:
	_refresh_stats()


## Reads the selected (or override) cat's stat multipliers.
func _refresh_stats() -> void:
	var skin_id := skin_override
	if skin_id == "":
		skin_id = GameState.selected_cat
	var stats: Dictionary = GameState.cat_stats(skin_id)
	stat_speed = stats.get("speed", 1.0)
	stat_jump = stats.get("jump", 1.0)
	stat_dash = stats.get("dash", 1.0)
	stat_weight = stats.get("weight", 1.0)
	stat_push = int(stats.get("push", 2))


func respawn(pos: Vector2) -> void:
	_refresh_stats()
	position = pos
	velocity = Vector2.ZERO
	alive = true
	on_floor = false
	scare = 0.0
	jolt = 0.0
	dash_timer = 0.0
	dash_cooldown = 0.0
	coyote_timer = 0.0
	jump_buffer = 0.0
	knockback_timer = 0.0
	wall_dir = 0
	floating = false
	float_base_y = pos.y
	flap_timer = 0.0
	float_gauge = 1.0
	gauge_wait = 0.0
	gauge_show = 0.0
	gauge_flash = 0.0
	puff = 0.0
	facing = 1
	queue_redraw()


func die() -> void:
	alive = false
	queue_redraw()


func rect() -> Rect2:
	return Rect2(position - Vector2.ONE * SIZE / 2.0, Vector2.ONE * SIZE)


func _physics_process(delta: float) -> void:
	if not alive or not board.playing or board.is_paused:
		return
	if board.fever_on():
		# 피버타임: 중력도 블록도 없다. 저 혼자 솟구치고, 조작은 좌우뿐 —
		# 별을 훑으러 다니라고 남겨 둔 폭이다.
		_fever_motion(delta)
		queue_redraw()
		return
	squash_timer = maxf(squash_timer - delta, 0.0)
	flap_timer = maxf(flap_timer - delta, 0.0)
	var was_floating := floating
	# 머리 위 블록: 놀라는 건 즉시, 푸는 건 천천히 — 스쳐 지나가도 여운이 남는다.
	scare = maxf(board.overhead_threat(rect()), scare - delta * SCARE_EASE)
	jolt = maxf(jolt - delta / JOLT_TIME, 0.0)
	_handle_input(delta)
	_apply_motion(delta)
	if was_floating and not floating:
		# 바람이 빠지는 순간: 발밑으로 훅 불어 낸다.
		board.land_dust(Vector2(position.x, rect().end.y), 0.35)
	puff = move_toward(puff, 1.0 if floating else 0.0, delta / PUFF_TIME)
	gauge_flash = maxf(gauge_flash - delta, 0.0)
	gauge_show = GAUGE_LINGER if float_gauge < 1.0 else maxf(gauge_show - delta, 0.0)
	queue_redraw()


## 피버타임 상승: 위로는 보드가 정한 속도로 일정하게, 좌우만 조작이 먹는다.
## 벽 안쪽으로만 가둬 두고 블록 충돌은 아예 재지 않는다 — 스택을 뚫고 오른다.
func _fever_motion(delta: float) -> void:
	squash_timer = 0.0
	scare = 0.0
	jolt = maxf(jolt - delta / JOLT_TIME, 0.0)
	dash_timer = 0.0
	knockback_timer = 0.0
	on_floor = false
	coyote_timer = 0.0
	wall_dir = 0
	floating = false
	puff = 0.0
	gauge_show = 0.0
	float_base_y = position.y
	var axis := Input.get_axis("move_left", "move_right")
	if axis != 0.0:
		facing = int(signf(axis))
	velocity = Vector2(axis * RUN_SPEED * stat_speed * board.FEVER_STEER, -board.fever_rise())
	position += velocity * delta
	position.x = clampf(position.x, SIZE / 2.0,
			board.COLS * board.CELL - SIZE / 2.0)


## 옆에서 블록이 쿵 하고 박혔다 — 몸이 한 번 튄다 (escape_board가 부른다).
func shock(power: float) -> void:
	jolt = maxf(jolt, clampf(power, 0.0, 1.0))
	squash_timer = maxf(squash_timer, SQUASH_TIME * 0.7 * power)


func _handle_input(delta: float) -> void:
	dash_cooldown = maxf(dash_cooldown - delta, 0.0)
	# 풍선 게이지는 바닥을 딛고 잠깐 숨을 고른 뒤에만 찬다.
	if on_floor:
		gauge_wait = maxf(gauge_wait - delta, 0.0)
		if gauge_wait <= 0.0:
			float_gauge = minf(float_gauge + float_gauge_refill * delta, 1.0)
	else:
		gauge_wait = float_gauge_refill_delay
	var now := Time.get_ticks_msec() / 1000.0
	for dir in [-1, 1]:
		var action := "move_left" if dir == -1 else "move_right"
		if Input.is_action_just_pressed(action):
			if now - last_tap[dir] <= DOUBLE_TAP and dash_cooldown <= 0.0:
				dash_timer = DASH_TIME
				dash_dir = dir
				dash_cooldown = DASH_COOLDOWN / stat_dash
				Sfx.play("dash")
			last_tap[dir] = now
	var axis := Input.get_axis("move_left", "move_right")
	if axis != 0.0:
		facing = int(signf(axis))
	# Shift dash: dashes toward the held direction, or the way we last faced.
	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0:
		dash_timer = DASH_TIME
		dash_dir = int(signf(axis)) if axis != 0.0 else facing
		dash_cooldown = DASH_COOLDOWN / stat_dash
		Sfx.play("dash")
	if knockback_timer > 0.0:
		knockback_timer -= delta
		velocity.x = knockback_vx
	elif dash_timer > 0.0:
		dash_timer -= delta
		velocity.x = dash_dir * DASH_SPEED * stat_dash
	else:
		velocity.x = axis * RUN_SPEED * stat_speed
		if floating:
			velocity.x *= float_move_factor
	if dash_timer > 0.0:
		floating = false  # 대시는 바람을 빼고 나간다
	if Input.is_action_just_pressed("jump"):
		jump_buffer = JUMP_BUFFER
	else:
		jump_buffer = maxf(jump_buffer - delta, 0.0)
	coyote_timer = COYOTE if on_floor else maxf(coyote_timer - delta, 0.0)
	wall_dir = _wall_contact()
	var jump_vel := JUMP_VEL * stat_jump
	if jump_buffer > 0.0 and coyote_timer > 0.0:
		velocity.y = jump_vel
		jump_buffer = 0.0
		coyote_timer = 0.0
		Sfx.play("jump")
	elif Input.is_action_just_pressed("jump") and not on_floor:
		# 공중에서 다시 점프: 부풀어 뜬다. 입력 버퍼는 그대로 둬서, 바닥 직전에
		# 누른 점프는 착지하자마자 평소 점프로 나간다.
		_flap()
	var fast_fall := Input.is_action_pressed("soft_drop")
	if floating and fast_fall:
		floating = false  # 낙하 키는 바람을 빼고 곧장 떨어진다
	if floating:
		float_gauge = maxf(float_gauge - float_gauge_drain * delta, 0.0)
		if float_gauge <= 0.0:
			floating = false  # 게이지가 바닥나면 바람이 빠진다
	if floating:
		velocity.y = minf(velocity.y + float_gravity * delta, float_max_fall)
		# 뜰 수 있는 높이는 마지막으로 디딘 자리 기준으로 정해져 있다.
		var top_y := float_base_y - float_max_height_cells * board.CELL
		if velocity.y < 0.0:
			velocity.y = maxf(velocity.y, minf((top_y - position.y) / delta, 0.0))
	else:
		var g := GRAVITY
		if velocity.y > 0.0 and fast_fall:
			g *= FAST_FALL_FACTOR * stat_weight
		velocity.y = minf(velocity.y + g * delta, MAX_FALL)
	# Hug a wall while falling to slide down it slowly (unless fast-falling).
	if not on_floor and wall_dir != 0 and not fast_fall and velocity.y > WALL_SLIDE_SPEED:
		velocity.y = WALL_SLIDE_SPEED


## 풍선 점프 한 번: 처음이면 부풀고, 이미 부풀어 있으면 한 번 더 떠오른다.
## 게이지가 모자라면 아무 일도 없고 머리 위 막대만 번쩍인다.
func _flap() -> void:
	if float_gauge < float_gauge_flap_cost:
		gauge_flash = GAUGE_FLASH
		return
	float_gauge -= float_gauge_flap_cost
	floating = true
	velocity.y = float_flap_velocity * stat_jump
	flap_timer = FLAP_TIME
	dash_timer = 0.0
	Sfx.play("puff")
	board.land_dust(Vector2(position.x, rect().end.y), 0.2)


func _apply_motion(delta: float) -> void:
	var hit_h := _move_axis(Vector2(velocity.x * delta, 0.0))
	if hit_h and dash_timer > 0.0 and velocity.x != 0.0:
		# Dash impact shoves the falling piece sideways (push stat = cells),
		# or smashes one locked block — either way the player bounces off.
		var dirx := signf(velocity.x)
		var side := rect()
		side.position.x += dirx * BREAK_PROBE
		var probe := side.grow_individual(0.0, -6.0, 0.0, -6.0)
		if board.piece_hits_rect(probe):
			board.shove_piece(int(dirx), stat_push)
			dash_timer = 0.0
			knockback_timer = KNOCKBACK_TIME
			knockback_vx = -dirx * KNOCKBACK_SPEED / stat_weight
		elif board.break_cell_in_rect(probe):
			dash_timer = 0.0
			knockback_timer = KNOCKBACK_TIME
			knockback_vx = -dirx * KNOCKBACK_SPEED / stat_weight
	var hit_v := _move_axis(Vector2(0.0, velocity.y * delta))
	if hit_v:
		if velocity.y > 0.0:
			if not on_floor and velocity.y > 300.0:
				squash_timer = SQUASH_TIME
				Sfx.play("land")
				# 내려앉은 발밑에서 먼지가 인다 — 세기는 떨어진 속도를 따른다.
				board.land_dust(Vector2(position.x, rect().end.y),
						clampf(velocity.y / 1400.0, 0.2, 1.0))
			on_floor = true
		elif velocity.y < 0.0 and not floating:
			# Head-bump smashes the single block above (부푼 몸으로는 못 부순다).
			var head := rect()
			head.position.y -= BREAK_PROBE
			board.break_cell_in_rect(head.grow_individual(-6.0, 0.0, -6.0, 0.0))
		velocity.y = 0.0
	else:
		var feet := Rect2(position.x - SIZE / 2.0, position.y + SIZE / 2.0, SIZE, 2.0)
		on_floor = velocity.y >= 0.0 and board.rect_blocked_for_player(feet)
	if on_floor:
		floating = false
		float_base_y = position.y


## Returns which side has a wall/block flush against the player.
func _wall_contact() -> int:
	var half := SIZE / 2.0
	var left := Rect2(position.x - half - 2.0, position.y - half + 6.0, 2.0, SIZE - 12.0)
	var right := Rect2(position.x + half, position.y - half + 6.0, 2.0, SIZE - 12.0)
	if board.rect_blocked_for_player(left):
		return -1
	if board.rect_blocked_for_player(right):
		return 1
	return 0


## Moves along one axis in small steps; returns true if blocked.
func _move_axis(motion: Vector2) -> bool:
	var remaining := motion.length()
	if remaining <= 0.0:
		return false
	var dir := motion.normalized()
	while remaining > 0.0:
		var step := minf(remaining, STEP)
		var next := position + dir * step
		if board.rect_blocked_for_player(Rect2(next - Vector2.ONE * SIZE / 2.0, Vector2.ONE * SIZE)):
			# Creep up to the surface pixel by pixel.
			while not board.rect_blocked_for_player(
					Rect2(position + dir - Vector2.ONE * SIZE / 2.0, Vector2.ONE * SIZE)):
				position += dir
			return true
		position = next
		remaining -= step
	return false


func _draw() -> void:
	var half := SIZE / 2.0
	var body := Rect2(-Vector2.ONE * half, Vector2.ONE * SIZE)
	var look := signf(velocity.x) * 4.0
	var skin_id := skin_override
	if skin_id == "":
		skin_id = GameState.selected_cat
	var skin: Dictionary = GameState.cat_skin(skin_id)
	var trail: Color = skin.get("body", BODY_COLOR)
	# 피버 상승 잔상: 지나온 자리에 몸이 길게 늘어져 남는다 — 속도를 몸으로 말한다.
	if board.fever_on():
		var speed := board.fever_rise()
		var stretch := clampf(speed / board.FEVER_RISE, 0.0, 1.0)
		for i in range(1, 6):
			var ghost := body
			ghost.position.y += float(i) * SIZE * 0.42 * stretch
			draw_rect(ghost, Color(trail, (0.30 - float(i) * 0.05) * stretch))
	if dash_timer > 0.0:
		draw_rect(body.grow(5.0), Color(trail, 0.22))
		for i in range(1, 4):
			var ghost := body
			ghost.position.x -= dash_dir * i * 16.0
			draw_rect(ghost, Color(trail, 0.2 - i * 0.05))
	# Squash on landing, stretch while airborne.
	var scale_xy := Vector2.ONE
	if squash_timer > 0.0:
		var t := squash_timer / SQUASH_TIME
		scale_xy = Vector2(1.0 + 0.2 * t, 1.0 - 0.24 * t)
	elif not on_floor:
		if velocity.y < -220.0:
			scale_xy = Vector2(0.9, 1.13)
		elif velocity.y > 500.0:
			scale_xy = Vector2(0.94, 1.07)
	# 풍선 점프: 빵 하고 부풀었다(살짝 넘쳤다 돌아온다) 날갯짓마다 위로 출렁인다.
	var inflate := _puff_ease(puff)
	if puff > 0.0:
		var pulse := flap_timer / FLAP_TIME
		var breathe := sin(Time.get_ticks_msec() / 1000.0 * 5.0) * 0.03
		var full := Vector2(float_puff_scale + 0.06, float_puff_scale) \
				+ Vector2(-0.1, 0.12) * pulse + Vector2(breathe, -breathe)
		scale_xy = scale_xy.lerp(full, inflate)
	# 머리 위에서 블록이 내려오면 납작하게 움츠린다 — 놀랄수록 더 눌린다.
	if alive and scare > 0.0:
		scale_xy *= Vector2(1.0 + 0.14 * scare, 1.0 - 0.16 * scare)
	# 옆에서 블록이 박힌 충격은 짧게 떨리는 흔들림으로 나온다.
	var jitter := Vector2.ZERO
	if jolt > 0.0:
		jitter = Vector2(sin(jolt * 47.0), cos(jolt * 61.0)) * 3.5 * jolt
	draw_set_transform(jitter + Vector2(0.0, half * (1.0 - scale_xy.y)), 0.0, scale_xy)
	var mouth_open := (not on_floor and not floating and velocity.y < -100.0) or scare > 0.45
	if puff > 0.0:
		_draw_balloon_back(half, inflate, skin)
	paint_cat(self, Vector2.ZERO, SIZE, look, alive, mouth_open, skin)
	if puff > 0.0:
		_draw_balloon_shine(half, inflate)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if alive and gauge_show > 0.0 and not board.fever_on():
		_draw_float_gauge(half)
	if alive and scare > 0.2:
		_draw_scare(half)



## 부푸는 곡선: 끝에서 살짝 넘쳤다 돌아온다 (back-out).
func _puff_ease(t: float) -> float:
	var u := t - 1.0
	return 1.0 + 2.7 * u * u * u + 1.7 * u * u


## 풍선 몸: 네모난 몸 뒤로 둥근 배가 사방으로 불룩 나온다 (몸 색 + 잉크 외곽선).
func _draw_balloon_back(half: float, inflate: float, skin: Dictionary) -> void:
	var a := clampf(inflate, 0.0, 1.0)
	var r := half * (0.8 + 0.46 * a)
	draw_circle(Vector2.ZERO, r + 3.0, Color(skin.get("ink", INK_COLOR), a))
	draw_circle(Vector2.ZERO, r, Color(skin.get("body", BODY_COLOR), a))


## 풍선 광택: 빛은 늘 위에서 — 왼쪽 위에 흰 호 하나와 점 하나.
func _draw_balloon_shine(half: float, inflate: float) -> void:
	var a := clampf(inflate, 0.0, 1.0) * 0.8
	draw_arc(Vector2.ZERO, half * 1.1, PI * 1.12, PI * 1.36, 10, Color(1, 1, 1, a), 4.0)
	draw_circle(Vector2.from_angle(PI * 1.44) * half * 1.1, 2.6, Color(1, 1, 1, a))


## 풍선 게이지: 머리 위 작은 막대. 다 차 있으면 숨고, 쓰기 시작하면 뜬다.
## 넉넉하면 하늘색, 날갯짓 두 번이 안 남으면 빨강, 모자라 거절당하면 번쩍인다.
func _draw_float_gauge(half: float) -> void:
	var a := clampf(gauge_show / 0.3, 0.0, 1.0)
	var head_y := half - SIZE * lerpf(1.0, float_puff_scale, clampf(puff, 0.0, 1.0))
	var bar := Rect2(Vector2(-GAUGE_SIZE.x / 2.0, head_y - 24.0 - GAUGE_SIZE.y), GAUGE_SIZE)
	draw_rect(bar.grow(3.0), Color(0.17, 0.11, 0.09, a))
	draw_rect(bar, Color(1.0, 1.0, 1.0, 0.92 * a))
	var col := Color("3ec1f3")
	if float_gauge < float_gauge_flap_cost * 2.0:
		col = Color("ff5a4d")
	if gauge_flash > 0.0:
		col = col.lerp(Color.WHITE, gauge_flash / GAUGE_FLASH)
		draw_rect(bar.grow(3.0), Color(1.0, 0.35, 0.3, a * gauge_flash / GAUGE_FLASH), false, 3.0)
	var fill := bar
	fill.size.x = bar.size.x * clampf(float_gauge, 0.0, 1.0)
	draw_rect(fill, Color(col, a))


## 머리 위 블록이 코앞이라는 신호: 볼 옆 땀방울과, 가까우면 머리 위 느낌표.
## 냥이 그림 위에 코드로 얹는다 — 스프라이트든 코드 렌더든 똑같이 붙고, 어두운
## 우물에서도 읽히도록 크림색 + 잉크 외곽선으로 그린다.
func _draw_scare(half: float) -> void:
	var t := clampf((scare - 0.2) / 0.8, 0.0, 1.0)
	# 땀방울 — 놀란 쪽(바라보는 반대편) 볼 옆에서 흘러내린다.
	var sx := -float(facing)
	var rr := half * 0.24
	var drop := Vector2(sx * half * 0.95, -half * 0.45 + half * 0.6 * t)
	var tear := PackedVector2Array([
		drop + Vector2(0.0, -rr * 1.9), drop + Vector2(rr, rr * 0.45),
		drop + Vector2(0.0, rr * 1.2), drop + Vector2(-rr, rr * 0.45),
	])
	draw_polyline(tear + PackedVector2Array([tear[0]]),
			Color(0.17, 0.16, 0.20, 0.9 * t), rr * 0.5)
	draw_colored_polygon(tear, Color(0.62, 0.87, 1.0, 0.95 * t))
	draw_circle(drop + Vector2(-rr * 0.32, -rr * 0.25), rr * 0.33,
			Color(1.0, 1.0, 1.0, 0.9 * t))
	if scare < 0.35:
		return
	# 더 가까워지면 머리 위에 느낌표가 튀어 오른다. 어두운 우물에서 묻히지 않게
	# 뜨자마자 제 색을 내고(짧은 페이드인), 가까울수록 더 높이 뛴다.
	var a := clampf((scare - 0.35) / 0.12, 0.0, 1.0)
	var e := clampf((scare - 0.35) / 0.5, 0.0, 1.0)
	var w := half * 0.3
	var bx := half * 0.55 * float(facing) - w / 2.0
	var by := -half * (1.55 + 0.25 * e)
	var bar := Rect2(bx, by, w, half * 0.66)
	var dot := Rect2(bx, by + half * 0.8, w, w)
	for r: Rect2 in [bar, dot]:
		draw_rect(r.grow(w * 0.4), Color(0.17, 0.16, 0.20, a))
		draw_rect(r, Color(1.0, 0.86, 0.32, a))


## 큐브 고양이 렌더는 파츠 레이어 방식으로 cat_art.gd가 담당한다.
## (아래는 다른 스크립트가 쓰는 얇은 위임 래퍼 — 호출부는 그대로 Player.* 사용)


## Small heart glyph (forehead marks, UI 장식).
static func paint_heart(ci: CanvasItem, at: Vector2, r: float, col: Color) -> void:
	CatArt.heart(ci, at, r, col)


## Four-point twinkle star (UI 반짝임).
static func paint_sparkle(ci: CanvasItem, at: Vector2, r: float, col: Color) -> void:
	CatArt.sparkle(ci, at, r, col)


## Draws the cube cat onto any canvas item (player, title screen, ...).
## skin carries the part set: {"body", "ear", "ink", "parts"}.
static func paint_cat(ci: CanvasItem, center: Vector2, s: float, look := 0.0,
		cat_alive := true, mouth_open := false, skin: Dictionary = {}) -> void:
	CatArt.paint(ci, center, s, look, cat_alive, mouth_open, skin)

