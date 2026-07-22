extends Node
## Headless smoke test for Board logic.
## Run: godot --headless --path . res://tests/test_board.tscn

var failures := 0


func _ready() -> void:
	var board: Node2D = load("res://scripts/board.gd").new()
	add_child(board)
	board.start_game()

	_check(board.playing, "game starts in playing state")
	_check(board.queue.size() == board.NEXT_COUNT, "next queue is filled")
	_check(board.current_type in board.PIECES, "a piece has spawned")

	# Wall / floor collision
	_check(board._collides([Vector2i(-1, 0)]), "left wall collides")
	_check(board._collides([Vector2i(10, 0)]), "right wall collides")
	_check(board._collides([Vector2i(0, 20)]), "floor collides")
	_check(not board._collides([Vector2i(0, 0)]), "empty cell is free")

	# Basic movement
	board.current_type = "T"
	board.current_rot = 0
	board.current_pos = Vector2i(3, 5)
	_check(board._try_move(Vector2i(1, 0)), "move right succeeds")
	_check(board.current_pos == Vector2i(4, 5), "position updated after move")

	# Rotation (T piece, open field)
	board._try_rotate(1)
	_check(board.current_rot == 1, "clockwise rotation succeeds")
	board._try_rotate(-1)
	_check(board.current_rot == 0, "counter-clockwise rotation succeeds")

	# Line clear: fill bottom row except x=9, hard-drop a vertical I at x=9
	board.grid.clear()
	for x in range(9):
		board.grid[Vector2i(x, 19)] = "O"
	board.current_type = "I"
	board.current_rot = 1
	board.current_pos = Vector2i(7, 10)
	var score_before: int = GameState.score
	board._hard_drop()
	_check(board.total_lines == 1, "one line cleared after hard drop")
	_check(GameState.score > score_before, "score increased by clear + drop")
	_check(not board.grid.has(Vector2i(0, 19)), "cleared row removed")
	_check(board.grid.has(Vector2i(9, 19)), "remaining I cells shifted down")
	_check(board.grid.size() == 3, "exactly 3 cells remain on the board")

	# Hold swaps the current piece
	var held: String = board.current_type
	board._hold()
	_check(board.hold_type == held, "hold stores the piece")
	_check(board.hold_used, "hold flagged as used")

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
