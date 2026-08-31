extends Control
## Death popup: dead cat portrait, run stats and two choices —
## restart from scratch, or back to the title.
## The whole UI is built in code, matching the project's draw-in-code style.
##
## 보상 연출: 판이 끝나면 보상은 이미 세이브에 들어가 있지만, 화면은 그것을
## **두 단계로 나누어** 보여 준다 — ① 골드 코인이 결과창에서 좌상단 유저 HUD의
## 골드로 날아가 숫자가 올라가고 ② 그다음 결과창의 경험치 게이지가 차오르며
## 레벨업이 뜬다. 그동안 HUD는 `hold()`로 옛 값에 붙들어 두고, 끝나면 `release()`.
## 화면을 누르면 그 단계가 즉시 끝나고 다음으로 넘어간다(버튼은 전부 건너뛴다).

signal restart_pressed
signal title_pressed

const UiKit := preload("res://core/scripts/ui_kit.gd")

const GOLD := UiKit.GOLD_DEEP
const INK := UiKit.INK
const XP_COL := UiKit.CYAN_DEEP  # 계정 경험치 (골드와 구분되는 하늘색)

## 연출 타이밍 (초).
const OPEN_HOLD := 0.45  # 창이 뜨고 골드가 날아가기까지
const COIN_STEP := 0.09  # 코인 사이 간격
const COIN_FLY := 0.5
const COIN_MAX := 8
const PHASE_GAP := 0.4  # 단계 사이 숨 고르기
const XP_FILL := 1.1  # 경험치 게이지가 차는 시간

var hud: CanvasLayer  # 좌상단 유저 HUD (main이 물려 준다 — 없으면 게이지만 돈다)

var _panel: PanelContainer
var _title: Label
var _record_label: Label
var _stats_label: Label
var _reward_label: Label
var _xp_gauge: Control  # 결과창 경험치 게이지 (Lv · 바 · 진행 숫자)
var _xp_label: Label  # 계정 경험치 + 레벨업 줄

var _phase := ""  # "" | "gold" | "xp" | "done"
var _seq: Tween
var _gold_from := 0
var _gold_to := 0
var _xp_from := 0
var _xp_to := 0
var _xp_val := 0.0  # 게이지가 지금 보여 주는 누적 경험치
var _lv_shown := 1
var _xp_line := ""  # 연출이 끝났을 때 남을 경험치 줄
var _levelups := 0


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)

	var dim := ColorRect.new()
	dim.color = Color(0.09, 0.13, 0.18, 0.55)  # 타이틀 오버레이와 같은 딤
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 클릭은 스킵 처리로 넘긴다
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	# 카드 위를 눌러도 연출 스킵이 먹도록 이벤트를 통과시킨다 (버튼만 STOP).
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	# 타이틀 카드와 같은 흰 패널 (두꺼운 잉크 외곽선 + 둥근 모서리).
	var box := UiKit.panel_box(UiKit.WHITE, 28, 0.0)
	box.content_margin_left = 64.0
	box.content_margin_right = 64.0
	box.content_margin_top = 36.0
	box.content_margin_bottom = 44.0
	_panel.add_theme_stylebox_override("panel", box)
	center.add_child(_panel)

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	_panel.add_child(v)

	# Fallen cube cat, X-eyed and tipped over.
	var cat := Control.new()
	cat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cat.custom_minimum_size = Vector2(140.0, 100.0)
	cat.draw.connect(func() -> void:
		cat.draw_set_transform(cat.size / 2.0 + Vector2(0.0, 10.0), 0.42, Vector2.ONE)
		Player.paint_cat(cat, Vector2.ZERO, 72.0, 0.0, false)
		cat.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE))
	v.add_child(cat)

	_title = Label.new()
	_title.text = tr("POP_DEAD_TITLE")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 52)
	_title.add_theme_color_override("font_color", UiKit.RED_DEEP)
	v.add_child(_title)

	_record_label = Label.new()
	_record_label.text = tr("POP_NEW_RECORD")
	_record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_record_label.add_theme_font_size_override("font_size", 30)
	_record_label.add_theme_color_override("font_color", GOLD)
	_record_label.visible = false
	v.add_child(_record_label)

	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override("font_size", 26)
	_stats_label.add_theme_color_override("font_color", UiKit.MUTED)
	v.add_child(_stats_label)

	_reward_label = Label.new()
	_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_label.add_theme_font_size_override("font_size", 26)
	_reward_label.add_theme_color_override("font_color", GOLD)
	_reward_label.visible = false
	v.add_child(_reward_label)

	# 경험치 게이지 — 숫자만 던지지 않고 "얼마나 찼는가"를 눈으로 보여 준다.
	_xp_gauge = Control.new()
	_xp_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_gauge.custom_minimum_size = Vector2(460.0, 44.0)
	_xp_gauge.draw.connect(_draw_xp_gauge)
	_xp_gauge.visible = false
	v.add_child(_xp_gauge)

	# 경험치는 골드와 다른 축이라 색도 다르다 (지갑 = 금색, 계정 레벨 = 하늘색).
	_xp_label = Label.new()
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_label.add_theme_font_size_override("font_size", 26)
	_xp_label.add_theme_color_override("font_color", XP_COL)
	_xp_label.visible = false
	v.add_child(_xp_label)

	v.add_child(_spacer(10.0))

	var restart := _make_button(tr("POP_RESTART"), true)
	restart.pressed.connect(func() -> void:
		_finish_all()
		restart_pressed.emit())
	v.add_child(restart)

	var to_title := _make_button(tr("POP_TO_TITLE"), false)
	to_title.pressed.connect(func() -> void:
		_finish_all()
		title_pressed.emit())
	v.add_child(to_title)


## title_text: timed modes end on the clock, not in death — a cheerier headline.
## xp_line: 이 판이 준 계정 경험치(+레벨업). 안 주는 판은 빈 문자열.
## reward: 보상 연출에 필요한 값 —
##   {"gold": 이 판이 준 골드, "gold_from": 판 전 지갑,
##    "xp": 이 판이 준 경험치, "xp_from": 판 전 누적 경험치}
## 비어 있으면 연출 없이 줄만 띄운다 (테스트·캡처가 쓰는 예전 동작).
func open(stats: String, new_record: bool, earned := "", title_text := "",
		xp_line := "", reward := {}) -> void:
	_title.text = title_text if title_text != "" else tr("POP_DEAD_TITLE")
	_title.add_theme_color_override("font_color",
			GOLD if title_text != "" else UiKit.RED_DEEP)
	_stats_label.text = stats
	_record_label.visible = new_record
	_reward_label.text = earned
	_xp_line = xp_line
	_xp_label.text = xp_line
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
		# 창이 자리를 잡은 뒤에 보상 연출을 시작한다 (위 tween은 병렬이라 따로 건다).
		_seq = create_tween()
		_seq.tween_interval(OPEN_HOLD)
		_seq.tween_callback(_run_gold)


func close() -> void:
	_kill_seq()
	_phase = ""
	if hud:  # 연출 도중에 닫혀도 HUD가 옛 값에 붙들린 채 남지 않게
		hud.release()
	visible = false


# --- 보상 연출 ---------------------------------------------------------------


## 연출을 걸지, 그냥 결과만 띄울지 정하고 시작 상태를 만든다.
func _setup_reward(earned: String, xp_line: String, reward: Dictionary) -> void:
	_kill_seq()
	_levelups = 0
	var gold: int = int(reward.get("gold", 0))
	var xp: int = int(reward.get("xp", 0))
	if reward.is_empty() or (gold <= 0 and xp <= 0):
		# 연출 없음 — 예전처럼 결과 줄만 (골드·경험치가 없는 판, 캡처, 테스트).
		_phase = "done"
		_reward_label.visible = earned != ""
		_xp_label.visible = xp_line != ""
		_xp_gauge.visible = false
		if hud:
			hud.release()
		return
	_gold_from = int(reward.get("gold_from", GameState.gold))
	_gold_to = _gold_from + gold
	_xp_from = int(reward.get("xp_from", GameState.xp))
	_xp_to = _xp_from + xp
	_xp_val = float(_xp_from)
	_lv_shown = Account.level_at(_xp_from)
	# 결과 줄은 각 단계가 올 때 하나씩 켠다 — 처음부터 다 보이면 연출이 뒷북이 된다.
	_reward_label.visible = false
	_xp_label.visible = false
	_xp_gauge.visible = true
	_xp_gauge.queue_redraw()
	if hud:
		hud.hold(_gold_from, _xp_from)
	_phase = "gold"


## ① 골드: 코인이 결과창에서 좌상단 지갑으로 날아가고, 숫자가 따라 올라간다.
func _run_gold() -> void:
	if _phase != "gold":
		return
	if _gold_to <= _gold_from or hud == null:
		_run_xp()
		return
	_reward_label.visible = _reward_label.text != ""
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


## 코인 한 닢이 지갑에 닿을 때마다 그만큼 숫자가 올라간다.
func _on_coin_land(nth: int, coins: int, total: int) -> void:
	if _phase != "gold" or hud == null:
		return
	if nth == 1:
		hud.pop_gain(total)
	Sfx.play("gold", 1.0 + 0.05 * nth)
	hud.set_gold_shown(_gold_from + int(round(float(total) * nth / coins)))


## ② 경험치: 결과창 게이지가 차오르고, 레벨이 오르면 그 줄이 붙는다.
func _run_xp() -> void:
	if _phase == "done":
		return
	_phase = "xp"
	if hud:
		hud.set_gold_shown(_gold_to)
	_reward_label.visible = _reward_label.text != ""
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


## 레벨업 — 축하 줄 + 보상 골드가 지갑으로 얹힌다 (이미 지급된 값의 표시분).
func _level_up(lv: int) -> void:
	_levelups += 1
	Sfx.play("record")
	var reward := Account.level_reward(lv)
	_xp_label.text = tr("HUD_XP_EARNED").format({"xp": _xp_to - _xp_from}) \
			+ "\n" + tr("HUD_LEVEL_UP").format({"level": lv, "gold": reward})
	_xp_label.visible = true
	if hud:
		hud.set_gold_shown(hud.gold_shown() + reward)
		hud.pop_gain(reward)
	# 게이지가 한 번 부풀었다 돌아온다 — "올랐다"는 감각.
	var tw := create_tween()
	tw.tween_property(_xp_gauge, "modulate", Color(1.4, 1.4, 1.4), 0.1)
	tw.tween_property(_xp_gauge, "modulate", Color.WHITE, 0.25)


## 정산 끝 — 결과 줄을 최종본으로 맞추고 HUD를 실제 값으로 놓아 준다.
func _finish() -> void:
	_kill_seq()
	_phase = "done"
	_xp_val = float(_xp_to)
	if is_instance_valid(_xp_gauge):
		_xp_gauge.queue_redraw()
	if _xp_line != "":
		_xp_label.text = _xp_line
		_xp_label.visible = true
	_reward_label.visible = _reward_label.text != ""
	if hud:
		hud.release()


## 화면 클릭 = 지금 단계 건너뛰기. 버튼은 자기 클릭을 먹으므로 여기 오지 않는다.
func _on_gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		skip()


## 지금 단계를 즉시 끝낸다 — 골드면 다 채우고 경험치 단계로, 경험치면 정산 완료로.
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


## 버튼을 누르면 남은 연출은 통째로 건너뛰고 값만 제자리에 놓는다.
func _finish_all() -> void:
	if _phase == "gold" or _phase == "xp":
		_kill_seq()
		_set_xp_val(float(_xp_to))
		_finish()


func _kill_seq() -> void:
	if _seq != null and _seq.is_valid():
		_seq.kill()
	_seq = null


## 코인이 출발하는 자리 — 결과창의 골드 줄(없으면 카드 가운데).
func _coin_origin() -> Vector2:
	if is_instance_valid(_reward_label) and _reward_label.visible:
		return _reward_label.get_global_rect().get_center()
	return _panel.get_global_rect().get_center()


## 결과창 경험치 게이지: [Lv.N] ▓▓▓▓░░░ 240 / 480 XP
func _draw_xp_gauge() -> void:
	var ci := _xp_gauge
	var font := ThemeDB.fallback_font
	var total := int(_xp_val)
	var lv := Account.level_at(total)
	var w: float = ci.size.x
	var lv_text := tr("MENU_LEVEL").format({"level": lv})
	var lv_w := font.get_string_size(lv_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	ci.draw_string(font, Vector2(0.0, 21.0), lv_text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 24, XP_COL)
	var need := Account.xp_to_next_at(total)
	var count := tr("MENU_LEVEL_MAX") if need <= 0 else tr("MENU_LEVEL_XP").format(
			{"xp": Account.xp_in_level_at(total), "need": need})
	var count_w := font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	ci.draw_string(font, Vector2(w - count_w, 21.0), count,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiKit.MUTED)
	# 바는 HUD의 경험치 바와 같은 모양 — 같은 값을 크게 보여 주는 것뿐이다.
	var bar := Rect2(lv_w + 14.0, 4.0, w - lv_w - 14.0 - count_w - 14.0, 18.0)
	if bar.size.x < 40.0:
		bar = Rect2(0.0, 26.0, w, 18.0)
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color(UiKit.INK, 0.10)
	groove.set_corner_radius_all(int(bar.size.y / 2.0))
	ci.draw_style_box(groove, bar)
	var inner := bar.grow(-3.0)
	var fill := inner
	fill.size.x = maxf(5.0, inner.size.x * Account.progress_at(total))
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiKit.CYAN
	sb.set_corner_radius_all(int(inner.size.y / 2.0))
	ci.draw_style_box(sb, fill)


func _spacer(h: float) -> Control:
	var s := Control.new()
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.custom_minimum_size = Vector2(0.0, h)
	return s


func _make_button(label: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = label
	b.pressed.connect(func() -> void: Sfx.play("click"))
	b.custom_minimum_size = Vector2(420.0, 68.0)
	b.add_theme_font_size_override("font_size", 30)
	if primary:
		UiKit.btn_primary(b, 30)
	else:
		UiKit.btn_ghost(b, 30)
	return b
