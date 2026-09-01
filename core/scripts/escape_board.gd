class_name EscapeBoard
extends Node2D
## 우물 보드: 테트로미노가 화면 위에서 플레이어의 열을 따라다니다가, 카운트다운이
## 끝나면 자유낙하해 격자에 박힌다. 플레이어는 쌓인 블록을 밟고 오른다. 떨어지는
## 블록에 깔리면 사망. SHAPES/KICKS/COLORS는 Board에서 재사용한다.
## 모드는 둘뿐이다 — 스테이지 모드(밀폐 우물 + 레벨 클리어 셔터)와 무한의 계단
## (카메라 추적 + 상승하는 용암). 둘 다 우물이 사방으로 막혀 있어서, 예전
## 스토리 모드가 쓰던 옆벽 출구(문)는 함께 걷어 냈다.

enum PieceState { TRACKING, FALLING, LANDED }
# 값은 GameState.MODE_* 와 1:1 — 내린 모드(0 스토리 · 2 2P 대전 · 4 피크닉)
# 자리는 남은 모드의 번호가 흔들리지 않게 비워 둔다.
enum Mode { ENDLESS = 1, CLASSIC = 3 }

const CatSprite := preload("res://core/scripts/cat_sprite.gd")
const UiKit := preload("res://core/scripts/ui_kit.gd")

const COLS := 10
const PIT_ROWS := 20  # actual well height, every mode — standard tetris
const CELL := 64.0
const TRACK_TIME_BASE := 5.0
const TRACK_TIME_MIN := 2.0
const TRACK_STEP := 0.07
const FALL_INTERVAL_BASE := 0.26
const FALL_INTERVAL_MIN := 0.1
const LINE_SCORES := [0, 100, 300, 500, 800]
const CRUSH_MARGIN := 6.0
const SOFT_DROP_FACTOR := 4.0
const DROP_DOUBLE_TAP := 0.3
const BREAK_SCORE := 20
const BREAK_FX_TIME := 0.3
# 골드 블록: 떨어지는 블록 네 칸 중 하나에 금이 박혀 나온다. 직접 부딪혀 깨거나
# 줄로 지우면 제값(ORE_VALUE)을, 레벨 클리어 셔터가 쓸어 가면 절반만 준다 —
# "제때 먹어라"가 낮게 쌓기(빈 줄 보너스)와 같은 방향을 보게 하는 값이다.
const ORE_CHANCE := 0.10  # 이 확률로 블록 하나에 금이 박힌다
const ORE_GARBAGE_CHANCE := 0.35  # 스테이지 방해 블록 줄마다 금 한 칸이 섞일 확률
const ORE_VALUE := 20  # 직접 깨기 · 줄 클리어
const ORE_SWEEP_VALUE := 10  # 셔터가 쓸어 간 몫 (절반)
const ORE_FX_TIME := 0.6  # 금이 사방으로 튀는 연출 길이
const ORE_SPARKS := 9
const LOCK_GRACE := 0.7  # landed piece stays shovable this long before locking
const HEIGHT_SCORE := 10
const VIEW_BELOW := 620.0  # how far below the camera center the pit stays drawn
const ENDLESS_SPAWN_AHEAD := 9  # piece spawns this many cells above the camera cell
const SPAWN_CLEARANCE := 4  # next piece hovers at least a box height above loose pieces
const LAVA_START_OFFSET := CELL * 3.0
const LAVA_SPEED_BASE := 8.0
const LAVA_SPEED_STEP := 2.0
const LAVA_SPEED_MAX := 45.0
const LAVA_MAX_GAP := 980.0  # lava never trails the player by more than this
const LAVA_PUSH := [0, 2, 5, 9, 15]  # endless: lava shoved down this many cells per clear size
# --- 골드러시 (무한의 계단 전용 스파이크) --------------------------------------
# 무한의 계단은 처음부터 끝까지 같은 리듬으로 조여 오기만 해서 "판이 뒤집히는
# 순간"이 없었다. 골드러시가 그 자리다. 게이지는 **시간으로는 절대 차지 않고**
# 줄 클리어·콤보·금 캐기·용암 발끝 세이브로만 찬다 — 운이 아니라 실력이
# 터뜨린다. 발동하면 용암이 멎고 블록마다 금이 박혀 나오며, 끝나는 순간 필드에
# 남은 금이 아래에서부터 한 칸씩 순차로 터진다: 그래서 러시 중에는 "지금 캘까,
# 쌓아 둘까"라는 판단이 하나 더 생긴다.
const RUSH_MAX := 100.0
const RUSH_LINE_GAIN := [0.0, 8.0, 20.0, 36.0, 60.0]  # 한 번에 지운 줄 수만큼
const RUSH_COMBO_GAIN := 5.0  # 콤보 한 단계마다 얹는다
const RUSH_ORE_GAIN := 6.0  # 금 한 칸을 직접 깨서 캤다
const RUSH_NEAR_GAIN := 12.0  # 발끝 세이브: 용암에 붙어 있는 동안 초당
const RUSH_NEAR_DIST := CELL * 1.5  # 발과 용암이 이보다 가까우면 "발끝"
const RUSH_TIME := 10.0  # 발동 지속 (초)
const RUSH_ORE_CHANCE := 0.75  # 발동 중 블록에 금이 박힐 확률
const RUSH_LAVA_PUSH := 6  # 발동 순간 용암을 이만큼(칸) 밀어낸다
const RUSH_POP_STEP := 0.09  # 종료 폭발: 금 한 칸이 터지는 간격
const RUSH_FLASH_TIME := 0.5  # 발동 순간의 금빛 섬광
# Classic level-clear shutter (Atari B-type): a steel curtain rolls down over
# the well, paying a bonus for every empty row it passes at the top, holds shut
# while the next level's board is dealt behind it, then rolls back up.
const SHUTTER_CLOSE_STEP := 0.075  # seconds per row on the way down
const SHUTTER_OPEN_STEP := 0.028  # the curtain snaps back up faster
const SHUTTER_HOLD := 0.4  # beat with the well fully covered
const SHUTTER_POP_TIME := 0.18  # the tally flares each time it ticks up
# Marathon creep (classic / endless): every stretch of survived play adds a
# gravity step on top of the mode's own ramp, so a long run keeps tightening.
const SPEED_CREEP_TIME := 45.0  # seconds of play per extra step
const SPEED_CREEP_MAX := 8  # the creep alone never exceeds this many steps

# --- 타격감(임팩트 연출) 상수 -------------------------------------------------
# 블록이 "무겁게" 느껴지도록 이동·회전·낙하·착지·줄 클리어마다 화면을 흔들고
# 잔상·먼지·파편·배너를 얹는다. 전부 보드 로컬 좌표로 그리므로 가로·세로 화면이
# 같은 코드를 쓴다 — 흔들림만 고정 우물은 노드 자리를, 무한은 카메라를 민다.
const SHAKE_MAX := 30.0  # 흔들림 진폭 상한 (화면 px)
const SHAKE_DECAY := 9.0  # 초당 감쇠 계수
const HITSTOP_MAX := 0.12  # 임팩트 프레임 상한 (초)
const SLIDE_TIME := 0.07  # 가로 한 칸 이동을 눈이 따라잡는 시간
const SPIN_SPEED := 16.0  # 회전 잔여 각도가 풀리는 속도 (rad/s)
const LAND_SQUASH_TIME := 0.22  # 착지 눌림이 펴지는 시간
const TRAIL_TIME := 0.22  # 낙하 잔상이 남는 시간
const DUST_TIME := 0.45
const SHARD_TIME := 0.7
const RING_TIME := 0.35
const ROW_FLASH_TIME := 0.3
const LOCK_FLASH_TIME := 0.16
const BANNER_TIME := 1.0
const FX_MAX := 200  # 먼지·파편 총량 상한 (웹 빌드 프레임 보호)

var grid := {}  # Vector2i -> piece type
var cracked := {}  # Vector2i -> true; first break hit cracks, second destroys
var ore := {}  # Vector2i -> true; 금이 박힌 칸 (grid와 나란히 간다)
var piece_ore := -1  # 지금 떨어지는 블록에서 금이 박힌 칸 번호 (-1 = 없음)
var ore_gold := 0  # 이 판에 골드 블록으로 번 골드
var ore_fx: Array = []  # [중심 좌표, 경과 시간, 값] — 금이 튀는 연출
var bag: Array = []
var piece_type := ""
var next_type := ""
var piece_rot := 0
var piece_pos := Vector2i.ZERO
var piece_state := PieceState.TRACKING
var track_timer := 0.0
var track_move_timer := 0.0
var fall_timer := 0.0
var land_timer := 0.0
var level := 1
var total_lines := 0
var run_time := 0.0  # seconds of active play this run — drives the speed creep
# Classic (arcade B-type): `level` is the board number. These track its line
# goal and the shutter sequence that closes it out.
enum Shutter { NONE, CLOSING, HOLD, OPENING }
var level_lines := 0  # lines banked toward this level's quota
var level_garbage := 0  # garbage rows this level started with (spawn sits above)
var shutter_phase: Shutter = Shutter.NONE
var shutter_row := 0  # rows of the well the curtain currently covers
var shutter_timer := 0.0
var shutter_bonus := 0  # empty-row payout tallied by the closing curtain
var shutter_bonus_done := false  # curtain reached the stack: no more empty rows
var shutter_pop := 0.0  # flare left on the tally after its latest tick
var playing := false
var is_paused := false
var break_fx: Array = []  # [cell: Vector2i, age: float]
var mode := Mode.CLASSIC
var rows := PIT_ROWS  # pit height in cells
## 무한의 계단 카메라 배율과, 그 배율에서 화면을 덮는 "카메라 아래로 더 그리는
## 거리". 스테이지 모드와 같은 크기의 우물을 쓰려고 start_game에서 정해진다.
var view_zoom := 1.0
var view_below := VIEW_BELOW
var best_height := 0
## 이 보드가 이번 판에 번 점수. 분할 화면은 보드마다 따로 세고(지갑 하나 원칙에
## 걸리는 GameState.score와 달리 좌석별 기록이 필요하다), 1인 플레이에서는
## GameState.score와 같은 값을 따라간다.
var run_score := 0
var drop_tap_time := -1e9
var lava_y := 0.0
var lava_phase := 0.0
# Endless: once its countdown ends a piece detaches and falls on its own (no
# more rotation), so the next piece starts tracking immediately. Each entry:
# {t: type, r: rot, p: pos, s: PieceState, ft: fall timer, lt: land timer}.
var loose: Array = []
# Replay recording: 10Hz state frames (cat + piece + score) plus grid-diff
# events, exported via rec_export().
const REC_STEP := 0.1
const REC_MAX_FRAMES := 6000  # ~10 minutes, then the recording just stops
const REC_STRIDE := 8
var rec_frames := PackedInt32Array()
var rec_events: Array = []
var _rec_shadow := {}
var _rec_timer := 0.0
var _rec_on := false

# --- 타격감 연출 상태 (`_fx_reset()`이 전부 비운다) ---------------------------
var base_pos := Vector2.ZERO  # 흔들림의 기준 자리 — main.gd `_fit_board()`가 물려 준다
var shake_amt := 0.0
var shake_t := 0.0
var hitstop := 0.0  # 이 시간 동안 판이 멎는다 (임팩트가 눈에 박히게)
var slide_off := 0.0  # 떨어지는 블록의 가로 잔여 오프셋 (칸 단위, 0으로 수렴)
var spin_off := 0.0  # 회전 잔여 각도 (rad, 0으로 수렴)
var spin_pop := 0.0  # 회전 직후의 테두리 섬광 (0..1)
var land_squash := 0.0  # 착지 눌림 (0..1)
var fall_from := 0  # 낙하를 시작한 줄 — 착지 세기 계산용
var hard_drop_rows := 0  # 이번 하드드롭이 훑고 내려온 줄 수
var trails: Array = []  # [cells, swept, color, age] — 낙하 잔상
var dust: Array = []  # [pos, vel, age, life, size, color]
var shards: Array = []  # [pos, vel, age, color, size, spin]
var rings: Array = []  # [pos, age, radius, color] — 착지 충격 링
var row_flash: Array = []  # [row_y, age] — 지워지는 줄의 섬광
var lock_flash: Array = []  # [cells, age, color] — 격자에 박히는 순간
var banner_key := ""  # 멀티 라인 배너 번역 키
var banner_age := BANNER_TIME
var banner_y := 0.0
var combo := 0  # 연속 줄 클리어 — 못 지운 락에서 끊긴다

# --- 골드러시 상태 (`_fx_reset()`이 전부 비운다) -------------------------------
var rush_gauge := 0.0  # 0 ~ RUSH_MAX
var rush_time := 0.0  # 남은 발동 시간 (0 = 꺼짐)
var rush_near := 0.0  # 발끝 세이브 근접도 0..1 — 용암 위 열기 연출에 쓴다
var rush_pop: Array = []  # 종료 폭발 대기열 (아래 칸부터)
var rush_pop_t := 0.0
var rush_flash := 0.0  # 발동 순간의 금빛 섬광 (초)

@onready var player: Player = $Player
@onready var cam: Camera2D = get_node_or_null("Cam")


func start_game() -> void:
	mode = GameState.mode as Mode
	rows = PIT_ROWS
	grid.clear()
	cracked.clear()
	ore.clear()
	ore_fx.clear()
	ore_gold = 0
	piece_ore = -1
	bag.clear()
	next_type = ""
	level = 1
	total_lines = 0
	run_time = 0.0
	level_lines = 0
	level_garbage = 0
	shutter_phase = Shutter.NONE
	shutter_bonus = 0
	shutter_pop = 0.0
	best_height = 0
	run_score = 0
	lava_y = rows * CELL + LAVA_START_OFFSET
	lava_phase = 0.0
	loose.clear()
	is_paused = false
	_fx_reset()
	GameState.reset()
	view_zoom = _fit_zoom() if mode == Mode.ENDLESS else 1.0
	view_below = VIEW_BELOW / view_zoom
	if cam:
		cam.enabled = mode == Mode.ENDLESS
		cam.zoom = Vector2(view_zoom, view_zoom)
		cam.position = Vector2(COLS * CELL / 2.0, rows * CELL / 2.0)
		cam.reset_smoothing()
	if mode == Mode.CLASSIC:
		# Arcade pit: clear the level's 10 lines and survive with the usual cat
		# controls. Each level is a fresh, harder board.
		_classic_setup_level(1)
	player.respawn(_spawn_point())
	player.visible = true  # a restart mid-shutter must not leave the cat hidden
	_spawn_piece()
	playing = true
	_rec_reset()
	EventBus.game_started.emit()
	EventBus.lines_changed.emit(0)
	EventBus.level_changed.emit(level)
	EventBus.height_changed.emit(0)
	if mode == Mode.CLASSIC:
		_classic_announce_level()
	queue_redraw()


## 점수 한 곳: 보드 자기 몫(run_score)에 쌓고, HUD·지갑이 읽는
## GameState.score에도 그대로 반영한다.
func _add_score(n: int) -> void:
	run_score += n
	GameState.score += n


## 골드 블록 한 칸이 사라졌다: 그 자리에서 금을 사방으로 튀기고 지갑에 바로 넣는다.
## 세이브는 판이 끝날 때 보상과 함께 한 번만 쓴다 — 깰 때마다 저장하면 디스크를
## 두드리게 된다(중간에 죽어도 지급은 결과 화면의 저장으로 확정된다).
func _bank_ore(c: Vector2i, value: int) -> void:
	if not ore.has(c):
		return
	ore.erase(c)
	ore_gold += value
	GameState.add_currency(value, false)
	var at := _cell_rect(c).get_center()
	ore_fx.append([at, 0.0, value])
	Sfx.play("gold", 1.05 + randf() * 0.15)
	EventBus.ore_collected.emit(value, at)


func _process(delta: float) -> void:
	if not playing or is_paused:
		return
	_update_shake(delta)
	_age_fx(delta)
	if hitstop > 0.0:
		# 임팩트 프레임: 판은 멎고 연출만 흐른다 — 한 방이 눈에 박히는 자리다.
		hitstop -= delta
		queue_redraw()
		return
	if _shutter_on():
		# Classic 레벨 클리어 연출: 셔터가 내려오는 동안 조작·낙하·판정 정지.
		_update_shutter(delta)
		shutter_pop = maxf(shutter_pop - delta / SHUTTER_POP_TIME, 0.0)
		queue_redraw()
		return
	run_time += delta  # only ticks while the board is actually being played
	if Input.is_action_just_pressed("rotate_cw"):
		_try_rotate(1)
	if Input.is_action_just_pressed("rotate_ccw"):
		_try_rotate(-1)
	if piece_type != "":
		match piece_state:
			PieceState.TRACKING:
				_track(delta)
			PieceState.FALLING:
				_fall(delta)
			PieceState.LANDED:
				_landed(delta)
	if mode == Mode.ENDLESS and playing:
		_step_loose(delta)
	_rec_tick(delta)
	if mode == Mode.ENDLESS:
		_update_endless(delta)
	queue_redraw()


## 무한의 계단도 스테이지 모드와 같은 크기의 우물에서 논다. 고정 우물 모드는
## 보드 노드를 화면에 맞춰 줄이지만(main.gd `_fit_board()`), 무한은 카메라가
## 그리므로 같은 배율을 카메라 줌으로 준다.
# --- 타격감 엔진 ---------------------------------------------------------------


## 판을 새로 깔 때 연출 상태를 전부 비운다 — 흔들려 있던 자리도 제자리로.
func _fx_reset() -> void:
	shake_amt = 0.0
	shake_t = 0.0
	hitstop = 0.0
	slide_off = 0.0
	spin_off = 0.0
	spin_pop = 0.0
	land_squash = 0.0
	fall_from = 0
	hard_drop_rows = 0
	combo = 0
	rush_gauge = 0.0
	rush_time = 0.0
	rush_near = 0.0
	rush_pop.clear()
	rush_pop_t = 0.0
	rush_flash = 0.0
	banner_key = ""
	banner_age = BANNER_TIME
	trails.clear()
	dust.clear()
	shards.clear()
	rings.clear()
	row_flash.clear()
	lock_flash.clear()
	if cam:
		cam.offset = Vector2.ZERO
	if base_pos != Vector2.ZERO:
		position = base_pos


## 연출 타이머 한 곳. 임팩트 프레임·셔터 연출 중에도 계속 돌아간다.
func _age_fx(delta: float) -> void:
	for fx in break_fx:
		fx[1] += delta
	break_fx = break_fx.filter(func(fx: Array) -> bool: return fx[1] < BREAK_FX_TIME)
	_age_ore_fx(delta)
	slide_off = move_toward(slide_off, 0.0, delta / SLIDE_TIME)
	spin_off = move_toward(spin_off, 0.0, delta * SPIN_SPEED)
	spin_pop = maxf(spin_pop - delta * 7.0, 0.0)
	land_squash = maxf(land_squash - delta / LAND_SQUASH_TIME, 0.0)
	for e in trails:
		e[3] += delta
	trails = trails.filter(func(e: Array) -> bool: return e[3] < TRAIL_TIME)
	for e in lock_flash:
		e[1] += delta
	lock_flash = lock_flash.filter(func(e: Array) -> bool: return e[1] < LOCK_FLASH_TIME)
	for e in rings:
		e[1] += delta
	rings = rings.filter(func(e: Array) -> bool: return e[1] < RING_TIME)
	for e in row_flash:
		e[1] += delta
	row_flash = row_flash.filter(func(e: Array) -> bool: return e[1] < ROW_FLASH_TIME)
	for d in dust:
		d[2] += delta
		d[1] = (d[1] as Vector2) * maxf(1.0 - delta * 3.2, 0.0) + Vector2(0.0, 220.0 * delta)
		d[0] = (d[0] as Vector2) + (d[1] as Vector2) * delta
	dust = dust.filter(func(d: Array) -> bool: return d[2] < d[3])
	for sh in shards:
		sh[2] += delta
		sh[1] = (sh[1] as Vector2) + Vector2(0.0, 1500.0 * delta)
		sh[0] = (sh[0] as Vector2) + (sh[1] as Vector2) * delta
		sh[5] += delta * 9.0
	shards = shards.filter(func(sh: Array) -> bool: return sh[2] < SHARD_TIME)
	banner_age = minf(banner_age + delta, BANNER_TIME)
	if banner_age >= BANNER_TIME:
		banner_key = ""


## 화면 흔들림 한 곳. 고정 우물은 보드 노드를 base_pos 기준으로 흔들고, 무한의
## 계단은 카메라 오프셋을 민다 — 카메라 줌으로 나눠 화면 픽셀 진폭을 맞춘다.
func _update_shake(delta: float) -> void:
	if shake_amt <= 0.01:
		if shake_amt != 0.0:
			shake_amt = 0.0
			if cam and cam.enabled:
				cam.offset = Vector2.ZERO
			elif base_pos != Vector2.ZERO:
				position = base_pos
		return
	shake_t += delta
	var off := Vector2(
			sin(shake_t * 61.0) + 0.5 * sin(shake_t * 113.0),
			cos(shake_t * 47.0) + 0.5 * sin(shake_t * 89.0)) * shake_amt * 0.55
	if cam and cam.enabled:
		cam.offset = off / maxf(view_zoom, 0.05)
	elif base_pos != Vector2.ZERO:
		position = base_pos + off
	shake_amt = maxf(shake_amt - shake_amt * SHAKE_DECAY * delta - 14.0 * delta, 0.0)


## 흔들림을 얹는다 — 겹치면 큰 쪽이 이긴다(연달아 터져도 화면이 폭주하지 않게).
func shake(amount: float) -> void:
	shake_amt = minf(maxf(shake_amt, amount), SHAKE_MAX)


## 임팩트 프레임(히트스톱). 같은 이유로 겹치면 긴 쪽이 이긴다.
func _freeze(t: float) -> void:
	hitstop = minf(maxf(hitstop, t), HITSTOP_MAX)


## 착지·파괴 자리에서 먼지가 좌우로 퍼진다.
func _spawn_dust(at: Vector2, n: int, power: float,
		col := Color(1.0, 0.96, 0.86)) -> void:
	if dust.size() > FX_MAX:
		return
	for i in n:
		var ang := -PI * (0.15 + 0.7 * randf())
		var sp := (140.0 + 300.0 * randf()) * power
		dust.append([
			at + Vector2(randf_range(-CELL * 0.4, CELL * 0.4), 0.0),
			Vector2(cos(ang) * sp * 1.7, sin(ang) * sp * 0.55),
			0.0, DUST_TIME * (0.6 + 0.6 * randf()),
			CELL * (0.05 + 0.10 * randf()), col])


## 부서진 블록 파편: 제 색을 물고 사방으로 튄 뒤 중력에 진다.
func _spawn_shards(at: Vector2, col: Color, n: int, power := 1.0) -> void:
	if shards.size() > FX_MAX:
		return
	for i in n:
		var ang := randf() * TAU
		var sp := (180.0 + 400.0 * randf()) * power
		shards.append([at, Vector2(cos(ang) * sp * 1.3, sin(ang) * sp - 260.0), 0.0,
				col, CELL * (0.09 + 0.13 * randf()), randf() * TAU])


## 블록이 스택/바닥에 닿았다: 눌림 + 흔들림 + 충격 링 + 먼지. 세기(power)는
## 얼마나 멀리서 떨어졌는가로, 하드드롭이 가장 세다.
func _impact(cells: Array, col: Color, power: float) -> void:
	land_squash = clampf(power, 0.2, 1.0)
	shake(4.0 + 15.0 * power)
	_freeze(0.015 + 0.05 * power)
	GameState.haptic(0.22 + 0.55 * power, 0.05 + 0.09 * power)
	Sfx.play("impact", 1.15 - 0.3 * power, -9.0 + 8.0 * power)
	# 블록의 아랫변마다 먼지가 일고, 그 가운데에 납작한 충격 링이 퍼진다.
	var low := {}
	for c: Vector2i in cells:
		if not low.has(c.x) or c.y > low[c.x]:
			low[c.x] = c.y
	if low.is_empty():
		return
	var mid := Vector2.ZERO
	for cx in low:
		var at := _cell_rect(Vector2i(cx, low[cx])).get_center() + Vector2(0.0, CELL * 0.5)
		_spawn_dust(at, 3 + int(4.0 * power), 0.5 + power)
		mid += at
	mid /= float(low.size())
	rings.append([mid, 0.0, CELL * (0.6 + 1.5 * power), col.lerp(Color.WHITE, 0.6)])
	# 가까이서 박히면 고양이도 함께 튄다 — 멀면 화면 흔들림만 남는다.
	if player and player.alive:
		var near := clampf(1.0 - player.position.distance_to(mid) / (CELL * 5.0), 0.0, 1.0)
		if near > 0.0:
			player.shock(power * near)


## 낙하 잔상: 지나온 자리에 블록 색 띠를 남긴다 (swept = 훑고 온 줄 수).
func _push_trail(swept: int, strength: float) -> void:
	if piece_type == "" or swept <= 0 or trails.size() > 24:
		return
	trails.append([_cells(piece_type, piece_rot, piece_pos), swept,
			Color(Board.COLORS[piece_type], strength), 0.0])


## 대시로 블록을 밀어냈다 — 미끄러진 만큼 잔상을 남기고 짧게 멎는다.
func _shove_impact() -> void:
	slide_off = clampf(slide_off, -2.5, 2.5)
	shake(7.0)
	_freeze(0.035)
	GameState.haptic(0.4, 0.06)
	var cells := _cells(piece_type, piece_rot, piece_pos) if piece_type != "" else []
	if not cells.is_empty():
		_spawn_dust(_cell_rect(cells[0]).get_center(), 5, 0.8)


## 줄이 지워진 순간의 타격 — 지운 줄 수만큼 크게 흔들리고 잠깐 멎는다.
func _line_clear_fx(cleared: int) -> void:
	shake(9.0 + 6.0 * cleared)
	_freeze(0.05 + 0.03 * cleared)
	GameState.haptic(clampf(0.45 + 0.16 * cleared, 0.0, 1.0), 0.1 + 0.05 * cleared)
	banner_age = 0.0
	banner_key = "FX_LINE_%d" % cleared if cleared >= 2 else ""
	if combo >= 2:
		Sfx.play("combo", clampf(0.85 + 0.09 * combo, 0.85, 1.9))


## 고양이 머리 바로 위에서 내려오는 블록이 얼마나 가까운가 (0 = 없음, 1 = 코앞).
## player.gd가 이 값으로 움츠린 자세와 놀란 표정을 고른다. 추적 중(TRACKING)인
## 블록은 아직 매달려 있을 뿐이라 절반만 세고, 떨어지는 중이면 제값을 센다.
func overhead_threat(r: Rect2) -> float:
	var worst := 0.0
	var groups: Array = []
	if piece_type != "" and piece_state != PieceState.LANDED:
		groups.append([_cells(piece_type, piece_rot, piece_pos),
				0.5 if piece_state == PieceState.TRACKING else 1.0])
	for e: Dictionary in loose:
		if e.s != PieceState.LANDED:
			groups.append([_loose_cells(e), 1.0])
	for g: Array in groups:
		for c: Vector2i in g[0]:
			var cr := _cell_rect(c)
			if cr.end.x <= r.position.x or cr.position.x >= r.end.x:
				continue  # 머리 위가 아니다
			var gap := r.position.y - cr.end.y
			if gap < 0.0:
				continue  # 이미 옆·아래다
			worst = maxf(worst, (1.0 - clampf(gap / (CELL * 5.0), 0.0, 1.0)) * g[1])
	return worst


## 플레이어가 쿵 하고 내려앉은 자리에 먼지가 인다 (player.gd가 부른다).
func land_dust(at: Vector2, power: float) -> void:
	_spawn_dust(at, 3 + int(5.0 * power), 0.4 + 0.7 * power)
	if power > 0.7:
		shake(3.0 * power)


func _fit_zoom() -> float:
	var vp := get_viewport_rect().size
	var portrait := vp.y > vp.x
	var top := 200.0 if portrait else 40.0
	var bottom := 1410.0 if portrait else vp.y - 56.0
	return minf(1.0, (bottom - top) / (PIT_ROWS * CELL))


func _update_endless(delta: float) -> void:
	if not playing or cam == null:
		return
	# Camera follows the player both ways: rises with the climb, and scrolls
	# back down when they drop into a hole. Never sinks past the start view.
	# The player sits at ~1/3 from the bottom of the *usable* area — portrait
	# screens reserve the bottom ~490px for the touch controls, so the cat
	# rides higher there instead of hiding under the buttons.
	var vp := get_viewport_rect().size
	var usable := vp.y - 490.0 if vp.y > vp.x else vp.y
	# 화면 픽셀 거리를 카메라 줌으로 나눠 월드 거리로 바꾼다 — 줌이 1이 아니다.
	var cam_offset := (usable / 1.5 - vp.y / 2.0) / view_zoom  # cat screen y = usable * 2/3
	# Camera floor: at run start the pit bottom sits just above the screen
	# bottom (landscape) / the touch zone (portrait), never behind them.
	var bottom_sy := vp.y - 60.0 if vp.x > vp.y else vp.y - 540.0
	var cam_floor := rows * CELL - (bottom_sy - vp.y / 2.0) / view_zoom
	cam.position.y = minf(player.position.y - cam_offset, cam_floor)
	# Lava creeps up from below; it also keeps pace with the player so a
	# fast climber can never leave it arbitrarily far behind.
	lava_phase += delta
	# 골드러시가 도는 동안 용암은 멎는다 — 10초짜리 숨통이자, 낮게 파고들어 금을
	# 캘 수 있는 유일한 창이다. (낙하 속도는 건드리지 않는다: 느려지면 긴장이
	# 죽고, 빨라지면 벌 수가 없다.)
	if not rush_on():
		lava_y -= _lava_speed() * delta
	lava_y = minf(lava_y, player.position.y + LAVA_MAX_GAP)
	var feet := player.position.y + Player.SIZE / 2.0
	if feet > lava_y:
		_kill_player()
		return
	_rush_step(delta, feet)
	var h := int(round((rows * CELL - feet) / CELL))
	if h > best_height:
		_add_score((h - best_height) * HEIGHT_SCORE)
		best_height = h
		EventBus.height_changed.emit(best_height)


func rect_hits_solid(r: Rect2) -> bool:
	if _rect_hits_bounds(r):
		return true
	var x0 := int(floor(r.position.x / CELL))
	var x1 := int(floor((r.end.x - 0.01) / CELL))
	var y0 := int(floor(r.position.y / CELL))
	var y1 := int(floor((r.end.y - 0.01) / CELL))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if grid.has(Vector2i(x, y)):
				return true
	return false


## Walls, floor and (outside endless) ceiling — the pit boundary alone.
func _rect_hits_bounds(r: Rect2) -> bool:
	if r.position.x < 0.0 or r.end.x > COLS * CELL:
		return true
	if r.end.y > rows * CELL:
		return true
	if mode != Mode.ENDLESS and r.position.y < 0.0:
		return true
	return false


## What the player collides with: locked grid, walls, and the falling piece.
## The falling piece is a solid body — the player can never pass through it.
func rect_blocked_for_player(r: Rect2) -> bool:
	return rect_hits_solid(r) or piece_hits_rect(r)


func piece_hits_rect(r: Rect2) -> bool:
	if piece_state != PieceState.TRACKING and piece_type != "":
		for c in _cells(piece_type, piece_rot, piece_pos):
			if _cell_rect(c).intersects(r):
				return true
	for e: Dictionary in loose:
		for c: Vector2i in _loose_cells(e):
			if _cell_rect(c).intersects(r):
				return true
	return false


func _track(delta: float) -> void:
	if Input.is_action_just_pressed("soft_drop"):
		drop_tap_time = Time.get_ticks_msec() / 1000.0
		_release_piece()
		return
	track_timer += delta
	track_move_timer += delta
	if mode == Mode.ENDLESS:
		piece_pos.y = _endless_spawn_row()
	while track_move_timer >= TRACK_STEP:
		track_move_timer -= TRACK_STEP
		var target := _track_target()
		var dir := signi(target - piece_pos.x)
		if dir != 0 and not _piece_collides(piece_rot, piece_pos + Vector2i(dir, 0), true):
			piece_pos.x += dir
			# 눈은 한 박자 늦게 따라온다 — 칸 단위 이동이 미끄러지듯 보이게.
			slide_off = clampf(slide_off - float(dir), -1.5, 1.5)
	if track_timer >= _track_time():
		_release_piece()


## Origin column the tracking piece steers toward. The default "-2" centers
## the 4-wide spawn box on the cat, but shapes/rotations whose occupied cells
## sit inside the box (vertical I = one column, rotated T/S/O = two) would
## then stop short of a wall-hugging cat. Clamp the target so the piece keeps
## sliding until its real footprint covers the cat's column.
func _track_target() -> int:
	var min_dx := 3
	var max_dx := 0
	for c: Vector2i in Board.SHAPES[piece_type][piece_rot]:
		min_dx = mini(min_dx, c.x)
		max_dx = maxi(max_dx, c.x)
	var pcol := int(player.position.x / CELL)
	return clampi(pcol - 2, pcol - max_dx, pcol - min_dx)


## The countdown ended (or the drop key sent the piece down). Endless detaches
## the piece into [member loose] so the next one starts tracking immediately;
## every other mode keeps the classic one-piece fall.
func _release_piece() -> void:
	if mode == Mode.ENDLESS:
		_detach_piece()
	else:
		_start_fall()


## Endless: the tracked piece lets go and free-falls on its own — locked out
## of rotation from here — while the next piece appears at the top right away.
func _detach_piece() -> void:
	if _piece_collides(piece_rot, piece_pos, false):
		_kill_player()  # true block out: the locked stack reached the spawn row
		return
	if _cells_hit_loose(_cells(piece_type, piece_rot, piece_pos), -1):
		return  # the previous piece still fills this lane — try again next frame
	loose.append({"t": piece_type, "r": piece_rot, "p": piece_pos,
			"s": PieceState.FALLING, "ft": 0.0, "lt": 0.0, "o": piece_ore})
	if _resolve_loose_overlap(loose.size() - 1) or not playing:
		return
	_spawn_piece()


func _loose_cells(e: Dictionary) -> Array:
	return _cells(e.t, e.r, e.p)


## Any of the given cells occupied by a loose piece (other than #exclude)?
func _cells_hit_loose(cells: Array, exclude: int) -> bool:
	for i in loose.size():
		if i == exclude:
			continue
		for c: Vector2i in _loose_cells(loose[i]):
			if c in cells:
				return true
	return false


## Cells one step in the given direction hit a wall, the grid or another
## loose piece. dir (0,1) = falling, (±1,0) = shove.
func _loose_blocked(i: int, dir: Vector2i) -> bool:
	var e: Dictionary = loose[i]
	var moved: Array = _cells(e.t, e.r, e.p + dir)
	for c: Vector2i in moved:
		if c.x < 0 or c.x >= COLS or c.y >= rows or grid.has(c):
			return true
	return _cells_hit_loose(moved, i)


## Steps every detached piece: fall, land into the shovable grace, lock.
## Oldest (lowest) pieces step first so mid-air stacks settle bottom-up.
func _step_loose(delta: float) -> void:
	var interval := _fall_interval()
	if Input.is_action_pressed("soft_drop"):
		interval /= SOFT_DROP_FACTOR
	var i := 0
	while i < loose.size():
		var e: Dictionary = loose[i]
		if e.s == PieceState.FALLING:
			e.ft += delta
			while e.ft >= interval and playing:
				e.ft -= interval
				if _loose_blocked(i, Vector2i(0, 1)):
					e.s = PieceState.LANDED
					e.lt = 0.0
					_impact(_loose_cells(e), Board.COLORS[e.t], 0.55)
					break
				e.p += Vector2i(0, 1)
				if _resolve_loose_overlap(i) or not playing:
					return
		elif e.s == PieceState.LANDED:
			if not _loose_blocked(i, Vector2i(0, 1)):
				# Shoved off a ledge (or the floor cleared): fall again.
				e.s = PieceState.FALLING
				e.ft = 0.0
			else:
				e.lt += delta
				if e.lt >= LOCK_GRACE:
					loose.remove_at(i)
					_merge_piece(e.t, e.r, e.p, int(e.get("o", -1)))
					if not playing:
						return
					continue
		i += 1


## Endless dash: shoves whichever detached piece the cat slammed into.
func _shove_loose(dir: int, max_cells: int) -> bool:
	var probe := player.rect()
	probe.position.x += dir * CELL * 0.75
	var target := -1
	for i in loose.size():
		for c: Vector2i in _loose_cells(loose[i]):
			if _cell_rect(c).intersects(probe):
				target = i
				break
		if target >= 0:
			break
	if target < 0:
		return false
	var e: Dictionary = loose[target]
	var moved := false
	var cells := 0
	while cells < max_cells and not _loose_blocked(target, Vector2i(dir, 0)):
		e.p += Vector2i(dir, 0)
		moved = true
		cells += 1
		if _resolve_loose_overlap(target) or not playing:
			break
	if moved:
		Sfx.play("shove")
	return moved


func _start_fall() -> void:
	piece_state = PieceState.FALLING
	fall_timer = 0.0
	fall_from = piece_pos.y
	hard_drop_rows = 0
	# Classic Tetris block out: the stack reaches the spawn area and the
	# piece has nowhere to start falling.
	if _piece_collides(piece_rot, piece_pos, false):
		_kill_player()
		return
	_resolve_piece_overlap()


func _fall(delta: float) -> void:
	# Double-tap soft drop slams the piece all the way down.
	if Input.is_action_just_pressed("soft_drop"):
		var now := Time.get_ticks_msec() / 1000.0
		if now - drop_tap_time <= DROP_DOUBLE_TAP:
			drop_tap_time = -1e9
			_hard_drop()
			return
		drop_tap_time = now
	fall_timer += delta
	var interval := _fall_interval()
	if Input.is_action_pressed("soft_drop"):
		interval /= SOFT_DROP_FACTOR
	while fall_timer >= interval and playing:
		fall_timer -= interval
		if _piece_collides(piece_rot, piece_pos + Vector2i(0, 1), false):
			_land()
			return
		piece_pos.y += 1
		if Input.is_action_pressed("soft_drop"):
			_push_trail(1, 0.5)  # 빠르게 내려올 때만 자국이 남는다
		if _resolve_piece_overlap():
			return


## Touched down: hold briefly in a shovable state before locking for real.
func _land() -> void:
	var was := piece_state
	piece_state = PieceState.LANDED
	land_timer = 0.0
	if was == PieceState.LANDED or piece_type == "":
		return
	# 멀리서 떨어질수록, 하드드롭일수록 세게 박힌다.
	var fallen := maxi(hard_drop_rows, piece_pos.y - fall_from)
	var power := clampf(0.25 + fallen / 16.0, 0.25, 1.0)
	if hard_drop_rows > 0:
		power = minf(power * 1.5, 1.0)
	_impact(_cells(piece_type, piece_rot, piece_pos), Board.COLORS[piece_type], power)
	hard_drop_rows = 0


func _landed(delta: float) -> void:
	# Shoved off a ledge (or the ground cleared): resume falling.
	if not _piece_collides(piece_rot, piece_pos + Vector2i(0, 1), false):
		piece_state = PieceState.FALLING
		fall_timer = 0.0
		fall_from = piece_pos.y
		return
	# Tapping down locks it in place immediately.
	if Input.is_action_just_pressed("soft_drop"):
		_lock_piece()
		return
	land_timer += delta
	if land_timer >= LOCK_GRACE:
		_lock_piece()


## Dash impact from the player shoves the piece sideways up to max_cells
## (the cat's push stat; default slams to the wall or the nearest locked
## block). Works while falling and during the landed grace window.
func shove_piece(dir: int, max_cells: int = COLS) -> bool:
	if not loose.is_empty() and _shove_loose(dir, max_cells):
		return true
	if piece_state == PieceState.TRACKING or piece_type == "":
		return false
	var moved := false
	var cells := 0
	while cells < max_cells \
			and not _piece_collides(piece_rot, piece_pos + Vector2i(dir, 0), false):
		piece_pos.x += dir
		moved = true
		cells += 1
		slide_off = clampf(slide_off - float(dir), -2.5, 2.5)
		if _resolve_piece_overlap() or not playing:
			Sfx.play("shove")
			_shove_impact()
			return true
	if moved:
		Sfx.play("shove")
		_shove_impact()
	return moved


func _hard_drop() -> void:
	var from_y := piece_pos.y
	while playing and not _piece_collides(piece_rot, piece_pos + Vector2i(0, 1), false):
		piece_pos.y += 1
		if _resolve_piece_overlap():
			return
	if playing:
		hard_drop_rows = piece_pos.y - from_y
		if hard_drop_rows > 0:
			_push_trail(hard_drop_rows, 0.6)
			Sfx.play("harddrop")
		_land()


## The falling piece overlaps the player: drive them straight down with it,
## sideways only as a last resort. Death only when truly pinned — crushed.
func _resolve_piece_overlap() -> bool:
	return _resolve_overlap_cells(_cells(piece_type, piece_rot, piece_pos))


func _resolve_loose_overlap(i: int) -> bool:
	return _resolve_overlap_cells(_loose_cells(loose[i]))


func _resolve_overlap_cells(piece_cells: Array) -> bool:
	var pr := player.rect().grow(-CRUSH_MARGIN)
	var cell_rects: Array = []
	var overlapping: Array = []
	for c in piece_cells:
		var r := _cell_rect(c)
		cell_rects.append(r)
		if r.intersects(pr):
			overlapping.append(r)
	if overlapping.is_empty():
		return false
	var full := player.rect()
	var d_down := 0.0
	var d_left := 0.0
	var d_right := 0.0
	for r in overlapping:
		d_down = maxf(d_down, r.end.y - full.position.y)
		d_left = maxf(d_left, full.end.x - r.position.x)
		d_right = maxf(d_right, r.end.x - full.position.x)
	var sides := [
		[Vector2(-(d_left + 1.0), 0.0), d_left],
		[Vector2(d_right + 1.0, 0.0), d_right],
	]
	sides.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
	# Down always wins: a descending block shoves the player beneath it.
	var candidates := [[Vector2(0.0, d_down + 1.0), d_down, CELL * 1.6]]
	for s in sides:
		candidates.append([s[0], s[1], CELL])
	for cand in candidates:
		if cand[1] > cand[2]:
			continue
		var moved := Rect2(full.position + cand[0], full.size)
		if rect_hits_solid(moved):
			continue
		var still_overlaps := false
		for r in cell_rects:
			if r.intersects(moved.grow(-CRUSH_MARGIN)):
				still_overlaps = true
				break
		if still_overlaps:
			continue
		player.position += cand[0]
		if cand[0].y > 0.0:
			# Carry the piece's fall speed so the player is driven downward.
			player.velocity.y = maxf(player.velocity.y, CELL / _fall_interval())
			player.on_floor = false
		return false
	_kill_player()
	return true


func _lock_piece() -> void:
	if _merge_piece(piece_type, piece_rot, piece_pos, piece_ore):
		_spawn_piece()


## Locks a piece's cells into the grid: overflow, line clears and scoring.
## Serves both the active piece and detached (loose) endless pieces. Returns
## false when the game ended — or a rescue already spawned the next piece —
## and the caller must not spawn another.
func _merge_piece(t: String, r: int, pos: Vector2i, ore_idx := -1) -> bool:
	var overflow := false
	var cells := _cells(t, r, pos)
	for i in cells.size():
		var c: Vector2i = cells[i]
		grid[c] = t
		cracked.erase(c)
		if i == ore_idx:
			ore[c] = true
		else:
			ore.erase(c)
		if c.y < 0:
			overflow = true
	if overflow and mode != Mode.ENDLESS:
		# Stack spilled over the top: the cat is buried.
		_kill_player()
		return false
	if not _free_player_from_grid():
		return false
	Sfx.play("lock")
	lock_flash.append([cells, 0.0, Board.COLORS[t]])
	shake(2.5)
	_add_score(10 * level)
	var cleared := _clear_lines()
	if cleared == 0:
		combo = 0
	else:
		combo += 1
		_line_clear_fx(cleared)
	if cleared > 0:
		total_lines += cleared
		# Classic pays the arcade table (40/100/300/1200 × stage, pre-level-up).
		var table: Array = Board.CLASSIC_SCORES if mode == Mode.CLASSIC else LINE_SCORES
		_add_score(table[cleared] * level)
		Sfx.play("clear", 1.0 + 0.07 * (cleared - 1))
		if mode == Mode.ENDLESS:
			_endless_line_reward(cleared)
		elif mode == Mode.CLASSIC:
			_classic_line_progress(cleared)
		EventBus.lines_changed.emit(total_lines)
		if _shutter_on():
			return true  # 레벨 클리어 연출 중: 깔림 판정 없이 셔터가 내려온다
		if not _free_player_from_grid():
			return false
	return true


# --- 골드러시 -------------------------------------------------------------------


## 지금 골드러시가 돌고 있는가 (계기판·금 확률·용암 정지가 이 값을 본다).
func rush_on() -> bool:
	return rush_time > 0.0


## 게이지 충전. 무한의 계단에서, 러시가 돌고 있지 않을 때만 찬다 — 가만히 있어서
## 차는 길은 어디에도 없다.
func _rush_gain(amount: float) -> void:
	if mode != Mode.ENDLESS or not playing or rush_on() or amount <= 0.0:
		return
	if not rush_pop.is_empty():
		return  # 종료 폭발이 자기 게이지를 다시 채우면 러시가 끊기지 않는다
	rush_gauge = minf(rush_gauge + amount, RUSH_MAX)
	EventBus.goldrush_changed.emit(rush_gauge / RUSH_MAX, 0.0)
	if rush_gauge >= RUSH_MAX:
		_rush_start()


## 발동: 용암을 한 번 크게 밀어내고 10초간 금이 쏟아진다.
func _rush_start() -> void:
	rush_gauge = 0.0
	rush_time = RUSH_TIME
	rush_flash = RUSH_FLASH_TIME
	lava_y += RUSH_LAVA_PUSH * CELL
	shake(16.0)
	_freeze(0.08)
	GameState.haptic(0.9, 0.25)
	banner_key = "FX_GOLDRUSH"
	banner_age = 0.0
	banner_y = player.position.y - CELL * 1.6 if player else rows * CELL * 0.4
	Sfx.play("goldrush")
	EventBus.goldrush_changed.emit(0.0, rush_time)


## 매 프레임: 남은 시간을 깎고, 발끝 세이브를 재고, 종료 폭발을 흘린다.
func _rush_step(delta: float, feet: float) -> void:
	rush_flash = maxf(rush_flash - delta, 0.0)
	# 발끝 세이브 — 용암에 바짝 붙어 있는 동안만 게이지가 찬다. 안전하게만
	# 올라가면 러시는 영영 안 터진다: 위험을 감수할 이유를 만드는 자리다.
	var gap := lava_y - feet
	rush_near = clampf(1.0 - gap / RUSH_NEAR_DIST, 0.0, 1.0) if gap > 0.0 else 0.0
	if rush_near > 0.0:
		_rush_gain(RUSH_NEAR_GAIN * delta)
	if rush_on():
		rush_time = maxf(rush_time - delta, 0.0)
		EventBus.goldrush_changed.emit(0.0, rush_time)
		if rush_time <= 0.0:
			_rush_end()
	_rush_pop_step(delta)


## 종료: 필드에 남은 금을 아래에서부터 한 칸씩 터뜨린다. 러시 중에 캐지 않고
## 쌓아 둔 금이 여기서 한꺼번에 돌아오는 것이 이 연출의 전부다.
func _rush_end() -> void:
	rush_pop = ore.keys()
	rush_pop.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y)
	rush_pop_t = 0.0
	rush_near = 0.0
	EventBus.goldrush_changed.emit(0.0, 0.0)


func _rush_pop_step(delta: float) -> void:
	if rush_pop.is_empty():
		return
	rush_pop_t -= delta
	while rush_pop_t <= 0.0 and not rush_pop.is_empty():
		rush_pop_t += RUSH_POP_STEP
		_bank_ore(rush_pop.pop_front() as Vector2i, ORE_VALUE)
		shake(3.0)


## Endless: line clears fight the lava — every clear shoves it back down,
## scaling steeply with multi-line clears.
## Height itself is never lost: _clear_lines leaves gaps instead of collapsing.
func _endless_line_reward(cleared: int) -> void:
	lava_y += LAVA_PUSH[cleared] * CELL
	# 줄 클리어가 골드러시 게이지의 주 수입원이다 — 4줄 한 방이면 절반이 넘는다.
	_rush_gain(RUSH_LINE_GAIN[cleared] + RUSH_COMBO_GAIN * float(maxi(combo - 1, 0)))


# --- Classic level (arcade B-type) ------------------------------------------------


## Deals the board for level `n`: bare field plus its garbage floor. Does not
## touch the player or the piece — callers follow with respawn/_spawn_piece.
func _classic_setup_level(n: int) -> void:
	level = n
	level_lines = 0
	level_garbage = Board.classic_garbage(n)
	grid.clear()
	cracked.clear()
	ore.clear()
	loose.clear()
	piece_type = ""
	_fill_garbage(level_garbage)


## Tells the HUD which board is up (start of run and every new level).
func _classic_announce_level() -> void:
	EventBus.classic_level_started.emit(level, Board.classic_quota(level), level_garbage)
	EventBus.classic_level_progress.emit(level_lines, Board.classic_quota(level))
	EventBus.level_changed.emit(level)


## Game Boy Type-B style garbage: `count` rows of debris on the floor, each
## with a hole or two so no row is already complete and the holes never stack
## into one free column.
func _fill_garbage(count: int) -> void:
	if count <= 0:
		return
	var hole := randi() % COLS
	for i in range(count):
		var y := rows - 1 - i
		# Walk the hole sideways every row: no straight chimney, no full line.
		hole = (hole + 1 + randi() % (COLS - 1)) % COLS
		var holes := {hole: true}
		if i % 3 == 2:  # deeper rows occasionally get a second gap to dig into
			holes[(hole + 2 + randi() % (COLS - 3)) % COLS] = true
		var solid: Array = []
		for x in range(COLS):
			if holes.has(x):
				continue
			grid[Vector2i(x, y)] = Board.PIECES[randi() % Board.PIECES.size()]
			solid.append(x)
		# 파묻힌 금: 방해 블록을 파고들 이유를 하나 준다.
		if not solid.is_empty() and randf() < ORE_GARBAGE_CHANCE:
			ore[Vector2i(solid[randi() % solid.size()], y)] = true


## A clear landed in classic: bank it toward this level's 10 lines. Meeting the
## quota rolls the shutter down and closes the board out.
func _classic_line_progress(cleared: int) -> void:
	level_lines += cleared
	var quota := Board.classic_quota(level)
	EventBus.classic_level_progress.emit(mini(level_lines, quota), quota)
	if level_lines >= quota:
		_classic_start_shutter()


## True while the level-clear curtain owns the board: no input, no gravity,
## no crush checks.
func _shutter_on() -> bool:
	return shutter_phase != Shutter.NONE


## Test affordance: clear the current level on the spot. The shutter runs its
## normal course, so the empty-row bonus still reflects how the board stands.
func classic_skip_level() -> bool:
	if mode != Mode.CLASSIC or not playing or is_paused or _shutter_on():
		return false
	level_lines = Board.classic_quota(level)
	EventBus.classic_level_progress.emit(level_lines, level_lines)
	_classic_start_shutter()
	return true


## Quota met: freeze play and start rolling the shutter down.
func _classic_start_shutter() -> void:
	shutter_phase = Shutter.CLOSING
	shutter_row = 0
	shutter_timer = 0.0
	shutter_bonus = 0
	shutter_bonus_done = false
	piece_type = ""  # the tracking piece bows out
	loose.clear()
	Sfx.play("shutter")
	queue_redraw()


## Shutter tick. CLOSING pays the empty-row bonus row by row on the way down,
## HOLD deals the next board behind the curtain, OPENING reveals it and hands
## control back to the player.
func _update_shutter(delta: float) -> void:
	if player:
		# The cat disappears behind the curtain as it passes, and is revealed
		# again on the way up.
		player.visible = shutter_row * CELL < player.position.y - Player.SIZE / 2.0
	shutter_timer -= delta
	if shutter_timer > 0.0:
		return
	match shutter_phase:
		Shutter.CLOSING:
			# The curtain only comes down as far as the stack: it stops on the
			# first row holding a block, so how far it travels is exactly what
			# the level pays out.
			if not _shutter_pay_row(shutter_row):
				_classic_shutter_landed()
				queue_redraw()
				return
			shutter_timer = SHUTTER_CLOSE_STEP
			shutter_row += 1
			if shutter_row > rows:  # swept a bare well, ceiling to floor
				_classic_shutter_landed()
		Shutter.HOLD:
			shutter_phase = Shutter.OPENING
			shutter_timer = SHUTTER_OPEN_STEP
			Sfx.play("shutter", 1.3)
		Shutter.OPENING:
			shutter_timer = SHUTTER_OPEN_STEP
			shutter_row -= 1
			if shutter_row <= 0:
				shutter_row = 0
				shutter_phase = Shutter.NONE
				if player:
					player.visible = true
	queue_redraw()


## Atari B-type payout: every empty row at the top of the well is worth
## CLASSIC_EMPTY_ROW_BONUS × level as the curtain passes it. Returns false when
## the row is blocked (or the well is exhausted) — that's where the curtain
## stops, so a low stack pays more and closes faster.
func _shutter_pay_row(y: int) -> bool:
	if y >= rows:
		return false
	for x in range(COLS):
		if grid.has(Vector2i(x, y)):
			shutter_bonus_done = true
			return false
	var pay := Board.CLASSIC_EMPTY_ROW_BONUS * level
	shutter_bonus += pay
	_add_score(pay)
	shutter_pop = 1.0
	Sfx.play("gold", 1.0 + 0.04 * y)
	return true


## The curtain has come to rest on the stack: it flattens whatever is left
## and the next board is dealt.
func _classic_shutter_landed() -> void:
	# 커튼이 스택에 부딪히는 이 순간이 레벨의 마지막 한 방이다 — 남은 블록이
	# 통째로 파편이 되어 흩어지고, 부딪힌 자리를 따라 먼지와 충격 링이 퍼진다.
	for c: Vector2i in grid:
		break_fx.append([c, 0.0])
		_spawn_shards(_cell_rect(c).get_center(), Board.COLORS[grid[c]], 4, 1.2)
		# 셔터가 쓸어 간 금은 절반값이다 — 직접 깨서 먹는 쪽이 늘 이득이도록.
		_bank_ore(c, ORE_SWEEP_VALUE)
	if not grid.is_empty():
		Sfx.play("break", 0.75)
		Sfx.play("impact", 0.7, 0.0)
		shake(SHAKE_MAX)
		_freeze(HITSTOP_MAX)
		GameState.haptic(1.0, 0.3)
		var hit_y := float(shutter_row) * CELL
		for i in range(6):
			_spawn_dust(Vector2(COLS * CELL * (i + 0.5) / 6.0, hit_y), 6, 1.3)
		rings.append([Vector2(COLS * CELL * 0.5, hit_y), 0.0, COLS * CELL * 0.3,
				Color(1.0, 0.96, 0.84)])  # 우물 밖으로 삐져나가지 않는 폭
	EventBus.classic_level_cleared.emit(level, shutter_bonus)
	_classic_deal_next_level()
	shutter_phase = Shutter.HOLD
	shutter_timer = SHUTTER_HOLD


## Deals the next level's field under the curtain. The cat is left to fall
## onto the fresh floor on its own — it only gets moved if the new garbage
## would swallow it.
func _classic_deal_next_level() -> void:
	_classic_setup_level(level + 1)
	for c: Vector2i in grid:
		break_fx.append([c, 0.0])  # the new debris puffs into place
	if rect_hits_solid(player.rect()):
		player.respawn(_spawn_point())
	_spawn_piece()
	_classic_announce_level()


# --- Replay recording -------------------------------------------------------------


func _rec_reset() -> void:
	_rec_on = true
	rec_frames = PackedInt32Array()
	rec_events = []
	_rec_shadow = {}
	_rec_timer = 0.0
	if _rec_on:
		_rec_diff()  # opening keyframe: prefilled stages start with cells set


func _rec_tick(delta: float) -> void:
	if not _rec_on or not playing:
		return
	_rec_timer += delta
	if _rec_timer < REC_STEP:
		return
	_rec_timer = fmod(_rec_timer, REC_STEP)
	_rec_diff()
	var pt := Board.PIECES.find(piece_type) if piece_type != "" else -1
	rec_frames.append_array(PackedInt32Array([
		int(player.position.x), int(player.position.y),
		pt, piece_rot, piece_pos.x, piece_pos.y, int(piece_state),
		int(lava_y) if mode == Mode.ENDLESS else run_score,
	]))
	if rec_frames.size() >= REC_MAX_FRAMES * REC_STRIDE:
		_rec_on = false  # marathon runs: stop recording, keep what we have


## Grid changes land as diff events against a shadow copy — locks, clears,
## breaks and rescue blasts all reduce to added/removed cells.
func _rec_diff() -> void:
	var adds := PackedInt32Array()
	var dels := PackedInt32Array()
	for c: Vector2i in grid:
		if not _rec_shadow.has(c) or _rec_shadow[c] != grid[c]:
			adds.append_array(PackedInt32Array([c.x, c.y, Board.PIECES.find(grid[c])]))
	for c: Vector2i in _rec_shadow:
		if not grid.has(c):
			dels.append_array(PackedInt32Array([c.x, c.y]))
	if adds.is_empty() and dels.is_empty():
		return
	rec_events.append({"f": rec_frames.size() / REC_STRIDE, "a": adds, "d": dels})
	_rec_shadow = grid.duplicate()


## Snapshot of the finished (or in-progress) recording for storage/sharing.
func rec_export() -> Dictionary:
	_rec_diff()
	if rec_frames.is_empty():
		return {}
	return {"v": 1, "mode": int(mode), "cat": GameState.selected_cat,
			"rows": rows, "level": level,
			"frames": rec_frames.duplicate(), "events": rec_events.duplicate(true)}


func _clear_lines() -> int:
	var rows := {}
	for c in grid:
		rows[c.y] = true
	var full_rows: Array = []
	for y in rows:
		var full := true
		for x in range(COLS):
			if not grid.has(Vector2i(x, y)):
				full = false
				break
		if full:
			full_rows.append(y)
	if full_rows.is_empty():
		return 0
	# 지워질 줄마다 흰 섬광을 깔고, 배너가 뜰 높이를 그 한가운데로 잡는다.
	banner_y = 0.0
	for y in full_rows:
		row_flash.append([y, 0.0])
		banner_y += float(y) * CELL
	banner_y = banner_y / full_rows.size() + CELL * 0.5
	# Endless keeps the stack floating: cleared rows become open gaps instead of
	# dropping everything above, so a clear never costs the climb its height.
	var collapse := mode != Mode.ENDLESS
	var new_grid := {}
	var new_cracked := {}
	var new_ore := {}
	for c in grid:
		if c.y in full_rows:
			break_fx.append([c, 0.0])
			_spawn_shards(_cell_rect(c).get_center(), Board.COLORS[grid[c]], 3)
			_bank_ore(c, ORE_VALUE)  # 줄로 지운 금도 제값 — 지우면 손해가 되면 안 된다
			continue
		var dest: Vector2i = c
		if collapse:
			var shift := 0
			for fy in full_rows:
				if c.y < fy:
					shift += 1
			dest = Vector2i(c.x, c.y + shift)
		new_grid[dest] = grid[c]
		if cracked.has(c):
			new_cracked[dest] = true
		if ore.has(c):
			new_ore[dest] = true
	ore = new_ore
	grid = new_grid
	cracked = new_cracked
	return full_rows.size()


## Buried by a lock/line shift with nowhere to nudge to: that is death.
func _free_player_from_grid() -> bool:
	if _shove_player_out_of_grid():
		return true
	_kill_player()
	return false


## The player ended up inside locked cells (piece lock or line shift):
## nudge them to the nearest free spot. Returns false if nowhere to go.
func _shove_player_out_of_grid() -> bool:
	if not rect_hits_solid(player.rect()):
		return true
	for dist in [8.0, 16.0, 24.0, 32.0, 48.0, 64.0, 96.0, 128.0]:
		for dir in [Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]:
			var moved := Rect2(player.rect().position + dir * dist, player.rect().size)
			if not rect_hits_solid(moved):
				player.position += dir * dist
				return true
	return false


## Destroys the single locked block nearest the probe rect's center
## (jump head-bump / dash impact). Always breaks at most one block.
func break_cell_in_rect(r: Rect2) -> bool:
	var x0 := int(floor(r.position.x / CELL))
	var x1 := int(floor((r.end.x - 0.01) / CELL))
	var y0 := int(floor(r.position.y / CELL))
	var y1 := int(floor((r.end.y - 0.01) / CELL))
	var center := r.get_center()
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var c := Vector2i(x, y)
			if grid.has(c):
				var d := _cell_rect(c).get_center().distance_squared_to(center)
				if d < best_d:
					best_d = d
					best = c
	if best.x < 0:
		return false
	if ore.has(best):
		# 골드 블록은 한 방에 터진다 — 두 번 쳐야 하면 리듬이 죽는다.
		_break_fx_at(best, Board.COLORS[grid[best]])
		cracked.erase(best)
		grid.erase(best)
		break_fx.append([best, 0.0])
		_bank_ore(best, ORE_VALUE)
		_rush_gain(RUSH_ORE_GAIN)
		_add_score(BREAK_SCORE)
		Sfx.play("break")
		queue_redraw()
		return true
	if cracked.has(best):
		_break_fx_at(best, Board.COLORS[grid[best]])
		cracked.erase(best)
		grid.erase(best)
		break_fx.append([best, 0.0])
		_add_score(BREAK_SCORE)
		Sfx.play("break")
	else:
		cracked[best] = true
		shake(3.0)
		_spawn_dust(_cell_rect(best).get_center(), 3, 0.5)
		Sfx.play("crack")
	queue_redraw()
	return true


func _spawn_piece() -> void:
	if next_type == "":
		next_type = _draw_from_bag()
	piece_type = next_type
	next_type = _draw_from_bag()
	EventBus.next_piece_changed.emit(next_type)
	piece_rot = 0
	var spawn_row := _endless_spawn_row() if mode == Mode.ENDLESS else 0
	piece_pos = Vector2i(clampi(int(player.position.x / CELL) - 2, 0, COLS - 4), spawn_row)
	piece_state = PieceState.TRACKING
	# 금은 블록 네 칸 중 한 곳에 박힌다 — 회전해도 같은 칸을 따라간다(_try_rotate).
	var ore_chance := RUSH_ORE_CHANCE if rush_on() else ORE_CHANCE
	piece_ore = randi() % Board.SHAPES[piece_type][0].size() if randf() < ore_chance else -1
	track_timer = 0.0
	track_move_timer = 0.0
	# Classic Tetris block out: the new piece spawns inside the stack.
	if _piece_collides(piece_rot, piece_pos, false):
		_kill_player()


func _draw_from_bag() -> String:
	if bag.is_empty():
		bag = Board.PIECES.duplicate()
		bag.shuffle()
	return bag.pop_back()


## In endless mode the piece hovers a fixed number of cells above the camera,
## so it climbs along with the player. While a freshly detached piece still
## fills that space, the row is pushed further up so the next piece never
## spawns overlapping the previous one — it slides back down as the piece falls.
func _endless_spawn_row() -> int:
	if cam == null:
		return 0
	var row := int(floor(cam.position.y / CELL)) - ENDLESS_SPAWN_AHEAD
	for e: Dictionary in loose:
		for c: Vector2i in _loose_cells(e):
			row = mini(row, c.y - SPAWN_CLEARANCE)
	return row


func _try_rotate(dir: int) -> void:
	if piece_type == "O" or not playing:
		return
	var new_rot := (piece_rot + dir + 4) % 4
	var key := "%d>%d" % [piece_rot, new_rot]
	var kicks: Array = Board.KICKS_I[key] if piece_type == "I" else Board.KICKS_JLSTZ[key]
	var ignore_grid := piece_state == PieceState.TRACKING
	var player_rect := player.rect().grow(-CRUSH_MARGIN)
	for kick in kicks:
		var target: Vector2i = piece_pos + kick
		if _piece_collides(new_rot, target, ignore_grid):
			continue
		if piece_state != PieceState.TRACKING:
			# Never let a rotation itself crush the player.
			var overlaps := false
			for c in _cells(piece_type, new_rot, target):
				if _cell_rect(c).intersects(player_rect):
					overlaps = true
					break
			if overlaps:
				continue
		piece_ore = _rotate_ore_index(piece_type, piece_rot, new_rot, piece_ore)
		slide_off = clampf(slide_off - float(target.x - piece_pos.x), -1.5, 1.5)
		piece_pos = target
		piece_rot = new_rot
		# 도형은 이미 돌아갔고, 눈에 보이는 각도만 뒤에서 따라 붙는다.
		spin_off = -float(dir) * PI * 0.5
		spin_pop = 1.0
		Sfx.play("rotate", 1.0 + 0.06 * dir)
		return


## 회전해도 금은 같은 칸에 붙어 있어야 한다 — 칸 목록의 순서는 회전판마다
## 제각각이라, 금 칸을 도형 중심으로 90° 돌린 뒤 새 회전판에서 가장 가까운
## 칸을 찾아 번호를 다시 매긴다.
func _rotate_ore_index(t: String, from_rot: int, to_rot: int, idx: int) -> int:
	if idx < 0:
		return -1
	var src: Array = Board.SHAPES[t][from_rot]
	var dst: Array = Board.SHAPES[t][to_rot]
	if idx >= src.size():
		return -1
	var c_src := Vector2.ZERO
	for c: Vector2i in src:
		c_src += Vector2(c)
	c_src /= src.size()
	var c_dst := Vector2.ZERO
	for c: Vector2i in dst:
		c_dst += Vector2(c)
	c_dst /= dst.size()
	var turns := posmod(to_rot - from_rot, 4)
	var v := Vector2(src[idx]) - c_src
	for i in turns:
		v = Vector2(-v.y, v.x)  # 화면 좌표계(y 아래)에서의 시계 방향
	var want := c_dst + v
	var best := 0
	var best_d := INF
	for i in dst.size():
		var d := Vector2(dst[i]).distance_squared_to(want)
		if d < best_d:
			best_d = d
			best = i
	return best


func _piece_collides(rot: int, pos: Vector2i, ignore_grid: bool) -> bool:
	for c in _cells(piece_type, rot, pos):
		if c.x < 0 or c.x >= COLS or c.y >= rows:
			return true
		if not ignore_grid and grid.has(c):
			return true
	return false


func _kill_player() -> void:
	if _shutter_on():
		return  # 셔터 연출 중엔 아무도 죽지 않는다
	if player and player.alive:
		shake(SHAKE_MAX)
		GameState.haptic(1.0, 0.45)
	Sfx.play("death")
	player.die()
	playing = false
	EventBus.game_over.emit()
	queue_redraw()


## Difficulty driver: endless scales with the height climbed.
func _difficulty() -> int:
	return 1 + best_height / 8


## Extra gravity steps earned purely by staying alive. Classic and endless are
## marathons, so a long run keeps tightening even while the level (or the
## climb) stalls.
func _speed_creep() -> int:
	return mini(int(run_time / SPEED_CREEP_TIME), SPEED_CREEP_MAX)


## Difficulty driving piece speed only: the mode's own driver plus the creep.
## (The lava keeps to _difficulty — it already chases the climb.)
func _fall_difficulty() -> int:
	return _difficulty() + _speed_creep()


func _track_time() -> float:
	if mode == Mode.CLASSIC:
		# The NES gravity table scales our tracking window: level 1 keeps the
		# full 5s, the plateaus tighten it, the kill screen pins it at 1s.
		return clampf(TRACK_TIME_BASE * _classic_frames() / 48.0, 1.0, TRACK_TIME_BASE)
	return maxf(TRACK_TIME_BASE - (_fall_difficulty() - 1) * 0.4, TRACK_TIME_MIN)


func _fall_interval() -> float:
	if mode == Mode.CLASSIC:
		return clampf(FALL_INTERVAL_BASE * _classic_frames() / 48.0,
				0.03, FALL_INTERVAL_BASE)
	return maxf(FALL_INTERVAL_BASE - (_fall_difficulty() - 1) * 0.02, FALL_INTERVAL_MIN)


## NES frames-per-row for the current level. The gravity step advances every
## other level (Board.classic_speed) plus one per stretch of time survived, so
## the well never outruns the cat but a long run always tightens.
func _classic_frames() -> float:
	var step := Board.classic_speed(maxi(level, 1)) + _speed_creep()
	return float(Board.CLASSIC_FRAMES[clampi(step, 1, Board.CLASSIC_FRAMES.size()) - 1])


func _lava_speed() -> float:
	return minf(LAVA_SPEED_BASE + (_difficulty() - 1) * LAVA_SPEED_STEP, LAVA_SPEED_MAX)


## Test hotkey: N clears the current classic level on the spot.
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_N:
		classic_skip_level()


func _spawn_point() -> Vector2:
	var col := COLS / 2.0
	# Classic levels deal a garbage floor — the cat starts on top of it, not in it.
	var floor_row := rows - (level_garbage if mode == Mode.CLASSIC else 0)
	return Vector2(col * CELL, floor_row * CELL - Player.SIZE / 2.0)


func _cells(type: String, rot: int, pos: Vector2i) -> Array:
	var result: Array = []
	for c in Board.SHAPES[type][rot]:
		result.append(pos + c)
	return result


func _cell_rect(c: Vector2i) -> Rect2:
	return Rect2(Vector2(c) * CELL, Vector2.ONE * CELL)


func _draw() -> void:
	var w := COLS * CELL
	var h := rows * CELL
	var top := 0.0
	if mode == Mode.ENDLESS and cam:
		top = minf(0.0, cam.position.y - view_below)
	_draw_pit_background(w, h, top)
	for x in range(1, COLS):
		draw_line(Vector2(x * CELL, top), Vector2(x * CELL, h), Color(1, 1, 1, 0.04))
	for y in range(int(floor(top / CELL)) + 1, rows):
		draw_line(Vector2(0, y * CELL), Vector2(w, y * CELL), Color(1, 1, 1, 0.04))
	_draw_record_line(w)
	var show_hidden := mode == Mode.ENDLESS
	for c in grid:
		if show_hidden or c.y >= 0:
			_draw_cell(c, Board.COLORS[grid[c]])
			if ore.has(c):
				_draw_ore(_cell_rect(c).get_center())
			if cracked.has(c):
				_draw_crack(c)
	_draw_lock_flash()
	for fx in break_fx:
		var t: float = 1.0 - fx[1] / BREAK_FX_TIME
		var r := _cell_rect(fx[0]).grow(-CELL * 0.5 * (1.0 - t))
		draw_rect(r, Color(1.0, 1.0, 0.8, 0.7 * t))
	_draw_row_flash(w)
	_draw_trails()
	_draw_loose()
	if piece_type != "":
		_draw_ghost()
		_draw_piece()
	_draw_shards()
	_draw_dust()
	_draw_rings()
	_draw_ore_fx()
	_draw_banner(w, top)
	# 우물 테두리는 UI 키트와 같은 두꺼운 잉크 선 — 하늘 배경에 "뚫린 구덩이"로 보이게.
	var border := UiKit.INK
	var bw := 7.0
	if mode != Mode.ENDLESS:
		# Sealed pit: unbroken walls all around, no exits to draw.
		draw_rect(Rect2(-bw / 2.0, -bw / 2.0, w + bw, h + bw), border, false, bw)
	else:
		# 벽은 바닥 아래 어둠까지 이어진다 (배경을 그만큼 더 깔았다).
		var wall_bottom := h + view_below * 2.0
		draw_line(Vector2(-2, top), Vector2(-2, wall_bottom), border, bw)
		draw_line(Vector2(w + 2, top), Vector2(w + 2, wall_bottom), border, bw)
		draw_line(Vector2(-2, h + 2), Vector2(w + 2, h + 2), border, bw)
		_draw_lava(w)
		_draw_near_heat(w)
	_draw_rush_glow(w, top, h)
	if shutter_row > 0:
		_draw_shutter(w)


## 자기 최고 기록 높이에 걸리는 금색 점선. 무한의 계단에 "눈에 보이는 목표"를
## 하나 주고, 넘어서는 순간 사라진다 (그때부터는 계기판의 기록 갱신 줄이 맡는다).
func _draw_record_line(w: float) -> void:
	var best := GameState.best_height
	if mode != Mode.ENDLESS or best <= 0 or best_height >= best:
		return
	var y := rows * CELL - best * CELL
	var col := Color(1.0, 0.86, 0.38, 0.5)
	var x := 0.0
	while x < w:
		draw_line(Vector2(x, y), Vector2(minf(x + 22.0, w), y), col, 4.0)
		x += 38.0
	draw_string(ThemeDB.fallback_font, Vector2(10.0, y - 12.0),
			tr("FX_BEST_LINE").format({"n": best}), HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
			Color(1.0, 0.86, 0.38, 0.78))


## 발끝 세이브: 용암에 바짝 붙어 있는 동안 수면 위로 열기가 번진다 — 골드러시
## 게이지가 차고 있다는 신호이자 "지금 죽기 직전"이라는 경고를 겸한다.
func _draw_near_heat(w: float) -> void:
	if rush_near <= 0.0 or rush_on():
		return
	var pulse := 0.55 + 0.45 * sin(lava_phase * 13.0)
	var band := CELL * 0.7
	for i in 4:
		var a := rush_near * pulse * 0.26 * (1.0 - float(i) / 4.0)
		draw_rect(Rect2(0.0, lava_y - band * (i + 1), w, band), Color(1.0, 0.42, 0.22, a))


## 골드러시가 도는 동안 우물이 금빛으로 달아오른다. 어두운 구덩이에 반투명
## 금색을 넓게 깔면 잿빛 얼룩으로 보이므로, 벽 안쪽 금선과 좁은 띠로만 칠한다
## (발동 순간의 섬광만 예외로 화면을 통째로 덮는다).
func _draw_rush_glow(w: float, top: float, h: float) -> void:
	if not rush_on() and rush_flash <= 0.0:
		return
	var bottom := h + (view_below * 2.0 if mode == Mode.ENDLESS else 0.0)
	if rush_flash > 0.0:
		var f := rush_flash / RUSH_FLASH_TIME
		draw_rect(Rect2(0.0, top, w, bottom - top), Color(1.0, 0.88, 0.45, 0.42 * f))
	if not rush_on():
		return
	var fade := clampf(rush_time / 1.2, 0.0, 1.0)  # 끝나기 직전엔 잦아든다
	var pulse := (0.62 + 0.38 * sin(lava_phase * 9.0)) * fade
	draw_line(Vector2(8.0, top), Vector2(8.0, bottom),
			Color(1.0, 0.84, 0.34, 0.85 * pulse), 16.0)
	draw_line(Vector2(w - 8.0, top), Vector2(w - 8.0, bottom),
			Color(1.0, 0.84, 0.34, 0.85 * pulse), 16.0)
	# 금가루가 우물 위쪽에서 천천히 내려앉는다 — 화면이 "쏟아지고 있다"고 말한다.
	var span := bottom - top
	for i in 26:
		var seed := float(i) * 37.7
		var x := fposmod(seed * 13.1, w - 20.0) + 10.0
		var y := top + fposmod(seed * 7.3 + lava_phase * (90.0 + float(i % 5) * 26.0), span)
		var r := 2.5 + float(i % 3)
		draw_circle(Vector2(x, y), r, Color(1.0, 0.9, 0.5, 0.75 * fade))


## Level-clear curtain: slatted steel rolling down over the well, lit from
## above like everything else in the pit, with a warm lip on the leading edge.
## The running bonus is stamped on the closed section as it tallies up.
func _draw_shutter(w: float) -> void:
	var h := minf(shutter_row * CELL, rows * CELL)
	draw_rect(Rect2(0.0, 0.0, w, h), Color("14161d"))
	var slat := CELL * 0.5
	var y := 0.0
	while y < h:
		var band := minf(slat * 0.52, h - y)
		draw_rect(Rect2(0.0, y, w, band), Color("1d2029"))
		draw_line(Vector2(0.0, y + 1.0), Vector2(w, y + 1.0), Color(1, 1, 1, 0.07), 2.0)
		y += slat
	# Rivets down both edges sell the steel.
	var dot := 0.0
	while dot < h:
		for rx in [CELL * 0.35, w - CELL * 0.35]:
			draw_circle(Vector2(rx, dot + slat * 0.5), 3.0, Color(1, 1, 1, 0.10))
		dot += slat * 2.0
	draw_rect(Rect2(0.0, h - 7.0, w, 7.0), Color("f4e3c8"))
	draw_rect(Rect2(0.0, h, w, 14.0), Color(0, 0, 0, 0.4))
	if shutter_bonus > 0 and h > CELL * 2.5:
		# The tally the curtain is racking up, flaring on every empty row.
		var font := ThemeDB.fallback_font
		var y_at := minf(h - CELL * 1.2, rows * CELL * 0.42)
		draw_string(font, Vector2(0.0, y_at), "+%d" % shutter_bonus,
				HORIZONTAL_ALIGNMENT_CENTER, w, int(66 + 14 * shutter_pop),
				Color("fff3d0"))


## Pit backdrop: daylight seeps in from above, darkness pools below. In
## endless mode the whole pit brightens as the climb record grows, so the
## height record is visible as color.
func _draw_pit_background(w: float, h: float, top: float) -> void:
	var top_col := Color("2a3040")
	var bot_col := Color("0b0c12")
	if mode == Mode.ENDLESS:
		var t := clampf(best_height / 80.0, 0.0, 1.0)
		top_col = top_col.lerp(Color("6a7186"), t)
		bot_col = bot_col.lerp(Color("2a3040"), t)
	if rush_on():
		# 골드러시 동안은 구덩이 자체가 달아오른다 — 벽 금선만으로는 10초가
		# 시작됐는지 눈에 안 들어온다. 끝나기 직전 1.2초에 걸쳐 식는다.
		var g := clampf(rush_time / 1.2, 0.0, 1.0)
		top_col = top_col.lerp(Color("5c3f0e"), 0.62 * g)
		bot_col = bot_col.lerp(Color("2e1e05"), 0.9 * g)
	# 무한의 계단은 우물 바닥 아래(용암이 차오르는 어둠)까지 카메라에 들어온다 —
	# 하늘 배경이 비쳐 우물이 떠 보이지 않게 바닥색으로 더 아래까지 깐다.
	var floor_y := h + (view_below * 2.0 if mode == Mode.ENDLESS else 0.0)
	draw_polygon(PackedVector2Array([
		Vector2(0, top), Vector2(w, top), Vector2(w, floor_y), Vector2(0, floor_y),
	]), PackedColorArray([top_col, top_col, bot_col, bot_col]))
## Rising lava: hot glowing surface with a slow wave, cooling to dark below.
func _draw_lava(w: float) -> void:
	var bottom := maxf(rows * CELL, lava_y) + CELL * 6.0
	var hot := Color("ff8c38")
	var dark := Color("6d1a0c")
	draw_polygon(PackedVector2Array([
		Vector2(0, lava_y), Vector2(w, lava_y), Vector2(w, bottom), Vector2(0, bottom),
	]), PackedColorArray([hot, hot, dark, dark]))
	# Faint heat glow just above the surface.
	var glow := Color(1.0, 0.55, 0.2, 0.22)
	var faded := Color(1.0, 0.55, 0.2, 0.0)
	draw_polygon(PackedVector2Array([
		Vector2(0, lava_y - CELL), Vector2(w, lava_y - CELL),
		Vector2(w, lava_y), Vector2(0, lava_y),
	]), PackedColorArray([faded, faded, glow, glow]))
	var points := PackedVector2Array()
	for i in range(21):
		var x := w * i / 20.0
		points.append(Vector2(x, lava_y + sin(x * 0.045 + lava_phase * 2.6) * 4.0))
	draw_polyline(points, Color("ffd27a"), 5.0)


func _draw_piece() -> void:
	var color: Color = Board.COLORS[piece_type]
	var pulse := 0.0
	if piece_state == PieceState.TRACKING:
		var t := track_timer / _track_time()
		color.a = 0.35 + 0.4 * t
		if t > 0.7 and fmod(track_timer, 0.3) < 0.15:
			color.a = 1.0
	elif piece_state == PieceState.LANDED:
		# Landed but still shovable: glowing pulse until it locks.
		pulse = 0.5 + 0.5 * sin(land_timer * 16.0)
		color = color.lightened(0.18 + 0.18 * pulse)
	var cells := _cells(piece_type, piece_rot, piece_pos)
	# 격자에는 이미 칸 단위로 박혀 있고, 눈에 보이는 것만 뒤에서 따라온다 —
	# 가로 잔여 이동 · 회전 잔여 각도 · 착지 눌림을 변환 하나에 실어 그린다.
	var pivot := Vector2.ZERO
	for c: Vector2i in cells:
		pivot += _cell_rect(c).get_center()
	pivot /= float(maxi(cells.size(), 1))
	var sq := land_squash * land_squash
	var sc := Vector2(1.0 + 0.22 * sq, 1.0 - 0.26 * sq)
	draw_set_transform_matrix(Transform2D(spin_off, sc, 0.0,
			pivot + Vector2(slide_off * CELL, 0.0)))
	for i in range(cells.size()):
		var c: Vector2i = cells[i]
		if mode == Mode.ENDLESS or c.y >= 0:
			var p := Vector2(c) * CELL - pivot
			_draw_block(p, color)
			if i == piece_ore:
				_draw_ore(p + Vector2(CELL, CELL) * 0.5, color.a)
			if piece_state == PieceState.LANDED:
				draw_rect(Rect2(p + Vector2(2.0, 2.0), Vector2(CELL - 4.0, CELL - 4.0)),
						Color(1.0, 0.96, 0.8, 0.3 + 0.45 * pulse), false, 3.0)
			if spin_pop > 0.0:
				draw_rect(Rect2(p, Vector2(CELL, CELL)),
						Color(1.0, 1.0, 0.95, 0.5 * spin_pop), false, 3.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if piece_state == PieceState.TRACKING:
		var remain := ceili(_track_time() - track_timer)
		var top_left := Vector2(piece_pos) * CELL + Vector2(slide_off * CELL, 0.0)
		draw_string(ThemeDB.fallback_font, top_left + Vector2(CELL * 1.6, CELL * 1.4),
				str(remain), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1, 1, 1, 0.9))


## Detached endless pieces: full-color while falling, lock-pulse while landed.
func _draw_loose() -> void:
	for e: Dictionary in loose:
		var color: Color = Board.COLORS[e.t]
		var pulse := 0.0
		if e.s == PieceState.LANDED:
			pulse = 0.5 + 0.5 * sin(e.lt * 16.0)
			color = color.lightened(0.18 + 0.18 * pulse)
		var cells := _loose_cells(e)
		var oi := int(e.get("o", -1))
		for i in cells.size():
			var c: Vector2i = cells[i]
			_draw_cell(c, color)
			if i == oi:
				_draw_ore(_cell_rect(c).get_center(), color.a)
			if e.s == PieceState.LANDED:
				draw_rect(_cell_rect(c).grow(-2.0),
						Color(1.0, 0.96, 0.8, 0.3 + 0.45 * pulse), false, 3.0)


## 튀어 나간 금 부스러기를 나이 먹인다.
func _age_ore_fx(delta: float) -> void:
	if ore_fx.is_empty():
		return
	for fx in ore_fx:
		fx[1] += delta
	ore_fx = ore_fx.filter(func(fx: Array) -> bool: return fx[1] < ORE_FX_TIME)


## 블록 안에 박힌 금 — 잉크 외곽선 두른 금괴 한 덩이에 위쪽 하이라이트.
## 빛은 늘 위에서 온다는 아트 규칙을 그대로 따른다.
func _draw_ore(center: Vector2, alpha := 1.0) -> void:
	var r := CELL * 0.24
	var gold := Color(0.99, 0.79, 0.24, alpha)
	var deep := Color(0.78, 0.53, 0.10, alpha)
	var ink := UiKit.INK
	ink.a = alpha
	var pts := PackedVector2Array([
		center + Vector2(0.0, -r * 1.15),
		center + Vector2(r, 0.0),
		center + Vector2(0.0, r * 1.15),
		center + Vector2(-r, 0.0),
	])
	draw_colored_polygon(pts, gold)
	draw_colored_polygon(PackedVector2Array([
		pts[2], pts[1], center + Vector2(0.0, r * 0.1)]), deep)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), ink, 2.5)
	draw_line(center + Vector2(-r * 0.34, -r * 0.42), center + Vector2(-r * 0.04, -r * 0.72),
			Color(1.0, 0.99, 0.88, 0.9 * alpha), 3.0)


## 부서진 골드 블록에서 금이 사방으로 튄다 + 딴 금액이 떠오른다.
func _draw_ore_fx() -> void:
	var font := ThemeDB.fallback_font
	for fx in ore_fx:
		var at: Vector2 = fx[0]
		var t: float = clampf(fx[1] / ORE_FX_TIME, 0.0, 1.0)
		var fade := 1.0 - t
		for i in ORE_SPARKS:
			var ang := TAU * (float(i) / ORE_SPARKS) + at.x * 0.01
			var dist := CELL * (0.25 + 1.05 * ease(t, 0.35))
			var p := at + Vector2(cos(ang), sin(ang) * 0.85) * dist
			p.y += CELL * 1.1 * t * t  # 튀어 오른 뒤 중력에 진다
			draw_circle(p, maxf(2.0, 7.0 * fade), Color(1.0, 0.84, 0.32, fade))
		# 퍼지는 금빛 링 + 초반 한 점의 섬광. 넓게 깐 반투명 원은 어두운 우물에서
		# 잿빛 얼룩으로 보여서 쓰지 않는다.
		var ring := CELL * (0.26 + 0.6 * ease(t, 0.3))
		draw_circle(at, ring, Color(1.0, 0.86, 0.38, 0.9 * fade), false,
				maxf(2.0, 8.0 * fade))
		if t < 0.45:
			var flash := 1.0 - t / 0.45
			draw_circle(at, CELL * 0.42 * (0.45 + 0.55 * flash),
					Color(1.0, 0.98, 0.85, minf(1.0, flash * 1.8)))
		var text := "+%d" % int(fx[2])
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		var ty := at.y - CELL * 0.62 - 52.0 * t
		draw_string_outline(font, Vector2(at.x - w / 2.0, ty), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, Color(0.17, 0.16, 0.20, fade))
		draw_string(font, Vector2(at.x - w / 2.0, ty), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1.0, 0.86, 0.36, fade))


## 격자에 박히는 순간의 흰 섬광 — "쿵" 소리에 그림을 붙인다.
func _draw_lock_flash() -> void:
	for e in lock_flash:
		var t: float = 1.0 - float(e[1]) / LOCK_FLASH_TIME
		for c: Vector2i in e[0]:
			if mode == Mode.ENDLESS or c.y >= 0:
				draw_rect(_cell_rect(c).grow(-1.0), Color(1.0, 1.0, 0.95, 0.55 * t))


## 지워지는 줄: 흰 띠가 번쩍이며 얇아지고, 가운데 선이 좌우로 삐져나간다.
func _draw_row_flash(w: float) -> void:
	for e in row_flash:
		var t: float = clampf(float(e[1]) / ROW_FLASH_TIME, 0.0, 1.0)
		var y: float = float(e[0]) * CELL
		var h := CELL * (1.0 - ease(t, 0.4))
		var fade := 1.0 - t
		draw_rect(Rect2(0.0, y + (CELL - h) * 0.5, w, h),
				Color(1.0, 0.99, 0.9, 0.85 * fade))
		draw_rect(Rect2(-CELL * 0.5 * t, y + CELL * 0.5 - 2.0,
				w + CELL * t, 4.0), Color(1.0, 1.0, 1.0, fade))


## 빠르게 내려온 자국. 지나온 칸에 블록 색 띠 + 가운데 흰 심지가 남는다.
func _draw_trails() -> void:
	for e in trails:
		var t: float = clampf(float(e[3]) / TRAIL_TIME, 0.0, 1.0)
		var col: Color = e[2]
		var fade := (1.0 - t) * col.a
		var swept: int = e[1]
		for c: Vector2i in e[0]:
			var x := float(c.x) * CELL
			var y0 := float(c.y - swept) * CELL
			var h := float(swept) * CELL
			draw_rect(Rect2(x + CELL * 0.16, y0, CELL * 0.68, h),
					Color(col.r, col.g, col.b, 0.18 * fade))
			draw_rect(Rect2(x + CELL * 0.42, y0, CELL * 0.16, h),
					Color(1.0, 0.98, 0.9, 0.4 * fade))


## 착지 예상 자리. 어디에 떨어질지 보이면 조작이 붙는다 — 무한의 계단은 블록이
## 제 갈 길로 떨어져 나가므로(loose) 그리지 않는다.
func _draw_ghost() -> void:
	if mode == Mode.ENDLESS or piece_state == PieceState.LANDED:
		return
	var p := piece_pos
	var guard := 0
	while guard < rows + 4 and not _piece_collides(piece_rot, p + Vector2i(0, 1), false):
		p.y += 1
		guard += 1
	if p == piece_pos:
		return
	var col: Color = Board.COLORS[piece_type]
	var off := Vector2(slide_off * CELL, 0.0)
	for c: Vector2i in _cells(piece_type, piece_rot, p):
		if c.y < 0:
			continue
		var r := _cell_rect(c).grow(-CELL * 0.13)
		r.position += off
		draw_rect(r, Color(col.r, col.g, col.b, 0.10))
		draw_rect(r, Color(col.r, col.g, col.b, 0.5), false, 3.0)


func _draw_dust() -> void:
	for d in dust:
		var t: float = clampf(float(d[2]) / float(d[3]), 0.0, 1.0)
		var col: Color = d[5]
		draw_circle(d[0], float(d[4]) * (0.6 + 1.6 * t),
				Color(col.r, col.g, col.b, 0.45 * (1.0 - t)))


func _draw_shards() -> void:
	for sh in shards:
		var t: float = clampf(float(sh[2]) / SHARD_TIME, 0.0, 1.0)
		var sz: float = float(sh[4]) * (1.0 - 0.6 * t)
		var col: Color = sh[3]
		col.a = 1.0 - t
		var u := Vector2(cos(sh[5]), sin(sh[5])) * sz
		var v := Vector2(-u.y, u.x)
		var at: Vector2 = sh[0]
		draw_colored_polygon(PackedVector2Array([at + u, at + v, at - u, at - v]), col)


## 착지 충격 링 — 바닥에 납작하게 퍼진다(빛은 위에서 온다는 규칙과 같은 방향).
func _draw_rings() -> void:
	for e in rings:
		var t: float = clampf(float(e[1]) / RING_TIME, 0.0, 1.0)
		var col: Color = e[3]
		col.a = 0.7 * (1.0 - t)
		var rr: float = float(e[2]) * (0.35 + 1.3 * ease(t, 0.3))
		var pts := PackedVector2Array()
		for i in range(25):
			var ang := TAU * i / 24.0
			pts.append((e[0] as Vector2) + Vector2(cos(ang) * rr, sin(ang) * rr * 0.34))
		draw_polyline(pts, col, maxf(2.0, 7.0 * (1.0 - t)))


## 멀티 라인/콤보 배너 — 지운 줄 자리에서 크게 튀어 올라 사라진다.
func _draw_banner(w: float, top: float) -> void:
	if banner_age >= BANNER_TIME or (banner_key == "" and combo < 2):
		return
	var t := banner_age / BANNER_TIME
	var pop := 1.0 + 0.45 * (1.0 - ease(minf(t * 4.5, 1.0), 0.25))
	var fade := 1.0 - ease(t, 3.0)
	var font := ThemeDB.fallback_font
	var y := clampf(banner_y - 44.0 * t, top + CELL * 1.4, rows * CELL - CELL)
	if banner_key != "":
		var text := tr(banner_key)
		var fs := int(70 * pop)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := Vector2((w - tw) * 0.5, y)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10,
				Color(0.17, 0.16, 0.20, fade))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				Color(1.0, 0.94, 0.62, fade))
	if combo >= 2:
		var ctext := tr("FX_COMBO").format({"n": combo})
		var cw := font.get_string_size(ctext, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		var cat := Vector2((w - cw) * 0.5, y + (56.0 if banner_key != "" else 0.0))
		draw_string_outline(font, cat, ctext, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, 8,
				Color(0.17, 0.16, 0.20, fade))
		draw_string(font, cat, ctext, HORIZONTAL_ALIGNMENT_LEFT, -1, 40,
				Color(0.62, 0.92, 1.0, fade))


## 블록 한 칸이 부서졌다: 파편 + 먼지 + 짧은 흔들림.
func _break_fx_at(c: Vector2i, col: Color) -> void:
	var at := _cell_rect(c).get_center()
	_spawn_shards(at, col, 6)
	_spawn_dust(at, 4, 0.7)
	shake(6.0)
	_freeze(0.03)
	GameState.haptic(0.35, 0.05)


func _draw_crack(c: Vector2i) -> void:
	var p := Vector2(c) * CELL
	var col := Color(1.0, 0.96, 0.84, 0.65)
	draw_polyline(PackedVector2Array([
		p + Vector2(14, 8), p + Vector2(30, 26), p + Vector2(22, 40), p + Vector2(38, 56),
	]), col, 2.5)
	draw_polyline(PackedVector2Array([
		p + Vector2(48, 12), p + Vector2(36, 30), p + Vector2(50, 44),
	]), col, 2.0)


## 지금 떨어지는 블록의 한가운데 (보드 로컬 좌표) — HUD 연출이 과녁으로 쓴다.
func piece_center() -> Vector2:
	if piece_type == "":
		return Vector2(COLS * CELL * 0.5, 0.0)
	var cells := _cells(piece_type, piece_rot, piece_pos)
	var mid := Vector2.ZERO
	for c: Vector2i in cells:
		mid += _cell_rect(c).get_center()
	return mid / float(maxi(cells.size(), 1))


## 캐릭터별 알파벳 키캡. 캡 색은 그 냥이의 몸/귀 색을 따르고, 캡 위에는
## 컨셉 시트 원본에서 얼굴만 오려 얹어 "누구 키캡인지" 한눈에 보이게 한다.
## cat_id를 비우면 예전 크림색 기본 키캡(귀 + 수염 점)으로 그린다.
## pulse (0..1)가 부드러운 발광을 몰고, 정지 UI에서는 상수를 넘긴다.
static func paint_keycap(ci: CanvasItem, r: Rect2, letter: String,
		pulse := 0.5, glow := true, cat_id := "") -> void:
	var body := Color("f4e3c8")
	var edge := Color("d9a05c")
	var ink := Color("2a2230")
	var char_id := ""
	if cat_id != "":
		var cat: Dictionary = GameState.get_cat(cat_id)
		# 캡 바탕은 몸 색을 밝게 눕힌 것 — 검은 냥이도 글자가 읽혀야 한다.
		body = (cat.body as Color).lerp(Color.WHITE, 0.55)
		edge = cat.ear
		char_id = str(cat.get("char", ""))
	var center := r.get_center()
	var s := r.size.x  # keycap scales off the cell size (64 in-game)
	if glow:
		ci.draw_circle(center, s * 0.47 + s * 0.06 * pulse,
				Color(1.0, 0.95, 0.82, 0.10 + 0.08 * pulse))
	var cap := r.grow(-s * 0.125)
	# Ears peek over the top edge, drawn before the cap so their base hides.
	for sx: float in [-1.0, 1.0]:
		var ex := center.x + sx * s * 0.2
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(ex - s * 0.11, cap.position.y + s * 0.08),
			Vector2(ex + s * 0.11, cap.position.y + s * 0.08),
			Vector2(ex + sx * s * 0.03, cap.position.y - s * 0.1),
		]), edge)
	var sb := StyleBoxFlat.new()
	sb.bg_color = body
	sb.set_corner_radius_all(int(s * 0.14))
	sb.set_border_width_all(maxi(1, int(s * 0.03)))
	sb.border_color = edge
	ci.draw_style_box(sb, cap)
	# Light from above: a soft highlight along the keycap's top face.
	ci.draw_rect(Rect2(cap.position + Vector2(s * 0.09, s * 0.05),
			Vector2(cap.size.x - s * 0.18, s * 0.07)), Color(1, 1, 1, 0.5))
	var font := ThemeDB.fallback_font
	var face_drawn := _paint_keycap_face(ci, cap, char_id)
	# 얼굴이 올라가면 글자는 캡 아래쪽으로, 아니면 예전처럼 한가운데로.
	var fs := int(s * (0.26 if face_drawn else 0.44))
	var ly := (cap.end.y - s * 0.055) if face_drawn else (center.y + fs * 0.36)
	var w := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(font, Vector2(center.x - w / 2.0, ly), letter,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	if face_drawn:
		return
	# Whisker dots flanking the letter — the cat face of the default keycap.
	for sx: float in [-1.0, 1.0]:
		for dy: float in [-1.0, 1.0]:
			ci.draw_circle(center + Vector2(sx * s * 0.3, s * 0.05 + dy * s * 0.05),
					s * 0.022, Color(ink, 0.55))


## 컨셉 시트 원본에서 얼굴(귀 아래 ~ 입 언저리)만 오려 캡 위쪽에 얹는다.
## 그림이 없는 캐릭터면 false — 호출부가 기본 키캡 얼굴로 떨어진다.
static func _paint_keycap_face(ci: CanvasItem, cap: Rect2, char_id: String) -> bool:
	if char_id == "":
		return false
	var tex: Texture2D = CatSprite.face_texture(char_id)
	if tex == null:
		return false
	var src := CatSprite.FACE
	var w := cap.size.x * 0.92
	var h := w * src.size.y / src.size.x
	var at := Vector2(cap.get_center().x - w / 2.0, cap.position.y + cap.size.y * 0.05)
	ci.draw_texture_rect_region(tex, Rect2(at, Vector2(w, h)), src)
	return true


func _draw_cell(c: Vector2i, color: Color) -> void:
	_draw_block(Vector2(c) * CELL, color)


func _draw_block(p: Vector2, color: Color) -> void:
	var a := color.a
	draw_rect(Rect2(p + Vector2.ONE, Vector2(CELL - 2.0, CELL - 2.0)), color)
	# Light always comes from above: bright top face, shaded bottom.
	draw_rect(Rect2(p + Vector2(5.0, 3.0), Vector2(CELL - 10.0, 5.0)),
			Color(1.0, 0.96, 0.84, 0.4 * a))
	draw_rect(Rect2(p + Vector2(1.0, CELL - 6.0), Vector2(CELL - 2.0, 5.0)),
			Color(0.0, 0.0, 0.0, 0.28 * a))
	var edge := color.darkened(0.4)
	edge.a = a
	draw_rect(Rect2(p + Vector2.ONE, Vector2(CELL - 2.0, CELL - 2.0)), edge, false, 2.0)
