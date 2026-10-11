extends Control
## 설정 화면 (피그마 "셋팅" / "셋팅_컨트롤러" / "셋팅_키보드") — 전체 화면 페이지.
##
## 하늘 배경 + 우상단 뒤로가기(지갑·레벨은 그 위에 뜨는 상단 고정 유저 HUD가 맡는다)
## + 흰 카드 하나. 카드 안은 세 페이지가 갈아 끼워진다:
##   기본 (해상도 / 언어 / 음량 3종 / 진동 / 컨트롤러 · 키보드 진입 / 게임 초기화)
##   컨트롤러 (아이콘 + 제목 + 액션별 패드 버튼 칩 + 기본값으로 재설정)
##   키보드 (아이콘 + 제목 + 액션별 키 칩 + 기본값으로 재설정)
##
## 인게임 일시정지(`open(false)`)는 피그마 "일시정지"대로 **딤 + 제목 + [타이틀로][이어하기]**
## 만 띄운다 — 음량·조작은 타이틀 설정에서 만진다.

signal closed
signal quit_requested  # 일시정지 메뉴의 `타이틀로` — 판을 버리고 나간다

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

const CARD_W := 880.0  # 기본 페이지 카드
const CARD_PAD := 40.0
const LABEL_W := 200.0  # 줄 왼쪽 라벨
const CTRL_X := 240.0  # 컨트롤이 시작하는 x (카드 안쪽 기준)
const ROW_H := 98.0
const BIND_CARD_W := 1300.0  # 컨트롤러·키보드 카드
const CHIP_W := 350.0
const CHIP_H := 70.0
const BIND_ROW := 98.0

var vw := 1920.0
var vh := 1080.0
var _card_rect := Rect2()  # 지금 페이지의 흰 카드 자리

var _on_title := true
var _page := PAGE_MAIN
var _pages: Array[Control] = []

var _back_btn: Button
var _msg: Label

var _sliders := {}  # kind -> HSlider
var _res_row: Control
var _lang_row: Control
var _res_label: Button
var _lang_label: Button
var _vib_label: Button
var _res_idx := 0
var _lang_idx := 0
var _res_applied := 0
var _lang_applied := 0
var _res_opts: Array[Vector2i] = []
var _apply_btn: Button
var _main_rows: Array[Dictionary] = []  # {"node": Control, "h": float}
var _links: Array[Button] = []  # 컨트롤러 · 키보드 진입 버튼
var _reset_btn: Button
var _main_card_h := 0.0

## 일시정지 오버레이 — 딤 위에 제목 + [타이틀로][이어하기].
var _pause: Control
var _pause_title: Label
var _pause_resume: Button
var _pause_quit: Button

# 재설정 칩: 버튼 -> {"kind": "key"/"pad", "row": 행, "group": 충돌 검사 대상 행들}
var _chips := {}
var _cap_btn: Button = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vp := get_viewport_rect().size
	vw = vp.x
	vh = vp.y
	# 오프셋까지 맞춰 화면 전체를 덮는다 — 앵커만 걸면 CanvasLayer 아래에서 크기가 0으로
	# 남아, 빈 곳을 누른 입력이 뒤의 타이틀 메뉴 버튼으로 샜다.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = vp
	_build_header()
	for p: Control in [_build_main_page(), _build_pad_page(), _build_keys_page()]:
		_pages.append(p)
		add_child(p)
	_msg = Label.new()
	_msg.position = Vector2(0.0, vh - 46.0)
	_msg.size = Vector2(vw, 32.0)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.label(_msg, 20, UiKit.MUTED)
	add_child(_msg)
	_build_pause()
	_sync_values()
	_show_page(PAGE_MAIN)


func _draw() -> void:
	if not _on_title:
		draw_rect(Rect2(Vector2.ZERO, size), UiKit.DIM)
		return
	UiKit.paint_backdrop(self, Vector2(vw, vh))
	UiKit.round_rect(self, _card_rect, UiKit.WHITE, 24)
	if _page == PAGE_MAIN:
		return
	# 하위 페이지: 아이콘 + 제목.
	var icon := "controller.png" if _page == PAGE_PAD else "keyboard.png"
	var cx := _card_rect.get_center().x
	UiKit.draw_tex(self, icon, Rect2(cx - 50.0, _card_rect.position.y + 30.0, 100.0, 70.0))
	UiKit.text(self, tr("SET_CONTROLLER" if _page == PAGE_PAD else "SET_KEYBOARD"),
			Vector2(cx, _card_rect.position.y + 150.0), 40, UiKit.BROWN, true, 1)


func _page_drop() -> float:
	return 118.0 if vh > vw else 0.0


# --- 헤더 ---------------------------------------------------------------------


func _build_header() -> void:
	_back_btn = Button.new()
	_back_btn.text = tr("SET_BACK_FULL")
	_back_btn.size = Vector2(241.0, 71.0)  # 피그마 btn_normal 241×78 (얼굴 71 + 두께 7)
	_back_btn.position = Vector2(vw - 241.0 - 52.0, 60.0 + _page_drop())
	UiKit.btn_normal(_back_btn, 30)
	_back_btn.pressed.connect(_on_back)
	add_child(_back_btn)


# --- 기본 페이지 ---------------------------------------------------------------


func _build_main_page() -> Control:
	var page := Control.new()
	var cw := minf(CARD_W, vw - 80.0)
	var inner := cw - CARD_PAD * 2.0
	page.size = Vector2(cw, 0.0)
	var ctrl_w := inner - CTRL_X
	_res_row = _build_dropdown(page, "SET_RESOLUTION", ctrl_w,
			func() -> void: _open_res_list())
	_res_label = _res_row.get_meta("value")
	_lang_row = _build_dropdown(page, "SET_LANGUAGE", ctrl_w,
			func() -> void: _open_lang_list())
	_lang_label = _lang_row.get_meta("value")
	for r: Array in VOL_ROWS:
		_build_slider(page, str(r[0]), str(r[1]), ctrl_w)
	var vib := _build_dropdown(page, "SET_VIBRATION", ctrl_w,
			func() -> void: _open_vib_list())
	_vib_label = vib.get_meta("value")
	# 적용 — 해상도·언어는 고르는 즉시가 아니라 여기서 반영한다.
	_apply_btn = Button.new()
	_apply_btn.text = tr("SET_APPLY")
	_apply_btn.position = Vector2(CARD_PAD + CTRL_X, 0.0)
	_apply_btn.size = Vector2(ctrl_w, 56.0)
	UiKit.btn_primary(_apply_btn, 24)
	_apply_btn.pressed.connect(_on_apply)
	page.add_child(_apply_btn)
	_main_rows.append({"node": _apply_btn, "h": 82.0})
	# 컨트롤러 · 키보드 — 한 줄에 둘.
	var links := Control.new()
	links.position = Vector2(CARD_PAD, 0.0)
	links.size = Vector2(inner, 70.0)
	page.add_child(links)
	_main_rows.append({"node": links, "h": 100.0})
	var lw := (inner - 30.0) / 2.0
	for i in 2:
		var b := Button.new()
		b.text = tr("SET_CONTROLLER" if i == 0 else "SET_KEYBOARD")
		b.position = Vector2(i * (lw + 30.0), 0.0)
		b.size = Vector2(lw, 70.0)
		UiKit.btn_normal(b, 30)
		var to_page := PAGE_PAD if i == 0 else PAGE_KEYS
		b.pressed.connect(func() -> void:
			Sfx.play("click")
			_show_page(to_page))
		links.add_child(b)
		_links.append(b)
	# 점선 구분 + 게임 초기화 (타이틀 전용).
	var divider := Control.new()
	divider.position = Vector2(CARD_PAD, 0.0)
	divider.size = Vector2(inner, 2.0)
	divider.draw.connect(func() -> void:
		var x := 0.0
		while x < inner:
			divider.draw_line(Vector2(x, 1.0), Vector2(minf(x + 8.0, inner), 1.0),
					Color(UiKit.TEXT, 0.6), 2.0)
			x += 14.0)
	page.add_child(divider)
	_main_rows.append({"node": divider, "h": 42.0})
	_reset_btn = Button.new()
	_reset_btn.position = Vector2(CARD_PAD, 0.0)
	_reset_btn.size = Vector2(inner, 70.0)
	UiKit.btn_danger(_reset_btn, 30)
	_reset_btn.pressed.connect(_on_reset_pressed)
	page.add_child(_reset_btn)
	_main_rows.append({"node": _reset_btn, "h": 80.0})
	_layout_main()
	return page


## 보이는 줄만 위에서부터 쌓고, 카드 높이를 그만큼으로 잡아 화면 가운데에 세운다.
func _layout_main() -> void:
	var page := _pages[PAGE_MAIN] if not _pages.is_empty() else null
	var y := CARD_PAD
	for r: Dictionary in _main_rows:
		var node: Control = r.node
		if not node.visible:
			continue
		node.position.y = y
		y += float(r.h)
	_main_card_h = y + CARD_PAD - 20.0
	var cw := minf(CARD_W, vw - 80.0)
	var top := maxf(PAGE_TOP + _page_drop(), (vh - _main_card_h) / 2.0)
	_card_rect = Rect2((vw - cw) / 2.0, top, cw, _main_card_h)
	if page != null:
		page.position = _card_rect.position
	queue_redraw()


const PAGE_TOP := 186.0


## 라벨 + 회색 알약 버튼(값 ▼) 한 줄 — 누르면 다음 값으로.
func _build_dropdown(page: Control, label_key: String, ctrl_w: float,
		on_next: Callable) -> Control:
	var row := Control.new()
	row.position = Vector2(CARD_PAD, 0.0)
	row.size = Vector2(page.size.x - CARD_PAD * 2.0, 66.0)
	page.add_child(row)
	_main_rows.append({"node": row, "h": ROW_H})
	row.add_child(_row_label(label_key))
	var value := Button.new()
	value.position = Vector2(CTRL_X, 0.0)
	value.size = Vector2(ctrl_w, 66.0)
	value.alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.clip_text = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("ededed")
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 20.0
	sb.content_margin_right = 60.0
	for st in ["normal", "hover", "pressed"]:
		value.add_theme_stylebox_override(st, sb)
	value.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	value.add_theme_font_size_override("font_size", 36)
	value.add_theme_font_override("font", UiKit.font_bold())
	value.add_theme_color_override("font_color", UiKit.TEXT)
	value.add_theme_color_override("font_hover_color", UiKit.TEXT)
	value.add_theme_color_override("font_pressed_color", UiKit.TEXT)
	var arrow := Control.new()
	arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.draw.connect(func() -> void:
		var c := Vector2(ctrl_w - 30.0, 33.0)
		arrow.draw_colored_polygon(PackedVector2Array([c + Vector2(-9.0, -5.0),
				c + Vector2(9.0, -5.0), c + Vector2(0.0, 7.0)]), UiKit.TEXT))
	value.add_child(arrow)
	value.pressed.connect(on_next)
	row.add_child(value)
	row.set_meta("value", value)
	return row


## 라벨 + 초록 슬라이더 한 줄.
func _build_slider(page: Control, label_key: String, kind: String,
		ctrl_w: float) -> void:
	var row := Control.new()
	row.position = Vector2(CARD_PAD, 0.0)
	row.size = Vector2(page.size.x - CARD_PAD * 2.0, 66.0)
	page.add_child(row)
	_main_rows.append({"node": row, "h": ROW_H})
	row.add_child(_row_label(label_key))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.position = Vector2(CTRL_X, 11.0)
	s.size = Vector2(ctrl_w, 44.0)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("ededed")
	bg.set_corner_radius_all(13)
	bg.content_margin_top = 13.0  # 피그마 트랙 두께 26
	bg.content_margin_bottom = 13.0
	s.add_theme_stylebox_override("slider", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiKit.GREEN
	fill.set_corner_radius_all(13)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := _knob_texture()
	s.add_theme_icon_override("grabber", knob)
	s.add_theme_icon_override("grabber_highlight", knob)
	s.add_theme_icon_override("grabber_disabled", knob)
	s.value_changed.connect(func(v: float) -> void:
		Sfx.set_volume(kind, v, false))
	s.drag_ended.connect(func(changed: bool) -> void:
		if changed:
			GameState.save_game()
			Sfx.play("click"))
	row.add_child(s)
	_sliders[kind] = s


## 슬라이더 손잡이 — 흰 원 + 잉크 테두리 + ‖ 표시 (피그마).
static var _knob: Texture2D


static func _knob_texture() -> Texture2D:
	if _knob != null:
		return _knob
	var d := 44
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := Vector2(d / 2.0, d / 2.0)
	for y in d:
		for x in d:
			var p := Vector2(x + 0.5, y + 0.5)
			var dist := p.distance_to(c)
			var col := Color(0, 0, 0, 0)
			if dist <= d / 2.0 - 0.5:
				col = Color("2c1b17") if dist > d / 2.0 - 3.5 else Color.WHITE
				# 가운데 세로 두 줄.
				if absf(p.y - c.y) < 6.0 and (absf(p.x - c.x - 3.5) < 1.2
						or absf(p.x - c.x + 3.5) < 1.2):
					col = Color("2c1b17")
			img.set_pixel(x, y, col)
	_knob = ImageTexture.create_from_image(img)
	return _knob


func _row_label(label_key: String) -> Label:
	var l := Label.new()
	l.text = tr(label_key)
	l.size = Vector2(LABEL_W, 66.0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	UiKit.label(l, 40, UiKit.TEXT)  # 피그마 설정 라벨 40
	return l


# --- 컨트롤러 · 키보드 페이지 ---------------------------------------------------------


func _bind_card_rect() -> Rect2:
	var cw := minf(BIND_CARD_W, vw - 80.0)
	var top := PAGE_TOP + _page_drop()
	return Rect2((vw - cw) / 2.0, top, cw, vh - top - 44.0)


func _build_pad_page() -> Control:
	var page := Control.new()
	var card := _bind_card_rect()
	page.position = card.position
	page.size = card.size
	_build_bind_rows(page, KeyBinds.PAD, "pad")
	return page


func _build_keys_page() -> Control:
	var page := Control.new()
	var card := _bind_card_rect()
	page.position = card.position
	page.size = card.size
	_build_bind_rows(page, KeyBinds.SINGLE, "single")
	return page


## 액션 줄들(칩 + 라벨)을 스크롤 안에 쌓고, 카드 아래에 "기본값으로 재설정".
func _build_bind_rows(page: Control, rows: Array, group: String) -> void:
	var top := 190.0
	var reset_h := 70.0
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(CARD_PAD, top)
	scroll.size = Vector2(page.size.x - CARD_PAD * 2.0,
			page.size.y - top - reset_h - CARD_PAD - 20.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var list := Control.new()
	list.custom_minimum_size = Vector2(scroll.size.x - 20.0, rows.size() * BIND_ROW)
	scroll.add_child(list)
	var y := 0.0
	for row: Dictionary in rows:
		_build_bind_row(list, y, str(row.label), group, row, rows)
		y += BIND_ROW
	var reset := Button.new()
	reset.text = tr("SET_RESET_BINDS")
	reset.position = Vector2(CARD_PAD, page.size.y - CARD_PAD - reset_h)
	reset.size = Vector2(page.size.x - CARD_PAD * 2.0, reset_h)
	UiKit.btn_normal(reset, 30)
	if group == "pad":
		reset.pressed.connect(_reset_pad_binds)
	else:
		reset.pressed.connect(func() -> void: _reset_key_binds(rows))
	page.add_child(reset)


## 칩(왼쪽) + 라벨(오른쪽) 한 줄. 칩을 누르면 입력 대기 상태로 들어간다.
func _build_bind_row(parent: Control, y: float, label_key: String, group: String,
		row: Dictionary, siblings: Array) -> void:
	var chip := Button.new()
	chip.position = Vector2(0.0, y)
	chip.size = Vector2(CHIP_W, CHIP_H)
	parent.add_child(chip)
	var l := Label.new()
	l.text = tr(label_key)
	l.position = Vector2(CHIP_W + 30.0, y)
	l.size = Vector2(parent.custom_minimum_size.x - CHIP_W - 30.0, CHIP_H)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	UiKit.label(l, 40, UiKit.TEXT)  # 피그마 40
	parent.add_child(l)
	if bool(row.get("fixed", false)):
		# 이동은 고정 — 피그마처럼 보통 칩으로 보이되 눌리지 않는다.
		chip.text = "LS / D-PAD"
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.focus_mode = Control.FOCUS_NONE
		UiKit.btn_normal(chip, 30)
		return
	UiKit.btn_normal(chip, 30)
	chip.pressed.connect(func() -> void: _begin_capture(chip))
	_chips[chip] = {"kind": "pad" if group == "pad" else "key", "row": row,
			"group": siblings}


# --- 일시정지 (피그마 "일시정지") ----------------------------------------------------------


func _build_pause() -> void:
	_pause = Control.new()
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	add_child(_pause)
	_pause_title = Label.new()
	_pause_title.text = tr("SET_PAUSE_TITLE")
	_pause_title.position = Vector2(0.0, vh / 2.0 - 90.0)
	_pause_title.size = Vector2(vw, 60.0)
	_pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.label(_pause_title, 44, UiKit.WHITE, true)
	_pause.add_child(_pause_title)
	_pause_quit = Button.new()
	_pause_quit.text = tr("SET_TO_TITLE")
	_pause_quit.size = Vector2(250.0, 68.0)
	_pause_quit.position = Vector2(vw / 2.0 - 250.0 - 10.0, vh / 2.0 - 10.0)
	UiKit.btn_card(_pause_quit, UiKit.GRAY_DEEP, 26)
	_pause_quit.pressed.connect(func() -> void:
		Sfx.play("click")
		quit_requested.emit())
	_pause.add_child(_pause_quit)
	_pause_resume = Button.new()
	_pause_resume.text = tr("SET_RESUME")
	_pause_resume.size = Vector2(250.0, 68.0)
	_pause_resume.position = Vector2(vw / 2.0 + 10.0, vh / 2.0 - 10.0)
	UiKit.btn_primary(_pause_resume, 26)
	_pause_resume.pressed.connect(func() -> void:
		Sfx.play("click")
		close())
	_pause.add_child(_pause_resume)


# --- 페이지 전환 ---------------------------------------------------------------


func _show_page(page: int) -> void:
	_cancel_capture()
	_page = page
	for i in _pages.size():
		_pages[i].visible = _on_title and i == page
	_pause.visible = not _on_title
	_back_btn.visible = _on_title
	_msg.text = ""
	if page == PAGE_MAIN:
		_layout_main()
	else:
		_card_rect = _bind_card_rect()
	queue_redraw()
	_refresh()


func _on_back() -> void:
	Sfx.play("click")
	if _page == PAGE_MAIN:
		close()
	else:
		_show_page(PAGE_MAIN)


# --- 값 조작 -------------------------------------------------------------------


## 창 해상도를 고를 수 있는 환경인가 (= 해상도 줄을 띄울 것인가).
func _desktop() -> bool:
	return not OS.has_feature("web") and not OS.has_feature("mobile") and vw >= vh


func _res_options() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var scr := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	for r: Vector2i in RESOLUTIONS:
		if r.x <= scr.x and r.y <= scr.y:
			out.append(r)
	if out.is_empty():
		out.append(RESOLUTIONS[0])
	return out


# --- 드롭다운 목록 ---------------------------------------------------------------
## 값 칸을 누르면 그 아래로 목록이 펼쳐지고, 한 줄을 눌러 고른다(바깥 · ESC = 닫기).
## 해상도·언어는 고르는 즉시가 아니라 "적용"에서 반영한다 — 진동은 바로 들어간다.

const LIST_ROW_H := 62.0
const LIST_MAX_ROWS := 7

var _list: Control  # 펼친 목록 (바깥 누름 받이 + 판) — 닫히면 null


func _open_lang_list() -> void:
	var names: Array = []
	for code in I18n.codes():
		names.append(I18n.native_name(code))
	_open_list(_lang_label, names, _lang_idx, func(i: int) -> void:
		_lang_idx = i
		_refresh())


func _open_res_list() -> void:
	var names: Array = []
	for r in _res_opts:
		names.append("%d X %d" % [r.x, r.y])
	_open_list(_res_label, names, _res_idx, func(i: int) -> void:
		_res_idx = i
		_refresh())


func _open_vib_list() -> void:
	var names: Array = [tr("SET_VIBRATION_OFF")]
	for i in range(1, VIBRATION_MAX + 1):
		names.append(str(i))
	_open_list(_vib_label, names, GameState.vibration, func(i: int) -> void:
		GameState.vibration = i
		GameState.save_game()
		GameState.rumble(0.6, 0.6, 0.25)
		_refresh())


func _open_list(anchor: Button, labels: Array, cur: int, on_pick: Callable) -> void:
	_close_list()
	if labels.is_empty():
		return
	Sfx.play("click")
	_list = Control.new()
	_list.set_anchors_preset(Control.PRESET_FULL_RECT)
	_list.mouse_filter = Control.MOUSE_FILTER_STOP
	_list.gui_input.connect(func(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed:
			_close_list()
		elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
			_close_list())
	add_child(_list)
	var at := anchor.get_global_rect()
	at.position -= global_position
	var rows := mini(labels.size(), LIST_MAX_ROWS)
	var pad := 8.0
	var h := rows * LIST_ROW_H + pad * 2.0
	var y := at.end.y + 6.0
	if y + h > vh - 20.0:
		y = maxf(20.0, at.position.y - 6.0 - h)  # 아래가 모자라면 위로 펼친다
	var panel := Panel.new()
	panel.position = Vector2(at.position.x, y)
	panel.size = Vector2(at.size.x, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiKit.WHITE
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(4)
	sb.border_color = UiKit.INK
	panel.add_theme_stylebox_override("panel", sb)
	_list.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(pad, pad)
	scroll.size = Vector2(at.size.x - pad * 2.0, rows * LIST_ROW_H)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.custom_minimum_size = Vector2(scroll.size.x - (14.0 if labels.size() > rows else 0.0), 0.0)
	scroll.add_child(box)
	for i in labels.size():
		var b := Button.new()
		b.text = str(labels[i])
		b.custom_minimum_size = Vector2(0.0, LIST_ROW_H)
		b.clip_text = true
		var on := i == cur
		for st in ["normal", "hover", "pressed"]:
			var isb := StyleBoxFlat.new()
			isb.set_corner_radius_all(10)
			isb.bg_color = Color("ffe58a") if on else (Color("ededed") if st != "normal" 					else Color(1, 1, 1, 0))
			b.add_theme_stylebox_override(st, isb)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_font_size_override("font_size", 30)
		b.add_theme_font_override("font", UiKit.font_bold())
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(c, UiKit.TEXT)
		var idx := i
		b.pressed.connect(func() -> void:
			Sfx.play("click")
			_close_list()
			on_pick.call(idx))
		box.add_child(b)
	# 지금 값이 보이게 스크롤.
	scroll.set_deferred("scroll_vertical", int(maxf(0.0, (cur - rows / 2) * LIST_ROW_H)))


func _close_list() -> void:
	if _list != null and is_instance_valid(_list):
		_list.queue_free()
	_list = null


func _has_pending() -> bool:
	return _res_idx != _res_applied or _lang_idx != _lang_applied


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


func _refresh() -> void:
	if not _res_opts.is_empty():
		var r := _res_opts[_res_idx]
		_res_label.text = "%d X %d" % [r.x, r.y]
	_lang_label.text = I18n.native_name(I18n.codes()[_lang_idx])
	_apply_btn.visible = _on_title and _has_pending()
	_vib_label.text = tr("SET_VIBRATION_OFF") if GameState.vibration == 0 \
			else str(GameState.vibration)
	for kind: String in _sliders:
		_sliders[kind].set_value_no_signal(Sfx.get_volume(kind))
	_refresh_chips()
	if _page == PAGE_MAIN and _on_title:
		_layout_main()


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
	UiKit.style_button(chip, UiKit.WHITE, UiKit.GRAY_DEEP, Color(UiKit.TEXT, 0.45), 20, 16)
	chip.add_theme_constant_override("outline_size", 0)
	_msg.text = tr("SET_BIND_HINT")


func _cancel_capture() -> void:
	if _cap_btn == null:
		return
	UiKit.btn_normal(_cap_btn, 30)
	_cap_btn = null
	_msg.text = ""
	_refresh_chips()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _list != null and event is InputEventKey:
		var lk := event as InputEventKey
		if lk.pressed and not lk.echo and lk.physical_keycode == KEY_ESCAPE:
			_close_list()
			get_viewport().set_input_as_handled()
		return
	if _cap_btn != null:
		_capture_input(event)
		return
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


## on_title: 타이틀에서 연 설정인가 (false = 인게임 일시정지 — 딤 + 두 버튼만).
func open(on_title := true) -> void:
	_on_title = on_title
	_sync_values()
	_res_row.visible = on_title and _desktop()
	_lang_row.visible = on_title
	_reset_btn.text = tr("SET_RESET")
	_reset_btn.disabled = false
	_reset_armed = false
	move_to_front()
	visible = true
	_show_page(PAGE_MAIN)


var _reset_armed := false


## 두 번 눌러 확정: 기록·재화·해금·랭킹·리플레이를 지우고 타이틀을 새로 연다.
func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_btn.text = tr("SET_RESET_CONFIRM")
		Sfx.play("error")
		return
	_reset_btn.disabled = true
	_reset_btn.text = tr("SET_RESETTING")
	await Ranks.wipe_mine()
	GameState.reset_all()
	Replays.clear_all()
	Sfx.play("click")
	get_tree().reload_current_scene()


func close() -> void:
	if not visible:
		return
	_cancel_capture()
	_close_list()
	_res_idx = _res_applied
	_lang_idx = _lang_applied
	visible = false
	GameState.save_game()
	closed.emit()
