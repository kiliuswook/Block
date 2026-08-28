extends Node
## Online leaderboards, one board per mode (story / endless / classic).
## Entries: {"id": String, "name": String, "v": int, "cat": String}.
##
## 백엔드는 셋 중 하나로 정해진다 (`backend()`):
##   STEAM — 스팀 빌드 + 스팀 클라이언트가 살아 있을 때. Steamworks 리더보드를
##           쓴다. 보드 하나 = 모드 하나(주간은 주마다 새 이름), 제출·조회는
##           `Platform`을 통해 나간다. 서버가 필요 없다.
##   HTTP  — 그 외에 BOARD_URL이 채워져 있을 때. 공유 JSON blob 하나를 통째로
##           읽고 쓰는 프로토타입용 백엔드 (웹 빌드가 이걸 쓴다).
##   OFFLINE — 둘 다 아닐 때. 봇 크루 + 내 로컬 기록만 보여 준다.
## 어느 쪽이든 UI는 `entries()` / `my_rank()`만 보면 된다.

signal board_loaded(ok: bool)
signal weekly_reward(gold: int, gems: int)  # last week's top-3 payout landed

enum Backend { OFFLINE, HTTP, STEAM }

## The shared board: a jsonblob.com blob (anonymous, CORS-enabled, extended
## on every access). Point this at any GET/PUT JSON endpoint to migrate.
const BOARD_URL := "https://jsonblob.com/api/jsonBlob/019f9dbf-29d9-7346-bf9d-32c674bfed1c"
const MODES := ["story", "endless", "classic", "picnic"]
## 지금 실제로 플레이할 수 있는 모드. 스팀 리더보드는 여기 있는 것만 만든다 —
## 내려둔 모드(story/picnic)까지 만들면 앱에 죽은 보드가 쌓인다.
const LIVE_MODES := ["endless", "classic"]
const MAX_ENTRIES := 100  # kept per mode, sorted by value desc
## 스팀 보드에서 한 번에 받아 오는 상위 엔트리 수 (UI는 50줄까지 그린다).
const STEAM_FETCH := 50

# Weekly boards live beside the all-time ones under "wk_<mode>" keys, stamped
# with the week id. The first client of a new week rolls them into "lw_<mode>"
# (last week's final standings — kept so winners can claim their prize) and
# starts fresh. Weeks flip Monday 00:00 KST.
const WEEK_ANCHOR := 313200  # unix time of Monday 1970-01-05 00:00 KST
const WEEK_LEN := 604800
const WEEKLY_REWARDS := [[500, 5], [300, 3], [200, 2]]  # rank 1..3: [gold, gems]

## Offline placeholder crowd: until the backend goes live, boards are filled
## with these bot entries (deterministic per mode) plus the real local record.
const MOCK_NAMES := ["츄르대장", "골골송장인", "캣타워폭격기", "우다다다", "식빵굽는냥",
		"까칠한젤리", "높이높이", "츄르에진심", "안자는고양이", "꾹꾹이달인", "그르렁",
		"수염봉봉", "방울이", "호랑무늬", "낮잠금지", "점프좀치는냥", "테트리스냥",
		"용암싫어", "골드사냥꾼", "계단오르미", "블록부수기", "살금살금", "야옹백작",
		"츄르한입만"]
const MOCK_CATS := ["cream", "black", "cheese", "sleepy", "wizard", "gray"]

var board := {}  # last fetched board: mode key -> Array of entries
var busy := false
var _submitting := false  # serializes read-modify-write submits


func _ready() -> void:
	# Push any pre-existing local bests once at startup, so records earned
	# before the ranking update (or offline) still make it onto the board.
	submit_all.call_deferred()


## 지금 어느 백엔드로 도는가. 스팀 초기화가 실패하면(스팀 클라이언트가 꺼져
## 있거나 확장이 없거나) 자동으로 HTTP → 오프라인 순으로 내려간다.
func backend() -> int:
	if Platform.has_leaderboards():
		return Backend.STEAM
	return Backend.HTTP if BOARD_URL != "" else Backend.OFFLINE


func online() -> bool:
	return backend() != Backend.OFFLINE


## 보드에서 나를 가리키는 id. 스팀에서는 SteamID라 기기를 옮겨도 같은 사람이다.
func my_id() -> String:
	var uid := Platform.user_id() if backend() == Backend.STEAM else ""
	return uid if uid != "" else GameState.player_id


## 보드 이름. 주간 보드는 주마다 이름이 달라진다 — 스팀에는 자동 리셋이 없어서
## "새 주 = 새 보드"로 처리하고, 지난주 보드는 시상용으로 그대로 남는다.
func board_name(mode_key: String, weekly := false, week := -1) -> String:
	if not weekly:
		return mode_key
	return "%s_w%d" % [mode_key, week if week >= 0 else week_id()]


## 캐릭터 id ↔ 인덱스. 스팀 엔트리는 문자열을 못 실어서(int32 배열뿐)
## CATS 안의 자리 번호로 캐릭터를 실어 보낸다.
func cat_index(cat_id: String) -> int:
	for i in GameState.CATS.size():
		if GameState.CATS[i].id == cat_id:
			return i
	return -1


func cat_from_index(i: int) -> String:
	return str(GameState.CATS[i].id) if i >= 0 and i < GameState.CATS.size() else ""


func week_id() -> int:
	return (int(Time.get_unix_time_from_system()) - WEEK_ANCHOR) / WEEK_LEN


## "3일 4시간" until the weekly boards reset (Monday 00:00 KST).
func week_remaining_text() -> String:
	var rem := WEEK_LEN - ((int(Time.get_unix_time_from_system()) - WEEK_ANCHOR) % WEEK_LEN)
	var d := rem / 86400
	var h := (rem % 86400) / 3600
	var m := (rem % 3600) / 60
	if d > 0:
		return tr("RANK_DUR_DH").format({"d": d, "h": h})
	if h > 0:
		return tr("RANK_DUR_HM").format({"h": h, "m": m})
	return tr("RANK_DUR_M").format({"m": m})


## My current local best for a mode key.
func local_value(mode_key: String) -> int:
	match mode_key:
		"story":
			return GameState.story_stage
		"endless":
			return GameState.best_height
		"classic":
			return GameState.classic_best
		"picnic":
			return GameState.picnic_best
	return 0


func value_text(mode_key: String, v: int) -> String:
	match mode_key:
		"story":
			return "STAGE %d" % v
		"endless":
			return tr("HUD_FLOOR").format({"n": v})
	return tr("HUD_POINTS").format({"n": v})


func submit_all() -> void:
	for m: String in MODES:
		if local_value(m) > 0:
			submit(m, local_value(m))


## Fire-and-forget: 내 최고 기록(전체 + 이번 주)을 보드에 올린다.
## 백엔드에 따라 갈라진다 — 스팀은 보드별 업로드, HTTP는 blob 전체 RMW.
func submit(mode_key: String, value: int) -> void:
	if not online() or value <= 0:
		return
	if backend() == Backend.STEAM:
		await _submit_steam(mode_key, value)
		return
	while _submitting:
		await get_tree().process_frame
	_submitting = true
	var data: Variant = await _http(HTTPClient.METHOD_GET)
	if data is not Dictionary:
		_submitting = false
		return
	_rollover(data)
	_merge_mine(data, mode_key, maxi(value, local_value(mode_key)), true)
	var wv: int = GameState.weekly_value(mode_key)
	if wv > 0:
		_merge_mine(data, "wk_" + mode_key, wv, false)
	board = data
	await _http(HTTPClient.METHOD_PUT, JSON.stringify(data))
	_submitting = false
	_claim_rewards()


## 스팀 제출: 전체 보드 + 이번 주 보드에 각각 올린다. 리플레이는 전체 보드
## 엔트리에만 UGC로 붙인다(주간 보드는 매주 버려지므로 붙일 이유가 없다).
## keep_best라 이전 기록보다 낮으면 스팀이 알아서 무시한다.
func _submit_steam(mode_key: String, value: int) -> void:
	if not LIVE_MODES.has(mode_key):
		return  # 내려둔 모드까지 스팀에 보드를 만들지 않는다
	var details := PackedInt32Array([cat_index(GameState.selected_cat)])
	await Platform.submit_score(board_name(mode_key), maxi(value, local_value(mode_key)),
			details, Replays.pack(mode_key))
	var wv: int = GameState.weekly_value(mode_key)
	if wv > 0:
		await Platform.submit_score(board_name(mode_key, true), wv, details)


## Removes every entry of mine (all modes: all-time / weekly / last-week)
## from the shared board. Used by 설정 > 게임 초기화.
## 스팀 리더보드는 클라이언트가 자기 엔트리를 지울 수 없어서 그냥 넘어간다 —
## 로컬 기록만 지워지고 보드의 기록은 다음 플레이 때 덮어써진다.
func wipe_mine() -> void:
	if not online() or backend() == Backend.STEAM:
		return
	while _submitting:
		await get_tree().process_frame
	_submitting = true
	var data: Variant = await _http(HTTPClient.METHOD_GET)
	if data is Dictionary:
		for m: String in MODES:
			for key in [m, "wk_" + m, "lw_" + m]:
				if data.has(key) and data[key] is Array:
					data[key] = (data[key] as Array).filter(func(e: Variant) -> bool:
						return e is Dictionary and str(e.get("id")) != GameState.player_id)
		board = data
		await _http(HTTPClient.METHOD_PUT, JSON.stringify(data))
	_submitting = false


## Replaces my entry in one board list; replays ride only on the all-time
## boards (top 10 keep theirs — they are heavy).
func _merge_mine(data: Dictionary, key: String, value: int, with_replay: bool) -> void:
	var entries: Array = data.get(key, [])
	entries = entries.filter(func(e: Variant) -> bool:
		return e is Dictionary and str(e.get("id")) != GameState.player_id)
	var mine := {"id": GameState.player_id, "name": GameState.nickname,
			"v": value, "cat": GameState.selected_cat}
	if with_replay:
		var rep := Replays.encode(Replays.load_replay(key))
		if rep != "":
			mine["replay"] = rep
	entries.append(mine)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("v", 0)) > int(b.get("v", 0)))
	entries = entries.slice(0, MAX_ENTRIES)
	for i in range(10, entries.size()):
		(entries[i] as Dictionary).erase("replay")
	data[key] = entries


## New week: current weekly boards become last week's final standings (kept
## for prize claims), fresh weekly boards start empty.
func _rollover(data: Dictionary) -> void:
	var wk := week_id()
	var stored := int(data.get("week", wk))
	if stored < wk:
		data["lw_week"] = stored
		for m: String in MODES:
			data["lw_" + m] = data.get("wk_" + m, [])
			data["wk_" + m] = []
	data["week"] = wk


## Pays out last week's top-3 prizes for every mode I placed in. Runs after
## any fetch; each finished week is checked exactly once per save.
func _claim_rewards() -> void:
	var lw := int(board.get("lw_week", -1))
	if lw < 0 or lw <= GameState.weekly_claimed:
		return
	var gold := 0
	var gems := 0
	for m: String in MODES:
		var list: Array = board.get("lw_" + m, [])
		list = list.filter(func(e: Variant) -> bool: return e is Dictionary)
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("v", 0)) > int(b.get("v", 0)))
		for i in mini(3, list.size()):
			if str(list[i].get("id")) == GameState.player_id:
				gold += WEEKLY_REWARDS[i][0]
				gems += WEEKLY_REWARDS[i][1]
	GameState.weekly_claimed = lw
	GameState.save_game()
	if gold > 0 or gems > 0:
		GameState.add_currency(gold, gems)
		weekly_reward.emit(gold, gems)


## 랭킹 화면이 지금 보고 있는 보드 하나를 불러온다. HTTP 백엔드는 blob이 통째로
## 오므로 그냥 refresh()와 같고, 스팀은 보드마다 따로 받아야 해서 탭을 옮길 때마다
## 이게 불린다. 끝나면 board_loaded(ok).
func view(mode_key: String, weekly := false) -> void:
	if backend() != Backend.STEAM:
		await refresh()
		return
	if busy:
		return
	busy = true
	var key := ("wk_" if weekly else "") + mode_key
	if LIVE_MODES.has(mode_key):
		board[key] = await Platform.fetch_board(board_name(mode_key, weekly), STEAM_FETCH)
	else:
		board[key] = []  # 내려둔 모드는 스팀 보드가 없다
	busy = false
	board_loaded.emit(true)
	await _claim_rewards_steam()


## 스팀 주간 시상: 지난주 보드의 상위 3명 안에 내가 있으면 보상을 준다.
## 한 주에 한 번, 랭킹 화면을 열었을 때만 확인한다.
func _claim_rewards_steam() -> void:
	var lw := week_id() - 1
	if lw <= GameState.weekly_claimed:
		return
	var gold := 0
	var gems := 0
	var mine := my_id()
	for m: String in LIVE_MODES:
		var list: Array = await Platform.fetch_board(board_name(m, true, lw), 3)
		for i in mini(3, list.size()):
			if str(list[i].get("id")) == mine:
				gold += WEEKLY_REWARDS[i][0]
				gems += WEEKLY_REWARDS[i][1]
	GameState.weekly_claimed = lw
	GameState.save_game()
	if gold > 0 or gems > 0:
		GameState.add_currency(gold, gems)
		weekly_reward.emit(gold, gems)


## Refreshes the whole board; listeners get board_loaded(ok). Viewing also
## performs the weekly rollover (so boards reset even if nobody submits) and
## collects any pending last-week prize. HTTP 백엔드 전용.
func refresh() -> void:
	if not online() or busy or backend() == Backend.STEAM:
		board_loaded.emit(online() and not board.is_empty())
		return
	busy = true
	var data: Variant = await _http(HTTPClient.METHOD_GET)
	if data is Dictionary:
		var stored := int(data.get("week", -1))
		_rollover(data)
		board = data
		if stored != -1 and stored != int(data.get("week")) and not _submitting:
			_submitting = true
			await _http(HTTPClient.METHOD_PUT, JSON.stringify(data))
			_submitting = false
		_claim_rewards()
	busy = false
	board_loaded.emit(data is Dictionary)


## Sorted entries for a board — the fetched data online, or the mock crowd
## merged with my real local record while the backend isn't wired up.
func entries(mode_key: String, weekly := false) -> Array:
	var list: Array
	var my_v := GameState.weekly_value(mode_key) if weekly else local_value(mode_key)
	if online():
		list = board.get(("wk_" if weekly else "") + mode_key, [])
		list = list.filter(func(e: Variant) -> bool: return e is Dictionary)
	else:
		list = _mock_entries(mode_key, weekly)
		if my_v > 0:
			list.append({"id": GameState.player_id, "name": GameState.nickname,
					"v": my_v, "cat": GameState.selected_cat})
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("v", 0)) > int(b.get("v", 0)))
	return list


## Deterministic bot board per mode: same names, same scores, every visit —
## so climbing past "골골송장인" actually feels earned. Weekly mocks reshuffle
## each week with smaller scores.
func _mock_entries(mode_key: String, weekly := false) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("cattris-" + mode_key + ("-w%d" % week_id() if weekly else ""))
	var out: Array = []
	var s := 0.5 if weekly else 1.0  # a week's grind runs lower than a lifetime's
	for i in MOCK_NAMES.size():
		var v := 0
		match mode_key:
			"story":
				v = clampi(int((120 - i * 5 - rng.randi_range(0, 3)) * s), 1, 120)
			"endless":
				v = maxi(int(130.0 * s * pow(0.83, i)) + rng.randi_range(0, 4), 2)
			"classic":
				v = maxi(int(240000.0 * s * pow(0.72, i)) + rng.randi_range(0, 900), 400)
			"picnic":
				v = maxi(int(2600.0 * s * pow(0.85, i)) + rng.randi_range(0, 90), 150)
		out.append({"id": "bot-%d" % i, "name": MOCK_NAMES[i], "v": v,
				"cat": MOCK_CATS[rng.randi_range(0, MOCK_CATS.size() - 1)]})
	return out


## Replay for a board entry: my own comes from disk (always freshest),
## other players' ride inside their entry (HTTP) 또는 스팀 UGC로 내려받는다.
## {} when there is none. 스팀 경로는 네트워크를 타므로 await 할 것.
func replay_for(mode_key: String, e: Dictionary) -> Dictionary:
	if str(e.get("id")) == my_id():
		return Replays.load_replay(mode_key)
	if backend() == Backend.STEAM:
		return Replays.unpack(await Platform.fetch_replay(e))
	return Replays.decode(str(e.get("replay", "")))


func has_replay_for(mode_key: String, e: Dictionary) -> bool:
	if str(e.get("id")) == my_id():
		return Replays.has_replay(mode_key)
	if backend() == Backend.STEAM:
		return int(e.get("ugc", 0)) > 0
	return str(e.get("replay", "")) != ""


## My 1-based rank on a board (0 = not on it yet).
func my_rank(mode_key: String, weekly := false) -> int:
	var list := entries(mode_key, weekly)
	var mine := my_id()
	for i in list.size():
		if str(list[i].get("id")) == mine:
			return i + 1
	return 0


## Renaming updates every board entry I own (fire-and-forget).
## 스팀은 이름을 페르소나에서 가져오므로 다시 올릴 게 없다.
func rename_and_resubmit() -> void:
	if backend() == Backend.STEAM:
		return
	for m: String in MODES:
		if local_value(m) > 0:
			submit(m, local_value(m))


func _http(method: HTTPClient.Method, body := "") -> Variant:
	var req := HTTPRequest.new()
	req.timeout = 8.0
	add_child(req)
	var headers := PackedStringArray(["Content-Type: application/json",
			"Accept: application/json"])
	var err := req.request(BOARD_URL, headers, method, body)
	if err != OK:
		req.queue_free()
		return null
	var result: Array = await req.request_completed
	req.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or int(result[1]) >= 400:
		return null
	if method == HTTPClient.METHOD_PUT:
		return {}
	return JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
