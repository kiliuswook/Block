extends CanvasLayer
## 상단 고정 유저 HUD (피그마 `상단` 컴포넌트) — 왼쪽 **Lv 카드** + 오른쪽 **재화 알약 둘**.
##
## Lv 카드(390×118, 하늘색 #d6f3ff): 아바타 원 · 이름 + ⚙ 버튼 · Lv.N · n / need XP ·
## 파란 경험치 바. 재화 알약(높이 78): 코인 그림 + 골드 + [+], 캔 그림 + 캔 + [+].
## 타이틀과 인게임이 **같은 스크립트, 같은 자리**를 쓴다 — 인게임은 디자인대로
## Lv 카드만 띄우고(`show_wallet=false`), 결과창이 뜰 때 지갑을 같이 띄운다
## (코인이 날아갈 과녁이 필요하다).
##
## 자기 CanvasLayer(LAYER)를 들고 다니므로 오버레이·설정 페이지 위에 그대로 뜬다.
## (class_name 없이 preload로 참조)
##
##     const UserHud := preload("res://core/scripts/user_hud.gd")
##     _hud = UserHud.new()
##     add_child(_hud)
##     _hud.refresh()  # 골드·경험치가 바뀐 뒤

signal gear_pressed  # ⚙ — 닉네임 변경 팝업
signal plus_pressed(kind: String)  # 재화 알약의 [+] ("gold" / "cans") — 상점으로

const UiKit := preload("res://core/scripts/ui_kit.gd")
const CatSprite := preload("res://core/scripts/cat_sprite.gd")

const CARD := Vector2(390.0, 118.0)  # Lv 카드
const MARGIN := Vector2(52.0, 40.0)  # 화면 가장자리에서
const PILL_H := 78.0
const PILL_GAP := 8.0
const LAYER := 5  # UI(1)·터치(2)·팝업(3)보다 위

## 세로 화면 인게임처럼 좌상단이 이미 쓰이는 화면은 오른쪽으로 붙인다.
var align_right := false
## 재화 알약을 띄울 것인가 (인게임은 결과창이 뜰 때까지 숨긴다).
var show_wallet := true:
	set(v):
		show_wallet = v
		_layout()
## 피그마 헤더 줄(`상단` 1817폭): 전체 화면 페이지는 오른쪽 끝에 `뒤로가기`(241)가 서고
## 알약은 그 왼쪽 20px에서 끝난다. 타이틀 메뉴는 알약이 오른쪽 끝까지 간다.
## "menu" | "page" | "lv_only"(설정 — 알약 없음)
var header := "menu":
	set(v):
		if header == v:
			return
		header = v
		_layout()
const BACK_W := 241.0  # 피그마 뒤로가기 폭
const HEADER_GAP := 20.0

var _card: Control
var _wallet: Control
var _gear: Button
var _plus_gold: Button
var _plus_can: Button

## --- 연출용 표시값 (결과 화면의 보상 연출이 쓴다) ---------------------------
## 보상은 판이 끝난 그 순간 이미 세이브에 들어가 있다. 그런데 카드가 곧바로
## 새 값을 보여 주면 "골드가 날아와 더해졌다"는 연출이 성립하지 않으므로,
## 연출이 끝날 때까지 **표시값만** 옛 값에 붙들어 둔다 (-1 = 실제 값 그대로).
var _gold_shown := -1
var _xp_shown := -1
var _gain_text := ""  # 골드 위에 잠깐 뜨는 "+49 G"
var _gain_a := 0.0
var _gain_rise := 0.0
var _gold_rect := Rect2()  # 마지막으로 골드를 그린 자리 (코인이 날아올 과녁, 알약 로컬)


func _ready() -> void:
	layer = LAYER
	_card = Control.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 클릭은 아래 화면으로 통과
	_card.draw.connect(_draw_card)
	add_child(_card)
	_gear = Button.new()
	_gear.size = Vector2(38.0, 38.0)
	_gear.focus_mode = Control.FOCUS_NONE
	_gear.pressed.connect(func() -> void:
		Sfx.play("click")
		gear_pressed.emit())
	_style_round(_gear)
	var gear_face := Control.new()
	gear_face.set_anchors_preset(Control.PRESET_FULL_RECT)
	gear_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear_face.draw.connect(func() -> void:
		UiKit.draw_tex(gear_face, "gear.svg", Rect2(6.0, 6.0, 26.0, 26.0)))
	_gear.add_child(gear_face)
	_card.add_child(_gear)
	_wallet = Control.new()
	_wallet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wallet.draw.connect(_draw_wallet)
	add_child(_wallet)
	_plus_gold = _make_plus("gold")
	_plus_can = _make_plus("cans")
	_layout()


## [+] 버튼 — 흰 사각(잉크 외곽선 3) + 회색 두께.
func _make_plus(kind: String) -> Button:
	var b := Button.new()
	b.size = Vector2(56.0, 56.0)
	b.focus_mode = Control.FOCUS_NONE
	# 피그마 btn_icon: 흰 얼굴 56 + 잉크 테 3 + 회색 두께 2, 가운데 굵은 십자.
	UiKit.style_button(b, UiKit.WHITE, Color("898989"), UiKit.TEXT, 34, 16, true, 3, 2)
	var cross := Control.new()
	cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.draw.connect(func() -> void:
		var c := Vector2(28.0, 28.0)
		cross.draw_rect(Rect2(c - Vector2(12.0, 3.0), Vector2(24.0, 6.0)), UiKit.INK)
		cross.draw_rect(Rect2(c - Vector2(3.0, 12.0), Vector2(6.0, 24.0)), UiKit.INK))
	b.add_child(cross)
	b.pressed.connect(func() -> void:
		Sfx.play("click")
		plus_pressed.emit(kind))
	_wallet.add_child(b)
	return b


func _style_round(b: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiKit.WHITE
	sb.set_corner_radius_all(99)
	sb.set_border_width_all(3)
	sb.border_color = Color("d1d1d1")
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _layout() -> void:
	if not is_instance_valid(_card):
		return
	var vp := get_viewport().get_visible_rect().size
	var w := minf(CARD.x, vp.x - MARGIN.x * 2.0)
	_card.size = Vector2(w, CARD.y)
	_card.position = Vector2(
			vp.x - w - MARGIN.x if align_right else MARGIN.x, MARGIN.y)
	_gear.position = Vector2(w - 16.0 - 38.0, 16.0)  # 이름 오른쪽 끝 자리 — 그릴 때 이름 옆으로 옮긴다
	# 지갑 알약 둘 — 오른쪽 가장자리에서 왼쪽으로.
	_wallet.visible = show_wallet and header != "lv_only"
	var pw := _pill_w(_gold_text()) + PILL_GAP + _pill_w(UiKit.commas(GameState.cans))
	_wallet.size = Vector2(pw, PILL_H)
	var right := vp.x - MARGIN.x
	if header == "page":
		right -= BACK_W + HEADER_GAP
	_wallet.position = Vector2(right - pw, MARGIN.y + (CARD.y - PILL_H) / 2.0)
	if vp.y > vp.x:
		# 세로 화면은 폭이 모자라 Lv 카드 아래 줄에 오른쪽 정렬로 내려간다.
		_wallet.position = Vector2(vp.x - MARGIN.x + 28.0 - pw, MARGIN.y + CARD.y + 10.0)
	var gw := _pill_w(_gold_text())
	_plus_gold.position = Vector2(gw - 7.0 - 56.0, (PILL_H - 56.0) / 2.0)
	_plus_can.position = Vector2(pw - 7.0 - 56.0, (PILL_H - 56.0) / 2.0)
	_card.queue_redraw()
	_wallet.queue_redraw()


## 알약 하나의 폭: 7 + 아이콘 60 + 8 + 숫자 + 8 + [+] 56 + 7.
func _pill_w(num: String) -> float:
	return 7.0 + 60.0 + 8.0 + UiKit.text_width(num, 28, true) + 8.0 + 56.0 + 7.0


func _gold_text() -> String:
	return UiKit.commas(gold_shown())


## 골드·경험치·이름·캐릭터가 바뀐 뒤 호출.
func refresh() -> void:
	_layout()


## 연출이 끝날 때까지 표시값을 붙들어 둔다. -1을 넣으면 실제 값으로 돌아간다.
func hold(gold: int, total_xp: int) -> void:
	_gold_shown = gold
	_xp_shown = total_xp
	refresh()


func set_gold_shown(v: int) -> void:
	_gold_shown = v
	refresh()


func set_xp_shown(v: int) -> void:
	_xp_shown = v
	refresh()


## 붙들어 둔 표시값을 놓고 실제 세이브 값으로 돌아간다.
func release() -> void:
	_gold_shown = -1
	_xp_shown = -1
	refresh()


## 골드가 몇으로 보이고 있는가 (연출 중이면 표시값).
func gold_shown() -> int:
	return GameState.gold if _gold_shown < 0 else _gold_shown


## 골드 글자 위로 "+49 G"가 잠깐 떠올랐다 사라진다.
func pop_gain(amount: int) -> void:
	if amount <= 0:
		return
	_gain_text = "+%s G" % UiKit.commas(amount)
	_gain_a = 1.0
	_gain_rise = 0.0
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		_gain_rise = t
		_gain_a = 1.0 if t < 0.55 else (1.0 - t) / 0.45
		if is_instance_valid(_wallet):
			_wallet.queue_redraw(), 0.0, 1.0, 1.1)


## 골드 글자의 화면 좌표 — 결과 화면에서 코인이 날아올 과녁.
func gold_target() -> Vector2:
	if not is_instance_valid(_wallet):
		return Vector2.ZERO
	if not _wallet.visible:
		return _card.position + _card.size / 2.0
	return _wallet.position + _gold_rect.get_center()


## 코인 한 닢을 `from`(화면 좌표)에서 골드 자리로 날린다.
## HUD와 같은 캔버스에 그리므로 결과창 위로 지나간다. 도착하면 `on_land` 호출.
func fly_coin(from: Vector2, delay: float, dur: float, on_land: Callable) -> void:
	var to := gold_target()
	var coin := Control.new()
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.position = from
	coin.modulate.a = 0.0
	coin.draw.connect(func() -> void: _draw_coin(coin))
	add_child(coin)
	# 위로 한 번 솟았다가 빨려 들어가는 호 — 직선으로 가면 밋밋하다.
	var lift := minf(from.distance_to(to) * 0.35, 220.0)
	var mid := (from + to) * 0.5 - Vector2(0.0, lift)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(coin, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_method(func(t: float) -> void:
		var a := from.lerp(mid, t)
		var b := mid.lerp(to, t)
		coin.position = a.lerp(b, t), 0.0, 1.0, dur) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(coin, "scale", Vector2(0.6, 0.6), dur) \
			.set_delay(dur * 0.6)
	tw.tween_callback(func() -> void:
		if on_land.is_valid():
			on_land.call())
	tw.tween_callback(coin.queue_free)


func _draw_coin(coin: Control) -> void:
	UiKit.coin_icon(coin, Vector2.ZERO, 40.0)


## 카드를 다른 자리로 옮긴다 (세로 인게임 결과 화면 — 좌상단은 ⏸ 버튼과 큰 숫자
## 카드가 있어 위 가운데로 보낸다). 코인 과녁(`gold_target()`)도 따라간다.
func place(pos: Vector2) -> void:
	if is_instance_valid(_card):
		_card.position = pos


## 이 카드가 차지하는 자리 — 다른 UI가 겹치지 않게 피할 때 쓴다.
func rect() -> Rect2:
	return Rect2() if not is_instance_valid(_card) \
			else Rect2(_card.position, _card.size)


## 화면에 보이는 내 이름 — 이름의 출처는 GameState 하나로 모았다
## (스팀 페르소나가 있으면 그게 nickname에 심겨 있다).
static func display_name() -> String:
	return GameState.display_name()


# --- Lv 카드 -----------------------------------------------------------------


func _draw_card() -> void:
	var ci := _card
	var w: float = ci.size.x
	var h: float = ci.size.y
	UiKit.round_rect(ci, Rect2(Vector2.ZERO, ci.size), UiKit.CARD_SKY, 20)
	# 아바타 — 회색 원 + 흰 테두리 4, 안에 대표 캐릭터 얼굴.
	var av := Rect2(16.0, 16.0, 80.0, 80.0)
	_draw_avatar(ci, av)
	var x0 := av.end.x + 16.0
	var right := w - 16.0
	var xp_total := GameState.xp if _xp_shown < 0 else _xp_shown
	# 윗줄: 이름 + ⚙ (이름 바로 오른쪽).
	var who := display_name()
	var name_size := UiKit.fit_size(UiKit.font_bold(), who, right - x0 - 46.0, 28)
	var nw := UiKit.text(ci, who, Vector2(x0, 42.0), name_size, Color.BLACK, true)
	_gear.position = Vector2(minf(x0 + nw + 8.0, right - 38.0), 14.0)
	# 둘째 줄: Lv.N 왼쪽 / n / need XP 오른쪽.
	var lv := tr("MENU_LEVEL").format({"level": Account.level_at(xp_total)})
	UiKit.text(ci, lv, Vector2(x0, 76.0), 20, Color.BLACK, false, 0, 120.0)
	var need := Account.xp_to_next_at(xp_total)
	if need > 0:
		var cur := str(Account.xp_in_level_at(xp_total))
		var rest := " / %d XP" % need
		var rw := UiKit.text_width(rest, 20, false)
		UiKit.text(ci, rest, Vector2(right - rw, 76.0), 20, Color.BLACK)
		UiKit.text(ci, cur, Vector2(right - rw - 4.0, 76.0), 20, Color.BLACK, true, 2)
	else:
		UiKit.text(ci, tr("MENU_LEVEL_MAX"), Vector2(right, 76.0), 20, Color.BLACK,
				true, 2, right - x0 - 90.0)
	# 경험치 바 — 흰 홈에 파란 채움.
	var bar := Rect2(x0, h - 16.0 - 16.0, right - x0, 16.0)
	UiKit.round_rect(ci, bar, UiKit.WHITE, 8)
	var fill := bar
	fill.size.x = maxf(8.0, bar.size.x * Account.progress_at(xp_total))
	UiKit.round_rect(ci, fill, UiKit.GAUGE, 8)


## 아바타 — 회색 원 안에 대표 캐릭터(★) 얼굴 (키캡과 같은 얼굴 컷).
func _draw_avatar(ci: CanvasItem, badge: Rect2) -> void:
	var c := badge.get_center()
	var r := badge.size.x / 2.0
	ci.draw_circle(c, r, UiKit.WHITE)
	ci.draw_circle(c, r - 4.0, Color("959595"))
	var cat_id := GameState.featured_cat()
	var char_id := str(GameState.get_cat(cat_id).get("char", ""))
	var t: Texture2D = CatSprite.face_texture(char_id) if char_id != "" else null
	if t != null:
		var src: Rect2 = CatSprite.face_rect(char_id)
		var fw := badge.size.x * 0.8
		var fh := fw * src.size.y / src.size.x
		ci.draw_texture_rect_region(t, Rect2(
				Vector2(c.x - fw / 2.0, c.y - fh * 0.46), Vector2(fw, fh)), src)
		return
	# 시트 그림이 없는 냥이(나만의 캐릭터 등)는 코드 렌더를 작게 그린다.
	Player.paint_cat(ci, c + Vector2(0.0, badge.size.y * 0.06),
			badge.size.x * 0.46, 0.0, true, false, GameState.cat_skin(cat_id))


# --- 재화 알약 ------------------------------------------------------------------


func _draw_wallet() -> void:
	var ci := _wallet
	var gold := _gold_text()
	var gw := _pill_w(gold)
	_draw_pill(ci, Rect2(0.0, 0.0, gw, PILL_H), "coin.png", gold)
	_gold_rect = Rect2(7.0 + 60.0 + 8.0, 20.0, UiKit.text_width(gold, 28, true), 38.0)
	var can := UiKit.commas(GameState.cans)
	_draw_pill(ci, Rect2(gw + PILL_GAP, 0.0, _pill_w(can), PILL_H), "can.png", can)
	if _gain_a > 0.0 and _gain_text != "":
		UiKit.text(ci, _gain_text, Vector2(_gold_rect.end.x, 12.0 - _gain_rise * 16.0),
				22, Color(UiKit.GOLD_DEEP, clampf(_gain_a, 0.0, 1.0)), true, 2)


## 알약 하나 — 하늘색 판(흰 테두리 3) + 그림 60 + 숫자 (오른쪽 [+]는 버튼 노드).
func _draw_pill(ci: CanvasItem, r: Rect2, icon: String, num: String) -> void:
	UiKit.round_rect_outline(ci, r, UiKit.CARD_SKY, 20, 3, UiKit.WHITE)
	UiKit.draw_tex(ci, icon, Rect2(r.position + Vector2(7.0, (r.size.y - 60.0) / 2.0),
			Vector2(60.0, 60.0)))
	UiKit.text(ci, num, r.position + Vector2(7.0 + 60.0 + 8.0, r.size.y / 2.0 + 10.0),
			28, Color.BLACK, true)


## 1234567 → "1,234,567" (예전 호출부 호환).
static func _commas(n: int) -> String:
	return UiKit.commas(n)
