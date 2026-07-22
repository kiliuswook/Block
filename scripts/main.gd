extends Node2D
## Entry point: wires the escape board to the UI, handles restart and pause.

@onready var board: EscapeBoard = $Board
@onready var score_label: Label = $UI/ScoreLabel
@onready var level_label: Label = $UI/LevelLabel
@onready var lines_label: Label = $UI/LinesLabel
@onready var game_over_label: Label = $UI/GameOverLabel
@onready var pause_label: Label = $UI/PauseLabel
@onready var escape_label: Label = $UI/EscapeLabel


func _ready() -> void:
	EventBus.score_changed.connect(func(v: int) -> void: score_label.text = str(v))
	EventBus.level_changed.connect(func(v: int) -> void: level_label.text = str(v))
	EventBus.lines_changed.connect(func(v: int) -> void: lines_label.text = str(v))
	EventBus.game_over.connect(func() -> void: game_over_label.visible = true)
	EventBus.player_escaped.connect(_on_escaped)
	board.start_game()


func _on_escaped(new_level: int) -> void:
	escape_label.text = "ESCAPE!\nLEVEL %d" % new_level
	escape_label.visible = true
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(func() -> void: escape_label.visible = false)


func _unhandled_input(event: InputEvent) -> void:
	var touch_restart: bool = game_over_label.visible \
			and event is InputEventScreenTouch and event.pressed
	if event.is_action_pressed("restart") or touch_restart:
		game_over_label.visible = false
		pause_label.visible = false
		escape_label.visible = false
		board.start_game()
	elif event.is_action_pressed("pause") and board.playing:
		board.is_paused = not board.is_paused
		pause_label.visible = board.is_paused
