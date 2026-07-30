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
				Sfx.play("dash")
			last_tap[dir] = now
	var axis := Input.get_axis(act_left, act_right)
	if axis != 0.0:
		facing = int(signf(axis))
	# Shift dash: dashes toward the held direction, or the way we last faced.
	if Input.is_action_just_pressed(act_dash) and dash_cooldown <= 0.0:
		dash_timer = DASH_TIME
		dash_dir = int(signf(axis)) if axis != 0.0 else facing
		dash_cooldown = DASH_COOLDOWN / stat_dash
		Sfx.play("dash")
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
	# Fever: blocks are one-way, so the cat can end up buried inside the
	# stack (or fall into a covered-over hole). While submerged it can jump
	# repeatedly and sinks slowly, so it always swims up and out.
	var submerged: bool = board.fever_active and board.rect_hits_solid(rect())
	coyote_timer = COYOTE if on_floor or submerged else maxf(coyote_timer - delta, 0.0)
	wall_dir = _wall_contact()
	var jump_vel := JUMP_VEL * stat_jump * (FEVER_JUMP_FACTOR if board.fever_active else 1.0)
	if jump_buffer > 0.0 and coyote_timer > 0.0:
		velocity.y = jump_vel
		jump_buffer = 0.0
		coyote_timer = 0.0
		Sfx.play("jump")
	elif jump_buffer > 0.0 and not on_floor and wall_dir != 0 and wall_jumps_left > 0:
		# Wall jump: leap up and away from the wall, once per airtime.
		velocity.y = jump_vel
		knockback_timer = WALL_JUMP_TIME
		knockback_vx = -wall_dir * WALL_JUMP_PUSH
		wall_jumps_left -= 1
		jump_buffer = 0.0
		dash_timer = 0.0
		Sfx.play("walljump")
	var g := GRAVITY
	var fast_fall := Input.is_action_pressed(act_drop)
	if velocity.y > 0.0 and fast_fall:
		g *= FAST_FALL_FACTOR * stat_weight
	velocity.y = minf(velocity.y + g * delta, MAX_FALL)
	if submerged:
		# Sinking slowly inside the stack keeps each fever jump a net gain.
		velocity.y = minf(velocity.y, WALL_SLIDE_SPEED)
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
				Sfx.play("land")
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
						Sfx.play("land")
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
static var _glow_box: StyleBoxFlat  # max-affection golden rim


## Small heart glyph — affection marks (forehead, floating by the ears).
static func paint_heart(ci: CanvasItem, at: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(at + Vector2(-r * 0.45, 0.0), r * 0.62, col)
	ci.draw_circle(at + Vector2(r * 0.45, 0.0), r * 0.62, col)
	ci.draw_colored_polygon(PackedVector2Array([
		at + Vector2(-r * 0.99, r * 0.25), at + Vector2(r * 0.99, r * 0.25),
		at + Vector2(0.0, r * 1.35),
	]), col)


## Curled cat tail as a quadratic curve from root to tip (affection stage 2+).
static func _paint_tail(ci: CanvasItem, root: Vector2, ctrl: Vector2, tip: Vector2,
		w: float, col: Color, tip_col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(11):
		var t := i / 10.0
		pts.append(root.lerp(ctrl, t).lerp(ctrl.lerp(tip, t), t))
	ci.draw_polyline(pts, col, w)
	ci.draw_circle(tip, w * 0.62, tip_col)


## Four-point twinkle star (affection stage 2+).
static func paint_sparkle(ci: CanvasItem, at: Vector2, r: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([
		at + Vector2(0.0, -r), at + Vector2(r * 0.28, 0.0),
		at + Vector2(0.0, r), at + Vector2(-r * 0.28, 0.0),
	]), col)
	ci.draw_colored_polygon(PackedVector2Array([
		at + Vector2(-r, 0.0), at + Vector2(0.0, r * 0.28),
		at + Vector2(r, 0.0), at + Vector2(0.0, -r * 0.28),
	]), col)


## Draws the cube cat onto any canvas item (player, title screen, ...).
## skin can override colors: {"body": Color, "ear": Color, "ink": Color}.
static func paint_cat(ci: CanvasItem, center: Vector2, s: float, look := 0.0,
		cat_alive := true, mouth_open := false, skin: Dictionary = {}) -> void:
	var half := s / 2.0
	var body_col: Color = skin.get("body", BODY_COLOR) if cat_alive else DEAD_BODY_COLOR
	var ear_col: Color = skin.get("ear", EAR_COLOR) if cat_alive else DEAD_EAR_COLOR
	var ink_col: Color = skin.get("ink", INK_COLOR)
	var aff := int(skin.get("aff", 1))  # affection looks stage 1..3
	# 나만의 냥: cust가 비어있지 않으면 얼굴·꼬리·무늬를 커스텀 파트로 그린다.
	var cust: Dictionary = skin.get("custom", {})
	if cat_alive and aff >= 3:
		# Max affection: a golden halo with light rays behind the whole cat.
		ci.draw_circle(center, s * 0.85, Color(1.0, 0.9, 0.6, 0.14))
		ci.draw_circle(center, s * 0.70, Color(1.0, 0.88, 0.55, 0.18))
		for i in range(8):
			var a := TAU * i / 8.0 + 0.39
			ci.draw_line(center + Vector2.from_angle(a) * s * 0.74,
					center + Vector2.from_angle(a) * s * 0.98,
					Color(1.0, 0.9, 0.6, 0.4), s * 0.05)
	if cat_alive and not cust.is_empty():
		_paint_custom_tail(ci, center, s, str(cust.get("tail", "none")), ear_col)
	elif cat_alive and aff >= 2:
		# Grown cats sprout a curled tail — two of them at max affection,
		# myth-cat style, with bright cream tips.
		var tip_col := Color(1.0, 0.96, 0.88) if aff >= 3 else ear_col.lightened(0.3)
		if aff >= 3:
			_paint_tail(ci, center + Vector2(s * 0.44, s * 0.36),
					center + Vector2(s * 0.94, s * 0.24), center + Vector2(s * 0.9, -s * 0.18),
					s * 0.1, ear_col, tip_col)
		_paint_tail(ci, center + Vector2(s * 0.44, s * 0.3),
				center + Vector2(s * 0.78, s * 0.1), center + Vector2(s * 0.66, -s * 0.3),
				s * 0.11, ear_col, tip_col)
	# Protruding ears (behind the body) — they grow with affection.
	var ear_h := s * (0.3 if aff >= 2 and cat_alive else 0.16)
	for sg in [-1.0, 1.0]:
		ci.draw_colored_polygon(PackedVector2Array([
			center + Vector2(sg * s * 0.40, -half + 2.0),
			center + Vector2(sg * s * 0.28, -half - ear_h),
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
	if cat_alive and aff >= 3:
		# Max affection: the body itself glows with a golden rim.
		if _glow_box == null:
			_glow_box = StyleBoxFlat.new()
			_glow_box.draw_center = false
			_glow_box.anti_aliasing = true
		_glow_box.set_corner_radius_all(int(s * 0.25))
		_glow_box.set_border_width_all(maxi(2, int(s * 0.05)))
		_glow_box.border_color = Color(1.0, 0.85, 0.4, 0.8)
		_glow_box.draw(ci.get_canvas_item(),
				Rect2(center - Vector2.ONE * (half + s * 0.045), Vector2.ONE * (s + s * 0.09)))
	if cat_alive and not cust.is_empty():
		_paint_custom_pattern(ci, center, s, cust)
	# Keycap-style ear patches on the top corners.
	var inset := s * 0.12
	for sg in [-1.0, 1.0]:
		ci.draw_colored_polygon(PackedVector2Array([
			center + Vector2(sg * (half - inset), -half + 3.0),
			center + Vector2(sg * (half - s * 0.38), -half + 3.0),
			center + Vector2(sg * (half - inset), -half + s * 0.30),
		]), ear_col)
	if cat_alive and not cust.is_empty():
		_paint_custom_paws(ci, center, s, body_col, str(cust.get("paws", "none")))
	elif cat_alive and aff >= 2:
		# Tucked front paws peeking out at the bottom edge.
		for sg in [-1.0, 1.0]:
			ci.draw_circle(center + Vector2(sg * s * 0.18, half - s * 0.04), s * 0.085,
					body_col.lightened(0.22))
	if cat_alive and aff >= 3:
		# Legend look: cheek fluff and crown tufts break the cube silhouette,
		# plus a golden earring on the right ear.
		for sg in [-1.0, 1.0]:
			ci.draw_colored_polygon(PackedVector2Array([
				center + Vector2(sg * half, -s * 0.04),
				center + Vector2(sg * (half + s * 0.13), s * 0.02),
				center + Vector2(sg * half, s * 0.09),
			]), body_col)
			ci.draw_colored_polygon(PackedVector2Array([
				center + Vector2(sg * half, s * 0.12),
				center + Vector2(sg * (half + s * 0.1), s * 0.17),
				center + Vector2(sg * half, s * 0.22),
			]), body_col)
		for i in [-1, 0, 1]:
			ci.draw_colored_polygon(PackedVector2Array([
				center + Vector2(i * s * 0.09 - s * 0.045, -half + 1.0),
				center + Vector2(i * s * 0.09 + s * 0.045, -half + 1.0),
				center + Vector2(i * s * 0.09, -half - s * 0.11),
			]), body_col)
		ci.draw_arc(center + Vector2(s * 0.33, -half + s * 0.02), s * 0.04, 0.0, TAU, 10,
				Color(1.0, 0.84, 0.4), s * 0.028)
	# Face: eyes, mouth, blush, whiskers.
	var ex := s * 0.19
	var ey := -s * 0.06
	var er := s * 0.065
	if cat_alive:
		if not cust.is_empty():
			_paint_custom_face(ci, center, s, look, mouth_open, body_col, cust)
		else:
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
		if aff >= 2 and cust.is_empty():
			# Loved cats: rosier cheeks, eye sparkles, a forehead heart mark
			# and little twinkles floating around the head.
			for sg in [-1.0, 1.0]:
				ci.draw_circle(center + Vector2(sg * s * 0.30, s * 0.09), s * 0.07,
						Color(0.94, 0.5, 0.52, 0.3))
				ci.draw_circle(center + Vector2(sg * ex + look + er * 0.35, ey - er * 0.35),
						er * 0.34, Color(1, 1, 1, 0.92))
			var mark_col := Color(1.0, 0.82, 0.35, 0.95) if aff >= 3 else Color(ink_col, 0.5)
			paint_heart(ci, center + Vector2(0.0, -s * 0.31), s * 0.055, mark_col)
			paint_sparkle(ci, center + Vector2(-s * 0.55, -s * 0.52), s * 0.08,
					Color(1, 1, 1, 0.85))
			paint_sparkle(ci, center + Vector2(s * 0.60, -s * 0.16), s * 0.055,
					Color(1, 1, 1, 0.7))
		if aff >= 3:
			# Max affection: hearts float by both ears, golden twinkles join in.
			paint_heart(ci, center + Vector2(s * 0.48, -half - s * 0.24), s * 0.075,
					Color(0.95, 0.5, 0.6, 0.95))
			paint_heart(ci, center + Vector2(-s * 0.52, -half - s * 0.10), s * 0.05,
					Color(0.95, 0.55, 0.62, 0.85))
			paint_sparkle(ci, center + Vector2(s * 0.52, -s * 0.66), s * 0.095,
					Color(1.0, 0.88, 0.5, 0.95))
			paint_sparkle(ci, center + Vector2(-s * 0.66, s * 0.14), s * 0.065,
					Color(1.0, 0.88, 0.5, 0.8))
	else:
		for sg in [-1.0, 1.0]:
			var c := center + Vector2(sg * ex, ey)
			ci.draw_line(c + Vector2(-er, -er), c + Vector2(er, er), INK_COLOR, s * 0.05)
			ci.draw_line(c + Vector2(er, -er), c + Vector2(-er, er), INK_COLOR, s * 0.05)
	if cust.is_empty() or not cat_alive:
		var wh_col := Color(0.35, 0.27, 0.2, 0.75) if cat_alive else Color(0.28, 0.26, 0.24, 0.7)
		if cat_alive and skin.has("ink"):
			wh_col = Color(ink_col, 0.7)
		var wh_w := maxf(1.4, s * 0.028)
		for sg in [-1.0, 1.0]:
			ci.draw_line(center + Vector2(sg * s * 0.34, s * 0.04),
					center + Vector2(sg * s * 0.52, s * 0.01), wh_col, wh_w)
			ci.draw_line(center + Vector2(sg * s * 0.34, s * 0.13),
					center + Vector2(sg * s * 0.52, s * 0.12), wh_col, wh_w)
	for acc in skin.get("acc", []):
		paint_acc(ci, center, s, acc)


## Draws one procedural accessory (see GameState.ACCESSORIES) on the cube cat.
## acc: {"kind": String, "col": Color, "col2": Color}.
static func paint_acc(ci: CanvasItem, center: Vector2, s: float, acc: Dictionary) -> void:
	var half := s / 2.0
	var col: Color = acc.get("col", Color.WHITE)
	var col2: Color = acc.get("col2", col.darkened(0.3))
	match str(acc.get("kind", "")):
		"beanie":
			# Knit band across the head top with a pompom.
			ci.draw_rect(Rect2(center + Vector2(-s * 0.36, -half - s * 0.13),
					Vector2(s * 0.72, s * 0.16)), col)
			ci.draw_rect(Rect2(center + Vector2(-s * 0.36, -half - s * 0.02),
					Vector2(s * 0.72, s * 0.06)), col2)
			ci.draw_circle(center + Vector2(0.0, -half - s * 0.17), s * 0.08, col2)
		"leaf":
			var base := center + Vector2(0.0, -half - s * 0.02)
			ci.draw_line(base, base + Vector2(0.0, -s * 0.14), col2, s * 0.035)
			ci.draw_circle(base + Vector2(-s * 0.07, -s * 0.17), s * 0.07, col)
			ci.draw_circle(base + Vector2(s * 0.07, -s * 0.17), s * 0.07, col)
		"ribbon":
			var knot := center + Vector2(s * 0.30, -half - s * 0.04)
			for sg in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([
					knot, knot + Vector2(sg * s * 0.16, -s * 0.10),
					knot + Vector2(sg * s * 0.16, s * 0.08),
				]), col)
			ci.draw_circle(knot, s * 0.05, col2)
		"flower":
			var at := center + Vector2(-s * 0.28, -half - s * 0.03)
			for i in range(5):
				var a := TAU * i / 5.0
				ci.draw_circle(at + Vector2.from_angle(a) * s * 0.07, s * 0.055, col)
			ci.draw_circle(at, s * 0.05, col2)
		"wizard":
			ci.draw_rect(Rect2(center + Vector2(-s * 0.34, -half - s * 0.06),
					Vector2(s * 0.68, s * 0.07)), col2)
			ci.draw_colored_polygon(PackedVector2Array([
				center + Vector2(-s * 0.24, -half - s * 0.04),
				center + Vector2(s * 0.24, -half - s * 0.04),
				center + Vector2(s * 0.04, -half - s * 0.42),
			]), col)
			ci.draw_circle(center + Vector2(s * 0.05, -half - s * 0.40), s * 0.045, col2)
		"tophat":
			ci.draw_rect(Rect2(center + Vector2(-s * 0.38, -half - s * 0.05),
					Vector2(s * 0.76, s * 0.07)), col)
			ci.draw_rect(Rect2(center + Vector2(-s * 0.24, -half - s * 0.33),
					Vector2(s * 0.48, s * 0.29)), col)
			ci.draw_rect(Rect2(center + Vector2(-s * 0.24, -half - s * 0.13),
					Vector2(s * 0.48, s * 0.07)), col2)
		"crown":
			var base_y := -half - s * 0.02
			ci.draw_colored_polygon(PackedVector2Array([
				center + Vector2(-s * 0.26, base_y),
				center + Vector2(-s * 0.26, base_y - s * 0.20),
				center + Vector2(-s * 0.13, base_y - s * 0.08),
				center + Vector2(0.0, base_y - s * 0.24),
				center + Vector2(s * 0.13, base_y - s * 0.08),
				center + Vector2(s * 0.26, base_y - s * 0.20),
				center + Vector2(s * 0.26, base_y),
			]), col)
			ci.draw_circle(center + Vector2(0.0, base_y - s * 0.05), s * 0.045, col2)
		"halo":
			var at := center + Vector2(0.0, -half - s * 0.26)
			ci.draw_arc(at, s * 0.20, 0.0, TAU, 24, Color(col2, 0.35), s * 0.09)
			ci.draw_arc(at, s * 0.20, 0.0, TAU, 24, col, s * 0.045)
		"bell":
			ci.draw_rect(Rect2(center + Vector2(-half + s * 0.06, half - s * 0.10),
					Vector2(s - s * 0.12, s * 0.07)), col)
			var bell := center + Vector2(0.0, half - s * 0.01)
			ci.draw_circle(bell, s * 0.08, col2)
			ci.draw_line(bell + Vector2(0.0, s * 0.02), bell + Vector2(0.0, s * 0.08),
					Color(col2, 1.0).darkened(0.45), s * 0.03)
		"scarf":
			ci.draw_rect(Rect2(center + Vector2(-half + s * 0.04, half - s * 0.16),
					Vector2(s - s * 0.08, s * 0.14)), col)
			ci.draw_rect(Rect2(center + Vector2(-s * 0.26, half - s * 0.04),
					Vector2(s * 0.14, s * 0.22)), col2)
		"bowtie":
			var knot := center + Vector2(0.0, half - s * 0.07)
			for sg in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([
					knot, knot + Vector2(sg * s * 0.17, -s * 0.09),
					knot + Vector2(sg * s * 0.17, s * 0.09),
				]), col)
			ci.draw_circle(knot, s * 0.05, col2)
		"bandana":
			ci.draw_rect(Rect2(center + Vector2(-s * 0.30, half - s * 0.12),
					Vector2(s * 0.60, s * 0.07)), col)
			ci.draw_colored_polygon(PackedVector2Array([
				center + Vector2(-s * 0.20, half - s * 0.06),
				center + Vector2(s * 0.20, half - s * 0.06),
				center + Vector2(0.0, half + s * 0.16),
			]), col)
			ci.draw_circle(center + Vector2(0.0, half + s * 0.01), s * 0.025, col2)
		"goldchain":
			ci.draw_arc(center + Vector2(0.0, half - s * 0.20), s * 0.34,
					0.5, PI - 0.5, 14, col, s * 0.05)
			ci.draw_circle(center + Vector2(0.0, half + s * 0.10), s * 0.07, col)
			ci.draw_circle(center + Vector2(0.0, half + s * 0.10), s * 0.035, col2)
		"gemchain":
			ci.draw_arc(center + Vector2(0.0, half - s * 0.20), s * 0.34,
					0.5, PI - 0.5, 14, col, s * 0.035)
			for i in [-1, 0, 1]:
				var at := center + Vector2(i * s * 0.14, half + s * 0.06 - absi(i) * s * 0.035)
				ci.draw_colored_polygon(PackedVector2Array([
					at + Vector2(0.0, -s * 0.05), at + Vector2(s * 0.045, 0.0),
					at + Vector2(0.0, s * 0.05), at + Vector2(-s * 0.045, 0.0),
				]), col2)


# --- Custom cat (나만의 냥이) part painters --------------------------------------
# 스타일 id는 custom_cat.gd의 PARTS 카탈로그와 일치해야 한다.


static func _paint_custom_tail(ci: CanvasItem, center: Vector2, s: float,
		style: String, col: Color) -> void:
	var tip := col.lightened(0.3)
	match style:
		"curl":
			_paint_tail(ci, center + Vector2(s * 0.44, s * 0.3),
					center + Vector2(s * 0.78, s * 0.1), center + Vector2(s * 0.66, -s * 0.3),
					s * 0.11, col, tip)
		"up":
			_paint_tail(ci, center + Vector2(s * 0.46, s * 0.32),
					center + Vector2(s * 0.66, 0.0), center + Vector2(s * 0.58, -s * 0.42),
					s * 0.11, col, tip)
		"fluffy":
			_paint_tail(ci, center + Vector2(s * 0.44, s * 0.3),
					center + Vector2(s * 0.80, s * 0.12), center + Vector2(s * 0.68, -s * 0.26),
					s * 0.17, col, tip)
		"stub":
			_paint_tail(ci, center + Vector2(s * 0.45, s * 0.36),
					center + Vector2(s * 0.62, s * 0.3), center + Vector2(s * 0.64, s * 0.16),
					s * 0.13, col, tip)
		"zigzag":
			var pts := PackedVector2Array([
				center + Vector2(s * 0.44, s * 0.32), center + Vector2(s * 0.68, s * 0.18),
				center + Vector2(s * 0.50, 0.0), center + Vector2(s * 0.72, -s * 0.18),
			])
			ci.draw_polyline(pts, col, s * 0.1)
			ci.draw_circle(pts[3], s * 0.065, tip)
		"long":
			_paint_tail(ci, center + Vector2(s * 0.44, s * 0.34),
					center + Vector2(s * 1.0, s * 0.12), center + Vector2(s * 0.8, -s * 0.5),
					s * 0.1, col, tip)
		"double":
			_paint_tail(ci, center + Vector2(s * 0.44, s * 0.36),
					center + Vector2(s * 0.94, s * 0.24), center + Vector2(s * 0.9, -s * 0.18),
					s * 0.1, col, tip)
			_paint_tail(ci, center + Vector2(s * 0.44, s * 0.3),
					center + Vector2(s * 0.78, s * 0.1), center + Vector2(s * 0.66, -s * 0.3),
					s * 0.11, col, tip)
		"heart":
			_paint_tail(ci, center + Vector2(s * 0.44, s * 0.3),
					center + Vector2(s * 0.78, s * 0.1), center + Vector2(s * 0.66, -s * 0.3),
					s * 0.1, col, col)
			paint_heart(ci, center + Vector2(s * 0.66, -s * 0.34), s * 0.07,
					Color(0.95, 0.5, 0.6))
		"star":
			_paint_tail(ci, center + Vector2(s * 0.44, s * 0.3),
					center + Vector2(s * 0.78, s * 0.1), center + Vector2(s * 0.66, -s * 0.3),
					s * 0.1, col, col)
			paint_sparkle(ci, center + Vector2(s * 0.66, -s * 0.35), s * 0.1,
					Color(1.0, 0.85, 0.4))
		"flame":
			_paint_tail(ci, center + Vector2(s * 0.44, s * 0.3),
					center + Vector2(s * 0.78, s * 0.1), center + Vector2(s * 0.66, -s * 0.3),
					s * 0.12, col, col)
			ci.draw_circle(center + Vector2(s * 0.66, -s * 0.34), s * 0.085,
					Color(0.95, 0.5, 0.2, 0.9))
			ci.draw_circle(center + Vector2(s * 0.665, -s * 0.37), s * 0.05,
					Color(1.0, 0.8, 0.3))
			ci.draw_circle(center + Vector2(s * 0.67, -s * 0.395), s * 0.026,
					Color(1.0, 0.95, 0.7))
		"straight":
			_paint_tail(ci, center + Vector2(s * 0.46, s * 0.3),
					center + Vector2(s * 0.7, s * 0.27), center + Vector2(s * 0.95, s * 0.25),
					s * 0.1, col, tip)
		"question":
			_paint_tail(ci, center + Vector2(s * 0.5, s * 0.1),
					center + Vector2(s * 0.9, -s * 0.35), center + Vector2(s * 0.52, -s * 0.38),
					s * 0.09, col, tip)
			ci.draw_circle(center + Vector2(s * 0.52, s * 0.28), s * 0.05, col)
		"ring":
			var root := center + Vector2(s * 0.44, s * 0.3)
			var ctrl := center + Vector2(s * 0.78, s * 0.1)
			var rtip := center + Vector2(s * 0.66, -s * 0.3)
			_paint_tail(ci, root, ctrl, rtip, s * 0.11, col, tip)
			for t in [0.42, 0.72]:
				var p := root.lerp(ctrl, t).lerp(ctrl.lerp(rtip, t), t)
				ci.draw_circle(p, s * 0.052, col.darkened(0.35))


static func _paint_custom_pattern(ci: CanvasItem, center: Vector2, s: float,
		cust: Dictionary) -> void:
	var pc: Color = cust.get("pattern_col", Color(0.4, 0.3, 0.25))
	var half := s / 2.0
	match str(cust.get("pattern", "none")):
		"stripes":
			for i in [-1, 0, 1]:
				ci.draw_rect(Rect2(center + Vector2(i * s * 0.13 - s * 0.03, -half + s * 0.06),
						Vector2(s * 0.06, s * 0.16)), pc)
		"spots":
			ci.draw_circle(center + Vector2(-s * 0.30, s * 0.28), s * 0.09, pc)
			ci.draw_circle(center + Vector2(s * 0.32, -s * 0.26), s * 0.07, pc)
			ci.draw_circle(center + Vector2(s * 0.28, s * 0.32), s * 0.06, pc)
			ci.draw_circle(center + Vector2(-s * 0.33, -s * 0.30), s * 0.055, pc)
		"patch":
			ci.draw_circle(center + Vector2(s * 0.19, -s * 0.06), s * 0.16, pc)
		"tuxedo":
			ci.draw_colored_polygon(PackedVector2Array([
				center + Vector2(-s * 0.18, half - s * 0.03),
				center + Vector2(s * 0.18, half - s * 0.03),
				center + Vector2(0.0, s * 0.08),
			]), pc)
		"socks":
			for sg in [-1.0, 1.0]:
				var x := -half + s * 0.05 if sg < 0.0 else half - s * 0.29
				ci.draw_rect(Rect2(center + Vector2(x, half - s * 0.13),
						Vector2(s * 0.24, s * 0.10)), pc)
		"forehead":
			ci.draw_colored_polygon(PackedVector2Array([
				center + Vector2(-half + s * 0.06, -half + s * 0.04),
				center + Vector2(0.0, -half + s * 0.04),
				center + Vector2(-s * 0.06, -s * 0.14),
				center + Vector2(-half + s * 0.06, -s * 0.05),
			]), pc)
		"tabby":
			for sg in [-1.0, 1.0]:
				for k in 3:
					var y0 := -s * 0.1 + k * s * 0.16
					ci.draw_line(center + Vector2(sg * (half - s * 0.03), y0),
							center + Vector2(sg * (half - s * 0.22), y0 + s * 0.06),
							pc, s * 0.045)
		"tiger":
			for sg in [-1.0, 1.0]:
				for k in 2:
					ci.draw_rect(Rect2(center + Vector2(
							sg * (half - s * 0.13 - k * s * 0.17) - s * 0.03,
							-s * 0.06 + k * s * 0.08), Vector2(s * 0.06, s * 0.3)), pc)
		"cow":
			ci.draw_circle(center + Vector2(-s * 0.22, -s * 0.18), s * 0.13, pc)
			ci.draw_circle(center + Vector2(-s * 0.12, -s * 0.25), s * 0.09, pc)
			ci.draw_circle(center + Vector2(s * 0.24, s * 0.22), s * 0.12, pc)
			ci.draw_circle(center + Vector2(s * 0.32, s * 0.14), s * 0.08, pc)
		"heart_patch":
			paint_heart(ci, center + Vector2(-s * 0.28, s * 0.24), s * 0.085, pc)
		"star_patch":
			paint_sparkle(ci, center + Vector2(s * 0.29, s * 0.27), s * 0.12, pc)
		"lightning":
			var lp := center + Vector2(-s * 0.29, -s * 0.2)
			ci.draw_colored_polygon(PackedVector2Array([
				lp + Vector2(-s * 0.005, -s * 0.09), lp + Vector2(s * 0.05, -s * 0.09),
				lp + Vector2(s * 0.01, -s * 0.005), lp + Vector2(s * 0.05, -s * 0.005),
				lp + Vector2(-s * 0.035, s * 0.1), lp + Vector2(0.0, s * 0.005),
				lp + Vector2(-s * 0.04, s * 0.005),
			]), pc)
		"half":
			ci.draw_rect(Rect2(center + Vector2(-half + s * 0.06, -half + s * 0.06),
					Vector2(half - s * 0.06, s - s * 0.12)), Color(pc, 0.55))
		"diamond":
			var dp := center + Vector2(s * 0.28, s * 0.28)
			ci.draw_colored_polygon(PackedVector2Array([
				dp + Vector2(0.0, -s * 0.09), dp + Vector2(s * 0.07, 0.0),
				dp + Vector2(0.0, s * 0.09), dp + Vector2(-s * 0.07, 0.0),
			]), pc)
		"belly":
			ci.draw_circle(center + Vector2(0.0, s * 0.31), s * 0.19, pc)


static func _paint_custom_paws(ci: CanvasItem, center: Vector2, s: float,
		body_col: Color, style: String) -> void:
	if style == "none":
		return
	var half := s / 2.0
	var bean := Color(0.93, 0.55, 0.58, 0.95)
	if style == "boots":
		for sg in [-1.0, 1.0]:
			ci.draw_rect(Rect2(center + Vector2(sg * s * 0.18 - s * 0.085, half - s * 0.12),
					Vector2(s * 0.17, s * 0.11)), Color(0.72, 0.32, 0.28))
			ci.draw_rect(Rect2(center + Vector2(sg * s * 0.18 - s * 0.085, half - s * 0.13),
					Vector2(s * 0.17, s * 0.03)), Color(0.95, 0.9, 0.82))
		return
	var paw_col := body_col.lightened(0.22)
	if style == "mittens":
		paw_col = Color(0.96, 0.95, 0.92)
	for sg in [-1.0, 1.0]:
		var at := center + Vector2(sg * s * 0.18, half - s * 0.04)
		ci.draw_circle(at, s * 0.09, paw_col)
		match style:
			"beans":
				ci.draw_circle(at + Vector2(0.0, s * 0.02), s * 0.032, bean)
				for i in [-1, 0, 1]:
					ci.draw_circle(at + Vector2(i * s * 0.038, -s * 0.035), s * 0.016, bean)
			"heart_beans":
				paint_heart(ci, at + Vector2(0.0, s * 0.0), s * 0.032, bean)
			"star_beans":
				paint_sparkle(ci, at + Vector2(0.0, s * 0.005), s * 0.045,
						Color(1.0, 0.85, 0.4, 0.95))


static func _paint_custom_face(ci: CanvasItem, center: Vector2, s: float, look: float,
		mouth_open: bool, body_col: Color, cust: Dictionary) -> void:
	var ex := s * 0.19
	var ey := -s * 0.06
	var er := s * 0.065
	var eye_col: Color = cust.get("eye_col", INK_COLOR)
	match str(cust.get("eyes", "round")):
		"round":
			for sg in [-1.0, 1.0]:
				ci.draw_circle(center + Vector2(sg * ex + look, ey), er, eye_col)
		"sparkle":
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ci.draw_circle(c, er * 1.15, eye_col)
				ci.draw_circle(c + Vector2(er * 0.35, -er * 0.35), er * 0.4,
						Color(1, 1, 1, 0.95))
		"happy":
			for sg in [-1.0, 1.0]:
				ci.draw_arc(center + Vector2(sg * ex + look, ey + er * 0.4), er * 1.05,
						PI, TAU, 10, eye_col, s * 0.038)
		"sleepy":
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ci.draw_line(c + Vector2(-er, 0.0), c + Vector2(er, 0.0), eye_col, s * 0.04)
		"wink":
			ci.draw_circle(center + Vector2(-ex + look, ey), er, eye_col)
			ci.draw_arc(center + Vector2(ex + look, ey + er * 0.4), er * 1.05,
					PI, TAU, 10, eye_col, s * 0.038)
		"star":
			for sg in [-1.0, 1.0]:
				paint_sparkle(ci, center + Vector2(sg * ex + look, ey), er * 1.8, eye_col)
		"heart":
			for sg in [-1.0, 1.0]:
				paint_heart(ci, center + Vector2(sg * ex + look, ey - er * 0.3), er, eye_col)
		"dot":
			for sg in [-1.0, 1.0]:
				ci.draw_circle(center + Vector2(sg * ex + look, ey), er * 0.55, eye_col)
		"angry":
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ci.draw_line(c + Vector2(sg * er * 1.2, -er * 1.4),
						c + Vector2(-sg * er * 0.4, -er * 0.5), eye_col, s * 0.032)
				ci.draw_circle(c + Vector2(0.0, er * 0.25), er * 0.72, eye_col)
		"sad":
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ci.draw_line(c + Vector2(-sg * er * 0.4, -er * 1.4),
						c + Vector2(sg * er * 1.2, -er * 0.5), eye_col, s * 0.032)
				ci.draw_circle(c + Vector2(0.0, er * 0.25), er * 0.72, eye_col)
		"surprised":
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ci.draw_arc(c, er * 1.15, 0.0, TAU, 14, eye_col, s * 0.03)
				ci.draw_circle(c, er * 0.32, eye_col)
		"closed":
			for sg in [-1.0, 1.0]:
				ci.draw_arc(center + Vector2(sg * ex + look, ey - er * 0.3), er,
						0.3, PI - 0.3, 10, eye_col, s * 0.035)
		"glare":
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ci.draw_circle(c, er, eye_col)
				ci.draw_rect(Rect2(c - Vector2(er * 1.1, er * 1.15),
						Vector2(er * 2.2, er * 1.05)), body_col)
				ci.draw_line(c + Vector2(-er * 1.1, -er * 0.1),
						c + Vector2(er * 1.1, -er * 0.1), eye_col, s * 0.028)
		"cross":
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ci.draw_line(c + Vector2(-er * 0.9, -er * 0.9),
						c + Vector2(er * 0.9, er * 0.9), eye_col, s * 0.035)
				ci.draw_line(c + Vector2(er * 0.9, -er * 0.9),
						c + Vector2(-er * 0.9, er * 0.9), eye_col, s * 0.035)
		"uwu":
			for sg in [-1.0, 1.0]:
				ci.draw_polyline(PackedVector2Array([
					center + Vector2(sg * (ex + er * 0.9) + look, ey - er * 0.9),
					center + Vector2(sg * (ex - er * 0.6) + look, ey),
					center + Vector2(sg * (ex + er * 0.9) + look, ey + er * 0.9),
				]), eye_col, s * 0.035)
		"big":
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ci.draw_circle(c, er * 1.5, eye_col)
				ci.draw_circle(c + Vector2(er * 0.5, -er * 0.5), er * 0.5,
						Color(1, 1, 1, 0.95))
				ci.draw_circle(c + Vector2(-er * 0.4, er * 0.5), er * 0.25,
						Color(1, 1, 1, 0.7))
		"moon":
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ci.draw_circle(c, er, eye_col)
				ci.draw_circle(c + Vector2(er * 0.45, -er * 0.25), er * 0.85, body_col)
		"diamond":
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ci.draw_colored_polygon(PackedVector2Array([
					c + Vector2(0.0, -er * 1.25), c + Vector2(er * 0.9, 0.0),
					c + Vector2(0.0, er * 1.25), c + Vector2(-er * 0.9, 0.0),
				]), eye_col)
				ci.draw_circle(c + Vector2(er * 0.2, -er * 0.3), er * 0.25,
						Color(1, 1, 1, 0.9))
		"spiral":
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ci.draw_arc(c, er, PI * 0.3, TAU + PI * 0.1, 14, eye_col, s * 0.028)
				ci.draw_arc(c, er * 0.5, PI * 1.2, TAU + PI * 0.9, 10, eye_col, s * 0.028)
		"lash":
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ci.draw_circle(c, er, eye_col)
				for k in 3:
					var a: float = -PI / 2.0 + sg * (0.35 + k * 0.4)
					ci.draw_line(c + Vector2.from_angle(a) * er,
							c + Vector2.from_angle(a) * er * 1.7, eye_col, s * 0.022)
	# Nose sits between the eyes and the mouth.
	var nose_at := center + Vector2(look * 0.5, s * 0.03)
	var nose_col: Color = cust.get("nose_col", Color("e58a86"))
	match str(cust.get("nose", "tri")):
		"tri":
			ci.draw_colored_polygon(PackedVector2Array([
				nose_at + Vector2(-s * 0.042, -s * 0.016),
				nose_at + Vector2(s * 0.042, -s * 0.016),
				nose_at + Vector2(0.0, s * 0.036),
			]), nose_col)
		"heart":
			paint_heart(ci, nose_at, s * 0.03, nose_col)
		"dot":
			ci.draw_circle(nose_at, s * 0.028, nose_col)
		"square":
			ci.draw_rect(Rect2(nose_at + Vector2(-s * 0.032, -s * 0.022),
					Vector2(s * 0.064, s * 0.05)), nose_col)
		"oval":
			var pts := PackedVector2Array()
			for k in 12:
				var a := TAU * k / 12.0
				pts.append(nose_at + Vector2(cos(a) * s * 0.052, sin(a) * s * 0.026))
			ci.draw_colored_polygon(pts, nose_col)
		"clover":
			ci.draw_circle(nose_at + Vector2(-s * 0.022, s * 0.006), s * 0.02, nose_col)
			ci.draw_circle(nose_at + Vector2(s * 0.022, s * 0.006), s * 0.02, nose_col)
			ci.draw_circle(nose_at + Vector2(0.0, -s * 0.02), s * 0.02, nose_col)
		"shine":
			ci.draw_colored_polygon(PackedVector2Array([
				nose_at + Vector2(-s * 0.042, -s * 0.016),
				nose_at + Vector2(s * 0.042, -s * 0.016),
				nose_at + Vector2(0.0, s * 0.036),
			]), nose_col)
			ci.draw_circle(nose_at + Vector2(-s * 0.012, -s * 0.006), s * 0.011,
					Color(1, 1, 1, 0.95))
	var mcol := Color(0.95, 0.93, 0.88, 0.85) if body_col.get_luminance() < 0.45 \
			else Color(0.54, 0.35, 0.29)
	var mc := center + Vector2(look * 0.5, s * 0.12)
	if mouth_open:
		ci.draw_circle(center + Vector2(look * 0.5, s * 0.15), s * 0.055, Color("e58a86"))
	else:
		match str(cust.get("mouth", "w")):
			"w":
				ci.draw_arc(mc + Vector2(-s * 0.045, -s * 0.02), s * 0.05, 0.3, PI - 0.3,
						8, mcol, s * 0.035)
				ci.draw_arc(mc + Vector2(s * 0.045, -s * 0.02), s * 0.05, 0.3, PI - 0.3,
						8, mcol, s * 0.035)
			"smile":
				ci.draw_arc(mc + Vector2(0.0, -s * 0.03), s * 0.075, 0.35, PI - 0.35,
						10, mcol, s * 0.035)
			"neutral":
				ci.draw_line(mc + Vector2(-s * 0.05, 0.0), mc + Vector2(s * 0.05, 0.0),
						mcol, s * 0.032)
			"meow":
				ci.draw_circle(mc + Vector2(0.0, s * 0.01), s * 0.055, Color(0.45, 0.25, 0.25))
				ci.draw_circle(mc + Vector2(0.0, s * 0.035), s * 0.028, Color("e58a86"))
			"tongue":
				ci.draw_arc(mc + Vector2(-s * 0.045, -s * 0.02), s * 0.05, 0.3, PI - 0.3,
						8, mcol, s * 0.035)
				ci.draw_arc(mc + Vector2(s * 0.045, -s * 0.02), s * 0.05, 0.3, PI - 0.3,
						8, mcol, s * 0.035)
				ci.draw_circle(mc + Vector2(0.0, s * 0.055), s * 0.042, Color("e58a86"))
			"frown":
				ci.draw_arc(mc + Vector2(0.0, s * 0.035), s * 0.07, PI + 0.4, TAU - 0.4,
						10, mcol, s * 0.035)
			"grin":
				ci.draw_arc(mc + Vector2(0.0, -s * 0.03), s * 0.1, 0.3, PI - 0.3,
						12, mcol, s * 0.035)
				for sg in [-1.0, 1.0]:
					ci.draw_colored_polygon(PackedVector2Array([
						mc + Vector2(sg * s * 0.055 - s * 0.018, s * 0.005),
						mc + Vector2(sg * s * 0.055 + s * 0.018, s * 0.005),
						mc + Vector2(sg * s * 0.055, s * 0.04),
					]), Color(1, 1, 1, 0.95))
			"fang":
				ci.draw_arc(mc + Vector2(-s * 0.045, -s * 0.02), s * 0.05, 0.3, PI - 0.3,
						8, mcol, s * 0.035)
				ci.draw_arc(mc + Vector2(s * 0.045, -s * 0.02), s * 0.05, 0.3, PI - 0.3,
						8, mcol, s * 0.035)
				ci.draw_colored_polygon(PackedVector2Array([
					mc + Vector2(s * 0.03, s * 0.0), mc + Vector2(s * 0.08, s * 0.0),
					mc + Vector2(s * 0.055, s * 0.05),
				]), Color(1, 1, 1, 0.95))
			"pout":
				ci.draw_arc(mc + Vector2(0.0, -s * 0.02), s * 0.022, -PI / 2.0, PI / 2.0,
						8, mcol, s * 0.03)
				ci.draw_arc(mc + Vector2(0.0, s * 0.024), s * 0.022, -PI / 2.0, PI / 2.0,
						8, mcol, s * 0.03)
			"zigzag":
				var zpts := PackedVector2Array()
				for k in 7:
					zpts.append(mc + Vector2(-s * 0.07 + k * s * 0.0235,
							(s * 0.016 if k % 2 == 0 else -s * 0.016)))
				ci.draw_polyline(zpts, mcol, s * 0.028)
			"whistle":
				ci.draw_arc(mc, s * 0.032, 0.0, TAU, 12, mcol, s * 0.03)
			"drool":
				ci.draw_arc(mc + Vector2(-s * 0.045, -s * 0.02), s * 0.05, 0.3, PI - 0.3,
						8, mcol, s * 0.035)
				ci.draw_arc(mc + Vector2(s * 0.045, -s * 0.02), s * 0.05, 0.3, PI - 0.3,
						8, mcol, s * 0.035)
				ci.draw_circle(mc + Vector2(s * 0.07, s * 0.055), s * 0.026,
						Color(0.55, 0.75, 0.95, 0.9))
				ci.draw_circle(mc + Vector2(s * 0.075, s * 0.02), s * 0.016,
						Color(0.55, 0.75, 0.95, 0.7))
	match str(cust.get("blush", "pink")):
		"pink":
			for sg in [-1.0, 1.0]:
				ci.draw_circle(center + Vector2(sg * s * 0.30, s * 0.09), s * 0.055,
						Color(0.94, 0.55, 0.55, 0.4))
		"peach":
			for sg in [-1.0, 1.0]:
				ci.draw_circle(center + Vector2(sg * s * 0.30, s * 0.09), s * 0.055,
						Color(0.95, 0.68, 0.45, 0.45))
		"big":
			for sg in [-1.0, 1.0]:
				ci.draw_circle(center + Vector2(sg * s * 0.30, s * 0.10), s * 0.082,
						Color(0.94, 0.5, 0.52, 0.45))
		"line":
			for sg in [-1.0, 1.0]:
				for k in 3:
					ci.draw_line(center + Vector2(sg * (s * 0.24 + k * s * 0.05), s * 0.03),
							center + Vector2(sg * (s * 0.27 + k * s * 0.05), s * 0.14),
							Color(0.94, 0.55, 0.55, 0.55), s * 0.018)
		"heart":
			for sg in [-1.0, 1.0]:
				paint_heart(ci, center + Vector2(sg * s * 0.30, s * 0.08), s * 0.045,
						Color(0.94, 0.5, 0.55, 0.6))
		"star":
			for sg in [-1.0, 1.0]:
				paint_sparkle(ci, center + Vector2(sg * s * 0.30, s * 0.09), s * 0.06,
						Color(1.0, 0.85, 0.5, 0.7))
		"blue":
			for sg in [-1.0, 1.0]:
				ci.draw_circle(center + Vector2(sg * s * 0.30, s * 0.09), s * 0.055,
						Color(0.4, 0.55, 0.85, 0.4))
				ci.draw_line(center + Vector2(sg * s * 0.26, s * 0.04),
						center + Vector2(sg * s * 0.29, s * 0.14),
						Color(0.4, 0.55, 0.85, 0.5), s * 0.016)
	var wh_col := Color(0.95, 0.93, 0.88, 0.8) if body_col.get_luminance() < 0.45 \
			else Color(0.35, 0.27, 0.2, 0.75)
	var wh_w := maxf(1.4, s * 0.028)
	match str(cust.get("whisker", "basic")):
		"basic":
			for sg in [-1.0, 1.0]:
				ci.draw_line(center + Vector2(sg * s * 0.34, s * 0.04),
						center + Vector2(sg * s * 0.52, s * 0.01), wh_col, wh_w)
				ci.draw_line(center + Vector2(sg * s * 0.34, s * 0.13),
						center + Vector2(sg * s * 0.52, s * 0.12), wh_col, wh_w)
		"long":
			for sg in [-1.0, 1.0]:
				ci.draw_line(center + Vector2(sg * s * 0.34, s * 0.02),
						center + Vector2(sg * s * 0.64, -s * 0.04), wh_col, wh_w)
				ci.draw_line(center + Vector2(sg * s * 0.34, s * 0.08),
						center + Vector2(sg * s * 0.66, s * 0.08), wh_col, wh_w)
				ci.draw_line(center + Vector2(sg * s * 0.34, s * 0.14),
						center + Vector2(sg * s * 0.64, s * 0.20), wh_col, wh_w)
		"droop":
			for sg in [-1.0, 1.0]:
				ci.draw_line(center + Vector2(sg * s * 0.34, s * 0.04),
						center + Vector2(sg * s * 0.50, s * 0.12), wh_col, wh_w)
				ci.draw_line(center + Vector2(sg * s * 0.34, s * 0.12),
						center + Vector2(sg * s * 0.48, s * 0.22), wh_col, wh_w)
		"curl":
			for sg in [-1.0, 1.0]:
				ci.draw_arc(center + Vector2(sg * s * 0.44, s * 0.06), s * 0.06,
						0.0, PI, 10, wh_col, wh_w)
				ci.draw_arc(center + Vector2(sg * s * 0.46, s * 0.15), s * 0.045,
						0.0, PI, 10, wh_col, wh_w)
		"up":
			for sg in [-1.0, 1.0]:
				ci.draw_line(center + Vector2(sg * s * 0.34, s * 0.06),
						center + Vector2(sg * s * 0.54, -s * 0.06), wh_col, wh_w)
				ci.draw_line(center + Vector2(sg * s * 0.34, s * 0.13),
						center + Vector2(sg * s * 0.55, s * 0.04), wh_col, wh_w)
		"zig":
			for sg in [-1.0, 1.0]:
				for k in 2:
					var y0 := s * (0.04 + k * 0.09)
					ci.draw_polyline(PackedVector2Array([
						center + Vector2(sg * s * 0.34, y0),
						center + Vector2(sg * s * 0.44, y0 - s * 0.03),
						center + Vector2(sg * s * 0.54, y0 + s * 0.01),
					]), wh_col, wh_w)
		"thick":
			for sg in [-1.0, 1.0]:
				ci.draw_line(center + Vector2(sg * s * 0.34, s * 0.03),
						center + Vector2(sg * s * 0.54, -s * 0.01), wh_col, wh_w * 2.2)
				ci.draw_line(center + Vector2(sg * s * 0.34, s * 0.13),
						center + Vector2(sg * s * 0.54, s * 0.14), wh_col, wh_w * 2.2)
		"single":
			for sg in [-1.0, 1.0]:
				ci.draw_line(center + Vector2(sg * s * 0.34, s * 0.08),
						center + Vector2(sg * s * 0.56, s * 0.05), wh_col, wh_w)
		"spark":
			var sp_col := Color(1.0, 0.85, 0.3, 0.95)
			for sg in [-1.0, 1.0]:
				for k in 2:
					var y0 := s * (0.03 + k * 0.1)
					ci.draw_polyline(PackedVector2Array([
						center + Vector2(sg * s * 0.34, y0),
						center + Vector2(sg * s * 0.45, y0 - s * 0.04),
						center + Vector2(sg * s * 0.56, y0 + s * 0.01),
					]), sp_col, wh_w)
					ci.draw_circle(center + Vector2(sg * s * 0.575, y0 + s * 0.01),
							s * 0.018, sp_col)
	match str(cust.get("mark", "none")):
		"star":
			paint_sparkle(ci, center + Vector2(0.0, -s * 0.30), s * 0.085,
					Color(1.0, 0.85, 0.4))
		"moon":
			var at := center + Vector2(0.0, -s * 0.30)
			ci.draw_circle(at, s * 0.06, Color(1.0, 0.92, 0.6))
			ci.draw_circle(at + Vector2(s * 0.032, -s * 0.012), s * 0.05, body_col)
		"heart":
			paint_heart(ci, center + Vector2(0.0, -s * 0.31), s * 0.055,
					Color(0.95, 0.5, 0.6))
		"freckles":
			var fr := Color(0.55, 0.38, 0.26, 0.8)
			for sg in [-1.0, 1.0]:
				for i in 3:
					ci.draw_circle(center + Vector2(sg * (s * 0.24 + i * s * 0.05),
							s * 0.02 + (i % 2) * s * 0.03), s * 0.014, fr)
		"diamond":
			var at := center + Vector2(0.0, -s * 0.30)
			ci.draw_colored_polygon(PackedVector2Array([
				at + Vector2(0.0, -s * 0.06), at + Vector2(s * 0.045, 0.0),
				at + Vector2(0.0, s * 0.06), at + Vector2(-s * 0.045, 0.0),
			]), Color(0.55, 0.85, 1.0))
			ci.draw_circle(at + Vector2(s * 0.012, -s * 0.018), s * 0.012,
					Color(1, 1, 1, 0.95))
		"lightning":
			var at := center + Vector2(0.0, -s * 0.31)
			ci.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-s * 0.005, -s * 0.06), at + Vector2(s * 0.035, -s * 0.06),
				at + Vector2(s * 0.005, -s * 0.005), at + Vector2(s * 0.035, -s * 0.005),
				at + Vector2(-s * 0.025, s * 0.065), at + Vector2(-s * 0.002, s * 0.005),
				at + Vector2(-s * 0.03, s * 0.005),
			]), Color(1.0, 0.82, 0.3))
		"cross":
			var at := center + Vector2(0.0, -s * 0.30)
			var cc := Color(0.85, 0.4, 0.4, 0.9)
			ci.draw_line(at + Vector2(-s * 0.05, 0.0), at + Vector2(s * 0.05, 0.0),
					cc, s * 0.028)
			ci.draw_line(at + Vector2(0.0, -s * 0.05), at + Vector2(0.0, s * 0.05),
					cc, s * 0.028)
		"dot":
			ci.draw_circle(center + Vector2(0.0, -s * 0.30), s * 0.03,
					Color(0.6, 0.38, 0.28))
		"third_eye":
			var at := center + Vector2(0.0, -s * 0.30)
			var pts := PackedVector2Array()
			for k in 12:
				var a := TAU * k / 12.0
				pts.append(at + Vector2(cos(a) * s * 0.06, sin(a) * s * 0.036))
			ci.draw_colored_polygon(pts, Color(1, 1, 1, 0.95))
			ci.draw_circle(at, s * 0.022, Color(0.4, 0.25, 0.5))
		"band":
			var at := center + Vector2(0.0, -s * 0.30)
			var bc := Color(0.94, 0.85, 0.68, 0.95)
			ci.draw_line(at + Vector2(-s * 0.05, -s * 0.045),
					at + Vector2(s * 0.05, s * 0.045), bc, s * 0.045)
			ci.draw_line(at + Vector2(s * 0.05, -s * 0.045),
					at + Vector2(-s * 0.05, s * 0.045), bc, s * 0.045)
		"clover":
			var at := center + Vector2(0.0, -s * 0.31)
			var gc := Color(0.45, 0.75, 0.4)
			ci.draw_circle(at + Vector2(-s * 0.026, s * 0.006), s * 0.023, gc)
			ci.draw_circle(at + Vector2(s * 0.026, s * 0.006), s * 0.023, gc)
			ci.draw_circle(at + Vector2(0.0, -s * 0.024), s * 0.023, gc)
			ci.draw_line(at + Vector2(0.0, s * 0.01), at + Vector2(s * 0.012, s * 0.05),
					gc, s * 0.014)
	var dark := Color(0.16, 0.13, 0.12, 0.95)
	match str(cust.get("extra", "none")):
		"glasses":
			for sg in [-1.0, 1.0]:
				ci.draw_arc(center + Vector2(sg * ex + look, ey), er * 1.7,
						0.0, TAU, 16, dark, s * 0.03)
			ci.draw_line(center + Vector2(-ex + look + er * 1.7, ey),
					center + Vector2(ex + look - er * 1.7, ey), dark, s * 0.03)
		"round_glasses":
			for sg in [-1.0, 1.0]:
				ci.draw_arc(center + Vector2(sg * ex + look, ey), er * 2.1,
						0.0, TAU, 18, dark, s * 0.022)
			ci.draw_line(center + Vector2(-ex + look + er * 2.1, ey),
					center + Vector2(ex + look - er * 2.1, ey), dark, s * 0.022)
		"monocle":
			ci.draw_arc(center + Vector2(ex + look, ey), er * 1.9,
					0.0, TAU, 16, Color(0.85, 0.72, 0.35), s * 0.028)
			ci.draw_line(center + Vector2(ex + look + er * 1.3, ey + er * 1.3),
					center + Vector2(ex + look + er * 1.8, s * 0.24),
					Color(0.85, 0.72, 0.35), s * 0.02)
		"eyepatch":
			var pc := Color(0.13, 0.11, 0.14)
			ci.draw_circle(center + Vector2(ex + look, ey), er * 1.8, pc)
			ci.draw_line(center + Vector2(-s * 0.5, ey - s * 0.1),
					center + Vector2(ex + look - er * 1.5, ey - er * 0.8), pc, s * 0.035)
			ci.draw_line(center + Vector2(ex + look + er * 1.4, ey - er * 1.0),
					center + Vector2(s * 0.5, ey - s * 0.14), pc, s * 0.035)
		"sunglasses":
			var sg_col := Color(0.1, 0.09, 0.12, 0.96)
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ci.draw_rect(Rect2(c - Vector2(er * 1.6, er * 1.1),
						Vector2(er * 3.2, er * 2.1)), sg_col)
				ci.draw_line(c + Vector2(-er * 1.0, -er * 0.4),
						c + Vector2(-er * 0.2, -er * 0.4), Color(1, 1, 1, 0.35), s * 0.02)
			ci.draw_line(center + Vector2(-ex + look + er * 1.6, ey - er * 0.5),
					center + Vector2(ex + look - er * 1.6, ey - er * 0.5), sg_col, s * 0.03)
		"heart_glasses":
			var hg := Color(0.95, 0.45, 0.6, 0.9)
			for sg in [-1.0, 1.0]:
				paint_heart(ci, center + Vector2(sg * ex + look, ey - er * 0.5),
						er * 1.5, hg)
			ci.draw_line(center + Vector2(-ex + look + er * 1.4, ey),
					center + Vector2(ex + look - er * 1.4, ey), hg, s * 0.026)
		"star_glasses":
			var st := Color(1.0, 0.8, 0.3, 0.95)
			for sg in [-1.0, 1.0]:
				paint_sparkle(ci, center + Vector2(sg * ex + look, ey), er * 2.4, st)
			ci.draw_line(center + Vector2(-ex + look + er * 1.3, ey),
					center + Vector2(ex + look - er * 1.3, ey), st, s * 0.024)
		"mask":
			var mk := Color(0.93, 0.96, 0.97, 0.97)
			ci.draw_rect(Rect2(center + Vector2(-s * 0.24 + look * 0.5, -s * 0.01),
					Vector2(s * 0.48, s * 0.24)), mk)
			for sg in [-1.0, 1.0]:
				ci.draw_line(center + Vector2(sg * (s * 0.24) + look * 0.5, s * 0.05),
						center + Vector2(sg * s * 0.5, -s * 0.02),
						Color(mk, 0.8), s * 0.02)
			ci.draw_line(center + Vector2(-s * 0.18 + look * 0.5, s * 0.07),
					center + Vector2(s * 0.18 + look * 0.5, s * 0.07),
					Color(0.7, 0.78, 0.82, 0.6), s * 0.012)
		"mustache":
			var ms := Color(0.2, 0.16, 0.14, 0.95)
			for sg in [-1.0, 1.0]:
				ci.draw_arc(center + Vector2(sg * s * 0.075 + look * 0.5, s * 0.085),
						s * 0.055, PI, TAU, 10, ms, s * 0.045)
		"fish":
			var fb := Color(0.85, 0.6, 0.3)
			var fat := center + Vector2(s * 0.2 + look * 0.5, s * 0.16)
			var pts := PackedVector2Array()
			for k in 12:
				var a := TAU * k / 12.0
				pts.append(fat + Vector2(cos(a) * s * 0.09, sin(a) * s * 0.045))
			ci.draw_colored_polygon(pts, fb)
			ci.draw_colored_polygon(PackedVector2Array([
				fat + Vector2(s * 0.08, 0.0), fat + Vector2(s * 0.14, -s * 0.045),
				fat + Vector2(s * 0.14, s * 0.045),
			]), fb)
			ci.draw_circle(fat + Vector2(-s * 0.045, -s * 0.008), s * 0.011,
					Color(0.2, 0.15, 0.1))
		"tear":
			var tc := Color(0.5, 0.72, 0.92, 0.9)
			var tat := center + Vector2(-ex + look, ey + er * 2.0)
			ci.draw_circle(tat, s * 0.028, tc)
			ci.draw_colored_polygon(PackedVector2Array([
				tat + Vector2(-s * 0.024, -s * 0.01), tat + Vector2(s * 0.024, -s * 0.01),
				tat + Vector2(0.0, -s * 0.05),
			]), tc)
		"sweat":
			var sc := Color(0.5, 0.72, 0.92, 0.9)
			var sat := center + Vector2(s * 0.36, -s * 0.3)
			ci.draw_circle(sat, s * 0.026, sc)
			ci.draw_colored_polygon(PackedVector2Array([
				sat + Vector2(-s * 0.022, -s * 0.008), sat + Vector2(s * 0.022, -s * 0.008),
				sat + Vector2(0.0, -s * 0.046),
			]), sc)
		"scar":
			var sr := Color(0.6, 0.35, 0.3, 0.85)
			ci.draw_line(center + Vector2(-s * 0.33, -s * 0.24),
					center + Vector2(-s * 0.2, s * 0.0), sr, s * 0.022)
			for k in 2:
				var yy := -s * 0.17 + k * s * 0.09
				ci.draw_line(center + Vector2(-s * 0.335 + k * s * 0.045, yy + s * 0.035),
						center + Vector2(-s * 0.24 + k * s * 0.045, yy - s * 0.02),
						sr, s * 0.016)
