extends RefCounted
## 큐브 고양이 레이어 렌더러 — 캐릭터 컨셉 시트(Char01~Char11)를 코드로 옮긴 것.
## 아트 시트의 레이어 순서를 그대로 따른다 (아래 → 위):
##   Prop_Back → Tail(SkinFill/Pattern/Outline) → Ear(뒤) →
##   Body(SkinFill/Pattern/Outline) → Ear 패치 → Prop_Belly → Prop_Chest →
##   Feet(SkinFill/Pawpad/Outline) → Cheek → Whiskers → Mouth → Nose →
##   Eyes(Base/Color/Highlight) → Deco_Forehead → Prop_Face → Prop_Head
##
## 모든 캐릭터는 "파츠 묶음"(parts 딕셔너리)일 뿐이라, 커스터마이저에서
## 아무 고양이의 파츠나 섞어 쓸 수 있다. 카탈로그는 custom_cat.gd.
##
## skin에 "sprite"(캐릭터 id)가 있으면 컨셉 시트에서 뽑은 실제 그림(cat_sprite.gd)을
## 먼저 시도하고, 그릴 수 없을 때만 아래 코드 렌더로 떨어진다.
## (class_name 없이 preload로 참조 — 전역 클래스 캐시 갱신 불필요)

const CatSprite := preload("res://core/scripts/cat_sprite.gd")

const INK := Color("2c2a33")  # 두꺼운 잉크 외곽선 (UI 키트와 동일 톤)
const DEAD_BODY := Color("a8a29a")
const DEAD_EAR := Color("7d7770")
const WHITE := Color("fffdf8")
const PAD := Color("f7a8a4")  # 발바닥 젤리 핑크
const BLUSH := Color("f6a0a0")

static var _box: StyleBoxFlat


## 외곽선 두께.
static func _w(s: float) -> float:
	return maxf(1.5, s * 0.048)


# --- 기본 도형 (채움 + 잉크 외곽선) ------------------------------------------------


static func _rrect(ci: CanvasItem, rect: Rect2, radius: float, fill: Color,
		line: float, ink: Color = INK) -> void:
	if _box == null:
		_box = StyleBoxFlat.new()
		_box.anti_aliasing = true
	_box.set_corner_radius_all(maxi(1, int(radius)))
	_box.set_border_width_all(maxi(0, int(round(line))))
	_box.bg_color = fill
	_box.border_color = ink
	_box.draw(ci.get_canvas_item(), rect)


static func _poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color,
		line: float, ink: Color = INK) -> void:
	ci.draw_colored_polygon(pts, fill)
	if line > 0.0:
		var loop := PackedVector2Array(pts)
		loop.append(pts[0])
		ci.draw_polyline(loop, ink, line)


static func _disc(ci: CanvasItem, at: Vector2, r: float, fill: Color,
		line: float, ink: Color = INK) -> void:
	ci.draw_circle(at, r, fill)
	if line > 0.0:
		ci.draw_arc(at, r - line * 0.5, 0.0, TAU, 26, ink, line)


static func ellipse(ci: CanvasItem, at: Vector2, rx: float, ry: float, fill: Color,
		line := 0.0, ink: Color = INK) -> void:
	var pts := PackedVector2Array()
	for k in 26:
		var a := TAU * k / 26.0
		pts.append(at + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, fill)
	if line > 0.0:
		var loop := PackedVector2Array(pts)
		loop.append(pts[0])
		ci.draw_polyline(loop, ink, line)


## 작은 하트 (볼·이마·코 등에 두루 쓰인다).
static func heart(ci: CanvasItem, at: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(at + Vector2(-r * 0.45, 0.0), r * 0.62, col)
	ci.draw_circle(at + Vector2(r * 0.45, 0.0), r * 0.62, col)
	ci.draw_colored_polygon(PackedVector2Array([
		at + Vector2(-r * 0.99, r * 0.25), at + Vector2(r * 0.99, r * 0.25),
		at + Vector2(0.0, r * 1.35),
	]), col)


## 사각 반짝임 (별눈·꼬리 끝·연출용).
static func sparkle(ci: CanvasItem, at: Vector2, r: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([
		at + Vector2(0.0, -r), at + Vector2(r * 0.28, 0.0),
		at + Vector2(0.0, r), at + Vector2(-r * 0.28, 0.0),
	]), col)
	ci.draw_colored_polygon(PackedVector2Array([
		at + Vector2(-r, 0.0), at + Vector2(0.0, r * 0.28),
		at + Vector2(r, 0.0), at + Vector2(0.0, -r * 0.28),
	]), col)


## 다섯 꼭짓점 별.
static func star5(ci: CanvasItem, at: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rad := r if i % 2 == 0 else r * 0.45
		var a := -PI / 2.0 + TAU * i / 10.0
		pts.append(at + Vector2.from_angle(a) * rad)
	ci.draw_colored_polygon(pts, col)


## 초승달.
static func moon(ci: CanvasItem, at: Vector2, r: float, col: Color, bg: Color) -> void:
	ci.draw_circle(at, r, col)
	ci.draw_circle(at + Vector2(r * 0.45, -r * 0.2), r * 0.88, bg)


# --- 파츠 해석 -------------------------------------------------------------------


## skin 딕셔너리에서 파츠 묶음을 꺼낸다 ("parts", 구버전 "custom" 모두 허용).
static func parts_of(skin: Dictionary) -> Dictionary:
	var p: Dictionary = skin.get("parts", skin.get("custom", {}))
	return p if p is Dictionary else {}


static func _sid(p: Dictionary, key: String, def: String) -> String:
	return str(p.get(key, def))


# --- 메인 -----------------------------------------------------------------------


## 큐브 고양이를 아무 CanvasItem에나 그린다.
## skin: {"body","ear","ink","parts"} — parts가 실제 외형을 결정한다.
static func paint(ci: CanvasItem, center: Vector2, s: float, look := 0.0,
		alive := true, mouth_open := false, skin: Dictionary = {}) -> void:
	var p := parts_of(skin)
	var half := s / 2.0
	var line := _w(s)
	var body_col: Color = p.get("body_col", skin.get("body", Color("f4e3c8")))
	var ear_col: Color = p.get("ear_col", skin.get("ear", Color("d9a05c")))
	if not alive:
		body_col = DEAD_BODY
		ear_col = DEAD_EAR
	var ink: Color = p.get("ink", skin.get("ink", INK))
	var body_rect := Rect2(center - Vector2.ONE * half, Vector2.ONE * s)

	# 컨셉 시트 스프라이트 우선 — 소품만 그 위에 코드로 얹는다.
	var sprite := str(skin.get("sprite", ""))
	var gray: bool = not alive or bool(skin.get("gray", false))
	# 나만의 캐릭터 — 여러 냥이의 시트 파츠 그림을 섞어 그린다.
	var mix: Dictionary = skin.get("mix", {})
	if not mix.is_empty() and CatSprite.paint_mix(ci, center, s, mix,
			skin.get("tints", {}), not gray):
		if not alive:
			_paint_dead_face(ci, center, s, line)
			return
		if bool(skin.get("gray", false)):
			return
		return
	if sprite != "" and CatSprite.paint(ci, center, s, sprite,
			int(skin.get("tier", CatSprite.TIER_MAX)), not gray,
			skin.get("tints", {})):
		if not alive:
			_paint_dead_face(ci, center, s, line)
			return
		if bool(skin.get("gray", false)):
			return
		return

	# Layer 6 — 등 소품 (망토·날개).
	if alive:
		_paint_back(ci, center, s, _sid(p, "back", "none"), line)
	# Layer 10~12 — 꼬리 (몸 뒤).
	var tail_col: Color = p.get("tail_col", ear_col)
	_paint_tail(ci, center, s, _sid(p, "tail", "curl"), tail_col, line, ink)
	# 귀 (몸 뒤로 솟은 부분).
	var ear_style := _sid(p, "ear", "round")
	_paint_ears(ci, center, s, ear_style, ear_col, line, ink)
	# Layer 20~22 — 몸통.
	_rrect(ci, body_rect, s * 0.26, body_col, line, ink)
	# Layer 21 — 무늬 / 얼굴 마스크.
	if alive:
		_paint_pattern(ci, center, s, p, body_col, line, ink)
	# 귀 안쪽 패치 (몸통 위 모서리).
	_paint_ear_patch(ci, center, s, ear_style, ear_col, ink)
	if alive:
		# Layer 30 / 35 — 손에 든 소품, 가슴 소품.
		_paint_hold(ci, center, s, _sid(p, "hold", "none"), line, ink)
		_paint_neck(ci, center, s, _sid(p, "neck", "none"), line, ink)
		_paint_chest(ci, center, s, _sid(p, "chest", "none"), line, ink)
	# Layer 40~42 — 앞발.
	_paint_feet(ci, center, s, p, body_col, line, ink, alive)
	if not alive:
		_paint_dead_face(ci, center, s, line)
		return
	# Layer 50 — 볼터치.
	_paint_cheek(ci, center, s, _sid(p, "cheek", "pink"),
			p.get("cheek_col", Color(BLUSH)))
	# Layer 51 — 수염.
	_paint_whisker(ci, center, s, _sid(p, "whisker", "basic"), body_col, ink,
			p.get("whisker_col", null))
	# Layer 52 — 입.
	_paint_mouth(ci, center, s, look, mouth_open, _sid(p, "mouth", "w"), body_col, ink,
			p.get("mouth_col", null))
	# Layer 53 — 코.
	_paint_nose(ci, center, s, look, _sid(p, "nose", "tri"),
			p.get("nose_col", Color("e58a86")))
	# Layer 60~63 — 눈.
	_paint_eyes(ci, center, s, look, _sid(p, "eyes", "oval"),
			p.get("eye_col", Color("2a2230")), body_col, line)
	# Layer 70 — 이마 장식.
	_paint_forehead(ci, center, s, _sid(p, "mark", "none"), body_col, ink)
	# Layer 80 — 얼굴 소품 (안경·선글라스·헤드셋·수면안대).
	_paint_face_prop(ci, center, s, _sid(p, "face", "none"), line, ink)
	# Layer 85 — 머리 소품 (모자·과일·리본).
	_paint_head_prop(ci, center, s, _sid(p, "head", "none"), line, ink)


static func _paint_dead_face(ci: CanvasItem, center: Vector2, s: float,
		line: float) -> void:
	var er := s * 0.075
	for sg in [-1.0, 1.0]:
		var c := center + Vector2(sg * s * 0.19, -s * 0.04)
		ci.draw_line(c + Vector2(-er, -er), c + Vector2(er, er), INK, line * 0.8)
		ci.draw_line(c + Vector2(er, -er), c + Vector2(-er, er), INK, line * 0.8)


# --- 귀 -------------------------------------------------------------------------


static func _paint_ears(ci: CanvasItem, center: Vector2, s: float, style: String,
		col: Color, line: float, ink: Color) -> void:
	var half := s / 2.0
	match style:
		"none":
			return
		"folded":
			# Char01 — 접힌 귀. 몸통 위에 덮이는 부분은 _paint_ear_patch에서.
			for sg in [-1.0, 1.0]:
				_poly(ci, PackedVector2Array([
					center + Vector2(sg * s * 0.10, -half + s * 0.06),
					center + Vector2(sg * s * 0.24, -half - s * 0.11),
					center + Vector2(sg * s * 0.52, -half - s * 0.02),
					center + Vector2(sg * s * 0.51, -half + s * 0.14),
				]), col, line, ink)
		"pointy":
			for sg in [-1.0, 1.0]:
				_poly(ci, PackedVector2Array([
					center + Vector2(sg * s * 0.07, -half + s * 0.04),
					center + Vector2(sg * s * 0.28, -half - s * 0.17),
					center + Vector2(sg * s * 0.50, -half + s * 0.04),
				]), col, line, ink)
		"big":
			for sg in [-1.0, 1.0]:
				_poly(ci, PackedVector2Array([
					center + Vector2(sg * s * 0.06, -half + s * 0.03),
					center + Vector2(sg * s * 0.22, -half - s * 0.22),
					center + Vector2(sg * s * 0.40, -half - s * 0.19),
					center + Vector2(sg * s * 0.50, -half + s * 0.03),
				]), col, line, ink)
		"chip":
			for sg in [-1.0, 1.0]:
				_poly(ci, PackedVector2Array([
					center + Vector2(sg * s * 0.18, -half + s * 0.02),
					center + Vector2(sg * s * 0.30, -half - s * 0.10),
					center + Vector2(sg * s * 0.42, -half + s * 0.02),
				]), col, line, ink)
		"tuft":
			for sg in [-1.0, 1.0]:
				_poly(ci, PackedVector2Array([
					center + Vector2(sg * s * 0.12, -half + s * 0.03),
					center + Vector2(sg * s * 0.26, -half - s * 0.20),
					center + Vector2(sg * s * 0.34, -half - s * 0.09),
					center + Vector2(sg * s * 0.40, -half - s * 0.18),
					center + Vector2(sg * s * 0.48, -half + s * 0.03),
				]), col, line, ink)
		_:  # "round"
			for sg in [-1.0, 1.0]:
				_poly(ci, PackedVector2Array([
					center + Vector2(sg * s * 0.08, -half + s * 0.04),
					center + Vector2(sg * s * 0.20, -half - s * 0.15),
					center + Vector2(sg * s * 0.38, -half - s * 0.15),
					center + Vector2(sg * s * 0.50, -half + s * 0.04),
				]), col, line, ink)


## 몸통 위로 덮이는 귀 안쪽 패치 (아트 시트의 키캡형 귀).
static func _paint_ear_patch(ci: CanvasItem, center: Vector2, s: float, style: String,
		col: Color, ink: Color) -> void:
	if style == "none":
		return
	var half := s / 2.0
	var inset := s * 0.12
	for sg in [-1.0, 1.0]:
		var pts := PackedVector2Array([
			center + Vector2(sg * (half - inset), -half + s * 0.03),
			center + Vector2(sg * (half - s * 0.40), -half + s * 0.03),
			center + Vector2(sg * (half - inset), -half + s * 0.32),
		])
		if style == "folded":
			pts = PackedVector2Array([
				center + Vector2(sg * (half - s * 0.02), -half + s * 0.02),
				center + Vector2(sg * (half - s * 0.44), -half + s * 0.02),
				center + Vector2(sg * (half - s * 0.36), -half + s * 0.26),
				center + Vector2(sg * (half - s * 0.04), -half + s * 0.22),
			])
		ci.draw_colored_polygon(pts, col)
	if style == "folded":
		# 접힌 귀는 몸통 위에서도 잉크 선으로 경계를 잡는다.
		for sg in [-1.0, 1.0]:
			ci.draw_line(center + Vector2(sg * (half - s * 0.44), -half + s * 0.02),
					center + Vector2(sg * (half - s * 0.36), -half + s * 0.26),
					ink, maxf(1.2, s * 0.03))
			ci.draw_line(center + Vector2(sg * (half - s * 0.36), -half + s * 0.26),
					center + Vector2(sg * (half - s * 0.04), -half + s * 0.22),
					ink, maxf(1.2, s * 0.03))


# --- 무늬 / 얼굴 마스크 -----------------------------------------------------------


static func _paint_pattern(ci: CanvasItem, center: Vector2, s: float, p: Dictionary,
		body_col: Color, line: float, ink: Color) -> void:
	var pc: Color = p.get("pattern_col", Color(0.4, 0.3, 0.25))
	var half := s / 2.0
	match _sid(p, "pattern", "none"):
		"none":
			pass
		"stripes":
			for i in [-1, 0, 1]:
				ci.draw_rect(Rect2(center + Vector2(i * s * 0.13 - s * 0.03,
						-half + s * 0.06), Vector2(s * 0.06, s * 0.16)), pc)
		"tabby_head":
			# Char03/Char06 — 이마의 짧은 줄 3개 + 옆머리 줄.
			for i in [-1, 0, 1]:
				var w := s * 0.055
				var h := s * (0.20 if i == 0 else 0.15)
				ci.draw_rect(Rect2(center + Vector2(i * s * 0.15 - w / 2.0,
						-half + s * 0.05), Vector2(w, h)), pc)
			for sg in [-1.0, 1.0]:
				for k in 2:
					ci.draw_line(center + Vector2(sg * (half - s * 0.03),
							-s * 0.02 + k * s * 0.17),
							center + Vector2(sg * (half - s * 0.20),
							s * 0.03 + k * s * 0.17), pc, s * 0.05)
		"tuxedo_face":
			# Char02 — 얼굴·가슴을 덮는 흰 바탕.
			_poly(ci, PackedVector2Array([
				center + Vector2(-s * 0.30, -s * 0.20),
				center + Vector2(-s * 0.16, -s * 0.30),
				center + Vector2(s * 0.16, -s * 0.30),
				center + Vector2(s * 0.30, -s * 0.20),
				center + Vector2(s * 0.34, half - s * 0.01),
				center + Vector2(-s * 0.34, half - s * 0.01),
			]), pc, 0.0)
			# 이마의 흰 갈매기 무늬.
			_poly(ci, PackedVector2Array([
				center + Vector2(-s * 0.05, -half + s * 0.04),
				center + Vector2(s * 0.05, -half + s * 0.04),
				center + Vector2(0.0, -s * 0.24),
			]), pc, 0.0)
		"siamese":
			# Char05 — 주둥이·눈가를 덮는 짙은 마스크.
			ellipse(ci, center + Vector2(0.0, s * 0.06), s * 0.24, s * 0.20, pc)
			for sg in [-1.0, 1.0]:
				ellipse(ci, center + Vector2(sg * s * 0.19, -s * 0.05),
						s * 0.13, s * 0.115, pc)
		"calico":
			ci.draw_circle(center + Vector2(-s * 0.28, -s * 0.22), s * 0.15, pc)
			ci.draw_circle(center + Vector2(-s * 0.16, -s * 0.30), s * 0.10, pc)
			ci.draw_circle(center + Vector2(s * 0.27, s * 0.20), s * 0.13, pc)
			ci.draw_circle(center + Vector2(s * 0.34, s * 0.10), s * 0.08, pc)
		"visor_face":
			# Char11 — 로봇냥 얼굴 판.
			_rrect(ci, Rect2(center + Vector2(-s * 0.34, -s * 0.20),
					Vector2(s * 0.68, s * 0.42)), s * 0.12, pc, line * 0.8, ink)
		"spots":
			ci.draw_circle(center + Vector2(-s * 0.30, s * 0.28), s * 0.09, pc)
			ci.draw_circle(center + Vector2(s * 0.32, -s * 0.26), s * 0.07, pc)
			ci.draw_circle(center + Vector2(s * 0.28, s * 0.32), s * 0.06, pc)
			ci.draw_circle(center + Vector2(-s * 0.33, -s * 0.30), s * 0.055, pc)
		"patch":
			ci.draw_circle(center + Vector2(s * 0.19, -s * 0.06), s * 0.16, pc)
		"tuxedo":
			_poly(ci, PackedVector2Array([
				center + Vector2(-s * 0.18, half - s * 0.03),
				center + Vector2(s * 0.18, half - s * 0.03),
				center + Vector2(0.0, s * 0.08),
			]), pc, 0.0)
		"socks":
			for sg in [-1.0, 1.0]:
				var x := -half + s * 0.05 if sg < 0.0 else half - s * 0.29
				ci.draw_rect(Rect2(center + Vector2(x, half - s * 0.13),
						Vector2(s * 0.24, s * 0.10)), pc)
		"forehead":
			_poly(ci, PackedVector2Array([
				center + Vector2(-half + s * 0.06, -half + s * 0.04),
				center + Vector2(0.0, -half + s * 0.04),
				center + Vector2(-s * 0.06, -s * 0.14),
				center + Vector2(-half + s * 0.06, -s * 0.05),
			]), pc, 0.0)
		"tabby":
			for sg in [-1.0, 1.0]:
				for k in 3:
					var y0 := -s * 0.1 + k * s * 0.16
					ci.draw_line(center + Vector2(sg * (half - s * 0.03), y0),
							center + Vector2(sg * (half - s * 0.22), y0 + s * 0.06),
							pc, s * 0.045)
		"tiger":
			for sg in [-1.0, 1.0]:
				for k in 2:
					ci.draw_rect(Rect2(center + Vector2(
							sg * (half - s * 0.13 - k * s * 0.17) - s * 0.03,
							-s * 0.06 + k * s * 0.08), Vector2(s * 0.06, s * 0.3)), pc)
		"cow":
			ci.draw_circle(center + Vector2(-s * 0.22, -s * 0.18), s * 0.13, pc)
			ci.draw_circle(center + Vector2(-s * 0.12, -s * 0.25), s * 0.09, pc)
			ci.draw_circle(center + Vector2(s * 0.24, s * 0.22), s * 0.12, pc)
			ci.draw_circle(center + Vector2(s * 0.32, s * 0.14), s * 0.08, pc)
		"heart_patch":
			heart(ci, center + Vector2(-s * 0.28, s * 0.24), s * 0.085, pc)
		"star_patch":
			sparkle(ci, center + Vector2(s * 0.29, s * 0.27), s * 0.12, pc)
		"lightning":
			var lp := center + Vector2(-s * 0.29, -s * 0.2)
			ci.draw_colored_polygon(PackedVector2Array([
				lp + Vector2(-s * 0.005, -s * 0.09), lp + Vector2(s * 0.05, -s * 0.09),
				lp + Vector2(s * 0.01, -s * 0.005), lp + Vector2(s * 0.05, -s * 0.005),
				lp + Vector2(-s * 0.035, s * 0.1), lp + Vector2(0.0, s * 0.005),
				lp + Vector2(-s * 0.04, s * 0.005),
			]), pc)
		"half":
			ci.draw_rect(Rect2(center + Vector2(-half + s * 0.06, -half + s * 0.06),
					Vector2(half - s * 0.06, s - s * 0.12)), Color(pc, 0.55))
		"diamond":
			var dp := center + Vector2(s * 0.28, s * 0.28)
			ci.draw_colored_polygon(PackedVector2Array([
				dp + Vector2(0.0, -s * 0.09), dp + Vector2(s * 0.07, 0.0),
				dp + Vector2(0.0, s * 0.09), dp + Vector2(-s * 0.07, 0.0),
			]), pc)
		"belly":
			ci.draw_circle(center + Vector2(0.0, s * 0.31), s * 0.19, pc)


# --- 꼬리 -----------------------------------------------------------------------


static func _tail_curve(root: Vector2, ctrl: Vector2, tip: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(13):
		var t := i / 12.0
		pts.append(root.lerp(ctrl, t).lerp(ctrl.lerp(tip, t), t))
	return pts


## 외곽선이 있는 꼬리 한 가닥.
static func _tail_stroke(ci: CanvasItem, root: Vector2, ctrl: Vector2, tip: Vector2,
		w: float, col: Color, line: float, ink: Color, tip_col: Color) -> void:
	var pts := _tail_curve(root, ctrl, tip)
	ci.draw_polyline(pts, ink, w + line)
	ci.draw_circle(tip, (w + line) * 0.55, ink)
	ci.draw_polyline(pts, col, w)
	ci.draw_circle(tip, w * 0.55, tip_col)


static func _paint_tail(ci: CanvasItem, center: Vector2, s: float, style: String,
		col: Color, line: float, ink: Color) -> void:
	if style == "none":
		return
	var tip := col.lightened(0.25)
	match style:
		"up":
			_tail_stroke(ci, center + Vector2(s * 0.44, s * 0.32),
					center + Vector2(s * 0.66, 0.0), center + Vector2(s * 0.58, -s * 0.42),
					s * 0.11, col, line, ink, tip)
		"fluffy":
			_tail_stroke(ci, center + Vector2(s * 0.42, s * 0.3),
					center + Vector2(s * 0.80, s * 0.12), center + Vector2(s * 0.68, -s * 0.26),
					s * 0.17, col, line, ink, tip)
		"stub":
			_tail_stroke(ci, center + Vector2(s * 0.43, s * 0.36),
					center + Vector2(s * 0.62, s * 0.3), center + Vector2(s * 0.64, s * 0.16),
					s * 0.13, col, line, ink, tip)
		"zigzag":
			var pts := PackedVector2Array([
				center + Vector2(s * 0.42, s * 0.32), center + Vector2(s * 0.68, s * 0.18),
				center + Vector2(s * 0.50, 0.0), center + Vector2(s * 0.72, -s * 0.18),
			])
			ci.draw_polyline(pts, ink, s * 0.1 + line)
			ci.draw_polyline(pts, col, s * 0.1)
			ci.draw_circle(pts[3], s * 0.065, tip)
		"long":
			_tail_stroke(ci, center + Vector2(s * 0.42, s * 0.34),
					center + Vector2(s * 1.0, s * 0.12), center + Vector2(s * 0.8, -s * 0.5),
					s * 0.1, col, line, ink, tip)
		"double":
			_tail_stroke(ci, center + Vector2(s * 0.42, s * 0.36),
					center + Vector2(s * 0.94, s * 0.24), center + Vector2(s * 0.9, -s * 0.18),
					s * 0.1, col, line, ink, tip)
			_tail_stroke(ci, center + Vector2(s * 0.42, s * 0.3),
					center + Vector2(s * 0.78, s * 0.1), center + Vector2(s * 0.66, -s * 0.3),
					s * 0.11, col, line, ink, tip)
		"heart":
			_tail_stroke(ci, center + Vector2(s * 0.42, s * 0.3),
					center + Vector2(s * 0.78, s * 0.1), center + Vector2(s * 0.66, -s * 0.3),
					s * 0.1, col, line, ink, col)
			heart(ci, center + Vector2(s * 0.66, -s * 0.34), s * 0.075,
					Color(0.95, 0.5, 0.6))
		"star":
			_tail_stroke(ci, center + Vector2(s * 0.42, s * 0.3),
					center + Vector2(s * 0.78, s * 0.1), center + Vector2(s * 0.66, -s * 0.3),
					s * 0.1, col, line, ink, col)
			sparkle(ci, center + Vector2(s * 0.66, -s * 0.35), s * 0.11,
					Color(1.0, 0.85, 0.4))
		"flame":
			_tail_stroke(ci, center + Vector2(s * 0.42, s * 0.3),
					center + Vector2(s * 0.78, s * 0.1), center + Vector2(s * 0.66, -s * 0.3),
					s * 0.12, col, line, ink, col)
			ci.draw_circle(center + Vector2(s * 0.66, -s * 0.34), s * 0.085,
					Color(0.95, 0.5, 0.2, 0.9))
			ci.draw_circle(center + Vector2(s * 0.665, -s * 0.37), s * 0.05,
					Color(1.0, 0.8, 0.3))
		"straight":
			_tail_stroke(ci, center + Vector2(s * 0.44, s * 0.3),
					center + Vector2(s * 0.7, s * 0.27), center + Vector2(s * 0.95, s * 0.25),
					s * 0.1, col, line, ink, tip)
		"question":
			_tail_stroke(ci, center + Vector2(s * 0.48, s * 0.1),
					center + Vector2(s * 0.9, -s * 0.35), center + Vector2(s * 0.52, -s * 0.38),
					s * 0.09, col, line, ink, tip)
			_disc(ci, center + Vector2(s * 0.52, s * 0.28), s * 0.055, col, line, ink)
		"ring":
			var root := center + Vector2(s * 0.42, s * 0.3)
			var ctrl := center + Vector2(s * 0.78, s * 0.1)
			var rtip := center + Vector2(s * 0.66, -s * 0.3)
			_tail_stroke(ci, root, ctrl, rtip, s * 0.11, col, line, ink, tip)
			for t in [0.42, 0.72]:
				var pt := root.lerp(ctrl, t).lerp(ctrl.lerp(rtip, t), t)
				ci.draw_circle(pt, s * 0.052, col.darkened(0.35))
		_:  # "curl" — 컨셉 시트의 기본 꼬리 (오른쪽으로 말려 올라간다).
			_tail_stroke(ci, center + Vector2(s * 0.42, s * 0.30),
					center + Vector2(s * 0.80, s * 0.14), center + Vector2(s * 0.66, -s * 0.26),
					s * 0.11, col, line, ink, tip)


# --- 앞발 -----------------------------------------------------------------------


static func _paint_feet(ci: CanvasItem, center: Vector2, s: float, p: Dictionary,
		body_col: Color, line: float, ink: Color, alive: bool) -> void:
	var style := _sid(p, "feet", _sid(p, "paws", "beans"))
	if style == "none":
		return
	var half := s / 2.0
	var fill: Color = p.get("foot_col", body_col.lightened(0.18))
	if not alive:
		fill = DEAD_BODY.lightened(0.15)
	var pad: Color = p.get("pad_col", PAD)
	var r := s * 0.115
	if style == "boots":
		for sg in [-1.0, 1.0]:
			_rrect(ci, Rect2(center + Vector2(sg * s * 0.26 - s * 0.11, half - s * 0.15),
					Vector2(s * 0.22, s * 0.17)), s * 0.05,
					Color("8c4a3a"), line * 0.8, ink)
			ci.draw_rect(Rect2(center + Vector2(sg * s * 0.26 - s * 0.11, half - s * 0.16),
					Vector2(s * 0.22, s * 0.04)), Color("f0e6d8"))
		return
	if style == "mittens":
		fill = Color("fbf7ef")
	if style == "socks":
		fill = Color("fbf7ef")
	for sg in [-1.0, 1.0]:
		var at := center + Vector2(sg * s * 0.26, half - s * 0.05)
		_disc(ci, at, r, fill, line * 0.85, ink)
		match style:
			"plain", "mittens", "socks":
				pass
			"heart_beans":
				heart(ci, at + Vector2(0.0, s * 0.005), s * 0.042, pad)
			"star_beans":
				sparkle(ci, at, s * 0.055, Color(1.0, 0.85, 0.4, 0.95))
			_:  # "beans" — 아트 시트의 기본 젤리 발바닥.
				ellipse(ci, at + Vector2(0.0, s * 0.022), s * 0.046, s * 0.036, pad)
				for i in [-1, 0, 1]:
					ci.draw_circle(at + Vector2(i * s * 0.042, -s * 0.032),
							s * 0.019, pad)


# --- 볼 / 수염 -------------------------------------------------------------------


## 시트에서 뽑은 색(want)을 쓴다 — 단 몸 색과 명도 차가 없어 묻히면 fallback.
static func _readable(want: Variant, fallback: Color, body_col: Color) -> Color:
	if want == null:
		return fallback
	var col: Color = want
	if absf(col.get_luminance() - body_col.get_luminance()) < 0.22:
		return fallback
	return Color(col, fallback.a)


static func _paint_cheek(ci: CanvasItem, center: Vector2, s: float, style: String,
		col := Color(BLUSH)) -> void:
	if style == "none":
		return
	var y := s * 0.08
	for sg in [-1.0, 1.0]:
		var at := center + Vector2(sg * s * 0.30, y)
		match style:
			"peach":
				ellipse(ci, at, s * 0.075, s * 0.05, Color(0.98, 0.72, 0.55, 0.55))
			"big":
				ci.draw_circle(at, s * 0.085, Color(0.95, 0.55, 0.55, 0.5))
			"line":
				for k in 3:
					ci.draw_line(at + Vector2(-s * 0.045 + k * s * 0.035, -s * 0.03),
							at + Vector2(-s * 0.02 + k * s * 0.035, s * 0.03),
							Color(0.94, 0.5, 0.52, 0.6), s * 0.022)
			"heart":
				heart(ci, at, s * 0.05, Color(0.95, 0.5, 0.6, 0.6))
			"star":
				sparkle(ci, at, s * 0.06, Color(1.0, 0.75, 0.45, 0.7))
			"blue":
				ci.draw_circle(at, s * 0.06, Color(0.5, 0.7, 0.95, 0.5))
			_:  # "pink"
				ellipse(ci, at, s * 0.07, s * 0.048, Color(col, 0.6))


static func _paint_whisker(ci: CanvasItem, center: Vector2, s: float, style: String,
		body_col: Color, ink: Color, want: Variant = null) -> void:
	if style == "none":
		return
	var col := Color(ink, 0.55)
	if body_col.get_luminance() < 0.42:
		col = Color(0.98, 0.97, 0.94, 0.7)
	col = _readable(want, col, body_col)
	var w := maxf(1.2, s * 0.024)
	match style:
		"thick":
			w = maxf(1.6, s * 0.038)
		"long":
			pass
	var reach := s * 0.13
	if style == "long":
		reach = s * 0.17
	for sg in [-1.0, 1.0]:
		var rows := [0.0, 1.0]
		if style == "single":
			rows = [0.5]
		elif style == "thick":
			rows = [0.0, 1.0]
		for k in rows:
			var y0: float = s * (0.02 + 0.09 * float(k))
			var x0: float = sg * s * 0.30
			var y1 := y0
			match style:
				"droop":
					y1 = y0 + s * 0.07
				"up":
					y1 = y0 - s * 0.07
				"zig":
					ci.draw_polyline(PackedVector2Array([
						center + Vector2(x0, y0),
						center + Vector2(x0 + sg * reach * 0.4, y0 - s * 0.04),
						center + Vector2(x0 + sg * reach * 0.7, y0 + s * 0.03),
						center + Vector2(x0 + sg * reach, y0 - s * 0.02),
					]), col, w)
					continue
				"curl":
					ci.draw_arc(center + Vector2(x0 + sg * reach * 0.5, y0),
							reach * 0.5, PI * 0.15, PI * 0.95, 10, col, w)
					continue
				"spark":
					ci.draw_polyline(PackedVector2Array([
						center + Vector2(x0, y0),
						center + Vector2(x0 + sg * reach * 0.5, y0 - s * 0.05),
						center + Vector2(x0 + sg * reach * 0.75, y0 + s * 0.02),
						center + Vector2(x0 + sg * reach, y0 - s * 0.06),
					]), Color(0.55, 0.85, 1.0, 0.9), w)
					continue
			ci.draw_line(center + Vector2(x0, y0),
					center + Vector2(x0 + sg * reach, y1), col, w)


# --- 코 / 입 --------------------------------------------------------------------


static func _paint_nose(ci: CanvasItem, center: Vector2, s: float, look: float,
		style: String, col: Color) -> void:
	if style == "none":
		return
	var at := center + Vector2(look * 0.5, s * 0.045)
	match style:
		"heart":
			heart(ci, at, s * 0.03, col)
		"dot":
			ci.draw_circle(at, s * 0.026, col)
		"square":
			ci.draw_rect(Rect2(at + Vector2(-s * 0.03, -s * 0.02),
					Vector2(s * 0.06, s * 0.046)), col)
		"oval":
			ellipse(ci, at, s * 0.048, s * 0.026, col)
		"clover":
			ci.draw_circle(at + Vector2(-s * 0.022, s * 0.006), s * 0.02, col)
			ci.draw_circle(at + Vector2(s * 0.022, s * 0.006), s * 0.02, col)
			ci.draw_circle(at + Vector2(0.0, -s * 0.02), s * 0.02, col)
		"shine":
			ci.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-s * 0.042, -s * 0.016), at + Vector2(s * 0.042, -s * 0.016),
				at + Vector2(0.0, s * 0.036)]), col)
			ci.draw_circle(at + Vector2(-s * 0.012, -s * 0.006), s * 0.011,
					Color(1, 1, 1, 0.95))
		_:  # "tri"
			ci.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-s * 0.038, -s * 0.015), at + Vector2(s * 0.038, -s * 0.015),
				at + Vector2(0.0, s * 0.032)]), col)


static func _paint_mouth(ci: CanvasItem, center: Vector2, s: float, look: float,
		open: bool, style: String, body_col: Color, ink: Color,
		want: Variant = null) -> void:
	var col := Color(ink, 0.9)
	if body_col.get_luminance() < 0.42:
		col = Color(0.96, 0.94, 0.9, 0.9)
	col = _readable(want, col, body_col)
	var mc := center + Vector2(look * 0.5, s * 0.125)
	var w := maxf(1.3, s * 0.032)
	if open:
		ellipse(ci, mc + Vector2(0.0, s * 0.02), s * 0.055, s * 0.062, Color("d2716d"))
		ellipse(ci, mc + Vector2(0.0, s * 0.045), s * 0.03, s * 0.028, Color("f0a0a0"))
		return
	match style:
		"smile":
			ci.draw_arc(mc + Vector2(0.0, -s * 0.03), s * 0.075, 0.35, PI - 0.35, 12, col, w)
		"neutral":
			ci.draw_line(mc + Vector2(-s * 0.05, 0.0), mc + Vector2(s * 0.05, 0.0), col, w)
		"meow":
			ellipse(ci, mc + Vector2(0.0, s * 0.005), s * 0.06, s * 0.055, Color("d2716d"))
			ellipse(ci, mc + Vector2(0.0, s * 0.03), s * 0.03, s * 0.024, Color("f0a0a0"))
		"open_smile":
			# Char03 — 활짝 웃는 입.
			var pts := PackedVector2Array()
			for k in 13:
				var a: float = lerpf(0.0, PI, k / 12.0)
				pts.append(mc + Vector2(cos(PI - a) * s * 0.085, sin(a) * s * 0.075))
			pts.append(mc + Vector2(s * 0.085, 0.0))
			ci.draw_colored_polygon(pts, Color("d2716d"))
			ci.draw_polyline(pts, ink, w * 0.8)
			ci.draw_circle(mc + Vector2(0.0, s * 0.052), s * 0.028, Color("f2a8a8"))
		"tongue":
			ci.draw_arc(mc + Vector2(-s * 0.045, -s * 0.02), s * 0.05, 0.3, PI - 0.3, 8, col, w)
			ci.draw_arc(mc + Vector2(s * 0.045, -s * 0.02), s * 0.05, 0.3, PI - 0.3, 8, col, w)
			ci.draw_circle(mc + Vector2(0.0, s * 0.055), s * 0.042, Color("e58a86"))
		"frown":
			ci.draw_arc(mc + Vector2(0.0, s * 0.035), s * 0.07, PI + 0.4, TAU - 0.4, 10, col, w)
		"grin":
			ci.draw_arc(mc + Vector2(0.0, -s * 0.03), s * 0.1, 0.3, PI - 0.3, 12, col, w)
			for sg in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([
					mc + Vector2(sg * s * 0.055 - s * 0.018, s * 0.005),
					mc + Vector2(sg * s * 0.055 + s * 0.018, s * 0.005),
					mc + Vector2(sg * s * 0.055, s * 0.04)]), Color(1, 1, 1, 0.95))
		"fang":
			ci.draw_arc(mc + Vector2(-s * 0.045, -s * 0.02), s * 0.05, 0.3, PI - 0.3, 8, col, w)
			ci.draw_arc(mc + Vector2(s * 0.045, -s * 0.02), s * 0.05, 0.3, PI - 0.3, 8, col, w)
			ci.draw_colored_polygon(PackedVector2Array([
				mc + Vector2(s * 0.03, 0.0), mc + Vector2(s * 0.08, 0.0),
				mc + Vector2(s * 0.055, s * 0.05)]), Color(1, 1, 1, 0.95))
		"pout":
			ci.draw_arc(mc, s * 0.03, -PI / 2.0, PI * 1.5, 14, col, w)
		"yawn":
			# Char04 — 졸린 하품.
			ellipse(ci, mc + Vector2(0.0, s * 0.01), s * 0.045, s * 0.055, Color("d2716d"))
		"zigzag":
			ci.draw_polyline(PackedVector2Array([
				mc + Vector2(-s * 0.07, 0.0), mc + Vector2(-s * 0.035, s * 0.03),
				mc + Vector2(0.0, 0.0), mc + Vector2(s * 0.035, s * 0.03),
				mc + Vector2(s * 0.07, 0.0)]), col, w * 0.9)
		"whistle":
			ci.draw_arc(mc, s * 0.028, 0.0, TAU, 14, col, w * 0.9)
		"drool":
			ci.draw_arc(mc + Vector2(-s * 0.045, -s * 0.02), s * 0.05, 0.3, PI - 0.3, 8, col, w)
			ci.draw_arc(mc + Vector2(s * 0.045, -s * 0.02), s * 0.05, 0.3, PI - 0.3, 8, col, w)
			ci.draw_circle(mc + Vector2(s * 0.075, s * 0.05), s * 0.022,
					Color(0.6, 0.85, 1.0, 0.85))
		_:  # "w" — 컨셉 시트의 기본 야옹입.
			ci.draw_arc(mc + Vector2(-s * 0.042, -s * 0.02), s * 0.048, 0.25, PI - 0.25,
					9, col, w)
			ci.draw_arc(mc + Vector2(s * 0.042, -s * 0.02), s * 0.048, 0.25, PI - 0.25,
					9, col, w)


# --- 눈 -------------------------------------------------------------------------


static func _paint_eyes(ci: CanvasItem, center: Vector2, s: float, look: float,
		style: String, eye_col: Color, body_col: Color, line: float) -> void:
	var ex := s * 0.20
	var ey := -s * 0.055
	var er := s * 0.078
	var hl := Color(1, 1, 1, 0.95)
	match style:
		"oval":
			# 아트 시트 기본 — 세로로 긴 새까만 눈 + 흰 하이라이트 2개.
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ellipse(ci, c, er * 0.92, er * 1.18, eye_col)
				ci.draw_circle(c + Vector2(er * 0.3, -er * 0.45), er * 0.30, hl)
				ci.draw_circle(c + Vector2(-er * 0.28, er * 0.4), er * 0.15,
						Color(1, 1, 1, 0.6))
		"iris":
			# Char02 — 노란 홍채 + 검은 동공.
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ellipse(ci, c, er * 0.95, er * 1.15, eye_col)
				ellipse(ci, c, er * 0.42, er * 0.95, Color("241f28"))
				ci.draw_circle(c + Vector2(er * 0.34, -er * 0.5), er * 0.24, hl)
		"round":
			for sg in [-1.0, 1.0]:
				ci.draw_circle(center + Vector2(sg * ex + look, ey), er, eye_col)
		"squint":
			# Char03 — 기분 좋은 >< 눈.
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ci.draw_polyline(PackedVector2Array([
					c + Vector2(sg * er * 0.9, -er * 0.85), c + Vector2(-sg * er * 0.7, 0.0),
					c + Vector2(sg * er * 0.9, er * 0.85)]), eye_col, line * 0.75)
		"tired":
			# Char06 — 반쯤 감긴 눈.
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ci.draw_circle(c + Vector2(0.0, er * 0.2), er * 0.8, eye_col)
				ci.draw_rect(Rect2(c - Vector2(er * 1.1, er * 1.3),
						Vector2(er * 2.2, er * 1.15)), body_col)
				ci.draw_line(c + Vector2(-er * 1.0, -er * 0.15),
						c + Vector2(er * 1.0, -er * 0.15), eye_col, line * 0.7)
		"sleep":
			# Char04 — 곡선으로 감은 눈.
			for sg in [-1.0, 1.0]:
				ci.draw_arc(center + Vector2(sg * ex + look, ey - er * 0.2), er * 1.0,
						0.25, PI - 0.25, 12, eye_col, line * 0.75)
		"sparkle":
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ci.draw_circle(c, er * 1.15, eye_col)
				ci.draw_circle(c + Vector2(er * 0.35, -er * 0.35), er * 0.4, hl)
		"happy":
			for sg in [-1.0, 1.0]:
				ci.draw_arc(center + Vector2(sg * ex + look, ey + er * 0.4), er * 1.05,
						PI, TAU, 12, eye_col, line * 0.72)
		"sleepy":
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ci.draw_line(c + Vector2(-er, 0.0), c + Vector2(er, 0.0), eye_col, line * 0.75)
		"wink":
			ci.draw_circle(center + Vector2(-ex + look, ey), er, eye_col)
			ci.draw_arc(center + Vector2(ex + look, ey + er * 0.4), er * 1.05,
					PI, TAU, 12, eye_col, line * 0.72)
		"star":
			# Char05 — 별눈.
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				star5(ci, c, er * 1.45, eye_col)
				ci.draw_circle(c + Vector2(er * 0.2, -er * 0.35), er * 0.2,
						Color(1, 1, 1, 0.8))
		"heart":
			for sg in [-1.0, 1.0]:
				heart(ci, center + Vector2(sg * ex + look, ey - er * 0.3), er, eye_col)
		"dot":
			for sg in [-1.0, 1.0]:
				ci.draw_circle(center + Vector2(sg * ex + look, ey), er * 0.55, eye_col)
		"angry":
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ci.draw_line(c + Vector2(sg * er * 1.2, -er * 1.4),
						c + Vector2(-sg * er * 0.4, -er * 0.5), eye_col, line * 0.65)
				ci.draw_circle(c + Vector2(0.0, er * 0.25), er * 0.72, eye_col)
		"sad":
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ci.draw_line(c + Vector2(-sg * er * 0.4, -er * 1.4),
						c + Vector2(sg * er * 1.2, -er * 0.5), eye_col, line * 0.65)
				ci.draw_circle(c + Vector2(0.0, er * 0.25), er * 0.72, eye_col)
		"surprised":
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ci.draw_arc(c, er * 1.15, 0.0, TAU, 16, eye_col, line * 0.6)
				ci.draw_circle(c, er * 0.32, eye_col)
		"closed":
			for sg in [-1.0, 1.0]:
				ci.draw_arc(center + Vector2(sg * ex + look, ey - er * 0.3), er,
						0.3, PI - 0.3, 12, eye_col, line * 0.7)
		"glare":
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ci.draw_circle(c, er, eye_col)
				ci.draw_rect(Rect2(c - Vector2(er * 1.1, er * 1.15),
						Vector2(er * 2.2, er * 1.05)), body_col)
				ci.draw_line(c + Vector2(-er * 1.1, -er * 0.1),
						c + Vector2(er * 1.1, -er * 0.1), eye_col, line * 0.58)
		"cross":
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ci.draw_line(c + Vector2(-er * 0.9, -er * 0.9),
						c + Vector2(er * 0.9, er * 0.9), eye_col, line * 0.7)
				ci.draw_line(c + Vector2(er * 0.9, -er * 0.9),
						c + Vector2(-er * 0.9, er * 0.9), eye_col, line * 0.7)
		"uwu":
			for sg in [-1.0, 1.0]:
				ci.draw_polyline(PackedVector2Array([
					center + Vector2(sg * (ex + er * 0.9) + look, ey - er * 0.9),
					center + Vector2(sg * (ex - er * 0.6) + look, ey),
					center + Vector2(sg * (ex + er * 0.9) + look, ey + er * 0.9),
				]), eye_col, line * 0.7)
		"big":
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ci.draw_circle(c, er * 1.5, eye_col)
				ci.draw_circle(c + Vector2(er * 0.5, -er * 0.5), er * 0.5, hl)
				ci.draw_circle(c + Vector2(-er * 0.4, er * 0.5), er * 0.25,
						Color(1, 1, 1, 0.7))
		"moon":
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				moon(ci, c, er, eye_col, body_col)
		"diamond":
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ci.draw_colored_polygon(PackedVector2Array([
					c + Vector2(0.0, -er * 1.25), c + Vector2(er * 0.9, 0.0),
					c + Vector2(0.0, er * 1.25), c + Vector2(-er * 0.9, 0.0)]), eye_col)
				ci.draw_circle(c + Vector2(er * 0.2, -er * 0.3), er * 0.25, hl)
		"spiral":
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ci.draw_arc(c, er, PI * 0.3, TAU + PI * 0.1, 16, eye_col, line * 0.58)
				ci.draw_arc(c, er * 0.5, PI * 1.2, TAU + PI * 0.9, 12, eye_col, line * 0.58)
		"lash":
			for sg in [-1.0, 1.0]:
				var c := center + Vector2(sg * ex + look, ey)
				ci.draw_circle(c, er, eye_col)
				for k in 3:
					var a: float = -PI / 2.0 + sg * (0.35 + k * 0.4)
					ci.draw_line(c + Vector2.from_angle(a) * er,
							c + Vector2.from_angle(a) * er * 1.7, eye_col, line * 0.45)
		_:
			for sg in [-1.0, 1.0]:
				ci.draw_circle(center + Vector2(sg * ex + look, ey), er, eye_col)


# --- 이마 장식 -------------------------------------------------------------------


static func _paint_forehead(ci: CanvasItem, center: Vector2, s: float, style: String,
		body_col: Color, ink: Color) -> void:
	if style == "none":
		return
	var at := center + Vector2(0.0, -s * 0.29)
	match style:
		"star":
			star5(ci, at, s * 0.07, Color("f2c94c"))
		"moon":
			moon(ci, at, s * 0.062, Color("f2c94c"), body_col)
		"heart":
			heart(ci, at, s * 0.055, Color(0.95, 0.5, 0.6, 0.9))
		"freckles":
			for sg in [-1.0, 1.0]:
				for k in 3:
					ci.draw_circle(center + Vector2(sg * (s * 0.24 + k * s * 0.05),
							s * 0.03 + (k % 2) * s * 0.035), s * 0.014,
							Color(0.6, 0.4, 0.3, 0.6))
		"diamond":
			ci.draw_colored_polygon(PackedVector2Array([
				at + Vector2(0.0, -s * 0.07), at + Vector2(s * 0.05, 0.0),
				at + Vector2(0.0, s * 0.07), at + Vector2(-s * 0.05, 0.0)]),
				Color(0.6, 0.9, 1.0, 0.95))
		"lightning":
			ci.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-s * 0.005, -s * 0.08), at + Vector2(s * 0.045, -s * 0.08),
				at + Vector2(s * 0.01, 0.0), at + Vector2(s * 0.05, 0.0),
				at + Vector2(-s * 0.03, s * 0.09), at + Vector2(0.0, s * 0.005),
				at + Vector2(-s * 0.038, s * 0.005)]), Color("f2c94c"))
		"cross":
			ci.draw_line(at + Vector2(-s * 0.04, -s * 0.04), at + Vector2(s * 0.04, s * 0.04),
					Color(0.85, 0.3, 0.3, 0.8), s * 0.02)
			ci.draw_line(at + Vector2(s * 0.04, -s * 0.04), at + Vector2(-s * 0.04, s * 0.04),
					Color(0.85, 0.3, 0.3, 0.8), s * 0.02)
		"dot":
			ci.draw_circle(at, s * 0.025, Color(ink, 0.6))
		"third_eye":
			ellipse(ci, at, s * 0.06, s * 0.04, Color(0.95, 0.93, 0.9))
			ci.draw_circle(at, s * 0.026, Color("7a55b0"))
		"band":
			_rrect(ci, Rect2(at + Vector2(-s * 0.09, -s * 0.03),
					Vector2(s * 0.18, s * 0.06)), s * 0.02, Color("f0d7b0"), 0.0)
			ci.draw_rect(Rect2(at + Vector2(-s * 0.03, -s * 0.03),
					Vector2(s * 0.06, s * 0.06)), Color("e5c79a"))
		"clover":
			for i in 3:
				var a := -PI / 2.0 + TAU * i / 3.0
				ci.draw_circle(at + Vector2.from_angle(a) * s * 0.03, s * 0.026,
						Color("6fbf9a"))


# --- 소품: 머리 -----------------------------------------------------------------


static func _paint_head_prop(ci: CanvasItem, center: Vector2, s: float, style: String,
		line: float, ink: Color) -> void:
	if style == "none":
		return
	if style == "headset" or style == "sleep_mask":
		# 시트에선 둘 다 Prop_Head지만, 그림은 얼굴 높이에 걸린다.
		_paint_face_prop(ci, center, s, style, line, ink)
		return
	var half := s / 2.0
	var top := center + Vector2(0.0, -half)
	match style:
		"orange":
			# Char01 2nd — 머리 위 귤.
			_disc(ci, top + Vector2(0.0, -s * 0.06), s * 0.155, Color("f5a02a"), line, ink)
			ci.draw_circle(top + Vector2(-s * 0.05, -s * 0.11), s * 0.035,
					Color(1.0, 0.78, 0.45, 0.9))
			ci.draw_line(top + Vector2(0.0, -s * 0.19), top + Vector2(s * 0.02, -s * 0.26),
					Color("4a7a35"), line * 0.7)
			_poly(ci, PackedVector2Array([
				top + Vector2(s * 0.02, -s * 0.25), top + Vector2(s * 0.14, -s * 0.32),
				top + Vector2(s * 0.16, -s * 0.24), top + Vector2(s * 0.05, -s * 0.21),
			]), Color("6aa53f"), line * 0.7, ink)
		"wizard":
			# Char05 1st — 별·달이 붙은 마법사 모자.
			_poly(ci, PackedVector2Array([
				top + Vector2(-s * 0.40, -s * 0.02), top + Vector2(s * 0.40, -s * 0.02),
				top + Vector2(s * 0.34, -s * 0.12), top + Vector2(-s * 0.34, -s * 0.12),
			]), Color("2f3a6b"), line, ink)
			_poly(ci, PackedVector2Array([
				top + Vector2(-s * 0.28, -s * 0.10), top + Vector2(s * 0.28, -s * 0.10),
				top + Vector2(s * 0.12, -s * 0.50),
			]), Color("3a468a"), line, ink)
			moon(ci, top + Vector2(0.0, -s * 0.24), s * 0.06, Color("f2c94c"),
					Color("3a468a"))
			star5(ci, top + Vector2(s * 0.12, -s * 0.46), s * 0.05, Color("f2c94c"))
		"beanie":
			_rrect(ci, Rect2(top + Vector2(-s * 0.38, -s * 0.20),
					Vector2(s * 0.76, s * 0.22)), s * 0.08, Color("5a8fd0"), line, ink)
			ci.draw_rect(Rect2(top + Vector2(-s * 0.38, -s * 0.04),
					Vector2(s * 0.76, s * 0.06)), Color("e8eef6"))
			_disc(ci, top + Vector2(0.0, -s * 0.26), s * 0.075, Color("e8eef6"), line, ink)
		"ribbon":
			var knot := top + Vector2(s * 0.26, -s * 0.05)
			for sg in [-1.0, 1.0]:
				_poly(ci, PackedVector2Array([
					knot, knot + Vector2(sg * s * 0.17, -s * 0.12),
					knot + Vector2(sg * s * 0.17, s * 0.08)]), Color("e0607a"), line * 0.8, ink)
			_disc(ci, knot, s * 0.05, Color("f2909f"), line * 0.7, ink)
		"flower":
			var at := top + Vector2(-s * 0.26, -s * 0.06)
			for i in range(5):
				var a := TAU * i / 5.0
				_disc(ci, at + Vector2.from_angle(a) * s * 0.07, s * 0.055,
						Color("f6cdd8"), line * 0.6, ink)
			ci.draw_circle(at, s * 0.05, Color("f2b93e"))
		"leaf":
			var base := top + Vector2(0.0, -s * 0.02)
			ci.draw_line(base, base + Vector2(0.0, -s * 0.14), Color("5a9a38"), line * 0.7)
			_disc(ci, base + Vector2(-s * 0.07, -s * 0.17), s * 0.07, Color("7ec850"),
					line * 0.6, ink)
			_disc(ci, base + Vector2(s * 0.07, -s * 0.17), s * 0.07, Color("7ec850"),
					line * 0.6, ink)
		"crown":
			var base_y := -s * 0.02
			_poly(ci, PackedVector2Array([
				top + Vector2(-s * 0.26, base_y), top + Vector2(-s * 0.26, base_y - s * 0.20),
				top + Vector2(-s * 0.13, base_y - s * 0.08),
				top + Vector2(0.0, base_y - s * 0.26),
				top + Vector2(s * 0.13, base_y - s * 0.08),
				top + Vector2(s * 0.26, base_y - s * 0.20), top + Vector2(s * 0.26, base_y),
			]), Color("f2c94c"), line, ink)
			ci.draw_circle(top + Vector2(0.0, base_y - s * 0.06), s * 0.045, Color("e05f5f"))
		"tophat":
			_rrect(ci, Rect2(top + Vector2(-s * 0.40, -s * 0.08),
					Vector2(s * 0.80, s * 0.08)), s * 0.03, Color("2c2833"), line, ink)
			_rrect(ci, Rect2(top + Vector2(-s * 0.24, -s * 0.38),
					Vector2(s * 0.48, s * 0.32)), s * 0.03, Color("2c2833"), line, ink)
			ci.draw_rect(Rect2(top + Vector2(-s * 0.24, -s * 0.18),
					Vector2(s * 0.48, s * 0.06)), Color("b8433f"))
		"halo":
			var at := top + Vector2(0.0, -s * 0.24)
			ci.draw_arc(at, s * 0.20, 0.0, TAU, 26, Color(1.0, 0.85, 0.4, 0.35), s * 0.09)
			ci.draw_arc(at, s * 0.20, 0.0, TAU, 26, Color("fff3d0"), s * 0.045)
		"cap":
			_rrect(ci, Rect2(top + Vector2(-s * 0.34, -s * 0.22),
					Vector2(s * 0.68, s * 0.24)), s * 0.10, Color("c94f43"), line, ink)
			_rrect(ci, Rect2(top + Vector2(s * 0.10, -s * 0.06),
					Vector2(s * 0.36, s * 0.07)), s * 0.03, Color("a83d33"), line * 0.8, ink)
		"antenna":
			# Char11 — 로봇냥 안테나.
			ci.draw_line(top, top + Vector2(0.0, -s * 0.24), ink, line)
			_disc(ci, top + Vector2(0.0, -s * 0.28), s * 0.06, Color("6fe8d8"), line, ink)


# --- 소품: 얼굴 -----------------------------------------------------------------


static func _paint_face_prop(ci: CanvasItem, center: Vector2, s: float, style: String,
		line: float, ink: Color) -> void:
	if style == "none":
		return
	var ex := s * 0.20
	var ey := -s * 0.055
	match style:
		"sunglasses":
			# Char02 2nd — 검은 선글라스.
			for sg in [-1.0, 1.0]:
				_rrect(ci, Rect2(center + Vector2(sg * ex - s * 0.135, ey - s * 0.085),
						Vector2(s * 0.27, s * 0.17)), s * 0.05, Color("1e1b22"), line * 0.8, ink)
			ci.draw_line(center + Vector2(-s * 0.07, ey - s * 0.02),
					center + Vector2(s * 0.07, ey - s * 0.02), Color("1e1b22"), line)
			for sg in [-1.0, 1.0]:
				ci.draw_line(center + Vector2(sg * (ex + s * 0.02), ey - s * 0.05),
						center + Vector2(sg * (ex + s * 0.10), ey - s * 0.01),
						Color(1, 1, 1, 0.55), line * 0.7)
		"round_glasses":
			# Char06 — 동글 안경.
			for sg in [-1.0, 1.0]:
				ci.draw_circle(center + Vector2(sg * ex, ey), s * 0.135,
						Color(0.9, 0.95, 1.0, 0.22))
				ci.draw_arc(center + Vector2(sg * ex, ey), s * 0.135, 0.0, TAU, 26,
						ink, line * 0.9)
			ci.draw_line(center + Vector2(-s * 0.07, ey), center + Vector2(s * 0.07, ey),
					ink, line * 0.8)
		"square_glasses":
			for sg in [-1.0, 1.0]:
				_rrect(ci, Rect2(center + Vector2(sg * ex - s * 0.13, ey - s * 0.09),
						Vector2(s * 0.26, s * 0.18)), s * 0.04,
						Color(0.9, 0.95, 1.0, 0.22), line * 0.85, ink)
			ci.draw_line(center + Vector2(-s * 0.07, ey), center + Vector2(s * 0.07, ey),
					ink, line * 0.8)
		"sleep_mask":
			# Char04 1st — 별·달이 수놓인 수면 안대.
			_rrect(ci, Rect2(center + Vector2(-s * 0.40, ey - s * 0.12),
					Vector2(s * 0.80, s * 0.24)), s * 0.09, Color("2f3a6b"), line, ink)
			moon(ci, center + Vector2(-ex, ey), s * 0.055, Color("f2c94c"), Color("2f3a6b"))
			star5(ci, center + Vector2(ex, ey - s * 0.02), s * 0.05, Color("f2c94c"))
			star5(ci, center + Vector2(s * 0.02, ey - s * 0.06), s * 0.03, Color("f2c94c"))
		"headset":
			# Char03 1st — 게이밍 헤드셋.
			ci.draw_arc(center + Vector2(0.0, -s * 0.30), s * 0.46, PI + 0.35, TAU - 0.35,
					26, ink, line * 1.8)
			ci.draw_arc(center + Vector2(0.0, -s * 0.30), s * 0.46, PI + 0.35, TAU - 0.35,
					26, Color("3a3540"), line * 1.1)
			for sg in [-1.0, 1.0]:
				_rrect(ci, Rect2(center + Vector2(sg * s * 0.46 - s * 0.09, -s * 0.16),
						Vector2(s * 0.18, s * 0.26)), s * 0.07, Color("3a3540"), line, ink)
				ci.draw_rect(Rect2(center + Vector2(sg * s * 0.46 - s * 0.045, -s * 0.11),
						Vector2(s * 0.09, s * 0.16)), Color("6a6472"))
			# 붐 마이크.
			ci.draw_polyline(PackedVector2Array([
				center + Vector2(-s * 0.46, s * 0.08),
				center + Vector2(-s * 0.44, s * 0.20),
				center + Vector2(-s * 0.30, s * 0.24)]), ink, line)
			ci.draw_circle(center + Vector2(-s * 0.28, s * 0.24), s * 0.035, Color("3a3540"))
		"visor":
			_rrect(ci, Rect2(center + Vector2(-s * 0.32, ey - s * 0.10),
					Vector2(s * 0.64, s * 0.20)), s * 0.07, Color("1e2a33"), line, ink)
			ci.draw_line(center + Vector2(-s * 0.24, ey), center + Vector2(s * 0.24, ey),
					Color("6fe8d8"), line * 0.9)
		"eyepatch":
			_rrect(ci, Rect2(center + Vector2(ex - s * 0.13, ey - s * 0.10),
					Vector2(s * 0.26, s * 0.20)), s * 0.05, Color("2c2833"), line * 0.8, ink)
			ci.draw_line(center + Vector2(-s * 0.42, ey - s * 0.14),
					center + Vector2(s * 0.42, ey - s * 0.06), Color("2c2833"), line * 0.7)
		"monocle":
			ci.draw_arc(center + Vector2(ex, ey), s * 0.14, 0.0, TAU, 26, Color("f2c94c"),
					line * 0.8)
			ci.draw_circle(center + Vector2(ex, ey), s * 0.14, Color(0.9, 0.95, 1.0, 0.18))
			ci.draw_line(center + Vector2(ex + s * 0.10, ey + s * 0.10),
					center + Vector2(ex + s * 0.20, ey + s * 0.26), Color("f2c94c"), line * 0.6)
		"mask":
			_rrect(ci, Rect2(center + Vector2(-s * 0.26, s * 0.02),
					Vector2(s * 0.52, s * 0.24)), s * 0.06, Color("eef3f8"), line * 0.8, ink)
			for sg in [-1.0, 1.0]:
				ci.draw_line(center + Vector2(sg * s * 0.26, s * 0.06),
						center + Vector2(sg * s * 0.40, s * 0.02), Color("cfd8e2"), line * 0.6)
		"mustache":
			for sg in [-1.0, 1.0]:
				ci.draw_arc(center + Vector2(sg * s * 0.07, s * 0.08), s * 0.075,
						PI * (1.0 if sg > 0.0 else 1.5), PI * (1.5 if sg > 0.0 else 2.0),
						10, Color("4a3b30"), line)
		"scar":
			ci.draw_line(center + Vector2(ex - s * 0.02, ey - s * 0.16),
					center + Vector2(ex + s * 0.04, ey + s * 0.10),
					Color(0.75, 0.35, 0.35, 0.85), line * 0.7)


# --- 소품: 손·가슴·목·등 ---------------------------------------------------------


## 두 앞발 사이에 들리는 소품 (Layer 30 — Prop_Belly).
static func _paint_hold(ci: CanvasItem, center: Vector2, s: float, style: String,
		line: float, ink: Color) -> void:
	if style == "none":
		return
	if style == "tie":  # 시트의 Char02 넘타이는 Prop_Belly 슬롯 — 그림은 목 위치 그대로.
		_paint_neck(ci, center, s, "tie", line, ink)
		return
	var half := s / 2.0
	var at := center + Vector2(0.0, half - s * 0.12)
	match style:
		"mug":
			# Char01 1st — 하트가 그려진 머그컵.
			ci.draw_arc(at + Vector2(s * 0.13, 0.0), s * 0.06, -PI / 2.0, PI / 2.0, 12,
					ink, line * 1.4)
			ci.draw_arc(at + Vector2(s * 0.13, 0.0), s * 0.06, -PI / 2.0, PI / 2.0, 12,
					Color("8a4f2e"), line * 0.8)
			_rrect(ci, Rect2(at + Vector2(-s * 0.13, -s * 0.11),
					Vector2(s * 0.26, s * 0.23)), s * 0.05, Color("a35c33"), line, ink)
			ellipse(ci, at + Vector2(0.0, -s * 0.10), s * 0.115, s * 0.035,
					Color("5a3320"), line * 0.6, ink)
			heart(ci, at + Vector2(0.0, s * 0.02), s * 0.045, Color("f2c94c"))
		"keyboard":
			# Char03 2nd — 게이밍 키보드.
			_rrect(ci, Rect2(at + Vector2(-s * 0.26, -s * 0.07),
					Vector2(s * 0.52, s * 0.17)), s * 0.03, Color("2b2830"), line, ink)
			for row in 2:
				for k in 7:
					ci.draw_rect(Rect2(at + Vector2(-s * 0.23 + k * s * 0.066,
							-s * 0.045 + row * s * 0.065), Vector2(s * 0.045, s * 0.04)),
							Color("d05a3a") if (row + k) % 3 == 0 else Color("4a4552"))
		"book":
			# Char06 2nd — 두꺼운 책.
			_rrect(ci, Rect2(at + Vector2(-s * 0.14, -s * 0.13),
					Vector2(s * 0.28, s * 0.30)), s * 0.03, Color("2f4a8a"), line, ink)
			ci.draw_rect(Rect2(at + Vector2(-s * 0.14, -s * 0.13),
					Vector2(s * 0.05, s * 0.30)), Color("21356b"))
			ci.draw_rect(Rect2(at + Vector2(s * 0.04, -s * 0.13),
					Vector2(s * 0.035, s * 0.19)), Color("d9a05c"))
			_poly(ci, PackedVector2Array([
				at + Vector2(s * 0.04, s * 0.06), at + Vector2(s * 0.075, s * 0.06),
				at + Vector2(s * 0.0575, s * 0.11)]), Color("d9a05c"), 0.0)
		"orb":
			# Char05 2nd — 수정 구슬.
			_poly(ci, PackedVector2Array([
				at + Vector2(-s * 0.13, s * 0.15), at + Vector2(s * 0.13, s * 0.15),
				at + Vector2(s * 0.09, s * 0.07), at + Vector2(-s * 0.09, s * 0.07),
			]), Color("d9a05c"), line, ink)
			_disc(ci, at + Vector2(0.0, -s * 0.02), s * 0.135, Color("9fd8f2"), line, ink)
			ci.draw_circle(at + Vector2(-s * 0.04, -s * 0.06), s * 0.04,
					Color(1, 1, 1, 0.75))
			sparkle(ci, at + Vector2(s * 0.05, s * 0.02), s * 0.045, Color(1, 1, 1, 0.6))
		"lantern":
			# Char04 2nd — 달·별 무늬 랜턴.
			ci.draw_arc(at + Vector2(0.0, -s * 0.16), s * 0.05, PI, TAU, 12, ink, line)
			_rrect(ci, Rect2(at + Vector2(-s * 0.10, -s * 0.13),
					Vector2(s * 0.20, s * 0.06)), s * 0.02, Color("3a468a"), line * 0.8, ink)
			_rrect(ci, Rect2(at + Vector2(-s * 0.12, -s * 0.08),
					Vector2(s * 0.24, s * 0.24)), s * 0.05, Color("2f3a6b"), line, ink)
			moon(ci, at + Vector2(-s * 0.02, s * 0.02), s * 0.05, Color("f2c94c"),
					Color("2f3a6b"))
			star5(ci, at + Vector2(s * 0.06, s * 0.08), s * 0.03, Color("f2c94c"))
		"fish":
			ellipse(ci, at + Vector2(-s * 0.02, 0.0), s * 0.14, s * 0.075,
					Color("f0b070"), line * 0.8, ink)
			_poly(ci, PackedVector2Array([
				at + Vector2(s * 0.11, 0.0), at + Vector2(s * 0.21, -s * 0.07),
				at + Vector2(s * 0.21, s * 0.07)]), Color("f0b070"), line * 0.8, ink)
			ci.draw_circle(at + Vector2(-s * 0.08, -s * 0.02), s * 0.018, ink)
		"yarn":
			_disc(ci, at, s * 0.14, Color("e0607a"), line, ink)
			for k in 3:
				ci.draw_arc(at, s * 0.14 - k * s * 0.045, 0.4 + k, PI + 0.4 + k, 12,
						Color(0.8, 0.3, 0.42, 0.8), line * 0.6)
		"controller":
			_rrect(ci, Rect2(at + Vector2(-s * 0.22, -s * 0.07),
					Vector2(s * 0.44, s * 0.16)), s * 0.07, Color("3a3540"), line, ink)
			ci.draw_circle(at + Vector2(s * 0.11, 0.0), s * 0.03, Color("d05a3a"))
			ci.draw_rect(Rect2(at + Vector2(-s * 0.155, -s * 0.015),
					Vector2(s * 0.09, s * 0.03)), Color("d8d4dc"))
			ci.draw_rect(Rect2(at + Vector2(-s * 0.125, -s * 0.045),
					Vector2(s * 0.03, s * 0.09)), Color("d8d4dc"))


## 가슴 소품 (Layer 35 — 배지 등).
static func _paint_chest(ci: CanvasItem, center: Vector2, s: float, style: String,
		line: float, ink: Color) -> void:
	if style == "none":
		return
	if style == "bowtie":  # 시트의 Char06 나비넘타이는 Prop_Chest 슬롯.
		_paint_neck(ci, center, s, "bowtie", line, ink)
		return
	var at := center + Vector2(s * 0.28, s * 0.24)
	match style:
		"badge":
			# Char02 1st — 경찰 배지.
			_poly(ci, PackedVector2Array([
				at + Vector2(-s * 0.075, -s * 0.09), at + Vector2(s * 0.075, -s * 0.09),
				at + Vector2(s * 0.085, s * 0.02), at + Vector2(0.0, s * 0.10),
				at + Vector2(-s * 0.085, s * 0.02),
			]), Color("cfd6dd"), line * 0.85, ink)
			star5(ci, at + Vector2(0.0, -s * 0.005), s * 0.045, Color("8f99a5"))
		"heart_pin":
			heart(ci, at, s * 0.06, Color("e0607a"))
		"gem_pin":
			ci.draw_colored_polygon(PackedVector2Array([
				at + Vector2(0.0, -s * 0.07), at + Vector2(s * 0.055, 0.0),
				at + Vector2(0.0, s * 0.07), at + Vector2(-s * 0.055, 0.0)]),
				Color("6fd0e8"))
		"pocket":
			_rrect(ci, Rect2(at + Vector2(-s * 0.08, -s * 0.08),
					Vector2(s * 0.16, s * 0.16)), s * 0.03,
					Color(1, 1, 1, 0.18), line * 0.6, ink)


## 목 소품 (Layer 35 — 넥타이·나비넥타이·방울).
static func _paint_neck(ci: CanvasItem, center: Vector2, s: float, style: String,
		line: float, ink: Color) -> void:
	if style == "none":
		return
	var at := center + Vector2(0.0, s * 0.20)
	match style:
		"tie":
			# Char02 1st — 검은 넥타이.
			_poly(ci, PackedVector2Array([
				at + Vector2(-s * 0.05, -s * 0.02), at + Vector2(s * 0.05, -s * 0.02),
				at + Vector2(s * 0.035, s * 0.05), at + Vector2(-s * 0.035, s * 0.05),
			]), Color("2b2830"), line * 0.7, ink)
			_poly(ci, PackedVector2Array([
				at + Vector2(-s * 0.045, s * 0.05), at + Vector2(s * 0.045, s * 0.05),
				at + Vector2(s * 0.055, s * 0.24), at + Vector2(0.0, s * 0.30),
				at + Vector2(-s * 0.055, s * 0.24),
			]), Color("2b2830"), line * 0.7, ink)
		"bowtie":
			# Char06 1st — 파란 나비넥타이.
			for sg in [-1.0, 1.0]:
				_poly(ci, PackedVector2Array([
					at, at + Vector2(sg * s * 0.16, -s * 0.09),
					at + Vector2(sg * s * 0.16, s * 0.09)]), Color("2f6ab8"), line * 0.8, ink)
			_disc(ci, at, s * 0.045, Color("245a9e"), line * 0.7, ink)
		"bell":
			ci.draw_line(at + Vector2(-s * 0.34, -s * 0.02), at + Vector2(s * 0.34, -s * 0.02),
					Color("b8433f"), line * 1.4)
			_disc(ci, at + Vector2(0.0, s * 0.05), s * 0.075, Color("f2c94c"), line * 0.8, ink)
			ci.draw_line(at + Vector2(0.0, s * 0.05), at + Vector2(0.0, s * 0.11),
					ink, line * 0.6)
		"scarf":
			_rrect(ci, Rect2(at + Vector2(-s * 0.38, -s * 0.06),
					Vector2(s * 0.76, s * 0.14)), s * 0.05, Color("c94f43"), line * 0.8, ink)
			_rrect(ci, Rect2(at + Vector2(-s * 0.28, s * 0.05),
					Vector2(s * 0.14, s * 0.22)), s * 0.04, Color("a83d33"), line * 0.8, ink)
		"bandana":
			_poly(ci, PackedVector2Array([
				at + Vector2(-s * 0.22, -s * 0.02), at + Vector2(s * 0.22, -s * 0.02),
				at + Vector2(0.0, s * 0.22)]), Color("d08a3c"), line * 0.8, ink)
		"chain":
			ci.draw_arc(at + Vector2(0.0, -s * 0.06), s * 0.3, 0.5, PI - 0.5, 16,
					Color("f2c94c"), line * 1.1)
			_disc(ci, at + Vector2(0.0, s * 0.22), s * 0.06, Color("f2c94c"), line * 0.7, ink)


## 등 소품 (Layer 6 — 몸통 뒤).
static func _paint_back(ci: CanvasItem, center: Vector2, s: float, style: String,
		line: float) -> void:
	if style == "none":
		return
	var half := s / 2.0
	match style:
		"pillow":
			_rrect(ci, Rect2(center + Vector2(-s * 0.64, -s * 0.52),
					Vector2(s * 1.28, s * 1.10)), s * 0.24,
					Color("cfd8e2"), line, INK)
		"cape":
			_poly(ci, PackedVector2Array([
				center + Vector2(-s * 0.42, -half + s * 0.06),
				center + Vector2(s * 0.42, -half + s * 0.06),
				center + Vector2(s * 0.60, half + s * 0.08),
				center + Vector2(-s * 0.60, half + s * 0.08),
			]), Color("b8433f"), line, INK)
		"wings":
			for sg in [-1.0, 1.0]:
				_poly(ci, PackedVector2Array([
					center + Vector2(sg * s * 0.30, -s * 0.14),
					center + Vector2(sg * s * 0.72, -s * 0.44),
					center + Vector2(sg * s * 0.78, s * 0.02),
					center + Vector2(sg * s * 0.44, s * 0.16),
				]), Color(1.0, 0.99, 0.94), line, INK)
		"balloon":
			ci.draw_line(center + Vector2(s * 0.36, -s * 0.10),
					center + Vector2(s * 0.52, -half - s * 0.22), Color(INK, 0.7), line * 0.5)
			_disc(ci, center + Vector2(s * 0.54, -half - s * 0.36), s * 0.17,
					Color("e0607a"), line, INK)
		"jetpack":
			_rrect(ci, Rect2(center + Vector2(-s * 0.62, -s * 0.18),
					Vector2(s * 0.26, s * 0.44)), s * 0.09, Color("8f99a5"), line, INK)
			_poly(ci, PackedVector2Array([
				center + Vector2(-s * 0.56, s * 0.26), center + Vector2(-s * 0.42, s * 0.26),
				center + Vector2(-s * 0.49, s * 0.50)]), Color("f2a03a"), 0.0)
