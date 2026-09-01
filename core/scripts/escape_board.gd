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
	if _shutter_on():
		# Classic 레벨 클리어 연출: 셔터가 내려오는 동안 조작·낙하·판정 정지.
		_update_shutter(delta)
		shutter_pop = maxf(shutter_pop - delta / SHUTTER_POP_TIME, 0.0)
		for fx in break_fx:
			fx[1] += delta
		break_fx = break_fx.filter(func(fx: Array) -> bool: return fx[1] < BREAK_FX_TIME)
		_age_ore_fx(delta)
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
	for fx in break_fx:
		fx[1] += delta
	break_fx = break_fx.filter(func(fx: Array) -> bool: return fx[1] < BREAK_FX_TIME)
	_age_ore_fx(delta)
	if mode == Mode.ENDLESS:
		_update_endless(delta)
	queue_redraw()


## 무한의 계단도 스테이지 모드와 같은 크기의 우물에서 논다. 고정 우물 모드는
## 보드 노드를 화면에 맞춰 줄이지만(main.gd `_fit_board()`), 무한은 카메라가
## 그리므로 같은 배율을 카메라 줌으로 준다.
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
	lava_y -= _lava_speed() * delta
	lava_y = minf(lava_y, player.position.y + LAVA_MAX_GAP)
	var feet := player.position.y + Player.SIZE / 2.0
	if feet > lava_y:
		_kill_player()
		return
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
		if _resolve_piece_overlap():
			return


## Touched down: hold briefly in a shovable state before locking for real.
func _land() -> void:
	piece_state = PieceState.LANDED
	land_timer = 0.0


func _landed(delta: float) -> void:
	# Shoved off a ledge (or the ground cleared): resume falling.
	if not _piece_collides(piece_rot, piece_pos + Vector2i(0, 1), false):
		piece_state = PieceState.FALLING
		fall_timer = 0.0
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
		if _resolve_piece_overlap() or not playing:
			Sfx.play("shove")
			return true
	if moved:
		Sfx.play("shove")
	return moved


func _hard_drop() -> void:
	while playing and not _piece_collides(piece_rot, piece_pos + Vector2i(0, 1), false):
		piece_pos.y += 1
		if _resolve_piece_overlap():
			return
	if playing:
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
	_add_score(10 * level)
	var cleared := _clear_lines()
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


## Endless: line clears fight the lava — every clear shoves it back down,
## scaling steeply with multi-line clears.
## Height itself is never lost: _clear_lines leaves gaps instead of collapsing.
func _endless_line_reward(cleared: int) -> void:
	lava_y += LAVA_PUSH[cleared] * CELL


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
	for c: Vector2i in grid:
		break_fx.append([c, 0.0])
		# 셔터가 쓸어 간 금은 절반값이다 — 직접 깨서 먹는 쪽이 늘 이득이도록.
		_bank_ore(c, ORE_SWEEP_VALUE)
	if not grid.is_empty():
		Sfx.play("break", 0.75)
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
	# Endless keeps the stack floating: cleared rows become open gaps instead of
	# dropping everything above, so a clear never costs the climb its height.
	var collapse := mode != Mode.ENDLESS
	var new_grid := {}
	var new_cracked := {}
	var new_ore := {}
	for c in grid:
		if c.y in full_rows:
			break_fx.append([c, 0.0])
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
		cracked.erase(best)
		grid.erase(best)
		break_fx.append([best, 0.0])
		_bank_ore(best, ORE_VALUE)
		_add_score(BREAK_SCORE)
		Sfx.play("break")
		queue_redraw()
		return true
	if cracked.has(best):
		cracked.erase(best)
		grid.erase(best)
		break_fx.append([best, 0.0])
		_add_score(BREAK_SCORE)
		Sfx.play("break")
	else:
		cracked[best] = true
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
		piece_pos = target
		piece_rot = new_rot
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
	var show_hidden := mode == Mode.ENDLESS
	for c in grid:
		if show_hidden or c.y >= 0:
			_draw_cell(c, Board.COLORS[grid[c]])
			if ore.has(c):
				_draw_ore(_cell_rect(c).get_center())
			if cracked.has(c):
				_draw_crack(c)
	for fx in break_fx:
		var t: float = 1.0 - fx[1] / BREAK_FX_TIME
		var r := _cell_rect(fx[0]).grow(-CELL * 0.5 * (1.0 - t))
		draw_rect(r, Color(1.0, 1.0, 0.8, 0.7 * t))
	_draw_loose()
	if piece_type != "":
		_draw_piece()
	_draw_ore_fx()
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
	if shutter_row > 0:
		_draw_shutter(w)


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
	for i in range(cells.size()):
		var c: Vector2i = cells[i]
		if mode == Mode.ENDLESS or c.y >= 0:
			_draw_cell(c, color)
			if i == piece_ore:
				_draw_ore(_cell_rect(c).get_center(), color.a)
			if piece_state == PieceState.LANDED:
				draw_rect(_cell_rect(c).grow(-2.0),
						Color(1.0, 0.96, 0.8, 0.3 + 0.45 * pulse), false, 3.0)
	if piece_state == PieceState.TRACKING:
		var remain := ceili(_track_time() - track_timer)
		var top_left := Vector2(piece_pos) * CELL
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


func _draw_crack(c: Vector2i) -> void:
	var p := Vector2(c) * CELL
	var col := Color(1.0, 0.96, 0.84, 0.65)
	draw_polyline(PackedVector2Array([
		p + Vector2(14, 8), p + Vector2(30, 26), p + Vector2(22, 40), p + Vector2(38, 56),
	]), col, 2.5)
	draw_polyline(PackedVector2Array([
		p + Vector2(48, 12), p + Vector2(36, 30), p + Vector2(50, 44),
	]), col, 2.0)


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
