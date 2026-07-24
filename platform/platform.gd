extends Node
## Platform autoload — 실행 중인 빌드에 맞는 플랫폼 구현체를 선택.
## 게임 코드는 Platform.impl 또는 아래 위임 메서드만 호출하고,
## 스팀/모바일 구현체(steam/, mobile/)를 preload로 직접 참조하지 말 것
## (익스포트 필터로 반대 플랫폼 리소스가 빌드에서 제외되므로 파싱이 깨짐).

var impl: PlatformBase


func _ready() -> void:
	if OS.has_feature("steam"):
		impl = load("res://steam/steam_platform.gd").new()
	elif OS.has_feature("mobile"):
		impl = load("res://mobile/mobile_platform.gd").new()
	else:
		impl = PlatformBase.new()
	print("[Platform] ", impl.platform_name())


func platform_name() -> String:
	return impl.platform_name()


func unlock_achievement(id: String) -> void:
	impl.unlock_achievement(id)


func submit_score(board_id: String, score: int) -> void:
	impl.submit_score(board_id, score)


func sync_cloud_save() -> void:
	impl.sync_cloud_save()


func supports_iap() -> bool:
	return impl.supports_iap()


func supports_ads() -> bool:
	return impl.supports_ads()
