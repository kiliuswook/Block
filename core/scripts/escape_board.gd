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
const LAVA_REVIVE_GAP := CELL * 5.0  # revive pushes the lava this far below the feet
const REVIVE_BLAST := 2  # revive clears this radius of cells around the cat
const REVIVE_PLATFORM_GAP := 3  # revive platform floats this many cells above the lava
const REVIVE_FX_RADIUS := 16.0  # revive blast: cells beyond this erase without FX (off-screen)
const REVIVE_FX_WAVE := 0.018  # revive blast ripple: FX delay per cell of distance from the cat
const LAVA_PUSH := [0, 2, 5, 9, 15]  # endless: lava shoved down this many cells per clear size
const GOLD_PER_CLEAR := [0, 2, 5, 10, 20]  # endless: gold paid on the spot per clear size
const GOLD_FX_TIME := 1.0
const FEVER_TIME := 10.0
const FEVER_PER_LINE := 0.25  # gauge charge per cleared line (full at 4 lines)
const FEVER_PER_PIECE := 0.03  # small trickle charge for every locked piece
const FEVER_FALL_INTERVAL := 0.025  # fever: near-instant fall steps
const FEVER_LOCK_GRACE := 0.07  # fever: quick lock so the next piece follows
const FEVER_SPAWN_TRIES := 3  # fever spawn: candidate columns, deepest one wins
# Jelly picnic (casual): a 2-minute no-death snack hunt. Pieces fall slow and
# never speed up; anything that would kill the cat pops like jelly instead.
const PICNIC_TIME := 120.0
const PICNIC_SNACKS_ACTIVE := 3  # snacks floating in the pit at any moment
const PICNIC_SNACK_SCORE := 100
const PICNIC_TRACK_TIME := 6.0
const PICNIC_FALL_INTERVAL := 0.34
const PICNIC_SNACK_MIN_UP := 1  # snack floats this many cells above the stack
const PICNIC_SNACK_MAX_UP := 5
# Alphabet keycaps: every so often a random locked block turns into a cat-eared
# keycap; clear the line holding it to bank the letter (title-screen dex).
# TEST CADENCE — release values should be far rarer (e.g. 45.0 / 0.15).
const KEYCAP_INTERVAL := 6.0  # spawn roll every this many seconds
const KEYCAP_CHANCE := 0.6  # chance a roll actually spawns one
const KEYCAP_MAX_ACTIVE := 2  # keycaps sitting in the pit at once
const KEYCAP_FX_TIME := 1.3
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
var playing := false
var is_paused := false
var break_fx: Array = []  # [cell: Vector2i, age: float]
var gold_fx: Array = []  # [pos: Vector2, age: float, amount: int] — floating "+N G" popup
var mode := Mode.STORY
var rows := PIT_ROWS  # pit height in cells
var best_height := 0
var drop_tap_time := -1e9
var lava_y := 0.0
var lava_phase := 0.0
var p2_das_timer := 0.0
var versus_pieces := 0
# Fever (endless only): line clears charge the gauge; at full charge the cat
# goes invincible with double-height jumps while pieces rain down at full
# speed; buried cats swim up through the one-way stack (see player.gd).
var fever_gauge := 0.0
var fever_active := false
var fever_timer := 0.0
var gold_mult := 1.0  # lucky-jelly boost: endless gold multiplier for this run
# Endless: once its countdown ends a piece detaches and falls on its own (no
# more rotation), so the next piece starts tracking immediately. Each entry:
# {t: type, r: rot, p: pos, s: PieceState, ft: fall timer, lt: land timer}.
var loose: Array = []
# Alphabet keycaps living on locked blocks (cell -> letter "A".."Z").
var keycaps := {}
var keycap_timer := 0.0
var keycap_fx: Array = []  # [pos: Vector2, age: float, letter: String]
# Picnic: floating jelly-fish snacks (cell -> visual variant), time left, haul.
var snacks := {}
var picnic_time := 0.0
var picnic_snacks := 0
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
	best_height = 0
	versus_pieces = 0
	p2_das_timer = 0.0
	lava_y = rows * CELL + LAVA_START_OFFSET
	lava_phase = 0.0
	gold_fx.clear()
	loose.clear()
	keycaps.clear()
	keycap_timer = 0.0
	keycap_fx.clear()
	snacks.clear()
	picnic_time = 0.0
	picnic_snacks = 0
	fever_gauge = 0.0
	fever_active = false
	fever_timer = 0.0
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
	gold_mult = 1.0
	if _story():
		# Resume from the next uncleared stage; a finished story replays from 1.
		level = GameState.story_stage % StoryStages.TOTAL + 1
		_apply_stage()
	elif mode == Mode.CLASSIC:
		# Arcade pit: both exits sealed — clear lines and survive with the
		# usual cat controls; every 10 lines is a stage (arcade level).
		door_left = false
		door_right = false
	elif mode == Mode.PICNIC:
		# Sealed jelly pit: no exits, no death — just a timed snack hunt.
		door_left = false
		door_right = false
		picnic_time = PICNIC_TIME
		for i in range(PICNIC_SNACKS_ACTIVE):
			_spawn_snack()
	elif mode == Mode.ENDLESS and not split:
		# Consume boosts bought for this run (shop / death-popup chips).
		for b: String in GameState.take_boosts():
			match b:
				"warmup":
					_build_warmup_stairs()
				"fever":
					fever_gauge = 0.5
				"lucky":
					gold_mult = 1.5
	player.respawn(_spawn_point())
	_spawn_piece()
	playing = true
	_rec_reset()
	if not split:
		EventBus.game_started.emit()
		EventBus.lines_changed.emit(0)
		EventBus.level_changed.emit(level)
		EventBus.height_changed.emit(0)
	queue_redraw()


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
	keycaps.clear()
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
	if fever_active:
		fever_timer -= delta
		if fever_timer <= 0.0:
			fever_active = false
			# Blocks turn solid again — pop the cat out if it was inside one.
			if not _shove_player_out_of_grid():
				_erase_cells_around(Vector2i((player.position / CELL).floor()), 1)
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
	for fx in gold_fx:
		fx[1] += delta
	gold_fx = gold_fx.filter(func(fx: Array) -> bool: return fx[1] < GOLD_FX_TIME)
	for fx in keycap_fx:
		fx[1] += delta
	keycap_fx = keycap_fx.filter(func(fx: Array) -> bool: return fx[1] < KEYCAP_FX_TIME)
	_update_keycaps(delta)
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
		GameState.score += (h - best_height) * HEIGHT_SCORE
		best_height = h
		if not split:
			EventBus.height_changed.emit(best_height)


# --- Jelly picnic (casual) ------------------------------------------------------


func _update_picnic(delta: float) -> void:
	lava_phase += delta  # doubles as the snack-bobbing animation clock
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
	var pr := player.rect().grow(6.0)
	for c: Vector2i in snacks.keys():
		if _cell_rect(c).grow(-10.0).intersects(pr):
			_collect_snack(c)


func _collect_snack(c: Vector2i) -> void:
	snacks.erase(c)
	picnic_snacks += 1
	GameState.score += PICNIC_SNACK_SCORE
	break_fx.append([c, 0.0])
	gold_fx.append([_cell_rect(c).get_center(), 0.0, PICNIC_SNACK_SCORE])
	Sfx.play("gold")
	_spawn_snack()


## Drops a snack over a random column, floating a few cells above that
## column's stack surface — high ones ask for a little block-climbing.
func _spawn_snack() -> void:
	for attempt in range(40):
		var x := randi_range(0, COLS - 1)
		var surface := _surface_row(x, x)
		var y := clampi(surface - randi_range(PICNIC_SNACK_MIN_UP, PICNIC_SNACK_MAX_UP),
				2, rows - 1)
		var c := Vector2i(x, y)
		if grid.has(c) or snacks.has(c):
			continue
		if Vector2(c).distance_to(player.position / CELL) < 3.0:
			continue  # never a freebie right on the cat
		snacks[c] = randi_range(0, 2)
		return


## Picnic never kills: whatever pinned the cat pops like jelly instead. The
## falling piece bursts, nearby locked cells shatter, and play just continues.
## big = the stack overflowed the pit: blow the whole thing up and restock.
func _picnic_rescue(big := false) -> void:
	var center := Vector2i((player.position / CELL).floor())
	Sfx.play("break")
	if big:
		_blast_all_cells(center)
		snacks.clear()
		for i in range(PICNIC_SNACKS_ACTIVE):
			_spawn_snack()
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
## Fever changes the rules: only the pit boundary stays solid — locked blocks
## and the falling piece become one-way platforms (see [fever_platform_top]).
func rect_blocked_for_player(r: Rect2) -> bool:
	if fever_active:
		return _rect_hits_bounds(r)
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
	if mode == Mode.ENDLESS and not fever_active:
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
		if fever_active:
			for c in _cells(piece_type, piece_rot, piece_pos):
				_erase_cell(c)
		elif mode == Mode.VERSUS:
			_versus_over(1)
			return
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
	if land_timer >= (FEVER_LOCK_GRACE if fever_active else LOCK_GRACE):
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
	if fever_active:
		return false  # invincible: the piece passes straight through the cat
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


## Locks a piece's cells into the grid: overflow, line clears, scoring and the
## picnic snack shuffle. Serves both the active piece and detached (loose)
## endless pieces. Returns false when the game ended — or a rescue already
## spawned the next piece — and the caller must not spawn another.
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
	if not fever_active:  # fever locks a piece every ~0.1s — too spammy to click
		Sfx.play("lock")
	GameState.score += 10 * level
	_add_fever(FEVER_PER_PIECE)
	var cleared := _clear_lines()
	if cleared > 0:
		total_lines += cleared
		# Classic pays the arcade table (40/100/300/1200 × stage, pre-level-up).
		var table: Array = Board.CLASSIC_SCORES if mode == Mode.CLASSIC else LINE_SCORES
		GameState.score += table[cleared] * level
		_add_fever(cleared * FEVER_PER_LINE)
		Sfx.play("clear", 1.0 + 0.07 * (cleared - 1))
		if mode == Mode.ENDLESS:
			_endless_line_reward(cleared)
		elif mode == Mode.CLASSIC:
			# Arcade level design: every 10 lines advances the stage.
			var new_stage := total_lines / 10 + 1
			if new_stage != level:
				level = new_stage
				EventBus.level_changed.emit(level)
		_story_add_progress("lines", cleared)
		if not split:
			EventBus.lines_changed.emit(total_lines)
		if not _free_player_from_grid():
			return false
	if mode == Mode.PICNIC:
		# Locks and line shifts may have buried a snack — float it elsewhere.
		for c: Vector2i in snacks.keys():
			if grid.has(c):
				snacks.erase(c)
				_spawn_snack()
	return true


## Warmup boost: a staircase against the left wall reaching 5 floors up, so
## the run starts with a quick climb instead of a bare pit. Columns only —
## never a full row, so it can't be cashed in as an instant line clear.
func _build_warmup_stairs() -> void:
	for i in range(1, 6):
		var x := 5 - i  # x=4 is 1 tall ... x=0 is 5 tall
		for d in range(i):
			grid[Vector2i(x, rows - 1 - d)] = "J"


## Endless: line clears fight the lava — every clear shoves it back down
## (scaling steeply with multi-line clears) and pays gold on the spot.
## Height itself is never lost: _clear_lines leaves gaps instead of collapsing.
func _endless_line_reward(cleared: int) -> void:
	lava_y += LAVA_PUSH[cleared] * CELL
	if split:
		return  # split race: shared wallet would double-pay across two boards
	var g := int(GOLD_PER_CLEAR[cleared] * gold_mult)
	GameState.add_currency(g, 0)
	gold_fx.append([Vector2(player.position.x, player.position.y - CELL), 0.0, g])
	Sfx.play("gold")


# --- Alphabet keycaps -----------------------------------------------------------


## Every KEYCAP_INTERVAL seconds, one random locked block may turn into an
## alphabet keycap. Clearing the line that holds it banks the letter. Split
## boards skip it (two boards share one save), versus skips it (P2 owns the
## blocks, a collectible for P1 there makes no sense).
func _update_keycaps(delta: float) -> void:
	if not playing or split or mode == Mode.VERSUS:
		return
	keycap_timer += delta
	if keycap_timer < KEYCAP_INTERVAL:
		return
	keycap_timer = 0.0
	if randf() > KEYCAP_CHANCE or keycaps.size() >= KEYCAP_MAX_ACTIVE:
		return
	var cells: Array = grid.keys().filter(func(c: Vector2i) -> bool:
		return not keycaps.has(c) and (mode == Mode.ENDLESS or c.y >= 0))
	if cells.is_empty():
		return
	keycaps[cells.pick_random()] = char(65 + randi() % 26)
	Sfx.play("crack")
	queue_redraw()


func _collect_keycap(c: Vector2i) -> void:
	var letter: String = keycaps[c]
	keycaps.erase(c)
	GameState.add_keycap(letter)
	keycap_fx.append([_cell_rect(c).get_center(), 0.0, letter])
	Sfx.play("record")


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
		int(lava_y) if mode == Mode.ENDLESS else GameState.score,
	]))
	if rec_frames.size() >= REC_MAX_FRAMES * REC_STRIDE:
		_rec_on = false  # marathon runs: stop recording, keep what we have


## Grid changes land as diff events against a shadow copy — locks, clears,
## breaks and revive blasts all reduce to added/removed cells.
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
	var new_keycaps := {}
	for c in grid:
		if c.y in full_rows:
			break_fx.append([c, 0.0])
			if keycaps.has(c):
				_collect_keycap(c)
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
		if keycaps.has(c):
			new_keycaps[dest] = keycaps[c]
	grid = new_grid
	cracked = new_cracked
	keycaps = new_keycaps
	return full_rows.size()


## Buried by a lock/line shift with nowhere to nudge to: normally death, but
## a fever cat is invincible — blocks are one-way, so being inside them is
## fine and it can simply jump out.
func _free_player_from_grid() -> bool:
	if fever_active:
		return true
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
		keycaps.erase(best)
		break_fx.append([best, 0.0])
		GameState.score += BREAK_SCORE
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
	if fever_active:
		# Fever pieces don't chase the cat: rain over the whole pit width,
		# leaning toward the lowest part of the stack (see [_fever_spawn_x]).
		piece_pos = Vector2i(_fever_spawn_x(), spawn_row)
	elif mode == Mode.VERSUS:
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
		if fever_active:
			for c in _cells(piece_type, piece_rot, piece_pos):
				_erase_cell(c)
		elif mode == Mode.VERSUS:
			_versus_over(1)
		else:
			_kill_player()
	if fever_active and playing:
		_start_fall()


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
		GameState.score += ESCAPE_SCORE * level
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
	GameState.score += ESCAPE_SCORE * (level - 1)
	grid.clear()
	cracked.clear()
	keycaps.clear()
	player.respawn(_spawn_point())
	_spawn_piece()
	EventBus.level_changed.emit(level)
	EventBus.player_escaped.emit(level)


## Revive after death ("continue"): blast the blocks around the cat open,
## push the lava back down and resume the run right where it ended.
## Endless: the blast rips through the whole stack in a ripple spreading out
## from the cat, and a flat rescue bar appears above the lava so the cat
## never free-falls straight back into it.
func revive_player() -> void:
	loose.clear()  # mid-air pieces vanish too — no instant re-crush
	var center := Vector2i((player.position / CELL).floor())
	if mode == Mode.ENDLESS:
		_blast_all_cells(center)
	else:
		_erase_cells_around(center, REVIVE_BLAST)
	var spot := _find_revive_spot()
	player.respawn(spot)
	if mode == Mode.ENDLESS:
		lava_y = maxf(lava_y, spot.y + Player.SIZE / 2.0 + LAVA_REVIVE_GAP)
		_build_revive_platform(spot)
	playing = true
	is_paused = false
	_clear_spawn_window()
	_spawn_piece()
	Sfx.play("revive")
	queue_redraw()


## Endless revive: every locked block explodes, the burst rippling outward
## from the cat. Cells beyond the visible radius skip the FX entry.
func _blast_all_cells(center: Vector2i) -> void:
	for c: Vector2i in grid:
		var dist := Vector2(c - center).length()
		if dist <= REVIVE_FX_RADIUS:
			break_fx.append([c, -dist * REVIVE_FX_WAVE])
	grid.clear()
	cracked.clear()
	keycaps.clear()


## Endless revive: a flat bar floats a few cells above the lava as a rescue
## floor. One edge cell (the side away from the cat) stays open so the row
## never counts as a clearable line — a line clear would drop this floor out
## from under the freshly revived cat.
func _build_revive_platform(spot: Vector2) -> void:
	var row := int(floor(lava_y / CELL)) - REVIVE_PLATFORM_GAP
	if row >= rows:  # lava still below the pit floor — the floor itself catches the cat
		return
	var gap := 0 if spot.x > COLS * CELL / 2.0 else COLS - 1
	for x in range(COLS):
		if x == gap:
			continue
		var c := Vector2i(x, row)
		grid[c] = "I"
		cracked.erase(c)


## Nearest free spot for the revived cat: death position first, then upward,
## then sideways columns. Falls back to the pit-bottom spawn point.
func _find_revive_spot() -> Vector2:
	var half := Player.SIZE / 2.0
	var size := Vector2.ONE * Player.SIZE
	for radius in range(0, COLS):
		var offsets: Array = [0] if radius == 0 else [-radius, radius]
		for sx in offsets:
			var x: float = clampf(player.position.x + sx * CELL, half, COLS * CELL - half)
			for up in range(0, rows * 2):
				var p := Vector2(x, player.position.y - up * CELL)
				if p.y - half < 0.0 and mode != Mode.ENDLESS:
					break
				if p.y + half > rows * CELL:
					continue
				if not rect_hits_solid(Rect2(p - Vector2.ONE * half, size)):
					return p
	return _spawn_point()


func _erase_cells_around(center: Vector2i, radius: int) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			_erase_cell(Vector2i(x, y))


## Clears the 4x4 window where the next piece will spawn, so reviving can
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
	keycaps.erase(c)
	break_fx.append([c, 0.0])


func _kill_player() -> void:
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


func _track_time() -> float:
	if mode == Mode.PICNIC:
		return PICNIC_TRACK_TIME
	if mode == Mode.CLASSIC:
		# The NES gravity table scales our tracking window: stage 1 keeps the
		# full 5s, the plateaus tighten it, the kill screen pins it at 1s.
		return clampf(TRACK_TIME_BASE * _classic_frames() / 48.0, 1.0, TRACK_TIME_BASE)
	if _story() and stage.has("track_time"):
		return float(stage.track_time)
	return maxf(TRACK_TIME_BASE - (_difficulty() - 1) * 0.4, TRACK_TIME_MIN)


func _fall_interval() -> float:
	if fever_active:
		return FEVER_FALL_INTERVAL
	if mode == Mode.PICNIC:
		return PICNIC_FALL_INTERVAL
	if mode == Mode.CLASSIC:
		return clampf(FALL_INTERVAL_BASE * _classic_frames() / 48.0,
				0.03, FALL_INTERVAL_BASE)
	if _story() and stage.has("fall_interval"):
		return float(stage.fall_interval)
	return maxf(FALL_INTERVAL_BASE - (_difficulty() - 1) * 0.02, FALL_INTERVAL_MIN)


## NES frames-per-row for the current stage (Board.CLASSIC_FRAMES, 1-based).
func _classic_frames() -> float:
	return float(Board.CLASSIC_FRAMES[clampi(level, 1, Board.CLASSIC_FRAMES.size()) - 1])


func _lava_speed() -> float:
	return minf(LAVA_SPEED_BASE + (_difficulty() - 1) * LAVA_SPEED_STEP, LAVA_SPEED_MAX)


# --- Fever time (endless) -----------------------------------------------------


## Test hotkey: F fills the gauge instantly and kicks off fever (endless only).
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F and playing and not is_paused:
		_add_fever(1.0)


func _add_fever(amount: float) -> void:
	if mode != Mode.ENDLESS or fever_active:
		return
	fever_gauge = clampf(fever_gauge + amount, 0.0, 1.0)
	if fever_gauge >= 1.0:
		_start_fever()


func _start_fever() -> void:
	fever_active = true
	fever_timer = FEVER_TIME
	fever_gauge = 0.0
	Sfx.play("fever")
	# The hovering piece joins the downpour right away, from a random column.
	if piece_state == PieceState.TRACKING and piece_type != "":
		piece_pos.x = _fever_spawn_x()
		_start_fall()


## Fever spawn column. The old uniform randi over [0, COLS-4] had two flaws:
## most shapes only cover x offsets 0..2, so the rightmost columns almost
## never got blocks, and pure i.i.d. rolls cluster into one-sided towers.
## Instead: span the true footprint of the piece across the full pit width,
## roll a few candidates and keep the one over the lowest stack surface —
## still reads as random rain, but fills valleys and stays climbable.
func _fever_spawn_x() -> int:
	var min_dx := 3
	var max_dx := 0
	for c: Vector2i in Board.SHAPES[piece_type][0]:
		min_dx = mini(min_dx, c.x)
		max_dx = maxi(max_dx, c.x)
	var lo := -min_dx
	var hi := COLS - 1 - max_dx
	var best_x := randi_range(lo, hi)
	var best_top := _surface_row(best_x + min_dx, best_x + max_dx)
	for i in range(FEVER_SPAWN_TRIES - 1):
		var x := randi_range(lo, hi)
		var top := _surface_row(x + min_dx, x + max_dx)
		if top > best_top:  # larger y = deeper valley
			best_x = x
			best_top = top
	return best_x


## Highest occupied row (smallest y) across columns [x0, x1]; the pit floor
## row when those columns are empty. Endless rows go negative as the stack
## climbs, so "deepest" means the largest value returned here.
func _surface_row(x0: int, x1: int) -> int:
	var top := rows
	for c: Vector2i in grid:
		if c.x >= x0 and c.x <= x1:
			top = mini(top, c.y)
	return top


## One-way platforms during fever: blocks are intangible from below, but
## their exposed tops can still be stood on — both the falling piece and the
## locked grid. Highest top the player's feet can rest on (within
## [feet - 10, feet + tol]), or INF when none.
func fever_platform_top(r: Rect2, tol: float) -> float:
	var best := INF
	if piece_state != PieceState.TRACKING and piece_type != "":
		for c in _cells(piece_type, piece_rot, piece_pos):
			best = minf(best, _platform_top_of(_cell_rect(c), r, tol))
	for e: Dictionary in loose:
		for c: Vector2i in _loose_cells(e):
			best = minf(best, _platform_top_of(_cell_rect(c), r, tol))
	# Locked grid: only exposed surfaces count (no landing inside the stack).
	var x0 := int(floor((r.position.x + 6.0) / CELL))
	var x1 := int(floor((r.end.x - 6.0) / CELL))
	var y0 := int(ceil((r.end.y - 10.0) / CELL))
	var y1 := int(floor((r.end.y + tol) / CELL))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if grid.has(Vector2i(x, y)) and not grid.has(Vector2i(x, y - 1)):
				best = minf(best, _platform_top_of(_cell_rect(Vector2i(x, y)), r, tol))
	return best


func _platform_top_of(rect: Rect2, r: Rect2, tol: float) -> float:
	if rect.position.x < r.end.x - 6.0 and rect.end.x > r.position.x + 6.0:
		var top: float = rect.position.y
		if top >= r.end.y - 10.0 and top <= r.end.y + tol:
			return top
	return INF


func _spawn_point() -> Vector2:
	var col := COLS / 2.0
	if _story():
		col = float(stage.get("spawn_col", col))
	return Vector2(col * CELL, rows * CELL - Player.SIZE / 2.0)


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
			if keycaps.has(c):
				paint_keycap(self, _cell_rect(c), keycaps[c],
						0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 3.0
								+ (c.x * 5 + c.y) * 1.1))
	for fx in break_fx:
		if fx[1] < 0.0:
			continue  # revive ripple: the blast hasn't reached this cell yet
		var t: float = 1.0 - fx[1] / BREAK_FX_TIME
		var r := _cell_rect(fx[0]).grow(-CELL * 0.5 * (1.0 - t))
		draw_rect(r, Color(1.0, 1.0, 0.8, 0.7 * t))
	if mode != Mode.ENDLESS and mode != Mode.PICNIC:
		_draw_doors()
	if mode == Mode.PICNIC:
		_draw_snacks()
	_draw_keycap_fx()
	_draw_loose()
	if piece_type != "":
		_draw_piece()
	var border := Color(1, 1, 1, 0.35)
	if mode == Mode.PICNIC:
		# Sealed jelly pit: unbroken walls all around, no doors to draw.
		draw_rect(Rect2(-2.0, -2.0, w + 4.0, h + 4.0), border, false, 2.0)
		_draw_gold_fx()
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
		_draw_fever(w)
		_draw_gold_fx()


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
	for c in _cells(piece_type, piece_rot, piece_pos):
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


## Fever gauge/timer bar, anchored to the camera so it stays on screen in
## both single and split-viewport play.
## Floating "+N G" popup over the cat when an endless line clear pays out.
func _draw_gold_fx() -> void:
	var font := ThemeDB.fallback_font
	for fx in gold_fx:
		var t: float = fx[1] / GOLD_FX_TIME
		var pos: Vector2 = fx[0] + Vector2(-90.0, -CELL * t)
		var col := Color("f7d354")
		col.a = 1.0 - t * t
		var text := ("+%d 냠!" % fx[2]) if mode == Mode.PICNIC else "+%d G" % fx[2]
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 180.0, 30, col)


func _draw_fever(w: float) -> void:
	var cam_y := cam.position.y if cam else rows * CELL / 2.0
	# Bar rides just above the screen bottom — or above the touch zone on
	# portrait, where the bottom belongs to the controls.
	var vp := get_viewport_rect().size
	var bar_sy := vp.y - 70.0 if vp.x > vp.y else vp.y - 555.0
	var bar := Rect2(CELL * 0.5, cam_y - vp.y / 2.0 + bar_sy, w - CELL, 16.0)
	draw_rect(bar, Color(0, 0, 0, 0.45))
	if fever_active:
		var t := fever_timer / FEVER_TIME
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * t, bar.size.y)), Color("ffd27a"))
		if fmod(lava_phase, 0.3) < 0.2:
			draw_string(ThemeDB.fallback_font, Vector2(w / 2.0 - 130.0, cam_y - 380.0),
					"FEVER!!", HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color(1.0, 0.85, 0.35))
	elif fever_gauge > 0.0:
		var fill := Color("e8935a")
		if fever_gauge >= 0.75:
			fill = fill.lerp(Color("ffd27a"), 0.5 + 0.5 * sin(lava_phase * 8.0))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * fever_gauge, bar.size.y)), fill)
	draw_rect(bar, Color(1, 1, 1, 0.35), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(bar.position.x, bar.position.y - 8.0),
			"FEVER", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.95, 0.82, 0.75))


## Jelly-fish snacks bobbing in place, glowing faintly like little exit lights.
func _draw_snacks() -> void:
	const BODY_COLS: Array[Color] = [Color("f2c94c"), Color("bfe8d5"), Color("f6cdd8")]
	for c: Vector2i in snacks:
		var p := _cell_rect(c).get_center() \
				+ Vector2(0.0, sin(lava_phase * 3.0 + (c.x * 7 + c.y) * 1.3) * 5.0)
		var col: Color = BODY_COLS[int(snacks[c]) % BODY_COLS.size()]
		var pulse := 0.5 + 0.5 * sin(lava_phase * 4.0 + c.x)
		draw_circle(p, 24.0 + 3.0 * pulse, Color(1.0, 0.95, 0.82, 0.10))
		# Fish: round body, triangular tail, one content little eye.
		draw_circle(p + Vector2(-3.0, 0.0), 13.0, col)
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(7.0, 0.0), p + Vector2(19.0, -10.0), p + Vector2(19.0, 10.0),
		]), col.darkened(0.15))
		draw_circle(p + Vector2(-8.0, -3.0), 2.4, Color("2a2230"))


## Cat-eared alphabet keycap riding a locked block: cream cap, two little ears,
## whisker dots beside the letter. Static so the title-screen dex reuses it.
## pulse (0..1) drives the soft glow; pass a constant for still UI renders.
static func paint_keycap(ci: CanvasItem, r: Rect2, letter: String,
		pulse := 0.5, glow := true) -> void:
	var body := Color("f4e3c8")
	var edge := Color("d9a05c")
	var ink := Color("2a2230")
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
	var fs := int(s * 0.44)
	var w := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(font, Vector2(center.x - w / 2.0, center.y + fs * 0.36), letter,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	# Whisker dots flanking the letter — the cat face of the keycap.
	for sx: float in [-1.0, 1.0]:
		for dy: float in [-1.0, 1.0]:
			ci.draw_circle(center + Vector2(sx * s * 0.3, s * 0.05 + dy * s * 0.05),
					s * 0.022, Color(ink, 0.55))


## Floating "키캡 획득!" popup rising off the cleared keycap block.
func _draw_keycap_fx() -> void:
	var font := ThemeDB.fallback_font
	for fx in keycap_fx:
		var t: float = fx[1] / KEYCAP_FX_TIME
		var pos: Vector2 = fx[0] + Vector2(0.0, -CELL * 1.2 * t)
		var col := Color("f4e3c8")
		col.a = 1.0 - t * t
		var cap := Rect2(pos - Vector2(CELL * 0.45, CELL * 0.85), Vector2.ONE * CELL * 0.9)
		paint_keycap(self, cap, fx[2], 1.0, false)
		var text := "%s 키캡 획득!" % fx[2]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		var tp := Vector2(pos.x - w / 2.0, pos.y + 24.0)
		draw_string(font, tp + Vector2(2.0, 2.0), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0, 0, 0, 0.6 * col.a))
		draw_string(font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, col)


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
