extends Control
## 개발용 임시 확인 패널 — 업적과 리더보드를 **게임 안에서 눈으로 보기 위한** 것.
##
## 원래 업적 목록은 스팀 오버레이가, 리더보드는 랭킹 화면이 맡으므로 게임 안에
## 업적 UI가 없다. 그래서 스팀 없이 개발하는 동안 "지금 뭐가 열렸나 / 어느
## 백엔드로 도나"를 확인할 방법이 없어서 이 패널을 임시로 둔다.
##
## **출시(스팀) 빌드에서는 통째로 뺀다.** 지우는 방법은 둘 중 하나:
##   ① 아래 ENABLED 를 false 로 — 타이틀의 DEV 버튼째로 사라진다 (코드는 남음)
##   ② 이 파일을 지우고 title.gd 의 DEV_PANEL 관련 줄(preload · _dev ·
##      _build_dev_panel() · _unhandled_input 의 Esc 처리)을 제거
##
## 임시 UI라 문구는 개발자용 한국어 그대로 둔다 (번역 CSV에 넣지 않는다).

const UiKit := preload("res://core/scripts/ui_kit.gd")

## 이 하나로 패널 전체(타이틀 DEV 버튼 · 오버레이)가 켜지고 꺼진다.
const ENABLED := true

const TAB_NAMES := ["업적 (Achievements)", "리더보드 (Leaderboards)", "치트 (Cheats)"]

## 치트 탭의 골드 지급 단위.
const GOLD_GRANTS := [1000, 10000, 100000, 1000000]
## 통조림 캔은 주간 랭킹 보상으로만 들어와서 개발 중에는 한 주를 기다려야 한다 —
## 캔 뽑기·유니크 파츠를 바로 만져 보려고 두는 치트.
const CAN_GRANTS := [10, 50, 200]

var _tab := 0  # 0 = 업적, 1 = 리더보드, 2 = 치트
var _fetched := false  # 이번에 연 뒤 보드를 한 번 받아 왔는가
var _body: VBoxContainer
var _tabs: Array[Button] = []
var _note: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func _ready() -> void:
	var vw := get_viewport_rect().size.x
	var vh := get_viewport_rect().size.y
	var dim := Button.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim_sb := StyleBoxFlat.new()
	dim_sb.bg_color = Color(0.06, 0.08, 0.12, 0.72)
	for st in ["normal", "hover", "pressed", "focus"]:
		dim.add_theme_stylebox_override(st, dim_sb)
	dim.pressed.connect(close)
	add_child(dim)
	var pw := minf(vw - 80.0, 1000.0)
	var ph := minf(vh - 80.0, 920.0)
	var card := PanelContainer.new()
	card.position = (Vector2(vw, vh) - Vector2(pw, ph)) / 2.0
	card.size = Vector2(pw, ph)
	card.add_theme_stylebox_override("panel", UiKit.panel_box(UiKit.WHITE, 22, 22.0))
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var head := Label.new()
	head.text = "🛠  개발용 확인 패널  ·  출시 빌드에서는 제거"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 26)
	head.add_theme_color_override("font_color", UiKit.INK)
	v.add_child(head)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	v.add_child(tabs)
	for i in TAB_NAMES.size():
		var b := Button.new()
		b.text = TAB_NAMES[i]
		b.custom_minimum_size = Vector2((pw - 80.0) / float(TAB_NAMES.size()), 48.0)
		var idx := i
		b.pressed.connect(func() -> void:
			Sfx.play("click")
			_tab = idx
			_rebuild())
		tabs.add_child(b)
		_tabs.append(b)
	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_font_size_override("font_size", 15)
	_note.add_theme_color_override("font_color", UiKit.MUTED)
	v.add_child(_note)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	var close_btn := Button.new()
	close_btn.text = "닫기 (Esc)"
	close_btn.custom_minimum_size = Vector2(220.0, 52.0)
	UiKit.btn_ghost(close_btn, 20)
	close_btn.pressed.connect(close)
	var wrap := CenterContainer.new()
	wrap.add_child(close_btn)
	v.add_child(wrap)
	# 보드 조회는 비동기라, 다 받아 오면 그때 다시 그린다.
	Ranks.board_loaded.connect(func(_ok: bool) -> void:
		if visible and _tab == 1:
			_rebuild())


func open() -> void:
	if get_parent() != null:
		get_parent().move_child(self, -1)  # 다른 오버레이 위로
	visible = true
	_fetched = false
	_rebuild()


func close() -> void:
	visible = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _rebuild() -> void:
	for i in _tabs.size():
		UiKit.btn_chip(_tabs[i], i == _tab, 18)
	for c in _body.get_children():
		c.queue_free()
	if _tab == 0:
		_build_achievements()
	elif _tab == 1:
		_build_boards()
	else:
		_build_cheats()


# --- 업적 ---------------------------------------------------------------------


func _build_achievements() -> void:
	var got := 0
	for d: Dictionary in Achv.DEFS:
		if Achv.has(str(d.id)):
			got += 1
	_note.text = "해금 %d / %d  ·  기록은 GameState.achv (save.json), 스팀에는 Platform.unlock_achievement() 로 나간다" \
			% [got, Achv.DEFS.size()]
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	_body.add_child(tools)
	tools.add_child(_tool_btn("↻ 다시 판정 (Achv.check)", UiKit.CYAN_DEEP, func() -> void:
		Achv.check()))
	tools.add_child(_tool_btn("전부 해금", UiKit.ORANGE_DEEP, func() -> void:
		for d: Dictionary in Achv.DEFS:
			Achv.unlock(str(d.id))))
	tools.add_child(_tool_btn("해금 기록 비우기", UiKit.RED_DEEP, func() -> void:
		GameState.achv.clear()
		GameState.save_game()))
	for d: Dictionary in Achv.DEFS:
		_body.add_child(_achv_row(d))


func _achv_row(d: Dictionary) -> Control:
	var id := str(d.id)
	var got := Achv.has(id)
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.bg_color = Color("e7f6e2") if got else Color("f2f5f9")
	sb.set_border_width_all(2)
	sb.border_color = Color(0.24, 0.6, 0.3, 0.7) if got else Color(UiKit.INK, 0.12)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 7.0
	sb.content_margin_bottom = 7.0
	row.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	row.add_child(h)
	var mark := Label.new()
	mark.text = "★" if got else "☆"
	mark.custom_minimum_size.x = 26.0
	mark.add_theme_font_size_override("font_size", 20)
	mark.add_theme_color_override("font_color",
			UiKit.GOLD_DEEP if got else UiKit.MUTED)
	h.add_child(mark)
	var name_l := Label.new()
	name_l.text = id
	name_l.custom_minimum_size.x = 190.0
	name_l.add_theme_font_size_override("font_size", 17)
	name_l.add_theme_color_override("font_color", UiKit.INK)
	h.add_child(name_l)
	var cond := Label.new()
	cond.text = "%s%s" % [str(d.get("cond", "")),
			"   [사건형]" if bool(d.get("ev", false)) else ""]
	cond.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cond.add_theme_font_size_override("font_size", 16)
	cond.add_theme_color_override("font_color", Color(UiKit.INK, 0.8))
	h.add_child(cond)
	var prog := Label.new()
	prog.text = _progress(id, bool(d.get("ev", false)))
	prog.custom_minimum_size.x = 110.0
	prog.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prog.add_theme_font_size_override("font_size", 16)
	prog.add_theme_color_override("font_color", UiKit.GOLD_DEEP)
	h.add_child(prog)
	var t := Button.new()
	t.text = "잠그기" if got else "해금"
	t.custom_minimum_size = Vector2(84.0, 34.0)
	UiKit.btn_card(t, UiKit.PURPLE_DEEP if got else UiKit.CYAN_DEEP, 15)
	t.pressed.connect(func() -> void:
		Sfx.play("click")
		if Achv.has(id):
			GameState.achv.erase(id)
			GameState.save_game()
		else:
			Achv.unlock(id)
		_rebuild())
	h.add_child(t)
	return row


## 상태형 업적의 현재 진행 — 세는 것은 Achv.progress()가 하고, 여기선 표시만 한다.
func _progress(id: String, ev: bool) -> String:
	if ev or id == Achv.FIRST_ESCAPE:
		return "사건형"
	var p := Achv.progress(id)
	return "" if p.y <= 0 else _frac(p.x, p.y)


func _frac(cur: int, goal: int) -> String:
	return "%d / %d" % [mini(cur, goal), goal]


# --- 치트 -------------------------------------------------------------------


## 개발 중에 상점·뽑기를 마음껏 돌려 보려고 두는 재화 치트.
func _build_cheats() -> void:
	_note.text = "지금 골드: %s  ·  캔: %s  —  개발용 치트라 세이브에 그대로 들어간다 (출시 빌드에서는 패널째로 빠진다)" % [_comma(GameState.gold), _comma(GameState.cans)]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_body.add_child(row)
	for amount: int in GOLD_GRANTS:
		var add := amount
		row.add_child(_tool_btn("+ %s G" % _comma(add), UiKit.GOLD_DEEP, func() -> void:
			GameState.add_currency(add)  # 누적 획득에도 반영 (골드 업적 확인용)
			_refresh_wallet()))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	_body.add_child(row2)
	row2.add_child(_tool_btn("골드 0 으로", UiKit.RED_DEEP, func() -> void:
		GameState.gold = 0
		GameState.save_game()
		_refresh_wallet()))
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 8)
	_body.add_child(row3)
	for amount: int in CAN_GRANTS:
		var add := amount
		row3.add_child(_tool_btn("+ %d 캔" % add, UiKit.CAN_DEEP, func() -> void:
			GameState.add_cans(add)
			_refresh_wallet()))
	row3.add_child(_tool_btn("캔 0 으로", UiKit.RED_DEEP, func() -> void:
		GameState.cans = 0
		GameState.save_game()
		_refresh_wallet()))
	_body.add_child(_kv("골드", _comma(GameState.gold)))
	_body.add_child(_kv("누적 획득 골드", _comma(GameState.gold_earned)))
	_body.add_child(_kv("통조림 캔", _comma(GameState.cans)))
	_body.add_child(_kv("누적 획득 캔", _comma(GameState.cans_earned)))


## 치트로 재화를 바꾼 뒤 패널의 골드 표시와 타이틀의 유저 HUD(지갑)를 다시 그린다.
func _refresh_wallet() -> void:
	var scene := get_tree().current_scene
	if scene and scene.has_method("_refresh_currency"):
		scene.call("_refresh_currency")
	_rebuild()


func _comma(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return ("-" if n < 0 else "") + out


# --- 리더보드 ------------------------------------------------------------------


func _build_boards() -> void:
	# 탭을 처음 열었을 때 한 번만 자동으로 받아 온다 (board_loaded 가 다시 그린다).
	if not _fetched and Ranks.online():
		_fetched = true
		_fetch_all()
	var names := ["OFFLINE (봇 크루 + 내 기록)", "HTTP (jsonblob)", "STEAM",
			"SERVER (Supabase)"]
	_note.text = "백엔드: %s  ·  플랫폼: %s  ·  %d주차 (리셋까지 %s)" % [
			names[Ranks.backend()], Platform.platform_name(), Ranks.week_id(),
			Ranks.week_remaining_text()]
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	_body.add_child(tools)
	tools.add_child(_tool_btn("↻ 보드 다시 받기", UiKit.CYAN_DEEP, _fetch_all))
	tools.add_child(_tool_btn("내 기록 전부 제출", UiKit.ORANGE_DEEP, func() -> void:
		Ranks.submit_all()))
	var persona := Platform.user_name()
	_body.add_child(_kv("내 id", Ranks.my_id()))
	_body.add_child(_kv("이름", persona if persona != ""
			else "(스팀 페르소나 없음 — GameState.nickname: %s)" % GameState.nickname))
	_body.add_child(_kv("리더보드 지원", "예" if Platform.has_leaderboards() else "아니오"))
	_body.add_child(_kv("불러오는 중", "예" if Ranks.busy else "아니오"))
	for m: String in Ranks.LIVE_MODES:
		for weekly in [false, true]:
			_body.add_child(_board_block(m, weekly))


## 살아 있는 모드의 누적·주간 보드를 차례로 받아 온다.
func _fetch_all() -> void:
	for m: String in Ranks.LIVE_MODES:
		for weekly in [false, true]:
			await Ranks.view(m, weekly)


## 보드 하나 — 이름·엔트리 수·내 순위 + 상위 5줄. (전체 목록은 타이틀의 랭킹 화면)
func _board_block(mode_key: String, weekly: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var list := Ranks.entries(mode_key, weekly)
	var mine := Ranks.my_id()
	var my_v := GameState.weekly_value(mode_key) if weekly \
			else Ranks.local_value(mode_key)
	var rank := Ranks.my_rank(mode_key, weekly)
	var head := Label.new()
	head.text = "▸ %s   (%s)   엔트리 %d   ·   내 순위 %s   ·   내 기록 %s" % [
			Ranks.board_name(mode_key, weekly), "주간" if weekly else "누적",
			list.size(), "%d위" % rank if rank > 0 else "-",
			Ranks.value_text(mode_key, my_v)]
	head.add_theme_font_size_override("font_size", 17)
	head.add_theme_color_override("font_color", UiKit.INK)
	box.add_child(head)
	if list.is_empty():
		box.add_child(_dim_label("      (비어 있음)"))
	for i in mini(list.size(), 5):
		var e: Dictionary = list[i]
		var me := str(e.get("id")) == mine
		var l := _dim_label("      %d. %s%s  —  %s%s" % [i + 1,
				str(e.get("name", "???")), "  ◀ 나" if me else "",
				Ranks.value_text(mode_key, int(e.get("v", 0))),
				"   ▶리플레이" if Ranks.has_replay_for(mode_key, e) else ""])
		if me:
			l.add_theme_color_override("font_color", UiKit.GOLD_DEEP)
		box.add_child(l)
	return box


# --- 공용 조각 ----------------------------------------------------------------


func _tool_btn(text: String, accent: Color, act: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0.0, 40.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.btn_card(b, accent, 16)
	b.pressed.connect(func() -> void:
		Sfx.play("click")
		act.call()  # 보드 조회 같은 비동기 작업은 board_loaded 로 다시 그려진다
		_rebuild())
	return b


func _kv(key: String, value: String) -> Control:
	var l := Label.new()
	l.text = "%s : %s" % [key, value]
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(UiKit.INK, 0.85))
	return l


func _dim_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", UiKit.MUTED)
	return l
