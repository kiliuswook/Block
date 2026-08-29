extends CanvasLayer
## 상단 고정 유저 HUD — "내가 누구이고 얼마나 컸는가"를 한 장의 카드로.
##
## 이름(스팀 페르소나 → 없으면 닉네임) · 계정 레벨 + 칭호 · 경험치 바 · 골드.
## 타이틀과 인게임이 **같은 스크립트, 같은 자리**를 쓴다 — 화면이 바뀌어도
## 유저 정보는 늘 좌상단 같은 카드에 있다는 것이 이 HUD의 전부다.
##
## 자기 CanvasLayer(LAYER)를 들고 다니므로 오버레이·설정 페이지 위에 그대로 뜬다.
## 그래서 다른 화면은 이 자리에 지갑/레벨을 따로 그리지 않는다.
## (class_name 없이 preload로 참조)
##
##     const UserHud := preload("res://core/scripts/user_hud.gd")
##     _hud = UserHud.new()
##     add_child(_hud)
##     _hud.refresh()  # 골드·경험치가 바뀐 뒤

const UiKit := preload("res://core/scripts/ui_kit.gd")
const CatSprite := preload("res://core/scripts/cat_sprite.gd")

const CARD := Vector2(520.0, 96.0)  # 가로 화면 기준 크기 (좁은 화면은 폭만 줄인다)
const MARGIN := Vector2(24.0, 16.0)
const LAYER := 5  # UI(1)·터치(2)·팝업(3)보다 위

## 세로 화면 인게임처럼 좌상단이 이미 쓰이는 화면은 오른쪽으로 붙인다.
var align_right := false

var _card: Control


func _ready() -> void:
	layer = LAYER
	var vp := get_viewport().get_visible_rect().size
	var w := minf(CARD.x, vp.x - MARGIN.x * 2.0)
	_card = Control.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 클릭은 아래 화면으로 통과
	_card.size = Vector2(w, CARD.y)
	_card.position = Vector2(
			vp.x - w - MARGIN.x if align_right else MARGIN.x, MARGIN.y)
	_card.draw.connect(_draw_card)
	add_child(_card)


## 골드·경험치·이름·캐릭터가 바뀐 뒤 호출.
func refresh() -> void:
	if is_instance_valid(_card):
		_card.queue_redraw()


## 이 카드가 차지하는 자리 — 다른 UI가 겹치지 않게 피할 때 쓴다.
func rect() -> Rect2:
	return Rect2() if not is_instance_valid(_card) \
			else Rect2(_card.position, _card.size)


## 화면에 보이는 내 이름 — 이름의 출처는 GameState 하나로 모았다
## (스팀 페르소나가 있으면 그게 nickname에 심겨 있다).
static func display_name() -> String:
	return GameState.display_name()


func _draw_card() -> void:
	var ci := _card
	var font := ThemeDB.fallback_font
	var w: float = ci.size.x
	var h: float = ci.size.y
	ci.draw_style_box(UiKit.panel_box(UiKit.WHITE, 26, 0.0),
			Rect2(Vector2.ZERO, ci.size))
	var badge := Rect2(11.0, 11.0, h - 22.0, h - 22.0)
	_draw_avatar(ci, badge)
	var x0 := badge.end.x + 14.0
	var right := w - 18.0
	# 윗줄 오른쪽: 골드. 지갑은 이 HUD 하나뿐이라 다른 화면은 이걸 다시 그리지 않는다.
	var gold_text := "%s G" % _commas(GameState.gold)
	var gold_size := UiKit.fit_size(font, gold_text, (right - x0) * 0.45, 25)
	var gold_w := font.get_string_size(gold_text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			gold_size).x
	ci.draw_string(font, Vector2(right - gold_w, 37.0), gold_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, gold_size, UiKit.GOLD_DEEP)
	# 윗줄 왼쪽: 이름.
	var name_room := right - gold_w - 14.0 - x0
	var who := display_name()
	ci.draw_string(font, Vector2(x0, 37.0), who, HORIZONTAL_ALIGNMENT_LEFT, -1,
			UiKit.fit_size(font, who, name_room, 25), UiKit.INK)
	# 아랫줄: Lv.N · 칭호 (왼쪽) / 이번 레벨 진행 (오른쪽).
	var count := tr("MENU_LEVEL_MAX")
	var need := Account.xp_to_next()
	if need > 0:
		count = tr("MENU_LEVEL_XP").format(
				{"xp": Account.xp_in_level(), "need": need})
	var count_size := UiKit.fit_size(font, count, (right - x0) * 0.45, 17)
	var count_w := font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1,
			count_size).x
	ci.draw_string(font, Vector2(right - count_w, 63.0), count,
			HORIZONTAL_ALIGNMENT_LEFT, -1, count_size, UiKit.MUTED)
	var lv := tr("MENU_LEVEL").format({"level": Account.level()})
	var lv_size := UiKit.fit_size(font, lv, (right - x0) * 0.3, 21)
	var lv_w := font.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, lv_size).x
	ci.draw_string(font, Vector2(x0, 63.0), lv, HORIZONTAL_ALIGNMENT_LEFT, -1,
			lv_size, UiKit.INK)
	# 칭호는 남는 폭에만 — 긴 번역이 오면 줄어들고, 자리가 없으면 생략한다.
	var tier_x := x0 + lv_w + 10.0
	var tier_room := right - count_w - 12.0 - tier_x
	if tier_room > 30.0:
		var tier := tr(Account.tier_key())
		ci.draw_string(font, Vector2(tier_x, 63.0), tier, HORIZONTAL_ALIGNMENT_LEFT,
				-1, UiKit.fit_size(font, tier, tier_room, 18), UiKit.MUTED)
	_draw_xp_bar(ci, Rect2(x0, h - 26.0, right - x0, 14.0))


## 경험치 바 — 홈을 파고 그 안쪽만 채운다 (외곽선이 두 겹으로 보이지 않게).
func _draw_xp_bar(ci: CanvasItem, bar: Rect2) -> void:
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color(UiKit.INK, 0.10)
	groove.set_corner_radius_all(int(bar.size.y / 2.0))
	ci.draw_style_box(groove, bar)
	var inner := bar.grow(-3.0)
	var fill := inner
	fill.size.x = maxf(5.0, inner.size.x * Account.progress())
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiKit.CYAN
	sb.set_corner_radius_all(int(inner.size.y / 2.0))
	ci.draw_style_box(sb, fill)


## 아바타 — 하늘색 배지 안에 지금 고른 냥이 얼굴 (키캡과 같은 얼굴 컷).
func _draw_avatar(ci: CanvasItem, badge: Rect2) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiKit.SKY
	sb.set_corner_radius_all(int(badge.size.x * 0.32))
	sb.set_border_width_all(3)
	sb.border_color = UiKit.INK
	ci.draw_style_box(sb, badge)
	# 아바타는 대표 캐릭터(★)다 — 타이틀 무대는 자리 냥이가 맡는다.
	var cat_id := GameState.featured_cat()
	var char_id := str(GameState.get_cat(cat_id).get("char", ""))
	var tex: Texture2D = CatSprite.face_texture(char_id) if char_id != "" else null
	if tex != null:
		var src: Rect2 = CatSprite.FACE
		var fw := badge.size.x * 0.86
		var fh := fw * src.size.y / src.size.x
		ci.draw_texture_rect_region(tex, Rect2(
				Vector2(badge.get_center().x - fw / 2.0,
				badge.get_center().y - fh * 0.46), Vector2(fw, fh)), src)
		return
	# 시트 그림이 없는 냥이(나만의 캐릭터 등)는 코드 렌더를 작게 그린다.
	Player.paint_cat(ci, badge.get_center() + Vector2(0.0, badge.size.y * 0.06),
			badge.size.x * 0.5, 0.0, true, false, GameState.cat_skin(cat_id))


## 1234567 → "1,234,567" (자릿수 구분은 언어와 무관한 숫자 표기로 통일).
static func _commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return ("-" if n < 0 else "") + out
