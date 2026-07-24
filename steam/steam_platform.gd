extends PlatformBase
## 스팀 빌드 전용 구현. GodotSteam 연동 시 여기에 채워 넣는다.
## 주의: class_name 붙이지 말 것 — 모바일 빌드에서 이 파일은 제외되므로
## 전역 클래스로 등록되면 참조하는 쪽이 깨진다.


func platform_name() -> String:
	return "steam"

# TODO: GodotSteam 도입 후 unlock_achievement / submit_score / sync_cloud_save 구현
