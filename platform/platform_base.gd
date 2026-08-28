class_name PlatformBase
extends RefCounted
## 플랫폼별 기능의 no-op 기본 구현. 웹/에디터 빌드는 이 클래스를 그대로 사용.
## 스팀/모바일 구현체는 이 클래스를 extends 하고 필요한 메서드만 오버라이드.
##
## 리더보드 계약: 게임 쪽(`Ranks`)은 여기 정의된 4개 메서드만 알면 되고,
## 스팀 리더보드인지 자체 HTTP 보드인지는 신경 쓰지 않는다.
## `has_leaderboards()`가 false면 `Ranks`가 기존 HTTP 백엔드로 떨어진다.

func platform_name() -> String:
	return "generic"


## 플랫폼 SDK 초기화. Platform autoload가 _ready에서 한 번 호출한다.
func setup() -> void:
	pass


## 종료 시 정리 (스팀: SteamAPI_Shutdown).
func shutdown() -> void:
	pass


## 도전과제/업적 해금 (스팀: Steamworks, 모바일: Play Games/Game Center)
func unlock_achievement(_id: String) -> void:
	pass


## 클라우드 세이브 동기화 요청. 미지원 플랫폼은 no-op (로컬 save.json만 사용)
func sync_cloud_save() -> void:
	pass


## 인앱 결제 지원 여부 (모바일 전용)
func supports_iap() -> bool:
	return false


## 광고 지원 여부 (모바일 전용)
func supports_ads() -> bool:
	return false


# --- 리더보드 ------------------------------------------------------------------
# board_id는 `Ranks`가 만드는 보드 이름 그대로다 ("endless", "endless_w2953" 등).

## 이 플랫폼이 리더보드를 제공하는가. 스팀은 초기화에 성공했을 때만 true —
## 스팀 클라이언트가 꺼져 있으면 false라 게임은 오프라인 보드로 돌아간다.
func has_leaderboards() -> bool:
	return false


## 보드에서 나를 식별하는 id (스팀: SteamID 문자열). 빈 문자열이면
## `Ranks`가 save.json의 player_id를 쓴다.
func user_id() -> String:
	return ""


## 플랫폼이 아는 내 표시 이름 (스팀: 페르소나 이름). 빈 문자열이면 닉네임 사용.
func user_name() -> String:
	return ""


## 점수 제출. details는 엔트리에 같이 싣는 작은 정수 배열(스팀은 int32 × 최대 64),
## replay는 첨부할 리플레이 바이트 — 빈 배열이면 첨부하지 않는다.
## 실패해도 조용히 넘어간다 (기록은 로컬에 남아 있고 다음에 다시 올라간다).
func submit_score(_board_id: String, _score: int, _details := PackedInt32Array(),
		_replay := PackedByteArray()) -> void:
	pass


## 보드 상위 엔트리 조회 (await 가능). 반환 형식은 `Ranks`의 엔트리와 같은
## [{"id": String, "name": String, "v": int, "cat": String, "ugc": int}] —
## "ugc"는 첨부 리플레이 핸들(0 = 없음). 실패하면 빈 배열.
func fetch_board(_board_id: String, _count: int) -> Array:
	return []


## 엔트리에 첨부된 리플레이 내려받기 (await 가능). 없으면 빈 배열.
func fetch_replay(_entry: Dictionary) -> PackedByteArray:
	return PackedByteArray()


## 보드에서 내 기록을 지울 수 있는가. 스팀 리더보드는 클라이언트가 자기 엔트리를
## 삭제할 수 없어서 false — 설정 > 게임 초기화가 그 사실을 안내한다.
func can_wipe_scores() -> bool:
	return false
