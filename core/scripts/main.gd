extends Node2D
## Entry point: wires the board to the UI, handles restart, pause and
## returning to the title screen. The board mode comes from GameState.mode.

const CREAM := Color(0.956863, 0.890196, 0.784314)
const GOLD := Color(1.0, 0.85, 0.35)

const UiKit := preload("res://core/scripts/ui_kit.gd")
const SETTINGS_PANEL := preload("res://core/scripts/settings_panel.gd")
const GOAL_METER := preload("res://core/scripts/goal_meter.gd")
const RUSH_METER := preload("res://core/scripts/rush_meter.gd")
const USER_HUD := preload("res://core/scripts/user_hud.gd")
const PIECE_FLYER := preload("res://core/scripts/piece_flyer.gd")
## 계기판 카드(타이틀과 같은 흰 카드): 열의 폭과 카드가 그 둘레에 두는 여백.
const HUD_COL_W := 300.0
const HUD_CARD_PAD := Vector2(22.0, 18.0)
## 오른쪽 계기판 열의 자리. 모드마다 켜지는 줄이 달라서 씬에 박힌 y를 그대로 쓰면
## 서로 겹친다 — 가로 화면 계기판의 y는 `_layout_stat_column()` 한 곳에서만 정한다.
const HUD_COL_X := 1360.0
const HUD_COL_TOP := 44.0
const HUD_ROW_GAP := 26.0  # 줄과 줄 사이
const HUD_CAPTION_GAP := 4.0  # 제목 ↔ 숫자
const HUD_CAPTION_H := 26.0

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
@onready var death_popup: Control = $PopupLayer/DeathPopup
@onready var help_label: Label = $UI/HelpLabel

var height := 0
var record_broken := false
var height_tween: Tween
var record_tween: Tween
var goal_meter: Control  # classic: the LINES goal drawn as a rack of tiles
var rush_meter: Control  # endless: the gold-rush gauge
# Gold already paid out this run.
var gold_awarded := 0
var xp_awarded := 0  # 이 판이 이미 지급한 계정 경험치 (중복 지급 방지)
var settings_panel: Control  # doubles as the pause menu (volume sliders)
var user_hud: CanvasLayer  # 타이틀과 같은 자리·같은 카드의 유저 정보 HUD
var piece_flyer: Control  # NEXT 카드 → 우물로 넘어오는 블록 조각 연출
var _flyer_armed := false  # 판을 열 때의 첫 블록은 예고된 적이 없다
## 계기판 뒤에 깔리는 흰 카드(들)를 그리는 레이어와, 카드가 감쌀 노드 묶음.
var hud_cards: Control
var hud_groups: Array = []


func _ready() -> void:
	_build_backdrop()
	EventBus.score_changed.connect(func(v: int) -> void: score_label.text = str(v))
	EventBus.level_changed.connect(func(v: int) -> void: level_label.text = str(v))
	EventBus.lines_changed.connect(func(v: int) -> void: lines_label.text = str(v))
	EventBus.height_changed.connect(_on_height_changed)
	EventBus.ore_collected.connect(_on_ore_collected)
	EventBus.next_piece_changed.connect(_on_next_piece)
	EventBus.game_started.connect(_on_game_started)
	EventBus.game_over.connect(_on_game_over)
	death_popup.restart_pressed.connect(_restart)
	death_popup.title_pressed.connect(_to_title)
	var endless := GameState.mode == GameState.MODE_ENDLESS
	var classic := GameState.mode == GameState.MODE_CLASSIC
	level_title.visible = not endless and not classic
	level_label.visible = not endless and not classic
	score_title.visible = true
	score_label.visible = true
	lines_title.visible = true
	lines_label.visible = true
	height_title.visible = true
	height_label.visible = true
	best_title.visible = true
	best_label.visible = true
	if classic:
		# Arcade cabinet HUD: LEVEL is the board you're on, TOP is the high score,
		# and LINES is a rack of tiles rather than a number.
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
	if endless:
		# 설명 문구는 두지 않는다 — 계기판만 남긴다 (스테이지 모드와 같은 규칙).
		goal_label.visible = false
		_build_rush_meter()
		EventBus.goldrush_changed.connect(_on_goldrush)
	height_label.pivot_offset = height_label.size / 2.0
	milestone_label.pivot_offset = milestone_label.size / 2.0
	if get_viewport_rect().size.y > get_viewport_rect().size.x:
		# Portrait: the endless camera keeps the pit behind the help-line slot,
		# and the touch buttons explain themselves — drop the text everywhere.
		help_label.visible = false
	_build_user_hud()
	piece_flyer = PIECE_FLYER.new()
	$PopupLayer.add_child(piece_flyer)
	$PopupLayer.move_child(piece_flyer, 0)  # 결과 팝업·설정 아래에 깔린다
	settings_panel = SETTINGS_PANEL.new()
	settings_panel.closed.connect(_on_settings_closed)
	$PopupLayer.add_child(settings_panel)
	Sfx.play_bgm("game")
	board.start_game()
	if not endless:  # endless is camera-driven; fixed pits get scaled to fit
		_fit_board()
	# 자리 → 톤앤매너 → 카드 순서. 모드별로 켜진 줄이 다 정해진 뒤라야 열을 쌓을 수
	# 있고, 열을 쌓은 뒤라야 계기판을 감싸는 카드의 자리를 알 수 있다.
	_layout_stat_column()
	_tone_hud()
	_build_hud_cards()


func _on_game_started() -> void:
	height = 0
	record_broken = false
	gold_awarded = 0
	xp_awarded = 0
	record_label.visible = false
	if record_tween:
		record_tween.kill()
	if GameState.mode == GameState.MODE_CLASSIC:
		best_label.text = tr("HUD_POINTS").format({"n": GameState.classic_best})
	else:
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
	# 흰 계기판 카드 위로 떠오르는 숫자 — 외곽선 없이 따뜻한 강조색으로.
	pop.add_theme_color_override("font_color", UiKit.ORANGE)
	# 큰 숫자 바로 옆에 붙인다 — 라벨 상자는 넉넉해서, 상자 끝에 붙이면 카드 밖으로 나간다.
	var num_w := ThemeDB.fallback_font.get_string_size(height_label.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1,
			height_label.get_theme_font_size("font_size")).x
	pop.position = height_label.position + Vector2(num_w + 14.0, 22.0)
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
	best_label.modulate = Color(1.2, 1.1, 0.9)  # 이미 금색 글자다 — 살짝 밝히기만
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
	else:
		stats = "STAGE %d      SCORE %d" % [board.level, GameState.score]
	# 보상은 지금 바로 세이브에 들어가지만, HUD 표시는 결과창의 연출이 맡는다 —
	# 골드가 날아가고 경험치 게이지가 찬 뒤에야 상단 카드가 새 값을 보여 준다.
	var gold_before := GameState.gold
	var xp_before := GameState.xp
	var got_gold := _award_run_rewards()
	var got_xp := _award_run_xp(was_record)
	GameState.save_game()  # 판 중에 미뤄 둔 골드 블록 몫까지 여기서 확정된다
	var earned: String = got_gold.get("line", "")
	var xp_line: String = got_xp.get("line", "")
	# 골드 단계가 세는 것은 **이 판이 번 골드**뿐이다 — 레벨업 보상 골드는
	# 경험치 단계에서 그 레벨에 닿는 순간 따로 얹힌다 (두 번 세지 않게).
	var reward := {
		"gold": int(got_gold.get("gold", 0)), "gold_from": gold_before,
		"xp": int(got_xp.get("xp", 0)), "xp_from": xp_before,
	}
	if user_hud:
		user_hud.hold(gold_before, xp_before)
	# 업적: 무한 첫 완주는 판이 끝난 그 순간에만 알 수 있고, 나머지(기록·골드)는
	# 위에서 갱신된 세이브 값으로 판정된다.
	if endless:
		Achv.unlock(Achv.FIRST_ESCAPE)
	Achv.check()
	# Let the death sink in for a beat before the popup slides up.
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_callback(func() -> void:
		if not board.playing:
			if user_hud:
				user_hud.visible = true  # 세로 화면은 여기서 처음 뜬다
			death_popup.open(stats, was_record, earned, "", xp_line, reward))


## NEXT 카드에 예고돼 있던 블록이 방금 우물로 들어왔다: 카드에서 조각 하나가
## 떨어져 나와 우물 위 그 자리로 날아간다. 신호가 오는 시점에는 새 블록의
## 자리(piece_pos)가 아직 안 정해져 있어서 한 프레임 미룬다.
func _on_next_piece(_next: String) -> void:
	if piece_flyer == null or not is_instance_valid(board):
		return
	var moved: String = board.piece_type
	if moved == "" or not _flyer_armed:
		_flyer_armed = true  # 판을 열 때의 첫 블록은 예고된 적이 없다
		return
	_launch_handoff.call_deferred(moved)


## 위 신호의 실제 연출 — NEXT 카드 한가운데에서 그 블록이 선 자리까지.
func _launch_handoff(type: String) -> void:
	if piece_flyer == null or not is_instance_valid(board) or not board.playing:
		return
	var card: Control = $UI/NextPreview
	if not card.visible:
		return
	piece_flyer.launch(type, card.get_global_rect().get_center(),
			board.get_global_transform_with_canvas() * board.piece_center())


## 골드 블록이 터졌다: 그 자리에서 코인 한 닢이 좌상단 지갑으로 빨려 들어가고
## 숫자가 오른다. 지갑은 이미 board._bank_ore()가 채워 뒀으니 여기는 연출만 맡는다.
## 세로 인게임은 플레이 중 HUD를 숨겨 두므로(터치 메뉴 자리) 보드 쪽 연출만 남는다.
func _on_ore_collected(amount: int, at: Vector2) -> void:
	if not is_instance_valid(user_hud) or not user_hud.visible:
		return
	var from: Vector2 = board.get_global_transform_with_canvas() * at
	user_hud.fly_coin(from, 0.0, 0.42, func() -> void:
		if is_instance_valid(user_hud):
			user_hud.pop_gain(amount)
			user_hud.refresh())


## 유저 정보 HUD — 타이틀과 같은 스크립트·같은 자리(좌상단).
## 세로 화면(모바일 인게임)은 좌상단이 터치 메뉴 버튼 자리라 **플레이 중에는 숨겨 두고**
## 판이 끝나 결과창이 뜰 때만 띄운다 (그때는 화면이 딤 처리돼 자리가 비고, 보상
## 연출의 코인이 날아갈 과녁이 필요하다). 가로 화면은 처음부터 늘 떠 있다.
func _build_user_hud() -> void:
	var vp := get_viewport_rect().size
	user_hud = USER_HUD.new()
	user_hud.visible = vp.x >= vp.y
	add_child(user_hud)
	death_popup.hud = user_hud  # 결과 화면의 보상 연출이 이 카드로 골드를 날린다


# --- 톤앤매너 (타이틀과 같은 UI 키트) -----------------------------------------


## 우물 바깥은 "구덩이 밖의 낮" — 타이틀과 같은 하늘색 배경 + 발바닥 무늬를 깐다.
## 우물 안(어두운 구덩이)은 escape_board가 계속 자기 배경을 그리므로 그대로다.
func _build_backdrop() -> void:
	var sky := CanvasLayer.new()
	sky.layer = -1  # 보드(기본 캔버스)보다 뒤
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = get_viewport_rect().size
	c.draw.connect(func() -> void: UiKit.paint_backdrop(c, c.size, 41))
	sky.add_child(c)
	add_child(sky)


## 계기판 글자를 타이틀 톤으로 — 흰 카드 위 잉크 글자다. 어두운 우물 위에 뜨는
## 배너(마일스톤/탈출/일시정지)만 잉크 외곽선을 두른 크림색으로 남긴다.
func _tone_hud() -> void:
	for l: Label in [$UI/NextTitle, score_title, level_title, lines_title,
			height_title, best_title]:
		l.add_theme_color_override("font_color", UiKit.MUTED)
		l.add_theme_font_size_override("font_size", 21)
	for l: Label in [score_label, level_label, lines_label]:
		_ink_label(l, UiKit.INK)
	# 큰 숫자 슬롯(무한=층, 스테이지=LEVEL)은 따뜻한 강조색.
	_ink_label(height_label, UiKit.ORANGE_DEEP)
	_ink_label(best_label, UiKit.GOLD_DEEP)
	_ink_label(record_label, UiKit.GOLD_DEEP)
	_ink_label(goal_label, UiKit.MUTED)
	_ink_label(help_label, Color(UiKit.INK, 0.72))
	help_label.add_theme_font_size_override("font_size", 19)
	# 화면 한가운데 배너는 우물(어두움) 위에도 뜨므로 잉크 외곽선을 유지한다.
	for l: Label in [milestone_label, pause_label]:
		l.add_theme_color_override("font_outline_color", UiKit.INK)
	milestone_label.add_theme_color_override("font_color", UiKit.CREAM)
	pause_label.add_theme_color_override("font_color", UiKit.CREAM)
	flash_rect.color = Color(UiKit.CREAM, flash_rect.color.a)


## 흰 카드 위에 얹는 글자: 어두운 배경용 외곽선을 걷고 잉크 계열 색으로.
func _ink_label(l: Label, col: Color) -> void:
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))


## 오른쪽 계기판 열: 보이는 줄만 위에서부터 차곡차곡 쌓는다. 모드마다 켜지는 줄이
## 다른데(무한=층 · 스테이지=LEVEL) 씬의 y를 그대로 쓰면 서로
## 겹치므로, 순서·글자 크기·간격을 여기서 한 번에 정해 두 모드를 같은 모양으로 만든다.
## 순서: NEXT → 큰 숫자 슬롯 → BEST/TOP → SCORE → (LEVEL) → LINES(+타일 랙) → 기록.
## 세로 화면(모바일)은 계기판이 화면 곳곳에 흩어져 있어 아직 씬(main_mobile.tscn)의
## offset이 정한다 — 여기로 합치는 건 밀린 모바일 대응 (CLAUDE.md ⛳ 목록).
func _layout_stat_column() -> void:
	var vp := get_viewport_rect().size
	if vp.y > vp.x:
		return
	var y := HUD_COL_TOP
	# NEXT는 제목 + 미리보기 판이라 따로 쌓는다.
	var next_title: Label = $UI/NextTitle
	var next_prev: Control = $UI/NextPreview
	next_title.position = Vector2(HUD_COL_X, y)
	next_title.size = Vector2(HUD_COL_W, HUD_CAPTION_H)
	y += HUD_CAPTION_H + HUD_CAPTION_GAP
	next_prev.position = Vector2(HUD_COL_X, y)
	y += next_prev.size.y + HUD_ROW_GAP
	for row: Array in [[height_title, height_label, 72],
			[best_title, best_label, 44],
			[score_title, score_label, 40],
			[level_title, level_label, 40],
			[lines_title, lines_label, 36]]:
		var cap: Label = row[0]
		var val: Label = row[1]
		if not val.visible:
			continue
		var fs: int = row[2]
		val.add_theme_font_size_override("font_size", fs)
		cap.position = Vector2(HUD_COL_X, y)
		cap.size = Vector2(HUD_COL_W, HUD_CAPTION_H)
		y += HUD_CAPTION_H + HUD_CAPTION_GAP
		val.position = Vector2(HUD_COL_X, y)
		val.size = Vector2(HUD_COL_W, ceilf(fs * 1.25))
		val.pivot_offset = val.size / 2.0
		y += val.size.y + HUD_ROW_GAP
		if val == height_label and rush_meter != null:
			# 골드러시 게이지는 큰 층수 바로 아래 — 이 판의 리듬을 읽는 줄이다.
			rush_meter.position = Vector2(HUD_COL_X, y - HUD_ROW_GAP + 8.0)
			rush_meter.size = Vector2(HUD_COL_W - 40.0, 50.0)
			y = rush_meter.position.y + rush_meter.size.y + HUD_ROW_GAP
		if val == lines_label and goal_meter != null:
			# 타일 랙은 LINES 숫자에 딸린 줄이라 바로 아래 붙인다.
			goal_meter.position = Vector2(HUD_COL_X, y - HUD_ROW_GAP + 10.0)
			goal_meter.size = Vector2(HUD_COL_W - 40.0, 106.0)
			goal_meter.per_row = 5
			y = goal_meter.position.y + goal_meter.size.y + HUD_ROW_GAP
	# 기록 갱신 줄은 판 도중에 켜진다 — 자리는 지금 잡아 둔다(카드가 자라지 않게).
	record_label.position = Vector2(HUD_COL_X, y)
	record_label.size = Vector2(HUD_COL_W, 36.0)
	y += 36.0 + HUD_ROW_GAP
	if goal_label.visible:
		goal_label.position = Vector2(HUD_COL_X, y)
		goal_label.size = Vector2(HUD_COL_W, 150.0)
		goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## 계기판 묶음마다 흰 카드를 한 장씩 깐다 (타이틀의 카드와 같은 스타일박스).
## 가로 화면은 오른쪽 열 하나가 통째로 한 장이고, 세로 화면은 계기판이 세 곳으로
## 흩어져 있어(왼쪽 NEXT · 위 큰 숫자 · 오른쪽 기록) 세 장으로 나눠 깐다.
func _build_hud_cards() -> void:
	var vp := get_viewport_rect().size
	hud_groups = []
	if vp.y > vp.x:
		_build_hud_cards_portrait()
	else:
		var col: Array = [$UI/NextTitle, $UI/NextPreview, score_title, score_label,
				level_title, level_label, lines_title, lines_label, height_title,
				height_label, best_title, best_label, goal_label, goal_meter,
				rush_meter]
		# 기록 갱신 줄은 판 도중에 켜진다 — 그때 카드가 자라지 않게 미리 넣어 둔다.
		hud_groups.append({"nodes": col, "w": HUD_COL_W, "always": [record_label]})
	if help_label.visible and help_label.text != "":
		hud_groups.append({"nodes": [help_label], "w": 0.0, "pill": true})
	hud_cards = Control.new()
	hud_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_cards.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_cards.draw.connect(_draw_hud_cards)
	$UI.add_child(hud_cards)
	$UI.move_child(hud_cards, 0)  # 계기판 뒤로


## 세로 화면 계기판은 자리마다 성격이 달라 카드도 세 장이다.
## (좌표는 mobile/ui/main_mobile.tscn의 오버라이드가 정한다 — 여기선 묶기만 한다.)
func _build_hud_cards_portrait() -> void:
	hud_groups.append({"nodes": [$UI/NextTitle, $UI/NextPreview], "w": 0.0})
	hud_groups.append({"nodes": [height_title, height_label], "w": 0.0})
	if rush_meter != null:
		# 골드러시 게이지는 NEXT 카드 아래 — 우물(x 220~860) 왼쪽 여백이라
		# 판을 가리지 않고, 엄지에서도 먼 자리다.
		hud_groups.append({"nodes": [rush_meter], "w": 0.0})
	# 오른쪽 열 — 우물(x 220~860) 바깥에 서므로 카드가 판을 가리지 않는다.
	# 기록 갱신 줄(★ NEW RECORD!)은 열보다 넓어 카드에 넣지 않고 그대로 띄운다.
	var right: Array = [best_title, best_label, score_title, score_label,
			level_title, level_label, lines_title, lines_label]
	if goal_meter != null:
		right.append(goal_meter)
	hud_groups.append({"nodes": right, "w": 0.0})


func _draw_hud_cards() -> void:
	var box := UiKit.panel_box(UiKit.WHITE, 26, 0.0)
	for g: Dictionary in hud_groups:
		var r := _group_rect(g)
		if r.size.x > 0.0:
			hud_cards.draw_style_box(box, r)


## 묶음이 차지하는 자리 + 여백. 열은 폭을 고정해(`w`) 짧은 숫자 하나 때문에
## 카드가 홀쭉해지거나, 넓은 라벨 하나 때문에 늘어나지 않게 한다.
func _group_rect(g: Dictionary) -> Rect2:
	var left := INF
	var top := INF
	var right := -INF
	var bottom := -INF
	var always: Array = g.get("always", [])
	for n: Control in (g["nodes"] as Array) + always:
		if n == null or not is_instance_valid(n):
			continue
		if not n.visible and not always.has(n):
			continue
		left = minf(left, n.position.x)
		top = minf(top, n.position.y)
		right = maxf(right, n.position.x + n.size.x)
		bottom = maxf(bottom, n.position.y + n.size.y)
	if left == INF:
		return Rect2()
	var w: float = g.get("w", 0.0)
	if w > 0.0:
		right = left + w
	var pad: Vector2 = HUD_CARD_PAD
	if g.get("pill", false):
		# 한 줄 안내는 글자 폭만큼만 감싼다 — 라벨 상자(화면 폭)를 다 덮지 않게.
		var l: Label = g["nodes"][0]
		var tw := ThemeDB.fallback_font.get_string_size(tr(l.text),
				HORIZONTAL_ALIGNMENT_LEFT, -1,
				l.get_theme_font_size("font_size")).x
		var cx := left + (right - left) / 2.0
		left = cx - tw / 2.0
		right = cx + tw / 2.0
		pad = Vector2(26.0, 8.0)
	return Rect2(left - pad.x, top - pad.y,
			right - left + pad.x * 2.0, bottom - top + pad.y * 2.0)


## Pays out gold for the whole run so far (minus what this run already paid).
## 돌려주는 것: {"gold": 이번에 준 골드, "daily": 오늘 첫 판 2배였나, "line": 표시 줄}
func _award_run_rewards() -> Dictionary:
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
		return {"gold": 0, "daily": false, "line": ""}
	# First rewarded run of the day pays double gold.
	var daily := GameState.claim_daily_bonus()
	if daily:
		earn_gold *= 2
	GameState.add_currency(earn_gold)
	var line := tr("HUD_EARNED").format({"gold": earn_gold})
	if daily:
		line = tr("HUD_DAILY_DOUBLE") + line
	return {"gold": earn_gold, "daily": daily, "line": line}


## 이 판의 계정 경험치를 지급한다 — 골드와 달리 소비할 수 없는 축이라
## 성적이 나빠도 참가비만큼은 들어온다. 오른 레벨이 있으면 그 줄까지 붙여 준다.
## 돌려주는 것: {"xp": 이번에 준 경험치, "levels": [오른 레벨...], "line": 표시 줄}
func _award_run_xp(record: bool) -> Dictionary:
	var run_xp := Account.run_xp(GameState.mode, GameState.score, height,
			board.level if is_instance_valid(board) else 0, record)
	var earn_xp := maxi(run_xp - xp_awarded, 0)
	xp_awarded = maxi(run_xp, xp_awarded)
	if earn_xp <= 0:
		return {"xp": 0, "levels": [], "line": ""}
	var got := Account.add_xp(earn_xp)
	var line := tr("HUD_XP_EARNED").format({"xp": earn_xp})
	var levels: Array = got.get("levels", [])
	if not levels.is_empty():
		# 축하 효과음은 결과창의 게이지가 그 레벨에 닿는 순간에 울린다.
		line += "\n" + tr("HUD_LEVEL_UP").format(
				{"level": int(levels[-1]), "gold": int(got.get("gold", 0))})
	return {"xp": earn_xp, "levels": levels, "line": line}

func _restart() -> void:
	death_popup.close()
	pause_label.visible = false
	settings_panel.visible = false  # bypass close(): start_game resets pause
	_flyer_armed = false
	milestone_label.visible = false
	board.start_game()


func _to_title() -> void:
	# 인게임에서 주운 골드 블록은 저장을 미뤄 뒀다 — 나가기 전에 한 번 쓴다.
	GameState.save_game()
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
	# 흔들림은 이 자리를 기준으로 보드 노드를 민다 (무한은 카메라가 대신 흔들린다).
	board.base_pos = board.position
	if portrait:
		# The tall well runs through the portrait help-line slot — drop it,
		# the touch buttons are self-explanatory.
		help_label.visible = false


# --- Classic level (arcade B-type) ----------------------------------------------


## 골드러시 게이지. 가로 화면의 자리는 `_layout_stat_column()`이 큰 층수 바로
## 아래로 잡고, 세로 화면만 여기서 따로 배치한다(NEXT 카드 아래 왼쪽 여백).
func _build_rush_meter() -> void:
	rush_meter = RUSH_METER.new()
	$UI.add_child(rush_meter)
	var vp := get_viewport_rect().size
	if vp.y > vp.x:
		rush_meter.position = Vector2(40.0, 292.0)
		rush_meter.size = Vector2(196.0, 50.0)


## 골드러시가 터진 순간에만 화면을 한 번 밝힌다 (게이지가 차는 동안은 조용히).
func _on_goldrush(_gauge: float, time_left: float) -> void:
	if time_left >= EscapeBoard.RUSH_TIME - 0.001:
		_screen_flash(0.28)


## LINES goal as a rack of tiles. 가로 화면의 자리·크기는 `_layout_stat_column()`이
## LINES 숫자 바로 아래로 잡고, 세로 화면만 여기서 따로 배치한다(좁은 오른쪽 열
## 대신 상단 가운데 한 줄).
func _build_goal_meter() -> void:
	var vp := get_viewport_rect().size
	goal_meter = GOAL_METER.new()
	$UI.add_child(goal_meter)
	if vp.y > vp.x:
		# Portrait: LEVEL rides top-center, LINES moves up into the empty LEVEL
		# slot, and the rack sits under it in the right column — 5씩 두 줄이면
		# 좁은 열에서도 읽힌다 (한 줄 10칸은 위쪽 큰 숫자와 겹친다).
		lines_title.position = Vector2(898.0, 440.0)
		lines_label.position = Vector2(898.0, 468.0)
		goal_meter.position = Vector2(898.0, 524.0)
		goal_meter.size = Vector2(158.0, 72.0)
		goal_meter.per_row = 5
		goal_meter.centered = true


## Test affordance: clears the current level (shutter and all) so the later
## boards can be reached without playing through. Keyboard equivalent: N.
func _build_skip_level_button() -> void:
	var vp := get_viewport_rect().size
	var btn := Button.new()
	btn.text = tr("HUD_NEXT_LEVEL_TEST")
	btn.tooltip_text = tr("HUD_NEXT_LEVEL_TEST_TIP")
	btn.focus_mode = Control.FOCUS_NONE
	UiKit.btn_ghost(btn, 20)
	btn.modulate.a = 0.85
	if vp.x > vp.y:
		# 좌상단은 유저 HUD 카드 자리 — 그 아래로 내려 앉힌다.
		btn.position = Vector2(40.0, 132.0)
		btn.size = Vector2(240.0, 48.0)
	else:
		# Portrait: down the left margin, clear of the NEXT panel and the well.
		UiKit.btn_ghost(btn, 20)
		btn.position = Vector2(16.0, 400.0)
		btn.size = Vector2(200.0, 64.0)
		btn.clip_text = true  # 번역이 길어도 판을 넘지 않게
	btn.pressed.connect(func() -> void:
		if board.classic_skip_level():
			Sfx.play("click"))
	$UI.add_child(btn)


## A new board was dealt. No banner — the shutter lifting is the announcement;
## the HUD just rolls over to the new level.
func _on_classic_level_started(level: int, quota: int, _garbage: int) -> void:
	# 도달 LEVEL은 판이 끝나면 사라지는 값이라 여기서 최고치를 남긴다 (LV5/LV10 업적).
	if level > GameState.classic_level_best:
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("to_title"):
		_to_title()
	elif event.is_action_pressed("restart"):
		_restart()
	elif event.is_action_pressed("pause") and board.playing:
		if board.is_paused:
			settings_panel.close()  # closed signal resumes the board
		else:
			board.is_paused = true
			Sfx.play("pause")
			settings_panel.open(false)


## The pause menu (settings panel) closed: resume play.
func _on_settings_closed() -> void:
	board.is_paused = false
	Sfx.play("pause")
