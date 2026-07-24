extends Node
## 부트 씬: 빌드의 피처 태그(개발 시엔 `-- --steam`/`-- --mobile` 인자)에 맞는
## 타이틀 씬으로 라우팅. 타이틀로 돌아갈 때도 항상 이 씬을 거친다 (main.gd 참조).
## 플랫폼 타이틀은 load()로만 여니 익스포트 필터에 안전.


func _ready() -> void:
	# 데스크톱에서 `-- --mobile`로 모바일을 흉내낼 때 세로 화면도 함께 적용
	# (실제 모바일 빌드는 project.godot의 .mobile 오버라이드가 처리).
	if "--mobile" in OS.get_cmdline_user_args() and not OS.has_feature("mobile"):
		var win := get_window()
		win.content_scale_size = Vector2i(1080, 1920)
		win.size = Vector2i(486, 864)
	get_tree().change_scene_to_file.call_deferred(title_path())


static func title_path() -> String:
	var args := OS.get_cmdline_user_args()
	if OS.has_feature("steam") or "--steam" in args:
		return "res://steam/ui/title_steam.tscn"
	if OS.has_feature("mobile") or "--mobile" in args:
		return "res://mobile/ui/title_mobile.tscn"
	return "res://core/scenes/title.tscn"
