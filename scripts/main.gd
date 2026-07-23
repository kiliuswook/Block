extends Node2D
## Entry point: wires the board to the UI, handles restart, pause and
## returning to the title screen. The board mode comes from GameState.mode.

const CREAM := Color(0.956863, 0.890196, 0.784314)
const GOLD := Color(1.0, 0.85, 0.35)

@onready var board: EscapeBoard = $Board
@onready var score_title: Label = $UI/ScoreTitle
@onready var score_label: Label = $UI/ScoreLabel
@onready var level_title: Label = $UI/LevelTitle
@onready var level_label: Label = $UI/LevelLabel
@onready var height_title: Label = $UI/HeightTitle
@onready var height_label: Label = $UI/HeightLabel
@onready var best_title: Label = $UI/BestTitle
@onready var best_label: Label = $UI/BestLabel
@onready var record_label: Label = $UI/RecordLabel
@onready var flash_rect: ColorRect = $UI/FlashRect
@onready var milestone_label: Label = $UI/MilestoneLabel
@onready var lines_title: Label = $UI/LinesTitle
@onready var lines_label: Label = $UI/LinesLabel
@onready var goal_label: Label = $UI/GoalLabel
@onready var game_over_label: Label = $UI/GameOverLabel
@onready var pause_label: Label = $UI/PauseLabel
@onready var escape_label: Label = $UI/EscapeLabel

var height := 0
var record_broken := false
var height_tween: Tween
var record_tween: Tween


func _ready() -> void:
	EventBus.score_changed.connect(func(v: int) -> void: score_label.text = str(v))
	EventBus.level_changed.connect(func(v: int) -> void: level_label.text = str(v))
	EventBus.lines_changed.connect(func(v: int) -> void: lines_label.text = str(v))
	EventBus.height_changed.connect(_on_height_changed)
	EventBus.game_started.connect(_on_game_started)
	EventBus.game_over.connect(_on_game_over)
	EventBus.player_escaped.connect(_on_escaped)
	var endless := GameState.mode == GameState.MODE_ENDLESS
	level_title.visible = not endless
	level_label.visible = not endless
	score_title.visible = not endless
	score_label.visible = not endless
	lines_title.visible = not endless
	lines_label.visible = not endless
	height_title.visible = endless
	height_label.visible = endless
	best_title.visible = endless
	best_label.visible = endless
	if endless:
		goal_label.text = "블록을 쌓고 밟으며
끝없이 위로 올라가자!
아래에서 용암이 올라온다 — 닿으면 사망
대시/점프 2회 타격으로 블록 파괴"
	height_label.pivot_offset = height_label.size / 2.0
	milestone_label.pivot_offset = milestone_label.size / 2.0
	board.start_game()


func _on_game_started() -> void:
	height = 0
	record_broken = false
	record_label.visible = false
	if record_tween:
		record_tween.kill()
	best_label.text = "%d층" % GameState.best_height
	best_label.modulate = Color.WHITE
	height_label.modulate = Color.WHITE
	height_label.scale = Vector2.ONE
	if GameState.mode == GameState.MODE_ENDLESS:
		game_over_label.text = "GAME OVER\nR / 화면 터치  재시작      ESC  타이틀"


func _on_height_changed(v: int) -> void:
	var prev := height
	height = v
	height_label.text = "%d층" % v
	if v <= prev:
		return
	_punch_height_label()
	_spawn_floor_popup(v - prev)
	if v > GameState.best_height and not record_broken:
		record_broken = true
		_show_new_record()
	if record_broken:
		best_label.text = "%d층" % v
	var tier := floori(v / 10.0)
	if tier > floori(prev / 10.0):
		_show_milestone(tier * 10)


## Quick punch-scale + warm flash on the big height number.
func _punch_height_label() -> void:
	if height_tween:
		height_tween.kill()
	height_label.scale = Vector2(1.35, 1.35)
	height_label.modulate = Color(1.6, 1.5, 1.2)
	height_tween = create_tween()
	height_tween.set_parallel(true)
	height_tween.tween_property(height_label, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	height_tween.tween_property(height_label, "modulate", Color.WHITE, 0.4)


## A small "+N" that floats up from the height counter and fades out.
func _spawn_floor_popup(delta_floors: int) -> void:
	var pop := Label.new()
	pop.text = "+%d" % delta_floors
	pop.add_theme_font_size_override("font_size", 44)
	pop.add_theme_color_override("font_color", CREAM)
	pop.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	pop.add_theme_constant_override("outline_size", 8)
	pop.position = Vector2(1580.0, 250.0)
	height_label.get_parent().add_child(pop)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(pop, "position:y", pop.position.y - 90.0, 0.7) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(pop, "modulate:a", 0.0, 0.7).set_delay(0.15)
	tw.chain().tween_callback(pop.queue_free)


## Full-screen banner every 10 floors: slams in, holds, fades.
func _show_milestone(floors: int) -> void:
	milestone_label.text = "%d층 돌파!" % floors
	if floors % 50 == 0:
		milestone_label.text = "대기록! %d층 돌파!!" % floors
	milestone_label.visible = true
	milestone_label.modulate = Color(1, 1, 1, 0)
	milestone_label.scale = Vector2(2.2, 2.2)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(milestone_label, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(milestone_label, "modulate:a", 1.0, 0.12)
	tw.chain().tween_interval(0.7)
	tw.chain().tween_property(milestone_label, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(func() -> void: milestone_label.visible = false)
	_screen_flash(0.22 if floors % 50 == 0 else 0.14)


func _screen_flash(strength: float) -> void:
	flash_rect.visible = true
	flash_rect.color.a = strength
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, 0.45)
	tw.tween_callback(func() -> void: flash_rect.visible = false)


## First time the run passes the all-time best: gold pulse until game over.
func _show_new_record() -> void:
	record_label.visible = true
	best_label.modulate = GOLD
	record_label.scale = Vector2(1.8, 1.8)
	record_label.pivot_offset = record_label.size / 2.0
	var intro := create_tween()
	intro.tween_property(record_label, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	record_tween = create_tween()
	record_tween.set_loops()
	record_tween.tween_property(record_label, "modulate:a", 0.45, 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	record_tween.tween_property(record_label, "modulate:a", 1.0, 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_screen_flash(0.18)


func _on_game_over() -> void:
	if GameState.mode != GameState.MODE_ENDLESS:
		return
	var was_record := GameState.record_height(height)
	var head := "☆ 신기록 달성! ☆\n" if was_record else ""
	game_over_label.text = "%sGAME OVER\n도달 높이 %d층      최고 기록 %d층\nR / 화면 터치  재시작      ESC  타이틀" \
			% [head, height, GameState.best_height]


func _on_escaped(new_level: int) -> void:
	escape_label.text = "ESCAPE!\nLEVEL %d" % new_level
	escape_label.visible = true
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(func() -> void: escape_label.visible = false)


func _unhandled_input(event: InputEvent) -> void:
	var touch_restart: bool = game_over_label.visible \
			and event is InputEventScreenTouch and event.pressed
	if event.is_action_pressed("to_title"):
		get_tree().change_scene_to_file("res://scenes/title.tscn")
	elif event.is_action_pressed("restart") or touch_restart:
		game_over_label.visible = false
		pause_label.visible = false
		escape_label.visible = false
		board.start_game()
	elif event.is_action_pressed("pause") and board.playing:
		board.is_paused = not board.is_paused
		pause_label.visible = board.is_paused
