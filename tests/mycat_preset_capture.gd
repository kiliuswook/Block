extends Node
## 나만의 냥이 탭의 "원본 냥이" 프리셋 캡처 — 가진 냥이만 늘어서고(신규 10종 포함),
## 신규 냥이를 불러오면 그 냥이의 파츠 레이어로 조립되는지 본다. 세이브는 쓰지 않는다.
## 결과: .tmp_shots/title_mycat_preset.png · title_mycat_preset_baker.png ·
##       title_mycat_preset_ninja.png

const OUT := "E:/WonderWheel/Games/CatTris/dev/.tmp_shots"


func _ready() -> void:
	GameState.save_enabled = false
	await get_tree().process_frame  # 루트가 자식을 받을 수 있을 때까지
	var caps := {}
	# 크림(무료) + 신규 넷을 서로 다른 등급으로 — 나머지는 잠김이라 목록에 없어야 한다.
	for pair: Array in [["cream", 4], ["baker", 4], ["pirate", 2], ["ninja", 4], ["cow", 1]]:
		var d := {}
		for j in 26:
			d[char(65 + j)] = int(pair[1])
		caps[str(pair[0])] = d
	GameState.keycaps = caps
	GameState.cat_custom.erase("mycat")
	await _shot("title_mycat_preset.png", "")
	await _shot("title_mycat_preset_baker.png", "char07")
	await _shot("title_mycat_preset_ninja.png", "char10")
	get_tree().quit()


func _shot(file: String, preset: String) -> void:
	var inst: Node = (load("res://core/scenes/title.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	inst._open_chars()
	inst._char_view = "mycat"
	inst._refresh_char_page()
	inst._customizer._cur = 0
	inst._customizer._refresh()
	if preset != "":
		inst._customizer._load_preset(preset)
	for i in 40:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OUT + "/" + file)
	print("saved ", file)
	inst.queue_free()
	await get_tree().process_frame
