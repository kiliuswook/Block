extends Control
## HUD panel showing the next tetromino, in the board's mini cell style.

const MINI := 28.0

var next_type := ""


func _ready() -> void:
	EventBus.next_piece_changed.connect(func(t: String) -> void:
		next_type = t
		queue_redraw())


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("2a3040", 0.6))
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.35), false, 2.0)
	if next_type == "":
		return
	var cells: Array = Board.SHAPES[next_type][0]
	var minc := Vector2i(9, 9)
	var maxc := Vector2i(-9, -9)
	for c in cells:
		minc = minc.min(c)
		maxc = maxc.max(c)
	var span := Vector2(maxc - minc + Vector2i.ONE)
	var origin := size / 2.0 - span * MINI / 2.0 - Vector2(minc) * MINI
	var color: Color = Board.COLORS[next_type]
	for c in cells:
		var p: Vector2 = origin + Vector2(c) * MINI
		draw_rect(Rect2(p + Vector2.ONE, Vector2.ONE * (MINI - 2.0)), color)
		# Light always comes from above: bright top face, shaded bottom.
		draw_rect(Rect2(p + Vector2(3.0, 2.0), Vector2(MINI - 6.0, 3.0)),
				Color(1.0, 0.96, 0.84, 0.4))
		draw_rect(Rect2(p + Vector2(1.0, MINI - 4.0), Vector2(MINI - 2.0, 3.0)),
				Color(0.0, 0.0, 0.0, 0.28))
		draw_rect(Rect2(p + Vector2.ONE, Vector2.ONE * (MINI - 2.0)),
				color.darkened(0.4), false, 1.5)
