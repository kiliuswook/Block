class_name EscapeBoard
extends Node2D
## Escape mode: a tetromino tracks the player's column at the top of the
## field, free-falls after a countdown, and locks into the grid. The player
## climbs the stack and escapes through the door at the top. Getting caught
## under a falling piece is death. Reuses SHAPES/KICKS/COLORS from Board.

## Split screen: this board's round result (true = this player escaped/won).
signal finished(win: bool)

enum PieceState { TRACKING, FALLING, LANDED }
enum Mode { ESCAPE, ENDLESS, VERSUS }

const COLS := 10
const ROWS := 14
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
const ENDLESS_SPAWN_AHEAD := 7  # piece spawns this many cells above the camera cell
const LAVA_START_OFFSET := CELL * 3.0
const LAVA_SPEED_BASE := 8.0
const LAVA_SPEED_STEP := 2.0
const LAVA_SPEED_MAX := 45.0
const LAVA_MAX_GAP := 980.0  # lava never trails the camera by more than this
const LAVA_REVIVE_GAP := CELL * 5.0  # revive pushes the lava this far below the feet
const REVIVE_BLAST := 2  # revive clears this radius of cells around the cat
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
var mode := Mode.ESCAPE
var best_height := 0
var drop_tap_time := -1e9
var lava_y := 0.0
var lava_phase := 0.0
var p2_das_timer := 0.0
var versus_pieces := 0
# Split screen: one board per player — global EventBus signals are muted and
# the piece is driven by this board's own action set instead of the defaults.
var split := false
var act_rot_cw := "rotate_cw"
var act_rot_ccw := "rotate_ccw"
var act_drop := "soft_drop"

@onready var player: Player = $Player
@onready var cam: Camera2D = get_node_or_null("Cam")


func start_game() -> void:
	mode = GameState.mode as Mode
	split = GameState.split
	grid.clear()
	cracked.clear()
	bag.clear()
	next_type = ""
	level = 1
	total_lines = 0
	best_height = 0
	versus_pieces = 0
	p2_das_timer = 0.0
	lava_y = ROWS * CELL + LAVA_START_OFFSET
	lava_phase = 0.0
	is_paused = false
	GameState.reset()
	if cam:
		cam.enabled = mode == Mode.ENDLESS
		cam.position = Vector2(COLS * CELL / 2.0, ROWS * CELL / 2.0)
		cam.reset_smoothing()
	player.respawn(_spawn_point())
	_spawn_piece()
	playing = true
	if not split:
		EventBus.game_started.emit()
		EventBus.lines_changed.emit(0)
		EventBus.level_changed.emit(1)
		EventBus.height_changed.emit(0)
	queue_redraw()


func _process(delta: float) -> void:
	if not playing or is_paused:
		return
	if mode == Mode.VERSUS:
		_p2_input(delta)
	else:
		if Input.is_action_just_pressed(act_rot_cw):
			_try_rotate(1)
		if Input.is_action_just_pressed(act_rot_ccw):
			_try_rotate(-1)
	match piece_state:
		PieceState.TRACKING:
			_track(delta)
		PieceState.FALLING:
			_fall(delta)
		PieceState.LANDED:
			_landed(delta)
	for fx in break_fx:
		fx[1] += delta
	break_fx = break_fx.filter(func(fx: Array) -> bool: return fx[1] < BREAK_FX_TIME)
	if mode == Mode.ENDLESS:
		_update_endless(delta)
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
	cam.position.y = minf(player.position.y, ROWS * CELL / 2.0)
	# Lava creeps up from below; it also keeps pace with the camera so a
	# fast climber can never leave it arbitrarily far behind.
	lava_phase += delta
	lava_y -= _lava_speed() * delta
	lava_y = minf(lava_y, cam.position.y + LAVA_MAX_GAP)
	var feet := player.position.y + Player.SIZE / 2.0
	if feet > lava_y:
		_kill_player()
		return
	var h := int(round((ROWS * CELL - feet) / CELL))
	if h > best_height:
		GameState.score += (h - best_height) * HEIGHT_SCORE
		best_height = h
		if not split:
			EventBus.height_changed.emit(best_height)


func rect_hits_solid(r: Rect2) -> bool:
	if r.position.x < 0.0 or r.end.x > COLS * CELL:
		# Escape/versus: the side walls open at the top rows — one exit each.
		if not (mode != Mode.ENDLESS and _rect_in_side_door(r)):
			return true
	if r.end.y > ROWS * CELL:
		return true
	if mode != Mode.ENDLESS and r.position.y < 0.0:
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


func _rect_in_side_door(r: Rect2) -> bool:
	return r.position.y >= DOOR_ROW_TOP * CELL and r.end.y <= (DOOR_ROW_BOTTOM + 1) * CELL


## What the player collides with: locked grid, walls, and the falling piece.
## The falling piece is a solid body — the player can never pass through it.
func rect_blocked_for_player(r: Rect2) -> bool:
	return rect_hits_solid(r) or piece_hits_rect(r)


func piece_hits_rect(r: Rect2) -> bool:
	if piece_state == PieceState.TRACKING or piece_type == "":
		return false
	for c in _cells(piece_type, piece_rot, piece_pos):
		if _cell_rect(c).intersects(r):
			return true
	return false


func _track(delta: float) -> void:
	if Input.is_action_just_pressed(_drop_action()):
		drop_tap_time = Time.get_ticks_msec() / 1000.0
		_start_fall()
		return
	track_timer += delta
	track_move_timer += delta
	if mode == Mode.ENDLESS:
		piece_pos.y = _endless_spawn_row()
	while track_move_timer >= TRACK_STEP:
		track_move_timer -= TRACK_STEP
		if mode == Mode.VERSUS:
			continue  # versus: P2 steers the piece by hand instead
		var target := int(player.position.x / CELL) - 2
		var dir := signi(target - piece_pos.x)
		if dir != 0 and not _piece_collides(piece_rot, piece_pos + Vector2i(dir, 0), true):
			piece_pos.x += dir
	if track_timer >= _track_time():
		_start_fall()


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


## Dash impact from the player slams the piece sideways as far as it can go —
## all the way to the wall or the nearest locked block. Works while falling
## and during the landed grace window.
func shove_piece(dir: int) -> bool:
	if piece_state == PieceState.TRACKING or piece_type == "":
		return false
	var moved := false
	while not _piece_collides(piece_rot, piece_pos + Vector2i(dir, 0), false):
		piece_pos.x += dir
		moved = true
		if _resolve_piece_overlap() or not playing:
			return true
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
	var pr := player.rect().grow(-CRUSH_MARGIN)
	var cell_rects: Array = []
	var overlapping: Array = []
	for c in _cells(piece_type, piece_rot, piece_pos):
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
	var overflow := false
	for c in _cells(piece_type, piece_rot, piece_pos):
		grid[c] = piece_type
		cracked.erase(c)
		if c.y < 0:
			overflow = true
	if overflow and mode != Mode.ENDLESS:
		# Stack spilled over the top: cat dies in escape, P2 loses in versus.
		if mode == Mode.VERSUS:
			_versus_over(1)
		else:
			_kill_player()
		return
	if not _shove_player_out_of_grid():
		_kill_player()
		return
	GameState.score += 10 * level
	var cleared := _clear_lines()
	if cleared > 0:
		total_lines += cleared
		GameState.score += LINE_SCORES[cleared] * level
		if not split:
			EventBus.lines_changed.emit(total_lines)
		if not _shove_player_out_of_grid():
			_kill_player()
			return
	_spawn_piece()


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
	var new_grid := {}
	var new_cracked := {}
	for c in grid:
		if c.y in full_rows:
			continue
		var shift := 0
		for fy in full_rows:
			if c.y < fy:
				shift += 1
		var dest := Vector2i(c.x, c.y + shift)
		new_grid[dest] = grid[c]
		if cracked.has(c):
			new_cracked[dest] = true
	grid = new_grid
	cracked = new_cracked
	return full_rows.size()


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
		GameState.score += BREAK_SCORE
	else:
		cracked[best] = true
	queue_redraw()
	return true


func _spawn_piece() -> void:
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
		bag = Board.PIECES.duplicate()
		bag.shuffle()
	return bag.pop_back()


## In endless mode the piece hovers a fixed number of cells above the
## (rise-only) camera, so it climbs along with the player.
func _endless_spawn_row() -> int:
	if cam == null:
		return 0
	return int(floor(cam.position.y / CELL)) - ENDLESS_SPAWN_AHEAD


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
		if c.x < 0 or c.x >= COLS or c.y >= ROWS:
			return true
		if not ignore_grid and grid.has(c):
			return true
	return false


func _escape() -> void:
	# Split screen: first escape ends the round for both halves.
	if split:
		playing = false
		finished.emit(true)
		return
	level += 1
	GameState.score += ESCAPE_SCORE * (level - 1)
	grid.clear()
	cracked.clear()
	player.respawn(_spawn_point())
	_spawn_piece()
	EventBus.level_changed.emit(level)
	EventBus.player_escaped.emit(level)


## Revive after death ("continue"): blast the blocks around the cat open,
## push the lava back down and resume the run right where it ended.
func revive_player() -> void:
	_erase_cells_around(Vector2i((player.position / CELL).floor()), REVIVE_BLAST)
	var spot := _find_revive_spot()
	player.respawn(spot)
	if mode == Mode.ENDLESS:
		lava_y = maxf(lava_y, spot.y + Player.SIZE / 2.0 + LAVA_REVIVE_GAP)
	playing = true
	is_paused = false
	_clear_spawn_window()
	_spawn_piece()
	queue_redraw()


## Nearest free spot for the revived cat: death position first, then upward,
## then sideways columns. Falls back to the pit-bottom spawn point.
func _find_revive_spot() -> Vector2:
	var half := Player.SIZE / 2.0
	var size := Vector2.ONE * Player.SIZE
	for radius in range(0, COLS):
		var offsets: Array = [0] if radius == 0 else [-radius, radius]
		for sx in offsets:
			var x: float = clampf(player.position.x + sx * CELL, half, COLS * CELL - half)
			for up in range(0, ROWS * 2):
				var p := Vector2(x, player.position.y - up * CELL)
				if p.y - half < 0.0 and mode != Mode.ENDLESS:
					break
				if p.y + half > ROWS * CELL:
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
	break_fx.append([c, 0.0])


func _kill_player() -> void:
	if mode == Mode.VERSUS:
		# The cat got crushed or trapped — round to P2.
		_versus_over(2)
		return
	player.die()
	playing = false
	if split:
		finished.emit(false)
	else:
		EventBus.game_over.emit()
	queue_redraw()


## Difficulty driver: escape scales with level, endless with height climbed,
## versus with pieces spawned this round (rounds get tenser as they run long).
func _difficulty() -> int:
	if mode == Mode.ESCAPE:
		return level
	if mode == Mode.VERSUS:
		return 1 + versus_pieces / VERSUS_RAMP
	return 1 + best_height / 8


func _track_time() -> float:
	return maxf(TRACK_TIME_BASE - (_difficulty() - 1) * 0.4, TRACK_TIME_MIN)


func _fall_interval() -> float:
	return maxf(FALL_INTERVAL_BASE - (_difficulty() - 1) * 0.02, FALL_INTERVAL_MIN)


func _lava_speed() -> float:
	return minf(LAVA_SPEED_BASE + (_difficulty() - 1) * LAVA_SPEED_STEP, LAVA_SPEED_MAX)


func _spawn_point() -> Vector2:
	return Vector2(COLS * CELL / 2.0, ROWS * CELL - Player.SIZE / 2.0)


func _cells(type: String, rot: int, pos: Vector2i) -> Array:
	var result: Array = []
	for c in Board.SHAPES[type][rot]:
		result.append(pos + c)
	return result


func _cell_rect(c: Vector2i) -> Rect2:
	return Rect2(Vector2(c) * CELL, Vector2.ONE * CELL)


func _draw() -> void:
	var w := COLS * CELL
	var h := ROWS * CELL
	var top := 0.0
	if mode == Mode.ENDLESS and cam:
		top = minf(0.0, cam.position.y - VIEW_BELOW)
	_draw_pit_background(w, h, top)
	for x in range(1, COLS):
		draw_line(Vector2(x * CELL, top), Vector2(x * CELL, h), Color(1, 1, 1, 0.04))
	for y in range(int(floor(top / CELL)) + 1, ROWS):
		draw_line(Vector2(0, y * CELL), Vector2(w, y * CELL), Color(1, 1, 1, 0.04))
	var show_hidden := mode == Mode.ENDLESS
	for c in grid:
		if show_hidden or c.y >= 0:
			_draw_cell(c, Board.COLORS[grid[c]])
			if cracked.has(c):
				_draw_crack(c)
	for fx in break_fx:
		var t: float = 1.0 - fx[1] / BREAK_FX_TIME
		var r := _cell_rect(fx[0]).grow(-CELL * 0.5 * (1.0 - t))
		draw_rect(r, Color(1.0, 1.0, 0.8, 0.7 * t))
	if mode != Mode.ENDLESS:
		_draw_doors()
	if piece_type != "":
		_draw_piece()
	var border := Color(1, 1, 1, 0.35)
	if mode != Mode.ENDLESS:
		# Side walls open at the exit rows: draw them with a gap at the doors.
		var door_bottom := (DOOR_ROW_BOTTOM + 1) * CELL
		draw_line(Vector2(-2, -2), Vector2(w + 2, -2), border, 2.0)
		draw_line(Vector2(-2, door_bottom), Vector2(-2, h + 2), border, 2.0)
		draw_line(Vector2(w + 2, door_bottom), Vector2(w + 2, h + 2), border, 2.0)
		draw_line(Vector2(-2, h + 2), Vector2(w + 2, h + 2), border, 2.0)
	else:
		draw_line(Vector2(-2, top), Vector2(-2, h + 2), border, 2.0)
		draw_line(Vector2(w + 2, top), Vector2(w + 2, h + 2), border, 2.0)
		draw_line(Vector2(-2, h + 2), Vector2(w + 2, h + 2), border, 2.0)
		_draw_lava(w)


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
	draw_polygon(PackedVector2Array([
		Vector2(0, top), Vector2(w, top), Vector2(w, h), Vector2(0, h),
	]), PackedColorArray([top_col, top_col, bot_col, bot_col]))
	if mode != Mode.ENDLESS:
		# Warm light shafts slanting in from the two side exits.
		var y0 := DOOR_ROW_TOP * CELL
		var y1 := (DOOR_ROW_BOTTOM + 1) * CELL
		var warm := Color(1.0, 0.95, 0.82, 0.1)
		var faded := Color(1.0, 0.95, 0.82, 0.0)
		draw_polygon(PackedVector2Array([
			Vector2(0, y0), Vector2(0, y1), Vector2(w * 0.55, h * 0.7),
		]), PackedColorArray([warm, warm, faded]))
		draw_polygon(PackedVector2Array([
			Vector2(w, y0), Vector2(w, y1), Vector2(w * 0.45, h * 0.7),
		]), PackedColorArray([warm, warm, faded]))


## One exit tunnel in each side wall, at the top rows.
func _draw_doors() -> void:
	var w := COLS * CELL
	var door_h := (DOOR_ROW_BOTTOM - DOOR_ROW_TOP + 1) * CELL
	var y := DOOR_ROW_TOP * CELL
	var glow := Color(1.0, 0.95, 0.82, 0.18)
	var frame := Color(1.0, 0.95, 0.82, 0.75)
	var font := ThemeDB.fallback_font
	for door in [Rect2(-CELL, y, CELL, door_h), Rect2(w, y, CELL, door_h)]:
		draw_rect(door, glow)
		draw_rect(door, frame, false, 2.0)
	var mid_y := y + door_h / 2.0 + 9.0
	draw_string(font, Vector2(CELL * 0.25, mid_y), "← ESC",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1.0, 0.95, 0.82, 0.9))
	draw_string(font, Vector2(w - CELL * 1.55, mid_y), "ESC →",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1.0, 0.95, 0.82, 0.9))


## Rising lava: hot glowing surface with a slow wave, cooling to dark below.
func _draw_lava(w: float) -> void:
	var bottom := maxf(ROWS * CELL, lava_y) + CELL * 6.0
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


func _draw_crack(c: Vector2i) -> void:
	var p := Vector2(c) * CELL
	var col := Color(1.0, 0.96, 0.84, 0.65)
	draw_polyline(PackedVector2Array([
		p + Vector2(14, 8), p + Vector2(30, 26), p + Vector2(22, 40), p + Vector2(38, 56),
	]), col, 2.5)
	draw_polyline(PackedVector2Array([
		p + Vector2(48, 12), p + Vector2(36, 30), p + Vector2(50, 44),
	]), col, 2.0)


func _draw_cell(c: Vector2i, color: Color) -> void:
	var p := Vector2(c) * CELL
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
