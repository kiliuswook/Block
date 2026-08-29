extends Control
## 냥이 크리에이터 3000 — 캐릭터 커스터마이징 오버레이 (코드 빌드 UI).
## AAA 캐릭터 크리에이터를 흉내 내는 B급 감성: 스포트라이트 받침대 위에서
## 숨쉬는 프리뷰, 유전자 스캔 연출, 희귀도 표기, 옵션마다 플레이버 텍스트.
## open(cat_id, player)로 캐릭터 한 마리를 열고, 손댄 부위만 그 캐릭터(+자리) 몫으로
## GameState.cat_custom에 즉시 저장된다 (나머지는 디자인 그대로).
## player는 1P/2P 자리 — 2인 플레이에서 같은 냥이를 골라도 꾸민 건 따로 남는다.
## 뷰포트 크기 기준 레이아웃 — 가로(1920×1080)·세로(1080×1920) 둘 다 대응.

signal changed  # 선택이 바뀔 때마다 — 타이틀이 타일/팝업을 다시 그린다

const CustomCat := preload("res://core/scripts/custom_cat.gd")
const CatSprite := preload("res://core/scripts/cat_sprite.gd")
const CREAM := Color("f4e3c8")
## 좌상단 유저 HUD 카드 아래에서 시작하는 헤더 y (겹침 방지).
const HEAD_TOP := 164.0
const SCAN_TIME := 1.4  # 열릴 때 유전자 스캔 연출 길이(초)
const TAB_W := 96.0  # 부위 칩 크기
const TAB_H := 118.0
const CLOSE_UP := 82.0  # 칩 안 부위 클로즈업 사각형 한 변

var _cat_id := "cream"  # 지금 꾸미는 중인 캐릭터
var _player := 1  # 꾸미는 자리 (1 = P1, 2 = P2)
var _cur := 0  # 현재 부위 탭 인덱스 (CustomCat.PARTS)
var _t := 0.0  # 프리뷰 애니메이션 시계
var _open_t := 99.0  # 열린 뒤 경과 시간 (스캔 연출용)
var _portrait := false
var _pv_rect := Rect2()  # 프리뷰(무대) 영역
var _preview: Control
var _tab_btns: Array[Button] = []
var _tab_faces: Array[Control] = []  # 칩의 클로즈업 면
var _tabs: HFlowContainer
var _groups: Array[Dictionary] = []  # 이 캐릭터에 적용되는 부위 묶음
var _preset_tab := false  # 0번 "원본 냥이" 프리셋 탭을 쓰는가
var _custom_slot := false  # "나만의 캐릭터"인가 — 파츠마다 해금이 걸린다
## 잠긴 파츠를 입혀 본 임시 선택 — 미리보기에만 쓰이고 저장되지 않는다.
var _preview_sel: Dictionary = {}
var _panel: VBoxContainer
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
	_tabs = HFlowContainer.new()
	_tabs.position = Vector2(rx, ry)
	_tabs.size = Vector2(rw, TAB_H * 2.0 + 10.0)
	_tabs.add_theme_constant_override("h_separation", 8)
	_tabs.add_theme_constant_override("v_separation", 8)
	add_child(_tabs)
	var bar_y := vs.y - 86.0
	var top := ry + TAB_H * 2.0 + 24.0
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(rx, top)
	scroll.size = Vector2(rw, bar_y - top - 12.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	# 부위 하나의 모양과 색을 한 패널에 쌓는다 — 둘을 같은 뎁스에 둔다.
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 16)
	_panel.custom_minimum_size = Vector2(rw, 0.0)
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_panel)
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


func open(cat_id: String, player := 1) -> void:
	# 꾸미기는 "나만의 캐릭터" 슬롯 전용 — 디자인 냥이는 컨셉 시트 원본 그대로.
	if not GameState.is_custom_cat(cat_id):
		return
	_cat_id = cat_id
	_player = player
	_cur = 0
	_preview_sel.clear()
	_build_tabs()
	_open_t = 0.0
	_flavor = tr("CC_FLAVOR_OPEN")
	_flavor_col = Color(0.5, 0.9, 0.95)
	_refresh()
	visible = true
	Sfx.play("click")


func close() -> void:
	Sfx.play("click")
	visible = false


func _char_id() -> String:
	return str(GameState.get_cat(_cat_id).get("char", "char01"))


## 이 캐릭터에 실제로 반영되는 부위만 칩으로 세운다.
## 시트 그림으로 그리는 냥이는 레이어 색만, 나만의 캐릭터는 디자인 냥이에게서
## 빌려 온 파츠만 다룬다. 부위는 CustomCat.GROUPS 단위 — 모양과 색이 한 칩에 얽힌다.
func _build_tabs() -> void:
	var sprite := CatSprite.has(_char_id())
	_custom_slot = GameState.is_custom_cat(_cat_id)
	_preset_tab = not sprite
	_groups.clear()
	for group in CustomCat.GROUPS:
		var keys: Array = []
		for part in CustomCat.group_parts(group):
			var key := str(part.key)
			if sprite and not CustomCat.SPRITE_TINTS.has(key):
				continue
			# 고를 게 하나뿐인 자리는 내지 않는다.
			if _custom_slot and CustomCat.my_options(key).size() < 2:
				continue
			keys.append(key)
		if keys.is_empty():
			continue
		var g: Dictionary = group.duplicate()
		g["keys"] = keys
		_groups.append(g)
	for b in _tab_btns:
		b.queue_free()
	_tab_btns.clear()
	_tab_faces.clear()
	if _preset_tab:
		_add_chip(tr("CC_PRESET"), 0, {})
	for i in _groups.size():
		_add_chip(tr(str(_groups[i].name)), i + (1 if _preset_tab else 0), _groups[i])


## 부위 칩 하나 — 지금 냥이를 그 부위만 확대해 보여 준다(빈 group = 전신).
func _add_chip(label: String, i: int, group: Dictionary) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(TAB_W, TAB_H)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void:
		Sfx.play("click")
		_cur = i
		_refresh())
	var face := Control.new()
	face.position = Vector2((TAB_W - CLOSE_UP) / 2.0, 5.0)
	face.size = Vector2(CLOSE_UP, CLOSE_UP)
	face.clip_contents = true  # 클로즈업 — 부위 밖은 잘라 낸다
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.draw.connect(func() -> void: _draw_chip(face, group))
	b.add_child(face)
	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.position = Vector2(0.0, CLOSE_UP + 6.0)
	name_lbl.size = Vector2(TAB_W, 24.0)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(name_lbl)
	_tabs.add_child(b)
	_tab_btns.append(b)
	_tab_faces.append(face)


## 칩 안의 그림: 부위 그룹이면 그 자리를 확대해, 프리셋 칩이면 전신을.
func _draw_chip(face: Control, group: Dictionary) -> void:
	var mid := Vector2(CLOSE_UP, CLOSE_UP) / 2.0
	if group.is_empty():
		Player.paint_cat(face, mid + Vector2(0.0, 2.0), CLOSE_UP * 0.78, 0.0,
				true, false, _skin())
		return
	var s := CLOSE_UP / maxf(0.1, float(group.zoom))
	Player.paint_cat(face, mid - Vector2(group.at) * s, s, 0.0, true, false, _skin())


## 현재 캐릭터의 파츠 + 저장된 커스터마이징(+ 미리보기용 임시 선택 하나).
func _skin(extra_key := "", extra_idx := 0) -> Dictionary:
	var sel: Dictionary = GameState.custom_sel(_cat_id, _player).duplicate()
	for key: Variant in _preview_sel:
		sel[str(key)] = int(_preview_sel[key])
	if extra_key != "":
		sel[extra_key] = extra_idx
	var char_id := _char_id()
	var tier: int = GameState.cat_tier(_cat_id)
	var skin := CustomCat.build_skin(char_id, tier, sel)
	# 게임에서 보이는 그대로 미리 보여준다 (시트 그림 → 레이어 틴트).
	if CatSprite.has(char_id) and (sel.is_empty()
			or (CatSprite.is_layered(char_id) and CustomCat.sprite_safe(sel))):
		skin["sprite"] = char_id
		skin["tier"] = tier
		skin["tints"] = CustomCat.sprite_tints(sel)
	return skin


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


## 지금 다루는 모든 부위 정의 (그룹을 펼친 것).
func _all_parts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g in _groups:
		for key: String in (g.keys as Array):
			var part := CustomCat.get_part(key)
			if not part.is_empty():
				out.append(part)
	return out


func _randomize_all() -> void:
	_preview_sel.clear()
	Sfx.play("record")
	var sel := {}
	for p in _all_parts():
		var key := str(p.key)
		# 나만의 캐릭터는 이미 열린 파츠 중에서만 굴린다.
		var pool: Array = []
		if _custom_slot:
			for i: int in CustomCat.my_options(key):
				if GameState.part_unlocked(key, i):
					pool.append(i)
		else:
			pool = range(CustomCat.option_count(p))
		if pool.is_empty():
			continue
		sel[key] = pool[randi() % pool.size()]
	GameState.set_custom_all(_cat_id, sel, _player)
	Achv.unlock(Achv.CUSTOM_CAT)
	_flavor = tr("CC_FLAVOR_RANDOM")
	_flavor_col = Color(1.0, 0.85, 0.35)
	_refresh()
	changed.emit()


func _reset_all() -> void:
	_preview_sel.clear()
	Sfx.play("click")
	GameState.set_custom_all(_cat_id, {}, _player)
	_flavor = tr("CC_FLAVOR_RESET")
	_flavor_col = Color(1, 1, 1, 0.8)
	_refresh()
	changed.emit()


func _refresh() -> void:
	_preview.queue_redraw()
	_restyle_tabs()
	for f in _tab_faces:
		f.queue_redraw()
	_rebuild_panel()


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
	Player.paint_cat(ci, Vector2(pcx, cat_y + bob), cat_s, look, true, false, _skin())
	# 지금 고르는 부위가 어디인지 냥이 위에 표시한다 — 칩과 몸을 이어 준다.
	var gi := _cur - (1 if _preset_tab else 0)
	if gi >= 0 and gi < _groups.size():
		var at := Vector2(pcx, cat_y + bob) + Vector2(_groups[gi].at) * cat_s
		var rr := cat_s * maxf(0.14, float(_groups[gi].zoom) * 0.5)
		var pulse := 0.55 + 0.25 * sin(_t * 3.4)
		ci.draw_arc(at, rr, 0.0, TAU, 40, Color(0.45, 0.95, 1.0, pulse), 2.5)
		ci.draw_arc(at, rr + 5.0, 0.0, TAU, 40, Color(0.45, 0.95, 1.0, pulse * 0.3), 1.5)
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
	# 타이틀 + 짝퉁 에디션 표기. 좌상단은 유저 HUD 카드가 늘 떠 있는 자리라
	# 그 아래에서 시작한다 (HEAD_TOP).
	ci.draw_string(font, Vector2(32.0, HEAD_TOP), tr("CC_TITLE"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 42, CREAM)
	ci.draw_string(font, Vector2(34.0, HEAD_TOP + 28.0),
			tr("CC_SUBTITLE"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.45))
	# 지금 꾸미는 캐릭터 이름.
	var who := tr(str(GameState.get_cat(_cat_id).get("name", "")))
	if _player > 1:
		who = "2P  ·  " + who
	ci.draw_string(font, Vector2(34.0, HEAD_TOP + 58.0), who,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1.0, 0.85, 0.35))
	# 잠긴 파츠를 입혀 보는 중이면 무대에 명시한다 — 저장되는 모습이 아니다.
	if not _preview_sel.is_empty():
		var note := tr("CC_PREVIEW_ON").format({"n": _preview_sel.size()})
		var nw := font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		ci.draw_string(font, Vector2(pcx - nw / 2.0, pcy + 46.0), note,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.45, 0.95, 1.0, 0.9))
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
## 선택한 부위 하나를 통째로 펀친다 — 모양 타일과 색 스와치가
## 한 화면에 같이 다. 더 이상 "모양 탭 → 색 탭"으로 들어갈 필요가 없다.
func _rebuild_panel() -> void:
	for c in _panel.get_children():
		c.queue_free()
	if _preset_tab and _cur == 0:
		var grid := _section(tr("CC_PRESET"), 120.0)
		for char_id: String in CustomCat.CHARS:
			grid.add_child(_make_preset_tile(char_id))
		return
	var gi := _cur - (1 if _preset_tab else 0)
	if gi < 0 or gi >= _groups.size():
		return
	for key: String in (_groups[gi].keys as Array):
		var part := CustomCat.get_part(key)
		if part.is_empty():
			continue
		var picked: int = GameState.custom_idx(_cat_id, key, _player)
		# 잠긴 파츠를 입혀 보는 중이면 그쪽이 지금 모습이다.
		if _preview_sel.has(key):
			picked = int(_preview_sel[key])
		var idxs: Array = range(CustomCat.option_count(part))
		if _custom_slot:
			idxs = CustomCat.my_options(key)
		var color: bool = part.get("type") == "color"
		var grid := _section(tr(str(part.name)), 82.0 if color else 120.0)
		for i: int in idxs:
			var lock := _locked(key, i)
			var prev: bool = lock and int(_preview_sel.get(key, -1)) == i
			if color:
				grid.add_child(_make_swatch(key, i, (part.cols as Array)[i],
						i == picked, lock, prev))
			else:
				grid.add_child(_make_style_tile(key, i, (part.opts as Array)[i],
						i == picked, lock, prev))


## 부위 안의 한 줄 — 소제목 + 그 아래 옵션 격자.
func _section(title: String, cell: float) -> GridContainer:
	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 16)
	head.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	_panel.add_child(head)
	var grid := GridContainer.new()
	grid.columns = maxi(1, int(_grid_w / cell))
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.add_child(grid)
	return grid



## 나만의 캐릭터에서 아직 못 쓰는 옵션인가 (출처 냥이가 잠겨 있다).
func _locked(key: String, idx: int) -> bool:
	return _custom_slot and not GameState.part_unlocked(key, idx)


func _pick(key: String, idx: int) -> void:
	if _locked(key, idx):
		_preview_locked(key, idx)
		return
	var part := CustomCat.get_part(key)
	# 같은 부위에 걸려 있던 미리보기는 진짜 선택이 덮어쓴다.
	_preview_sel.erase(key)
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
	GameState.set_custom_part(_cat_id, key, idx, _player)
	Achv.unlock(Achv.CUSTOM_CAT)  # 업적: 냥이 크리에이터로 부위를 하나라도 바꿔 저장
	_preview.queue_redraw()
	_rebuild_panel()
	changed.emit()


## 잠긴 파츠는 입혀만 본다 — 미리보기에만 얻어가고 저장되지 않는다.
## 다시 누르면 보기를 그만둔다 (토글).
func _preview_locked(key: String, idx: int) -> void:
	if int(_preview_sel.get(key, -1)) == idx:
		_preview_sel.erase(key)
		Sfx.play("click")
		_flavor = tr("CC_PREVIEW_CLEAR")
		_flavor_col = Color(1, 1, 1, 0.65)
	else:
		_preview_sel[key] = idx
		Sfx.play("click")
		_flavor = "%s  ·  %s" % [tr("CC_PREVIEW"), _lock_text(key, idx)]
		_flavor_col = Color(0.5, 0.9, 0.95)
	_preview.queue_redraw()
	for f in _tab_faces:
		f.queue_redraw()
	_rebuild_panel()


## 이 옵션을 여는 조건 문구 — 어느 냥이를 어디까지 키우면 되는지.
func _lock_text(key: String, idx: int) -> String:
	var hint := GameState.part_unlock_hint(key, idx)
	if hint.is_empty():
		return tr("CC_LOCKED_ANY")
	var who := tr(str(GameState.get_cat(str(hint.cat)).get("name", "")))
	if int(hint.grade) > 1:
		return tr("CC_LOCKED_GRADE").format({"name": who, "grade": hint.grade})
	return tr("CC_LOCKED").format({"name": who})





## 디자인 캐릭터 한 마리를 통째로 불러오는 타일.
func _make_preset_tile(char_id: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(108.0, 124.0)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.bg_color = Color(1, 1, 1, 0.05)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.2)
	b.add_theme_stylebox_override("normal", sb)
	var hover: StyleBoxFlat = sb.duplicate()
	hover.bg_color = Color(1, 1, 1, 0.12)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var locked := _preset_locked(char_id)
	b.pressed.connect(func() -> void: _load_preset(char_id))
	var face := Control.new()
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.draw.connect(func() -> void:
		var skin := {"parts": CustomCat.char_parts(char_id, _preset_tier(char_id))}
		Player.paint_cat(face, Vector2(54.0, 52.0), 52.0, 0.0, true, false,
				_shadow(skin) if locked else skin)
		if locked:
			_draw_lock(face, Vector2(88.0, 24.0), 0.9)
		var font := ThemeDB.fallback_font
		var label := tr(str((CustomCat.CHARS[char_id] as Dictionary).get("name", char_id)))
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		face.draw_string(font, Vector2((108.0 - w) / 2.0, 112.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
				Color(1, 1, 1, 0.35) if locked else Color(1, 1, 1, 0.75)))
	b.add_child(face)
	return b


## 나만의 캐릭터는 잠긴 냥이의 프리셋을 불러올 수 없다.
func _preset_locked(char_id: String) -> bool:
	if not _custom_slot:
		return false
	var cid := GameState.cat_id_for_char(char_id)
	return cid == "" or not GameState.is_unlocked(cid)


## 프리셋으로 가져올 파츠 단계 — 나만의 캐릭터는 그 냥이가 키운 만큼만 가져온다.
func _preset_tier(char_id: String) -> int:
	if not _custom_slot:
		return GameState.cat_tier(_cat_id)
	var cid := GameState.cat_id_for_char(char_id)
	return GameState.cat_tier(cid) if cid != "" else 0


## 잠긴 파츠/프리셋 미리보기용 회색 실루엣 — 색만 지우고 모양은 남긴다.
func _shadow(skin: Dictionary) -> Dictionary:
	var out := skin.duplicate(true)
	var parts: Dictionary = out.get("parts", {})
	parts["body_col"] = Color("cdd4dd")
	parts["ear_col"] = Color("b3bcc9")
	parts["tail_col"] = Color("b3bcc9")
	parts["foot_col"] = Color("dfe4ea")
	parts["pad_col"] = Color("b3bcc9")
	parts["eye_col"] = Color("8f98a6")
	parts["nose_col"] = Color("8f98a6")
	parts["pattern_col"] = Color("b3bcc9")
	out["parts"] = parts
	out["body"] = parts["body_col"]
	out["ear"] = parts["ear_col"]
	out.erase("sprite")
	out["gray"] = true
	out.erase("tints")
	return out


## 프리셋을 현재 선택값으로 옮겨 담는다 (이후 파츠별로 마음껏 수정 가능).
func _load_preset(char_id: String) -> void:
	if _preset_locked(char_id):
		Sfx.play("error")
		var cid := GameState.cat_id_for_char(char_id)
		_flavor = tr("CC_LOCKED").format(
				{"name": tr(str(GameState.get_cat(cid).get("name", "")))})
		_flavor_col = Color(1.0, 0.55, 0.5)
		_preview.queue_redraw()
		return
	Sfx.play("record")
	_preview_sel.clear()
	GameState.set_custom_all(_cat_id,
			CustomCat.char_selection(char_id, _preset_tier(char_id)), _player)
	_flavor = tr("CC_FLAVOR_PRESET")
	_flavor_col = Color(1.0, 0.85, 0.35)
	_refresh()
	changed.emit()


func _make_swatch(key: String, idx: int, col: Color, selected: bool,
		locked := false, previewing := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(70.0, 70.0)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	# 미리보기 중인 잠긴 색은 진짜 색으로 보여 준다.
	sb.bg_color = col if (previewing or not locked) else Color(col.darkened(0.5), 0.55)
	sb.set_border_width_all(4 if selected else 1)
	sb.border_color = Color(0, 0, 0, 0.4)
	if previewing:
		sb.set_border_width_all(4)
		sb.border_color = Color(0.45, 0.95, 1.0)
	elif selected:
		sb.border_color = CREAM
	b.add_theme_stylebox_override("normal", sb)
	var hover: StyleBoxFlat = sb.duplicate()
	hover.border_color = Color(1, 1, 1, 0.8)
	if not selected:
		hover.set_border_width_all(2)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void: _pick(key, idx))
	if locked:
		var face := Control.new()
		face.set_anchors_preset(Control.PRESET_FULL_RECT)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.draw.connect(func() -> void: _draw_lock(face, Vector2(35.0, 35.0)))
		b.add_child(face)
	return b


## 잠금 뱃지 — 자물쇠 하나. sc로 스와치/타일 크기에 맞춘다.
func _draw_lock(ci: CanvasItem, at: Vector2, sc := 1.0) -> void:
	var col := Color(1, 1, 1, 0.85)
	ci.draw_rect(Rect2(at + Vector2(-9.0, -2.0) * sc, Vector2(18.0, 15.0) * sc), col)
	ci.draw_arc(at + Vector2(0.0, -3.0) * sc, 6.0 * sc, PI, TAU, 10, col, 3.0 * sc)


## 이 옵션만 바꾼 미니 냥이를 그려주는 미리보기 타일 (이름은 희귀도 색).
func _make_style_tile(key: String, idx: int, opt: Dictionary, selected: bool,
		locked := false, previewing := false) -> Button:
	var rar := int(opt.get("r", 0))
	var b := Button.new()
	b.custom_minimum_size = Vector2(108.0, 124.0)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.bg_color = Color(CREAM, 0.12) if selected else Color(1, 1, 1, 0.05)
	sb.set_border_width_all(3 if selected else 1)
	if previewing:
		sb.bg_color = Color(0.45, 0.95, 1.0, 0.12)
		sb.set_border_width_all(3)
		sb.border_color = Color(0.45, 0.95, 1.0)
	elif selected:
		sb.border_color = CREAM
	elif rar > 0:
		sb.border_color = Color(CustomCat.RARITY_COLS[rar], 0.55)
	else:
		sb.border_color = Color(1, 1, 1, 0.2)
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
		# 잠긴 파츠는 회색 실루엣 — 단, 입혀 보는 중이면 제 색으로 보여 준다.
		Player.paint_cat(face, Vector2(54.0, 50.0), 52.0, 0.0, true, false,
				_skin(key, idx) if (previewing or not locked)
				else _shadow(_skin(key, idx)))
		if locked:
			_draw_lock(face, Vector2(88.0, 24.0), 0.9)
		var font := ThemeDB.fallback_font
		var w := font.get_string_size(opt_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		face.draw_string(font, Vector2((108.0 - w) / 2.0, 112.0), opt_name,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
			Color(0.45, 0.95, 1.0) if previewing
					else (Color(1, 1, 1, 0.35) if locked
					else (CREAM if selected else CustomCat.RARITY_COLS[rar]))))
	b.add_child(face)
	return b
