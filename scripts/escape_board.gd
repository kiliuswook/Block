class_name EscapeBoard
extends Node2D
## Escape mode: a tetromino tracks the player's column at the top of the
## field, free-falls after a countdown, and locks into the grid. The player
## climbs the stack and escapes through the door at the top. Getting caught
## under a falling piece is death. Reuses SHAPES/KICKS/COLORS from Board.

enum PieceState { TRACKING, FALLING }
enum Mode { ESCAPE, ENDLESS }

const COLS := 10
const ROWS := 14
const CELL := 64.0
const DOOR_MIN := 3
const DOOR_MAX := 6
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
const HEIGHT_SCORE := 10
const FALL_DEATH_MARGIN := 620.0
const ENDLESS_SPAWN_AHEAD := 7  # piece spawns this many cells above the camera cell

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
var level := 1
var total_lines := 0
var playing := false
var is_paused := false
var break_fx: Array = []  # [cell: Vector2i, age: float]
var mode := Mode.ESCAPE
var best_height := 0
var drop_tap_time := -1e9

@onready var player: Player = $Player
@onready var cam: Camera2D = get_node_or_null("Cam")


func start_game() -> void:
	mode = GameState.mode as Mode
	grid.clear()
	cracked.clear()
	bag.clear()
	next_type = ""
	level = 1
	total_lines = 0
	best_height = 0
	is_paused = false
	GameState.reset()
	if cam:
		cam.enabled = mode == Mode.ENDLESS
		cam.position = Vector2(COLS * CELL / 2.0, ROWS * CELL / 2.0)
		cam.reset_smoothing()
	player.respawn(_spawn_point())
	_spawn_piece()
	playing = true
	EventBus.game_started.emit()
	EventBus.lines_changed.emit(0)
	EventBus.level_changed.emit(1)
	EventBus.height_changed.emit(0)
	queue_redraw()


func _process(delta: float) -> void:
	if not playing or is_paused:
		return
	if Input.is_action_just_pressed("rotate_cw"):
		_try_rotate(1)
	if Input.is_action_just_pressed("rotate_ccw"):
		_try_rotate(-1)
	match piece_state:
		PieceState.TRACKING:
			_track(delta)
		PieceState.FALLING:
			_fall(delta)
	for fx in break_fx:
		fx[1] += delta
	break_fx = break_fx.filter(func(fx: Array) -> bool: return fx[1] < BREAK_FX_TIME)
	if mode == Mode.ESCAPE:
		if playing and player.position.y < -CELL * 0.6:
			_escape()
	else:
		_update_endless()
	queue_redraw()


func _update_endless() -> void:
	if not playing or cam == null:
		return
	# Camera only ever rises: follow the player upward, never back down.
	cam.position.y = minf(cam.position.y, player.position.y)
	# Falling below the visible screen is death.
	if player.position.y - Player.SIZE / 2.0 > cam.position.y + FALL_DEATH_MARGIN:
		_kill_player()
		return
	var feet := player.position.y + Player.SIZE / 2.0
	var h := int(round((ROWS * CELL - feet) / CELL))
	if h > best_height:
		GameState.score += (h - best_height) * HEIGHT_SCORE
		best_height = h
		EventBus.height_changed.emit(best_height)


func rect_hits_solid(r: Rect2) -> bool:
	if r.position.x < 0.0 or r.end.x > COLS * CELL:
		return true
	if r.end.y > ROWS * CELL:
		return true
	if mode == Mode.ESCAPE and r.position.y < 0.0:
		var in_door := r.position.x >= DOOR_MIN * CELL and r.end.x <= (DOOR_MAX + 1) * CELL
		if not in_door:
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


## What the player collides with: locked grid, walls, and the falling piece.
## The falling piece is a solid body — the player can never pass through it.
func rect_blocked_for_player(r: Rect2) -> bool:
	return rect_hits_solid(r) or piece_hits_rect(r)


func piece_hits_rect(r: Rect2) -> bool:
	if piece_state != PieceState.FALLING or piece_type == "":
		return false
	for c in _cells(piece_type, piece_rot, piece_pos):
		if _cell_rect(c).intersects(r):
			return true
	return false


func _track(delta: float) -> void:
	if Input.is_action_just_pressed("soft_drop"):
		drop_tap_time = Time.get_ticks_msec() / 1000.0
		_start_fall()
		return
	track_timer += delta
	track_move_timer += delta
	if mode == Mode.ENDLESS:
		piece_pos.y = _endless_spawn_row()
	while track_move_timer >= TRACK_STEP:
		track_move_timer -= TRACK_STEP
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
	# piece has nowhere to start falling — game over in every mode.
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
			_lock_piece()
			return
		piece_pos.y += 1
		if _resolve_piece_overlap():
			return


## Dash impact from the player shoves the falling piece one cell sideways.
func shove_piece(dir: int) -> bool:
	if piece_state != PieceState.FALLING or piece_type == "":
		return false
	if _piece_collides(piece_rot, piece_pos + Vector2i(dir, 0), false):
		return false
	piece_pos.x += dir
	_resolve_piece_overlap()
	return true


func _hard_drop() -> void:
	while playing and not _piece_collides(piece_rot, piece_pos + Vector2i(0, 1), false):
		piece_pos.y += 1
		if _resolve_piece_overlap():
			return
	if playing:
		_lock_piece()


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
	if overflow and mode == Mode.ESCAPE:
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
	EventBus.next_piece_changed.emit(next_type)
	piece_rot = 0
	var spawn_row := 0 if mode == Mode.ESCAPE else _endless_spawn_row()
	piece_pos = Vector2i(clampi(int(player.position.x / CELL) - 2, 0, COLS - 4), spawn_row)
	piece_state = PieceState.TRACKING
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
		if piece_state == PieceState.FALLING:
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
	level += 1
	GameState.score += ESCAPE_SCORE * (level - 1)
	grid.clear()
	cracked.clear()
	player.respawn(_spawn_point())
	_spawn_piece()
	EventBus.level_changed.emit(level)
	EventBus.player_escaped.emit(level)


func _kill_player() -> void:
	player.die()
	playing = false
	EventBus.game_over.emit()
	queue_redraw()


## Difficulty driver: escape scales with level, endless with height climbed.
func _difficulty() -> int:
	if mode == Mode.ESCAPE:
		return level
	return 1 + best_height / 8


func _track_time() -> float:
	return maxf(TRACK_TIME_BASE - (_difficulty() - 1) * 0.4, TRACK_TIME_MIN)


func _fall_interval() -> float:
	return maxf(FALL_INTERVAL_BASE - (_difficulty() - 1) * 0.02, FALL_INTERVAL_MIN)


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
		top = minf(0.0, cam.position.y - FALL_DEATH_MARGIN)
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
	if mode == Mode.ESCAPE:
		_draw_door()
	if piece_type != "":
		_draw_piece()
	if mode == Mode.ESCAPE:
		draw_rect(Rect2(-2, -2, w + 4, h + 4), Color(1, 1, 1, 0.35), false, 2.0)
	else:
		draw_line(Vector2(-2, top), Vector2(-2, h + 2), Color(1, 1, 1, 0.35), 2.0)
		draw_line(Vector2(w + 2, top), Vector2(w + 2, h + 2), Color(1, 1, 1, 0.35), 2.0)
		draw_line(Vector2(-2, h + 2), Vector2(w + 2, h + 2), Color(1, 1, 1, 0.35), 2.0)


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
	if mode == Mode.ESCAPE:
		# Warm light shaft falling from the exit door.
		var lx0 := DOOR_MIN * CELL
		var lx1 := (DOOR_MAX + 1) * CELL
		var spread := CELL * 1.2
		var warm := Color(1.0, 0.95, 0.82, 0.1)
		var faded := Color(1.0, 0.95, 0.82, 0.0)
		draw_polygon(PackedVector2Array([
			Vector2(lx0, 0), Vector2(lx1, 0),
			Vector2(minf(lx1 + spread, w), h), Vector2(maxf(lx0 - spread, 0.0), h),
		]), PackedColorArray([warm, warm, faded, faded]))


func _draw_door() -> void:
	var door := Rect2(DOOR_MIN * CELL, -CELL, (DOOR_MAX - DOOR_MIN + 1) * CELL, CELL)
	draw_rect(door, Color(1.0, 0.95, 0.82, 0.18))
	draw_rect(door, Color(1.0, 0.95, 0.82, 0.75), false, 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, door.position + Vector2(door.size.x / 2.0 - 44.0, CELL / 2.0 + 8.0),
			"ESCAPE", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.95, 0.82, 0.9))
	# Solid ceiling on both sides of the door.
	draw_rect(Rect2(0, -8, DOOR_MIN * CELL, 8), Color(0.55, 0.58, 0.68, 0.5))
	draw_rect(Rect2((DOOR_MAX + 1) * CELL, -8, (COLS - DOOR_MAX - 1) * CELL, 8),
			Color(0.55, 0.58, 0.68, 0.5))


func _draw_piece() -> void:
	var color: Color = Board.COLORS[piece_type]
	if piece_state == PieceState.TRACKING:
		var t := track_timer / _track_time()
		color.a = 0.35 + 0.4 * t
		if t > 0.7 and fmod(track_timer, 0.3) < 0.15:
			color.a = 1.0
	for c in _cells(piece_type, piece_rot, piece_pos):
		if mode == Mode.ENDLESS or c.y >= 0:
			_draw_cell(c, color)
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
