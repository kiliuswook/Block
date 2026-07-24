extends Node
## Headless smoke test for EscapeBoard logic.
## Run: godot --headless --path . res://tests/test_escape.tscn

var failures := 0


func _ready() -> void:
	# Park the story on its final stage: escape goal, top doors, full bag,
	# no prefill — the neutral config the mechanical tests below assume.
	# (Restored, along with the save file, at the end of the run.)
	var saved_story: int = GameState.story_stage
	GameState.mode = GameState.MODE_STORY
	GameState.story_stage = StoryStages.TOTAL - 1
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
	_check(board.rect_hits_solid(Rect2(-5, 300, 10, 10)), "left wall below the door is solid")
	_check(board.rect_hits_solid(Rect2(EscapeBoard.COLS * c - 5, 300, 10, 10)),
			"right wall below the door is solid")
	_check(board.rect_hits_solid(Rect2(100, EscapeBoard.ROWS * c - 5, 10, 10)), "floor is solid")
	_check(board.rect_hits_solid(Rect2(100, -20, 10, 10)), "ceiling is solid")
	_check(not board.rect_hits_solid(Rect2(-30, c, 10, 10)), "left side door is open")
	_check(not board.rect_hits_solid(Rect2(EscapeBoard.COLS * c + 20, c, 10, 10)),
			"right side door is open")
	board.grid[Vector2i(4, 10)] = "T"
	_check(board.rect_hits_solid(Rect2(4 * c + 10, 10 * c + 10, 10, 10)), "locked cell is solid")
	board.grid.clear()

	# Line clear shifts cells down
	for x in range(EscapeBoard.COLS):
		board.grid[Vector2i(x, EscapeBoard.ROWS - 1)] = "O"
	board.grid[Vector2i(0, EscapeBoard.ROWS - 2)] = "T"
	_check(board._clear_lines() == 1, "full row clears")
	_check(board.grid.has(Vector2i(0, EscapeBoard.ROWS - 1)), "cell above shifted down")
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
		board.grid[Vector2i(x, EscapeBoard.ROWS - 1)] = "O"
	board.grid[Vector2i(0, EscapeBoard.ROWS - 2)] = "T"
	board.cracked[Vector2i(0, EscapeBoard.ROWS - 2)] = true
	board._clear_lines()
	_check(board.cracked.has(Vector2i(0, EscapeBoard.ROWS - 1)), "crack shifted down with its block")
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
	board.piece_pos = Vector2i(3, EscapeBoard.ROWS - 2)  # O resting on the floor
	board._fall(1.0)
	_check(board.piece_state == board.PieceState.LANDED, "piece lands into the grace state")
	_check(board.grid.is_empty(), "landed piece has not locked yet")
	_check(board.piece_hits_rect(Rect2(4 * c + 10, (EscapeBoard.ROWS - 1) * c + 10, 10, 10)),
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
	board.piece_pos = Vector2i(3, EscapeBoard.ROWS - 2)
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
	# the cat at ~1/3 from the screen bottom with open space above.
	var cam_off: float = b2.get_viewport_rect().size.y / 6.0
	b2._update_endless(0.016)
	_check(cam2.position.y == 200.0 - cam_off, "camera follows the player up")
	_check(b2.best_height > 0, "height is tracked")
	var lava_before: float = b2.lava_y
	p2.position = Vector2(320, 400)
	b2._update_endless(0.016)
	_check(cam2.position.y == 400.0 - cam_off, "camera follows the player back down")
	_check(p2.alive, "falling down a hole is not death by itself")
	_check(b2.lava_y < lava_before, "lava rises over time")
	b2.lava_y = p2.position.y  # lava reaches the player's feet
	b2._update_endless(0.016)
	_check(not p2.alive, "touching lava is death")
	GameState.mode = GameState.MODE_STORY

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
	GameState.mode = GameState.MODE_STORY

	# --- Revive ("이어서 하기") ---
	# Escape block-out: revive reopens the spawn window and resumes play
	b3.revive_player()
	_check(b3.playing, "revive resumes an escape run")
	_check(p3.alive, "revived player is alive")
	_check(not b3.rect_hits_solid(p3.rect()), "revived player stands in a free spot")
	_check(b3.piece_state == b3.PieceState.TRACKING, "revive spawns a fresh tracking piece")

	# Endless lava death: revive pushes the lava back below the feet
	b2.revive_player()
	_check(b2.playing, "revive resumes an endless run")
	_check(p2.alive, "lava-killed player revives")
	_check(b2.lava_y >= p2.position.y + Player.SIZE / 2.0 + c,
			"revive pushes the lava back down")

	# Endless revive: the blast wipes the whole stack, and a rescue bar
	# floats above the lava so the cat lands on it instead of falling back in
	b2.grid[Vector2i(2, 5)] = "T"
	b2.grid[Vector2i(7, -3)] = "L"
	b2.revive_player()
	_check(not b2.grid.has(Vector2i(2, 5)) and not b2.grid.has(Vector2i(7, -3)),
			"endless revive blasts the whole stack")
	var plat_row := int(floor(b2.lava_y / c)) - EscapeBoard.REVIVE_PLATFORM_GAP
	var plat_cells := 0
	for x in range(EscapeBoard.COLS):
		if b2.grid.has(Vector2i(x, plat_row)):
			plat_cells += 1
	_check(plat_cells == EscapeBoard.COLS - 1, "rescue bar spans the row with one edge gap")
	_check(b2._clear_lines() == 0, "rescue bar never counts as a clearable line")
	_check(plat_row * c > p2.position.y, "rescue bar sits below the revived cat")
	b2.grid.clear()

	# --- Fever time (endless only) ---
	board.mode = board.Mode.STORY
	board._add_fever(1.0)
	_check(not board.fever_active and board.fever_gauge == 0.0,
			"story mode never charges fever")
	b2.playing = true
	b2.fever_gauge = 0.0  # earlier lock tests already trickled some charge in
	b2._add_fever(0.5)
	_check(b2.fever_gauge == 0.5 and not b2.fever_active, "line clears charge the gauge")
	b2._add_fever(0.5)
	_check(b2.fever_active, "full gauge triggers fever")
	_check(b2.fever_gauge == 0.0, "fever spends the gauge")
	b2._add_fever(1.0)
	_check(b2.fever_gauge == 0.0, "no recharging during fever")
	# Normal piece flow keeps running during fever — no tracking, instant drop
	_check(b2.piece_state == b2.PieceState.FALLING, "fever drops the piece immediately")
	_check(b2._fall_interval() == EscapeBoard.FEVER_FALL_INTERVAL, "fever pieces fall fast")
	b2._spawn_piece()
	_check(b2.piece_state == b2.PieceState.FALLING, "fever spawns skip tracking entirely")
	# The falling piece is intangible to the cat (pass through)...
	b2.grid.clear()
	b2.piece_type = "O"
	b2.piece_rot = 0
	b2.piece_state = b2.PieceState.FALLING
	b2.piece_pos = Vector2i(3, 7)  # O cells at x 4..5, y 7..8
	var inside := Rect2(4 * c + 10, 7 * c + 10, 10, 10)
	_check(b2.piece_hits_rect(inside), "piece cell occupies the probe")
	_check(not b2.rect_blocked_for_player(inside), "fever: cat passes through the piece")
	# ...but its top is a one-way platform the cat can stand on
	var feet_r := Rect2(4 * c - 25.0, 7 * c - 50.0, 50.0, 50.0)
	_check(b2.fever_platform_top(feet_r, 12.0) == 7.0 * c, "piece top supports the cat")
	var below_r := Rect2(4 * c - 25.0, 9 * c + 10.0, 50.0, 50.0)
	_check(b2.fever_platform_top(below_r, 12.0) == INF, "no support from below")
	# Overlap never crushes an invincible cat
	p2.alive = true
	p2.position = Vector2(4 * c + c / 2.0, 8 * c)
	_check(not b2._resolve_piece_overlap(), "fever: overlap resolves as pass-through")
	_check(p2.alive, "fever: falling piece cannot crush the cat")
	# Locked blocks are one-way during fever: pass through, land on exposed tops
	b2.piece_state = b2.PieceState.TRACKING  # park the piece for grid-only checks
	for x in range(2, 8):
		for y in range(5, 12):
			b2.grid[Vector2i(x, y)] = "T"
	p2.position = Vector2(4 * c + c / 2.0, 8 * c)
	_check(b2._free_player_from_grid(), "fever: burial does not kill")
	_check(p2.alive and b2.playing, "fever: cat survives inside the stack")
	_check(not b2.rect_blocked_for_player(p2.rect()), "fever: locked blocks are pass-through")
	var stack_feet := Rect2(4 * c + 7.0, 5 * c - 50.0, 50.0, 50.0)
	_check(b2.fever_platform_top(stack_feet, 12.0) == 5.0 * c, "fever: stack surface is standable")
	var inner_feet := Rect2(4 * c + 7.0, 8 * c - 50.0, 50.0, 50.0)
	_check(b2.fever_platform_top(inner_feet, 12.0) == INF, "fever: no landing inside the stack")
	b2.grid.clear()
	# Fever runs out after its duration
	b2.fever_timer = 0.01
	b2._process(0.05)
	_check(not b2.fever_active, "fever expires after its duration")
	b2.piece_state = b2.PieceState.TRACKING
	b2._lock_piece()
	_check(is_equal_approx(b2.fever_gauge, EscapeBoard.FEVER_PER_PIECE),
			"locking a piece trickle-charges the gauge")
	b2.grid.clear()
	b2.fever_gauge = 0.0

	# Crushed under blocks: the revive blast clears the cells around the cat
	for x in range(3, 8):
		for y in range(10, EscapeBoard.ROWS):
			board.grid[Vector2i(x, y)] = "T"
	player.position = Vector2(5 * c + c / 2.0, 12 * c)
	board.revive_player()
	_check(player.alive and board.playing, "crushed player revives")
	_check(not board.rect_hits_solid(player.rect()), "revive blast frees the crushed cat")

	# --- Story mode stages ---
	# Stage 1: movement tutorial — prefilled stairs, no pieces, doors open
	GameState.story_stage = 0
	var s1: Node2D = load("res://core/scripts/escape_board.gd").new()
	var sp1: Node2D = load("res://core/scripts/player.gd").new()
	sp1.name = "Player"
	s1.add_child(sp1)
	add_child(s1)
	s1.start_game()
	_check(s1.level == 1, "story starts at stage 1")
	_check(s1.piece_type == "", "stage 1 spawns no pieces")
	_check(not s1.grid.is_empty(), "stage 1 prefills the staircase")
	_check(not s1.rect_hits_solid(Rect2(-30, c, 10, 10)), "stage 1 left door is open")
	s1._escape()
	_check(s1.level == 2, "escape advances to the next stage")
	_check(s1.playing, "the run continues into the next stage")
	_check(GameState.story_stage == 1, "stage clear is recorded")
	_check(s1.piece_type == "O", "stage 2 restricts the piece bag")
	# Stage 2 lowers the exit: the top wall is closed, rows 10-11 are the door
	_check(s1.rect_hits_solid(Rect2(-30, c, 10, 10)), "lowered door: top wall is solid")
	_check(not s1.rect_hits_solid(Rect2(-30, 10 * c + 10, 10, 10)),
			"lowered door: mid-wall exit is open")

	# Stage 5: shove goal — ground doors locked until one shove opens them
	GameState.story_stage = 4
	var s5: Node2D = load("res://core/scripts/escape_board.gd").new()
	var sp5: Node2D = load("res://core/scripts/player.gd").new()
	sp5.name = "Player"
	s5.add_child(sp5)
	add_child(s5)
	s5.start_game()
	_check(s5.level == 5, "story resumes from the next uncleared stage")
	_check(not s5.goal_done, "goal stage starts locked")
	_check(s5.rect_hits_solid(Rect2(-30, 12 * c + 10, 10, 10)),
			"locked ground door is solid")
	s5.piece_type = "O"
	s5.piece_rot = 0
	s5.piece_state = s5.PieceState.FALLING
	s5.piece_pos = Vector2i(3, 4)
	sp5.position = Vector2(2 * c, 700.0)  # clear of the piece's path
	s5.shove_piece(1)
	_check(s5.goal_done, "one shove completes the stage 5 goal")
	_check(not s5.rect_hits_solid(Rect2(-30, 12 * c + 10, 10, 10)),
			"ground door opens once the goal is met")

	# Stage 4: break goal counts destroyed blocks
	GameState.story_stage = 3
	var s4: Node2D = load("res://core/scripts/escape_board.gd").new()
	var sp4: Node2D = load("res://core/scripts/player.gd").new()
	sp4.name = "Player"
	s4.add_child(sp4)
	add_child(s4)
	s4.start_game()
	_check(s4.piece_type == "", "break stage spawns no pieces")
	_check(s4.grid.has(Vector2i(6, 12)), "break stage prefills the wall")
	_check(not s4.goal_done, "break stage starts locked")
	var wall_probe := Rect2(6 * c + 30, 12 * c + 30, 10, 10)
	s4.break_cell_in_rect(wall_probe)  # crack
	s4.break_cell_in_rect(wall_probe)  # destroy
	_check(s4.goal_count == 1, "destroying a block counts toward the goal")
	s4._story_add_progress("breaks", 1)
	_check(s4.goal_done, "reaching the break count opens the doors")

	# Line goal counts cleared lines the same way
	GameState.story_stage = 5
	var s6: Node2D = load("res://core/scripts/escape_board.gd").new()
	var sp6: Node2D = load("res://core/scripts/player.gd").new()
	sp6.name = "Player"
	s6.add_child(sp6)
	add_child(s6)
	s6.start_game()
	_check(not s6.grid.is_empty(), "stage 6 prefills the line gaps")
	_check(not s6.goal_done, "stage 6 starts locked")
	s6._story_add_progress("lines", 1)
	_check(s6.goal_done, "the cleared line opens the doors")

	# Survive goal ticks with _process time
	GameState.story_stage = 6
	var s7: Node2D = load("res://core/scripts/escape_board.gd").new()
	var sp7: Node2D = load("res://core/scripts/player.gd").new()
	sp7.name = "Player"
	s7.add_child(sp7)
	add_child(s7)
	s7.start_game()
	_check(not s7.goal_done, "survive stage starts locked")
	s7._process(21.0)
	_check(s7.goal_done, "surviving the full time opens the doors")

	# Stage 19: only the right door opens, up at rows 2-3
	GameState.story_stage = 18
	var s19: Node2D = load("res://core/scripts/escape_board.gd").new()
	var sp19: Node2D = load("res://core/scripts/player.gd").new()
	sp19.name = "Player"
	s19.add_child(sp19)
	add_child(s19)
	s19.start_game()
	_check(s19.rect_hits_solid(Rect2(-30, 2 * c + 10, 10, 10)),
			"stage 19 left door stays shut")
	_check(not s19.rect_hits_solid(Rect2(EscapeBoard.COLS * c + 20, 2 * c + 10, 10, 10)),
			"stage 19 right door is open")

	# Generated stages cover the long tail up to the finale
	var gen: Dictionary = StoryStages.get_stage(37)
	_check(gen.has("goal") and gen.has("hint"), "generated stages have goal and hint")
	var late: Dictionary = StoryStages.get_stage(100)
	var early_gen: Dictionary = StoryStages.get_stage(25)
	_check(float(late.track_time) < float(early_gen.track_time),
			"generated stages speed up with the stage number")

	# Clearing the final stage completes the story
	GameState.story_stage = StoryStages.TOTAL - 1
	var s12: Node2D = load("res://core/scripts/escape_board.gd").new()
	var sp12: Node2D = load("res://core/scripts/player.gd").new()
	sp12.name = "Player"
	s12.add_child(sp12)
	add_child(s12)
	s12.start_game()
	_check(s12.level == StoryStages.TOTAL, "final stage loads")
	s12._escape()
	_check(not s12.playing, "final stage clear ends the run")
	_check(GameState.story_stage == StoryStages.TOTAL, "story completion is recorded")
	GameState.story_stage = StoryStages.TOTAL
	var s13: Node2D = load("res://core/scripts/escape_board.gd").new()
	var sp13: Node2D = load("res://core/scripts/player.gd").new()
	sp13.name = "Player"
	s13.add_child(sp13)
	add_child(s13)
	s13.start_game()
	_check(s13.level == 1, "a finished story replays from stage 1")

	# Restore the real save the story tests overwrote
	GameState.story_stage = saved_story
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
