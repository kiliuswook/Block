extends Node
## 피그마 대조용 빠른 캡처 — 가로 화면 주요 상태만 찍어 .tmp_shots/fig_*.png 로 남긴다.
## 실행: godot --path E:\WonderWheel\Games\CatTris\dev res://tests/figma_shots.tscn

const OUT := "E:/WonderWheel/Games/CatTris/dev/.tmp_shots"
const T := "res://core/scenes/title.tscn"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var w := get_window()
	w.borderless = true
	w.position = Vector2i.ZERO
	w.size = Vector2i(1920, 1080)
	w.content_scale_size = Vector2i(1920, 1080)
	await get_tree().process_frame
	var only := OS.get_cmdline_user_args()
	var shots := [
		["menu", T, func(i: Node) -> void: i._dismiss_splash()],
		["splash", T, Callable()],
		["modes", T, func(i: Node) -> void: i._open_modes()],
		["chars", T, func(i: Node) -> void:
			i._open_chars()
			i._char_view = "cream"
			i._refresh_char_page()],
		["mycat", T, func(i: Node) -> void:
			i._open_chars()
			i._char_view = "mycat"
			i._refresh_char_page()],
		["mycat_eyes", T, func(i: Node) -> void:
			i._open_chars()
			i._char_view = "mycat"
			i._refresh_char_page()
			var cc: Node = i._customizer
			for n in cc._rows.size():
				if (cc._rows[n].get_child(1) as Label).text == tr("CAT_GROUP_EYES"):
					cc._cur = n
			cc._refresh()],
		["shop", T, func(i: Node) -> void: i._open_gacha()],
		["pick", T, func(i: Node) -> void:
			i._open_gacha()
			i._open_gacha_pick()],
		["ranks", T, func(i: Node) -> void: i._open_ranks()],
		["settings", T, func(i: Node) -> void: i._settings.open()],
		["set_pad", T, func(i: Node) -> void:
			i._settings.open()
			i._settings._show_page(i._settings.PAGE_PAD)],
		["set_keys", T, func(i: Node) -> void:
			i._settings.open()
			i._settings._show_page(i._settings.PAGE_KEYS)],
		["feature", T, func(i: Node) -> void:
			i._open_chars()
			i._char_view = "cream"
			i._refresh_char_page()
			i._open_feature_ask()],
		["nick", T, func(i: Node) -> void:
			i._dismiss_splash()
			i._open_nick_pop()],
		["play", "res://core/scenes/main.tscn", Callable()],
	]
	for s: Array in shots:
		if not only.is_empty() and not only.has(str(s[0])):
			continue
		var inst: Node = (load(str(s[1])) as PackedScene).instantiate()
		get_tree().root.add_child(inst)
		var setup: Callable = s[2]
		if setup.is_valid():
			setup.call(inst)
		for f in 30:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(OUT + "/fig_%s.png" % s[0])
		inst.queue_free()
		await get_tree().process_frame
	get_tree().quit()
