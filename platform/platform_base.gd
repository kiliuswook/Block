class_name PlatformBase
extends RefCounted
## 플랫폼별 기능의 no-op 기본 구현. 웹/에디터 빌드는 이 클래스를 그대로 사용.
## 스팀/모바일 구현체는 이 클래스를 extends 하고 필요한 메서드만 오버라이드.

func platform_name() -> String:
	return "generic"


## 도전과제/업적 해금 (스팀: Steamworks, 모바일: Play Games/Game Center)
func unlock_achievement(_id: String) -> void:
	pass


## 리더보드 점수 제출 (무한의 계단 높이 기록 등)
func submit_score(_board_id: String, _score: int) -> void:
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
