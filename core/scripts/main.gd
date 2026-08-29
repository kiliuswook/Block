extends Node2D
## Entry point: wires the board to the UI, handles restart, pause and
## returning to the title screen. The board mode comes from GameState.mode.

const CREAM := Color(0.956863, 0.890196, 0.784314)
const GOLD := Color(1.0, 0.85, 0.35)
const VERSUS_TARGET := 3  # first to this many round wins takes the match

const BOARD_SCENE := preload("res://core/scenes/board.tscn")
const SETTINGS_PANEL := preload("res://core/scripts/settings_panel.gd")
const GOAL_METER := preload("res://core/scripts/goal_meter.gd")
const USER_HUD := preload("res://core/scripts/user_hud.gd")
const HALF_W := 960.0  # split screen: width of each player's viewport
const NEXT_PREVIEW := preload("res://core/scripts/next_preview.gd")
## 분할 스테이지 모드의 좌석별 계기판: 화면 바깥쪽 여백에 세우는 열의 자리와 폭.
const SEAT_HUD_W := 200.0
const SEAT_HUD_MARGIN := 20.0

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
# Story mode: full-screen stage intro / completion overlay (built in code).
var story_intro: Control
var intro_mode := "stage"  # "stage" resumes play on dismiss, "complete" → title
var intro_clear: Label
var intro_stage: Label
var intro_name: Label
var intro_hint: Label
var intro_prompt: Label
var stage_header := ""
var goal_meter: Control  # classic: the LINES goal drawn as a rack of tiles
# Gold already paid out this run.
var gold_awarded := 0
var xp_awarded := 0  # 이 판이 이미 지급한 계정 경험치 (중복 지급 방지)
var p1_wins := 0
var p2_wins := 0
var versus_tally: Label
var match_over := false
var boards: Array = []  # every active board: [board] normally, two in split
var split_labels: Array = []
## 분할 스테이지 모드: 좌석별로 판이 끝났는지 (끝난 쪽은 그 자리에 멈춰 있고
## 남은 쪽은 계속 논다). 다 끝나면 승자의 기록만 랭킹에 올라간다.
var stage_split_over := [false, false]
## 좌석별 계기판 노드 {score, best, level, lines, meter, next} × 2 (스테이지 분할).
var seat_hud: Array = []
var round_active := true
var settings_panel: Control  # doubles as the pause menu (volume sliders)
var user_hud: CanvasLayer  # 타이틀과 같은 자리·같은 카드의 유저 정보 HUD


func _ready() -> void:
	EventBus.score_changed.connect(func(v: int) -> void: score_label.text = str(v))
	EventBus.level_changed.connect(func(v: int) -> void: level_label.text = str(v))
	EventBus.lines_changed.connect(func(v: int) -> void: lines_label.text = str(v))
	EventBus.height_changed.connect(_on_height_changed)
	EventBus.game_started.connect(_on_game_started)
	EventBus.game_over.connect(_on_game_over)
	EventBus.player_escaped.connect(_on_escaped)
	death_popup.restart_pressed.connect(_restart)
	death_popup.title_pressed.connect(_to_title)
	EventBus.story_reward.connect(_on_story_reward)
	EventBus.versus_round_over.connect(_on_versus_round)
	var endless := GameState.mode == GameState.MODE_ENDLESS
	var versus := GameState.mode == GameState.MODE_VERSUS
	var classic := GameState.mode == GameState.MODE_CLASSIC
	var picnic := GameState.mode == GameState.MODE_PICNIC
	level_title.visible = not endless and not versus and not picnic and not classic
	level_label.visible = not endless and not versus and not picnic and not classic
	score_title.visible = not endless and not versus
	score_label.visible = not endless and not versus
	lines_title.visible = not endless and not versus and not picnic
	lines_label.visible = not endless and not versus and not picnic
	height_title.visible = endless or picnic or classic
	height_label.visible = endless or picnic or classic
	best_title.visible = endless or picnic or classic
	best_label.visible = endless or picnic or classic
	if classic and not GameState.split:
		# Arcade cabinet HUD: LEVEL is the board you're on, TOP is the high score,
		# and LINES is a rack of tiles rather than a number.
		# 분할 화면은 이 HUD를 통째로 숨기고 좌석 라벨로 대신한다 (_build_split).
		height_title.text = "LEVEL"
		best_title.text = "TOP"
		lines_title.text = "LINES"
		# 설명 문구는 두지 않는다 — 아케이드 계기판만 남긴다.
		goal_label.visible = false
		_build_goal_meter()
		_build_skip_level_button()
		EventBus.classic_level_started.connect(_on_classic_level_started)
		EventBus.classic_level_progress.connect(_on_classic_level_progress)
		EventBus.classic_level_cleared.connect(_on_classic_level_cleared)
	if picnic:
		# Casual mode: the big number slot becomes the countdown timer.
		height_title.text = tr("HUD_TIME_LEFT")
		best_title.text = tr("HUD_BEST_SCORE")
		if get_viewport_rect().size.x > get_viewport_rect().size.y:
			# Landscape: score shares the timer's slot — slide it below BEST.
			# (Portrait already spreads them: timer top-center, score right column.)
			score_title.position = Vector2(1360.0, 460.0)
			score_label.position = Vector2(1360.0, 488.0)
		goal_label.text = tr("TUT_PICNIC")
	if endless:
		goal_label.text = tr("TUT_ENDLESS")
	elif versus:
		goal_label.text = tr("TUT_VERSUS").format({"target": VERSUS_TARGET})
		help_label.text = tr("TUT_KEYS_VERSUS")
		_build_versus_tally()
	if GameState.mode == GameState.MODE_STORY and not GameState.split:
		EventBus.story_stage_started.connect(_on_story_stage)
		EventBus.story_progress_changed.connect(_on_story_progress)
		EventBus.story_doors_opened.connect(_on_story_doors_opened)
		EventBus.story_completed.connect(_on_story_completed)
		_build_story_intro()
		_layout_story_goal_label()
	height_label.pivot_offset = height_label.size / 2.0
	milestone_label.pivot_offset = milestone_label.size / 2.0
	if get_viewport_rect().size.y > get_viewport_rect().size.x:
		# Portrait: the endless camera keeps the pit behind the help-line slot,
		# and the touch buttons explain themselves — drop the text everywhere.
		help_label.visible = false
	_build_user_hud()
	settings_panel = SETTINGS_PANEL.new()
	settings_panel.closed.connect(_on_settings_closed)
	$PopupLayer.add_child(settings_panel)
	Sfx.play_bgm("game")
	boards = [board]
	if GameState.split:
		_build_split()
	else:
		board.start_game()
		if not endless:  # endless is camera-driven; fixed pits get scaled to fit
			_fit_board()


func _on_game_started() -> void:
	height = 0
	record_broken = false
	gold_awarded = 0
	xp_awarded = 0
	record_label.visible = false
	if record_tween:
		record_tween.kill()
	match GameState.mode:
		GameState.MODE_PICNIC:
			best_label.text = tr("HUD_POINTS").format({"n": GameState.picnic_best})
		GameState.MODE_CLASSIC:
			best_label.text = tr("HUD_POINTS").format({"n": GameState.classic_best})
		_:
			best_label.text = tr("HUD_FLOOR").format({"n": GameState.best_height})
	best_label.modulate = Color.WHITE
	height_label.modulate = Color.WHITE
	height_label.scale = Vector2.ONE


func _on_height_changed(v: int) -> void:
	if GameState.mode == GameState.MODE_CLASSIC:
		return  # classic owns the big-number slot for the LEVEL counter
	var prev := height
	height = v
	height_label.text = tr("HUD_FLOOR").format({"n": v})
	if v <= prev:
		return
	_punch_height_label()
	_spawn_floor_popup(v - prev)
	if v > GameState.best_height and not record_broken:
		record_broken = true
		_show_new_record()
	if record_broken:
		best_label.text = tr("HUD_FLOOR").format({"n": v})
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
	milestone_label.text = tr("HUD_MILESTONE").format({"n": floors})
	if floors % 50 == 0:
		milestone_label.text = tr("HUD_MILESTONE_BIG").format({"n": floors})
	Sfx.play("milestone")
	_pop_milestone()
	_screen_flash(0.22 if floors % 50 == 0 else 0.14)


## Slam-in/hold/fade animation for whatever text milestone_label holds.
func _pop_milestone() -> void:
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


func _screen_flash(strength: float) -> void:
	flash_rect.visible = true
	flash_rect.color.a = strength
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, 0.45)
	tw.tween_callback(func() -> void: flash_rect.visible = false)


## First time the run passes the all-time best: gold pulse until game over.
func _show_new_record() -> void:
	Sfx.play("record")
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
	var endless := GameState.mode == GameState.MODE_ENDLESS
	var classic := GameState.mode == GameState.MODE_CLASSIC
	var picnic := GameState.mode == GameState.MODE_PICNIC
	if endless:
		var weekly_up := GameState.record_weekly("endless", height)
		was_record = GameState.record_height(height)
		stats = tr("HUD_STATS_ENDLESS").format(
				{"height": height, "best": GameState.best_height})
		if was_record:
			Replays.save_replay("endless", board.rec_export())
		if weekly_up and not was_record:  # record_height already submits
			Ranks.submit("endless", GameState.best_height)
	elif classic:
		var weekly_up := GameState.record_weekly("classic", GameState.score)
		was_record = GameState.record_classic(GameState.score)
		stats = "SCORE %d      LEVEL %d      LINES %d" \
				% [GameState.score, board.level, board.total_lines]
		if was_record:
			Replays.save_replay("classic", board.rec_export())
		if weekly_up and not was_record:
			Ranks.submit("classic", GameState.classic_best)
	elif picnic:
		var weekly_up := GameState.record_weekly("picnic", GameState.score)
		was_record = GameState.record_picnic(GameState.score)
		stats = tr("HUD_STATS_PICNIC").format({"score": GameState.score})
		if was_record:
			Replays.save_replay("picnic", board.rec_export())
		if weekly_up and not was_record:
			Ranks.submit("picnic", GameState.picnic_best)
	else:
		stats = "STAGE %d      SCORE %d" % [board.level, GameState.score]
	var earned := _award_run_rewards()
	var xp_line := _award_run_xp(was_record)
	if user_hud:  # 방금 받은 골드·경험치를 상단 HUD에 반영
		user_hud.refresh()
	# 업적: 무한 첫 완주는 판이 끝난 그 순간에만 알 수 있고, 나머지(기록·골드)는
	# 위에서 갱신된 세이브 값으로 판정된다. 분할 화면은 지갑·기록이 없어 제외.
	if not GameState.split:
		if endless:
			Achv.unlock(Achv.FIRST_ESCAPE)
		Achv.check()
	# Let the death sink in for a beat before the popup slides up.
	# Picnic ends on the clock, not in defeat: a cheerier title.
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_callback(func() -> void:
		if not board.playing:
			death_popup.open(stats, was_record, earned,
					tr("POP_PICNIC_END") if picnic else "", xp_line))


## 유저 정보 HUD — 타이틀과 같은 스크립트·같은 자리(좌상단).
## 지갑이 없는 분할 화면 대전에서는 띄우지 않는다. 세로 화면(모바일 인게임)은
## 좌상단이 터치 메뉴 버튼, 우상단이 기록 슬롯이라 아직 자리가 없다 —
## 모바일 레이아웃을 재개할 때 배치를 정한다 (PC 우선 기간).
func _build_user_hud() -> void:
	var vp := get_viewport_rect().size
	if GameState.split or vp.y > vp.x:
		return
	user_hud = USER_HUD.new()
	add_child(user_hud)


## Pays out gold for the whole run so far (minus what this run already paid).
## Returns a display line.
func _award_run_rewards() -> String:
	var run_gold := 0
	if GameState.mode == GameState.MODE_ENDLESS:
		run_gold = height * 3
	elif GameState.mode == GameState.MODE_CLASSIC:
		# Arcade scores swing bigger (1200 x level tetrises + shutter bonuses),
		# so gold divides harder.
		run_gold = GameState.score / 40
	else:
		run_gold = GameState.score / 20
	var earn_gold := maxi(run_gold - gold_awarded, 0)
	gold_awarded = maxi(run_gold, gold_awarded)
	if earn_gold <= 0:
		return ""
	# First rewarded run of the day pays double gold.
	var daily := GameState.claim_daily_bonus()
	if daily:
		earn_gold *= 2
	GameState.add_currency(earn_gold)
	var line := tr("HUD_EARNED").format({"gold": earn_gold})
	if daily:
		line = tr("HUD_DAILY_DOUBLE") + line
	return line


## 이 판의 계정 경험치를 지급한다 — 골드와 달리 소비할 수 없는 축이라
## 성적이 나빠도 참가비만큼은 들어온다. 오른 레벨이 있으면 그 줄까지 붙여 준다.
## 분할 화면(2인)은 지갑도 기록도 없는 대전이라 제외.
func _award_run_xp(record: bool) -> String:
	if GameState.split:
		return ""
	var run_xp := Account.run_xp(GameState.mode, GameState.score, height,
			board.level if is_instance_valid(board) else 0, record)
	var earn_xp := maxi(run_xp - xp_awarded, 0)
	xp_awarded = maxi(run_xp, xp_awarded)
	if earn_xp <= 0:
		return ""
	var got := Account.add_xp(earn_xp)
	var line := tr("HUD_XP_EARNED").format({"xp": earn_xp})
	var levels: Array = got.get("levels", [])
	if not levels.is_empty():
		Sfx.play("record")
		line += "\n" + tr("HUD_LEVEL_UP").format(
				{"level": int(levels[-1]), "gold": int(got.get("gold", 0))})
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
	help_label.text = tr("TUT_KEYS_SPLIT")
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
		if GameState.mode != GameState.MODE_ENDLESS:
			# Fixed 20-row pit (escape race / stage duel) — scale to the half
			# viewport. Endless is camera-driven and keeps its own framing.
			var bs := (1080.0 - 80.0) / (EscapeBoard.PIT_ROWS * EscapeBoard.CELL)
			b.scale = Vector2(bs, bs)
			b.position = Vector2(
					(HALF_W - EscapeBoard.COLS * EscapeBoard.CELL * bs) / 2.0, 40.0)
		else:
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
	p1.player_slot = 1
	# 오른쪽 절반(기본 키 배치)이 2P — 자기 냥이와 커스터마이징을 쓴다.
	var p2: Player = (boards[1] as EscapeBoard).get_node("Player")
	p2.player_slot = 2
	var divider := ColorRect.new()
	divider.position = Vector2(HALF_W - 2.0, 0.0)
	divider.size = Vector2(4.0, 1080.0)
	divider.color = Color(CREAM, 0.35)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(divider)
	if GameState.mode != GameState.MODE_CLASSIC:
		# 스테이지 분할은 좌석 계기판이 점수를 다 보여 준다 — 가운데 집계는 없다.
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
	if GameState.mode == GameState.MODE_CLASSIC:
		_build_seat_huds()
	_start_boards()


## 분할 스테이지 모드: 1인 플레이와 같은 계기판(NEXT·SCORE·TOP·LEVEL·LINES 랙)을
## 좌석마다 하나씩 세운다. 우물은 반쪽 화면 가운데에 놓이므로 열은 바깥쪽 여백
## (P1 왼쪽 끝 / P2 오른쪽 끝)에 세워 가운데 분할선을 비워 둔다.
func _build_seat_huds() -> void:
	for i in range(2):
		var x := SEAT_HUD_MARGIN if i == 0 else 1920.0 - SEAT_HUD_MARGIN - SEAT_HUD_W
		# 좌석 이름표는 그 열의 머리로 올라간다.
		var name_label: Label = split_labels[i]
		name_label.position = Vector2(x, 24.0)
		name_label.size = Vector2(SEAT_HUD_W, 52.0)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var hud := {}
		_seat_title(x, 96.0, "NEXT")
		var nx: Control = NEXT_PREVIEW.new()
		nx.position = Vector2(x, 126.0)
		nx.size = Vector2(SEAT_HUD_W, 116.0)
		$UI.add_child(nx)
		hud["next"] = nx
		# 1인 계기판과 같은 순서·같은 표기: NEXT → LEVEL → SCORE → TOP → LINES 랙.
		hud["level"] = _seat_stat(x, 268.0, "LEVEL", 52)
		hud["score"] = _seat_stat(x, 380.0, "SCORE")
		hud["best"] = _seat_stat(x, 470.0, "TOP")
		hud["lines"] = _seat_stat(x, 560.0, "LINES")
		var meter: Control = GOAL_METER.new()
		meter.position = Vector2(x, 646.0)
		meter.size = Vector2(SEAT_HUD_W, 110.0)
		meter.per_row = 5
		meter.centered = true
		$UI.add_child(meter)
		hud["meter"] = meter
		seat_hud.append(hud)


## Small dim caption above a seat stat (matches the solo HUD's title style).
func _seat_title(x: float, y: float, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.position = Vector2(x, y)
	l.size = Vector2(SEAT_HUD_W, 28.0)
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	$UI.add_child(l)


## Caption + value pair; returns the value label the HUD keeps updating.
func _seat_stat(x: float, y: float, title: String, font_size := 38) -> Label:
	_seat_title(x, y, title)
	var l := Label.new()
	l.text = "0"
	l.position = Vector2(x, y + 26.0)
	l.size = Vector2(SEAT_HUD_W, float(font_size) + 12.0)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", CREAM)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	$UI.add_child(l)
	return l


## 좌석 계기판을 보드 상태에 맞춰 갱신한다 (끝난 좌석은 마지막 값 그대로 멈춘다).
func _update_seat_huds() -> void:
	for i in range(2):
		var b: EscapeBoard = boards[i]
		var hud: Dictionary = seat_hud[i]
		(hud["score"] as Label).text = str(b.run_score)
		(hud["best"] as Label).text = tr("HUD_POINTS").format(
				{"n": GameState.classic_best})
		(hud["level"] as Label).text = str(b.level)
		var quota := Board.classic_quota(b.level)
		var lines := mini(b.level_lines, quota)
		(hud["lines"] as Label).text = "%d / %d" % [lines, quota]
		var meter = hud["meter"]
		if meter.cleared != lines or meter.quota != quota:
			meter.set_goal(lines, quota)
		var nx = hud["next"]
		if nx.next_type != b.next_type:
			nx.next_type = b.next_type
			nx.queue_redraw()


func _process(_delta: float) -> void:
	if GameState.mode == GameState.MODE_PICNIC and not GameState.split:
		var t := ceili(board.picnic_time)
		height_label.text = "%d:%02d" % [t / 60, t % 60]
		height_label.modulate = Color(1.0, 0.5, 0.45) if t <= 10 else Color.WHITE
	if split_labels.is_empty():
		return
	if GameState.mode == GameState.MODE_CLASSIC:
		_update_seat_huds()
	for i in range(2):
		var b: EscapeBoard = boards[i]
		if GameState.mode == GameState.MODE_ENDLESS:
			split_labels[i].text = tr("SPLIT_SCORE").format(
					{"n": i + 1, "floors": b.best_height})
		elif GameState.mode == GameState.MODE_CLASSIC:
			# 진행은 좌석 계기판이 읽어 준다 — 이름표는 좌석과 종료만 알린다.
			if stage_split_over[i]:
				split_labels[i].text = tr("SPLIT_STAGE_OVER").format({"n": i + 1})
				split_labels[i].modulate = Color(1.0, 0.55, 0.5)
			else:
				split_labels[i].text = "P%d" % (i + 1)
		else:
			split_labels[i].text = "P%d" % (i + 1)


## A split board reports its round result. Escape: first escape wins. Any
## death (crushed, lava, buried) loses the round for that side.
func _on_split_finished(win: bool, idx: int) -> void:
	if not round_active:
		return
	if GameState.mode == GameState.MODE_CLASSIC:
		_on_stage_split_finished(idx)
		return
	var winner := (idx + 1) if win else (2 - idx)
	for b in boards:
		b.is_paused = b.playing  # freeze the other half during the banner
	_duel_round(winner, "P%d" % winner)


## 분할 스테이지 모드: 한쪽이 죽어도 판은 끝나지 않는다 — 죽은 좌석은 그 상태로
## 멈춰 있고, 남은 좌석이 자기 판을 끝낼 때까지 계속 논다. 둘 다 끝나면 점수가
## 높은 쪽이 승자고, 그 좌석의 성적만 1인 플레이와 똑같이 기록·랭킹에 올라간다.
func _on_stage_split_finished(idx: int) -> void:
	stage_split_over[idx] = true  # 죽는 소리·연출은 보드가 이미 냈다
	if not stage_split_over.has(false):
		_finish_stage_split()


## 두 좌석 모두 끝났다: 승자를 가리고 그 기록을 남긴다.
func _finish_stage_split() -> void:
	round_active = false
	var b1: EscapeBoard = boards[0]
	var b2: EscapeBoard = boards[1]
	# 점수 우선, 같으면 더 멀리 간 판 → 지운 줄 순으로 가른다.
	var w := 1
	for key: Array in [[b1.run_score, b2.run_score], [b1.level, b2.level],
			[b1.total_lines, b2.total_lines]]:
		if key[0] != key[1]:
			w = 1 if key[0] > key[1] else 2
			break
	var wb: EscapeBoard = boards[w - 1]
	# 1인 플레이와 같은 기록 경로: 최고 점수·주간 기록·랭킹·도달 LEVEL·업적.
	var weekly_up := GameState.record_weekly("classic", wb.run_score)
	var was_record := GameState.record_classic(wb.run_score)
	if weekly_up and not was_record:  # record_classic already submits
		Ranks.submit("classic", GameState.classic_best)
	if wb.level > GameState.classic_level_best:
		GameState.classic_level_best = wb.level
		GameState.save_game()
	Achv.check()
	var title_text := tr("SPLIT_STAGE_WIN").format(
			{"n": w, "score": wb.run_score})
	var stats := "P%d      SCORE %d      LEVEL %d      LINES %d" 			% [w, wb.run_score, wb.level, wb.total_lines]
	milestone_label.visible = true
	milestone_label.modulate = Color(1, 1, 1, 0)
	milestone_label.scale = Vector2(1.8, 1.8)
	milestone_label.text = title_text
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(milestone_label, "scale", Vector2.ONE, 0.25) 			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(milestone_label, "modulate:a", 1.0, 0.12)
	_screen_flash(0.22)
	if was_record:
		Sfx.play("record")
	var pop := create_tween()
	pop.tween_interval(1.4)
	pop.tween_callback(func() -> void:
		milestone_label.visible = false
		death_popup.open(stats, was_record, "", title_text, ""))


func _start_boards() -> void:
	round_active = true
	stage_split_over = [false, false]
	milestone_label.visible = false
	for l: Label in split_labels:
		l.modulate = Color.WHITE
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
	if versus_tally == null:
		return  # 스테이지 분할: 가운데 집계 없이 좌석 계기판만 쓴다
	if GameState.split:
		versus_tally.text = "P1  %d : %d  P2" % [p1_wins, p2_wins]
	else:
		versus_tally.text = tr("VS_TALLY").format({"p1": p1_wins, "p2": p2_wins})


func _on_versus_round(winner: int) -> void:
	_duel_round(winner, tr("VS_CAT") if winner == 1 else tr("VS_BLOCKS"))


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
		milestone_label.text = tr("VS_MATCH_WIN").format(
				{"who": who, "p1": p1_wins, "p2": p2_wins})
	else:
		milestone_label.text = tr("VS_ROUND_WIN").format({"who": who})
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


## Floating banner for a first-clear story payout.
func _on_story_reward(reward_gold: int) -> void:
	var text := tr("HUD_STORY_REWARD").format({"gold": reward_gold})
	var vp := get_viewport_rect().size
	var pop := Label.new()
	pop.text = text
	pop.position = Vector2(0.0, vp.y * 0.30)
	pop.size = Vector2(vp.x, 50.0)
	pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pop.add_theme_font_size_override("font_size", 34)
	pop.add_theme_color_override("font_color", GOLD)
	pop.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	pop.add_theme_constant_override("outline_size", 8)
	$UI.add_child(pop)
	Sfx.play("gold")
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(pop, "position:y", pop.position.y - 70.0, 1.4) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(pop, "modulate:a", 0.0, 0.6).set_delay(0.9)
	tw.chain().tween_callback(pop.queue_free)


func _restart() -> void:
	death_popup.close()
	pause_label.visible = false
	settings_panel.visible = false  # bypass close(): _start_boards resets pause
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


## Every fixed-pit mode plays in the standard 20-row tetris well — taller
## than the scene layouts expect, so scale the board to fit between the top
## margin and (portrait) the touch zone, centered horizontally. Endless keeps
## its camera instead.
func _fit_board() -> void:
	var vp := get_viewport_rect().size
	var portrait := vp.y > vp.x
	var top := 200.0 if portrait else 40.0
	var bottom := 1410.0 if portrait else vp.y - 56.0
	var s := minf(1.0, (bottom - top) / (board.rows * EscapeBoard.CELL))
	board.scale = Vector2(s, s)
	board.position = Vector2((vp.x - EscapeBoard.COLS * EscapeBoard.CELL * s) / 2.0, top)
	if portrait:
		# The tall well runs through the portrait help-line slot — drop it,
		# the touch buttons are self-explanatory.
		help_label.visible = false


# --- Classic level (arcade B-type) ----------------------------------------------


## LINES goal as a rack of tiles: it sits under the LINES readout, and the
## column geometry differs per orientation (portrait's stat column is narrow).
func _build_goal_meter() -> void:
	var vp := get_viewport_rect().size
	goal_meter = GOAL_METER.new()
	$UI.add_child(goal_meter)
	if vp.x > vp.y:
		# Landscape: LEVEL takes the endless big-number slot, so the stat column
		# slides down past it and the meter gets a wide 5x2 rack.
		for pair: Array in [[score_title, score_label, 340.0],
				[best_title, best_label, 440.0],
				[lines_title, lines_label, 540.0]]:
			pair[0].position = Vector2(1360.0, pair[2])
			pair[1].position = Vector2(1360.0, pair[2] + 28.0)
		# The endless big-number font is sized for "23층"; "LEVEL 12" over a
		# full stat column needs to be a touch smaller to clear the SCORE row.
		height_label.add_theme_font_size_override("font_size", 60)
		goal_meter.position = Vector2(1360.0, 628.0)
		goal_meter.size = Vector2(260.0, 106.0)
		goal_meter.per_row = 5
	else:
		# Portrait: LEVEL rides top-center with the rack in one wide row beneath
		# it — the right column is too narrow to read ten tiles.
		lines_title.position = Vector2(912.0, 440.0)
		lines_label.position = Vector2(912.0, 468.0)
		goal_meter.position = Vector2(300.0, 140.0)
		goal_meter.size = Vector2(480.0, 44.0)
		goal_meter.per_row = 10
		goal_meter.centered = true


## Test affordance: clears the current level (shutter and all) so the later
## boards can be reached without playing through. Keyboard equivalent: N.
func _build_skip_level_button() -> void:
	var vp := get_viewport_rect().size
	var btn := Button.new()
	btn.text = tr("HUD_NEXT_LEVEL_TEST")
	btn.tooltip_text = tr("HUD_NEXT_LEVEL_TEST_TIP")
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(CREAM, 0.75))
	btn.modulate.a = 0.7
	if vp.x > vp.y:
		btn.position = Vector2(40.0, 40.0)
		btn.size = Vector2(240.0, 48.0)
	else:
		# Portrait: down the left margin, clear of the NEXT panel and the well.
		btn.add_theme_font_size_override("font_size", 24)
		btn.position = Vector2(24.0, 400.0)
		btn.size = Vector2(186.0, 64.0)
	btn.pressed.connect(func() -> void:
		if board.classic_skip_level():
			Sfx.play("click"))
	$UI.add_child(btn)


## A new board was dealt. No banner — the shutter lifting is the announcement;
## the HUD just rolls over to the new level.
func _on_classic_level_started(level: int, quota: int, _garbage: int) -> void:
	# 도달 LEVEL은 판이 끝나면 사라지는 값이라 여기서 최고치를 남긴다 (LV5/LV10 업적).
	if not GameState.split and level > GameState.classic_level_best:
		GameState.classic_level_best = level
		GameState.save_game()
		Achv.check()
	height_label.text = "%d" % level
	lines_label.text = "0 / %d" % quota
	goal_meter.set_goal(0, quota)
	if level > 1:
		_punch_height_label()


func _on_classic_level_progress(cleared: int, quota: int) -> void:
	lines_label.text = "%d / %d" % [cleared, quota]
	goal_meter.set_goal(cleared, quota)


## The shutter finished paying out: flash the well, nothing to read.
func _on_classic_level_cleared(_level: int, bonus: int) -> void:
	if bonus > 0:
		Sfx.play("record")
	_screen_flash(0.25)


func _on_escaped(new_level: int) -> void:
	if story_intro:
		# Story: the next stage's intro is already up — stamp the clear line on it.
		intro_clear.text = tr("HUD_STAGE_CLEAR").format({"n": new_level - 1})
		_screen_flash(0.2)
		return
	escape_label.text = "ESCAPE!\nLEVEL %d" % new_level
	escape_label.visible = true
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(func() -> void: escape_label.visible = false)


# --- Story mode UI --------------------------------------------------------------


## Story HUD goal readout: portrait (mobile) screens tuck it top-center;
## landscape keeps the scene's side-panel placement.
func _layout_story_goal_label() -> void:
	var vp := get_viewport_rect().size
	goal_label.visible = true
	if vp.y > vp.x:
		goal_label.position = Vector2(240.0, 20.0)
		goal_label.size = Vector2(vp.x - 480.0, 170.0)
		goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		goal_label.add_theme_font_size_override("font_size", 24)
		goal_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
		goal_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		goal_label.add_theme_constant_override("outline_size", 6)


## Full-screen stage intro / story-complete overlay, viewport-relative so the
## same code serves the landscape and portrait layouts.
func _build_story_intro() -> void:
	var vp := get_viewport_rect().size
	story_intro = Control.new()
	story_intro.set_anchors_preset(Control.PRESET_FULL_RECT)
	story_intro.visible = false
	$UI.add_child(story_intro)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.68)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	story_intro.add_child(dim)
	intro_clear = _intro_label(vp, vp.y * 0.17, 40, GOLD)
	intro_stage = _intro_label(vp, vp.y * 0.24, 92, CREAM)
	intro_name = _intro_label(vp, vp.y * 0.36, 46, Color.WHITE)
	intro_hint = _intro_label(vp, vp.y * 0.46, 27, Color(1, 1, 1, 0.9))
	# Portrait keeps the prompt above the touch-control zone.
	var prompt_y := vp.y * (0.62 if vp.y > vp.x else 0.8)
	intro_prompt = _intro_label(vp, prompt_y, 24, Color(CREAM, 0.8))


func _intro_label(vp: Vector2, y: float, font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.position = Vector2(40.0, y)
	l.size = Vector2(vp.x - 80.0, 60.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 10)
	story_intro.add_child(l)
	return l


func _on_story_stage(stage_num: int) -> void:
	var stage := StoryStages.get_stage(stage_num)
	stage_header = "STAGE %d — %s" % [stage_num, stage.name]
	goal_label.text = stage_header
	intro_mode = "stage"
	intro_clear.text = ""
	intro_stage.text = "STAGE %d" % stage_num
	intro_name.text = str(stage.name)
	var hint := str(stage.get("hint", ""))
	if $TouchControls.visible:
		hint = str(stage.get("hint_touch", hint))
	intro_hint.text = hint
	intro_prompt.text = tr("HUD_TAP_TO_START")
	story_intro.visible = true
	board.is_paused = true


func _hide_story_intro() -> void:
	if story_intro == null or not story_intro.visible:
		return
	story_intro.visible = false
	if intro_mode == "complete":
		_to_title()
	else:
		board.is_paused = false


func _on_story_progress(text: String) -> void:
	goal_label.text = "%s\n%s" % [stage_header, text]


func _on_story_doors_opened() -> void:
	milestone_label.text = tr("HUD_EXIT_OPEN")
	_pop_milestone()
	_screen_flash(0.18)


func _on_story_completed() -> void:
	Sfx.play("record")
	var earned := _award_run_rewards()
	var xp_line := _award_run_xp(true)
	intro_mode = "complete"
	intro_clear.text = tr("STORY_ALL_CLEAR")
	intro_stage.text = tr("STORY_COMPLETE")
	intro_name.text = tr("STORY_COMPLETE_DESC")
	intro_hint.text = "SCORE %d" % GameState.score \
			+ ("\n%s" % earned if earned != "" else "")
	intro_prompt.text = tr("STORY_TAP_TO_TITLE")
	story_intro.visible = true
	_screen_flash(0.3)


## Any key / click / touch dismisses the story overlay (Esc keeps its
## return-to-title role and passes through).
func _input(event: InputEvent) -> void:
	if story_intro == null or not story_intro.visible:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
		return
	_hide_story_intro()
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("to_title"):
		_to_title()
	elif event.is_action_pressed("restart"):
		_restart()
	elif event.is_action_pressed("pause") and round_active \
			and (story_intro == null or not story_intro.visible) \
			and boards.any(func(b: EscapeBoard) -> bool: return b.playing):
		if board.is_paused:
			settings_panel.close()  # closed signal resumes the boards
		else:
			for b in boards:
				b.is_paused = true
			Sfx.play("pause")
			settings_panel.open(false)


## The pause menu (settings panel) closed: resume play.
func _on_settings_closed() -> void:
	for b in boards:
		b.is_paused = false
	Sfx.play("pause")
