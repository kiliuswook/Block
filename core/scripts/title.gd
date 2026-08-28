extends Node2D
## Title screen: pick a game mode with the buttons or the 1 / 2 keys,
## and pick / buy a cube-cat skin in the character row at the bottom.

const UiKit := preload("res://core/scripts/ui_kit.gd")

const CREAM := UiKit.CREAM
const GOLD_COL := UiKit.GOLD_DEEP  # 흰 패널 위에서도 읽히는 진한 금색
const GEM_COL := UiKit.CYAN_DEEP
const INK := UiKit.INK

const SETTINGS_PANEL := preload("res://core/scripts/settings_panel.gd")
const CAT_CUSTOMIZER := preload("res://core/scripts/cat_customizer.gd")
const CatSprite := preload("res://core/scripts/cat_sprite.gd")
const TILE_SIZE := Vector2(128.0, 178.0)
const TILE_GAP := 14.0
const POPUP_SIZE := Vector2(620.0, 812.0)
const SHOP_TILE := Vector2(200.0, 210.0)
const STAT_ROWS := [["STAT_SPEED", "speed"], ["STAT_JUMP", "jump"],
		["STAT_DASH", "dash"], ["STAT_WEIGHT", "weight"], ["STAT_PUSH", "push"]]
const KEY_ROWS: Array[String] = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
const KEY_GAP := 8.0
## 캐릭터 선택 아래에 깔리는 참가자 슬롯 영역 (마리오 파티식 픽 화면).
const SLOT_CARD := Vector2(340.0, 168.0)
const PICK_FOOTER_H := 258.0
## 모드별 최대 인원 — 여기 없는 모드는 1인 전용. 화면 분할은 무한의 계단만
## 지원한다 (스테이지 모드는 LINES 목표 UI가 분할 화면에 들어가지 않는다).
const MODE_PLAYERS := {GameState.MODE_ENDLESS: 2}

@onready var escape_btn: Button = $UI/EscapeBtn
@onready var endless_btn: Button = $UI/EndlessBtn
@onready var versus_btn: Button = $UI/VersusBtn
@onready var classic_btn: Button = $UI/ClassicBtn
@onready var picnic_btn: Button = $UI/PicnicBtn
@onready var escape2_btn: Button = $UI/Escape2Btn
@onready var endless2_btn: Button = $UI/Endless2Btn
# 설명 라벨은 모드 오버레이 안으로 옮겨지므로 참조를 미리 잡아 둔다.
@onready var escape_desc: Label = $UI/EscapeDesc
@onready var endless_desc: Label = $UI/EndlessDesc
@onready var versus_desc: Label = $UI/VersusDesc
@onready var classic_desc: Label = $UI/ClassicDesc
@onready var picnic_desc: Label = $UI/PicnicDesc

# 레이아웃은 뷰포트 크기 기준으로 계산 — 모바일(세로 1080×1920)도 같은 코드를 쓴다.
var vw := 1920.0
var vh := 1080.0
var tile_y := 780.0  # 캐릭터 타일 첫 줄 y (_build_character_row에서 계산)
var max_tiles_per_row := 99  # 모바일 타이틀이 줄바꿈을 위해 줄인다
var main_scene := "res://core/scenes/main.tscn"  # 플랫폼 타이틀이 교체 가능
var allow_2p := true  # 모바일 타이틀은 false (키보드 한 대가 필요한 2인 모드 없음)

var _tiles := {}  # cat id -> Button
var _currency_label: Label
var _toast: Label
var _toast_tween: Tween
var _popup: Control
var _popup_face: Control
var _popup_action: Button
var _popup_close: Button
var _popup_feed: Button
var _popup_custom: Button
var _popup_dex: Button  # 이 냥이의 키캡 도감 열기
var _popup_cat: Dictionary = {}
var _customizer: Control
var _settings: Control
var _shop: Control
var _shop_tiles := {}  # accessory id -> preview Control (for redraws)
var _boost_chips := {}  # boost id -> Button
var _shop_wallet: Label
var _gacha_btns: Array[Button] = []  # [1회, 10연차]
var _gacha_result: Control  # 마지막으로 뽑은 키캡이 깔리는 자리
var _last_pull: Array = []  # draw_keycaps()가 돌려준 마지막 결과
var _bob := 0.0  # title cat idle bounce (affection level 5+)
var _modes: Control  # PLAY로 여는 모드 선택 오버레이
var _chars: Control  # CHARACTER로 여는 캐릭터 선택 오버레이
var _players_ui: Control  # 2인 가능 모드에서 PLAY 다음에 뜨는 인원 선택
var _pick := false  # 캐릭터 선택이 "게임 시작 전 픽" 모드인가
var _pick_mode := GameState.MODE_CLASSIC  # 픽이 끝나면 시작할 모드
var _pick_count := 1  # 이번 판 인원 (1 또는 2)
var _pick_slot := 0  # 지금 고르는 자리 (0 = 1P, 1 = 2P)
var _pick_cats: Array[String] = ["cream", "cream"]  # 자리별 고른 냥이
var _pick_footer: Control  # 슬롯 카드 + 시작 버튼이 놓이는 영역
var _slot_cards: Array = []  # 자리별 카드 [Button, face Control, 꾸미기 Button]
var _pick_start: Button
var _char_rows: Control  # 캐릭터 타일이 놓이는 컨테이너
var _cat_anchor := Vector2(1420.0, 660.0)  # 타이틀 큐브 고양이 자리
var _cat_size := 300.0
var _logo_top := 90.0
var _logo_cell := 46.0
var _keycap_dex: Control
var _keycap_board: Control
var _keycap_stats: Label
var _keycap_tabs := {}  # cat id -> 도감 상단 캐릭터 탭 Button
var _keycap_cat := "cream"  # 도감에서 보고 있는 캐릭터
var _ranks: Control
var _rank_tabs := {}  # mode key -> Button
var _rank_scopes := {}  # true (주간) / false (누적) -> Button
var _rank_mode := "classic"
var _rank_weekly := true
var _rank_list: VBoxContainer
var _rank_status: Label
var _rank_sub: Label
var _nick_edit: LineEdit
var _replay_viewer: Control


func _ready() -> void:
	# 이 타이틀이 뜬 플랫폼을 개발용 상태로 기록 (플랫폼 타이틀은 super 후 덮어씀).
	preload("res://core/scripts/boot.gd").dev_platform = ""
	vw = get_viewport_rect().size.x
	vh = get_viewport_rect().size.y
	UiKit.apply_theme($UI)
	# 로고는 코드로 그린다 — 씬의 텍스트 타이틀은 숨긴다.
	$UI/TitleLabel.visible = false
	$UI/SubtitleLabel.visible = false
	$UI/HintLabel.visible = false
	classic_btn.pressed.connect(func() -> void: _on_mode_picked(GameState.MODE_CLASSIC))
	endless_btn.pressed.connect(func() -> void: _on_mode_picked(GameState.MODE_ENDLESS))
	_refresh_classic_desc()
	_compute_layout()
	_build_currency_display()
	_build_character_row()
	_build_popup()
	_build_toast()
	_build_settings()
	_build_mode_select()
	_build_players_select()
	_build_menu()
	_build_shop()
	_build_ranks()
	_build_keycap_dex()
	_customizer = CAT_CUSTOMIZER.new()
	$UI.add_child(_customizer)
	UiKit.apply_theme($UI)  # 코드로 만든 오버레이까지 컨셉 테마를 덮는다
	# 냥이 크리에이터·리플레이 뷰어는 의도적으로 어두운 무대 연출 — 테마 제외.
	_customizer.theme = null
	_replay_viewer.theme = null
	_customizer.changed.connect(func() -> void:
		_refresh_tiles()
		_refresh_pick_cards()
		if _popup and _popup.visible:
			_popup_face.queue_redraw())
	Ranks.board_loaded.connect(func(_ok: bool) -> void:
		if _ranks and _ranks.visible:
			_refresh_rank_list())
	Ranks.weekly_reward.connect(func(g: int, gm: int) -> void:
		Sfx.play("record")
		var line := tr("MENU_WEEKLY_PRIZE").format({"gold": g})
		if gm > 0:
			line += "  +%d ◆" % gm
		_show_toast(line, GOLD_COL)
		_refresh_currency())
	Sfx.play_bgm("title")


## The selected cat bounces on the title once affection reaches level 5.
func _process(delta: float) -> void:
	if GameState.affection_level(GameState.selected_cat) >= 5:
		_bob += delta
		queue_redraw()


## 스테이지 모드 설명줄에 최고 기록을 얹는다.
func _refresh_classic_desc() -> void:
	if GameState.classic_best > 0:
		classic_desc.text = \
				tr("MODE_CLASSIC_DESC_BEST").format({"best": GameState.classic_best})


func _start(mode: int, split := false) -> void:
	Sfx.play("click")
	GameState.mode = mode
	GameState.split = split
	get_tree().change_scene_to_file(main_scene)


func _build_settings() -> void:
	_settings = SETTINGS_PANEL.new()
	$UI.add_child(_settings)


# --- 메인 메뉴 (컨셉: PLAY 한 방 + 카드 4장) ------------------------------------


## 화면 비율(가로/세로)에 따라 로고·메뉴·고양이 자리를 정한다.
func _compute_layout() -> void:
	if vh > vw:  # 모바일 세로
		_logo_cell = minf(44.0, (vw - 80.0) / 30.0)
		_logo_top = vh * 0.09
		_cat_anchor = Vector2(vw / 2.0, vh * 0.36)
		_cat_size = vw * 0.32
	else:
		_logo_cell = minf(48.0, (vw - 200.0) / 32.0)
		_logo_top = vh * 0.09
		_cat_anchor = Vector2(vw * 0.74, vh * 0.62)
		_cat_size = minf(vh * 0.28, 320.0)


## 메뉴 블록의 좌상단과 폭 — PLAY / 카드 4장 / 키캡 줄이 여기에 쌓인다.
func _menu_rect() -> Rect2:
	if vh > vw:
		var w := minf(vw - 80.0, 880.0)
		return Rect2((vw - w) / 2.0, vh * 0.52, w, vh * 0.38)
	var lw := minf(vw * 0.40, 700.0)
	return Rect2(vw * 0.30 - lw / 2.0, vh * 0.42, lw, vh * 0.46)


func _build_menu() -> void:
	var area := _menu_rect()
	var gap := 16.0
	var card_w := (area.size.x - gap) / 2.0
	var play_h := area.size.y * 0.24
	var card_h := area.size.y * 0.21
	var play := Button.new()
	play.text = "▶   PLAY"
	play.position = area.position
	play.size = Vector2(area.size.x, play_h)
	UiKit.btn_primary(play, int(play_h * 0.42))
	play.pressed.connect(func() -> void:
		Sfx.play("click")
		_open_modes())
	$UI.add_child(play)
	var cards := [
		[tr("MENU_CHARACTER"), UiKit.GOLD_DEEP, func() -> void: _open_chars()],
		[tr("MENU_SHOP"), UiKit.CYAN_DEEP, func() -> void: _open_shop()],
		[tr("MENU_RANKING"), UiKit.GOLD_DEEP, func() -> void: _open_ranks()],
		[tr("MENU_SETTINGS"), UiKit.PURPLE_DEEP, func() -> void: _settings.open()],
	]
	for i in cards.size():
		var entry: Array = cards[i]
		var b := Button.new()
		b.text = str(entry[0])
		b.position = area.position + Vector2((i % 2) * (card_w + gap),
				play_h + gap + (i / 2) * (card_h + gap))
		b.size = Vector2(card_w, card_h)
		UiKit.btn_card(b, entry[1], int(card_h * 0.3))
		var act: Callable = entry[2]
		b.pressed.connect(func() -> void:
			Sfx.play("click")
			act.call())
		$UI.add_child(b)
	# 키캡 도감은 한 줄짜리 얇은 알약 버튼으로 카드 아래에.
	var cap := Button.new()
	cap.text = tr("MENU_KEYCAP_DEX")
	cap.position = area.position + Vector2(0.0, play_h + card_h * 2.0 + gap * 3.0)
	cap.size = Vector2(area.size.x, card_h * 0.62)
	UiKit.btn_card(cap, UiKit.CYAN_DEEP, int(card_h * 0.24))
	cap.pressed.connect(func() -> void:
		Sfx.play("click")
		_open_keycap_dex())
	$UI.add_child(cap)


# --- 모드 선택 오버레이 --------------------------------------------------------


## 씬에 있던 모드 버튼들을 흰 패널 오버레이 안으로 옮기고 컨셉 톤으로 다시 칠한다.
## 플레이 가능한 모드는 스테이지 모드 · 무한의 계단 둘뿐 — 나머지 버튼은 숨긴다.
func _build_mode_select() -> void:
	_modes = _make_overlay(tr("MENU_MODE_SELECT"), func() -> void: _modes.visible = false,
			Vector2(minf(vw - 80.0, 900.0), minf(vh - 140.0, 460.0)))
	var panel: Control = _modes.get_meta("body")
	var pw: float = panel.size.x
	for n: Control in [escape_btn, escape_desc, picnic_btn, picnic_desc,
			versus_btn, versus_desc, escape2_btn, endless2_btn]:
		n.visible = false
	# 버튼 라벨 키를 코드에 명시적으로 들고 간다 — 씬의 text를 번호까지 붙여
	# 덮어쓰기 때문에, 키가 없으면 자동 번역이 끊긴다. (/i18n 철칙 1)
	var entries := [
		[classic_btn, classic_desc, "MODE_CLASSIC", UiKit.GOLD, UiKit.GOLD_DEEP,
				GameState.MODE_CLASSIC],
		[endless_btn, endless_desc, "MODE_ENDLESS", UiKit.CYAN, UiKit.CYAN_DEEP,
				GameState.MODE_ENDLESS],
	]
	var row_h := minf(120.0, panel.size.y / entries.size() - 40.0)
	var y := 8.0
	for i in entries.size():
		var e: Array = entries[i]
		var btn: Button = e[0]
		# 번호는 화면에 보이는 순서와 맞춘다 (= 데스크톱 단축키 순서).
		btn.text = "%d.  %s" % [i + 1, tr(str(e[2]))]
		var desc: Label = e[1]
		_reparent(btn, panel)
		btn.position = Vector2(0.0, y)
		btn.size = Vector2(pw, row_h)
		UiKit.style_button(btn, e[3], e[4], INK, int(row_h * 0.3), 16)
		_reparent(desc, panel)
		desc.position = Vector2(0.0, y + row_h + 4.0)
		desc.size = Vector2(pw, 26.0)
		desc.add_theme_font_size_override("font_size", 18)
		desc.add_theme_color_override("font_color", UiKit.MUTED)
		# 2인까지 되는 모드에는 인원 뱃지를 달아 둔다 (숫자·기호뿐 — 번역 불필요).
		if _max_players(int(e[5])) > 1:
			var tag := Label.new()
			tag.text = "1–2P"
			tag.position = Vector2(pw - 116.0, y + row_h + 2.0)
			tag.size = Vector2(112.0, 26.0)
			tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			tag.add_theme_font_size_override("font_size", 20)
			tag.add_theme_color_override("font_color", UiKit.CYAN_DEEP)
			panel.add_child(tag)
		y += row_h + 40.0
	_modes.visible = false


## 오버레이를 항상 메뉴 위로 올린다 (형제 순서 = 그리는 순서).
func _raise(c: Control) -> void:
	if c != null and c.get_parent() != null:
		c.get_parent().move_child(c, -1)


func _open_modes() -> void:
	_raise(_modes)
	_refresh_classic_desc()
	_modes.visible = true


## 이 모드가 받을 수 있는 최대 인원 (모바일 타이틀은 항상 1인).
func _max_players(mode: int) -> int:
	if not allow_2p:
		return 1
	return int(MODE_PLAYERS.get(mode, 1))


## 모드가 정해진 다음 단계: 2인 가능하면 인원 선택, 아니면 바로 캐릭터 선택.
func _on_mode_picked(mode: int) -> void:
	Sfx.play("click")
	_pick_mode = mode
	if _modes:
		_modes.visible = false
	if _max_players(mode) > 1:
		_open_players()
	else:
		_open_pick(1)


# --- 인원 선택 오버레이 ---------------------------------------------------------


## 2인까지 되는 모드에서만 뜨는 단계. 1인 / 2인(화면 분할) 둘 중 하나.
func _build_players_select() -> void:
	_players_ui = _make_overlay(tr("MENU_PLAYERS"),
			func() -> void: _back_to_modes(),
			Vector2(minf(vw - 80.0, 820.0), minf(vh - 160.0, 420.0)))
	var body: Control = _players_ui.get_meta("body")
	var entries := [
		[1, "MENU_PLAYERS_1", "MENU_PLAYERS_1_DESC", UiKit.GOLD, UiKit.GOLD_DEEP],
		[2, "MENU_PLAYERS_2", "MENU_PLAYERS_2_DESC", UiKit.CYAN, UiKit.CYAN_DEEP],
	]
	var row_h := minf(112.0, body.size.y / entries.size() - 40.0)
	var y := 8.0
	for e: Array in entries:
		var count := int(e[0])
		var b := Button.new()
		b.text = "%d.  %s" % [count, tr(str(e[1]))]
		b.position = Vector2(0.0, y)
		b.size = Vector2(body.size.x, row_h)
		UiKit.style_button(b, e[3], e[4], INK, int(row_h * 0.3), 16)
		b.pressed.connect(func() -> void:
			Sfx.play("click")
			_players_ui.visible = false
			_open_pick(count))
		body.add_child(b)
		var d := Label.new()
		d.text = tr(str(e[2]))
		d.position = Vector2(0.0, y + row_h + 4.0)
		d.size = Vector2(body.size.x, 26.0)
		d.add_theme_font_size_override("font_size", 18)
		d.add_theme_color_override("font_color", UiKit.MUTED)
		body.add_child(d)
		y += row_h + 40.0
	_players_ui.visible = false


func _open_players() -> void:
	_raise(_players_ui)
	_players_ui.visible = true


## 픽 흐름에서 한 단계 뒤로 (인원 선택 → 모드 선택).
func _back_to_modes() -> void:
	if _players_ui:
		_players_ui.visible = false
	_open_modes()


## 어두운 배경 + 흰 패널 + 제목 + 닫기 버튼을 갖춘 공용 오버레이 껍데기.
## 반환된 Control의 "body" 메타에 내용물을 붙일 빈 Control이 들어 있다.
func _make_overlay(title_text: String, on_close: Callable,
		size: Vector2 = Vector2.ZERO) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	$UI.add_child(root)
	var dim := Button.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim_sb := StyleBoxFlat.new()
	dim_sb.bg_color = Color(0.09, 0.13, 0.18, 0.55)
	for st in ["normal", "hover", "pressed", "focus"]:
		dim.add_theme_stylebox_override(st, dim_sb)
	dim.pressed.connect(on_close)
	root.add_child(dim)
	var pw: float = size.x if size.x > 0.0 else minf(vw - 80.0, 900.0)
	var ph: float = size.y if size.y > 0.0 else minf(vh - 140.0, 760.0)
	var card := Panel.new()
	card.position = (Vector2(vw, vh) - Vector2(pw, ph)) / 2.0
	card.size = Vector2(pw, ph)
	card.add_theme_stylebox_override("panel", UiKit.panel_box(UiKit.WHITE, 26, 0.0))
	root.add_child(card)
	var head := Label.new()
	head.text = title_text
	head.position = Vector2(0.0, 18.0)
	head.size = Vector2(pw, 52.0)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 38)
	head.add_theme_color_override("font_color", INK)
	card.add_child(head)
	root.set_meta("head", head)
	var close := Button.new()
	close.text = "✕"
	close.size = Vector2(56.0, 56.0)
	close.position = Vector2(pw - 72.0, 16.0)
	UiKit.btn_ghost(close, 26)
	close.pressed.connect(on_close)
	card.add_child(close)
	var body := Control.new()
	body.position = Vector2(34.0, 86.0)
	body.size = Vector2(pw - 68.0, ph - 116.0)
	card.add_child(body)
	root.set_meta("body", body)
	root.set_meta("card", card)
	return root


func _reparent(node: Node, to: Node) -> void:
	if node.get_parent() == to:
		return
	node.get_parent().remove_child(node)
	to.add_child(node)


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
	if _keycap_dex and _keycap_dex.visible:
		if event is InputEventKey and event.pressed \
				and event.physical_keycode == KEY_ESCAPE:
			_keycap_dex.visible = false
		return
	if _customizer and _customizer.visible:
		if event is InputEventKey and event.pressed \
				and event.physical_keycode == KEY_ESCAPE:
			_customizer.close()
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
	if _chars and _chars.visible:
		if event is InputEventKey and event.pressed \
				and event.physical_keycode == KEY_ESCAPE:
			_close_chars()
		return
	# 인원 선택: 1 / 2 로 고르고 Esc로 모드 선택으로 돌아간다.
	if _players_ui and _players_ui.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_ESCAPE:
					_back_to_modes()
				KEY_1, KEY_KP_1:
					_players_ui.visible = false
					_open_pick(1)
				KEY_2, KEY_KP_2:
					_players_ui.visible = false
					_open_pick(2)
		return
	# 모드 오버레이는 숫자 단축키를 그대로 통과시킨다 (Esc는 닫기).
	if _modes and _modes.visible and event is InputEventKey and event.pressed \
			and event.physical_keycode == KEY_ESCAPE:
		_modes.visible = false
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1, KEY_KP_1:
				_on_mode_picked(GameState.MODE_CLASSIC)
			KEY_2, KEY_KP_2:
				_on_mode_picked(GameState.MODE_ENDLESS)


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
	dim_sb.bg_color = Color(0.09, 0.13, 0.18, 0.55)
	for st in ["normal", "hover", "pressed", "focus"]:
		dim.add_theme_stylebox_override(st, dim_sb)
	dim.pressed.connect(_close_shop)
	_shop.add_child(dim)
	var pw := minf(vw - 60.0, 940.0)
	var ph := minf(vh - 140.0, 980.0)
	var panel := PanelContainer.new()
	panel.position = (Vector2(vw, vh) - Vector2(pw, ph)) / 2.0
	panel.size = Vector2(pw, ph)
	panel.add_theme_stylebox_override("panel", UiKit.panel_box(UiKit.WHITE, 26, 30.0))
	_shop.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := Label.new()
	title.text = tr("SHOP_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", INK)
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
	# 키캡 가챠 — 캐릭터 해금·등급업의 유일한 통로라 상점 맨 위에 둔다.
	list.add_child(_shop_header(tr("SHOP_GACHA")))
	var gacha_row := HBoxContainer.new()
	gacha_row.add_theme_constant_override("separation", 14)
	list.add_child(gacha_row)
	for n: int in [1, GameState.KEYCAP_GACHA_BULK]:
		var b := Button.new()
		b.custom_minimum_size = Vector2((pw - 88.0) / 2.0, 74.0)
		b.pressed.connect(func() -> void: _on_gacha(n))
		UiKit.btn_primary(b, 22)
		gacha_row.add_child(b)
		_gacha_btns.append(b)
	_gacha_result = Control.new()
	_gacha_result.custom_minimum_size = Vector2(pw - 60.0, 118.0)
	_gacha_result.draw.connect(func() -> void: _draw_gacha_result(_gacha_result))
	list.add_child(_gacha_result)
	var per_row := maxi(1, int((pw - 60.0 + TILE_GAP) / (SHOP_TILE.x + TILE_GAP)))
	for slot: Array in [["head", "SHOP_HEAD"], ["neck", "SHOP_NECK"]]:
		list.add_child(_shop_header(tr(str(slot[1]))))
		var items := GameState.ACCESSORIES.filter(
				func(a: Dictionary) -> bool: return a.slot == slot[0])
		var row: HBoxContainer = null
		for i in items.size():
			if i % per_row == 0:
				row = HBoxContainer.new()
				row.add_theme_constant_override("separation", int(TILE_GAP))
				list.add_child(row)
			row.add_child(_make_shop_tile(items[i]))
	list.add_child(_shop_header(tr("SHOP_BOOSTS")))
	var boost_row := HBoxContainer.new()
	boost_row.add_theme_constant_override("separation", 14)
	list.add_child(boost_row)
	for b: Dictionary in GameState.BOOSTS:
		var chip := Button.new()
		chip.custom_minimum_size = Vector2((pw - 88.0) / 3.0, 128.0)
		chip.pressed.connect(_on_boost_chip.bind(b))
		boost_row.add_child(chip)
		_boost_chips[b.id] = chip
	var close := Button.new()
	close.text = tr("SET_CLOSE")
	close.custom_minimum_size = Vector2(200.0, 56.0)
	UiKit.btn_ghost(close, 22)
	close.pressed.connect(_close_shop)
	var close_wrap := CenterContainer.new()
	close_wrap.add_child(close)
	v.add_child(close_wrap)


func _shop_header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", UiKit.MUTED)
	return l


func _make_shop_tile(acc: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = SHOP_TILE
	var equipped: bool = GameState.acc_head == acc.id or GameState.acc_neck == acc.id
	UiKit.style_button(b, Color("fff1cf") if equipped else UiKit.WHITE,
			UiKit.GOLD_DEEP if equipped else Color("c9c6d0"), INK, 18, 16)
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
	var skin := GameState.cat_skin("cream")
	skin["acc"] = [acc]
	Player.paint_cat(ci, Vector2(SHOP_TILE.x / 2.0, 84.0), 64.0, 0.0, true, false, skin)
	var font := ThemeDB.fallback_font
	_draw_center_text(ci, font, tr(str(acc.name)), 152.0, 20, INK, SHOP_TILE.x)
	var owned: bool = acc.id in GameState.acc_owned
	var equipped: bool = GameState.acc_head == acc.id or GameState.acc_neck == acc.id
	if equipped:
		_draw_center_text(ci, font, tr("CHAR_EQUIPPED"), 184.0, 18, GOLD_COL, SHOP_TILE.x)
	elif owned:
		_draw_center_text(ci, font, tr("SHOP_OWNED"), 184.0, 16,
				UiKit.MUTED, SHOP_TILE.x)
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
		_show_toast(tr("SHOP_BOUGHT").format({"name": tr(str(acc.name))}), CREAM)
	else:
		Sfx.play("error")
		_show_toast(tr("SHOP_NO_GOLD") if acc.price.type == "gold" else tr("SHOP_NO_GEMS"),
				Color(1.0, 0.55, 0.5))
		return
	_refresh_shop()
	_refresh_currency()
	_refresh_tiles()


## 키캡 n장 뽑기. 결과는 아래 띠에 깔리고, 등급이 오른 냥이는 토스트로 알린다.
func _on_gacha(n: int) -> void:
	var pull := GameState.draw_keycaps(n)
	if pull.is_empty():
		Sfx.play("error")
		_show_toast(tr("SHOP_NO_GOLD"), Color(1.0, 0.55, 0.5))
		return
	_last_pull = pull
	_gacha_result.queue_redraw()
	# 등급업(=해금 포함)이 있으면 그쪽을 알리고, 아니면 마지막 한 장을 알린다.
	var announced := false
	for hit: Dictionary in pull:
		if not hit.grade_up:
			continue
		var id := str(hit.cat)
		var cat_name := tr(str(GameState.get_cat(id).name))
		var grade := GameState.cat_grade(id)
		Sfx.play("record")
		_show_toast(tr("CHAR_RECRUITED").format({"name": cat_name}) if grade == 1
				else tr("KEYCAP_GRADE_UP").format({"name": cat_name, "grade": grade}),
				CREAM)
		announced = true
		break
	if not announced:
		var last: Dictionary = pull[-1]
		var cat_name := tr(str(GameState.get_cat(str(last.cat)).name))
		Sfx.play("buy" if last.fresh else "click")
		_show_toast(tr("KEYCAP_NEW" if last.fresh else "KEYCAP_DUP").format(
				{"name": cat_name, "letter": str(last.letter)}),
				GOLD_COL if last.fresh else UiKit.MUTED)
	_refresh_shop()
	_refresh_currency()
	_refresh_tiles()
	if _keycap_dex.visible:
		_refresh_keycap_dex()


## 마지막 뽑기 결과 — 키캡 한 줄과 그 아래 냥이 이름. 새로 채운 글자는 별표.
func _draw_gacha_result(ci: Control) -> void:
	if _last_pull.is_empty():
		UiKit.center_text(ci, tr("SHOP_GACHA_EMPTY"), 62.0, ci.size.x, 19,
				UiKit.MUTED)
		return
	var n := _last_pull.size()
	var gap := 8.0
	var cap := minf(74.0, (ci.size.x - gap * (n - 1)) / n)
	var x := (ci.size.x - (cap * n + gap * (n - 1))) / 2.0
	for i in n:
		var hit: Dictionary = _last_pull[i]
		var at := Rect2(x + i * (cap + gap), 6.0, cap, cap)
		EscapeBoard.paint_keycap(ci, at, str(hit.letter), 0.6, false, str(hit.cat))
		if not hit.fresh:  # 중복은 흐리게 눌러 둔다
			ci.draw_rect(at, Color(0.09, 0.13, 0.18, 0.42))
		var label := tr(str(GameState.get_cat(str(hit.cat)).name))
		UiKit.center_text(ci, label, at.end.y + 22.0, cap + gap, 14,
				GOLD_COL if hit.fresh else UiKit.MUTED, at.position.x - gap / 2.0)


func _on_boost_chip(boost: Dictionary) -> void:
	var had: bool = boost.id in GameState.pending_boosts
	if not GameState.toggle_boost(str(boost.id)):
		Sfx.play("error")
		_show_toast(tr("SHOP_NO_GOLD"), Color(1.0, 0.55, 0.5))
		return
	Sfx.play("click" if had else "buy")
	_refresh_shop()
	_refresh_currency()


func _refresh_shop() -> void:
	_shop_wallet.text = tr("SHOP_WALLET").format(
			{"gold": GameState.gold, "gems": GameState.gems})
	for id: String in _shop_tiles:
		var face: Control = _shop_tiles[id]
		face.queue_redraw()
		var eq: bool = GameState.acc_head == id or GameState.acc_neck == id
		UiKit.style_button(face.get_parent() as Button,
				Color("fff1cf") if eq else UiKit.WHITE,
				UiKit.GOLD_DEEP if eq else Color("c9c6d0"), INK, 18, 16)
	for i in _gacha_btns.size():
		var n: int = 1 if i == 0 else GameState.KEYCAP_GACHA_BULK
		_gacha_btns[i].text = tr("SHOP_GACHA_DRAW").format(
				{"n": n, "price": GameState.keycap_price(n)})
	_gacha_result.queue_redraw()
	for b: Dictionary in GameState.BOOSTS:
		var chip: Button = _boost_chips[b.id]
		var pending: bool = b.id in GameState.pending_boosts
		chip.text = "%s  ·  %d G\n%s\n%s" % [tr(b.name), b.price, tr(b.desc),
				tr("SHOP_BOOST_READY") if pending else tr("SHOP_BOOST_BUY")]
		UiKit.btn_chip(chip, pending, 20)


func _open_shop() -> void:
	_raise(_shop)
	_refresh_shop()
	_shop.visible = true


func _close_shop() -> void:
	_shop.visible = false
	queue_redraw()  # title cat may have changed outfit


# --- Keycap dex (alphabet collection) --------------------------------------------


## Collected-keycaps overlay: a keyboard plate where every banked letter sits
## as a cat-eared keycap; missing letters are empty sockets. Counts stack.
func _build_keycap_dex() -> void:
	_keycap_dex = Control.new()
	_keycap_dex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_keycap_dex.visible = false
	$UI.add_child(_keycap_dex)
	var dim := Button.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim_sb := StyleBoxFlat.new()
	dim_sb.bg_color = Color(0.09, 0.13, 0.18, 0.55)
	for st in ["normal", "hover", "pressed", "focus"]:
		dim.add_theme_stylebox_override(st, dim_sb)
	dim.pressed.connect(func() -> void: _keycap_dex.visible = false)
	_keycap_dex.add_child(dim)
	var pw := minf(vw - 60.0, 1000.0)
	var key := (pw - 60.0 - KEY_GAP * 9.0) / 10.0
	var plate_h := key * 3.0 + KEY_GAP * 2.0 + 44.0
	var ph := minf(vh - 100.0, plate_h + 360.0)
	var panel := PanelContainer.new()
	panel.position = (Vector2(vw, vh) - Vector2(pw, ph)) / 2.0
	panel.size = Vector2(pw, ph)
	panel.add_theme_stylebox_override("panel", UiKit.panel_box(UiKit.WHITE, 26, 30.0))
	_keycap_dex.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := Label.new()
	title.text = tr("KEYCAP_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", INK)
	v.add_child(title)
	# 캐릭터 탭 — 키캡은 냥이마다 따로 모으므로 어느 냥이 도감인지 먼저 고른다.
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	# 키캡은 디자인 냥이들만 모은다 — 나만의 캐릭터는 도감에 자리가 없다.
	var dex_cats := GameState.keycap_cats()
	for cat: Dictionary in dex_cats:
		var id := str(cat.id)
		var tab := Button.new()
		tab.custom_minimum_size = Vector2(
				(pw - 60.0 - 6.0 * (dex_cats.size() - 1)) / dex_cats.size(), 46.0)
		tab.pressed.connect(func() -> void:
			Sfx.play("click")
			_keycap_cat = id
			_refresh_keycap_dex())
		tabs.add_child(tab)
		_keycap_tabs[id] = tab
	_keycap_stats = Label.new()
	_keycap_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keycap_stats.add_theme_font_size_override("font_size", 24)
	_keycap_stats.add_theme_color_override("font_color", GOLD_COL)
	v.add_child(_keycap_stats)
	_keycap_board = Control.new()
	_keycap_board.custom_minimum_size = Vector2(pw - 60.0, plate_h)
	_keycap_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_keycap_board.draw.connect(_draw_keycap_dex_board)
	v.add_child(_keycap_board)
	var hint := Label.new()
	hint.text = tr("KEYCAP_HINT")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", UiKit.MUTED)
	v.add_child(hint)
	var close := Button.new()
	close.text = tr("SET_CLOSE")
	close.custom_minimum_size = Vector2(200.0, 56.0)
	UiKit.btn_ghost(close, 22)
	close.pressed.connect(func() -> void: _keycap_dex.visible = false)
	var wrap := CenterContainer.new()
	wrap.add_child(close)
	v.add_child(wrap)


## cat_id를 주면 그 냥이 도감을 펼친 채로 연다 (캐릭터 팝업의 도감 버튼).
func _open_keycap_dex(cat_id := "") -> void:
	if cat_id != "" and not GameState.is_custom_cat(cat_id):
		_keycap_cat = cat_id
	_raise(_keycap_dex)
	_refresh_keycap_dex()
	_keycap_dex.visible = true


func _refresh_keycap_dex() -> void:
	for id: String in _keycap_tabs:
		var tab: Button = _keycap_tabs[id]
		# 잠긴 냥이는 자물쇠를 달고, 칩 폭이 좁아 글자는 작게 (긴 이름 대응).
		var label := tr(str(GameState.get_cat(id).name))
		if not GameState.is_unlocked(id):
			label = "🔒" + label
		tab.text = "%s %d/26" % [label, GameState.keycap_ring(id)]
		UiKit.btn_chip(tab, id == _keycap_cat, 15)
	var cat: Dictionary = GameState.get_cat(_keycap_cat)
	_keycap_stats.text = tr("KEYCAP_STATS").format({
			"name": tr(str(cat.name)),
			"kinds": GameState.keycap_ring(_keycap_cat),
			"grade": GameState.cat_grade(_keycap_cat),
			"max": GameState.KEYCAP_GRADE_MAX,
			"total": GameState.keycap_total(_keycap_cat)})
	_keycap_board.queue_redraw()


## The keyboard: three staggered QWERTY rows on a light plate. Letters banked
## this round wear that cat's own keycap; the rest are dim empty sockets.
func _draw_keycap_dex_board() -> void:
	var ci := _keycap_board
	var bw := ci.size.x
	var key := (bw - KEY_GAP * 9.0) / 10.0
	var plate := Rect2(0.0, 0.0, bw, key * 3.0 + KEY_GAP * 2.0 + 44.0)
	ci.draw_style_box(UiKit.panel_box(Color("e8f4fb"), 20, 0.0), plate)
	var font := ThemeDB.fallback_font
	for r in KEY_ROWS.size():
		var letters := KEY_ROWS[r]
		var row_w := letters.length() * key + (letters.length() - 1) * KEY_GAP
		var x := (bw - row_w) / 2.0
		var y := 22.0 + r * (key + KEY_GAP)
		for i in letters.length():
			var letter := letters[i]
			var rect := Rect2(x + i * (key + KEY_GAP), y, key, key)
			var count := GameState.keycap_count(_keycap_cat, letter)
			if GameState.has_keycap(_keycap_cat, letter):
				EscapeBoard.paint_keycap(ci, rect, letter, 0.6, false, _keycap_cat)
				if count > 1:
					var badge := rect.position + Vector2(key - 14.0, key - 8.0)
					ci.draw_circle(badge + Vector2(0.0, -6.0), 15.0, Color("b8433f"))
					var txt := "×%d" % count if count < 100 else "99+"
					var tw := font.get_string_size(txt,
							HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
					ci.draw_string(font, badge + Vector2(-tw / 2.0, 0.0), txt,
							HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
			else:
				# 빈 소켓: 이번 바퀴에 아직 못 모은 글자 자리.
				var sock := StyleBoxFlat.new()
				sock.bg_color = Color(0.72, 0.82, 0.88, 0.55)
				sock.set_corner_radius_all(int(key * 0.14))
				sock.set_border_width_all(2)
				sock.border_color = Color(INK, 0.18)
				ci.draw_style_box(sock, rect.grow(-key * 0.09))
				var fs := int(key * 0.4)
				var w := font.get_string_size(letter,
						HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				ci.draw_string(font, rect.get_center() + Vector2(-w / 2.0, fs * 0.36),
						letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(INK, 0.3))


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
	dim_sb.bg_color = Color(0.09, 0.13, 0.18, 0.55)
	for st in ["normal", "hover", "pressed", "focus"]:
		dim.add_theme_stylebox_override(st, dim_sb)
	dim.pressed.connect(func() -> void: _ranks.visible = false)
	_ranks.add_child(dim)
	var pw := minf(vw - 60.0, 760.0)
	var ph := minf(vh - 140.0, 960.0)
	var panel := PanelContainer.new()
	panel.position = (Vector2(vw, vh) - Vector2(pw, ph)) / 2.0
	panel.size = Vector2(pw, ph)
	panel.add_theme_stylebox_override("panel", UiKit.panel_box(UiKit.WHITE, 26, 28.0))
	_ranks.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := Label.new()
	title.text = tr("RANK_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", INK)
	v.add_child(title)
	# Nickname row: shown on every board, editable here.
	var nick_row := HBoxContainer.new()
	nick_row.alignment = BoxContainer.ALIGNMENT_CENTER
	nick_row.add_theme_constant_override("separation", 10)
	v.add_child(nick_row)
	var nick_title := Label.new()
	nick_title.text = tr("RANK_MY_NAME")
	nick_title.add_theme_font_size_override("font_size", 20)
	nick_title.add_theme_color_override("font_color", UiKit.MUTED)
	nick_row.add_child(nick_title)
	_nick_edit = LineEdit.new()
	_nick_edit.custom_minimum_size = Vector2(240.0, 48.0)
	_nick_edit.max_length = 12
	_nick_edit.add_theme_font_size_override("font_size", 20)
	nick_row.add_child(_nick_edit)
	var nick_save := Button.new()
	nick_save.text = tr("RANK_RENAME")
	nick_save.custom_minimum_size = Vector2(96.0, 48.0)
	UiKit.btn_card(nick_save, UiKit.CYAN_DEEP, 18)
	nick_save.pressed.connect(func() -> void:
		Sfx.play("click")
		GameState.set_nickname(_nick_edit.text)
		_nick_edit.text = GameState.nickname
		_show_toast(tr("RANK_RENAMED").format({"name": GameState.nickname}), CREAM)
		_refresh_rank_list())
	nick_row.add_child(nick_save)
	# Scope toggle: weekly (resets Monday 00:00 KST, top 3 win prizes) / all-time.
	var scopes := HBoxContainer.new()
	scopes.alignment = BoxContainer.ALIGNMENT_CENTER
	scopes.add_theme_constant_override("separation", 10)
	v.add_child(scopes)
	for entry: Array in [[true, tr("RANK_WEEKLY")], [false, tr("RANK_ALLTIME")]]:
		var sb_btn := Button.new()
		sb_btn.text = str(entry[1])
		sb_btn.custom_minimum_size = Vector2((pw - 70.0) / 2.0, 52.0)
		sb_btn.pressed.connect(func() -> void:
			Sfx.play("click")
			_rank_weekly = entry[0]
			_refresh_rank_list()
			Ranks.view(_rank_mode, _rank_weekly))
		scopes.add_child(sb_btn)
		_rank_scopes[entry[0]] = sb_btn
	# Mode tabs.
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	v.add_child(tabs)
	for entry: Array in [["classic", tr("MODE_CLASSIC")],
			["endless", tr("MODE_ENDLESS")]]:
		var b := Button.new()
		b.text = str(entry[1])
		b.custom_minimum_size = Vector2((pw - 70.0) / 2.0, 54.0)
		b.pressed.connect(_on_rank_tab.bind(str(entry[0])))
		tabs.add_child(b)
		_rank_tabs[entry[0]] = b
	_rank_sub = Label.new()
	_rank_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_sub.add_theme_font_size_override("font_size", 16)
	_rank_sub.add_theme_color_override("font_color", GOLD_COL)
	v.add_child(_rank_sub)
	_rank_status = Label.new()
	_rank_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_status.add_theme_font_size_override("font_size", 16)
	_rank_status.add_theme_color_override("font_color", UiKit.MUTED)
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
	close.text = tr("SET_CLOSE")
	close.custom_minimum_size = Vector2(200.0, 56.0)
	UiKit.btn_ghost(close, 22)
	close.pressed.connect(func() -> void: _ranks.visible = false)
	var wrap := CenterContainer.new()
	wrap.add_child(close)
	v.add_child(wrap)
	_replay_viewer = preload("res://core/scripts/replay_viewer.gd").new()
	$UI.add_child(_replay_viewer)


func _open_ranks() -> void:
	_raise(_ranks)
	_nick_edit.text = GameState.nickname
	_ranks.visible = true
	_refresh_rank_list()
	Ranks.view(_rank_mode, _rank_weekly)  # board_loaded will re-render


func _on_rank_tab(mode_key: String) -> void:
	Sfx.play("click")
	_rank_mode = mode_key
	_refresh_rank_list()
	# 스팀 백엔드는 보드를 하나씩 받아 오므로 탭을 옮길 때마다 불러야 한다.
	Ranks.view(_rank_mode, _rank_weekly)


func _refresh_rank_list() -> void:
	for tab_key: String in _rank_tabs:
		_style_rank_tab(_rank_tabs[tab_key], tab_key == _rank_mode)
	for scope_key: bool in _rank_scopes:
		_style_rank_tab(_rank_scopes[scope_key], scope_key == _rank_weekly)
	_rank_sub.visible = _rank_weekly
	if _rank_weekly:
		_rank_sub.text = tr("RANK_RESET_IN").format(
				{"time": Ranks.week_remaining_text()})
	for child in _rank_list.get_children():
		child.queue_free()
	var mine := Ranks.my_id()
	var local_v := GameState.weekly_value(_rank_mode) if _rank_weekly \
			else Ranks.local_value(_rank_mode)
	var list := Ranks.entries(_rank_mode, _rank_weekly)
	if Ranks.online() and Ranks.busy and list.is_empty():
		_rank_status.text = tr("RANK_LOADING")
		return
	var rank := Ranks.my_rank(_rank_mode, _rank_weekly)
	var scope_txt := tr("RANK_SCOPE_WEEK") if _rank_weekly else tr("RANK_SCOPE_MINE")
	if not Ranks.online():
		# Pre-launch board: bot crowd + my real record mixed in.
		_rank_status.text = tr("RANK_MY_RANK_MOCK").format({"scope": scope_txt,
				"rank": rank, "value": Ranks.value_text(_rank_mode, local_v)}) if rank > 0 \
				else tr("RANK_NONE_MOCK")
	else:
		_rank_status.text = tr("RANK_MY_RANK").format({"scope": scope_txt, "rank": rank,
				"value": Ranks.value_text(_rank_mode, local_v)}) \
				if rank > 0 else (tr("RANK_NONE") if local_v <= 0
				else tr("RANK_SUBMITTING"))
	if list.is_empty():
		_rank_list.add_child(_rank_row(0, tr("RANK_BE_FIRST"), -1, false))
	for i in mini(list.size(), 50):
		var e: Dictionary = list[i]
		# Replays ride only on the all-time boards.
		_rank_list.add_child(_rank_row(i + 1, str(e.get("name", "???")),
				int(e.get("v", 0)), str(e.get("id")) == mine,
				{} if _rank_weekly else e))


func _style_rank_tab(b: Button, active: bool) -> void:
	UiKit.btn_chip(b, active, 19)


func _rank_row(rank: int, name_text: String, v: int, mine: bool,
		entry: Dictionary = {}) -> Control:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.bg_color = Color("fff1cf") if mine else Color("f2f5f9")
	sb.set_border_width_all(3 if mine else 2)
	sb.border_color = UiKit.GOLD_DEEP if mine else Color(INK, 0.12)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 7.0
	sb.content_margin_bottom = 7.0
	row.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)
	var rank_l := Label.new()
	rank_l.text = tr("RANK_POSITION").format({"rank": rank}) if rank > 0 \
			else (tr("RANK_MY_RECORD") if v >= 0 else "")
	rank_l.custom_minimum_size.x = 64.0
	rank_l.add_theme_font_size_override("font_size", 18)
	rank_l.add_theme_color_override("font_color",
			GOLD_COL if rank in [1, 2, 3] else UiKit.MUTED)
	h.add_child(rank_l)
	var name_l := Label.new()
	name_l.text = name_text + (tr("RANK_ME_MARK") if mine and rank > 0 else "")
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.add_theme_font_size_override("font_size", 18)
	name_l.add_theme_color_override("font_color", INK if mine else Color(INK, 0.85))
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
		play.custom_minimum_size = Vector2(56.0, 36.0)
		UiKit.btn_card(play, UiKit.ORANGE_DEEP, 16)
		play.pressed.connect(func() -> void:
			Sfx.play("click")
			var rep: Dictionary = await Ranks.replay_for(mode_key, entry)
			if rep.is_empty():
				_show_toast(tr("RANK_REPLAY_FAIL"), Color(1.0, 0.55, 0.5))
				return
			_replay_viewer.open(rep, "%s  ·  %s" % [name_text,
					Ranks.value_text(mode_key, v)]))
		h.add_child(play)
	return row


# --- Character select ---------------------------------------------------------


## 캐릭터 선택은 컨셉의 CHARACTER 카드로 여는 오버레이 안에 산다.
## 두 가지로 쓰인다: ① 메뉴에서 여는 둘러보기(구매·꾸미기) ② PLAY 흐름의
## 참가자 픽(마리오 파티식) — 아래쪽 슬롯 카드에 1P·2P가 자기 냥이를 앉힌다.
func _build_character_row() -> void:
	_chars = _make_overlay(tr("CHAR_SELECT"), func() -> void: _close_chars(),
			Vector2(minf(vw - 60.0, 1180.0), minf(vh - 100.0, 800.0)))
	var body: Control = _chars.get_meta("body")
	# 아래쪽은 참가자 슬롯 몫으로 늘 비워 둔다 (둘러보기 모드에선 빈 자리).
	var grid_h := body.size.y - PICK_FOOTER_H
	# 패널 폭에 맞춰 줄바꿈 (가로는 한 줄, 세로 화면은 여러 줄).
	var fit := maxi(1, int((body.size.x + TILE_GAP) / (TILE_SIZE.x + TILE_GAP)))
	var per_row := mini(mini(fit, max_tiles_per_row), GameState.CATS.size())
	var rows := ceili(GameState.CATS.size() / float(per_row))
	tile_y = maxf(0.0, (grid_h - rows * TILE_SIZE.y - (rows - 1) * TILE_GAP) / 2.0)
	for r in rows:
		var chunk: Array = GameState.CATS.slice(r * per_row, (r + 1) * per_row)
		var total := chunk.size() * TILE_SIZE.x + (chunk.size() - 1) * TILE_GAP
		var x := (body.size.x - total) / 2.0
		for cat in chunk:
			var tile := _make_tile(cat)
			tile.position = Vector2(x, tile_y + r * (TILE_SIZE.y + TILE_GAP))
			body.add_child(tile)
			_tiles[cat.id] = tile
			x += TILE_SIZE.x + TILE_GAP
	_build_pick_footer(body, grid_h)


func _open_chars() -> void:
	_pick = false
	_pick_count = 1
	(_chars.get_meta("head") as Label).text = tr("CHAR_SELECT")
	_pick_footer.visible = false
	_raise(_chars)
	_refresh_tiles()
	_chars.visible = true


func _close_chars() -> void:
	# 픽 도중이면 한 단계 뒤로, 둘러보기면 그냥 닫는다.
	_chars.visible = false
	if not _pick:
		return
	_pick = false
	if _max_players(_pick_mode) > 1:
		_open_players()
	else:
		_open_modes()


# --- 참가자 픽 (마리오 파티식 슬롯) -----------------------------------------------


## 게임 시작 전 캐릭터 픽을 연다. count = 1이면 1P 슬롯 하나, 2면 1P·2P 둘.
func _open_pick(count: int) -> void:
	_pick = true
	_pick_count = count
	_pick_slot = 0
	_pick_cats[0] = _first_unlocked(GameState.selected_cat)
	_pick_cats[1] = _first_unlocked(GameState.selected_cat2)
	(_chars.get_meta("head") as Label).text = tr("CHAR_PICK")
	_pick_footer.visible = true
	_layout_pick_footer()
	_raise(_chars)
	_refresh_tiles()
	_refresh_pick_cards()
	_chars.visible = true


## 저장된 선택이 아직 잠겨 있으면 해금된 첫 냥이로 대체한다.
func _first_unlocked(id: String) -> String:
	if GameState.is_unlocked(id):
		return id
	for cat in GameState.CATS:
		if GameState.is_unlocked(cat.id):
			return str(cat.id)
	return "cream"


func _build_pick_footer(body: Control, top: float) -> void:
	_pick_footer = Control.new()
	_pick_footer.position = Vector2(0.0, top)
	_pick_footer.size = Vector2(body.size.x, PICK_FOOTER_H)
	_pick_footer.visible = false
	body.add_child(_pick_footer)
	for i in 2:
		var slot := i  # captured
		var card := Button.new()
		card.size = SLOT_CARD
		card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		card.pressed.connect(func() -> void:
			Sfx.play("click")
			_pick_slot = slot
			_refresh_pick_cards())
		var face := Control.new()
		face.set_anchors_preset(Control.PRESET_FULL_RECT)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.draw.connect(func() -> void: _draw_slot_card(face, slot))
		card.add_child(face)
		var custom := Button.new()
		custom.text = tr("CHAR_CUSTOMIZE")
		custom.size = Vector2(150.0, 48.0)
		custom.position = Vector2(SLOT_CARD.x - 166.0, SLOT_CARD.y - 62.0)
		UiKit.btn_card(custom, UiKit.PURPLE_DEEP, 20)
		custom.pressed.connect(func() -> void:
			Sfx.play("click")
			_pick_slot = slot
			_refresh_pick_cards()
			_customizer.open(_pick_cats[slot], slot + 1))
		card.add_child(custom)
		_pick_footer.add_child(card)
		_slot_cards.append([card, face, custom])
	_pick_start = Button.new()
	_pick_start.text = tr("MENU_START")
	_pick_start.size = Vector2(300.0, 58.0)
	UiKit.btn_primary(_pick_start, 26)
	_pick_start.pressed.connect(_start_picked)
	_pick_footer.add_child(_pick_start)


## 인원 수에 맞춰 카드를 가운데로 모으고, 시작 버튼을 그 아래에 놓는다.
func _layout_pick_footer() -> void:
	var gap := 24.0
	var total := _pick_count * SLOT_CARD.x + (_pick_count - 1) * gap
	var x := (_pick_footer.size.x - total) / 2.0
	for i in _slot_cards.size():
		var card: Button = _slot_cards[i][0]
		card.visible = i < _pick_count
		if card.visible:
			card.position = Vector2(x, 0.0)
			x += SLOT_CARD.x + gap
	_pick_start.position = Vector2((_pick_footer.size.x - _pick_start.size.x) / 2.0,
			SLOT_CARD.y + 26.0)


func _refresh_pick_cards() -> void:
	if _pick_footer == null or not _pick_footer.visible:
		return
	for i in _slot_cards.size():
		var card: Button = _slot_cards[i][0]
		if i == _pick_slot:
			UiKit.style_button(card, Color("fff1cf"), UiKit.GOLD_DEEP, INK, 20, 18)
		else:
			UiKit.style_button(card, UiKit.WHITE, Color("c9c6d0"), INK, 20, 18)
		(_slot_cards[i][1] as Control).queue_redraw()


func _draw_slot_card(ci: Control, slot: int) -> void:
	var id := _pick_cats[slot]
	var font := ThemeDB.fallback_font
	Player.paint_cat(ci, Vector2(76.0, 92.0), 84.0, 0.0, true, false,
			GameState.cat_skin(id, slot + 1))
	# 자리 뱃지 (숫자 + P — 언어 무관).
	ci.draw_string(font, Vector2(16.0, 36.0), "%dP" % (slot + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 28,
			GOLD_COL if slot == _pick_slot else UiKit.MUTED)
	var right := Rect2(140.0, 0.0, SLOT_CARD.x - 156.0, SLOT_CARD.y)
	var cat_name := tr(str(GameState.get_cat(id).get("name", "")))
	var size := UiKit.fit_size(font, cat_name, right.size.x, 26)
	ci.draw_string(font, Vector2(right.position.x, 54.0), cat_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, INK)
	if slot == _pick_slot:
		var turn := tr("CHAR_PICK_TURN")
		var ts := UiKit.fit_size(font, turn, right.size.x, 19)
		ci.draw_string(font, Vector2(right.position.x, 84.0), turn,
				HORIZONTAL_ALIGNMENT_LEFT, -1, ts, GOLD_COL)


## 타일에서 고른 냥이를 지금 자리에 앉히고, 2인이면 다음 자리로 넘긴다.
func _assign_pick(cat_id: String) -> void:
	Sfx.play("buy")
	_pick_cats[_pick_slot] = cat_id
	if _pick_count > 1:
		_pick_slot = (_pick_slot + 1) % _pick_count
	_refresh_pick_cards()
	_refresh_tiles()


func _start_picked() -> void:
	GameState.select_cat(_pick_cats[0], 1)
	if _pick_count > 1:
		GameState.select_cat(_pick_cats[1], 2)
	_chars.visible = false
	_pick = false
	_start(_pick_mode, _pick_count > 1)


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
	var selected := _is_chosen(str(cat.id))
	if selected:
		UiKit.style_button(b, Color("fff1cf"), UiKit.GOLD_DEEP, INK, 20, 16)
	else:
		UiKit.style_button(b, UiKit.WHITE, Color("c9c6d0"), INK, 20, 16)


func _draw_tile(ci: Control, cat: Dictionary) -> void:
	var unlocked: bool = GameState.is_unlocked(cat.id)
	var center := Vector2(TILE_SIZE.x / 2.0, 62.0)
	if unlocked:
		Player.paint_cat(ci, center, 68.0, 0.0, true, false, GameState.cat_skin(cat.id))
	else:
		# 잠긴 냥이는 실루엣 + 자물쇠 뱃지.
		var shadow := GameState.cat_shadow_skin(str(cat.id))
		Player.paint_cat(ci, center, 68.0, 0.0, true, false, shadow)
		_draw_lock(ci, center + Vector2(34.0, 24.0))
	var font := ThemeDB.fallback_font
	# 픽 중에는 어느 자리가 이 냥이를 골랐는지 우상단 뱃지로 보여준다.
	if _pick:
		var by := 6.0
		for i in _pick_count:
			if _pick_cats[i] != cat.id:
				continue
			var chip := Rect2(TILE_SIZE.x - 44.0, by, 38.0, 26.0)
			ci.draw_rect(chip, GOLD_COL)
			ci.draw_string(font, chip.position + Vector2(5.0, 20.0),
					"%dP" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, UiKit.WHITE)
			by += 30.0
	var name_col := INK if unlocked else UiKit.MUTED
	var tile_name := tr(str(cat.name))
	if unlocked and GameState.affection_level(cat.id) >= 10:
		tile_name = "★" + tile_name
	_draw_center_text(ci, font, tile_name, 112.0, 22, name_col)
	if unlocked:
		# 해금된 냥이는 특성 태그를 달고, 선택된 냥이는 진한 금색.
		var tag_col := GOLD_COL if _is_chosen(str(cat.id)) else UiKit.MUTED
		_draw_center_text(ci, font, tr(str(cat.get("trait", ""))), 142.0, 16, tag_col)
	else:
		# 잠긴 냥이는 해금 게이지 = 이번 바퀴 키캡 진행 (기호+숫자라 번역 불필요).
		_draw_center_text(ci, font, "▦ %d / 26" % GameState.keycap_ring(str(cat.id)),
				142.0, 18, GOLD_COL)
	# 나만의 캐릭터는 키캡을 모으지 않는다 — 등급 칩 대신 파츠 해금 수를 띄운다.
	if GameState.is_custom_cat(str(cat.id)):
		var prog := GameState.my_parts_progress()
		_draw_center_text(ci, font, "🎨 %d / %d" % [prog.x, prog.y], 162.0, 16,
				UiKit.PURPLE_DEEP)
	else:
		_draw_grade_pips(ci, str(cat.id), 158.0)


## 타일 아래 등급 칩 — 채워진 개수가 지금 등급(키캡 A~Z를 채운 바퀴 수)이다.
func _draw_grade_pips(ci: Control, id: String, y: float) -> void:
	var top: int = GameState.KEYCAP_GRADE_MAX
	var grade := GameState.cat_grade(id)
	var w := 18.0
	var gap := 6.0
	var x := (TILE_SIZE.x - (top * w + (top - 1) * gap)) / 2.0
	for i in top:
		var r := Rect2(x + i * (w + gap), y, w, 8.0)
		ci.draw_rect(r, UiKit.GOLD_DEEP if i < grade else Color(INK, 0.12))


func _draw_center_text(ci: Control, font: Font, text: String, y: float,
		size: int, col: Color, width: float = TILE_SIZE.x) -> void:
	# 타일/팝업 폭을 넘기면 글자를 줄여서 맞춘다 (긴 번역 대응).
	size = UiKit.fit_size(font, text, width - 12.0, size)
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
	var col := UiKit.GOLD_DEEP
	ci.draw_rect(Rect2(at + Vector2(-8.0, -2.0), Vector2(16.0, 13.0)), col)
	ci.draw_arc(at + Vector2(0.0, -3.0), 5.5, PI, TAU, 10, col, 3.0)


func _on_tile_pressed(cat: Dictionary) -> void:
	Sfx.play("click")
	# 픽 중에는 해금된 냥이를 곧장 자리에 앉힌다 (잠긴 냥이는 구매 팝업으로).
	if _pick and GameState.is_unlocked(cat.id):
		_assign_pick(str(cat.id))
		return
	_open_popup(cat)


## 이 냥이가 지금 "고른" 상태인가 — 픽 중에는 참가자 슬롯, 아니면 저장된 선택.
func _is_chosen(id: String) -> bool:
	if not _pick:
		return GameState.selected_cat == id
	for i in _pick_count:
		if _pick_cats[i] == id:
			return true
	return false


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
	dim_sb.bg_color = Color(0.09, 0.13, 0.18, 0.55)
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
	_popup_close.text = tr("SET_CLOSE")
	_popup_close.pressed.connect(_close_popup)
	_popup_feed = _make_popup_button(panel, false)
	_popup_feed.add_theme_font_size_override("font_size", 19)
	_popup_feed.pressed.connect(_on_popup_feed)
	_popup_custom = _make_popup_button(panel, false)
	_popup_custom.text = tr("CHAR_CUSTOMIZE")
	_popup_custom.pressed.connect(func() -> void:
		Sfx.play("click")
		var id: String = str(_popup_cat.get("id", "cream"))
		var slot := (_pick_slot + 1) if _pick else 1
		_close_popup()
		_customizer.open(id, slot))
	_popup_dex = _make_popup_button(panel, false)
	_popup_dex.text = tr("CHAR_DEX_BTN")
	_popup_dex.pressed.connect(func() -> void:
		Sfx.play("click")
		var id: String = str(_popup_cat.get("id", "cream"))
		_close_popup()
		_open_keycap_dex(id))


func _make_popup_button(panel: Control, accent: bool) -> Button:
	var b := Button.new()
	if accent:
		UiKit.btn_primary(b, 24)
	else:
		UiKit.btn_ghost(b, 22)
	panel.add_child(b)
	return b


func _open_popup(cat: Dictionary) -> void:
	_raise(_popup)
	_popup_cat = cat
	var unlocked: bool = GameState.is_unlocked(cat.id)
	# 캐릭터는 키캡으로만 해금된다 — 잠긴 냥이에겐 고를 버튼 자체가 없다.
	if unlocked:
		if _pick:
			_popup_action.visible = _pick_cats[_pick_slot] != cat.id
		else:
			_popup_action.visible = GameState.selected_cat != cat.id
		_popup_action.text = tr("CHAR_SELECT_BTN")
	else:
		_popup_action.visible = false
	_refresh_feed_button()
	# 꾸미기는 결과가 실제로 보이는 냥이에만 — 컨셉 시트 그림으로 그리는 냥이는
	# 파츠 레이어 아트가 있어야 색을 갈아끼울 수 있다.
	var char_id := str(cat.get("char", "char01"))
	_popup_custom.visible = unlocked and (CatSprite.is_layered(char_id)
			or not CatSprite.has(char_id))
	# 나만의 캐릭터는 키캡을 모으지 않으므로 도감 버튼이 없다.
	_popup_dex.visible = not GameState.is_custom_cat(str(cat.id))
	# Bottom row: visible buttons side by side, centered — 다 들어가지 않으면
	# 폭을 같은 비율로 줄인다 (긴 번역 + 버튼 4개).
	var y := POPUP_SIZE.y - 70.0
	var row: Array = []
	if _popup_action.visible:
		row.append([_popup_action, 200.0])
	if _popup_custom.visible:
		row.append([_popup_custom, 170.0])
	if _popup_dex.visible:
		row.append([_popup_dex, 170.0])
	row.append([_popup_close, 200.0 if row.is_empty() else 140.0])
	var total := -18.0
	for entry: Array in row:
		total += entry[1] + 18.0
	var avail := POPUP_SIZE.x - 44.0
	var shrink := minf(1.0, (avail - (row.size() - 1) * 18.0)
			/ maxf(1.0, total - (row.size() - 1) * 18.0))
	total = -18.0
	for entry: Array in row:
		entry[1] = floorf(entry[1] * shrink)
		total += entry[1] + 18.0
	var x := (POPUP_SIZE.x - total) / 2.0
	for entry: Array in row:
		var b: Button = entry[0]
		b.size = Vector2(entry[1], 52.0)
		b.position = Vector2(x, y)
		x += entry[1] + 18.0
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
		_popup_feed.text = tr("CHAR_FEED_MAX")
		_popup_feed.disabled = true
	else:
		_popup_feed.text = tr("CHAR_FEED").format(
				{"price": GameState.snack_price(str(cat.id)), "left": to_next})
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
			_show_toast(tr("CHAR_FEED_EVOLVE").format(
					{"name": tr(str(cat.name)), "level": level}), GOLD_COL)
		elif level > before_level:
			Sfx.play("record")
			_show_toast(tr("CHAR_FEED_LEVEL").format({"level": level,
					"pct": roundi(GameState.affection_bonus(cat.id) * 100)}),
					Color(0.96, 0.62, 0.7))
		else:
			Sfx.play("buy")
			_show_toast(tr("CHAR_FEED_HAPPY").format({"name": tr(str(cat.name))}),
					Color(0.96, 0.62, 0.7))
		_refresh_feed_button()
		_refresh_currency()
		_popup_face.queue_redraw()
		_refresh_tiles()
	else:
		Sfx.play("error")
		_show_toast(tr("SHOP_NO_GOLD"), Color(1.0, 0.55, 0.5))


func _on_popup_action() -> void:
	var cat := _popup_cat
	if not GameState.is_unlocked(cat.id):
		return
	Sfx.play("click")
	if _pick:
		_assign_pick(str(cat.id))
	else:
		GameState.select_cat(cat.id)
	_refresh_tiles()
	_close_popup()


func _draw_popup(ci: Control) -> void:
	var cat := _popup_cat
	if cat.is_empty():
		return
	var unlocked: bool = GameState.is_unlocked(cat.id)
	ci.draw_style_box(UiKit.panel_box(UiKit.WHITE, 26, 0.0),
			Rect2(Vector2.ZERO, POPUP_SIZE))
	var font := ThemeDB.fallback_font
	var center := Vector2(POPUP_SIZE.x / 2.0, 118.0)
	if unlocked:
		Player.paint_cat(ci, center, 110.0, 0.0, true, false, GameState.cat_skin(cat.id))
	else:
		var shadow := GameState.cat_shadow_skin(str(cat.id))
		Player.paint_cat(ci, center, 110.0, 0.0, true, false, shadow)
		_draw_lock(ci, center + Vector2(52.0, 38.0))
	var name_col := INK if unlocked else UiKit.MUTED
	var pop_name := tr(str(cat.name))
	if unlocked and GameState.affection_level(cat.id) >= 10:
		pop_name = "★ %s ★" % pop_name
	_draw_center_text(ci, font, pop_name, 226.0, 34, name_col, POPUP_SIZE.x)
	_draw_center_text(ci, font, "「%s」" % tr(str(cat.get("trait", ""))), 262.0, 21,
			GOLD_COL, POPUP_SIZE.x)
	# Stat bars.
	var stats: Dictionary = GameState.cat_stats(cat.id)
	for i in STAT_ROWS.size():
		var row_y := 302.0 + i * 40.0
		ci.draw_string(font, Vector2(150.0, row_y + 14.0), tr(STAT_ROWS[i][0]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(INK, 0.85))
		var pips := _stat_pips(STAT_ROWS[i][1], stats.get(STAT_ROWS[i][1], 1.0))
		for p in 5:
			var r := Rect2(238.0 + p * 50.0, row_y, 42.0, 16.0)
			var col := UiKit.ORANGE if p < pips else Color(INK, 0.12)
			ci.draw_rect(r, col)
	# 키캡 수집 현황 — 잠긴 냥이에겐 이게 곧 해금 조건이다.
	# 나만의 캐릭터는 모을 키캡이 없다: 대신 파츠 해금 규칙을 알려 준다.
	if GameState.is_custom_cat(str(cat.id)):
		var prog := GameState.my_parts_progress()
		_draw_center_text(ci, font, tr("CHAR_MINE_HINT"), 522.0, 20,
				UiKit.PURPLE_DEEP, POPUP_SIZE.x)
		_draw_center_text(ci, font, "🎨 %d / %d" % [prog.x, prog.y], 556.0, 24,
				GOLD_COL, POPUP_SIZE.x)
		_draw_center_text(ci, font, tr("CHAR_MINE_HINT2"), 584.0, 17,
				UiKit.MUTED, POPUP_SIZE.x)
	else:
		_draw_keycap_progress(ci, str(cat.id), 530.0)
	# Affection hearts (snacks fed) — unlocked cats only.
	if unlocked:
		var level := GameState.affection_level(cat.id)
		var hearts := "♥".repeat(level) + "♡".repeat(10 - level)
		var line := tr("CHAR_AFFECTION").format({"level": level, "hearts": hearts})
		if level > 1:
			line += tr("CHAR_AFFECTION_BONUS").format(
					{"pct": roundi(GameState.affection_bonus(cat.id) * 100)})
		_draw_center_text(ci, font, line, 620.0, 20,
				Color("e0578a"), POPUP_SIZE.x)
	if unlocked and GameState.selected_cat == cat.id:
		_draw_center_text(ci, font, tr("CHAR_EQUIPPED"), POPUP_SIZE.y - 92.0, 19,
				GOLD_COL, POPUP_SIZE.x)


## 이 냥이의 키캡 수집 현황 — 이번 바퀴 진행 바 + 등급.
## 잠긴 냥이에게는 이 바가 그대로 해금 게이지다 (A~Z 한 바퀴 = 합류).
func _draw_keycap_progress(ci: Control, id: String, y: float) -> void:
	var font := ThemeDB.fallback_font
	var ring := GameState.keycap_ring(id)
	var grade := GameState.cat_grade(id)
	var top := GameState.KEYCAP_GRADE_MAX
	var full := grade >= top
	_draw_center_text(ci, font, tr("CHAR_KEYCAP").format(
			{"ring": ring, "grade": grade, "max": top}), y, 20, GOLD_COL, POPUP_SIZE.x)
	var bar := Rect2((POPUP_SIZE.x - 340.0) / 2.0, y + 14.0, 340.0, 16.0)
	ci.draw_rect(bar, Color(INK, 0.10))
	var frac := 1.0 if full else ring / 26.0
	if frac > 0.0:
		ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)),
				UiKit.GOLD_DEEP if full else UiKit.ORANGE)
	ci.draw_rect(bar, Color(INK, 0.35), false, 2.0)
	var note := ""
	if full:
		note = tr("CHAR_KEYCAP_MAX")
	elif grade == 0:
		note = tr("CHAR_LOCK_KEYCAP").format({"left": GameState.keycaps_to_next(id)})
	else:
		note = tr("CHAR_KEYCAP_NEXT").format(
				{"left": GameState.keycaps_to_next(id), "grade": grade + 1})
	_draw_center_text(ci, font, note, y + 54.0, 17, UiKit.MUTED, POPUP_SIZE.x)


func _refresh_tiles() -> void:
	for id: String in _tiles:
		_style_tile(_tiles[id], GameState.get_cat(id))
		(_tiles[id].get_child(0) as Control).queue_redraw()
	queue_redraw()


# --- Currency + toast ---------------------------------------------------------


## 우상단 지갑 — 흰 알약 위에 골드/보석.
func _build_currency_display() -> void:
	var pill := Panel.new()
	pill.size = Vector2(320.0, 56.0)
	pill.position = Vector2(vw - 350.0, 20.0)
	pill.add_theme_stylebox_override("panel", UiKit.panel_box(UiKit.WHITE, 31, 0.0))
	$UI.add_child(pill)
	_currency_label = Label.new()
	_currency_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_currency_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_currency_label.add_theme_font_size_override("font_size", 26)
	pill.add_child(_currency_label)
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
	_toast.add_theme_color_override("font_outline_color", INK)
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
	UiKit.paint_backdrop(self, vp)
	_draw_logo()
	# 선택한 냥이가 로고 옆(세로 화면은 아래)에 앉아 손님을 맞는다.
	# 애정도 5 이상이면 기분 좋게 통통 튄다.
	var at := _cat_anchor
	if GameState.affection_level(GameState.selected_cat) >= 5:
		at.y += sin(_bob * 5.0) * 7.0
	# 발밑 그림자 — 밝은 배경에서 캐릭터를 띄워 준다.
	UiKit.ellipse(self, _cat_anchor + Vector2(0.0, _cat_size * 0.56),
			Vector2(_cat_size * 0.42, _cat_size * 0.1), Color(0.2, 0.35, 0.45, 0.16))
	Player.paint_cat(self, at, _cat_size, 0.0, true, false,
			GameState.cat_skin(GameState.selected_cat))
	_draw_stat_line()


## 블록 글자 로고 "CAT-TRIS" — 컨셉의 통통한 블록 타이포.
func _draw_logo() -> void:
	var text := "CAT-TRIS"
	var w := UiKit.block_text_width(text, _logo_cell)
	UiKit.block_text(self, Vector2((vw - w) / 2.0, _logo_top), text, _logo_cell)
	UiKit.center_text_outlined(self, tr("MENU_TAGLINE"),
			_logo_top + _logo_cell * 6.6, vw, int(maxf(28.0, _logo_cell * 0.6)),
			UiKit.WHITE, 0.0, 7)


## 선택한 냥이의 한 줄 능력치 — 타이틀 고양이 바로 아래.
func _draw_stat_line() -> void:
	var cat := GameState.get_cat(GameState.selected_cat)
	var stats: Dictionary = GameState.cat_stats(cat.id)
	var font := ThemeDB.fallback_font
	var parts: Array[String] = []
	for entry in STAT_ROWS:
		var pips := _stat_pips(entry[1], stats.get(entry[1], 1.0))
		parts.append("%s %s%s" % [tr(entry[0]), "●".repeat(pips), "○".repeat(5 - pips)])
	var y := _cat_anchor.y + _cat_size * 0.72
	UiKit.center_text_outlined(self, "%s · %s" % [tr(str(cat.name)),
			tr(str(cat.get("trait", "")))],
			y, _cat_size * 2.4, 28, UiKit.CREAM, _cat_anchor.x - _cat_size * 1.2, 7)
	var text := "   ".join(parts)
	# 자리에 넘치면 폰트를 줄여서 한 줄에 맞춘다 (세로 화면 대응).
	var size := 19
	var room := minf(_cat_size * 2.6, vw - 40.0)
	while font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > room \
			and size > 11:
		size -= 1
	UiKit.center_text_outlined(self, text, y + 34.0, room, size, UiKit.WHITE,
			_cat_anchor.x - room / 2.0, maxi(3, size / 4))
