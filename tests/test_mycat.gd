extends Node
## "나만의 캐릭터"(커스텀 슬롯) + 파츠 해금 규칙의 헤드리스 스모크 테스트.
## Run: godot --headless --path . res://tests/test_mycat.tscn
## 세이브는 읽기만 한다 (커스터마이징을 저장하지 않는다).

const CustomCat := preload("res://core/scripts/custom_cat.gd")

var failures := 0


func _ready() -> void:
	# 커스텀 슬롯 자체
	_check(GameState.is_custom_cat("mycat"), "mycat is the custom slot")
	_check(not GameState.is_custom_cat("cream"), "design cats are not custom slots")
	_check(GameState.is_unlocked("mycat"), "mycat is available from the start")
	_check(GameState.keycap_cats().size() == GameState.CATS.size() - 1,
			"mycat is out of the keycap pool")
	_check(GameState.cat_id_for_char("char01") == "cream", "char01 maps to cream")
	_check(GameState.cat_id_for_char("custom") == "", "the blank body has no owner")

	# 출처표: 파츠는 전부 디자인 냥이에게서 온다
	var src := CustomCat.my_sources()
	_check(not src.is_empty(), "part sources are built")
	_check(_idx("eyes", "oval") in CustomCat.my_options("eyes"),
			"char01's eyes are in the catalog")
	_check(not (_idx("eyes", "heart") in CustomCat.my_options("eyes")),
			"parts no design cat wears stay out of the catalog")
	_check(CustomCat.option_sources("head", _idx("head", "none")) == [],
			'"none" is always open')

	# 해금 판정 — 각 옵션은 출처 냥이의 등급을 따라간다
	_check(GameState.part_unlocked("eyes", _idx("eyes", "oval")),
			"the free cat's parts are usable")
	_check(GameState.part_unlocked("head", _idx("head", "none")),
			'"none" needs no unlock')
	_check(GameState.part_unlocked("eyes", _idx("eyes", "iris"))
			== GameState.is_unlocked("black"),
			"char02's eyes follow char02's recruitment")
	# 선글라스는 char02의 2nd 파츠 = 등급 3부터.
	_check(GameState.part_unlocked("face", _idx("face", "sunglasses"))
			== (GameState.cat_grade("black") >= 3),
			"tier parts need the owner's grade")
	var hint := GameState.part_unlock_hint("face", _idx("face", "sunglasses"))
	_check(str(hint.get("cat", "")) == "black" and int(hint.get("grade", 0)) == 3,
			"the lock hint names the cat and the grade it opens at")

	# 백지 몸통이 실제로 조립되는가
	var skin: Dictionary = GameState.cat_skin("mycat")
	_check(not skin.has("sprite"), "mycat is drawn by code, not a sheet sprite")
	_check((skin.get("parts", {}) as Dictionary).has("body_col"),
			"mycat's blank body has parts")
	_check(CustomCat.char_parts("custom").get("ear") == "pointy",
			"the blank body falls back to BLANK_CHAR, not char01")

	if failures == 0:
		print("ALL TESTS PASSED")
	else:
		print("%d TEST(S) FAILED" % failures)
	get_tree().quit(failures)


## 부위 옵션 id -> index.
func _idx(key: String, id: String) -> int:
	var part := CustomCat.get_part(key)
	var opts: Array = part.opts
	for i in opts.size():
		if str(opts[i].id) == id:
			return i
	return -1


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: %s" % label)
	else:
		failures += 1
		print("  FAIL: %s" % label)
