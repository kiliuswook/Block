class_name EscapeBoard
extends Node2D
## Escape mode: a tetromino tracks the player's column at the top of the
## field, free-falls after a countdown, and locks into the grid. The player
## climbs the stack and escapes through the door at the top. Getting caught
## under a falling piece is death. Reuses SHAPES/KICKS/COLORS from Board.

enum PieceState { TRACKING, FALLING }

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
const BREAK_SCORE := 20
const BREAK_FX_TIME := 0.3

var grid := {}  # Vector2i -> piece type
var bag: Array = []
var piece_type := ""
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

@onready var player: Player = $Player


func start_game() -> void:
	grid.clear()
	bag.clear()
	level = 1
	total_lines = 0
	is_paused = false
	GameState.reset()
	player.respawn(_spawn_point())
	_spawn_piece()
	playing = true
	EventBus.game_started.emit()
	EventBus.lines_changed.emit(0)
	EventBus.level_changed.emit(1)
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
	if playing and player.position.y < -CELL * 0.6:
		_escape()
	queue_redraw()


func rect_hits_solid(r: Rect2) -> bool:
	if r.position.x < 0.0 or r.end.x > COLS * CELL:
		return true
	if r.end.y > ROWS * CELL:
		return true
	if r.position.y < 0.0:
		var in_door := r.position.x >= DOOR_MIN * CELL and r.end.x <= (DOOR_MAX + 1) * CELL
		if not in_door:
			return true
	var x0 := int(floor(r.position.x / CELL))
	var x1 := int(floor((r.end.x - 0.01) / CELL))
	var y0 := maxi(int(floor(r.position.y / CELL)), 0)
	var y1 := int(floor((r.end.y - 0.01) / CELL))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if grid.has(Vector2i(x, y)):
				return true
	return false


func _track(delta: float) -> void:
	if Input.is_action_just_pressed("soft_drop"):
		_start_fall()
		return
	track_timer += delta
	track_move_timer += delta
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
	# If the stack has grown into the spawn area, back off upward.
	var guard := 8
	while _piece_collides(piece_rot, piece_pos, false) and guard > 0:
		piece_pos.y -= 1
		guard -= 1
	_resolve_piece_overlap()


func _fall(delta: float) -> void:
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


## The falling piece overlaps the player: shove them out (down or sideways)
## if there is room. Death only when truly pinned — crushed, not bumped.
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
	var candidates := [
		[Vector2(0.0, d_down + 1.0), d_down],
		[Vector2(-(d_left + 1.0), 0.0), d_left],
		[Vector2(d_right + 1.0, 0.0), d_right],
	]
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
	for cand in candidates:
		if cand[1] > CELL:
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
		return false
	_kill_player()
	return true


func _lock_piece() -> void:
	var overflow := false
	for c in _cells(piece_type, piece_rot, piece_pos):
		grid[c] = piece_type
		if c.y < 0:
			overflow = true
	if overflow:
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
	var full_rows: Array = []
	for y in range(ROWS):
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
	for c in grid:
		if c.y in full_rows:
			continue
		var shift := 0
		for fy in full_rows:
			if c.y < fy:
				shift += 1
		new_grid[Vector2i(c.x, c.y + shift)] = grid[c]
	grid = new_grid
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


## Destroys locked blocks overlapping the rect (jump head-bump / dash impact).
func break_cells_in_rect(r: Rect2) -> bool:
	var x0 := int(floor(r.position.x / CELL))
	var x1 := int(floor((r.end.x - 0.01) / CELL))
	var y0 := maxi(int(floor(r.position.y / CELL)), 0)
	var y1 := int(floor((r.end.y - 0.01) / CELL))
	var broke := false
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var c := Vector2i(x, y)
			if grid.has(c):
				grid.erase(c)
				break_fx.append([c, 0.0])
				GameState.score += BREAK_SCORE
				broke = true
	if broke:
		queue_redraw()
	return broke


func _spawn_piece() -> void:
	if bag.is_empty():
		bag = Board.PIECES.duplicate()
		bag.shuffle()
	piece_type = bag.pop_back()
	piece_rot = 0
	piece_pos = Vector2i(clampi(int(player.position.x / CELL) - 2, 0, COLS - 4), 0)
	piece_state = PieceState.TRACKING
	track_timer = 0.0
	track_move_timer = 0.0


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
	player.respawn(_spawn_point())
	_spawn_piece()
	EventBus.level_changed.emit(level)
	EventBus.player_escaped.emit(level)


func _kill_player() -> void:
	player.die()
	playing = false
	EventBus.game_over.emit()
	queue_redraw()


func _track_time() -> float:
	return maxf(TRACK_TIME_BASE - (level - 1) * 0.4, TRACK_TIME_MIN)


func _fall_interval() -> float:
	return maxf(FALL_INTERVAL_BASE - (level - 1) * 0.02, FALL_INTERVAL_MIN)


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
	draw_rect(Rect2(0, 0, w, h), Color(0.08, 0.09, 0.12))
	for x in range(1, COLS):
		draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, h), Color(1, 1, 1, 0.04))
	for y in range(1, ROWS):
		draw_line(Vector2(0, y * CELL), Vector2(w, y * CELL), Color(1, 1, 1, 0.04))
	for c in grid:
		if c.y >= 0:
			_draw_cell(c, Board.COLORS[grid[c]])
	for fx in break_fx:
		var t: float = 1.0 - fx[1] / BREAK_FX_TIME
		var r := _cell_rect(fx[0]).grow(-CELL * 0.5 * (1.0 - t))
		draw_rect(r, Color(1.0, 1.0, 0.8, 0.7 * t))
	_draw_door()
	if piece_type != "":
		_draw_piece()
	draw_rect(Rect2(-2, -2, w + 4, h + 4), Color(1, 1, 1, 0.35), false, 2.0)


func _draw_door() -> void:
	var door := Rect2(DOOR_MIN * CELL, -CELL, (DOOR_MAX - DOOR_MIN + 1) * CELL, CELL)
	draw_rect(door, Color(0.3, 0.9, 0.5, 0.18))
	draw_rect(door, Color(0.3, 0.9, 0.5, 0.7), false, 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, door.position + Vector2(door.size.x / 2.0 - 44.0, CELL / 2.0 + 8.0),
			"ESCAPE", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.5, 1.0, 0.7, 0.9))
	# Solid ceiling on both sides of the door.
	draw_rect(Rect2(0, -8, DOOR_MIN * CELL, 8), Color(1, 1, 1, 0.35))
	draw_rect(Rect2((DOOR_MAX + 1) * CELL, -8, (COLS - DOOR_MAX - 1) * CELL, 8),
			Color(1, 1, 1, 0.35))


func _draw_piece() -> void:
	var color: Color = Board.COLORS[piece_type]
	if piece_state == PieceState.TRACKING:
		var t := track_timer / _track_time()
		color.a = 0.35 + 0.4 * t
		if t > 0.7 and fmod(track_timer, 0.3) < 0.15:
			color.a = 1.0
	for c in _cells(piece_type, piece_rot, piece_pos):
		if c.y >= 0:
			_draw_cell(c, color)
	if piece_state == PieceState.TRACKING:
		var remain := ceili(_track_time() - track_timer)
		var top_left := Vector2(piece_pos) * CELL
		draw_string(ThemeDB.fallback_font, top_left + Vector2(CELL * 1.6, CELL * 1.4),
				str(remain), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1, 1, 1, 0.9))


func _draw_cell(c: Vector2i, color: Color) -> void:
	var p := Vector2(c) * CELL
	draw_rect(Rect2(p + Vector2.ONE, Vector2(CELL - 2.0, CELL - 2.0)), color)
	draw_rect(Rect2(p + Vector2.ONE, Vector2(CELL - 2.0, CELL - 2.0)),
			color.darkened(0.3), false, 2.0)
