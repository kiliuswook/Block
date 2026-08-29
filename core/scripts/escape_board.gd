class_name EscapeBoard
extends Node2D
## Story mode pit: a tetromino tracks the player's column at the top of the
## field, free-falls after a countdown, and locks into the grid. The player
## climbs the stack and escapes through the door at the top. Getting caught
## under a falling piece is death. Reuses SHAPES/KICKS/COLORS from Board.
## In story mode (single player) the run walks through StoryStages: each
## stage has a tutorial goal (escape / lines / shoves / survive) and the exit
## doors stay locked until the goal is met. Split screen reuses this board as
## a plain escape race with no stage logic.

## Split screen: this board's round result (true = this player escaped/won).
signal finished(win: bool)

enum PieceState { TRACKING, FALLING, LANDED }
enum Mode { STORY, ENDLESS, VERSUS, CLASSIC, PICNIC }

const CatSprite := preload("res://core/scripts/cat_sprite.gd")

const COLS := 10
const ROWS := 14  # story stage data coordinate base — prefills/door_row are
				  # authored on the original 14-row pit and shifted at load
const PIT_ROWS := 20  # actual well height, every mode — standard tetris
const CELL := 64.0
const DOOR_ROW_TOP := 0
const DOOR_ROW_BOTTOM := 1
const TRACK_TIME_BASE := 5.0
const TRACK_TIME_MIN := 2.0
const TRACK_STEP := 0.07
const FALL_INTERVAL_BASE := 0.26
const FALL_INTERVAL_MIN := 0.1
const ESCAPE_SCORE := 1000
const LINE_SCORES := [0, 100, 300, 500, 800]
const CRUSH_MARGIN := 6.0
const SOFT_DROP_FACTOR := 4.0
const DROP_DOUBLE_TAP := 0.3
const BREAK_SCORE := 20
const BREAK_FX_TIME := 0.3
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
const BLAST_FX_RADIUS := 16.0  # blast: cells beyond this erase without FX (off-screen)
const BLAST_FX_WAVE := 0.018  # blast ripple: FX delay per cell of distance from the cat
const LAVA_PUSH := [0, 2, 5, 9, 15]  # endless: lava shoved down this many cells per clear size
# Jelly picnic (casual): a 2-minute no-death timed run. Pieces fall slow and
# never speed up; anything that would kill the cat pops like jelly instead.
const PICNIC_TIME := 120.0
const PICNIC_TRACK_TIME := 6.0
const PICNIC_FALL_INTERVAL := 0.34
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
const P2_DAS_DELAY := 0.17  # versus: held-direction delay before auto-repeat
const P2_DAS_REPEAT := 0.06
const VERSUS_RAMP := 7  # versus: difficulty +1 per this many pieces

var grid := {}  # Vector2i -> piece type
var cracked := {}  # Vector2i -> true; first break hit cracks, second destroys
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
var mode := Mode.STORY
var rows := PIT_ROWS  # pit height in cells
var best_height := 0
## 이 보드가 이번 판에 번 점수. 분할 화면은 보드마다 따로 세고(지갑 하나 원칙에
## 걸리는 GameState.score와 달리 좌석별 기록이 필요하다), 1인 플레이에서는
## GameState.score와 같은 값을 따라간다.
var run_score := 0
var drop_tap_time := -1e9
var lava_y := 0.0
var lava_phase := 0.0
var p2_das_timer := 0.0
var versus_pieces := 0
# Endless: once its countdown ends a piece detaches and falls on its own (no
# more rotation), so the next piece starts tracking immediately. Each entry:
# {t: type, r: rot, p: pos, s: PieceState, ft: fall timer, lt: land timer}.
var loose: Array = []
# Picnic: time left on the clock.
var picnic_time := 0.0
# Replay recording: 10Hz state frames (cat + piece + score) plus grid-diff
# events, exported via rec_export(). Story records one stage at a time.
const REC_STEP := 0.1
const REC_MAX_FRAMES := 6000  # ~10 minutes, then the recording just stops
const REC_STRIDE := 8
var rec_frames := PackedInt32Array()
var rec_events: Array = []
var _rec_shadow := {}
var _rec_timer := 0.0
var _rec_on := false
# Split screen: one board per player — global EventBus signals are muted and
# the piece is driven by this board's own action set instead of the defaults.
var split := false
var act_rot_cw := "rotate_cw"
var act_rot_ccw := "rotate_ccw"
var act_drop := "soft_drop"
# Story mode: the active stage config and its goal/door state.
var stage := {}
var door_left := true
var door_right := true
var door_row := DOOR_ROW_TOP  # top row of the 2-row exit (story stages move it)
var goal_done := true  # true once the doors are open (escape goals start true)
var goal_count := 0
var survive_time := 0.0

@onready var player: Player = $Player
@onready var cam: Camera2D = get_node_or_null("Cam")


func start_game() -> void:
	mode = GameState.mode as Mode
	split = GameState.split
	rows = PIT_ROWS
	grid.clear()
	cracked.clear()
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
	versus_pieces = 0
	p2_das_timer = 0.0
	lava_y = rows * CELL + LAVA_START_OFFSET
	lava_phase = 0.0
	loose.clear()
	picnic_time = 0.0
	is_paused = false
	stage = {}
	door_left = true
	door_right = true
	# Non-story exits keep their original height-above-floor: the pit grew
	# from 14 to 20 rows, so "top" doors ride 6 rows down with the old summit.
	# Classic keeps its sealed slabs at the true top corners.
	door_row = DOOR_ROW_TOP if mode == Mode.CLASSIC else DOOR_ROW_TOP + (PIT_ROWS - ROWS)
	goal_done = true
	GameState.reset()
	if cam:
		cam.enabled = mode == Mode.ENDLESS
		cam.position = Vector2(COLS * CELL / 2.0, rows * CELL / 2.0)
		cam.reset_smoothing()
	if _story():
		# Resume from the next uncleared stage; a finished story replays from 1.
		level = GameState.story_stage % StoryStages.TOTAL + 1
		_apply_stage()
	elif mode == Mode.CLASSIC:
		# Arcade pit: both exits sealed — clear the level's 10 lines and survive
		# with the usual cat controls. Each level is a fresh, harder board.
		door_left = false
		door_right = false
		_classic_setup_level(1)
	elif mode == Mode.PICNIC:
		# Sealed jelly pit: no exits, no death — just a timed run.
		door_left = false
		door_right = false
		picnic_time = PICNIC_TIME
	elif mode == Mode.ENDLESS and not split:
		# Consume boosts bought for this run (shop / death-popup chips).
		for b: String in GameState.take_boosts():
			match b:
				"warmup":
					_build_warmup_stairs()
	player.respawn(_spawn_point())
	player.visible = true  # a restart mid-shutter must not leave the cat hidden
	_spawn_piece()
	playing = true
	_rec_reset()
	if not split:
		EventBus.game_started.emit()
		EventBus.lines_changed.emit(0)
		EventBus.level_changed.emit(level)
		EventBus.height_changed.emit(0)
		if mode == Mode.CLASSIC:
			_classic_announce_level()
	queue_redraw()


## 점수 한 곳: 보드 자기 몫(run_score)에 쌓고, 1인 플레이에서는 그대로 HUD·지갑이
## 읽는 GameState.score에도 반영한다. 분할 화면은 좌석마다 점수가 따로라 공용
## 값을 건드리지 않는다 — 최종 승자의 점수만 main.gd가 기록으로 올린다.
func _add_score(n: int) -> void:
	run_score += n
	if not split:
		GameState.score += n


## Story stage logic runs only in single-player story mode; the split-screen
## escape race shares this board but keeps the plain always-open-doors rules.
func _story() -> bool:
	return mode == Mode.STORY and not split


func _goal_type() -> String:
	return str(stage.get("goal", {}).get("type", "escape"))


## Loads the current stage (level) config: goal, doors, prefilled grid.
func _apply_stage() -> void:
	stage = StoryStages.get_stage(level)
	goal_count = 0
	survive_time = 0.0
	goal_done = _goal_type() == "escape"
	# Stage data is authored on the 14-row pit: shift doors and prefills down
	# so every height-above-floor (and thus the balance) stays identical.
	var shift := rows - ROWS
	door_row = clampi(int(stage.get("door_row", 0)) + shift, 0, rows - 2)
	_set_doors(goal_done)
	grid.clear()
	cracked.clear()
	var pf: Dictionary = stage.get("prefill_cells", {})
	for c: Vector2i in pf:
		grid[c + Vector2i(0, shift)] = pf[c]
	bag.clear()
	next_type = ""
	EventBus.story_stage_started.emit(level)
	EventBus.story_progress_changed.emit(
			StoryStages.progress_text(stage, 0, goal_done))


func _set_doors(open: bool) -> void:
	var side := str(stage.get("door", "both"))
	door_left = open and side != "right"
	door_right = open and side != "left"


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
		queue_redraw()
		return
	run_time += delta  # only ticks while the board is actually being played
	if mode == Mode.VERSUS:
		_p2_input(delta)
	else:
		if Input.is_action_just_pressed(act_rot_cw):
			_try_rotate(1)
		if Input.is_action_just_pressed(act_rot_ccw):
			_try_rotate(-1)
	if piece_type != "":  # no-piece tutorial stages skip the piece machine
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
	if _story() and playing and not goal_done and _goal_type() == "survive":
		var prev := int(survive_time)
		survive_time += delta
		if int(survive_time) != prev:
			goal_count = int(survive_time)
			EventBus.story_progress_changed.emit(
					StoryStages.progress_text(stage, goal_count, false))
		if survive_time >= float(stage.goal.time):
			_story_goal_done()
	if mode == Mode.ENDLESS:
		_update_endless(delta)
	elif mode == Mode.PICNIC:
		_update_picnic(delta)
	elif playing and (player.position.x < -CELL * 0.6
			or player.position.x > COLS * CELL + CELL * 0.6):
		if mode == Mode.VERSUS:
			_versus_over(1)
		else:
			_escape()
	queue_redraw()


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
	var cam_offset := usable / 1.5 - vp.y / 2.0  # cat screen y = usable * 2/3
	# Camera floor: at run start the pit bottom sits just above the screen
	# bottom (landscape) / the touch zone (portrait), never behind them.
	var bottom_sy := vp.y - 60.0 if vp.x > vp.y else vp.y - 540.0
	var cam_floor := rows * CELL - (bottom_sy - vp.y / 2.0)
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
		if not split:
			EventBus.height_changed.emit(best_height)


# --- Jelly picnic (casual) ------------------------------------------------------


func _update_picnic(delta: float) -> void:
	lava_phase += delta
	picnic_time -= delta
	if picnic_time <= 0.0:
		picnic_time = 0.0
		playing = false
		Sfx.play("milestone")
		if split:
			finished.emit(false)
		else:
			EventBus.game_over.emit()
		queue_redraw()
		return


## Picnic never kills: whatever pinned the cat pops like jelly instead. The
## falling piece bursts, nearby locked cells shatter, and play just continues.
## big = the stack overflowed the pit: blow the whole thing up.
func _picnic_rescue(big := false) -> void:
	var center := Vector2i((player.position / CELL).floor())
	Sfx.play("break")
	if big:
		_blast_all_cells(center)
	if piece_type != "" and piece_state != PieceState.TRACKING:
		for c in _cells(piece_type, piece_rot, piece_pos):
			break_fx.append([c, 0.0])
	_erase_cells_around(center, 1)
	if not _shove_player_out_of_grid():
		_erase_cells_around(center, 2)
		_shove_player_out_of_grid()
	_clear_spawn_window()
	_spawn_piece()
	queue_redraw()


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
## The side walls open at the top rows (one exit each), but only while that
## door is unlocked — story goals keep them shut until the goal is met.
func _rect_hits_bounds(r: Rect2) -> bool:
	if r.position.x < 0.0 \
			and not (mode != Mode.ENDLESS and door_left and _rect_in_side_door(r)):
		return true
	if r.end.x > COLS * CELL \
			and not (mode != Mode.ENDLESS and door_right and _rect_in_side_door(r)):
		return true
	if r.end.y > rows * CELL:
		return true
	if mode != Mode.ENDLESS and r.position.y < 0.0:
		return true
	return false


func _rect_in_side_door(r: Rect2) -> bool:
	return r.position.y >= door_row * CELL and r.end.y <= (door_row + 2) * CELL


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
	if Input.is_action_just_pressed(_drop_action()):
		drop_tap_time = Time.get_ticks_msec() / 1000.0
		_release_piece()
		return
	track_timer += delta
	track_move_timer += delta
	if mode == Mode.ENDLESS:
		piece_pos.y = _endless_spawn_row()
	while track_move_timer >= TRACK_STEP:
		track_move_timer -= TRACK_STEP
		if mode == Mode.VERSUS:
			continue  # versus: P2 steers the piece by hand instead
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
			"s": PieceState.FALLING, "ft": 0.0, "lt": 0.0})
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
	if Input.is_action_pressed(_drop_action()):
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
					_merge_piece(e.t, e.r, e.p)
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
	# piece has nowhere to start falling. In versus that's on P2 — cat wins.
	if _piece_collides(piece_rot, piece_pos, false):
		if mode == Mode.VERSUS:
			_versus_over(1)
		else:
			_kill_player()
		return
	_resolve_piece_overlap()


func _fall(delta: float) -> void:
	# Double-tap soft drop slams the piece all the way down.
	if Input.is_action_just_pressed(_drop_action()):
		var now := Time.get_ticks_msec() / 1000.0
		if now - drop_tap_time <= DROP_DOUBLE_TAP:
			drop_tap_time = -1e9
			_hard_drop()
			return
		drop_tap_time = now
	fall_timer += delta
	var interval := _fall_interval()
	if Input.is_action_pressed(_drop_action()):
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
	if Input.is_action_just_pressed(_drop_action()):
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
			_story_add_progress("shoves", 1)
			Sfx.play("shove")
			return true
	if moved:
		_story_add_progress("shoves", 1)
		Sfx.play("shove")
	return moved


## Versus: P2 drives the piece directly — A/D step (with DAS auto-repeat),
## W/Q rotate, S drop. The drop key itself is handled by the state handlers.
func _p2_input(delta: float) -> void:
	if piece_type == "":
		return
	if Input.is_action_just_pressed("p2_rot_cw"):
		_try_rotate(1)
	if Input.is_action_just_pressed("p2_rot_ccw"):
		_try_rotate(-1)
	var axis := int(Input.get_axis("p2_left", "p2_right"))
	if Input.is_action_just_pressed("p2_left") or Input.is_action_just_pressed("p2_right"):
		_p2_step(axis)
		p2_das_timer = P2_DAS_DELAY
	elif axis != 0:
		p2_das_timer -= delta
		if p2_das_timer <= 0.0:
			p2_das_timer = P2_DAS_REPEAT
			_p2_step(axis)


func _p2_step(dir: int) -> void:
	if dir == 0 or not playing:
		return
	var ignore := piece_state == PieceState.TRACKING
	if _piece_collides(piece_rot, piece_pos + Vector2i(dir, 0), ignore):
		return
	piece_pos.x += dir
	if not ignore:
		_resolve_piece_overlap()


## Versus splits the drop key: the cat keeps ↓ for fast fall, P2 gets S.
func _drop_action() -> String:
	return "p2_drop" if mode == Mode.VERSUS else act_drop


func _versus_over(winner: int) -> void:
	Sfx.play("escape" if winner == 1 else "death")
	if winner == 2:
		player.die()
	playing = false
	EventBus.versus_round_over.emit(winner)
	queue_redraw()


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
	if _merge_piece(piece_type, piece_rot, piece_pos):
		_spawn_piece()


## Locks a piece's cells into the grid: overflow, line clears and scoring.
## Serves both the active piece and detached (loose) endless pieces. Returns
## false when the game ended — or a rescue already spawned the next piece —
## and the caller must not spawn another.
func _merge_piece(t: String, r: int, pos: Vector2i) -> bool:
	var overflow := false
	for c in _cells(t, r, pos):
		grid[c] = t
		cracked.erase(c)
		if c.y < 0:
			overflow = true
	if overflow and mode != Mode.ENDLESS:
		# Stack spilled over the top: cat dies in escape, P2 loses in versus.
		if mode == Mode.PICNIC:
			# Picnic: the whole overstuffed stack bursts and the hunt goes on.
			_picnic_rescue(true)
			return false
		if mode == Mode.VERSUS:
			_versus_over(1)
		else:
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
		_story_add_progress("lines", cleared)
		if not split:
			EventBus.lines_changed.emit(total_lines)
		if _shutter_on():
			return true  # 레벨 클리어 연출 중: 깔림 판정 없이 셔터가 내려온다
		if not _free_player_from_grid():
			return false
	return true


## Warmup boost: a staircase against the left wall reaching 5 floors up, so
## the run starts with a quick climb instead of a bare pit. Columns only —
## never a full row, so it can't be cashed in as an instant line clear.
func _build_warmup_stairs() -> void:
	for i in range(1, 6):
		var x := 5 - i  # x=4 is 1 tall ... x=0 is 5 tall
		for d in range(i):
			grid[Vector2i(x, rows - 1 - d)] = "J"


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
	loose.clear()
	piece_type = ""
	_fill_garbage(level_garbage)


## Tells the HUD which board is up (start of run and every new level).
func _classic_announce_level() -> void:
	if split:
		return  # 분할 화면에는 아케이드 HUD가 없다 — 좌석 라벨이 대신한다
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
		for x in range(COLS):
			if holes.has(x):
				continue
			grid[Vector2i(x, y)] = Board.PIECES[randi() % Board.PIECES.size()]


## A clear landed in classic: bank it toward this level's 10 lines. Meeting the
## quota rolls the shutter down and closes the board out.
func _classic_line_progress(cleared: int) -> void:
	level_lines += cleared
	var quota := Board.classic_quota(level)
	if not split:
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
	if not split:
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
	if not grid.is_empty():
		Sfx.play("break", 0.75)
	if not split:
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
	_rec_on = not split and mode != Mode.VERSUS
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
			"rows": rows, "door": door_row, "dl": door_left, "dr": door_right,
			"level": level,
			"frames": rec_frames.duplicate(), "events": rec_events.duplicate(true)}


# --- Story goals ----------------------------------------------------------------


## Counts progress toward the stage goal (lines cleared / pieces shoved).
func _story_add_progress(kind: String, amount: int) -> void:
	if not _story() or goal_done or _goal_type() != kind:
		return
	goal_count += amount
	if goal_count >= int(stage.goal.count):
		_story_goal_done()
	else:
		EventBus.story_progress_changed.emit(
				StoryStages.progress_text(stage, goal_count, false))


## Goal met: unlock the stage's doors and tell the HUD.
func _story_goal_done() -> void:
	goal_done = true
	_set_doors(true)
	Sfx.play("door")
	EventBus.story_doors_opened.emit()
	EventBus.story_progress_changed.emit(
			StoryStages.progress_text(stage, goal_count, true))
	queue_redraw()


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
	for c in grid:
		if c.y in full_rows:
			break_fx.append([c, 0.0])
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
	if cracked.has(best):
		cracked.erase(best)
		grid.erase(best)
		break_fx.append([best, 0.0])
		_add_score(BREAK_SCORE)
		_story_add_progress("breaks", 1)
		Sfx.play("break")
	else:
		cracked[best] = true
		Sfx.play("crack")
	queue_redraw()
	return true


func _spawn_piece() -> void:
	# Movement-tutorial stages: no tetromino at all.
	if _story() and stage.get("no_pieces", false):
		piece_type = ""
		next_type = ""
		if not split:
			EventBus.next_piece_changed.emit("")
		return
	if next_type == "":
		next_type = _draw_from_bag()
	piece_type = next_type
	next_type = _draw_from_bag()
	if not split:
		EventBus.next_piece_changed.emit(next_type)
	piece_rot = 0
	var spawn_row := _endless_spawn_row() if mode == Mode.ENDLESS else 0
	if mode == Mode.VERSUS:
		# Neutral center spawn: P2 steers it from there.
		piece_pos = Vector2i(COLS / 2 - 2, spawn_row)
		versus_pieces += 1
	else:
		piece_pos = Vector2i(clampi(int(player.position.x / CELL) - 2, 0, COLS - 4), spawn_row)
	piece_state = PieceState.TRACKING
	track_timer = 0.0
	track_move_timer = 0.0
	# Classic Tetris block out: the new piece spawns inside the stack.
	if _piece_collides(piece_rot, piece_pos, false):
		if mode == Mode.VERSUS:
			_versus_over(1)
		else:
			_kill_player()


func _draw_from_bag() -> String:
	if bag.is_empty():
		# Early story stages restrict the bag to a couple of simple pieces.
		if _story() and stage.has("pieces"):
			bag = (stage.pieces as Array).duplicate()
		else:
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
		piece_pos = target
		piece_rot = new_rot
		return


func _piece_collides(rot: int, pos: Vector2i, ignore_grid: bool) -> bool:
	for c in _cells(piece_type, rot, pos):
		if c.x < 0 or c.x >= COLS or c.y >= rows:
			return true
		if not ignore_grid and grid.has(c):
			return true
	return false


func _escape() -> void:
	Sfx.play("escape")
	# Split screen: first escape ends the round for both halves.
	if split:
		playing = false
		finished.emit(true)
		return
	if _story():
		# A first-time clear keeps its replay (watched from the rankings).
		if level > GameState.story_stage:
			Replays.save_replay("story", rec_export())
		GameState.story_clear(level)
		_add_score(ESCAPE_SCORE * level)
		if level >= StoryStages.TOTAL:
			# Final stage cleared — the story run ends here.
			playing = false
			EventBus.story_completed.emit()
			queue_redraw()
			return
		level += 1
		_apply_stage()
		_rec_reset()
		player.respawn(_spawn_point())
		_spawn_piece()
		EventBus.level_changed.emit(level)
		EventBus.player_escaped.emit(level)
		return
	level += 1
	_add_score(ESCAPE_SCORE * (level - 1))
	grid.clear()
	cracked.clear()
	player.respawn(_spawn_point())
	_spawn_piece()
	EventBus.level_changed.emit(level)
	EventBus.player_escaped.emit(level)


## Blows the whole stack apart, the burst rippling outward from the cat.
## Cells beyond the visible radius skip the FX entry.
func _blast_all_cells(center: Vector2i) -> void:
	for c: Vector2i in grid:
		var dist := Vector2(c - center).length()
		if dist <= BLAST_FX_RADIUS:
			break_fx.append([c, -dist * BLAST_FX_WAVE])
	grid.clear()
	cracked.clear()


func _erase_cells_around(center: Vector2i, radius: int) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			_erase_cell(Vector2i(x, y))


## Clears the 4x4 window where the next piece will spawn, so a rescue can
## never immediately block out again ([_spawn_piece] would kill on collide).
func _clear_spawn_window() -> void:
	var spawn_row := _endless_spawn_row() if mode == Mode.ENDLESS else 0
	var spawn_x := clampi(int(player.position.x / CELL) - 2, 0, COLS - 4)
	for y in range(spawn_row, spawn_row + 4):
		for x in range(spawn_x, spawn_x + 4):
			_erase_cell(Vector2i(x, y))


func _erase_cell(c: Vector2i) -> void:
	if not grid.has(c):
		return
	grid.erase(c)
	cracked.erase(c)
	break_fx.append([c, 0.0])


func _kill_player() -> void:
	if _shutter_on():
		return  # 셔터 연출 중엔 아무도 죽지 않는다
	if mode == Mode.PICNIC:
		# Nobody dies at a picnic — pop the offending jelly and play on.
		_picnic_rescue()
		return
	if mode == Mode.VERSUS:
		# The cat got crushed or trapped — round to P2.
		_versus_over(2)
		return
	Sfx.play("death")
	player.die()
	playing = false
	if split:
		finished.emit(false)
	else:
		EventBus.game_over.emit()
	queue_redraw()


## Difficulty driver: story scales with stage, endless with height climbed,
## versus with pieces spawned this round (rounds get tenser as they run long).
func _difficulty() -> int:
	if mode == Mode.PICNIC:
		return 1  # picnic never speeds up
	if mode == Mode.STORY:
		return level
	if mode == Mode.VERSUS:
		return 1 + versus_pieces / VERSUS_RAMP
	return 1 + best_height / 8


## Extra gravity steps earned purely by staying alive. Classic and endless are
## marathons, so a long run keeps tightening even while the level (or the
## climb) stalls. Story is curated, versus has its own ramp, picnic never
## speeds up — all three opt out.
func _speed_creep() -> int:
	if mode != Mode.CLASSIC and mode != Mode.ENDLESS:
		return 0
	return mini(int(run_time / SPEED_CREEP_TIME), SPEED_CREEP_MAX)


## Difficulty driving piece speed only: the mode's own driver plus the creep.
## (The lava keeps to _difficulty — it already chases the climb.)
func _fall_difficulty() -> int:
	return _difficulty() + _speed_creep()


func _track_time() -> float:
	if mode == Mode.PICNIC:
		return PICNIC_TRACK_TIME
	if mode == Mode.CLASSIC:
		# The NES gravity table scales our tracking window: level 1 keeps the
		# full 5s, the plateaus tighten it, the kill screen pins it at 1s.
		return clampf(TRACK_TIME_BASE * _classic_frames() / 48.0, 1.0, TRACK_TIME_BASE)
	if _story() and stage.has("track_time"):
		return float(stage.track_time)
	return maxf(TRACK_TIME_BASE - (_fall_difficulty() - 1) * 0.4, TRACK_TIME_MIN)


func _fall_interval() -> float:
	if mode == Mode.PICNIC:
		return PICNIC_FALL_INTERVAL
	if mode == Mode.CLASSIC:
		return clampf(FALL_INTERVAL_BASE * _classic_frames() / 48.0,
				0.03, FALL_INTERVAL_BASE)
	if _story() and stage.has("fall_interval"):
		return float(stage.fall_interval)
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
	if _story():
		col = float(stage.get("spawn_col", col))
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
		top = minf(0.0, cam.position.y - VIEW_BELOW)
	_draw_pit_background(w, h, top)
	for x in range(1, COLS):
		draw_line(Vector2(x * CELL, top), Vector2(x * CELL, h), Color(1, 1, 1, 0.04))
	for y in range(int(floor(top / CELL)) + 1, rows):
		draw_line(Vector2(0, y * CELL), Vector2(w, y * CELL), Color(1, 1, 1, 0.04))
	var show_hidden := mode == Mode.ENDLESS
	for c in grid:
		if show_hidden or c.y >= 0:
			_draw_cell(c, Board.COLORS[grid[c]])
			if cracked.has(c):
				_draw_crack(c)
	for fx in break_fx:
		if fx[1] < 0.0:
			continue  # blast ripple: it hasn't reached this cell yet
		var t: float = 1.0 - fx[1] / BREAK_FX_TIME
		var r := _cell_rect(fx[0]).grow(-CELL * 0.5 * (1.0 - t))
		draw_rect(r, Color(1.0, 1.0, 0.8, 0.7 * t))
	if mode != Mode.ENDLESS and mode != Mode.PICNIC and mode != Mode.CLASSIC:
		_draw_doors()  # the arcade well has no exit at all — nothing to draw
	_draw_loose()
	if piece_type != "":
		_draw_piece()
	var border := Color(1, 1, 1, 0.35)
	if mode == Mode.PICNIC or mode == Mode.CLASSIC:
		# Sealed pit: unbroken walls all around, no exits to draw.
		draw_rect(Rect2(-2.0, -2.0, w + 4.0, h + 4.0), border, false, 2.0)
	elif mode != Mode.ENDLESS:
		# Side walls open at the exit rows: draw them with a gap at the doors.
		var door_top := door_row * CELL
		var door_bottom := (door_row + 2) * CELL
		draw_line(Vector2(-2, -2), Vector2(w + 2, -2), border, 2.0)
		for wx in [-2.0, w + 2.0]:
			if door_top > 0.0:
				draw_line(Vector2(wx, -2), Vector2(wx, door_top), border, 2.0)
			draw_line(Vector2(wx, door_bottom), Vector2(wx, h + 2), border, 2.0)
		draw_line(Vector2(-2, h + 2), Vector2(w + 2, h + 2), border, 2.0)
	else:
		draw_line(Vector2(-2, top), Vector2(-2, h + 2), border, 2.0)
		draw_line(Vector2(w + 2, top), Vector2(w + 2, h + 2), border, 2.0)
		draw_line(Vector2(-2, h + 2), Vector2(w + 2, h + 2), border, 2.0)
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
	if mode == Mode.PICNIC:
		# Picnic daylight: the softest, warmest pit in the game.
		top_col = Color("3d4258")
		bot_col = Color("1a1c28")
	if mode == Mode.ENDLESS:
		var t := clampf(best_height / 80.0, 0.0, 1.0)
		top_col = top_col.lerp(Color("6a7186"), t)
		bot_col = bot_col.lerp(Color("2a3040"), t)
	draw_polygon(PackedVector2Array([
		Vector2(0, top), Vector2(w, top), Vector2(w, h), Vector2(0, h),
	]), PackedColorArray([top_col, top_col, bot_col, bot_col]))
	if mode == Mode.PICNIC:
		# A single soft sunbeam straight down the middle of the picnic pit.
		var beam := Color(1.0, 0.95, 0.82, 0.08)
		var beam_faded := Color(1.0, 0.95, 0.82, 0.0)
		draw_polygon(PackedVector2Array([
			Vector2(w * 0.3, 0.0), Vector2(w * 0.7, 0.0),
			Vector2(w * 0.8, h), Vector2(w * 0.2, h),
		]), PackedColorArray([beam, beam, beam_faded, beam_faded]))
	elif mode != Mode.ENDLESS:
		# Warm light shafts slanting in — only from doors that are open.
		var y0 := door_row * CELL
		var y1 := (door_row + 2) * CELL
		var yt := minf(y1 + h * 0.45, h)
		var warm := Color(1.0, 0.95, 0.82, 0.1)
		var faded := Color(1.0, 0.95, 0.82, 0.0)
		if door_left:
			draw_polygon(PackedVector2Array([
				Vector2(0, y0), Vector2(0, y1), Vector2(w * 0.55, yt),
			]), PackedColorArray([warm, warm, faded]))
		if door_right:
			draw_polygon(PackedVector2Array([
				Vector2(w, y0), Vector2(w, y1), Vector2(w * 0.45, yt),
			]), PackedColorArray([warm, warm, faded]))


## One exit tunnel in each side wall, at the top rows. Locked doors (story
## goals not yet met) draw as a dark slab with a padlock instead of the glow.
func _draw_doors() -> void:
	var w := COLS * CELL
	var door_h := 2 * CELL
	var y := door_row * CELL
	var glow := Color(1.0, 0.95, 0.82, 0.18)
	var frame := Color(1.0, 0.95, 0.82, 0.75)
	var font := ThemeDB.fallback_font
	var mid_y := y + door_h / 2.0 + 9.0
	for entry in [[Rect2(-CELL, y, CELL, door_h), door_left],
			[Rect2(w, y, CELL, door_h), door_right]]:
		var door: Rect2 = entry[0]
		if entry[1]:
			draw_rect(door, glow)
			draw_rect(door, frame, false, 2.0)
		else:
			draw_rect(door, Color(0.09, 0.09, 0.13, 0.95))
			draw_rect(door, Color(1, 1, 1, 0.22), false, 2.0)
			_draw_lock(door.get_center())
	if door_left:
		draw_string(font, Vector2(CELL * 0.25, mid_y), "← ESC",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1.0, 0.95, 0.82, 0.9))
	if door_right:
		draw_string(font, Vector2(w - CELL * 1.55, mid_y), "ESC →",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1.0, 0.95, 0.82, 0.9))


func _draw_lock(at: Vector2) -> void:
	var col := Color(1.0, 0.9, 0.6, 0.85)
	draw_rect(Rect2(at + Vector2(-10.0, -3.0), Vector2(20.0, 16.0)), col)
	draw_arc(at + Vector2(0.0, -4.0), 7.0, PI, TAU, 10, col, 3.5)


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
		for c: Vector2i in _loose_cells(e):
			_draw_cell(c, color)
			if e.s == PieceState.LANDED:
				draw_rect(_cell_rect(c).grow(-2.0),
						Color(1.0, 0.96, 0.8, 0.3 + 0.45 * pulse), false, 3.0)


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
