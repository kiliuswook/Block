extends RefCounted
## 컨셉 시트(`리소스/1.png`) 스프라이트 렌더러.
##
## 시트에서 뽑은 에셋은 `tools/extract_cat_sheet.py`가 만든다:
##   shared/assets/cats/char0N_tT.png        캐릭터 6종 × 파츠 해금 4단계 완성 렌더
##   shared/assets/cats/gray/char0N_tT.png   같은 그림의 회청색 램프 (잠금 실루엣·사망)
##   shared/assets/cats/parts/char01/*.png   Char01의 파츠 레이어 (틴트 대상은 흰 마스크)
##
## 레이어가 있는 캐릭터는 LAYERS 스펙대로 겹쳐 그려 부위별 색을 갈아끼울 수 있고,
## 아직 레이어 아트가 없는 캐릭터는 완성 렌더 한 장을 그대로 쓴다.
## 좌표는 전부 시트 메타데이터(배치 기준 레이어 + 좌상단 오프셋)를 그대로 옮긴 것.
## (class_name 없이 preload로 참조 — 전역 클래스 캐시 갱신 불필요)

const DIR := "res://shared/assets/cats/"
const CANVAS := Vector2(261.0, 293.0)  # 완성 렌더 한 장의 크기
## 캔버스 안에서 "고양이_몸통_아웃라인"이 차지하는 칸 — 코드 렌더의 몸통 사각형과 맞춘다.
const BODY := Rect2(10.0, 42.0, 194.0, 242.0)
const TIER_MAX := 3

## 파츠 레이어가 준비된 캐릭터. 나머지는 완성 렌더로 폴백.
const LAYERED := ["char01"]

## 시트의 레이어 메타데이터 그대로 (번호가 클수록 위).
## anchor = 배치 기준 레이어("" = 캔버스 원점), at = 그 기준 좌상단에서의 오프셋,
## tint = 기본 색상(알파 0이면 원본 색 그대로), recolor = 커스터마이징으로 색 변경 가능,
## tier = 이 레이어가 붙는 해금 단계.
const LAYERS: Array[Dictionary] = [
	{"n": "Cat_Tail_SkinFill", "layer": 10, "anchor": "Cat_Body_Outline", "at": Vector2(162, 156),
		"tint": Color("fbfbf8"), "recolor": true, "tier": 3},
	{"n": "Cat_Tail_Pattern", "layer": 11, "anchor": "Cat_Body_Outline", "at": Vector2(200, 155),
		"tint": Color("fdbe03"), "recolor": true, "tier": 3},
	{"n": "Cat_Tail_Outline", "layer": 12, "anchor": "Cat_Body_Outline", "at": Vector2(158, 152),
		"tint": Color("000000"), "recolor": false, "tier": 3},
	{"n": "Cat_Body_SkinFill", "layer": 20, "anchor": "Cat_Body_Outline", "at": Vector2(-1, 2),
		"tint": Color("fbfbf8"), "recolor": true, "tier": 0},
	{"n": "Cat_Body_Pattern", "layer": 21, "anchor": "Cat_Body_Outline", "at": Vector2(0, 1),
		"tint": Color("fdbe03"), "recolor": true, "tier": 0},
	{"n": "Cat_Body_Outline", "layer": 22, "anchor": "", "at": Vector2(0, 0),
		"tint": Color("000000"), "recolor": false, "tier": 0},
	{"n": "Cat_Prop_Belly", "layer": 30, "anchor": "Cat_Body_Outline", "at": Vector2(60, 169),
		"tint": Color(0, 0, 0, 0), "recolor": false, "tier": 1},
	{"n": "Cat_Feet_SkinFill", "layer": 40, "anchor": "Cat_Body_Outline", "at": Vector2(-5, 173),
		"tint": Color("fbfbf8"), "recolor": true, "tier": 0},
	{"n": "Cat_Feet_Pawpad", "layer": 41, "anchor": "Cat_Body_Outline", "at": Vector2(9, 188),
		"tint": Color("fe856d"), "recolor": true, "tier": 0},
	{"n": "Cat_Feet_Outline", "layer": 42, "anchor": "Cat_Body_Outline", "at": Vector2(-5, 173),
		"tint": Color("000000"), "recolor": false, "tier": 0},
	{"n": "Cat_Cheek", "layer": 50, "anchor": "Cat_Body_Outline", "at": Vector2(40, 117),
		"tint": Color("feb8ad"), "recolor": true, "tier": 0},
	{"n": "Cat_Whiskers", "layer": 51, "anchor": "Cat_Body_Outline", "at": Vector2(15, 108),
		"tint": Color("000000"), "recolor": true, "tier": 0},
	{"n": "Cat_Mouse", "layer": 52, "anchor": "Cat_Body_Outline", "at": Vector2(80, 115),
		"tint": Color("000000"), "recolor": true, "tier": 0},
	{"n": "Cat_Eyes_Color", "layer": 61, "anchor": "Cat_Body_Outline", "at": Vector2(47, 87),
		"tint": Color("000000"), "recolor": true, "tier": 0},
	{"n": "Cat_Eyes_Highlight", "layer": 62, "anchor": "Cat_Eyes_Color", "at": Vector2(4, 3),
		"tint": Color("ffffff"), "recolor": false, "tier": 0},
	{"n": "Prop_Head", "layer": 85, "anchor": "Cat_Body_Outline", "at": Vector2(56, -31),
		"tint": Color(0, 0, 0, 0), "recolor": false, "tier": 2},
]

static var _tex: Dictionary = {}  # 경로 → Texture2D (없으면 null 캐시)


static func _load(path: String) -> Texture2D:
	if _tex.has(path):
		return _tex[path]
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex[path] = t
	return t


## 이 캐릭터를 스프라이트로 그릴 수 있는가.
static func has(char_id: String) -> bool:
	return _load(DIR + "%s_t0.png" % char_id) != null


static func is_layered(char_id: String) -> bool:
	return char_id in LAYERED


## 캔버스 좌표 → 화면 좌표 변환. 몸통 아웃라인의 가로폭이 s, 바닥이 코드 렌더의
## 몸통 사각형 아랫변과 맞도록 스케일·원점을 잡는다.
static func _place(center: Vector2, s: float) -> Transform2D:
	var k := s / BODY.size.x
	var org := Vector2(center.x - (BODY.position.x + BODY.size.x * 0.5) * k,
			center.y + s * 0.5 - (BODY.position.y + BODY.size.y) * k)
	return Transform2D(0.0, Vector2(k, k), 0.0, org)


## 레이어 배치 좌표를 캔버스 좌표로 푼다 (anchor 체인 해석).
static func _anchor(name: String) -> Vector2:
	for l in LAYERS:
		if l.n != name:
			continue
		var at: Vector2 = l.at
		return at if l.anchor == "" else _anchor(str(l.anchor)) + at
	return Vector2.ZERO


## 스프라이트로 고양이를 그린다. 그릴 수 없으면 false (호출부가 코드 렌더로 폴백).
## tints: 레이어 이름 → 덮어쓸 색 (레이어 아트가 있는 캐릭터만 적용).
static func paint(ci: CanvasItem, center: Vector2, s: float, char_id: String,
		tier: int, alive := true, tints: Dictionary = {}) -> bool:
	tier = clampi(tier, 0, TIER_MAX)
	if is_layered(char_id) and alive and not tints.is_empty():
		return _paint_layers(ci, center, s, char_id, tier, tints)
	var sub := "gray/" if not alive else ""
	var tex := _load(DIR + "%s%s_t%d.png" % [sub, char_id, tier])
	if tex == null:
		return false
	var tf := _place(center, s)
	ci.draw_texture_rect(tex, Rect2(tf.origin, CANVAS * tf.get_scale()), false)
	return true


static func _paint_layers(ci: CanvasItem, center: Vector2, s: float, char_id: String,
		tier: int, tints: Dictionary) -> bool:
	var base := DIR + "parts/%s/" % char_id
	var tf := _place(center, s)
	var k: Vector2 = tf.get_scale()
	var drawn := false
	for l in LAYERS:
		if int(l.tier) > tier:
			continue
		var tex := _load(base + "%s.png" % l.n)
		if tex == null:
			continue
		var col: Color = l.tint
		if bool(l.recolor) and tints.has(l.n):
			col = tints[l.n]
		if col.a <= 0.0:
			col = Color.WHITE  # 원본 색 그대로 (틴트 없음)
		var at: Vector2 = BODY.position + _anchor(str(l.n))
		ci.draw_texture_rect(tex, Rect2(tf.origin + at * k, Vector2(tex.get_size()) * k),
				false, col)
		drawn = true
	return drawn
