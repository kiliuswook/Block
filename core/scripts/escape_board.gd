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
# --- 피버타임 (무한의 계단 전용 스파이크) --------------------------------------
# 무한의 계단은 처음부터 끝까지 같은 리듬으로 조여 오기만 해서 "판이 뒤집히는
# 순간"이 없었다. 피버타임이 그 자리다. 게이지는 **시간으로는 절대 차지 않고**
# 무한에서 실제로 하는 짓 — 올라가기·블록 부수기·용암 발끝 세이브, 그리고
# (드물지만) 줄 클리어로만 찬다: 운이 아니라 실력이 터뜨린다.
#
# 발동하면 고양이가 중력도 블록도 무시하고 **저 혼자 솟구친다**. 짧고, 안전하고,
# 화려하다 — 조여 오던 판이 잠깐 통째로 사라지는 기분 전환이 이 연출의 전부다.
# 상승 경로에는 별이 지그재그로 깔려서, 좌우로 잘 훑으면 조금 더 높이 간다
# (`FEVER_BOOST_MAX`만큼 = 최대 3할 남짓. 가만히 있어도 대부분은 비슷하게 오른다).
# 끝나는 순간 발밑에 착지 발판을 깔아 준다 — 안 그러면 오른 만큼 도로 떨어져
# 용암에 빠지므로, "안전하게 벌었다"는 약속이 깨진다.
const FEVER_MAX := 100.0
const FEVER_CLIMB_GAIN := 3.0  # 최고 높이를 새로 갱신한 칸마다 (주 수입원)
const FEVER_BREAK_GAIN := 3.0  # 일반 블록을 직접 부쉈다 (대시·머리 박기)
const FEVER_LINE_GAIN := [0.0, 8.0, 20.0, 36.0, 60.0]  # 한 번에 지운 줄 수만큼
const FEVER_COMBO_GAIN := 5.0  # 콤보 한 단계마다 얹는다
const FEVER_ORE_GAIN := 6.0  # 금 한 칸을 직접 깨서 캤다
const FEVER_NEAR_GAIN := 18.0  # 발끝 세이브: 용암에 붙어 있는 동안 초당
const FEVER_NEAR_DIST := CELL * 2.2  # 발과 용암이 이보다 가까우면 "발끝"
const FEVER_TIME := 3.4  # 발동 지속 (초) — 짧게 끊어야 기분 전환으로 남는다
const FEVER_RISE := 560.0  # 최고 상승 속도 (px/s) ≈ 8.75칸/초
const FEVER_ACCEL_TIME := 0.5  # 이만큼에 걸쳐 최고 속도까지 붙는다 (가속이 있어야 빠르게 느낀다)
const FEVER_ZOOM := 0.94  # 발동 중 카메라를 살짝 당긴다 — 시야가 좁아지면 더 빨라 보인다
const FEVER_STEER := 1.35  # 상승 중 좌우 조작 배율 (별을 훑으러 다닐 만큼)
const FEVER_COIN_RATE := 16.0  # 하늘에서 쏟아지는 코인 수 (초당)
const FEVER_COIN_SEED := 14  # 발동 순간 하늘에 미리 깔아 두는 코인 수 (첫 프레임부터 비가 온다)
const FEVER_COIN_FALL := 300.0  # 코인 낙하 속도 (px/s) — 솟는 고양이와 마주 달려 더 빨라 보인다
const FEVER_COIN_SPREAD := 0.36  # 소나기 줄기가 좌우로 흔들리는 폭 (우물 폭 대비)
const FEVER_COIN_R := 22.0  # 먹는 판정 반지름
const FEVER_COIN_BOOST := 0.02  # 코인 하나마다 붙는 상승 속도 (비율)
const FEVER_BOOST_MAX := 0.35  # 다 주워도 여기까지 — "대부분 비슷하게" 오른다
const FEVER_COIN_GOLD := 8  # 코인 하나의 골드
const FEVER_LAVA_PUSH := 6  # 발동 순간 용암을 이만큼(칸) 밀어낸다
const FEVER_FLASH_TIME := 0.5  # 발동 순간의 섬광
# [테스트용 · 출시 전 0.0으로 되돌릴 것] 판을 시작할 때 게이지를 이만큼 채워 두면
# 피버 발동·종료 연출을 몇 수 만에 확인할 수 있다.
const FEVER_DEBUG_START := 90.0
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
# 피버가 공중에 깔아 준 바닥. `_unsupported_cells()`가 이 칸을 품은 덩어리를
# "받쳐져 있다"고 쳐 준다 — 우물 바닥에 닿지 않는 섬이라, 앵커가 없으면 다음
# `_settle_grid()`에 통째로 떨어져 애써 벌어 준 높이가 날아간다.
var anchor := {}  # Vector2i -> true (grid·cracked·ore와 나란히 옮겨 다닌다)
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
var rise_off := 0.0  # 회전 월킥의 세로 잔여 오프셋 (칸 단위, 0으로 수렴)
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

# --- 피버타임 상태 (`_fx_reset()`이 전부 비운다) -------------------------------
var fever_gauge := 0.0  # 0 ~ FEVER_MAX
var fever_time := 0.0  # 남은 발동 시간 (0 = 꺼짐)
var fever_near := 0.0  # 발끝 세이브 근접도 0..1 — 용암 위 열기 연출에 쓴다
var fever_boost := 0.0  # 이번 피버에 별로 벌어들인 상승 속도 (비율, 0~FEVER_BOOST_MAX)
var fever_coins: Array = []  # [pos, age, taken, vel, spin] — 하늘에서 쏟아지는 골드 코인
var fever_coin_acc := 0.0  # 코인 생성 누적기 (FEVER_COIN_RATE)
var fever_streaks: Array = []  # [x, y, len, speed] — 아래로 흐르는 속도선
var fever_phase := 0.0  # 연출용 누적 시간
var fever_flash := 0.0  # 발동 순간의 섬광 (초)

@onready var player: Player = $Player
@onready var cam: Camera2D = get_node_or_null("Cam")


func start_game() -> void:
	mode = GameState.mode as Mode
	rows = PIT_ROWS
	grid.clear()
	cracked.clear()
	ore.clear()
	anchor.clear()
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
	EventBus.fever_changed.emit(fever_gauge / FEVER_MAX, 0.0)  # [테스트용 시작 게이지 반영]
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
	# 피버타임 동안은 판이 통째로 멎는다 — 조각도, 굴러다니는 덩어리도. 조여 오던
	# 것이 잠깐 사라지는 것이 이 6초의 전부라, 위에서 뭐가 내려오면 안 된다.
	if not fever_on():
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
	rise_off = 0.0
	spin_off = 0.0
	spin_pop = 0.0
	land_squash = 0.0
	fall_from = 0
	hard_drop_rows = 0
	combo = 0
	fever_gauge = FEVER_DEBUG_START  # [테스트용] 평소엔 0.0
	fever_time = 0.0
	fever_near = 0.0
	fever_boost = 0.0
	fever_phase = 0.0
	fever_coins.clear()
	fever_coin_acc = 0.0
	fever_streaks.clear()
	fever_flash = 0.0
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
	rise_off = move_toward(rise_off, 0.0, delta / SLIDE_TIME)
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
	# 피버 동안 카메라를 살짝 당긴다 — 시야가 좁아지면 같은 속도도 더 빨라 보인다.
	var want_zoom := view_zoom / (FEVER_ZOOM if fever_on() else 1.0)
	cam.zoom = cam.zoom.lerp(Vector2(want_zoom, want_zoom), clampf(delta * 6.0, 0.0, 1.0))
	# Lava creeps up from below; it also keeps pace with the player so a
	# fast climber can never leave it arbitrarily far behind.
	lava_phase += delta
	# 골드러시가 도는 동안 용암은 멎는다 — 10초짜리 숨통이자, 낮게 파고들어 금을
	# 캘 수 있는 유일한 창이다. (낙하 속도는 건드리지 않는다: 느려지면 긴장이
	# 죽고, 빨라지면 벌 수가 없다.)
	if not fever_on():
		lava_y -= _lava_speed() * delta
	lava_y = minf(lava_y, player.position.y + LAVA_MAX_GAP)
	var feet := player.position.y + Player.SIZE / 2.0
	if feet > lava_y:
		_kill_player()
		return
	_fever_step(delta, feet)
	_track_height(feet)


## 발 높이를 층수로 재서 이 판의 기록을 갱신한다. 새로 오른 칸만큼 점수와
## 골드러시 게이지를 준다 — 내려갔다 다시 올라오는 구간은 값을 치르지 않으니
## 파밍도, 시간 충전도 되지 않는다.
func _track_height(feet: float) -> void:
	var h := int(round((rows * CELL - feet) / CELL))
	if h <= best_height:
		return
	var gained := h - best_height
	_add_score(gained * HEIGHT_SCORE)
	_fever_gain(FEVER_CLIMB_GAIN * float(gained))
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
		if mode == Mode.ENDLESS:
			# 무한의 계단: 우물에 천장은 없지만 화면 위 가장자리가 천장이다.
			# 떨어지던 블록이 스폰 줄을 위로 밀어 올려 스택이 화면 밖으로 계속
			# 자라는 일이 없게, 락되는 칸이 카메라 위 끝에 닿으면 끝낸다.
			if float(c.y) * CELL <= _screen_top_y():
				overflow = true
		elif c.y < 0:
			overflow = true
	if overflow:
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


# --- 피버타임 -------------------------------------------------------------------


## 지금 피버타임이 돌고 있는가 (플레이어 상승·블록 정지·연출이 이 값을 본다).
func fever_on() -> bool:
	return fever_time > 0.0


## 지금 프레임의 상승 속도 (px/s). 별을 훑은 만큼 붙는다 — player.gd가 읽는다.
## 발동 직후 FEVER_ACCEL_TIME에 걸쳐 최고 속도까지 붙는다: 처음부터 등속으로
## 올라가면 아무리 빨라도 "빠르다"가 아니라 "그냥 그런 속도"로 읽힌다.
func fever_rise() -> float:
	var t := clampf((FEVER_TIME - fever_time) / FEVER_ACCEL_TIME, 0.0, 1.0)
	return FEVER_RISE * (1.0 + fever_boost) * (t * t * (3.0 - 2.0 * t))


## 게이지 충전. 무한의 계단에서, 피버가 돌고 있지 않을 때만 찬다 — 가만히 있어서
## 차는 길은 어디에도 없다. (피버 중 솟구쳐 오른 높이가 다음 피버를 채우면
## 무한 연쇄가 되므로, 발동 중에는 문이 닫혀 있는 것이 중요하다.)
func _fever_gain(amount: float) -> void:
	if mode != Mode.ENDLESS or not playing or fever_on() or amount <= 0.0:
		return
	fever_gauge = minf(fever_gauge + amount, FEVER_MAX)
	EventBus.fever_changed.emit(fever_gauge / FEVER_MAX, 0.0)
	if fever_gauge >= FEVER_MAX:
		_fever_start()


## 발동: 용암을 한 번 크게 밀어내고, 고양이가 솟구칠 별길을 깐다.
func _fever_start() -> void:
	fever_gauge = 0.0
	fever_time = FEVER_TIME
	fever_flash = FEVER_FLASH_TIME
	fever_boost = 0.0
	fever_phase = 0.0
	lava_y += FEVER_LAVA_PUSH * CELL
	_fever_seed_coins()
	fever_streaks.clear()
	shake(16.0)
	_freeze(0.08)
	GameState.haptic(0.9, 0.25)
	banner_key = "FX_FEVER"
	banner_age = 0.0
	banner_y = player.position.y - CELL * 1.6 if player else rows * CELL * 0.4
	Sfx.play("fever")
	EventBus.fever_changed.emit(0.0, fever_time)


## 하늘에서 골드가 쏟아진다. 발동 순간 화면 위쪽에 미리 한 움큼 깔아 두어
## 첫 프레임부터 비가 오고, 그 뒤로는 `_fever_rain()`이 초당 FEVER_COIN_RATE개씩
## 흘려 보낸다.
func _fever_seed_coins() -> void:
	fever_coins.clear()
	fever_coin_acc = 0.0
	var top := _fever_sky_top()
	var bottom := player.position.y - CELL * 2.0
	for i in FEVER_COIN_SEED:
		var y := lerpf(bottom, top, (float(i) + randf()) / float(FEVER_COIN_SEED))
		_fever_drop_coin(y)


## 카메라 위쪽 가장자리(월드 y) — 코인이 태어나는 하늘. 카메라가 없으면(테스트)
## 아래로 그리는 거리만큼 위로 잡는다.
func _fever_sky_top() -> float:
	if cam:
		return _screen_top_y() - CELL
	return player.position.y - view_below


## 카메라가 보여 주는 위쪽 끝(월드 y). 무한의 계단에서 스택이 여기 닿으면 끝이다.
## 카메라가 없으면(테스트) 닿을 수 없는 높이를 돌려준다.
func _screen_top_y() -> float:
	if cam == null:
		return -INF
	return cam.position.y - get_viewport_rect().size.y * 0.5 / maxf(cam.zoom.y, 0.05)


## 코인 하나를 y 높이에 떨어뜨린다. 셋 중 둘은 좌우로 흔들리는 소나기 줄기를
## 따르고(훑으러 움직일 이유), 하나는 우물 폭 어디에나 — 가만히 있어도 몇 개는 온다.
func _fever_drop_coin(y: float) -> void:
	var w := COLS * CELL
	var x: float
	if randf() < 0.66:
		var mid := w * 0.5 + sin(fever_phase * 1.7) * w * FEVER_COIN_SPREAD
		x = clampf(mid + randfn(0.0, CELL * 0.8), CELL * 0.4, w - CELL * 0.4)
	else:
		x = CELL * 0.4 + randf() * (w - CELL * 0.8)
	var vel := Vector2(randfn(0.0, 30.0), FEVER_COIN_FALL * (0.8 + randf() * 0.5))
	fever_coins.append([Vector2(x, y), 0.0, false, vel, randf() * TAU])


## 매 프레임: 새 코인을 하늘에 흘리고, 있는 코인을 떨어뜨리고, 화면 아래로
## 지나간 것은 치운다.
func _fever_rain(delta: float) -> void:
	fever_coin_acc += FEVER_COIN_RATE * delta
	var top := _fever_sky_top()
	while fever_coin_acc >= 1.0:
		fever_coin_acc -= 1.0
		_fever_drop_coin(top - randf() * CELL * 2.0)
	var floor_y := player.position.y + view_below
	var kept: Array = []
	for st in fever_coins:
		st[1] += delta
		if st[2]:
			if st[1] < 0.35:
				kept.append(st)
			continue
		var vel := st[3] as Vector2
		st[0] = (st[0] as Vector2) + vel * delta
		st[4] = (st[4] as float) + delta * 7.0
		if (st[0] as Vector2).y < floor_y:
			kept.append(st)
	fever_coins = kept


## 매 프레임: 남은 시간을 깎고, 발끝 세이브를 재고, 별을 줍고, 연출을 흘린다.
func _fever_step(delta: float, feet: float) -> void:
	fever_flash = maxf(fever_flash - delta, 0.0)
	fever_phase += delta
	# 발끝 세이브 — 용암에 바짝 붙어 있는 동안만 게이지가 찬다. 안전하게만
	# 올라가면 피버는 영영 안 터진다: 위험을 감수할 이유를 만드는 자리다.
	var gap := lava_y - feet
	fever_near = clampf(1.0 - gap / FEVER_NEAR_DIST, 0.0, 1.0) if gap > 0.0 else 0.0
	if fever_near > 0.0:
		_fever_gain(FEVER_NEAR_GAIN * delta)
	if not fever_on():
		return
	fever_time = maxf(fever_time - delta, 0.0)
	EventBus.fever_changed.emit(0.0, fever_time)
	_fever_rain(delta)
	_fever_collect()
	_fever_streak_step(delta)
	if fever_time <= 0.0:
		_fever_end()


## 몸이 닿은 코인을 줍는다: 상승 속도가 조금 붙고 골드가 지갑으로 날아간다.
func _fever_collect() -> void:
	var c := player.position
	var got := 0
	for st in fever_coins:
		if st[2]:
			continue
		if c.distance_to(st[0] as Vector2) > FEVER_COIN_R + Player.SIZE * 0.5:
			continue
		st[2] = true
		st[1] = 0.0
		got += 1
		fever_boost = minf(fever_boost + FEVER_COIN_BOOST, FEVER_BOOST_MAX)
		ore_gold += FEVER_COIN_GOLD
		GameState.add_currency(FEVER_COIN_GOLD, false)
		EventBus.ore_collected.emit(FEVER_COIN_GOLD, st[0] as Vector2)  # 보드 로컬 좌표
		_add_score(FEVER_COIN_GOLD)
	if got > 0:
		GameState.haptic(0.3, 0.08)
		# 주울수록 음이 올라간다 — 연속으로 주워 담는 리듬이 들린다.
		Sfx.play("coin", 1.0 + 0.03 * float(mini(ore_gold / FEVER_COIN_GOLD, 24)))


## 아래로 흐르는 속도선을 흘려 보낸다 — "빠르게 오르고 있다"를 말하는 연출.
func _fever_streak_step(delta: float) -> void:
	for st in fever_streaks:
		st[1] += st[3] * delta
	fever_streaks = fever_streaks.filter(
			func(st: Array) -> bool: return st[1] < player.position.y + view_below)
	if fever_streaks.size() < 64:
		for _i in 7:
			var x := randf() * COLS * CELL
			var y := player.position.y - view_below - randf() * CELL * 8.0
			# 길이·속도를 넓게 흩어 놓으면 층이 생겨 깊이감이 난다.
			fever_streaks.append([x, y, CELL * (1.4 + randf() * 3.4), 1700.0 + randf() * 1500.0])


## 종료: 발밑에 착지 발판을 깔고 판을 돌려준다. 발판이 없으면 오른 만큼 도로
## 떨어져 용암에 빠지므로 "안전하게 벌었다"는 약속이 깨진다.
func _fever_end() -> void:
	fever_time = 0.0
	fever_near = 0.0
	fever_coins.clear()
	fever_streaks.clear()
	_fever_lay_floor()
	shake(6.0)
	GameState.haptic(0.5, 0.15)
	EventBus.fever_changed.emit(0.0, 0.0)


## 착지 바닥: 고양이 발밑에 **우물 폭 전체를 막은 암반**을 깐다. 3칸짜리
## 발판은 수십 칸 상공에 뜬 작은 섬이라 한 발만 헛디디면 그대로 추락이었다 —
## 피버가 벌어 준 높이가 통째로 날아가면 "안전하게 벌었다"는 약속이 깨진다.
## 구멍 없이 꽉 채우고, 대신 `anchor`에 올려 **지워지지도 부서지지도 않게** 한다
## (`_clear_lines()`는 앵커가 낀 줄을 건너뛰고, `break_cell_in_rect()`는 거절한다).
func _fever_lay_floor() -> void:
	var feet := player.position.y + Player.SIZE / 2.0
	# 발끝이 걸친 줄이 아니라 그 **바로 아래** 줄이다 — 발끝 줄에 깔면 몸이 바닥에
	# 파묻힌 채 깨어나 그대로 깔림 판정이 난다.
	var row := int(ceil(feet / CELL))
	var body := player.rect()
	var laid: Array = []
	for x in COLS:
		var c := Vector2i(x, row)
		if grid.has(c) or _cell_rect(c).intersects(body):
			continue
		grid[c] = Board.PIECES[randi() % Board.PIECES.size()]
		anchor[c] = true
		laid.append(c)
	if not laid.is_empty():
		lock_flash.append([laid, 0.0, Color(1.0, 0.95, 0.7)])
		_spawn_dust(Vector2((COLS * CELL) * 0.5, float(row) * CELL), 14, 1.0)


## Endless: line clears fight the lava — every clear shoves it back down,
## scaling steeply with multi-line clears.
func _endless_line_reward(cleared: int) -> void:
	lava_y += LAVA_PUSH[cleared] * CELL
	# 줄 클리어가 골드러시 게이지의 주 수입원이다 — 4줄 한 방이면 절반이 넘는다.
	_fever_gain(FEVER_LINE_GAIN[cleared] + FEVER_COMBO_GAIN * float(maxi(combo - 1, 0)))


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
			var c := Vector2i(x, y)
			# 피버 암반이 낀 줄은 절대 지워지지 않는다 — 벌어 준 높이를 지키는 바닥이다.
			if not grid.has(c) or anchor.has(c):
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
	# 고정 우물은 줄 단위로 통째 내린다. 무한은 줄만 비우고, 뒤에서 _settle_grid()가
	# 받칠 것을 잃은 덩어리만 내려앉힌다 (떠 있는 발판 모양을 그대로 지킨다).
	var collapse := mode != Mode.ENDLESS
	var new_grid := {}
	var new_cracked := {}
	var new_ore := {}
	var new_anchor := {}
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
		if anchor.has(c):
			new_anchor[dest] = true
	ore = new_ore
	grid = new_grid
	cracked = new_cracked
	anchor = new_anchor
	if not collapse:
		_settle_grid()
	return full_rows.size()


# --- 무한: 사라진 칸 메우기 -----------------------------------------------------
## 블록이 사라진 자리를 빈 구멍으로 남겨 두지 않는다 — 받칠 것을 잃은 칸 덩어리가
## 아래로 내려앉는다. 덩어리 = 상하좌우로 이어진 칸 묶음이라 칸이 따로 흘러내리지
## 않고 발판이 통째로 내려온다. 줄 클리어와 블록 파괴가 같은 길로 모인다.


## 이어진 칸 묶음들 (4방향 연결).
func _grid_components() -> Array:
	var seen := {}
	var comps: Array = []
	for start: Vector2i in grid:
		if seen.has(start):
			continue
		seen[start] = true
		var comp: Array = []
		var stack: Array = [start]
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			comp.append(c)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0),
					Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = c + d
				if grid.has(q) and not seen.has(q):
					seen[q] = true
					stack.append(q)
		comps.append(comp)
	return comps


## 지금 받쳐 주는 것이 없는 칸들 (바닥에 닿았거나, 받쳐진 덩어리 위에 얹힌
## 덩어리는 제외). 지지는 덩어리를 타고 위로 번진다.
func _unsupported_cells() -> Dictionary:
	var comps := _grid_components()
	var owner := {}
	for i in comps.size():
		for c: Vector2i in comps[i]:
			owner[c] = i
	var held: Array[bool] = []
	held.resize(comps.size())
	for i in comps.size():
		for c: Vector2i in comps[i]:
			# 우물 바닥에 닿았거나, 피버가 깔아 준 앵커 바닥을 품고 있다.
			if c.y >= rows - 1 or anchor.has(c):
				held[i] = true
				break
	var spread := true
	while spread:
		spread = false
		for i in comps.size():
			if held[i]:
				continue
			for c: Vector2i in comps[i]:
				var below: Vector2i = c + Vector2i(0, 1)
				if owner.has(below) and held[owner[below]]:
					held[i] = true
					spread = true
					break
	var out := {}
	for i in comps.size():
		if held[i]:
			continue
		for c: Vector2i in comps[i]:
			out[c] = true
	return out


## 뜬 덩어리를 한 칸씩 다 같이 내려 모두 받쳐질 때까지 앉힌다.
## 반환값은 내려간 칸 수(0이면 그대로). 떨어진 자리에는 착지 연출이 붙는다.
func _settle_grid() -> int:
	var drop := 0
	var sunk := {}  # 내려앉은 칸 (지금 자리 기준)
	while drop < rows:
		var falling := _unsupported_cells()
		if falling.is_empty():
			break
		var down := Vector2i(0, 1)
		var new_grid := {}
		var new_cracked := {}
		var new_ore := {}
		var new_anchor := {}
		for c: Vector2i in grid:
			var dest: Vector2i = c + down if falling.has(c) else c
			new_grid[dest] = grid[c]
			if cracked.has(c):
				new_cracked[dest] = true
			if ore.has(c):
				new_ore[dest] = true
			if anchor.has(c):
				new_anchor[dest] = true
		grid = new_grid
		cracked = new_cracked
		ore = new_ore
		anchor = new_anchor
		# 러시 종료 폭발 대기줄도 같이 따라간다 — 자리가 어긋나면 금값을 못 준다.
		var next_sunk := {}
		for c: Vector2i in sunk:
			next_sunk[c + down if falling.has(c) else c] = true
		for c: Vector2i in falling:
			next_sunk[c + down] = true
		sunk = next_sunk
		drop += 1
	if drop == 0:
		return 0
	var cells := sunk.keys()
	if not cells.is_empty():
		_impact(cells, Board.COLORS[grid[cells[0]]], clampf(drop * 0.18, 0.15, 0.9))
	if playing:
		_free_player_from_grid()  # 내려앉은 스택에 깔렸으면 밀어내거나 깔림 판정
	queue_redraw()
	return drop


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
	if anchor.has(best):
		# 피버 암반은 부서지지 않는다 — 둔탁하게 튕길 뿐.
		shake(2.0)
		Sfx.play("land")
		return false
	if ore.has(best):
		# 골드 블록은 한 방에 터진다 — 두 번 쳐야 하면 리듬이 죽는다.
		_break_fx_at(best, Board.COLORS[grid[best]])
		cracked.erase(best)
		grid.erase(best)
		break_fx.append([best, 0.0])
		_bank_ore(best, ORE_VALUE)
		_fever_gain(FEVER_ORE_GAIN)
		_add_score(BREAK_SCORE)
		Sfx.play("break")
		if mode == Mode.ENDLESS:
			_settle_grid()  # 판 구멍을 남기지 않는다 — 위가 내려앉는다
		queue_redraw()
		return true
	if cracked.has(best):
		_break_fx_at(best, Board.COLORS[grid[best]])
		cracked.erase(best)
		grid.erase(best)
		anchor.erase(best)
		break_fx.append([best, 0.0])
		_add_score(BREAK_SCORE)
		_fever_gain(FEVER_BREAK_GAIN)  # 부수는 것도 무한의 동사다
		Sfx.play("break")
		if mode == Mode.ENDLESS:
			_settle_grid()
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
	piece_ore = randi() % Board.SHAPES[piece_type][0].size() if randf() < ORE_CHANCE else -1
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
		rise_off = clampf(rise_off - float(target.y - piece_pos.y), -2.5, 2.5)
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
			if anchor.has(c):
				_draw_bedrock(c)
				continue
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
	_draw_fever_glow(w, top, h)
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
	if fever_near <= 0.0 or fever_on():
		return
	var pulse := 0.55 + 0.45 * sin(lava_phase * 13.0)
	var band := CELL * 0.7
	for i in 4:
		var a := fever_near * pulse * 0.26 * (1.0 - float(i) / 4.0)
		draw_rect(Rect2(0.0, lava_y - band * (i + 1), w, band), Color(1.0, 0.42, 0.22, a))


## 피버타임 연출. 화려하게 가되 어두운 구덩이에 반투명 색을 넓게 깔면 잿빛
## 얼룩이 되므로, 밝은 것은 전부 "선과 점"으로 그린다 — 아래로 흐르는 속도선,
## 무지개로 도는 벽 기둥, 별. 발동 순간의 섬광만 예외로 화면을 통째로 덮는다.
func _draw_fever_glow(w: float, top: float, h: float) -> void:
	if not fever_on() and fever_flash <= 0.0:
		return
	var bottom := h + (view_below * 2.0 if mode == Mode.ENDLESS else 0.0)
	if fever_flash > 0.0:
		var f := fever_flash / FEVER_FLASH_TIME
		draw_rect(Rect2(0.0, top, w, bottom - top), Color(1.0, 0.72, 0.92, 0.5 * f))
	if not fever_on():
		return
	var fade := clampf(fever_time / 0.8, 0.0, 1.0)  # 끝나기 직전엔 잦아든다
	# 벽 기둥이 무지개로 돈다 — 색이 흐르는 것만으로 "지금은 다른 시간"이 된다.
	for side in 2:
		var x := 8.0 if side == 0 else w - 8.0
		var seg := 7
		for i in seg:
			var t0 := top + (bottom - top) * float(i) / float(seg)
			var t1 := top + (bottom - top) * float(i + 1) / float(seg)
			var hue := fposmod(fever_phase * 0.8 + float(i) * 0.13 + float(side) * 0.5, 1.0)
			draw_line(Vector2(x, t0), Vector2(x, t1),
					Color.from_hsv(hue, 0.62, 1.0, 0.9 * fade), 16.0)
	# 속도선: 아래로 흘러 내려가 "빠르게 오르고 있다"를 말한다.
	for st: Array in fever_streaks:
		var y := st[1] as float
		draw_line(Vector2(st[0], y), Vector2(st[0], y + (st[2] as float)),
				Color(1.0, 1.0, 1.0, 0.30 * fade), 3.0)
	_draw_fever_coins(fade)


## 쏟아지는 골드 코인. 아직 안 주운 것은 빙글 돌며 떨어지고(폭이 좁아졌다
## 넓어졌다 = 옆면이 보이는 회전), 주운 것은 금빛 링이 되어 퍼진다.
func _draw_fever_coins(fade: float) -> void:
	for st: Array in fever_coins:
		var at := st[0] as Vector2
		var age := st[1] as float
		if st[2]:
			if age > 0.35:
				continue
			var t := age / 0.35
			draw_arc(at, FEVER_COIN_R * (0.6 + t * 1.9), 0.0, TAU, 22,
					Color(1.0, 0.95, 0.6, (1.0 - t) * 0.9), 4.0)
			continue
		var spin := st[4] as float
		var wx := maxf(absf(cos(spin)), 0.18)
		var r := FEVER_COIN_R * 0.8
		var ink := Color(0.17, 0.16, 0.20, fade)
		var face := Color(1.0, 0.84, 0.30, fade)
		var rim := Color(0.86, 0.62, 0.16, fade)
		var pts := PackedVector2Array()
		for i in 20:
			var ang := float(i) * TAU / 20.0
			pts.append(at + Vector2(cos(ang) * r * wx, sin(ang) * r))
		draw_colored_polygon(pts, face if cos(spin) >= 0.0 else rim)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, ink, 2.5)
		if wx > 0.45:
			# 앞면일 때만 발바닥 각인 — 코인이 "냥이 골드"임을 말한다
			var pad := Color(0.86, 0.62, 0.16, fade * clampf((wx - 0.45) * 3.0, 0.0, 1.0))
			draw_circle(at + Vector2(0.0, r * 0.15), r * 0.30, pad)
			for k in 3:
				var a := -PI * 0.5 + (float(k) - 1.0) * 0.75
				draw_circle(at + Vector2(cos(a) * wx, sin(a)) * r * 0.42, r * 0.13, pad)
		draw_circle(at + Vector2(-r * 0.3 * wx, -r * 0.3), r * 0.16, Color(1.0, 1.0, 0.9, 0.8 * fade))


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
	if fever_on():
		# 피버 동안은 구덩이 자체가 물든다 — 벽 기둥만으로는 6초가 시작됐는지
		# 눈에 안 들어온다. 색이 천천히 돌고, 끝나기 직전 0.8초에 걸쳐 식는다.
		var g := clampf(fever_time / 0.8, 0.0, 1.0)
		var hue := fposmod(fever_phase * 0.25, 1.0)
		top_col = top_col.lerp(Color.from_hsv(hue, 0.55, 0.46), 0.72 * g)
		bot_col = bot_col.lerp(Color.from_hsv(fposmod(hue + 0.12, 1.0), 0.7, 0.2), 0.9 * g)
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


## SRS 회전축 — 도형이 든 박스의 한가운데다(JLSTZ/S/T/Z는 3x3, I는 4x4).
## 칸 4개의 무게중심이 아니다: 무게중심은 회전판마다 옮겨 다녀서 그걸 축으로
## 삼으면 도는 게 아니라 휘둘리는 것처럼 보인다.
func _spin_pivot(t: String, pos: Vector2i) -> Vector2:
	var half := 2.0 if t == "I" else 1.5
	return (Vector2(pos) + Vector2.ONE * half) * CELL


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
	# 가로·세로 잔여 이동 · 회전 잔여 각도 · 착지 눌림이 변환에 실린다.
	# 회전은 SRS 회전축을 중심으로, 착지 눌림은 도형 한가운데를 중심으로 —
	# 두 축이 달라서 변환을 따로 만들어 곱한다 (칸은 제자리 좌표로 그린다).
	var pivot := _spin_pivot(piece_type, piece_pos)
	var m := Transform2D(spin_off, Vector2.ONE, 0.0, Vector2.ZERO)
	m = m.translated_local(-pivot).translated(pivot + Vector2(slide_off, rise_off) * CELL)
	var sq := land_squash * land_squash
	if sq > 0.0:
		var cen := Vector2.ZERO
		for c: Vector2i in cells:
			cen += _cell_rect(c).get_center()
		cen /= float(maxi(cells.size(), 1))
		var sc := Vector2(1.0 + 0.22 * sq, 1.0 - 0.26 * sq)
		m *= Transform2D(0.0, sc, 0.0, Vector2.ZERO).translated_local(-cen).translated(cen)
	draw_set_transform_matrix(m)
	for i in range(cells.size()):
		var c: Vector2i = cells[i]
		if mode == Mode.ENDLESS or c.y >= 0:
			var p := Vector2(c) * CELL
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
		var top_left := Vector2(piece_pos) * CELL + Vector2(slide_off, rise_off) * CELL
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


## 피버 암반: 지워지지도 부서지지도 않는 바닥. 회청색 돌 + 금 리벳으로 "다른
## 종류의 블록"임을 한눈에 말한다 — 부딪혀 보고 나서야 아는 건 늦다.
func _draw_bedrock(c: Vector2i) -> void:
	var p := Vector2(c) * CELL
	_draw_block(p, Color(0.33, 0.33, 0.40))
	var ink := Color(0.17, 0.16, 0.20)
	draw_rect(Rect2(p + Vector2.ONE, Vector2(CELL - 2.0, CELL - 2.0)), ink, false, 3.0)
	# 벽돌 줄눈 한 줄 + 네 귀퉁이 리벳
	draw_line(p + Vector2(4.0, CELL * 0.5), p + Vector2(CELL - 4.0, CELL * 0.5), ink, 2.0)
	draw_line(p + Vector2(CELL * 0.5, 4.0), p + Vector2(CELL * 0.5, CELL * 0.5), ink, 2.0)
	for dx in [10.0, CELL - 10.0]:
		for dy in [10.0, CELL - 10.0]:
			draw_circle(p + Vector2(dx, dy), 3.2, Color(0.95, 0.80, 0.35))
			draw_circle(p + Vector2(dx, dy), 3.2, ink, false, 1.2)


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
