extends Node
## Supabase 백엔드 클라이언트 (모바일 서비스용) — 익명 로그인 · 클라우드 세이브 ·
## 리더보드 제출/조회 · 주간 시상 청구를 맡는다. 스팀 빌드는 Steamworks가 이 일을
## 대신하므로 여기서는 통째로 꺼진다(`enabled()`).
##
## **신뢰 모델(A안: 지갑은 클라이언트가 주인)** — 서버가 맡는 것은 셋뿐이다:
##   ① 랭킹 보드 (내 행만 쓸 수 있게 RLS로 막는다)
##   ② 주간 정산 (서버 cron이 지난 주 상위 3을 뽑아 rewards 행을 만든다 —
##      클라이언트는 `claim_rewards()`로 받기만 하고 순위를 스스로 읽지 않는다)
##   ③ 세이브 백업 (기기 이전·재설치 복구용. 값을 검증하지는 않는다)
## 골드·키캡·레벨은 계속 로컬 save.json이 주인이다. 결제를 붙일 때 B안(서버가
## 지갑의 주인)으로 올리려면 여기가 아니라 서버 함수부터 늘어난다.
##
## 설정은 `project.godot`의 `cattris/cloud/url`·`cattris/cloud/anon_key`.
## 비어 있으면 아무 요청도 나가지 않고 `Ranks`가 예전 백엔드로 떨어진다.
## 서버 스키마는 `server/supabase/schema.sql`, 대시보드 절차는 `docs/cloud_setup.md`.

signal auth_changed(ok: bool)
signal save_pulled  ## 서버 세이브가 더 최신이라 로컬을 갈아 끼웠다

const URL_SETTING := "cattris/cloud/url"
const KEY_SETTING := "cattris/cloud/anon_key"
## 로그인 토큰은 세이브와 따로 둔다 — 게임 초기화가 계정까지 날리면 안 된다.
const TOKEN_PATH := "user://cloud.json"
const TIMEOUT := 8.0
## 세이브 푸시 디바운스: save_game()이 자주 불리므로 마지막 호출 뒤 이만큼 기다린다.
const PUSH_DELAY := 5.0
## 보드 엔트리에 실어 보낼 base64 리플레이 상한 (누적 보드 상위권만 붙는다).
const REPLAY_MAX := 60000
## scores.week_id 의 누적(전체 기간) 보드 표식. 주간 보드는 Ranks.week_id().
const ALL_TIME := -1

var uid := ""  ## 서버가 준 내 계정 id (auth.users.id) — 보드 엔트리의 "id"

var _url := ""
var _key := ""
var _token := ""
var _refresh := ""
var _expires := 0  # access token 만료 unix time
var _authing := false
var _pushing := false
var _dirty := false
var _push_at := 0.0
var _suppress := false  # 우리가 부른 save_game()이 다시 푸시를 예약하지 않게


func _ready() -> void:
	set_process(false)
	_url = str(ProjectSettings.get_setting(URL_SETTING, "")).strip_edges()
	while _url.ends_with("/"):
		_url = _url.substr(0, _url.length() - 1)
	_key = str(ProjectSettings.get_setting(KEY_SETTING, "")).strip_edges()
	if not enabled():
		return
	_load_tokens()
	set_process(true)
	sync.call_deferred()


## 이 빌드가 서버 백엔드를 쓰는가. 스팀 빌드는 Steamworks가 랭킹·클라우드를
## 맡으므로 설정이 있어도 끈다.
func enabled() -> bool:
	return _url != "" and _key != "" and not OS.has_feature("steam")


func authed() -> bool:
	return uid != "" and _token != ""


func _process(delta: float) -> void:
	if not _dirty or _pushing:
		return
	_push_at -= delta
	if _push_at <= 0.0:
		_dirty = false
		push_save()


## 세이브가 바뀌었다는 표시 — GameState.save_game()이 부른다. 실제 업로드는
## PUSH_DELAY 뒤에 한 번만 나간다.
func mark_dirty() -> void:
	if not enabled() or _suppress:
		return
	_dirty = true
	_push_at = PUSH_DELAY


## 부팅 동기화: 로그인 → 서버 세이브가 더 최신이면 받아서 갈아 끼운다.
func sync() -> void:
	if not enabled():
		return
	await pull_save()


# --- 인증 ----------------------------------------------------------------------
# 익명 로그인이라 가입 절차가 없다. 토큰은 user://cloud.json 에 남고, 앱을 지우면
# 계정도 사라진다 — 기기 이전을 지원하려면 나중에 구글/애플 로그인 연동을 얹는다.


func ensure_auth() -> bool:
	if not enabled():
		return false
	while _authing:
		await get_tree().process_frame
	if authed() and Time.get_unix_time_from_system() < _expires - 60:
		return true
	_authing = true
	var ok := false
	if _refresh != "":
		ok = await _refresh_session()
	if not ok:
		ok = await _sign_in_anon()
	_authing = false
	auth_changed.emit(ok)
	return ok


func _sign_in_anon() -> bool:
	var res := await _api(HTTPClient.METHOD_POST, "/auth/v1/signup", "{}")
	return _adopt_session(res.get("data"))


func _refresh_session() -> bool:
	var body := JSON.stringify({"refresh_token": _refresh})
	var res := await _api(HTTPClient.METHOD_POST,
			"/auth/v1/token?grant_type=refresh_token", body)
	if _adopt_session(res.get("data")):
		return true
	_refresh = ""  # 만료된 refresh 토큰은 버리고 새 익명 계정으로 간다
	return false


func _adopt_session(data: Variant) -> bool:
	if data is not Dictionary:
		return false
	var d: Dictionary = data
	var tok := str(d.get("access_token", ""))
	if tok == "":
		return false
	_token = tok
	_refresh = str(d.get("refresh_token", _refresh))
	_expires = int(Time.get_unix_time_from_system()) + int(d.get("expires_in", 3600))
	var user: Variant = d.get("user")
	if user is Dictionary:
		uid = str((user as Dictionary).get("id", uid))
	_store_tokens()
	return uid != ""


func _load_tokens() -> void:
	if not FileAccess.file_exists(TOKEN_PATH):
		return
	var f := FileAccess.open(TOKEN_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is not Dictionary:
		return
	var d: Dictionary = data
	uid = str(d.get("uid", ""))
	_token = str(d.get("token", ""))
	_refresh = str(d.get("refresh", ""))
	_expires = int(d.get("expires", 0))


func _store_tokens() -> void:
	var f := FileAccess.open(TOKEN_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"uid": uid, "token": _token,
				"refresh": _refresh, "expires": _expires}))


# --- 클라우드 세이브 -------------------------------------------------------------
# save.json 통째로 한 행. 충돌은 rev(단조 증가) 하나로 정리한다 — 서버 rev가 더
# 크면 서버가 이긴다(다른 기기에서 더 논 것). 같거나 작으면 내 것을 올린다.


## 서버 rev가 로컬보다 앞서 있는가 = 서버 세이브를 받아야 하는가.
func should_adopt(local_rev: int, remote_rev: int) -> bool:
	return remote_rev > local_rev


func pull_save() -> bool:
	if not await ensure_auth():
		return false
	var res := await _api(HTTPClient.METHOD_GET, "/rest/v1/saves?select=data,rev&limit=1")
	var rows: Variant = res.get("data")
	if rows is not Array:
		return false
	if (rows as Array).is_empty():
		push_save()  # 서버에 아직 아무것도 없다 — 지금 세이브를 올려 둔다
		return false
	var row: Variant = (rows as Array)[0]
	if row is not Dictionary:
		return false
	var rev := int((row as Dictionary).get("rev", 0))
	var data: Variant = (row as Dictionary).get("data")
	if data is not Dictionary or not should_adopt(GameState.cloud_rev, rev):
		return false
	_adopt_save(data, rev)
	return true


## 받은 세이브로 로컬 save.json을 갈아 끼우고 다시 읽는다 — 마이그레이션 코드를
## 한 벌만 두려고 파일을 거쳐 간다(GameState.load_game()이 구버전 필드를 처리한다).
func _adopt_save(data: Dictionary, rev: int) -> void:
	if not GameState.save_enabled:
		return
	data["cloud_rev"] = rev
	var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f = null
	_suppress = true
	GameState.load_game()
	_suppress = false
	save_pulled.emit()


func push_save() -> void:
	if _pushing:
		return
	if not await ensure_auth():
		return
	_pushing = true
	var rev := GameState.cloud_rev + 1
	var body := JSON.stringify([{"user_id": uid, "data": GameState.save_dict(), "rev": rev}])
	var res := await _api(HTTPClient.METHOD_POST, "/rest/v1/saves", body,
			PackedStringArray(["Prefer: resolution=merge-duplicates"]))
	if int(res.get("code", 0)) < 300:
		GameState.cloud_rev = rev
		_suppress = true
		GameState.save_game()
		_suppress = false
	_pushing = false


# --- 리더보드 --------------------------------------------------------------------
# 보드 하나 = (mode, week_id) 한 쌍. 누적은 week_id = ALL_TIME(-1), 주간은 그 주차.
# 지난 주 보드는 밀어 옮기지 않고 그냥 그 주차 행으로 남는다 — 롤오버가 없다.


## 보드에 올릴 한 행. 네트워크를 타지 않아 테스트가 그대로 검사한다.
func score_row(mode_key: String, week: int, value: int, with_replay := false) -> Dictionary:
	var row := {
		"user_id": uid,
		"mode": mode_key,
		"week_id": week,
		"value": value,
		"name": GameState.display_name(),
		"cat": GameState.selected_cat,
	}
	if with_replay:
		var rep := Replays.encode(Replays.load_replay(mode_key), REPLAY_MAX)
		if rep != "":
			row["replay"] = rep
	return row


## 서버 행 → `Ranks` 엔트리 형식 {"id","name","v","cat","replay"}.
func to_entries(rows: Variant) -> Array:
	var out: Array = []
	if rows is not Array:
		return out
	for r: Variant in rows:
		if r is not Dictionary:
			continue
		var d: Dictionary = r
		var rep: Variant = d.get("replay")
		out.append({
			"id": str(d.get("user_id", "")),
			"name": str(d.get("name", "")),
			"v": int(d.get("value", 0)),
			"cat": str(d.get("cat", "")),
			"replay": str(rep) if rep != null else "",
		})
	return out


## 기록 제출 (upsert — 같은 (나, 모드, 주차) 행 하나를 갱신한다).
## 서버 트리거가 이전 값보다 낮은 제출을 무시하므로 keep-best는 서버가 지킨다.
func submit_score(mode_key: String, week: int, value: int, with_replay := false) -> void:
	if value <= 0:
		return
	if not await ensure_auth():
		return
	var body := JSON.stringify([score_row(mode_key, week, value, with_replay)])
	await _api(HTTPClient.METHOD_POST, "/rest/v1/scores", body,
			PackedStringArray(["Prefer: resolution=merge-duplicates"]))


func fetch_board(mode_key: String, week: int, count: int) -> Array:
	if not await ensure_auth():
		return []
	var path := "/rest/v1/scores?select=user_id,name,value,cat,replay"
	path += "&mode=eq.%s&week_id=eq.%d&order=value.desc,updated_at.asc&limit=%d" % [
			mode_key, week, count]
	var res := await _api(HTTPClient.METHOD_GET, path)
	return to_entries(res.get("data"))


## 서버가 정산해 둔 지난 주 상금을 받는다 — 순위 판정은 서버가 이미 끝냈고
## 여기서는 미청구분 합계를 돌려받을 뿐이다. 없으면 0.
func claim_rewards() -> int:
	if not await ensure_auth():
		return 0
	var res := await _api(HTTPClient.METHOD_POST, "/rest/v1/rpc/claim_rewards", "{}")
	var data: Variant = res.get("data")
	return int(data) if data is float or data is int else 0


## 설정 > 게임 초기화: 보드에서 내 행을 전부 지운다 (RLS가 내 것만 허용).
func wipe_scores() -> void:
	if not await ensure_auth():
		return
	await _api(HTTPClient.METHOD_DELETE, "/rest/v1/scores?user_id=eq." + uid)


# --- HTTP -----------------------------------------------------------------------


func _api(method: HTTPClient.Method, path: String, body := "",
		extra := PackedStringArray()) -> Dictionary:
	var headers := PackedStringArray(["apikey: " + _key,
			"Content-Type: application/json", "Accept: application/json"])
	if _token != "":
		headers.append("Authorization: Bearer " + _token)
	for h: String in extra:
		headers.append(h)
	return await _http(method, _url + path, body, headers)


func _http(method: HTTPClient.Method, url: String, body: String,
		headers: PackedStringArray) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT
	add_child(req)
	var err := req.request(url, headers, method, body)
	if err != OK:
		req.queue_free()
		return {"code": 0, "data": null}
	var result: Array = await req.request_completed
	req.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"code": 0, "data": null}
	var text := (result[3] as PackedByteArray).get_string_from_utf8()
	return {"code": int(result[1]), "data": JSON.parse_string(text)}
