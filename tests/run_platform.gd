extends Node
## F6 전용 개발 런처: 지정한 플랫폼으로 부트 흐름 전체를 실행한다.
## tests/run_mobile.tscn 또는 tests/run_steam.tscn을 열고 F6.

const BootScript := preload("res://core/scripts/boot.gd")

@export_enum("mobile", "steam") var platform := "mobile"


func _ready() -> void:
	BootScript.dev_platform = platform
	get_tree().change_scene_to_file.call_deferred("res://core/scenes/boot.tscn")
