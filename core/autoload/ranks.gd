extends Node
## Online leaderboards, one board per mode (story / endless / classic).
## Backend: a single shared JSON blob behind a plain REST endpoint
## (GET = whole board, PUT = replace whole board). BOARD_URL empty means
## offline mode — the UI then shows only the local records.
## Entries: {"id": String, "name": String, "v": int, "cat": String}.

signal board_loaded(ok: bool)

## Set this to a jsonblob.com blob URL (or any GET/PUT JSON endpoint) to go
## online, e.g. "https://jsonblob.com/api/jsonBlob/<id>".
const BOARD_URL := ""
const MODES := ["story", "endless", "classic"]
const MAX_ENTRIES := 100  # kept per mode, sorted by value desc

## Offline placeholder crowd: until the backend goes live, boards are filled
## with these bot entries (deterministic per mode) plus the real local record.
const MOCK_NAMES := ["츄르대장", "골골송장인", "캣타워폭격기", "우다다다", "식빵굽는냥",
		"까칠한젤리", "높이높이", "츄르에진심", "안자는고양이", "꾹꾹이달인", "그르렁",
		"수염봉봉", "방울이", "호랑무늬", "낮잠금지", "점프좀치는냥", "테트리스냥",
		"용암싫어", "골드사냥꾼", "계단오르미", "블록부수기", "살금살금", "야옹백작",
		"츄르한입만"]
const MOCK_CATS := ["cream", "cheese", "calico", "black", "gray", "mint", "pink",
		"ghost", "gold"]

var board := {}  # last fetched board: mode key -> Array of entries
var busy := false


func _ready() -> void:
	# Push any pre-existing local bests once at startup, so records earned
	# before the ranking update (or offline) still make it onto the board.
	submit_all.call_deferred()


func online() -> bool:
	return BOARD_URL != ""


## My current local best for a mode key.
func local_value(mode_key: String) -> int:
	match mode_key:
		"story":
			return GameState.story_stage
		"endless":
			return GameState.best_height
		"classic":
			return GameState.classic_best
	return 0


func value_text(mode_key: String, v: int) -> String:
	match mode_key:
		"story":
			return "STAGE %d" % v
		"endless":
			return "%d층" % v
	return "%d점" % v


func submit_all() -> void:
	for m: String in MODES:
		if local_value(m) > 0:
			submit(m, local_value(m))


## Fire-and-forget: merge my best into the shared board (read-modify-write).
func submit(mode_key: String, value: int) -> void:
	if not online() or value <= 0:
		return
	var data: Variant = await _http(HTTPClient.METHOD_GET)
	if data is not Dictionary:
		return
	var entries: Array = data.get(mode_key, [])
	entries = entries.filter(func(e: Variant) -> bool:
		return e is Dictionary and str(e.get("id")) != GameState.player_id)
	var mine := {"id": GameState.player_id, "name": GameState.nickname,
			"v": maxi(value, local_value(mode_key)), "cat": GameState.selected_cat}
	entries.append(mine)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("v", 0)) > int(b.get("v", 0)))
	data[mode_key] = entries.slice(0, MAX_ENTRIES)
	board = data
	await _http(HTTPClient.METHOD_PUT, JSON.stringify(data))


## Refreshes the whole board; listeners get board_loaded(ok).
func refresh() -> void:
	if not online() or busy:
		board_loaded.emit(online() and not board.is_empty())
		return
	busy = true
	var data: Variant = await _http(HTTPClient.METHOD_GET)
	busy = false
	if data is Dictionary:
		board = data
	board_loaded.emit(data is Dictionary)


## Sorted entries for a mode — the fetched board online, or the mock crowd
## merged with my real local record while the backend isn't wired up.
func entries(mode_key: String) -> Array:
	var list: Array
	if online():
		list = board.get(mode_key, [])
		list = list.filter(func(e: Variant) -> bool: return e is Dictionary)
	else:
		list = _mock_entries(mode_key)
		if local_value(mode_key) > 0:
			list.append({"id": GameState.player_id, "name": GameState.nickname,
					"v": local_value(mode_key), "cat": GameState.selected_cat})
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("v", 0)) > int(b.get("v", 0)))
	return list


## Deterministic bot board per mode: same names, same scores, every visit —
## so climbing past "골골송장인" actually feels earned.
func _mock_entries(mode_key: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("cattris-" + mode_key)
	var out: Array = []
	for i in MOCK_NAMES.size():
		var v := 0
		match mode_key:
			"story":
				v = clampi(120 - i * 5 - rng.randi_range(0, 3), 1, 120)
			"endless":
				v = maxi(int(130.0 * pow(0.83, i)) + rng.randi_range(0, 4), 2)
			"classic":
				v = maxi(int(240000.0 * pow(0.72, i)) + rng.randi_range(0, 900), 400)
		out.append({"id": "bot-%d" % i, "name": MOCK_NAMES[i], "v": v,
				"cat": MOCK_CATS[rng.randi_range(0, MOCK_CATS.size() - 1)]})
	return out


## My 1-based rank on the fetched board (0 = not on it yet).
func my_rank(mode_key: String) -> int:
	var list := entries(mode_key)
	for i in list.size():
		if str(list[i].get("id")) == GameState.player_id:
			return i + 1
	return 0


## Renaming updates every board entry I own (fire-and-forget).
func rename_and_resubmit() -> void:
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
