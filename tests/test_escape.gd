extends Node
## Headless smoke test for EscapeBoard logic.
## Run: godot --headless --path . res://tests/test_escape.tscn

var failures := 0


func _ready() -> void:
	# 아래 기계 판정들은 밀폐 우물(스테이지 모드) 기준이다.
	GameState.mode = GameState.MODE_CLASSIC
	var board: Node2D = load("res://core/scripts/escape_board.gd").new()
	var player: Node2D = load("res://core/scripts/player.gd").new()
	player.name = "Player"
	board.add_child(player)
	add_child(board)
	board.start_game()

	_check(board.playing, "game starts in playing state")
	_check(board.piece_type in Board.PIECES, "a piece has spawned")
	_check(board.piece_state == board.PieceState.TRACKING, "piece starts tracking")
	_check(board.next_type in Board.PIECES, "next piece is queued")
	var queued: String = board.next_type
	board._spawn_piece()
	_check(board.piece_type == queued, "queued piece becomes the current piece")

	# Solidity queries
	var c := EscapeBoard.CELL
	_check(board.rect_hits_solid(Rect2(-5, 300, 10, 10)), "left wall is solid")
	_check(board.rect_hits_solid(Rect2(EscapeBoard.COLS * c - 5, 300, 10, 10)),
			"right wall is solid")
	_check(board.rect_hits_solid(Rect2(100, board.rows * c - 5, 10, 10)), "floor is solid")
	_check(board.rect_hits_solid(Rect2(100, -20, 10, 10)), "ceiling is solid")
	# 우물은 사방이 막혀 있다 — 옛 스토리 모드의 옆벽 출구는 없어졌다.
	var wall_y := 6.0 * c + 10.0
	_check(board.rect_hits_solid(Rect2(-30, wall_y, 10, 10)), "left wall has no exit")
	_check(board.rect_hits_solid(Rect2(EscapeBoard.COLS * c + 20, wall_y, 10, 10)),
			"right wall has no exit")
	board.grid[Vector2i(4, 10)] = "T"
	_check(board.rect_hits_solid(Rect2(4 * c + 10, 10 * c + 10, 10, 10)), "locked cell is solid")
	board.grid.clear()

	# Line clear shifts cells down
	for x in range(EscapeBoard.COLS):
		board.grid[Vector2i(x, EscapeBoard.PIT_ROWS - 1)] = "O"
	board.grid[Vector2i(0, EscapeBoard.PIT_ROWS - 2)] = "T"
	_check(board._clear_lines() == 1, "full row clears")
	_check(board.grid.has(Vector2i(0, EscapeBoard.PIT_ROWS - 1)), "cell above shifted down")
	board.grid.clear()

	# Two-stage breaking: first hit cracks, second destroys — one block at a time
	var probe := Rect2(4 * c + 30, 10 * c + 30, 10, 10)
	board.grid[Vector2i(4, 10)] = "T"
	_check(board.break_cell_in_rect(probe), "first hit registers")
	_check(board.grid.has(Vector2i(4, 10)), "cracked block still stands")
	_check(board.cracked.has(Vector2i(4, 10)), "block is marked cracked")
	_check(board.break_cell_in_rect(probe), "second hit registers")
	_check(not board.grid.has(Vector2i(4, 10)), "second hit destroys the block")
	_check(not board.break_cell_in_rect(probe), "empty cell breaks nothing")
	board.grid[Vector2i(4, 10)] = "T"
	board.grid[Vector2i(5, 10)] = "T"
	var wide := Rect2(4 * c + 20, 10 * c + 20, 80, 20)
	board.break_cell_in_rect(wide)
	board.break_cell_in_rect(wide)
	_check(not board.grid.has(Vector2i(4, 10)) and board.grid.has(Vector2i(5, 10)),
			"only the nearest block breaks, neighbor survives")
	_check(not board.cracked.has(Vector2i(5, 10)), "neighbor is not even cracked")
	board.grid.clear()
	board.cracked.clear()

	# Wall contact detection (for wall slide / wall jump)
	player.position = Vector2(Player.SIZE / 2.0, 500.0)
	_check(player._wall_contact() == -1, "left wall contact detected")
	player.position = Vector2(EscapeBoard.COLS * c - Player.SIZE / 2.0, 500.0)
	_check(player._wall_contact() == 1, "right wall contact detected")
	player.position = Vector2(320.0, 500.0)
	_check(player._wall_contact() == 0, "no wall contact in open air")
	board.grid[Vector2i(6, 7)] = "J"
	player.position = Vector2(6 * c - Player.SIZE / 2.0, 7 * c + 32.0)
	_check(player._wall_contact() == 1, "block face counts as a wall")
	board.grid.clear()

	# Cracks follow blocks down through a line clear
	for x in range(EscapeBoard.COLS):
		board.grid[Vector2i(x, EscapeBoard.PIT_ROWS - 1)] = "O"
	board.grid[Vector2i(0, EscapeBoard.PIT_ROWS - 2)] = "T"
	board.cracked[Vector2i(0, EscapeBoard.PIT_ROWS - 2)] = true
	board._clear_lines()
	_check(board.cracked.has(Vector2i(0, EscapeBoard.PIT_ROWS - 1)), "crack shifted down with its block")
	board.grid.clear()
	board.cracked.clear()

	# A falling piece bumping an airborne player shoves them instead of killing
	board.piece_type = "O"
	board.piece_rot = 0
	board.piece_state = board.PieceState.FALLING
	board.piece_pos = Vector2i(3, 4)  # O cells span y 4..5, bottom edge at 6*CELL
	player.position = Vector2(5 * c, 6 * c + Player.SIZE / 2.0 - 20.0)  # 20px overlap from below
	board._resolve_piece_overlap()
	_check(player.alive, "bumped airborne player survives")
	_check(player.position.y > 6 * c, "player was shoved below the piece")

	# The falling piece is solid to the player — no passing through it
	_check(board.piece_hits_rect(Rect2(4 * c + 10, 4 * c + 10, 10, 10)),
			"falling piece cell blocks the player")
	_check(board.rect_blocked_for_player(Rect2(4 * c + 10, 4 * c + 10, 10, 10)),
			"player collision includes the falling piece")
	board.piece_state = board.PieceState.TRACKING
	_check(not board.piece_hits_rect(Rect2(4 * c + 10, 4 * c + 10, 10, 10)),
			"tracking piece is not solid")
	board.piece_state = board.PieceState.FALLING

	# Tracking target covers a wall-hugging cat even when the piece's occupied
	# cells sit inside the 4-wide box (vertical I = one column, rotated T = two).
	player.position = Vector2(EscapeBoard.COLS * c - Player.SIZE / 2.0, 700.0)
	board.piece_type = "I"
	board.piece_rot = 3  # occupies x offset 1 only
	_check(board._track_target() + 1 == EscapeBoard.COLS - 1,
			"vertical I tracks all the way to the right wall")
	board.piece_rot = 0  # occupies x offsets 0..3 — keeps the old -2 centering
	_check(board._track_target() == EscapeBoard.COLS - 3, "flat I keeps the -2 centering")
	board.piece_type = "T"
	board.piece_rot = 3  # occupies x offsets 0..1
	_check(board._track_target() + 1 == EscapeBoard.COLS - 1,
			"rotated T reaches a right-wall cat")
	player.position = Vector2(Player.SIZE / 2.0, 700.0)
	board.piece_rot = 1  # occupies x offsets 1..2
	_check(board._track_target() + 1 <= 0, "rotated T reaches a left-wall cat")
	board.piece_type = "O"
	board.piece_rot = 0

	# Dash impact slams the piece sideways all the way to the wall
	player.position = Vector2(2 * c, 700.0)  # out of the piece's way
	board.piece_pos = Vector2i(3, 4)
	_check(board.shove_piece(1), "shove pushes the piece right")
	_check(board.piece_pos == Vector2i(EscapeBoard.COLS - 3, 4), "piece slammed into the right wall")
	_check(not board.shove_piece(1), "shove into the wall fails")
	board.grid[Vector2i(3, 4)] = "T"
	_check(board.shove_piece(-1), "shove pushes the piece left")
	_check(board.piece_pos == Vector2i(3, 4), "piece stops against a locked block")
	board.grid.clear()
	board.piece_state = board.PieceState.TRACKING
	_check(not board.shove_piece(1), "tracking piece cannot be shoved")
	board.piece_state = board.PieceState.FALLING

	# Push stat: max_cells caps how far one dash shoves the piece
	board.piece_pos = Vector2i(3, 4)
	_check(board.shove_piece(1, 1), "limited shove moves the piece")
	_check(board.piece_pos == Vector2i(4, 4), "push power 1 shoves exactly one cell")
	board.piece_pos = Vector2i(3, 4)
	_check(board.shove_piece(1, 3), "push power 3 shove moves")
	_check(board.piece_pos == Vector2i(6, 4), "push power 3 shoves three cells")

	# Landed grace: the piece rests shovable for a moment before locking
	board.piece_pos = Vector2i(3, board.rows - 2)  # O resting on the floor
	board._fall(1.0)
	_check(board.piece_state == board.PieceState.LANDED, "piece lands into the grace state")
	_check(board.grid.is_empty(), "landed piece has not locked yet")
	_check(board.piece_hits_rect(Rect2(4 * c + 10, (board.rows - 1) * c + 10, 10, 10)),
			"landed piece is still solid")
	_check(board.shove_piece(-1), "landed piece can still be shoved")
	_check(board.piece_pos.x == -1, "landed piece slammed into the left wall")
	board._landed(EscapeBoard.LOCK_GRACE)
	_check(not board.grid.is_empty(), "grace expiry locks the piece")
	_check(board.piece_state == board.PieceState.TRACKING, "next piece starts tracking")

	# A falling piece landing on a grounded player kills them
	board.piece_type = "O"  # fixed shape: the random next piece may shove instead
	board.piece_rot = 0
	board.piece_state = board.PieceState.FALLING
	board.piece_pos = Vector2i(3, board.rows - 2)
	player.position = board._spawn_point()
	board._resolve_piece_overlap()
	_check(not player.alive, "falling piece crushes pinned player")
	_check(not board.playing, "crush ends the game")

	# --- Endless (infinite stairs) mode ---
	GameState.mode = GameState.MODE_ENDLESS
	var b2: Node2D = load("res://core/scripts/escape_board.gd").new()
	var p2: Node2D = load("res://core/scripts/player.gd").new()
	p2.name = "Player"
	b2.add_child(p2)
	var cam2 := Camera2D.new()
	cam2.name = "Cam"
	b2.add_child(cam2)
	add_child(b2)
	b2.start_game()
	_check(b2.mode == b2.Mode.ENDLESS, "endless mode starts")
	_check(not b2.rect_hits_solid(Rect2(100, -200, 10, 10)), "no ceiling in endless")
	b2.piece_type = "O"
	b2.piece_rot = 0
	b2.piece_state = b2.PieceState.FALLING
	b2.piece_pos = Vector2i(0, -6)
	b2._lock_piece()
	_check(b2.playing, "locking above the top keeps the game running")
	_check(b2.grid.has(Vector2i(1, -5)), "cells lock at negative rows")
	_check(b2.rect_hits_solid(Rect2(1 * c + 30, -5 * c + 30, 10, 10)), "negative-row cell is solid")
	cam2.position = Vector2(320, 448)
	p2.position = Vector2(320, 200)
	# The camera sits above the player by 1/6 of the viewport height, keeping
	# the cat at ~1/3 from the screen bottom with open space above. 화면 픽셀
	# 거리라 카메라 줌으로 나눠야 월드 거리가 된다 (b2.view_zoom).
	var cam_off: float = b2.get_viewport_rect().size.y / 6.0 / b2.view_zoom
	b2._update_endless(0.016)
	_check(absf(cam2.position.y - (200.0 - cam_off)) < 0.01, "camera follows the player up")
	_check(b2.best_height > 0, "height is tracked")
	var lava_before: float = b2.lava_y
	p2.position = Vector2(320, 400)
	b2._update_endless(0.016)
	_check(absf(cam2.position.y - (400.0 - cam_off)) < 0.01,
			"camera follows the player back down")
	_check(p2.alive, "falling down a hole is not death by itself")
	_check(b2.lava_y < lava_before, "lava rises over time")
	b2.lava_y = p2.position.y  # lava reaches the player's feet
	b2._update_endless(0.016)
	_check(not p2.alive, "touching lava is death")

	# Endless line clears: the stack stays floating (no collapse) and the lava
	# is shoved back down.
	b2.grid.clear()
	b2.cracked.clear()
	for x in range(EscapeBoard.COLS):
		b2.grid[Vector2i(x, 6)] = "O"
	b2.grid[Vector2i(4, 5)] = "T"
	b2.cracked[Vector2i(4, 5)] = true
	b2.lava_y = 2000.0
	var lava_pushed_from: float = b2.lava_y
	var endless_cleared: int = b2._clear_lines()
	_check(endless_cleared == 1, "endless full row clears")
	_check(not b2.grid.has(Vector2i(0, 6)), "cleared row is gone")
	_check(b2.grid.has(Vector2i(4, 5)), "endless clear leaves the stack floating")
	_check(b2.cracked.has(Vector2i(4, 5)), "endless clear keeps the crack in place")
	b2._endless_line_reward(endless_cleared)
	_check(b2.lava_y > lava_pushed_from, "line clear shoves the lava down")

	GameState.mode = GameState.MODE_CLASSIC

	# Classic Tetris block out: stack reaching the spawn area ends the game
	var b3: Node2D = load("res://core/scripts/escape_board.gd").new()
	var p3: Node2D = load("res://core/scripts/player.gd").new()
	p3.name = "Player"
	b3.add_child(p3)
	add_child(b3)
	b3.start_game()
	for x in range(EscapeBoard.COLS):
		for y in range(3):
			b3.grid[Vector2i(x, y)] = "O"
	b3._spawn_piece()
	_check(not b3.playing, "escape: piece spawning inside the stack ends the game")

	GameState.mode = GameState.MODE_ENDLESS
	var b4: Node2D = load("res://core/scripts/escape_board.gd").new()
	var p4: Node2D = load("res://core/scripts/player.gd").new()
	p4.name = "Player"
	b4.add_child(p4)
	var cam4 := Camera2D.new()
	cam4.name = "Cam"
	b4.add_child(cam4)
	add_child(b4)
	b4.start_game()
	var spawn_row: int = b4._endless_spawn_row()
	for x in range(EscapeBoard.COLS):
		for y in range(spawn_row, spawn_row + 3):
			b4.grid[Vector2i(x, y)] = "O"
	b4._spawn_piece()
	_check(not b4.playing, "endless: piece spawning inside the stack ends the game")

	# --- Classic mode: arcade rules, cat controls ------------------------------
	GameState.mode = GameState.MODE_CLASSIC
	var cl: Node2D = load("res://core/scripts/escape_board.gd").new()
	var clp: Node2D = load("res://core/scripts/player.gd").new()
	clp.name = "Player"
	cl.add_child(clp)
	add_child(cl)
	cl.start_game()
	_check(cl.playing, "classic: game starts")
	_check(cl.rows == EscapeBoard.PIT_ROWS, "classic: standard 20-row well")
	_check(cl.rect_hits_solid(Rect2(100, cl.rows * c + 5, 10, 10)),
			"classic: floor sits at the 20-row bottom")
	_check(not cl.rect_hits_solid(Rect2(100, 16.0 * c, 10, 10)),
			"classic: mid-pit is open air")
	_check(cl.rect_hits_solid(Rect2(-30, c, 10, 10)),
			"classic: left wall is solid")
	_check(cl.rect_hits_solid(Rect2(EscapeBoard.COLS * c + 20, c, 10, 10)),
			"classic: right wall is solid")
	# NES gravity mapping: stage 1 keeps base pacing, deep stages hit the floor.
	_check(absf(cl._track_time() - EscapeBoard.TRACK_TIME_BASE) < 0.01,
			"classic: stage 1 keeps the full tracking window")
	_check(Board.classic_speed(1) == 1 and Board.classic_speed(2) == 1
			and Board.classic_speed(3) == 2,
			"classic: gravity steps up every other level")
	cl.level = 17
	_check(cl._track_time() <= 1.01, "classic: deep levels bottom out the window")
	_check(cl._fall_interval() <= 0.05, "classic: deep levels slam pieces down")
	cl.level = 59
	_check(cl._fall_interval() <= 0.031, "classic: the kill-screen speed still lands")
	# Marathon creep: time survived tightens gravity on top of the level ramp.
	cl.level = 1
	cl.run_time = 0.0
	var fresh_fall: float = cl._fall_interval()
	cl.run_time = EscapeBoard.SPEED_CREEP_TIME * 3.0
	_check(cl._speed_creep() == 3, "classic: the creep adds a step per stretch played")
	_check(cl._fall_interval() < fresh_fall,
			"classic: a long run falls faster at the same level")
	cl.run_time = EscapeBoard.SPEED_CREEP_TIME * 999.0
	_check(cl._speed_creep() == EscapeBoard.SPEED_CREEP_MAX,
			"classic: the creep is capped")
	cl.run_time = 0.0
	# Level structure (Atari B-type): level 1 is a clean board, 3 lines to clear.
	cl.level = 1
	_check(Board.classic_quota(1) == 3 and Board.classic_quota(2) == 4
			and Board.classic_quota(99) == Board.CLASSIC_QUOTA_MAX,
			"classic: the line goal eases in from 3 up to the arcade's 10")
	_check(cl.level_lines == 0 and cl.level_garbage == 0 and cl.grid.is_empty(),
			"classic: level 1 deals a clean board")
	_check(Board.classic_garbage(1) == 0 and Board.classic_garbage(6) > 0
			and Board.classic_garbage(99) == Board.CLASSIC_GARBAGE_MAX,
			"classic: later levels deal a deeper garbage floor, capped")
	# Arcade scoring (40 x level) and quota progress, via the lock path.
	cl.level_lines = 0
	for x in range(EscapeBoard.COLS):
		cl.grid[Vector2i(x, cl.rows - 1)] = "O"
	cl.piece_type = "O"
	cl.piece_rot = 0
	cl.piece_pos = Vector2i(0, 9)
	var classic_score: int = GameState.score
	cl._lock_piece()
	# 10 x level placement score (house rule) + the arcade single (40 x level).
	_check(GameState.score == classic_score + 10 + 40,
			"classic: single pays the arcade 40 x level")
	_check(cl.level_lines == 1, "classic: the clear counts toward the level quota")
	_check(not cl._shutter_on(), "classic: the level runs on until its quota is met")
	# Quota met: the shutter rolls down, paying for every empty row it passes.
	cl.level_lines = Board.classic_quota(cl.level) - 1
	for x in range(EscapeBoard.COLS):
		cl.grid[Vector2i(x, cl.rows - 1)] = "O"
	cl.piece_type = "O"
	cl.piece_rot = 0
	cl.piece_pos = Vector2i(0, 9)
	var before_bonus: int = GameState.score
	cl._lock_piece()
	_check(cl._shutter_on(), "classic: meeting the quota rolls the shutter down")
	_check(cl.shutter_phase == EscapeBoard.Shutter.CLOSING,
			"classic: the shutter starts closing")
	# Every row above the stack pays out; the rows at and below it pay nothing.
	var stack_top: int = cl.rows
	for gc: Vector2i in cl.grid:
		stack_top = mini(stack_top, gc.y)
	var expect_bonus: int = maxi(stack_top, 0) * Board.CLASSIC_EMPTY_ROW_BONUS * cl.level
	var shutter_guard := 0
	while cl.shutter_phase == EscapeBoard.Shutter.CLOSING and shutter_guard < 200:
		cl._update_shutter(1.0)
		shutter_guard += 1
	_check(cl.shutter_bonus == expect_bonus,
			"classic: the shutter pays 100 x level per empty row")
	_check(cl.shutter_row == stack_top,
			"classic: the curtain stops on the stack, covering only the empty rows")
	_check(GameState.score == before_bonus + 10 + 40 + expect_bonus,
			"classic: the empty-row bonus lands on the score")
	_check(cl.shutter_bonus_done, "classic: the tally stops at the stack")
	# The next board is dealt behind the closed curtain, then it lifts.
	_check(cl.level == 2 and cl.level_lines == 0 and cl.piece_type != "",
			"classic: the next level is dealt behind the shutter")
	_check(cl.level_garbage == Board.classic_garbage(2),
			"classic: the new board carries its own garbage floor")
	shutter_guard = 0
	while cl._shutter_on() and shutter_guard < 400:
		cl._update_shutter(1.0)
		shutter_guard += 1
	_check(cl.shutter_phase == EscapeBoard.Shutter.NONE and cl.shutter_row == 0,
			"classic: the shutter opens again and hands play back")
	_check(cl.player.visible, "classic: the cat is revealed by the rising shutter")
	# Deep levels: a garbage floor with holes, and a spawn that sits on top of it.
	cl._classic_setup_level(6)
	_check(cl.level_garbage == Board.classic_garbage(6) and not cl.grid.is_empty(),
			"classic: deep levels deal a garbage floor")
	var garbage_full := false
	for y in range(cl.rows - cl.level_garbage, cl.rows):
		var filled := 0
		for x in range(EscapeBoard.COLS):
			if cl.grid.has(Vector2i(x, y)):
				filled += 1
		if filled >= EscapeBoard.COLS:
			garbage_full = true
	_check(not garbage_full, "classic: garbage rows always leave a hole")
	_check(cl._spawn_point().y < (cl.rows - cl.level_garbage + 1) * c,
			"classic: the cat spawns on top of the garbage")
	# Test affordance: the skip button/hotkey clears the level on the spot.
	cl._classic_setup_level(3)
	cl.playing = true
	cl.is_paused = false
	_check(cl.classic_skip_level(), "classic: the level-skip test button fires")
	_check(cl._shutter_on() and cl.level_lines >= Board.classic_quota(3),
			"classic: skipping runs the normal shutter clear")
	_check(not cl.classic_skip_level(),
			"classic: skipping again mid-shutter does nothing")
	var skip_guard := 0
	while cl._shutter_on() and skip_guard < 400:
		cl._update_shutter(1.0)
		skip_guard += 1
	_check(cl.level == 4, "classic: the skip lands on the next level")
	cl._classic_setup_level(1)
	cl.piece_type = "O"
	cl.grid[Vector2i(0, cl.rows - 1)] = "O"  # the replay diff needs a live grid

	# --- Replay recording -------------------------------------------------------
	cl._rec_tick(0.25)
	cl._rec_tick(0.25)
	_check(cl.rec_frames.size() >= EscapeBoard.REC_STRIDE * 2, "replay: frames recorded")
	var rep: Dictionary = cl.rec_export()
	_check(not rep.is_empty() and not (rep.events as Array).is_empty(),
			"replay: export carries frames and grid events")
	var round_trip: Dictionary = Replays.decode(Replays.encode(rep))
	_check(round_trip.get("frames") == rep.get("frames"),
			"replay: encode/decode round-trip keeps frames")
	_check(int(round_trip.get("rows", 0)) == cl.rows, "replay: metadata survives")

	# --- Endless: detached pieces (rotation locked, next piece is instant) ------
	GameState.mode = GameState.MODE_ENDLESS
	var b6: Node2D = load("res://core/scripts/escape_board.gd").new()
	var p6: Node2D = load("res://core/scripts/player.gd").new()
	p6.name = "Player"
	b6.add_child(p6)
	var cam6 := Camera2D.new()
	cam6.name = "Cam"
	b6.add_child(cam6)
	add_child(b6)
	b6.start_game()
	# Endless creeps too: the climb drives it, and so does time survived.
	var endless_fresh: float = b6._fall_interval()
	var endless_lava: float = b6._lava_speed()
	b6.run_time = EscapeBoard.SPEED_CREEP_TIME * 4.0
	_check(b6._fall_interval() < endless_fresh,
			"endless: a long run falls faster at the same height")
	_check(is_equal_approx(b6._lava_speed(), endless_lava),
			"endless: the creep leaves the lava on the climb-based difficulty")
	b6.run_time = 0.0
	b6.piece_type = "O"
	b6.piece_rot = 0
	b6.piece_state = b6.PieceState.TRACKING
	b6.piece_pos = Vector2i(3, 4)
	p6.position = Vector2(c, 16 * c)  # well clear of the falling lane
	var queued6: String = b6.next_type
	b6._release_piece()
	_check(b6.loose.size() == 1, "endless: countdown end detaches the piece")
	_check(b6.piece_state == b6.PieceState.TRACKING,
			"endless: next piece starts tracking at once")
	_check(b6.piece_type == queued6, "endless: the queued piece became active")
	_check(b6.piece_hits_rect(Rect2(4 * c + 10, 4 * c + 10, 10, 10)),
			"endless: detached piece is solid to the cat")
	# The next piece spawns clear of the freshly detached one: its 4-row spawn
	# box must sit fully above the previous piece's topmost cell.
	var loose_top6: int = b6.rows
	for lc: Vector2i in b6._loose_cells(b6.loose[0]):
		loose_top6 = mini(loose_top6, lc.y)
	_check(b6.piece_pos.y + 3 < loose_top6, "endless: next piece spawns above the detached piece")
	_check(b6._endless_spawn_row() <= loose_top6 - EscapeBoard.SPAWN_CLEARANCE,
			"endless: tracking row stays above the falling piece")
	# The detached piece falls on its own, lands and locks into the grid.
	var le: Dictionary = b6.loose[0]
	le.p = Vector2i(3, b6.rows - 2)
	b6._step_loose(EscapeBoard.FALL_INTERVAL_BASE)
	_check(le.s == b6.PieceState.LANDED, "endless: detached piece lands")
	b6._step_loose(EscapeBoard.LOCK_GRACE)
	_check(b6.loose.is_empty(), "endless: landed piece locks after the grace")
	_check(b6.grid.has(Vector2i(4, b6.rows - 1)),
			"endless: locked cells merged into the grid")
	# Mid-air pieces stack on each other instead of overlapping.
	b6.grid.clear()
	b6.loose.append({"t": "O", "r": 0, "p": Vector2i(3, 10),
			"s": b6.PieceState.FALLING, "ft": 0.0, "lt": 0.0})
	b6.loose.append({"t": "O", "r": 0, "p": Vector2i(3, 8),
			"s": b6.PieceState.FALLING, "ft": 0.0, "lt": 0.0})
	_check(b6._loose_blocked(1, Vector2i(0, 1)),
			"endless: a piece stacks on the one below it")
	# The dash shove targets the detached piece beside the cat.
	p6.position = Vector2(3.5 * c, 11.0 * c)
	_check(b6.shove_piece(1, 2), "endless: dash shoves the detached piece")
	_check(b6.loose[0].p == Vector2i(5, 10),
			"endless: shove moved it by the push-stat cells")
	b6.loose.clear()

	# --- 골드 블록 ------------------------------------------------------------
	# 직접 깨면 제값, 셔터가 쓸어 가면 절반. 회전해도 금은 같은 칸에 붙어 있다.
	GameState.mode = GameState.MODE_CLASSIC
	var b7: Node2D = load("res://core/scripts/escape_board.gd").new()
	var p7: Node2D = load("res://core/scripts/player.gd").new()
	p7.name = "Player"
	b7.add_child(p7)
	add_child(b7)
	b7.start_game()
	b7.grid.clear()
	b7.ore.clear()
	b7.loose.clear()
	b7.ore_gold = 0

	# 골드 블록은 한 방에 터지고 제값을 준다 (일반 블록은 두 번 쳐야 한다).
	var gold0: int = GameState.gold
	var oc := Vector2i(4, 10)
	b7.grid[oc] = "T"
	b7.ore[oc] = true
	var oprobe := Rect2(4 * c + 30, 10 * c + 30, 10, 10)
	_check(b7.break_cell_in_rect(oprobe), "ore: the hit registers")
	_check(not b7.grid.has(oc), "ore: one hit destroys a gold block")
	_check(not b7.ore.has(oc), "ore: the gold is taken off the field")
	_check(GameState.gold == gold0 + EscapeBoard.ORE_VALUE, "ore: breaking pays full value")
	_check(b7.ore_gold == EscapeBoard.ORE_VALUE, "ore: the run tally counts it")

	# 줄로 지운 금도 제값 — 지우면 손해가 되면 안 된다.
	gold0 = GameState.gold
	for x in range(EscapeBoard.COLS):
		b7.grid[Vector2i(x, b7.rows - 1)] = "O"
	b7.ore[Vector2i(2, b7.rows - 1)] = true
	_check(b7._clear_lines() == 1, "ore: the row clears")
	_check(GameState.gold == gold0 + EscapeBoard.ORE_VALUE, "ore: a line clear pays full value")

	# 살아남은 금은 줄이 무너질 때 함께 내려온다.
	b7.grid.clear()
	b7.ore.clear()
	for x in range(EscapeBoard.COLS):
		b7.grid[Vector2i(x, b7.rows - 1)] = "O"
	b7.grid[Vector2i(3, b7.rows - 2)] = "T"
	b7.ore[Vector2i(3, b7.rows - 2)] = true
	b7._clear_lines()
	_check(b7.ore.has(Vector2i(3, b7.rows - 1)), "ore: surviving gold rides the row shift down")

	# 셔터가 쓸어 간 금은 절반값이다.
	b7.grid.clear()
	b7.ore.clear()
	gold0 = GameState.gold
	b7.grid[Vector2i(5, b7.rows - 1)] = "O"
	b7.ore[Vector2i(5, b7.rows - 1)] = true
	b7._classic_shutter_landed()
	_check(GameState.gold == gold0 + EscapeBoard.ORE_SWEEP_VALUE,
			"ore: the shutter sweep pays half")

	# 회전해도 금은 같은 칸을 따라간다: 도형 중심에서 잰 자리가 그대로여야 한다.
	var rot_ok := true
	for t: String in Board.PIECES:
		for r in 4:
			for idx in Board.SHAPES[t][r].size():
				var to_rot := (r + 1) % 4
				var moved: int = b7._rotate_ore_index(t, r, to_rot, idx)
				var src: Array = Board.SHAPES[t][r]
				var dst: Array = Board.SHAPES[t][to_rot]
				var c_src := Vector2.ZERO
				for sc: Vector2i in src:
					c_src += Vector2(sc)
				c_src /= src.size()
				var c_dst := Vector2.ZERO
				for dc: Vector2i in dst:
					c_dst += Vector2(dc)
				c_dst /= dst.size()
				var v := Vector2(src[idx]) - c_src
				var want := c_dst + Vector2(-v.y, v.x)
				if Vector2(dst[moved]).distance_to(want) > 0.01:
					rot_ok = false
	_check(rot_ok, "ore: rotation keeps the gold on the same cell")
	_check(b7._rotate_ore_index("T", 0, 1, -1) == -1, "ore: a plain piece stays plain")

	# 새 레벨 판은 금을 물려받지 않는다.
	b7.ore[Vector2i(1, 1)] = true
	b7._classic_setup_level(2)
	_check(b7.ore.is_empty(), "ore: a fresh level board starts without leftover gold")
	b7.queue_free()

	GameState.save_game()

	if failures == 0:
		print("ALL TESTS PASSED")
	else:
		print("%d TEST(S) FAILED" % failures)
	get_tree().quit(failures)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: %s" % label)
	else:
		failures += 1
		print("  FAIL: %s" % label)
