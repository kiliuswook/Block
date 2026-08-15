extends Node
## Global game state: score, progress, currency, characters, save/load.

const SAVE_PATH := "user://save.json"

const MODE_STORY := 0
const MODE_ENDLESS := 1
const MODE_VERSUS := 2
const MODE_CLASSIC := 3  # arcade tetris: clear lines, survive, stage up
const MODE_PICNIC := 4  # casual jelly picnic: no death, collect snacks on a timer

## Playable cube-cat skins. Unlock types:
##  free — always available / gold, gems — purchasable / height — endless best
##  story — story-mode stage cleared / plays — total games played.
## Per-cat stat multipliers (1.0 = baseline cream):
##  speed — run speed / jump — jump velocity / dash — dash speed & cooldown
##  weight — heavier falls harder when fast-falling and resists knockback,
##  lighter floats but gets flung further.
##  push — dash shove power in cells: 1 shoves the piece exactly one cell.
const CATS: Array[Dictionary] = [
	{"id": "cream", "name": "CAT_CREAM", "body": Color("f4e3c8"), "ear": Color("d9a05c"),
		"unlock": {"type": "free"}, "trait": "TRAIT_BALANCED",
		"stats": {"speed": 1.0, "jump": 1.0, "dash": 1.0, "weight": 1.0, "push": 2}},
	{"id": "cheese", "name": "CAT_CHEESE", "body": Color("f5b352"), "ear": Color("e08a3c"),
		"unlock": {"type": "gold", "amount": 300}, "trait": "TRAIT_HEAVY",
		"stats": {"speed": 0.92, "jump": 0.96, "dash": 1.0, "weight": 1.3, "push": 3}},
	{"id": "calico", "name": "CAT_CALICO", "body": Color("f2e6d4"), "ear": Color("8a5a33"),
		"unlock": {"type": "score", "amount": 2000}, "trait": "TRAIT_DASHKING",
		"stats": {"speed": 1.04, "jump": 0.97, "dash": 1.18, "weight": 0.95, "push": 4}},
	{"id": "black", "name": "CAT_BLACK", "body": Color("3a3540"), "ear": Color("26232c"),
		"ink": Color("f0d060"), "unlock": {"type": "height", "floors": 10},
		"trait": "TRAIT_SPRINTER",
		"stats": {"speed": 1.15, "jump": 1.0, "dash": 1.05, "weight": 0.9, "push": 2}},
	{"id": "gray", "name": "CAT_GRAY", "body": Color("aeb6c2"), "ear": Color("7e8694"),
		"unlock": {"type": "gold", "amount": 500}, "trait": "TRAIT_HEAVYJUMP",
		"stats": {"speed": 0.94, "jump": 1.06, "dash": 0.9, "weight": 1.2, "push": 3}},
	{"id": "mint", "name": "CAT_MINT", "body": Color("bfe8d5"), "ear": Color("6fbf9a"),
		"unlock": {"type": "height", "floors": 30}, "trait": "TRAIT_JUMPKING",
		"stats": {"speed": 0.96, "jump": 1.12, "dash": 0.95, "weight": 0.9, "push": 1}},
	{"id": "pink", "name": "CAT_PINK", "body": Color("f6cdd8"), "ear": Color("e08ea6"),
		"unlock": {"type": "gold", "amount": 800}, "trait": "TRAIT_SWIFT",
		"stats": {"speed": 1.08, "jump": 1.06, "dash": 1.0, "weight": 0.8, "push": 2}},
	{"id": "ghost", "name": "CAT_GHOST", "body": Color(0.93, 0.96, 1.0, 0.6),
		"ear": Color(0.75, 0.8, 0.95, 0.55), "ink": Color("5a6a8a"),
		"unlock": {"type": "plays", "count": 20}, "trait": "TRAIT_FEATHER",
		"stats": {"speed": 1.0, "jump": 1.04, "dash": 1.1, "weight": 0.72, "push": 1}},
	{"id": "gold", "name": "CAT_GOLD", "body": Color("f7d354"), "ear": Color("c9982a"),
		"unlock": {"type": "gems", "amount": 20}, "trait": "TRAIT_ALLROUND",
		"stats": {"speed": 1.05, "jump": 1.04, "dash": 1.05, "weight": 1.05, "push": 3}},
	# 나만의 냥: 외형은 CustomCat 카탈로그(custom_cat 저장값)로 결정되는 커스텀 슬롯.
	{"id": "custom", "name": "CAT_CUSTOM", "body": Color("f4e3c8"), "ear": Color("d9a05c"),
		"unlock": {"type": "free"}, "trait": "TRAIT_CUSTOM",
		"stats": {"speed": 1.0, "jump": 1.0, "dash": 1.0, "weight": 1.0, "push": 2}},
]

const CustomCat := preload("res://core/scripts/custom_cat.gd")

## Procedural accessories, drawn by Player.paint_cat on top of the skin.
## Two independent slots (head / neck), purely cosmetic — no stat effects.
## kind selects the draw routine in player.gd; col/col2 tint it.
const ACCESSORIES: Array[Dictionary] = [
	{"id": "beanie", "name": "ACC_BEANIE", "slot": "head", "kind": "beanie",
		"price": {"type": "gold", "amount": 200},
		"col": Color("5a8fd0"), "col2": Color("e8eef6")},
	{"id": "leaf", "name": "ACC_LEAF", "slot": "head", "kind": "leaf",
		"price": {"type": "gold", "amount": 250},
		"col": Color("7ec850"), "col2": Color("5a9a38")},
	{"id": "ribbon", "name": "ACC_RIBBON", "slot": "head", "kind": "ribbon",
		"price": {"type": "gold", "amount": 300},
		"col": Color("e0607a"), "col2": Color("b84760")},
	{"id": "flower", "name": "ACC_FLOWER", "slot": "head", "kind": "flower",
		"price": {"type": "gold", "amount": 400},
		"col": Color("f6cdd8"), "col2": Color("f2b93e")},
	{"id": "wizard", "name": "ACC_WIZARD", "slot": "head", "kind": "wizard",
		"price": {"type": "gold", "amount": 1200},
		"col": Color("6a55b0"), "col2": Color("f2d365")},
	{"id": "tophat", "name": "ACC_TOPHAT", "slot": "head", "kind": "tophat",
		"price": {"type": "gold", "amount": 1500},
		"col": Color("2c2833"), "col2": Color("b8433f")},
	{"id": "crown", "name": "ACC_CROWN", "slot": "head", "kind": "crown",
		"price": {"type": "gold", "amount": 3000},
		"col": Color("f2c94c"), "col2": Color("e05f5f")},
	{"id": "halo", "name": "ACC_HALO", "slot": "head", "kind": "halo",
		"price": {"type": "gems", "amount": 12},
		"col": Color("fff3d0"), "col2": Color("f7d354")},
	{"id": "bell", "name": "ACC_BELL", "slot": "neck", "kind": "bell",
		"price": {"type": "gold", "amount": 200},
		"col": Color("b8433f"), "col2": Color("f2c94c")},
	{"id": "scarf", "name": "ACC_SCARF", "slot": "neck", "kind": "scarf",
		"price": {"type": "gold", "amount": 300},
		"col": Color("c94f43"), "col2": Color("a83d33")},
	{"id": "bowtie", "name": "ACC_BOWTIE", "slot": "neck", "kind": "bowtie",
		"price": {"type": "gold", "amount": 400},
		"col": Color("4a6fb8"), "col2": Color("35507f")},
	{"id": "bandana", "name": "ACC_BANDANA", "slot": "neck", "kind": "bandana",
		"price": {"type": "gold", "amount": 800},
		"col": Color("d08a3c"), "col2": Color("f4e3c8")},
	{"id": "goldchain", "name": "ACC_GOLDCHAIN", "slot": "neck", "kind": "goldchain",
		"price": {"type": "gold", "amount": 3000},
		"col": Color("f2c94c"), "col2": Color("c9982a")},
	{"id": "gemchain", "name": "ACC_GEMCHAIN", "slot": "neck", "kind": "gemchain",
		"price": {"type": "gems", "amount": 10},
		"col": Color("d8dee8"), "col2": Color("6fd0e8")},
]

## One-run boosts for endless mode, bought before a run and consumed on start.
const BOOSTS: Array[Dictionary] = [
	{"id": "warmup", "name": "BOOST_WARMUP", "desc": "BOOST_WARMUP_DESC", "price": 50},
	{"id": "fever", "name": "BOOST_FEVER", "desc": "BOOST_FEVER_DESC", "price": 40},
	{"id": "lucky", "name": "BOOST_LUCKY", "desc": "BOOST_LUCKY_DESC", "price": 60},
]

## Snack price scales with the cat's current level: 50 + 50×level gold.
const SNACK_PRICE_BASE := 50
const SNACK_PRICE_STEP := 50
## Cumulative snacks needed for affection level 1..10 (level 1 is the base).
const AFFECTION_STEPS := [0, 1, 2, 4, 6, 9, 12, 16, 20, 25]
const SNACK_MAX := 25
## Stat growth per affection level above 1 (speed/jump/dash), +9% at Lv.10.
const AFFECTION_STAT_STEP := 0.01
const SKIP_COST := 3  # gems to skip a story stage after repeated failures

var mode: int = MODE_CLASSIC
var split: bool = false  # 2-player split screen (escape race/endless only), not saved
var best_height: int = 0
var classic_best: int = 0  # classic mode all-time high score
var picnic_best: int = 0  # jelly picnic all-time high score
var story_stage: int = 0  # highest story stage cleared
var games_played: int = 0
var gold: int = 0
var gems: int = 0
var selected_cat: String = "cream"
var nickname: String = ""  # leaderboard name — defaults to 냥이-XXXX on first run
var player_id: String = ""  # stable random id identifying this save on boards
var weekly: Dictionary = {}  # this week's bests: {"week": id, "story": n, ...}
var weekly_claimed: int = 0  # last finished week whose prize was checked
var purchased: Array = []  # ids of cats bought with gold/gems
var acc_owned: Array = []  # ids of purchased accessories
var acc_head: String = ""  # equipped accessory per slot ("" = none)
var acc_neck: String = ""
var affection: Dictionary = {}  # cat id -> total snacks fed
var pending_boosts: Array = []  # boost ids paid for, consumed by the next endless run
var skipped_stages: Array = []  # story stages passed with a skip ticket
var keycaps: Dictionary = {}  # collected alphabet keycaps: "A".."Z" -> count
var custom_cat: Dictionary = {}  # 나만의 냥 part picks: part key -> option index
var last_daily: String = ""  # date the daily first-run double-gold was claimed
var locale: String = ""  # chosen UI language ("" = follow the system locale)
# Volume settings (linear 0..1) — applied to the audio buses by the Sfx autoload.
var vol_master: float = 1.0
var vol_bgm: float = 0.8
var vol_sfx: float = 1.0

var score: int = 0:
	set(value):
		score = value
		EventBus.score_changed.emit(score)


func _ready() -> void:
	load_game()
	if player_id == "":
		randomize()
		player_id = "%08x" % (randi() & 0x7fffffff)
		save_game()
	if nickname == "":
		nickname = tr("NICKNAME_DEFAULT").format({"n": "%04d" % (randi() % 10000)})
		save_game()
	EventBus.game_started.connect(func() -> void: games_played += 1)


func set_nickname(n: String) -> void:
	n = n.strip_edges().left(12)
	if n == "" or n == nickname:
		return
	nickname = n
	save_game()
	Ranks.rename_and_resubmit()


func reset() -> void:
	score = 0


## Full progress wipe (설정 > 게임 초기화): records, story progress, wallet,
## unlocked cats, accessories, affection, keycaps, custom cat, weekly bests.
## Keeps the volume settings, language, nickname and player_id (same identity).
func reset_all() -> void:
	score = 0
	best_height = 0
	classic_best = 0
	picnic_best = 0
	story_stage = 0
	games_played = 0
	gold = 0
	gems = 0
	selected_cat = "cream"
	weekly = {}
	weekly_claimed = 0
	purchased = []
	acc_owned = []
	acc_head = ""
	acc_neck = ""
	affection = {}
	pending_boosts = []
	skipped_stages = []
	keycaps = {}
	custom_cat = {}
	last_daily = ""
	save_game()


## Records a cleared story stage (progress only ever moves forward).
## A first-time clear pays a reward: 20~50 gold scaling with the stage, plus
## 2 gems at every 10-stage boss. Announced via EventBus.story_reward.
func story_clear(stage_num: int) -> void:
	# Weekly board counts every clear — replayed stages included.
	var weekly_up := record_weekly("story", stage_num)
	if stage_num <= story_stage:
		if weekly_up:
			Ranks.submit("story", story_stage)
		return
	story_stage = stage_num
	var reward_gold := 20 + stage_num / 4
	var reward_gems := 2 if stage_num % 10 == 0 else 0
	add_currency(reward_gold, reward_gems)  # save_game included
	EventBus.story_reward.emit(reward_gold, reward_gems)
	Ranks.submit("story", story_stage)


## Skip ticket: marks the stage as passed without paying the first-clear
## reward. The stage is remembered as skipped (shown differently in UI).
func story_skip(stage_num: int) -> void:
	if stage_num not in skipped_stages:
		skipped_stages.append(stage_num)
	story_stage = maxi(story_stage, stage_num)
	save_game()


## Records a finished classic run. Returns true on a new all-time high score.
func record_classic(s: int) -> bool:
	if s <= classic_best:
		return false
	classic_best = s
	save_game()
	Ranks.submit("classic", classic_best)
	return true


## Records a finished picnic run. Returns true on a new all-time high score.
func record_picnic(s: int) -> bool:
	if s <= picnic_best:
		return false
	picnic_best = s
	save_game()
	Ranks.submit("picnic", picnic_best)
	return true


## Records a finished endless run. Returns true if it set a new all-time best.
func record_height(h: int) -> bool:
	if h <= best_height:
		return false
	best_height = h
	save_game()
	Ranks.submit("endless", best_height)
	return true


# --- Weekly bests (weekly leaderboards reset Monday 00:00 KST) ------------------


func _roll_weekly() -> void:
	var wk: int = Ranks.week_id()
	if int(weekly.get("week", -1)) != wk:
		weekly = {"week": wk, "story": 0, "endless": 0, "classic": 0, "picnic": 0}


func weekly_value(mode_key: String) -> int:
	_roll_weekly()
	return int(weekly.get(mode_key, 0))


## Records a run result on this week's board. Returns true when it improved.
func record_weekly(mode_key: String, v: int) -> bool:
	_roll_weekly()
	if v <= int(weekly.get(mode_key, 0)):
		return false
	weekly[mode_key] = v
	save_game()
	return true


func add_currency(add_gold: int, add_gems: int) -> void:
	gold += add_gold
	gems += add_gems
	save_game()


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	save_game()
	return true


func spend_gems(amount: int) -> bool:
	if gems < amount:
		return false
	gems -= amount
	save_game()
	return true


## True once per calendar day: the first rewarded run pays double gold.
func claim_daily_bonus() -> bool:
	var today := Time.get_date_string_from_system()
	if last_daily == today:
		return false
	last_daily = today
	save_game()
	return true


# --- Keycaps (alphabet collection) ---------------------------------------------


func keycap_count(letter: String) -> int:
	return int(keycaps.get(letter, 0))


## Distinct letters collected so far (dex completion, 0..26).
func keycap_kinds() -> int:
	return keycaps.size()


func keycap_total() -> int:
	var total := 0
	for letter in keycaps:
		total += int(keycaps[letter])
	return total


## A cleared line held a keycap block: bank the letter (duplicates stack).
func add_keycap(letter: String) -> void:
	keycaps[letter] = keycap_count(letter) + 1
	save_game()
	EventBus.keycap_collected.emit(letter, keycap_count(letter))


# --- Accessories --------------------------------------------------------------


func get_acc(id: String) -> Dictionary:
	for acc in ACCESSORIES:
		if acc.id == id:
			return acc
	return {}


func try_buy_acc(id: String) -> bool:
	if id in acc_owned:
		return false
	var price: Dictionary = get_acc(id).get("price", {})
	var paid := spend_gold(int(price.amount)) if price.get("type") == "gold" \
			else spend_gems(int(price.amount))
	if not paid:
		return false
	acc_owned.append(id)
	save_game()
	return true


## Equips an owned accessory into its slot; equipping the worn one takes it off.
func toggle_acc(id: String) -> void:
	if id not in acc_owned:
		return
	var slot := str(get_acc(id).get("slot", "head"))
	if slot == "head":
		acc_head = "" if acc_head == id else id
	else:
		acc_neck = "" if acc_neck == id else id
	save_game()


## Accessory defs the given cat should wear — only the selected cat dresses up.
func equipped_accs(cat_id: String) -> Array:
	if cat_id != selected_cat:
		return []
	var accs: Array = []
	for id in [acc_head, acc_neck]:
		if id != "":
			var acc := get_acc(id)
			if not acc.is_empty():
				accs.append(acc)
	return accs


# --- Boosts (endless, one run) -------------------------------------------------


func get_boost(id: String) -> Dictionary:
	for b in BOOSTS:
		if b.id == id:
			return b
	return {}


## Buys a boost for the next endless run, or refunds it when already pending.
## Returns true if the toggle went through (false = not enough gold).
func toggle_boost(id: String) -> bool:
	var price := int(get_boost(id).get("price", 0))
	if id in pending_boosts:
		pending_boosts.erase(id)
		add_currency(price, 0)  # save included
		return true
	if not spend_gold(price):
		return false
	pending_boosts.append(id)
	save_game()
	return true


## Hands the paid boosts to the board starting an endless run and clears them.
func take_boosts() -> Array:
	var taken := pending_boosts
	pending_boosts = []
	if not taken.is_empty():
		save_game()
	return taken


# --- Affection (snacks) ---------------------------------------------------------


func affection_fed(id: String) -> int:
	return int(affection.get(id, 0))


## Affection level 1..10 from cumulative snacks fed.
func affection_level(id: String) -> int:
	var fed := affection_fed(id)
	var level := 1
	for i in range(AFFECTION_STEPS.size()):
		if fed >= AFFECTION_STEPS[i]:
			level = i + 1
	return level


## Snacks still needed for the next affection level (0 at max).
func snacks_to_next(id: String) -> int:
	var level := affection_level(id)
	if level >= 10:
		return 0
	return AFFECTION_STEPS[level] - affection_fed(id)


## Snacks get pricier as the cat levels up: 100G at Lv.1 up to 500G at Lv.9.
func snack_price(id: String) -> int:
	return SNACK_PRICE_BASE + SNACK_PRICE_STEP * affection_level(id)


## Multiplier bonus on speed/jump/dash from affection (+1% per level above 1).
func affection_bonus(id: String) -> float:
	return AFFECTION_STAT_STEP * (affection_level(id) - 1)


## Looks stage 1..3: base / sparkling eyes (Lv.5+) / aura + heart (Lv.10).
func aff_stage(id: String) -> int:
	var level := affection_level(id)
	if level >= 10:
		return 3
	return 2 if level >= 5 else 1


func feed_cat(id: String) -> bool:
	if affection_fed(id) >= SNACK_MAX or not spend_gold(snack_price(id)):
		return false
	affection[id] = affection_fed(id) + 1
	save_game()
	return true


# --- Custom cat (나만의 냥) ------------------------------------------------------


func custom_idx(key: String) -> int:
	return CustomCat.pick(custom_cat, key)


func set_custom_part(key: String, idx: int) -> void:
	custom_cat[key] = idx
	save_game()


## Replaces the whole selection at once (랜덤/초기화 buttons).
func set_custom_all(sel: Dictionary) -> void:
	custom_cat = sel
	save_game()


func get_cat(id: String) -> Dictionary:
	for cat in CATS:
		if cat.id == id:
			return cat
	return CATS[0]


## Stat multiplier dictionary for a cat (speed / jump / dash / weight),
## including the affection growth bonus on speed/jump/dash.
func cat_stats(id: String) -> Dictionary:
	var stats: Dictionary = get_cat(id).get("stats",
			{"speed": 1.0, "jump": 1.0, "dash": 1.0, "weight": 1.0, "push": 2}).duplicate()
	var bonus := 1.0 + affection_bonus(id)
	for k in ["speed", "jump", "dash"]:
		stats[k] = float(stats.get(k, 1.0)) * bonus
	return stats


## Skin dictionary consumed by Player.paint_cat. The selected cat also
## carries its equipped accessory defs under "acc".
func cat_skin(id: String) -> Dictionary:
	var cat := get_cat(id)
	var skin: Dictionary
	if id == "custom":
		skin = CustomCat.build_skin(custom_cat)
	else:
		skin = {"body": cat.body, "ear": cat.ear}
		if cat.has("ink"):
			skin["ink"] = cat.ink
	var accs := equipped_accs(id)
	if not accs.is_empty():
		skin["acc"] = accs
	var stage := aff_stage(id)
	if stage > 1:
		skin["aff"] = stage
	return skin


func is_unlocked(id: String) -> bool:
	var u: Dictionary = get_cat(id).unlock
	match u.type:
		"free":
			return true
		"gold", "gems":
			return id in purchased
		"height":
			return best_height >= int(u.floors)
		"score":
			return classic_best >= int(u.amount)
		"plays":
			return games_played >= int(u.count)
	return false


## Attempts to buy a purchasable cat. Returns true on success.
func try_buy(id: String) -> bool:
	if is_unlocked(id):
		return false
	var u: Dictionary = get_cat(id).unlock
	if u.type == "gold" and gold >= int(u.amount):
		gold -= int(u.amount)
	elif u.type == "gems" and gems >= int(u.amount):
		gems -= int(u.amount)
	else:
		return false
	purchased.append(id)
	save_game()
	return true


func select_cat(id: String) -> void:
	if is_unlocked(id):
		selected_cat = id
		save_game()


func save_game() -> void:
	var data := {
		"score": score,
		"best_height": best_height,
		"classic_best": classic_best,
		"picnic_best": picnic_best,
		"story_stage": story_stage,
		"games_played": games_played,
		"gold": gold,
		"gems": gems,
		"selected_cat": selected_cat,
		"nickname": nickname,
		"player_id": player_id,
		"weekly": weekly,
		"weekly_claimed": weekly_claimed,
		"purchased": purchased,
		"acc_owned": acc_owned,
		"acc_head": acc_head,
		"acc_neck": acc_neck,
		"affection": affection,
		"pending_boosts": pending_boosts,
		"skipped_stages": skipped_stages,
		"keycaps": keycaps,
		"custom_cat": custom_cat,
		"last_daily": last_daily,
		"locale": locale,
		"vol_master": vol_master,
		"vol_bgm": vol_bgm,
		"vol_sfx": vol_sfx,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		score = int(data.get("score", 0))
		best_height = int(data.get("best_height", 0))
		classic_best = int(data.get("classic_best", 0))
		picnic_best = int(data.get("picnic_best", 0))
		story_stage = int(data.get("story_stage", 0))
		games_played = int(data.get("games_played", 0))
		gold = int(data.get("gold", 0))
		gems = int(data.get("gems", 0))
		selected_cat = str(data.get("selected_cat", "cream"))
		nickname = str(data.get("nickname", ""))
		player_id = str(data.get("player_id", ""))
		var wkly: Variant = data.get("weekly", {})
		if wkly is Dictionary:
			weekly = {}
			for k in wkly:
				weekly[str(k)] = int(wkly[k])
		weekly_claimed = int(data.get("weekly_claimed", 0))
		var bought: Variant = data.get("purchased", [])
		if bought is Array:
			purchased = bought
		var owned: Variant = data.get("acc_owned", [])
		if owned is Array:
			acc_owned = owned
		acc_head = str(data.get("acc_head", ""))
		acc_neck = str(data.get("acc_neck", ""))
		if acc_head not in acc_owned:
			acc_head = ""
		if acc_neck not in acc_owned:
			acc_neck = ""
		var aff: Variant = data.get("affection", {})
		if aff is Dictionary:
			affection = {}
			for k in aff:
				affection[str(k)] = int(aff[k])
		var boosts: Variant = data.get("pending_boosts", [])
		if boosts is Array:
			pending_boosts = boosts
		var skipped: Variant = data.get("skipped_stages", [])
		if skipped is Array:
			skipped_stages = []
			for s in skipped:
				skipped_stages.append(int(s))
		var caps: Variant = data.get("keycaps", {})
		if caps is Dictionary:
			keycaps = {}
			for k in caps:
				keycaps[str(k)] = int(caps[k])
		var cst: Variant = data.get("custom_cat", {})
		if cst is Dictionary:
			custom_cat = {}
			for k in cst:
				custom_cat[str(k)] = int(cst[k])
		last_daily = str(data.get("last_daily", ""))
		locale = str(data.get("locale", ""))
		vol_master = clampf(float(data.get("vol_master", 1.0)), 0.0, 1.0)
		vol_bgm = clampf(float(data.get("vol_bgm", 0.8)), 0.0, 1.0)
		vol_sfx = clampf(float(data.get("vol_sfx", 1.0)), 0.0, 1.0)
		if not is_unlocked(selected_cat):
			selected_cat = "cream"
