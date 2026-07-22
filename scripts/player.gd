class_name Player
extends Node2D
## Square-block character: run, double-tap dash, jump with air control,
## fast fall. Custom AABB physics against the EscapeBoard grid.

const SIZE := 50.0
const RUN_SPEED := 330.0
const DASH_SPEED := 850.0
const DASH_TIME := 0.22
const DASH_COOLDOWN := 0.25
const DOUBLE_TAP := 0.3
const BREAK_PROBE := 10.0
const KNOCKBACK_SPEED := 420.0
const KNOCKBACK_TIME := 0.15
const WALL_SLIDE_SPEED := 160.0
const WALL_JUMP_PUSH := 430.0
const WALL_JUMP_TIME := 0.18
const GRAVITY := 2300.0
const FAST_FALL_FACTOR := 2.2
const MAX_FALL := 1300.0
const JUMP_VEL := -840.0
const COYOTE := 0.1
const JUMP_BUFFER := 0.12
const STEP := 4.0

var velocity := Vector2.ZERO
var alive := true
var on_floor := false
var dash_timer := 0.0
var dash_dir := 0
var dash_cooldown := 0.0
var coyote_timer := 0.0
var jump_buffer := 0.0
var knockback_timer := 0.0
var knockback_vx := 0.0
var wall_dir := 0  # -1: wall on the left, 1: on the right, 0: none
var wall_jumps_left := 1
var last_tap := {-1: -1e9, 1: -1e9}

@onready var board: EscapeBoard = get_parent()


func respawn(pos: Vector2) -> void:
	position = pos
	velocity = Vector2.ZERO
	alive = true
	on_floor = false
	dash_timer = 0.0
	dash_cooldown = 0.0
	coyote_timer = 0.0
	jump_buffer = 0.0
	knockback_timer = 0.0
	wall_dir = 0
	wall_jumps_left = 1
	queue_redraw()


func die() -> void:
	alive = false
	queue_redraw()


func rect() -> Rect2:
	return Rect2(position - Vector2.ONE * SIZE / 2.0, Vector2.ONE * SIZE)


func _physics_process(delta: float) -> void:
	if not alive or not board.playing or board.is_paused:
		return
	_handle_input(delta)
	_apply_motion(delta)
	queue_redraw()


func _handle_input(delta: float) -> void:
	dash_cooldown = maxf(dash_cooldown - delta, 0.0)
	var now := Time.get_ticks_msec() / 1000.0
	for dir in [-1, 1]:
		var action := "move_left" if dir == -1 else "move_right"
		if Input.is_action_just_pressed(action):
			if now - last_tap[dir] <= DOUBLE_TAP and dash_cooldown <= 0.0:
				dash_timer = DASH_TIME
				dash_dir = dir
				dash_cooldown = DASH_COOLDOWN
			last_tap[dir] = now
	var axis := Input.get_axis("move_left", "move_right")
	if knockback_timer > 0.0:
		knockback_timer -= delta
		velocity.x = knockback_vx
	elif dash_timer > 0.0:
		dash_timer -= delta
		velocity.x = dash_dir * DASH_SPEED
	else:
		velocity.x = axis * RUN_SPEED
	if Input.is_action_just_pressed("jump"):
		jump_buffer = JUMP_BUFFER
	else:
		jump_buffer = maxf(jump_buffer - delta, 0.0)
	coyote_timer = COYOTE if on_floor else maxf(coyote_timer - delta, 0.0)
	wall_dir = _wall_contact()
	if jump_buffer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_VEL
		jump_buffer = 0.0
		coyote_timer = 0.0
	elif jump_buffer > 0.0 and not on_floor and wall_dir != 0 and wall_jumps_left > 0:
		# Wall jump: leap up and away from the wall, once per airtime.
		velocity.y = JUMP_VEL
		knockback_timer = WALL_JUMP_TIME
		knockback_vx = -wall_dir * WALL_JUMP_PUSH
		wall_jumps_left -= 1
		jump_buffer = 0.0
		dash_timer = 0.0
	var g := GRAVITY
	var fast_fall := Input.is_action_pressed("soft_drop")
	if velocity.y > 0.0 and fast_fall:
		g *= FAST_FALL_FACTOR
	velocity.y = minf(velocity.y + g * delta, MAX_FALL)
	# Hug a wall while falling to slide down it slowly (unless fast-falling).
	if not on_floor and wall_dir != 0 and not fast_fall and velocity.y > WALL_SLIDE_SPEED:
		velocity.y = WALL_SLIDE_SPEED


func _apply_motion(delta: float) -> void:
	var hit_h := _move_axis(Vector2(velocity.x * delta, 0.0))
	if hit_h and dash_timer > 0.0 and velocity.x != 0.0:
		# Dash impact smashes one block, then bounces the player off it.
		var dirx := signf(velocity.x)
		var side := rect()
		side.position.x += dirx * BREAK_PROBE
		if board.break_cell_in_rect(side.grow_individual(0.0, -6.0, 0.0, -6.0)):
			dash_timer = 0.0
			knockback_timer = KNOCKBACK_TIME
			knockback_vx = -dirx * KNOCKBACK_SPEED
	var hit_v := _move_axis(Vector2(0.0, velocity.y * delta))
	if hit_v:
		if velocity.y > 0.0:
			on_floor = true
			wall_jumps_left = 1
		elif velocity.y < 0.0:
			# Head-bump smashes the single block above.
			var head := rect()
			head.position.y -= BREAK_PROBE
			board.break_cell_in_rect(head.grow_individual(-6.0, 0.0, -6.0, 0.0))
		velocity.y = 0.0
	else:
		var feet := Rect2(position.x - SIZE / 2.0, position.y + SIZE / 2.0, SIZE, 2.0)
		on_floor = velocity.y >= 0.0 and board.rect_blocked_for_player(feet)
		if on_floor:
			wall_jumps_left = 1


## Returns which side has a wall/block flush against the player.
func _wall_contact() -> int:
	var half := SIZE / 2.0
	var left := Rect2(position.x - half - 2.0, position.y - half + 6.0, 2.0, SIZE - 12.0)
	var right := Rect2(position.x + half, position.y - half + 6.0, 2.0, SIZE - 12.0)
	if board.rect_blocked_for_player(left):
		return -1
	if board.rect_blocked_for_player(right):
		return 1
	return 0


## Moves along one axis in small steps; returns true if blocked.
func _move_axis(motion: Vector2) -> bool:
	var remaining := motion.length()
	if remaining <= 0.0:
		return false
	var dir := motion.normalized()
	while remaining > 0.0:
		var step := minf(remaining, STEP)
		var next := position + dir * step
		if board.rect_blocked_for_player(Rect2(next - Vector2.ONE * SIZE / 2.0, Vector2.ONE * SIZE)):
			# Creep up to the surface pixel by pixel.
			while not board.rect_blocked_for_player(
					Rect2(position + dir - Vector2.ONE * SIZE / 2.0, Vector2.ONE * SIZE)):
				position += dir
			return true
		position = next
		remaining -= step
	return false


func _draw() -> void:
	var half := SIZE / 2.0
	var body := Rect2(-Vector2.ONE * half, Vector2.ONE * SIZE)
	var color := Color("ffd166") if alive else Color("777777")
	if dash_timer > 0.0:
		draw_rect(body.grow(5.0), Color("ffd166", 0.25))
		for i in range(1, 4):
			var ghost := body
			ghost.position.x -= dash_dir * i * 16.0
			draw_rect(ghost, Color("ffd166", 0.22 - i * 0.06))
	draw_rect(body, color)
	draw_rect(body, color.darkened(0.35), false, 3.0)
	var eye := Vector2(6.0, 9.0)
	var look := signf(velocity.x) * 4.0
	draw_rect(Rect2(Vector2(-14.0 + look, -10.0), eye), Color(0.15, 0.15, 0.2))
	draw_rect(Rect2(Vector2(8.0 + look, -10.0), eye), Color(0.15, 0.15, 0.2))
	if not alive:
		draw_line(Vector2(-14, 4), Vector2(14, 10), Color(0.15, 0.15, 0.2), 3.0)
