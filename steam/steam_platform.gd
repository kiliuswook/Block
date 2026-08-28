extends PlatformBase
## 스팀 빌드 전용 구현 — GodotSteam GDExtension(addons/godotsteam) 위에서 돈다.
## 주의: class_name 붙이지 말 것 — 모바일/웹 빌드에서 이 파일은 제외되므로
## 전역 클래스로 등록되면 참조하는 쪽이 깨진다.
##
## 여기가 하는 일: 스팀 초기화, 업적, 리더보드(전체/주간), 리플레이 UGC 첨부,
## 클라우드 세이브 업로드. 계약은 platform_base.gd에 적혀 있다.
##
## **비동기 규칙**: GodotSteam의 콜백은 Steam 싱글톤에서 *전역* 시그널로 온다 —
## 어느 요청의 응답인지 시그널만 봐서는 알 수 없다. 그래서 리더보드 작업 전체를
## `_busy` 하나로 직렬화한다. 동시에 두 개를 던지면 응답이 뒤바뀐다.

## Steamworks 열거값 — GodotSteam의 Steam.LEADERBOARD_* 와 같은 값이지만,
## 확장이 없는 환경에서도 이 파일이 파싱되도록 숫자로 박아 둔다.
const SORT_DESCENDING := 2  # 높은 점수가 1위 (모든 보드가 점수/높이 기준)
const DISPLAY_NUMERIC := 1
const REQUEST_GLOBAL := 0

## 엔트리에 함께 싣는 int32 개수. [0]=캐릭터 인덱스, 나머지는 나중을 위해 예약.
const DETAILS_MAX := 4
## 콜백을 기다리는 최대 시간 — 넘기면 실패로 보고 조용히 포기한다.
const TIMEOUT := 10.0
## 리플레이를 올려 두는 스팀 클라우드 파일 이름 앞머리.
const REPLAY_PREFIX := "replay_"
## 남의 리플레이를 내려받아 두는 임시 경로.
const REPLAY_TMP := "user://ugc_replay.dat"

var _steam: Object = null
var _ok := false  # 초기화 성공 + 스팀 클라이언트 살아 있음
var _busy := false  # 리더보드 작업 직렬화
var _handles := {}  # 보드 이름 -> 리더보드 핸들 (세션 캐시)
var _id := ""
var _name := ""


func platform_name() -> String:
	return "steam"


func setup() -> void:
	if not Engine.has_singleton("Steam"):
		push_warning("[Steam] GodotSteam 확장이 없다 — 리더보드는 오프라인으로 돈다.")
		return
	_steam = Engine.get_singleton("Steam")
	# embed_callbacks = true → GodotSteam이 SceneTree.process_frame에 콜백 펌프를
	# 직접 물린다. 우리 쪽에서 run_callbacks()를 매 프레임 돌릴 필요가 없다.
	var res: Dictionary = _steam.steamInitEx(_app_id(), true)
	var status := int(res.get("status", -1))
	if status != 0:  # 0 = STEAM_API_INIT_RESULT_OK
		push_warning("[Steam] 초기화 실패(%d): %s" % [status, res.get("verbal", "")])
		_steam = null
		return
	_ok = true
	_steam.set_leaderboard_details_max(DETAILS_MAX)
	_id = str(_steam.getSteamID())
	_name = str(_steam.getPersonaName())
	print("[Steam] 준비됨 — app %d, %s (%s)" % [_app_id(), _name, _id])


func shutdown() -> void:
	if _ok and _steam != null:
		_steam.steamShutdown()
		_ok = false


## 앱 id는 프로젝트 설정에서 읽는다. 스팀 출시 id를 받으면 그 값만 바꾸면 된다.
## 기본값 480 = Valve의 공개 테스트 앱 "Spacewar" — 리더보드 실험용.
func _app_id() -> int:
	return int(ProjectSettings.get_setting("cattris/steam/app_id", 480))


func unlock_achievement(id: String) -> void:
	if not _ok:
		return
	_steam.setAchievement(id)
	_steam.storeStats()


## save.json을 스팀 클라우드에 올린다. **내려받기는 하지 않는다** — 양방향
## 동기화는 파트너 사이트의 Auto-Cloud 설정(코드 없이 user:// 폴더를 통째로
## 동기화)이 정답이고, 이건 그 설정 전에도 백업이 남게 하는 보조 수단이다.
func sync_cloud_save() -> void:
	if not _ok or not _steam.isCloudEnabledForApp():
		return
	var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data := f.get_buffer(f.get_length())
	_steam.fileWrite("save.json", data, data.size())


func has_leaderboards() -> bool:
	return _ok


func user_id() -> String:
	return _id


func user_name() -> String:
	return _name


func can_wipe_scores() -> bool:
	return false  # 스팀은 클라이언트가 자기 리더보드 엔트리를 지울 수 없다


# --- 리더보드 -----------------------------------------------------------------

func submit_score(board_id: String, score: int, details := PackedInt32Array(),
		replay := PackedByteArray()) -> void:
	if not _ok or score <= 0:
		return
	await _lock()
	var handle := await _handle(board_id)
	if handle == 0:
		_unlock()
		return
	var box: Array = []
	var cb := func(success: bool, h: int, s: Dictionary) -> void:
		box.append([success, h, s])
	_steam.leaderboard_score_uploaded.connect(cb, CONNECT_ONE_SHOT)
	# keep_best = true → 지금 점수가 기존 기록보다 낮으면 스팀이 무시한다.
	# 로컬 최고 기록을 그대로 밀어 넣어도 보드가 뒤로 가지 않는다.
	_steam.uploadLeaderboardScore(score, true, _pad(details), handle)
	var r: Variant = await _poll(box, _steam.leaderboard_score_uploaded, cb)
	if r != null and bool(r[0]) and not replay.is_empty():
		await _attach_replay(board_id, handle, replay)
	_unlock()


func fetch_board(board_id: String, count: int) -> Array:
	if not _ok:
		return []
	await _lock()
	var handle := await _handle(board_id)
	if handle == 0:
		_unlock()
		return []
	var box: Array = []
	var cb := func(message: String, h: int, entries: Array) -> void:
		box.append([message, h, entries])
	_steam.leaderboard_scores_downloaded.connect(cb, CONNECT_ONE_SHOT)
	_steam.downloadLeaderboardEntries(1, maxi(count, 1), REQUEST_GLOBAL, handle)
	var r: Variant = await _poll(box, _steam.leaderboard_scores_downloaded, cb)
	_unlock()
	if r == null:
		return []
	return await _to_entries(r[2] as Array)


## 다른 플레이어 엔트리에 붙은 리플레이를 내려받는다. 스팀은 UGC를 파일로만
## 주기 때문에 임시 파일로 받아서 읽고 지운다.
func fetch_replay(entry: Dictionary) -> PackedByteArray:
	var ugc := int(entry.get("ugc", 0))
	if not _ok or ugc <= 0:
		return PackedByteArray()
	await _lock()
	var box: Array = []
	var cb := func(result: int, data: Dictionary) -> void:
		box.append([result, data])
	_steam.download_ugc_result.connect(cb, CONNECT_ONE_SHOT)
	_steam.ugcDownloadToLocation(ugc, ProjectSettings.globalize_path(REPLAY_TMP), 0)
	var r: Variant = await _poll(box, _steam.download_ugc_result, cb)
	_unlock()
	if r == null or int(r[0]) != 1:  # 1 = RESULT_OK
		return PackedByteArray()
	var f := FileAccess.open(REPLAY_TMP, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var bytes := f.get_buffer(f.get_length())
	f.close()
	DirAccess.remove_absolute(REPLAY_TMP)
	return bytes


## 리플레이를 스팀 클라우드에 쓰고 → 공유 핸들을 받아 → 내 엔트리에 붙인다.
## 셋 중 하나라도 실패하면 리플레이 없이 점수만 남는다 (치명적이지 않다).
func _attach_replay(board_id: String, handle: int, replay: PackedByteArray) -> void:
	var file_name := REPLAY_PREFIX + board_id + ".dat"
	if not _steam.fileWrite(file_name, replay, replay.size()):
		return
	var box: Array = []
	var cb := func(result: int, ugc: int, n: String) -> void:
		box.append([result, ugc, n])
	_steam.file_share_result.connect(cb, CONNECT_ONE_SHOT)
	_steam.fileShare(file_name)
	var r: Variant = await _poll(box, _steam.file_share_result, cb)
	if r == null or int(r[0]) != 1:  # 1 = RESULT_OK
		return
	_steam.attachLeaderboardUGC(int(r[1]), handle)


## 보드 이름 → 핸들. 없으면 만든다(스팀은 클라이언트의 보드 생성을 허용한다) —
## 주간 보드가 주마다 새 이름으로 생기는 게 이 호출에 기대고 있다.
## 이미 _lock()을 잡은 상태에서만 부를 것.
func _handle(board_id: String) -> int:
	if _handles.has(board_id):
		return int(_handles[board_id])
	var box: Array = []
	var cb := func(h: int, found: int) -> void:
		box.append([h, found])
	_steam.leaderboard_find_result.connect(cb, CONNECT_ONE_SHOT)
	_steam.findOrCreateLeaderboard(board_id, SORT_DESCENDING, DISPLAY_NUMERIC)
	var r: Variant = await _poll(box, _steam.leaderboard_find_result, cb)
	if r == null or int(r[1]) == 0:
		return 0
	_handles[board_id] = int(r[0])
	return int(r[0])


## 스팀 엔트리를 게임이 쓰는 형식으로. 이름은 스팀에 물어보는데, 친구가 아닌
## 유저는 캐시에 없어서 한 박자 기다렸다가 읽는다 — 그래도 비면 SteamID 꼬리로
## 대체 이름을 만든다(보드가 "???"로 도배되지 않게).
func _to_entries(raw: Array) -> Array:
	var ids: Array = []
	for e: Dictionary in raw:
		var sid := int(e.get("steam_id", 0))
		if sid != 0:
			ids.append(sid)
			_steam.requestUserInformation(sid, true)
	if not ids.is_empty():
		await Engine.get_main_loop().create_timer(0.4).timeout
	var out: Array = []
	for e: Dictionary in raw:
		var sid := int(e.get("steam_id", 0))
		var who := str(_steam.getFriendPersonaName(sid)) if sid != 0 else ""
		if who == "" or who == "[unknown]":
			who = "냥이 %04d" % (sid % 10000)
		var details: PackedInt32Array = e.get("details", PackedInt32Array())
		out.append({
			"id": str(sid),
			"name": who,
			"v": int(e.get("score", 0)),
			"cat": Ranks.cat_from_index(details[0] if details.size() > 0 else -1),
			# 첨부가 없으면 스팀이 k_UGCHandleInvalid(=부호 있는 정수로 -1)를
			# 준다. 0으로 눕혀서 "없음"을 한 가지 값으로만 표현한다.
			"ugc": maxi(int(e.get("ugc_handle", 0)), 0),
		})
	return out


func _pad(details: PackedInt32Array) -> PackedInt32Array:
	var out := details.duplicate()
	out.resize(DETAILS_MAX)  # 스팀은 항상 details_max 개를 기대한다
	return out


# --- 콜백 대기 ----------------------------------------------------------------

## 리더보드 작업 하나가 끝날 때까지 다음 작업을 붙잡아 둔다.
func _lock() -> void:
	while _busy:
		await Engine.get_main_loop().process_frame
	_busy = true


func _unlock() -> void:
	_busy = false


## box에 응답이 들어오거나 TIMEOUT이 지날 때까지 프레임을 돌린다.
## 시그널 대기와 타임아웃을 동시에 걸 수 없어서(await은 하나만 기다린다)
## 한 프레임씩 확인하는 방식을 쓴다. 타임아웃이면 null.
func _poll(box: Array, sig: Signal, cb: Callable) -> Variant:
	var until := Time.get_ticks_msec() + int(TIMEOUT * 1000.0)
	while box.is_empty() and Time.get_ticks_msec() < until:
		await Engine.get_main_loop().process_frame
	if box.is_empty():
		if sig.is_connected(cb):
			sig.disconnect(cb)  # 늦게 온 응답이 다음 요청을 오염시키지 않게
		push_warning("[Steam] 콜백 시간 초과 — 요청을 버린다.")
		return null
	return box[0]
