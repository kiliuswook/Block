class_name Board
extends Node2D
## Tetris play field: SRS rotation with wall kicks, 7-bag randomizer,
## hold, ghost piece, soft/hard drop, line clears, level-based gravity.

const COLS := 10
const ROWS := 20
const CELL := 46.0
const PREVIEW_CELL := 22.0
const NEXT_COUNT := 3
const SPAWN := Vector2i(3, -2)
const LOCK_DELAY := 0.5
const MAX_LOCK_RESETS := 15
const DAS := 0.17
const ARR := 0.045
const SOFT_DROP_FACTOR := 20.0
const LINE_SCORES := [0, 100, 300, 500, 800]
const PIECES := ["I", "O", "T", "S", "Z", "J", "L"]
const HOLD_PANEL := Rect2(-186, 0, 146, 96)

const COLORS := {
	"I": Color("4dd9e8"),
	"O": Color("f7d94c"),
	"T": Color("a678de"),
	"S": Color("6fce6f"),
	"Z": Color("e05656"),
	"J": Color("5c7fdd"),
	"L": Color("e8944a"),
}

# 4 rotation states per piece (SRS), cell offsets in a 3x3 (4x4 for I) box.
const SHAPES := {
	"I": [
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
		[Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3)],
		[Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)],
	],
	"O": [
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1)],
	],
	"T": [
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
	],
	"S": [
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)],
		[Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2)],
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
	],
	"Z": [
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2)],
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)],
	],
	"J": [
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(1, 2)],
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2)],
	],
	"L": [
		[Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2)],
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)],
	],
}

# SRS wall-kick offsets, converted to y-down screen coordinates.
const KICKS_JLSTZ := {
	"0>1": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, 2), Vector2i(-1, 2)],
	"1>0": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, -2), Vector2i(1, -2)],
	"1>2": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, -2), Vector2i(1, -2)],
	"2>1": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, 2), Vector2i(-1, 2)],
	"2>3": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, 2), Vector2i(1, 2)],
	"3>2": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, -2), Vector2i(-1, -2)],
	"3>0": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, -2), Vector2i(-1, -2)],
	"0>3": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, 2), Vector2i(1, 2)],
}

const KICKS_I := {
	"0>1": [Vector2i(0, 0), Vector2i(-2, 0), Vector2i(1, 0), Vector2i(-2, 1), Vector2i(1, -2)],
	"1>0": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(-1, 0), Vector2i(2, -1), Vector2i(-1, 2)],
	"1>2": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(2, 0), Vector2i(-1, -2), Vector2i(2, 1)],
	"2>1": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-2, 0), Vector2i(1, 2), Vector2i(-2, -1)],
	"2>3": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(-1, 0), Vector2i(2, -1), Vector2i(-1, 2)],
	"3>2": [Vector2i(0, 0), Vector2i(-2, 0), Vector2i(1, 0), Vector2i(-2, 1), Vector2i(1, -2)],
	"3>0": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-2, 0), Vector2i(1, 2), Vector2i(-2, -1)],
	"0>3": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(2, 0), Vector2i(-1, -2), Vector2i(2, 1)],
}

var grid := {}  # Vector2i -> piece type ("I".."L"); y < 0 is the hidden spawn zone
var bag: Array = []
var queue: Array = []
var current_type := ""
var current_rot := 0
var current_pos := Vector2i.ZERO
var hold_type := ""
var hold_used := false
var playing := false
var is_paused := false
var level := 1
var total_lines := 0
var fall_timer := 0.0
var lock_timer := 0.0
var lock_resets := 0
var das_timer := 0.0


func start_game() -> void:
	grid.clear()
	bag.clear()
	queue.clear()
	hold_type = ""
	hold_used = false
	level = 1
	total_lines = 0
	fall_timer = 0.0
	das_timer = 0.0
	is_paused = false
	GameState.reset()
	for i in NEXT_COUNT:
		queue.append(_draw_from_bag())
	playing = true
	_spawn_next()
	EventBus.game_started.emit()
	EventBus.lines_changed.emit(0)
	EventBus.level_changed.emit(1)
	queue_redraw()


func _process(delta: float) -> void:
	if not playing or is_paused:
		return
	_handle_move_input(delta)
	if Input.is_action_just_pressed("rotate_cw"):
		_try_rotate(1)
	if Input.is_action_just_pressed("rotate_ccw"):
		_try_rotate(-1)
	if Input.is_action_just_pressed("hold_piece"):
		_hold()
	if Input.is_action_just_pressed("hard_drop") and playing:
		_hard_drop()
	if playing:
		_apply_gravity(delta)
	queue_redraw()


func _handle_move_input(delta: float) -> void:
	var left := Input.is_action_pressed("move_left")
	var right := Input.is_action_pressed("move_right")
	if left == right:
		das_timer = 0.0
		return
	var dir := -1 if left else 1
	var action := "move_left" if left else "move_right"
	if Input.is_action_just_pressed(action):
		das_timer = 0.0
		_try_move(Vector2i(dir, 0))
		return
	das_timer += delta
	while das_timer >= DAS + ARR:
		das_timer -= ARR
		if not _try_move(Vector2i(dir, 0)):
			das_timer = DAS
			break


func _apply_gravity(delta: float) -> void:
	if _grounded():
		fall_timer = 0.0
		lock_timer += delta
		if lock_timer >= LOCK_DELAY:
			_lock_piece()
		return
	var interval := _fall_interval()
	var soft := Input.is_action_pressed("soft_drop")
	if soft:
		interval /= SOFT_DROP_FACTOR
	fall_timer += delta
	while fall_timer >= interval and not _grounded():
		fall_timer -= interval
		current_pos.y += 1
		lock_timer = 0.0
		lock_resets = 0
		if soft:
			GameState.score += 1


func _fall_interval() -> float:
	return pow(0.8 - (level - 1) * 0.007, level - 1)


func _try_move(offset: Vector2i) -> bool:
	var target := current_pos + offset
	if _collides(_cells(current_type, current_rot, target)):
		return false
	current_pos = target
	_reset_lock()
	return true


func _try_rotate(dir: int) -> void:
	if current_type == "O":
		return
	var new_rot := (current_rot + dir + 4) % 4
	var key := "%d>%d" % [current_rot, new_rot]
	var kicks: Array = KICKS_I[key] if current_type == "I" else KICKS_JLSTZ[key]
	for kick in kicks:
		var target: Vector2i = current_pos + kick
		if not _collides(_cells(current_type, new_rot, target)):
			current_pos = target
			current_rot = new_rot
			_reset_lock()
			return


func _reset_lock() -> void:
	if lock_timer > 0.0 and lock_resets < MAX_LOCK_RESETS:
		lock_timer = 0.0
		lock_resets += 1


func _hard_drop() -> void:
	var dist := 0
	while not _grounded():
		current_pos.y += 1
		dist += 1
	GameState.score += dist * 2
	_lock_piece()


func _hold() -> void:
	if hold_used:
		return
	var prev := hold_type
	hold_type = current_type
	if prev == "":
		_spawn_next()
	else:
		current_type = prev
		current_rot = 0
		current_pos = SPAWN
		fall_timer = 0.0
		lock_timer = 0.0
		lock_resets = 0
		if _collides(_cells(current_type, current_rot, current_pos)):
			_end_game()
	hold_used = true


func _lock_piece() -> void:
	var cells := _cells(current_type, current_rot, current_pos)
	var all_hidden := true
	for c in cells:
		grid[c] = current_type
		if c.y >= 0:
			all_hidden = false
	if all_hidden:
		_end_game()
		return
	var cleared := _clear_lines()
	if cleared > 0:
		total_lines += cleared
		GameState.score += LINE_SCORES[cleared] * level
		EventBus.lines_changed.emit(total_lines)
		var new_level := int(total_lines / 10.0) + 1
		if new_level != level:
			level = new_level
			EventBus.level_changed.emit(level)
	_spawn_next()


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


func _spawn_next() -> void:
	current_type = queue.pop_front()
	queue.append(_draw_from_bag())
	current_rot = 0
	current_pos = SPAWN
	hold_used = false
	fall_timer = 0.0
	lock_timer = 0.0
	lock_resets = 0
	if _collides(_cells(current_type, current_rot, current_pos)):
		_end_game()


func _end_game() -> void:
	playing = false
	EventBus.game_over.emit()
	queue_redraw()


func _draw_from_bag() -> String:
	if bag.is_empty():
		bag = PIECES.duplicate()
		bag.shuffle()
	return bag.pop_back()


func _cells(type: String, rot: int, pos: Vector2i) -> Array:
	var result: Array = []
	for c in SHAPES[type][rot]:
		result.append(pos + c)
	return result


func _collides(cells: Array) -> bool:
	for c in cells:
		if c.x < 0 or c.x >= COLS or c.y >= ROWS or grid.has(c):
			return true
	return false


func _grounded() -> bool:
	return _collides(_cells(current_type, current_rot, current_pos + Vector2i(0, 1)))


func _ghost_pos() -> Vector2i:
	var p := current_pos
	while not _collides(_cells(current_type, current_rot, p + Vector2i(0, 1))):
		p.y += 1
	return p


func _draw() -> void:
	draw_rect(Rect2(0, 0, COLS * CELL, ROWS * CELL), Color(0.08, 0.09, 0.12))
	for x in range(1, COLS):
		draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, ROWS * CELL), Color(1, 1, 1, 0.04))
	for y in range(1, ROWS):
		draw_line(Vector2(0, y * CELL), Vector2(COLS * CELL, y * CELL), Color(1, 1, 1, 0.04))
	for c in grid:
		if c.y >= 0:
			_draw_cell(c, COLORS[grid[c]])
	if playing and current_type != "":
		var gp := _ghost_pos()
		if gp != current_pos:
			var ghost_color: Color = COLORS[current_type]
			ghost_color.a = 0.22
			for c in _cells(current_type, current_rot, gp):
				if c.y >= 0:
					_draw_cell(c, ghost_color)
		for c in _cells(current_type, current_rot, current_pos):
			if c.y >= 0:
				_draw_cell(c, COLORS[current_type])
	draw_rect(Rect2(-2, -2, COLS * CELL + 4, ROWS * CELL + 4), Color(1, 1, 1, 0.35), false, 2.0)
	draw_rect(HOLD_PANEL, Color(0.08, 0.09, 0.12))
	if hold_type != "":
		var hold_color: Color = COLORS[hold_type]
		if hold_used:
			hold_color = hold_color.darkened(0.5)
		_draw_preview(hold_type, HOLD_PANEL, hold_color)
	for i in queue.size():
		var slot := Rect2(Vector2(COLS * CELL + 40.0, i * 104.0), Vector2(146, 96))
		draw_rect(slot, Color(0.08, 0.09, 0.12))
		_draw_preview(queue[i], slot, COLORS[queue[i]])


func _draw_cell(c: Vector2i, color: Color) -> void:
	var p := Vector2(c) * CELL
	draw_rect(Rect2(p + Vector2.ONE, Vector2(CELL - 2.0, CELL - 2.0)), color)
	draw_rect(Rect2(p + Vector2.ONE, Vector2(CELL - 2.0, CELL - 2.0)), color.darkened(0.3), false, 2.0)


func _draw_preview(type: String, panel: Rect2, color: Color) -> void:
	var cells: Array = SHAPES[type][0]
	var min_c := Vector2i(99, 99)
	var max_c := Vector2i(-99, -99)
	for c in cells:
		min_c = Vector2i(mini(min_c.x, c.x), mini(min_c.y, c.y))
		max_c = Vector2i(maxi(max_c.x, c.x), maxi(max_c.y, c.y))
	var size := Vector2(max_c - min_c + Vector2i.ONE) * PREVIEW_CELL
	var origin := panel.position + (panel.size - size) / 2.0
	for c in cells:
		var p := origin + Vector2(c - min_c) * PREVIEW_CELL
		draw_rect(Rect2(p + Vector2.ONE, Vector2(PREVIEW_CELL - 2.0, PREVIEW_CELL - 2.0)), color)
