extends PlatformBase
## 모바일(Android/iOS) 빌드 전용 구현. IAP/광고/플랫폼 게임 서비스 연동 지점.
## 주의: class_name 붙이지 말 것 — 스팀 빌드에서 이 파일은 제외됨.


func platform_name() -> String:
	return "mobile"


func supports_iap() -> bool:
	return false  # TODO: 스토어 결제 플러그인 연동 후 true

# TODO: unlock_achievement(Play Games/Game Center), 광고 SDK 연동
