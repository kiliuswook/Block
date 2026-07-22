extends Node2D
## Title screen: pick a game mode with the buttons or the 1 / 2 keys.

@onready var escape_btn: Button = $UI/EscapeBtn
@onready var endless_btn: Button = $UI/EndlessBtn


func _ready() -> void:
	escape_btn.pressed.connect(func() -> void: _start(GameState.MODE_ESCAPE))
	endless_btn.pressed.connect(func() -> void: _start(GameState.MODE_ENDLESS))


func _start(mode: int) -> void:
	GameState.mode = mode
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1, KEY_KP_1:
				_start(GameState.MODE_ESCAPE)
			KEY_2, KEY_KP_2:
				_start(GameState.MODE_ENDLESS)


func _draw() -> void:
	# Decorative tetromino scatter.
	var decos := [
		["T", Vector2(280, 260)], ["L", Vector2(1460, 220)], ["S", Vector2(240, 700)],
		["I", Vector2(1520, 660)], ["Z", Vector2(420, 900)], ["J", Vector2(1360, 880)],
	]
	for d in decos:
		var color: Color = Board.COLORS[d[0]]
		color.a = 0.5
		for c in Board.SHAPES[d[0]][0]:
			var p: Vector2 = d[1] + Vector2(c) * 44.0
			draw_rect(Rect2(p, Vector2(42.0, 42.0)), color)
			draw_rect(Rect2(p, Vector2(42.0, 42.0)), color.darkened(0.3), false, 2.0)
