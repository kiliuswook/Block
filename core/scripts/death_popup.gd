extends Control
## Death popup: dead cat portrait, run stats and two choices —
## restart from scratch, or back to the title.
## The whole UI is built in code, matching the project's draw-in-code style.

signal restart_pressed
signal title_pressed

const UiKit := preload("res://core/scripts/ui_kit.gd")

const GOLD := UiKit.GOLD_DEEP
const INK := UiKit.INK
const XP_COL := UiKit.CYAN_DEEP  # 계정 경험치 (골드와 구분되는 하늘색)

var _panel: PanelContainer
var _title: Label
var _record_label: Label
var _stats_label: Label
var _reward_label: Label
var _xp_label: Label  # 계정 경험치 + 레벨업 줄


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.09, 0.13, 0.18, 0.55)  # 타이틀 오버레이와 같은 딤
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	# 타이틀 카드와 같은 흰 패널 (두꺼운 잉크 외곽선 + 둥근 모서리).
	var box := UiKit.panel_box(UiKit.WHITE, 28, 0.0)
	box.content_margin_left = 64.0
	box.content_margin_right = 64.0
	box.content_margin_top = 36.0
	box.content_margin_bottom = 44.0
	_panel.add_theme_stylebox_override("panel", box)
	center.add_child(_panel)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	_panel.add_child(v)

	# Fallen cube cat, X-eyed and tipped over.
	var cat := Control.new()
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

	# 경험치는 골드와 다른 축이라 색도 다르다 (지갑 = 금색, 계정 레벨 = 하늘색).
	_xp_label = Label.new()
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_label.add_theme_font_size_override("font_size", 26)
	_xp_label.add_theme_color_override("font_color", XP_COL)
	_xp_label.visible = false
	v.add_child(_xp_label)

	v.add_child(_spacer(10.0))

	var restart := _make_button(tr("POP_RESTART"), true)
	restart.pressed.connect(func() -> void: restart_pressed.emit())
	v.add_child(restart)

	var to_title := _make_button(tr("POP_TO_TITLE"), false)
	to_title.pressed.connect(func() -> void: title_pressed.emit())
	v.add_child(to_title)


## title_text: timed modes end on the clock, not in death — a cheerier headline.
## xp_line: 이 판이 준 계정 경험치(+레벨업). 분할 화면처럼 안 주는 판은 빈 문자열.
func open(stats: String, new_record: bool, earned := "", title_text := "",
		xp_line := "") -> void:
	_title.text = title_text if title_text != "" else tr("POP_DEAD_TITLE")
	_title.add_theme_color_override("font_color",
			GOLD if title_text != "" else UiKit.RED_DEEP)
	_stats_label.text = stats
	_record_label.visible = new_record
	_reward_label.text = earned
	_reward_label.visible = earned != ""
	_xp_label.text = xp_line
	_xp_label.visible = xp_line != ""
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


func close() -> void:
	visible = false


func _spacer(h: float) -> Control:
	var s := Control.new()
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
