extends Node
## Global game state: score, progress, currency, characters, save/load.

const SAVE_PATH := "user://save.json"

const MODE_ESCAPE := 0
const MODE_ENDLESS := 1
const MODE_VERSUS := 2

## Playable cube-cat skins. Unlock types:
##  free — always available / gold, gems — purchasable / height — endless best
##  escape — escape-mode best level / plays — total games played.
## Per-cat stat multipliers (1.0 = baseline cream):
##  speed — run speed / jump — jump velocity / dash — dash speed & cooldown
##  weight — heavier falls harder when fast-falling and resists knockback,
##  lighter floats but gets flung further.
const CATS: Array[Dictionary] = [
	{"id": "cream", "name": "크림", "body": Color("f4e3c8"), "ear": Color("d9a05c"),
		"unlock": {"type": "free"}, "trait": "밸런스",
		"stats": {"speed": 1.0, "jump": 1.0, "dash": 1.0, "weight": 1.0}},
	{"id": "cheese", "name": "치즈", "body": Color("f5b352"), "ear": Color("e08a3c"),
		"unlock": {"type": "gold", "amount": 300}, "trait": "헤비급",
		"stats": {"speed": 0.92, "jump": 0.96, "dash": 1.0, "weight": 1.3}},
	{"id": "calico", "name": "삼색", "body": Color("f2e6d4"), "ear": Color("8a5a33"),
		"unlock": {"type": "escape", "level": 3}, "trait": "대시왕",
		"stats": {"speed": 1.04, "jump": 0.97, "dash": 1.18, "weight": 0.95}},
	{"id": "black", "name": "까망", "body": Color("3a3540"), "ear": Color("26232c"),
		"ink": Color("f0d060"), "unlock": {"type": "height", "floors": 10},
		"trait": "질주본능",
		"stats": {"speed": 1.15, "jump": 1.0, "dash": 1.05, "weight": 0.9}},
	{"id": "gray", "name": "회색", "body": Color("aeb6c2"), "ear": Color("7e8694"),
		"unlock": {"type": "gold", "amount": 500}, "trait": "묵직점프",
		"stats": {"speed": 0.94, "jump": 1.06, "dash": 0.9, "weight": 1.2}},
	{"id": "mint", "name": "민트", "body": Color("bfe8d5"), "ear": Color("6fbf9a"),
		"unlock": {"type": "height", "floors": 30}, "trait": "점프킹",
		"stats": {"speed": 0.96, "jump": 1.12, "dash": 0.95, "weight": 0.9}},
	{"id": "pink", "name": "벚꽃", "body": Color("f6cdd8"), "ear": Color("e08ea6"),
		"unlock": {"type": "gold", "amount": 800}, "trait": "날쌘돌이",
		"stats": {"speed": 1.08, "jump": 1.06, "dash": 1.0, "weight": 0.8}},
	{"id": "ghost", "name": "유령", "body": Color(0.93, 0.96, 1.0, 0.6),
		"ear": Color(0.75, 0.8, 0.95, 0.55), "ink": Color("5a6a8a"),
		"unlock": {"type": "plays", "count": 20}, "trait": "깃털몸",
		"stats": {"speed": 1.0, "jump": 1.04, "dash": 1.1, "weight": 0.72}},
	{"id": "gold", "name": "황금", "body": Color("f7d354"), "ear": Color("c9982a"),
		"unlock": {"type": "gems", "amount": 20}, "trait": "올라운더",
		"stats": {"speed": 1.05, "jump": 1.04, "dash": 1.05, "weight": 1.05}},
]

var mode: int = MODE_ESCAPE
var split: bool = false  # 2-player split screen (escape/endless only), not saved
var best_height: int = 0
var best_escape_level: int = 1
var games_played: int = 0
var gold: int = 0
var gems: int = 0
var selected_cat: String = "cream"
var purchased: Array = []  # ids of cats bought with gold/gems

var score: int = 0:
	set(value):
		score = value
		EventBus.score_changed.emit(score)


func _ready() -> void:
	load_game()
	EventBus.game_started.connect(func() -> void: games_played += 1)
	EventBus.player_escaped.connect(_on_escaped)


func reset() -> void:
	score = 0


func _on_escaped(new_level: int) -> void:
	if new_level > best_escape_level:
		best_escape_level = new_level
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


func get_cat(id: String) -> Dictionary:
	for cat in CATS:
		if cat.id == id:
			return cat
	return CATS[0]


## Stat multiplier dictionary for a cat (speed / jump / dash / weight).
func cat_stats(id: String) -> Dictionary:
	return get_cat(id).get("stats",
			{"speed": 1.0, "jump": 1.0, "dash": 1.0, "weight": 1.0})


## Skin dictionary consumed by Player.paint_cat.
func cat_skin(id: String) -> Dictionary:
	var cat := get_cat(id)
	var skin := {"body": cat.body, "ear": cat.ear}
	if cat.has("ink"):
		skin["ink"] = cat.ink
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
		"escape":
			return best_escape_level >= int(u.level)
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
		"best_escape_level": best_escape_level,
		"games_played": games_played,
		"gold": gold,
		"gems": gems,
		"selected_cat": selected_cat,
		"purchased": purchased,
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
		best_escape_level = int(data.get("best_escape_level", 1))
		games_played = int(data.get("games_played", 0))
		gold = int(data.get("gold", 0))
		gems = int(data.get("gems", 0))
		selected_cat = str(data.get("selected_cat", "cream"))
		var bought: Variant = data.get("purchased", [])
		if bought is Array:
			purchased = bought
		if not is_unlocked(selected_cat):
			selected_cat = "cream"
