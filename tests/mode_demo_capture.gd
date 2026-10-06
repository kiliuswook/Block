extends Node
## 모드 선택 카드의 데모 플레이 캡처 — 시간차로 몇 장 찍어 움직임을 확인한다.
## 세로 확인은 `-- --mobile` 인자로 띄운다(파일 이름 앞에 m_).

const OUT := "E:/WonderWheel/Games/CatTris/dev/.tmp_shots"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var pre := "m_" if OS.get_cmdline_user_args().has("--mobile") or OS.get_cmdline_args().has("--mobile") else ""
	await get_tree().process_frame
	var scene := "res://core/scenes/title.tscn"
	if pre != "":
		scene = "res://mobile/ui/title_mobile.tscn"
		var w := get_window()
		w.borderless = true
		w.position = Vector2i.ZERO
		w.size = Vector2i(1080, 1920)
		w.content_scale_size = Vector2i(1080, 1920)
		await get_tree().process_frame
		await get_tree().process_frame
	var inst: Node = (load(scene) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	await get_tree().process_frame
	inst._open_modes()
	for i in 4:
		await get_tree().create_timer(3.0 if i == 0 else 6.0).timeout
		get_viewport().get_texture().get_image().save_png(OUT + "/%smode_demo_%d.png" % [pre, i])
	inst._select_mode_card(1)
	await get_tree().create_timer(4.0).timeout
	get_viewport().get_texture().get_image().save_png(OUT + "/%smode_demo_sel.png" % pre)
	get_tree().quit()
