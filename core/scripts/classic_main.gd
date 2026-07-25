extends Node2D
## Classic mode: the arcade tetris, straight up — NES gravity curve and
## scoring, one-piece preview, no hold/ghost/hard drop. Clear lines, survive,
## and every 10 lines advances the stage (= arcade level). All UI is built in
## code off the viewport size, so the same scene serves landscape (PC/web)
## and portrait (mobile).

const CREAM := Color("f4e3c8")
const GOLD := Color(1.0, 0.85, 0.35)
const SETTINGS_PANEL := preload("res://core/scripts/settings_panel.gd")
const DEATH_POPUP := preload("res://core/scripts/death_popup.gd")
const BOARD_W := Board.COLS * Board.CELL  # 460
const BOARD_H := Board.ROWS * Board.CELL  # 920
const NEXT_W := 186.0  # next-slot column drawn by the board on its right

@onready var board: Board = $Board

var score_label: Label
var stage_label: Label
var lines_label: Label
var best_label: Label
var banner: Label
var flash_rect: ColorRect
var help_label: Label
var death_popup: Control
var settings_panel: Control
var record_broken := false
# Same delta-payout bookkeeping as main.gd: a continued run only earns more.
var gold_awarded := 0
var gems_awarded := 0
var revives_used := 0


func _ready() -> void:
	var vp := get_viewport_rect().size
	var portrait := vp.y > vp.x
	# Board block (field + NEXT column) centered; portrait leaves the top for
	# the HUD row and the bottom for the touch zone.
	var bx := (vp.x - BOARD_W - NEXT_W) / 2.0
	var by := 300.0 if portrait else (vp.y - BOARD_H) / 2.0
	if portrait:
		var s := minf(1.0, (vp.y - 300.0 - 480.0) / BOARD_H)  # fit above touch zone
		board.scale = Vector2(s, s)
		by = 300.0
	board.position = Vector2(bx, by)
	board.classic = true
	_build_ui(vp, portrait)
	if _touch():
		_build_touch(vp, portrait)
	EventBus.score_changed.connect(func(v: int) -> void: score_label.text = str(v))
	EventBus.lines_changed.connect(func(v: int) -> void: lines_label.text = str(v))
	EventBus.level_changed.connect(_on_stage_changed)
	EventBus.game_started.connect(_on_game_started)
	EventBus.game_over.connect(_on_game_over)
	settings_panel = SETTINGS_PANEL.new()
	settings_panel.closed.connect(func() -> void:
		board.is_paused = false
		Sfx.play("pause"))
	$PopupLayer.add_child(settings_panel)
	death_popup = DEATH_POPUP.new()
	death_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	$PopupLayer.add_child(death_popup)
	death_popup.continue_pressed.connect(_on_revive)
	death_popup.restart_pressed.connect(_restart)
	death_popup.title_pressed.connect(_to_title)
	Sfx.play_bgm("game")
	board.start_game()


# --- UI -------------------------------------------------------------------------


func _build_ui(vp: Vector2, portrait: bool) -> void:
	if portrait:
		# HUD row across the top, above the (possibly scaled) board.
		var w := vp.x / 4.0
		score_label = _hud_block(0.0 * w, w, "SCORE")
		stage_label = _hud_block(1.0 * w, w, "STAGE")
		lines_label = _hud_block(2.0 * w, w, "LINES")
		best_label = _hud_block(3.0 * w, w, "BEST")
	else:
		# Label column to the left of the field, arcade-cabinet style.
		var x := board.position.x - 300.0
		score_label = _side_block(x, 120.0, "SCORE")
		stage_label = _side_block(x, 280.0, "STAGE")
		lines_label = _side_block(x, 440.0, "LINES")
		best_label = _side_block(x, 600.0, "BEST")
	banner = Label.new()
	banner.position = Vector2(0.0, vp.y * 0.38)
	banner.size = Vector2(vp.x, 120.0)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 72)
	banner.add_theme_color_override("font_color", CREAM)
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	banner.add_theme_constant_override("outline_size", 12)
	banner.visible = false
	$UI.add_child(banner)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1, 1, 0.9, 0.0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.visible = false
	$UI.add_child(flash_rect)
	help_label = Label.new()
	help_label.position = Vector2(0.0, vp.y - 44.0)
	help_label.size = Vector2(vp.x, 30.0)
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_label.add_theme_font_size_override("font_size", 18)
	help_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	help_label.text = "< > 이동    v 소프트 드랍    Z / X 회전    P 일시정지    R 재시작    ESC 타이틀"
	help_label.visible = not _touch()
	$UI.add_child(help_label)


func _hud_block(x: float, w: float, title: String) -> Label:
	_mk_label(x, 90.0, w, title, 22, Color(1, 1, 1, 0.55))
	return _mk_label(x, 130.0, w, "0", 44, Color.WHITE)


func _side_block(x: float, y: float, title: String) -> Label:
	_mk_label(x, y, 240.0, title, 26, Color(1, 1, 1, 0.55))
	return _mk_label(x, y + 40.0, 240.0, "0", 52, Color.WHITE)


func _mk_label(x: float, y: float, w: float, text: String, font_size: int,
		col: Color) -> Label:
	var l := Label.new()
	l.position = Vector2(x, y)
	l.size = Vector2(w, font_size + 16.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	$UI.add_child(l)
	return l


func _touch() -> bool:
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()


## On-screen controls: move pair + rotate pair, soft drop bar underneath.
## (Guard lives in _ready so visual_capture can force-build these on desktop.)
func _build_touch(vp: Vector2, portrait: bool) -> void:
	var layer: CanvasLayer = $TouchLayer
	if portrait:
		_touch_btn(layer, "move_left", "◀", Rect2(30, 1480, 240, 170))
		_touch_btn(layer, "move_right", "▶", Rect2(290, 1480, 240, 170))
		_touch_btn(layer, "rotate_ccw", "⟲", Rect2(550, 1480, 240, 170))
		_touch_btn(layer, "rotate_cw", "⟳", Rect2(810, 1480, 240, 170))
		_touch_btn(layer, "soft_drop", "▼", Rect2(290, 1670, 500, 150))
		_touch_btn(layer, "pause", "≡", Rect2(vp.x - 170, 20, 150, 90), 36)
	else:
		_touch_btn(layer, "move_left", "◀", Rect2(40, 860, 220, 150))
		_touch_btn(layer, "move_right", "▶", Rect2(280, 860, 220, 150))
		_touch_btn(layer, "soft_drop", "▼", Rect2(1540, 690, 220, 150))
		_touch_btn(layer, "rotate_ccw", "⟲", Rect2(1420, 860, 220, 150))
		_touch_btn(layer, "rotate_cw", "⟳", Rect2(1660, 860, 220, 150))
		_touch_btn(layer, "pause", "≡", Rect2(vp.x - 170, 20, 150, 90), 36)


func _touch_btn(layer: CanvasLayer, action: String, label: String, r: Rect2,
		font_size := 48) -> void:
	var b := TouchButton.new()
	b.action = action
	b.label = label
	b.font_size = font_size
	b.position = r.position
	b.size = r.size
	layer.add_child(b)


# --- Flow -----------------------------------------------------------------------


func _on_game_started() -> void:
	record_broken = false
	gold_awarded = 0
	gems_awarded = 0
	revives_used = 0
	stage_label.text = "1"
	best_label.text = str(GameState.classic_best)
	best_label.modulate = Color.WHITE


## Level == stage in classic: slam a banner and flash on every speed-up.
func _on_stage_changed(new_level: int) -> void:
	stage_label.text = str(new_level)
	if new_level <= 1:
		return
	Sfx.play("milestone")
	banner.text = "STAGE %d" % new_level
	if new_level >= 30:
		banner.text = "STAGE %d — 킬 스크린!!" % new_level
	elif new_level >= 20:
		banner.text = "STAGE %d — 최고 속도!" % new_level
	banner.visible = true
	banner.modulate = Color(1, 1, 1, 0)
	banner.scale = Vector2(1.8, 1.8)
	banner.pivot_offset = banner.size / 2.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(banner, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner, "modulate:a", 1.0, 0.12)
	tw.chain().tween_interval(0.7)
	tw.chain().tween_property(banner, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(func() -> void: banner.visible = false)
	flash_rect.visible = true
	flash_rect.color.a = 0.16
	var ft := create_tween()
	ft.tween_property(flash_rect, "color:a", 0.0, 0.45)
	ft.tween_callback(func() -> void: flash_rect.visible = false)


func _on_game_over() -> void:
	var was_record := GameState.record_classic(GameState.score)
	if was_record:
		record_broken = true
		best_label.text = str(GameState.score)
		best_label.modulate = GOLD
	var stats := "SCORE %d      STAGE %d      LINES %d" \
			% [GameState.score, board.level, board.total_lines]
	var earned := _award_run_rewards(was_record)
	var cost := 0 if revives_used == 0 else revives_used + 1
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_callback(func() -> void:
		if not board.playing:
			death_popup.open(stats, was_record, earned, cost))


## Classic payout: arcade scores run big, so gold is score/200 and gems come
## from stage depth (every 5 stages, capped) plus the usual record bonus.
func _award_run_rewards(was_record: bool) -> String:
	var run_gold := GameState.score / 200
	var run_gems := mini((board.level - 1) / 5, 3)
	if was_record and run_gold > 0:
		run_gems += 1
	var earn_gold := maxi(run_gold - gold_awarded, 0)
	var earn_gems := maxi(run_gems - gems_awarded, 0)
	gold_awarded = maxi(run_gold, gold_awarded)
	gems_awarded = maxi(run_gems, gems_awarded)
	if earn_gold <= 0 and earn_gems <= 0:
		return ""
	var daily := earn_gold > 0 and GameState.claim_daily_bonus()
	if daily:
		earn_gold *= 2
	GameState.add_currency(earn_gold, earn_gems)
	var line := "획득   +%d G" % earn_gold
	if earn_gems > 0:
		line += "   +%d ◆" % earn_gems
	if daily:
		line = "오늘 첫 판 2배!   " + line
	return line


## Arcade continue: pay the jelly, wipe the field, keep score/stage/lines.
func _on_revive() -> void:
	var cost := 0 if revives_used == 0 else revives_used + 1
	if cost > 0 and not GameState.spend_gems(cost):
		Sfx.play("error")
		return
	revives_used += 1
	death_popup.close()
	board.continue_run()
	Sfx.play("revive")


func _restart() -> void:
	death_popup.close()
	settings_panel.visible = false
	board.start_game()


func _to_title() -> void:
	get_tree().change_scene_to_file("res://core/scenes/boot.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("to_title"):
		_to_title()
	elif event.is_action_pressed("restart"):
		_restart()
	elif event.is_action_pressed("pause") and board.playing:
		if board.is_paused:
			settings_panel.close()  # closed signal resumes
		else:
			board.is_paused = true
			Sfx.play("pause")
			settings_panel.open("일시정지", "계속하기")
