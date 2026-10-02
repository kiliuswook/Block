extends Control
## 결과창 (피그마 "팝업_엔딩"): 제목 · 유령 냥이 그림 · 통계 판(SCORE/LEVEL/LINES) ·
## 코인 줄 · 경험치 게이지 · [타이틀로][다시 도전]. 전부 코드로 짓는다.
##
## 보상 연출: 판이 끝나면 보상은 이미 세이브에 들어가 있지만, 화면은 그것을
## **두 단계로 나누어** 보여 준다 — ① 골드 코인이 결과창에서 상단 유저 HUD의
## 골드로 날아가 숫자가 올라가고 ② 그다음 결과창의 경험치 게이지가 차오르며
## 레벨업이 뜬다. 레벨이 올랐으면 정산 끝에 **레벨업 팝업**(피그마 "팝업_레벨업")이
## 결과창 위로 한 번 더 뜬다. 그동안 HUD는 `hold()`로 옛 값에 붙들어 두고, 끝나면
## `release()`. 화면을 누르면 그 단계가 즉시 끝나고 다음으로 넘어간다.

signal restart_pressed
signal title_pressed

const UiKit := preload("res://core/scripts/ui_kit.gd")

const GOLD := UiKit.GOLD_DEEP
const INK := UiKit.INK
const XP_COL := UiKit.GAUGE

## 연출 타이밍 (초).
const OPEN_HOLD := 0.45
const COIN_STEP := 0.09
const COIN_FLY := 0.5
const COIN_MAX := 8
const PHASE_GAP := 0.4
const XP_FILL := 1.1

var hud: CanvasLayer  # 상단 유저 HUD (main이 물려 준다 — 없으면 게이지만 돈다)

var _panel: PanelContainer
var _title: Label
var _record_label: Label
var _stats_label: Label  # 문자열 통계 (열 통계가 없을 때)
var _stats_box: Control  # 통계 판 (열 통계)
var _stat_cols: Array = []  # [[제목, 값], ...]
var _reward_label: Label  # 예전 API 호환 — 보이지 않고 코인 줄이 대신한다
var _coin_row: Control  # "코인 +100 [coin]"
var _xp_gauge: Control
var _xp_label: Label
## 레벨업 팝업.
var _lvup: Control
var _lvup_face: Control
var _lvup_level := 0
var _lvup_gold := 0

var _phase := ""  # "" | "gold" | "xp" | "done"
var _seq: Tween
var _gold_from := 0
var _gold_to := 0
var _xp_from := 0
var _xp_to := 0
var _xp_val := 0.0
var _lv_shown := 1
var _xp_line := ""
var _levelups := 0
var _earned_gold := 0


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)

	var dim := ColorRect.new()
	dim.color = UiKit.DIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.custom_minimum_size = Vector2(850.0, 0.0)
	var box := UiKit.card_box(UiKit.WHITE, 28)
	box.content_margin_left = 40.0
	box.content_margin_right = 40.0
	box.content_margin_top = 44.0
	box.content_margin_bottom = 30.0
	_panel.add_theme_stylebox_override("panel", box)
	center.add_child(_panel)

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	_panel.add_child(v)

	_title = Label.new()
	_title.text = tr("POP_DEAD_TITLE")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.label(_title, 44, UiKit.BROWN, true)
	v.add_child(_title)

	# 쓰러진 큐브 냥이 유령 (피그마 그림).
	var ghost := Control.new()
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.custom_minimum_size = Vector2(240.0, 240.0)
	ghost.draw.connect(func() -> void:
		var t := UiKit.tex("ghost_cat.png")
		if t != null:
			UiKit.draw_tex(ghost, "ghost_cat.png", Rect2(Vector2.ZERO, ghost.size))
		else:
			ghost.draw_set_transform(ghost.size / 2.0, 0.42, Vector2.ONE)
			Player.paint_cat(ghost, Vector2.ZERO, 90.0, 0.0, false)
			ghost.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE))
	v.add_child(ghost)

	_record_label = Label.new()
	_record_label.text = tr("POP_NEW_RECORD")
	_record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.label(_record_label, 26, GOLD, true)
	_record_label.visible = false
	v.add_child(_record_label)

	_stats_box = Control.new()
	_stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_box.custom_minimum_size = Vector2(600.0, 110.0)
	_stats_box.draw.connect(_draw_stats)
	v.add_child(_stats_box)

	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.label(_stats_label, 24, UiKit.MUTED)
	_stats_label.visible = false
	v.add_child(_stats_label)

	_reward_label = Label.new()
	_reward_label.visible = false
	v.add_child(_reward_label)

	_coin_row = Control.new()
	_coin_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin_row.custom_minimum_size = Vector2(300.0, 40.0)
	_coin_row.draw.connect(_draw_coin_row)
	_coin_row.visible = false
	v.add_child(_coin_row)

	_xp_gauge = Control.new()
	_xp_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_gauge.custom_minimum_size = Vector2(560.0, 30.0)
	_xp_gauge.draw.connect(_draw_xp_gauge)
	_xp_gauge.visible = false
	v.add_child(_xp_gauge)

	_xp_label = Label.new()
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.label(_xp_label, 20, UiKit.TEXT)
	_xp_label.visible = false
	v.add_child(_xp_label)

	v.add_child(_spacer(6.0))

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 16)
	v.add_child(btns)
	var to_title := _make_button(tr("POP_TO_TITLE"), false)
	to_title.pressed.connect(func() -> void:
		_finish_all()
		title_pressed.emit())
	btns.add_child(to_title)
	var restart := _make_button(tr("POP_RETRY"), true)
	restart.pressed.connect(func() -> void:
		_finish_all()
		restart_pressed.emit())
	btns.add_child(restart)
	_build_levelup()


## stats: 한 줄 통계 (stat_cols가 비었을 때만 보인다).
## stat_cols: [[제목, 값], ...] — 통계 판 세 열.
## reward: {"gold", "gold_from", "xp", "xp_from"} — 비어 있으면 연출 없이 줄만.
func open(stats: String, new_record: bool, earned := "", title_text := "",
		xp_line := "", reward := {}, stat_cols: Array = []) -> void:
	_title.text = title_text if title_text != "" else tr("POP_DEAD_TITLE")
	_stat_cols = stat_cols
	_stats_box.visible = not stat_cols.is_empty()
	_stats_box.queue_redraw()
	_stats_label.text = stats
	_stats_label.visible = stat_cols.is_empty() and stats != ""
	_record_label.visible = new_record
	_reward_label.text = earned
	_earned_gold = int(reward.get("gold", 0))
	_xp_line = xp_line
	_xp_label.text = xp_line
	_lvup.visible = false
	_setup_reward(earned, xp_line, reward)
	visible = true
	_panel.modulate.a = 0.0
	await get_tree().process_frame
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.7, 0.7)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.15)
	if _phase == "gold":
		_seq = create_tween()
		_seq.tween_interval(OPEN_HOLD)
		_seq.tween_callback(_run_gold)


func close() -> void:
	_kill_seq()
	_phase = ""
	if hud:
		hud.release()
	_lvup.visible = false
	visible = false


# --- 보상 연출 ---------------------------------------------------------------


func _setup_reward(earned: String, xp_line: String, reward: Dictionary) -> void:
	_kill_seq()
	_levelups = 0
	var gold: int = int(reward.get("gold", 0))
	var xp: int = int(reward.get("xp", 0))
	if reward.is_empty() or (gold <= 0 and xp <= 0):
		_phase = "done"
		_coin_row.visible = earned != "" or gold > 0
		_coin_row.queue_redraw()
		_xp_label.visible = xp_line != ""
		_xp_gauge.visible = xp_line != ""
		_xp_val = float(GameState.xp)
		_xp_gauge.queue_redraw()
		if hud:
			hud.release()
		return
	_gold_from = int(reward.get("gold_from", GameState.gold))
	_gold_to = _gold_from + gold
	_xp_from = int(reward.get("xp_from", GameState.xp))
	_xp_to = _xp_from + xp
	_xp_val = float(_xp_from)
	_lv_shown = Account.level_at(_xp_from)
	_coin_row.visible = false
	_xp_label.visible = false
	_xp_gauge.visible = true
	_xp_gauge.queue_redraw()
	if hud:
		hud.hold(_gold_from, _xp_from)
	_phase = "gold"


## ① 골드: 코인이 결과창에서 지갑으로 날아가고, 숫자가 따라 올라간다.
func _run_gold() -> void:
	if _phase != "gold":
		return
	if _gold_to <= _gold_from or hud == null:
		_run_xp()
		return
	_coin_row.visible = true
	_coin_row.queue_redraw()
	var total := _gold_to - _gold_from
	var coins := clampi(total / 12 + 3, 3, COIN_MAX)
	var from := _coin_origin()
	Sfx.play("gold")
	for i in coins:
		var idx := i
		var jitter := Vector2(randf_range(-70.0, 70.0), randf_range(-24.0, 24.0))
		hud.fly_coin(from + jitter, idx * COIN_STEP, COIN_FLY,
				func() -> void: _on_coin_land(idx + 1, coins, total))
	_seq = create_tween()
	_seq.tween_interval(coins * COIN_STEP + COIN_FLY + PHASE_GAP)
	_seq.tween_callback(_run_xp)


func _on_coin_land(nth: int, coins: int, total: int) -> void:
	if _phase != "gold" or hud == null:
		return
	if nth == 1:
		hud.pop_gain(total)
	Sfx.play("gold", 1.0 + 0.05 * nth)
	hud.set_gold_shown(_gold_from + int(round(float(total) * nth / coins)))


## ② 경험치: 결과창 게이지가 차오르고, 레벨이 오르면 정산 끝에 레벨업 팝업.
func _run_xp() -> void:
	if _phase == "done":
		return
	_phase = "xp"
	if hud:
		hud.set_gold_shown(_gold_to)
	_coin_row.visible = _gold_to > _gold_from or _reward_label.text != ""
	_xp_label.text = tr("HUD_XP_EARNED").format({"xp": _xp_to - _xp_from})
	_xp_label.visible = _xp_to > _xp_from
	if _xp_to <= _xp_from:
		_finish()
		return
	_seq = create_tween()
	_seq.tween_method(_set_xp_val, float(_xp_from), float(_xp_to), XP_FILL) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_seq.tween_interval(PHASE_GAP)
	_seq.tween_callback(_finish)


func _set_xp_val(v: float) -> void:
	_xp_val = v
	var lv := Account.level_at(int(v))
	while _lv_shown < lv:
		_lv_shown += 1
		_level_up(_lv_shown)
	if is_instance_valid(_xp_gauge):
		_xp_gauge.queue_redraw()


## 레벨업 — 보상 골드가 지갑으로 얹힌다 (이미 지급된 값의 표시분).
func _level_up(lv: int) -> void:
	_levelups += 1
	_lvup_level = lv
	_lvup_gold += Account.level_reward(lv)
	Sfx.play("record")
	var reward := Account.level_reward(lv)
	if hud:
		hud.set_gold_shown(hud.gold_shown() + reward)
		hud.pop_gain(reward)
	var tw := create_tween()
	tw.tween_property(_xp_gauge, "modulate", Color(1.4, 1.4, 1.4), 0.1)
	tw.tween_property(_xp_gauge, "modulate", Color.WHITE, 0.25)


## 정산 끝 — 결과 줄을 최종본으로 맞추고 HUD를 실제 값으로 놓아 준다.
## 레벨이 올랐으면 레벨업 팝업을 결과창 위에 띄운다.
func _finish() -> void:
	_kill_seq()
	_phase = "done"
	_xp_val = float(_xp_to)
	if is_instance_valid(_xp_gauge):
		_xp_gauge.queue_redraw()
	_xp_label.text = tr("HUD_XP_EARNED").format({"xp": _xp_to - _xp_from}) \
			if _xp_to > _xp_from else _xp_line
	_xp_label.visible = _xp_label.text != ""
	_coin_row.visible = _gold_to > _gold_from or _reward_label.text != ""
	if hud:
		hud.release()
	if _levelups > 0:
		_open_levelup()


func _on_gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		skip()


func skip() -> void:
	if _phase == "gold":
		_kill_seq()
		if hud:
			hud.set_gold_shown(_gold_to)
			hud.pop_gain(_gold_to - _gold_from)
		_run_xp()
	elif _phase == "xp":
		_kill_seq()
		_set_xp_val(float(_xp_to))
		_finish()


func _finish_all() -> void:
	if _phase == "gold" or _phase == "xp":
		_kill_seq()
		_set_xp_val(float(_xp_to))
		_levelups = 0  # 버튼으로 나가면 레벨업 팝업은 건너뛴다
		_finish()
	_lvup.visible = false


func _kill_seq() -> void:
	if _seq != null and _seq.is_valid():
		_seq.kill()
	_seq = null


func _coin_origin() -> Vector2:
	if is_instance_valid(_coin_row) and _coin_row.visible:
		return _coin_row.get_global_rect().get_center()
	return _panel.get_global_rect().get_center()


# --- 그리기 --------------------------------------------------------------------


## 통계 판 — 회색 판에 세 열(제목 16 · 값 32), 사이 세로선.
func _draw_stats() -> void:
	var ci := _stats_box
	var w := ci.size.x
	var h := ci.size.y
	UiKit.round_rect(ci, Rect2(Vector2.ZERO, ci.size), Color("f5f5f5"), 16)
	var n := _stat_cols.size()
	if n == 0:
		return
	var cw := w / n
	for i in n:
		var col: Array = _stat_cols[i]
		var cx := cw * (i + 0.5)
		UiKit.text(ci, str(col[0]), Vector2(cx, 34.0), 16, UiKit.TEXT, true, 1, cw - 16.0)
		UiKit.text(ci, str(col[1]), Vector2(cx, 84.0), 32, UiKit.TEXT, true, 1, cw - 16.0)
		if i > 0:
			ci.draw_line(Vector2(cw * i, 20.0), Vector2(cw * i, h - 20.0), UiKit.PANEL_LINE,
					2.0)


## "코인 +100 [coin]".
func _draw_coin_row() -> void:
	var ci := _coin_row
	var amount := _gold_to - _gold_from if _phase != "done" or _gold_to > _gold_from \
			else _earned_gold
	if amount <= 0 and _reward_label.text != "":
		UiKit.text(ci, _reward_label.text, Vector2(ci.size.x / 2.0, 28.0), 22, GOLD, true, 1)
		return
	var label := tr("POP_COIN")
	var num := "+%s" % UiKit.commas(amount)
	var lw := UiKit.text_width(label, 22, false)
	var nw := UiKit.text_width(num, 26, true)
	var total := lw + 8.0 + nw + 10.0 + 30.0
	var x := (ci.size.x - total) / 2.0
	UiKit.text(ci, label, Vector2(x, 28.0), 22, UiKit.TEXT)
	UiKit.text(ci, num, Vector2(x + lw + 8.0, 29.0), 26, UiKit.TEXT, true)
	UiKit.coin_icon(ci, Vector2(x + lw + 8.0 + nw + 10.0 + 15.0, 20.0), 30.0)


## 경험치 게이지: Lv.N [파란 바] 64 / 120 XP
func _draw_xp_gauge() -> void:
	var ci := _xp_gauge
	var total := int(_xp_val)
	var lv := Account.level_at(total)
	var w: float = ci.size.x
	var lv_text := tr("MENU_LEVEL").format({"level": lv})
	var lv_w := UiKit.text(ci, lv_text, Vector2(0.0, 22.0), 18, UiKit.TEXT, true)
	var need := Account.xp_to_next_at(total)
	var count_w := 0.0
	if need <= 0:
		count_w = UiKit.text(ci, tr("MENU_LEVEL_MAX"), Vector2(w, 22.0), 18, UiKit.TEXT,
				true, 2)
	else:
		var rest := " / %d XP" % need
		var rw := UiKit.text(ci, rest, Vector2(w, 22.0), 18, UiKit.TEXT, false, 2)
		var cw := UiKit.text(ci, str(Account.xp_in_level_at(total)), Vector2(w - rw, 22.0),
				18, UiKit.TEXT, true, 2)
		count_w = rw + cw
	var bar := Rect2(lv_w + 12.0, 6.0, w - lv_w - 12.0 - count_w - 12.0, 16.0)
	UiKit.round_rect(ci, bar, Color("ededed"), 8)
	var fill := bar
	fill.size.x = maxf(8.0, bar.size.x * Account.progress_at(total))
	UiKit.round_rect(ci, fill, XP_COL, 8)


# --- 레벨업 팝업 (피그마 "팝업_레벨업") --------------------------------------------------


func _build_levelup() -> void:
	_lvup = Control.new()
	_lvup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lvup.visible = false
	_lvup.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_lvup)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lvup.add_child(dim)
	_lvup_face = Control.new()
	_lvup_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lvup_face.draw.connect(_draw_levelup)
	_lvup.add_child(_lvup_face)
	var ok := Button.new()
	ok.text = tr("UI_CONFIRM")
	ok.size = Vector2(400.0, 68.0)
	UiKit.btn_card(ok, UiKit.GRAY_DEEP, 26)
	ok.pressed.connect(func() -> void:
		Sfx.play("click")
		_lvup.visible = false)
	_lvup_face.add_child(ok)
	_lvup.set_meta("ok", ok)


func _open_levelup() -> void:
	var vp := get_viewport_rect().size
	var card := Vector2(850.0, 770.0)
	_lvup_face.position = ((vp - card) / 2.0).floor()
	_lvup_face.size = card
	var ok: Button = _lvup.get_meta("ok")
	ok.position = Vector2((card.x - ok.size.x) / 2.0, card.y - 30.0 - ok.size.y)
	_lvup.visible = true
	_lvup_face.queue_redraw()
	Sfx.play("record")


func _draw_levelup() -> void:
	var ci := _lvup_face
	var w := ci.size.x
	UiKit.round_rect(ci, Rect2(Vector2.ZERO, ci.size), UiKit.WHITE, 28)
	UiKit.text(ci, tr("POP_LEVEL_UP"), Vector2(w / 2.0, 90.0), 44, UiKit.BROWN, true, 1)
	# 별 + LEVEL N.
	var star := Rect2(w / 2.0 - 100.0, 120.0, 200.0, 190.0)
	UiKit.draw_tex(ci, "star_big.png", star)
	UiKit.text(ci, tr("HUD_LEVEL_CAPTION"), Vector2(w / 2.0, 212.0), 14, Color("b8860b"),
			false, 1)
	UiKit.text(ci, "%02d" % _lvup_level, Vector2(w / 2.0, 250.0), 36, UiKit.WHITE, true, 1)
	# 보상 칩 — 골드.
	var chip := Rect2(w / 2.0 - 110.0, 340.0, 220.0, 200.0)
	UiKit.round_rect_outline(ci, chip, Color("f5f5f5"), 14, 2, UiKit.PANEL_LINE)
	UiKit.text(ci, tr("POP_REWARD_GOLD"), Vector2(chip.get_center().x, chip.position.y + 30.0),
			14, UiKit.TEXT, true, 1)
	UiKit.coin_icon(ci, chip.get_center() + Vector2(0.0, 6.0), 90.0)
	UiKit.text(ci, "+%s" % UiKit.commas(_lvup_gold), Vector2(chip.get_center().x,
			chip.end.y - 24.0), 26, UiKit.TEXT, true, 1)
	# 게이지.
	var total := _xp_to
	var lv := Account.level_at(total)
	var bar := Rect2(w / 2.0 - 220.0, 590.0, 440.0, 16.0)
	var lv_text := tr("MENU_LEVEL").format({"level": lv})
	UiKit.text(ci, lv_text, Vector2(bar.position.x - 12.0, bar.position.y + 14.0), 18,
			UiKit.TEXT, true, 2)
	UiKit.round_rect(ci, bar, Color("ededed"), 8)
	var fill := bar
	fill.size.x = maxf(8.0, bar.size.x * Account.progress_at(total))
	UiKit.round_rect(ci, fill, XP_COL, 8)
	var need := Account.xp_to_next_at(total)
	var count := tr("MENU_LEVEL_MAX") if need <= 0 \
			else "%d / %d XP" % [Account.xp_in_level_at(total), need]
	UiKit.text(ci, count, Vector2(bar.end.x + 12.0, bar.position.y + 14.0), 18, UiKit.TEXT)


func _spacer(h: float) -> Control:
	var s := Control.new()
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.custom_minimum_size = Vector2(0.0, h)
	return s


func _make_button(label: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = label
	b.pressed.connect(func() -> void: Sfx.play("click"))
	b.custom_minimum_size = Vector2(380.0, 70.0)
	if primary:
		UiKit.btn_primary(b, 28)
	else:
		UiKit.btn_card(b, UiKit.GRAY_DEEP, 28)
	return b
