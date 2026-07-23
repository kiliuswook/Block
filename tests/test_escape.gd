extends Node
## Headless smoke test for EscapeBoard logic.
## Run: godot --headless --path . res://tests/test_escape.tscn

var failures := 0


func _ready() -> void:
	var board: Node2D = load("res://scripts/escape_board.gd").new()
	var player: Node2D = load("res://scripts/player.gd").new()
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

	# Escape resets the field and levels up
	board._escape()
	_check(board.level == 2, "escape increases level")
	_check(board.grid.is_empty(), "escape clears the field")
	_check(player.alive, "player alive after escape")

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
	board.piece_pos = Vector2i(3, EscapeBoard.ROWS - 2)
	player.position = board._spawn_point()
	board._resolve_piece_overlap()
	_check(not player.alive, "falling piece crushes pinned player")
	_check(not board.playing, "crush ends the game")

	# --- Endless (infinite stairs) mode ---
	GameState.mode = GameState.MODE_ENDLESS
	var b2: Node2D = load("res://scripts/escape_board.gd").new()
	var p2: Node2D = load("res://scripts/player.gd").new()
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
	b2._update_endless(0.016)
	_check(cam2.position.y == 200.0, "camera follows the player up")
	_check(b2.best_height > 0, "height is tracked")
	var lava_before: float = b2.lava_y
	p2.position = Vector2(320, 400)
	b2._update_endless(0.016)
	_check(cam2.position.y == 400.0, "camera follows the player back down")
	_check(p2.alive, "falling down a hole is not death by itself")
	_check(b2.lava_y < lava_before, "lava rises over time")
	b2.lava_y = p2.position.y  # lava reaches the player's feet
	b2._update_endless(0.016)
	_check(not p2.alive, "touching lava is death")
	GameState.mode = GameState.MODE_ESCAPE

	# Classic Tetris block out: stack reaching the spawn area ends the game
	var b3: Node2D = load("res://scripts/escape_board.gd").new()
	var p3: Node2D = load("res://scripts/player.gd").new()
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
	var b4: Node2D = load("res://scripts/escape_board.gd").new()
	var p4: Node2D = load("res://scripts/player.gd").new()
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
	GameState.mode = GameState.MODE_ESCAPE

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

	# Crushed under blocks: the revive blast clears the cells around the cat
	for x in range(3, 8):
		for y in range(10, EscapeBoard.ROWS):
			board.grid[Vector2i(x, y)] = "T"
	player.position = Vector2(5 * c + c / 2.0, 12 * c)
	board.revive_player()
	_check(player.alive and board.playing, "crushed player revives")
	_check(not board.rect_hits_solid(player.rect()), "revive blast frees the crushed cat")

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
