extends Node
## 부트 씬: 빌드의 피처 태그(개발 시엔 --steam/--mobile 인자)에 맞는
## 타이틀 씬으로 라우팅. 타이틀로 돌아갈 때도 항상 이 씬을 거친다 (main.gd 참조).
## 플랫폼 타이틀은 load()로만 여니 익스포트 필터에 안전.


## 개발용 강제 플랫폼("steam"/"mobile"/""). 런처 씬(tests/run_*.tscn)이나
## 플랫폼 타이틀이 설정하며, 타이틀 복귀 등 이후의 boot 라우팅에도 유지된다.
static var dev_platform := ""


func _ready() -> void:
	var path := title_path()
	# 데스크톱에서 모바일을 흉내낼 때 세로 화면도 함께 적용
	# (실제 모바일 빌드는 project.godot의 .mobile 오버라이드가 처리).
	if path.begins_with("res://mobile/") and not OS.has_feature("mobile"):
		apply_mobile_dev_window(get_window())
	print("[Boot] user_args=", OS.get_cmdline_user_args(),
			" dev_platform=", dev_platform, " -> ", path)
	get_tree().change_scene_to_file.call_deferred(path)


static func title_path() -> String:
	if OS.has_feature("steam") or dev_platform == "steam" or _has_arg("--steam"):
		return "res://steam/ui/title_steam.tscn"
	if OS.has_feature("mobile") or dev_platform == "mobile" or _has_arg("--mobile"):
		return "res://mobile/ui/title_mobile.tscn"
	return "res://core/scenes/title.tscn"


## `-- --mobile`(사용자 인자)뿐 아니라 `--mobile`(구분자 없이)도 허용 —
## 에디터의 Main Run Args처럼 `--`를 빼먹기 쉬운 곳에서도 동작하게.
static func _has_arg(flag: String) -> bool:
	return flag in OS.get_cmdline_user_args() or flag in OS.get_cmdline_args()


## 개발용 세로 창 (1080×1920 컨텐츠를 486×864 창에 표시).
static func apply_mobile_dev_window(win: Window) -> void:
	win.content_scale_size = Vector2i(1080, 1920)
	win.size = Vector2i(486, 864)
