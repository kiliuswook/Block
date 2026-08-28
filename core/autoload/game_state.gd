extends Node
## Global game state: score, progress, currency, characters, save/load.

const SAVE_PATH := "user://save.json"
const KeyBinds := preload("res://core/scripts/key_binds.gd")

const MODE_STORY := 0
const MODE_ENDLESS := 1
const MODE_VERSUS := 2
const MODE_CLASSIC := 3  # arcade tetris: clear lines, survive, stage up
const MODE_PICNIC := 4  # casual jelly picnic: no death, collect snacks on a timer

## Playable cube-cat skins. Unlock types:
##  free — 시작부터 지급되는 첫 캐릭터 (첫 키캡 한 바퀴를 공짜로 갖고 시작)
##  keycap — 그 캐릭터의 키캡 A~Z를 한 바퀴 모으면 해금.
## 해금 뒤에도 한 바퀴를 더 모을 때마다 등급이 오른다 (등급 1~4, 파츠 해금).
## Per-cat stat multipliers (1.0 = baseline cream):
##  speed — run speed / jump — jump velocity / dash — dash speed & cooldown
##  weight — heavier falls harder when fast-falling and resists knockback,
##  lighter floats but gets flung further.
##  push — dash shove power in cells: 1 shoves the piece exactly one cell.
const CATS: Array[Dictionary] = [
	{"id": "cream", "char": "char01", "name": "CAT_CREAM", "body": Color("f4e3c8"), "ear": Color("d9a05c"),
		"unlock": {"type": "free"}, "trait": "TRAIT_BALANCED",
		"stats": {"speed": 1.0, "jump": 1.0, "dash": 1.0, "weight": 1.0, "push": 2}},
	{"id": "black", "char": "char02", "name": "CAT_BLACK", "body": Color("3a3540"), "ear": Color("26232c"),
		"ink": Color("f0d060"), "unlock": {"type": "keycap"}, "trait": "TRAIT_SPRINTER",
		"stats": {"speed": 1.15, "jump": 1.0, "dash": 1.05, "weight": 0.9, "push": 2}},
	{"id": "cheese", "char": "char03", "name": "CAT_CHEESE", "body": Color("f5b352"), "ear": Color("e08a3c"),
		"unlock": {"type": "keycap"}, "trait": "TRAIT_HEAVY",
		"stats": {"speed": 0.92, "jump": 0.96, "dash": 1.0, "weight": 1.3, "push": 3}},
	{"id": "sleepy", "char": "char04", "name": "CAT_SLEEPY", "body": Color("fbf6ee"),
		"ear": Color("f0e2d8"), "unlock": {"type": "keycap"},
		"trait": "TRAIT_DREAMER",
		"stats": {"speed": 0.95, "jump": 1.08, "dash": 0.95, "weight": 0.95, "push": 2}},
	{"id": "wizard", "char": "char05", "name": "CAT_WIZARD", "body": Color("f0e2d0"),
		"ear": Color("5a4038"), "unlock": {"type": "keycap"},
		"trait": "TRAIT_MAGIC",
		"stats": {"speed": 1.02, "jump": 1.02, "dash": 1.12, "weight": 0.9, "push": 3}},
	{"id": "gray", "char": "char06", "name": "CAT_GRAY", "body": Color("aeb6c2"), "ear": Color("7e8694"),
		"unlock": {"type": "keycap"}, "trait": "TRAIT_HEAVYJUMP",
		"stats": {"speed": 0.94, "jump": 1.06, "dash": 0.9, "weight": 1.2, "push": 3}},
	# 나만의 캐릭터 — 디자인 냥이가 아니라 백지 몸통(CustomCat.BLANK_CHAR)이다.
	# 처음부터 열려 있고 키캡을 모으지 않는다(가챠 풀·도감에서 제외).
	# 꾸미기에 쓸 수 있는 파츠는 "해금한 디자인 냥이가 가진 파츠"뿐이다.
	{"id": "mycat", "char": "custom", "name": "CAT_MINE", "body": Color("fbf6ee"),
		"ear": Color("e8d9c8"), "custom": true, "unlock": {"type": "free"},
		"trait": "TRAIT_MINE",
		"stats": {"speed": 1.0, "jump": 1.0, "dash": 1.0, "weight": 1.0, "push": 2}},
]

const CustomCat := preload("res://core/scripts/custom_cat.gd")
const CatSprite := preload("res://core/scripts/cat_sprite.gd")

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
		"price": {"type": "gold", "amount": 5000},
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
		"price": {"type": "gold", "amount": 4000},
		"col": Color("d8dee8"), "col2": Color("6fd0e8")},
]

## One-run boosts for endless mode, bought before a run and consumed on start.
const BOOSTS: Array[Dictionary] = [
	{"id": "warmup", "name": "BOOST_WARMUP", "desc": "BOOST_WARMUP_DESC", "price": 50},
]

## 캐릭터 등급 1~4 (0 = 잠김). 등급 하나 = 그 캐릭터의 키캡 A~Z 한 바퀴.
const KEYCAP_GRADE_MAX := 4
## 키캡 가챠 — 상점에서 골드로 뽑는다. 10연차는 한 장 값을 깎아 준다.
## 전원 만렙(6종 × 4등급)까지 대략 625장 = 약 1.6만 골드 (한 판 수입 150~400G 기준).
const KEYCAP_GACHA_PRICE := 30
const KEYCAP_GACHA_BULK := 10
const KEYCAP_GACHA_BULK_PRICE := 250
## 이번 바퀴에서 아직 못 채운 글자가 나올 확률 (나머지는 완전 랜덤 = 중복).
const KEYCAP_FRESH_CHANCE := 0.7
## 선택 뽑기: 이만큼의 냥이를 골라 두면 그 냥이들만 캡슐에서 나온다.
## 원하는 냥이를 겨냥할 수 있는 값이라 한 장 값이 그만큼 비싸다.
const KEYCAP_PICK_SIZE := 5
const KEYCAP_PICK_MARKUP := 1.5

var mode: int = MODE_CLASSIC
var split: bool = false  # 2-player split screen (escape race/endless only), not saved
var best_height: int = 0
var classic_best: int = 0  # classic mode all-time high score
var picnic_best: int = 0  # jelly picnic all-time high score
var story_stage: int = 0  # highest story stage cleared
var games_played: int = 0
var gold: int = 0
var selected_cat: String = "cream"
## 2P(화면 분할) 몫으로 고른 냥이 — 1P와 같은 냥이여도 커스터마이징은 따로 간다.
var selected_cat2: String = "cream"
var nickname: String = ""  # leaderboard name — defaults to 냥이-XXXX on first run
var player_id: String = ""  # stable random id identifying this save on boards
var weekly: Dictionary = {}  # this week's bests: {"week": id, "story": n, ...}
var weekly_claimed: int = 0  # last finished week whose prize was checked
var acc_owned: Array = []  # ids of purchased accessories
var acc_head: String = ""  # equipped accessory per slot ("" = none)
var acc_neck: String = ""
var pending_boosts: Array = []  # boost ids paid for, consumed by the next endless run
var skipped_stages: Array = []  # story stages passed with a skip ticket
var keycaps: Dictionary = {}  # 캐릭터별 키캡: {cat id: {"A".."Z" -> 개수}}
## 선택 뽑기에 걸어 둔 냥이 id들 (최대 KEYCAP_PICK_SIZE) — 뽑기 화면에서 유지된다.
var gacha_pick: Array = []
# 캐릭터별 커스터마이징: 저장 키(custom_key) -> {부위 key: 옵션 index}
var cat_custom: Dictionary = {}
var last_daily: String = ""  # date the daily first-run double-gold was claimed
var locale: String = ""  # chosen UI language ("" = follow the system locale)
# Volume settings (linear 0..1) — applied to the audio buses by the Sfx autoload.
var vol_master: float = 1.0
var vol_bgm: float = 0.8
var vol_sfx: float = 1.0
## 컨트롤러 진동 세기 0~3 (0 = 끄기).
var vibration: int = 2
## 창 해상도 "1920x1080" ("" = project.godot 기본값 그대로).
var resolution: String = ""
## 타이틀에서 미리 정해 두는 참가 인원 (1 또는 2) — 모드를 고를 때마다 묻지 않는다.
var players: int = 1
## 사용자가 바꾼 키 바인딩 {"<액션>#<슬롯>": physical_keycode}. 빈 값 = 기본.
var keybinds: Dictionary = {}
## 사용자가 바꾼 패드 바인딩 {"<액션>": {"t": "b"/"a", "i": 인덱스}}.
var padbinds: Dictionary = {}

var score: int = 0:
	set(value):
		score = value
		EventBus.score_changed.emit(score)


func _ready() -> void:
	load_game()
	KeyBinds.apply_all(keybinds, padbinds)
	apply_resolution()
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


## 창 해상도 적용 (데스크톱 전용 — 웹·모바일은 창 크기를 우리가 못 정한다).
func apply_resolution() -> void:
	if resolution == "" or OS.has_feature("web") or OS.has_feature("mobile"):
		return
	var parts := resolution.split("x")
	if parts.size() != 2:
		return
	var want := Vector2i(int(parts[0]), int(parts[1]))
	if want.x < 640 or want.y < 480:
		return
	DisplayServer.window_set_size(want)
	var scr := DisplayServer.window_get_current_screen()
	DisplayServer.window_set_position(DisplayServer.screen_get_position(scr)
			+ (DisplayServer.screen_get_size(scr) - want) / 2)


## 게임패드 진동 — 설정의 세기(0~3)를 곱해서 울린다. 0이면 아무것도 안 한다.
func rumble(weak: float, strong: float, duration: float) -> void:
	if vibration <= 0:
		return
	var k := vibration / 3.0
	for dev in Input.get_connected_joypads():
		Input.start_joy_vibration(dev, weak * k, strong * k, duration)


func reset() -> void:
	score = 0


## Full progress wipe (설정 > 게임 초기화): records, story progress, wallet,
## unlocked cats, accessories, keycaps, custom cat, weekly bests.
## Keeps the volume settings, language, nickname and player_id (same identity).
func reset_all() -> void:
	score = 0
	best_height = 0
	classic_best = 0
	picnic_best = 0
	story_stage = 0
	games_played = 0
	gold = 0
	selected_cat = "cream"
	selected_cat2 = "cream"
	weekly = {}
	weekly_claimed = 0
	acc_owned = []
	acc_head = ""
	acc_neck = ""
	pending_boosts = []
	skipped_stages = []
	keycaps = {}
	cat_custom = {}
	last_daily = ""
	save_game()


## Records a cleared story stage (progress only ever moves forward).
## A first-time clear pays a reward: 20~50 gold scaling with the stage.
## Announced via EventBus.story_reward.
func story_clear(stage_num: int) -> void:
	# Weekly board counts every clear — replayed stages included.
	var weekly_up := record_weekly("story", stage_num)
	if stage_num <= story_stage:
		if weekly_up:
			Ranks.submit("story", story_stage)
		return
	story_stage = stage_num
	var reward_gold := 20 + stage_num / 4
	add_currency(reward_gold)  # save_game included
	EventBus.story_reward.emit(reward_gold)
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


func add_currency(add_gold: int) -> void:
	gold += add_gold
	save_game()


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
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


# --- Keycaps (캐릭터별 알파벳 수집) ---------------------------------------------
## 키캡은 **캐릭터마다 따로** 모은다: keycaps = {cat id: {"A": n, ...}}.
## 한 캐릭터의 A~Z를 한 바퀴 채울 때마다 그 캐릭터의 등급이 1 오른다 —
## 첫 바퀴가 해금(등급 1), 이후 세 바퀴가 파츠 단계 1~3(등급 4 = 만렙).
## 첫 캐릭터(unlock.type == "free")만 첫 바퀴를 처음부터 갖고 시작한다.


## 이 캐릭터가 모은 키캡 사전 ("A" -> 개수). 저장 사전을 그대로 돌려준다.
func cat_keycaps(cat_id: String) -> Dictionary:
	var d: Variant = keycaps.get(cat_id, {})
	return d if d is Dictionary else {}


func keycap_count(cat_id: String, letter: String) -> int:
	return int(cat_keycaps(cat_id).get(letter, 0))


## 이 캐릭터가 모은 글자 종류 수 (0..26).
func keycap_kinds(cat_id: String) -> int:
	return cat_keycaps(cat_id).size()


## 중복 포함 총 장수. cat_id를 비우면 전 캐릭터 합계.
func keycap_total(cat_id := "") -> int:
	var total := 0
	for id: String in keycaps:
		if cat_id != "" and id != cat_id:
			continue
		var d: Dictionary = cat_keycaps(id)
		for letter: String in d:
			total += int(d[letter])
	return total


## 키캡 한 장을 그 캐릭터 앞으로 적립한다 (중복은 쌓인다).
## 여러 장을 한꺼번에 뽑을 때는 save=false로 넘기고 마지막에 한 번만 저장한다.
func add_keycap(cat_id: String, letter: String, save := true) -> void:
	var d := cat_keycaps(cat_id)
	d[letter] = int(d.get(letter, 0)) + 1
	keycaps[cat_id] = d
	if save:
		save_game()
	EventBus.keycap_collected.emit(cat_id, letter, int(d[letter]))


## 이 캐릭터의 A~Z를 몇 바퀴 채웠는가 (= 26글자 중 가장 적게 가진 글자의 수).
func keycap_sets(cat_id: String) -> int:
	var d := cat_keycaps(cat_id)
	if d.size() < 26:
		return 0
	var least := 99
	for i in 26:
		least = mini(least, int(d.get(char(65 + i), 0)))
	return least


## 시작부터 주는 바퀴 수 — 첫 캐릭터만 1 (즉 처음부터 해금 상태).
func free_sets(id: String) -> int:
	return 1 if str(get_cat(id).unlock.type) == "free" else 0


## 캐릭터 등급 0~4. 0 = 잠김, 1 = 해금(기본 파츠), 4 = 파츠 만렙.
func cat_grade(id: String) -> int:
	return mini(keycap_sets(id) + free_sets(id), KEYCAP_GRADE_MAX)


## 이번(=다음 등급) 바퀴에서 아직 못 채운 글자 수. 만렙이면 0.
func keycaps_to_next(id: String) -> int:
	if cat_grade(id) >= KEYCAP_GRADE_MAX:
		return 0
	var d := cat_keycaps(id)
	var need := keycap_sets(id) + 1
	var left := 0
	for i in 26:
		if int(d.get(char(65 + i), 0)) < need:
			left += 1
	return left


## 이번 바퀴에서 채운 글자 수 (0~26) — 도감·진행 바 표시용.
func keycap_ring(id: String) -> int:
	return 26 - keycaps_to_next(id)


## 이번 바퀴 기준으로 이 글자를 이미 갖고 있는가 (도감에서 불 켜진 자리).
func has_keycap(cat_id: String, letter: String) -> bool:
	if cat_grade(cat_id) >= KEYCAP_GRADE_MAX:
		return keycap_count(cat_id, letter) > 0
	return keycap_count(cat_id, letter) > keycap_sets(cat_id)


# --- 키캡 가챠 (상점) ------------------------------------------------------------
## 인게임 드랍은 없다 — 키캡은 상점에서 골드로 뽑는다.


## 키캡을 n장 뽑는다. 뽑기는 두 종류다:
##  · 랜덤 뽑기 (pick 비움) — 아직 만렙이 아닌 냥이 전체에서 균등 랜덤
##    (잠긴 냥이 포함 — 아무나 먼저 완성한 순서대로 합류한다).
##  · 선택 뽑기 (pick = 냥이 id 배열) — 그 냥이들만 나온다. 대신 값이 비싸다.
## 반환: [{"cat": id, "letter": "A", "fresh": bool, "grade_up": bool}, ...]
## 골드가 모자라거나 풀이 비면 빈 배열.
func draw_keycaps(n: int, pick: Array = []) -> Array:
	n = maxi(1, n)
	var pool := gacha_pool(pick)
	if pool.is_empty():
		return []
	if not spend_gold(keycap_price(n, not pick.is_empty())):
		return []
	var out: Array = []
	for i in n:
		var cat_id := pool[randi() % pool.size()]
		var before := cat_grade(cat_id)
		var letter := _roll_letter(cat_id)
		var fresh := not has_keycap(cat_id, letter)
		add_keycap(cat_id, letter, false)
		out.append({"cat": cat_id, "letter": letter, "fresh": fresh,
				"grade_up": cat_grade(cat_id) > before})
	save_game()
	return out


## 이번 뽑기에서 캡슐에 들어가는 냥이들. 선택 뽑기는 고른 냥이 그대로,
## 랜덤 뽑기는 아직 만렙이 아닌 냥이들 (전원 만렙이면 전체 = 중복 수집).
func gacha_pool(pick: Array = []) -> Array[String]:
	var pool: Array[String] = []
	if not pick.is_empty():
		for cid in pick:
			var id := str(cid)
			if not get_cat(id).is_empty() and not is_custom_cat(id) and id not in pool:
				pool.append(id)
		return pool
	for cat in keycap_cats():
		if cat_grade(str(cat.id)) < KEYCAP_GRADE_MAX:
			pool.append(str(cat.id))
	if pool.is_empty():
		for cat in keycap_cats():
			pool.append(str(cat.id))
	return pool


## n장 값. 선택 뽑기는 겨냥하는 대가로 KEYCAP_PICK_MARKUP배.
func keycap_price(n: int, pick := false) -> int:
	var base := KEYCAP_GACHA_PRICE * n
	if n >= KEYCAP_GACHA_BULK:
		base = KEYCAP_GACHA_BULK_PRICE
	return int(ceil(base * KEYCAP_PICK_MARKUP)) if pick else base


## 이번 바퀴에서 비어 있는 글자를 우선으로 하나 고른다. 확정이 아니라
## 확률이라 중복도 나온다 (100%면 뽑는 맛 없이 정해진 횟수 노가다가 된다).
func _roll_letter(cat_id: String) -> String:
	if randf() > KEYCAP_FRESH_CHANCE:
		return char(65 + randi() % 26)
	var missing: Array[String] = []
	for i in 26:
		var letter := char(65 + i)
		if not has_keycap(cat_id, letter):
			missing.append(letter)
	if missing.is_empty():
		return char(65 + randi() % 26)
	return missing[randi() % missing.size()]


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
	if not spend_gold(int(price.amount)):
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
		add_currency(price)  # save included
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


# --- 캐릭터 커스터마이징 ----------------------------------------------------------
## 캐릭터마다 따로 저장된다. sel에는 사용자가 손댄 부위만 들어가고,
## 나머지는 그 캐릭터의 디자인 파츠가 그대로 남는다 (빈 sel = 완전 기본 상태).


## 커스터마이징 저장 키. 2P는 같은 냥이를 골라도 자기 몫으로 따로 꾸민다.
func custom_key(id: String, player: int) -> String:
	return id if player <= 1 else "%s|%d" % [id, player]


func custom_sel(id: String, player := 1) -> Dictionary:
	var sel: Variant = cat_custom.get(custom_key(id, player), {})
	return sel if sel is Dictionary else {}


func custom_idx(id: String, key: String, player := 1) -> int:
	return CustomCat.pick(custom_sel(id, player), key)


func set_custom_part(id: String, key: String, idx: int, player := 1) -> void:
	var sel := custom_sel(id, player).duplicate()
	sel[key] = idx
	cat_custom[custom_key(id, player)] = sel
	save_game()


## Replaces the whole selection at once (프리셋/랜덤/초기화 buttons).
func set_custom_all(id: String, sel: Dictionary, player := 1) -> void:
	if sel.is_empty():
		cat_custom.erase(custom_key(id, player))
	else:
		cat_custom[custom_key(id, player)] = sel
	save_game()


## 디자인 캐릭터의 해금된 파츠 단계 (0=디폴트 ~ 3=꼬리까지) = 등급 - 1.
func cat_tier(id: String) -> int:
	return clampi(cat_grade(id) - 1, 0, CustomCat.TIER_MAX)


func get_cat(id: String) -> Dictionary:
	for cat in CATS:
		if cat.id == id:
			return cat
	return CATS[0]


## 나만의 캐릭터(백지 슬롯)인가 — 키캡·해금 진행이 없는 자리.
func is_custom_cat(id: String) -> bool:
	return bool(get_cat(id).get("custom", false))


## 키캡을 모으는 냥이들 (가챠 풀·도감 탭 — 나만의 캐릭터는 빠진다).
func keycap_cats() -> Array:
	var out: Array = []
	for cat in CATS:
		if not cat.get("custom", false):
			out.append(cat)
	return out


## 디자인 캐릭터(char01…) → 그 캐릭터를 쓰는 냥이 id ("" = 없음).
func cat_id_for_char(char_id: String) -> String:
	for cat in CATS:
		if cat.get("char", "") == char_id and not cat.get("custom", false):
			return str(cat.id)
	return ""


# --- 나만의 캐릭터의 파츠 해금 ------------------------------------------------------
## 파츠는 전부 디자인 냥이에게서 빌려 온다 — 그 냥이를 해금해야(그리고 그 파츠가
## 붙는 단계까지 키캡을 모아야) 나만의 캐릭터에 쓸 수 있다.


## 이 출처(냥이 + 파츠 단계)가 열려 있는가. 단계 t는 등급 1+t에서 붙는다.
func _source_open(src: Dictionary) -> bool:
	var cid := cat_id_for_char(str(src.get("char", "")))
	return cid != "" and cat_grade(cid) >= 1 + int(src.get("tier", 0))


## 나만의 캐릭터가 이 부위 옵션을 쓸 수 있는가 (출처가 없는 "없음"은 항상 가능).
func part_unlocked(key: String, idx: int) -> bool:
	var srcs: Variant = CustomCat.option_sources(key, idx)
	if not srcs is Array:
		return false
	for src: Dictionary in srcs:
		if _source_open(src):
			return true
	return (srcs as Array).is_empty()


## 나만의 캐릭터가 지금 쓸 수 있는 파츠 수 / 전체 (타일·팝업 표시용).
func my_parts_progress() -> Vector2i:
	var open := 0
	var total := 0
	for part in CustomCat.PARTS:
		var key := str(part.key)
		for i: int in CustomCat.my_options(key):
			total += 1
			if part_unlocked(key, i):
				open += 1
	return Vector2i(open, total)


## 잠긴 옵션을 여는 가장 가까운 조건 — {"cat": id, "grade": n}. 없으면 빈 사전.
func part_unlock_hint(key: String, idx: int) -> Dictionary:
	var srcs: Variant = CustomCat.option_sources(key, idx)
	if not srcs is Array:
		return {}
	var best := {}
	for src: Dictionary in srcs:
		var cid := cat_id_for_char(str(src.get("char", "")))
		if cid == "":
			continue
		var need := 1 + int(src.get("tier", 0))
		# 이미 해금된 냥이의 다음 단계가 가장 가깝다 — 등급 차이로 고른다.
		var gap := need - cat_grade(cid)
		if best.is_empty() or gap < int(best.get("gap", 99)):
			best = {"cat": cid, "grade": need, "gap": gap}
	return best


## Stat multiplier dictionary for a cat (speed / jump / dash / weight).
func cat_stats(id: String) -> Dictionary:
	return get_cat(id).get("stats",
			{"speed": 1.0, "jump": 1.0, "dash": 1.0, "weight": 1.0, "push": 2}).duplicate()


## Skin dictionary consumed by Player.paint_cat. The selected cat also
## carries its equipped accessory defs under "acc".
func cat_skin(id: String, player := 1) -> Dictionary:
	var cat := get_cat(id)
	var char_id := str(cat.get("char", "char01"))
	var tier := cat_tier(id)
	var sel := custom_sel(id, player)
	var skin := CustomCat.build_skin(char_id, tier, sel)
	# 컨셉 시트 그림으로 그릴 수 있으면 그쪽을 쓴다. 색만 바꾼 경우엔
	# 파츠 레이어에 틴트로 얹고, 모양까지 바꿨으면 코드 렌더로 남긴다.
	if CatSprite.has(char_id) and (sel.is_empty()
			or (CatSprite.is_layered(char_id) and CustomCat.sprite_safe(sel))):
		skin["sprite"] = char_id
		skin["tier"] = tier
		skin["tints"] = CustomCat.sprite_tints(sel)
	# 액세서리는 지갑이 하나라 1P(=저장된 선택 냥이) 몫으로만 붙는다.
	var accs: Array = equipped_accs(id) if player <= 1 else []
	if not accs.is_empty():
		skin["acc"] = accs
	return skin


## 잠긴 냥이용 실루엣 — 실루엣(모양)은 유지하고 색·소품만 지운다.
func cat_shadow_skin(id: String) -> Dictionary:
	var full := cat_skin(id)
	if full.has("sprite"):
		return {"body": Color("cdd4dd"), "ear": Color("b3bcc9"), "gray": true,
				"sprite": full["sprite"], "tier": full["tier"],
				"parts": full.get("parts", {})}
	var parts: Dictionary = (full.get("parts", {}) as Dictionary).duplicate()
	parts["body_col"] = Color("cdd4dd")
	parts["ear_col"] = Color("b3bcc9")
	parts["tail_col"] = Color("b3bcc9")
	parts["foot_col"] = Color("dfe4ea")
	parts["pad_col"] = Color("b3bcc9")
	parts["eye_col"] = Color("8f98a6")
	parts["nose_col"] = Color("8f98a6")
	parts["pattern"] = "none"
	parts["cheek"] = "none"
	for k in ["head", "face", "neck", "hold", "chest", "back", "mark"]:
		parts[k] = "none"
	return {"body": parts["body_col"], "ear": parts["ear_col"], "parts": parts}


## 해금 = 그 캐릭터의 키캡 A~Z를 한 바퀴 채웠는가 (첫 캐릭터는 처음부터).
func is_unlocked(id: String) -> bool:
	return cat_grade(id) >= 1


func select_cat(id: String, player := 1) -> void:
	if not is_unlocked(id):
		return
	if player <= 1:
		selected_cat = id
	else:
		selected_cat2 = id
	save_game()


## 플레이어 자리(1/2)가 지금 쓰는 냥이 id.
func cat_for(player: int) -> String:
	return selected_cat if player <= 1 else selected_cat2


func save_game() -> void:
	var data := {
		"score": score,
		"best_height": best_height,
		"classic_best": classic_best,
		"picnic_best": picnic_best,
		"story_stage": story_stage,
		"games_played": games_played,
		"gold": gold,
		"selected_cat": selected_cat,
		"selected_cat2": selected_cat2,
		"nickname": nickname,
		"player_id": player_id,
		"weekly": weekly,
		"weekly_claimed": weekly_claimed,
		"acc_owned": acc_owned,
		"acc_head": acc_head,
		"acc_neck": acc_neck,
		"pending_boosts": pending_boosts,
		"skipped_stages": skipped_stages,
		"keycaps": keycaps,
		"gacha_pick": gacha_pick,
		"cat_custom": cat_custom,
		"last_daily": last_daily,
		"locale": locale,
		"vol_master": vol_master,
		"vol_bgm": vol_bgm,
		"vol_sfx": vol_sfx,
		"vibration": vibration,
		"resolution": resolution,
		"players": players,
		"keybinds": keybinds,
		"padbinds": padbinds,
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
		selected_cat = str(data.get("selected_cat", "cream"))
		selected_cat2 = str(data.get("selected_cat2", "cream"))
		nickname = str(data.get("nickname", ""))
		player_id = str(data.get("player_id", ""))
		var wkly: Variant = data.get("weekly", {})
		if wkly is Dictionary:
			weekly = {}
			for k in wkly:
				weekly[str(k)] = int(wkly[k])
		weekly_claimed = int(data.get("weekly_claimed", 0))
		var owned: Variant = data.get("acc_owned", [])
		if owned is Array:
			acc_owned = owned
		acc_head = str(data.get("acc_head", ""))
		acc_neck = str(data.get("acc_neck", ""))
		if acc_head not in acc_owned:
			acc_head = ""
		if acc_neck not in acc_owned:
			acc_neck = ""
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
				var per: Variant = caps[k]
				if per is Dictionary:
					var d := {}
					for letter in per:
						d[str(letter)] = int(per[letter])
					keycaps[str(k)] = d
				else:
					# 구버전 저장(캐릭터 구분 없는 평면 A~Z)은 첫 캐릭터 몫으로 옮긴다.
					var first := str(CATS[0].id)
					var d0: Dictionary = keycaps.get(first, {})
					d0[str(k)] = int(per)
					keycaps[first] = d0
		var picked: Variant = data.get("gacha_pick", [])
		if picked is Array:
			gacha_pick = []
			for cid in picked:
				# 저장 이후 사라진 냥이 id는 흘려보낸다.
				var id := str(cid)
				if id in gacha_pick or get_cat(id).is_empty() or is_custom_cat(id):
					continue
				gacha_pick.append(id)
			gacha_pick.resize(mini(gacha_pick.size(), KEYCAP_PICK_SIZE))
		var cst: Variant = data.get("cat_custom", {})
		if cst is Dictionary:
			cat_custom = {}
			for cid in cst:
				var picks: Variant = cst[cid]
				if not picks is Dictionary:
					continue
				var sel := {}
				for k in (picks as Dictionary):
					# 카탈로그가 시트 기준으로 재편되면 사라진 부위·범위 밖 선택이
					# 남는다 — 불러올 때 정리해 저장본이 높은 값을 질질 끌지 않게 한다.
					var part := CustomCat.get_part(str(k))
					if part.is_empty():
						continue
					var idx := int((picks as Dictionary)[k])
					if idx < 0 or idx >= CustomCat.option_count(part):
						continue
					sel[str(k)] = idx
				if not sel.is_empty():
					cat_custom[str(cid)] = sel
		last_daily = str(data.get("last_daily", ""))
		locale = str(data.get("locale", ""))
		vol_master = clampf(float(data.get("vol_master", 1.0)), 0.0, 1.0)
		vol_bgm = clampf(float(data.get("vol_bgm", 0.8)), 0.0, 1.0)
		vol_sfx = clampf(float(data.get("vol_sfx", 1.0)), 0.0, 1.0)
		vibration = clampi(int(data.get("vibration", 2)), 0, 3)
		resolution = str(data.get("resolution", ""))
		players = clampi(int(data.get("players", 1)), 1, 2)
		var kb: Variant = data.get("keybinds", {})
		if kb is Dictionary:
			keybinds = {}
			for k in kb:
				keybinds[str(k)] = int(kb[k])
		var pb: Variant = data.get("padbinds", {})
		if pb is Dictionary:
			padbinds = {}
			for k in pb:
				var b: Variant = pb[k]
				if b is Dictionary:
					padbinds[str(k)] = {"t": str(b.get("t", "b")), "i": int(b.get("i", 0)),
							"d": int(b.get("d", 1))}
		# 사라진 캐릭터(구버전 세이브)를 고르고 있었으면 기본냥으로 되돌린다.
		var known := false
		for cat in CATS:
			known = known or cat.id == selected_cat
		if not known or not is_unlocked(selected_cat):
			selected_cat = "cream"
		var known2 := false
		for cat in CATS:
			known2 = known2 or cat.id == selected_cat2
		if not known2 or not is_unlocked(selected_cat2):
			selected_cat2 = "cream"
