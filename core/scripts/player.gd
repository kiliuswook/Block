class_name Player
extends Node2D
## Cube-cat character: run, double-tap dash, jump with air control,
## fast fall. Custom AABB physics against the EscapeBoard grid.

const SIZE := 50.0
const SQUASH_TIME := 0.12

const BODY_COLOR := Color("f4e3c8")
const EAR_COLOR := Color("d9a05c")
const DEAD_BODY_COLOR := Color("a8a29a")
const DEAD_EAR_COLOR := Color("7d7770")
const INK_COLOR := Color("4a3b30")
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
const FEVER_JUMP_FACTOR := sqrt(2.0)  # jump height scales with v² — this doubles it
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
var squash_timer := 0.0
var wall_jumps_left := 1
var facing := 1
var last_tap := {-1: -1e9, 1: -1e9}
# Split screen: P2's cat reads its own action set and wears a distinct skin.
var act_left := "move_left"
var act_right := "move_right"
var act_jump := "jump"
var act_drop := "soft_drop"
var act_dash := "dash"
var skin_override := ""
# Per-cat stat multipliers, refreshed from GameState on respawn.
var stat_speed := 1.0
var stat_jump := 1.0
var stat_dash := 1.0
var stat_weight := 1.0
var stat_push := 2  # dash shove power, in cells

@onready var board: EscapeBoard = get_parent()


func _ready() -> void:
	_refresh_stats()


## Reads the selected (or override) cat's stat multipliers.
func _refresh_stats() -> void:
	var skin_id := skin_override if skin_override != "" else GameState.selected_cat
	var stats: Dictionary = GameState.cat_stats(skin_id)
	stat_speed = stats.get("speed", 1.0)
	stat_jump = stats.get("jump", 1.0)
	stat_dash = stats.get("dash", 1.0)
	stat_weight = stats.get("weight", 1.0)
	stat_push = int(stats.get("push", 2))


func respawn(pos: Vector2) -> void:
	_refresh_stats()
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
	facing = 1
	queue_redraw()


func die() -> void:
	alive = false
	queue_redraw()


func rect() -> Rect2:
	return Rect2(position - Vector2.ONE * SIZE / 2.0, Vector2.ONE * SIZE)


func _physics_process(delta: float) -> void:
	if not alive or not board.playing or board.is_paused:
		return
	squash_timer = maxf(squash_timer - delta, 0.0)
	_handle_input(delta)
	_apply_motion(delta)
	queue_redraw()


func _handle_input(delta: float) -> void:
	dash_cooldown = maxf(dash_cooldown - delta, 0.0)
	var now := Time.get_ticks_msec() / 1000.0
	for dir in [-1, 1]:
		var action := act_left if dir == -1 else act_right
		if Input.is_action_just_pressed(action):
			if now - last_tap[dir] <= DOUBLE_TAP and dash_cooldown <= 0.0:
				dash_timer = DASH_TIME
				dash_dir = dir
				dash_cooldown = DASH_COOLDOWN / stat_dash
			last_tap[dir] = now
	var axis := Input.get_axis(act_left, act_right)
	if axis != 0.0:
		facing = int(signf(axis))
	# Shift dash: dashes toward the held direction, or the way we last faced.
	if Input.is_action_just_pressed(act_dash) and dash_cooldown <= 0.0:
		dash_timer = DASH_TIME
		dash_dir = int(signf(axis)) if axis != 0.0 else facing
		dash_cooldown = DASH_COOLDOWN / stat_dash
	if knockback_timer > 0.0:
		knockback_timer -= delta
		velocity.x = knockback_vx
	elif dash_timer > 0.0:
		dash_timer -= delta
		velocity.x = dash_dir * DASH_SPEED * stat_dash
	else:
		velocity.x = axis * RUN_SPEED * stat_speed
	if Input.is_action_just_pressed(act_jump):
		jump_buffer = JUMP_BUFFER
	else:
		jump_buffer = maxf(jump_buffer - delta, 0.0)
	coyote_timer = COYOTE if on_floor else maxf(coyote_timer - delta, 0.0)
	wall_dir = _wall_contact()
	var jump_vel := JUMP_VEL * stat_jump * (FEVER_JUMP_FACTOR if board.fever_active else 1.0)
	if jump_buffer > 0.0 and coyote_timer > 0.0:
		velocity.y = jump_vel
		jump_buffer = 0.0
		coyote_timer = 0.0
	elif jump_buffer > 0.0 and not on_floor and wall_dir != 0 and wall_jumps_left > 0:
		# Wall jump: leap up and away from the wall, once per airtime.
		velocity.y = jump_vel
		knockback_timer = WALL_JUMP_TIME
		knockback_vx = -wall_dir * WALL_JUMP_PUSH
		wall_jumps_left -= 1
		jump_buffer = 0.0
		dash_timer = 0.0
	var g := GRAVITY
	var fast_fall := Input.is_action_pressed(act_drop)
	if velocity.y > 0.0 and fast_fall:
		g *= FAST_FALL_FACTOR * stat_weight
	velocity.y = minf(velocity.y + g * delta, MAX_FALL)
	# Hug a wall while falling to slide down it slowly (unless fast-falling).
	if not on_floor and wall_dir != 0 and not fast_fall and velocity.y > WALL_SLIDE_SPEED:
		velocity.y = WALL_SLIDE_SPEED


func _apply_motion(delta: float) -> void:
	var hit_h := _move_axis(Vector2(velocity.x * delta, 0.0))
	if hit_h and dash_timer > 0.0 and velocity.x != 0.0:
		# Dash impact shoves the falling piece sideways (push stat = cells),
		# or smashes one locked block — either way the player bounces off.
		var dirx := signf(velocity.x)
		var side := rect()
		side.position.x += dirx * BREAK_PROBE
		var probe := side.grow_individual(0.0, -6.0, 0.0, -6.0)
		if board.piece_hits_rect(probe):
			board.shove_piece(int(dirx), stat_push)
			dash_timer = 0.0
			knockback_timer = KNOCKBACK_TIME
			knockback_vx = -dirx * KNOCKBACK_SPEED / stat_weight
		elif board.break_cell_in_rect(probe):
			dash_timer = 0.0
			knockback_timer = KNOCKBACK_TIME
			knockback_vx = -dirx * KNOCKBACK_SPEED / stat_weight
	var hit_v := _move_axis(Vector2(0.0, velocity.y * delta))
	if hit_v:
		if velocity.y > 0.0:
			if not on_floor and velocity.y > 300.0:
				squash_timer = SQUASH_TIME
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
		# Fever: the falling piece is a one-way platform — pass through from
		# below, land on top.
		if not on_floor and board.fever_active and velocity.y >= 0.0:
			var top := board.fever_platform_top(rect(), maxf(velocity.y * delta, 4.0) + 8.0)
			if top < INF:
				var snapped := Rect2(position.x - SIZE / 2.0, top - SIZE, SIZE, SIZE)
				if not board.rect_blocked_for_player(snapped):
					position.y = top - SIZE / 2.0
					if velocity.y > 300.0:
						squash_timer = SQUASH_TIME
					velocity.y = 0.0
					on_floor = true
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
	var look := signf(velocity.x) * 4.0
	var skin_id := skin_override if skin_override != "" else GameState.selected_cat
	var skin: Dictionary = GameState.cat_skin(skin_id)
	var trail: Color = skin.get("body", BODY_COLOR)
	if board and board.fever_active and alive:
		# Fever aura: pulsing golden glow around the invincible cat.
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0)
		draw_rect(body.grow(10.0 + 4.0 * pulse), Color(1.0, 0.85, 0.35, 0.16 + 0.1 * pulse))
		draw_rect(body.grow(4.0), Color(1.0, 0.93, 0.6, 0.22))
	if dash_timer > 0.0:
		draw_rect(body.grow(5.0), Color(trail, 0.22))
		for i in range(1, 4):
			var ghost := body
			ghost.position.x -= dash_dir * i * 16.0
			draw_rect(ghost, Color(trail, 0.2 - i * 0.05))
	# Squash on landing, stretch while airborne.
	var scale_xy := Vector2.ONE
	if squash_timer > 0.0:
		var t := squash_timer / SQUASH_TIME
		scale_xy = Vector2(1.0 + 0.2 * t, 1.0 - 0.24 * t)
	elif not on_floor:
		if velocity.y < -220.0:
			scale_xy = Vector2(0.9, 1.13)
		elif velocity.y > 500.0:
			scale_xy = Vector2(0.94, 1.07)
	draw_set_transform(Vector2(0.0, half * (1.0 - scale_xy.y)), 0.0, scale_xy)
	var mouth_open := not on_floor and velocity.y < -100.0
	paint_cat(self, Vector2.ZERO, SIZE, look, alive, mouth_open, skin)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static var _body_box: StyleBoxFlat


## Draws the cube cat onto any canvas item (player, title screen, ...).
## skin can override colors: {"body": Color, "ear": Color, "ink": Color}.
static func paint_cat(ci: CanvasItem, center: Vector2, s: float, look := 0.0,
		cat_alive := true, mouth_open := false, skin: Dictionary = {}) -> void:
	var half := s / 2.0
	var body_col: Color = skin.get("body", BODY_COLOR) if cat_alive else DEAD_BODY_COLOR
	var ear_col: Color = skin.get("ear", EAR_COLOR) if cat_alive else DEAD_EAR_COLOR
	var ink_col: Color = skin.get("ink", INK_COLOR)
	# Protruding ears (behind the body).
	for sg in [-1.0, 1.0]:
		ci.draw_colored_polygon(PackedVector2Array([
			center + Vector2(sg * s * 0.40, -half + 2.0),
			center + Vector2(sg * s * 0.28, -half - s * 0.16),
			center + Vector2(sg * s * 0.13, -half + 2.0),
		]), ear_col)
	# Rounded body with soft dark outline.
	if _body_box == null:
		_body_box = StyleBoxFlat.new()
		_body_box.anti_aliasing = true
	_body_box.set_corner_radius_all(int(s * 0.22))
	_body_box.set_border_width_all(maxi(2, int(s * 0.055)))
	_body_box.bg_color = body_col
	_body_box.border_color = Color(0.24, 0.18, 0.14, 0.55)
	_body_box.draw(ci.get_canvas_item(), Rect2(center - Vector2.ONE * half, Vector2.ONE * s))
	# Keycap-style ear patches on the top corners.
	var inset := s * 0.12
	for sg in [-1.0, 1.0]:
		ci.draw_colored_polygon(PackedVector2Array([
			center + Vector2(sg * (half - inset), -half + 3.0),
			center + Vector2(sg * (half - s * 0.38), -half + 3.0),
			center + Vector2(sg * (half - inset), -half + s * 0.30),
		]), ear_col)
	# Face: eyes, mouth, blush, whiskers.
	var ex := s * 0.19
	var ey := -s * 0.06
	var er := s * 0.065
	if cat_alive:
		ci.draw_circle(center + Vector2(-ex + look, ey), er, ink_col)
		ci.draw_circle(center + Vector2(ex + look, ey), er, ink_col)
		if mouth_open:
			ci.draw_circle(center + Vector2(look * 0.5, s * 0.15), s * 0.055, Color("e58a86"))
		else:
			var mc := center + Vector2(look * 0.5, s * 0.10)
			var mouth_col := Color(ink_col, 0.85) if skin.has("ink") else Color(0.54, 0.35, 0.29)
			ci.draw_arc(mc + Vector2(-s * 0.045, 0.0), s * 0.05, 0.3, PI - 0.3, 8, mouth_col, s * 0.035)
			ci.draw_arc(mc + Vector2(s * 0.045, 0.0), s * 0.05, 0.3, PI - 0.3, 8, mouth_col, s * 0.035)
		ci.draw_circle(center + Vector2(-s * 0.30, s * 0.09), s * 0.055, Color(0.94, 0.55, 0.55, 0.4))
		ci.draw_circle(center + Vector2(s * 0.30, s * 0.09), s * 0.055, Color(0.94, 0.55, 0.55, 0.4))
	else:
		for sg in [-1.0, 1.0]:
			var c := center + Vector2(sg * ex, ey)
			ci.draw_line(c + Vector2(-er, -er), c + Vector2(er, er), INK_COLOR, s * 0.05)
			ci.draw_line(c + Vector2(er, -er), c + Vector2(-er, er), INK_COLOR, s * 0.05)
	var wh_col := Color(0.35, 0.27, 0.2, 0.75) if cat_alive else Color(0.28, 0.26, 0.24, 0.7)
	if cat_alive and skin.has("ink"):
		wh_col = Color(ink_col, 0.7)
	var wh_w := maxf(1.4, s * 0.028)
	for sg in [-1.0, 1.0]:
		ci.draw_line(center + Vector2(sg * s * 0.34, s * 0.04),
				center + Vector2(sg * s * 0.52, s * 0.01), wh_col, wh_w)
		ci.draw_line(center + Vector2(sg * s * 0.34, s * 0.13),
				center + Vector2(sg * s * 0.52, s * 0.12), wh_col, wh_w)
