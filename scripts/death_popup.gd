extends Control
## Death popup: dead cat portrait, run stats and three choices —
## continue (revive), restart from scratch, or back to the title.
## The whole UI is built in code, matching the project's draw-in-code style.

signal continue_pressed
signal restart_pressed
signal title_pressed

const CREAM := Color("f4e3c8")
const GOLD := Color(1.0, 0.85, 0.35)
const INK := Color("2a2230")

var _panel: PanelContainer
var _record_label: Label
var _stats_label: Label


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.10, 0.09, 0.13, 0.97)
	box.set_corner_radius_all(20)
	box.set_border_width_all(2)
	box.border_color = Color(CREAM, 0.35)
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

	var title := Label.new()
	title.text = "냐옹... 쓰러졌다!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(1.0, 0.42, 0.4))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 10)
	v.add_child(title)

	_record_label = Label.new()
	_record_label.text = "☆ 신기록 달성! ☆"
	_record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_record_label.add_theme_font_size_override("font_size", 30)
	_record_label.add_theme_color_override("font_color", GOLD)
	_record_label.visible = false
	v.add_child(_record_label)

	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override("font_size", 26)
	_stats_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	v.add_child(_stats_label)

	v.add_child(_spacer(10.0))

	var cont := _make_button("이어서 하기", true)
	cont.pressed.connect(func() -> void: continue_pressed.emit())
	v.add_child(cont)

	# Revive currency hint — no real economy yet, so it's free for now.
	var hint := Label.new()
	hint.text = "◆ 부활 젤리 1개 사용  (준비 중 · 지금은 무료!)"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(GOLD, 0.75))
	v.add_child(hint)

	v.add_child(_spacer(6.0))

	var restart := _make_button("처음부터 다시하기", false)
	restart.pressed.connect(func() -> void: restart_pressed.emit())
	v.add_child(restart)

	var to_title := _make_button("타이틀로 나가기", false)
	to_title.pressed.connect(func() -> void: title_pressed.emit())
	v.add_child(to_title)


func open(stats: String, new_record: bool) -> void:
	_stats_label.text = stats
	_record_label.visible = new_record
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
	b.custom_minimum_size = Vector2(420.0, 68.0)
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(14)
	if primary:
		# The warmest thing on screen — like the cat itself.
		sb.bg_color = CREAM
		b.add_theme_color_override("font_color", INK)
		b.add_theme_color_override("font_hover_color", INK)
		b.add_theme_color_override("font_pressed_color", INK)
	else:
		sb.bg_color = Color(1, 1, 1, 0.07)
		sb.set_border_width_all(2)
		sb.border_color = Color(1, 1, 1, 0.25)
		b.add_theme_color_override("font_color", Color(1, 1, 1, 0.88))
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 0.7))
	b.add_theme_stylebox_override("normal", sb)
	var hover: StyleBoxFlat = sb.duplicate()
	hover.bg_color = sb.bg_color.lightened(0.12) if primary else Color(1, 1, 1, 0.14)
	b.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = sb.duplicate()
	pressed.bg_color = sb.bg_color.darkened(0.15) if primary else Color(1, 1, 1, 0.04)
	b.add_theme_stylebox_override("pressed", pressed)
	return b
