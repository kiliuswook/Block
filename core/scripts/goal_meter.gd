extends Control
## Classic mode's LINES goal drawn as a rack of tiles instead of a number: one
## pip per line the level needs, filling with the exit's warm light as the cat
## clears them. Code-drawn like the rest of the pit — no textures.

const FILL := Color("fff3d0")  # exit light: the brightest thing on screen
const FILL_EDGE := Color("f7d354")
const EMPTY := Color("232733")
const EMPTY_EDGE := Color(1, 1, 1, 0.12)
const POP_TIME := 0.35  # a freshly lit pip flares, then settles
const MAX_CELL := 48.0  # tiles never grow past this, however few there are

var quota := 10
var cleared := 0
var per_row := 5  # pips per row; set by the HUD to match the column width
var centered := false  # center the rack in its box (portrait) or left-align it
var _pop := 0.0  # seconds left on the newest pip's flare


func _ready() -> void:
	set_process(false)


func set_goal(lines: int, goal: int) -> void:
	goal = maxi(goal, 1)
	if lines > cleared and goal == quota:
		_pop = POP_TIME
		set_process(true)
	quota = goal
	cleared = clampi(lines, 0, goal)
	queue_redraw()


func _process(delta: float) -> void:
	_pop -= delta
	if _pop <= 0.0:
		_pop = 0.0
		set_process(false)
	queue_redraw()


func _draw() -> void:
	# Balance the rows so the rack never trails a long empty tail: 7 tiles in a
	# 5-wide box lay out 4+3, not 5+2.
	var lines_n := maxi(ceili(float(quota) / per_row), 1)
	var cols := ceili(float(quota) / lines_n)
	var gap := 5.0
	# Square tiles at a fixed size: a short goal makes a short rack, never a row
	# of stretched slabs.
	var cell := minf(minf((size.x - gap * (cols - 1)) / cols,
			(size.y - gap * (lines_n - 1)) / lines_n), MAX_CELL)
	var span := cols * cell + (cols - 1) * gap
	var left := (size.x - span) / 2.0 if centered else 0.0
	# Backing panel so the rack reads as an instrument, not stray blocks.
	var used := Rect2(left, 0.0, span,
			lines_n * cell + (lines_n - 1) * gap).grow(7.0)
	draw_rect(used, Color(0, 0, 0, 0.35))
	draw_rect(used, Color(1, 1, 1, 0.09), false, 2.0)
	for i in range(quota):
		var r := Rect2(left + (i % cols) * (cell + gap),
				(i / cols) * (cell + gap), cell, cell)
		var on := i < cleared
		if on and i == cleared - 1 and _pop > 0.0:
			r = r.grow(5.0 * (_pop / POP_TIME))
		draw_rect(r, FILL if on else EMPTY)
		if on:
			# Light from above: only the top face of a filled tile highlights.
			draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.34)),
					Color(1, 1, 1, 0.45))
		draw_rect(r, FILL_EDGE if on else EMPTY_EDGE, false, 2.0)
