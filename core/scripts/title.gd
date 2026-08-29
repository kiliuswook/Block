extends Node2D
## Title screen: pick a game mode with the buttons or the 1 / 2 keys,
## and pick / buy a cube-cat skin in the character row at the bottom.

const UiKit := preload("res://core/scripts/ui_kit.gd")

const CREAM := UiKit.CREAM
const GOLD_COL := UiKit.GOLD_DEEP  # 흰 패널 위에서도 읽히는 진한 금색
const INK := UiKit.INK

const SETTINGS_PANEL := preload("res://core/scripts/settings_panel.gd")
const USER_HUD := preload("res://core/scripts/user_hud.gd")
const CAT_CUSTOMIZER := preload("res://core/scripts/cat_customizer.gd")
## [개발용 · 출시 빌드에서 제거] 업적·리더보드를 눈으로 확인하는 임시 패널.
const DEV_PANEL := preload("res://core/scripts/dev_panel.gd")
const TILE_SIZE := Vector2(128.0, 178.0)
const TILE_GAP := 14.0
const STAT_ROWS := [["STAT_SPEED", "speed"], ["STAT_JUMP", "jump"],
		["STAT_DASH", "dash"], ["STAT_WEIGHT", "weight"], ["STAT_PUSH", "push"]]
const KEY_ROWS: Array[String] = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
const KEY_GAP := 8.0
## 캐릭터 페이지 (UI 문서 19~23p): 헤더 · 캐릭터 스트립 · 본문 3단.
const CHAR_HEAD_H := 132.0
const CHAR_STRIP_H := 208.0
const CHAR_MARGIN := 28.0
const CHAR_COL_GAP := 20.0
const CHAR_LEFT_W := 380.0
const CHAR_RIGHT_W := 250.0
## 가운데 카드에서 꾸미기 패널이 시작하는 y (카드 제목 아래).
const CHAR_CUSTOM_TOP := 74.0
## 모드별 최대 인원 — 여기 없는 모드는 1인 전용. 화면 분할은 무한의 계단과
## 스테이지 모드가 지원한다 (분할에서는 LINES 랙 대신 좌석 라벨로 진행을 읽는다).
const MODE_PLAYERS := {GameState.MODE_ENDLESS: 2, GameState.MODE_CLASSIC: 2}
## 뽑기 화면 — 왼쪽 캡슐 기계와 아래 당첨 트레이 크기.
const GACHA_MACHINE_W := 300.0
const GACHA_MACHINE_H := 430.0
const GACHA_TRAY_H := 192.0
## 기계 돔 안에 채워 둔 캡슐 자리 (돔 반지름 70 기준 오프셋).
const DOME_CAPSULES: Array[Vector2] = [
	Vector2(-52.0, 22.0), Vector2(-16.0, 40.0), Vector2(22.0, 30.0),
	Vector2(54.0, 12.0), Vector2(-38.0, -14.0), Vector2(2.0, -4.0),
	Vector2(40.0, -22.0), Vector2(-8.0, -44.0), Vector2(-62.0, -8.0),
]
## 캡슐 하나가 굴러 나와 열리기까지의 연출 타이밍 (초).
const CAPSULE_STEP := 0.13
const CAPSULE_FALL := 0.34
const CAPSULE_HOLD := 0.16
const CAPSULE_OPEN := 0.26

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
var max_tiles_per_row := 99  # 모바일 타이틀이 줄바꿈을 위해 줄인다
var main_scene := "res://core/scenes/main.tscn"  # 플랫폼 타이틀이 교체 가능
var allow_2p := true  # 모바일 타이틀은 false (키보드 한 대가 필요한 2인 모드 없음)

var _tiles := {}  # cat id -> Button
var _user_hud: CanvasLayer  # 좌상단 고정 유저 HUD (이름 · 레벨 · 경험치 · 골드)
var _toast: Label
var _toast_tween: Tween
var _customizer: Control
var _settings: Control
var _gacha: Control  # 뽑기 오버레이 (캡슐 가챠)
var _gacha_machine: Control  # 캡슐 뽑기 기계 연출
var _gacha_tray: Control  # 뽑은 캡슐이 굴러 나오는 당첨 트레이
var _gacha_btns: Array[Button] = []  # [1개, 10개]
var _gacha_mode_btns: Array[Button] = []  # [랜덤, 선택]
var _gacha_pick_ui: Control  # 선택 뽑기용 냥이 칩 판
var _gacha_chips := {}  # cat id -> 선택 뽑기 칩 Button
var _gacha_count: Label
var _gacha_desc: Label
var _gacha_pick_mode := false  # false = 랜덤 뽑기, true = 선택 뽑기
var _last_pull: Array = []  # draw_keycaps()가 돌려준 마지막 결과
var _pull_t := 0.0  # 캡슐 연출 경과 시간
var _pull_anim := false
var _spin_t := 0.0  # 기계 손잡이/캡슐 상시 애니메이션
var _modes: Control  # PLAY로 여는 모드 선택 오버레이
var _chars: Control  # CHARACTER로 여는 캐릭터 선택 오버레이
var _players_chips: Array[Button] = []  # 타이틀 메뉴에 상주하는 1인 / 2인 토글
var _mode_rows: Array = []  # 모드 행 [{mode, btn, desc, tag, face, deep, size}]
var _pick := false  # 캐릭터 선택이 "게임 시작 전 픽" 모드인가
var _pick_mode := GameState.MODE_CLASSIC  # 픽이 끝나면 시작할 모드
var _pick_count := 1  # 이번 판 인원 (1 또는 2)
var _pick_slot := 0  # 지금 고르는 자리 (0 = 1P, 1 = 2P)
var _pick_cats: Array[String] = ["cream", "cream"]  # 자리별 고른 냥이
var _char_view := "cream"  # 본문 3단에 펼쳐 놓은 냥이
var _char_strip: HBoxContainer  # 캐릭터 타일이 늘어서는 스트립
var _char_scroll: ScrollContainer  # 스트립을 담는 가로 스크롤
var _char_seat_tabs: Array[Button] = []  # 2인 세팅에서 뜨는 1P / 2P 좌석 탭
var _char_left: Control  # 능력치 카드
var _char_center: Control  # 키캡 도감 / 커스터마이징 카드
var _char_right: Control  # 보상 열
var _char_star: Button  # 대표 캐릭터 지정 (★)
var _customizer_on := false  # 가운데 카드가 꾸미기 패널을 띄우고 있는가
var _feature_ask: Control  # 대표 캐릭터 확인 팝업
var _feature_face: Control
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
var _dev: Control  # [개발용] 업적·리더보드 확인 패널 (DEV_PANEL.ENABLED)
var _nick_edit: LineEdit
var _replay_viewer: Control


func _ready() -> void:
	# 이 타이틀이 뜬 플랫폼을 개발용 상태로 기록 (플랫폼 타이틀은 super 후 덮어씀).
	preload("res://core/scripts/boot.gd").dev_platform = ""
	vw = get_viewport_rect().size.x
	vh = get_viewport_rect().size.y
	UiKit.apply_theme($UI)
	# 세이브 상태로 판정되는 업적을 소급 적용한다 (업적을 나중에 추가해도
	# 이미 조건을 만족한 세이브는 여기서 해금된다).
	Achv.check()
	# 커브를 손댔거나 구버전 세이브라면 밀린 레벨 보상을 여기서 따라잡는다.
	Account.sync()
	# 로고는 코드로 그린다 — 씬의 텍스트 타이틀은 숨긴다.
	$UI/TitleLabel.visible = false
	$UI/SubtitleLabel.visible = false
	$UI/HintLabel.visible = false
	classic_btn.pressed.connect(func() -> void: _on_mode_picked(GameState.MODE_CLASSIC))
	endless_btn.pressed.connect(func() -> void: _on_mode_picked(GameState.MODE_ENDLESS))
	_refresh_classic_desc()
	_compute_layout()
	_build_user_hud()
	_build_character_page()
	_build_toast()
	_build_settings()
	_build_mode_select()
	_build_menu()
	_build_gacha()
	_build_ranks()
	_build_keycap_dex()
	_build_dev_panel()
	UiKit.apply_theme($UI)  # 코드로 만든 오버레이까지 컨셉 테마를 덮는다
	# 리플레이 뷰어는 의도적으로 어두운 무대 연출 — 테마 제외.
	_replay_viewer.theme = null
	_customizer.changed.connect(func() -> void:
		_refresh_tiles()
		_refresh_currency()  # HUD 아바타
		if _chars and _chars.visible:
			_refresh_char_page())
	Ranks.board_loaded.connect(func(_ok: bool) -> void:
		if _ranks and _ranks.visible:
			_refresh_rank_list())
	Ranks.weekly_reward.connect(func(g: int) -> void:
		Sfx.play("record")
		_show_toast(tr("MENU_WEEKLY_PRIZE").format({"gold": g}), GOLD_COL)
		_refresh_currency())
	Sfx.play_bgm("title")


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
		# 상단 유저 HUD 카드(좌상단, ~112px)와 겹치지 않게 로고를 그 아래로 민다.
		_logo_cell = minf(44.0, (vw - 200.0) / 32.0)
		_logo_top = maxf(vh * 0.11, USER_HUD.MARGIN.y + USER_HUD.CARD.y + 22.0)
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
	var play_h := area.size.y * 0.22
	var seat_h := area.size.y * 0.125 if allow_2p else 0.0
	var card_h := area.size.y * 0.195
	var play := Button.new()
	play.text = "▶   PLAY"
	play.position = area.position
	play.size = Vector2(area.size.x, play_h)
	UiKit.btn_primary(play, int(play_h * 0.42))
	play.pressed.connect(func() -> void:
		Sfx.play("click")
		_open_modes())
	$UI.add_child(play)
	# 인원은 여기서 미리 정해 둔다 — 모드를 고를 때마다 다시 묻지 않는다.
	var seat_y := play_h + gap
	if allow_2p:
		_players_chips.clear()
		for i in 2:
			var count := i + 1
			var chip := Button.new()
			chip.text = "%s  %s" % ["👤" if count == 1 else "👥",
					tr("MENU_PLAYERS_1" if count == 1 else "MENU_PLAYERS_2")]
			chip.position = area.position + Vector2(i * (card_w + gap), seat_y)
			chip.size = Vector2(card_w, seat_h)
			chip.pressed.connect(func() -> void: _set_players(count))
			$UI.add_child(chip)
			_players_chips.append(chip)
		_refresh_players_chips()
		seat_y += seat_h + gap
	var cards := [
		[tr("MENU_CHARACTER"), UiKit.GOLD_DEEP, func() -> void: _open_chars()],
		[tr("MENU_GACHA"), UiKit.CYAN_DEEP, func() -> void: _open_gacha()],
		[tr("MENU_RANKING"), UiKit.GOLD_DEEP, func() -> void: _open_ranks()],
		[tr("MENU_SETTINGS"), UiKit.PURPLE_DEEP, func() -> void: _settings.open()],
	]
	for i in cards.size():
		var entry: Array = cards[i]
		var b := Button.new()
		b.text = str(entry[0])
		b.position = area.position + Vector2((i % 2) * (card_w + gap),
				seat_y + (i / 2) * (card_h + gap))
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
	cap.position = area.position + Vector2(0.0, seat_y + card_h * 2.0 + gap * 2.0)
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
	_mode_rows.clear()
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
		# 인원 뱃지 — 인원을 먼저 고르는 흐름이라 여기서 "이 모드가 되는지"를 알린다.
		var tag := Label.new()
		tag.position = Vector2(pw - 240.0, y + row_h + 2.0)
		tag.size = Vector2(236.0, 26.0)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tag.add_theme_font_size_override("font_size", 20)
		panel.add_child(tag)
		_mode_rows.append({"mode": int(e[5]), "btn": btn, "desc": desc, "tag": tag,
				"face": e[3], "deep": e[4], "size": int(row_h * 0.3)})
		y += row_h + 40.0
	_modes.visible = false


## 인원 선택 결과에 맞춰 모드 행을 켜고 끈다 (2인 불가 모드는 회색 + 안내 뱃지).
func _refresh_mode_rows() -> void:
	for row: Dictionary in _mode_rows:
		var btn: Button = row["btn"]
		var tag: Label = row["tag"]
		var maxp := _max_players(int(row["mode"]))
		var ok := maxp >= _pick_count
		btn.disabled = not ok
		if ok:
			UiKit.style_button(btn, row["face"], row["deep"], INK, int(row["size"]), 16)
		else:
			UiKit.style_button(btn, Color("dcdae0"), Color("b0adb8"),
					Color("6b6875"), int(row["size"]), 16)
		(row["desc"] as Label).add_theme_color_override("font_color",
				UiKit.MUTED if ok else Color(0.17, 0.16, 0.2, 0.32))
		if not ok:
			tag.text = tr("MENU_MODE_SOLO_ONLY")
			tag.add_theme_color_override("font_color", UiKit.RED_DEEP)
		elif maxp > 1:
			tag.text = "1–2P"
			tag.add_theme_color_override("font_color", UiKit.CYAN_DEEP)
		else:
			tag.text = "1P"
			tag.add_theme_color_override("font_color", UiKit.MUTED)


## 오버레이를 항상 메뉴 위로 올린다 (형제 순서 = 그리는 순서).
func _raise(c: Control) -> void:
	if c != null and c.get_parent() != null:
		c.get_parent().move_child(c, -1)


func _open_modes() -> void:
	# 인원은 타이틀에서 미리 정해 둔 값을 그대로 따른다.
	_pick_count = _seats()
	_raise(_modes)
	_refresh_classic_desc()
	_refresh_mode_rows()
	# 지금 몇 명으로 시작하는지를 제목에 계속 붙여 둔다.
	var head: Label = _modes.get_meta("head")
	head.text = tr("MENU_MODE_SELECT")
	if allow_2p:
		head.text += "  ·  %s" % tr("MENU_PLAYERS_1" if _pick_count < 2 else "MENU_PLAYERS_2")
	_modes.visible = true


## 타이틀에 미리 세팅해 둔 참가 인원 (2인이 없는 플랫폼은 항상 1인).
func _seats() -> int:
	if not allow_2p:
		return 1
	return clampi(GameState.players, 1, 2)


## 이 모드가 받을 수 있는 최대 인원 (모바일 타이틀은 항상 1인).
func _max_players(mode: int) -> int:
	if not allow_2p:
		return 1
	return int(MODE_PLAYERS.get(mode, 1))


## 인원이 이미 정해진 뒤의 단계 — 모드를 고르면 바로 캐릭터 픽으로 넘어간다.
func _on_mode_picked(mode: int) -> void:
	if _max_players(mode) < _pick_count:
		Sfx.play("error")
		_show_toast(tr("MENU_MODE_SOLO_ONLY"), UiKit.RED_DEEP)
		return
	_pick_mode = mode
	if _modes:
		_modes.visible = false
	# 캐릭터는 타이틀에서 이미 정해 뒀다 — 모드를 고르면 곧장 시작.
	_start(mode, _pick_count > 1)


# --- 타이틀에 상주하는 인원 토글 -------------------------------------------------


## 1인 / 2인을 타이틀에서 미리 정해 둔다 (save.json에 남아 다음 실행에도 유지).
func _set_players(count: int) -> void:
	if GameState.players == count:
		return
	Sfx.play("click")
	GameState.players = count
	GameState.save_game()
	_pick_count = _seats()
	_refresh_players_chips()
	# 모드 선택이 떠 있는 채로 바꿨다면 잠금 상태도 곧바로 다시 계산한다.
	if _modes and _modes.visible:
		_open_modes()
	# 캐릭터 세팅이 열려 있으면 자리 수를 바로 맞춘다.
	if _chars and _chars.visible:
		_pick_slot = mini(_pick_slot, _pick_count - 1)
		_commit_pick()
		_refresh_chars_head()
		_refresh_char_page()


func _refresh_players_chips() -> void:
	for i in _players_chips.size():
		var chip: Button = _players_chips[i]
		UiKit.btn_chip(chip, _seats() == i + 1, int(chip.size.y * 0.42))


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
	# [개발용 · 출시 빌드에서 제거] 확인 패널은 우상단 DEV 버튼으로만 연다
	# (웹 빌드에서 단축키가 브라우저에 먹히는 경우가 있어 버튼 하나로 통일).
	if _dev and _dev.visible:
		if event is InputEventKey and event.pressed 				and event.physical_keycode == KEY_ESCAPE:
			_dev.close()
		return
	if _settings_open():
		if event is InputEventKey and event.pressed \
				and event.physical_keycode == KEY_ESCAPE:
			_settings.close()
		return
	if _gacha and _gacha.visible:
		if event is InputEventKey and event.pressed \
				and event.physical_keycode == KEY_ESCAPE:
			_close_gacha()
		return
	if _keycap_dex and _keycap_dex.visible:
		if event is InputEventKey and event.pressed \
				and event.physical_keycode == KEY_ESCAPE:
			_keycap_dex.visible = false
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
	if _feature_ask and _feature_ask.visible:
		if event is InputEventKey and event.pressed \
				and event.physical_keycode == KEY_ESCAPE:
			_feature_ask.visible = false
		return
	if _chars and _chars.visible:
		if event is InputEventKey and event.pressed \
				and event.physical_keycode == KEY_ESCAPE:
			_close_chars()
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


# --- 뽑기 (캡슐 가챠) ---------------------------------------------------------


## 뽑기 오버레이 — 파는 것은 키캡 캡슐 하나뿐이고, 뽑는 방식이 둘이다.
##  · 랜덤 뽑기: 전체 냥이 대상
##  · 선택 뽑기: 고른 KEYCAP_PICK_SIZE마리만 캡슐에 들어간다 (값은 비싸다)
## 연출은 동전 넣고 손잡이를 돌리는 장난감 캡슐 뽑기 기계.
func _build_gacha() -> void:
	var pw := minf(vw - 60.0, 1000.0)
	var ph := minf(vh - 90.0, 860.0)
	_gacha = _make_overlay(tr("SHOP_TITLE"), func() -> void: _close_gacha(),
			Vector2(pw, ph))
	var body: Control = _gacha.get_meta("body")
	var bw := body.size.x
	var bh := body.size.y
	# 지갑은 상단 유저 HUD 하나뿐 — 여기 또 그리지 않는다.
	var top_y := 40.0
	var tray_y := bh - GACHA_TRAY_H
	# 왼쪽 — 캡슐 뽑기 기계 (연출 전담, 클릭은 받지 않는다).
	var mach_h := minf(GACHA_MACHINE_H, tray_y - top_y - 12.0)
	_gacha_machine = Control.new()
	_gacha_machine.position = Vector2(0.0,
			top_y + (tray_y - top_y - 12.0 - mach_h) / 2.0)
	_gacha_machine.size = Vector2(GACHA_MACHINE_W, mach_h)
	_gacha_machine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gacha_machine.draw.connect(func() -> void: _draw_machine(_gacha_machine))
	body.add_child(_gacha_machine)
	# 오른쪽 — 뽑기 종류 · 냥이 선택 · 뽑기 버튼.
	var rx := GACHA_MACHINE_W + 26.0
	var rw := bw - rx
	var half := (rw - 12.0) / 2.0
	for i in 2:
		var pick := i == 1
		var b := Button.new()
		b.text = tr("SHOP_GACHA_PICK" if pick else "SHOP_GACHA_RANDOM")
		b.position = Vector2(rx + i * (half + 12.0), top_y)
		b.size = Vector2(half, 56.0)
		b.pressed.connect(func() -> void:
			Sfx.play("click")
			_gacha_pick_mode = pick
			_refresh_gacha())
		body.add_child(b)
		_gacha_mode_btns.append(b)
	_gacha_desc = Label.new()
	_gacha_desc.position = Vector2(rx, top_y + 62.0)
	_gacha_desc.size = Vector2(rw, 46.0)
	_gacha_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gacha_desc.add_theme_font_size_override("font_size", 18)
	_gacha_desc.add_theme_color_override("font_color", UiKit.MUTED)
	body.add_child(_gacha_desc)
	# 냥이 칩 — 선택 뽑기에서는 고르는 판이고, 랜덤 뽑기에서는 이번 풀 미리보기다
	# (칩을 누르면 그대로 선택 뽑기로 넘어간다).
	var pick_y := top_y + 112.0
	var btn_y := tray_y - 92.0
	# 냥이가 늘어나도(목표 30마리) 칩 크기는 그대로 두고 세로로 스크롤한다.
	_gacha_pick_ui = ScrollContainer.new()
	_gacha_pick_ui.position = Vector2(rx, pick_y)
	_gacha_pick_ui.size = Vector2(rw, btn_y - pick_y - 34.0)
	_gacha_pick_ui.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_gacha_pick_ui)
	var grid := Control.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gacha_pick_ui.add_child(grid)
	var cats := GameState.keycap_cats()
	var per_row := maxi(1, int((rw - 12.0) / 124.0))
	var chip := Vector2((rw - 12.0 * (per_row - 1) - 14.0) / per_row, 126.0)
	var rows := int(ceilf(cats.size() / float(per_row)))
	grid.custom_minimum_size = Vector2(rw - 14.0, rows * (chip.y + 10.0) - 10.0)
	for i in cats.size():
		var cat: Dictionary = cats[i]
		var b := Button.new()
		b.position = Vector2((i % per_row) * (chip.x + 12.0),
				(i / per_row) * (chip.y + 10.0))
		b.size = chip
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var face := Control.new()
		face.set_anchors_preset(Control.PRESET_FULL_RECT)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.draw.connect(func() -> void: _draw_gacha_chip(face, cat))
		b.add_child(face)
		b.pressed.connect(func() -> void: _toggle_gacha_pick(str(cat.id)))
		grid.add_child(b)
		_gacha_chips[str(cat.id)] = b
	_gacha_count = Label.new()
	_gacha_count.position = Vector2(rx, btn_y - 32.0)
	_gacha_count.size = Vector2(rw, 28.0)
	_gacha_count.add_theme_font_size_override("font_size", 19)
	_gacha_count.add_theme_color_override("font_color", GOLD_COL)
	_gacha_count.clip_text = true
	body.add_child(_gacha_count)
	# 1개 / 10개 뽑기.
	for i in 2:
		var n: int = 1 if i == 0 else GameState.KEYCAP_GACHA_BULK
		var b := Button.new()
		b.position = Vector2(rx + i * (half + 12.0), btn_y)
		b.size = Vector2(half, 82.0)
		b.pressed.connect(func() -> void: _on_gacha(n))
		UiKit.btn_primary(b, 24)
		body.add_child(b)
		_gacha_btns.append(b)
	# 아래 — 캡슐이 굴러 나오는 당첨 트레이.
	_gacha_tray = Control.new()
	_gacha_tray.position = Vector2(0.0, tray_y)
	_gacha_tray.size = Vector2(bw, GACHA_TRAY_H)
	_gacha_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gacha_tray.clip_contents = true  # 튀어오른 뚜껑이 트레이 밖으로 나가지 않게
	_gacha_tray.draw.connect(func() -> void: _draw_gacha_tray(_gacha_tray))
	body.add_child(_gacha_tray)


## 선택 뽑기의 냥이 칩 — 얼굴 + 이름, 고른 냥이는 금색 체크.
func _draw_gacha_chip(ci: Control, cat: Dictionary) -> void:
	var id := str(cat.id)
	var unlocked: bool = GameState.is_unlocked(id)
	var center := Vector2(ci.size.x / 2.0, ci.size.y * 0.36)
	var skin: Dictionary = GameState.cat_skin(id)
	if not unlocked:
		skin = GameState.cat_shadow_skin(id)
	Player.paint_cat(ci, center, ci.size.y * 0.46, 0.0, true, false, skin)
	var font := ThemeDB.fallback_font
	_draw_center_text(ci, font, tr(str(cat.name)), ci.size.y - 30.0, 17,
			INK if unlocked else UiKit.MUTED, ci.size.x)
	_draw_center_text(ci, font, "▦ %d / 26" % GameState.keycap_ring(id),
			ci.size.y - 10.0, 14, UiKit.MUTED, ci.size.x)
	if id in GameState.gacha_pick:
		# 고른 냥이 — 우상단에 금색 체크 뱃지.
		var at := Vector2(ci.size.x - 18.0, 18.0)
		ci.draw_circle(at, 13.0, GOLD_COL)
		ci.draw_polyline(PackedVector2Array([at + Vector2(-6.0, 0.0),
				at + Vector2(-2.0, 5.0), at + Vector2(6.0, -6.0)]), UiKit.WHITE, 3.0)


func _toggle_gacha_pick(id: String) -> void:
	var pick: Array = GameState.gacha_pick.duplicate()
	if id in pick:
		pick.erase(id)
		Sfx.play("click")
	elif pick.size() >= GameState.KEYCAP_PICK_SIZE:
		Sfx.play("error")
		_show_toast(tr("SHOP_GACHA_FULL").format(
				{"max": GameState.KEYCAP_PICK_SIZE}), Color(1.0, 0.55, 0.5))
		return
	else:
		pick.append(id)
		Sfx.play("buy")
	GameState.gacha_pick = pick
	GameState.save_game()
	# 선택 뽑기 칩을 건드렸다는 건 그 모드를 쓰겠다는 뜻이다.
	_gacha_pick_mode = true
	_refresh_gacha()


## 캡슐 n개 뽑기. 결과는 아래 트레이에 캡슐로 굴러 나와 열린다.
func _on_gacha(n: int) -> void:
	var pick: Array = GameState.gacha_pick if _gacha_pick_mode else []
	if _gacha_pick_mode and pick.size() < GameState.KEYCAP_PICK_SIZE:
		Sfx.play("error")
		_show_toast(tr("SHOP_GACHA_PICK_NEED").format(
				{"n": GameState.KEYCAP_PICK_SIZE}), Color(1.0, 0.55, 0.5))
		return
	var pull := GameState.draw_keycaps(n, pick)
	if pull.is_empty():
		Sfx.play("error")
		_show_toast(tr("SHOP_NO_GOLD"), Color(1.0, 0.55, 0.5))
		return
	_last_pull = pull
	_pull_t = 0.0
	_pull_anim = true
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
	_refresh_gacha()
	_refresh_currency()
	_refresh_tiles()
	if _keycap_dex.visible:
		_refresh_keycap_dex()


# --- 뽑기 기계 그리기 ----------------------------------------------------------


## 돔 + 몸통 + 손잡이 + 배출구. 돔 안의 캡슐 색은 이번 뽑기 풀의 냥이 색이라,
## 선택 뽑기로 냥이를 고르면 기계 안 캡슐 색도 그 냥이들로 바뀐다.
func _draw_machine(ci: Control) -> void:
	var w := ci.size.x
	var h := ci.size.y
	var dome_r := minf(w * 0.38, h * 0.3)
	var dome_c := Vector2(w / 2.0, dome_r + 14.0)
	var body_top := dome_c.y + dome_r * 0.62
	var pool := _gacha_pool_colors()
	# 발밑 그림자.
	UiKit.ellipse(ci, Vector2(w / 2.0, h - 6.0), Vector2(w * 0.36, 10.0),
			Color(0.2, 0.35, 0.45, 0.16))
	# 몸통 — 통통한 하늘색 상자.
	var body := Rect2(w * 0.13, body_top, w * 0.74, h - body_top - 12.0)
	_round_box(ci, body, UiKit.CYAN, 24)
	_round_box(ci, Rect2(body.position + Vector2(0.0, body.size.y - 26.0),
			Vector2(body.size.x, 26.0)), UiKit.CYAN_DEEP, 24)
	# 돔 — 반투명 플라스틱 안에 캡슐이 가득.
	ci.draw_circle(dome_c, dome_r, Color(1.0, 1.0, 1.0, 0.82))
	for i in DOME_CAPSULES.size():
		var off: Vector2 = DOME_CAPSULES[i]
		# 뽑는 동안에는 캡슐이 통 안에서 통통 튄다.
		var jig := 3.0 if _pull_anim else 1.2
		var at := dome_c + off * dome_r / 70.0
		at += Vector2(sin(_spin_t * 3.4 + i) * jig, cos(_spin_t * 4.1 + i * 1.7) * jig)
		_draw_capsule(ci, at, dome_r * 0.17, pool[i % pool.size()], 0.0)
	ci.draw_arc(dome_c, dome_r, 0.0, TAU, 48, INK, 5.0)
	# 돔에 얹힌 하이라이트 — 빛은 항상 위에서.
	ci.draw_arc(dome_c, dome_r * 0.78, PI * 1.15, PI * 1.55, 16,
			Color(1, 1, 1, 0.75), 7.0)
	# 손잡이 — 뽑는 동안 힘차게 돈다.
	var knob := Vector2(w / 2.0, body_top + body.size.y * 0.34)
	var kr := minf(28.0, body.size.y * 0.22)
	ci.draw_circle(knob, kr, UiKit.WHITE)
	ci.draw_arc(knob, kr, 0.0, TAU, 32, INK, 4.0)
	var spin := _spin_t * (7.0 if _pull_anim else 0.6)
	for i in 2:
		var a := spin + PI * i / 2.0
		var d := Vector2(cos(a), sin(a)) * kr * 0.62
		ci.draw_line(knob - d, knob + d, INK, 6.0)
	# 동전 투입구 — 손잡이 옆 작은 슬롯.
	var slot_w := body.size.x * 0.1
	_round_box(ci, Rect2(knob.x + kr + 14.0, knob.y - 9.0, slot_w, 18.0),
			Color(0.16, 0.2, 0.26), 6)
	# 배출구.
	var chute := Rect2(w / 2.0 - body.size.x * 0.24,
			body_top + body.size.y * 0.62, body.size.x * 0.48,
			body.size.y * 0.3)
	_round_box(ci, chute, Color(0.16, 0.2, 0.26), 14)
	ci.draw_rect(Rect2(chute.position + Vector2(8.0, 6.0),
			Vector2(chute.size.x - 16.0, 5.0)), Color(1, 1, 1, 0.18))


## 이번 뽑기에 들어가는 냥이들의 캡슐 색 (풀이 비면 기본 팔레트).
func _gacha_pool_colors() -> Array:
	var pick: Array = GameState.gacha_pick if _gacha_pick_mode else []
	var out: Array = []
	for id: String in GameState.gacha_pool(pick):
		out.append(GameState.get_cat(id).ear)
	if out.is_empty():
		out = [UiKit.GOLD, UiKit.PINK, UiKit.CYAN, UiKit.PURPLE]
	return out


## 잉크 외곽선을 두른 둥근 상자 (기계 부품용).
func _round_box(ci: CanvasItem, r: Rect2, col: Color, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(4)
	sb.border_color = INK
	ci.draw_style_box(sb, r)


## 캡슐 한 알. open(0~1)이 1로 갈수록 위 뚜껑이 튀어오르며 열린다.
func _draw_capsule(ci: CanvasItem, c: Vector2, r: float, col: Color,
		open_amt: float) -> void:
	var bottom := PackedVector2Array()
	for i in 17:
		var a := PI * i / 16.0
		bottom.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(bottom, col)
	ci.draw_polyline(bottom, INK, maxf(1.5, r * 0.1))
	# 뚜껑 — 반투명 플라스틱. 열리면 위로 튀며 기울어진다.
	var lift := Vector2(r * 0.55 * open_amt, -r * 1.25 * open_amt)
	var rot := open_amt * 0.7
	var lid := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		var p := Vector2(cos(a), sin(a)) * r
		lid.append(c + p.rotated(rot) + lift)
	ci.draw_colored_polygon(lid, Color(1.0, 1.0, 1.0, 0.9 - 0.5 * open_amt))
	ci.draw_polyline(lid, Color(INK, 1.0 - 0.55 * open_amt), maxf(1.5, r * 0.1))
	if open_amt < 0.5:
		# 뚜껑 위 하이라이트.
		var hl := c + lift + Vector2(-r * 0.34, -r * 0.42).rotated(rot)
		UiKit.ellipse(ci, hl, Vector2(r * 0.24, r * 0.15),
				Color(1, 1, 1, 0.85 * (1.0 - open_amt * 2.0)))


# --- 당첨 트레이 --------------------------------------------------------------


## 뽑은 캡슐이 하나씩 굴러 나와 착지하고, 잠시 뒤 뚜껑이 열리며 키캡이 나온다.
func _draw_gacha_tray(ci: Control) -> void:
	var w := ci.size.x
	var h := ci.size.y
	_round_box(ci, Rect2(0.0, 0.0, w, h), Color("eef6fb"), 20)
	if _last_pull.is_empty():
		UiKit.center_text(ci, tr("SHOP_GACHA_EMPTY"), h / 2.0 + 8.0, w, 19,
				UiKit.MUTED)
		return
	var n := _last_pull.size()
	var cols := mini(n, 5)
	var rows := int(ceilf(n / float(cols)))
	var cw := minf(120.0, (w - 28.0) / cols)
	var ch := (h - 20.0) / rows
	var r := minf(cw * 0.4, (ch - 30.0) / 2.0)
	var x0 := (w - cw * cols) / 2.0
	var font := ThemeDB.fallback_font
	for i in n:
		var hit: Dictionary = _last_pull[i]
		var col := i % cols
		var row := i / cols
		var slot := Vector2(x0 + cw * (col + 0.5), 12.0 + ch * (row + 0.5) - 8.0)
		var t := _pull_t - i * CAPSULE_STEP
		if t <= 0.0:
			continue
		# ① 배출구에서 굴러떨어져 착지 ② 잠깐 멈춤 ③ 뚜껑이 열린다
		var fall := minf(t / CAPSULE_FALL, 1.0)
		var drop := 1.0 - pow(1.0 - fall, 3.0)
		var at := Vector2(slot.x, lerpf(slot.y - h - r, slot.y, drop))
		var open_amt := clampf((t - CAPSULE_FALL - CAPSULE_HOLD) / CAPSULE_OPEN,
				0.0, 1.0)
		# 착지 순간 살짝 눌렸다 펴진다.
		var squash := 0.0 if fall < 1.0 else maxf(0.0,
				1.0 - (t - CAPSULE_FALL) / 0.16)
		var rr := r * (1.0 + 0.12 * squash)
		UiKit.ellipse(ci, Vector2(at.x, slot.y + r * 0.92),
				Vector2(r * 0.72 * drop, r * 0.2), Color(0.2, 0.35, 0.45, 0.18))
		var cat_col: Color = GameState.get_cat(str(hit.cat)).ear
		_draw_capsule(ci, at, rr, cat_col, open_amt)
		if open_amt <= 0.0:
			continue
		# 키캡이 캡슐에서 솟아오른다 (살짝 오버슛).
		var pop := open_amt * (1.0 + 0.18 * sin(open_amt * PI))
		var cap := r * 1.5 * pop
		var cap_at := Rect2(at.x - cap / 2.0, at.y - cap * 0.62 - r * 0.5 * open_amt,
				cap, cap)
		EscapeBoard.paint_keycap(ci, cap_at, str(hit.letter), 0.6, false,
				str(hit.cat))
		if not hit.fresh:  # 중복은 흐리게 눌러 둔다
			ci.draw_rect(cap_at, Color(0.09, 0.13, 0.18, 0.38))
		if open_amt < 1.0:
			continue
		var label := tr(str(GameState.get_cat(str(hit.cat)).name))
		if hit.grade_up:
			label = "★ " + label
		var size := UiKit.fit_size(font, label, cw - 8.0, 15)
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		ci.draw_string(font, Vector2(at.x - tw / 2.0, slot.y + r + 16.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, size,
				GOLD_COL if hit.fresh else UiKit.MUTED)


func _process(delta: float) -> void:
	if _gacha == null or not _gacha.visible:
		return
	# 기계는 늘 살짝 움직이고, 뽑는 동안에는 캡슐이 굴러 나온다.
	_spin_t += delta
	_gacha_machine.queue_redraw()
	if not _pull_anim:
		return
	_pull_t += delta
	_gacha_tray.queue_redraw()
	var total := (_last_pull.size() - 1) * CAPSULE_STEP
	total += CAPSULE_FALL + CAPSULE_HOLD + CAPSULE_OPEN
	if _pull_t > total:
		_pull_anim = false


func _refresh_gacha() -> void:
	for i in _gacha_mode_btns.size():
		UiKit.btn_chip(_gacha_mode_btns[i], _gacha_pick_mode == (i == 1), 22)
	var picked: int = GameState.gacha_pick.size()
	if _gacha_pick_mode:
		_gacha_desc.text = tr("SHOP_GACHA_PICK_DESC").format(
				{"n": GameState.KEYCAP_PICK_SIZE,
				"pct": int(round((GameState.KEYCAP_PICK_MARKUP - 1.0) * 100.0))})
		_gacha_count.text = tr("SHOP_GACHA_PICK_COUNT").format(
				{"n": picked, "max": GameState.KEYCAP_PICK_SIZE})
		_gacha_count.add_theme_color_override("font_color", GOLD_COL)
	else:
		_gacha_desc.text = tr("SHOP_GACHA_RANDOM_DESC")
		_gacha_count.text = tr("SHOP_GACHA_RANDOM_HINT")
		_gacha_count.add_theme_color_override("font_color", UiKit.MUTED)
	for id: String in _gacha_chips:
		var b: Button = _gacha_chips[id]
		var on: bool = id in GameState.gacha_pick
		UiKit.style_button(b, Color("fff1cf") if on else UiKit.WHITE,
				UiKit.GOLD_DEEP if on else Color("c9c6d0"), INK, 18, 16)
		(b.get_child(0) as Control).queue_redraw()
	for i in _gacha_btns.size():
		var n: int = 1 if i == 0 else GameState.KEYCAP_GACHA_BULK
		_gacha_btns[i].text = tr("SHOP_GACHA_DRAW").format(
				{"n": n, "price": GameState.keycap_price(n, _gacha_pick_mode)})
	_gacha_machine.queue_redraw()
	_gacha_tray.queue_redraw()


func _open_gacha() -> void:
	_raise(_gacha)
	_refresh_gacha()
	_gacha.visible = true


func _close_gacha() -> void:
	_gacha.visible = false
	_pull_anim = false
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
	_keycap_board.draw.connect(func() -> void: _draw_keycap_plate(_keycap_board,
			Rect2(Vector2.ZERO, _keycap_board.size), _keycap_cat))
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
## 캐릭터 페이지의 도감 카드와 도감 오버레이가 같은 판을 그린다.
func _draw_keycap_plate(ci: Control, plate: Rect2, cat_id: String) -> void:
	var key := (plate.size.x - KEY_GAP * 9.0) / 10.0
	ci.draw_style_box(UiKit.panel_box(Color("e8f4fb"), 20, 0.0), plate)
	var font := ThemeDB.fallback_font
	for r in KEY_ROWS.size():
		var letters := KEY_ROWS[r]
		var row_w := letters.length() * key + (letters.length() - 1) * KEY_GAP
		var x := plate.position.x + (plate.size.x - row_w) / 2.0
		var y := plate.position.y + 22.0 + r * (key + KEY_GAP)
		for i in letters.length():
			var letter := letters[i]
			var rect := Rect2(x + i * (key + KEY_GAP), y, key, key)
			var count := GameState.keycap_count(cat_id, letter)
			if GameState.has_keycap(cat_id, letter):
				EscapeBoard.paint_keycap(ci, rect, letter, 0.6, false, cat_id)
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


# --- [개발용 · 출시 빌드에서 제거] 업적/리더보드 확인 패널 -----------------------


## 타이틀 우상단의 작은 DEV 버튼으로 여는 임시 확인 패널 (단축키는 두지 않는다).
## 끄려면 dev_panel.gd 의 ENABLED 를 false 로 두거나 이 함수와 호출을 지운다.
func _build_dev_panel() -> void:
	if not DEV_PANEL.ENABLED:
		return
	_dev = DEV_PANEL.new()
	$UI.add_child(_dev)
	var b := Button.new()
	b.text = "🛠 DEV"
	b.size = Vector2(120.0, 44.0)
	b.position = Vector2(vw - b.size.x - 24.0, 18.0)
	UiKit.btn_card(b, UiKit.PURPLE_DEEP, 17)
	b.pressed.connect(func() -> void:
		Sfx.play("click")
		_dev.open())
	$UI.add_child(b)


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
		_refresh_currency()  # HUD 이름도 같이
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
			Achv.unlock(Achv.REPLAY_WATCH)
			_replay_viewer.open(rep, "%s  ·  %s" % [name_text,
					Ranks.value_text(mode_key, v)]))
		h.add_child(play)
	return row


# --- 캐릭터 페이지 (UI 문서 19~23p) ------------------------------------------------


## 캐릭터 메뉴는 팝업이 아니라 전체 화면 페이지다 (UI 문서 20p):
##   헤더(제목 · 뒤로 — 골드는 좌상단 고정 유저 HUD가 맡는다)
##   캐릭터 스트립(디자인 냥이 → 커스텀 슬롯 → "+" 타일로 슬롯 추가)
##   본문 3단: 능력치 카드 · 키캡 도감(커스텀 슬롯이면 커스터마이징) · 보상 열
## 자리(1P·2P) 세팅도 여기서 겸한다 — 2인이면 헤더에 좌석 탭이 뜨고(문서 16p),
## 타일을 누르면 그 자리에 즉시 앉는다.
func _build_character_page() -> void:
	_chars = Control.new()
	_chars.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chars.visible = false
	$UI.add_child(_chars)
	# 페이지라 뒤가 비쳐서는 안 된다 — 타이틀과 같은 하늘 배경을 깐다.
	var bg := Control.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.draw.connect(func() -> void: UiKit.paint_backdrop(bg, Vector2(vw, vh), 7))
	_chars.add_child(bg)
	var head := Label.new()
	head.text = tr("CHAR_SELECT")
	head.position = Vector2(0.0, 28.0)
	head.size = Vector2(vw, 62.0)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 46)
	head.add_theme_color_override("font_color", INK)
	_chars.add_child(head)
	_chars.set_meta("head", head)
	var back := Button.new()
	back.text = tr("SET_BACK")
	back.size = Vector2(150.0, 62.0)
	back.position = Vector2(vw - 150.0 - CHAR_MARGIN, 24.0)
	UiKit.btn_ghost(back, 24)
	back.pressed.connect(func() -> void:
		Sfx.play("click")
		_close_chars())
	_chars.add_child(back)
	# 캐릭터 스트립 — 가로로 넘치면 스크롤된다 (커스텀 슬롯이 늘어난다).
	var strip := Panel.new()
	strip.position = Vector2(0.0, CHAR_HEAD_H)
	strip.size = Vector2(vw, CHAR_STRIP_H)
	strip.add_theme_stylebox_override("panel", UiKit.panel_box(UiKit.WHITE, 0, 0.0))
	_chars.add_child(strip)
	# 좌석 탭 — 2인 세팅일 때만 스트립 왼쪽에 선다 (문서 16p의 1P / 2P 탭).
	_char_seat_tabs.clear()
	for i in 2:
		var slot := i
		var tab := Button.new()
		tab.text = "%dP" % (i + 1)
		tab.size = Vector2(84.0, 56.0)
		tab.position = Vector2(CHAR_MARGIN, CHAR_STRIP_H / 2.0 - 62.0 + i * 68.0)
		tab.pressed.connect(func() -> void:
			Sfx.play("click")
			_pick_slot = slot
			_refresh_char_page())
		strip.add_child(tab)
		_char_seat_tabs.append(tab)
	_char_scroll = ScrollContainer.new()
	_char_scroll.position = Vector2(CHAR_MARGIN,
			(CHAR_STRIP_H - TILE_SIZE.y) / 2.0 - 6.0)
	_char_scroll.size = Vector2(vw - CHAR_MARGIN * 2.0, TILE_SIZE.y + 16.0)
	_char_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip.add_child(_char_scroll)
	var scroll := _char_scroll
	_char_strip = HBoxContainer.new()
	_char_strip.add_theme_constant_override("separation", int(TILE_GAP))
	_char_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	_char_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_char_strip)
	_build_char_tiles()
	# 본문 3단 — 카드는 각자 _draw()로 그리고, 버튼만 자식으로 얹는다.
	var top := CHAR_HEAD_H + CHAR_STRIP_H + 20.0
	var body_h := vh - top - CHAR_MARGIN
	_char_left = Control.new()
	_char_left.position = Vector2(CHAR_MARGIN, top)
	_char_left.size = Vector2(CHAR_LEFT_W, body_h)
	_char_left.draw.connect(func() -> void: _draw_char_stats(_char_left))
	_chars.add_child(_char_left)
	# ★ = 타이틀 화면에 앉는 대표 캐릭터 (문서 20~21p의 별, 23p 확인 팝업).
	_char_star = Button.new()
	_char_star.size = Vector2(56.0, 56.0)
	_char_star.position = Vector2(CHAR_LEFT_W - 76.0, 18.0)
	_char_star.pressed.connect(func() -> void:
		Sfx.play("click")
		_open_feature_ask())
	_char_left.add_child(_char_star)
	_char_center = Control.new()
	_char_center.position = Vector2(CHAR_MARGIN + CHAR_LEFT_W + CHAR_COL_GAP, top)
	_char_center.size = Vector2(400.0, body_h)
	_char_center.draw.connect(func() -> void: _draw_char_center(_char_center))
	_chars.add_child(_char_center)
	# 커스터마이징은 이 카드 안에서 바로 한다 (문서 21p) — 커스텀 슬롯 전용.
	_customizer = CAT_CUSTOMIZER.new()
	_char_center.add_child(_customizer)
	_customizer.saved.connect(func() -> void:
		_show_toast(tr("CC_SAVED"), GOLD_COL))
	_char_right = Control.new()
	_char_right.position = Vector2(vw - CHAR_MARGIN - CHAR_RIGHT_W, top)
	_char_right.size = Vector2(CHAR_RIGHT_W, body_h)
	_char_right.draw.connect(func() -> void: _draw_char_rewards(_char_right))
	_chars.add_child(_char_right)
	_layout_char_body()
	_build_feature_ask()


## 스트립 타일 다시 깔기 — 커스텀 슬롯을 새로 열면 그 자리가 늘어난다.
func _build_char_tiles() -> void:
	for child in _char_strip.get_children():
		_char_strip.remove_child(child)
		child.queue_free()
	_tiles.clear()
	for cat: Dictionary in GameState.all_cats():
		var tile := _make_tile(cat)
		_char_strip.add_child(tile)
		_tiles[cat.id] = tile
	if GameState.can_add_custom_slot():
		_char_strip.add_child(_make_add_tile())


## "+" 타일 — 나만의 캐릭터를 담을 빈 슬롯을 하나 더 연다 (문서 20p).
func _make_add_tile() -> Button:
	var b := Button.new()
	b.custom_minimum_size = TILE_SIZE
	b.size = TILE_SIZE
	b.text = "+"
	UiKit.style_button(b, Color("eef2f6"), Color("c9c6d0"), Color(INK, 0.55), 54, 16)
	b.pressed.connect(func() -> void:
		var id := GameState.add_custom_slot()
		if id == "":
			Sfx.play("error")
			_show_toast(tr("CHAR_SLOT_FULL"), UiKit.MUTED)
			return
		Sfx.play("buy")
		_show_toast(tr("CHAR_SLOT_NEW").format(
				{"n": GameState.custom_slots}), UiKit.PURPLE_DEEP)
		_char_view = id
		_build_char_tiles()
		_refresh_char_page())
	return b


## 캐릭터는 타이틀에서 미리 정해 둔다 — 인원 세팅에 맞춰 좌석 탭이 뜨고,
## 고르는 즉시 GameState에 저장된다. 플레이 입장 때는 다시 묻지 않는다.
func _open_chars() -> void:
	_pick = true
	_pick_count = _seats()
	_pick_slot = 0
	_pick_cats[0] = _first_unlocked(GameState.selected_cat)
	_pick_cats[1] = _first_unlocked(GameState.selected_cat2)
	_commit_pick()
	_char_view = _pick_cats[0]
	_refresh_chars_head()
	_raise(_chars)
	_refresh_char_page()
	_chars.visible = true


## 페이지 제목에 지금 세팅한 인원을 붙인다.
func _refresh_chars_head() -> void:
	var head: Label = _chars.get_meta("head")
	head.text = tr("CHAR_SELECT")
	if allow_2p:
		head.text += "  ·  " + tr("MENU_PLAYERS_1" if _pick_count < 2 \
				else "MENU_PLAYERS_2")


## 자리별 선택을 저장한다 (고를 때마다 즉시 — 따로 확정 단계가 없다).
func _commit_pick() -> void:
	GameState.select_cat(_pick_cats[0], 1)
	if _pick_count > 1:
		GameState.select_cat(_pick_cats[1], 2)
	_refresh_currency()  # HUD 아바타가 1P 냥이를 따라간다


func _close_chars() -> void:
	_chars.visible = false
	_pick = false
	queue_redraw()  # 타이틀 고양이를 새 선택으로 다시 그린다


## 저장된 선택이 아직 잠겨 있으면 해금된 첫 냥이로 대체한다.
func _first_unlocked(id: String) -> String:
	if GameState.is_unlocked(id):
		return id
	for cat in GameState.all_cats():
		if GameState.is_unlocked(cat.id):
			return str(cat.id)
	return "cream"


## 커스텀 슬롯은 보상 열이 없다 — 그만큼 가운데 카드가 넓어진다 (문서 21p).
func _layout_char_body() -> void:
	var custom := GameState.is_custom_cat(_char_view)
	_char_right.visible = not custom
	var right := 0.0 if custom else CHAR_RIGHT_W + CHAR_COL_GAP
	var cx := CHAR_MARGIN + CHAR_LEFT_W + CHAR_COL_GAP
	_char_center.size = Vector2(vw - CHAR_MARGIN - right - cx, _char_left.size.y)
	_customizer.visible = custom
	if custom:
		# 카드 제목(커스터마이징) 아래부터 카드 안쪽 여백까지.
		_customizer.set_area(Rect2(24.0, CHAR_CUSTOM_TOP,
				_char_center.size.x - 48.0,
				_char_center.size.y - CHAR_CUSTOM_TOP - 22.0))


func _refresh_char_page() -> void:
	if _chars == null:
		return
	for i in _char_seat_tabs.size():
		var tab: Button = _char_seat_tabs[i]
		tab.visible = _pick_count > 1
		UiKit.btn_chip(tab, i == _pick_slot, 22)
	var seat_w := 112.0 if _pick_count > 1 else 0.0
	_char_scroll.position.x = CHAR_MARGIN + seat_w
	_char_scroll.size.x = vw - CHAR_MARGIN * 2.0 - seat_w
	_char_star.visible = GameState.is_unlocked(_char_view)
	var featured := GameState.featured_cat() == _char_view
	_char_star.text = "★" if featured else "☆"
	if featured:
		UiKit.style_button(_char_star, UiKit.GOLD, UiKit.GOLD_DEEP, INK, 30, 16)
	else:
		UiKit.btn_ghost(_char_star, 30)
	_customizer_on = GameState.is_custom_cat(_char_view)
	_layout_char_body()
	if _customizer_on:
		_customizer.open(_char_view, _pick_slot + 1)
	_refresh_tiles()
	_char_left.queue_redraw()
	_char_center.queue_redraw()
	_char_right.queue_redraw()


## 타일에서 고른 냥이를 지금 자리에 앉히고, 2인이면 다음 자리로 넘긴다.
func _assign_pick(cat_id: String) -> void:
	Sfx.play("buy")
	_pick_cats[_pick_slot] = cat_id
	_commit_pick()
	if _pick_count > 1:
		_pick_slot = (_pick_slot + 1) % _pick_count
	_refresh_char_page()


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


## 지금 펼쳐 놓은 냥이는 빨간 테두리, 자리에 앉힌 냥이는 금색 (문서 20p).
func _style_tile(b: Button, cat: Dictionary) -> void:
	var id := str(cat.id)
	if _chars != null and _chars.visible and id == _char_view:
		UiKit.style_button(b, Color("fff1cf"), UiKit.RED_DEEP, INK, 20, 16)
	elif _is_chosen(id):
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
	# 타일/카드 폭을 넘기면 글자를 줄여서 맞춘다 (긴 번역 대응).
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


## 타일 누르기 = 본문에 그 냥이를 펼치고, 해금된 냥이면 지금 자리에 앉힌다.
func _on_tile_pressed(cat: Dictionary) -> void:
	_char_view = str(cat.id)
	if GameState.is_unlocked(cat.id):
		_assign_pick(str(cat.id))
	else:
		Sfx.play("click")
		_refresh_char_page()


## 이 냥이가 지금 "고른" 상태인가 — 픽 중에는 참가자 자리, 아니면 저장된 선택.
func _is_chosen(id: String) -> bool:
	if not _pick:
		return GameState.selected_cat == id
	for i in _pick_count:
		if _pick_cats[i] == id:
			return true
	return false


# --- 본문 1단: 능력치 카드 --------------------------------------------------------
## 능력치는 캐릭터 데이터(GameState.cat_stats)를 그대로 보여 주는 표시 전용이다.


func _draw_char_stats(ci: Control) -> void:
	var id := _char_view
	var cat := GameState.get_cat(id)
	var unlocked := GameState.is_unlocked(id)
	var w := ci.size.x
	ci.draw_style_box(UiKit.panel_box(UiKit.WHITE, 22, 0.0),
			Rect2(Vector2.ZERO, ci.size))
	var font := ThemeDB.fallback_font
	ci.draw_string(font, Vector2(24.0, 48.0), tr("CHAR_STATS"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, INK)
	var center := Vector2(w / 2.0, 206.0)
	UiKit.ellipse(ci, center + Vector2(0.0, 96.0), Vector2(78.0, 19.0),
			Color(0.2, 0.35, 0.45, 0.14))
	if unlocked:
		# 꾸미기 중인 슬롯은 패널이 들고 있는 모습 그대로 (잠긴 파츠 미리보기 포함).
		var skin: Dictionary = _customizer.preview_skin() if _customizer_on \
				else GameState.cat_skin(id, _pick_slot + 1)
		Player.paint_cat(ci, center, 176.0, 0.0, true, false, skin)
	else:
		Player.paint_cat(ci, center, 176.0, 0.0, true, false,
				GameState.cat_shadow_skin(id))
		_draw_lock(ci, center + Vector2(74.0, 60.0))
	_draw_center_text(ci, font, tr(str(cat.name)), 342.0, 32,
			INK if unlocked else UiKit.MUTED, w)
	_draw_center_text(ci, font, "「%s」" % tr(str(cat.get("trait", ""))), 378.0, 20,
			GOLD_COL, w)
	var stats: Dictionary = GameState.cat_stats(id)
	var pip_w := (w - 176.0) / 5.0 - 6.0
	for i in STAT_ROWS.size():
		var y := 418.0 + i * 42.0
		ci.draw_string(font, Vector2(26.0, y + 16.0), tr(STAT_ROWS[i][0]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(INK, 0.85))
		var pips := _stat_pips(STAT_ROWS[i][1], stats.get(STAT_ROWS[i][1], 1.0))
		for p in 5:
			var r := Rect2(146.0 + p * (pip_w + 6.0), y, pip_w, 18.0)
			ci.draw_rect(r, UiKit.ORANGE if p < pips else Color(INK, 0.12))
	var note := ""
	if GameState.featured_cat() == id:
		note = tr("CHAR_FEATURE_ON")
	elif _is_chosen(id):
		note = tr("CHAR_EQUIPPED")
	if note != "":
		_draw_center_text(ci, font, note, ci.size.y - 28.0, 20, GOLD_COL, w)


# --- 본문 2단: 키캡 도감 / 커스터마이징 ---------------------------------------------


func _draw_char_center(ci: Control) -> void:
	var w := ci.size.x
	ci.draw_style_box(UiKit.panel_box(UiKit.WHITE, 22, 0.0),
			Rect2(Vector2.ZERO, ci.size))
	var font := ThemeDB.fallback_font
	if GameState.is_custom_cat(_char_view):
		# 제목 줄만 그리고, 아래는 꾸미기 패널(부위 목록 + 옵션 격자)이 채운다.
		ci.draw_string(font, Vector2(24.0, 48.0), tr("CHAR_CUSTOM_TITLE"),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 26, INK)
		var prog := GameState.my_parts_progress()
		var note := "🎨 %d / %d" % [prog.x, prog.y]
		var nw := font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		ci.draw_string(font, Vector2(w - nw - 24.0, 48.0), note,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 22, GOLD_COL)
		ci.draw_line(Vector2(24.0, 60.0), Vector2(w - 24.0, 60.0), Color(INK, 0.12),
				2.0)
		return
	ci.draw_string(font, Vector2(24.0, 48.0), tr("KEYCAP_TITLE"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, INK)
	var plate_w := w - 56.0
	var key := (plate_w - KEY_GAP * 9.0) / 10.0
	var plate := Rect2(28.0, 72.0, plate_w, key * 3.0 + KEY_GAP * 2.0 + 44.0)
	_draw_keycap_plate(ci, plate, _char_view)
	var below := plate.position.y + plate.size.y + 46.0
	_draw_center_text(ci, font, tr("KEYCAP_HINT"), below, 20, UiKit.MUTED, w)
	_draw_center_text(ci, font, tr("CHAR_DEX_COLLECTED").format(
			{"ring": GameState.keycap_ring(_char_view)}), below + 48.0, 30, INK, w)
	_draw_keycap_progress(ci, _char_view, below + 92.0, w)


# --- 본문 3단: 보상 열 ------------------------------------------------------------
## 등급 하나 = 키캡 A~Z 한 바퀴. 1등급은 캐릭터 해금, 2~4등급은 파츠 단계다.
## 칩에는 그 등급에서 받게 되는 모습(그 단계 파츠를 입은 냥이)을 그린다.


func _draw_char_rewards(ci: Control) -> void:
	var w := ci.size.x
	ci.draw_style_box(UiKit.panel_box(UiKit.WHITE, 22, 0.0),
			Rect2(Vector2.ZERO, ci.size))
	var font := ThemeDB.fallback_font
	_draw_center_text(ci, font, tr("CHAR_REWARD"), 48.0, 26, INK, w)
	var grade := GameState.cat_grade(_char_view)
	var top: int = GameState.KEYCAP_GRADE_MAX
	var step := (ci.size.y - 96.0) / top
	var chip_h := minf(80.0, step - 66.0)
	for i in top:
		var lvl := i + 1
		var done := grade >= lvl
		var next := grade == lvl - 1
		var rect := Rect2(30.0, 84.0 + i * step, w - 60.0, chip_h)
		var box := UiKit.panel_box(UiKit.CYAN if done else Color("e6eaef"), 18, 0.0)
		if next:
			box.border_color = UiKit.GOLD_DEEP
			box.set_border_width_all(5)
		ci.draw_style_box(box, rect)
		# 칩마다 그 등급에서 붙는 파츠 단계로 그린다 (잠긴 칩도 같은 단계의 실루엣).
		var tier := mini(i, GameState.CustomCat.TIER_MAX)
		var skin: Dictionary = GameState.cat_skin(_char_view, 1, tier) if done \
				else GameState.cat_shadow_skin(_char_view, tier)
		Player.paint_cat(ci, rect.get_center(), chip_h * 0.76, 0.0, true, false, skin)
		var label := tr("CHAR_REWARD_UNLOCK") if lvl == 1 \
				else tr("CHAR_REWARD_PARTS").format({"n": lvl - 1})
		_draw_center_text(ci, font, label, rect.position.y + chip_h + 24.0, 18,
				INK if done else UiKit.MUTED, w)
		var status := tr("CHAR_REWARD_DONE") if done \
				else (tr("CHAR_REWARD_NEXT") if next else tr("CHAR_REWARD_LOCKED"))
		_draw_center_text(ci, font, status, rect.position.y + chip_h + 46.0, 16,
				GOLD_COL if next else (Color(INK, 0.55) if done else UiKit.SOFT), w)


# --- 대표 캐릭터 확인 팝업 (문서 23p) ------------------------------------------------


func _build_feature_ask() -> void:
	_feature_ask = _make_overlay(tr("CHAR_FEATURE_TITLE"),
			func() -> void: _feature_ask.visible = false, Vector2(600.0, 520.0))
	var body: Control = _feature_ask.get_meta("body")
	var ask := Label.new()
	ask.text = tr("CHAR_FEATURE_ASK")
	ask.size = Vector2(body.size.x, 64.0)
	ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ask.add_theme_font_size_override("font_size", 21)
	ask.add_theme_color_override("font_color", Color(INK, 0.85))
	body.add_child(ask)
	_feature_face = Control.new()
	_feature_face.position = Vector2(0.0, 80.0)
	_feature_face.size = Vector2(body.size.x, 230.0)
	_feature_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feature_face.draw.connect(func() -> void:
		Player.paint_cat(_feature_face, Vector2(_feature_face.size.x / 2.0, 104.0),
				172.0, 0.0, true, false,
				GameState.cat_skin(_char_view, _pick_slot + 1))
		_draw_center_text(_feature_face, ThemeDB.fallback_font,
				tr(str(GameState.get_cat(_char_view).name)), 216.0, 26, INK,
				_feature_face.size.x))
	body.add_child(_feature_face)
	var cancel := Button.new()
	cancel.text = tr("UI_CANCEL")
	cancel.size = Vector2(190.0, 60.0)
	cancel.position = Vector2(body.size.x / 2.0 - 200.0, body.size.y - 76.0)
	UiKit.btn_ghost(cancel, 24)
	cancel.pressed.connect(func() -> void:
		Sfx.play("click")
		_feature_ask.visible = false)
	body.add_child(cancel)
	var ok := Button.new()
	ok.text = tr("UI_CONFIRM")
	ok.size = Vector2(190.0, 60.0)
	ok.position = Vector2(body.size.x / 2.0 + 10.0, body.size.y - 76.0)
	UiKit.btn_primary(ok, 26)
	ok.pressed.connect(func() -> void:
		Sfx.play("record")
		GameState.set_feature_cat(_char_view)
		_show_toast(tr("CHAR_FEATURE_SET").format(
				{"name": tr(str(GameState.get_cat(_char_view).name))}), GOLD_COL)
		_feature_ask.visible = false
		_refresh_char_page()
		queue_redraw())
	body.add_child(ok)


func _open_feature_ask() -> void:
	_raise(_feature_ask)
	_feature_face.queue_redraw()
	_feature_ask.visible = true


## 이 냥이의 키캡 수집 현황 — 이번 바퀴 진행 바 + 등급.
## 잠긴 냥이에게는 이 바가 그대로 해금 게이지다 (A~Z 한 바퀴 = 합류).
func _draw_keycap_progress(ci: Control, id: String, y: float, width: float) -> void:
	var font := ThemeDB.fallback_font
	var ring := GameState.keycap_ring(id)
	var grade := GameState.cat_grade(id)
	var top := GameState.KEYCAP_GRADE_MAX
	var full := grade >= top
	_draw_center_text(ci, font, tr("CHAR_KEYCAP").format(
			{"ring": ring, "grade": grade, "max": top}), y, 20, GOLD_COL, width)
	var bar := Rect2((width - 340.0) / 2.0, y + 14.0, 340.0, 16.0)
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
	_draw_center_text(ci, font, note, y + 54.0, 17, UiKit.MUTED, width)


func _refresh_tiles() -> void:
	for id: String in _tiles:
		_style_tile(_tiles[id], GameState.get_cat(id))
		(_tiles[id].get_child(0) as Control).queue_redraw()
	queue_redraw()


# --- Currency + toast ---------------------------------------------------------


## 상단 고정 유저 HUD — 이름·레벨·경험치·골드는 늘 이 카드 하나에만 산다.
## (같은 스크립트를 인게임 main.gd도 쓴다 — 화면이 바뀌어도 자리가 같다)
func _build_user_hud() -> void:
	_user_hud = USER_HUD.new()
	add_child(_user_hud)


## 지갑/레벨 표시 갱신 — 이름이 바뀌었을 때도 같이 부른다.
func _refresh_currency() -> void:
	if _user_hud:
		_user_hud.refresh()


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
	# 대표 캐릭터가 로고 옆(세로 화면은 아래)에 앉아 손님을 맞는다.
	var at := _cat_anchor
	# 발밑 그림자 — 밝은 배경에서 캐릭터를 띄워 준다.
	UiKit.ellipse(self, _cat_anchor + Vector2(0.0, _cat_size * 0.56),
			Vector2(_cat_size * 0.42, _cat_size * 0.1), Color(0.2, 0.35, 0.45, 0.16))
	Player.paint_cat(self, at, _cat_size, 0.0, true, false,
			GameState.cat_skin(GameState.featured_cat()))
	_draw_stat_line()


## 블록 글자 로고 "CAT-TRIS" — 컨셉의 통통한 블록 타이포.
func _draw_logo() -> void:
	var text := "CAT-TRIS"
	var w := UiKit.block_text_width(text, _logo_cell)
	UiKit.block_text(self, Vector2((vw - w) / 2.0, _logo_top), text, _logo_cell)
	UiKit.center_text_outlined(self, tr("MENU_TAGLINE"),
			_logo_top + _logo_cell * 6.6, vw, int(maxf(28.0, _logo_cell * 0.6)),
			UiKit.WHITE, 0.0, 7)


## 대표 캐릭터의 한 줄 능력치 — 타이틀 고양이 바로 아래.
func _draw_stat_line() -> void:
	var cat := GameState.get_cat(GameState.featured_cat())
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
