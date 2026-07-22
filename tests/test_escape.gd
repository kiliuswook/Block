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

	# Solidity queries
	var c := EscapeBoard.CELL
	_check(board.rect_hits_solid(Rect2(-5, 100, 10, 10)), "left wall is solid")
	_check(board.rect_hits_solid(Rect2(EscapeBoard.COLS * c - 5, 100, 10, 10)), "right wall is solid")
	_check(board.rect_hits_solid(Rect2(100, EscapeBoard.ROWS * c - 5, 10, 10)), "floor is solid")
	_check(board.rect_hits_solid(Rect2(0, -20, 10, 10)), "ceiling outside door is solid")
	var door_x := (EscapeBoard.DOOR_MIN + 1) * c
	_check(not board.rect_hits_solid(Rect2(door_x, -20, 10, 10)), "door opening is free")
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

	# Head-bump / dash impact breaks locked blocks
	board.grid[Vector2i(4, 10)] = "T"
	_check(board.break_cells_in_rect(Rect2(4 * c + 30, 10 * c + 30, 10, 10)), "break removes a block")
	_check(not board.grid.has(Vector2i(4, 10)), "broken block is gone")
	_check(not board.break_cells_in_rect(Rect2(4 * c + 30, 10 * c + 30, 10, 10)), "empty cell breaks nothing")

	# A falling piece bumping an airborne player shoves them instead of killing
	board.piece_type = "O"
	board.piece_rot = 0
	board.piece_state = board.PieceState.FALLING
	board.piece_pos = Vector2i(3, 4)  # O cells span y 4..5, bottom edge at 6*CELL
	player.position = Vector2(5 * c, 6 * c + Player.SIZE / 2.0 - 20.0)  # 20px overlap from below
	board._resolve_piece_overlap()
	_check(player.alive, "bumped airborne player survives")
	_check(player.position.y > 6 * c, "player was shoved below the piece")

	# A falling piece landing on a grounded player kills them
	board.piece_pos = Vector2i(3, EscapeBoard.ROWS - 2)
	player.position = board._spawn_point()
	board._resolve_piece_overlap()
	_check(not player.alive, "falling piece crushes pinned player")
	_check(not board.playing, "crush ends the game")

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
