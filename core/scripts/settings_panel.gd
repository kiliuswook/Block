extends Control
## Settings panel (language + master / BGM / SFX sliders), built in code and
## viewport-relative so one control serves landscape and portrait, the title
## screen (SET_TITLE) and the in-game pause menu (SET_PAUSE_TITLE).

signal closed

const UiKit := preload("res://core/scripts/ui_kit.gd")
const CREAM := UiKit.CREAM
const PANEL_SIZE := Vector2(640.0, 640.0)
const ROWS := [["SET_VOL_MASTER", "master"], ["SET_VOL_BGM", "bgm"],
		["SET_VOL_SFX", "sfx"]]

var _title_label: Label
var _close_btn: Button
var _reset_btn: Button
var _reset_armed := false  # 첫 탭 = 확인 문구, 둘째 탭 = 실제 초기화
var _sliders := {}  # kind -> HSlider
var _lang_row: Array[Control] = []  # 언어 줄 (타이틀 설정에서만 노출)
var _lang_btn: OptionButton


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vp := get_viewport_rect().size
	size = vp  # CanvasLayer 밑에서는 앵커만으로 크기가 잡히지 않는다
	var dim := ColorRect.new()
	dim.color = Color(0.09, 0.13, 0.18, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.size = vp
	add_child(dim)
	var panel := Control.new()
	panel.position = (vp - PANEL_SIZE) / 2.0
	panel.size = PANEL_SIZE
	add_child(panel)
	var face := Control.new()
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.draw.connect(func() -> void:
		face.draw_style_box(UiKit.panel_box(UiKit.WHITE, 26, 0.0),
				Rect2(Vector2.ZERO, PANEL_SIZE)))
	panel.add_child(face)
	_title_label = Label.new()
	_title_label.text = tr("SET_TITLE")
	_title_label.position = Vector2(0.0, 36.0)
	_title_label.size = Vector2(PANEL_SIZE.x, 50.0)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 38)
	_title_label.add_theme_color_override("font_color", UiKit.INK)
	panel.add_child(_title_label)
	_build_language_row(panel, 124.0)
	for i in ROWS.size():
		_build_row(panel, 214.0 + i * 74.0, tr(ROWS[i][0]), ROWS[i][1])
	_close_btn = Button.new()
	_close_btn.text = tr("SET_CLOSE")
	_close_btn.size = Vector2(220.0, 56.0)
	_close_btn.position = Vector2((PANEL_SIZE.x - 220.0) / 2.0, PANEL_SIZE.y - 88.0)
	UiKit.btn_primary(_close_btn, 26)
	_close_btn.pressed.connect(close)
	panel.add_child(_close_btn)
	# 게임 초기화 (타이틀의 설정에서만 노출 — 인게임 일시정지에서는 숨김).
	_reset_btn = Button.new()
	_reset_btn.size = Vector2(440.0, 52.0)
	_reset_btn.position = Vector2((PANEL_SIZE.x - 440.0) / 2.0, PANEL_SIZE.y - 168.0)
	UiKit.style_button(_reset_btn, UiKit.RED, UiKit.RED_DEEP, UiKit.WHITE, 20, 14)
	_reset_btn.pressed.connect(_on_reset_pressed)
	panel.add_child(_reset_btn)


## Language picker. Title-screen only: switching language rebuilds the scene to
## re-read every string, which would throw away a run if done mid-game.
func _build_language_row(panel: Control, y: float) -> void:
	var l := Label.new()
	l.text = tr("SET_LANGUAGE")
	l.position = Vector2(64.0, y)
	l.size = Vector2(190.0, 44.0)
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", UiKit.INK)
	panel.add_child(l)
	_lang_btn = OptionButton.new()
	_lang_btn.position = Vector2(264.0, y - 2.0)
	_lang_btn.size = Vector2(310.0, 48.0)
	_lang_btn.fit_to_longest_item = false
	_lang_btn.add_theme_font_size_override("font_size", 22)
	UiKit.btn_card(_lang_btn, UiKit.PURPLE_DEEP, 22)
	for code in I18n.codes():
		_lang_btn.add_item(I18n.native_name(code))
		_lang_btn.set_item_metadata(_lang_btn.item_count - 1, code)
	_lang_btn.item_selected.connect(_on_language_selected)
	panel.add_child(_lang_btn)
	_lang_row = [l, _lang_btn]


func _on_language_selected(idx: int) -> void:
	var code := str(_lang_btn.get_item_metadata(idx))
	if code == TranslationServer.get_locale():
		return
	Sfx.play("click")
	I18n.apply(code)
	GameState.save_game()
	get_tree().reload_current_scene()


func _build_row(panel: Control, y: float, text: String, kind: String) -> void:
	var l := Label.new()
	l.text = text
	l.position = Vector2(64.0, y)
	l.size = Vector2(190.0, 44.0)
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", UiKit.INK)
	panel.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.position = Vector2(264.0, y + 6.0)
	s.size = Vector2(310.0, 32.0)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(UiKit.INK, 0.14)
	bg.set_corner_radius_all(5)
	bg.content_margin_top = 5.0
	bg.content_margin_bottom = 5.0
	s.add_theme_stylebox_override("slider", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiKit.ORANGE
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


## on_title: 타이틀에서 연 설정인가 (false = 인게임 일시정지).
## 초기화·언어 변경은 씬을 새로 열기 때문에 타이틀에서만 노출한다.
func open(on_title := true) -> void:
	_title_label.text = tr("SET_TITLE") if on_title else tr("SET_PAUSE_TITLE")
	_close_btn.text = tr("SET_CLOSE") if on_title else tr("SET_RESUME")
	_reset_btn.visible = on_title
	for c in _lang_row:
		c.visible = on_title
	if on_title:
		var codes := I18n.codes()
		var cur := TranslationServer.get_locale()
		_lang_btn.selected = maxi(0, Array(codes).find(cur))
	_reset_armed = false
	_reset_btn.disabled = false
	_reset_btn.text = tr("SET_RESET")
	for kind: String in _sliders:
		_sliders[kind].set_value_no_signal(Sfx.get_volume(kind))
	move_to_front()
	visible = true


## 두 번 눌러 확정: 스토리 진행·기록·재화·해금·랭킹(온라인 보드 포함)·
## 리플레이를 지우고 타이틀을 새로 연다. 볼륨·닉네임은 유지.
func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_btn.text = tr("SET_RESET_CONFIRM")
		Sfx.play("error")
		return
	_reset_btn.disabled = true
	_reset_btn.text = tr("SET_RESETTING")
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
