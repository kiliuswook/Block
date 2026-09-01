extends Node
## "나만의 캐릭터"(커스텀 슬롯) + 파츠 해금 규칙의 헤드리스 스모크 테스트.
## Run: godot --headless --path . res://tests/test_mycat.tscn
## 세이브는 읽기만 한다 (커스터마이징을 저장하지 않는다).

const CustomCat := preload("res://core/scripts/custom_cat.gd")
const CatSprite := preload("res://core/scripts/cat_sprite.gd")

var failures := 0


func _ready() -> void:
	# 실기 세이브를 그대로 읽으므로, 판정에 쓰는 상태는 먼저 비워 고정한다.
	GameState.save_enabled = false
	GameState.cat_custom.erase("mycat")
	GameState.parts_owned = {}
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
	_check(_idx("eyes", "nosuch") < 0, "unknown option ids are not in the catalog")
	# [임시 · 임시 파츠와 함께 되돌릴 것] 원래는 "디자인 냥이가 안 입은 파츠는
	# 카탈로그에 없다"를 확인하던 자리다. 지금은 임시 파츠가 그 자리를 채우고
	# 있고, 임시 파츠는 해금 없이 늘 열려 있어야 한다.
	# [임시 · 임시 파츠와 함께 되돌릴 것] 임시 파츠도 카탈로그에 선다.
	_check(_idx("eyes", "heart") in CustomCat.my_options("eyes"),
			"임시 파츠가 카탈로그에 있다")
	_check(CustomCat.option_sources("head", _idx("head", "none")) == [],
			'"none" is always open')

	# 해금 판정 — 파츠는 기본적으로 잠겨 있고 골드로 산다
	_check(GameState.part_free("eyes", _idx("eyes", "oval")),
			"the blank body's own parts are free")
	_check(GameState.part_free("head", _idx("head", "none")),
			'"none" needs no purchase')
	var iris := _idx("eyes", "iris")
	_check(not GameState.part_unlocked("eyes", iris),
			"every other part starts locked")
	_check(GameState.part_price("eyes", iris)
			== GameState.PART_PRICES[1], "the price follows the rarity")
	_check(GameState.part_price("body", 2) == GameState.PART_COLOR_PRICE,
			"colors have one flat price")
	# 골드가 모자라면 지갑도 파츠도 그대로다.
	GameState.gold = 0
	_check(not GameState.buy_part("eyes", iris), "no gold, no part")
	_check(not GameState.part_unlocked("eyes", iris), "the failed buy changed nothing")
	GameState.gold = 10000
	_check(GameState.buy_part("eyes", iris), "the part is bought")
	_check(GameState.part_unlocked("eyes", iris), "and usable right away")
	_check(GameState.gold == 10000 - GameState.PART_PRICES[1], "the gold is spent")
	_check(GameState.part_price("eyes", iris) == 0, "an owned part costs nothing")
	# 출처(어느 냥이의 파츠였나)는 안내 문구로만 남아 있다.
	var hint := GameState.part_unlock_hint("face", _idx("face", "sunglasses"))
	_check(str(hint.get("cat", "")) == "black" and int(hint.get("grade", 0)) == 3,
			"the origin hint still names the cat")

	# 백지 몸통이 실제로 조립되는가
	var skin: Dictionary = GameState.cat_skin("mycat")
	_check(not skin.has("sprite"),
			"mycat is not one design cat's finished render")
	# 나만의 캐릭터는 디자인 냐이들의 시트 파츠 그림을 섞어 그린다.
	var mix: Dictionary = skin.get("mix", {})
	_check(not mix.is_empty(), "mycat is assembled from sheet part layers")
	_check(mix.has("Cat_Body_Outline") and mix.has("Cat_Eyes_Color"),
			"the body and eyes come from a real cat's layers")
	for layer: String in mix:
		_check(not CatSprite.find_layer(str(mix[layer]), layer).is_empty(),
				"layer %s exists on %s" % [layer, mix[layer]])
	_check(not (skin.get("tints", {}) as Dictionary).is_empty(),
			"the mix carries its layer tints")
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
