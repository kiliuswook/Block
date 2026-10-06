extends Node
## 세로 화면 비율 점검: 폰(1080×1920) · 태블릿(1200×1920, 10:16) · 긴 폰(1080×2340, 9:19.5)에서
## 모바일 화면들을 찍는다. 모바일 빌드는 stretch aspect가 expand라 뷰포트가 화면 비율만큼
## 늘어난다 — 씬 좌표로 박힌 UI가 따라오는지 본다. → `.tmp_shots/aspect_<화면>_<크기>.png`

const OUT := "E:/WonderWheel/Games/CatTris/dev/.tmp_shots"
const SIZES := [Vector2i(1080, 1920), Vector2i(1200, 1920), Vector2i(1080, 2340)]
const TITLE := "res://mobile/ui/title_mobile.tscn"
const MAIN := "res://mobile/ui/main_mobile.tscn"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await get_tree().process_frame
	var mode := GameState.mode
	for sz: Vector2i in SIZES:
		await _fit(sz)
		var tag := "%dx%d" % [sz.x, sz.y]
		await _shot(TITLE, "title_" + tag, func(i: Node) -> void: i._dismiss_splash())
		await _shot(TITLE, "modes_" + tag, func(i: Node) -> void: i._open_modes())
		await _shot(TITLE, "chars_" + tag, func(i: Node) -> void: i._open_chars())
		await _shot(TITLE, "gacha_" + tag, func(i: Node) -> void: i._open_gacha())
		await _shot(TITLE, "settings_" + tag, func(i: Node) -> void: i._settings.open())
		await _shot(TITLE, "achv_" + tag, func(i: Node) -> void: i._open_achv())
		GameState.mode = GameState.MODE_CLASSIC
		await _shot(MAIN, "classic_" + tag, func(i: Node) -> void:
				i.get_node("TouchControls").visible = true)
		GameState.mode = GameState.MODE_ENDLESS
		await _shot(MAIN, "endless_" + tag, func(i: Node) -> void:
				i.get_node("TouchControls").visible = true)
		await _shot(MAIN, "death_" + tag, func(i: Node) -> void:
				i.get_node("TouchControls").visible = true
				i.get_node("Board")._kill_player()
				if i.user_hud:
					i._reveal_user_hud()
				i.get_node("PopupLayer/DeathPopup").open("", true, "+76", "", "+55", {},
						[["SCORE", "1,520"], ["LEVEL", "2"], ["LINES", "3"]]))
	GameState.mode = mode
	print("aspect_capture done")
	get_tree().quit()


func _fit(sz: Vector2i) -> void:
	var w := get_window()
	w.borderless = true
	w.position = Vector2i.ZERO
	w.content_scale_size = Vector2i(1080, 1920)
	w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	w.size = sz / 2
	await get_tree().process_frame
	await get_tree().process_frame


func _shot(path: String, name: String, setup: Callable) -> void:
	var inst: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	setup.call(inst)
	for i in range(40):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OUT + "/aspect_" + name + ".png")
	inst.queue_free()
	await get_tree().process_frame
