extends Control
## 냥이 크리에이터 3000 — 나만의 냥이 커스터마이징 오버레이 (코드 빌드 UI).
## AAA 캐릭터 크리에이터를 흉내 내는 B급 감성: 스포트라이트 받침대 위에서
## 숨쉬는 프리뷰, 유전자 스캔 연출, 냥자인 싱크로율 게이지, 희귀도 표기,
## 옵션마다 플레이버 텍스트. 선택은 즉시 GameState.custom_cat에 저장된다.
## 뷰포트 크기 기준 레이아웃 — 가로(1920×1080)·세로(1080×1920) 둘 다 대응.

signal changed  # 선택이 바뀔 때마다 — 타이틀이 타일/팝업을 다시 그린다

const CustomCat := preload("res://core/scripts/custom_cat.gd")
const CREAM := Color("f4e3c8")
const SCAN_TIME := 1.4  # 열릴 때 유전자 스캔 연출 길이(초)

var _cur := 0  # 현재 부위 탭 인덱스 (CustomCat.PARTS)
var _t := 0.0  # 프리뷰 애니메이션 시계
var _open_t := 99.0  # 열린 뒤 경과 시간 (스캔 연출용)
var _portrait := false
var _pv_rect := Rect2()  # 프리뷰(무대) 영역
var _preview: Control
var _tab_btns: Array[Button] = []
var _grid: GridContainer
var _grid_w := 900.0
var _flavor := ""
var _flavor_col := Color(1, 1, 1, 0.8)


func _ready() -> void:
	_flavor = tr("CC_FLAVOR_WELCOME")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var vs := get_viewport_rect().size
	_portrait = vs.y > vs.x
	_pv_rect = Rect2(0, 0, vs.x, 600.0) if _portrait \
			else Rect2(0, 0, vs.x * 0.40, vs.y)
	# 클릭은 아래(타이틀)로 통과 금지. 배경은 명시적 자식 노드로 깐다 —
	# 루트 자체 _draw는 visibility 토글만으로는 갱신이 보장되지 않는다.
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("0e0c16")
	bg.size = vs
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var deco := Control.new()
	deco.size = vs
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.draw.connect(func() -> void: _draw_backdrop(deco))
	add_child(deco)
	_preview = Control.new()
	_preview.position = _pv_rect.position
	_preview.size = _pv_rect.size
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.draw.connect(_draw_preview)
	add_child(_preview)
	# 오른쪽(가로) / 아래쪽(세로) 작업 영역.
	var rx := 30.0 if _portrait else _pv_rect.size.x + 24.0
	# ✕ 버튼(우상단 폭 ~100px)과 겹치지 않게 가로 모드는 폭을 더 줄인다.
	var rw := vs.x - 60.0 if _portrait else vs.x - rx - 110.0
	var ry := _pv_rect.size.y + 10.0 if _portrait else 28.0
	_grid_w = rw
	var tabs := HFlowContainer.new()
	tabs.position = Vector2(rx, ry)
	tabs.size = Vector2(rw, 150.0)
	tabs.add_theme_constant_override("h_separation", 7)
	tabs.add_theme_constant_override("v_separation", 7)
	add_child(tabs)
	for i in CustomCat.PARTS.size():
		var idx := i  # captured
		var tb := Button.new()
		tb.text = tr(str(CustomCat.PARTS[i].name))
		tb.add_theme_font_size_override("font_size", 17)
		tb.custom_minimum_size = Vector2(0.0, 42.0)
		tb.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		tb.pressed.connect(func() -> void:
			Sfx.play("click")
			_cur = idx
			_refresh())
		tabs.add_child(tb)
		_tab_btns.append(tb)
	var bar_y := vs.y - 86.0
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(rx, ry + 158.0)
	scroll.size = Vector2(rw, bar_y - (ry + 158.0) - 12.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)
	# 하단 액션 바: 운명의 주사위 / 공장 초기화 / 출격.
	var bar := HBoxContainer.new()
	bar.position = Vector2(rx, bar_y)
	bar.size = Vector2(rw, 58.0)
	bar.add_theme_constant_override("separation", 14)
	add_child(bar)
	var rnd := _bar_btn(tr("CC_RANDOM"), false)
	rnd.pressed.connect(_randomize_all)
	bar.add_child(rnd)
	var rst := _bar_btn(tr("CC_RESET"), false)
	rst.pressed.connect(_reset_all)
	bar.add_child(rst)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	var ok := _bar_btn(tr("CC_CONFIRM"), true)
	ok.pressed.connect(func() -> void:
		Sfx.play("record")
		visible = false)
	bar.add_child(ok)
	# 우상단 ✕.
	var x_btn := _bar_btn("✕", false)
	x_btn.position = Vector2(vs.x - 82.0, 20.0)
	x_btn.size = Vector2(56.0, 52.0)
	add_child(x_btn)
	x_btn.pressed.connect(close)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_open_t += delta
	_preview.queue_redraw()


func open() -> void:
	_open_t = 0.0
	_flavor = tr("CC_FLAVOR_OPEN")
	_flavor_col = Color(0.5, 0.9, 0.95)
	_refresh()
	visible = true
	Sfx.play("click")


func close() -> void:
	Sfx.play("click")
	visible = false


func _bar_btn(text: String, accent: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0.0, 54.0)
	b.add_theme_font_size_override("font_size", 21)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.bg_color = Color(CREAM, 0.18) if accent else Color(1, 1, 1, 0.07)
	sb.set_border_width_all(2)
	sb.border_color = CREAM if accent else Color(1, 1, 1, 0.25)
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	b.add_theme_stylebox_override("normal", sb)
	var hover: StyleBoxFlat = sb.duplicate()
	hover.bg_color = Color(CREAM, 0.3) if accent else Color(1, 1, 1, 0.14)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _randomize_all() -> void:
	Sfx.play("record")
	var sel := {}
	for p in CustomCat.PARTS:
		sel[str(p.key)] = randi() % CustomCat.option_count(p)
	GameState.set_custom_all(sel)
	_flavor = tr("CC_FLAVOR_RANDOM")
	_flavor_col = Color(1.0, 0.85, 0.35)
	_refresh()
	changed.emit()


func _reset_all() -> void:
	Sfx.play("click")
	GameState.set_custom_all({})
	_flavor = tr("CC_FLAVOR_RESET")
	_flavor_col = Color(1, 1, 1, 0.8)
	_refresh()
	changed.emit()


func _refresh() -> void:
	_preview.queue_redraw()
	_restyle_tabs()
	_rebuild_grid()


# --- 무대(프리뷰) ----------------------------------------------------------------


## 배경 장식: 위·아래 비네트 띠 + 코너의 짝퉁 엔진 표기.
func _draw_backdrop(ci: Control) -> void:
	var vs := ci.size
	ci.draw_rect(Rect2(0, 0, vs.x, 6), Color(CREAM, 0.25))
	ci.draw_rect(Rect2(0, vs.y - 6, vs.x, 6), Color(CREAM, 0.25))
	var font := ThemeDB.fallback_font
	ci.draw_string(font, Vector2(vs.x - 430.0, vs.y - 14.0),
			tr("CC_ENGINE_LINE"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.22))


func _draw_preview() -> void:
	var ci := _preview
	var pw := _pv_rect.size.x
	var ph := _pv_rect.size.y
	var pcx := pw / 2.0
	var pcy := ph * 0.66 if not _portrait else 462.0
	var cat_s := 220.0 if not _portrait else 190.0
	var cat_y := pcy - cat_s * 0.72
	var font := ThemeDB.fallback_font
	# 스포트라이트 원뿔.
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(pcx - 80.0, -10.0), Vector2(pcx + 80.0, -10.0),
		Vector2(pcx + 250.0, pcy + 30.0), Vector2(pcx - 250.0, pcy + 30.0),
	]), Color(1.0, 0.95, 0.8, 0.05))
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(pcx - 40.0, -10.0), Vector2(pcx + 40.0, -10.0),
		Vector2(pcx + 170.0, pcy + 20.0), Vector2(pcx - 170.0, pcy + 20.0),
	]), Color(1.0, 0.95, 0.8, 0.06))
	# 받침대 (타원 2단 + 링 글로우).
	_ellipse(ci, Vector2(pcx, pcy + 8.0), 200.0, 46.0, Color("1c1928"))
	_ellipse(ci, Vector2(pcx, pcy), 185.0, 40.0, Color("2c2740"))
	_ellipse(ci, Vector2(pcx, pcy - 4.0), 160.0, 32.0, Color("3a3450"))
	_ellipse(ci, Vector2(pcx, pcy + 2.0), 120.0, 22.0, Color(0, 0, 0, 0.35))
	# 숨쉬는 냥이 + 궤도 반짝이.
	var bob := sin(_t * 2.1) * 6.0
	var look := sin(_t * 0.7) * 5.0
	var skin: Dictionary = CustomCat.build_skin(GameState.custom_cat)
	Player.paint_cat(ci, Vector2(pcx, cat_y + bob), cat_s, look, true, false, skin)
	for i in 3:
		var a := _t * 0.6 + TAU * i / 3.0
		var sp := Vector2(pcx + cos(a) * (cat_s * 1.05),
				cat_y + bob * 0.5 + sin(a) * cat_s * 0.42)
		Player.paint_sparkle(ci, sp, 9.0 + 3.0 * sin(_t * 3.0 + i),
				Color(1.0, 0.92, 0.7, 0.35 + 0.3 * sin(_t * 2.3 + i * 2.0)))
	# 열릴 때 유전자 스캔 라인.
	if _open_t < SCAN_TIME:
		var sy := lerpf(cat_y - cat_s * 0.75, cat_y + cat_s * 0.75,
				_open_t / SCAN_TIME)
		ci.draw_line(Vector2(pcx - cat_s * 0.8, sy), Vector2(pcx + cat_s * 0.8, sy),
				Color(0.4, 0.95, 1.0, 0.85), 3.0)
		ci.draw_rect(Rect2(pcx - cat_s * 0.8, sy - 14.0, cat_s * 1.6, 14.0),
				Color(0.4, 0.95, 1.0, 0.12))
		var scan_txt := tr("CC_SCANNING") + ".".repeat(1 + int(_open_t * 6.0) % 3)
		ci.draw_string(font, Vector2(pcx - 70.0, cat_y - cat_s * 0.85), scan_txt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.4, 0.95, 1.0, 0.9))
	# 타이틀 + 짝퉁 에디션 표기.
	ci.draw_string(font, Vector2(32.0, 60.0), tr("CC_TITLE"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 42, CREAM)
	ci.draw_string(font, Vector2(34.0, 88.0),
			tr("CC_SUBTITLE"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.45))
	# 플레이버 텍스트 (마지막 선택 파츠).
	var fw := font.get_string_size(_flavor, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	ci.draw_string(font, Vector2(pcx - fw / 2.0, pcy + 74.0), _flavor,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 19, _flavor_col)
	# B급 각주.
	var joke := tr("CC_JOKE")
	var jw := font.get_string_size(joke, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	ci.draw_string(font, Vector2(pcx - jw / 2.0, ph - 16.0), joke,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.3))


func _ellipse(ci: CanvasItem, at: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 28:
		var a := TAU * k / 28.0
		pts.append(at + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)


# --- 부위 탭 + 옵션 그리드 -------------------------------------------------------


func _restyle_tabs() -> void:
	for i in _tab_btns.size():
		var b := _tab_btns[i]
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 13.0
		sb.content_margin_right = 13.0
		if i == _cur:
			sb.bg_color = Color(CREAM, 0.16)
			sb.set_border_width_all(2)
			sb.border_color = CREAM
		else:
			sb.bg_color = Color(1, 1, 1, 0.05)
			sb.set_border_width_all(1)
			sb.border_color = Color(1, 1, 1, 0.2)
		b.add_theme_stylebox_override("normal", sb)
		var hover: StyleBoxFlat = sb.duplicate()
		hover.bg_color = Color(1, 1, 1, 0.12)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", sb)


func _rebuild_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var part: Dictionary = CustomCat.PARTS[_cur]
	var key := str(part.key)
	var picked: int = CustomCat.pick(GameState.custom_cat, key)
	if part.get("type") == "color":
		_grid.columns = maxi(1, int(_grid_w / 82.0))
		var cols: Array = part.cols
		for i in cols.size():
			_grid.add_child(_make_swatch(key, i, cols[i], i == picked))
	else:
		_grid.columns = maxi(1, int(_grid_w / 120.0))
		var opts: Array = part.opts
		for i in opts.size():
			_grid.add_child(_make_style_tile(key, i, opts[i], i == picked))


func _pick(key: String, idx: int) -> void:
	var part := CustomCat.get_part(key)
	if part.get("type") == "color":
		Sfx.play("click")
		_flavor = tr("CC_FLAVOR_COLOR")
		_flavor_col = Color(1, 1, 1, 0.8)
	else:
		var opt: Dictionary = (part.opts as Array)[idx]
		var r := int(opt.get("r", 0))
		Sfx.play("record" if r >= 3 else ("buy" if r >= 2 else "click"))
		_flavor = "[%s] %s — %s" % [tr(CustomCat.RARITY_NAMES[r]), opt.name,
				str(opt.get("d", ""))]
		_flavor_col = CustomCat.RARITY_COLS[r]
	GameState.set_custom_part(key, idx)
	_preview.queue_redraw()
	_rebuild_grid()
	changed.emit()


func _make_swatch(key: String, idx: int, col: Color, selected: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(70.0, 70.0)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.bg_color = col
	sb.set_border_width_all(4 if selected else 1)
	sb.border_color = CREAM if selected else Color(0, 0, 0, 0.4)
	b.add_theme_stylebox_override("normal", sb)
	var hover: StyleBoxFlat = sb.duplicate()
	hover.border_color = Color(1, 1, 1, 0.8)
	if not selected:
		hover.set_border_width_all(2)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void: _pick(key, idx))
	return b


## 이 옵션만 바꾼 미니 냥이를 그려주는 미리보기 타일 (이름은 희귀도 색).
func _make_style_tile(key: String, idx: int, opt: Dictionary, selected: bool) -> Button:
	var rar := int(opt.get("r", 0))
	var b := Button.new()
	b.custom_minimum_size = Vector2(108.0, 124.0)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.bg_color = Color(CREAM, 0.12) if selected else Color(1, 1, 1, 0.05)
	sb.set_border_width_all(3 if selected else 1)
	sb.border_color = CREAM if selected \
			else (Color(CustomCat.RARITY_COLS[rar], 0.55) if rar > 0
					else Color(1, 1, 1, 0.2))
	b.add_theme_stylebox_override("normal", sb)
	var hover: StyleBoxFlat = sb.duplicate()
	hover.bg_color = Color(1, 1, 1, 0.1)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void: _pick(key, idx))
	var face := Control.new()
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var opt_name := ("★" if rar >= 3 else "") + str(opt.name)
	face.draw.connect(func() -> void:
		var sel: Dictionary = GameState.custom_cat.duplicate()
		sel[key] = idx
		Player.paint_cat(face, Vector2(54.0, 50.0), 52.0, 0.0, true, false,
				CustomCat.build_skin(sel))
		var font := ThemeDB.fallback_font
		var w := font.get_string_size(opt_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		face.draw_string(font, Vector2((108.0 - w) / 2.0, 112.0), opt_name,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
				CREAM if selected else CustomCat.RARITY_COLS[rar]))
	b.add_child(face)
	return b
