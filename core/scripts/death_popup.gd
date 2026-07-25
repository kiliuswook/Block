extends Control
## Death popup: dead cat portrait, run stats and three choices —
## continue (revive), restart from scratch, or back to the title.
## The whole UI is built in code, matching the project's draw-in-code style.

signal continue_pressed
signal restart_pressed
signal title_pressed
signal skip_pressed  # story: give up and buy past this stage with gems

const CREAM := Color("f4e3c8")
const GOLD := Color(1.0, 0.85, 0.35)
const INK := Color("2a2230")

var _panel: PanelContainer
var _record_label: Label
var _stats_label: Label
var _reward_label: Label
var _cont: Button
var _hint: Label
var _boost_label: Label
var _boost_row: HBoxContainer
var _boost_chips := {}  # boost id -> Button
var _skip_btn: Button


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

	_reward_label = Label.new()
	_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_label.add_theme_font_size_override("font_size", 26)
	_reward_label.add_theme_color_override("font_color", GOLD)
	_reward_label.visible = false
	v.add_child(_reward_label)

	v.add_child(_spacer(10.0))

	_cont = _make_button("이어서 하기", true)
	_cont.pressed.connect(func() -> void: continue_pressed.emit())
	v.add_child(_cont)

	# Revive jelly price line — open() fills in the cost for this death.
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(GOLD, 0.75))
	v.add_child(_hint)

	v.add_child(_spacer(6.0))

	var restart := _make_button("처음부터 다시하기", false)
	restart.pressed.connect(func() -> void: restart_pressed.emit())
	v.add_child(restart)

	# One-tap boost rebuy for the next endless run (hidden in story mode).
	_boost_label = Label.new()
	_boost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boost_label.add_theme_font_size_override("font_size", 17)
	_boost_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	v.add_child(_boost_label)
	_boost_row = HBoxContainer.new()
	_boost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_boost_row.add_theme_constant_override("separation", 10)
	v.add_child(_boost_row)
	for b: Dictionary in GameState.BOOSTS:
		var chip := Button.new()
		chip.custom_minimum_size = Vector2(150.0, 60.0)
		chip.add_theme_font_size_override("font_size", 17)
		chip.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		chip.pressed.connect(_on_boost_chip.bind(b))
		_boost_row.add_child(chip)
		_boost_chips[b.id] = chip

	# Story: after enough failures a paid skip past the stage appears.
	_skip_btn = _make_button("", false)
	_skip_btn.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	_skip_btn.pressed.connect(func() -> void: skip_pressed.emit())
	v.add_child(_skip_btn)

	var to_title := _make_button("타이틀로 나가기", false)
	to_title.pressed.connect(func() -> void: title_pressed.emit())
	v.add_child(to_title)


## revive_cost: gems this revive costs (0 = free). show_boosts: endless-only
## next-run boost chips. show_skip: story skip offer after repeated failures.
func open(stats: String, new_record: bool, earned := "", revive_cost := 0,
		show_boosts := false, show_skip := false) -> void:
	_stats_label.text = stats
	_record_label.visible = new_record
	_reward_label.text = earned
	_reward_label.visible = earned != ""
	if revive_cost <= 0:
		_hint.text = "◆ 부활 젤리  ·  이번엔 무료!"
		_hint.add_theme_color_override("font_color", Color(GOLD, 0.75))
		_cont.disabled = false
	elif GameState.gems >= revive_cost:
		_hint.text = "◆ 부활 젤리 %d개 사용  (보유 ◆ %d)" % [revive_cost, GameState.gems]
		_hint.add_theme_color_override("font_color", Color(GOLD, 0.75))
		_cont.disabled = false
	else:
		_hint.text = "부활에 ◆ %d 필요  (보유 ◆ %d — 부족)" % [revive_cost, GameState.gems]
		_hint.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
		_cont.disabled = true
	_boost_label.visible = show_boosts
	_boost_row.visible = show_boosts
	if show_boosts:
		_refresh_boosts()
	_skip_btn.visible = show_skip
	if show_skip:
		_skip_btn.text = "◆ %d  이 스테이지 건너뛰기" % GameState.SKIP_COST
		_skip_btn.disabled = GameState.gems < GameState.SKIP_COST
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


func _on_boost_chip(boost: Dictionary) -> void:
	if not GameState.toggle_boost(str(boost.id)):
		Sfx.play("error")
		return
	Sfx.play("buy" if boost.id in GameState.pending_boosts else "click")
	_refresh_boosts()


func _refresh_boosts() -> void:
	_boost_label.text = "다음 판 부스트  (보유 %d G)" % GameState.gold
	for b: Dictionary in GameState.BOOSTS:
		var chip: Button = _boost_chips[b.id]
		var pending: bool = b.id in GameState.pending_boosts
		chip.text = "%s%s  %dG" % ["✓ " if pending else "", b.name, b.price]
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.bg_color = Color(CREAM, 0.18) if pending else Color(1, 1, 1, 0.06)
		sb.set_border_width_all(2)
		sb.border_color = CREAM if pending else Color(1, 1, 1, 0.22)
		chip.add_theme_stylebox_override("normal", sb)
		var hover: StyleBoxFlat = sb.duplicate()
		hover.bg_color = Color(CREAM, 0.26) if pending else Color(1, 1, 1, 0.12)
		chip.add_theme_stylebox_override("hover", hover)
		chip.add_theme_stylebox_override("pressed", sb)
		chip.add_theme_color_override("font_color",
				CREAM if pending else Color(1, 1, 1, 0.85))


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
