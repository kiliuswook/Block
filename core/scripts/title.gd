extends Node2D
## Title screen: pick a game mode with the buttons or the 1 / 2 keys,
## and pick / buy a cube-cat skin in the character row at the bottom.

const CREAM := Color("f4e3c8")
const GOLD_COL := Color(1.0, 0.85, 0.35)
const GEM_COL := Color(0.55, 0.85, 1.0)
const INK := Color("2a2230")

const SETTINGS_PANEL := preload("res://core/scripts/settings_panel.gd")
const TILE_SIZE := Vector2(128.0, 168.0)
const TILE_GAP := 14.0
const POPUP_SIZE := Vector2(620.0, 700.0)
const SHOP_TILE := Vector2(200.0, 210.0)
const STAT_ROWS := [["이동", "speed"], ["점프", "jump"], ["대시", "dash"],
		["무게", "weight"], ["밀기", "push"]]

@onready var escape_btn: Button = $UI/EscapeBtn
@onready var endless_btn: Button = $UI/EndlessBtn
@onready var versus_btn: Button = $UI/VersusBtn
@onready var classic_btn: Button = $UI/ClassicBtn
@onready var escape2_btn: Button = $UI/Escape2Btn
@onready var endless2_btn: Button = $UI/Endless2Btn

# 레이아웃은 뷰포트 크기 기준으로 계산 — 모바일(세로 1080×1920)도 같은 코드를 쓴다.
var vw := 1920.0
var vh := 1080.0
var tile_y := 780.0  # 캐릭터 타일 첫 줄 y (_build_character_row에서 계산)
var max_tiles_per_row := 99  # 모바일 타이틀이 줄바꿈을 위해 줄인다
var main_scene := "res://core/scenes/main.tscn"  # 플랫폼 타이틀이 교체 가능

var _tiles := {}  # cat id -> Button
var _currency_label: Label
var _toast: Label
var _toast_tween: Tween
var _popup: Control
var _popup_face: Control
var _popup_action: Button
var _popup_close: Button
var _popup_feed: Button
var _popup_cat: Dictionary = {}
var _settings: Control
var _shop: Control
var _shop_tiles := {}  # accessory id -> preview Control (for redraws)
var _boost_chips := {}  # boost id -> Button
var _shop_wallet: Label
var _bob := 0.0  # title cat idle bounce (affection level 5+)
var _ranks: Control
var _rank_tabs := {}  # mode key -> Button
var _rank_mode := "endless"
var _rank_list: VBoxContainer
var _rank_status: Label
var _nick_edit: LineEdit
var _replay_viewer: Control


func _ready() -> void:
	# 이 타이틀이 뜬 플랫폼을 개발용 상태로 기록 (플랫폼 타이틀은 super 후 덮어씀).
	preload("res://core/scripts/boot.gd").dev_platform = ""
	vw = get_viewport_rect().size.x
	vh = get_viewport_rect().size.y
	escape_btn.pressed.connect(func() -> void: _start(GameState.MODE_STORY))
	endless_btn.pressed.connect(func() -> void: _start(GameState.MODE_ENDLESS))
	versus_btn.pressed.connect(func() -> void: _start(GameState.MODE_VERSUS))
	classic_btn.pressed.connect(func() -> void: _start(GameState.MODE_CLASSIC))
	escape2_btn.pressed.connect(func() -> void: _start(GameState.MODE_STORY, true))
	endless2_btn.pressed.connect(func() -> void: _start(GameState.MODE_ENDLESS, true))
	_refresh_classic_desc()
	_refresh_story_desc()
	_build_currency_display()
	_build_character_row()
	_build_popup()
	_build_toast()
	_build_settings()
	_build_shop()
	_build_ranks()
	Ranks.board_loaded.connect(func(_ok: bool) -> void:
		if _ranks and _ranks.visible:
			_refresh_rank_list())
	Sfx.play_bgm("title")


## The selected cat bounces on the title once affection reaches level 5.
func _process(delta: float) -> void:
	if GameState.affection_level(GameState.selected_cat) >= 5:
		_bob += delta
		queue_redraw()


## Story button subtitle mirrors the saved progress.
func _refresh_story_desc() -> void:
	var total := StoryStages.TOTAL
	var desc: Label = $UI/EscapeDesc
	if GameState.story_stage >= total:
		desc.text = "전 스테이지 클리어! 처음부터 다시 도전할 수 있다"
	elif GameState.story_stage > 0:
		desc.text = "이어서 도전  —  STAGE %d / %d" % [GameState.story_stage + 1, total]


## Classic-mode subtitle carries the arcade high score.
func _refresh_classic_desc() -> void:
	if GameState.classic_best > 0:
		($UI/ClassicDesc as Label).text = \
				"고전 오락실 난이도 그대로 — 최고 기록  %d점" % GameState.classic_best


func _start(mode: int, split := false) -> void:
	Sfx.play("click")
	GameState.mode = mode
	GameState.split = split
	get_tree().change_scene_to_file(main_scene)


## 설정 버튼(좌상단) + 볼륨 설정 패널.
func _build_settings() -> void:
	var b := Button.new()
	b.text = "⚙ 설정"
	b.position = Vector2(30.0, 30.0)
	b.size = Vector2(150.0, 56.0)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void:
		Sfx.play("click")
		_settings.open())
	$UI.add_child(b)
	_settings = SETTINGS_PANEL.new()
	$UI.add_child(_settings)
	var shop_btn := Button.new()
	shop_btn.text = "★ 상점"
	shop_btn.position = Vector2(30.0, 100.0)
	shop_btn.size = Vector2(150.0, 56.0)
	shop_btn.add_theme_font_size_override("font_size", 24)
	shop_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	shop_btn.pressed.connect(func() -> void:
		Sfx.play("click")
		_open_shop())
	$UI.add_child(shop_btn)
	var rank_btn := Button.new()
	rank_btn.text = "♛ 랭킹"
	rank_btn.position = Vector2(30.0, 170.0)
	rank_btn.size = Vector2(150.0, 56.0)
	rank_btn.add_theme_font_size_override("font_size", 24)
	rank_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	rank_btn.pressed.connect(func() -> void:
		Sfx.play("click")
		_open_ranks())
	$UI.add_child(rank_btn)


func _settings_open() -> bool:
	return _settings != null and _settings.visible


func _unhandled_input(event: InputEvent) -> void:
	if _settings_open():
		if event is InputEventKey and event.pressed \
				and event.physical_keycode == KEY_ESCAPE:
			_settings.close()
		return
	if _shop and _shop.visible:
		if event is InputEventKey and event.pressed \
				and event.physical_keycode == KEY_ESCAPE:
			_close_shop()
		return
	if _replay_viewer and _replay_viewer.visible:
		if event is InputEventKey and event.pressed \
				and event.physical_keycode == KEY_ESCAPE:
			_replay_viewer.playing_back = false
			_replay_viewer.visible = false
		return
	if _ranks and _ranks.visible:
		if event is InputEventKey and event.pressed \
				and event.physical_keycode == KEY_ESCAPE:
			_ranks.visible = false
		return
	if _popup and _popup.visible:
		# The popup swallows mode hotkeys; Esc closes it.
		if event is InputEventKey and event.pressed \
				and event.physical_keycode == KEY_ESCAPE:
			_close_popup()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1, KEY_KP_1:
				_start(GameState.MODE_STORY)
			KEY_2, KEY_KP_2:
				_start(GameState.MODE_ENDLESS)
			KEY_3, KEY_KP_3:
				_start(GameState.MODE_VERSUS)
			KEY_4, KEY_KP_4:
				_start(GameState.MODE_CLASSIC)
			KEY_5, KEY_KP_5:
				_start(GameState.MODE_STORY, true)
			KEY_6, KEY_KP_6:
				_start(GameState.MODE_ENDLESS, true)


# --- Shop (accessories + run boosts) ------------------------------------------


## Code-built shop overlay: accessory tiles per slot plus one-run endless
## boosts. Sized off the viewport so portrait (mobile) and landscape both fit.
func _build_shop() -> void:
	_shop = Control.new()
	_shop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop.visible = false
	$UI.add_child(_shop)
	var dim := Button.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim_sb := StyleBoxFlat.new()
	dim_sb.bg_color = Color(0, 0, 0, 0.65)
	for st in ["normal", "hover", "pressed", "focus"]:
		dim.add_theme_stylebox_override(st, dim_sb)
	dim.pressed.connect(_close_shop)
	_shop.add_child(dim)
	var pw := minf(vw - 60.0, 940.0)
	var ph := minf(vh - 140.0, 980.0)
	var panel := PanelContainer.new()
	panel.position = (Vector2(vw, vh) - Vector2(pw, ph)) / 2.0
	panel.size = Vector2(pw, ph)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("1c1a26")
	box.set_corner_radius_all(18)
	box.set_border_width_all(3)
	box.border_color = Color(CREAM, 0.65)
	box.content_margin_left = 30.0
	box.content_margin_right = 30.0
	box.content_margin_top = 22.0
	box.content_margin_bottom = 22.0
	panel.add_theme_stylebox_override("panel", box)
	_shop.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := Label.new()
	title.text = "냥냥 상점"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", CREAM)
	v.add_child(title)
	_shop_wallet = Label.new()
	_shop_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_wallet.add_theme_font_size_override("font_size", 24)
	_shop_wallet.add_theme_color_override("font_color", GOLD_COL)
	v.add_child(_shop_wallet)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var per_row := maxi(1, int((pw - 60.0 + TILE_GAP) / (SHOP_TILE.x + TILE_GAP)))
	for slot: Array in [["head", "머리 장식"], ["neck", "목 장식"]]:
		list.add_child(_shop_header(str(slot[1])))
		var items := GameState.ACCESSORIES.filter(
				func(a: Dictionary) -> bool: return a.slot == slot[0])
		var row: HBoxContainer = null
		for i in items.size():
			if i % per_row == 0:
				row = HBoxContainer.new()
				row.add_theme_constant_override("separation", int(TILE_GAP))
				list.add_child(row)
			row.add_child(_make_shop_tile(items[i]))
	list.add_child(_shop_header("다음 판 부스트  ·  무한의 계단 1판 소모"))
	var boost_row := HBoxContainer.new()
	boost_row.add_theme_constant_override("separation", 14)
	list.add_child(boost_row)
	for b: Dictionary in GameState.BOOSTS:
		var chip := Button.new()
		chip.custom_minimum_size = Vector2((pw - 88.0) / 3.0, 128.0)
		chip.add_theme_font_size_override("font_size", 20)
		chip.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		chip.pressed.connect(_on_boost_chip.bind(b))
		boost_row.add_child(chip)
		_boost_chips[b.id] = chip
	var close := Button.new()
	close.text = "닫기"
	close.custom_minimum_size = Vector2(200.0, 52.0)
	close.add_theme_font_size_override("font_size", 22)
	close.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close.pressed.connect(_close_shop)
	var close_wrap := CenterContainer.new()
	close_wrap.add_child(close)
	v.add_child(close_wrap)


func _shop_header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	return l


func _make_shop_tile(acc: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = SHOP_TILE
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(14)
	sb.bg_color = Color(1, 1, 1, 0.05)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.18)
	b.add_theme_stylebox_override("normal", sb)
	var hover: StyleBoxFlat = sb.duplicate()
	hover.bg_color = Color(1, 1, 1, 0.12)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", sb)
	b.pressed.connect(_on_shop_item.bind(acc))
	var face := Control.new()
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.draw.connect(func() -> void: _draw_shop_tile(face, acc))
	b.add_child(face)
	_shop_tiles[acc.id] = face
	return b


func _draw_shop_tile(ci: Control, acc: Dictionary) -> void:
	# Preview: the cream cat modeling the item.
	var skin := {"body": Color("f4e3c8"), "ear": Color("d9a05c"), "acc": [acc]}
	Player.paint_cat(ci, Vector2(SHOP_TILE.x / 2.0, 84.0), 64.0, 0.0, true, false, skin)
	var font := ThemeDB.fallback_font
	_draw_center_text(ci, font, str(acc.name), 152.0, 20, Color.WHITE, SHOP_TILE.x)
	var owned: bool = acc.id in GameState.acc_owned
	var equipped: bool = GameState.acc_head == acc.id or GameState.acc_neck == acc.id
	if equipped:
		_draw_center_text(ci, font, "장착 중", 184.0, 18, CREAM, SHOP_TILE.x)
	elif owned:
		_draw_center_text(ci, font, "보유 · 눌러서 장착", 184.0, 16,
				Color(1, 1, 1, 0.6), SHOP_TILE.x)
	elif acc.price.type == "gold":
		_draw_center_text(ci, font, "%d G" % acc.price.amount, 184.0, 18, GOLD_COL,
				SHOP_TILE.x)
	else:
		_draw_center_text(ci, font, "◆ %d" % acc.price.amount, 184.0, 18, GEM_COL,
				SHOP_TILE.x)


func _on_shop_item(acc: Dictionary) -> void:
	if acc.id in GameState.acc_owned:
		Sfx.play("click")
		GameState.toggle_acc(str(acc.id))
	elif GameState.try_buy_acc(str(acc.id)):
		Sfx.play("buy")
		GameState.toggle_acc(str(acc.id))  # wear it right away
		_show_toast("%s 구매 완료!" % acc.name, CREAM)
	else:
		Sfx.play("error")
		_show_toast("골드가 부족해요!" if acc.price.type == "gold" else "보석이 부족해요!",
				Color(1.0, 0.55, 0.5))
		return
	_refresh_shop()
	_refresh_currency()
	_refresh_tiles()


func _on_boost_chip(boost: Dictionary) -> void:
	var had: bool = boost.id in GameState.pending_boosts
	if not GameState.toggle_boost(str(boost.id)):
		Sfx.play("error")
		_show_toast("골드가 부족해요!", Color(1.0, 0.55, 0.5))
		return
	Sfx.play("click" if had else "buy")
	_refresh_shop()
	_refresh_currency()


func _refresh_shop() -> void:
	_shop_wallet.text = "보유   %d G      ◆ %d" % [GameState.gold, GameState.gems]
	for id: String in _shop_tiles:
		_shop_tiles[id].queue_redraw()
	for b: Dictionary in GameState.BOOSTS:
		var chip: Button = _boost_chips[b.id]
		var pending: bool = b.id in GameState.pending_boosts
		chip.text = "%s  ·  %d G\n%s\n%s" % [b.name, b.price, b.desc,
				"준비 완료! (다시 누르면 환불)" if pending else "누르면 구매"]
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(12)
		sb.bg_color = Color(CREAM, 0.16) if pending else Color(1, 1, 1, 0.05)
		sb.set_border_width_all(2)
		sb.border_color = CREAM if pending else Color(1, 1, 1, 0.2)
		chip.add_theme_stylebox_override("normal", sb)
		var hover: StyleBoxFlat = sb.duplicate()
		hover.bg_color = Color(CREAM, 0.24) if pending else Color(1, 1, 1, 0.11)
		chip.add_theme_stylebox_override("hover", hover)
		chip.add_theme_stylebox_override("pressed", sb)


func _open_shop() -> void:
	_refresh_shop()
	_shop.visible = true


func _close_shop() -> void:
	_shop.visible = false
	queue_redraw()  # title cat may have changed outfit


# --- Rankings (per-mode leaderboards) -------------------------------------------


## Rankings overlay: one board per mode, my row highlighted, nickname editor.
## Works offline too — then it shows only the local records.
func _build_ranks() -> void:
	_ranks = Control.new()
	_ranks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ranks.visible = false
	$UI.add_child(_ranks)
	var dim := Button.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim_sb := StyleBoxFlat.new()
	dim_sb.bg_color = Color(0, 0, 0, 0.65)
	for st in ["normal", "hover", "pressed", "focus"]:
		dim.add_theme_stylebox_override(st, dim_sb)
	dim.pressed.connect(func() -> void: _ranks.visible = false)
	_ranks.add_child(dim)
	var pw := minf(vw - 60.0, 760.0)
	var ph := minf(vh - 140.0, 960.0)
	var panel := PanelContainer.new()
	panel.position = (Vector2(vw, vh) - Vector2(pw, ph)) / 2.0
	panel.size = Vector2(pw, ph)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("1c1a26")
	box.set_corner_radius_all(18)
	box.set_border_width_all(3)
	box.border_color = Color(CREAM, 0.65)
	box.content_margin_left = 28.0
	box.content_margin_right = 28.0
	box.content_margin_top = 20.0
	box.content_margin_bottom = 20.0
	panel.add_theme_stylebox_override("panel", box)
	_ranks.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := Label.new()
	title.text = "♛ 랭킹"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", CREAM)
	v.add_child(title)
	# Nickname row: shown on every board, editable here.
	var nick_row := HBoxContainer.new()
	nick_row.alignment = BoxContainer.ALIGNMENT_CENTER
	nick_row.add_theme_constant_override("separation", 10)
	v.add_child(nick_row)
	var nick_title := Label.new()
	nick_title.text = "내 이름"
	nick_title.add_theme_font_size_override("font_size", 20)
	nick_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	nick_row.add_child(nick_title)
	_nick_edit = LineEdit.new()
	_nick_edit.custom_minimum_size = Vector2(240.0, 44.0)
	_nick_edit.max_length = 12
	_nick_edit.add_theme_font_size_override("font_size", 20)
	nick_row.add_child(_nick_edit)
	var nick_save := Button.new()
	nick_save.text = "변경"
	nick_save.custom_minimum_size = Vector2(90.0, 44.0)
	nick_save.add_theme_font_size_override("font_size", 18)
	nick_save.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	nick_save.pressed.connect(func() -> void:
		Sfx.play("click")
		GameState.set_nickname(_nick_edit.text)
		_nick_edit.text = GameState.nickname
		_show_toast("이름이 '%s' (으)로 바뀌었어요!" % GameState.nickname, CREAM)
		_refresh_rank_list())
	nick_row.add_child(nick_save)
	# Mode tabs.
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	v.add_child(tabs)
	for entry: Array in [["story", "스토리"], ["endless", "무한의 계단"], ["classic", "클래식"]]:
		var b := Button.new()
		b.text = str(entry[1])
		b.custom_minimum_size = Vector2((pw - 80.0) / 3.0, 50.0)
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(_on_rank_tab.bind(str(entry[0])))
		tabs.add_child(b)
		_rank_tabs[entry[0]] = b
	_rank_status = Label.new()
	_rank_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_status.add_theme_font_size_override("font_size", 16)
	_rank_status.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	v.add_child(_rank_status)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	_rank_list = VBoxContainer.new()
	_rank_list.add_theme_constant_override("separation", 4)
	_rank_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rank_list)
	var close := Button.new()
	close.text = "닫기"
	close.custom_minimum_size = Vector2(200.0, 52.0)
	close.add_theme_font_size_override("font_size", 22)
	close.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close.pressed.connect(func() -> void: _ranks.visible = false)
	var wrap := CenterContainer.new()
	wrap.add_child(close)
	v.add_child(wrap)
	_replay_viewer = preload("res://core/scripts/replay_viewer.gd").new()
	$UI.add_child(_replay_viewer)


func _open_ranks() -> void:
	_nick_edit.text = GameState.nickname
	_ranks.visible = true
	_refresh_rank_list()
	Ranks.refresh()  # board_loaded will re-render with fresh data


func _on_rank_tab(mode_key: String) -> void:
	Sfx.play("click")
	_rank_mode = mode_key
	_refresh_rank_list()


func _refresh_rank_list() -> void:
	for tab_key: String in _rank_tabs:
		var b: Button = _rank_tabs[tab_key]
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		var active: bool = tab_key == _rank_mode
		sb.bg_color = Color(CREAM, 0.18) if active else Color(1, 1, 1, 0.05)
		sb.set_border_width_all(2)
		sb.border_color = CREAM if active else Color(1, 1, 1, 0.2)
		b.add_theme_stylebox_override("normal", sb)
		var hover: StyleBoxFlat = sb.duplicate()
		hover.bg_color = Color(CREAM, 0.24) if active else Color(1, 1, 1, 0.11)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", sb)
	for child in _rank_list.get_children():
		child.queue_free()
	var mine := GameState.player_id
	var local_v := Ranks.local_value(_rank_mode)
	var list := Ranks.entries(_rank_mode)
	if Ranks.online() and Ranks.busy and list.is_empty():
		_rank_status.text = "불러오는 중..."
		return
	var rank := Ranks.my_rank(_rank_mode)
	if not Ranks.online():
		# Pre-launch board: bot crowd + my real record mixed in.
		_rank_status.text = ("내 순위  %d위  ·  %s   (다른 유저는 임시 데이터)" \
				% [rank, Ranks.value_text(_rank_mode, local_v)]) if rank > 0 \
				else "아직 내 기록 없음 — 한 판 달리면 자동 등록!   (다른 유저는 임시 데이터)"
	else:
		_rank_status.text = ("내 순위  %d위  ·  %s" \
				% [rank, Ranks.value_text(_rank_mode, local_v)]) \
				if rank > 0 else ("아직 순위 없음 — 기록을 세우면 자동 등록!" if local_v <= 0
				else "등록 중... 잠시 후 새로고침해 보세요")
	if list.is_empty():
		_rank_list.add_child(_rank_row(0, "첫 기록의 주인공이 되어보자냥!", -1, false))
	for i in mini(list.size(), 50):
		var e: Dictionary = list[i]
		_rank_list.add_child(_rank_row(i + 1, str(e.get("name", "???")),
				int(e.get("v", 0)), str(e.get("id")) == mine, e))


func _rank_row(rank: int, name_text: String, v: int, mine: bool,
		entry: Dictionary = {}) -> Control:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(8)
	sb.bg_color = Color(CREAM, 0.14) if mine else Color(1, 1, 1, 0.04)
	if mine:
		sb.set_border_width_all(2)
		sb.border_color = Color(CREAM, 0.8)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 7.0
	sb.content_margin_bottom = 7.0
	row.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)
	var rank_l := Label.new()
	rank_l.text = ("%d위" % rank) if rank > 0 else ("내 기록" if v >= 0 else "")
	rank_l.custom_minimum_size.x = 64.0
	rank_l.add_theme_font_size_override("font_size", 18)
	rank_l.add_theme_color_override("font_color",
			GOLD_COL if rank in [1, 2, 3] else Color(1, 1, 1, 0.6))
	h.add_child(rank_l)
	var name_l := Label.new()
	name_l.text = name_text + ("   ◀ 나" if mine and rank > 0 else "")
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.add_theme_font_size_override("font_size", 18)
	name_l.add_theme_color_override("font_color", CREAM if mine else Color(1, 1, 1, 0.85))
	h.add_child(name_l)
	if v >= 0:
		var val_l := Label.new()
		val_l.text = Ranks.value_text(_rank_mode, v)
		val_l.add_theme_font_size_override("font_size", 18)
		val_l.add_theme_color_override("font_color", GOLD_COL)
		h.add_child(val_l)
	if not entry.is_empty() and Ranks.has_replay_for(_rank_mode, entry):
		var mode_key := _rank_mode  # captured: tab may change before the press
		var play := Button.new()
		play.text = "▶"
		play.custom_minimum_size = Vector2(52.0, 30.0)
		play.add_theme_font_size_override("font_size", 16)
		play.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		play.pressed.connect(func() -> void:
			Sfx.play("click")
			var rep: Dictionary = Ranks.replay_for(mode_key, entry)
			if rep.is_empty():
				_show_toast("리플레이를 불러올 수 없어요", Color(1.0, 0.55, 0.5))
				return
			_replay_viewer.open(rep, "%s  ·  %s" % [name_text,
					Ranks.value_text(mode_key, v)]))
		h.add_child(play)
	return row


# --- Character select ---------------------------------------------------------


func _build_character_row() -> void:
	var ui: CanvasLayer = $UI
	# 화면 폭에 맞춰 줄바꿈: 가로(1920)는 9칸 한 줄, 세로(1080)는 여러 줄.
	var fit := maxi(1, int((vw - 60.0 + TILE_GAP) / (TILE_SIZE.x + TILE_GAP)))
	var per_row := mini(mini(fit, max_tiles_per_row), GameState.CATS.size())
	var rows := ceili(GameState.CATS.size() / float(per_row))
	tile_y = vh - 300.0 - (rows - 1) * (TILE_SIZE.y + TILE_GAP)
	for r in rows:
		var chunk: Array = GameState.CATS.slice(r * per_row, (r + 1) * per_row)
		var total := chunk.size() * TILE_SIZE.x + (chunk.size() - 1) * TILE_GAP
		var x := (vw - total) / 2.0
		for cat in chunk:
			var tile := _make_tile(cat)
			tile.position = Vector2(x, tile_y + r * (TILE_SIZE.y + TILE_GAP))
			ui.add_child(tile)
			_tiles[cat.id] = tile
			x += TILE_SIZE.x + TILE_GAP


func _make_tile(cat: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = TILE_SIZE
	b.size = TILE_SIZE
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void: _on_tile_pressed(cat))
	# All visuals are custom-drawn on a child control.
	var face := Control.new()
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.draw.connect(func() -> void: _draw_tile(face, cat))
	b.add_child(face)
	_style_tile(b, cat)
	return b


func _style_tile(b: Button, cat: Dictionary) -> void:
	var selected: bool = GameState.selected_cat == cat.id
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(14)
	if selected:
		sb.bg_color = Color(CREAM, 0.14)
		sb.set_border_width_all(3)
		sb.border_color = CREAM
	else:
		sb.bg_color = Color(1, 1, 1, 0.05)
		sb.set_border_width_all(2)
		sb.border_color = Color(1, 1, 1, 0.18)
	b.add_theme_stylebox_override("normal", sb)
	var hover: StyleBoxFlat = sb.duplicate()
	hover.bg_color = Color(1, 1, 1, 0.12) if not selected else Color(CREAM, 0.2)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", sb)


func _draw_tile(ci: Control, cat: Dictionary) -> void:
	var unlocked: bool = GameState.is_unlocked(cat.id)
	var center := Vector2(TILE_SIZE.x / 2.0, 62.0)
	if unlocked:
		Player.paint_cat(ci, center, 68.0, 0.0, true, false, GameState.cat_skin(cat.id))
	else:
		# Dark silhouette + lock badge for locked cats.
		var shadow := {"body": Color(0.16, 0.15, 0.2), "ear": Color(0.11, 0.1, 0.14),
				"ink": Color(0.3, 0.29, 0.35)}
		Player.paint_cat(ci, center, 68.0, 0.0, true, false, shadow)
		_draw_lock(ci, center + Vector2(34.0, 24.0))
	var font := ThemeDB.fallback_font
	var name_col := Color.WHITE if unlocked else Color(1, 1, 1, 0.45)
	var tile_name := str(cat.name)
	if unlocked and GameState.affection_level(cat.id) >= 10:
		tile_name = "★" + tile_name
	_draw_center_text(ci, font, tile_name, 112.0, 22, name_col)
	if not unlocked:
		var u: Dictionary = cat.unlock
		match u.type:
			"gold":
				_draw_center_text(ci, font, "%d G" % u.amount, 144.0, 19, GOLD_COL)
			"gems":
				_draw_center_text(ci, font, "◆ %d" % u.amount, 144.0, 19, GEM_COL)
			"height":
				_draw_center_text(ci, font, "무한 %d층" % u.floors, 144.0, 16,
						Color(1, 1, 1, 0.55))
			"story":
				_draw_center_text(ci, font, "스토리 %d스테이지" % u.stage, 144.0, 16,
						Color(1, 1, 1, 0.55))
			"plays":
				_draw_center_text(ci, font, "%d판 플레이" % u.count, 144.0, 16,
						Color(1, 1, 1, 0.55))
	else:
		# Unlocked cats wear their trait tag; the selected one glows cream.
		var tag_col := CREAM if GameState.selected_cat == cat.id else Color(1, 1, 1, 0.5)
		_draw_center_text(ci, font, str(cat.get("trait", "")), 144.0, 16, tag_col)


func _draw_center_text(ci: Control, font: Font, text: String, y: float,
		size: int, col: Color, width: float = TILE_SIZE.x) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font, Vector2((width - w) / 2.0, y), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Maps a stat value onto 1–5 display pips. Multipliers (≈0.7–1.3) center on
## 3 pips at 1.0; the push stat is already a cell count and maps directly.
func _stat_pips(key: String, v: float) -> int:
	if key == "push":
		return clampi(int(v), 1, 5)
	return clampi(3 + roundi((v - 1.0) * 15.0), 1, 5)


func _draw_lock(ci: Control, at: Vector2) -> void:
	var col := Color(1.0, 0.9, 0.6, 0.9)
	ci.draw_rect(Rect2(at + Vector2(-8.0, -2.0), Vector2(16.0, 13.0)), col)
	ci.draw_arc(at + Vector2(0.0, -3.0), 5.5, PI, TAU, 10, col, 3.0)


func _on_tile_pressed(cat: Dictionary) -> void:
	Sfx.play("click")
	_open_popup(cat)


# --- Character info popup -----------------------------------------------------


func _build_popup() -> void:
	_popup = Control.new()
	_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup.visible = false
	$UI.add_child(_popup)
	# Dimmed backdrop; clicking it closes the popup.
	var dim := Button.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim_sb := StyleBoxFlat.new()
	dim_sb.bg_color = Color(0, 0, 0, 0.6)
	for st in ["normal", "hover", "pressed", "focus"]:
		dim.add_theme_stylebox_override(st, dim_sb)
	dim.pressed.connect(_close_popup)
	_popup.add_child(dim)
	var panel := Control.new()
	panel.position = (Vector2(vw, vh) - POPUP_SIZE) / 2.0
	panel.size = POPUP_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup.add_child(panel)
	_popup_face = Control.new()
	_popup_face.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_face.draw.connect(func() -> void: _draw_popup(_popup_face))
	panel.add_child(_popup_face)
	_popup_action = _make_popup_button(panel, true)
	_popup_action.pressed.connect(_on_popup_action)
	_popup_close = _make_popup_button(panel, false)
	_popup_close.text = "닫기"
	_popup_close.pressed.connect(_close_popup)
	_popup_feed = _make_popup_button(panel, false)
	_popup_feed.add_theme_font_size_override("font_size", 19)
	_popup_feed.pressed.connect(_on_popup_feed)


func _make_popup_button(panel: Control, accent: bool) -> Button:
	var b := Button.new()
	b.add_theme_font_size_override("font_size", 22)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.bg_color = Color(CREAM, 0.16) if accent else Color(1, 1, 1, 0.07)
	sb.set_border_width_all(2)
	sb.border_color = CREAM if accent else Color(1, 1, 1, 0.25)
	b.add_theme_stylebox_override("normal", sb)
	var hover: StyleBoxFlat = sb.duplicate()
	hover.bg_color = Color(CREAM, 0.28) if accent else Color(1, 1, 1, 0.14)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	panel.add_child(b)
	return b


func _open_popup(cat: Dictionary) -> void:
	_popup_cat = cat
	var unlocked: bool = GameState.is_unlocked(cat.id)
	var u: Dictionary = cat.unlock
	if unlocked:
		_popup_action.visible = GameState.selected_cat != cat.id
		_popup_action.text = "선택하기"
	elif u.type == "gold":
		_popup_action.visible = true
		_popup_action.text = "구매  %d G" % u.amount
	elif u.type == "gems":
		_popup_action.visible = true
		_popup_action.text = "구매  ◆ %d" % u.amount
	else:
		_popup_action.visible = false
	_refresh_feed_button()
	# Bottom row: action + close side by side, or close alone centered.
	var y := POPUP_SIZE.y - 70.0
	if _popup_action.visible:
		_popup_action.size = Vector2(240.0, 52.0)
		_popup_close.size = Vector2(160.0, 52.0)
		var total := 240.0 + 24.0 + 160.0
		_popup_action.position = Vector2((POPUP_SIZE.x - total) / 2.0, y)
		_popup_close.position = _popup_action.position + Vector2(240.0 + 24.0, 0.0)
	else:
		_popup_close.size = Vector2(200.0, 52.0)
		_popup_close.position = Vector2((POPUP_SIZE.x - 200.0) / 2.0, y)
	_popup.visible = true
	_popup_face.queue_redraw()


func _close_popup() -> void:
	_popup.visible = false


## Feed button doubles as the affection progress readout.
func _refresh_feed_button() -> void:
	var cat := _popup_cat
	if cat.is_empty() or not GameState.is_unlocked(cat.id):
		_popup_feed.visible = false
		return
	_popup_feed.visible = true
	_popup_feed.size = Vector2(400.0, 46.0)
	_popup_feed.position = Vector2((POPUP_SIZE.x - 400.0) / 2.0, POPUP_SIZE.y - 158.0)
	var to_next := GameState.snacks_to_next(str(cat.id))
	if to_next == 0:
		_popup_feed.text = "애정도 MAX  ·  최고의 단짝!"
		_popup_feed.disabled = true
	else:
		_popup_feed.text = "간식 주기  %d G   (다음 레벨까지 %d개)" \
				% [GameState.snack_price(str(cat.id)), to_next]
		_popup_feed.disabled = false


func _on_popup_feed() -> void:
	var cat := _popup_cat
	if cat.is_empty():
		return
	var before_level := GameState.affection_level(cat.id)
	var before_stage := GameState.aff_stage(cat.id)
	if GameState.feed_cat(str(cat.id)):
		var level := GameState.affection_level(cat.id)
		if GameState.aff_stage(cat.id) > before_stage:
			Sfx.play("record")
			_show_toast("%s (이)의 모습이 변했다!! Lv.%d" % [cat.name, level], GOLD_COL)
		elif level > before_level:
			Sfx.play("record")
			_show_toast("애정도 레벨 업!  Lv.%d — 능력 +%d%%" \
					% [level, roundi(GameState.affection_bonus(cat.id) * 100)],
					Color(0.96, 0.62, 0.7))
		else:
			Sfx.play("buy")
			_show_toast("%s (이)가 좋아한다냥! ♥" % cat.name, Color(0.96, 0.62, 0.7))
		_refresh_feed_button()
		_refresh_currency()
		_popup_face.queue_redraw()
		_refresh_tiles()
	else:
		Sfx.play("error")
		_show_toast("골드가 부족해요!", Color(1.0, 0.55, 0.5))


func _on_popup_action() -> void:
	var cat := _popup_cat
	if GameState.is_unlocked(cat.id):
		Sfx.play("click")
		GameState.select_cat(cat.id)
		_refresh_tiles()
		_close_popup()
		return
	var u: Dictionary = cat.unlock
	var wallet: int = GameState.gold if u.type == "gold" else GameState.gems
	if wallet < int(u.amount):
		Sfx.play("error")
		_show_toast("골드가 부족해요!" if u.type == "gold" else "보석이 부족해요!",
				Color(1.0, 0.55, 0.5))
		return
	if GameState.try_buy(cat.id):
		Sfx.play("buy")
		GameState.select_cat(cat.id)
		_show_toast("%s 냥이 영입 완료!" % cat.name, CREAM)
		_refresh_currency()
		_refresh_tiles()
		_close_popup()


func _draw_popup(ci: Control) -> void:
	var cat := _popup_cat
	if cat.is_empty():
		return
	var unlocked: bool = GameState.is_unlocked(cat.id)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1c1a26")
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(3)
	sb.border_color = Color(CREAM, 0.65)
	ci.draw_style_box(sb, Rect2(Vector2.ZERO, POPUP_SIZE))
	var font := ThemeDB.fallback_font
	var center := Vector2(POPUP_SIZE.x / 2.0, 118.0)
	if unlocked:
		Player.paint_cat(ci, center, 110.0, 0.0, true, false, GameState.cat_skin(cat.id))
	else:
		var shadow := {"body": Color(0.16, 0.15, 0.2), "ear": Color(0.11, 0.1, 0.14),
				"ink": Color(0.3, 0.29, 0.35)}
		Player.paint_cat(ci, center, 110.0, 0.0, true, false, shadow)
		_draw_lock(ci, center + Vector2(52.0, 38.0))
	var name_col := Color.WHITE if unlocked else Color(1, 1, 1, 0.6)
	var pop_name := str(cat.name)
	if unlocked and GameState.affection_level(cat.id) >= 10:
		pop_name = "★ %s ★" % pop_name
	_draw_center_text(ci, font, pop_name, 226.0, 34, name_col, POPUP_SIZE.x)
	_draw_center_text(ci, font, "「%s」" % cat.get("trait", ""), 262.0, 21,
			Color(CREAM, 0.95), POPUP_SIZE.x)
	# Stat bars.
	var stats: Dictionary = GameState.cat_stats(cat.id)
	for i in STAT_ROWS.size():
		var row_y := 302.0 + i * 40.0
		ci.draw_string(font, Vector2(150.0, row_y + 14.0), STAT_ROWS[i][0],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.8))
		var pips := _stat_pips(STAT_ROWS[i][1], stats.get(STAT_ROWS[i][1], 1.0))
		for p in 5:
			var r := Rect2(238.0 + p * 50.0, row_y, 42.0, 16.0)
			var col := Color(CREAM, 0.95) if p < pips else Color(1, 1, 1, 0.12)
			ci.draw_rect(r, col)
	# Affection hearts (snacks fed) — unlocked cats only.
	if unlocked:
		var level := GameState.affection_level(cat.id)
		var hearts := "♥".repeat(level) + "♡".repeat(10 - level)
		var line := "애정도 Lv.%d   %s" % [level, hearts]
		if level > 1:
			line += "   능력 +%d%%" % roundi(GameState.affection_bonus(cat.id) * 100)
		_draw_center_text(ci, font, line, 522.0, 20,
				Color(0.96, 0.62, 0.7), POPUP_SIZE.x)
	# Status / unlock condition line.
	var status := ""
	var status_col := Color(1, 1, 1, 0.7)
	var u: Dictionary = cat.unlock
	if unlocked:
		if GameState.selected_cat == cat.id:
			status = "장착 중"
			status_col = Color(CREAM, 0.95)
	else:
		match u.type:
			"gold":
				status = "보유 골드  %d G" % GameState.gold
				status_col = GOLD_COL
			"gems":
				status = "보유 보석  ◆ %d" % GameState.gems
				status_col = GEM_COL
			"height":
				status = "무한의 계단 %d층 도달 시 해금  (최고 %d층)" \
						% [u.floors, GameState.best_height]
			"story":
				status = "스토리 %d스테이지 클리어 시 해금  (현재 %d스테이지)" \
						% [u.stage, GameState.story_stage]
			"plays":
				status = "총 %d판 플레이 시 해금  (현재 %d판)" \
						% [u.count, GameState.games_played]
	if status != "":
		_draw_center_text(ci, font, status, POPUP_SIZE.y - 92.0, 19, status_col,
				POPUP_SIZE.x)


func _refresh_tiles() -> void:
	for id: String in _tiles:
		_style_tile(_tiles[id], GameState.get_cat(id))
		(_tiles[id].get_child(0) as Control).queue_redraw()
	queue_redraw()


# --- Currency + toast ---------------------------------------------------------


func _build_currency_display() -> void:
	_currency_label = Label.new()
	_currency_label.position = Vector2(vw - 500.0, 40.0)
	_currency_label.size = Vector2(440.0, 40.0)
	_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_currency_label.add_theme_font_size_override("font_size", 30)
	_currency_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_currency_label.add_theme_constant_override("outline_size", 8)
	$UI.add_child(_currency_label)
	_refresh_currency()


func _refresh_currency() -> void:
	_currency_label.text = "%d G      ◆ %d" % [GameState.gold, GameState.gems]
	_currency_label.add_theme_color_override("font_color", GOLD_COL)


func _build_toast() -> void:
	_toast = Label.new()
	_toast.position = Vector2((vw - 1000.0) / 2.0, vh - 125.0)
	_toast.size = Vector2(1000.0, 40.0)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 24)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.visible = false
	$UI.add_child(_toast)


func _show_toast(text: String, col: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", col)
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)


# --- Backdrop -----------------------------------------------------------------


func _draw() -> void:
	var vp := get_viewport_rect().size
	# Pit backdrop: light seeping down from above.
	draw_polygon(PackedVector2Array([
		Vector2.ZERO, Vector2(vp.x, 0), vp, Vector2(0, vp.y),
	]), PackedColorArray([
		Color("2a3040"), Color("2a3040"), Color("0b0c12"), Color("0b0c12"),
	]))
	var warm := Color(1.0, 0.95, 0.82, 0.08)
	var faded := Color(1.0, 0.95, 0.82, 0.0)
	draw_polygon(PackedVector2Array([
		Vector2(vp.x * 0.32, 0), Vector2(vp.x * 0.68, 0),
		Vector2(vp.x * 0.78, vp.y), Vector2(vp.x * 0.22, vp.y),
	]), PackedColorArray([warm, warm, faded, faded]))
	# Decorative tetromino scatter (viewport-relative so portrait works too).
	var decos := [
		["T", Vector2(0.146, 0.241)], ["L", Vector2(0.760, 0.204)],
		["S", Vector2(0.104, 0.519)], ["I", Vector2(0.792, 0.519)],
		["Z", Vector2(0.063, 0.352)], ["J", Vector2(0.885, 0.370)],
	]
	for d in decos:
		var color: Color = Board.COLORS[d[0]]
		color.a = 0.5
		for c in Board.SHAPES[d[0]][0]:
			var p := Vector2(d[1].x * vp.x, d[1].y * vp.y) + Vector2(c) * 44.0
			draw_rect(Rect2(p, Vector2(42.0, 42.0)), color)
			draw_rect(Rect2(p, Vector2(42.0, 42.0)),
					Color(1.0, 0.96, 0.84, 0.18), false, 2.0)
	# The cube cat perched above the title, wearing the selected skin.
	# High affection (level 5+) earns it a happy idle bounce.
	var cat_y := 100.0
	if GameState.affection_level(GameState.selected_cat) >= 5:
		cat_y += sin(_bob * 5.0) * 7.0
	Player.paint_cat(self, Vector2(vw / 2.0, cat_y), 96.0, 0.0, true, false,
			GameState.cat_skin(GameState.selected_cat))
	_draw_stat_line()


## One-line stat readout for the selected cat, above the character row.
func _draw_stat_line() -> void:
	var cat := GameState.get_cat(GameState.selected_cat)
	var stats: Dictionary = GameState.cat_stats(cat.id)
	var font := ThemeDB.fallback_font
	var parts: Array[String] = ["%s · %s" % [cat.name, cat.get("trait", "")]]
	for entry in STAT_ROWS:
		var pips := _stat_pips(entry[1], stats.get(entry[1], 1.0))
		parts.append("%s %s%s" % [entry[0], "●".repeat(pips), "○".repeat(5 - pips)])
	var text := "    ".join(parts)
	# 화면 폭에 넘치면 폰트를 줄여서 한 줄에 맞춘다 (세로 화면 대응).
	var size := 20
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	while w > vw - 40.0 and size > 12:
		size -= 1
		w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, Vector2((vw - w) / 2.0, tile_y - 12.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, 0.85))
