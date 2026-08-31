extends PlatformBase
## 모바일(Android/iOS) 빌드 전용 구현. IAP/광고/플랫폼 게임 서비스 연동 지점.
## 주의: class_name 붙이지 말 것 — 스팀 빌드에서 이 파일은 제외됨.
##
## 랭킹·클라우드 세이브는 스팀처럼 플랫폼 SDK가 아니라 자체 서버(Supabase)를
## 쓴다 — 구현은 core 쪽 `Cloud` autoload이고, `Ranks`가 Backend.SERVER 로
## 직접 부른다. 그래서 여기서는 has_leaderboards()를 거짓으로 두고(그게 참이면
## `Ranks`가 스팀 리더보드 경로로 간다) 클라우드 동기화만 넘겨 준다.


func platform_name() -> String:
	return "mobile"


## 앱이 뜰 때·포그라운드로 돌아올 때 부르면 서버 세이브를 확인한다.
## (Cloud는 부팅 시 스스로 한 번 돌므로 여기서는 재동기화용.)
func sync_cloud_save() -> void:
	Cloud.sync()


func supports_iap() -> bool:
	return false  # TODO: 스토어 결제 플러그인 연동 후 true

# TODO: unlock_achievement(Play Games/Game Center), 광고 SDK 연동
# TODO: 구글/애플 로그인으로 익명 계정 승격 (기기 이전) — docs/cloud_setup.md ⑤
