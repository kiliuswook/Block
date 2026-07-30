extends Control
## Volume settings panel (master / BGM / SFX sliders), built in code and
## viewport-relative so one control serves landscape and portrait, the title
## screen ("설정") and the in-game pause menu ("일시정지").

signal closed

const CREAM := Color("f4e3c8")
const PANEL_SIZE := Vector2(640.0, 560.0)
const ROWS := [["전체 음량", "master"], ["배경 음악", "bgm"], ["효과음", "sfx"]]

var _title_label: Label
var _close_btn: Button
var _reset_btn: Button
var _reset_armed := false  # 첫 탭 = 확인 문구, 둘째 탭 = 실제 초기화
var _sliders := {}  # kind -> HSlider


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var vp := get_viewport_rect().size
	var panel := Control.new()
	panel.position = (vp - PANEL_SIZE) / 2.0
	panel.size = PANEL_SIZE
	add_child(panel)
	var face := Control.new()
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.draw.connect(func() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("1c1a26")
		sb.set_corner_radius_all(18)
		sb.set_border_width_all(3)
		sb.border_color = Color(CREAM, 0.65)
		face.draw_style_box(sb, Rect2(Vector2.ZERO, PANEL_SIZE)))
	panel.add_child(face)
	_title_label = Label.new()
	_title_label.text = "설정"
	_title_label.position = Vector2(0.0, 36.0)
	_title_label.size = Vector2(PANEL_SIZE.x, 50.0)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 38)
	_title_label.add_theme_color_override("font_color", CREAM)
	panel.add_child(_title_label)
	for i in ROWS.size():
		_build_row(panel, 132.0 + i * 74.0, ROWS[i][0], ROWS[i][1])
	_close_btn = Button.new()
	_close_btn.text = "닫기"
	_close_btn.size = Vector2(220.0, 56.0)
	_close_btn.position = Vector2((PANEL_SIZE.x - 220.0) / 2.0, PANEL_SIZE.y - 88.0)
	_close_btn.add_theme_font_size_override("font_size", 26)
	_close_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.bg_color = Color(CREAM, 0.16)
	sb.set_border_width_all(2)
	sb.border_color = CREAM
	_close_btn.add_theme_stylebox_override("normal", sb)
	var hover: StyleBoxFlat = sb.duplicate()
	hover.bg_color = Color(CREAM, 0.28)
	_close_btn.add_theme_stylebox_override("hover", hover)
	_close_btn.add_theme_stylebox_override("pressed", sb)
	_close_btn.pressed.connect(close)
	panel.add_child(_close_btn)
	# 게임 초기화 (타이틀의 설정에서만 노출 — 인게임 일시정지에서는 숨김).
	_reset_btn = Button.new()
	_reset_btn.size = Vector2(440.0, 52.0)
	_reset_btn.position = Vector2((PANEL_SIZE.x - 440.0) / 2.0, PANEL_SIZE.y - 168.0)
	_reset_btn.add_theme_font_size_override("font_size", 20)
	_reset_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var danger := StyleBoxFlat.new()
	danger.set_corner_radius_all(12)
	danger.bg_color = Color(0.75, 0.3, 0.3, 0.14)
	danger.set_border_width_all(2)
	danger.border_color = Color(0.85, 0.4, 0.4, 0.8)
	_reset_btn.add_theme_stylebox_override("normal", danger)
	var danger_hover: StyleBoxFlat = danger.duplicate()
	danger_hover.bg_color = Color(0.75, 0.3, 0.3, 0.28)
	_reset_btn.add_theme_stylebox_override("hover", danger_hover)
	_reset_btn.add_theme_stylebox_override("pressed", danger)
	_reset_btn.add_theme_color_override("font_color", Color(0.95, 0.6, 0.6))
	_reset_btn.pressed.connect(_on_reset_pressed)
	panel.add_child(_reset_btn)


func _build_row(panel: Control, y: float, text: String, kind: String) -> void:
	var l := Label.new()
	l.text = text
	l.position = Vector2(64.0, y)
	l.size = Vector2(190.0, 44.0)
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	panel.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.position = Vector2(264.0, y + 6.0)
	s.size = Vector2(310.0, 32.0)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.12)
	bg.set_corner_radius_all(5)
	bg.content_margin_top = 5.0
	bg.content_margin_bottom = 5.0
	s.add_theme_stylebox_override("slider", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(CREAM, 0.9)
	fill.set_corner_radius_all(5)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	# Live preview while dragging; the save happens on release/close.
	s.value_changed.connect(func(v: float) -> void:
		Sfx.set_volume(kind, v, false))
	s.drag_ended.connect(func(changed: bool) -> void:
		if changed:
			GameState.save_game()
			Sfx.play("click"))
	panel.add_child(s)
	_sliders[kind] = s


func open(title_text := "설정", close_text := "닫기") -> void:
	_title_label.text = title_text
	_close_btn.text = close_text
	# 초기화는 타이틀(제목 "설정")에서만 — 인게임 도중 리셋은 상태가 꼬인다.
	_reset_btn.visible = title_text == "설정"
	_reset_armed = false
	_reset_btn.disabled = false
	_reset_btn.text = "⚠ 게임 초기화  (기록·재화·해금 전부 삭제)"
	for kind: String in _sliders:
		_sliders[kind].set_value_no_signal(Sfx.get_volume(kind))
	move_to_front()
	visible = true


## 두 번 눌러 확정: 스토리 진행·기록·재화·해금·랭킹(온라인 보드 포함)·
## 리플레이를 지우고 타이틀을 새로 연다. 볼륨·닉네임은 유지.
func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_btn.text = "정말 초기화할까요?  다시 누르면 삭제됩니다!"
		Sfx.play("error")
		return
	_reset_btn.disabled = true
	_reset_btn.text = "초기화 중..."
	await Ranks.wipe_mine()  # 온라인 보드에서 내 기록 제거 (오프라인이면 즉시 통과)
	GameState.reset_all()
	Replays.clear_all()
	Sfx.play("click")
	get_tree().reload_current_scene()


func close() -> void:
	if not visible:
		return
	visible = false
	GameState.save_game()
	closed.emit()
