extends RefCounted
## Cat-Tris UI 키트 — 피그마 디자인(2026-09, 캣트리스 UI kit)의 팔레트·스타일·
## 드로잉 헬퍼를 한 곳에 모은다. 배경은 하늘색 + 발바닥/별 패턴, 카드는 흰 둥근
## 판(외곽선 없음), 버튼은 두꺼운 잉크 외곽선(#2c1b17, 5px) + 아래 두께감(베벨).
##
## class_name 없이 preload로 쓴다 (플랫폼 코드에서도 동일하게 참조 가능):
##     const UiKit := preload("res://core/scripts/ui_kit.gd")
##     UiKit.btn_primary(b, 34)
##
## 그림 에셋은 `shared/assets/ui/`(피그마에서 뽑은 원본)이고 `tex("coin.png")`로
## 읽는다 — 화면마다 아이콘을 다시 그리지 말고 여기 것을 쓸 것.

# --- 팔레트 (피그마 UI kit) --------------------------------------------------------

const SKY := Color("95dfff")  # 배경 하늘색
const SKY_PAW := Color("6fcbf5")  # 배경 패턴(발바닥·별) 색 — 30% 알파로 깐다
const SKY_DEEP := Color("95dfff")  # (예전 그라데이션용 — 이제 단색)
const CARD_SKY := Color("d6f3ff")  # 유저 HUD 카드 · 재화 알약 · 인게임 힌트 카드
const INK := Color("2c1b17")  # 모든 외곽선 (짙은 갈색)
const TEXT := Color("2d2d2d")  # 기본 글자
const BROWN := Color("2e1d00")  # 팝업 제목 (뽑기 결과 · 랭킹 · 레벨업)
const WHITE := Color("ffffff")
const CREAM := Color("fff3d0")  # 인게임 배너(마일스톤) 글자

const GREEN := Color("a8e63a")  # 주 버튼 (플레이 · 저장 · 확인)
const GREEN_DEEP := Color("6ea60b")
const GREEN_INK := Color("2a6800")  # 주 버튼 흰 글자의 그림자 (피그마 값)
const PRIMARY_OUTLINE := Color("122b00")  # 그 그림자가 렌더에서 보이는 테 색
const BTN_TEXT := Color("000000")  # 피그마 버튼 글자 (btn_normal · 초록 확인 버튼)
const NORMAL_DEEP := Color("888888")  # 피그마 btn_normal 두께 (일반_그림자)
const BLUE_DEEP := Color("1f83ae")  # 흰 CTA 버튼(캐릭터 변경하기 등)의 아래 두께
const GRAY_DEEP := Color("8a8a8a")  # 흰 보조 버튼의 아래 두께
const GAUGE := Color("1362ff")  # 경험치 바
const YELLOW := Color("ffe040")  # 탭 활성 · 선택 타일 · 랭킹 프레임
const YELLOW_DEEP := Color("dfb302")
const RED_TAB := Color("ff5355")  # 나만의 냥이 탭
const GRAY_TAB := Color("bcbcbc")  # 비활성 탭
const PANEL := Color("f1f1f1")  # 카드 안 회색 판 (키캡 도감 · 기계 판 · 결과 통계)
const PANEL_LINE := Color("dadada")
const NAVY := Color("1e2b45")  # 우물 · NEXT 판 · 모드 카드 미리보기
const LABEL := Color("b4b4b4")  # 계기판 소제목 (LEVEL · SCORE …)
const LAVENDER := Color("eae8ff")  # 캔 뽑기 열의 기계 판
const TRAY := Color("fff3be")  # 뽑기 결과 트레이 · 결과 보상 칩
const RANK_BLUE := Color("6ad4ff")  # 누적 랭킹 프레임
const RANK_BLUE_TAB := Color("42859f")
const PEACH := Color("ffe6c6")  # 나만의 냥이 프리뷰 판

# 예전 이름들 — 기존 호출부(보드·터치 버튼·커스터마이저)가 그대로 쓴다.
const ORANGE := Color("f7861d")
const ORANGE_DEEP := Color("d1660a")
const GOLD := Color("f5b400")
const GOLD_DEEP := Color("b8860b")
const CYAN := Color("5cc4ea")
const CYAN_DEEP := Color("2f9cc4")
const PURPLE := Color("9b5de5")
const PURPLE_DEEP := Color("7038c0")
const RED := Color("ff5355")
const RED_DEEP := Color("c53a24")
const PINK := Color("f9a9a0")
## 통조림 캔 — 주간 랭킹 보상으로만 들어오는 두 번째 재화 (은빛 + 붉은 라벨).
const CAN := Color("cfd8e3")
const CAN_DEEP := Color("8794a6")
const CAN_LABEL := Color("e05a49")

const MUTED := Color(0.17, 0.16, 0.2, 0.55)  # 보조 텍스트 (흰 패널 위)
const SOFT := Color(0.17, 0.16, 0.2, 0.35)  # 더 흐린 보조 텍스트

const BORDER := 5  # 버튼 외곽선 두께 (피그마 5px)
const RADIUS := 20  # 기본 모서리 반경
const BEVEL := 10  # 버튼 아래 두께감

const DIM := Color("292929", 0.86)  # 팝업 뒤 어두운 딤 (피그마 #292929)
const DIM_SOFT := Color("676767", 0.8)  # 랭킹 팝업 딤

const ASSET_DIR := "res://shared/assets/ui/"

# 로고 블록 글자용 팔레트 (예전 코드 로고 — 지금 로고는 logo.png 그림이다)
const LOGO_COLORS := [CYAN, GOLD, RED, WHITE, GOLD, ORANGE, GOLD_DEEP, CYAN]

# 3×5 블록 폰트 — 블록 글자용. 각 행의 '#'이 블록 한 칸.
const GLYPHS := {
	"A": ["_#_", "#_#", "###", "#_#", "#_#"],
	"C": ["###", "#__", "#__", "#__", "###"],
	"E": ["###", "#__", "##_", "#__", "###"],
	"I": ["###", "_#_", "_#_", "_#_", "###"],
	"M": ["#_#", "###", "###", "#_#", "#_#"],
	"O": ["###", "#_#", "#_#", "#_#", "###"],
	"P": ["##_", "#_#", "##_", "#__", "#__"],
	"R": ["##_", "#_#", "##_", "#_#", "#_#"],
	"S": ["###", "#__", "###", "__#", "###"],
	"T": ["###", "_#_", "_#_", "_#_", "_#_"],
	"-": ["___", "___", "###", "___", "___"],
	" ": ["___", "___", "___", "___", "___"],
}

static var _tex_cache: Dictionary = {}
static var _bold: Font
static var _heavy: Font
static var _extra: Font
static var _black: Font


# --- 에셋 ---------------------------------------------------------------------


## 피그마에서 뽑은 UI 그림 (shared/assets/ui/<name>). 없으면 null.
static func tex(name: String) -> Texture2D:
	if _tex_cache.has(name):
		return _tex_cache[name]
	var path := ASSET_DIR + name
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	_tex_cache[name] = t
	return t


## 그림을 rect 안에 비율을 지키며 가운데 맞춰 그린다.
static func draw_tex(ci: CanvasItem, name: String, rect: Rect2,
		modulate := Color.WHITE) -> void:
	var t := tex(name)
	if t == null:
		return
	var ts := t.get_size()
	var s := minf(rect.size.x / ts.x, rect.size.y / ts.y)
	var size := ts * s
	ci.draw_texture_rect(t, Rect2(rect.position + (rect.size - size) / 2.0, size),
			false, modulate)


## 그림을 폭 w에 맞춰 (center 기준) 그린다. 그린 높이를 돌려준다.
static func draw_tex_w(ci: CanvasItem, name: String, center: Vector2, w: float,
		modulate := Color.WHITE) -> float:
	var t := tex(name)
	if t == null:
		return 0.0
	var ts := t.get_size()
	var h := w * ts.y / ts.x
	ci.draw_texture_rect(t, Rect2(center - Vector2(w, h) / 2.0, Vector2(w, h)),
			false, modulate)
	return h


# --- 폰트 -----------------------------------------------------------------------


static func font() -> Font:
	return ThemeDB.fallback_font


## 굵은 글자 — 피그마 UI kit의 Paperlogy 6 SemiBold (버튼·제목·라벨 대부분).
static func font_bold() -> Font:
	if _bold == null:
		_bold = load("res://shared/assets/fonts/ui_font_bold.tres")
	return _bold


## 더 굵은 글자 — Paperlogy 7 Bold (피그마 값 알약·강조 숫자).
static func font_heavy() -> Font:
	if _heavy == null:
		_heavy = load("res://shared/assets/fonts/ui_font_heavy.tres")
	return _heavy


## 아주 굵은 글자 — Paperlogy 8 ExtraBold (메인 플레이 · CTA · 모드 버튼 · 큰 점수).
static func font_extra() -> Font:
	if _extra == null:
		_extra = load("res://shared/assets/fonts/ui_font_extra.tres")
	return _extra


## 가장 굵은 글자 — Paperlogy 9 Black (Press to play · 타이머).
static func font_black() -> Font:
	if _black == null:
		_black = load("res://shared/assets/fonts/ui_font_black.tres")
	return _black


## 글자 한 줄. align: 0 왼쪽 / 1 가운데 / 2 오른쪽 (`at`이 그 기준점).
## width > 0 이면 그 폭에 들어가도록 글자를 줄인다 (긴 번역 대응).
static func text(ci: CanvasItem, s: String, at: Vector2, size: int, col: Color,
		bold := false, align := 0, width := 0.0) -> float:
	var f := font_bold() if bold else font()
	if width > 0.0:
		size = fit_size(f, s, width, size)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := at.x
	if align == 1:
		x -= w / 2.0
	elif align == 2:
		x -= w
	ci.draw_string(f, Vector2(x, at.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	return w


static func text_width(s: String, size: int, bold := false) -> float:
	var f := font_bold() if bold else font()
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Label을 디자인 톤으로 (크기 · 색 · 굵기).
static func label(l: Label, size: int, col: Color = TEXT, bold := false) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if bold:
		l.add_theme_font_override("font", font_bold())


# --- 스타일박스 ---------------------------------------------------------------


## 흰 카드 — 디자인의 카드는 외곽선이 없다 (둥근 흰 판만).
static func card_box(bg: Color = WHITE, radius: int = 24, pad: float = 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb


## 잉크 외곽선을 두른 둥근 판 (예전 카드 — 지금은 버튼·재화 알약 정도에만).
static func panel_box(bg: Color = WHITE, radius: int = 24, pad: float = 26.0,
		border: int = BORDER, border_col: Color = INK) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = border_col
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.8
	sb.content_margin_bottom = pad * 0.8
	sb.shadow_size = 0
	return sb


## 버튼에 색 세트를 입힌다 (normal / hover / pressed / disabled / focus).
static func style_button(b: Button, face: Color, deep: Color, text_col: Color,
		font_size: int = 30, radius: int = RADIUS, bold := true,
		border: int = BORDER, bevel: int = BEVEL) -> void:
	# 번역이 길어져도 버튼이 밖으로 자라지 않게 한다 (/i18n 철칙 5).
	b.clip_text = true
	b.add_theme_font_size_override("font_size", font_size)
	if bold:
		b.add_theme_font_override("font", font_bold())
	else:
		b.remove_theme_font_override("font")
	b.add_theme_color_override("font_color", text_col)
	b.add_theme_color_override("font_hover_color", text_col)
	b.add_theme_color_override("font_pressed_color", text_col)
	b.add_theme_color_override("font_focus_color", text_col)
	b.add_theme_color_override("font_disabled_color", Color(text_col, 0.4))
	b.add_theme_color_override("icon_normal_color", text_col)
	b.add_theme_constant_override("outline_size", 0)
	b.add_theme_constant_override("shadow_outline_size", 0)
	b.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	b.add_theme_stylebox_override("normal",
			_bevel_box(face, deep, radius, false, border, bevel))
	b.add_theme_stylebox_override("hover",
			_bevel_box(face.lightened(0.08), deep, radius, false, border, bevel))
	b.add_theme_stylebox_override("pressed", _bevel_box(face.darkened(0.06), deep,
			radius, true, border, bevel))
	b.add_theme_stylebox_override("disabled",
			_bevel_box(face.lerp(Color(0.85, 0.85, 0.87), 0.6), deep.lightened(0.35),
			radius, false, border, bevel))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## 버튼 배경 — rect 전체가 얼굴이고, 두께(베벨)는 rect **아래 바깥**에 붙는다.
## 그래서 피그마의 버튼 높이(얼굴 + 두께)가 115면 Button.size.y는 105다.
## 글자는 얼굴 한가운데. 눌리면 두께가 접히고 글자가 살짝 내려앉는다.
static func _bevel_box(face: Color, deep: Color, radius: int, sunk: bool,
		border: int = BORDER, bevel: int = BEVEL) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = face
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = INK
	# 아래 그림자를 딱 붙여 그려서 "두께"로 보이게 한다 (번지지 않게 크기 = 오프셋).
	sb.shadow_color = deep
	sb.shadow_size = 0 if sunk or bevel <= 0 else 1
	sb.shadow_offset = Vector2(0.0, 0.0 if sunk else float(bevel))
	sb.content_margin_top = float(bevel) * 0.6 if sunk else 0.0
	sb.content_margin_bottom = 0.0
	sb.anti_aliasing = true
	return sb


## 버튼 모서리를 따로 깎는다 (style_button 뒤에 — 이어 붙은 버튼 묶음: 최소|◀ n ▶|최대).
static func btn_corners(b: Button, tl: int, tr: int, br: int, bl: int) -> void:
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := b.get_theme_stylebox(st) as StyleBoxFlat
		if sb == null:
			continue
		sb.corner_radius_top_left = tl
		sb.corner_radius_top_right = tr
		sb.corner_radius_bottom_right = br
		sb.corner_radius_bottom_left = bl


## 초록 확인 버튼 (피그마 btn_normal 초록 — 저장 · 확인 · 다시 도전 · 이어하기 · 모드 카드).
## 테 3 · 두께 7(#6ea60b) · 모서리 16 · **진한 글자**. 흰 글자는 메인 `플레이`(btn_play)뿐이다.
static func btn_primary(b: Button, font_size: int = 30) -> void:
	style_button(b, GREEN, GREEN_DEEP, BTN_TEXT, font_size, 16, true, 3, 7)


## 메인 메뉴의 큰 `플레이` (피그마 Component 22): 테 5 · 두께 10 · 모서리 30,
## 흰 글자 + 짙은 초록 테(text-shadow).
static func btn_play(b: Button, font_size: int = 72) -> void:
	style_button(b, GREEN, GREEN_DEEP, WHITE, font_size, 30, true, 5, 10)
	b.add_theme_color_override("font_outline_color", PRIMARY_OUTLINE)
	# 피그마 렌더의 테는 글자 둘레 ~4px + 아래로 2~3px 더 두껍다 (text-shadow 1 2 1).
	b.add_theme_constant_override("outline_size", maxi(5, int(font_size * 0.2)))
	b.add_theme_color_override("font_shadow_color", PRIMARY_OUTLINE)
	b.add_theme_constant_override("shadow_offset_x", maxi(1, font_size / 40))
	b.add_theme_constant_override("shadow_offset_y", maxi(2, font_size / 22))
	b.add_theme_constant_override("shadow_outline_size", maxi(5, int(font_size * 0.2)))
	b.add_theme_font_override("font", font_extra())  # 피그마 8 ExtraBold


## 흰 CTA 버튼 — 아래 두께가 파랑 (캐릭터 변경하기 · 상점 가기 · 랭킹 보기 · 설정 하기).
## 피그마 btn_cta: 테 5 · 두께 10 · 모서리 20.
static func btn_cta(b: Button, font_size: int = 45) -> void:
	style_button(b, WHITE, BLUE_DEEP, TEXT, font_size, 20, true, 5, 10)
	b.add_theme_font_override("font", font_extra())  # 피그마 8 ExtraBold


## 큰 색 버튼 (피그마 btn_cta 색 변형 — 모드 카드의 초록/회색). 테 5 · 두께 10 · 진한 글자.
static func btn_big(b: Button, face: Color, deep: Color, font_size: int = 45) -> void:
	style_button(b, face, deep, TEXT, font_size, 20, true, 5, 10)
	b.add_theme_font_override("font", font_extra())  # 피그마 8 ExtraBold


## 흰 카드 버튼 — 아래 베벨만 강조색 (기본은 회색: 뒤로가기 · 닫기 · 취소).
static func btn_card(b: Button, _accent: Color = GRAY_DEEP, font_size: int = 30) -> void:
	btn_normal(b, font_size)


## 피그마 btn_normal: 흰 얼굴 · 테 3 · 두께 7(#888) · 모서리 16 · 검정 SemiBold.
## 뒤로가기(241×71) · 닫기/취소(250×71) · 설정 칩(350×71) 등 대부분의 보조 버튼.
static func btn_normal(b: Button, font_size: int = 30, face: Color = WHITE,
		deep: Color = NORMAL_DEEP) -> void:
	style_button(b, face, deep, BTN_TEXT, font_size, 16, true, 3, 7)


## 작은 보조 버튼 (닫기 · 뒤로 · 취소).
static func btn_ghost(b: Button, font_size: int = 22) -> void:
	btn_normal(b, font_size)


## 노란 강조 버튼 (대표 캐릭터 해제 · 원본냥이).
static func btn_yellow(b: Button, font_size: int = 24) -> void:
	# 피그마 btn(대표 캐릭터 해제 · 원본냥이): #ffcd03 · 테 3 · 두께 7 · 모서리 11.
	style_button(b, Color("ffcd03"), Color("c79a00"), BTN_TEXT, font_size, 11, true, 3, 7)


## 빨간 위험 버튼 (게임 초기화).
static func btn_danger(b: Button, font_size: int = 30) -> void:
	# 피그마 게임초기화: #ff3838 · 두께 #740000 · 테 3 · 두께 7.
	style_button(b, Color("ff3838"), Color("740000"), WHITE, font_size, 16, true, 3, 7)


## 선택 상태를 가지는 칩. 켜지면 노랑, 꺼지면 흰색.
static func btn_chip(b: Button, active: bool, font_size: int = 20) -> void:
	if active:
		style_button(b, YELLOW, YELLOW_DEEP, TEXT, font_size, 14)
	else:
		style_button(b, WHITE, GRAY_DEEP, Color(TEXT, 0.75), font_size, 14)
	b.add_theme_constant_override("outline_size", 0)


## 페이지 위 큰 탭 (일반 냥이 / 나만의 냥이, 주간 / 누적). 베벨·외곽선 없이
## 색판 하나 — 켜진 탭은 `col`, 꺼진 탭은 회색.
static func btn_tab(b: Button, active: bool, col: Color = YELLOW, font_size: int = 30,
		radius: int = 16, top_only := true) -> void:
	b.clip_text = true
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_font_override("font", font_bold())
	# 피그마 탭: 켜진 노랑 탭은 검정 글자, 빨강·파랑 탭은 흰 글자, 꺼진 회색 탭은 흰 75%.
	var text_col := Color.BLACK if active and col == YELLOW 			else (WHITE if active else Color(1, 1, 1, 0.75))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, text_col)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col if active else GRAY_TAB
	# 위·옆 테 3px — 탭 색보다 한참 진한 색 (노랑 #a06800 · 빨강 #7f0002 · 회색 #969696).
	sb.border_width_top = 3
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 0 if top_only else 3
	var edge := Color("969696")
	if active:
		edge = Color("a06800") if col == YELLOW else (Color("7f0002") if col == RED_TAB
				else col.darkened(0.45))
	sb.border_color = edge
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = 0 if top_only else radius
	sb.corner_radius_bottom_right = 0 if top_only else radius
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_constant_override("outline_size", 0)


## 이 UI 아래 모든 기본 컨트롤(Label/Button/LineEdit)에 디자인 톤을 깐다.
static func apply_theme(root: Node) -> void:
	var t := Theme.new()
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_stylebox("normal", "Button", _bevel_box(WHITE, GRAY_DEEP, RADIUS, false))
	t.set_stylebox("hover", "Button",
			_bevel_box(WHITE.darkened(0.05), GRAY_DEEP, RADIUS, false))
	t.set_stylebox("pressed", "Button",
			_bevel_box(Color("efeff3"), GRAY_DEEP, RADIUS, true))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", TEXT)
	t.set_stylebox("normal", "LineEdit", panel_box(WHITE, 16, 14.0, 3, PANEL_LINE))
	t.set_stylebox("focus", "LineEdit", panel_box(WHITE, 16, 14.0, 3, GAUGE))
	if root is Control:
		(root as Control).theme = t
	elif root is CanvasLayer:
		for c in root.get_children():
			if c is Control:
				(c as Control).theme = t
	return


# --- 배경 ---------------------------------------------------------------------


## 하늘색 배경 + 발바닥/별 패턴 (피그마 paw-star-pattern: 발바닥 70px가 190 간격,
## 사이사이 별 20px, 줄마다 반 칸씩 엇갈리며 전체 30% 알파). `seed_off`는 예전
## 호출부 호환용이고 무늬는 늘 같다 — 화면이 바뀌어도 배경은 이어져 보여야 한다.
static func paint_backdrop(ci: CanvasItem, size: Vector2, _seed_off: int = 0) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, size), SKY)
	var paw_t := tex("paw.svg")
	var star_t := tex("star.svg")
	var mod := Color(1, 1, 1, 0.3)
	var pitch := 190.0
	var row := 0
	var y := -10.0
	while y < size.y + 70.0:
		var off := 0.0 if row % 2 == 0 else 95.0
		var x := -10.0 + off
		while x < size.x + 70.0:
			if paw_t != null:
				ci.draw_texture_rect(paw_t, Rect2(x, y, 70.0, 70.0), false, mod)
			else:
				paw(ci, Vector2(x + 35.0, y + 35.0), 26.0, Color(SKY_PAW, 0.3))
			x += pitch
		# 별 줄 — 발바닥 사이(80px 아래), 발바닥과 반 칸 엇갈려.
		var sx := 75.0 if row % 2 == 0 else -10.0
		while sx < size.x + 20.0:
			if star_t != null:
				ci.draw_texture_rect(star_t, Rect2(sx, y + 80.0, 20.0, 20.0), false, mod)
			sx += pitch
		y += 160.0
		row += 1


## 발바닥 도장 하나 (큰 발볼 + 발가락 4개) — 패턴 텍스처가 없을 때의 대체.
static func paw(ci: CanvasItem, at: Vector2, r: float, col: Color, rot := 0.0) -> void:
	ellipse(ci, at + Vector2(0.0, r * 0.30).rotated(rot),
			Vector2(r * 0.72, r * 0.58), col, rot)
	var toes := [Vector2(-0.72, -0.52), Vector2(-0.26, -0.86),
			Vector2(0.26, -0.86), Vector2(0.72, -0.52)]
	for t: Vector2 in toes:
		ellipse(ci, at + (t * r).rotated(rot), Vector2(r * 0.25, r * 0.31), col, rot)


static func ellipse(ci: CanvasItem, at: Vector2, radius: Vector2, col: Color,
		rot := 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(at + Vector2(cos(a) * radius.x, sin(a) * radius.y).rotated(rot))
	ci.draw_colored_polygon(pts, col)


## 둥근 상자 하나 (색만).
static func round_rect(ci: CanvasItem, r: Rect2, col: Color, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	ci.draw_style_box(sb, r)


## 둥근 상자 + 외곽선.
static func round_rect_outline(ci: CanvasItem, r: Rect2, col: Color, radius: int,
		border: int, border_col: Color = INK) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = border_col
	ci.draw_style_box(sb, r)


## 알약(캡슐 모양 배지). 글자 폭에 맞춰 늘어난다. 그린 폭을 돌려준다.
static func pill(ci: CanvasItem, s: String, at: Vector2, h: float, size: int,
		fg: Color, bg: Color, bold := true, pad := 14.0, border := 0,
		border_col := INK) -> float:
	var w := text_width(s, size, bold) + pad * 2.0
	if border > 0:
		round_rect_outline(ci, Rect2(at, Vector2(w, h)), bg, int(h / 2.0), border,
				border_col)
	else:
		round_rect(ci, Rect2(at, Vector2(w, h)), bg, int(h / 2.0))
	text(ci, s, at + Vector2(pad, h * 0.5 + size * 0.36), size, fg, bold)
	return w


## 체크 뱃지 (선택된 타일 우상단의 검은 동그라미 + 흰 체크).
static func check_badge(ci: CanvasItem, at: Vector2, r := 13.0,
		col: Color = TEXT) -> void:
	ci.draw_circle(at, r, col)
	ci.draw_polyline(PackedVector2Array([at + Vector2(-r * 0.45, 0.0),
			at + Vector2(-r * 0.12, r * 0.38), at + Vector2(r * 0.5, -r * 0.42)]),
			WHITE, maxf(2.0, r * 0.22))


## 자물쇠 (잠긴 타일).
static func lock_icon(ci: CanvasItem, at: Vector2, s: float, col: Color = Color("8f8f8f")) -> void:
	round_rect(ci, Rect2(at + Vector2(-s * 0.5, -s * 0.05), Vector2(s, s * 0.8)), col,
			int(s * 0.14))
	ci.draw_arc(at + Vector2(0.0, -s * 0.12), s * 0.32, PI, TAU, 12, col, s * 0.16)


# --- 블록 글자 ----------------------------------------------------------------


## 둥근 모서리 블록 한 칸 (윗면 하이라이트 + 잉크 외곽선). 아트 규칙: 빛은 위에서.
static func block(ci: CanvasItem, rect: Rect2, col: Color, ink_w := 4.0) -> void:
	var r := minf(rect.size.x, rect.size.y) * 0.22
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(r))
	sb.set_border_width_all(int(ink_w))
	sb.border_color = INK
	ci.draw_style_box(sb, rect)
	# 윗면 하이라이트 — 항상 위에서 오는 빛.
	var hi := StyleBoxFlat.new()
	hi.bg_color = Color(1, 1, 1, 0.45)
	hi.set_corner_radius_all(int(r * 0.7))
	var inset := ink_w + rect.size.x * 0.12
	ci.draw_style_box(hi, Rect2(rect.position + Vector2(inset, ink_w + rect.size.y * 0.1),
			Vector2(rect.size.x - inset * 2.0, rect.size.y * 0.2)))


## 블록 글자 한 줄을 그리고 그린 폭을 돌려준다. `at`은 좌상단.
static func block_text(ci: CanvasItem, at: Vector2, s: String, cell: float,
		gap: float = 0.0, colors: Array = LOGO_COLORS) -> float:
	var x := at.x
	var idx := 0
	for i in s.length():
		var g: Array = GLYPHS.get(s[i].to_upper(), GLYPHS[" "])
		var col: Color = colors[idx % colors.size()] if not colors.is_empty() else GOLD
		for row in g.size():
			var line: String = g[row]
			for c in line.length():
				if line[c] != "#":
					continue
				block(ci, Rect2(x + c * (cell + gap), at.y + row * (cell + gap),
						cell, cell), col, maxf(2.0, cell * 0.09))
		x += 3.0 * (cell + gap) + cell * 0.45
		idx += 1
	return x - at.x - cell * 0.45


## 블록 글자 한 줄의 폭 (block_text와 같은 계산).
static func block_text_width(s: String, cell: float, gap: float = 0.0) -> float:
	if s.is_empty():
		return 0.0
	return s.length() * (3.0 * (cell + gap) + cell * 0.45) - cell * 0.45


# --- 텍스트 -------------------------------------------------------------------


## 가운데 정렬 텍스트 (지정 폭 기준). 그린 폭을 돌려준다.
static func center_text(ci: CanvasItem, s: String, at_y: float, width: float,
		size: int, col: Color, x0: float = 0.0, bold := false) -> float:
	var f := font_bold() if bold else font()
	size = fit_size(f, s, width, size)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(f, Vector2(x0 + (width - w) / 2.0, at_y), s,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	return w


## 잉크 외곽선을 두른 가운데 정렬 텍스트 (밝은 배경 위 강조용).
static func center_text_outlined(ci: CanvasItem, s: String, at_y: float,
		width: float, size: int, col: Color, x0: float = 0.0,
		outline: int = 8, fnt: Font = null) -> void:
	var f := fnt if fnt != null else font_bold()
	size = fit_size(f, s, width, size)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(x0 + (width - w) / 2.0, at_y)
	ci.draw_string_outline(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			outline, INK)
	ci.draw_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## 주어진 폭에 들어가는 가장 큰 글자 크기 (최소 min_size까지 줄인다).
## _draw()로 직접 그리는 텍스트는 자동 축소가 없으므로, 번역이 길어질 수 있는
## 문구는 반드시 이걸 거쳐서 그린다. (/i18n 철칙 5)
static func fit_size(f: Font, s: String, width: float, size: int,
		min_size: int = 11) -> int:
	while size > min_size and f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT,
			-1, size).x > width:
		size -= 1
	return size


## 1234567 → "1,234,567" (자릿수 구분은 언어와 무관한 숫자 표기로 통일).
static func commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return ("-" if n < 0 else "") + out


## 통조림 캔 아이콘 — 피그마 캔 그림(can.png)을 `at` 중심, 높이 h로.
static func can_icon(ci: CanvasItem, at: Vector2, h: float, _outline := true) -> void:
	var t := tex("can.png")
	if t == null:
		ci.draw_rect(Rect2(at - Vector2(h * 0.39, h * 0.5), Vector2(h * 0.78, h)), CAN)
		return
	var ts := t.get_size()
	var w := h * ts.x / ts.y
	ci.draw_texture_rect(t, Rect2(at - Vector2(w, h) / 2.0, Vector2(w, h)), false)


## 골드 코인 아이콘 (coin.png).
static func coin_icon(ci: CanvasItem, at: Vector2, h: float) -> void:
	var t := tex("coin.png")
	if t == null:
		ci.draw_circle(at, h / 2.0, GOLD)
		return
	var ts := t.get_size()
	var w := h * ts.x / ts.y
	ci.draw_texture_rect(t, Rect2(at - Vector2(w, h) / 2.0, Vector2(w, h)), false)
