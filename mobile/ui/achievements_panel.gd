extends Control
## 모바일 전용 업적 화면 (class_name 없음 — preload/new 로 쓴다).
##
## 스팀 빌드에는 이 화면이 없다 — 오버레이(Shift+Tab)가 목록·진행률·전세계 달성률을
## 다 보여 주기 때문이다. 모바일에는 그런 게 없어서 **딴 업적을 볼 방법이 아예 없다.**
## 그래서 모바일 타이틀 메뉴에만 `업적` 카드를 두고 여기로 들어온다.
##
## 여기서 하는 일은 **읽어서 보여 주는 것뿐**이다:
##   · 목록·조건은 `Achv.DEFS`
##   · 해금 여부는 `Achv.has()` (기록은 GameState.achv)
##   · 진행 "지금 / 목표"는 `Achv.progress()`
## 판정은 전부 `Achv`가 계속 소유한다 — 이 화면 때문에 판정 코드를 늘리지 않는다.
##
## 표시 문자열은 번역 키로 뺀다: ACHV_<ID>_NAME / ACHV_<ID>_DESC (/i18n 규칙).

const UiKit := preload("res://core/scripts/ui_kit.gd")
const UserHud := preload("res://core/scripts/user_hud.gd")

## 좌상단 유저 HUD 아래에서 헤더가 시작한다 (타이틀의 다른 전체 화면 페이지와 같은 규칙).
const HEAD_DROP := 118.0
const MARGIN := 28.0
const ROW_H := 168.0
const ROW_GAP := 14.0
const BADGE := 92.0

signal closed

var _list: VBoxContainer
var _count: Label
var _vw := 0.0
var _vh := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var vp := get_viewport_rect().size
	_vw = vp.x
	_vh = vp.y
	size = vp
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var head := Label.new()
	head.text = tr("ACHV_TITLE")
	head.position = Vector2(0.0, 24.0 + HEAD_DROP)
	head.size = Vector2(_vw, 62.0)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 46)
	head.add_theme_color_override("font_color", UiKit.INK)
	add_child(head)
	var back := Button.new()
	back.text = tr("SET_BACK")
	back.size = Vector2(150.0, 62.0)
	back.position = Vector2(_vw - 150.0 - MARGIN, 22.0 + HEAD_DROP)
	UiKit.btn_ghost(back, 24)
	back.pressed.connect(func() -> void:
		Sfx.play("click")
		close())
	add_child(back)
	_count = Label.new()
	_count.position = Vector2(MARGIN, 92.0 + HEAD_DROP)
	_count.size = Vector2(_vw - MARGIN * 2.0, 36.0)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.add_theme_font_size_override("font_size", 24)
	_count.add_theme_color_override("font_color", UiKit.GOLD_DEEP)
	add_child(_count)
	var top := 142.0 + HEAD_DROP
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(MARGIN, top)
	scroll.size = Vector2(_vw - MARGIN * 2.0, _vh - top - MARGIN)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", int(ROW_GAP))
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	for d: Dictionary in Achv.DEFS:
		_list.add_child(_make_row(str(d.id), bool(d.get("ev", false)),
				scroll.size.x - 20.0))


func _draw() -> void:
	UiKit.paint_backdrop(self, Vector2(_vw, _vh), 23)


## 줄 하나 = 뱃지 + 이름 + 설명 + (셀 수 있으면) 진행 바.
func _make_row(id: String, ev: bool, w: float) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(w, ROW_H)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.draw.connect(func() -> void: _draw_row(row, id, ev))
	return row


func _draw_row(ci: Control, id: String, ev: bool) -> void:
	var font := ThemeDB.fallback_font
	var done := Achv.has(id)
	var w := ci.size.x
	ci.draw_style_box(UiKit.panel_box(UiKit.WHITE, 22, 0.0),
			Rect2(Vector2.ZERO, ci.size))
	# 뱃지 — 딴 것은 금색 트로피, 못 딴 것은 회색 자물쇠.
	var c := Vector2(24.0 + BADGE / 2.0, ROW_H / 2.0)
	ci.draw_circle(c, BADGE / 2.0, UiKit.GOLD if done else Color(UiKit.INK, 0.10))
	ci.draw_arc(c, BADGE / 2.0, 0.0, TAU, 40, UiKit.INK, 4.0)
	var mark := "🏆" if done else "🔒"
	var ms := font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 40)
	ci.draw_string(font, c + Vector2(-ms.x / 2.0, 14.0), mark,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 40)
	var x := 24.0 + BADGE + 24.0
	var tw := w - x - 24.0
	var name_col := UiKit.INK if done else Color(UiKit.INK, 0.55)
	ci.draw_string(font, Vector2(x, 52.0), tr("ACHV_%s_NAME" % id),
			HORIZONTAL_ALIGNMENT_LEFT, tw, 30, name_col)
	ci.draw_multiline_string(font, Vector2(x, 86.0), tr("ACHV_%s_DESC" % id),
			HORIZONTAL_ALIGNMENT_LEFT, tw, 21, 2,
			Color(UiKit.INK, 0.62) if done else UiKit.MUTED)
	# 상태 · 진행. 사건형은 셀 수 없으므로 상태만 (Achv.progress()가 목표 0을 준다).
	var status := tr("ACHV_DONE") if done else tr("ACHV_LOCKED")
	var sw := font.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	ci.draw_string(font, Vector2(w - 24.0 - sw, 52.0), status,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
			UiKit.GOLD_DEEP if done else UiKit.MUTED)
	var p := Achv.progress(id)
	if ev or p.y <= 0:
		return
	var cur := mini(p.x, p.y)
	# 숫자를 오른쪽 끝에 먼저 앉히고, 바는 그 앞까지만 그린다 (100000처럼 긴 목표도
	# 잘리지 않게 — 바가 줄어들 뿐이다).
	var num := "%d / %d" % [cur, p.y]
	var nw := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	var bar := Rect2(x, ROW_H - 44.0, maxf(60.0, tw - nw - 16.0), 14.0)
	ci.draw_rect(bar, Color(UiKit.INK, 0.10))
	var frac := float(cur) / float(p.y)
	if frac > 0.0:
		ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)),
				UiKit.GOLD_DEEP if done else UiKit.ORANGE)
	ci.draw_rect(bar, Color(UiKit.INK, 0.30), false, 2.0)
	ci.draw_string(font, Vector2(w - 24.0 - nw, bar.position.y + 14.0), num,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(UiKit.INK, 0.7))


func open() -> void:
	# 들어올 때 한 번 더 판정한다 — 상태형은 소급 적용이라 여기서 열릴 수 있다.
	Achv.check()
	refresh()
	visible = true


func refresh() -> void:
	var done := 0
	for d: Dictionary in Achv.DEFS:
		if Achv.has(str(d.id)):
			done += 1
	_count.text = tr("ACHV_DONE_COUNT").format({"n": done, "m": Achv.DEFS.size()})
	for row: Control in _list.get_children():
		row.queue_redraw()


func close() -> void:
	visible = false
	closed.emit()
