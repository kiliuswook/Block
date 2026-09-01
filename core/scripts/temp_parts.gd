extends RefCounted
## ══════════════════════════════════════════════════════════════════════════════
## [임시 · 진짜 파츠 아트가 나오면 통째로 제거] 커스터마이징용 임시 파츠 카탈로그
## ------------------------------------------------------------------------------
## 정식 파츠 카탈로그(custom_cat.gd의 PARTS)는 "컨셉 시트에 그림이 있는 것만" 담는다.
## 그래서 꾸미기 선택지가 부위마다 2~6개뿐이다. 여기 있는 임시 파츠는 그 자리를
## 채우려고 **코드 렌더러(cat_art.gd)가 이미 그릴 줄 아는 모양**을 부위마다 5~6개씩
## 더 꺼내 놓은 것이다. 시트 그림이 없으므로:
##   · 시트/믹스로 그려지는 냥이 위에는 cat_art.gd가 **코드로 얹어** 그린다.
##   · 귀 모양(ear_shape)만은 몸 실루엣을 정하는 자리라 얹을 수 없어서,
##     고르면 그 냥이 전체가 코드 렌더로 떨어진다 (CODE_RENDER_SLOTS).
## 임시 파츠도 다른 파츠처럼 꾸미기 화면에서 골드로 산다 (희귀도 r이 값이 된다).
##
## ※ 제거할 때: 이 파일 + custom_cat.gd의 parts_all()/groups_all()/TempParts 참조 +
##    cat_art.gd의 "[임시] 임시 파츠 오버레이" 블록을 지우면 된다.
##    (세이브에 남은 옵션 index는 범위를 벗어나면 자동으로 0 = 기본값이 된다.)
## (class_name 없이 preload로 참조 — 전역 클래스 캐시 갱신 불필요)
## ══════════════════════════════════════════════════════════════════════════════

## 이 부위를 고르면 시트 위에 얹을 수 없어 냥이 전체가 코드 렌더로 떨어진다.
const CODE_RENDER_SLOTS: Array[String] = ["ear_shape"]

## 시트에 그림이 없어 코드로 얹어야 하는 부위 (그리는 순서 = 시트 레이어 순서).
const BEHIND_SLOTS: Array[String] = ["back", "tail"]
const FRONT_SLOTS: Array[String] = ["pattern", "hold", "chest", "neck", "whisker",
		"mouth", "nose", "eyes", "mark", "face", "head"]

## 기존 부위에 얹는 임시 옵션 {부위 key: [옵션]}.
## id는 cat_art.gd가 이미 아는 이름이거나("new" 없음), 아래 _paint_new()가
## 직접 그리는 임시 모양("new": true)이다.
const STYLES: Dictionary = {
	"back": [
		{"id": "cape", "name": "망토", "r": 1, "d": "[임시] 펄럭이는 붉은 망토."},
		{"id": "wings", "name": "천사 날개", "r": 2, "d": "[임시] 하얀 깃털 날개."},
		{"id": "balloon", "name": "풍선", "r": 1, "d": "[임시] 둥실 떠 있는 풍선."},
		{"id": "jetpack", "name": "제트팩", "r": 2, "d": "[임시] 불을 뿜는 등짐."},
		{"id": "shell", "new": true, "name": "등껍질", "r": 1, "d": "[임시] 느긋한 거북 등껍질."},
		{"id": "backpack", "new": true, "name": "책가방", "d": "[임시] 등에 멘 책가방."},
	],
	"tail": [
		{"id": "up", "name": "쫑긋 꼬리", "d": "[임시] 하늘로 세운 꼬리."},
		{"id": "fluffy", "name": "복슬 꼬리", "r": 1, "d": "[임시] 풍성한 꼬리."},
		{"id": "flame", "name": "불꽃 꼬리", "r": 2, "d": "[임시] 타오르는 꼬리."},
		{"id": "long", "name": "긴 꼬리", "d": "[임시] 길게 늘어진 꼬리."},
		{"id": "heart", "name": "하트 꼬리", "r": 2, "d": "[임시] 끝이 하트."},
		{"id": "star", "name": "별 꼬리", "r": 2, "d": "[임시] 끝이 반짝인다."},
	],
	# 몸 실루엣을 정하는 자리 — 고르면 냥이 전체가 코드 렌더로 그려진다.
	"ear_shape": [
		{"id": "big", "name": "큰 귀", "d": "[임시] 크게 솟은 귀."},
		{"id": "chip", "name": "이 빠진 귀", "r": 1, "d": "[임시] 한쪽이 깨진 귀."},
		{"id": "tuft", "name": "술 귀", "r": 1, "d": "[임시] 끝에 술이 달린 귀."},
		{"id": "none", "name": "귀 없음", "d": "[임시] 귀를 지운다."},
	],
	"pattern": [
		{"id": "stripes", "name": "줄무늬", "d": "[임시] 등에 두른 줄무늬."},
		{"id": "spots", "name": "점박이", "d": "[임시] 동글동글 점무늬."},
		{"id": "tiger", "name": "호랑이", "r": 1, "d": "[임시] 굵은 호랑이 줄."},
		{"id": "cow", "name": "얼룩", "r": 1, "d": "[임시] 젖소 얼룩."},
		{"id": "socks", "name": "양말", "d": "[임시] 발끝만 다른 색."},
		{"id": "belly", "name": "배 무늬", "d": "[임시] 배만 밝은 색."},
	],
	"hold": [
		{"id": "fish", "name": "생선", "r": 1, "d": "[임시] 오늘의 전리품."},
		{"id": "yarn", "name": "털실공", "d": "[임시] 굴리기 좋은 실뭉치."},
		{"id": "controller", "name": "게임패드", "r": 1, "d": "[임시] 한 판 더."},
		{"id": "cookie", "new": true, "name": "쿠키", "d": "[임시] 초코칩 쿠키."},
		{"id": "flower", "new": true, "name": "꽃", "r": 1, "d": "[임시] 한 송이 꽃."},
		{"id": "can", "new": true, "name": "통조림", "d": "[임시] 참치 캔."},
	],
	"chest": [
		{"id": "heart_pin", "name": "하트 핀", "d": "[임시] 가슴팍 하트."},
		{"id": "gem_pin", "name": "보석 핀", "r": 2, "d": "[임시] 반짝이는 브로치."},
		{"id": "pocket", "name": "주머니", "d": "[임시] 앞주머니."},
		{"id": "medal", "new": true, "name": "메달", "r": 2, "d": "[임시] 1등 메달."},
		{"id": "star_pin", "new": true, "name": "별 배지", "r": 1, "d": "[임시] 별 모양 배지."},
		{"id": "patch", "new": true, "name": "헝겊 조각", "d": "[임시] 덧댄 헝겊."},
	],
	"neck": [
		{"id": "bell", "name": "방울", "r": 1, "d": "[임시] 딸랑거리는 방울."},
		{"id": "scarf", "name": "목도리", "r": 1, "d": "[임시] 포근한 목도리."},
		{"id": "bandana", "name": "반다나", "d": "[임시] 목에 두른 반다나."},
		{"id": "chain", "name": "체인", "r": 2, "d": "[임시] 굵은 금목걸이."},
		{"id": "pearl", "new": true, "name": "진주 목걸이", "r": 2, "d": "[임시] 알알이 진주."},
	],
	"whisker": [
		{"id": "thick", "name": "굵은 수염", "d": "[임시] 도톰한 수염."},
		{"id": "long", "name": "긴 수염", "d": "[임시] 길게 뻗은 수염."},
		{"id": "single", "name": "한 줄 수염", "d": "[임시] 한 가닥만."},
		{"id": "up", "name": "치켜올린 수염", "d": "[임시] 기세 좋은 수염."},
		{"id": "zig", "name": "지그재그 수염", "r": 1, "d": "[임시] 삐뚤빼뚤한 수염."},
	],
	"mouth": [
		{"id": "smile", "name": "방긋", "d": "[임시] 얌전한 미소."},
		{"id": "meow", "name": "야옹", "d": "[임시] 벌린 입."},
		{"id": "tongue", "name": "메롱", "r": 1, "d": "[임시] 혀를 내민 입."},
		{"id": "grin", "name": "씩 웃음", "d": "[임시] 장난기 어린 입."},
		{"id": "fang", "name": "송곳니", "r": 1, "d": "[임시] 뾰족한 덧니."},
		{"id": "pout", "name": "뾰로통", "d": "[임시] 삐친 입."},
	],
	"eyes": [
		{"id": "wink", "name": "윙크", "r": 1, "d": "[임시] 한쪽만 감은 눈."},
		{"id": "heart", "name": "하트눈", "r": 2, "d": "[임시] 반한 눈."},
		{"id": "uwu", "name": "웃는 눈", "d": "[임시] 기분 좋은 곡선."},
		{"id": "sparkle", "name": "반짝눈", "r": 2, "d": "[임시] 별이 쏟아지는 눈."},
		{"id": "angry", "name": "화난눈", "d": "[임시] 잔뜩 찌푸린 눈."},
		{"id": "spiral", "name": "빙글눈", "r": 1, "d": "[임시] 어질어질한 눈."},
	],
	"nose": [
		{"id": "heart", "name": "하트 코", "r": 1, "d": "[임시] 하트 모양 코."},
		{"id": "dot", "name": "점 코", "d": "[임시] 작고 동그란 코."},
		{"id": "square", "name": "네모 코", "d": "[임시] 각진 코."},
		{"id": "oval", "name": "동글 코", "d": "[임시] 통통한 코."},
		{"id": "clover", "name": "클로버 코", "r": 2, "d": "[임시] 세 잎 모양 코."},
		{"id": "shine", "name": "윤기 코", "r": 1, "d": "[임시] 반들거리는 코."},
	],
	"mark": [
		{"id": "star", "name": "별", "d": "[임시] 이마의 별."},
		{"id": "heart", "name": "하트", "d": "[임시] 이마의 하트."},
		{"id": "freckles", "name": "주근깨", "d": "[임시] 볼에 흩뿌린 점."},
		{"id": "diamond", "name": "다이아", "r": 1, "d": "[임시] 이마의 보석."},
		{"id": "lightning", "name": "번개", "r": 2, "d": "[임시] 이마의 번개."},
		{"id": "clover", "name": "클로버", "r": 1, "d": "[임시] 행운의 네 잎."},
	],
	"face": [
		{"id": "square_glasses", "name": "네모 안경", "d": "[임시] 각진 뿔테."},
		{"id": "visor", "name": "바이저", "r": 2, "d": "[임시] 빛나는 바이저."},
		{"id": "eyepatch", "name": "안대", "r": 1, "d": "[임시] 한쪽 눈 안대."},
		{"id": "monocle", "name": "외알 안경", "r": 2, "d": "[임시] 신사의 품격."},
		{"id": "mask", "name": "마스크", "d": "[임시] 입을 가린 마스크."},
		{"id": "mustache", "name": "콧수염", "r": 1, "d": "[임시] 붙인 콧수염."},
	],
	"head": [
		{"id": "beanie", "name": "비니", "d": "[임시] 뒤집어쓴 비니."},
		{"id": "ribbon", "name": "리본", "r": 1, "d": "[임시] 머리 위 리본."},
		{"id": "crown", "name": "왕관", "r": 3, "d": "[임시] 반짝이는 왕관."},
		{"id": "tophat", "name": "실크햇", "r": 2, "d": "[임시] 신사 모자."},
		{"id": "halo", "name": "천사링", "r": 3, "d": "[임시] 머리 위 고리."},
		{"id": "cap", "name": "야구모자", "d": "[임시] 챙 달린 모자."},
	],
}

## 팔레트에 덧붙이는 임시 색 (기존 색 뒤에 붙으므로 저장된 index는 안전하다).
const COLORS: Dictionary = {
	"body": ["a9dcc3", "bcd8f2", "f6a8bb", "cfc0e8", "f7e08a", "4a4750"],
	"ear": ["5fae8e", "6f9fd0", "d76b8a", "8f77c4", "d9b53f", "c05a24"],
	"pattern_col": ["a9dcc3", "f6a8bb", "cfc0e8", "f7e08a", "5aa8d8", "2e3350"],
	"eye_col": ["3fa66b", "2f6ab8", "b8433f", "8f5fd0", "26c6c6", "e06a9a"],
	"pad_col": ["f7a8c4", "c7b0e8", "9fd8c0", "f5d67a", "b8c4d4"],
	"cheek_col": ["f7c9a0", "c9e2f7", "e2c9f7", "f7f0a0", "d0f0c9"],
	"whisker_col": ["fdfbf8", "8f99a5", "f0c53a", "6f9fd0", "d76b8a"],
	"mouth_col": ["b8433f", "3fa66b", "2f6ab8", "8f5fd0", "fdfbf8"],
	"nose_col": ["f2c94c", "8f99a5", "b8433f", "9fd8c0", "cfc0e8"],
}

## 정식 카탈로그에 아예 없는 부위 — 기본 옵션(index 0)까지 여기서 만든다.
const NEW_PARTS: Array[Dictionary] = [
	{"key": "neck", "name": "CAT_PART_NECK", "type": "style", "base": [
		{"id": "none", "name": "없음", "d": "[임시] 목은 비워둔다."}]},
	{"key": "nose", "name": "CAT_PART_NOSE", "type": "style", "base": [
		{"id": "tri", "name": "기본 코", "d": "[임시] 시트의 기본 삼각 코."}]},
]

## 새 부위를 커스터마이저 화면에 앉히는 자리 (CustomCat.GROUPS와 같은 모양).
const GROUPS_EXTRA: Array[Dictionary] = [
	{"key": "g_neck", "name": "CAT_PART_NECK", "at": Vector2(0.0, 0.20),
		"zoom": 0.80, "parts": ["neck"], "after": "g_chest"},
]


## 이 부위·옵션이 임시 파츠인가.
static func owns(slot: String, id: String) -> bool:
	for opt: Dictionary in (STYLES.get(slot, []) as Array):
		if str(opt.id) == id:
			return true
	return false


## cat_art.gd가 모르는, 이 파일이 직접 그리는 모양인가.
static func is_new(slot: String, id: String) -> bool:
	for opt: Dictionary in (STYLES.get(slot, []) as Array):
		if str(opt.id) == id:
			return bool(opt.get("new", false))
	return false


## 시트 그림 위에 얹을 수 없어 코드 렌더로 떨어져야 하는 선택인가.
static func forces_code_render(parts: Dictionary) -> bool:
	for slot in CODE_RENDER_SLOTS:
		if owns(slot, str(parts.get(_key(slot), ""))):
			return true
	return false


## 이 파츠 묶음에서 "시트에 그림이 없어 코드로 얹어야 하는" 부위들 {부위: 옵션 id}.
static func overlay_of(parts: Dictionary) -> Dictionary:
	var out := {}
	for slot in BEHIND_SLOTS + FRONT_SLOTS:
		var id := str(parts.get(_key(slot), ""))
		if id != "" and owns(slot, id):
			out[slot] = id
	return out


## 부위 key → 파츠 묶음 안의 key (custom_cat.gd의 _parts_key와 같은 규칙).
static func _key(slot: String) -> String:
	match slot:
		"ear_shape":
			return "ear"
		"body":
			return "body_col"
		"ear":
			return "ear_col"
		_:
			return slot


# --- 이 파일이 직접 그리는 임시 모양 -------------------------------------------------
## cat_art.gd가 모르는 모양("new": true)만 여기서 그린다.
## 좌표 규칙은 cat_art.gd와 같다 — 몸통은 center ± s/2.


static func paint_new(ci: CanvasItem, center: Vector2, s: float, slot: String,
		id: String, line: float, ink: Color) -> void:
	match slot:
		"back":
			_new_back(ci, center, s, id, line, ink)
		"hold":
			_new_hold(ci, center, s, id, line, ink)
		"chest":
			_new_chest(ci, center, s, id, line, ink)
		"neck":
			_new_neck(ci, center, s, id, line, ink)


static func _new_back(ci: CanvasItem, center: Vector2, s: float, id: String,
		line: float, ink: Color) -> void:
	match id:
		"shell":
			_ellipse(ci, center + Vector2(0.0, s * 0.02), s * 0.72, s * 0.62,
					Color("7a9a4a"), line, ink)
			for k in 3:
				_ellipse(ci, center + Vector2((k - 1) * s * 0.34, -s * 0.10),
						s * 0.14, s * 0.12, Color("5d7a36"))
		"backpack":
			_rrect(ci, Rect2(center + Vector2(-s * 0.66, -s * 0.34),
					Vector2(s * 1.32, s * 0.86)), s * 0.16, Color("8a5a3c"), line, ink)
			for sg in [-1.0, 1.0]:
				_rrect(ci, Rect2(center + Vector2(sg * s * 0.56 - s * 0.07, -s * 0.30),
						Vector2(s * 0.14, s * 0.70)), s * 0.05,
						Color("a97a52"), line * 0.8, ink)


static func _new_hold(ci: CanvasItem, center: Vector2, s: float, id: String,
		line: float, ink: Color) -> void:
	var at := center + Vector2(0.0, s / 2.0 - s * 0.12)
	match id:
		"cookie":
			_disc(ci, at, s * 0.15, Color("d9a35c"), line, ink)
			for p in [Vector2(-0.05, -0.05), Vector2(0.06, -0.02), Vector2(-0.01, 0.06)]:
				ci.draw_circle(at + p * s, s * 0.026, Color("5a3320"))
		"flower":
			for k in 5:
				var a := TAU * k / 5.0 - PI / 2.0
				_disc(ci, at + Vector2.from_angle(a) * s * 0.10, s * 0.062,
						Color("f6a8bb"), line * 0.7, ink)
			_disc(ci, at, s * 0.055, Color("f7e08a"), line * 0.7, ink)
			ci.draw_line(at + Vector2(0.0, s * 0.09), at + Vector2(0.0, s * 0.22),
					Color("5c8a30"), line)
		"can":
			_rrect(ci, Rect2(at + Vector2(-s * 0.15, -s * 0.09),
					Vector2(s * 0.30, s * 0.20)), s * 0.04, Color("c9d2da"), line, ink)
			ci.draw_rect(Rect2(at + Vector2(-s * 0.15, -s * 0.03),
					Vector2(s * 0.30, s * 0.08)), Color("3fa6c6"))
			_ellipse(ci, at + Vector2(0.0, -s * 0.09), s * 0.15, s * 0.04,
					Color("e2e8ee"), line * 0.7, ink)


static func _new_chest(ci: CanvasItem, center: Vector2, s: float, id: String,
		line: float, ink: Color) -> void:
	var at := center + Vector2(s * 0.28, s * 0.24)
	match id:
		"medal":
			for sg in [-1.0, 1.0]:
				_poly(ci, PackedVector2Array([
					at + Vector2(sg * s * 0.02, -s * 0.13),
					at + Vector2(sg * s * 0.08, -s * 0.13),
					at + Vector2(sg * s * 0.05, -s * 0.02)]), Color("b8433f"), line * 0.6, ink)
			_disc(ci, at + Vector2(0.0, s * 0.03), s * 0.075, Color("f2c94c"), line * 0.8, ink)
			_star(ci, at + Vector2(0.0, s * 0.03), s * 0.04, Color("d9a12a"))
		"star_pin":
			_star(ci, at, s * 0.085, Color("f2c94c"))
			_star(ci, at, s * 0.045, Color("fff3d0"))
		"patch":
			_rrect(ci, Rect2(at + Vector2(-s * 0.08, -s * 0.08),
					Vector2(s * 0.16, s * 0.16)), s * 0.03, Color("c9a37a"), line * 0.8, ink)
			for k in 3:
				ci.draw_line(at + Vector2(-s * 0.08, -s * 0.05 + k * s * 0.05),
						at + Vector2(s * 0.08, -s * 0.05 + k * s * 0.05),
						Color(ink, 0.5), line * 0.4)


static func _new_neck(ci: CanvasItem, center: Vector2, s: float, id: String,
		line: float, ink: Color) -> void:
	var at := center + Vector2(0.0, s * 0.20)
	if id == "pearl":
		for k in 9:
			var t := (k / 8.0) * 2.0 - 1.0
			ci.draw_circle(at + Vector2(t * s * 0.30, absf(t) * -s * 0.05 + s * 0.03),
					s * 0.033, Color("fdfbf8"))
			ci.draw_arc(at + Vector2(t * s * 0.30, absf(t) * -s * 0.05 + s * 0.03),
					s * 0.033, 0.0, TAU, 12, Color(ink, 0.5), line * 0.35)


# --- 도형 헬퍼 (cat_art.gd와 같은 모양 — 이 파일만 지우면 되도록 따로 둔다) --------------


static var _box: StyleBoxFlat


static func _rrect(ci: CanvasItem, rect: Rect2, radius: float, fill: Color,
		line: float, ink: Color) -> void:
	if _box == null:
		_box = StyleBoxFlat.new()
		_box.anti_aliasing = true
	_box.set_corner_radius_all(maxi(1, int(radius)))
	_box.set_border_width_all(maxi(0, int(round(line))))
	_box.bg_color = fill
	_box.border_color = ink
	_box.draw(ci.get_canvas_item(), rect)


static func _poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color,
		line: float, ink: Color) -> void:
	ci.draw_colored_polygon(pts, fill)
	if line > 0.0:
		var loop := PackedVector2Array(pts)
		loop.append(pts[0])
		ci.draw_polyline(loop, ink, line)


static func _disc(ci: CanvasItem, at: Vector2, r: float, fill: Color,
		line: float, ink: Color) -> void:
	ci.draw_circle(at, r, fill)
	if line > 0.0:
		ci.draw_arc(at, r - line * 0.5, 0.0, TAU, 26, ink, line)


static func _ellipse(ci: CanvasItem, at: Vector2, rx: float, ry: float, fill: Color,
		line := 0.0, ink := Color("2c2a33")) -> void:
	var pts := PackedVector2Array()
	for k in 26:
		var a := TAU * k / 26.0
		pts.append(at + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, fill)
	if line > 0.0:
		var loop := PackedVector2Array(pts)
		loop.append(pts[0])
		ci.draw_polyline(loop, ink, line)


static func _star(ci: CanvasItem, at: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rad := r if i % 2 == 0 else r * 0.45
		var a := -PI / 2.0 + TAU * i / 10.0
		pts.append(at + Vector2.from_angle(a) * rad)
	ci.draw_colored_polygon(pts, col)
