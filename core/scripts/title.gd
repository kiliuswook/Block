extends Node2D
## 타이틀 화면 (피그마 UI 2026-09) — 스플래시(로고 + Press to play) → 메뉴
## (무대 냥이 · 플레이 · CTA 4장) → 모드 선택 · 캐릭터 · 상점 · 랭킹 · 설정.
## 그림 에셋은 UiKit.tex()로 읽고, 나머지는 _draw()로 직접 그린다.

const UiKit := preload("res://core/scripts/ui_kit.gd")

const CREAM := UiKit.CREAM
const GOLD_COL := UiKit.GOLD_DEEP  # 흰 패널 위에서도 읽히는 진한 금색
const INK := UiKit.INK
const TEXT := UiKit.TEXT

const SETTINGS_PANEL := preload("res://core/scripts/settings_panel.gd")
const USER_HUD := preload("res://core/scripts/user_hud.gd")
const CAT_CUSTOMIZER := preload("res://core/scripts/cat_customizer.gd")
const CatSprite := preload("res://core/scripts/cat_sprite.gd")
const MODE_DEMO := preload("res://core/scripts/mode_demo.gd")
## [개발용 · 출시 빌드에서 제거] 업적·리더보드를 눈으로 확인하는 임시 패널.
const DEV_PANEL := preload("res://core/scripts/dev_panel.gd")
const TILE_SIZE := Vector2(195.0, 190.0)  # 캐릭터 격자 타일 (피그마 cat list 195×190)
const TILE_GAP := 20.0
const KEY_ROWS: Array[String] = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
const KEY_GAP := 10.0
## 페이지 공통 — 좌우 여백 · 헤더(유저 HUD 줄) 높이 · 뒤로가기 버튼 크기.
const PAGE_MARGIN := 52.0
const PAGE_HEAD_H := 188.0  # 본문이 시작하는 y (헤더 40~158 + 간격 30)
const PAGE_HUD_DROP := 118.0  # 세로 화면은 헤더를 HUD 아래로 (예전 규칙 유지)
const BACK_BTN := Vector2(241.0, 71.0)  # 피그마 btn_normal 241×78 (얼굴 71 + 두께 7)
## 캐릭터 페이지: 탭 두 장 + 흰 본문 카드, 본문은 왼쪽(상세)·오른쪽(격자/꾸미기).
const CHAR_TAB_H := 60.0
const CHAR_TAB_GAP := 8.0
const CHAR_BODY_W := 1822.0  # 피그마 본문 폭 (왼쪽 상세 910 + 오른쪽 격자 912)
const CHAR_LEFT_W := 910.0
const CHAR_RIGHT_PAD := 20.0  # 오른쪽 격자 칸 안쪽 여백
const CHAR_KEY := Vector2(52.0, 55.0)  # 키캡 얼굴 (+ 두께 7 = 62)
const CHAR_KEY_GAP := 20.0
const CHAR_PAD := 40.0  # 왼쪽 상세 칸 안쪽 여백 (피그마 p-40)
const CHAR_LEFT_RATIO := 0.497  # 가로: 왼쪽 상세가 차지하는 폭 비율 (디자인 904/1816)
const CHAR_LEFT_RATIO_V := 0.55
const CHAR_GRID_COLS := 4
const CHAR_SCROLL_W := 20.0
const CHAR_SLOT_GAP := 16.0
## 왼쪽 상세 — 위 프리뷰 줄, 키캡 도감 판, 아래 보상 줄.
const CHAR_PREVIEW := 150.0
const CHAR_DEX_TOP := 240.0
const CHAR_DEX_H := 314.0
const CHAR_REWARD_H := 185.0
const CHAR_STAGE_TOP := 28.0
const CHAR_CUSTOM_TOP := 30.0
const SEAT_BTN_H := 115.0
## 상점 (피그마 `상점`) — 열(카드) 셋. 열 하나를 피그마 크기(603×830) 그대로 짓고
## 화면에 맞춰 통째로 scale한다 — 세로 화면은 탭으로 한 장씩 크게 보여 준다.
const SHOP_COL := Vector2(603.0, 830.0)
const SHOP_COL_GAP := 20.0
const SHOP_TOP := 188.0  # 카드 윗변 (HUD 40~158 + 30)
const SHOP_PAD := 30.0
const SHOP_AREA_H := 559.0  # 기계 판(+선택 열은 걸어 둔 냥이 줄)이 차지하는 높이
const SHOP_STEP_Y := 619.0  # 개수 스테퍼 윗변
const SHOP_DRAW_Y := 709.0  # 뽑기 버튼 윗변 (얼굴 84 + 두께 7)
const SHOP_PICK_PANEL_H := 375.2  # 선택 열의 기계 판 높이 (아래는 냥이 줄)
const SHOP_TAB_H := 84.0  # 세로 화면의 열 탭
## 기계 판 안 기계 그림 자리 · 기계 속 캡슐 묶음 자리 (판 좌표, 피그마 값).
const GACHA_MACHINE_RECT := [Rect2(136.5, 64.0, 270.0, 431.0), Rect2(136.0, 31.0, 270.0, 442.0),
		Rect2(136.5, 62.0, 270.0, 435.0)]
const GACHA_CAPS_RECT := [Rect2(162.0, 141.0, 212.31, 202.1), Rect2(154.0, 123.0, 235.07, 194.51),
		Rect2(166.5, 157.68, 215.77, 179.61)]
## 뽑기 결과 연출 타이밍 (초) — 닫힌 캡슐이 하나씩 떨어져 트레이에 앉고(STEP 간격, FALL),
## 다 앉으면 HOLD 뒤에 OPEN_STEP 간격으로 차례로 열린다(OPEN).
const CAPSULE_STEP := 0.07
const CAPSULE_FALL := 0.34
const CAPSULE_HOLD := 0.3
const CAPSULE_OPEN_STEP := 0.12
const CAPSULE_OPEN := 0.3
## 선택뽑기 캐릭터 팝업 (피그마 93:5148) — 팝업 크기 · 격자 카드 높이 · 고른 냥이 카드 높이.
const PICK_POP := Vector2(1000.0, 850.0)
const PICK_CHIP_H := 188.0
const PICK_ROW_H := 170.0
## 결과 트레이 (피그마 `팝업_뽑기결과` keyboard-chassis-top, 1120×689) 안의 캡슐 배치.
const RESULT_TRAY := Vector2(1120.0, 689.0)
const RESULT_CAP := Vector2(200.0, 203.0)  # 닫힌 캡슐 한 알
const RESULT_PITCH := Vector2(210.0, 284.75)  # 한 줄 5알 (간격 10) · 줄 간격
const RESULT_LID_UP := 65.0  # 열리면 뚜껑이 올라가는 거리
const RESULT_BOWL_DOWN := 15.0  # 열리면 아래통·냥이가 내려가는 거리
## 캡슐 색 10가지 (피그마 순서) — [아래통 그림, 통 안쪽 테 색].
const RESULT_CAP_COLORS := [["red", "fb1e2c"], ["orange", "fd831c"], ["blue", "1cb5fc"],
		["navy", "4c5aca"], ["purple", "a445f4"], ["green", "51db69"], ["yellow", "fdd020"],
		["mint", "a9fad2"], ["pink", "fd699e"], ["cream", "fcefc9"]]

@onready var endless_btn: Button = $UI/EndlessBtn
@onready var classic_btn: Button = $UI/ClassicBtn
@onready var endless_desc: Label = $UI/EndlessDesc
@onready var classic_desc: Label = $UI/ClassicDesc

# 레이아웃은 뷰포트 크기 기준으로 계산 — 모바일(세로 1080×1920)도 같은 코드를 쓴다.
var vw := 1920.0
var vh := 1080.0
var max_tiles_per_row := 99  # 모바일 타이틀이 줄바꿈을 위해 줄인다
var main_scene := "res://core/scenes/main.tscn"  # 플랫폼 타이틀이 교체 가능

var _splash := true  # 로고 + Press to play (아무 키로 메뉴로)
var _menu_nodes: Array[Control] = []  # 스플래시 동안 숨기는 메뉴 노드들
var _tiles := {}  # cat id -> Button
var _user_hud: CanvasLayer  # 상단 고정 유저 HUD (Lv 카드 + 재화 알약)
var _toast: Label
var _toast_tween: Tween
var _customizer: Control
var _settings: Control
var _gacha: Control  # 상점 페이지
var _gacha_cols: Array[Dictionary] = []
var _gacha_machines: Array[Control] = []
var _gacha_n: Array[int] = [1, 1, 1]  # 열마다 뽑을 개수 [랜덤, 선택, 캔]
var _gacha_tab := 0  # 세로 화면에서 펼친 열
var _gacha_tabs: Array[Button] = []
var _gacha_tray: Control
var _gacha_pick_ui: Control
var _gacha_result: Control
var _gacha_chips := {}
var _gacha_count: Label
var _gacha_can_ui: Control
var _gacha_can_chips := {}
var _last_pull: Array = []
var _pull_t := 0.0
var _pull_anim := false
var _spin_t := 0.0
var _unlock_pop: Control
var _unlock_queue: Array[Dictionary] = []
var _unlock_at := 0
var _unlock_face: Control
var _unlock_btn: Button
var _unlock_go: Button  # 캐릭터 선택으로
var _modes: Control  # PLAY로 여는 모드 선택 페이지
var _mode_cards: Array[Control] = []
var _overlays: Array[Control] = []  # _make_overlay()가 만든 팝업 — 떠 있으면 유저 HUD를 감춘다
var _mode_demos: Array = []  # 카드마다 스스로 플레이하는 미리보기 (mode_demo.gd)
var _mode_sel := 0  # 커서가 올라간(선택 상태) 모드 카드
var _chars: Control  # 캐릭터 페이지
var _seat_btn: Button  # 메뉴의 "캐릭터 변경하기" (= 좌석 몫으로 캐릭터 페이지)
var _play_btn: Button
var _stage_cat: Control  # 무대 냥이 (플레이 버튼 위에 앞발이 걸친다)
var _pick_seat := false
var _char_tab := 0  # 0 일반 냥이 / 1 나만의 냥이
var _char_tabs: Array[Button] = []
var _char_view := "cream"
var _char_body: Control  # 흰 본문 카드
var _char_left: Control  # 상세 (탭 0) / 나만의 냥이 프리뷰 (탭 1)
var _char_grid_card: Control  # 오른쪽 격자 (탭 0)
var _char_scroll: ScrollContainer
var _char_grid: GridContainer
var _char_slots: HBoxContainer  # 탭 1 아래 커스텀 슬롯 줄
var _char_star: Button  # 대표 캐릭터 설정/해제
var _char_pick_btn: Button  # 탭 1 "캐릭터 선택"
var _customizer_on := false
var _feature_ask: Control
var _feature_face: Control
var _nick_pop: Control
var _nick_edit: LineEdit
var _nick_hint: Label
var _nick_save: Button
var _stage := Rect2()  # 메뉴 무대 — 이번 판에 나갈 냥이가 서는 자리
var _cat_anchor := Vector2(690.0, 500.0)
var _cat_size := 260.0
var _keycap_dex: Control
var _keycap_board: Control
var _keycap_stats: Label
var _keycap_tabs := {}
var _keycap_cat := "cream"
var _ranks: Control
var _rank_tabs := {}
var _rank_scopes := {}
var _rank_mode := "classic"
var _rank_weekly := true
var _rank_list: VBoxContainer
var _rank_status: Label
var _rank_sub: Label
var _rank_frame: Control
var _rank_bubble: Control
var _dev: Control
var _replay_viewer: Control


func _ready() -> void:
	preload("res://core/scripts/boot.gd").dev_platform = ""
	vw = get_viewport_rect().size.x
	vh = get_viewport_rect().size.y
	UiKit.apply_theme($UI)
	Achv.check()
	Account.sync()
	$UI/TitleLabel.visible = false
	$UI/SubtitleLabel.visible = false
	classic_btn.pressed.connect(func() -> void: _on_mode_picked(GameState.MODE_CLASSIC))
	endless_btn.pressed.connect(func() -> void: _on_mode_picked(GameState.MODE_ENDLESS))
	_refresh_classic_desc()
	_compute_layout()
	_fix_seat_cats()
	_build_user_hud()
	_build_character_page()
	_build_toast()
	_build_settings()
	_build_mode_select()
	_build_menu()
	_build_seat_stage()
	_build_gacha()
	_build_ranks()
	_build_nick_pop()
	_build_keycap_dex()
	_build_dev_panel()
	UiKit.apply_theme($UI)
	_replay_viewer.theme = null
	# 페이지가 바뀌면 상단 HUD 모양도 바뀐다 (피그마: 메뉴=알약 끝까지 / 페이지=뒤로가기
	# 왼쪽에서 끝 / 설정=알약 없음 / 모드 선택=HUD 없음).
	for page: Control in [_modes, _chars, _gacha, _settings]:
		page.visibility_changed.connect(_sync_hud)
	_customizer.changed.connect(func() -> void:
		_refresh_tiles()
		_refresh_currency()
		if _chars and _chars.visible:
			_refresh_char_page())
	Ranks.board_loaded.connect(func(_ok: bool) -> void:
		if _ranks and _ranks.visible:
			_refresh_rank_list())
	Ranks.weekly_reward.connect(func(g: int, c: int) -> void:
		Sfx.play("record")
		if g > 0:
			_show_toast(tr("MENU_WEEKLY_PRIZE").format({"gold": g, "cans": c})
					if c > 0 else tr("MENU_WEEKLY_PRIZE_GOLD").format({"gold": g}),
					GOLD_COL)
		elif c > 0:
			_show_toast(tr("MENU_WEEKLY_PRIZE_CAN").format({"cans": c}),
					UiKit.CAN_DEEP)
		_refresh_currency())
	_set_splash(true)
	Sfx.play_bgm("title")


## 스테이지 모드 설명줄에 최고 기록을 얹는다.
func _refresh_classic_desc() -> void:
	if GameState.classic_best > 0:
		classic_desc.text = \
				tr("MODE_CLASSIC_DESC_BEST").format({"best": GameState.classic_best})


func _start(mode: int) -> void:
	Sfx.play("click")
	GameState.mode = mode
	get_tree().change_scene_to_file(main_scene)


func _build_settings() -> void:
	_settings = SETTINGS_PANEL.new()
	$UI.add_child(_settings)
	# 스플래시 상태에서 곧장 설정을 열어도(캡처·테스트) HUD가 같이 뜨게.
	_settings.visibility_changed.connect(func() -> void:
		if _settings.visible and _splash:
			_set_splash(false))


# --- 스플래시 ---------------------------------------------------------------------


## 로고 화면 ↔ 메뉴. 스플래시 동안은 메뉴·HUD를 감추고 로고만 그린다.
func _set_splash(on: bool) -> void:
	_splash = on
	for n: Control in _menu_nodes:
		if is_instance_valid(n):
			n.visible = not on
	_sync_hud()
	queue_redraw()


func _dismiss_splash() -> void:
	if not _splash:
		return
	Sfx.play("click")
	_set_splash(false)


# --- 메인 메뉴 (무대 냥이 + 플레이 + CTA 4장) --------------------------------------


## 화면 비율(가로/세로)에 따라 무대·메뉴 자리를 정한다.
func _compute_layout() -> void:
	if vh > vw:  # 모바일 세로
		_cat_anchor = Vector2(vw / 2.0, vh * 0.40)
		_cat_size = vw * 0.30
		_stage = Rect2(0.0, vh * 0.24, vw, vh * 0.28)
	else:
		# 피그마 "선택"(116:4800): 냥이 그림 304×346이 플레이 버튼 위 가운데
		# (x 537~841, y 324~670) — 앞발이 버튼 윗변에 살짝 걸친다.
		var k := vh / 1080.0
		_cat_anchor = Vector2(vw / 2.0 - 271.0 * k, 530.0 * k)
		_cat_size = 264.0 * k
		_stage = Rect2(vw / 2.0 - 423.0 * k, 324.0 * k, 304.0 * k, 346.0 * k)


## 플레이 버튼 자리.
func _play_rect() -> Rect2:
	if vh > vw:
		var w := minf(vw - 120.0, 750.0)
		return Rect2((vw - w) / 2.0, vh * 0.55, w, 140.0)
	# 피그마: 가운데 정렬된 줄(플레이 750 + 간격 100 + CTA 443) — 플레이 얼굴 750×157, y 654.
	var k := vh / 1080.0
	return Rect2(vw / 2.0 - 646.5 * k, 654.0 * k, 750.0 * k, 157.0 * k)


## CTA 열의 좌상단·폭.
func _cta_rect() -> Rect2:
	if vh > vw:
		var w := minf(vw - 120.0, 750.0)
		return Rect2((vw - w) / 2.0, vh * 0.55 + 160.0, w, vh * 0.4)
	# CTA 열: x = 줄 왼쪽 + 750 + 100, y 332. 버튼 얼굴 443×105(+두께 10), 간격 12.
	var k := vh / 1080.0
	return Rect2(vw / 2.0 + 203.5 * k, 332.0 * k, 443.0 * k, (115.0 * 4.0 + 12.0 * 3.0) * k)


## CTA 한 장의 얼굴 높이와 줄 간격(얼굴 + 두께 + 12).
func _cta_face_h() -> float:
	return (105.0 if vw >= vh else 88.0) * (vh / 1080.0 if vw >= vh else 1.0)


func _cta_pitch() -> float:
	return _cta_face_h() + UiKit.BEVEL + 12.0


## 플랫폼 타이틀이 메뉴 CTA를 더 붙일 자리 (`[라벨, 베벨색, 누르면 할 일]`).
## 예컨대 모바일은 여기에 `업적`을 넣는다 (core → steam/mobile 참조 금지 규칙의 통로).
func extra_menu_cards() -> Array:
	return []


func _build_menu() -> void:
	var pr := _play_rect()
	_play_btn = Button.new()
	_play_btn.text = tr("MENU_PLAY")
	_play_btn.position = pr.position
	_play_btn.size = pr.size
	# 피그마 80px ExtraBold — 기본 폰트는 글자 몸이 커서 72로 같은 높이가 된다.
	UiKit.btn_play(_play_btn, int(pr.size.y * 80.0 / 157.0))  # 피그마 80 / 157
	_play_btn.pressed.connect(func() -> void:
		Sfx.play("click")
		_open_modes())
	$UI.add_child(_play_btn)
	_menu_nodes.append(_play_btn)
	_stage_cat = Control.new()
	_stage_cat.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage_cat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_cat.draw.connect(_draw_seats)
	$UI.add_child(_stage_cat)
	_menu_nodes.append(_stage_cat)
	var area := _cta_rect()
	var h := _cta_face_h()
	# 첫 장은 좌석 몫의 "캐릭터 변경하기" — _build_seat_stage()가 만든다.
	var cards := [
		[tr("MENU_BTN_SHOP"), func() -> void: _open_gacha()],
		[tr("MENU_BTN_RANKS"), func() -> void: _open_ranks()],
		[tr("MENU_BTN_SETTINGS"), func() -> void: _settings.open()],
	]
	for extra: Array in extra_menu_cards():
		cards.append([extra[0], extra[2]])
	for i in cards.size():
		var entry: Array = cards[i]
		var b := Button.new()
		b.text = str(entry[0])
		b.position = area.position + Vector2(0.0, (i + 1) * _cta_pitch())
		b.size = Vector2(area.size.x, h)
		# 피그마 50px ExtraBold ≈ 기본 폰트 45 (글자 높이 42px).
		UiKit.btn_cta(b, int(h * 50.0 / 105.0))  # 피그마 50 / 얼굴 105
		var act: Callable = entry[1]
		b.pressed.connect(func() -> void:
			Sfx.play("click")
			act.call())
		$UI.add_child(b)
		_menu_nodes.append(b)


# --- 모드 선택 페이지 --------------------------------------------------------------


## 하늘 배경 위에 큰 카드 두 장 — 스테이지 모드 · 무한의 계단. 카드 위쪽은 모드
## 미리보기(우물 판), 아래는 그 모드 이름 버튼. 씬의 버튼 둘을 그 자리로 옮겨 쓴다.
func _build_mode_select() -> void:
	_modes = _make_page(func() -> void: _modes.visible = false)
	_modes.visible = false
	# 피그마 "모드 선택"(83:1508): 카드 620×940 두 장(간격 30)이 화면 가운데 — 안쪽 여백
	# 40, 위는 미리보기 판(모서리 30), 아래는 큰 모드 버튼(얼굴 105 + 두께 10).
	# 커서가 올라간 카드가 "선택"(흰 판 · 남색 미리보기 · 초록 버튼), 나머지는
	# "비선택"(연하늘 판 · 회색 미리보기 · 회색 버튼)이다. 모드 설명 줄은 디자인에 없다.
	var portrait := vh > vw
	var k := vh / 1080.0 if not portrait else 1.0
	var card := Vector2(620.0, 940.0) * k
	var gap := 30.0 * k
	if portrait:
		card = Vector2(minf(vw - 100.0, 680.0), (vh - PAGE_HEAD_H - _page_drop() - 90.0) / 2.0)
	var entries := [
		[classic_btn, classic_desc, "MODE_CLASSIC", GameState.MODE_CLASSIC],
		[endless_btn, endless_desc, "MODE_ENDLESS", GameState.MODE_ENDLESS],
	]
	_mode_cards.clear()
	for i in entries.size():
		var e: Array = entries[i]
		var at := Vector2((vw - card.x * 2.0 - gap) / 2.0 + i * (card.x + gap),
				8.0 * k + (vh - 8.0 * k - card.y) / 2.0)
		if portrait:
			at = Vector2((vw - card.x) / 2.0,
					PAGE_HEAD_H + _page_drop() + i * (card.y + 30.0))
		var c := Control.new()
		c.position = at
		c.size = card
		c.mouse_filter = Control.MOUSE_FILTER_PASS
		var idx := i
		var mode: int = e[3]
		c.draw.connect(func() -> void: _draw_mode_card(c, mode, idx == _mode_sel))
		c.mouse_entered.connect(func() -> void: _select_mode_card(idx))
		_modes.add_child(c)
		_mode_cards.append(c)
		# 미리보기 판 = 둥근 판을 그리는 마스크 + 그 안에서 도는 데모 플레이.
		var pv := _mode_preview_rect(card)
		var mask := Control.new()
		mask.position = pv.position
		mask.size = pv.size
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		mask.draw.connect(func() -> void:
			UiKit.round_rect(mask, Rect2(Vector2.ZERO, mask.size),
					UiKit.NAVY if idx == _mode_sel else Color("5a5a5a"), int(30.0 * card.x / 620.0)))
		c.add_child(mask)
		var demo: Control = MODE_DEMO.new()
		demo.mode = mode
		demo.skin = GameState.cat_skin(GameState.selected_cat)
		demo.size = pv.size
		mask.add_child(demo)
		_mode_demos.append(demo)
		var btn: Button = e[0]
		btn.text = tr(str(e[2]))
		_reparent(btn, c)
		var pad := 40.0 * k
		btn.size = Vector2(card.x - pad * 2.0, 105.0 * k)
		btn.position = Vector2(pad, card.y - pad - 10.0 * k - btn.size.y)
		btn.mouse_entered.connect(func() -> void: _select_mode_card(idx))
		btn.focus_entered.connect(func() -> void: _select_mode_card(idx))
		var desc: Label = e[1]
		_reparent(desc, c)
		desc.visible = false
	_select_mode_card(0)


## 모드 카드 하나를 "선택" 상태로 — 버튼 색도 같이 바꾼다.
func _select_mode_card(idx: int) -> void:
	_mode_sel = idx
	var btns := [classic_btn, endless_btn]
	for i in btns.size():
		var on := i == idx
		UiKit.btn_big(btns[i], UiKit.GREEN if on else Color("bfbfbf"),
				UiKit.GREEN_DEEP if on else Color("787878"),
				int(50.0 * (vh / 1080.0 if vw >= vh else 1.0)))
	for c: Control in _mode_cards:
		c.queue_redraw()
		for m in c.get_children():
			if m is Control and m.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED:
				(m as Control).queue_redraw()
	for i in _mode_demos.size():
		_mode_demos[i].on = i == idx


## 모드 카드 — 판만 그린다. 미리보기 판은 자식 마스크 + 데모(`mode_demo.gd`)가 맡는다.
func _draw_mode_card(ci: Control, _mode: int, on := true) -> void:
	UiKit.round_rect(ci, Rect2(Vector2.ZERO, ci.size),
			UiKit.WHITE if on else Color("c6eeff"), int(20.0 * ci.size.x / 620.0))


## 카드 안 미리보기 판 자리 — 안쪽 여백 40, 아래는 모드 버튼(105 + 두께 10)과 간격 30.
func _mode_preview_rect(card: Vector2) -> Rect2:
	var k := card.x / 620.0
	var pad := 40.0 * k
	return Rect2(pad, pad, card.x - pad * 2.0, card.y - pad * 2.0 - 30.0 * k - 115.0 * k)


## 페이지 껍데기 — 하늘 배경 + 우상단 뒤로가기 (유저 HUD는 제 층에 따로 뜬다).
func _make_page(on_back: Callable) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	$UI.add_child(root)
	var bg := Control.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.draw.connect(func() -> void: UiKit.paint_backdrop(bg, Vector2(vw, vh)))
	root.add_child(bg)
	var back := Button.new()
	back.text = tr("SET_BACK_FULL")
	back.size = BACK_BTN
	# 피그마 헤더 줄: x 51.5 + 1817 - 241, y 40 + (118 - 78) / 2 = 60.
	back.position = Vector2(vw - BACK_BTN.x - PAGE_MARGIN, 60.0 + _page_drop())
	UiKit.btn_normal(back, 30)
	back.pressed.connect(func() -> void:
		Sfx.play("click")
		on_back.call())
	root.add_child(back)
	root.set_meta("back", back)
	return root


## 오버레이를 항상 메뉴 위로 올린다 (형제 순서 = 그리는 순서).
func _raise(c: Control) -> void:
	if c != null and c.get_parent() != null:
		c.get_parent().move_child(c, -1)


func _open_modes() -> void:
	if _splash:
		_set_splash(false)
	_raise(_modes)
	_refresh_classic_desc()
	# 데모는 좌석 냥이로 — 캐릭터 페이지에서 바꿨을 수 있다. 열 때마다 새 판부터.
	for d in _mode_demos:
		d.skin = GameState.cat_skin(GameState.selected_cat)
		d.call("_reset")
	_modes.visible = true
	for c in _modes.get_children():
		if c is Control:
			(c as Control).queue_redraw()


## 모드를 고르면 곧장 시작한다 — 캐릭터는 타이틀에서 이미 정해 뒀다.
func _on_mode_picked(mode: int) -> void:
	if _modes:
		_modes.visible = false
	_start(mode)


# --- 타이틀 무대 = 참가 좌석 -------------------------------------------------------
## 메뉴 가운데에 이번 판에 나갈 냥이가 서고, CTA 첫 장 "캐릭터 변경하기"가
## 그 자리 몫으로 캐릭터 페이지를 연다.


func _seat_cat_size(plate: Rect2) -> float:
	return minf(_cat_size, minf(plate.size.x * 0.62, plate.size.y * 0.7))


func _build_seat_stage() -> void:
	_seat_btn = Button.new()
	_seat_btn.pressed.connect(func() -> void:
		Sfx.play("click")
		_open_chars(true))
	$UI.add_child(_seat_btn)
	_menu_nodes.append(_seat_btn)
	_refresh_seats()


## "캐릭터 변경하기" = CTA 열 첫 장.
func _refresh_seats() -> void:
	var area := _cta_rect()
	var h := _cta_face_h()
	_seat_btn.text = tr("MENU_BTN_CHARS")
	_seat_btn.size = Vector2(area.size.x, h)
	_seat_btn.position = area.position
	UiKit.btn_cta(_seat_btn, int(h * 50.0 / 105.0))
	if is_instance_valid(_stage_cat):
		_stage_cat.queue_redraw()
	queue_redraw()


## 저장된 자리 냥이가 잠겨 있으면 해금된 냥이로 바꿔 둔다.
func _fix_seat_cats() -> void:
	GameState.select_cat(_first_unlocked(GameState.selected_cat))


## 어두운 딤 + 흰 카드 + 제목을 갖춘 공용 팝업 껍데기.
## "body" 메타에 내용물을 붙일 빈 Control, "head"에 제목 Label, "card"에 카드.
## with_close = 우상단 ✕ (피그마: 선택 뽑기 캐릭터 팝업만 ✕가 있다).
func _make_overlay(title_text: String, on_close: Callable,
		size: Vector2 = Vector2.ZERO, with_close := false,
		dim: Color = UiKit.DIM) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	$UI.add_child(root)
	_overlays.append(root)
	var dim_btn := Button.new()
	dim_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim_sb := StyleBoxFlat.new()
	dim_sb.bg_color = dim
	for st in ["normal", "hover", "pressed", "focus"]:
		dim_btn.add_theme_stylebox_override(st, dim_sb)
	dim_btn.pressed.connect(on_close)
	root.add_child(dim_btn)
	var pw: float = size.x if size.x > 0.0 else minf(vw - 80.0, 900.0)
	var ph: float = size.y if size.y > 0.0 else minf(vh - 140.0, 760.0)
	var card := Panel.new()
	card.position = ((Vector2(vw, vh) - Vector2(pw, ph)) / 2.0).floor()
	card.size = Vector2(pw, ph)
	card.add_theme_stylebox_override("panel", UiKit.card_box(UiKit.WHITE, 20))
	root.add_child(card)
	var head := Label.new()  # 피그마 팝업 제목: 50 · #2e1d00
	head.text = title_text
	head.position = Vector2(0.0, 28.0)
	head.size = Vector2(pw, 64.0)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.label(head, 50, UiKit.BROWN, true)
	card.add_child(head)
	root.set_meta("head", head)
	if with_close:
		var close := Button.new()
		close.text = "✕"
		close.size = Vector2(60.0, 60.0)
		close.position = Vector2(pw - 60.0 - 40.0, 40.0)
		UiKit.btn_card(close, UiKit.GRAY_DEEP, 28)
		close.pressed.connect(on_close)
		card.add_child(close)
	var body := Control.new()
	body.position = Vector2(40.0, 110.0)
	body.size = Vector2(pw - 80.0, ph - 150.0)
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
	if _splash:
		var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
				or (event is InputEventMouseButton and event.pressed) \
				or (event is InputEventScreenTouch and event.pressed) \
				or (event is InputEventJoypadButton and event.pressed)
		if pressed:
			_dismiss_splash()
			get_viewport().set_input_as_handled()
		return
	var esc: bool = event is InputEventKey and event.pressed \
			and event.physical_keycode == KEY_ESCAPE
	if _dev and _dev.visible:
		if esc:
			_dev.close()
		return
	if _settings_open():
		if esc:
			_settings.close()
		return
	if _nick_pop and _nick_pop.visible:
		if esc:
			_nick_pop.visible = false
		return
	if _unlock_pop and _unlock_pop.visible:
		if esc:
			_next_unlock()
		return
	if _gacha_result and _gacha_result.visible:
		if esc:
			_close_gacha_result()
		return
	if _gacha_can_ui and _gacha_can_ui.visible:
		if esc:
			_close_gacha_can()
		return
	if _gacha_pick_ui and _gacha_pick_ui.visible:
		if esc:
			_close_gacha_pick()
		return
	if _gacha and _gacha.visible:
		if esc:
			_close_gacha()
		return
	if _keycap_dex and _keycap_dex.visible:
		if esc:
			_keycap_dex.visible = false
		return
	if _replay_viewer and _replay_viewer.visible:
		if esc:
			_replay_viewer.playing_back = false
			_replay_viewer.visible = false
		return
	if _ranks and _ranks.visible:
		if esc:
			_ranks.visible = false
		return
	if _feature_ask and _feature_ask.visible:
		if esc:
			_feature_ask.visible = false
		return
	if _chars and _chars.visible:
		if esc:
			_close_chars()
		return
	if _modes and _modes.visible and esc:
		_modes.visible = false
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1, KEY_KP_1:
				_on_mode_picked(GameState.MODE_CLASSIC)
			KEY_2, KEY_KP_2:
				_on_mode_picked(GameState.MODE_ENDLESS)


# --- 상점 (캡슐 뽑기) ---------------------------------------------------------


## 상점 페이지 (피그마 `상점`) — 흰 카드 셋이 나란히: 일반(골드) · 선택(골드) · 고급(캔).
## 카드 하나 = 기계 판(기계 그림 + 캡슐 묶음) · (선택) 걸어 둔 냥이 캡슐 줄 + 고르기 버튼 ·
## 개수 스테퍼 · 초록 뽑기 버튼(값 알약). 세로 화면은 탭으로 한 장씩 크게.
func _build_gacha() -> void:
	_gacha = _make_page(func() -> void: _close_gacha())
	var cols := 3
	var top := SHOP_TOP + _page_drop()
	if vh > vw:
		var tab_w := (vw - PAGE_MARGIN * 2.0 - 16.0 * (cols - 1)) / cols
		top = PAGE_HEAD_H + _page_drop()
		for i in cols:
			var tab := Button.new()
			tab.text = tr(["SHOP_GACHA_RANDOM", "SHOP_GACHA_PICK", "SHOP_GACHA_CAN"][i])
			tab.position = Vector2(PAGE_MARGIN + i * (tab_w + 16.0), top)
			tab.size = Vector2(tab_w, SHOP_TAB_H)
			tab.pressed.connect(func() -> void:
				Sfx.play("click")
				_set_gacha_tab(i))
			_gacha.add_child(tab)
			_gacha_tabs.append(tab)
		top += SHOP_TAB_H + 16.0
		var s := minf((vw - PAGE_MARGIN * 2.0) / SHOP_COL.x, (vh - top - 40.0) / SHOP_COL.y)
		for i in cols:
			_build_gacha_col(_gacha, i, Vector2((vw - SHOP_COL.x * s) / 2.0, top), s)
		_set_gacha_tab(_gacha_tab)
	else:
		var row_w := SHOP_COL.x * cols + SHOP_COL_GAP * (cols - 1)
		var s := minf(1.0, minf((vw - 72.0) / row_w, (vh - top - 40.0) / SHOP_COL.y))
		var x0 := (vw - row_w * s) / 2.0
		for i in cols:
			_build_gacha_col(_gacha, i,
					Vector2(x0 + i * (SHOP_COL.x + SHOP_COL_GAP) * s, top), s)
	_build_gacha_pick_ui(false)
	_build_gacha_pick_ui(true)
	_build_gacha_result()
	_build_unlock_pop()
	_refresh_gacha()


## 세로 화면 — 탭을 누르면 그 열 카드만 보인다.
func _set_gacha_tab(i: int) -> void:
	_gacha_tab = i
	for j in _gacha_tabs.size():
		UiKit.btn_tab(_gacha_tabs[j], j == i, UiKit.YELLOW, 28, 16, false)
	for c: Dictionary in _gacha_cols:
		(c.col as Control).visible = _gacha_tabs.is_empty() or int(c.mode) == i


## 열(카드) 하나 — 피그마 크기(SHOP_COL)로 짓고 `s`배로 줄이거나 키운다.
## mode(GACHA_*)가 그 열의 풀·값·재화를 정한다.
func _build_gacha_col(parent: Control, mode: int, at: Vector2, s: float) -> void:
	var idx := mode
	var col := Control.new()
	col.position = at
	col.size = SHOP_COL
	col.scale = Vector2(s, s)
	col.draw.connect(func() -> void:
		UiKit.round_rect(col, Rect2(Vector2.ZERO, col.size), UiKit.WHITE, 24))
	parent.add_child(col)
	var area := Rect2(SHOP_PAD, SHOP_PAD, SHOP_COL.x - SHOP_PAD * 2.0, SHOP_AREA_H)
	# 기계 판 — 판 밖으로 나가는 기계(선택 열)는 판 아래 변에서 잘린다.
	var panel := Control.new()
	panel.position = area.position
	panel.size = Vector2(area.size.x,
			SHOP_PICK_PANEL_H if mode == GameState.GACHA_PICK else area.size.y)
	panel.clip_contents = true
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.draw.connect(func() -> void: _draw_gacha_panel(panel, mode))
	col.add_child(panel)
	var mach_r: Rect2 = GACHA_MACHINE_RECT[mode]
	var machine := Control.new()
	machine.position = mach_r.position
	machine.size = mach_r.size
	machine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	machine.draw.connect(func() -> void: _draw_machine(machine, mode))
	panel.add_child(machine)
	_gacha_machines.append(machine)
	if mode == GameState.GACHA_CAN:
		# 피그마 고급 열에는 고르기 줄이 없다 — 기계 판을 누르면 유니크 냥이를 고른다.
		var pick_b := Button.new()
		pick_b.flat = true
		pick_b.focus_mode = Control.FOCUS_NONE
		pick_b.position = panel.position
		pick_b.size = panel.size
		for st in ["normal", "hover", "pressed", "focus"]:
			pick_b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		pick_b.pressed.connect(func() -> void:
			Sfx.play("click")
			_open_gacha_can())
		col.add_child(pick_b)
	if mode == GameState.GACHA_PICK:
		# 걸어 둔 냥이 캡슐 줄 + "캐릭터 N종 선택" (피그마 Frame 100: 폭 508, 판 아래 10).
		var box := Rect2(area.position.x + 17.0, area.position.y + SHOP_PICK_PANEL_H + 10.0,
				508.0, area.size.y - SHOP_PICK_PANEL_H - 10.0)
		var chips := Control.new()
		chips.position = box.position + Vector2(0.0, 10.0)
		chips.size = Vector2(box.size.x, 81.8)
		chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chips.draw.connect(func() -> void: _draw_gacha_pick_row(chips))
		col.add_child(chips)
		var set_btn := Button.new()
		set_btn.text = tr("SHOP_GACHA_PICK_SET").format({"n": GameState.KEYCAP_PICK_SIZE})
		set_btn.size = Vector2(220.0, 57.0)
		set_btn.position = box.position + Vector2((box.size.x - 220.0) / 2.0, 99.8)
		UiKit.style_button(set_btn, UiKit.WHITE, Color("747474"), Color.BLACK, 25, 16,
				true, 3, 7)
		set_btn.pressed.connect(func() -> void:
			Sfx.play("click")
			_open_gacha_pick())
		col.add_child(set_btn)
	# 개수 스테퍼 (피그마 btn_combo) — [최소|◀  n  ▶|최대]가 한 줄로 이어 붙는다.
	var side := 100.0
	var qty := 211.0
	var arrow := 61.0
	var face_h := 53.0  # + 두께 7 = 60
	var sx := (SHOP_COL.x - (side * 2.0 + qty + 16.0)) / 2.0
	var steps: Array[Button] = []
	var min_b := _gacha_step_btn(tr("SHOP_GACHA_MIN"), Rect2(sx, SHOP_STEP_Y, side, face_h),
			[16, 0, 0, 16])
	min_b.pressed.connect(func() -> void: _set_gacha_count(idx, 1))
	col.add_child(min_b)
	steps.append(min_b)
	var qx := sx + side + 8.0
	var qty_bg := Control.new()
	qty_bg.position = Vector2(qx, SHOP_STEP_Y)
	qty_bg.size = Vector2(qty, face_h + 7.0)
	qty_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qty_bg.draw.connect(func() -> void:
		UiKit.round_rect(qty_bg, Rect2(Vector2.ZERO, qty_bg.size), Color("f4f2eb"), 16))
	col.add_child(qty_bg)
	var dec := _gacha_step_btn("", Rect2(qx, SHOP_STEP_Y, arrow, face_h), [16, 0, 0, 16],
			"ic_step_l.svg")
	dec.pressed.connect(func() -> void: _set_gacha_count(idx, _gacha_n[idx] - 1))
	col.add_child(dec)
	steps.append(dec)
	var count := Label.new()
	count.position = Vector2(qx + arrow, SHOP_STEP_Y)
	count.size = Vector2(qty - arrow * 2.0, face_h + 7.0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiKit.label(count, 30, INK)
	col.add_child(count)
	var inc := _gacha_step_btn("", Rect2(qx + qty - arrow, SHOP_STEP_Y, arrow, face_h),
			[0, 16, 16, 0], "ic_step_r.svg")
	inc.pressed.connect(func() -> void: _set_gacha_count(idx, _gacha_n[idx] + 1))
	col.add_child(inc)
	steps.append(inc)
	var max_b := _gacha_step_btn(tr("SHOP_GACHA_MAX"),
			Rect2(qx + qty + 8.0, SHOP_STEP_Y, side, face_h), [0, 16, 16, 0])
	max_b.pressed.connect(func() -> void:
		_set_gacha_count(idx, GameState.keycap_max_draws(mode)))
	col.add_child(max_b)
	steps.append(max_b)
	# 뽑기 버튼 (피그마 btn_option) — 글자와 값 알약은 얼굴 Control이 직접 그린다.
	var draw_b := Button.new()
	draw_b.position = Vector2(SHOP_PAD, SHOP_DRAW_Y)
	draw_b.size = Vector2(SHOP_COL.x - SHOP_PAD * 2.0, 84.0)
	_style_draw_btn(draw_b, false)
	draw_b.text = ""
	draw_b.pressed.connect(func() -> void: _on_gacha(idx))
	col.add_child(draw_b)
	var face := Control.new()
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.draw.connect(func() -> void: _draw_gacha_draw_btn(face, mode))
	draw_b.add_child(face)
	_gacha_cols.append({"mode": mode, "col": col, "count": count, "face": face,
			"panel": panel, "machine": machine, "draw": draw_b, "steps": steps})


## 스테퍼 조각 하나 — 흰 얼굴 + 잉크 테 3 + 회색 두께 7. corners = [tl, tr, br, bl].
func _gacha_step_btn(label: String, r: Rect2, corners: Array, icon := "") -> Button:
	var b := Button.new()
	b.text = label
	b.position = r.position
	b.size = r.size
	b.focus_mode = Control.FOCUS_NONE
	UiKit.style_button(b, UiKit.WHITE, Color("888888") if icon == "" else Color("898989"),
			Color.BLACK, 24, 16, true, 3, 7)
	UiKit.btn_corners(b, corners[0], corners[1], corners[2], corners[3])
	if icon != "":
		var ic := Control.new()
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.draw.connect(func() -> void:
			UiKit.draw_tex(ic, icon, Rect2((ic.size - Vector2(30.0, 30.0)) / 2.0,
					Vector2(30.0, 30.0)),
					Color(1, 1, 1, 0.35) if b.disabled else Color.WHITE))
		b.add_child(ic)
	return b


## 뽑기 버튼은 셋 다 초록 + 잉크 테 3 + 진초록 두께 7 (피그마 btn_option). 품절이면 회색.
func _style_draw_btn(b: Button, sold_out: bool) -> void:
	if sold_out:
		UiKit.style_button(b, Color("9a9a9a"), Color("6d6a74"), UiKit.WHITE, 26, 16, true, 3, 7)
	else:
		UiKit.style_button(b, UiKit.GREEN, UiKit.GREEN_DEEP, INK, 26, 16, true, 3, 7)


## 기계 판 — 회색(고급 열은 연보라) 둥근 판. 기계 그림은 자식 Control이 그린다.
func _draw_gacha_panel(ci: Control, mode: int) -> void:
	var can_col := mode == GameState.GACHA_CAN
	UiKit.round_rect(ci, Rect2(Vector2.ZERO, ci.size),
			UiKit.LAVENDER if can_col else Color("f0f0f0"), 20)


## 선택 열의 걸어 둔 냥이 줄 — 투명 뚜껑 + 냥이 얼굴 + 빨간 아래통 (피그마 Group 22~27).
func _draw_gacha_pick_row(ci: Control) -> void:
	var slots: int = GameState.KEYCAP_PICK_SIZE
	var w := 80.63
	var gap := 8.0
	var x0 := (ci.size.x - (w * slots + gap * (slots - 1))) / 2.0
	for i in slots:
		var id := ""
		if i < GameState.gacha_pick.size():
			id = str(GameState.gacha_pick[i])
		var o := Vector2(x0 + i * (w + gap), 0.0)
		var tint := Color.WHITE if id != "" else Color(1, 1, 1, 0.35)
		UiKit.draw_tex(ci, "capsule_lid.png", Rect2(o, Vector2(w, 53.31)), tint)
		if id != "":
			# 피그마는 캡슐 안에 냥이 한 마리(40×48)가 통째로 앉아 있다.
			var fit := _fit_cat(Rect2(o + Vector2(18.0, 10.0), Vector2(45.0, 52.0)))
			Player.paint_cat(ci, fit[1], fit[0], 0.0, true, false, GameState.cat_skin(id))
		UiKit.draw_tex(ci, "capsule_bot_red.png", Rect2(o + Vector2(0.0, 43.23),
				Vector2(w, 38.57)), tint)
		if id == "":
			UiKit.text(ci, "?", o + Vector2(w / 2.0, 44.0), 28, Color(TEXT, 0.4), true, 1)


## 뽑기 버튼 얼굴 — "일반 뽑기" + 반투명 검은 값 알약(코인/캔 + 값). 재화가 모자라면 값이 붉다.
func _draw_gacha_draw_btn(ci: Control, mode: int) -> void:
	var cans_mode := mode == GameState.GACHA_CAN
	var n: int = _gacha_n[mode]
	var price: int = GameState.keycap_price(n, mode)
	var w := ci.size.x
	var cy := ci.size.y / 2.0
	if _gacha_sold_out(mode):
		UiKit.text(ci, tr("SHOP_GACHA_SOLD_OUT"), Vector2(w / 2.0, cy + 9.0), 26,
				UiKit.WHITE, true, 1, w - 40.0)
		return
	var label := tr(["SHOP_GACHA_RANDOM", "SHOP_GACHA_PICK", "SHOP_GACHA_CAN"][mode])
	var purse: int = GameState.cans if cans_mode else GameState.gold
	var ok := purse >= price
	var price_s := UiKit.commas(price)
	var icon_w := 38.0 if cans_mode else 32.0
	var pill_w := 8.0 + icon_w + 8.0 + UiKit.text_width(price_s, 24, true) + 12.0
	var lw := UiKit.font_heavy().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x  # 피그마 7 Bold
	var x := (w - (lw + 8.0 + pill_w)) / 2.0
	ci.draw_string(UiKit.font_heavy(), Vector2(x, cy + 9.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1,
			26, INK)
	var pill := Rect2(x + lw + 8.0, cy - 20.0, pill_w, 40.0)
	UiKit.round_rect(ci, pill, Color(0, 0, 0, 0.6), 20)
	var ic := pill.position + Vector2(8.0 + icon_w / 2.0, 20.0)
	if cans_mode:
		UiKit.can_icon(ci, ic, 32.0)
	else:
		UiKit.coin_icon(ci, ic, 32.0)
	UiKit.text(ci, price_s, pill.position + Vector2(8.0 + icon_w + 8.0, 29.0), 24,
			UiKit.WHITE if ok else Color("ffb3b3"), true)


func _set_gacha_count(idx: int, n: int) -> void:
	n = clampi(n, 1, _gacha_cap(idx))
	if n == _gacha_n[idx]:
		Sfx.play("error")
		return
	_gacha_n[idx] = n
	Sfx.play("click")
	_refresh_gacha()


# --- 선택 뽑기 냥이 고르기 ------------------------------------------------------


## 뽑기에 걸 냥이를 고르는 팝업 (피그마 `선택뽑기 캐릭터` 93:5148, 1000×850):
## 제목 + 우상단 ✕ · 노란 판(설명 한 줄 + 한 줄 5칸 냥이 카드 격자, 오른쪽 흰 스크롤 바) ·
## "선택한 냥이 n / 5" 알약 · 고른 냥이 카드 줄 · [초기화][저장]. 캔 열은 같은 틀에 유니크 냥이만, 1칸.
func _build_gacha_pick_ui(can_mode: bool) -> void:
	var close_fn := func() -> void:
		if can_mode:
			_close_gacha_can()
		else:
			_close_gacha_pick()
	var ui := _make_overlay(
			tr("SHOP_GACHA_CAN_TITLE") if can_mode else tr("SHOP_GACHA_PICK_TITLE"),
			close_fn, Vector2(minf(vw - 80.0, PICK_POP.x),
			# 세로 화면은 남는 높이만큼 키워 격자를 더 많이 보여 준다 (아래 줄·버튼 자리는 그대로).
			minf(vh - 100.0, PICK_POP.y) if vw >= vh else minf(vh - 360.0, 1400.0)))
	if can_mode:
		_gacha_can_ui = ui
	else:
		_gacha_pick_ui = ui
	var card: Control = ui.get_meta("card")
	var pw := card.size.x
	var ph := card.size.y
	var inner := pw - 80.0
	# ✕ (피그마 btn-primary 68×68 + 회색 두께 5) — 머리 줄 오른쪽 끝.
	var close := Button.new()
	close.position = Vector2(pw - 40.0 - 68.0, 40.0)
	close.size = Vector2(68.0, 68.0)
	close.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus"]:
		close.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var close_face := Control.new()
	close_face.set_anchors_preset(Control.PRESET_FULL_RECT)
	close_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	close_face.draw.connect(func() -> void:
		var down := 3.0 if close.button_pressed else 0.0
		UiKit.round_rect(close_face, Rect2(0.0, 5.0, 68.0, 68.0), Color("898989"), 20)
		UiKit.draw_tex(close_face, "ic_close_btn.svg", Rect2(0.0, down, 68.0, 68.0)))
	close.add_child(close_face)
	close.button_down.connect(func() -> void: close_face.queue_redraw())
	close.button_up.connect(func() -> void: close_face.queue_redraw())
	close.pressed.connect(func() -> void:
		Sfx.play("click")
		close_fn.call())
	card.add_child(close)
	# 아래에서부터: 버튼 줄(78) · 20 · 고른 냥이 줄(170) · 8 · 알약(40) · 20 · 노란 판.
	var btn_y := ph - 40.0 - 78.0
	var row_y := btn_y - 20.0 - PICK_ROW_H
	var pill_y := row_y - 8.0 - 40.0
	var board_y := 40.0 + 73.0 + 20.0
	var board := Rect2(40.0, board_y, inner, pill_y - 20.0 - board_y)
	var board_c := Control.new()
	board_c.position = board.position
	board_c.size = board.size
	board_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_c.draw.connect(func() -> void:
		UiKit.round_rect(board_c, Rect2(Vector2.ZERO, board_c.size), UiKit.TRAY, 10)
		UiKit.text(board_c, tr("SHOP_GACHA_CAN_DESC") if can_mode
				else tr("SHOP_GACHA_PICK_DESC").format({"n": GameState.KEYCAP_PICK_SIZE}),
				Vector2(board_c.size.x / 2.0, 20.0 + 22.0), 22, Color.BLACK, false, 1,
				board_c.size.x - 40.0))
	card.add_child(board_c)
	# 격자 + 오른쪽 흰 스크롤 바 (판 안쪽 여백: 왼 20 · 오른 10 · 위아래 20, 설명 줄 아래 20).
	var scroll := ScrollContainer.new()
	scroll.position = board.position + Vector2(20.0, 20.0 + 27.0 + 20.0)
	scroll.size = Vector2(board.size.x - 30.0, board.size.y - 20.0 - 27.0 - 20.0 - 20.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO  # 다 들어가면 바를 숨긴다
	_style_pick_scrollbar(scroll.get_v_scroll_bar())
	card.add_child(scroll)
	var grid := Control.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var cats: Array = []
	for cat in GameState.keycap_cats():
		if bool(cat.get("unique", false)) == can_mode:
			cats.append(cat)
	var grid_w := scroll.size.x - 18.0 - 20.0
	var cols := 5
	var chip := Vector2((grid_w - 16.0 * (cols - 1)) / cols, PICK_CHIP_H)
	var rows := int(ceilf(cats.size() / float(cols)))
	grid.custom_minimum_size = Vector2(grid_w, rows * (chip.y + 20.0) - 20.0)
	for i in cats.size():
		var cat: Dictionary = cats[i]
		var b := Button.new()
		b.position = Vector2((i % cols) * (chip.x + 16.0), (i / cols) * (chip.y + 20.0))
		b.size = chip
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var face := Control.new()
		face.set_anchors_preset(Control.PRESET_FULL_RECT)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.draw.connect(func() -> void: _draw_gacha_chip(face, cat, can_mode))
		b.add_child(face)
		b.pressed.connect(func() -> void:
			if can_mode:
				_set_gacha_can(str(cat.id))
			else:
				_toggle_gacha_pick(str(cat.id)))
		grid.add_child(b)
		if can_mode:
			_gacha_can_chips[str(cat.id)] = b
		else:
			_gacha_chips[str(cat.id)] = b
	# 아래: "선택한 냥이 n / 5" 알약 + 고른 냥이 카드 줄.
	var picked := Control.new()
	picked.position = Vector2(40.0, pill_y)
	picked.size = Vector2(inner, row_y + PICK_ROW_H - pill_y)
	picked.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picked.draw.connect(func() -> void: _draw_gacha_picked_row(picked, can_mode))
	card.add_child(picked)
	if not can_mode:
		_gacha_count = Label.new()
		_gacha_count.visible = false  # 숫자는 picked 판이 직접 그린다
		card.add_child(_gacha_count)
	# [초기화](흰 + 진회색 두께) [저장](초록) — 250×78, 간격 14.
	var reset := Button.new()
	reset.text = tr("CC_RESET")
	reset.size = Vector2(250.0, 71.0)
	reset.position = Vector2(pw / 2.0 - 250.0 - 7.0, btn_y)
	UiKit.style_button(reset, UiKit.WHITE, Color("6f6f6f"), Color.BLACK, 30, 16, true, 3, 7)
	reset.pressed.connect(func() -> void:
		Sfx.play("click")
		if can_mode:
			GameState.gacha_can_pick = ""
		else:
			GameState.gacha_pick = []
		GameState.save_game()
		_refresh_gacha())
	card.add_child(reset)
	var done := Button.new()
	done.text = tr("CC_SAVE")
	done.size = Vector2(250.0, 71.0)
	done.position = Vector2(pw / 2.0 + 7.0, btn_y)
	UiKit.btn_primary(done, 30)
	done.pressed.connect(func() -> void:
		Sfx.play("click")
		close_fn.call())
	card.add_child(done)
	ui.set_meta("picked", picked)


## 격자 옆 스크롤 바 (피그마 scroll): 흰 알약 트랙 18폭 + 회색 손잡이(검은 테 1).
func _style_pick_scrollbar(bar: VScrollBar) -> void:
	bar.custom_minimum_size.x = 18.0
	var track := StyleBoxFlat.new()
	track.bg_color = UiKit.WHITE
	track.set_corner_radius_all(99)
	track.content_margin_left = 3.0
	track.content_margin_right = 3.0
	track.content_margin_top = 3.0
	track.content_margin_bottom = 3.0
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	for st in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var g := StyleBoxFlat.new()
		g.bg_color = Color("828282") if st == "grabber" else Color("6f6f6f")
		g.set_corner_radius_all(99)
		g.set_border_width_all(1)
		g.border_color = Color.BLACK
		bar.add_theme_stylebox_override(st, g)


## 팝업 아래 — "선택한 냥이 n / 5" 알약(숫자만 Black) + 고른 냥이 카드(흰 + 갈색 테 3).
func _draw_gacha_picked_row(ci: Control, can_mode: bool) -> void:
	var w := ci.size.x
	var ids: Array = [GameState.gacha_can_pick] if can_mode else GameState.gacha_pick
	var slots: int = 1 if can_mode else GameState.KEYCAP_PICK_SIZE
	var picked := 0
	for id: Variant in ids:
		if str(id) != "":
			picked += 1
	UiKit.round_rect(ci, Rect2(0.0, 0.0, w, 40.0), Color(1, 1, 1, 0.8), 20)
	var parts := tr("SHOP_GACHA_PICK_COUNT").split("{n}")
	var left := parts[0]
	var right := (parts[1] if parts.size() > 1 else "").format({"max": slots})
	var num := str(picked)
	var fb := UiKit.font_bold()
	var fk := UiKit.font_black()
	var lw := fb.get_string_size(left, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var nw := fk.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var rw := fb.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var x := (w - lw - nw - rw) / 2.0
	ci.draw_string(fb, Vector2(x, 27.0), left, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.BLACK)
	ci.draw_string(fk, Vector2(x + lw, 27.0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
			Color.BLACK)
	ci.draw_string(fb, Vector2(x + lw + nw, 27.0), right, HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
			Color.BLACK)
	var gap := 10.0
	var cw := (w - gap * (GameState.KEYCAP_PICK_SIZE - 1)) / GameState.KEYCAP_PICK_SIZE
	var x0 := (w - (cw * slots + gap * (slots - 1))) / 2.0
	for i in slots:
		var r := Rect2(x0 + i * (cw + gap), 48.0, cw, PICK_ROW_H)
		var id := str(ids[i]) if i < ids.size() else ""
		if id == "":
			UiKit.round_rect_outline(ci, r, Color(1, 1, 1, 0.6), 10, 3, Color("d6d6d6"))
			UiKit.text(ci, "?", r.get_center() + Vector2(0.0, 12.0), 34, Color(TEXT, 0.3),
					true, 1)
			continue
		UiKit.round_rect_outline(ci, r, UiKit.WHITE, 10, 3, Color("4e3f00"))
		_draw_pick_card_body(ci, r, id, true, false)


## 냥이 카드 속 — 위 32줄(고른 냥이면 오른쪽 ✓) · 냥이 66×80 · 이름 16 · 키캡 알약
## (아이콘 + n/26) · (bar면) 등급 막대 4칸. 피그마 `cat list` 컴포넌트.
func _draw_pick_card_body(ci: Control, r: Rect2, id: String, chosen: bool,
		bar: bool, on_yellow := false) -> void:
	if chosen:
		UiKit.draw_tex(ci, "ic_check.svg", Rect2(r.end.x - 6.0 - 26.0, r.position.y + 6.0,
				26.0, 26.0))
	var cx := r.get_center().x
	var cat_r := Rect2(cx - 33.0, r.position.y + 32.0, 66.0, 80.0)
	var body := cat_r.size.x * 0.86
	Player.paint_cat(ci, Vector2(cx, cat_r.end.y - body * CAT_DOWN), body, 0.0, true, false,
			GameState.cat_skin(id))
	var y := cat_r.end.y + 4.0
	UiKit.text(ci, tr(str(GameState.get_cat(id).name)), Vector2(cx, y + 16.0), 16,
			Color("272727"), true, 1, r.size.x - 20.0)
	y += 19.0 + 4.0
	var done: bool = not GameState.can_pick_gacha(id)
	var prog := tr("SHOP_GACHA_CHIP_DONE") if done else "%d/26" % GameState.keycap_ring(id)
	var tw := UiKit.text_width(prog, 12, true)
	var pill := Rect2(cx - (2.0 + 14.0 + tw + 2.0) / 2.0, y, 2.0 + 14.0 + tw + 2.0, 20.0)
	UiKit.round_rect_outline(ci, pill, UiKit.WHITE, 4, 1, Color("d6d6d6"))
	UiKit.draw_tex(ci, "ic_keycap.svg", Rect2(pill.position + Vector2(2.0, 3.0),
			Vector2(14.0, 14.0)))
	UiKit.text(ci, prog, pill.position + Vector2(16.0, 15.0), 12, Color("272727"), true)
	if bar:
		# _draw_grade_pips는 x 14부터 그린다 — 피그마 막대는 카드 안쪽 10부터라 4만큼 당긴다.
		ci.draw_set_transform(Vector2(r.position.x - 4.0, 0.0))
		_draw_grade_pips(ci, id, y + 20.0 + 6.0, r.size.x + 8.0, on_yellow)
		ci.draw_set_transform(Vector2.ZERO)


func _open_gacha_pick() -> void:
	_raise(_gacha_pick_ui)
	_refresh_gacha()
	_gacha_pick_ui.visible = true


func _close_gacha_pick() -> void:
	_gacha_pick_ui.visible = false
	_refresh_gacha()


func _open_gacha_can() -> void:
	_raise(_gacha_can_ui)
	_refresh_gacha()
	_gacha_can_ui.visible = true


func _close_gacha_can() -> void:
	_gacha_can_ui.visible = false
	_refresh_gacha()


## 캔 뽑기에 걸 유니크 냥이 1종 — 같은 냥이를 다시 누르면 내려놓는다.
func _set_gacha_can(id: String) -> void:
	if not GameState.can_pick_gacha(id):
		Sfx.play("error")
		_show_toast(tr("SHOP_GACHA_DONE_CAT").format(
				{"name": tr(str(GameState.get_cat(id).name))}), UiKit.MUTED)
		return
	if GameState.gacha_can_pick == id:
		GameState.gacha_can_pick = ""
		Sfx.play("click")
	else:
		GameState.gacha_can_pick = id
		Sfx.play("buy")
	GameState.save_game()
	_refresh_gacha()


## 뽑기 냥이 카드 (피그마 `cat list`) — 연회색(고르면 노랑 #ffcd03, 다 모은 냥이는 회색) 판.
func _draw_gacha_chip(ci: Control, cat: Dictionary, can_mode := false) -> void:
	var id := str(cat.id)
	var chosen := (id == GameState.gacha_can_pick) if can_mode \
			else (id in GameState.gacha_pick)
	var done: bool = not GameState.can_pick_gacha(id)
	var bg := Color("e1e1e1") if done else (Color("ffcd03") if chosen else Color("f9f9f9"))
	UiKit.round_rect(ci, Rect2(Vector2.ZERO, ci.size), bg, 10)
	_draw_pick_card_body(ci, Rect2(Vector2.ZERO, ci.size), id, chosen, true, chosen)

func _toggle_gacha_pick(id: String) -> void:
	var pick: Array = GameState.gacha_pick.duplicate()
	if not GameState.can_pick_gacha(id):
		Sfx.play("error")
		_show_toast(tr("SHOP_GACHA_DONE_CAT").format(
				{"name": tr(str(GameState.get_cat(id).name))}), UiKit.MUTED)
		return
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
	_refresh_gacha()


## 캡슐 뽑기 (mode = GACHA_RANDOM/PICK/CAN, 개수는 그 열의 스테퍼 값).
func _on_gacha(mode: int) -> void:
	GameState.prune_gacha_pick()
	if mode == GameState.GACHA_PICK \
			and GameState.gacha_pick.size() < GameState.gacha_pick_need():
		Sfx.play("error")
		_show_toast(tr("SHOP_GACHA_PICK_NEED").format(
				{"n": GameState.gacha_pick_need()}), Color(1.0, 0.55, 0.5))
		return
	if mode == GameState.GACHA_CAN and GameState.gacha_can_pick == "":
		# 고급 열에는 고르기 버튼이 없다(피그마) — 바로 유니크 냥이 고르기를 연다.
		Sfx.play("error")
		_show_toast(tr("SHOP_GACHA_CAN_NEED"), Color(1.0, 0.55, 0.5))
		_open_gacha_can()
		return
	if GameState.gacha_capacity(mode) <= 0:
		Sfx.play("error")
		_show_toast(tr("SHOP_GACHA_SOLD_OUT"), Color(1.0, 0.55, 0.5))
		return
	var pull := GameState.draw_keycaps(_gacha_n[mode], mode)
	if pull.is_empty():
		Sfx.play("error")
		_show_toast(tr("SHOP_NO_CANS" if mode == GameState.GACHA_CAN
				else "SHOP_NO_GOLD"), Color(1.0, 0.55, 0.5))
		return
	_last_pull = pull
	_pull_t = 0.0
	_pull_anim = true
	_open_gacha_result()
	_unlock_queue.clear()
	_unlock_at = 0
	var announced := false
	for hit: Dictionary in pull:
		if not hit.grade_up:
			continue
		var id := str(hit.cat)
		var grade := GameState.cat_grade(id)
		_unlock_queue.append({"cat": id, "grade": grade})
		if announced:
			continue
		var cat_name := tr(str(GameState.get_cat(id).name))
		Sfx.play("record")
		_show_toast(tr("CHAR_RECRUITED").format({"name": cat_name}) if grade == 1
				else tr("KEYCAP_GRADE_UP").format({"name": cat_name, "grade": grade}),
				CREAM)
		announced = true
	if not announced:
		var last: Dictionary = pull[-1]
		var cat_name := tr(str(GameState.get_cat(str(last.cat)).name))
		Sfx.play("buy")
		_show_toast(tr("KEYCAP_NEW").format(
				{"name": cat_name, "letter": str(last.letter)}), GOLD_COL)
	_refresh_gacha()
	_refresh_currency()
	_refresh_tiles()
	if _keycap_dex.visible:
		_refresh_keycap_dex()


# --- 뽑기 기계 그리기 ----------------------------------------------------------


## 기계 그림 (피그마 원본을 피그마 프레임대로 잘라 둔 machine_*.png) + 기계 속
## 캡슐 묶음(machine_*_caps.png, 피그마 Group 42 내보내기). 뽑는 동안엔 살짝 흔들린다.
func _draw_machine(ci: Control, mode: int) -> void:
	var key: String = ["random", "pick", "can"][mode]
	var jig := Vector2.ZERO
	if _pull_anim:
		jig = Vector2(sin(_spin_t * 40.0) * 3.0, absf(cos(_spin_t * 27.0)) * -4.0)
	var t := UiKit.tex("machine_%s.png" % key)
	if t != null:
		ci.draw_texture_rect(t, Rect2(jig, ci.size), false)
	var caps: Rect2 = GACHA_CAPS_RECT[mode]
	var mach: Rect2 = GACHA_MACHINE_RECT[mode]
	var ct := UiKit.tex("machine_%s_caps.png" % key)
	if ct != null:
		ci.draw_texture_rect(ct, Rect2(caps.position - mach.position + jig, caps.size), false)


## 그 열의 뽑기에 들어가는 냥이들의 캡슐 색 (풀이 비면 기본 팔레트).
func _gacha_pool_colors(mode: int) -> Array:
	var out: Array = []
	for id: String in GameState.gacha_pool(mode):
		out.append(GameState.get_cat(id).ear)
	if out.is_empty():
		out = [UiKit.GOLD, UiKit.PINK, UiKit.CYAN, UiKit.PURPLE]
	return out


## 스프라이트 냥이는 몸통 폭 s를 기준으로 중심에서 위로 CAT_UP·아래로 CAT_DOWN,
## 좌우로 CAT_SIDE만큼 그려진다 — 머리 소품이 시트 캔버스 위쪽을 다 쓴다.
const CAT_UP := 0.95
const CAT_DOWN := 0.57
const CAT_SIDE := 0.8


## rect 안에 냥이가 통째로 들어가는 [몸통 폭, 중심].
func _fit_cat(rect: Rect2) -> Array:
	var s := minf(rect.size.y / (CAT_UP + CAT_DOWN), rect.size.x / (CAT_SIDE * 2.0))
	var at := Vector2(rect.position.x + rect.size.x / 2.0,
			rect.position.y + (rect.size.y - s * (CAT_UP + CAT_DOWN)) / 2.0
			+ s * CAT_UP)
	return [s, at]


func _round_box(ci: CanvasItem, r: Rect2, col: Color, radius: int) -> void:
	UiKit.round_rect_outline(ci, r, col, radius, 4)


## 시트 얼굴 컷을 rect 폭에 맞춰 그린다. 그림이 없으면 false.
func _paint_face(ci: CanvasItem, rect: Rect2, char_id: String) -> bool:
	if char_id == "":
		return false
	var t: Texture2D = CatSprite.face_texture(char_id)
	if t == null:
		return false
	var src: Rect2 = CatSprite.face_rect(char_id)
	var h := rect.size.x * src.size.y / src.size.x
	ci.draw_texture_rect_region(t, Rect2(rect.position + Vector2(0.0, rect.size.y - h),
			Vector2(rect.size.x, h)), src)
	return true


# --- 당첨 트레이 --------------------------------------------------------------


## 뽑기 결과 팝업 (피그마 "뽑기결과"): 제목 + 한 줄 + 노란 트레이에 캡슐들 + 확인.
func _build_gacha_result() -> void:
	_gacha_result = _make_overlay(tr("SHOP_GACHA_RESULT"),
			func() -> void: _close_gacha_result(),
			Vector2(minf(vw - 120.0, 1200.0), minf(vh - 90.0, 992.0)))
	var body: Control = _gacha_result.get_meta("body")
	var sub := Label.new()
	sub.text = tr("SHOP_GACHA_RESULT_SUB")
	sub.position = Vector2(0.0, -2.0)
	sub.size = Vector2(body.size.x, 30.0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.label(sub, 22, Color.BLACK)
	body.add_child(sub)
	# 피그마: 트레이는 부제 아래 55 · 확인 버튼(250×78)은 트레이 아래 30 · 카드 아래 여백 30.
	var btn_y := body.size.y - 78.0 + 10.0
	_gacha_tray = Control.new()
	_gacha_tray.position = Vector2(0.0, 55.0)
	_gacha_tray.size = Vector2(body.size.x, btn_y - 30.0 - 55.0)
	_gacha_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gacha_tray.clip_contents = true
	_gacha_tray.draw.connect(func() -> void: _draw_gacha_tray(_gacha_tray))
	body.add_child(_gacha_tray)
	var ok := Button.new()
	ok.text = tr("UI_CONFIRM")
	ok.size = Vector2(250.0, 71.0)
	ok.position = Vector2((body.size.x - 250.0) / 2.0, btn_y)
	UiKit.btn_primary(ok, 30)
	ok.pressed.connect(func() -> void:
		Sfx.play("click")
		_close_gacha_result())
	body.add_child(ok)


func _open_gacha_result() -> void:
	_raise(_gacha_result)
	_gacha_result.visible = true
	_gacha_tray.queue_redraw()


func _close_gacha_result() -> void:
	_gacha_result.visible = false
	_pull_anim = false
	_flush_unlocks()


## 결과 연출 전체 길이 (초).
func _gacha_pull_len() -> float:
	var n := _last_pull.size()
	return _gacha_open_at(n - 1) + CAPSULE_OPEN


## i번째 캡슐이 열리기 시작하는 시각 — 전부 앉은 뒤 HOLD, 그다음 차례로.
func _gacha_open_at(i: int) -> float:
	var n := _last_pull.size()
	return (n - 1) * CAPSULE_STEP + CAPSULE_FALL + CAPSULE_HOLD + i * CAPSULE_OPEN_STEP


## 뽑기 결과 트레이 (피그마 `뽑기결과` 두 장: 닫힌 캡슐 → 열린 캡슐). 닫힌 캡슐이 위에서
## 하나씩 떨어져 앉고, 다 앉으면 차례로 뚜껑이 올라가고 아래통이 내려가며 냥이가 드러난다.
## 좌표는 피그마 트레이(1120×689) 기준 — 트레이가 작으면 통째로 줄인다.
func _draw_gacha_tray(ci: Control) -> void:
	var w := ci.size.x
	var h := ci.size.y
	UiKit.round_rect(ci, Rect2(0.0, 0.0, w, h), UiKit.TRAY, 28)
	if _last_pull.is_empty():
		UiKit.text(ci, tr("SHOP_GACHA_EMPTY"), Vector2(w / 2.0, h / 2.0 + 8.0), 19,
				UiKit.MUTED, false, 1)
		return
	var k := minf(w / RESULT_TRAY.x, h / RESULT_TRAY.y)
	var origin := (ci.size - RESULT_TRAY * k) / 2.0
	ci.draw_set_transform(origin, 0.0, Vector2(k, k))
	var n := _last_pull.size()
	var cols := mini(n, 5)
	var rows := int(ceilf(n / float(cols)))
	var rows_h := RESULT_CAP.y + (rows - 1) * RESULT_PITCH.y
	var top := (RESULT_TRAY.y - rows_h) / 2.0
	for i in n:
		var t := _pull_t - i * CAPSULE_STEP
		if t <= 0.0:
			continue
		var row := i / cols
		var in_row := mini(cols, n - row * cols)
		var row_w := RESULT_CAP.x + (in_row - 1) * RESULT_PITCH.x
		var col := i % cols
		var base := Vector2((RESULT_TRAY.x - row_w) / 2.0 + col * RESULT_PITCH.x,
				top + row * RESULT_PITCH.y)
		# 떨어지기: 트레이 위 밖에서 제자리로 (끝에 살짝 눌렸다 편다).
		var fall := minf(t / CAPSULE_FALL, 1.0)
		base.y -= (1.0 - (1.0 - pow(1.0 - fall, 3.0))) * (base.y + RESULT_CAP.y + 40.0)
		var squash := 0.0 if fall < 1.0 else maxf(0.0, 1.0 - (t - CAPSULE_FALL) / 0.14)
		var ot := clampf((_pull_t - _gacha_open_at(i)) / CAPSULE_OPEN, 0.0, 1.0)
		var open_amt := _ease_out_back(ot)
		_draw_result_capsule(ci, base, i, _last_pull[i], open_amt, squash, ot)
	ci.draw_set_transform(Vector2.ZERO)


## 캡슐 한 알 (피그마 Group 22~31): 통 안쪽 테(색 타원) → 냥이 → 투명 뚜껑 → 색 아래통.
## open 0 = 닫힘(뚜껑 유리 너머로 냥이가 비친다), 1 = 뚜껑이 올라가고 아래통이 내려간 모습.
func _draw_result_capsule(ci: CanvasItem, base: Vector2, i: int, hit: Dictionary,
		open_amt: float, squash: float, ot: float) -> void:
	var cc: Array = RESULT_CAP_COLORS[i % RESULT_CAP_COLORS.size()]
	var lid_y := base.y - RESULT_LID_UP * open_amt
	var bowl_y := base.y + RESULT_BOWL_DOWN * open_amt
	# 착지 눌림 — 가운데 아래를 기준으로 납작하게.
	var sq := Vector2(1.0 + 0.06 * squash, 1.0 - 0.06 * squash)
	var pivot := base + Vector2(RESULT_CAP.x / 2.0, RESULT_CAP.y)
	var sub := func(r: Rect2) -> Rect2:
		var p := pivot + (r.position - pivot) * sq
		return Rect2(p, r.size * sq)
	var rim_h := lerpf(30.11, 33.0, open_amt)
	var rim: Rect2 = sub.call(Rect2(base.x + 5.0, bowl_y + lerpf(105.39, 97.12, open_amt),
			lerpf(194.05, 192.0, open_amt), rim_h))
	_fill_ellipse(ci, rim, Color(str(cc[1])))
	var cat_r: Rect2 = sub.call(Rect2(base.x + 58.55, bowl_y + 49.26, 83.64, 100.37))
	# 피그마 냥이 그림(83.6×100.4)은 몸통이 판 폭을 거의 다 채운다 — 몸통 폭 = 판 폭 × 0.86,
	# 발끝을 판 아래 변에 맞춘다 (머리 소품은 판 위로 삐져나가도 된다).
	var body := cat_r.size.x * 0.86
	Player.paint_cat(ci, Vector2(cat_r.get_center().x, cat_r.end.y - body * CAT_DOWN), body,
			0.0, true, false, GameState.cat_skin(str(hit.cat)))
	UiKit.draw_tex(ci, "capsule_lid.png", sub.call(Rect2(base.x, lid_y, 200.0, 132.23)))
	UiKit.draw_tex(ci, "capsule_bot_%s.png" % str(cc[0]),
			sub.call(Rect2(base.x, bowl_y + 107.23, 200.0, 95.66)))
	if ot <= 0.0:
		return
	# 열리는 순간 흰 링이 퍼진다.
	if ot < 1.0:
		var c := base + Vector2(100.0, 110.0)
		ci.draw_arc(c, 70.0 + 70.0 * ot, 0.0, TAU, 48, Color(1, 1, 1, 0.8 * (1.0 - ot)),
				10.0 * (1.0 - ot) + 2.0, true)
	# 열린 뒤: 이번에 나온 키캡 글자 (등급이 오른 뽑기는 빛난다) — 아래통 오른쪽 위.
	var a := clampf(ot * 2.0 - 1.0, 0.0, 1.0)
	if a <= 0.0:
		return
	var cap := Rect2(base.x + 138.0, bowl_y + 118.0, 50.0, 50.0)
	EscapeBoard.paint_keycap(ci, cap, str(hit.letter), 0.6, bool(hit.grade_up), str(hit.cat))


func _fill_ellipse(ci: CanvasItem, r: Rect2, col: Color) -> void:
	var pts := PackedVector2Array()
	var c := r.get_center()
	for j in 32:
		var ang := TAU * j / 32.0
		pts.append(c + Vector2(cos(ang) * r.size.x / 2.0, sin(ang) * r.size.y / 2.0))
	ci.draw_colored_polygon(pts, col)


func _ease_out_back(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


# --- 해금 안내 팝업 -------------------------------------------------------------
## 키캡 A~Z를 한 바퀴 채우면 등급이 오르고 무언가가 열린다 — 1등급은 캐릭터 합류,
## 2~4등급은 파츠 단계. 피그마 "아이템 해금": 제목 · 한 줄 · 그림 · [확인][캐릭터 선택으로].
func _build_unlock_pop() -> void:
	_unlock_pop = _make_overlay(tr("CHAR_UNLOCK_TITLE"),
			func() -> void: _next_unlock(),
			Vector2(minf(vw - 100.0, 800.0), minf(vh - 140.0, 620.0)))
	var body: Control = _unlock_pop.get_meta("body")
	_unlock_face = Control.new()
	_unlock_face.position = Vector2(0.0, -30.0)
	_unlock_face.size = Vector2(body.size.x, body.size.y - 70.0)
	_unlock_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unlock_face.draw.connect(func() -> void: _draw_unlock(_unlock_face))
	body.add_child(_unlock_face)
	_unlock_btn = Button.new()
	_unlock_btn.size = Vector2(250.0, 68.0)
	_unlock_btn.position = Vector2(body.size.x / 2.0 - 250.0 - 10.0, body.size.y - 74.0)
	UiKit.btn_card(_unlock_btn, UiKit.GRAY_DEEP, 26)
	_unlock_btn.pressed.connect(func() -> void: _next_unlock())
	body.add_child(_unlock_btn)
	_unlock_go = Button.new()
	_unlock_go.text = tr("CHAR_UNLOCK_GO")
	_unlock_go.size = Vector2(250.0, 68.0)
	_unlock_go.position = Vector2(body.size.x / 2.0 + 10.0, body.size.y - 74.0)
	UiKit.btn_primary(_unlock_go, 24)
	_unlock_go.pressed.connect(func() -> void:
		Sfx.play("click")
		var id := ""
		if _unlock_at < _unlock_queue.size():
			id = str(_unlock_queue[_unlock_at].cat)
		_unlock_queue.clear()
		_unlock_at = 0
		_unlock_pop.visible = false
		_close_gacha()
		_open_chars(true)
		if id != "":
			_char_view = id
			_refresh_char_page())
	body.add_child(_unlock_go)


func _flush_unlocks() -> void:
	if _unlock_pop == null or _unlock_pop.visible:
		return
	if _unlock_at >= _unlock_queue.size():
		return
	_open_unlock()


func _open_unlock() -> void:
	var item: Dictionary = _unlock_queue[_unlock_at]
	var head: Label = _unlock_pop.get_meta("head")
	head.text = tr("CHAR_UNLOCK_TITLE") if int(item.grade) <= 1 \
			else tr("CHAR_UNLOCK_PARTS_TITLE")
	var left := _unlock_queue.size() - _unlock_at - 1
	_unlock_btn.text = tr("CHAR_UNLOCK_NEXT").format({"n": left}) if left > 0 \
			else tr("UI_CONFIRM")
	Sfx.play("record")
	_raise(_unlock_pop)
	_unlock_pop.visible = true
	_unlock_face.queue_redraw()


func _next_unlock() -> void:
	_unlock_at += 1
	if _unlock_at < _unlock_queue.size():
		_open_unlock()
		return
	_unlock_queue.clear()
	_unlock_at = 0
	_unlock_pop.visible = false
	_refresh_gacha()
	queue_redraw()


## 팝업 본문 — 한 줄 안내 + 해금된 모습(캐릭터 한 컷 / 파츠는 이전 → 지금 두 컷).
func _draw_unlock(ci: Control) -> void:
	if _unlock_at >= _unlock_queue.size():
		return
	var item: Dictionary = _unlock_queue[_unlock_at]
	var id := str(item.cat)
	var grade := int(item.grade)
	var cat := GameState.get_cat(id)
	var w := ci.size.x
	var nm := tr(str(cat.name))
	var head_line := tr("CHAR_RECRUITED").format({"name": nm}) if grade <= 1 \
			else tr("KEYCAP_GRADE_UP").format({"name": nm, "grade": grade})
	UiKit.text(ci, head_line, Vector2(w / 2.0, 24.0), 20, TEXT, false, 1, w - 20.0)
	var tier := clampi(grade - 1, 0, GameState.CustomCat.TIER_MAX)
	var cy := 200.0
	if grade <= 1:
		Player.paint_cat(ci, Vector2(w / 2.0, cy), 190.0, 0.0, true, false,
				GameState.cat_skin(id, tier))
		UiKit.text(ci, tr("CHAR_UNLOCK_HINT"), Vector2(w / 2.0, cy + 160.0), 17,
				UiKit.MUTED, false, 1, w - 40.0)
		return
	for i in 2:
		var at := Vector2(w * (0.3 if i == 0 else 0.7), cy)
		Player.paint_cat(ci, at, 150.0, 0.0, true, false,
				GameState.cat_skin(id, tier - 1 + i))
	var mid := Vector2(w * 0.5, cy)
	ci.draw_colored_polygon(PackedVector2Array([
			mid + Vector2(-14.0, -18.0), mid + Vector2(12.0, 0.0),
			mid + Vector2(-14.0, 18.0)]), Color(TEXT, 0.45))
	var gains: Array[String] = GameState.CustomCat.tier_gain_names(
			str(cat.get("char", "")), tier - 1)
	var line := tr("CHAR_REWARD_PARTS").format({"n": tier})
	if not gains.is_empty():
		var names: Array[String] = []
		for key in gains:
			names.append(tr(key))
		line = tr("CHAR_UNLOCK_PARTS_GAIN").format({"parts": " · ".join(names)})
	UiKit.text(ci, line, Vector2(w / 2.0, cy + 130.0), 20, TEXT, true, 1, w - 20.0)
	UiKit.text(ci, tr("CHAR_UNLOCK_PARTS_HINT"), Vector2(w / 2.0, cy + 162.0), 17,
			UiKit.MUTED, false, 1, w - 40.0)


func _process(delta: float) -> void:
	_sync_hud()
	if _gacha == null or not _gacha.visible:
		return
	_spin_t += delta
	if _pull_anim:
		for m: Control in _gacha_machines:
			m.queue_redraw()
	if not _pull_anim:
		return
	_pull_t += delta
	_gacha_tray.queue_redraw()
	if _pull_t > _gacha_pull_len():
		_pull_anim = false
		for m: Control in _gacha_machines:
			m.queue_redraw()
		_flush_unlocks()


func _gacha_sold_out(mode: int) -> bool:
	if mode == GameState.GACHA_PICK:
		return GameState.gacha_capacity(GameState.GACHA_RANDOM) <= 0
	if mode == GameState.GACHA_CAN and GameState.gacha_can_pick == "":
		return GameState.unique_cats().all(
				func(cat: Dictionary) -> bool:
					return not GameState.can_pick_gacha(str(cat.id)))
	return GameState.gacha_capacity(mode) <= 0


func _gacha_cap(mode: int) -> int:
	return clampi(GameState.gacha_capacity(mode), 1,
			GameState.KEYCAP_GACHA_MAX)


func _refresh_gacha() -> void:
	GameState.prune_gacha_pick()
	for c: Dictionary in _gacha_cols:
		var mode: int = c.mode
		_gacha_n[mode] = clampi(_gacha_n[mode], 1, _gacha_cap(mode))
		(c.count as Label).text = str(_gacha_n[mode])
		var sold_out := _gacha_sold_out(mode)
		var draw_b: Button = c.draw
		draw_b.disabled = sold_out
		_style_draw_btn(draw_b, sold_out)
		for b: Button in c.steps:
			b.disabled = sold_out
			if b.get_child_count() > 0:
				(b.get_child(0) as Control).queue_redraw()
		(c.face as Control).queue_redraw()
		(c.panel as Control).queue_redraw()
		(c.machine as Control).queue_redraw()
		for ch in (c.panel.get_parent() as Control).get_children():
			if ch is Control:
				(ch as Control).queue_redraw()
	for ui: Control in [_gacha_pick_ui, _gacha_can_ui]:
		if ui != null and ui.has_meta("picked"):
			(ui.get_meta("picked") as Control).queue_redraw()
	for id: String in _gacha_chips:
		_style_gacha_chip(_gacha_chips[id])
	for id: String in _gacha_can_chips:
		_style_gacha_chip(_gacha_can_chips[id])


func _style_gacha_chip(b: Button) -> void:
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	(b.get_child(0) as Control).queue_redraw()


func _open_gacha() -> void:
	if _splash:
		_set_splash(false)
	_raise(_gacha)
	_refresh_gacha()
	_gacha.visible = true


func _close_gacha() -> void:
	_gacha.visible = false
	_gacha_pick_ui.visible = false
	_gacha_result.visible = false
	_unlock_pop.visible = false
	_unlock_queue.clear()
	_pull_anim = false
	queue_redraw()


# --- Keycap dex (alphabet collection) --------------------------------------------


## 키캡 도감 팝업 — 캐릭터 탭 + 자판 한 장.
func _build_keycap_dex() -> void:
	var pw := minf(vw - 60.0, 1000.0)
	var key := (pw - 80.0 - KEY_GAP * 9.0) / 10.0
	var plate_h := key * 3.0 + KEY_GAP * 2.0 + 44.0
	var ph := minf(vh - 100.0, plate_h + 380.0)
	_keycap_dex = _make_overlay(tr("KEYCAP_TITLE"),
			func() -> void: _keycap_dex.visible = false, Vector2(pw, ph))
	var body: Control = _keycap_dex.get_meta("body")
	var v := VBoxContainer.new()
	v.position = Vector2.ZERO
	v.size = body.size
	v.add_theme_constant_override("separation", 10)
	body.add_child(v)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	var dex_cats := GameState.keycap_cats()
	for cat: Dictionary in dex_cats:
		var id := str(cat.id)
		var tab := Button.new()
		tab.custom_minimum_size = Vector2(
				(body.size.x - 6.0 * (dex_cats.size() - 1)) / dex_cats.size(), 46.0)
		tab.pressed.connect(func() -> void:
			Sfx.play("click")
			_keycap_cat = id
			_refresh_keycap_dex())
		tabs.add_child(tab)
		_keycap_tabs[id] = tab
	_keycap_stats = Label.new()
	_keycap_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.label(_keycap_stats, 22, GOLD_COL, true)
	v.add_child(_keycap_stats)
	_keycap_board = Control.new()
	_keycap_board.custom_minimum_size = Vector2(body.size.x, plate_h)
	_keycap_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_keycap_board.draw.connect(func() -> void: _draw_keycap_plate(_keycap_board,
			Rect2(Vector2.ZERO, _keycap_board.size), _keycap_cat))
	v.add_child(_keycap_board)
	var hint := Label.new()
	hint.text = tr("KEYCAP_HINT")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.label(hint, 18, UiKit.MUTED)
	v.add_child(hint)
	var close := Button.new()
	close.text = tr("SET_CLOSE")
	close.custom_minimum_size = Vector2(250.0, 68.0)
	UiKit.btn_card(close, UiKit.GRAY_DEEP, 26)
	close.pressed.connect(func() -> void: _keycap_dex.visible = false)
	var wrap := CenterContainer.new()
	wrap.add_child(close)
	v.add_child(wrap)


func _open_keycap_dex(cat_id := "") -> void:
	if cat_id != "" and not GameState.is_custom_cat(cat_id):
		_keycap_cat = cat_id
	_raise(_keycap_dex)
	_refresh_keycap_dex()
	_keycap_dex.visible = true


func _refresh_keycap_dex() -> void:
	for id: String in _keycap_tabs:
		var tab: Button = _keycap_tabs[id]
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


## 자판: 회색 판 위 QWERTY 세 줄. 모은 글자는 그 냥이 키캡, 나머지는 회색 소켓.
## 캐릭터 페이지의 도감 판과 도감 팝업이 같은 판을 그린다.
func _draw_keycap_plate(ci: Control, plate: Rect2, cat_id: String,
		with_bg := true, top_pad := 22.0) -> void:
	var key := (plate.size.x - 40.0 - KEY_GAP * 9.0) / 10.0
	if with_bg:
		UiKit.round_rect(ci, plate, UiKit.PANEL, 16)
	var f := UiKit.font()
	for r in KEY_ROWS.size():
		var letters := KEY_ROWS[r]
		var row_w := letters.length() * key + (letters.length() - 1) * KEY_GAP
		var x := plate.position.x + (plate.size.x - row_w) / 2.0
		var y := plate.position.y + top_pad + r * (key + KEY_GAP)
		for i in letters.length():
			var letter := letters[i]
			var rect := Rect2(x + i * (key + KEY_GAP), y, key, key)
			var count := GameState.keycap_count(cat_id, letter)
			if GameState.has_keycap(cat_id, letter):
				EscapeBoard.paint_keycap(ci, rect, letter, 0.6, false, cat_id)
				if count > 1:
					var badge := rect.position + Vector2(key - 12.0, key - 8.0)
					ci.draw_circle(badge + Vector2(0.0, -6.0), 13.0, UiKit.RED)
					var txt := "×%d" % count if count < 100 else "99+"
					UiKit.text(ci, txt, badge + Vector2(0.0, 0.0), 13, Color.WHITE, true, 1)
			else:
				UiKit.round_rect(ci, rect, UiKit.PANEL_LINE, int(key * 0.18))
				var fs := int(key * 0.42)
				UiKit.text(ci, letter.to_lower(), rect.get_center() + Vector2(0.0, fs * 0.36),
						fs, Color(TEXT, 0.3), false, 1)


# --- [개발용 · 출시 빌드에서 제거] 업적/리더보드 확인 패널 -----------------------


func _build_dev_panel() -> void:
	if not DEV_PANEL.ENABLED:
		return
	_dev = DEV_PANEL.new()
	$UI.add_child(_dev)
	var b := Button.new()
	b.text = "DEV"
	b.size = Vector2(120.0, 44.0)
	b.position = Vector2(24.0, vh - 60.0)
	UiKit.btn_card(b, UiKit.PURPLE_DEEP, 17)
	b.pressed.connect(func() -> void:
		Sfx.play("click")
		_dev.open())
	$UI.add_child(b)
	_menu_nodes.append(b)


# --- 랭킹 (피그마 "랭킹" 팝업) --------------------------------------------------------


## 제목 · [주간랭킹 | 누적랭킹] 탭 · 색 프레임 안에 [스테이지 모드 | 무한의 계단] +
## 흰 목록(메달 1~3위 · 이름 · STAGE n · 점수) · 왼쪽 "내 랭킹" 말풍선 · 닫기.
func _build_ranks() -> void:
	_ranks = _make_overlay(tr("RANK_TITLE"), func() -> void: _ranks.visible = false,
			Vector2(minf(vw - 60.0, 1000.0), minf(vh - 100.0, 874.0)), false,
			UiKit.DIM_SOFT)
	var body: Control = _ranks.get_meta("body")
	var bw := body.size.x
	var bh := body.size.y
	# 범위 탭 둘.
	var tab_w := (bw - 8.0) / 2.0
	for entry: Array in [[true, tr("RANK_WEEKLY"), 0.0], [false, tr("RANK_ALLTIME"), tab_w + 8.0]]:
		var sb_btn := Button.new()
		sb_btn.text = str(entry[1])
		sb_btn.position = Vector2(float(entry[2]), 0.0)
		sb_btn.size = Vector2(tab_w, 60.0)
		sb_btn.pressed.connect(func() -> void:
			Sfx.play("click")
			_rank_weekly = entry[0]
			_refresh_rank_list()
			Ranks.view(_rank_mode, _rank_weekly))
		body.add_child(sb_btn)
		_rank_scopes[entry[0]] = sb_btn
	# 색 프레임 — 탭 아래 붙어서 목록을 감싼다.
	_rank_frame = Control.new()
	_rank_frame.position = Vector2(0.0, 57.0)
	_rank_frame.size = Vector2(bw, bh - 57.0 - 86.0)
	_rank_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rank_frame.draw.connect(func() -> void:
		var f := _rank_frame
		var col := UiKit.YELLOW if _rank_weekly else UiKit.RANK_BLUE
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.corner_radius_bottom_left = 16
		sb.corner_radius_bottom_right = 16
		f.draw_style_box(sb, Rect2(Vector2.ZERO, f.size))
		UiKit.round_rect(f, Rect2(19.0, 84.0, f.size.x - 38.0, f.size.y - 100.0),
				UiKit.WHITE, 16))
	body.add_child(_rank_frame)
	var mode_w := (bw - 38.0 - 8.0) / 2.0
	for entry: Array in [["classic", tr("MODE_CLASSIC"), 0.0],
			["endless", tr("MODE_ENDLESS"), mode_w + 8.0]]:
		var b := Button.new()
		b.text = str(entry[1])
		b.position = Vector2(19.0 + float(entry[2]), 16.0)
		b.size = Vector2(mode_w, 60.0)
		b.pressed.connect(_on_rank_tab.bind(str(entry[0])))
		_rank_frame.add_child(b)
		_rank_tabs[entry[0]] = b
	_rank_sub = Label.new()
	_rank_sub.position = Vector2(19.0, 88.0)
	_rank_sub.size = Vector2(bw - 38.0, 22.0)
	_rank_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.label(_rank_sub, 14, UiKit.MUTED)
	_rank_frame.add_child(_rank_sub)
	_rank_status = Label.new()
	_rank_status.position = Vector2(19.0, 108.0)
	_rank_status.size = Vector2(bw - 38.0, 22.0)
	_rank_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.label(_rank_status, 14, UiKit.MUTED)
	_rank_frame.add_child(_rank_status)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(50.0, 132.0)
	scroll.size = Vector2(bw - 100.0, _rank_frame.size.y - 132.0 - 20.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rank_frame.add_child(scroll)
	_rank_list = VBoxContainer.new()
	_rank_list.add_theme_constant_override("separation", 10)
	_rank_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rank_list)
	# 내 랭킹 말풍선 — 프레임 왼쪽 바깥.
	_rank_bubble = Control.new()
	_rank_bubble.position = Vector2(-62.0, bh * 0.66)
	_rank_bubble.size = Vector2(124.0, 96.0)
	_rank_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rank_bubble.draw.connect(_draw_rank_bubble)
	body.add_child(_rank_bubble)
	var close := Button.new()
	close.text = tr("SET_CLOSE")
	close.size = Vector2(250.0, 68.0)
	close.position = Vector2((bw - 250.0) / 2.0, bh - 74.0)
	UiKit.btn_card(close, UiKit.GRAY_DEEP, 26)
	close.pressed.connect(func() -> void: _ranks.visible = false)
	body.add_child(close)
	_replay_viewer = preload("res://core/scripts/replay_viewer.gd").new()
	$UI.add_child(_replay_viewer)


## 왼쪽 말풍선: "내 랭킹" + 순위 (없으면 -).
func _draw_rank_bubble(ci: Control = null) -> void:
	ci = _rank_bubble
	var r := Rect2(0.0, 0.0, ci.size.x, 74.0)
	UiKit.round_rect_outline(ci, r, UiKit.WHITE, 18, 3, TEXT)
	var tip := PackedVector2Array([Vector2(r.size.x * 0.72, r.end.y - 3.0),
			Vector2(r.size.x * 0.95, r.end.y + 22.0), Vector2(r.size.x * 0.98, r.end.y - 3.0)])
	ci.draw_colored_polygon(tip, UiKit.WHITE)
	ci.draw_polyline(PackedVector2Array([tip[0], tip[1], tip[2]]), TEXT, 3.0)
	UiKit.text(ci, tr("RANK_MINE"), Vector2(r.size.x / 2.0, 26.0), 13, TEXT, false, 1)
	var rank := Ranks.my_rank(_rank_mode, _rank_weekly)
	UiKit.text(ci, str(rank) if rank > 0 else "-", Vector2(r.size.x / 2.0, 58.0), 28,
			TEXT, true, 1)


func _open_ranks() -> void:
	if _splash:
		_set_splash(false)
	_raise(_ranks)
	_ranks.visible = true
	_refresh_rank_list()
	Ranks.view(_rank_mode, _rank_weekly)


func _on_rank_tab(mode_key: String) -> void:
	Sfx.play("click")
	_rank_mode = mode_key
	_refresh_rank_list()
	Ranks.view(_rank_mode, _rank_weekly)


func _refresh_rank_list() -> void:
	for tab_key: String in _rank_tabs:
		_style_rank_mode(_rank_tabs[tab_key], tab_key == _rank_mode)
	for scope_key: bool in _rank_scopes:
		UiKit.btn_tab(_rank_scopes[scope_key], scope_key == _rank_weekly,
				UiKit.YELLOW if scope_key else UiKit.RANK_BLUE_TAB, 24)
	_rank_frame.queue_redraw()
	_rank_bubble.queue_redraw()
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
		_rank_list.add_child(_rank_row(i + 1, str(e.get("name", "???")),
				int(e.get("v", 0)), str(e.get("id")) == mine,
				{} if _rank_weekly else e))


## 모드 버튼 — 켜진 쪽은 진노랑 + ↪ 표시, 꺼진 쪽은 흰색.
func _style_rank_mode(b: Button, active: bool) -> void:
	if active:
		UiKit.style_button(b, Color("ffcd03"), Color("ffcd03"), TEXT, 22, 14, true, 3)
	else:
		UiKit.style_button(b, UiKit.WHITE, UiKit.WHITE, TEXT, 22, 14, true, 3)
	b.add_theme_constant_override("outline_size", 0)
	for st in ["normal", "hover", "pressed"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(st).duplicate()
		sb.shadow_size = 0
		sb.content_margin_bottom = 0.0
		b.add_theme_stylebox_override(st, sb)


## 랭킹 한 줄 — 1~3위는 메달 그림, 그 밖은 번호 원. 이름 · STAGE n · 점수.
func _rank_row(rank: int, name_text: String, v: int, mine: bool,
		entry: Dictionary = {}) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(0.0, 80.0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mode_key := _rank_mode
	row.draw.connect(func() -> void:
		var w := row.size.x
		var bg := Color("fff9ef")
		if rank == 1:
			bg = Color("fff860")
		elif rank == 2:
			bg = Color("e8e8e8")
		elif rank == 3:
			bg = Color("f3c988")
		UiKit.round_rect_outline(row, Rect2(0.0, 0.0, w, 80.0), bg, 16, 3,
				UiKit.GOLD_DEEP if mine else TEXT)
		# 오른쪽 절반은 살짝 더 진한 띠 (피그마 사선 느낌).
		row.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.55, 3.0),
				Vector2(w - 12.0, 3.0), Vector2(w - 12.0, 77.0), Vector2(w * 0.45, 77.0)]),
				Color(0, 0, 0, 0.05))
		if rank >= 1 and rank <= 3:
			UiKit.draw_tex(row, "medal%d.png" % rank, Rect2(6.0, -12.0, 108.0, 100.0))
		elif rank > 0:
			row.draw_circle(Vector2(56.0, 40.0), 27.0, UiKit.WHITE)
			row.draw_arc(Vector2(56.0, 40.0), 27.0, 0.0, TAU, 40, Color(TEXT, 0.15), 2.0)
			UiKit.text(row, str(rank), Vector2(56.0, 50.0), 24 if rank < 1000 else 18,
					TEXT, false, 1)
		var nm := name_text + (tr("RANK_ME_MARK") if mine and rank > 0 else "")
		UiKit.text(row, nm, Vector2(127.0, 51.0), 24, TEXT, true, 0, w * 0.38)
		if v >= 0:
			var vt := Ranks.value_text(mode_key, v)
			var vw_ := UiKit.text(row, vt, Vector2(w - 28.0, 52.0), 28, TEXT, true, 2)
			if mode_key == "classic" and not entry.is_empty():
				var st := int(entry.get("stage", 0))
				if st > 0:
					var sw := UiKit.text(row, str(st), Vector2(w - 28.0 - vw_ - 18.0, 52.0),
							28, TEXT, false, 2)
					UiKit.text(row, tr("RANK_STAGE"), Vector2(w - 28.0 - vw_ - 18.0 - sw - 8.0,
							50.0), 20, Color(TEXT, 0.6), false, 2))
	if not entry.is_empty() and Ranks.has_replay_for(_rank_mode, entry):
		var play := Button.new()
		play.text = "▶"
		play.size = Vector2(56.0, 44.0)
		UiKit.btn_card(play, UiKit.BLUE_DEEP, 16)
		# 줄 폭은 VBox가 나중에 정한다 — 그때 값 왼쪽에 붙인다.
		row.resized.connect(func() -> void:
			play.position = Vector2(row.size.x * 0.5 - 28.0, 18.0))
		play.pressed.connect(func() -> void:
			Sfx.play("click")
			var rep: Dictionary = await Ranks.replay_for(mode_key, entry)
			if rep.is_empty():
				_show_toast(tr("RANK_REPLAY_FAIL"), Color(1.0, 0.55, 0.5))
				return
			Achv.unlock(Achv.REPLAY_WATCH)
			_replay_viewer.open(rep, "%s  ·  %s" % [name_text,
					Ranks.value_text(mode_key, v)]))
		row.add_child(play)
	return row


# --- 닉네임 변경 팝업 (피그마 "닉네임 변경") ------------------------------------------


func _build_nick_pop() -> void:
	_nick_pop = _make_overlay(tr("NICK_TITLE"), func() -> void: _nick_pop.visible = false,
			Vector2(800.0, 373.0))  # 피그마 800×373
	var body: Control = _nick_pop.get_meta("body")
	var rule := Label.new()
	rule.text = tr("NICK_RULE")
	rule.position = Vector2(0.0, -14.0)
	rule.size = Vector2(body.size.x, 30.0)
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.label(rule, 20, TEXT)
	body.add_child(rule)
	_nick_edit = LineEdit.new()
	_nick_edit.position = Vector2(0.0, 45.0)
	_nick_edit.size = Vector2(body.size.x, 70.0)
	for st: String in ["normal", "focus", "read_only"]:
		var sb := StyleBoxFlat.new()  # 피그마 입력칸: 흰 바탕 · 테 2 #d6d6d6 · 모서리 10
		sb.bg_color = UiKit.WHITE
		sb.set_border_width_all(2)
		sb.border_color = Color("d6d6d6") if st != "focus" else Color("a8a8a8")
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 20.0
		sb.content_margin_right = 20.0
		_nick_edit.add_theme_stylebox_override(st, sb)
	_nick_edit.add_theme_color_override("font_color", UiKit.BTN_TEXT)
	_nick_edit.add_theme_color_override("font_placeholder_color", Color("b5b5b5"))
	_nick_edit.add_theme_color_override("caret_color", UiKit.BTN_TEXT)
	_nick_edit.max_length = 12
	_nick_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nick_edit.placeholder_text = tr("NICK_PLACEHOLDER")
	_nick_edit.add_theme_font_size_override("font_size", 22)
	body.add_child(_nick_edit)
	_nick_hint = Label.new()
	_nick_hint.position = Vector2(0.0, 45.0)
	_nick_hint.size = Vector2(body.size.x, 70.0)
	_nick_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nick_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_nick_hint.visible = false
	UiKit.label(_nick_hint, 18, UiKit.MUTED)
	body.add_child(_nick_hint)
	var cancel := Button.new()
	cancel.text = tr("UI_CANCEL")
	cancel.size = Vector2(250.0, 71.0)
	cancel.position = Vector2(body.size.x / 2.0 - 250.0 - 10.0, 145.0)
	UiKit.btn_normal(cancel, 30)
	cancel.pressed.connect(func() -> void:
		Sfx.play("click")
		_nick_pop.visible = false)
	body.add_child(cancel)
	_nick_save = Button.new()
	_nick_save.text = tr("NICK_CHANGE")
	_nick_save.size = Vector2(250.0, 71.0)
	_nick_save.position = Vector2(body.size.x / 2.0 + 10.0, 145.0)
	UiKit.btn_primary(_nick_save, 30)
	_nick_save.pressed.connect(func() -> void:
		Sfx.play("click")
		GameState.set_nickname(_nick_edit.text)
		_nick_edit.text = GameState.display_name()
		_show_toast(tr("RANK_RENAMED").format({"name": GameState.display_name()}), CREAM)
		_refresh_currency()
		_nick_pop.visible = false
		if _ranks.visible:
			_refresh_rank_list())
	body.add_child(_nick_save)


## ⚙ — 스팀 페르소나가 있으면 그 이름을 잠근 채 안내만 보여 준다.
func _open_nick_pop() -> void:
	var account := Platform.user_name().strip_edges()
	_nick_edit.text = GameState.display_name()
	_nick_edit.visible = account == ""
	_nick_save.visible = account == ""
	_nick_hint.visible = account != ""
	_nick_hint.text = tr("RANK_NAME_ACCOUNT")
	_raise(_nick_pop)
	_nick_pop.visible = true
	if account == "":
		_nick_edit.grab_focus()


# --- 캐릭터 페이지 (피그마 "캐릭터 선택") ------------------------------------------------


## 캐릭터 페이지 (피그마 "캐릭터 선택" 74:5728 · 나만의 냥이 119:2921).
## 헤더 줄(유저 HUD · 뒤로가기) 아래 탭 두 장(887×60, 간격 8, 좌우 20 들여) + 흰 본문
## 1822×792. 본문 왼쪽 910 = 상세(탭 0) / 나만의 냥이 프리뷰(탭 1), 오른쪽 = 격자 / 꾸미기.
## 자리 배정은 메뉴의 "캐릭터 변경하기"로 열었을 때만(_pick_seat).
func _build_character_page() -> void:
	_chars = _make_page(func() -> void: _close_chars())
	var head := Label.new()  # 예전 API 호환 (테스트가 head 메타를 읽는다)
	head.text = tr("CHAR_SELECT")
	head.visible = false
	_chars.add_child(head)
	_chars.set_meta("head", head)
	var body_r := _char_body_rect()
	var tab_y := body_r.position.y - CHAR_TAB_H
	var tab_w := (body_r.size.x - 40.0 - CHAR_TAB_GAP) / 2.0
	for i in 2:
		var t := Button.new()
		t.text = tr("CHAR_TAB_NORMAL") if i == 0 else tr("CHAR_TAB_MINE")
		t.position = Vector2(body_r.position.x + 20.0 + i * (tab_w + CHAR_TAB_GAP), tab_y)
		t.size = Vector2(tab_w, CHAR_TAB_H)
		t.pressed.connect(func() -> void:
			Sfx.play("click")
			_set_char_tab(i))
		_chars.add_child(t)
		_char_tabs.append(t)
	_char_body = Control.new()
	_char_body.position = body_r.position
	_char_body.size = body_r.size
	_char_body.draw.connect(func() -> void:
		UiKit.round_rect(_char_body, Rect2(Vector2.ZERO, _char_body.size), UiKit.WHITE, 20)
		# 왼쪽·오른쪽 칸 사이 구분선 (가로 화면).
		if vw >= vh:
			var x := _char_left_rect().size.x
			_char_body.draw_line(Vector2(x, 20.0), Vector2(x, _char_body.size.y - 20.0),
					Color("e6e6e6"), 2.0))
	_chars.add_child(_char_body)
	var left_rect := _char_left_rect()
	var grid_rect := _char_grid_rect()
	_char_left = Control.new()
	_char_left.position = left_rect.position
	_char_left.size = left_rect.size
	_char_left.draw.connect(func() -> void: _draw_char_detail(_char_left))
	_char_body.add_child(_char_left)
	# 대표 캐릭터 설정/해제 — 노란 btn(얼굴 53 + 두께 7), 상세 줄 오른쪽 위 (x 40+631).
	_char_star = Button.new()
	_char_star.size = Vector2(left_rect.size.x - CHAR_PAD - 671.0, 53.0)
	_char_star.position = Vector2(671.0, CHAR_PAD)
	_char_star.pressed.connect(func() -> void:
		Sfx.play("click")
		if GameState.feature_cat == _char_view:
			GameState.set_feature_cat("")
			_refresh_currency()
			_refresh_char_page()
		else:
			_open_feature_ask())
	_char_left.add_child(_char_star)
	# 탭 1의 "캐릭터 선택" (피그마 btn 205×56: 얼굴 53 + 얇은 두께 3).
	_char_pick_btn = Button.new()
	_char_pick_btn.text = tr("CHAR_MINE_PICK")
	_char_pick_btn.size = Vector2(205.0, 53.0)
	_char_pick_btn.position = Vector2(left_rect.size.x - 40.0 - 205.0, 40.0)
	UiKit.style_button(_char_pick_btn, UiKit.WHITE, Color("e9e9e9"), UiKit.BTN_TEXT, 24, 11,
			true, 3, 3)
	_char_pick_btn.pressed.connect(func() -> void:
		if GameState.is_unlocked(_char_view):
			_assign_pick(_char_view)
		else:
			Sfx.play("error"))
	_char_left.add_child(_char_pick_btn)
	# 꾸미기 패널 — 탭 1의 오른쪽 자리.
	_customizer = CAT_CUSTOMIZER.new()
	_char_body.add_child(_customizer)
	_customizer.saved.connect(func() -> void:
		_show_toast(tr("CC_SAVED"), GOLD_COL))
	_char_grid_card = Control.new()
	_char_grid_card.position = grid_rect.position
	_char_grid_card.size = grid_rect.size
	_char_grid_card.draw.connect(func() -> void:
		_draw_char_grid_card(_char_grid_card))
	_char_body.add_child(_char_grid_card)
	var tile := _char_tile_size()
	_char_scroll = ScrollContainer.new()
	_char_scroll.position = Vector2(CHAR_RIGHT_PAD, CHAR_RIGHT_PAD)
	_char_scroll.size = grid_rect.size - Vector2(CHAR_RIGHT_PAD, CHAR_RIGHT_PAD) * 2.0
	_char_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_style_scroll(_char_scroll)
	_char_grid_card.add_child(_char_scroll)
	_char_grid = GridContainer.new()
	_char_grid.columns = _char_grid_cols()
	_char_grid.add_theme_constant_override("h_separation", int(TILE_GAP))
	_char_grid.add_theme_constant_override("v_separation", int(TILE_GAP))
	_char_scroll.add_child(_char_grid)
	# 커스텀 슬롯 줄 — 탭 1 왼쪽 아래 (피그마: 간격 16, 좌우 20 + 칸 여백 20).
	_char_slots = HBoxContainer.new()
	_char_slots.add_theme_constant_override("separation", 16)
	_char_slots.position = Vector2(40.0, left_rect.size.y - 20.0 - tile.y)
	_char_slots.size = Vector2(left_rect.size.x - 80.0, tile.y)
	_char_left.add_child(_char_slots)
	_build_char_tiles()
	_layout_char_body()
	_build_feature_ask()


## 피그마 scroll 컴포넌트: 흰 트랙(모서리 999, 안쪽 3) + 회색 손잡이(#828282, 폭 12, 검은 테 1).
func _style_scroll(sc: ScrollContainer) -> void:
	var bar := sc.get_v_scroll_bar()
	var track := StyleBoxFlat.new()
	track.bg_color = Color("f1f1f1")
	track.set_corner_radius_all(99)
	track.content_margin_left = 3.0
	track.content_margin_right = 3.0
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color("828282")
	grab.set_corner_radius_all(99)
	grab.set_border_width_all(1)
	grab.border_color = Color.BLACK
	grab.content_margin_left = 6.0
	grab.content_margin_right = 6.0
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("grabber", grab)
	bar.add_theme_stylebox_override("grabber_highlight", grab)
	bar.add_theme_stylebox_override("grabber_pressed", grab)
	bar.custom_minimum_size.x = 18.0


# --- 페이지 자리 계산 (가로·세로 화면을 한 코드로) ------------------------------------


func _page_drop() -> float:
	return PAGE_HUD_DROP if vh > vw else 0.0


## 흰 본문 자리 (탭 아래) — 피그마 1822×792, 화면 가운데.
func _char_body_rect() -> Rect2:
	var top := PAGE_HEAD_H + _page_drop() + CHAR_TAB_H
	var w := minf(CHAR_BODY_W, vw - 40.0)
	return Rect2(Vector2((vw - w) / 2.0, top), Vector2(w, vh - top - 40.0))


## 본문 안 왼쪽(가로) / 위(세로) 칸 — 본문 로컬 좌표.
func _char_left_rect() -> Rect2:
	var b := _char_body_rect()
	if vh > vw:
		return Rect2(Vector2.ZERO, Vector2(b.size.x, b.size.y * CHAR_LEFT_RATIO_V))
	return Rect2(Vector2.ZERO, Vector2(CHAR_LEFT_W * b.size.x / CHAR_BODY_W, b.size.y))


func _char_grid_rect() -> Rect2:
	var b := _char_body_rect()
	var l := _char_left_rect()
	if vh > vw:
		return Rect2(Vector2(0.0, l.size.y), Vector2(b.size.x, b.size.y - l.size.y))
	return Rect2(Vector2(l.size.x, 0.0), Vector2(b.size.x - l.size.x, b.size.y))


func _char_grid_cols() -> int:
	return maxi(1, mini(CHAR_GRID_COLS, max_tiles_per_row))


## 격자 칸 크기 — 피그마 195×190 (세로 화면은 폭에 맞춰 줄인다).
func _char_tile_size() -> Vector2:
	var cols := _char_grid_cols()
	var inner := _char_grid_rect().size.x - CHAR_RIGHT_PAD * 2.0 - 32.0
	var w := minf(TILE_SIZE.x, (inner - TILE_GAP * (cols - 1)) / cols)
	return Vector2(w, TILE_SIZE.y)


## 타일 다시 깔기 — 디자인 냥이는 격자(탭 0), 커스텀 슬롯은 탭 1의 줄.
func _build_char_tiles() -> void:
	for box: Control in [_char_grid, _char_slots]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	_tiles.clear()
	var tile := _char_tile_size()
	var slot := tile
	for cat: Dictionary in GameState.all_cats():
		if GameState.is_custom_cat(str(cat.id)):
			var b := _make_tile(cat, slot)
			_char_slots.add_child(b)
			_tiles[cat.id] = b
		else:
			var b := _make_tile(cat, tile)
			_char_grid.add_child(b)
			_tiles[cat.id] = b
	if GameState.can_add_custom_slot():
		_char_slots.add_child(_make_add_tile(slot))


## "+" 타일 — 나만의 캐릭터를 담을 빈 슬롯을 하나 더 연다.
func _make_add_tile(tile := TILE_SIZE) -> Button:
	var b := Button.new()
	b.custom_minimum_size = tile
	b.size = tile
	b.text = "+"
	UiKit.style_button(b, Color("e0e0e0"), Color("e0e0e0"), Color(TEXT, 0.45), 54, 16, true, 0)
	b.add_theme_constant_override("outline_size", 0)
	for st in ["normal", "hover", "pressed"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(st).duplicate()
		sb.shadow_size = 0
		sb.content_margin_bottom = 0.0
		b.add_theme_stylebox_override(st, sb)
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


## 캐릭터 페이지는 두 가지로 열린다:
##   seat false — 둘러보기 (도감·성장·꾸미기. 자리는 안 건드린다)
##   seat true — 메뉴의 "캐릭터 변경하기" (좌석에 앉힐 냥이를 고른다)
func _open_chars(seat := false) -> void:
	if _splash:
		_set_splash(false)
	_pick_seat = seat
	_char_view = _first_unlocked(GameState.selected_cat)
	_refresh_chars_head()
	_raise(_chars)
	_refresh_char_page()
	_chars.visible = true


func _refresh_chars_head() -> void:
	var head: Label = _chars.get_meta("head")
	head.text = tr("CHAR_SELECT")


func _close_chars() -> void:
	_chars.visible = false
	_pick_seat = false
	_refresh_seats()


func _first_unlocked(id: String) -> String:
	if GameState.is_unlocked(id):
		return id
	for cat in GameState.all_cats():
		if GameState.is_unlocked(cat.id):
			return str(cat.id)
	return "cream"


## 탭 전환 — 탭 1로 가면 첫 커스텀 슬롯을, 탭 0으로 가면 좌석 냥이(또는 첫 냥이)를 펼친다.
func _set_char_tab(i: int) -> void:
	if i == 1:
		if not GameState.is_custom_cat(_char_view):
			_char_view = GameState.custom_slot_id(1)
	elif GameState.is_custom_cat(_char_view):
		_char_view = _first_unlocked(GameState.selected_cat)
		if GameState.is_custom_cat(_char_view):
			_char_view = "cream"
	_refresh_char_page()


## 탭에 따라 어느 카드가 보이는지 — 탭 1은 오른쪽이 꾸미기 패널.
func _layout_char_body() -> void:
	var custom := GameState.is_custom_cat(_char_view)
	_char_tab = 1 if custom else 0
	_customizer.visible = custom
	_char_grid_card.visible = not custom
	_char_slots.visible = custom
	_char_pick_btn.visible = custom
	if custom:
		var g := _char_grid_rect()
		_customizer.set_area(Rect2(g.position + Vector2(CHAR_RIGHT_PAD, CHAR_RIGHT_PAD),
				g.size - Vector2(CHAR_RIGHT_PAD, CHAR_RIGHT_PAD) * 2.0))
	for i in _char_tabs.size():
		UiKit.btn_tab(_char_tabs[i], i == _char_tab,
				UiKit.YELLOW if i == 0 else UiKit.RED_TAB, 30)


func _refresh_char_page() -> void:
	if _chars == null:
		return
	_layout_char_body()
	var unlocked := GameState.is_unlocked(_char_view)
	var custom := GameState.is_custom_cat(_char_view)
	_char_star.visible = unlocked and not custom
	# 버튼은 **명시적으로** 대표로 찍어 둔 냥이에게만 "해제"다 (featured_cat()은
	# 비어 있으면 좌석 냥이를 돌려주므로 그걸로 판단하면 해제가 안 먹는다).
	var featured := GameState.feature_cat == _char_view
	_char_star.text = tr("CHAR_FEATURE_OFF") if featured else tr("CHAR_FEATURE_SET_BTN")
	UiKit.btn_yellow(_char_star, 24)
	_customizer_on = custom
	if _customizer_on:
		_customizer.open(_char_view)
	_refresh_tiles()
	_char_body.queue_redraw()
	_char_left.queue_redraw()
	_char_grid_card.queue_redraw()


## 타일에서 고른 냥이를 좌석에 앉힌다 (즉시 저장).
func _assign_pick(cat_id: String) -> void:
	Sfx.play("buy")
	GameState.select_cat(cat_id)
	_refresh_currency()
	_refresh_char_page()
	_refresh_seats()


func _make_tile(cat: Dictionary, tile := TILE_SIZE) -> Button:
	var b := Button.new()
	b.custom_minimum_size = tile
	b.size = tile
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void: _on_tile_pressed(cat))
	var face := Control.new()
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.draw.connect(func() -> void: _draw_tile(face, cat))
	b.add_child(face)
	_style_tile(b, cat)
	return b


## 타일 배경은 face가 그린다 — 버튼 스타일은 비운다.
func _style_tile(b: Button, _cat: Dictionary) -> void:
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())


## 격자 타일 (피그마 cat list 195×190, 모서리 10): 펼친 냥이 = 노랑 #ffcd03 + 체크,
## 보통 = #f9f9f9, 잠김 = #e0e0e0 + 회색 실루엣 + 흐린 글자. 위 26px 뱃지 줄 · 냥이 66×80 ·
## 이름 16 · 진행 알약(▦ n/26, 12) · 등급 바 4칸.
func _draw_tile(ci: Control, cat: Dictionary) -> void:
	var ts := ci.size
	var id := str(cat.id)
	var unlocked: bool = GameState.is_unlocked(id)
	var viewing := _chars != null and _chars.visible and id == _char_view
	var custom := GameState.is_custom_cat(id)
	var bg := Color("f9f9f9")
	if viewing:
		bg = Color("ffcd03")
	elif not unlocked:
		bg = Color("e0e0e0")
	UiKit.round_rect(ci, Rect2(Vector2.ZERO, ts), bg, 10)
	if _is_chosen(id) and not viewing:
		UiKit.round_rect_outline(ci, Rect2(Vector2.ZERO, ts).grow(-1.0), Color(0, 0, 0, 0), 10,
				3, Color("dfb302"))
	if viewing:
		UiKit.check_badge(ci, Vector2(ts.x - 6.0 - 13.0, 6.0 + 13.0), 13.0, Color("272727"))
	if GameState.is_unique_cat(id):
		UiKit.can_icon(ci, Vector2(6.0 + 15.0, 6.0 + 13.0), 26.0)
	var ink := Color("272727") if unlocked else Color("9a9a9a")
	var cat_r := Rect2(ts.x / 2.0 - 40.0, 32.0 if not custom else 40.0, 80.0, 80.0)
	var fit := _fit_cat(cat_r)
	Player.paint_cat(ci, fit[1], fit[0], 0.0, true, false,
			GameState.cat_skin(id) if unlocked else GameState.cat_shadow_skin(id))
	var name_y := cat_r.end.y + 4.0 + 16.0
	UiKit.text(ci, tr(str(cat.name)), Vector2(ts.x / 2.0, name_y), 16, ink, true, 1,
			ts.x - 20.0)
	if custom:
		return
	# 진행 알약 — 테 #d6d6d6 · 모서리 4 · ▦ + n/26 (12).
	var prog := "%d/26" % GameState.keycap_ring(id)
	var pw := UiKit.text_width(prog, 12, true) + 14.0 + 4.0 + 8.0
	var pill := Rect2(ts.x / 2.0 - pw / 2.0, name_y + 6.0, pw, 20.0)
	UiKit.round_rect_outline(ci, pill, Color(1, 1, 1, 0.0) if viewing else Color(1, 1, 1, 0.0),
			4, 1, Color("d6d6d6") if not viewing else Color(0, 0, 0, 0.25))
	UiKit.text(ci, "▦", Vector2(pill.position.x + 3.0, pill.end.y - 5.0), 12, ink)
	UiKit.text(ci, prog, Vector2(pill.position.x + 3.0 + 14.0 + 4.0, pill.end.y - 5.0), 12,
			ink, true)
	_draw_grade_pips(ci, id, pill.end.y + 6.0, ts.x, viewing)


## 등급 바 — 4칸(높이 8, 간격 2, 양 끝 둥글게). 채운 칸 #272727, 빈 칸 #d2d2d2
## (노란 타일 위에서는 흰색).
func _draw_grade_pips(ci: Control, id: String, y: float,
		width: float = TILE_SIZE.x, on_yellow := false) -> void:
	var top: int = GameState.KEYCAP_GRADE_MAX
	var grade := GameState.cat_grade(id)
	var pad := 14.0
	var gap := 2.0
	var w := (width - pad * 2.0 - gap * (top - 1)) / top
	for i in top:
		var r := Rect2(pad + i * (w + gap), y, w, 8.0)
		var col := Color("272727") if i < grade else (UiKit.WHITE if on_yellow else Color("d2d2d2"))
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		if i == 0:
			sb.corner_radius_top_left = 4
			sb.corner_radius_bottom_left = 4
		if i == top - 1:
			sb.corner_radius_top_right = 4
			sb.corner_radius_bottom_right = 4
		ci.draw_style_box(sb, r)


## 타일 누르기 = 그 냥이를 펼친다. 자리 몫으로 연 페이지에서만 해금된 냥이를 앉힌다.
func _on_tile_pressed(cat: Dictionary) -> void:
	_char_view = str(cat.id)
	if _pick_seat and GameState.is_unlocked(cat.id):
		_assign_pick(str(cat.id))
	else:
		Sfx.play("click")
		_refresh_char_page()


func _is_chosen(id: String) -> bool:
	return GameState.selected_cat == id


# --- 오른쪽 카드: 캐릭터 격자 ------------------------------------------------------


func _draw_char_grid_card(_ci: Control) -> void:
	pass  # 흰 본문 카드가 배경 — 격자는 타일이 각자 그린다


# --- 왼쪽: 펼친 냥이 (프리뷰 · 키캡 도감 · 보상) / 나만의 냥이 -------------------------


## 왼쪽 상세 (피그마 74:5738, 안쪽 40): 윗줄 = 냥이 160×180 + [이름 40 · 상태 태그] ·
## 소개 22 (오른쪽 위에 노란 대표 버튼) → 키캡 판 → 보상 칸 4개.
func _draw_char_detail(ci: Control) -> void:
	var id := _char_view
	var cat := GameState.get_cat(id)
	var unlocked := GameState.is_unlocked(id)
	var w := ci.size.x
	if GameState.is_custom_cat(id):
		_draw_mine_detail(ci)
		return
	var x0 := CHAR_PAD
	var y0 := CHAR_PAD
	var art := Rect2(x0, y0, 160.0, 180.0)
	var fit := _fit_cat(art)
	Player.paint_cat(ci, fit[1], fit[0], 0.0, true, false,
			GameState.cat_skin(id) if unlocked else GameState.cat_shadow_skin(id))
	var ix := x0 + 160.0 + 30.0
	var iw := w - CHAR_PAD - ix
	# 이름 + 상태 태그 한 줄, 그 아래 소개 — 180 높이 가운데.
	var name_base := y0 + 70.0
	var nm := tr(str(cat.name))
	var nw := UiKit.text(ci, nm, Vector2(ix, name_base), 40, Color("2e1d00"), true, 0,
			iw - 230.0)
	var tag := ""
	if GameState.feature_cat == id:
		tag = tr("CHAR_FEATURE_TAG")
	elif _is_chosen(id):
		tag = tr("CHAR_EQUIPPED")
	elif not unlocked:
		tag = tr("CHAR_REWARD_LOCKED")
	if tag != "":
		UiKit.pill(ci, tag, Vector2(ix + nw + 8.0, name_base - 32.0), 36.0, 18,
				Color("2e1d00"), Color("fff2c1"), true, 20.0, 3, Color("97832a"))
	ci.draw_multiline_string(UiKit.font(), Vector2(ix, name_base + 46.0),
			tr("%s_DESC" % str(cat.name)), HORIZONTAL_ALIGNMENT_LEFT, iw, 22, 3,
			Color.BLACK if unlocked else Color(0, 0, 0, 0.45))
	_draw_char_keycaps(ci, w)
	_draw_char_rewards(ci, w)


## 키캡 판 (피그마 keyboard-chassis-top: #f1f1f1 · 모서리 10 · 위 16 아래 20 좌우 24):
## "보유한 키캡 n / 26"(18) → 키 3줄(52×62, 간격 20 · 줄 간격 10) → "m글자만 모으면
## k단계 획득가능"(18).
func _draw_char_keycaps(ci: Control, w: float) -> void:
	var top := CHAR_PAD + 180.0 + 20.0
	var bottom := ci.size.y - CHAR_PAD - CHAR_REWARD_H - 20.0
	var plate := Rect2(CHAR_PAD, top, w - CHAR_PAD * 2.0, bottom - top)
	UiKit.round_rect(ci, plate, Color("f1f1f1"), 10)
	var ring := GameState.keycap_ring(_char_view)
	var grade := GameState.cat_grade(_char_view)
	var cx := plate.get_center().x
	# 머리줄: 라벨(#525252) + 개수(굵게) + " / 26"(#9e9e9e).
	var label := tr("CHAR_KEYCAP_LABEL")
	var cnt := str(ring)
	var tail := "/  26"
	var tw := UiKit.text_width(label, 18) + 10.0 + UiKit.text_width(cnt, 18, true) + 10.0 \
			+ UiKit.text_width(tail, 18)
	var hx := cx - tw / 2.0
	var hy := plate.position.y + 16.0 + 18.0
	hx += UiKit.text(ci, label, Vector2(hx, hy), 18, Color("525252")) + 10.0
	hx += UiKit.text(ci, cnt, Vector2(hx, hy), 18, Color.BLACK, true) + 10.0
	UiKit.text(ci, tail, Vector2(hx, hy), 18, Color("9e9e9e"))
	# 키 3줄.
	var ky := plate.position.y + 16.0 + 22.0 + 14.0
	for r in KEY_ROWS.size():
		var letters := KEY_ROWS[r]
		var row_w := letters.length() * CHAR_KEY.x + (letters.length() - 1) * CHAR_KEY_GAP
		var kx := cx - row_w / 2.0
		for i in letters.length():
			_draw_detail_key(ci, Rect2(kx + i * (CHAR_KEY.x + CHAR_KEY_GAP),
					ky + r * (CHAR_KEY.y + 7.0 + 10.0), CHAR_KEY.x, CHAR_KEY.y), letters[i])
	# 발밑 안내 — 굵은 부분(#404040)과 보통(#696969).
	var fy := plate.end.y - 20.0 - 4.0
	var foot := ""
	if grade >= GameState.KEYCAP_GRADE_MAX:
		foot = tr("CHAR_KEYCAP_MAX")
	else:
		foot = tr("CHAR_KEYCAP_NEXT_HINT").format(
				{"left": GameState.keycaps_to_next(_char_view), "grade": grade + 1})
	if GameState.is_unique_cat(_char_view) and grade < GameState.KEYCAP_GRADE_MAX:
		foot += "   ·   " + tr("CHAR_UNIQUE_CAN")
	UiKit.text(ci, foot, Vector2(cx, fy), 18, Color("404040"), true, 1, plate.size.x - 40.0)


## 키캡 한 개 — 모은 글자는 흰 캡(테 3 · 두께 7 #898989) 위에 그 냥이 얼굴 + 글자,
## 못 모은 글자는 회색 캡(#dcdcdc · 두께 #c7c7c7)에 흐린 소문자.
func _draw_detail_key(ci: Control, r: Rect2, letter: String) -> void:
	var owned := GameState.has_keycap(_char_view, letter)
	var count := GameState.keycap_count(_char_view, letter)
	if not owned:
		UiKit.round_rect(ci, Rect2(r.position + Vector2(0.0, 7.0), r.size), Color("c7c7c7"), 14)
		UiKit.round_rect(ci, r, Color("dcdcdc"), 14)
		UiKit.text(ci, letter.to_lower(), r.get_center() + Vector2(0.0, 9.0), 24,
				Color("9e9e9e"), false, 1)
		return
	UiKit.round_rect(ci, Rect2(r.position + Vector2(0.0, 7.0), r.size), Color("898989"), 14)
	UiKit.round_rect_outline(ci, r, UiKit.WHITE, 14, 3, UiKit.INK)
	var char_id := str(GameState.get_cat(_char_view).get("char", ""))
	var face := Rect2(r.position.x + 6.0, r.position.y + 3.0, r.size.x - 12.0, r.size.y * 0.55)
	if not _paint_face(ci, face, char_id):
		Player.paint_cat(ci, face.get_center() + Vector2(0.0, 4.0), face.size.x * 0.55, 0.0,
				true, false, GameState.cat_skin(_char_view))
	UiKit.text(ci, letter, Vector2(r.get_center().x, r.end.y - 6.0), 16, UiKit.INK, true, 1)
	if count > 1:
		var at := r.position + Vector2(r.size.x - 2.0, r.size.y - 2.0)
		ci.draw_circle(at, 12.0, Color("fc4b48"))
		UiKit.text(ci, "×%d" % mini(count, 99), at + Vector2(0.0, 4.0), 11, UiKit.WHITE, true, 1)


## 보상 칸 4개 (피그마: 204×185, 간격 8, 안쪽 10, 모서리 10): 그림 판(모서리 30,
## 해금됨 #fff3c4 / 잠김 #d2d2d2, 냥이 70×80) → 단계 태그 → 라벨(24). 다음 보상 칸은
## 노란 반투명 판(테 2, 모서리 20)이 통째로 덮고 선물 상자 그림이 선다.
func _draw_char_rewards(ci: Control, w: float) -> void:
	var top := ci.size.y - CHAR_PAD - CHAR_REWARD_H
	var grade := GameState.cat_grade(_char_view)
	var n: int = GameState.KEYCAP_GRADE_MAX
	var gap := 8.0
	var cw := minf(204.0, (w - CHAR_PAD * 2.0 - gap * (n - 1)) / n)
	for i in n:
		var lvl := i + 1
		var done := grade >= lvl
		var next := grade == lvl - 1
		var cell := Rect2(CHAR_PAD + i * (cw + gap), top, cw, CHAR_REWARD_H)
		var box := Rect2(cell.position + Vector2(10.0, 10.0), Vector2(cw - 20.0, 96.0))
		UiKit.round_rect(ci, box, Color("fff3c4") if done else Color("d2d2d2"), 30)
		var tier := mini(i, GameState.CustomCat.TIER_MAX)
		var fit := _fit_cat(Rect2(box.get_center().x - 35.0, box.position.y + 8.0, 70.0, 80.0))
		Player.paint_cat(ci, fit[1], fit[0], 0.0, true, false,
				GameState.cat_skin(_char_view, tier) if done
				else GameState.cat_shadow_skin(_char_view, tier))
		if done and lvl == 1:
			UiKit.text(ci, "✦", Vector2(box.end.x - 30.0, box.position.y + 58.0), 30,
					Color("ffcd03"), true, 1)
		var cx := cell.get_center().x
		var step := tr("CHAR_REWARD_STEP").format({"n": lvl})
		var sw := UiKit.text_width(step, 14, true) + 24.0
		var ty := box.end.y + 8.0
		if done:
			UiKit.pill(ci, step, Vector2(cx - sw / 2.0, ty), 26.0, 14, Color("2e1d00"),
					UiKit.WHITE, true, 12.0, 3, Color("97832a"))
		else:
			UiKit.pill(ci, step, Vector2(cx - sw / 2.0, ty), 26.0, 14, Color("7d7d7d"),
					Color("ededed"), true, 12.0)
		var label := ""
		if lvl == 1:
			label = tr("CHAR_REWARD_GET") if done else tr("CHAR_REWARD_UNLOCK")
		elif done:
			label = tr("CHAR_REWARD_COMPLETE") if lvl == n else tr("CHAR_REWARD_DONE")
		elif next:
			label = tr("CHAR_REWARD_NEXT")
		else:
			label = tr("CHAR_REWARD_LOCKED")
		UiKit.text(ci, label, Vector2(cx, ty + 26.0 + 8.0 + 22.0), 24 if done else 18,
				Color("2e1d00") if done else Color("7d7d7d"), true, 1, cw - 10.0)
		if next:
			var ov := StyleBoxFlat.new()
			ov.bg_color = Color(1.0, 0.918, 0.459, 0.8)
			ov.set_corner_radius_all(20)
			ov.set_border_width_all(2)
			ov.border_color = UiKit.INK
			ci.draw_style_box(ov, cell)
			UiKit.draw_tex(ci, "gift.png", Rect2(cell.get_center().x - 50.0,
					cell.position.y + 20.0, 100.0, 103.0))


## 탭 1 왼쪽 (피그마 119:3229, 안쪽 20): 연살구 판(#fff7ed, 모서리 10, 위 20 아래 50)
## 안에 톱니 장식 · 오른쪽 위 "캐릭터 선택" · 슬롯 이름(40) · 냥이 · 안내 두 줄(30 / 20),
## 그 아래 슬롯 타일 줄.
func _draw_mine_detail(ci: Control) -> void:
	var w := ci.size.x
	var slots_top := _char_slots.position.y
	var plate := Rect2(20.0, 20.0, w - 40.0, slots_top - 30.0 - 20.0)
	UiKit.round_rect(ci, plate, Color("fff7ed"), 10)
	for g: Array in [[Vector2(158.0, 215.0), 94.0], [Vector2(564.0, 130.0), 59.0],
			[Vector2(313.0, 53.0), 32.0]]:
		var at: Vector2 = plate.position + (g[0] as Vector2) + Vector2(g[1], g[1])
		_draw_gear(ci, at, g[1] as float, Color("ffe2bd"))
	var id := _char_view
	var cat := GameState.get_cat(id)
	var cx := plate.get_center().x
	UiKit.text(ci, tr(str(cat.name)), Vector2(cx, plate.position.y + 20.0 + 53.0 + 40.0 + 10.0),
			40, Color("2e1d00"), true, 1, plate.size.x - 260.0)
	var skin: Dictionary = _customizer.preview_skin() if _customizer_on \
			else GameState.cat_skin(id)
	var fit := _fit_cat(Rect2(cx - 90.0, plate.position.y + 150.0, 180.0, 180.0))
	Player.paint_cat(ci, fit[1], fit[0], 0.0, true, false, skin)
	UiKit.text(ci, tr("CHAR_MINE_TITLE"), Vector2(cx, plate.end.y - 50.0 - 36.0), 30,
			Color.BLACK, true, 1, plate.size.x - 40.0)
	UiKit.text(ci, tr("CHAR_MINE_SUB"), Vector2(cx, plate.end.y - 50.0), 20, Color.BLACK,
			false, 1, plate.size.x - 40.0)


## 톱니 장식 하나 (피그마 나만의 냥이 판의 둥근 톱니) — 몸통 원 + 둥근 이 8개 + 가운데 구멍.
func _draw_gear(ci: CanvasItem, at: Vector2, r: float, col: Color) -> void:
	var teeth := 8
	var tw := r * 0.46
	var th := r * 0.34
	for i in teeth:
		var a := TAU * i / teeth
		ci.draw_set_transform(at, a + PI / 2.0, Vector2.ONE)
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(int(tw * 0.28))
		ci.draw_style_box(sb, Rect2(-tw / 2.0, -r, tw, th + r * 0.2))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ci.draw_circle(at, r * 0.76, col)
	ci.draw_circle(at, r * 0.3, Color("fff7ed"))


# --- 대표 캐릭터 확인 팝업 ---------------------------------------------------------


func _build_feature_ask() -> void:
	_feature_ask = _make_overlay(tr("CHAR_FEATURE_TITLE"),
			func() -> void: _feature_ask.visible = false, Vector2(800.0, 603.0))
	var body: Control = _feature_ask.get_meta("body")
	var ask := Label.new()
	ask.text = tr("CHAR_FEATURE_ASK")
	ask.position = Vector2(0.0, -14.0)
	ask.size = Vector2(body.size.x, 30.0)
	ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.label(ask, 20, TEXT)
	body.add_child(ask)
	_feature_face = Control.new()
	_feature_face.position = Vector2(0.0, 30.0)
	_feature_face.size = Vector2(body.size.x, 300.0)
	_feature_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feature_face.draw.connect(func() -> void:
		Player.paint_cat(_feature_face, Vector2(_feature_face.size.x / 2.0, 200.0),
				200.0, 0.0, true, false, GameState.cat_skin(_char_view)))
	body.add_child(_feature_face)
	var cancel := Button.new()
	cancel.text = tr("UI_CANCEL")
	cancel.size = Vector2(250.0, 71.0)
	cancel.position = Vector2(body.size.x / 2.0 - 250.0 - 10.0, body.size.y - 71.0)
	UiKit.btn_normal(cancel, 30)
	cancel.pressed.connect(func() -> void:
		Sfx.play("click")
		_feature_ask.visible = false)
	body.add_child(cancel)
	var ok := Button.new()
	ok.text = tr("CC_SAVE")
	ok.size = Vector2(250.0, 71.0)
	ok.position = Vector2(body.size.x / 2.0 + 10.0, body.size.y - 71.0)
	UiKit.btn_primary(ok, 30)
	ok.pressed.connect(func() -> void:
		Sfx.play("record")
		GameState.set_feature_cat(_char_view)
		_show_toast(tr("CHAR_FEATURE_SET").format(
				{"name": tr(str(GameState.get_cat(_char_view).name))}), GOLD_COL)
		_feature_ask.visible = false
		_refresh_currency()
		_refresh_char_page()
		queue_redraw())
	body.add_child(ok)


func _open_feature_ask() -> void:
	_raise(_feature_ask)
	_feature_face.queue_redraw()
	_feature_ask.visible = true


func _refresh_tiles() -> void:
	for id: String in _tiles:
		(_tiles[id].get_child(0) as Control).queue_redraw()
	queue_redraw()


# --- Currency + toast ---------------------------------------------------------


## 상단 고정 유저 HUD — ⚙는 닉네임 팝업, [+]는 상점으로.
func _build_user_hud() -> void:
	_user_hud = USER_HUD.new()
	add_child(_user_hud)
	_user_hud.gear_pressed.connect(_open_nick_pop)
	_user_hud.plus_pressed.connect(func(_kind: String) -> void:
		if _gacha != null and not _gacha.visible:
			_open_gacha())


func _sync_hud() -> void:
	if _user_hud == null:
		return
	# 팝업은 화면 가운데 큰 카드라 위 줄의 HUD(제 층에 떠서 딤 위로 올라온다)와 겹친다.
	var popup := false
	for o: Control in _overlays:
		if is_instance_valid(o) and o.visible:
			popup = true
			break
	if _splash or (_modes and _modes.visible) or popup:
		_user_hud.visible = false
		return
	_user_hud.visible = true
	if _settings and _settings.visible:
		_user_hud.header = "lv_only"
	elif (_chars and _chars.visible) or (_gacha and _gacha.visible):
		_user_hud.header = "page"
	else:
		_user_hud.header = "menu"


func _refresh_currency() -> void:
	if _user_hud:
		_user_hud.refresh()


func _build_toast() -> void:
	_toast = Label.new()
	_toast.position = Vector2((vw - 1000.0) / 2.0, vh - 125.0)
	_toast.size = Vector2(1000.0, 40.0)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 24)
	_toast.add_theme_font_override("font", UiKit.font_bold())
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
	if _splash:
		_draw_logo()


## 스플래시 — 로고 그림(logo.png) 가운데 + "Press to play".
func _draw_logo() -> void:
	var t := UiKit.tex("logo.png")
	var w := minf(vw * 0.603, vw - 80.0)
	var h := 0.0
	if t != null:
		h = w * t.get_size().y / t.get_size().x
		if h > vh * 0.66:
			h = vh * 0.66
			w = h * t.get_size().x / t.get_size().y
		var at := Vector2((vw - w) / 2.0, vh * 0.107 if vw >= vh else vh * 0.22)
		draw_texture_rect(t, Rect2(at, Vector2(w, h)), false)
	else:
		var cell := minf(44.0, (vw - 200.0) / 32.0)
		var bw := UiKit.block_text_width("CAT-TRIS", cell)
		UiKit.block_text(self, Vector2((vw - bw) / 2.0, vh * 0.2), "CAT-TRIS", cell)
	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 400.0)
	UiKit.center_text_outlined(self, tr("MENU_PRESS_TO_PLAY"), vh * 0.897, vw, 30,
			Color(1, 1, 1, pulse), 0.0, 6, UiKit.font_black())  # 피그마 9 Black 30
	queue_redraw()  # 깜빡임


## 무대 — 이번 판에 나갈 냥이가 플레이 버튼 위에 선다.
func _draw_seats() -> void:
	var id := GameState.selected_cat
	Player.paint_cat(_stage_cat, _cat_anchor, _cat_size, 0.0, true, false,
			GameState.cat_skin(id))
