extends Node
## Platform autoload — 실행 중인 빌드에 맞는 플랫폼 구현체를 선택.
## 게임 코드는 Platform.impl 또는 아래 위임 메서드만 호출하고,
## 스팀/모바일 구현체(steam/, mobile/)를 preload로 직접 참조하지 말 것
## (익스포트 필터로 반대 플랫폼 리소스가 빌드에서 제외되므로 파싱이 깨짐).

var impl: PlatformBase


func _ready() -> void:
	# autoload는 boot.gd보다 먼저 도므로 dev_platform을 못 본다 — 개발 중
	# 스팀/모바일 구현체를 쓰려면 커맨드라인 인자로 강제한다 (boot.gd와 같은 규칙).
	var path := ""
	if OS.has_feature("steam") or _forced("--steam"):
		path = "res://steam/steam_platform.gd"
	elif OS.has_feature("mobile") or _forced("--mobile"):
		path = "res://mobile/mobile_platform.gd"
	# 익스포트 필터로 빠진 구현체를 강제로 부르면 null이 오므로 존재를 확인한다.
	impl = load(path).new() if path != "" and ResourceLoader.exists(path) \
			else PlatformBase.new()
	impl.setup()
	print("[Platform] ", impl.platform_name())
	# 스팀 페르소나 같은 계정 이름이 있으면 그걸 내 이름으로 삼는다
	# (autoload 순서상 GameState._ready 때는 아직 스팀이 안 떠 있다).
	GameState.adopt_platform_name()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if impl != null:
			impl.shutdown()


## `-- --steam`(사용자 인자)도 `--steam`(구분자 없이)도 허용 — boot.gd와 동일.
func _forced(flag: String) -> bool:
	return flag in OS.get_cmdline_user_args() or flag in OS.get_cmdline_args()


func platform_name() -> String:
	return impl.platform_name()


func unlock_achievement(id: String) -> void:
	impl.unlock_achievement(id)


func sync_cloud_save() -> void:
	impl.sync_cloud_save()


func supports_iap() -> bool:
	return impl.supports_iap()


func supports_ads() -> bool:
	return impl.supports_ads()


# --- 리더보드 (계약 설명은 platform_base.gd 참고) --------------------------------

func has_leaderboards() -> bool:
	return impl != null and impl.has_leaderboards()


func user_id() -> String:
	return impl.user_id()


func user_name() -> String:
	return impl.user_name()


func submit_score(board_id: String, score: int, details := PackedInt32Array(),
		replay := PackedByteArray()) -> void:
	impl.submit_score(board_id, score, details, replay)


func fetch_board(board_id: String, count: int) -> Array:
	return await impl.fetch_board(board_id, count)


func fetch_replay(entry: Dictionary) -> PackedByteArray:
	return await impl.fetch_replay(entry)


func can_wipe_scores() -> bool:
	return impl.can_wipe_scores()
