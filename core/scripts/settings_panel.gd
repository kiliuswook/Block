extends Control
## 설정 화면 — UX 기획서(캣트리스 UI 플로우) 기준의 전체 화면 페이지.
##
## 하늘색 헤더(지갑 · 제목 · 뒤로) + 흰 본문, 본문은 세 페이지가 갈아 끼워진다:
##   기본 (해상도 / 언어 / 음량 3종 / 컨트롤러 진동 / 컨트롤러 · 키보드 진입)
##   컨트롤러 (액션별 패드 버튼 재설정)
##   키보드 (액션별 키 재설정)
##
## 타이틀(SET_TITLE)과 인게임 일시정지(SET_PAUSE_TITLE)가 같은 컨트롤을 공유한다 —
## 해상도·언어·게임 초기화는 씬을 새로 여는 동작이라 타이틀에서만 노출한다.

signal closed

const UiKit := preload("res://core/scripts/ui_kit.gd")
const KeyBinds := preload("res://core/scripts/key_binds.gd")

const PAGE_MAIN := 0
const PAGE_PAD := 1
const PAGE_KEYS := 2

const VOL_ROWS := [["SET_VOL_MASTER", "master"], ["SET_VOL_BGM", "bgm"],
		["SET_VOL_SFX", "sfx"]]
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const VIBRATION_MAX := 3

const GROUP_W := 760.0  # 기본 페이지 라벨+컨트롤 묶음 폭
const LABEL_W := 300.0
const CTRL_X := 320.0
const CTRL_W := 440.0
const ROW_H := 80.0

var vw := 1920.0
var vh := 1080.0
var _head_h := 216.0
var _foot_h := 46.0
var _body_rect := Rect2()

var _on_title := true
var _page := PAGE_MAIN
var _pages: Array[Control] = []

var _title_label: Label
var _back_btn: Button
var _msg: Label

var _sliders := {}  # kind -> HSlider
var _res_row: Control
var _lang_row: Control
var _res_label: Label
var _lang_label: Label
var _vib_label: Label
var _res_idx := 0  # 화면에 보이는 선택 (아직 적용 전일 수 있다)
var _lang_idx := 0
var _res_applied := 0  # 실제로 적용된 선택 — 둘이 다르면 "적용" 버튼이 켜진다
var _lang_applied := 0
var _res_opts: Array[Vector2i] = []
var _apply_btn: Button
var _main_rows: Array[Dictionary] = []  # {"node": Control, "h": float} — 세로 배치용

var _reset_btn: Button
var _reset_armed := false  # 첫 탭 = 확인 문구, 둘째 탭 = 실제 초기화

# 재설정 칩: 버튼 -> {"kind": "key"/"pad", "row": 행, "group": 충돌 검사 대상 행들}
var _chips := {}
var _cap_btn: Button = null  # 지금 입력을 기다리는 칩



func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vp := get_viewport_rect().size
	vw = vp.x
	vh = vp.y
	size = vp  # CanvasLayer 밑에서는 앵커만으로 크기가 잡히지 않는다
	_head_h = maxf(150.0, vh * 0.20)
	_foot_h = maxf(24.0, vh * 0.043)
	_body_rect = Rect2(6.0, _head_h, vw - 12.0, vh - _head_h - _foot_h)
	_build_header()
	var body := Control.new()
	body.position = _body_rect.position
	body.size = _body_rect.size
	add_child(body)
	for p: Control in [_build_main_page(), _build_pad_page(), _build_keys_page()]:
		_pages.append(p)
		body.add_child(p)
	_msg = Label.new()
	_msg.position = Vector2(0.0, _body_rect.size.y - 44.0)
	_msg.size = Vector2(_body_rect.size.x, 32.0)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.add_theme_font_size_override("font_size", 20)
	_msg.add_theme_color_override("font_color", UiKit.MUTED)
	body.add_child(_msg)
	_sync_values()
	_show_page(PAGE_MAIN)


func _draw() -> void:
	UiKit.paint_backdrop(self, Vector2(vw, vh), 77)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiKit.WHITE
	sb.set_border_width_all(UiKit.BORDER)
	sb.border_color = UiKit.INK
	sb.set_corner_radius_all(0)
	draw_style_box(sb, _body_rect)
	if _page == PAGE_MAIN:
		return
	var cx := _body_rect.position.x + _body_rect.size.x / 2.0
	var ly := _body_rect.position.y + 52.0
	for dx: float in [-1.0, 1.0]:
		draw_line(Vector2(cx + dx * 170.0, ly), Vector2(cx + dx * 330.0, ly),
				Color(UiKit.INK, 0.55), 3.0)


# --- 헤더 ---------------------------------------------------------------------


func _build_header() -> void:
	_title_label = Label.new()
	_title_label.position = Vector2(0.0, _head_h * 0.30)
	_title_label.size = Vector2(vw, _head_h * 0.44)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 56)
	_title_label.add_theme_color_override("font_color", UiKit.INK)
	_title_label.add_theme_color_override("font_outline_color", UiKit.WHITE)
	_title_label.add_theme_constant_override("outline_size", 8)
	add_child(_title_label)
	_back_btn = Button.new()
	_back_btn.text = tr("SET_BACK")
	_back_btn.size = Vector2(150.0, 74.0)
	_back_btn.position = Vector2(vw - 190.0, 34.0)
	UiKit.style_button(_back_btn, UiKit.CYAN, UiKit.CYAN_DEEP, UiKit.WHITE, 26, 16)
	_back_btn.pressed.connect(_on_back)
	add_child(_back_btn)
	# 지갑·레벨은 좌상단 유저 HUD(user_hud.gd)가 이 페이지 위에 그대로 떠 있다 —
	# 여기서 또 그리면 같은 자리에 두 겹이 된다.


# --- 기본 페이지 ---------------------------------------------------------------


func _build_main_page() -> Control:
	var page := Control.new()
	page.size = _body_rect.size
	var gx := (_body_rect.size.x - GROUP_W) / 2.0
	_res_row = _build_stepper(page, gx, "SET_RESOLUTION",
			func() -> void: _step_res(-1), func() -> void: _step_res(1))
	_res_label = _res_row.get_meta("value")
	_lang_row = _build_stepper(page, gx, "SET_LANGUAGE",
			func() -> void: _step_lang(-1), func() -> void: _step_lang(1))
	_lang_label = _lang_row.get_meta("value")
	for r: Array in VOL_ROWS:
		_build_slider(page, gx, str(r[0]), str(r[1]))
	var vib := _build_stepper(page, gx, "SET_VIBRATION",
			func() -> void: _step_vib(-1), func() -> void: _step_vib(1))
	_vib_label = vib.get_meta("value")
	_apply_btn = Button.new()
	_apply_btn.text = tr("SET_APPLY")
	_apply_btn.position = Vector2(gx + CTRL_X, 0.0)
	_apply_btn.size = Vector2(CTRL_W, 56.0)
	UiKit.btn_primary(_apply_btn, 26)
	_apply_btn.pressed.connect(_on_apply)
	page.add_child(_apply_btn)
	_main_rows.append({"node": _apply_btn, "h": 70.0})
	_build_page_link(page, gx, "SET_CONTROLLER", PAGE_PAD)
	_build_page_link(page, gx, "SET_KEYBOARD", PAGE_KEYS)
	# 게임 초기화 (타이틀 전용) — 본문 맨 아래에 고정.
	_reset_btn = Button.new()
	_reset_btn.size = Vector2(560.0, 52.0)
	_reset_btn.position.x = (_body_rect.size.x - 560.0) / 2.0
	UiKit.style_button(_reset_btn, UiKit.RED, UiKit.RED_DEEP, UiKit.WHITE, 20, 14)
	_reset_btn.pressed.connect(_on_reset_pressed)
	page.add_child(_reset_btn)
	_layout_main()
	return page


## 보이는 줄만 위에서부터 다시 쌓는다 — 일시정지에서는 해상도·언어가 빠지므로
## 그 자리에 구멍이 남지 않게 열 때마다 다시 부른다.
func _layout_main() -> void:
	var y := 30.0
	for r: Dictionary in _main_rows:
		var node: Control = r.node
		if not node.visible:
			continue
		node.position.y = y
		y += float(r.h)
	_reset_btn.position.y = maxf(y + 14.0, _body_rect.size.y - 104.0)


## ◀ 값 ▶ 한 줄. 반환된 Control의 "value" 메타에 가운데 Label이 들어 있다.
func _build_stepper(page: Control, gx: float, label_key: String,
		on_prev: Callable, on_next: Callable) -> Control:
	var row := Control.new()
	row.position = Vector2(gx, 0.0)
	row.size = Vector2(GROUP_W, 62.0)
	page.add_child(row)
	_main_rows.append({"node": row, "h": ROW_H})
	row.add_child(_row_label(label_key))
	var prev := Button.new()
	prev.text = "◀"
	prev.size = Vector2(56.0, 54.0)
	prev.position = Vector2(CTRL_X, 0.0)
	UiKit.btn_card(prev, UiKit.CYAN_DEEP, 22)
	prev.pressed.connect(on_prev)
	row.add_child(prev)
	var value := Label.new()
	value.position = Vector2(CTRL_X + 66.0, 0.0)
	value.size = Vector2(CTRL_W - 132.0, 54.0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.clip_text = true
	value.add_theme_font_size_override("font_size", 26)
	value.add_theme_color_override("font_color", UiKit.INK)
	row.add_child(value)
	var next := Button.new()
	next.text = "▶"
	next.size = Vector2(56.0, 54.0)
	next.position = Vector2(CTRL_X + CTRL_W - 56.0, 0.0)
	UiKit.btn_card(next, UiKit.CYAN_DEEP, 22)
	next.pressed.connect(on_next)
	row.add_child(next)
	row.set_meta("value", value)
	return row


func _build_slider(page: Control, gx: float, label_key: String,
		kind: String) -> void:
	var row := Control.new()
	row.position = Vector2(gx, 0.0)
	row.size = Vector2(GROUP_W, 54.0)
	page.add_child(row)
	_main_rows.append({"node": row, "h": ROW_H})
	row.add_child(_row_label(label_key))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.position = Vector2(CTRL_X, 12.0)
	s.size = Vector2(CTRL_W, 32.0)
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
	# 드래그 중에는 바로 들려주고, 저장은 놓을 때/닫을 때.
	s.value_changed.connect(func(v: float) -> void:
		Sfx.set_volume(kind, v, false))
	s.drag_ended.connect(func(changed: bool) -> void:
		if changed:
			GameState.save_game()
			Sfx.play("click"))
	row.add_child(s)
	_sliders[kind] = s


func _build_page_link(page: Control, gx: float, label_key: String,
		to_page: int) -> void:
	var b := Button.new()
	b.text = tr(label_key)
	b.position = Vector2(gx, 0.0)
	b.size = Vector2(GROUP_W, 62.0)
	_main_rows.append({"node": b, "h": 72.0})
	UiKit.btn_card(b, UiKit.PURPLE_DEEP, 26)
	b.pressed.connect(func() -> void:
		Sfx.play("click")
		_show_page(to_page))
	page.add_child(b)


func _row_label(label_key: String) -> Label:
	var l := Label.new()
	l.text = tr(label_key)
	l.size = Vector2(LABEL_W, 54.0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", UiKit.INK)
	return l


# --- 컨트롤러 페이지 -----------------------------------------------------------


func _build_pad_page() -> Control:
	var page := Control.new()
	page.size = _body_rect.size
	page.add_child(_section_head("SET_CONTROLLER", 0.0, _body_rect.size.x, 26.0))
	var gw := 520.0
	var gx := (_body_rect.size.x - gw) / 2.0
	var y := 116.0
	for row: Dictionary in KeyBinds.PAD:
		_build_bind_row(page, gx, y, gw, str(row.label), "pad", row, KeyBinds.PAD)
		y += 74.0
	var reset := Button.new()
	reset.text = tr("SET_RESET_BINDS")
	reset.position = Vector2(gx, y + 16.0)
	reset.size = Vector2(gw, 58.0)
	UiKit.btn_card(reset, UiKit.RED_DEEP, 22)
	reset.pressed.connect(_reset_pad_binds)
	page.add_child(reset)
	return page


# --- 키보드 페이지 -------------------------------------------------------------


func _build_keys_page() -> Control:
	var page := Control.new()
	page.size = _body_rect.size
	page.add_child(_section_head("SET_KEYBOARD", 0.0, _body_rect.size.x, 26.0))
	var single := Control.new()
	single.position = Vector2(0.0, 116.0)
	single.size = Vector2(_body_rect.size.x, _body_rect.size.y - 116.0)
	page.add_child(single)
	var gw := 520.0
	_build_bind_column(single, (_body_rect.size.x - gw) / 2.0, 0.0, gw, "",
			KeyBinds.SINGLE, "single")
	return page


func _build_bind_column(parent: Control, gx: float, gy: float, gw: float,
		seat_key: String, rows: Array, group: String) -> void:
	var y := gy
	if seat_key != "":
		var head := Label.new()
		head.text = tr(seat_key)
		head.position = Vector2(gx, y)
		head.size = Vector2(gw, 40.0)
		head.add_theme_font_size_override("font_size", 28)
		head.add_theme_color_override("font_color", UiKit.CYAN_DEEP)
		parent.add_child(head)
		y += 50.0
	for row: Dictionary in rows:
		_build_bind_row(parent, gx, y, gw, str(row.label), group, row, rows)
		y += 64.0
	var reset := Button.new()
	reset.text = tr("SET_RESET_BINDS")
	reset.position = Vector2(gx, y + 12.0)
	reset.size = Vector2(gw, 54.0)
	UiKit.btn_card(reset, UiKit.RED_DEEP, 20)
	reset.pressed.connect(func() -> void: _reset_key_binds(rows))
	parent.add_child(reset)


## 라벨 + 키캡 칩 한 줄. 칩을 누르면 입력 대기 상태로 들어간다.
func _build_bind_row(parent: Control, gx: float, y: float, gw: float,
		label_key: String, group: String, row: Dictionary, siblings: Array) -> void:
	var l := Label.new()
	l.text = tr(label_key)
	l.position = Vector2(gx, y)
	l.size = Vector2(gw - 190.0, 54.0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", UiKit.INK)
	parent.add_child(l)
	var chip := Button.new()
	chip.position = Vector2(gx + gw - 180.0, y)
	chip.size = Vector2(180.0, 54.0)
	parent.add_child(chip)
	if bool(row.get("fixed", false)):
		chip.text = "LS / D-pad"
		chip.disabled = true
		UiKit.style_button(chip, UiKit.WHITE, Color("c9c6d0"), UiKit.MUTED, 20, 14)
		return
	UiKit.style_button(chip, UiKit.WHITE, UiKit.INK, UiKit.INK, 22, 14)
	chip.pressed.connect(func() -> void: _begin_capture(chip))
	_chips[chip] = {"kind": "pad" if group == "pad" else "key", "row": row,
			"group": siblings}


func _section_head(key: String, x: float, w: float, y: float) -> Label:
	var l := Label.new()
	l.text = tr(key)
	l.position = Vector2(x, y)
	l.size = Vector2(w, 50.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", UiKit.INK)
	return l


# --- 페이지 전환 ---------------------------------------------------------------


func _show_page(page: int) -> void:
	_cancel_capture()
	_page = page
	for i in _pages.size():
		_pages[i].visible = i == page
	_msg.text = ""
	_title_label.text = tr("SET_TITLE") if _on_title else tr("SET_PAUSE_TITLE")
	queue_redraw()
	_refresh()


func _on_back() -> void:
	Sfx.play("click")
	if _page == PAGE_MAIN:
		close()
	else:
		_show_page(PAGE_MAIN)


# --- 값 조작 -------------------------------------------------------------------


func _desktop() -> bool:
	return not OS.has_feature("web") and not OS.has_feature("mobile")


func _res_options() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var scr := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	for r: Vector2i in RESOLUTIONS:
		if r.x <= scr.x and r.y <= scr.y:
			out.append(r)
	if out.is_empty():
		out.append(RESOLUTIONS[0])
	return out


## 해상도·언어는 고르는 즉시 적용하지 않는다 — 창 크기가 튀거나 화면이
## 다시 열리면서 고르던 흐름이 끊기기 때문. 값만 바꿔 두고 "적용"을 기다린다.
func _step_res(dir: int) -> void:
	if _res_opts.is_empty():
		return
	_res_idx = posmod(_res_idx + dir, _res_opts.size())
	Sfx.play("click")
	_refresh()


func _step_lang(dir: int) -> void:
	_lang_idx = posmod(_lang_idx + dir, I18n.codes().size())
	Sfx.play("click")
	_refresh()


## 아직 적용되지 않은 선택이 있는가.
func _has_pending() -> bool:
	return _res_idx != _res_applied or _lang_idx != _lang_applied


## 현재 상태(적용된 값)를 화면 선택으로 되돌린다 — 열 때와 취소할 때.
func _sync_values() -> void:
	_res_opts = _res_options()
	var cur := DisplayServer.window_get_size()
	if GameState.resolution != "":
		var parts := GameState.resolution.split("x")
		if parts.size() == 2:
			cur = Vector2i(int(parts[0]), int(parts[1]))
	_res_idx = maxi(0, _res_opts.find(cur))
	_res_applied = _res_idx
	_lang_idx = maxi(0, Array(I18n.codes()).find(TranslationServer.get_locale()))
	_lang_applied = _lang_idx


## "적용" — 해상도를 창에 반영하고, 언어가 바뀌었으면 씬을 새로 열어
## 모든 문자열을 다시 읽는다 (Control.text 자동 번역은 열 때 한 번뿐이라).
func _on_apply() -> void:
	if not _has_pending():
		return
	Sfx.play("click")
	var lang_changed := _lang_idx != _lang_applied
	if _res_idx != _res_applied:
		var r := _res_opts[_res_idx]
		GameState.resolution = "%dx%d" % [r.x, r.y]
		GameState.apply_resolution()
		_res_applied = _res_idx
	if lang_changed:
		I18n.apply(I18n.codes()[_lang_idx])
		_lang_applied = _lang_idx
	GameState.save_game()
	if lang_changed:
		get_tree().reload_current_scene()
		return
	_refresh()


func _step_vib(dir: int) -> void:
	GameState.vibration = clampi(GameState.vibration + dir, 0, VIBRATION_MAX)
	GameState.save_game()
	Sfx.play("click")
	GameState.rumble(0.6, 0.6, 0.25)
	_refresh()


func _refresh() -> void:
	if not _res_opts.is_empty():
		var r := _res_opts[_res_idx]
		_res_label.text = "%d X %d" % [r.x, r.y]
	_lang_label.text = I18n.native_name(I18n.codes()[_lang_idx])
	_apply_btn.disabled = not _has_pending()
	_vib_label.text = tr("SET_VIBRATION_OFF") if GameState.vibration == 0 \
			else str(GameState.vibration)
	for kind: String in _sliders:
		_sliders[kind].set_value_no_signal(Sfx.get_volume(kind))
	_refresh_chips()


func _refresh_chips() -> void:
	for chip: Button in _chips:
		if chip == _cap_btn:
			continue
		var info: Dictionary = _chips[chip]
		var row: Dictionary = info.row
		if info.kind == "pad":
			chip.text = KeyBinds.pad_name(KeyBinds.pad_of(GameState.padbinds,
					str(row.act)))
		else:
			chip.text = KeyBinds.key_name(KeyBinds.code_of(GameState.keybinds, row))


# --- 재설정 (입력 대기) ---------------------------------------------------------


func _begin_capture(chip: Button) -> void:
	_cancel_capture()
	Sfx.play("click")
	_cap_btn = chip
	var kind: String = _chips[chip].kind
	chip.text = tr("SET_PRESS_BUTTON") if kind == "pad" else tr("SET_PRESS_KEY")
	UiKit.style_button(chip, UiKit.GOLD, UiKit.GOLD_DEEP, UiKit.INK, 18, 14)
	_msg.text = tr("SET_BIND_HINT")


func _cancel_capture() -> void:
	if _cap_btn == null:
		return
	UiKit.style_button(_cap_btn, UiKit.WHITE, UiKit.INK, UiKit.INK, 22, 14)
	_cap_btn = null
	_msg.text = ""
	_refresh_chips()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _cap_btn != null:
		_capture_input(event)
		return
	# 하위 페이지에서 ESC = 한 단계 뒤로 (타이틀/인게임의 ESC 처리보다 먼저).
	if _page == PAGE_MAIN or not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if k.pressed and not k.echo and k.physical_keycode == KEY_ESCAPE:
		_show_page(PAGE_MAIN)
		get_viewport().set_input_as_handled()


func _capture_input(event: InputEvent) -> void:
	var info: Dictionary = _chips[_cap_btn]
	if event is InputEventKey:
		var ev := event as InputEventKey
		if not ev.pressed or ev.echo:
			return
		get_viewport().set_input_as_handled()
		if info.kind == "pad":
			if ev.physical_keycode == KEY_ESCAPE:
				_cancel_capture()
			return
		if ev.physical_keycode == KEY_ESCAPE:
			_cancel_capture()
			return
		if ev.physical_keycode in KeyBinds.RESERVED:
			_reject()
			return
		_assign_key(info, ev.physical_keycode)
	elif event is InputEventJoypadButton and info.kind == "pad":
		var jb := event as InputEventJoypadButton
		if not jb.pressed:
			return
		get_viewport().set_input_as_handled()
		_assign_pad(info, {"t": "b", "i": jb.button_index, "d": 1})
	elif event is InputEventJoypadMotion and info.kind == "pad":
		var jm := event as InputEventJoypadMotion
		if absf(jm.axis_value) < 0.7:
			return
		get_viewport().set_input_as_handled()
		_assign_pad(info, {"t": "a", "i": jm.axis,
				"d": 1 if jm.axis_value > 0.0 else -1})


func _assign_key(info: Dictionary, code: int) -> void:
	var row: Dictionary = info.row
	for other: Dictionary in info.group:
		if other == row:
			continue
		if KeyBinds.code_of(GameState.keybinds, other) == code:
			_reject()
			return
	GameState.keybinds[KeyBinds.slot_key(row)] = code
	KeyBinds.apply_all(GameState.keybinds, GameState.padbinds)
	GameState.save_game()
	Sfx.play("click")
	_cancel_capture()


func _assign_pad(info: Dictionary, bind: Dictionary) -> void:
	var act := str(info.row.act)
	for other: Dictionary in info.group:
		var oa := str(other.get("act", ""))
		if oa == "" or oa == act:
			continue
		var ob := KeyBinds.pad_of(GameState.padbinds, oa)
		if ob.get("t") == bind.t and int(ob.get("i", -1)) == int(bind.i):
			_reject()
			return
	GameState.padbinds[act] = bind
	KeyBinds.apply_all(GameState.keybinds, GameState.padbinds)
	GameState.save_game()
	Sfx.play("click")
	GameState.rumble(0.4, 0.4, 0.15)
	_cancel_capture()


func _reject() -> void:
	Sfx.play("error")
	_cancel_capture()
	_msg.text = tr("SET_BIND_TAKEN")


func _reset_key_binds(rows: Array) -> void:
	for row: Dictionary in rows:
		GameState.keybinds.erase(KeyBinds.slot_key(row))
	KeyBinds.apply_all(GameState.keybinds, GameState.padbinds)
	GameState.save_game()
	Sfx.play("click")
	_cancel_capture()
	_refresh_chips()


func _reset_pad_binds() -> void:
	GameState.padbinds.clear()
	KeyBinds.apply_all(GameState.keybinds, GameState.padbinds)
	GameState.save_game()
	Sfx.play("click")
	_cancel_capture()
	_refresh_chips()


# --- 열기 / 닫기 ---------------------------------------------------------------


## on_title: 타이틀에서 연 설정인가 (false = 인게임 일시정지).
## 초기화·언어·해상도 변경은 씬을 새로 열기 때문에 타이틀에서만 노출한다.
func open(on_title := true) -> void:
	_on_title = on_title
	_sync_values()
	_reset_btn.visible = on_title
	_res_row.visible = on_title and _desktop()
	_lang_row.visible = on_title
	_apply_btn.visible = on_title
	_layout_main()
	_reset_armed = false
	_reset_btn.disabled = false
	_reset_btn.text = tr("SET_RESET")
	_back_btn.text = tr("SET_BACK") if on_title else tr("SET_RESUME")
	move_to_front()
	visible = true
	_show_page(PAGE_MAIN)


## 두 번 눌러 확정: 스토리 진행·기록·재화·해금·랭킹(온라인 보드 포함)·
## 리플레이를 지우고 타이틀을 새로 연다. 볼륨·언어·조작키·닉네임은 유지.
func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_btn.text = tr("SET_RESET_CONFIRM")
		Sfx.play("error")
		return
	_reset_btn.disabled = true
	_reset_btn.text = tr("SET_RESETTING")
	# 온라인 보드에서 내 기록 제거 (오프라인이면 즉시 통과).
	# 스팀 리더보드는 클라이언트가 자기 엔트리를 못 지워서 그냥 넘어간다 —
	# 로컬 기록만 비고, 보드의 기록은 다음 플레이 때 덮어써진다.
	await Ranks.wipe_mine()
	GameState.reset_all()
	Replays.clear_all()
	Sfx.play("click")
	get_tree().reload_current_scene()


func close() -> void:
	if not visible:
		return
	_cancel_capture()
	# 적용하지 않은 해상도·언어 선택은 버린다.
	_res_idx = _res_applied
	_lang_idx = _lang_applied
	visible = false
	GameState.save_game()
	closed.emit()
