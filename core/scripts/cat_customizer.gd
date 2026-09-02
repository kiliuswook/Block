extends Control
## 냥이 꾸미기 패널 (UI 문서 21p) — 캐릭터 페이지 가운데 카드 안에 박혀 사는 UI.
## 왼쪽 세로 부위 목록 + 오른쪽 옵션 격자 + 아래 액션 바(랜덤 생성 · 초기화 · 저장).
## 프리뷰는 페이지 왼쪽 상세 카드가 맡는다 — 고를 때마다 changed로 알려 다시 그린다.
## 꾸미기는 "나만의 캐릭터"(커스텀 슬롯) 전용이고, 손댄 부위만 그 캐릭터 몫으로
## GameState.cat_custom에 **고르는 즉시** 저장된다 (저장 버튼은 확인 표시).

signal changed  # 선택이 바뀔 때마다 — 페이지가 프리뷰·타일을 다시 그린다
signal saved  # 저장 버튼 — 페이지가 토스트를 띄운다

const UiKit := preload("res://core/scripts/ui_kit.gd")
const CustomCat := preload("res://core/scripts/custom_cat.gd")
const CatSprite := preload("res://core/scripts/cat_sprite.gd")
const INK := UiKit.INK
const LIST_W := 190.0  # 왼쪽 부위 목록 폭
const ROW_H := 60.0  # 부위 목록 한 줄
const ROW_ICON := 46.0  # 줄 왼쪽 클로즈업 아이콘
const BAR_H := 62.0  # 아래 액션 바
const TILE := Vector2(112.0, 128.0)  # 모양 타일
const SWATCH := 72.0  # 색 스와치
## 흰 패널 위에서 읽히는 희귀도 색 (CustomCat.RARITY_COLS는 어두운 무대용이었다).
const RARITY_INK: Array[Color] = [
	Color(0.17, 0.16, 0.2, 0.75), UiKit.CYAN_DEEP, UiKit.PURPLE_DEEP, UiKit.GOLD_DEEP,
]
const ASK_PAD := 28.0  # 구매 확인창 카드 안쪽 여백
const ASK_GAP := 12.0  # 확인창 글 줄 간격
const ASK_BTN_H := 56.0  # 확인창 버튼 높이
const PREVIEW_COL := Color("2f9cc4")  # 잠긴 파츠 "입혀 보는 중" 표시

var _cat_id := "mycat"  # 지금 꾸미는 중인 캐릭터
var _cur := 0  # 현재 부위 줄 인덱스
var _groups: Array[Dictionary] = []  # 이 캐릭터에 적용되는 부위 묶음
var _preset_tab := false  # 0번 "원본 냥이" 프리셋 줄을 쓰는가
var _custom_slot := true  # "나만의 캐릭터"인가 — 파츠마다 해금이 걸린다
## 잠긴 파츠를 입혀 본 임시 선택 — 미리보기에만 쓰이고 저장되지 않는다.
var _preview_sel: Dictionary = {}
var _rows: Array[Button] = []
var _row_faces: Array[Control] = []
var _list: VBoxContainer
var _list_scroll: ScrollContainer
var _grid_scroll: ScrollContainer
var _panel: VBoxContainer
var _bar: HBoxContainer
var _flavor_lbl: Label
var _grid_w := 900.0
var _flavor := ""  # 마지막 선택/안내 한 줄
var _flavor_col := UiKit.MUTED
## 파츠 구매 확인창 — 잠긴 파츠를 누르면 값을 보여 주고 살지 묻는다.
## 꾸미기 패널은 캐릭터 카드 안쪽 한 칸이라 좁다 — 확인창은 패널이 아니라
## **화면 전체**를 덮는 제 CanvasLayer 위에 서고, 카드 높이는 글 줄 수를 재서 정한다.
var _ask_layer: CanvasLayer
var _ask: Control
var _ask_title: Label  # 「이름」을 n G에 살까냥?
var _ask_hint: Label  # 원래 어느 냥이의 파츠였나 (없으면 접는다)
var _ask_wallet: Label  # 가진 골드/캔
var _ask_buy: Button
var _ask_no: Button
var _ask_key := ""
var _ask_idx := -1
var _ask_rect := Rect2()  # 확인창 카드 자리 (_layout_ask가 재서 넣는다)


func _ready() -> void:
	# 카드 배경·제목은 페이지가 그린다 — 여기서는 내용물만 얹는다.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list_scroll = ScrollContainer.new()
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_list_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.add_child(_list)
	_grid_scroll = ScrollContainer.new()
	_grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_grid_scroll)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 14)
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_scroll.add_child(_panel)
	# 마지막으로 고른 파츠 한 줄 (희귀도 색 / 잠금 안내).
	_flavor_lbl = Label.new()
	_flavor_lbl.clip_text = true
	_flavor_lbl.add_theme_font_size_override("font_size", 17)
	add_child(_flavor_lbl)
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 12)
	_bar.alignment = BoxContainer.ALIGNMENT_END
	add_child(_bar)
	var rnd := _bar_btn(tr("CC_RANDOM"), UiKit.CYAN_DEEP)
	rnd.pressed.connect(_randomize_all)
	_bar.add_child(rnd)
	var rst := _bar_btn(tr("CC_RESET"), Color("c9c6d0"))
	rst.pressed.connect(_reset_all)
	_bar.add_child(rst)
	var ok := Button.new()
	ok.text = tr("CC_SAVE")
	ok.custom_minimum_size = Vector2(190.0, 56.0)
	UiKit.style_button(ok, UiKit.GOLD, UiKit.GOLD_DEEP, INK, 24, 16)
	ok.pressed.connect(func() -> void:
		Sfx.play("record")
		Achv.unlock(Achv.CUSTOM_CAT)
		_flavor = tr("CC_SAVED")
		_flavor_col = UiKit.GOLD_DEEP
		_refresh_flavor()
		saved.emit())
	_bar.add_child(ok)
	_build_ask()
	_flavor = tr("CC_FLAVOR_WELCOME")
	_flavor_col = UiKit.MUTED
	_refresh_flavor()


## 패널이 앉을 자리 (가운데 카드 안쪽) — 페이지가 카드 크기를 정하고 부른다.
func set_area(rect: Rect2) -> void:
	position = rect.position
	size = rect.size
	var grid_h := rect.size.y - BAR_H - 34.0
	_list_scroll.position = Vector2.ZERO
	# 부위 목록은 줄 단위로 끊는다 — 반쯤 잘린 줄이 보이면 고장 난 것처럼 보인다.
	var step := ROW_H + 8.0  # 줄 + VBox separation
	_list_scroll.size = Vector2(LIST_W,
			maxf(step, floorf((grid_h + 8.0) / step) * step - 8.0))
	var gx := LIST_W + 22.0
	_grid_w = rect.size.x - gx
	_grid_scroll.position = Vector2(gx, 0.0)
	_grid_scroll.size = Vector2(_grid_w, grid_h)
	_panel.custom_minimum_size = Vector2(_grid_w, 0.0)
	_flavor_lbl.position = Vector2(0.0, grid_h + 2.0)
	_flavor_lbl.size = Vector2(rect.size.x, 26.0)
	_bar.position = Vector2(0.0, rect.size.y - BAR_H)
	_bar.size = Vector2(rect.size.x, BAR_H)
	_layout_ask()
	_rebuild_panel()


## 이 냥이를 패널에 펼친다. 같은 대상이면 다시 짓지 않고 새로 그리기만 한다.
func open(cat_id: String) -> void:
	# 꾸미기는 "나만의 캐릭터" 슬롯 전용 — 디자인 냥이는 컨셉 시트 원본 그대로.
	if not GameState.is_custom_cat(cat_id):
		return
	if cat_id == _cat_id and not _rows.is_empty():
		_refresh()
		return
	_cat_id = cat_id
	_cur = 0
	_preview_sel.clear()
	_build_rows()
	_refresh()


func target() -> String:
	return _cat_id


func _char_id() -> String:
	return str(GameState.get_cat(_cat_id).get("char", "char01"))


# --- 왼쪽 부위 목록 --------------------------------------------------------------
## 이 캐릭터에 실제로 반영되는 부위만 줄로 세운다. 시트 그림으로 그리는 냥이는
## 레이어 색만, 나만의 캐릭터는 디자인 냥이에게서 빌려 온 파츠만 다룬다.
## 부위는 CustomCat.groups_all() 단위 — 한 줄 안에서 모양과 색이 함께 나온다.


func _build_rows() -> void:
	var sprite := CatSprite.has(_char_id())
	_custom_slot = GameState.is_custom_cat(_cat_id)
	_preset_tab = not sprite
	_groups.clear()
	for group in CustomCat.groups_all():
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
	for b in _rows:
		_list.remove_child(b)
		b.queue_free()
	_rows.clear()
	_row_faces.clear()
	if _preset_tab:
		_add_row(tr("CC_PRESET"), 0, {})
	for i in _groups.size():
		_add_row(tr(str(_groups[i].name)), i + (1 if _preset_tab else 0), _groups[i])


## 부위 줄 하나 — 왼쪽에 그 부위만 확대한 클로즈업, 오른쪽에 이름.
func _add_row(label: String, i: int, group: Dictionary) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(LIST_W, ROW_H)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void:
		Sfx.play("click")
		_cur = i
		_refresh())
	var face := Control.new()
	face.position = Vector2(8.0, (ROW_H - ROW_ICON) / 2.0)
	face.size = Vector2(ROW_ICON, ROW_ICON)
	face.clip_contents = true  # 클로즈업 — 부위 밖은 잘라 낸다
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.draw.connect(func() -> void: _draw_row_icon(face, group))
	b.add_child(face)
	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.position = Vector2(ROW_ICON + 16.0, 0.0)
	name_lbl.size = Vector2(LIST_W - ROW_ICON - 24.0, ROW_H)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(name_lbl)
	_list.add_child(b)
	_rows.append(b)
	_row_faces.append(face)


## 줄 아이콘: 부위 그룹이면 그 자리를 확대해, 프리셋 줄이면 전신을.
func _draw_row_icon(face: Control, group: Dictionary) -> void:
	var mid := Vector2(ROW_ICON, ROW_ICON) / 2.0
	if group.is_empty():
		Player.paint_cat(face, mid + Vector2(0.0, 2.0), ROW_ICON * 0.8, 0.0,
				true, false, _skin())
		return
	var s := ROW_ICON / maxf(0.1, float(group.zoom))
	Player.paint_cat(face, mid - Vector2(group.at) * s, s, 0.0, true, false, _skin())


func _restyle_rows() -> void:
	for i in _rows.size():
		var b := _rows[i]
		if i == _cur:
			UiKit.style_button(b, UiKit.CYAN, UiKit.CYAN_DEEP, INK, 18, 14)
		else:
			UiKit.style_button(b, UiKit.WHITE, Color("c9c6d0"), Color(INK, 0.75),
					18, 14)
		(b.get_child(1) as Label).add_theme_color_override("font_color",
				INK if i == _cur else Color(INK, 0.75))


# --- 오른쪽 옵션 격자 -------------------------------------------------------------


## 현재 캐릭터의 파츠 + 저장된 커스터마이징(+ 미리보기용 임시 선택 하나).
func _skin(extra_key := "", extra_idx := 0) -> Dictionary:
	var sel: Dictionary = GameState.custom_sel(_cat_id).duplicate()
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


func _bar_btn(text: String, accent: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(190.0, 56.0)
	UiKit.style_button(b, UiKit.WHITE, accent, INK, 22, 16)
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
	GameState.set_custom_all(_cat_id, sel)
	Achv.unlock(Achv.CUSTOM_CAT)
	_flavor = tr("CC_FLAVOR_RANDOM")
	_flavor_col = UiKit.GOLD_DEEP
	_refresh()
	changed.emit()


func _reset_all() -> void:
	_preview_sel.clear()
	Sfx.play("click")
	GameState.set_custom_all(_cat_id, {})
	_flavor = tr("CC_FLAVOR_RESET")
	_flavor_col = UiKit.MUTED
	_refresh()
	changed.emit()


func _refresh() -> void:
	_restyle_rows()
	for f in _row_faces:
		f.queue_redraw()
	_refresh_flavor()
	_rebuild_panel()


func _refresh_flavor() -> void:
	if _flavor_lbl == null:
		return
	# 잠긴 파츠를 입혀 보는 중이면 그 사실을 우선으로 알린다 (저장되지 않는다).
	if not _preview_sel.is_empty():
		_flavor_lbl.text = "%s      %s" % [
				tr("CC_PREVIEW_ON").format({"n": _preview_sel.size()}), _flavor]
		_flavor_lbl.add_theme_color_override("font_color", PREVIEW_COL)
		return
	_flavor_lbl.text = _flavor
	_flavor_lbl.add_theme_color_override("font_color", _flavor_col)


## 선택한 부위 하나를 통째로 편친다 — 모양 타일과 색 스와치가 한 화면에 같이 온다.
func _rebuild_panel() -> void:
	if _panel == null:
		return
	for c in _panel.get_children():
		_panel.remove_child(c)
		c.queue_free()
	if _preset_tab and _cur == 0:
		var grid := _section(tr("CC_PRESET"), TILE.x + 8.0)
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
		var picked: int = GameState.custom_idx(_cat_id, key)
		# 잠긴 파츠를 입혀 보는 중이면 그쪽이 지금 모습이다.
		if _preview_sel.has(key):
			picked = int(_preview_sel[key])
		var idxs: Array = range(CustomCat.option_count(part))
		if _custom_slot:
			idxs = CustomCat.my_options(key)
		var color: bool = part.get("type") == "color"
		var grid := _section(tr(str(part.name)),
				(SWATCH + 10.0) if color else (TILE.x + 10.0))
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
	head.add_theme_font_size_override("font_size", 17)
	head.add_theme_color_override("font_color", UiKit.MUTED)
	_panel.add_child(head)
	var grid := GridContainer.new()
	grid.columns = maxi(1, int((_grid_w - 18.0) / cell))
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
		_open_buy(key, idx)
		return
	var part := CustomCat.get_part(key)
	# 같은 부위에 걸려 있던 미리보기는 진짜 선택이 덮어쓴다.
	_preview_sel.erase(key)
	if part.get("type") == "color":
		Sfx.play("click")
		_flavor = tr("CC_FLAVOR_COLOR")
		_flavor_col = UiKit.MUTED
	else:
		var opt: Dictionary = (part.opts as Array)[idx]
		var r := int(opt.get("r", 0))
		Sfx.play("record" if r >= 3 else ("buy" if r >= 2 else "click"))
		_flavor = "[%s] %s — %s" % [tr(CustomCat.RARITY_NAMES[r]), opt.name,
				str(opt.get("d", ""))]
		_flavor_col = RARITY_INK[r]
	GameState.set_custom_part(_cat_id, key, idx)
	Achv.unlock(Achv.CUSTOM_CAT)  # 업적: 부위를 하나라도 바꿔 저장
	_refresh()
	changed.emit()


## 잠긴 옵션의 값 한 조각 — 유니크 파츠는 캔, 나머지는 골드로 표기한다.
func _price_text(key: String, idx: int) -> String:
	var n := _gold(GameState.part_price(key, idx))
	return tr("CC_PRICE_CAN").format({"cans": n}) if GameState.part_can(key, idx) \
			else tr("CC_PRICE").format({"gold": n})


## 잠긴 옵션 한 줄 안내 — 값과, 원래 어느 냥이의 파츠였는지.
func _lock_text(key: String, idx: int) -> String:
	var line := _price_text(key, idx)
	var hint := GameState.part_unlock_hint(key, idx)
	if not hint.is_empty():
		var who := tr(str(GameState.get_cat(str(hint.cat)).get("name", "")))
		line += "   ·   " + tr("CC_FROM").format({"name": who})
	return line


## 1,200 처럼 세 자리마다 끊어 준다.
func _gold(n: int) -> String:
	var t := str(maxi(n, 0))
	var out := ""
	for i in t.length():
		if i > 0 and (t.length() - i) % 3 == 0:
			out += ","
		out += t[i]
	return out


# --- 파츠 구매 -------------------------------------------------------------------
## 잠긴 파츠를 누르면 그 모습을 입혀 보여 주면서(프리뷰) 살지 묻는다.


func _build_ask() -> void:
	# 패널 안에 갇히면 카드가 뒤 타일과 겹쳐 보인다 — 화면 전체를 덮는 층에 올린다.
	_ask_layer = CanvasLayer.new()
	_ask_layer.layer = 6  # 상단 고정 유저 HUD(5) 위
	_ask_layer.visible = false
	add_child(_ask_layer)
	_ask = Control.new()
	_ask_layer.add_child(_ask)
	_ask.draw.connect(func() -> void:
		_ask.draw_rect(Rect2(Vector2.ZERO, _ask.size), Color(0.09, 0.13, 0.18, 0.55))
		UiKit.panel_box(UiKit.WHITE, 22, 0.0).draw(_ask.get_canvas_item(), _ask_rect))
	_ask_title = _ask_label(22, INK)
	_ask_hint = _ask_label(17, UiKit.MUTED)
	_ask_wallet = _ask_label(18, UiKit.GOLD_DEEP)
	_ask_buy = Button.new()
	UiKit.style_button(_ask_buy, UiKit.GOLD, UiKit.GOLD_DEEP, INK, 21, 14)
	_ask_buy.pressed.connect(_confirm_buy)
	_ask.add_child(_ask_buy)
	_ask_no = Button.new()
	_ask_no.text = tr("UI_CANCEL")
	UiKit.btn_ghost(_ask_no, 21)
	_ask_no.pressed.connect(_close_ask)
	_ask.add_child(_ask_no)
	# 캐릭터 페이지를 닫으면 확인창도 같이 내린다 (CanvasLayer는 부모가 숨어도 그려진다).
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_close_ask())
	_layout_ask()


func _ask_label(fs: int, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	_ask.add_child(l)
	return l


## 줄 수를 재서 카드 높이를 정한다 — 글이 길어져도 버튼 줄과 겹치지 않게.
func _ask_card() -> Rect2:
	var vp := _ask.size if _ask.size.x > 0.0 else Vector2(1080.0, 1920.0)
	var w := clampf(vp.x - 120.0, 320.0, 560.0)
	var inner := w - ASK_PAD * 2.0
	var h := ASK_PAD
	for lbl: Label in [_ask_title, _ask_hint, _ask_wallet]:
		if lbl.text.is_empty():
			continue
		lbl.size.x = inner
		h += _ask_text_h(lbl) + ASK_GAP
	h += ASK_BTN_H + ASK_PAD
	return Rect2(((vp - Vector2(w, h)) / 2.0).floor(), Vector2(w, h))


func _ask_text_h(lbl: Label) -> float:
	return float(maxi(lbl.get_line_count(), 1)) * float(lbl.get_line_height())


func _layout_ask() -> void:
	if _ask == null:
		return
	_ask.position = Vector2.ZERO
	_ask.size = _ask.get_viewport_rect().size
	_ask_rect = _ask_card()
	var card := _ask_rect
	var inner := card.size.x - ASK_PAD * 2.0
	var y := card.position.y + ASK_PAD
	for lbl: Label in [_ask_title, _ask_hint, _ask_wallet]:
		lbl.visible = not lbl.text.is_empty()
		if not lbl.visible:
			continue
		lbl.position = Vector2(card.position.x + ASK_PAD, y)
		lbl.size = Vector2(inner, _ask_text_h(lbl))
		y += lbl.size.y + ASK_GAP
	var bw := (inner - 16.0) / 2.0
	var by := card.position.y + card.size.y - ASK_PAD - ASK_BTN_H
	_ask_buy.position = Vector2(card.position.x + ASK_PAD, by)
	_ask_buy.size = Vector2(bw, ASK_BTN_H)
	_ask_no.position = Vector2(card.position.x + ASK_PAD + bw + 16.0, by)
	_ask_no.size = Vector2(bw, ASK_BTN_H)
	_ask.queue_redraw()


func _open_buy(key: String, idx: int) -> void:
	var part := CustomCat.get_part(key)
	if part.is_empty():
		return
	_ask_key = key
	_ask_idx = idx
	var price := GameState.part_price(key, idx)
	var name := tr(str(part.name)) if part.get("type") == "color" 			else str((part.opts as Array)[idx].name)
	var cans_buy := GameState.part_can(key, idx)
	# 값은 제목 줄이 말한다 — 가운데 줄은 "원래 어느 냥이의 파츠였나"만 (중복 제거).
	_ask_title.text = tr("CC_BUY_ASK_CAN").format({"name": name, "cans": _gold(price)}) 			if cans_buy else tr("CC_BUY_ASK").format({"name": name, "gold": _gold(price)})
	var hint := GameState.part_unlock_hint(key, idx)
	_ask_hint.text = "" if hint.is_empty() else tr("CC_FROM").format(
			{"name": tr(str(GameState.get_cat(str(hint.cat)).get("name", "")))})
	var afford := GameState.can_afford_part(key, idx)
	_ask_wallet.text = tr("CC_WALLET_CAN").format({"cans": _gold(GameState.cans)}) 			if cans_buy else tr("CC_WALLET").format({"gold": _gold(GameState.gold)})
	_ask_wallet.add_theme_color_override("font_color",
			(UiKit.CAN_DEEP if cans_buy else UiKit.GOLD_DEEP) if afford else UiKit.RED_DEEP)
	_ask_buy.text = tr("CC_BUY")
	_ask_buy.disabled = not afford
	# 유니크 파츠는 캔으로 산다 — 확인 버튼 색까지 갈라 둔다.
	UiKit.style_button(_ask_buy,
			UiKit.CAN if cans_buy else UiKit.GOLD,
			UiKit.CAN_DEEP if cans_buy else UiKit.GOLD_DEEP, INK, 21, 14)
	_ask_layer.visible = true
	_layout_ask()
	# 사기 전에 입혀 본 모습을 보여 준다 (저장되지 않는다).
	_preview_sel[key] = idx
	Sfx.play("click")
	_refresh()
	changed.emit()


func _close_ask() -> void:
	if _ask_layer == null or not _ask_layer.visible:
		return
	_ask_layer.visible = false
	if _ask_key != "":
		_preview_sel.erase(_ask_key)
	_ask_key = ""
	_ask_idx = -1
	_refresh()
	changed.emit()


func _confirm_buy() -> void:
	var key := _ask_key
	var idx := _ask_idx
	if key == "" or idx < 0:
		_close_ask()
		return
	var price := GameState.part_price(key, idx)
	var cans_buy := GameState.part_can(key, idx)
	if not GameState.buy_part(key, idx):
		Sfx.play("error")
		_flavor = tr("CC_NO_CANS").format({"cans": _gold(price)}) if cans_buy \
				else tr("CC_NO_GOLD").format({"gold": _gold(price)})
		_flavor_col = UiKit.RED_DEEP
		_refresh_flavor()
		return
	Sfx.play("buy")
	_ask_layer.visible = false
	_ask_key = ""
	_ask_idx = -1
	_preview_sel.erase(key)
	# 산 파츠는 그 자리에서 바로 입는다.
	GameState.set_custom_part(_cat_id, key, idx)
	Achv.unlock(Achv.CUSTOM_CAT)
	_flavor = tr("CC_BOUGHT_CAN").format({"cans": _gold(price)}) if cans_buy \
			else tr("CC_BOUGHT").format({"gold": _gold(price)})
	_flavor_col = UiKit.CAN_DEEP if cans_buy else UiKit.GOLD_DEEP
	_refresh()
	changed.emit()


## 페이지 프리뷰가 쓰는 스킨 — 잠긴 파츠를 입혀 보는 중이면 그 모습이다.
func preview_skin() -> Dictionary:
	return _skin()


func previewing() -> bool:
	return not _preview_sel.is_empty()


# --- 옵션 타일 -------------------------------------------------------------------


## 디자인 캐릭터 한 마리를 통째로 불러오는 타일.
func _make_preset_tile(char_id: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = TILE
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var locked := _preset_locked(char_id)
	UiKit.style_button(b, UiKit.WHITE, Color("c9c6d0"), INK, 15, 14)
	b.pressed.connect(func() -> void: _load_preset(char_id))
	var face := Control.new()
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.draw.connect(func() -> void:
		var skin := {"parts": CustomCat.char_parts(char_id, _preset_tier(char_id))}
		Player.paint_cat(face, Vector2(TILE.x / 2.0, 54.0), 56.0, 0.0, true, false,
				_shadow(skin) if locked else skin)
		if locked:
			_draw_lock(face, Vector2(TILE.x - 22.0, 24.0), 0.9)
		var font := ThemeDB.fallback_font
		var label := tr(str((CustomCat.CHARS[char_id] as Dictionary).get("name",
				char_id)))
		var fs := UiKit.fit_size(font, label, TILE.x - 10.0, 15)
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		face.draw_string(font, Vector2((TILE.x - w) / 2.0, TILE.y - 14.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				UiKit.MUTED if locked else Color(INK, 0.85)))
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
		_flavor_col = UiKit.RED_DEEP
		_refresh_flavor()
		return
	Sfx.play("record")
	_preview_sel.clear()
	# 프리셋도 산 파츠까지만 가져온다 — 안 산 부위는 지금 모습 그대로 남는다.
	var want := CustomCat.char_selection(char_id, _preset_tier(char_id))
	var got := GameState.owned_selection(_cat_id, want)
	GameState.set_custom_all(_cat_id, got)
	var skipped := want.size() - got.size()
	_flavor = tr("CC_FLAVOR_PRESET") if skipped <= 0 			else "%s   %s" % [tr("CC_FLAVOR_PRESET"),
					tr("CC_PRESET_LOCKED").format({"n": skipped})]
	_flavor_col = UiKit.GOLD_DEEP
	_refresh()
	changed.emit()


func _make_swatch(key: String, idx: int, col: Color, selected: bool,
		locked := false, previewing := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(SWATCH, SWATCH)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# 미리보기 중인 잠긴 색은 진짜 색으로 보여 준다.
	var face_col := col if (previewing or not locked) else Color("dfe4ea")
	var deep := PREVIEW_COL if previewing \
			else (UiKit.GOLD_DEEP if selected else Color("c9c6d0"))
	UiKit.style_button(b, face_col, deep, INK, 15, 14)
	b.pressed.connect(func() -> void: _pick(key, idx))
	var face := Control.new()
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.draw.connect(func() -> void:
		if selected or previewing:
			# 고른 색은 안쪽에 체크 링을 둘러 한눈에 보이게.
			face.draw_arc(Vector2(SWATCH, SWATCH) / 2.0, SWATCH * 0.32, 0.0, TAU, 28,
					PREVIEW_COL if previewing else UiKit.WHITE, 4.0)
		if locked:
			_draw_lock(face, Vector2(SWATCH / 2.0, SWATCH / 2.0 - 8.0), 1.0,
					GameState.part_can(key, idx))
			_draw_price(face, Vector2(8.0, SWATCH - 10.0), key, idx, 12))
	b.add_child(face)
	return b


## 잠긴 옵션의 값 — 골드는 금색, 유니크 파츠는 캔 아이콘 + 은빛 글씨.
func _draw_price(ci: CanvasItem, at: Vector2, key: String, idx: int,
		fs := 13) -> void:
	if not GameState.part_can(key, idx):
		ci.draw_string(ThemeDB.fallback_font, at, _price_text(key, idx),
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.GOLD_DEEP)
		return
	UiKit.can_icon(ci, at + Vector2(fs * 0.4, -fs * 0.35), fs * 1.15)
	ci.draw_string(ThemeDB.fallback_font, at + Vector2(fs, 0.0),
			str(GameState.part_price(key, idx)),
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.CAN_DEEP)


## 잠금 뱃지 — 자물쇠 하나. sc로 스와치/타일 크기에 맞춘다.
## 유니크 파츠는 캔으로만 열리므로 자물쇠도 은빛이다.
func _draw_lock(ci: CanvasItem, at: Vector2, sc := 1.0, can_lock := false) -> void:
	var col := UiKit.CAN_DEEP if can_lock else UiKit.GOLD_DEEP
	ci.draw_rect(Rect2(at + Vector2(-9.0, -2.0) * sc, Vector2(18.0, 15.0) * sc), col)
	ci.draw_arc(at + Vector2(0.0, -3.0) * sc, 6.0 * sc, PI, TAU, 10, col, 3.0 * sc)


## 이 옵션만 바꾼 미니 냥이를 그려주는 미리보기 타일 (이름은 희귀도 색).
func _make_style_tile(key: String, idx: int, opt: Dictionary, selected: bool,
		locked := false, previewing := false) -> Button:
	var rar := int(opt.get("r", 0))
	var b := Button.new()
	b.custom_minimum_size = TILE
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var deep := PREVIEW_COL if previewing \
			else (UiKit.GOLD_DEEP if selected
			else (Color(RARITY_INK[rar], 0.6) if rar > 0 else Color("c9c6d0")))
	UiKit.style_button(b, Color("fff1cf") if selected else UiKit.WHITE, deep,
			INK, 15, 14)
	b.pressed.connect(func() -> void: _pick(key, idx))
	var face := Control.new()
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var opt_name := ("★" if rar >= 3 else "") + str(opt.name)
	face.draw.connect(func() -> void:
		# 잠긴 파츠는 회색 실루엣 — 단, 입혀 보는 중이면 제 색으로 보여 준다.
		Player.paint_cat(face, Vector2(TILE.x / 2.0, 52.0), 56.0, 0.0, true, false,
				_skin(key, idx) if (previewing or not locked)
				else _shadow(_skin(key, idx)))
		if locked:
			_draw_lock(face, Vector2(TILE.x - 22.0, 24.0), 0.9,
					GameState.part_can(key, idx))
			_draw_price(face, Vector2(9.0, 24.0), key, idx)
		var font := ThemeDB.fallback_font
		var fs := UiKit.fit_size(font, opt_name, TILE.x - 10.0, 15)
		var w := font.get_string_size(opt_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		face.draw_string(font, Vector2((TILE.x - w) / 2.0, TILE.y - 14.0), opt_name,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				PREVIEW_COL if previewing
						else (UiKit.MUTED if locked else RARITY_INK[rar])))
	b.add_child(face)
	return b
