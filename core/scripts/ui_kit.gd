extends RefCounted
## Cat-Tris UI 키트 — 아트 컨셉(밝은 하늘색 + 두꺼운 잉크 외곽선 + 통통한 3D 버튼)을
## 한 곳에 모은 팔레트/스타일/드로잉 헬퍼 모음.
##
## class_name 없이 preload로 쓴다 (플랫폼 코드에서도 동일하게 참조 가능):
##     const UiKit := preload("res://core/scripts/ui_kit.gd")
##     UiKit.btn_primary(b, 34)

# --- 팔레트 -------------------------------------------------------------------

const SKY := Color("a3d9f5")  # 배경 하늘색
const SKY_PAW := Color("8ecdf0")  # 배경 발바닥 무늬
const SKY_DEEP := Color("7ec4ea")  # 배경 아래쪽 그라데이션
const INK := Color("2c2a33")  # 모든 외곽선/기본 글자색
const WHITE := Color("ffffff")
const CREAM := Color("fff3d0")  # 출구의 빛 / 강조 텍스트

const ORANGE := Color("f7861d")  # 주 버튼(PLAY)
const ORANGE_DEEP := Color("d1660a")  # 주 버튼 아래 베벨
const GOLD := Color("f2b41e")
const GOLD_DEEP := Color("c98c0c")
const CYAN := Color("5cc4ea")
const CYAN_DEEP := Color("2f9cc4")
const PURPLE := Color("9b5de5")
const PURPLE_DEEP := Color("7038c0")
const RED := Color("ef5f45")
const RED_DEEP := Color("c53a24")
const PINK := Color("f9a9a0")  # 볼터치
## 통조림 캔 — 주간 랭킹 보상으로만 들어오는 두 번째 재화. 골드(금)와 확실히
## 갈라 보이도록 차가운 은빛 + 붉은 라벨을 쓴다.
const CAN := Color("cfd8e3")
const CAN_DEEP := Color("8794a6")
const CAN_LABEL := Color("e05a49")

const MUTED := Color(0.17, 0.16, 0.2, 0.55)  # 보조 텍스트 (흰 패널 위)
const SOFT := Color(0.17, 0.16, 0.2, 0.35)  # 더 흐린 보조 텍스트

const BORDER := 4  # 기본 외곽선 두께
const RADIUS := 18  # 기본 모서리 반경
const BEVEL := 8  # 버튼 아래 두께감

# 로고 블록 글자용 팔레트 (컨셉 이미지의 CAT-TRIS 색 순서)
const LOGO_COLORS := [CYAN, GOLD, RED, WHITE, GOLD, ORANGE, GOLD_DEEP, CYAN]

# 3×5 블록 폰트 — 로고/블록 글자용. 각 행의 '#'이 블록 한 칸.
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


# --- 스타일박스 ---------------------------------------------------------------


## 흰 카드/패널 배경 (두꺼운 잉크 외곽선 + 둥근 모서리).
static func panel_box(bg: Color = WHITE, radius: int = 24, pad: float = 26.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(BORDER)
	sb.border_color = INK
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.8
	sb.content_margin_bottom = pad * 0.8
	sb.shadow_size = 0
	return sb


## 버튼에 색 세트를 입힌다 (normal / hover / pressed / disabled / focus).
static func style_button(b: Button, face: Color, deep: Color, text_col: Color,
		font_size: int = 30, radius: int = RADIUS) -> void:
	# 번역이 길어져도 버튼이 밖으로 자라지 않게 한다 — 독일어/러시아어는 한국어의
	# 1.6~1.8배라, 이걸 안 걸면 긴 라벨이 패널을 뚫고 나간다. (/i18n 철칙 5)
	b.clip_text = true
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", text_col)
	b.add_theme_color_override("font_hover_color", text_col)
	b.add_theme_color_override("font_pressed_color", text_col)
	b.add_theme_color_override("font_focus_color", text_col)
	b.add_theme_color_override("font_disabled_color", Color(text_col, 0.4))
	b.add_theme_color_override("icon_normal_color", text_col)
	b.add_theme_stylebox_override("normal", _bevel_box(face, deep, radius, false))
	b.add_theme_stylebox_override("hover",
			_bevel_box(face.lightened(0.12), deep, radius, false))
	b.add_theme_stylebox_override("pressed", _bevel_box(face.darkened(0.06), deep,
			radius, true))
	b.add_theme_stylebox_override("disabled",
			_bevel_box(face.lerp(Color(0.85, 0.85, 0.87), 0.6), deep.lightened(0.35),
			radius, false))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## 아래 베벨(두께)까지 포함한 버튼 배경. 눌리면 베벨이 접히며 버튼이 내려앉는다.
static func _bevel_box(face: Color, deep: Color, radius: int, sunk: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = face
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(BORDER)
	sb.border_color = INK
	# 아래 그림자를 딱 붙여 그려서 "두께"로 보이게 한다.
	sb.shadow_color = deep
	sb.shadow_size = 0 if sunk else BEVEL
	sb.shadow_offset = Vector2(0.0, 0.0 if sunk else float(BEVEL))
	sb.content_margin_top = float(BEVEL) if sunk else 0.0
	sb.content_margin_bottom = 0.0 if sunk else float(BEVEL)
	return sb


## 큰 오렌지 주 버튼 (PLAY).
static func btn_primary(b: Button, font_size: int = 40) -> void:
	style_button(b, ORANGE, ORANGE_DEEP, INK, font_size, 20)


## 흰 카드 버튼 — 아래 베벨만 강조색 (CHARACTER / SHOP / RANKING / SETTINGS).
static func btn_card(b: Button, accent: Color, font_size: int = 26) -> void:
	style_button(b, WHITE, accent, INK, font_size, 18)


## 작은 보조 버튼 (닫기 등).
static func btn_ghost(b: Button, font_size: int = 22) -> void:
	style_button(b, WHITE, Color("c9c6d0"), INK, font_size, 16)


## 선택 상태를 가지는 탭/칩. 켜지면 골드, 꺼지면 흰색.
static func btn_chip(b: Button, active: bool, font_size: int = 20) -> void:
	if active:
		style_button(b, GOLD, GOLD_DEEP, INK, font_size, 14)
	else:
		style_button(b, WHITE, Color("c9c6d0"), Color(INK, 0.7), font_size, 14)


## 이 UI 아래 모든 기본 컨트롤(Label/Button/LineEdit)에 컨셉 톤을 깐다.
static func apply_theme(root: Node) -> void:
	var t := Theme.new()
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_stylebox("normal", "Button", _bevel_box(WHITE, Color("c9c6d0"), RADIUS, false))
	t.set_stylebox("hover", "Button",
			_bevel_box(WHITE.darkened(0.05), Color("c9c6d0"), RADIUS, false))
	t.set_stylebox("pressed", "Button",
			_bevel_box(Color("efeff3"), Color("c9c6d0"), RADIUS, true))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("caret_color", "LineEdit", INK)
	t.set_stylebox("normal", "LineEdit", panel_box(Color("f2f4f8"), 12, 12.0))
	t.set_stylebox("focus", "LineEdit", panel_box(Color("fff8e6"), 12, 12.0))
	if root is Control:
		(root as Control).theme = t
	elif root is CanvasLayer:
		for c in root.get_children():
			if c is Control:
				(c as Control).theme = t
	return


# --- 배경 ---------------------------------------------------------------------


## 하늘색 배경 + 흩뿌린 발바닥 무늬. `seed_off`로 화면마다 무늬를 조금 다르게.
static func paint_backdrop(ci: CanvasItem, size: Vector2, seed_off: int = 0) -> void:
	ci.draw_polygon(PackedVector2Array([
		Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y),
	]), PackedColorArray([SKY, SKY, SKY_DEEP, SKY_DEEP]))
	# 결정적(deterministic) 배치 — 매 프레임 같은 자리에 찍힌다.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260813 + seed_off
	var cols := maxi(4, int(size.x / 190.0))
	var rows := maxi(4, int(size.y / 190.0))
	for gy in rows + 1:
		for gx in cols + 1:
			var jitter := Vector2(rng.randf_range(-52.0, 52.0), rng.randf_range(-52.0, 52.0))
			var at := Vector2((gx + 0.5) * size.x / cols, (gy + 0.5) * size.y / rows) + jitter
			paw(ci, at, rng.randf_range(22.0, 34.0), SKY_PAW,
					rng.randf_range(-0.5, 0.5))


## 발바닥 도장 하나 (큰 발볼 + 발가락 4개).
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
static func block_text(ci: CanvasItem, at: Vector2, text: String, cell: float,
		gap: float = 0.0, colors: Array = LOGO_COLORS) -> float:
	var x := at.x
	var idx := 0
	for i in text.length():
		var g: Array = GLYPHS.get(text[i].to_upper(), GLYPHS[" "])
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
static func block_text_width(text: String, cell: float, gap: float = 0.0) -> float:
	if text.is_empty():
		return 0.0
	return text.length() * (3.0 * (cell + gap) + cell * 0.45) - cell * 0.45


# --- 텍스트 -------------------------------------------------------------------


## 가운데 정렬 텍스트 (지정 폭 기준). 그린 폭을 돌려준다.
static func center_text(ci: CanvasItem, text: String, at_y: float, width: float,
		size: int, col: Color, x0: float = 0.0) -> float:
	var font := ThemeDB.fallback_font
	size = fit_size(font, text, width, size)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font, Vector2(x0 + (width - w) / 2.0, at_y), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	return w


## 잉크 외곽선을 두른 가운데 정렬 텍스트 (밝은 배경 위 강조용).
static func center_text_outlined(ci: CanvasItem, text: String, at_y: float,
		width: float, size: int, col: Color, x0: float = 0.0,
		outline: int = 8) -> void:
	var font := ThemeDB.fallback_font
	size = fit_size(font, text, width, size)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(x0 + (width - w) / 2.0, at_y)
	ci.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			outline, INK)
	ci.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## 주어진 폭에 들어가는 가장 큰 글자 크기 (최소 min_size까지 줄인다).
## _draw()로 직접 그리는 텍스트는 자동 축소가 없으므로, 번역이 길어질 수 있는
## 문구는 반드시 이걸 거쳐서 그린다. (/i18n 철칙 5)
static func fit_size(font: Font, text: String, width: float, size: int,
		min_size: int = 11) -> int:
	while size > min_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, size).x > width:
		size -= 1
	return size


## 통조림 캔 아이콘 — 재화 표시가 늘 같은 그림이 되도록 여기 한 곳에서 그린다.
## `at`은 캔의 중심, `h`는 캔 높이 (폭은 h * 0.78).
static func can_icon(ci: CanvasItem, at: Vector2, h: float,
		outline := true) -> void:
	var w := h * 0.78
	var body := Rect2(at.x - w / 2.0, at.y - h / 2.0 + h * 0.12, w, h * 0.82)
	var lid := Vector2(w / 2.0, h * 0.15)
	var ink := Color(INK, 1.0 if outline else 0.0)
	ci.draw_rect(body, CAN)
	# 라벨 띠 — 캔이라는 걸 한눈에 알게 하는 붉은 가로줄.
	ci.draw_rect(Rect2(body.position.x, at.y - h * 0.12, w, h * 0.34), CAN_LABEL)
	# 세로 하이라이트 (금속 광택은 늘 왼쪽 위에서).
	ci.draw_rect(Rect2(body.position.x + w * 0.16, body.position.y,
			w * 0.13, body.size.y), Color(1, 1, 1, 0.35))
	ellipse(ci, Vector2(at.x, body.end.y), lid, CAN_DEEP)
	ellipse(ci, Vector2(at.x, body.position.y), lid, WHITE)
	if outline:
		ci.draw_rect(body, ink, false, maxf(1.5, h * 0.06))
		var pts := PackedVector2Array()
		for i in 25:
			var a := TAU * i / 24.0
			pts.append(Vector2(at.x, body.position.y)
					+ Vector2(cos(a) * lid.x, sin(a) * lid.y))
		ci.draw_polyline(pts, ink, maxf(1.5, h * 0.06))
