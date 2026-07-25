extends Node
## Global game state: score, progress, currency, characters, save/load.

const SAVE_PATH := "user://save.json"

const MODE_STORY := 0
const MODE_ENDLESS := 1
const MODE_VERSUS := 2

## Playable cube-cat skins. Unlock types:
##  free — always available / gold, gems — purchasable / height — endless best
##  story — story-mode stage cleared / plays — total games played.
## Per-cat stat multipliers (1.0 = baseline cream):
##  speed — run speed / jump — jump velocity / dash — dash speed & cooldown
##  weight — heavier falls harder when fast-falling and resists knockback,
##  lighter floats but gets flung further.
##  push — dash shove power in cells: 1 shoves the piece exactly one cell.
const CATS: Array[Dictionary] = [
	{"id": "cream", "name": "크림", "body": Color("f4e3c8"), "ear": Color("d9a05c"),
		"unlock": {"type": "free"}, "trait": "밸런스",
		"stats": {"speed": 1.0, "jump": 1.0, "dash": 1.0, "weight": 1.0, "push": 2}},
	{"id": "cheese", "name": "치즈", "body": Color("f5b352"), "ear": Color("e08a3c"),
		"unlock": {"type": "gold", "amount": 300}, "trait": "헤비급",
		"stats": {"speed": 0.92, "jump": 0.96, "dash": 1.0, "weight": 1.3, "push": 3}},
	{"id": "calico", "name": "삼색", "body": Color("f2e6d4"), "ear": Color("8a5a33"),
		"unlock": {"type": "story", "stage": 3}, "trait": "대시왕",
		"stats": {"speed": 1.04, "jump": 0.97, "dash": 1.18, "weight": 0.95, "push": 4}},
	{"id": "black", "name": "까망", "body": Color("3a3540"), "ear": Color("26232c"),
		"ink": Color("f0d060"), "unlock": {"type": "height", "floors": 10},
		"trait": "질주본능",
		"stats": {"speed": 1.15, "jump": 1.0, "dash": 1.05, "weight": 0.9, "push": 2}},
	{"id": "gray", "name": "회색", "body": Color("aeb6c2"), "ear": Color("7e8694"),
		"unlock": {"type": "gold", "amount": 500}, "trait": "묵직점프",
		"stats": {"speed": 0.94, "jump": 1.06, "dash": 0.9, "weight": 1.2, "push": 3}},
	{"id": "mint", "name": "민트", "body": Color("bfe8d5"), "ear": Color("6fbf9a"),
		"unlock": {"type": "height", "floors": 30}, "trait": "점프킹",
		"stats": {"speed": 0.96, "jump": 1.12, "dash": 0.95, "weight": 0.9, "push": 1}},
	{"id": "pink", "name": "벚꽃", "body": Color("f6cdd8"), "ear": Color("e08ea6"),
		"unlock": {"type": "gold", "amount": 800}, "trait": "날쌘돌이",
		"stats": {"speed": 1.08, "jump": 1.06, "dash": 1.0, "weight": 0.8, "push": 2}},
	{"id": "ghost", "name": "유령", "body": Color(0.93, 0.96, 1.0, 0.6),
		"ear": Color(0.75, 0.8, 0.95, 0.55), "ink": Color("5a6a8a"),
		"unlock": {"type": "plays", "count": 20}, "trait": "깃털몸",
		"stats": {"speed": 1.0, "jump": 1.04, "dash": 1.1, "weight": 0.72, "push": 1}},
	{"id": "gold", "name": "황금", "body": Color("f7d354"), "ear": Color("c9982a"),
		"unlock": {"type": "gems", "amount": 20}, "trait": "올라운더",
		"stats": {"speed": 1.05, "jump": 1.04, "dash": 1.05, "weight": 1.05, "push": 3}},
]

## Procedural accessories, drawn by Player.paint_cat on top of the skin.
## Two independent slots (head / neck), purely cosmetic — no stat effects.
## kind selects the draw routine in player.gd; col/col2 tint it.
const ACCESSORIES: Array[Dictionary] = [
	{"id": "beanie", "name": "털모자", "slot": "head", "kind": "beanie",
		"price": {"type": "gold", "amount": 200},
		"col": Color("5a8fd0"), "col2": Color("e8eef6")},
	{"id": "leaf", "name": "새싹", "slot": "head", "kind": "leaf",
		"price": {"type": "gold", "amount": 250},
		"col": Color("7ec850"), "col2": Color("5a9a38")},
	{"id": "ribbon", "name": "리본", "slot": "head", "kind": "ribbon",
		"price": {"type": "gold", "amount": 300},
		"col": Color("e0607a"), "col2": Color("b84760")},
	{"id": "flower", "name": "꽃송이", "slot": "head", "kind": "flower",
		"price": {"type": "gold", "amount": 400},
		"col": Color("f6cdd8"), "col2": Color("f2b93e")},
	{"id": "wizard", "name": "마법사 모자", "slot": "head", "kind": "wizard",
		"price": {"type": "gold", "amount": 1200},
		"col": Color("6a55b0"), "col2": Color("f2d365")},
	{"id": "tophat", "name": "신사 모자", "slot": "head", "kind": "tophat",
		"price": {"type": "gold", "amount": 1500},
		"col": Color("2c2833"), "col2": Color("b8433f")},
	{"id": "crown", "name": "황금 왕관", "slot": "head", "kind": "crown",
		"price": {"type": "gold", "amount": 3000},
		"col": Color("f2c94c"), "col2": Color("e05f5f")},
	{"id": "halo", "name": "천사의 링", "slot": "head", "kind": "halo",
		"price": {"type": "gems", "amount": 12},
		"col": Color("fff3d0"), "col2": Color("f7d354")},
	{"id": "bell", "name": "방울 목걸이", "slot": "neck", "kind": "bell",
		"price": {"type": "gold", "amount": 200},
		"col": Color("b8433f"), "col2": Color("f2c94c")},
	{"id": "scarf", "name": "목도리", "slot": "neck", "kind": "scarf",
		"price": {"type": "gold", "amount": 300},
		"col": Color("c94f43"), "col2": Color("a83d33")},
	{"id": "bowtie", "name": "나비넥타이", "slot": "neck", "kind": "bowtie",
		"price": {"type": "gold", "amount": 400},
		"col": Color("4a6fb8"), "col2": Color("35507f")},
	{"id": "bandana", "name": "반다나", "slot": "neck", "kind": "bandana",
		"price": {"type": "gold", "amount": 800},
		"col": Color("d08a3c"), "col2": Color("f4e3c8")},
	{"id": "goldchain", "name": "금 목걸이", "slot": "neck", "kind": "goldchain",
		"price": {"type": "gold", "amount": 3000},
		"col": Color("f2c94c"), "col2": Color("c9982a")},
	{"id": "gemchain", "name": "보석 목걸이", "slot": "neck", "kind": "gemchain",
		"price": {"type": "gems", "amount": 10},
		"col": Color("d8dee8"), "col2": Color("6fd0e8")},
]

## One-run boosts for endless mode, bought before a run and consumed on start.
const BOOSTS: Array[Dictionary] = [
	{"id": "warmup", "name": "워밍업", "desc": "5층 계단에서 출발", "price": 50},
	{"id": "fever", "name": "피버 스타트", "desc": "피버 게이지 50%로 시작", "price": 40},
	{"id": "lucky", "name": "럭키 젤리", "desc": "이번 판 골드 +50%", "price": 60},
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

var mode: int = MODE_STORY
var split: bool = false  # 2-player split screen (escape race/endless only), not saved
var best_height: int = 0
var story_stage: int = 0  # highest story stage cleared
var games_played: int = 0
var gold: int = 0
var gems: int = 0
var selected_cat: String = "cream"
var purchased: Array = []  # ids of cats bought with gold/gems
var acc_owned: Array = []  # ids of purchased accessories
var acc_head: String = ""  # equipped accessory per slot ("" = none)
var acc_neck: String = ""
var affection: Dictionary = {}  # cat id -> total snacks fed
var pending_boosts: Array = []  # boost ids paid for, consumed by the next endless run
var skipped_stages: Array = []  # story stages passed with a skip ticket
var last_daily: String = ""  # date the daily first-run double-gold was claimed
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
	EventBus.game_started.connect(func() -> void: games_played += 1)


func reset() -> void:
	score = 0


## Records a cleared story stage (progress only ever moves forward).
## A first-time clear pays a reward: 20~50 gold scaling with the stage, plus
## 2 gems at every 10-stage boss. Announced via EventBus.story_reward.
func story_clear(stage_num: int) -> void:
	if stage_num <= story_stage:
		return
	story_stage = stage_num
	var reward_gold := 20 + stage_num / 4
	var reward_gems := 2 if stage_num % 10 == 0 else 0
	add_currency(reward_gold, reward_gems)  # save_game included
	EventBus.story_reward.emit(reward_gold, reward_gems)


## Skip ticket: marks the stage as passed without paying the first-clear
## reward. The stage is remembered as skipped (shown differently in UI).
func story_skip(stage_num: int) -> void:
	if stage_num not in skipped_stages:
		skipped_stages.append(stage_num)
	story_stage = maxi(story_stage, stage_num)
	save_game()


## Records a finished endless run. Returns true if it set a new all-time best.
func record_height(h: int) -> bool:
	if h <= best_height:
		return false
	best_height = h
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
	var skin := {"body": cat.body, "ear": cat.ear}
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
		"story":
			return story_stage >= int(u.stage)
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
		"story_stage": story_stage,
		"games_played": games_played,
		"gold": gold,
		"gems": gems,
		"selected_cat": selected_cat,
		"purchased": purchased,
		"acc_owned": acc_owned,
		"acc_head": acc_head,
		"acc_neck": acc_neck,
		"affection": affection,
		"pending_boosts": pending_boosts,
		"skipped_stages": skipped_stages,
		"last_daily": last_daily,
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
		story_stage = int(data.get("story_stage", 0))
		games_played = int(data.get("games_played", 0))
		gold = int(data.get("gold", 0))
		gems = int(data.get("gems", 0))
		selected_cat = str(data.get("selected_cat", "cream"))
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
		last_daily = str(data.get("last_daily", ""))
		vol_master = clampf(float(data.get("vol_master", 1.0)), 0.0, 1.0)
		vol_bgm = clampf(float(data.get("vol_bgm", 0.8)), 0.0, 1.0)
		vol_sfx = clampf(float(data.get("vol_sfx", 1.0)), 0.0, 1.0)
		if not is_unlocked(selected_cat):
			selected_cat = "cream"
