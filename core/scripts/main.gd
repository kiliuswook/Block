extends Node2D
## Entry point: wires the board to the UI, handles restart, pause and
## returning to the title screen. The board mode comes from GameState.mode.

const CREAM := Color(0.956863, 0.890196, 0.784314)
const GOLD := Color(1.0, 0.85, 0.35)
const VERSUS_TARGET := 3  # first to this many round wins takes the match

const BOARD_SCENE := preload("res://core/scenes/board.tscn")
const HALF_W := 960.0  # split screen: width of each player's viewport

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
@onready var pause_label: Label = $UI/PauseLabel
@onready var escape_label: Label = $UI/EscapeLabel
@onready var death_popup: Control = $PopupLayer/DeathPopup
@onready var help_label: Label = $UI/HelpLabel

var height := 0
var record_broken := false
var height_tween: Tween
var record_tween: Tween
# Rewards already paid out this run — a revived player only earns the delta.
var gold_awarded := 0
var gems_awarded := 0
var p1_wins := 0
var p2_wins := 0
var versus_tally: Label
var match_over := false
var boards: Array = []  # every active board: [board] normally, two in split
var split_labels: Array = []
var round_active := true


func _ready() -> void:
	EventBus.score_changed.connect(func(v: int) -> void: score_label.text = str(v))
	EventBus.level_changed.connect(func(v: int) -> void: level_label.text = str(v))
	EventBus.lines_changed.connect(func(v: int) -> void: lines_label.text = str(v))
	EventBus.height_changed.connect(_on_height_changed)
	EventBus.game_started.connect(_on_game_started)
	EventBus.game_over.connect(_on_game_over)
	EventBus.player_escaped.connect(_on_escaped)
	death_popup.continue_pressed.connect(_on_revive)
	death_popup.restart_pressed.connect(_restart)
	death_popup.title_pressed.connect(_to_title)
	EventBus.versus_round_over.connect(_on_versus_round)
	var endless := GameState.mode == GameState.MODE_ENDLESS
	var versus := GameState.mode == GameState.MODE_VERSUS
	level_title.visible = not endless and not versus
	level_label.visible = not endless and not versus
	score_title.visible = not endless and not versus
	score_label.visible = not endless and not versus
	lines_title.visible = not endless and not versus
	lines_label.visible = not endless and not versus
	height_title.visible = endless
	height_label.visible = endless
	best_title.visible = endless
	best_label.visible = endless
	if endless:
		goal_label.text = "블록을 쌓고 밟으며
끝없이 위로 올라가자!
아래에서 용암이 올라온다 — 닿으면 사망
대시/점프 2회 타격으로 블록 파괴
줄을 지워 FEVER 게이지 충전 —
피버 중엔 무적 + 2배 점프,
빠르게 쏟아지는 블록을 밟고 상승!"
	elif versus:
		goal_label.text = "2P 대전  —  %d선승
P1 고양이: 출구로 탈출하면 승리
P2 블록: 고양이를 깔아뭉개면 승리
꼭대기까지 쌓아버리면 P2 패배!" % VERSUS_TARGET
		help_label.text = "P1(고양이)  < > 이동 (더블탭: 대시)   ^ 점프   v 빠른 낙하        P2(블록)  A/D 이동   Q/E 회전   S 낙하 (더블탭: 슬램, 착지 후: 고정)        R 새 대결   ESC 타이틀"
		_build_versus_tally()
	height_label.pivot_offset = height_label.size / 2.0
	milestone_label.pivot_offset = milestone_label.size / 2.0
	boards = [board]
	if GameState.split:
		_build_split()
	else:
		board.start_game()


func _on_game_started() -> void:
	height = 0
	record_broken = false
	gold_awarded = 0
	gems_awarded = 0
	record_label.visible = false
	if record_tween:
		record_tween.kill()
	best_label.text = "%d층" % GameState.best_height
	best_label.modulate = Color.WHITE
	height_label.modulate = Color.WHITE
	height_label.scale = Vector2.ONE


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
	pop.position = height_label.position + Vector2(height_label.size.x + 20.0, 20.0)
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
	var was_record := false
	var stats := ""
	if GameState.mode == GameState.MODE_ENDLESS:
		was_record = GameState.record_height(height)
		stats = "도달 높이 %d층      최고 기록 %d층" % [height, GameState.best_height]
	else:
		stats = "LEVEL %d      SCORE %d" % [board.level, GameState.score]
	var earned := _award_run_rewards(was_record)
	# Let the death sink in for a beat before the popup slides up.
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_callback(func() -> void:
		if not board.playing:
			death_popup.open(stats, was_record, earned))


## Pays out gold/gems for the whole run so far (minus what a previous death in
## this run already paid). Gems are deliberately scarce. Returns a display line.
func _award_run_rewards(was_record: bool) -> String:
	var run_gold := 0
	var run_gems := 0
	if GameState.mode == GameState.MODE_ENDLESS:
		run_gold = height * 3
		run_gems = mini(height / 30, 3)
	else:
		run_gold = GameState.score / 20
		run_gems = mini(board.level - 1, 3)
	if was_record and run_gold > 0:
		run_gems += 1
	var earn_gold := maxi(run_gold - gold_awarded, 0)
	var earn_gems := maxi(run_gems - gems_awarded, 0)
	gold_awarded = maxi(run_gold, gold_awarded)
	gems_awarded = maxi(run_gems, gems_awarded)
	if earn_gold <= 0 and earn_gems <= 0:
		return ""
	GameState.add_currency(earn_gold, earn_gems)
	var line := "획득   +%d G" % earn_gold
	if earn_gems > 0:
		line += "   +%d ◆" % earn_gems
	return line


# --- Split screen (local 2P, escape/endless) ----------------------------------


## Replaces the single board with two SubViewports side by side, one board
## each: P1 (left, default keys) vs P2 (right, WASD + Q/E + Ctrl).
func _build_split() -> void:
	for n in [score_title, score_label, level_title, level_label, lines_title,
			lines_label, height_title, height_label, best_title, best_label,
			goal_label, $UI/NextTitle, $UI/NextPreview]:
		n.visible = false
	$TouchControls.visible = false
	help_label.text = "P1(왼쪽)  A/D 이동 (더블탭: 대시)   W 점프   S 낙하   Q/E 회전   Ctrl 대시        P2(오른쪽)  < > 이동   ^ 점프   v 낙하   , . 회전   Shift 대시        R 새 대결   ESC 타이틀"
	board.queue_free()
	boards = []
	for i in range(2):
		var svc := SubViewportContainer.new()
		svc.stretch = true
		svc.position = Vector2(i * HALF_W, 0.0)
		svc.size = Vector2(HALF_W, 1080.0)
		add_child(svc)
		var sv := SubViewport.new()
		sv.size = Vector2i(int(HALF_W), 1080)
		sv.transparent_bg = true
		svc.add_child(sv)
		var b: EscapeBoard = BOARD_SCENE.instantiate()
		b.position = Vector2((HALF_W - EscapeBoard.COLS * EscapeBoard.CELL) / 2.0, 92.0)
		sv.add_child(b)
		b.finished.connect(_on_split_finished.bind(i))
		boards.append(b)
	board = boards[0]
	# Seating matches the keyboard: P1 (left half) = WASD side,
	# P2 (right half) = arrow keys side (default action set).
	var b1: EscapeBoard = boards[0]
	b1.act_rot_cw = "p2_rot_cw"
	b1.act_rot_ccw = "p2_rot_ccw"
	b1.act_drop = "p2_drop"
	var p1: Player = b1.get_node("Player")
	p1.act_left = "p2_left"
	p1.act_right = "p2_right"
	p1.act_jump = "p2_jump"
	p1.act_drop = "p2_drop"
	p1.act_dash = "p2_dash"
	p1.skin_override = "cheese" if GameState.selected_cat != "cheese" else "gray"
	var divider := ColorRect.new()
	divider.position = Vector2(HALF_W - 2.0, 0.0)
	divider.size = Vector2(4.0, 1080.0)
	divider.color = Color(CREAM, 0.35)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(divider)
	_build_versus_tally()
	for i in range(2):
		var l := Label.new()
		# Outer corners, clear of the centered score tally.
		l.position = Vector2(28.0 if i == 0 else 1920.0 - 428.0, 30.0)
		l.size = Vector2(400.0, 56.0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 \
				else HORIZONTAL_ALIGNMENT_RIGHT
		l.add_theme_font_size_override("font_size", 38)
		l.add_theme_color_override("font_color", CREAM)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("outline_size", 8)
		$UI.add_child(l)
		split_labels.append(l)
	_start_boards()


func _process(_delta: float) -> void:
	if split_labels.is_empty():
		return
	for i in range(2):
		var b: EscapeBoard = boards[i]
		if GameState.mode == GameState.MODE_ENDLESS:
			split_labels[i].text = "P%d   %d층" % [i + 1, b.best_height]
		else:
			split_labels[i].text = "P%d" % (i + 1)


## A split board reports its round result. Escape: first escape wins. Any
## death (crushed, lava, buried) loses the round for that side.
func _on_split_finished(win: bool, idx: int) -> void:
	if not round_active:
		return
	var winner := (idx + 1) if win else (2 - idx)
	for b in boards:
		b.is_paused = b.playing  # freeze the other half during the banner
	_duel_round(winner, "P%d" % winner)


func _start_boards() -> void:
	round_active = true
	for b in boards:
		b.start_game()


# --- Versus (local 2P) --------------------------------------------------------


func _build_versus_tally() -> void:
	versus_tally = Label.new()
	versus_tally.position = Vector2(0.0, 28.0)
	versus_tally.size = Vector2(1920.0, 60.0)
	versus_tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	versus_tally.add_theme_font_size_override("font_size", 40)
	versus_tally.add_theme_color_override("font_color", CREAM)
	versus_tally.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	versus_tally.add_theme_constant_override("outline_size", 8)
	$UI.add_child(versus_tally)
	_update_versus_tally()


func _update_versus_tally() -> void:
	if GameState.split:
		versus_tally.text = "P1  %d : %d  P2" % [p1_wins, p2_wins]
	else:
		versus_tally.text = "P1 고양이  %d : %d  블록 P2" % [p1_wins, p2_wins]


func _on_versus_round(winner: int) -> void:
	_duel_round(winner, "고양이 (P1)" if winner == 1 else "블록 (P2)")


## Shared round flow for versus and split: tally, banner, auto next round,
## first to VERSUS_TARGET takes the match.
func _duel_round(winner: int, who: String) -> void:
	round_active = false
	if winner == 1:
		p1_wins += 1
	else:
		p2_wins += 1
	_update_versus_tally()
	match_over = p1_wins >= VERSUS_TARGET or p2_wins >= VERSUS_TARGET
	milestone_label.visible = true
	milestone_label.modulate = Color(1, 1, 1, 0)
	milestone_label.scale = Vector2(1.8, 1.8)
	if match_over:
		milestone_label.text = "%s 최종 승리!\n%d : %d\n\nR 새 대결  ·  ESC 타이틀" % [who, p1_wins, p2_wins]
	else:
		milestone_label.text = "%s 라운드 승리!" % who
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(milestone_label, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(milestone_label, "modulate:a", 1.0, 0.12)
	_screen_flash(0.2)
	if match_over:
		return
	tw.chain().tween_interval(1.3)
	tw.chain().tween_property(milestone_label, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(func() -> void:
		milestone_label.visible = false
		if not match_over and not round_active:
			_start_boards())


func _on_revive() -> void:
	death_popup.close()
	board.revive_player()
	_screen_flash(0.25)


func _restart() -> void:
	death_popup.close()
	pause_label.visible = false
	escape_label.visible = false
	if GameState.mode == GameState.MODE_VERSUS or GameState.split:
		p1_wins = 0
		p2_wins = 0
		match_over = false
		milestone_label.visible = false
		_update_versus_tally()
	_start_boards()


func _to_title() -> void:
	get_tree().change_scene_to_file("res://core/scenes/boot.tscn")


func _on_escaped(new_level: int) -> void:
	escape_label.text = "ESCAPE!\nLEVEL %d" % new_level
	escape_label.visible = true
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(func() -> void: escape_label.visible = false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("to_title"):
		_to_title()
	elif event.is_action_pressed("restart"):
		_restart()
	elif event.is_action_pressed("pause") and round_active \
			and boards.any(func(b: EscapeBoard) -> bool: return b.playing):
		var paused: bool = not board.is_paused
		for b in boards:
			b.is_paused = paused
		pause_label.visible = paused
