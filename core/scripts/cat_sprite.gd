extends RefCounted
## 컨셉 시트(`리소스/CATTRIS_Char_Sheet.png`) 스프라이트 렌더러.
##
## 시트에서 뽑은 에셋은 `tools/extract_cat_sheet.py`가 만든다:
##   shared/assets/cats/char0N_tT.png        캐릭터 6종 × 파츠 해금 4단계 완성 렌더
##   shared/assets/cats/gray/char0N_tT.png   같은 그림의 회청색 램프 (잠금 실루엣·사망)
##   shared/assets/cats/parts/char0N/*.png   캐릭터별 파츠 레이어 (틴트 대상은 단색 마스크)
##   core/scripts/cat_layouts.gd             그 레이어들의 배치 좌표·기본색·해금 단계
##
## 부위 색을 갈아끼울 때만 배치표대로 레이어를 겹쳐 그리고, 그럴 필요가 없으면
## 완성 렌더 한 장을 그대로 쓴다 (훨씬 싸다).
## (class_name 없이 preload로 참조 — 전역 클래스 캐시 갱신 불필요)

const DIR := "res://shared/assets/cats/"
## 캐릭터별 파츠 레이어 배치표 — 시트에서 구워 낸 자동 생성 파일.
const CatLayouts := preload("res://core/scripts/cat_layouts.gd")

const CANVAS := CatLayouts.CANVAS  # 완성 렌더 한 장의 크기
## 캔버스 안에서 "고양이_몸통_아웃라인"이 차지하는 칸 — 코드 렌더의 몸통 사각형과 맞춘다.
const BODY := CatLayouts.BODY
const TIER_MAX := 3
## 완성 렌더에서 얼굴(귀 아래 ~ 입 언저리)만 오려 내는 영역 — 키캡 아트에 쓴다.
const FACE := Rect2(BODY.position.x + 18.0, BODY.position.y + 16.0, 194.0, 150.0)

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


## 키캡 등 "이 캐릭터 얼굴"만 필요한 곳이 쓰는 기본 텍스처 (t0 완성 렌더).
static func face_texture(char_id: String) -> Texture2D:
	return _load(DIR + "%s_t0.png" % char_id)


## 파츠 레이어가 준비된 캐릭터인가 (= 부위별 색을 갈아끼울 수 있는가).
static func is_layered(char_id: String) -> bool:
	return CatLayouts.LAYOUTS.has(char_id)


## 캔버스 좌표 → 화면 좌표 변환. 몸통 아웃라인의 가로폭이 s, 바닥이 코드 렌더의
## 몸통 사각형 아랫변과 맞도록 스케일·원점을 잡는다.
static func _place(center: Vector2, s: float) -> Transform2D:
	var k := s / BODY.size.x
	var org := Vector2(center.x - (BODY.position.x + BODY.size.x * 0.5) * k,
			center.y + s * 0.5 - (BODY.position.y + BODY.size.y) * k)
	return Transform2D(0.0, Vector2(k, k), 0.0, org)


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
	for l: Dictionary in CatLayouts.LAYOUTS[char_id]:
		if not (tier in (l.tiers as Array)):
			continue
		var tex := _load(base + "%s.png" % l.n)
		if tex == null:
			continue
		var col: Color = l.tint
		if bool(l.recolor) and tints.has(l.n):
			col = tints[l.n]
		if col.a <= 0.0:
			col = Color.WHITE  # 원본 색 그대로 (틴트 없음)
		ci.draw_texture_rect(tex, Rect2(tf.origin + (l.at as Vector2) * k,
				Vector2(tex.get_size()) * k), false, col)
		drawn = true
	return drawn


## 캐릭터 배치표에서 레이어 하나를 찾는다 (없으면 빈 사전).
static func find_layer(char_id: String, name: String) -> Dictionary:
	for l: Dictionary in CatLayouts.LAYOUTS.get(char_id, []):
		if str(l.n) == name:
			return l
	return {}


## 여러 냥이의 파츠 레이어를 섞어 한 마리를 그린다 — "나만의 캐릭터"가 쓴다.
## mix   : 레이어 이름 → 그 그림을 빌려올 캐릭터 id (없는 레이어는 그리지 않는다).
## tints : 레이어 이름 → 덮어쓸 색 (recolor 레이어만).
## 캔버스 좌표계가 6종 공통이라 서로 다른 냥이의 파츠도 그대로 겹쳐진다.
static func paint_mix(ci: CanvasItem, center: Vector2, s: float, mix: Dictionary,
		tints: Dictionary = {}, alive := true) -> bool:
	var tf := _place(center, s)
	var k: Vector2 = tf.get_scale()
	var items: Array[Dictionary] = []
	for name: String in mix:
		var l := find_layer(str(mix[name]), name)
		if not l.is_empty():
			items.append({"l": l, "c": str(mix[name])})
	# 시트의 레이어 번호로 정렬 — 6종이 같은 번호 체계를 쓴다.
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int((a.l as Dictionary).layer) < int((b.l as Dictionary).layer))
	var drawn := false
	for it in items:
		var l: Dictionary = it.l
		var tex := _load(DIR + "parts/%s/%s.png" % [it.c, l.n])
		if tex == null:
			continue
		var col: Color = l.tint
		if bool(l.recolor) and tints.has(str(l.n)):
			col = tints[str(l.n)]
		if col.a <= 0.0:
			col = Color.WHITE  # 원본 색 그대로
		if not alive:
			col = _ashen(col)
		ci.draw_texture_rect(tex, Rect2(tf.origin + (l.at as Vector2) * k,
				Vector2(tex.get_size()) * k), false, col)
		drawn = true
	return drawn


## 사망·잠금용 회청색 램프 — gray/ 완성 렌더와 같은 톤으로 눌러 준다.
static func _ashen(col: Color) -> Color:
	var g := col.get_luminance()
	return Color(g * 0.70 + 0.10, g * 0.74 + 0.13, g * 0.79 + 0.17, col.a)
